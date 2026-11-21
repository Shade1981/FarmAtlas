-- FarmAtlas - Sync
-- Shares discoveries with party, raid and guild members who also run FarmAtlas.
-- Everything happens in the background through hidden addon messages
-- (C_ChatInfo.SendAddonMessage), the same Blizzard-approved channel that
-- GatherMate2 and DBM use. No buttons, no chat spam.
--
-- The protocol only ever sends ABSOLUTE values ("this cell has n loots",
-- "I looted this NPC n times"), never "+1". Receiving the same message twice
-- therefore never inflates the numbers, and a slow background trickle can
-- re-send your whole database safely so new group members get it too.
--
-- Messages (fields separated by "^"):
--   C^key^cat^mapID^ck,x,y,n;ck,x,y,n...   loot cells of an item on a map
--   M^key^npcID^n^lvl^name                  how often an NPC dropped the item
--   K^npcID^n                               how many of that NPC were killed
--   R^recipe^type^npc^mapID^x^y^fac^copper  where a recipe is sold / drops
--   P^objID^fish,fish^mapID^ck,x,y,n;...   fishing school spots
--   O^name^mapID^ck,x,y,n;...              fishable wreckage / debris spots
--   Q^name^itemID:n,itemID:n...            what was fished from that object
--   T^npc^mapID^x^y                        a profession trainer's position
-- (older versions ignore P/O/Q/T, so they can be mixed freely)
--
-- Restore (fresh install / new computer): at login you say hello
--   H^items^recipes^Name1,Name2           your own counts and your characters
-- A group / guild member who once received data from one of those characters,
-- and holds more than you have now, sends it back to you only (whisper):
--   S^Name                                "I am restoring Name" (the others skip)
--   XC / XM / XK / XR ...                 same fields as C / M / K / R
-- Restored values are merged by MAXIMUM, never added, so nothing can grow by
-- being sent twice; only data that earlier came from your own character name
-- is sent back, and only to a player who asked for it (hello) a moment ago.
local _, ns = ...
local L = ns.L

local PREFIX = "FarmAtlas"
local PROTO = "1"
local SEP = "^"
local MAX_LEN = 250
local SEND_EVERY = 0.6       -- seconds between two messages
local TRICKLE_EVERY = 20     -- seconds between two background items
local MAX_PLAYERS = 300      -- shared players kept
local MAX_ITEMS_PER_PLAYER = 400
local RATE_PER_MIN = 60      -- incoming messages per sender per minute
local MAX_RECIPES_PER_PLAYER = 300
local MAX_SOURCES_PER_RECIPE = 4
local VALID_SRC = { vendor = true, drop = true }
local HELLO_DELAYS = { 20, 300 }   -- seconds after login: say hello (twice, for late roster)
local RESTORE_WINDOW = 900         -- a restore must start this long after our hello
local RESTORE_IDLE = 120           -- ...and, once it runs, it stays open while messages keep coming
local RESTORE_MAX = 3600           -- hard limit after our hello, however long a restore runs
local MAX_RESTORE_MSGS = 3000      -- per restoring player and session
local MAX_RESTORE_ITEMS = 1000

local Sync = {}
ns.Sync = Sync

local MAX_POOLS_PER_PLAYER = 200
local MAX_OBJS_PER_PLAYER = 100
local MAX_TRAINERS_PER_PLAYER = 200
local VALID_CAT = { cooking = true, skinning = true, fishing = true, mining = true, herbalism = true, learned = true }

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function Enabled()
    return ns.db and ns.db.settings.sync
end

local function Clean(s)
    s = tostring(s or "")
    return (s:gsub("[%^;,|\n\r]", " "))
end

-- shorten to n bytes without cutting an accented letter (UTF-8) in half
local function Cut(s, n)
    if #s <= n then return s end
    s = s:sub(1, n)
    local i = #s
    while i > 0 and s:byte(i) >= 128 and s:byte(i) < 192 do i = i - 1 end
    if i > 0 and s:byte(i) >= 192 then
        local b = s:byte(i)
        local need = (b >= 240 and 4) or (b >= 224 and 3) or 2
        if #s - i + 1 < need then s = s:sub(1, i - 1) end
    end
    return s
end

local function EncodeKey(key)
    if type(key) == "number" then return tostring(key) end
    return Clean(key)
end

local function DecodeKey(s)
    if not s or s == "" or #s > 60 then return nil end
    local num = tonumber(s)
    if num then
        if num < 1 or num > 9999999 or num ~= math.floor(num) then return nil end
        if ns.Items[num] then return num end
        if ns:ShouldRecordItem(num, false, nil) then return num end
        return nil
    end
    -- name keys must exist in our own data (same addon data on both sides)
    if ns.Items[s] then return s end
    return nil
end

local function Fmt(v) return string.format("%.1f", v) end

local function Channels()
    local out = {}
    if IsInRaid and IsInRaid(LE_PARTY_CATEGORY_INSTANCE or 2) then
        out[#out + 1] = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        out[#out + 1] = "RAID"
    elseif IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then
        out[#out + 1] = "INSTANCE_CHAT"
    elseif IsInGroup and IsInGroup() then
        out[#out + 1] = "PARTY"
    end
    if ns.db.settings.syncGuild and IsInGuild and IsInGuild() then
        out[#out + 1] = "GUILD"
    end
    return out
end

------------------------------------------------------------------------
-- send queue (coalesced: a newer value for the same thing replaces the old)
------------------------------------------------------------------------
local queue, queued = {}, {}

------------------------------------------------------------------------
-- newer version seen on another player: tell the player once per session
------------------------------------------------------------------------
local function VerNum(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    a, b, c = tonumber(a), tonumber(b), tonumber(c)
    if a > 99 or b > 99 or c > 99 then return nil end
    return a * 10000 + b * 100 + c
end
local updateTold = false
local function SeenVersion(v)
    if updateTold or not v then return end
    local theirs, mine = VerNum(v), VerNum(ns.version)
    if not (theirs and mine) or theirs <= mine then return end
    if theirs >= mine + 20000 then return end          -- more than one major ahead: not believable
    updateTold = true
    C_Timer.After(5, function() ns:Print(L("update_avail", v, ns.version or "?")) end)
end
ns.SyncSeenVersion = SeenVersion

local recentSent = {}                   -- [full message] = time we sent it (echo detection)
local selfFull = nil                    -- our name as others see it (WoW Forever: "First Last")
-- a random mark on our hello messages: only OUR message can come back with it.
-- (Another player whose first name is also "Shade" sends the very same "CH" -
-- without this mark his message looked like our own echo.)
local NONCE = tostring(math.random(100000, 999999)) .. tostring(math.floor((time and time() or 0) % 100000))
local sentCount = 0
local function MarkSent(full)
    local now = GetTime()
    sentCount = sentCount + 1
    if sentCount > 200 then
        sentCount = 0
        for k, t in pairs(recentSent) do if now - t > 30 then recentSent[k] = nil end end
    end
    recentSent[full] = now
end
local capture, captureSeen = nil, nil   -- set while building a full dump
local DevLive                           -- forward to the collector (defined below)

local function Enqueue(id, msg)
    if #msg > MAX_LEN then return end
    if capture then
        if not captureSeen[id] then captureSeen[id] = true; capture[#capture + 1] = msg end
        return
    end
    if DevLive then DevLive(id, msg) end
    if queued[id] then
        queued[id] = msg
    else
        queued[id] = msg
        queue[#queue + 1] = id
    end
end

local function SendNext()
    if #queue == 0 then return end
    local channels = Channels()
    if #channels == 0 then
        wipe(queue); wipe(queued)
        return
    end
    local id = table.remove(queue, 1)
    local msg = queued[id]
    queued[id] = nil
    if not msg then return end
    for _, ch in ipairs(channels) do
        C_ChatInfo.SendAddonMessage(PREFIX, PROTO .. SEP .. msg, ch)
    end
end

------------------------------------------------------------------------
-- building messages from YOUR data
------------------------------------------------------------------------
local function QueueCells(key, mapID, onlyCell)
    local entry = ns.db.learned[key]
    local cells = entry and entry.zones and entry.zones[mapID]
    if not cells then return end
    local cat = VALID_CAT[entry.cat] and entry.cat or "learned"
    local head = table.concat({ "C", EncodeKey(key), cat, tostring(mapID) }, SEP) .. SEP
    local parts, len, chunk = {}, #head, 0
    local function flush()
        if #parts == 0 then return end
        chunk = chunk + 1
        local id = "C:" .. tostring(key) .. ":" .. mapID .. ":" .. (onlyCell or chunk)
        Enqueue(id, head .. table.concat(parts, ";"))
        wipe(parts); len = #head
    end
    for ck, c in pairs(cells) do
        if not onlyCell or ck == onlyCell then
            local s = ck .. "," .. Fmt(c.x) .. "," .. Fmt(c.y) .. "," .. c.n
            if len + #s + 1 > MAX_LEN then flush() end
            parts[#parts + 1] = s
            len = len + #s + 1
        end
    end
    flush()
end

local function QueueMob(key, npcID)
    local entry = ns.db.learned[key]
    local m = entry and entry.mobs and entry.mobs[npcID]
    if not m then return end
    Enqueue("M:" .. tostring(key) .. ":" .. npcID, table.concat({
        "M", EncodeKey(key), tostring(npcID), tostring(m.n), tostring(m.lvl or 0),
        Cut(Clean(m.name or ns.db.npcNames[npcID] or ""), 40),
    }, SEP))
end

local function QueueKill(npcID)
    local k = ns.db.kills[npcID]
    if not k then return end
    Enqueue("K:" .. npcID, table.concat({ "K", tostring(npcID), tostring(k) }, SEP))
end

local function FacShort(f)
    if f == "Alliance" or f == "A" then return "A" end
    if f == "Horde" or f == "H" then return "H" end
    if f == "N" then return "N" end
    return ""
end

local function QueueRecipeSource(recipe, src)
    if not (recipe and src and VALID_SRC[src.type] and src.mapID and src.x and src.y) then return end
    local fac = ns:IsNeutralNPC(src.npc) and "N" or FacShort(src.faction)
    Enqueue("R:" .. recipe .. ":" .. tostring(src.npc), table.concat({
        "R", Cut(Clean(recipe), 60), src.type, Cut(Clean(src.npc or "?"), 40), tostring(src.mapID),
        Fmt(src.x), Fmt(src.y), fac, tostring(math.floor(tonumber(src.copper) or 0)),
    }, SEP))
end

local function CellParts(head, cells, idPrefix, onlyCell)
    local parts, len, chunk = {}, #head, 0
    local function flush()
        if #parts == 0 then return end
        chunk = chunk + 1
        Enqueue(idPrefix .. ":" .. (onlyCell or chunk), head .. table.concat(parts, ";"))
        wipe(parts); len = #head
    end
    for ck, c in pairs(cells) do
        if not onlyCell or ck == onlyCell then
            local s = ck .. "," .. Fmt(c.x) .. "," .. Fmt(c.y) .. "," .. math.floor(c.n or 1)
            if len + #s + 1 > MAX_LEN then flush() end
            parts[#parts + 1] = s
            len = len + #s + 1
        end
    end
    flush()
end

local function QueuePool(objID, mapID, onlyCell)
    local p = ns.db.pools and ns.db.pools[objID]
    local cells = p and p.zones and p.zones[mapID]
    if not cells then return end
    local fish = {}
    for id in pairs(p.fish or {}) do
        if #fish < 5 then fish[#fish + 1] = tostring(id) end
    end
    if #fish == 0 then return end
    local head = table.concat({ "P", tostring(objID), table.concat(fish, ","), tostring(mapID) }, SEP) .. SEP
    CellParts(head, cells, "P:" .. objID .. ":" .. mapID, onlyCell)
end

local function QueueFishObj(name, mapID, onlyCell)
    local o = ns.db.fishObjects and ns.db.fishObjects[name]
    if not o then return end
    local clean = Cut(Clean(name), 40)
    if mapID then
        local cells = o.zones and o.zones[mapID]
        if cells then CellParts(table.concat({ "O", clean, tostring(mapID) }, SEP) .. SEP, cells, "O:" .. name .. ":" .. mapID, onlyCell) end
    end
    local list = {}
    for id, n in pairs(o.items or {}) do list[#list + 1] = { id = id, n = n } end
    table.sort(list, function(a, b) return a.n > b.n end)
    local parts = {}
    for i = 1, math.min(8, #list) do parts[#parts + 1] = list[i].id .. ":" .. math.floor(list[i].n) end
    if #parts > 0 then Enqueue("Q:" .. name, table.concat({ "Q", clean, table.concat(parts, ",") }, SEP)) end
end

local function QueueTrainer(npc)
    local tp = ns.db.trainerPos and ns.db.trainerPos[npc]
    if not (tp and tp.mapID and tp.x and tp.y) then return end
    Enqueue("T:" .. npc, table.concat({ "T", Cut(Clean(npc), 40), tostring(tp.mapID), Fmt(tp.x), Fmt(tp.y) }, SEP))
end

ns:On("POOL_RECORDED", function(objID, mapID, cellKey)
    if Enabled() then QueuePool(objID, mapID, cellKey) end
end)
ns:On("FISHOBJ_RECORDED", function(name, mapID, cellKey)
    if Enabled() then QueueFishObj(name, mapID, cellKey) end
end)
ns:On("TRAINER_POS", function(npc)
    if Enabled() then QueueTrainer(npc) end
end)

-- live: a recipe vendor or recipe drop you just saw
ns:On("RECIPE_SOURCE_ADDED", function(recipe, src)
    if not Enabled() then return end
    QueueRecipeSource(recipe, src)
end)

-- live: right after you loot something
ns:On("LOOT_RECORDED", function(key, mapID, cellKey, npcID)
    if not Enabled() then return end
    QueueCells(key, mapID, cellKey)
    if npcID then QueueMob(key, npcID); QueueKill(npcID) end
end)

ns:On("KILL_RECORDED", function(npcID)
    if not Enabled() then return end
    -- only kills of NPCs that drop something we track are interesting
    for _, e in pairs(ns.db.learned) do
        if e.mobs and e.mobs[npcID] then QueueKill(npcID); return end
    end
end)

-- background trickle: slowly re-sends your whole database, one item at a time
local trickleKeys, trickleIndex = nil, 0
local function TrickleOne()
    if not Enabled() or #queue > 0 then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if #Channels() == 0 then return end
    if not trickleKeys or trickleIndex >= #trickleKeys then
        trickleKeys, trickleIndex = {}, 0
        for key, e in pairs(ns.db.learned) do
            if e.own and e.zones and next(e.zones) then trickleKeys[#trickleKeys + 1] = key end
        end
        for recipe, list in pairs(ns.db.recipeSources or {}) do
            for _, src in ipairs(list) do
                if VALID_SRC[src.type] then trickleKeys[#trickleKeys + 1] = { recipe = recipe }; break end
            end
        end
        for objID in pairs(ns.db.pools or {}) do trickleKeys[#trickleKeys + 1] = { pool = objID } end
        for name in pairs(ns.db.fishObjects or {}) do trickleKeys[#trickleKeys + 1] = { obj = name } end
        for npc in pairs(ns.db.trainerPos or {}) do trickleKeys[#trickleKeys + 1] = { trainer = npc } end
        if #trickleKeys == 0 then return end
    end
    trickleIndex = trickleIndex + 1
    local key = trickleKeys[trickleIndex]
    if type(key) == "table" then
        if key.recipe then
            for _, src in ipairs(ns.db.recipeSources[key.recipe] or {}) do QueueRecipeSource(key.recipe, src) end
        elseif key.pool then
            local p = ns.db.pools and ns.db.pools[key.pool]
            for mapID in pairs(p and p.zones or {}) do QueuePool(key.pool, mapID) end
        elseif key.obj then
            local o = ns.db.fishObjects and ns.db.fishObjects[key.obj]
            for mapID in pairs(o and o.zones or {}) do QueueFishObj(key.obj, mapID) end
            QueueFishObj(key.obj, nil)
        elseif key.trainer then
            QueueTrainer(key.trainer)
        end
        return
    end
    local entry = ns.db.learned[key]
    if not entry then return end
    for mapID in pairs(entry.zones or {}) do QueueCells(key, mapID) end
    local mobs = {}
    for npcID, m in pairs(entry.mobs or {}) do mobs[#mobs + 1] = { id = npcID, n = m.n } end
    table.sort(mobs, function(a, b) return a.n > b.n end)
    for i = 1, math.min(8, #mobs) do QueueMob(key, mobs[i].id); QueueKill(mobs[i].id) end
end

------------------------------------------------------------------------
-- receiving
------------------------------------------------------------------------
local rate = {}
local refreshPending = false
local recipePending = false

local function ScheduleRefresh()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(2, function()
        refreshPending = false
        ns:Fire("LEARNED_CHANGED")
    end)
end

local IsCollectorFn
local function PlayerBucket(sender)
    local shared = ns.db.shared
    local MAX_PLAYERS = (IsCollectorFn and IsCollectorFn()) and 5000 or MAX_PLAYERS
    local s = shared[sender]
    if not s then
        -- keep the store bounded: drop the player we heard from least recently
        local count, oldest, oldestT = 0, nil, math.huge
        for name, d in pairs(shared) do
            count = count + 1
            if (d.seen or 0) < oldestT then oldest, oldestT = name, d.seen or 0 end
        end
        if count >= MAX_PLAYERS and oldest then shared[oldest] = nil end
        s = { items = {}, kills = {}, nItems = 0 }
        shared[sender] = s
    end
    s.seen = time()
    return s
end

local function ItemBucket(s, key, cat)
    local it = s.items[key]
    if not it then
        if (s.nItems or 0) >= MAX_ITEMS_PER_PLAYER then return nil end
        it = { zones = {}, mobs = {} }
        s.items[key] = it
        s.nItems = (s.nItems or 0) + 1
    end
    -- make unknown items searchable for you as well
    if not ns.Items[key] and not ns.db.learned[key] then
        ns.db.learned[key] = {
            zones = {}, mobs = {}, total = 0,
            name = type(key) == "string" and key or nil,
            cat = cat or ns.GuessCategory(key, false),
            icon = ns:GetItemIcon(key),
        }
    end
    return it
end

local function HandleC(s, f)
    local key = DecodeKey(f[2])
    local cat = VALID_CAT[f[3]] and f[3] or nil
    local mapID = tonumber(f[4])
    if not (key and mapID and f[5]) then return end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    local it = ItemBucket(s, key, cat)
    if not it then return end
    local zone = it.zones[mapID] or {}
    local n = 0
    for part in f[5]:gmatch("[^;]+") do
        n = n + 1
        if n > 25 then break end
        local ck, x, y, cnt = part:match("^(%d+:%d+),([%d%.]+),([%d%.]+),(%d+)$")
        x, y, cnt = tonumber(x), tonumber(y), tonumber(cnt)
        if ck and x and y and cnt and x >= 0 and x <= 100 and y >= 0 and y <= 100
            and cnt >= 1 and cnt <= 100000 then
            zone[ns:CellKey(x, y)] = { x = x, y = y, n = cnt }   -- absolute value: replace
        end
    end
    if next(zone) then it.zones[mapID] = zone end
end

local function HandleM(s, f)
    local key = DecodeKey(f[2])
    local npcID, cnt, lvl = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
    if not (key and npcID and cnt) then return end
    if npcID < 1 or npcID > 9999999 or cnt < 1 or cnt > 100000 then return end
    local it = ItemBucket(s, key)
    if not it then return end
    local name = f[6] and f[6] ~= "" and Cut(f[6], 40) or nil
    it.mobs[npcID] = { n = cnt, lvl = (lvl and lvl > 0 and lvl <= 63) and lvl or nil, name = name }
    if name and not ns.db.npcNames[npcID] then ns.db.npcNames[npcID] = name end
end

local function HandleK(s, f)
    local npcID, cnt = tonumber(f[2]), tonumber(f[3])
    if not (npcID and cnt) or npcID < 1 or npcID > 9999999 or cnt < 1 or cnt > 1000000 then return end
    s.kills[npcID] = cnt
end

local function HandleR(s, f)
    local recipe, typ, npc = f[2], f[3], f[4]
    local mapID, x, y = tonumber(f[5]), tonumber(f[6]), tonumber(f[7])
    local fac, copper = f[8], tonumber(f[9])
    if not (recipe and npc and mapID and x and y) then return end
    if #recipe < 3 or #recipe > 60 or #npc < 2 or #npc > 40 then return end
    if not recipe:match("^[%w%s%'%-%.:]+$") or not npc:match("^[%w%s%'%-%.]+$") then return end
    if not VALID_SRC[typ] then return end
    if x < 0 or x > 100 or y < 0 or y > 100 then return end
    if fac ~= "A" and fac ~= "H" and fac ~= "N" then fac = nil end
    if copper and (copper < 0 or copper > 100000000) then copper = nil end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    s.recipes = s.recipes or {}
    local list = s.recipes[recipe]
    if not list then
        if (s.nRecipes or 0) >= MAX_RECIPES_PER_PLAYER then return end
        list = {}
        s.recipes[recipe] = list
        s.nRecipes = (s.nRecipes or 0) + 1
    end
    local entry = { type = typ, npc = npc, mapID = mapID, x = x, y = y, faction = fac,
        copper = (copper and copper > 0) and copper or nil }
    for i, old in ipairs(list) do
        if old.npc == npc and old.type == typ then list[i] = entry; return end
    end
    if #list >= MAX_SOURCES_PER_RECIPE then return end
    list[#list + 1] = entry
end

local function ValidName(s)
    return type(s) == "string" and #s >= 2 and #s <= 40 and s:match("^[%w%s%'%-%.:]+$") ~= nil
end

local function ReadCells(str, zone)
    local n = 0
    for part in str:gmatch("[^;]+") do
        n = n + 1
        if n > 25 then break end
        local ck, x, y, cnt = part:match("^(%d+:%d+),([%d%.]+),([%d%.]+),(%d+)$")
        x, y, cnt = tonumber(x), tonumber(y), tonumber(cnt)
        if ck and x and y and cnt and x >= 0 and x <= 100 and y >= 0 and y <= 100 and cnt >= 1 and cnt <= 100000 then
            zone[ns:CellKey(x, y)] = { x = x, y = y, n = cnt }   -- absolute value: replace
        end
    end
end

local function HandleP(s, f)
    local objID, mapID = tonumber(f[2]), tonumber(f[4])
    if not (objID and mapID and f[3] and f[5]) or objID < 1 or objID > 99999999 then return end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    s.pools = s.pools or {}
    local p = s.pools[objID]
    if not p then
        if (s.nPools or 0) >= MAX_POOLS_PER_PLAYER then return end
        p = { fish = {}, zones = {} }
        s.pools[objID] = p
        s.nPools = (s.nPools or 0) + 1
    end
    local nf = 0
    for id in f[3]:gmatch("%d+") do
        nf = nf + 1
        if nf > 5 then break end
        local fid = tonumber(id)
        if fid and ns.Items[fid] and ns.Items[fid].cat == "fishing" then p.fish[fid] = true end
    end
    if not next(p.fish) then s.pools[objID] = nil; s.nPools = s.nPools - 1; return end
    local zone = p.zones[mapID] or {}
    ReadCells(f[5], zone)
    if next(zone) then p.zones[mapID] = zone end
end

local function ObjBucket(s, name)
    s.fishObjects = s.fishObjects or {}
    local o = s.fishObjects[name]
    if not o then
        if (s.nObjs or 0) >= MAX_OBJS_PER_PLAYER then return end
        o = { items = {}, zones = {} }
        s.fishObjects[name] = o
        s.nObjs = (s.nObjs or 0) + 1
    end
    return o
end

local function HandleO(s, f)
    local name, mapID = f[2], tonumber(f[3])
    if not (ValidName(name) and mapID and f[4]) then return end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    local o = ObjBucket(s, name)
    if not o then return end
    local zone = o.zones[mapID] or {}
    ReadCells(f[4], zone)
    if next(zone) then o.zones[mapID] = zone end
end

local function HandleQ(s, f)
    local name = f[2]
    if not (ValidName(name) and f[3]) then return end
    local o = ObjBucket(s, name)
    if not o then return end
    local n = 0
    for id, cnt in f[3]:gmatch("(%d+):(%d+)") do
        n = n + 1
        if n > 8 then break end
        id, cnt = tonumber(id), tonumber(cnt)
        if id and cnt and id >= 1 and id <= 9999999 and cnt >= 1 and cnt <= 100000 then o.items[id] = cnt end
    end
end

local function HandleT(s, f)
    local npc, mapID, x, y = f[2], tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
    if not (ValidName(npc) and mapID and x and y) or x < 0 or x > 100 or y < 0 or y > 100 then return end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    s.trainerPos = s.trainerPos or {}
    if not s.trainerPos[npc] then
        if (s.nTrainers or 0) >= MAX_TRAINERS_PER_PLAYER then return end
        s.nTrainers = (s.nTrainers or 0) + 1
    end
    s.trainerPos[npc] = { mapID = mapID, x = x, y = y }
end

------------------------------------------------------------------------
-- restore: get your own finds back after a fresh install
------------------------------------------------------------------------
local helloAt = nil                 -- when we last asked (restores accepted for a while)
local restoreGot = {}               -- [sender] = restore messages received this session
local restoreSkip = {}              -- [name] = time someone else started restoring them
local restorePending = {}           -- [name] = true while we wait to start
local rq, rqTarget = {}, nil        -- our outgoing restore queue (one target at a time)

local function MyNames()
    local realm = GetRealmName and ns.Plain(GetRealmName()) or nil
    local out, seen = {}, {}
    local me = ns.Plain(UnitName("player"))
    if me then out[1] = me; seen[me] = true end
    for key, c in pairs(ns.db.chars or {}) do
        local r, n = tostring(key):match("^(.-)%-([^@]+)")
        if type(c) == "table" and c.name then n = c.name end
        if n and r == realm and not seen[n] and #out < 10 then out[#out + 1] = n; seen[n] = true end
    end
    return out
end

local function OwnCounts()
    local items, recipes = 0, 0
    for _, e in pairs(ns.db.learned) do if e.own and e.zones and next(e.zones) then items = items + 1 end end
    for _, list in pairs(ns.db.recipeSources or {}) do
        for _, s in ipairs(list) do if VALID_SRC[s.type] then recipes = recipes + 1; break end end
    end
    return items, recipes
end

local function SayHello()
    if not Enabled() then return end
    local channels = Channels()
    if #channels == 0 then return end
    local items, recipes = OwnCounts()
    local names = {}
    for _, n in ipairs(MyNames()) do names[#names + 1] = Clean(n) end
    local msg = table.concat({ "H", tostring(items), tostring(recipes), table.concat(names, ","), tostring(ns.version or ""), NONCE }, SEP)
    if #msg > MAX_LEN then return end
    helloAt = GetTime()
    MarkSent(PROTO .. SEP .. msg)
    for _, ch in ipairs(channels) do C_ChatInfo.SendAddonMessage(PREFIX, PROTO .. SEP .. msg, ch) end
end

-- build the restore messages of one shared player bucket, for one target
local function BuildRestore(s)
    local out = {}
    for key, it in pairs(s.items or {}) do
        local cat = ns.Items[key] and ns.Items[key].cat or (ns.db.learned[key] and ns.db.learned[key].cat)
        cat = VALID_CAT[cat] and cat or "learned"
        for mapID, cells in pairs(it.zones or {}) do
            local head = table.concat({ "XC", EncodeKey(key), cat, tostring(mapID) }, SEP) .. SEP
            local parts, len = {}, #head
            local function flush()
                if #parts > 0 then out[#out + 1] = head .. table.concat(parts, ";") end
                wipe(parts); len = #head
            end
            for ck, c in pairs(cells) do
                local part = ck .. "," .. Fmt(c.x) .. "," .. Fmt(c.y) .. "," .. c.n
                if len + #part + 1 > MAX_LEN or #parts >= 25 then flush() end
                parts[#parts + 1] = part
                len = len + #part + 1
            end
            flush()
        end
        for npcID, m in pairs(it.mobs or {}) do
            out[#out + 1] = table.concat({ "XM", EncodeKey(key), tostring(npcID), tostring(m.n), tostring(m.lvl or 0),
                Cut(Clean(m.name or ""), 40) }, SEP)
        end
    end
    for npcID, n in pairs(s.kills or {}) do out[#out + 1] = table.concat({ "XK", tostring(npcID), tostring(n) }, SEP) end
    for recipe, list in pairs(s.recipes or {}) do
        for _, src in ipairs(list) do
            out[#out + 1] = table.concat({ "XR", Cut(Clean(recipe), 60), src.type, Cut(Clean(src.npc or "?"), 40),
                tostring(src.mapID), Fmt(src.x), Fmt(src.y), src.faction or "", tostring(math.floor(tonumber(src.copper) or 0)) }, SEP)
        end
    end
    return out
end

local function SendRestoreNext()
    if not rqTarget then return end
    if #rq == 0 then rqTarget = nil; return end
    if InCombatLockdown and InCombatLockdown() then return end
    local msg = table.remove(rq, 1)
    if #msg <= MAX_LEN then C_ChatInfo.SendAddonMessage(PREFIX, PROTO .. SEP .. msg, "WHISPER", rqTarget) end
end

-- someone said hello: if we hold more of their own finds than they have, send them back
local function HandleHello(f, channel, sender, short)
    SeenVersion(f[5])
    local theirItems, theirRecipes = tonumber(f[2]) or 0, tonumber(f[3]) or 0
    if rqTarget then return end                      -- one restore at a time
    -- WoW Forever: we keep their finds under the full name we saw ("Shade Tide"),
    -- while their hello lists first names only - so check the sender's own name first
    local cands, seenC = { short }, { [short] = true }
    for name in (f[4] or ""):gmatch("[^,]+") do
        if not seenC[name] then seenC[name] = true; cands[#cands + 1] = name end
    end
    for _, name in ipairs(cands) do
        local s = ns.db.shared[name]
        local items = s and s.nItems or 0
        local recipes = s and s.nRecipes or 0
        if s and (items > theirItems or recipes > theirRecipes) and not restorePending[short] then
            restorePending[short] = true
            -- wait a random moment; whoever starts first tells the others to skip
            C_Timer.After(3 + math.random() * 17, function()
                restorePending[short] = nil
                if rqTarget or (restoreSkip[short] and GetTime() - restoreSkip[short] < 120) then return end
                local msgs = BuildRestore(s)
                if #msgs == 0 then return end
                C_ChatInfo.SendAddonMessage(PREFIX, PROTO .. SEP .. "S" .. SEP .. Clean(short), channel)
                rq, rqTarget = msgs, sender
            end)
            return
        end
    end
end

-- merge a restored value into YOUR data: keep the larger value, never add
local function RestoreC(f)
    local key = DecodeKey(f[2])
    local cat = VALID_CAT[f[3]] and f[3] or nil
    local mapID = tonumber(f[4])
    if not (key and mapID and f[5]) then return end
    if not (C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)) then return end
    local entry = ns.db.learned[key]
    if not entry then
        local n = 0
        for _ in pairs(ns.db.learned) do n = n + 1 end
        if n >= MAX_RESTORE_ITEMS then return end
        entry = { zones = {}, mobs = {}, total = 0, cat = cat or ns.GuessCategory(key, false),
            name = type(key) == "string" and key or nil, icon = ns:GetItemIcon(key) }
        ns.db.learned[key] = entry
    end
    entry.own = true
    local zone = entry.zones[mapID] or {}
    local n, sum = 0, 0
    for part in f[5]:gmatch("[^;]+") do
        n = n + 1
        if n > 25 then break end
        local _, x, y, cnt = part:match("^(%d+:%d+),([%d%.]+),([%d%.]+),(%d+)$")
        x, y, cnt = tonumber(x), tonumber(y), tonumber(cnt)
        if x and y and cnt and x >= 0 and x <= 100 and y >= 0 and y <= 100 and cnt >= 1 and cnt <= 100000 then
            local ck = ns:CellKey(x, y)
            local old = zone[ck]
            if not old or cnt > (old.n or 0) then zone[ck] = { x = x, y = y, n = cnt } end
        end
    end
    if next(zone) then entry.zones[mapID] = zone end
    for _, cells in pairs(entry.zones) do for _, c in pairs(cells) do sum = sum + (c.n or 0) end end
    if sum > (entry.total or 0) then entry.total = sum end
end

local function RestoreM(f)
    local key = DecodeKey(f[2])
    local npcID, cnt, lvl = tonumber(f[3]), tonumber(f[4]), tonumber(f[5])
    if not (key and npcID and cnt) or npcID < 1 or npcID > 9999999 or cnt < 1 or cnt > 100000 then return end
    local entry = ns.db.learned[key]
    if not entry then return end            -- mobs only for items restored above
    local old = entry.mobs[npcID]
    if not old or cnt > (old.n or 0) then
        local name = f[6] and f[6] ~= "" and Cut(f[6], 40) or (old and old.name) or nil
        entry.mobs[npcID] = { n = cnt, lvl = (lvl and lvl > 0 and lvl <= 63) and lvl or (old and old.lvl), name = name }
        if name and not ns.db.npcNames[npcID] then ns.db.npcNames[npcID] = name end
    end
end

local function RestoreK(f)
    local npcID, cnt = tonumber(f[2]), tonumber(f[3])
    if not (npcID and cnt) or npcID < 1 or npcID > 9999999 or cnt < 1 or cnt > 1000000 then return end
    if cnt > (ns.db.kills[npcID] or 0) then ns.db.kills[npcID] = cnt end
end

local function RestoreR(f)
    local tmp = { kills = {}, items = {} }
    HandleR(tmp, { "R", f[2], f[3], f[4], f[5], f[6], f[7], f[8], f[9] })
    for recipe, list in pairs(tmp.recipes or {}) do
        for _, src in ipairs(list) do
            local have = false
            for _, o in ipairs(ns.db.recipeSources[recipe] or {}) do
                if o.type == src.type and o.npc == src.npc then have = true end
            end
            if not have then
                ns:AddRecipeSource(recipe, { type = src.type, npc = src.npc, mapID = src.mapID, x = src.x, y = src.y,
                    faction = src.faction == "A" and "Alliance" or (src.faction == "H" and "Horde" or nil), copper = src.copper })
            end
        end
    end
end

-- a restore message for us (whisper, shortly after our hello, bounded)
local restoreLast = {}             -- [sender] = time of the last restore message
local function HandleRestore(f, channel, short)
    if channel ~= "WHISPER" then return end
    if not helloAt then return end
    local now, since = GetTime(), GetTime() - helloAt
    local running = restoreLast[short] and now - restoreLast[short] <= RESTORE_IDLE
    if since > RESTORE_MAX or (since > RESTORE_WINDOW and not running) then return end
    restoreLast[short] = now
    restoreGot[short] = (restoreGot[short] or 0) + 1
    if restoreGot[short] > MAX_RESTORE_MSGS then return end
    local kind = f[1]
    if kind == "XC" then RestoreC(f)
    elseif kind == "XM" then RestoreM(f)
    elseif kind == "XK" then RestoreK(f)
    elseif kind == "XR" then RestoreR(f) end
    if not restoreGot.notified then
        restoreGot.notified = true
        C_Timer.After(30, function() ns:Print(L("sync_restored", short)) end)
    end
    ScheduleRefresh()
end
ns.SyncRestore = { Hello = SayHello, HandleHello = HandleHello, HandleRestore = HandleRestore, Build = BuildRestore,
    Send = SendRestoreNext, Names = MyNames, State = function() return rq, rqTarget end }

local Dev = {}
local ValidCollectorFn

-- the collector: something another player's guild sent them, with the finder's name.
-- Read into a scratch bucket, then kept per finder by the larger value, so a relayed
-- older copy never lowers what the finder sent us directly.
local function Bigger(a, b) return (b and b.n or 0) > (a and a.n or 0) end
local function MergeCells(dst, src)
    for ck, c in pairs(src or {}) do
        if Bigger(dst[ck], c) then dst[ck] = { x = c.x, y = c.y, n = c.n } end
    end
end
local function HandleForward(f, relay)
    local origin = f[2]
    if type(origin) ~= "string" or #origin < 2 or #origin > 48 or origin:find("[%c%^|]") or origin == relay then return end
    if ValidCollectorFn and ValidCollectorFn(origin, origin) then return end
    local inner = {}
    for i = 3, #f do inner[#inner + 1] = f[i] end
    local kind = inner[1]
    local tmp = { items = {}, kills = {}, nItems = 0 }
    if kind == "C" then HandleC(tmp, inner)
    elseif kind == "M" then HandleM(tmp, inner)
    elseif kind == "K" then HandleK(tmp, inner)
    elseif kind == "P" then HandleP(tmp, inner)
    elseif kind == "O" then HandleO(tmp, inner)
    elseif kind == "Q" then HandleQ(tmp, inner)
    elseif kind == "T" then HandleT(tmp, inner)
    else return end
    local s = PlayerBucket(origin)
    for key, it in pairs(tmp.items) do
        local d = ItemBucket(s, key)
        if d then
            for mapID, cells in pairs(it.zones) do
                d.zones[mapID] = d.zones[mapID] or {}
                MergeCells(d.zones[mapID], cells)
            end
            for npcID, m in pairs(it.mobs) do
                if Bigger(d.mobs[npcID], m) then d.mobs[npcID] = m end
            end
        end
    end
    for npcID, n in pairs(tmp.kills) do
        if n > (s.kills[npcID] or 0) then s.kills[npcID] = n end
    end
    for objID, p in pairs(tmp.pools or {}) do
        s.pools = s.pools or {}
        local d = s.pools[objID]
        if not d and (s.nPools or 0) < MAX_POOLS_PER_PLAYER then
            d = { fish = {}, zones = {} }; s.pools[objID] = d; s.nPools = (s.nPools or 0) + 1
        end
        if d then
            for fid in pairs(p.fish) do d.fish[fid] = true end
            for mapID, cells in pairs(p.zones) do d.zones[mapID] = d.zones[mapID] or {}; MergeCells(d.zones[mapID], cells) end
        end
    end
    for name, o in pairs(tmp.fishObjects or {}) do
        local d = ObjBucket(s, name)
        if d then
            for id, n in pairs(o.items) do if n > (d.items[id] or 0) then d.items[id] = n end end
            for mapID, cells in pairs(o.zones) do d.zones[mapID] = d.zones[mapID] or {}; MergeCells(d.zones[mapID], cells) end
        end
    end
    for npc, tp in pairs(tmp.trainerPos or {}) do
        s.trainerPos = s.trainerPos or {}
        if not s.trainerPos[npc] and (s.nTrainers or 0) < MAX_TRAINERS_PER_PLAYER then
            s.nTrainers = (s.nTrainers or 0) + 1
            s.trainerPos[npc] = tp
        end
    end
end

local function OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or not Enabled() or not sender then return end
    if channel == "GUILD" and not ns.db.settings.syncGuild then return end
    local me = UnitName("player")
    local short = Ambiguate(sender, "none")
    if short == me or sender == me or (selfFull and (short == selfFull or sender == selfFull)) then return end
    -- our own guild / group / channel message coming back under our full name
    local sentAt = recentSent[msg]
    if sentAt and GetTime() - sentAt < 15 and channel ~= "WHISPER" then
        local first = tostring(short):match("^([^%s%-]+)")
        if first == me then
            selfFull = short
            if ns.db.shared then ns.db.shared[short] = nil end
            return
        end
    end

    local f = { strsplit(SEP, msg) }
    if f[1] ~= PROTO then return end
    table.remove(f, 1)
    -- the shared data channel only carries the collector's "I am here"
    if channel == "CHANNEL" then
        if f[1] == "CH" then
            if ValidCollectorFn and ValidCollectorFn(sender, short) then SeenVersion(f[2]) end
            Dev.OnCollector(sender, short)
        end
        return
    end
    if channel == "WHISPER" and Dev.IsCollector() then Dev.Got(short, f[1]) end
    -- restore traffic has its own limits (only after our hello, capped per sender)
    if f[1] == "XC" or f[1] == "XM" or f[1] == "XK" or f[1] == "XR" then
        HandleRestore(f, channel, short)
        return
    end

    -- simple flood protection per sender
    local now = GetTime()
    local r = rate[short]
    if not r or now - r.t > 60 then r = { t = now, n = 0 }; rate[short] = r end
    r.n = r.n + 1
    if r.n > RATE_PER_MIN then return end

    if f[1] == "F" then
        if channel == "WHISPER" and Dev.IsCollector() then HandleForward(f, short); ScheduleRefresh() end
        return
    end
    if f[1] == "H" then HandleHello(f, channel, sender, short); return end
    if f[1] == "S" then if f[2] then restoreSkip[f[2]] = GetTime() end; return end
    local s = PlayerBucket(short)
    if f[1] == "C" then HandleC(s, f)
    elseif f[1] == "M" then HandleM(s, f)
    elseif f[1] == "K" then HandleK(s, f)
    elseif f[1] == "P" then HandleP(s, f)
    elseif f[1] == "O" then HandleO(s, f)
    elseif f[1] == "Q" then HandleQ(s, f)
    elseif f[1] == "T" then HandleT(s, f)
    elseif f[1] == "R" then
        HandleR(s, f)
        if not recipePending then
            recipePending = true
            C_Timer.After(2, function() recipePending = false; ns:Fire("RECIPES_CHANGED") end)
        end
        return
    else return end
    -- pass a guild / group mate's find on to the collector while it is online
    if channel ~= "WHISPER" and DevLive then
        local inner = msg:sub(#PROTO + #SEP + 1)
        local name = Cut(Clean(short), 40)
        if name ~= "" and #inner + #name + 3 <= MAX_LEN
            and not (ValidCollectorFn and ValidCollectorFn(sender, short)) then
            DevLive("F:" .. name .. ":" .. inner, "F" .. SEP .. name .. SEP .. inner)
        end
    end
    ScheduleRefresh()
end

------------------------------------------------------------------------
-- community collector: while the addon author's character is online, the
-- other FarmAtlas users on the same realm send their finds to that one
-- character (whisper), so they can ship with the next version for everyone.
-- Only game data, never anything personal; can be switched off in Options.
--   CH   on the hidden channel: "the collector is here" (only that character)
-- after that the normal C / M / K / R / P / O / Q / T messages go to it.
------------------------------------------------------------------------
-- full = the name other players see (WoW Forever: first and last name), lower case, no spaces
local COLLECTORS = { { name = "Shade", full = "shadetide", realm = "CAMWOWEU5Realm1PvE" } }
local DEV_CHANNEL = "FarmAtlasData"
local DEV_EVERY = 1.5          -- seconds between two messages to the collector
local DEV_ACTIVE = 150         -- collector counts as online this long after its last "here"
local DEV_REDUMP = 600         -- a full dump again only after the collector was away this long
local COLLECTOR_HELLO = 60

local function NoSpace(s) return (tostring(s or ""):gsub("%s", "")) end

local function DevOn()
    return Enabled() and ns.db.settings.devShare ~= false
end

function Dev.IsCollector()
    local me = ns.Plain(UnitName("player"))
    local realm = NoSpace(GetRealmName and ns.Plain(GetRealmName()) or "")
    for _, c in ipairs(COLLECTORS) do
        if me == c.name and realm == c.realm then
            -- once our full name is known, only the right character collects
            if selfFull and NoSpace(selfFull):lower():gsub("%-.*$", "") ~= c.full then return false end
            return true
        end
    end
    return false
end
IsCollectorFn = Dev.IsCollector

local function ValidCollector(sender, short)
    local myRealm = NoSpace(GetRealmName and ns.Plain(GetRealmName()) or ""):lower()
    local function Check(s)
        s = NoSpace(s):lower()
        local name, realm = s:match("^([^%-]+)%-(.+)$")
        if not name then name, realm = s, myRealm end
        for _, c in ipairs(COLLECTORS) do
            if name == c.full and (realm == myRealm or realm == c.realm:lower()) then return true end
        end
        return false
    end
    return Check(sender) or Check(short)
end
ValidCollectorFn = ValidCollector

local devTarget, devSeen, devAway = nil, nil, true
local devQ, devQueued = {}, {}

local function DevActive()
    return devTarget and devSeen and GetTime() - devSeen <= DEV_ACTIVE and DevOn()
end

DevLive = function(id, msg)
    if not DevActive() then return end
    if not devQueued[id] and #devQ >= 4000 then return end
    if devQueued[id] then devQueued[id] = msg; return end
    devQueued[id] = msg
    devQ[#devQ + 1] = id
end

-- every own find, built with the same message builders as the group sync
-- what the guild / group sent us, passed on with its finder's name ("F^finder^...")
local RELAY_ROOM = 50
local function BuildRelay(out)
    local db = ns.db
    local saved = { db.learned, db.kills, db.pools, db.fishObjects, db.trainerPos }
    local savedLen = MAX_LEN
    MAX_LEN = savedLen - RELAY_ROOM
    pcall(function()
    for origin, b in pairs(db.shared or {}) do
        local name = Cut(Clean(origin), 40)
        if name ~= "" and not (ValidCollectorFn and ValidCollectorFn(origin, origin)) then
            local fake = {}
            for key, it in pairs(b.items or {}) do
                local src = ns.Items[key] or saved[1][key]
                fake[key] = { zones = it.zones or {}, mobs = it.mobs or {}, own = true, cat = src and src.cat }
            end
            db.learned, db.kills = fake, b.kills or {}
            db.pools, db.fishObjects, db.trainerPos = b.pools or {}, b.fishObjects or {}, b.trainerPos or {}
            capture, captureSeen = {}, {}
            pcall(function()
                for key, e in pairs(fake) do
                    for mapID in pairs(e.zones) do QueueCells(key, mapID) end
                    for npcID in pairs(e.mobs) do QueueMob(key, npcID) end
                end
                for npcID in pairs(db.kills) do QueueKill(npcID) end
                for objID, p in pairs(db.pools) do
                    for mapID in pairs(p.zones or {}) do QueuePool(objID, mapID) end
                end
                for oname, o in pairs(db.fishObjects) do
                    for mapID in pairs(o.zones or {}) do QueueFishObj(oname, mapID) end
                    QueueFishObj(oname, nil)
                end
                for npc in pairs(db.trainerPos) do QueueTrainer(npc) end
            end)
            for _, m in ipairs(capture) do out[#out + 1] = "F" .. SEP .. name .. SEP .. m end
        end
    end
    end)
    db.learned, db.kills, db.pools, db.fishObjects, db.trainerPos = saved[1], saved[2], saved[3], saved[4], saved[5]
    MAX_LEN = savedLen
    capture, captureSeen = nil, nil
end

local function BuildDump()
    capture, captureSeen = {}, {}
    local ok = pcall(function()
        for key, e in pairs(ns.db.learned) do
            if e.own and e.zones and next(e.zones) then
                for mapID in pairs(e.zones) do QueueCells(key, mapID) end
                for npcID in pairs(e.mobs or {}) do QueueMob(key, npcID); QueueKill(npcID) end
            end
        end
        for recipe, list in pairs(ns.db.recipeSources or {}) do
            for _, src in ipairs(list) do if VALID_SRC[src.type] then QueueRecipeSource(recipe, src) end end
        end
        for objID, p in pairs(ns.db.pools or {}) do
            for mapID in pairs(p.zones or {}) do QueuePool(objID, mapID) end
        end
        for name, o in pairs(ns.db.fishObjects or {}) do
            for mapID in pairs(o.zones or {}) do QueueFishObj(name, mapID) end
            QueueFishObj(name, nil)
        end
        for npc in pairs(ns.db.trainerPos or {}) do QueueTrainer(npc) end
    end)
    local out = ok and capture or {}
    capture, captureSeen = nil, nil
    local relayOk = pcall(BuildRelay, out)
    if not relayOk then
        -- never leave the real tables swapped out
        capture, captureSeen = nil, nil
    end
    return out
end

function Dev.OnCollector(sender, short)
    if not DevOn() or Dev.IsCollector() then return end
    if not ValidCollector(sender, short) then return end
    local now = GetTime()
    local away = devAway or not devSeen or now - devSeen > DEV_REDUMP
    devTarget, devSeen, devAway = sender, now, false
    if away then
        local i = 0
        for _, msg in ipairs(BuildDump()) do
            i = i + 1
            DevLive("dump" .. i, msg)
        end
    end
end

local function DevSendNext()
    if #devQ == 0 then return end
    if not DevActive() then wipe(devQ); wipe(devQueued); return end
    if #queue > 0 then return end                       -- the group sync goes first
    if InCombatLockdown and InCombatLockdown() then return end
    if IsInInstance and IsInInstance() then return end
    local id = table.remove(devQ, 1)
    local msg = devQueued[id]
    devQueued[id] = nil
    if msg then pcall(C_ChatInfo.SendAddonMessage, PREFIX, PROTO .. SEP .. msg, "WHISPER", devTarget) end
end

-- the collector: who sent something this session
local devGot, devGotN = {}, 0
-- per sender this session: messages by kind, first / last arrival (only for the collector)
local KIND_HU = { C = "farmhely", M = "drop", K = "ölésszám", R = "receptforrás", P = "halraj", O = "roncs", Q = "roncsfogás", T = "tréner", F = "guildtársaktól továbbított" }
local devStats, helloSent, helloLast = {}, 0, nil
function Dev.Got(short, kind)
    local st = devStats[short]
    if not st then
        st = { n = 0, kinds = {}, first = GetTime() }
        devStats[short] = st
    end
    st.n = st.n + 1
    st.last = GetTime()
    st.done = nil
    if kind then st.kinds[kind] = (st.kinds[kind] or 0) + 1 end
    if devGot[short] then return end
    devGot[short] = true
    devGotN = devGotN + 1
    if devGotN <= 30 then ns:Print(L("dev_got", short)) end
end

local function KindText(st)
    local parts = {}
    for k, label in pairs(KIND_HU) do
        if st.kinds[k] then parts[#parts + 1] = st.kinds[k] .. " " .. label end
    end
    table.sort(parts)
    return table.concat(parts, ", ")
end

-- a sender went quiet: their package is in
local function CheckDone()
    if not Dev.IsCollector() then return end
    local now = GetTime()
    for name, st in pairs(devStats) do
        if not st.done and st.last and now - st.last > 30 then
            st.done = true
            ns:Print(("|cff3fc7ebGyűjtés:|r %s csomagja megjött: %d üzenet (%s)."):format(name, st.n, KindText(st)))
        end
    end
end

-- /farm gyujtes (only on the collector character)
function Dev.Status()
    local id = GetChannelName and tonumber(ns.Plain(GetChannelName(DEV_CHANNEL)))
    ns:Print(("|cff3fc7ebGyűjtés:|r csatorna %s, jelzés kiküldve %d alkalommal%s."):format(
        (id and id > 0) and "|cff33ff33rendben|r" or "|cffff4444nincs bent|r", helloSent,
        helloLast and (", utoljára " .. math.floor(GetTime() - helloLast) .. " mp-e") or ""))
    local names = {}
    for name in pairs(devStats) do names[#names + 1] = name end
    table.sort(names)
    if #names == 0 then ns:Print("Ebben a munkamenetben még senki nem küldött adatot."); return end
    local now = GetTime()
    for _, name in ipairs(names) do
        local st = devStats[name]
        ns:Print(("  %s: %d üzenet, %s - %s"):format(name, st.n, KindText(st),
            st.done and "kész" or ("most is jön (" .. math.floor(now - st.last) .. " mp-e)")))
    end
end

-- hide our "joined channel" lines; the channel itself never prints anything
local function NoticeFilter(_, _, _, _, _, _, _, _, _, _, chanName)
    chanName = ns.Plain(chanName)
    if chanName and tostring(chanName):find(DEV_CHANNEL, 1, true) then return true end
    return false
end
-- the collector just logged off: hide "No player named ... is currently playing"
local notFound = nil
local function SystemFilter(_, _, text)
    text = ns.Plain(text)
    if not (text and devTarget) then return false end
    if not notFound then
        local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S or "No player named '%s' is currently playing."
        notFound = "^" .. fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
    end
    local who = tostring(text):match(notFound)
    if who and (who == devTarget or Ambiguate(devTarget, "none") == who or devTarget:find(who, 1, true) == 1) then
        devSeen, devAway = nil, true
        wipe(devQ); wipe(devQueued)
        return true
    end
    return false
end
local filterAdded = false
local function AddFilter()
    if filterAdded then return end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then
        filterAdded = true
        pcall(add, "CHAT_MSG_CHANNEL_NOTICE", NoticeFilter)
        pcall(add, "CHAT_MSG_CHANNEL_NOTICE_USER", NoticeFilter)
        pcall(add, "CHAT_MSG_SYSTEM", SystemFilter)
    end
end

local function ChannelID()
    local id = GetChannelName and GetChannelName(DEV_CHANNEL)
    id = tonumber(ns.Plain(id))
    return (id and id > 0) and id or nil
end

local function JoinDev()
    if not DevOn() then return end
    if ChannelID() then return end
    AddFilter()
    local join = JoinTemporaryChannel or JoinChannelByName
    if not join then return end
    pcall(join, DEV_CHANNEL)
    C_Timer.After(2, function()
        local n = NUM_CHAT_WINDOWS or 10
        for i = 1, n do
            local cf = _G["ChatFrame" .. i]
            if cf then
                if ChatFrame_RemoveChannel then pcall(ChatFrame_RemoveChannel, cf, DEV_CHANNEL)
                elseif cf.RemoveChannel then pcall(cf.RemoveChannel, cf, DEV_CHANNEL) end
            end
        end
    end)
end

function Dev.Leave()
    devTarget, devSeen, devAway = nil, nil, true
    wipe(devQ); wipe(devQueued)
    if ChannelID() and LeaveChannelByName then pcall(LeaveChannelByName, DEV_CHANNEL) end
end

local function CollectorHello()
    if not (DevOn() and Dev.IsCollector()) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local id = ChannelID()
    if not id then JoinDev(); return end
    local msg = PROTO .. SEP .. "CH" .. SEP .. tostring(ns.version or "") .. SEP .. NONCE
    MarkSent(msg)
    if pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "CHANNEL", id) then
        helloSent, helloLast = helloSent + 1, GetTime()
    end
end

local function DevNote()
    if not DevOn() or Dev.IsCollector() or ns.db.devNoteShown then return end
    ns.db.devNoteShown = true
    ns:Print(L("dev_note"))
end

ns.SyncDev = Dev
Dev.Build = BuildDump
Dev.Send = DevSendNext
Dev.Join = JoinDev
Dev.Hello = CollectorHello
Dev.State = function() return devTarget, devQ, devQueued end

------------------------------------------------------------------------
-- boot
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns:SafeRegister(frame, "CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
    prefix, msg, channel, sender = ns.Plain(prefix), ns.Plain(msg), ns.Plain(channel), ns.Plain(sender)
    if not (prefix and msg and sender) then return end
    pcall(OnAddonMessage, prefix, msg, channel, sender)
end)

ns:On("LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    end
    C_Timer.NewTicker(SEND_EVERY, SendNext)
    C_Timer.NewTicker(TRICKLE_EVERY, TrickleOne)
    C_Timer.NewTicker(SEND_EVERY, SendRestoreNext)
    for _, d in ipairs(HELLO_DELAYS) do C_Timer.After(d, function() pcall(SayHello) end) end
    C_Timer.NewTicker(DEV_EVERY, function() pcall(DevSendNext) end)
    C_Timer.After(15, function() pcall(JoinDev); pcall(DevNote) end)
    C_Timer.After(25, function() pcall(CollectorHello) end)
    C_Timer.NewTicker(COLLECTOR_HELLO, function() pcall(CollectorHello) end)
    C_Timer.NewTicker(10, function() pcall(CheckDone) end)
end)

function Sync:Toggle()
    ns.db.settings.sync = not ns.db.settings.sync
    if not ns.db.settings.sync then wipe(queue); wipe(queued); pcall(Dev.Leave) end
    return ns.db.settings.sync
end
