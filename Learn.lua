-- FarmAtlas - Learn
-- Records where you actually loot / skin / fish trade goods, so the atlas
-- improves with real WoW Forever data (the built-in data is Classic-based).
-- Also counts kills per NPC so FarmAtlas can show REAL drop rates.
--
-- db.learned[key] = {
--   name, icon, cat, total,
--   zones = { [uiMapID] = { [cellKey] = { x, y, n } } },
--   mobs  = { [npcID] = { name, n, lvl } },
-- }
-- db.kills[npcID] = number of corpses you killed or looted
-- db.shared[player] = { items = { [key] = { zones = .., mobs = .. } }, kills = { [npcID] = n } }
--   (filled in the background by Sync.lua from party / raid / guild members)
-- ns.Community = same shape as one shared player (Data\Community.lua, shipped with releases)
local _, ns = ...
local GetItemInfoInstant = ns.GetItemInfoInstant

local CELL = 2            -- grid size in map percent (2% x 2%)
ns.LEARN_CELL = CELL
local seenThisSession = {} -- avoid double counting when a loot window is reopened
local countedCorpse = {}   -- GUIDs already counted as a kill

local function NpcFromGUID(guid)
    if not guid then return end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" then
        return tonumber(npcID), unitType
    end
    return nil, unitType
end
ns.NpcFromGUID = NpcFromGUID

local function UnitForGUID(guid)
    for _, unit in ipairs({ "target", "mouseover", "focus" }) do
        local g = UnitExists(unit) and ns.Plain(UnitGUID(unit))
        if g and g == guid then return unit end
    end
end

local function GuessCategory(itemID, isFishing)
    local known = ns.Items[itemID]
    if known then return known.cat end
    if isFishing then return "fishing" end
    if type(itemID) ~= "number" then return "learned" end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    -- Trade goods subclasses (modern ids): 6 leather, 8 cooking/meat
    if classID == 7 and subClassID == 6 then return "skinning" end
    if classID == 7 and subClassID == 8 then return "cooking" end
    -- Trade goods: 7 metal & stone (mining), 9 herbs
    if classID == 7 and subClassID == 7 then return "mining" end
    if classID == 7 and subClassID == 9 then return "herbalism" end
    return "learned"
end
ns.GuessCategory = GuessCategory

local function ShouldRecord(itemID, isFishing, name)
    if ns.Items[itemID] then return true end
    if name and ns.ItemsByName[string.lower(name)] ~= nil then return true end
    if type(itemID) ~= "number" then return false end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    if classID == 7 then
        -- leather, meat, fish, herbs (9) and metal & stone (7): ore veins and
        -- herb nodes are learned and shared like everything else
        return true
    end
    if isFishing and classID == 0 then return true end -- raw fish are consumables in some clients
    return false
end
ns.ShouldRecordItem = function(_, itemID, isFishing, name) return ShouldRecord(itemID, isFishing, name) end

function ns:CellKey(px, py)
    return math.floor(px / CELL) .. ":" .. math.floor(py / CELL)
end

local function CountKill(guid, npcID)
    if not (guid and npcID) or countedCorpse[guid] then return false end
    countedCorpse[guid] = true
    ns.db.kills[npcID] = (ns.db.kills[npcID] or 0) + 1
    return true
end

local function Record(itemID, link, count, mapID, x, y, npcID, unit, isFishing)
    local db = ns.db.learned
    local name = link and link:match("%[(.-)%]")
    if ns.Items[itemID] then name = ns.Items[itemID].name end -- keep English data name
    local entry = db[itemID]
    if not entry then
        entry = { zones = {}, mobs = {}, total = 0 }
        db[itemID] = entry
    end
    entry.own = true
    entry.name = name or entry.name
    entry.icon = ns:GetItemIcon(itemID)
    entry.cat = GuessCategory(itemID, isFishing)
    entry.total = (entry.total or 0) + (count or 1)

    local zone = entry.zones[mapID]
    if not zone then zone = {}; entry.zones[mapID] = zone end
    local px, py = x * 100, y * 100
    local key = ns:CellKey(px, py)
    local cell = zone[key]
    if not cell then
        cell = { x = px, y = py, n = 0 }
        zone[key] = cell
    end
    -- running average of the exact positions inside the cell
    cell.x = (cell.x * cell.n + px) / (cell.n + 1)
    cell.y = (cell.y * cell.n + py) / (cell.n + 1)
    cell.n = cell.n + 1

    if npcID then
        local m = entry.mobs[npcID] or { n = 0 }
        m.n = m.n + 1
        if unit then
            m.name = ns.Plain(UnitName(unit)) or m.name
            m.lvl = ns.Plain(UnitLevel(unit)) or m.lvl
            ns.db.npcNames[npcID] = m.name
        else
            m.name = m.name or ns.db.npcNames[npcID]
        end
        entry.mobs[npcID] = m
    end
    return key
end

local frame = CreateFrame("Frame")
-- LOOT_READY comes first: with auto loot the slots can already be empty by
-- LOOT_OPENED (that is why herbs / ore were missed). Both are handled, the
-- per-node key keeps one gather from being counted twice.
ns:SafeRegister(frame, "LOOT_READY")
ns:SafeRegister(frame, "LOOT_OPENED")
ns:SafeRegister(frame, "LOOT_CLOSED")
-- fallback: gathering that never opens a loot window (items go straight to
-- the bags) still prints your own loot line in chat
ns:SafeRegister(frame, "CHAT_MSG_LOOT")
local lootSession = 0
local recentLoot = {} -- [itemID] = GetTime() of the last loot-window record
local recentQty = {}  -- [itemID] = amount counted from that loot window
-- NOTE: COMBAT_LOG_EVENT_UNFILTERED is forbidden for addons in the WoW Forever
-- client (registering it triggers "blocked from an action"). Kills are counted
-- from your dead target (if you tagged it) and from every corpse you loot.
if frame.RegisterUnitEvent then
    pcall(frame.RegisterUnitEvent, frame, "UNIT_HEALTH", "target")
end
local function OnEvent(_, event, ...)
    if not (ns.db and ns.db.settings.learn) then return end

    if event == "UNIT_HEALTH" then
        -- your target just died and it was tagged by you / your group
        if not UnitExists("target") then return end
        if ns.Plain(UnitIsDead("target")) == true and ns.Plain(UnitIsPlayer("target")) == false
            and not (UnitIsTapDenied and ns.Plain(UnitIsTapDenied("target")) ~= false) then
            local guid = ns.Plain(UnitGUID("target"))
            local npcID = NpcFromGUID(guid)
            if npcID and CountKill(guid, npcID) then
                ns.db.npcNames[npcID] = ns.db.npcNames[npcID] or ns.Plain(UnitName("target"))
                ns:Fire("KILL_RECORDED", npcID)
            end
        end
        return
    end

    if event == "LOOT_CLOSED" then lootSession = lootSession + 1; return end

    if not (C_Map and C_Map.GetBestMapForUnit) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return end

    if event == "CHAT_MSG_LOOT" then
        local text, _, _, _, _, _, _, _, _, _, _, guid = ...
        text, guid = ns.Plain(text), ns.Plain(guid)
        if type(text) ~= "string" or not guid or guid ~= ns.Plain(UnitGUID("player")) then return end
        local link = text:match("|c%x+|Hitem:.-|h.-|h|r") or text:match("|Hitem:.-|h.-|h")
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if not itemID then return end
        local lootName = link:match("%[(.-)%]")
        local key = ns:KeyForLoot(itemID, lootName)
        local cat = GuessCategory(key, false)
        if cat ~= "herbalism" and cat ~= "mining" then return end
        if recentLoot[itemID] and GetTime() - recentLoot[itemID] < 5 then
            -- already recorded from the loot window; the chat line has the real stack size
            local count = tonumber(text:match("x(%d+)")) or 1
            local e = ns.db.learned[ns:KeyForLoot(itemID, lootName)]
            local got = recentQty[itemID] or count
            if e and count > got then e.total = (e.total or 0) + (count - got) end
            recentLoot[itemID], recentQty[itemID] = nil, nil
            return
        end
        if not ShouldRecord(itemID, false, lootName) then return end
        local count = tonumber(text:match("x(%d+)")) or 1
        local cellKey = Record(key, link, count, mapID, x, y, nil, nil, false)
        ns:Fire("LOOT_RECORDED", key, mapID, cellKey, nil, count)
        ns:Fire("LEARNED_CHANGED")
        return
    end

    local isFishing = IsFishingLoot and IsFishingLoot() or false
    local changed = {}
    local kills = {}

    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo and ns.Plain(GetLootSourceInfo(slot))
        local npcID = NpcFromGUID(guid)
        -- every looted corpse counts as one kill (for the drop rate)
        if npcID and CountKill(guid, npcID) then kills[#kills + 1] = npcID end

        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        local lootName = link and link:match("%[(.-)%]")
        -- fishing from a school: remember the school's spot (by its game object ID)
        if isFishing and itemID and type(guid) == "string" and guid:find("^GameObject") and mapID and x then
            local objID = tonumber((select(6, strsplit("-", guid))))
            -- 35591 = the fishing bobber itself (open water), not a school
            if objID and objID ~= 35591 and ns.RecordPool then
                ns:RecordPool(objID, guid, itemID, mapID, x, y)
            elseif ns.SchoolKeyForCatch then
                -- WoW Forever reports the bobber as the source even for a school:
                -- the school is known from its tooltip (see SchoolHint below)
                local key = ns:SchoolKeyForCatch(itemID, mapID, x, y)
                if key and ns.RecordPool then ns:RecordPool(key, guid, itemID, mapID, x, y) end
                local obj = ns.FishObjectForCatch and ns:FishObjectForCatch(itemID, mapID, x, y)
                if obj and ns.RecordFishObject then ns:RecordFishObject(obj, guid, itemID, mapID, x, y) end
            end
        end
        if itemID and ShouldRecord(itemID, isFishing, lootName) then
            local _, _, quantity = GetLootSlotInfo(slot)
            local sessionKey = (guid or ("loot" .. lootSession)) .. ":" .. itemID .. ":" .. slot
            if guid then sessionKey = guid .. ":" .. itemID end
            recentLoot[itemID] = GetTime()
            recentQty[itemID] = (type(quantity) == "number" and quantity > 0) and quantity or 1
            if not seenThisSession[sessionKey] then
                seenThisSession[sessionKey] = true
                local unit = guid and UnitForGUID(guid)
                local key = ns:KeyForLoot(itemID, lootName)
                local cellKey = Record(key, link, quantity, mapID, x, y, npcID, unit, isFishing)
                changed[#changed + 1] = { key = key, mapID = mapID, cell = cellKey, npcID = npcID, count = quantity or 1 }
            end
        end
    end

    for _, npcID in ipairs(kills) do ns:Fire("KILL_RECORDED", npcID) end
    for _, c in ipairs(changed) do ns:Fire("LOOT_RECORDED", c.key, c.mapID, c.cell, c.npcID, c.count) end
    if #changed > 0 then ns:Fire("LEARNED_CHANGED") end
end
-- never let a restricted (secret) value break the game UI
frame:SetScript("OnEvent", function(self, event, ...)
    local ok, err = pcall(OnEvent, self, event, ...)
    if ns.learnDebug and event ~= "UNIT_HEALTH" then
        local n = GetNumLootItems and GetNumLootItems() or "?"
        local info = ""
        if event ~= "CHAT_MSG_LOOT" and type(n) == "number" then
            for slot = 1, n do
                local okL, link = pcall(GetLootSlotLink, slot)
                local okS, src = pcall(GetLootSourceInfo, slot)
                info = info .. " [" .. slot .. "] " .. tostring(okL and (issecretvalue and issecretvalue(link) and "SECRET" or link) or "ERR")
                    .. " src=" .. tostring(okS and (issecretvalue and issecretvalue(src) and "SECRET" or src) or "ERR")
            end
        else
            local text = ...
            info = " text=" .. tostring(issecretvalue and issecretvalue(text) and "SECRET" or text)
                .. " guid=" .. tostring(select(12, ...))
        end
        local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        ns:Print(("%s ok=%s err=%s learn=%s map=%s items=%s%s"):format(event, tostring(ok), tostring(err),
            tostring(ns.db and ns.db.settings.learn), tostring(m), tostring(n), info))
    end
end)

-- data recorded by older versions belongs to you
ns:On("DB_READY", function()
    for _, e in pairs(ns.db.learned) do
        if (e.total or 0) > 0 then e.own = true end
    end
    -- community items you have never seen yet become searchable too
    for key, c in pairs(ns.Community and ns.Community.items or {}) do
        if not ns.Items[key] and not ns.db.learned[key] then
            ns.db.learned[key] = {
                zones = {}, mobs = {}, total = 0, cat = c.cat or "learned",
                name = c.name or (type(key) == "string" and key or nil),
            }
        end
    end
end)

------------------------------------------------------------------------
-- Combined view: your data + party/raid/guild data + community release
------------------------------------------------------------------------
local function Sources()
    local list = {}
    if ns.db then
        list[#list + 1] = { items = ns.db.learned, kills = ns.db.kills, own = true }
        for _, s in pairs(ns.db.shared or {}) do
            list[#list + 1] = { items = s.items or {}, kills = s.kills or {} }
        end
    end
    if ns.Community then
        list[#list + 1] = { items = ns.Community.items or {}, kills = ns.Community.kills or {} }
    end
    return list
end

-- Returns a sorted array of { mapID, n, own, cells = {...} } for an item.
function ns:GetLearnedZones(itemID)
    local merged = {}
    for _, src in ipairs(Sources()) do
        local entry = src.items[itemID]
        if entry and entry.zones then
            for mapID, cells in pairs(entry.zones) do
                local z = merged[mapID]
                if not z then z = { mapID = mapID, n = 0, map = {} }; merged[mapID] = z end
                if src.own then z.own = true end
                for ck, c in pairs(cells) do
                    local m = z.map[ck]
                    if not m then
                        m = { x = c.x, y = c.y, n = 0 }
                        z.map[ck] = m
                    else
                        local tot = m.n + c.n
                        if tot > 0 then
                            m.x = (m.x * m.n + c.x * c.n) / tot
                            m.y = (m.y * m.n + c.y * c.n) / tot
                        end
                    end
                    m.n = m.n + (c.n or 0)
                    z.n = z.n + (c.n or 0)
                end
            end
        end
    end
    local out = {}
    for _, z in pairs(merged) do
        z.cells = {}
        for _, c in pairs(z.map) do z.cells[#z.cells + 1] = c end
        z.map = nil
        out[#out + 1] = z
    end
    table.sort(out, function(a, b) return a.n > b.n end)
    return out
end

local function KillsFor(npcID)
    local k = 0
    for _, src in ipairs(Sources()) do k = k + (src.kills[npcID] or 0) end
    return k
end

-- { id, name, n (drops), kills, rate (0..1 or nil), lvl }
function ns:GetLearnedMobs(itemID)
    local merged = {}
    for _, src in ipairs(Sources()) do
        local entry = src.items[itemID]
        if entry and entry.mobs then
            for npcID, m in pairs(entry.mobs) do
                local o = merged[npcID]
                if not o then o = { id = npcID, n = 0 }; merged[npcID] = o end
                o.n = o.n + (m.n or 0)
                o.name = o.name or m.name
                o.lvl = o.lvl or m.lvl
            end
        end
    end
    local out = {}
    for npcID, o in pairs(merged) do
        o.name = o.name or self.db.npcNames[npcID] or ("NPC " .. npcID)
        o.kills = KillsFor(npcID)
        if o.kills >= 5 and o.kills >= o.n then o.rate = o.n / o.kills end
        out[#out + 1] = o
    end
    table.sort(out, function(a, b)
        if (a.rate or -1) ~= (b.rate or -1) then return (a.rate or -1) > (b.rate or -1) end
        return a.n > b.n
    end)
    return out
end

-- Does anybody's data say this NPC drops the item?
function ns:MobDrops(itemID, npcID)
    for _, src in ipairs(Sources()) do
        local e = src.items[itemID]
        if e and e.mobs and e.mobs[npcID] then return true end
    end
    return false
end

-- How many players have shared data with you (for the status line)
function ns:CountSharers()
    local n = 0
    for _ in pairs(self.db.shared or {}) do n = n + 1 end
    return n
end

function ns:CountLearned()
    local items, spots = 0, 0
    for _, e in pairs(self.db.learned) do
        if e.zones and next(e.zones) then items = items + 1 end
        for _, cells in pairs(e.zones or {}) do
            for _ in pairs(cells) do spots = spots + 1 end
        end
    end
    return items, spots
end

function ns:ForgetLearned(itemID)
    if itemID then self.db.learned[itemID] = nil else wipe(self.db.learned); wipe(self.db.kills) end
    self:Fire("LEARNED_CHANGED")
end

------------------------------------------------------------------------
-- Fishing schools in WoW Forever: the client gives the bobber as the loot
-- source even when you fish a school, so the school is recognised from its
-- tooltip instead. When the mouse is on a school ("Oily Blackmouth School")
-- the world tooltip shows its name; if it names a fish, that spot is a school
-- for the next catches nearby (the hint is renewed by every school catch, so
-- you do not have to keep the mouse on it).
------------------------------------------------------------------------
do
    local HINT_TIME = 45      -- seconds a hint stays valid after the last school catch / hover
    local HINT_DIST = 1.5     -- map percent you may move away from where the hint was made
    local hint                -- { t, mapID, x, y } (x, y in percent)
    local fishWords           -- { lower-case word } from the names of the fishing items
    local nodeWords           -- { [word] = true } from herb / ore names (world objects too)
    -- fishable objects that are not fish schools (enUS client words); any other
    -- language is still caught when the mouse is on the object while you cast
    local OBJECT_WORDS = { wreckage = true, debris = true, spill = true, flotsam = true,
        driftwood = true, floating = true }

    local function SplitWords(name)
        local out = {}
        for w in name:gmatch("[^%s%-%(%)]+") do out[#out + 1] = w:lower() end
        return out
    end

    -- one distinctive word per fishing item: its longest word that is not also
    -- in the name of a herb / ore (those are world objects with tooltips too):
    -- "Raw Mithril Head Trout" -> "trout", not "mithril" (Mithril Deposit)
    local function Words()
        if fishWords then return fishWords end
        local fish, other, ready = {}, {}, true
        for id, it in pairs(ns.Items or {}) do
            local name = ns.GetItemInfo and ns.Plain(ns.GetItemInfo(id))
            if type(name) ~= "string" then
                if it.cat == "fishing" then ready = false end
            elseif it.cat == "fishing" then
                fish[#fish + 1] = SplitWords(name)
            elseif it.cat == "herbalism" or it.cat == "mining" then
                for _, w in ipairs(SplitWords(name)) do other[w] = true end
            end
        end
        local list = {}
        for _, words in ipairs(fish) do
            table.sort(words, function(a, b) return #a > #b end)
            for _, w in ipairs(words) do
                if #w >= 4 and not other[w] then list[#list + 1] = w; break end
            end
        end
        if ready then fishWords = list; nodeWords = other end   -- names not cached yet: try again later
        return list, other
    end

    local function NamesAFish(text)
        if type(text) ~= "string" or text == "" then return false end
        -- whole words only: "Fishing Bobber" must not match "fish"
        local inText = {}
        for _, w in ipairs(SplitWords(text)) do inText[w] = true end
        for _, w in ipairs(Words()) do
            if inText[w] then return true end
        end
        return false
    end

    local function PlayerPos()
        if not (C_Map and C_Map.GetBestMapForUnit) then return end
        local mapID = C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        if not pos then return end
        local x, y = pos:GetXY()
        if not x or (x == 0 and y == 0) then return end
        return mapID, x * 100, y * 100
    end

    -- the tooltip of a world object (no unit) that names a fish = a school
    local bobberName
    local function IsObjectName(text, atCast)
        if type(text) ~= "string" or text == "" or text == bobberName then return false end
        local _, other = Words()
        local words = SplitWords(text)
        for _, w in ipairs(words) do
            if (nodeWords or other)[w] then return false end   -- a herb / ore node
        end
        if atCast then return true end                          -- mouse on it while casting
        for _, w in ipairs(words) do
            if OBJECT_WORDS[w] then return true end
        end
        return false
    end

    -- the tooltip of a world object (no unit): a fish school, or another fishable object
    local function CheckTooltip(atCast)
        if not (GameTooltip and GameTooltip:IsShown()) then return end
        local owner = GameTooltip:GetOwner()
        if owner ~= UIParent and owner ~= WorldFrame then return end
        if GameTooltip.GetUnit and ns.Plain((GameTooltip:GetUnit())) ~= nil then return end
        local fs = _G.GameTooltipTextLeft1
        local text = fs and ns.Plain(fs:GetText())
        local kind
        if NamesAFish(text) then kind = "school"
        elseif IsObjectName(text, atCast) then kind = "object" end
        if not kind then return end
        local mapID, x, y = PlayerPos()
        if mapID then hint = { t = GetTime(), mapID = mapID, x = x, y = y, kind = kind, name = text } end
    end

    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", function() pcall(CheckTooltip) end)
    end

    -- the mouse may already rest on the school when the cast starts
    local fishSpell
    local cf = CreateFrame("Frame")
    ns:SafeRegister(cf, "UNIT_SPELLCAST_SENT")
    cf:SetScript("OnEvent", function(_, _, unit, _, _, spellID)
        if unit ~= "player" then return end
        pcall(function()
            local gsn = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
            if not gsn then return end
            fishSpell = fishSpell or ns.Plain(gsn(7620))
            local name = spellID and ns.Plain(gsn(spellID))
            if name and fishSpell and name == fishSpell then
                local soft = ns.Plain(UnitName("softinteract"))
                if type(soft) == "string" and soft ~= "" and not bobberName then
                    local g = ns.Plain(UnitGUID("softinteract"))
                    if type(g) == "string" and g:find("%-35591%-") then bobberName = soft end
                end
                CheckTooltip(true)
            end
        end)
    end)

    -- the hint still valid for a catch here? (renews it)
    local function LiveHint(mapID, x, y)
        if not hint or not mapID or not x then return end
        if GetTime() - hint.t > HINT_TIME or hint.mapID ~= mapID then hint = nil; return end
        local px, py = x * 100, y * 100
        if math.abs(px - hint.x) > HINT_DIST or math.abs(py - hint.y) > HINT_DIST then hint = nil; return end
        hint.t = GetTime()                                    -- still fishing the same spot
        return hint
    end

    -- key of the school a catch came from, or nil (open water)
    function ns:SchoolKeyForCatch(itemID, mapID, x, y)
        if not itemID or not hint or hint.kind == "object" then return end
        if not LiveHint(mapID, x, y) then return end
        local it = ns.Items and ns.Items[itemID]
        if not (it and it.cat == "fishing") then return end   -- trunks, junk
        local ids = ns.NODE_OBJECTS and ns.NODE_OBJECTS[itemID]
        return (ids and ids[1]) or (9000000 + itemID)
    end

    -- name of the fishable object (wreckage, debris...) a catch came from, or nil
    function ns:FishObjectForCatch(itemID, mapID, x, y)
        if not itemID or not hint or hint.kind ~= "object" then return end
        local h = LiveHint(mapID, x, y)
        return h and h.name
    end

    -- test hook
    ns.SchoolHintState = function() return hint end
    ns.SchoolWords = function() return Words() end
end

