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
        if UnitExists(unit) and UnitGUID(unit) == guid then return unit end
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
    return "learned"
end
ns.GuessCategory = GuessCategory

local function ShouldRecord(itemID, isFishing, name)
    if ns.Items[itemID] then return true end
    if name and ns.ItemsByName[string.lower(name)] ~= nil then return true end
    if type(itemID) ~= "number" then return false end
    local _, _, _, _, _, classID, subClassID = GetItemInfoInstant(itemID)
    if classID == 7 then
        -- herbs (9) and metal & stone (7) are already covered by GatherMate.
        if subClassID == 9 or subClassID == 7 then return false end
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
            m.name = UnitName(unit) or m.name
            m.lvl = UnitLevel(unit) or m.lvl
            ns.db.npcNames[npcID] = m.name
        else
            m.name = m.name or ns.db.npcNames[npcID]
        end
        entry.mobs[npcID] = m
    end
    return key
end

local frame = CreateFrame("Frame")
ns:SafeRegister(frame, "LOOT_OPENED")
-- NOTE: COMBAT_LOG_EVENT_UNFILTERED is forbidden for addons in the WoW Forever
-- client (registering it triggers "blocked from an action"). Kills are counted
-- from your dead target (if you tagged it) and from every corpse you loot.
if frame.RegisterUnitEvent then
    pcall(frame.RegisterUnitEvent, frame, "UNIT_HEALTH", "target")
end
frame:SetScript("OnEvent", function(_, event)
    if not (ns.db and ns.db.settings.learn) then return end

    if event == "UNIT_HEALTH" then
        -- your target just died and it was tagged by you / your group
        if UnitExists("target") and UnitIsDead("target") and not UnitIsPlayer("target")
            and not (UnitIsTapDenied and UnitIsTapDenied("target")) then
            local guid = UnitGUID("target")
            local npcID = NpcFromGUID(guid)
            if npcID and CountKill(guid, npcID) then
                ns.db.npcNames[npcID] = ns.db.npcNames[npcID] or UnitName("target")
                ns:Fire("KILL_RECORDED", npcID)
            end
        end
        return
    end

    if not (C_Map and C_Map.GetBestMapForUnit) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not x or (x == 0 and y == 0) then return end

    local isFishing = IsFishingLoot and IsFishingLoot() or false
    local changed = {}
    local kills = {}

    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo and GetLootSourceInfo(slot)
        local npcID = NpcFromGUID(guid)
        -- every looted corpse counts as one kill (for the drop rate)
        if npcID and CountKill(guid, npcID) then kills[#kills + 1] = npcID end

        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        local lootName = link and link:match("%[(.-)%]")
        if itemID and ShouldRecord(itemID, isFishing, lootName) then
            local _, _, quantity = GetLootSlotInfo(slot)
            local sessionKey = (guid or ("fish" .. GetTime())) .. ":" .. itemID
            if not seenThisSession[sessionKey] then
                seenThisSession[sessionKey] = true
                local unit = guid and UnitForGUID(guid)
                local key = ns:KeyForLoot(itemID, lootName)
                local cellKey = Record(key, link, quantity, mapID, x, y, npcID, unit, isFishing)
                changed[#changed + 1] = { key = key, mapID = mapID, cell = cellKey, npcID = npcID }
            end
        end
    end

    for _, npcID in ipairs(kills) do ns:Fire("KILL_RECORDED", npcID) end
    for _, c in ipairs(changed) do ns:Fire("LOOT_RECORDED", c.key, c.mapID, c.cell, c.npcID) end
    if #changed > 0 then ns:Fire("LEARNED_CHANGED") end
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
