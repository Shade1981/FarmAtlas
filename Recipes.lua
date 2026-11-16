-- FarmAtlas - recipes: which recipes use an ingredient, which ones you (or your
-- alts) know, and where to learn the rest. Learns automatically from:
--   * your profession window  -> known recipes + their exact reagents
--   * trainers                -> which recipes a trainer teaches, and where
--   * vendors                 -> every "Recipe: ..." item sold, with price and position
--   * loot                    -> recipe items that drop from mobs
local _, ns = ...
local GetItemInfo = ns.GetItemInfo
local GetItemInfoInstant = ns.GetItemInfoInstant

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
local function PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID end
    local x, y = pos:GetXY()
    return mapID, x and x * 100, y and y * 100
end

local function RecipeNameFromItem(name)
    if not name then return end
    -- "Recipe: Roast Raptor" -> "Roast Raptor" (also Pattern:, Plans:, Formula:, Manual:)
    local stripped = name:match("^[^:]+:%s*(.+)$")
    return stripped or name
end

function ns:AddRecipeSource(recipe, src)
    if not recipe or recipe == "" then return end
    local list = self.db.recipeSources[recipe]
    if not list then list = {}; self.db.recipeSources[recipe] = list end
    for _, s in ipairs(list) do
        if s.type == src.type and s.npc == src.npc then
            -- refresh position/price
            for k, v in pairs(src) do s[k] = v end
            return
        end
    end
    list[#list + 1] = src
end

------------------------------------------------------------------------
-- Profession window scan (known recipes + reagents)
------------------------------------------------------------------------
local reported = {}
local function ReportScan(line, count)
    local key = tostring(line) .. ":" .. count
    if reported[line] == key then return end
    reported[line] = key
    ns:Print(ns.L("scan_done", count, tostring(line)))
end

-- Modern profession window (C_TradeSkillUI) - WoW Forever uses this one.
local function ReagentName(itemID)
    if not itemID then return end
    local data = ns.Items[itemID]
    if data then return data.name end
    for key, d in pairs(ns.Items) do
        if type(key) == "string" and ns.db.idAlias[key] == itemID then return d.name end
    end
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID))
        or GetItemInfo(itemID)
    return name
end

local modernRetries = 0
local function ScanTradeSkillModern(isRetry)
    if not isRetry then modernRetries = 0 end
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return false end
    local ids = T.GetAllRecipeIDs()
    if not ids or #ids == 0 then return false end
    local c = ns:CharData()
    local line = "?"
    if T.GetBaseProfessionInfo then
        local info = T.GetBaseProfessionInfo()
        line = info and info.professionName or line
    end
    if line == "?" and GetTradeSkillLine then line = GetTradeSkillLine() or line end
    local changed, missing, count = false, false, 0
    for _, recipeID in ipairs(ids) do
        local info = T.GetRecipeInfo(recipeID)
        if info and info.name and info.learned then
            count = count + 1
            if not c.recipes[info.name] then changed = true end
            c.recipes[info.name] = line
            local schem = T.GetRecipeSchematic and T.GetRecipeSchematic(recipeID, false)
            if schem and schem.reagentSlotSchematics then
                local reagents = {}
                for _, slot in ipairs(schem.reagentSlotSchematics) do
                    local r = slot.reagents and slot.reagents[1]
                    local rname = r and ReagentName(r.itemID)
                    if rname then
                        reagents[rname] = slot.quantityRequired or 1
                    elseif r and r.itemID then
                        missing = true
                        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(r.itemID) end
                    end
                end
                if next(reagents) then ns.db.recipeReagents[info.name] = reagents end
            end
        end
    end
    c.recipesScanned = time()
    ReportScan(line, count)
    if changed then ns:Fire("RECIPES_CHANGED") end
    -- some reagent names were not cached yet: read again shortly
    if missing and modernRetries < 3 then
        modernRetries = modernRetries + 1
        C_Timer.After(2, function() ScanTradeSkillModern(true) end)
    end
    return true
end

local function ScanTradeSkill()
    if ScanTradeSkillModern() then return end
    if not (GetNumTradeSkills and GetTradeSkillInfo) then return end
    local c = ns:CharData()
    local line = GetTradeSkillLine and GetTradeSkillLine() or "?"
    local changed, count = false, 0
    for i = 1, GetNumTradeSkills() do
        local name, kind = GetTradeSkillInfo(i)
        if name and kind ~= "header" and kind ~= "subheader" then
            count = count + 1
            if not c.recipes[name] then changed = true end
            c.recipes[name] = line
            local nr = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0
            if nr > 0 then
                local reagents = {}
                for j = 1, nr do
                    local rname, _, rcount = GetTradeSkillReagentInfo(i, j)
                    if rname then reagents[rname] = rcount or 1 end
                end
                ns.db.recipeReagents[name] = reagents
            end
        end
    end
    c.recipesScanned = time()
    ReportScan(line, count)
    if changed then ns:Fire("RECIPES_CHANGED") end
end

------------------------------------------------------------------------
-- Trainer scan
------------------------------------------------------------------------
local function ScanTrainer()
    if not (GetNumTrainerServices and GetTrainerServiceInfo) then return end
    if IsTradeskillTrainer and not IsTradeskillTrainer() then return end
    local npc = UnitName("npc")
    local mapID, x, y = PlayerPos()
    for i = 1, GetNumTrainerServices() do
        local name, _, category = GetTrainerServiceInfo(i)
        if name and category ~= "header" then
            ns:AddRecipeSource(name, { type = "trainer", npc = npc, mapID = mapID, x = x, y = y,
                faction = UnitFactionGroup("player") })
        end
    end
    ns:Fire("RECIPES_CHANGED")
end

------------------------------------------------------------------------
-- Vendor scan
------------------------------------------------------------------------
local function ScanMerchant()
    if not (GetMerchantNumItems and GetMerchantItemInfo) then return end
    local npc = UnitName("npc")
    local mapID, x, y = PlayerPos()
    local found = false
    for i = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(i)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
            local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
            if classID == 9 then -- Recipe
                local name, _, price = GetMerchantItemInfo(i)
                local recipe = RecipeNameFromItem(name or link:match("%[(.-)%]"))
                ns:AddRecipeSource(recipe, { type = "vendor", npc = npc, mapID = mapID, x = x, y = y,
                    price = price and price > 0 and GetCoinTextureString and GetCoinTextureString(price) or nil,
                    itemID = itemID, faction = UnitFactionGroup("player") })
                found = true
            end
        end
    end
    if found then ns:Fire("RECIPES_CHANGED") end
end

------------------------------------------------------------------------
-- Recipe drops
------------------------------------------------------------------------
local function ScanLootForRecipes()
    local mapID, x, y = PlayerPos()
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID then
            local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
            if classID == 9 then
                local npc = UnitExists("target") and UnitIsDead("target") and UnitName("target") or nil
                ns:AddRecipeSource(RecipeNameFromItem(link:match("%[(.-)%]")),
                    { type = "drop", npc = npc or "?", mapID = mapID, x = x, y = y, itemID = itemID })
            end
        end
    end
end

local f = CreateFrame("Frame")
ns:SafeRegister(f, "TRADE_SKILL_SHOW")
ns:SafeRegister(f, "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "NEW_RECIPE_LEARNED")
ns:SafeRegister(f, "TRAINER_SHOW")
ns:SafeRegister(f, "MERCHANT_SHOW")
ns:SafeRegister(f, "LOOT_OPENED")
local tsPending = false
f:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event:find("^TRADE_SKILL") or event == "NEW_RECIPE_LEARNED" then
        if tsPending then return end
        tsPending = true
        C_Timer.After(0.3, function() tsPending = false; ScanTradeSkill() end)
    elseif event == "TRAINER_SHOW" then
        C_Timer.After(0.2, ScanTrainer)
    elseif event == "MERCHANT_SHOW" then
        C_Timer.After(0.2, ScanMerchant)
    elseif event == "LOOT_OPENED" then
        ScanLootForRecipes()
    end
end)

------------------------------------------------------------------------
-- Queries
------------------------------------------------------------------------

-- All recipes that use an ingredient: built-in "uses" + reagents learned in game
function ns:RecipesForItem(key)
    local out, seen = {}, {}
    local data = self.Items[key]
    if data and data.uses then
        for _, r in ipairs(data.uses) do
            if not seen[r] then seen[r] = true; out[#out + 1] = r end
        end
    end
    local name = self:GetItemName(key)
    for recipe, reagents in pairs(self.db.recipeReagents) do
        if reagents[name] and not seen[recipe] then
            seen[recipe] = true
            out[#out + 1] = recipe
        end
    end
    return out
end

-- Known by this character? and which other characters know it
function ns:RecipeKnown(recipe)
    local me = self:CharKey()
    local mine, alts = false, {}
    for charKey, c in pairs(self.db.chars) do
        if c.recipes and c.recipes[recipe] then
            if charKey == me then mine = true
            else alts[#alts + 1] = charKey:match("%-(.+)$") or charKey end
        end
    end
    return mine, alts
end

function ns:HasScannedRecipes()
    local c = self:CharData()
    return c.recipesScanned ~= nil
end

-- Where to learn: static data + learned sources, filtered to your faction.
-- Returns srcType, list of { npc, zone, mapID, x, y, price, note, learned }
function ns:RecipeSources(recipe)
    local myFaction = UnitFactionGroup("player")
    local short = (myFaction == "Alliance" and "A") or (myFaction == "Horde" and "H") or nil
    local info = self.Recipes[recipe]
    local srcType = info and info.src or nil
    local list, seen = {}, {}

    local function ok(fac)
        if not fac or not short then return true end
        if fac == "Alliance" then fac = "A" elseif fac == "Horde" then fac = "H" end
        return fac == short
    end

    for _, s in ipairs(self.db.recipeSources[recipe] or {}) do
        if ok(s.faction) then
            local zoneKey = s.mapID and self:ZoneKeyForMap(s.mapID)
            local zone = zoneKey and self:ZoneName(zoneKey)
            if not zone and s.mapID and C_Map and C_Map.GetMapInfo then
                local mi = C_Map.GetMapInfo(s.mapID)
                zone = mi and mi.name
            end
            list[#list + 1] = { npc = s.npc, zone = zone, mapID = s.mapID, x = s.x, y = s.y,
                price = s.price, learned = true, type = s.type }
            seen[s.npc or "?"] = true
            srcType = srcType or s.type
        end
    end
    if info and info.where then
        for _, w in ipairs(info.where) do
            if ok(w.faction) and not seen[w.npc] then
                list[#list + 1] = { npc = w.npc, zone = w.zone, x = w.x, y = w.y,
                    price = w.price, note = w.note, type = info.src }
            end
        end
    end
    if (srcType == "trainer") and #list == 0 then
        -- nearest first: trainers in your current zone, then the rest
        local cur
        local m = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local mi = m and C_Map.GetMapInfo(m)
        cur = mi and mi.name
        for pass = 1, 2 do
            for _, t in ipairs(self.Trainers) do
                local here = (t.zone == cur)
                if ok(t.faction) and ((pass == 1) == here) then
                    list[#list + 1] = { npc = t.npc, zone = t.zone, x = t.x, y = t.y, note = t.note, type = "trainer" }
                end
            end
        end
    end
    if info and info.faction and not ok(info.faction) then srcType = "faction" end
    return srcType or "unknown", list, info and info.note
end

------------------------------------------------------------------------
-- Recipe browser ("Recipes" tab)
--   empty search  -> every recipe you know
--   with a search -> recipes whose name OR any ingredient matches
--                    (known + not yet known), with what you can craft now
------------------------------------------------------------------------
local function CountByName(name)
    local key = ns.ItemsByName[string.lower(name)]
    if key ~= nil then
        local bags = ns:GetCounts(key)
        return bags or 0, key
    end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if fn then
        local ok, n = pcall(fn, name)
        if ok and n then return n, nil end
    end
    return 0, nil
end

-- reagent list for a recipe: scanned exact reagents, or built-in "uses" data
local function ReagentsFor(recipe)
    local scanned = ns.db.recipeReagents[recipe]
    if scanned and next(scanned) then return scanned, true end
    local out = {}
    for _, data in pairs(ns.Items) do
        if data.uses then
            for _, r in ipairs(data.uses) do
                if r == recipe then out[data.name] = 0 end -- amount unknown
            end
        end
    end
    return out, false
end

function ns:SearchRecipes(query)
    query = string.lower(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local names, seen = {}, {}
    local function add(r) if r and not seen[r] then seen[r] = true; names[#names + 1] = r end end
    for charKey, c in pairs(self.db.chars) do
        for r in pairs(c.recipes or {}) do add(r) end
    end
    if query ~= "" then
        for r in pairs(self.db.recipeReagents) do add(r) end
        for _, data in pairs(self.Items) do
            for _, r in ipairs(data.uses or {}) do add(r) end
        end
        for r in pairs(self.Recipes or {}) do add(r) end
    end

    local out = {}
    for _, recipe in ipairs(names) do
        local reagents, exact = ReagentsFor(recipe)
        local match = query == "" or string.lower(recipe):find(query, 1, true)
        local list, mainKey, craft = {}, nil, exact and math.huge or nil
        for rname, need in pairs(reagents) do
            if not match and string.lower(rname):find(query, 1, true) then match = true end
            local have, key = CountByName(rname)
            list[#list + 1] = { name = rname, need = need, have = have, key = key }
            if key ~= nil then
                local d = self.Items[key]
                -- prefer the farmable ingredient as the "main" one
                if mainKey == nil or (d and d.spots and #d.spots > 0 and not d.vendor) then mainKey = key end
            end
            if craft and need and need > 0 then craft = math.min(craft, math.floor(have / need)) end
        end
        if match then
            if craft == math.huge then craft = nil end
            table.sort(list, function(a, b) return a.name < b.name end)
            local known, alts = self:RecipeKnown(recipe)
            out[#out + 1] = { name = recipe, known = known, alts = alts, reagents = list,
                exact = exact, craft = craft, mainKey = mainKey }
        end
    end
    table.sort(out, function(a, b)
        if a.known ~= b.known then return a.known end
        local ca, cb = a.craft or 0, b.craft or 0
        if (ca > 0) ~= (cb > 0) then return ca > 0 end
        return a.name < b.name
    end)
    return out
end
