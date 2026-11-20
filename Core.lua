-- FarmAtlas - Core
-- Namespace, saved variables, item helpers, search, tracking and events.

local ADDON, ns = ...
_G.FarmAtlas = ns

ns.version = "1.6.0"
ns.Items = {}        -- [itemID] = { name, cat, uses, tags, spots = { {z,x,y,r,mobs,lvl,note}, ... } }
ns.Zones = {}        -- [zoneKey] = { name = "Durotar", id = 1411, min = 1, max = 10 }
ns.callbacks = {}

-- the game client's language: on a non-English client FarmAtlas shows item,
-- recipe and zone names the way the game does (see GetItemName / RecipeLabel)
do
    local ok, loc = pcall(function() return GetLocale and GetLocale() end)
    ns.clientLocale = (ok and type(loc) == "string") and loc or "enUS"
    ns.localNames = not (ns.clientLocale == "enUS" or ns.clientLocale == "enGB")
end

-- Main sections: the icon rail on the left side of the atlas window
ns.SECTIONS = {
    { key = "atlas",   icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "recipes", icon = "Interface\\Icons\\INV_Scroll_03" },
    { key = "guide",   icon = "Interface\\Icons\\INV_Misc_Book_09" },
    { key = "tracked", icon = "Interface\\Icons\\Ability_Hunter_Pathfinding" },
}
-- Profession filters inside the Atlas section (chips above the list)
ns.CATEGORIES = {
    { key = "all",       icon = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "cooking",   icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { key = "skinning",  icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    { key = "fishing",   icon = "Interface\\Icons\\Trade_Fishing" },
    { key = "mining",    icon = "Interface\\Icons\\Trade_Mining" },
    { key = "herbalism", icon = "Interface\\Icons\\Trade_Herbalism" },
}
function ns:SectionOf(cat)
    if cat == "recipes" or cat == "guide" or cat == "tracked" then return cat end
    return "atlas"
end

ns.CAT_COLORS = {
    cooking  = { 1.00, 0.62, 0.25 },
    skinning = { 0.55, 0.85, 0.35 },
    fishing  = { 0.30, 0.70, 1.00 },
    mining   = { 0.80, 0.70, 0.55 },
    herbalism = { 0.45, 0.95, 0.55 },
    leatherworking = { 0.80, 0.55, 0.30 },
    firstaid = { 1.00, 0.40, 0.40 },
    alchemy  = { 0.35, 0.90, 0.85 },
    blacksmithing = { 0.70, 0.72, 0.78 },
    engineering = { 0.95, 0.80, 0.30 },
    learned  = { 0.80, 0.55, 1.00 },
}

-- Colors handed out to tracked items so several can be shown at once.
ns.PALETTE = {
    { 1.00, 0.55, 0.20 }, { 0.25, 0.80, 1.00 }, { 0.45, 0.95, 0.40 },
    { 1.00, 0.35, 0.55 }, { 0.85, 0.60, 1.00 }, { 1.00, 0.88, 0.30 },
    { 0.35, 1.00, 0.85 }, { 1.00, 0.45, 0.30 },
}

local DEFAULTS = {
    tracked = {},           -- [itemID] = colorIndex
    learned = {},           -- see Learn.lua
    npcNames = {},
    idAlias = {},           -- [data key] = real item ID seen in game
    chars = {},             -- per character: bags, bank, known recipes, goals
    recipeSources = {},     -- learned: [recipe] = { list of vendors/trainers/drops }
    recipeReagents = {},
    recipeIDs = {},         -- [recipe] = recipeID (to open the profession window on it)
    recipeLine = {},        -- [recipe] = profession skill line ID
    kills = {},             -- [npcID] = corpses you killed / looted (real drop rates)
    shared = {},            -- data received from party / raid / guild (Sync.lua)    -- learned from the Cooking window: [recipe] = { [reagent] = n }
    settings = {
        lang = "en",
        showOnMap = true,
        showOnContinent = true,
        showOnMinimap = true,   -- farm areas on the minimap
        learn = true,
        tooltip = true,
        areaAlpha = 0.12,
        nodeIconSize = 14,
        nodeHideRange = 15,
        poolAlert = true,
        poolAlertRange = 60,
        minimapAngle = 220,
        hideMinimapButton = false,
        sync = true,        -- share discoveries with party / raid / guild in the background
        syncGuild = true,
        tooltipPrices = true,   -- AH price per item on tooltips
        farmHour = true,        -- value looted in the last 60 minutes
        ownedValue = true,      -- value of everything you own (bags, bank, alts)
        newsPopup = true,       -- "What's new" window after an update
        guideAreas = true,      -- guide step areas on the world map
        guideTrainers = true,   -- current guide step trainers on map / minimap
        ownedOnly = false,      -- list filter: only what is in your bags / craftable now
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

------------------------------------------------------------------------
-- Callbacks (very small event bus)
------------------------------------------------------------------------
function ns:On(event, fn)
    self.callbacks[event] = self.callbacks[event] or {}
    table.insert(self.callbacks[event], fn)
end

function ns:Fire(event, ...)
    local list = self.callbacks[event]
    if not list then return end
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end
    end
end

------------------------------------------------------------------------
-- Data registration (used by Data\*.lua)
------------------------------------------------------------------------
ns.ItemsByName = {}  -- [lower english name] = data key

function ns:AddItems(cat, list)
    for key, data in pairs(list) do
        data.cat = data.cat or cat
        data.id = key
        data.spots = data.spots or {}
        self.Items[key] = data
        if data.name then self.ItemsByName[string.lower(data.name)] = key end
    end
end

-- More areas for items that already exist (Data/Extra.lua). A new spot is
-- skipped when a hand-made spot of the same item already covers that place.
function ns:AddSpots(list)
    for key, spots in pairs(list) do
        local data = self.Items[key]
        if data then
            data.spots = data.spots or {}
            local base = #data.spots
            for _, s in ipairs(spots) do
                local covered = false
                for i = 1, base do
                    local o = data.spots[i]
                    if o.z == s.z then
                        local d = math.sqrt((o.x - s.x) ^ 2 + (o.y - s.y) ^ 2)
                        if d < math.max(o.r or 8, 8) then covered = true; break end
                    end
                end
                if not covered then data.spots[#data.spots + 1] = s end
            end
        end
    end
end

-- Real in-game item ID for a data key (keys can be an English name when the ID
-- was unknown; numeric keys get corrected if the game reports a different ID).
-- Register events safely: some events don't exist in every client build
-- (WoW Forever, Classic Era, ...). Unknown events are silently skipped.
-- API compatibility: newer clients moved item functions into C_Item.
-- Kept addon-local (never as globals, globals would taint Blizzard code).
-- Midnight-era clients hand addons "secret" values (unit tokens, GUIDs,
-- names) in combat / restricted contexts. Using them in tainted code throws,
-- so every unit lookup checks this first.
function ns.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end
function ns.Plain(v)
    if ns.IsSecret(v) then return nil end
    return v
end

ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
ns.GetItemIconByID = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemInfo = ns.GetItemInfo

function ns:SafeRegister(frame, ...)
    for i = 1, select("#", ...) do
        local ev = select(i, ...)
        pcall(frame.RegisterEvent, frame, ev)
    end
end

function ns:RealID(key)
    local alias = self.db and self.db.idAlias[key]
    if alias then return alias end
    if type(key) == "number" then return key end
end

-- Data key for a looted item (links unknown/renamed IDs by English name).
function ns:KeyForLoot(itemID, name)
    if self.Items[itemID] then return itemID end
    local key = name and self.ItemsByName[string.lower(name)]
    if key ~= nil then
        self.db.idAlias[key] = itemID
        return key
    end
    return itemID
end

------------------------------------------------------------------------
-- Zone resolving: our data uses Classic uiMapIDs, but a client may use
-- different IDs (e.g. WoW Forever). We verify by name and fall back to a
-- name lookup over the continents.
------------------------------------------------------------------------
local resolvedZones = {}
local nameToMapID

local function BuildNameIndex()
    nameToMapID = {}
    if not (C_Map and C_Map.GetMapChildrenInfo) then return end
    local roots = { 947, 946, 1414, 1415, 12, 13 }
    for _, root in ipairs(roots) do
        local ok, children = pcall(C_Map.GetMapChildrenInfo, root, nil, true)
        if ok and children then
            for _, info in ipairs(children) do
                if info.name and not nameToMapID[info.name] then
                    nameToMapID[info.name] = info.mapID
                end
            end
        end
    end
end

function ns:ResolveZone(zoneKey)
    if resolvedZones[zoneKey] ~= nil then return resolvedZones[zoneKey] or nil end
    local z = self.Zones[zoneKey]
    if not z then resolvedZones[zoneKey] = false return nil end
    local mapID
    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(z.id)
        if info and info.name == z.name then mapID = z.id end
        if not mapID then
            if not nameToMapID then BuildNameIndex() end
            mapID = nameToMapID[z.name]
        end
        if not mapID and info then mapID = z.id end -- localized client: trust the ID
    end
    resolvedZones[zoneKey] = mapID or false
    return mapID
end

-- English zone name (any zone, also new Forever zones) -> uiMapID
function ns:ResolveZoneName(name)
    if not name then return end
    for key, z in pairs(self.Zones) do
        if z.name == name then return self:ResolveZone(key) end
    end
    if not nameToMapID then BuildNameIndex() end
    if nameToMapID[name] then return nameToMapID[name] end
    -- capitals: classic uiMapIDs as a fallback when the map index misses them
    local CAPITALS = { ["Stormwind City"] = 1453, ["Orgrimmar"] = 1454, ["Ironforge"] = 1455,
        ["Thunder Bluff"] = 1456, ["Darnassus"] = 1457, ["Undercity"] = 1458,
        ["Zephras Isle"] = 2521, ["Riverglades"] = 2548, ["Mount Hyjal"] = 2482, ["Moonglade"] = 1450 }
    return CAPITALS[name]
end

-- Show a single point (vendor, trainer...) on the world map
-- p = { zone = "Tanaris" or mapID = n, x = 0-100, y = 0-100, label = "...", sub = "..." }
function ns:ShowPoint(p)
    local mapID = p.mapID or self:ResolveZoneName(p.zone)
    if not mapID then
        self:Print((p.label or "?") .. " - " .. (p.zone or "?"))
        return
    end
    self.waypoint = p.x and p.y and { mapID = mapID, x = p.x, y = p.y, label = p.label, sub = p.sub } or nil
    self:Fire("TRACKING_CHANGED")
    self:OpenMapID(mapID)
end

-- an English zone name from the data, the way the game client names it
local localZoneCache, localLabelCache = {}, {}
function ns:ZoneLabel(name)
    if not (self.localNames and type(name) == "string") then return name end
    if localLabelCache[name] then return localLabelCache[name] end
    local mapID = self:ResolveZoneName(name)
    if mapID and C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        local nm = ok and info and self.Plain(info.name)
        if type(nm) == "string" and nm ~= "" then localLabelCache[name] = nm; return nm end
    end
    return name
end

function ns:ZoneList(zones)
    local t = {}
    for i, z in ipairs(zones or {}) do t[i] = ns:ZoneLabel(z) or z end
    return table.concat(t, ", ")
end

-- reverse: uiMapID -> our zone key
function ns:ZoneKeyForMap(mapID)
    for key in pairs(self.Zones) do
        if self:ResolveZone(key) == mapID then return key end
    end
end

-- Zone names: English on an English client, the game's own name otherwise.
function ns:ZoneName(zoneKey)
    local z = self.Zones[zoneKey]
    if z and self.localNames and C_Map and C_Map.GetMapInfo then
        local cached = localZoneCache[zoneKey]
        if cached then return cached end
        local mapID = self:ResolveZone(zoneKey)
        local ok, info = pcall(C_Map.GetMapInfo, mapID or z.id)
        local nm = ok and info and self.Plain(info.name)
        if type(nm) == "string" and nm ~= "" then localZoneCache[zoneKey] = nm; return nm end
    end
    if z then return z.name end
    if type(zoneKey) == "number" and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(zoneKey)
        if info and info.name then return info.name end
    end
    return "Zone " .. tostring(zoneKey)
end

------------------------------------------------------------------------
-- Item helpers
------------------------------------------------------------------------
-- GetItemInfo by real ID, or by English name when only the name is known
function ns:ItemInfo(key)
    local id = self:RealID(key)
    if id then return GetItemInfo(id) end
    local data = self.Items[key]
    if data and data.name then return GetItemInfo(data.name) end
end

function ns:GetItemIcon(key)
    local icon
    local id = self:RealID(key)
    if id then
        if C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
        if not icon and ns.GetItemIconByID then icon = ns.GetItemIconByID(id) end
    else
        icon = select(10, self:ItemInfo(key))
    end
    if not icon then
        local l = self.db and self.db.learned[key]
        icon = l and l.icon
    end
    return icon or 134400
end

-- English game client: item names are the English names from the data
-- (exactly as in the recipe book). Any other client language (French,
-- German, Spanish...): the game's own name for the item, so it matches what
-- the player sees in bags, recipes and loot. The English name still works
-- in the search box.
function ns:GetItemName(key)
    local data = self.Items[key]
    local infoName, _, quality = self:ItemInfo(key)
    infoName = self.Plain(infoName)
    if self.localNames and type(infoName) == "string" and infoName ~= "" then
        return infoName, quality or 1
    end
    local name = (data and data.name)
        or (self.db and self.db.learned[key] and self.db.learned[key].name)
        or infoName or ("item:" .. tostring(key))
    return name, quality or 1
end

function ns:GetItemColoredName(itemID)
    local name, quality = self:GetItemName(itemID)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.hex then return color.hex .. name .. "|r" end
    return name
end

function ns:GetCategory(itemID)
    local data = self.Items[itemID]
    if data then return data.cat end
    local l = self.db and self.db.learned[itemID]
    return l and l.cat or "learned"
end

-- Parse "12-17" -> 12, 17
function ns:ParseLevels(lvl)
    if not lvl then return end
    local a, b = tostring(lvl):match("(%d+)%s*%-%s*(%d+)")
    if a then return tonumber(a), tonumber(b) end
    local n = tonumber(tostring(lvl):match("(%d+)"))
    return n, n
end

function ns:LevelColor(lvl)
    local a, b = self:ParseLevels(lvl)
    if not a then return 0.8, 0.8, 0.8 end
    local mid = math.floor((a + b) / 2)
    if GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(mid)
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

------------------------------------------------------------------------
-- Search
------------------------------------------------------------------------
-- string.upper / string.lower only change A-Z: accented letters (á é ö ü ç
-- ñ ä ...) stay as they were, and a word like "Nyúzás" comes out "NYúZáS".
-- These also change the accented Latin letters (UTF-8, 2 bytes).
local function UpAcc(a, b)
    local n = b:byte()
    if a == "\195" and n >= 160 and n <= 190 and n ~= 183 then return a .. string.char(n - 32) end
    if a == "\197" and (n == 145 or n == 177) then return a .. string.char(n - 1) end
    return a .. b
end
local function LowAcc(a, b)
    local n = b:byte()
    if a == "\195" and n >= 128 and n <= 158 and n ~= 151 then return a .. string.char(n + 32) end
    if a == "\197" and (n == 144 or n == 176) then return a .. string.char(n + 1) end
    return a .. b
end
function ns.Upper(s)
    if type(s) ~= "string" then return s end
    return (string.upper(s):gsub("([\195\197])([\128-\191])", UpAcc))
end
function ns.Lower(s)
    if type(s) ~= "string" then return s end
    return (string.lower(s):gsub("([\195\197])([\128-\191])", LowAcc))
end
local function lower(s) return s and ns.Lower(s) or "" end

function ns:AllItemIDs()
    local ids, seen = {}, {}
    for id in pairs(self.Items) do ids[#ids + 1] = id; seen[id] = true end
    if self.db then
        for id in pairs(self.db.learned) do
            if not seen[id] then ids[#ids + 1] = id end
        end
    end
    return ids
end

function ns:ItemMatches(itemID, query)
    if query == "" then return true end
    local data = self.Items[itemID]
    local hay = { lower((self:GetItemName(itemID))) }
    if data then
        hay[#hay + 1] = lower(data.name)
        hay[#hay + 1] = lower(data.tags)
        if data.uses then hay[#hay + 1] = lower(table.concat(data.uses, " ")) end
        for _, s in ipairs(data.spots) do
            hay[#hay + 1] = lower(s.mobs)
            hay[#hay + 1] = lower(self:ZoneName(s.z))
            local z = self.Zones[s.z]
            if z and self.localNames then hay[#hay + 1] = lower(z.name) end
        end
    end
    local l = self.db and self.db.learned[itemID]
    if l and l.mobs then
        for _, m in pairs(l.mobs) do hay[#hay + 1] = lower(m.name) end
    end
    local text = table.concat(hay, " ")
    for word in query:gmatch("%S+") do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

function ns:Search(query, cat)
    query = lower(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local results = {}
    for _, id in ipairs(self:AllItemIDs()) do
        local c = self:GetCategory(id)
        local ok = (cat == "all") or (cat == c)
            or (cat == "tracked" and self:IsTracked(id))
            or (cat == "learned" and self.db.learned[id] ~= nil)
        if ok and self:ItemMatches(id, query) then
            results[#results + 1] = id
        end
    end
    -- in leveling order: lowest farm level first (fishing skill counts as skill / 5)
    local keys = {}
    for _, id in ipairs(results) do keys[id] = self:ItemLevelKey(id) end
    table.sort(results, function(a, b)
        if keys[a] ~= keys[b] then return keys[a] < keys[b] end
        return (self:GetItemName(a)) < (self:GetItemName(b))
    end)
    return results
end

-- lowest mob level (or fishing skill) of an item's farm spots
-- returns lo, hi, isSkill  (nil when unknown)
function ns:ItemLevelRange(id)
    local data = self.Items[id]
    if not data or not data.spots then return nil end
    local lo, hi, skill
    for _, s in ipairs(data.spots) do
        local txt = tostring(s.lvl or "")
        local a, b = self:ParseLevels(txt)
        if a then
            if txt:find("skill") then skill = true end
            if not lo or a < lo then lo = a end
            if not hi or (b or a) > hi then hi = b or a end
        end
    end
    return lo, hi, skill
end

function ns:ItemLevelKey(id)
    local lo, _, skill = self:ItemLevelRange(id)
    if not lo then return 999 end
    if skill then return lo / 5 end
    return lo
end

------------------------------------------------------------------------
-- Tracking
------------------------------------------------------------------------
function ns:IsTracked(itemID)
    return self.db and self.db.tracked[itemID] ~= nil
end

function ns:GetTrackColor(itemID)
    local idx = self.db.tracked[itemID]
    if not idx then
        local c = self.CAT_COLORS[self:GetCategory(itemID)] or self.CAT_COLORS.learned
        return c[1], c[2], c[3]
    end
    local c = self.PALETTE[((idx - 1) % #self.PALETTE) + 1]
    return c[1], c[2], c[3]
end

function ns:SetTracked(itemID, on)
    if on then
        if self.db.tracked[itemID] then return end
        local used = {}
        for _, idx in pairs(self.db.tracked) do used[idx] = true end
        local idx = 1
        while used[idx] do idx = idx + 1 end
        self.db.tracked[itemID] = idx
    else
        self.db.tracked[itemID] = nil
    end
    self:Fire("TRACKING_CHANGED", itemID, on)
end

function ns:ToggleTracked(itemID)
    self:SetTracked(itemID, not self:IsTracked(itemID))
end

function ns:ClearTracked()
    wipe(self.db.tracked)
    self:Fire("TRACKING_CHANGED")
end

function ns:CountTracked()
    local n = 0
    for _ in pairs(self.db.tracked) do n = n + 1 end
    return n
end

-- Open the world map on a zone (optionally tracking an item first).
function ns:ShowOnMap(zoneKey, itemID)
    if itemID and not self:IsTracked(itemID) then self:SetTracked(itemID, true) end
    self:OpenMapID(zoneKey and self:ResolveZone(zoneKey))
end

function ns:OpenMapID(mapID)
    if not WorldMapFrame then return end
    if self.UI and self.UI.frame then self.UI.frame:Hide() end
    if not WorldMapFrame:IsShown() then
        -- opening the map from addon code is blocked during combat
        if InCombatLockdown() then
            if mapID then self.pendingMapID = mapID end
            self:Print(ns.L("c_combat_map"))
            return
        end
        if ToggleWorldMap then ToggleWorldMap() else ShowUIPanel(WorldMapFrame) end
    end
    if mapID and WorldMapFrame:GetMapID() ~= mapID then
        -- switching the map from addon code in combat redraws Blizzard's pins
        -- in a tainted state (blocked SetPassThroughButtons)
        if InCombatLockdown() then
            self:Print(ns.L("c_combat_map"))
            return
        end
        WorldMapFrame:SetMapID(mapID)
    end
end

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3fc7ebFarm|r|cffffd200Atlas|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Mob name -> items index (for tooltips)
------------------------------------------------------------------------
function ns:BuildMobIndex()
    self.mobIndex = {}
    for id, data in pairs(self.Items) do
        for _, s in ipairs(data.spots) do
            if s.mobs then
                for mob in s.mobs:gmatch("[^,/]+") do
                    mob = lower(mob:gsub("^%s+", ""):gsub("%s+$", ""))
                    if mob ~= "" then
                        self.mobIndex[mob] = self.mobIndex[mob] or {}
                        self.mobIndex[mob][id] = true
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns:SafeRegister(frame, "ADDON_LOADED")
function ns:FlushBlocked()
    if not (self.db and self.blockedEarly) then return end
    self.db.blocked = self.db.blocked or {}
    for _, line in ipairs(self.blockedEarly) do table.insert(self.db.blocked, 1, line) end
    wipe(self.blockedEarly)
    while #self.db.blocked > 10 do table.remove(self.db.blocked) end
end

-- Diagnostics: tell the user WHICH protected function was blocked, so it can be fixed.
do
    local diag = CreateFrame("Frame")
    ns:SafeRegister(diag, "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN")
    diag:SetScript("OnEvent", function(_, event, addon, func)
        if addon ~= ADDON then return end
        local line = ("%s %s: %s (v%s, %s%s)"):format(date("%m-%d %H:%M"), event,
            tostring(func), ns.version, InCombatLockdown() and "combat" or "no combat",
            ns.db and "" or ", while loading")
        ns.blockedEarly = ns.blockedEarly or {}
        table.insert(ns.blockedEarly, line)
        if ns.db then ns:FlushBlocked() end
        print(("|cff3fc7ebFarm|r|cffffd200Atlas|r |cffff5555%s|r: %s (v%s) - %s"):format(
            event, tostring(func), ns.version,
            ns.L and ns.L("c_report") or "please send a screenshot of this line"))
    end)
end
ns:SafeRegister(frame, "PLAYER_LOGIN")
ns:SafeRegister(frame, "GET_ITEM_INFO_RECEIVED")

local itemInfoPending = false
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        FarmAtlasDB = FarmAtlasDB or {}
        CopyDefaults(DEFAULTS, FarmAtlasDB)
        ns.db = FarmAtlasDB
        ns:BuildMobIndex()
        ns:Fire("DB_READY")
        ns:FlushBlocked()
    elseif event == "PLAYER_LOGIN" then
        -- warm the item cache so names/qualities are available
        for key in pairs(ns.Items) do
            local id = ns:RealID(key)
            if id then
                if C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                else
                    GetItemInfo(id)
                end
            end
        end
        ns:Fire("LOGIN")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if not itemInfoPending then
            itemInfoPending = true
            C_Timer.After(0.5, function()
                itemInfoPending = false
                ns:Fire("ITEM_INFO")
            end)
        end
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_FARMATLAS1 = "/farm"
SLASH_FARMATLAS2 = "/fatlas"
SLASH_FARMATLAS3 = "/farmatlas"
SlashCmdList.FARMATLAS = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = lower(cmd)
    local L = ns.L
    if cmd == "clear" then
        ns:ClearTracked()
        ns:Print(L("c_cleared"))
    elseif cmd == "pins" then
        ns.db.settings.showOnMap = not ns.db.settings.showOnMap
        ns:Fire("TRACKING_CHANGED")
        ns:Print(ns.db.settings.showOnMap and L("c_pins_on") or L("c_pins_off"))
    elseif cmd == "learn" then
        ns.db.settings.learn = not ns.db.settings.learn
        ns:Print(ns.db.settings.learn and L("c_learn_on") or L("c_learn_off"))
    elseif cmd == "minimap" then
        ns.db.settings.hideMinimapButton = not ns.db.settings.hideMinimapButton
        ns:Fire("MINIMAP_SETTING")
    elseif cmd == "lang" then
        local lang = lower(rest)
        local known = false
        for _, lg in ipairs(ns.LANGS or {}) do if lg.key == lang then known = true end end
        if not known then
            -- no / unknown code: next language in the list
            local cur, list = ns:Lang(), ns.LANGS or { { key = "en" } }
            lang = list[1].key
            for i, lg in ipairs(list) do
                if lg.key == cur then lang = (list[i + 1] or list[1]).key end
            end
        end
        ns:SetLang(lang)
        ns:Print(L("c_lang"))
    elseif cmd == "sync" then
        local on = ns.Sync and ns.Sync:Toggle()
        ns:Print(on and L("c_sync_on") or L("c_sync_off"))
    elseif cmd == "guildsync" then
        ns.db.settings.syncGuild = not ns.db.settings.syncGuild
        ns:Print(ns.db.settings.syncGuild and L("c_gsync_on") or L("c_gsync_off"))
    elseif cmd == "nodes" then
        local src = ns.ExternalNodeSources and ns:ExternalNodeSources() or {}
        ns:Print("node sources: " .. (#src > 0 and table.concat(src, ", ") or "none"))
        if type(_G.ObjectDB) == "table" then
            local ok, sp = pcall(_G.ObjectDB.Get, 1618, "spawns")
            local zones = 0
            if ok and type(sp) == "table" then for _ in pairs(sp) do zones = zones + 1 end end
            ns:Print("Questie Peacebloom node 1618: ok=" .. tostring(ok) .. " type=" .. type(sp) .. " zones=" .. zones)
        end
        local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        for itemID in pairs(ns.db.tracked) do
            local e = ns.ExternalNodes and ns:ExternalNodes(itemID)
            if e then
                local here, all = e[m] and #e[m] or 0, 0
                for _, l in pairs(e) do all = all + #l end
                ns:Print(("%s: %d nodes here, %d total"):format(ns:GetItemName(itemID) or itemID, here, all))
            end
        end
    elseif cmd == "learndebug" then
        ns.learnDebug = not ns.learnDebug
        ns:Print("learn debug: " .. (ns.learnDebug and "ON" or "OFF"))
    elseif cmd == "debug" then
        local list = ns.db.blocked or {}
        if #list == 0 then ns:Print("no blocked actions recorded") end
        for _, line in ipairs(list) do ns:Print(line) end
    elseif cmd == "trainers" then
        local any = false
        for _, p in ipairs(ns.GUIDE_ORDER or {}) do if ns:TrainerPinsOn(p) then any = true end end
        for _, p in ipairs(ns.GUIDE_ORDER or {}) do ns:SetTrainerPins(p, not any) end
        ns:Print(L("g_pins") .. ": " .. (any and L("off") or L("on")))
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        if ns.Options then ns.Options:Toggle() end
    elseif cmd == "banner" then
        if rest == "off" or rest == "on" then
            ns:SetBannerOn(rest == "on")
            ns:Print(L("tb_name") .. ": " .. (rest == "on" and L("on") or L("off")))
        else
            local unlocked = ns:ToggleBannerEdit()
            ns:Print(unlocked and L("tb_unlocked") or L("tb_locked"))
        end
    elseif cmd == "news" then
        if ns.ShowNews then ns:ShowNews() end
    elseif cmd == "goals" then
        if ns.Goals then ns.Goals:Toggle() end
    elseif cmd == "best" then
        if ns.BestFarm then ns.BestFarm:Toggle() end
    elseif cmd == "help" then
        for _, line in ipairs(L("c_help")) do ns:Print(line) end
        ns:Print(L("c_goals"))
        ns:Print(L("c_best"))
    else
        if ns.UI then ns.UI:Open(msg ~= "" and msg or nil) end
    end
end
