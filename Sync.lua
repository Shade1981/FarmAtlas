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
local _, ns = ...

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

local Sync = {}
ns.Sync = Sync

local VALID_CAT = { cooking = true, skinning = true, fishing = true, learned = true }

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

local function Enqueue(id, msg)
    if #msg > MAX_LEN then return end
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
        if #trickleKeys == 0 then return end
    end
    trickleIndex = trickleIndex + 1
    local key = trickleKeys[trickleIndex]
    if type(key) == "table" then
        for _, src in ipairs(ns.db.recipeSources[key.recipe] or {}) do QueueRecipeSource(key.recipe, src) end
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

local function PlayerBucket(sender)
    local shared = ns.db.shared
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

local function OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or not Enabled() or not sender then return end
    if channel == "GUILD" and not ns.db.settings.syncGuild then return end
    local me = UnitName("player")
    local short = Ambiguate(sender, "none")
    if short == me or sender == me then return end

    -- simple flood protection per sender
    local now = GetTime()
    local r = rate[short]
    if not r or now - r.t > 60 then r = { t = now, n = 0 }; rate[short] = r end
    r.n = r.n + 1
    if r.n > RATE_PER_MIN then return end

    local f = { strsplit(SEP, msg) }
    if f[1] ~= PROTO then return end
    table.remove(f, 1)
    local s = PlayerBucket(short)
    if f[1] == "C" then HandleC(s, f)
    elseif f[1] == "M" then HandleM(s, f)
    elseif f[1] == "K" then HandleK(s, f)
    elseif f[1] == "R" then
        HandleR(s, f)
        if not recipePending then
            recipePending = true
            C_Timer.After(2, function() recipePending = false; ns:Fire("RECIPES_CHANGED") end)
        end
        return
    else return end
    ScheduleRefresh()
end

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
end)

function Sync:Toggle()
    ns.db.settings.sync = not ns.db.settings.sync
    if not ns.db.settings.sync then wipe(queue); wipe(queued) end
    return ns.db.settings.sync
end
