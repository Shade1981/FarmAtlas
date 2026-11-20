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
            if objID and objID ~= 35591 and ns.RecordPool then ns:RecordPool(objID, guid, itemID, mapID, x, y) end
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
-- TEMPORARY fishing diagnostics (dev build only, not released):
-- remembers what the client reports while fishing, so school detection can
-- be fixed for WoW Forever. Stored in db.fishDiag (last 40 lines).
------------------------------------------------------------------------
do
    local P = ns.Plain
    local fishName
    local function Note(line)
        if not ns.db then return end
        ns.db.fishDiag = ns.db.fishDiag or {}
        local t = ns.db.fishDiag
        table.insert(t, date("%H:%M:%S") .. " " .. line)
        while #t > 40 do table.remove(t, 1) end
    end
    local function S(v) v = P(v); return v == nil and "nil" or tostring(v) end
    local function TipLine()
        if not (GameTooltip and GameTooltip:IsShown()) then return "-" end
        local fs = _G.GameTooltipTextLeft1
        return fs and S(fs:GetText()) or "?"
    end
    -- what the tooltip shows when the mouse is on a world object (school?)
    local lastTip
    if GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", function(tip)
            pcall(function()
                local owner = tip:GetOwner()
                local ownerName = owner and owner.GetName and P(owner:GetName()) or "?"
                local fs = _G.GameTooltipTextLeft1
                local txt = fs and S(fs:GetText()) or "?"
                local hasUnit = tip.GetUnit and P((tip:GetUnit())) ~= nil
                if hasUnit then return end
                if ownerName ~= "UIParent" and ownerName ~= "WorldFrame" and ownerName ~= "?" then return end
                local key = txt .. ownerName
                if key == lastTip then return end
                lastTip = key
                local mapID = C_Map.GetBestMapForUnit("player")
                local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
                local x, y = 0, 0
                if pos then x, y = pos:GetXY() end
                Note(("TIP owner=%s text=%s l2=%s map=%s %.1f,%.1f"):format(ownerName, txt,
                    _G.GameTooltipTextLeft2 and S(_G.GameTooltipTextLeft2:GetText()) or "-", tostring(mapID), (x or 0) * 100, (y or 0) * 100))
            end)
        end)
        GameTooltip:HookScript("OnHide", function() lastTip = nil end)
    end
    local d = CreateFrame("Frame")
    ns:SafeRegister(d, "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_CHANNEL_START", "LOOT_READY")
    d:SetScript("OnEvent", function(_, event, ...)
        local ok, err = pcall(function(...)
            if not fishName then
                local gsi = C_Spell and C_Spell.GetSpellName or GetSpellInfo
                fishName = gsi and gsi(7620)
            end
            if event == "LOOT_READY" then
                if not (IsFishingLoot and IsFishingLoot()) then return end
                for slot = 1, GetNumLootItems() do
                    local link = P(GetLootSlotLink(slot))
                    local id = link and tostring(link):match("item:(%d+)")
                    local src = { GetLootSourceInfo(slot) }
                    local parts = {}
                    for i = 1, #src do parts[#parts + 1] = S(src[i]) end
                    Note("LOOT item=" .. tostring(id) .. " src=" .. table.concat(parts, ","))
                end
                return
            end
            local unit, a2, a3, a4 = ...
            if unit ~= "player" then return end
            local spellID = (event == "UNIT_SPELLCAST_SENT") and a4 or a3
            local gsn = C_Spell and C_Spell.GetSpellName or GetSpellInfo
            local name = spellID and gsn and gsn(spellID)
            if not (name and fishName and P(name) == P(fishName)) then return end
            Note(event .. " target=" .. S(event == "UNIT_SPELLCAST_SENT" and a2 or nil)
                .. " tip=" .. TipLine()
                .. " soft=" .. S(UnitName("softinteract")) .. "/" .. S(UnitGUID("softinteract"))
                .. " mo=" .. S(UnitName("mouseover")) .. "/" .. S(UnitGUID("mouseover")))
        end, ...)
        if not ok then Note("ERR " .. tostring(err)) end
    end)
end
