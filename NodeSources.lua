-- FarmAtlas - exact herb / ore node positions from node addons the player has
-- installed. Nothing is copied into FarmAtlas or sent to other players: the
-- positions are read on this computer, at run time, and only drawn.
--
-- Sources (any that is loaded):
--   QuestieDB  - public API: ObjectDB.Get(objectID, "spawns") -> { [areaID] = { {x, y}, ... } }
--   GatherMate2 - its own node database (what you / your imports have)
--
-- ns:ExternalNodes(itemID) -> { [uiMapID] = { {x, y}, ... } } (x, y in 0-100), or nil
-- ns:ExternalNodeSources() -> list of source names that are active
local _, ns = ...

local cache, cacheAt = {}, {}
local seen
local GM_TTL = 120 -- GatherMate2 grows while you play: re-read every 2 minutes

local function IsNodeItem(itemID)
    local it = ns.Items[itemID]
    local cat = it and it.cat or (ns.db and ns.db.learned[itemID] and ns.db.learned[itemID].cat)
    return cat == "herbalism" or cat == "mining"
end
ns.IsNodeItem = IsNodeItem

local function QuestieOK()
    return type(_G.ObjectDB) == "table" and type(_G.ObjectDB.Get) == "function"
end

local function GatherMateOK()
    local gm = _G.GatherMate2
    return type(gm) == "table" and type(gm.GetNodesForZone) == "function" and type(gm.DecodeLoc) == "function"
end

local function GathererOK()
    local g = _G.Gatherer
    return type(g) == "table" and type(g.Storage) == "table" and type(g.Storage.ZoneGatherNodes) == "function"
        and type(g.Storage.GetGatherInfo) == "function"
end

-- the zones FarmAtlas knows herb / ore nodes in
local zoneList
local function Zones()
    if not zoneList then
        zoneList, seen = {}, {}
        for _, ui in pairs(ns.AREA_TO_UIMAP or {}) do
            if not seen[ui] then seen[ui] = true; zoneList[#zoneList + 1] = ui end
        end
    end
    return zoneList
end

function ns:ExternalNodeSources()
    if ns.db and ns.db.settings.externalNodes == false then return {} end
    local out = {}
    if QuestieOK() then out[#out + 1] = "Questie" end
    if GatherMateOK() then out[#out + 1] = "GatherMate2" end
    if GathererOK() then out[#out + 1] = "Gatherer" end
    return out
end

local function add(out, mapID, x, y)
    if not (mapID and x and y) or x <= 0 or y <= 0 then return end
    local list = out[mapID]
    if not list then list = {}; out[mapID] = list end
    -- the same node from two sources: keep one
    for _, p in ipairs(list) do
        if math.abs(p[1] - x) < 0.4 and math.abs(p[2] - y) < 0.4 then return end
    end
    list[#list + 1] = { x, y }
end

local function FromQuestie(itemID, out)
    local ids = ns.NODE_OBJECTS and ns.NODE_OBJECTS[itemID]
    if not ids then return end
    for _, objID in ipairs(ids) do
        local ok, spawns = pcall(_G.ObjectDB.Get, objID, "spawns")
        if ok and type(spawns) == "table" then
            for areaID, points in pairs(spawns) do
                local mapID = ns.AREA_TO_UIMAP[areaID]
                if mapID and type(points) == "table" then
                    for _, p in ipairs(points) do
                        if type(p) == "table" then add(out, mapID, tonumber(p[1]), tonumber(p[2])) end
                    end
                end
            end
        end
    end
end

-- GatherMate2 keeps nodes by (localized) node name; match it to our item
local function GatherMateItemFor(dbType, nodeID, wantName)
    local gm = _G.GatherMate2
    local ok, name = pcall(gm.GetNameForNode, gm, dbType, nodeID)
    if not ok or type(name) ~= "string" then return false end
    if ns.NODE_NAMES[name] then return ns.NODE_NAMES[name] end
    -- localized clients: herb nodes carry the herb's own name
    return wantName and name == wantName
end

local function FromGatherMate(itemID, out)
    local gm = _G.GatherMate2
    local cat = ns.Items[itemID] and ns.Items[itemID].cat
    if cat == "fishing" then return end -- GatherMate pools are named by pool, not by fish
    local nodeType = (cat == "mining") and "Mining" or "Herb Gathering"
    local localName = ns.localNames and ns:GetItemName(itemID) or nil
    local match = {}
    for _, mapID in ipairs(Zones()) do
        local ok, iter, state, init = pcall(gm.GetNodesForZone, gm, mapID, nodeType, true)
        if ok and type(iter) == "function" then
            for coord, nodeID in iter, state, init do
                local m = match[nodeID]
                if m == nil then
                    local r = GatherMateItemFor(nodeType, nodeID, localName)
                    m = (r == itemID) or (r == true)
                    match[nodeID] = m
                end
                if m then
                    local okD, x, y = pcall(gm.DecodeLoc, gm, coord)
                    if okD and x and y then add(out, mapID, x * 100, y * 100) end
                end
            end
        end
    end
end

-- Gatherer (Reforged) stores nodes by game object ID, like our NODE_OBJECTS
local function FromGatherer(itemID, out)
    local ids = ns.NODE_OBJECTS and ns.NODE_OBJECTS[itemID]
    if not ids then return end
    local cat = ns.Items[itemID] and ns.Items[itemID].cat
    if cat ~= "herbalism" and cat ~= "mining" then return end
    local gType = (cat == "mining") and "MINE" or "HERB"
    local S = _G.Gatherer.Storage
    for _, mapID in ipairs(Zones()) do
        local ok, iter, state, init = pcall(S.ZoneGatherNodes, mapID, gType)
        if ok and type(iter) == "function" then
            for index, x, y in iter, state, init do
                for _, objID in ipairs(ids) do
                    local okI, gx = pcall(S.GetGatherInfo, mapID, objID, gType, index)
                    if okI and gx then add(out, mapID, x * 100, y * 100); break end
                end
            end
        end
    end
end

function ns:ExternalNodes(itemID)
    -- herbs and ore, plus fish that have known pools
    if not IsNodeItem(itemID) and not (ns.NODE_OBJECTS and ns.NODE_OBJECTS[itemID]) then return nil end
    if ns.db and ns.db.settings.externalNodes == false then return nil end
    local useQ, useG, useR = QuestieOK(), GatherMateOK(), GathererOK()
    if not (useQ or useG or useR) then return nil end
    local now = GetTime and GetTime() or 0
    if cache[itemID] and (not (useG or useR) or now - (cacheAt[itemID] or 0) < GM_TTL) then
        return cache[itemID] or nil
    end
    local out = {}
    if useQ then pcall(FromQuestie, itemID, out) end
    if useG then pcall(FromGatherMate, itemID, out) end
    if useR then pcall(FromGatherer, itemID, out) end
    -- the node addon may still be loading its data right after login: an
    -- empty answer is not kept, so the next look asks again
    if next(out) then
        cache[itemID], cacheAt[itemID] = out, now
    elseif ns.db and ns.db.settings then
        ns.extEmptyAt = now
    end
    return out
end

-- true if this zone has exact node positions for the item (then the big
-- built-in area circle is not needed there)
function ns:HasExternalNodes(itemID, mapID)
    local all = self:ExternalNodes(itemID)
    return all and all[mapID] and #all[mapID] > 0 or false
end

-- fishing places (Data\FishWater.lua): one per water, a new one where the catch
-- changes. Returns the list of { mapID, site } that offer this fish.
function ns:FishSitesFor(itemID)
    local out = {}
    for mapID, list in pairs(ns.FISH_SITES or {}) do
        for _, site in ipairs(list) do
            if site.fish[itemID] then out[#out + 1] = { mapID = mapID, site = site } end
        end
    end
    return out
end

-- tooltip of a fishing place: the water, then every fish caught there with its skill
local L = ns.L
function ns:FishSiteTooltip(tip, site)
    tip:AddLine(site.name ~= "" and site.name or L("np_water"), 1, 0.82, 0)
    tip:AddLine(L("np_catch"), 0.55, 0.8, 1)
    local list = {}
    for id, skill in pairs(site.fish) do list[#list + 1] = { id = id, skill = skill } end
    table.sort(list, function(a, b) return a.skill < b.skill end)
    local mySkill = ns.ProfSkill and ns:ProfSkill("fishing")
    for _, f in ipairs(list) do
        local ok = not mySkill or mySkill >= f.skill
        local tracked = ns:IsTracked(f.id)
        local r, g, b = 1, 1, 1
        if tracked then r, g, b = 0.4, 1, 0.4 elseif not ok then r, g, b = 0.6, 0.6, 0.6 end
        tip:AddDoubleLine((tracked and "> " or "   ") .. (ns:GetItemName(f.id) or tostring(f.id)),
            L("np_skill", f.skill), r, g, b, ok and 0.8 or 1, ok and 0.8 or 0.35, ok and 0.8 or 0.35)
    end
end
