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
            self:Fire("RECIPE_SOURCE_ADDED", recipe, s)
            return
        end
    end
    list[#list + 1] = src
    self:Fire("RECIPE_SOURCE_ADDED", recipe, src)
end

-- NPCs that stand in neutral towns (Booty Bay, Gadgetzan, Everlook...):
-- both factions can buy from them, whoever saw them first.
function ns:IsNeutralNPC(npc)
    if not npc then return false end
    if not self.neutralNPCs then
        local t = {}
        for _, info in pairs(self.Recipes) do
            for _, w in ipairs(info.where or {}) do
                if w.faction == "N" then t[w.npc] = true end
            end
        end
        self.neutralNPCs = t
    end
    return self.neutralNPCs[npc] or false
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
    local profID
    if T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        profID = ok and info and ns.Plain(info.professionID) or nil
        if type(profID) ~= "number" then profID = nil end
    end
    ns.db.recipeIDs = ns.db.recipeIDs or {}
    ns.db.recipeLine = ns.db.recipeLine or {}
    local changed, missing, count = false, false, 0
    local seen = {}
    for _, recipeID in ipairs(ids) do
        local info = T.GetRecipeInfo(recipeID)
        if info and info.name and info.learned then
            count = count + 1
            local schem = T.GetRecipeSchematic and T.GetRecipeSchematic(recipeID, false)
            local out = schem and ns.Plain(schem.outputItemID)
            -- the same recipe on every client language: matched by the item it makes
            local name = (type(out) == "number" and ns:RecipeForItem(out)) or info.name
            info = { name = name, learned = true }
            seen[name] = true
            if not c.recipes[info.name] then changed = true end
            c.recipes[info.name] = line
            -- remembered so a click in FarmAtlas can open the window on this recipe
            if type(ns.Plain(recipeID)) == "number" then ns.db.recipeIDs[info.name] = recipeID end
            if profID then ns.db.recipeLine[info.name] = profID end
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
            -- what the recipe makes (for tooltips of recipes you don't know on other characters)
            if type(out) == "number" and out > 0 then ns:SetRecipeItem(info.name, out) end
        end
    end
    -- a full list of this profession: forget recipes stored under another name
    -- before (e.g. the client language changed)
    if count > 0 and line ~= "?" then
        for r, l in pairs(c.recipes) do
            if l == line and not seen[r] then c.recipes[r] = nil; changed = true end
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
    local npc = ns.Plain(UnitName("npc"))
    local mapID, x, y = PlayerPos()
    if ns.RecordTrainerPos then ns:RecordTrainerPos(npc, mapID, x, y) end
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
    local npc = ns.Plain(UnitName("npc"))
    local mapID, x, y = PlayerPos()
    if ns.RecordTrainerPos and npc and ns.IsGuideNPC and ns:IsGuideNPC(npc) then ns:RecordTrainerPos(npc, mapID, x, y) end
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
                    copper = price and price > 0 and price or nil, itemID = itemID, faction = UnitFactionGroup("player") })
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
                local npc = UnitExists("target") and ns.Plain(UnitIsDead("target")) and ns.Plain(UnitName("target")) or nil
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
local function OnRecipeEvent(_, event)
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
end
f:SetScript("OnEvent", function(...) pcall(OnRecipeEvent, ...) end)

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
-- recipe name -> the item it makes. Learned from your Cooking window and from
-- any item you see (bags, AH, chat links) whose name is a recipe's name.
-- ask the client for the cooked items once, so their tooltips are ready
ns:On("LOGIN", function()
    if not (C_Item and C_Item.RequestLoadItemDataByID and ns.RecipeInfo) then return end
    for _, info in pairs(ns.RecipeInfo) do
        if info.item then pcall(C_Item.RequestLoadItemDataByID, info.item) end
    end
end)

function ns:SetRecipeItem(recipe, itemID)
    if not (self.db and recipe and itemID) then return end
    self.db.recipeOut = self.db.recipeOut or {}
    self.db.recipeOut[recipe] = itemID
end

local recipeNames
function ns:IsRecipeName(name)
    if not recipeNames then
        recipeNames = {}
        for n in pairs(self.Recipes or {}) do recipeNames[n] = true end
        for _, data in pairs(self.Items or {}) do
            for _, n in ipairs(data.uses or {}) do recipeNames[n] = true end
        end
    end
    if recipeNames[name] then return true end
    local rr = self.db and self.db.recipeReagents
    return rr and rr[name] ~= nil or false
end

-- crafted item ID -> FarmAtlas recipe name (English, as in the data)
local itemToRecipe
function ns:RecipeForItem(itemID)
    if not itemToRecipe then
        itemToRecipe = {}
        for name, info in pairs(self.RecipeInfo or {}) do
            if info.item then itemToRecipe[info.item] = name end
        end
    end
    local r = itemToRecipe[itemID]
    if r then return r end
    for name, id in pairs(self.db and self.db.recipeOut or {}) do
        if id == itemID and (self.RecipeInfo and self.RecipeInfo[name] or self.Recipes and self.Recipes[name]) then
            return name
        end
    end
end

-- the name to show for a recipe: English on an English client, the game's
-- own name (= the name of the dish) on any other client
function ns:RecipeLabel(recipe)
    if not (self.localNames and recipe) then return recipe end
    local id = self:RecipeItemID(recipe)
    if not id then return recipe end
    local nm
    if C_Item and C_Item.GetItemNameByID then
        local ok, v = pcall(C_Item.GetItemNameByID, id)
        nm = ok and self.Plain(v)
    end
    if type(nm) ~= "string" or nm == "" then
        local ok, v = pcall(ns.GetItemInfo or GetItemInfo, id)
        nm = ok and self.Plain(v)
    end
    if type(nm) == "string" and nm ~= "" then return nm end
    return recipe
end

-- an ingredient name from the data, the way the game client names it
function ns:MatLabel(name)
    if not (self.localNames and name) then return name end
    local key = self.ItemsByName and self.ItemsByName[string.lower(name)]
    if key ~= nil then return (self:GetItemName(key)) end
    return name
end

function ns:RecipeItemID(recipe)
    local info = self.RecipeInfo and self.RecipeInfo[recipe]
    if info and info.item then return info.item end
    local id = self.db and self.db.recipeOut and self.db.recipeOut[recipe]
    if id then return id end
    -- the client may already know the item by name (it was seen this session)
    local ok, _, link = pcall(ns.GetItemInfo, recipe)
    link = ok and ns.Plain(link)
    local found = type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if found then self:SetRecipeItem(recipe, found) end
    return found
end

-- The full recipe on a tooltip, learned or not: what it makes (the game's own
-- item tooltip once the item is known, else the Well Fed buff from the data),
-- skill colors, reagents with what you have, fire / oven, how to learn it.
function ns:AddRecipeTooltip(tip, recipe, opts)
    local L = self.L
    opts = opts or {}
    local info = self.RecipeInfo and self.RecipeInfo[recipe]
    local made = self:RecipeItemID(recipe)
    if made then
        tip:SetHyperlink("item:" .. made)
        tip:AddLine(" ")
    else
        tip:AddLine(self:RecipeLabel(recipe), 1, 0.82, 0)
    end
    local known = self:RecipeKnown(recipe)
    tip:AddLine(known and L("rc_known") or L("rc_unknown"), known and 0.3 or 1, known and 0.9 or 0.4, known and 0.35 or 0.4)
    if info then
        if not made then
            if info.buff ~= nil then
                tip:AddLine(L("ri_wellfed") .. (info.buff ~= "" and (": " .. info.buff) or "") .. ", " .. L("ri_xp"), 0.3, 0.9, 0.35, true)
            end
            if info.kind then tip:AddLine(info.kind, 0.6, 0.6, 0.6) end
        end
        if info.makes then tip:AddLine(L("ri_makes", info.makes), 1, 1, 1) end
        local s = info.skill or {}
        local parts = {}
        if #s >= 4 then
            parts[#parts + 1] = "|cffff8040" .. s[1] .. "|r"
            parts[#parts + 1] = "|cffffff00" .. s[2] .. "|r"
            parts[#parts + 1] = "|cff40c040" .. s[3] .. "|r"
            parts[#parts + 1] = "|cff808080" .. s[4] .. "|r"
        elseif #s == 3 then
            parts[#parts + 1] = "|cffffff00" .. s[1] .. "|r"
            parts[#parts + 1] = "|cff40c040" .. s[2] .. "|r"
            parts[#parts + 1] = "|cff808080" .. s[3] .. "|r"
        end
        if #parts > 0 then tip:AddDoubleLine(L("ri_skill"), table.concat(parts, "  "), 1, 0.82, 0, 1, 1, 1) end
        tip:AddLine(" ")
        tip:AddLine(L("g_mats"), 1, 0.82, 0)
        for _, m in ipairs(info.mats or {}) do
            local have = 0
            local key = self.ItemsByName[m[1]:lower()]
            if key ~= nil and self.GetCounts then
                local b, k = self:GetCounts(key)
                have = (b or 0) + (k or 0)
            end
            local enough = have >= m[2]
            tip:AddDoubleLine("   " .. m[2] .. "x " .. self:MatLabel(m[1]), have .. " / " .. m[2], 1, 1, 1,
                enough and 0.3 or 1, enough and 0.9 or 0.5, enough and 0.35 or 0.4)
        end
        tip:AddLine(info.oven and L("ri_oven") or L("ri_fire"), 0.6, 0.6, 0.6)
    end
    if not known and not opts.noSources then
        local srcType, sources, note = self:RecipeSources(recipe)
        tip:AddLine(" ")
        tip:AddLine(L("rc_where"), 1, 0.82, 0)
        if info and info.learn == "auto" then
            tip:AddLine(L("ri_auto"), 0.8, 0.8, 0.8, true)
        elseif srcType == "faction" then
            tip:AddLine(L("src_enemy"), 1, 0.5, 0.25, true)
        elseif #sources == 0 then
            tip:AddLine(note or ((info and info.learn == "trainer") and L("g_any_trainer")) or L("src_unknown"), 0.7, 0.7, 0.7, true)
        end
        for i = 1, math.min(4, #sources) do
            local src = sources[i]
            local loc = (self:ZoneLabel(src.zone) or "?") .. ((src.x and src.y) and (" %.1f, %.1f"):format(src.x, src.y) or "")
            if src.note then loc = loc .. " (" .. src.note .. ")" end
            if src.neutral then loc = loc .. " [" .. L("src_neutral") .. "]" end
            tip:AddDoubleLine(src.npc or "?", src.price or "", 1, 1, 1, 1, 0.82, 0)
            tip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
        end
        if #sources > 4 then tip:AddLine(L("more", #sources - 4), 0.55, 0.59, 0.66) end
    end
    if not made then tip:AddLine(L("rc_effect_unknown"), 0.5, 0.5, 0.5, true) end
end

function ns:RecipeKnown(recipe)
    local me = self:CharKey()
    local mine, alts = false, {}
    for charKey, c in pairs(self.db.chars) do
        if c.recipes and c.recipes[recipe] then
            if charKey == me then mine = true
            else alts[#alts + 1] = c.name or charKey:match("%-([^@]+)") or charKey end
        end
    end
    return mine, alts
end

function ns:HasScannedRecipes()
    local c = self:CharData()
    return c.recipesScanned ~= nil
end

-- Where to learn: static data + your own and shared discoveries, filtered
-- to your faction. Neutral-town vendors ("N") count for both factions.
-- Returns srcType, list of { npc, zone, mapID, x, y, price, note, learned,
-- shared, neutral }, note, enemyCount (sources only the other faction has).
local function ShortFaction(fac)
    if fac == "Alliance" then return "A" elseif fac == "Horde" then return "H" end
    return fac
end

function ns:RecipeSources(recipe)
    local short = ShortFaction(UnitFactionGroup("player"))
    if short ~= "A" and short ~= "H" then short = nil end
    local info = self.Recipes[recipe]
    local srcType = info and info.src or nil
    local list, seen = {}, {}
    local enemy = 0

    local function check(fac, npc)
        fac = ShortFaction(fac)
        if fac == "N" or self:IsNeutralNPC(npc) then return true, true end
        if not fac or fac == "" or not short then return true, false end
        if fac == short then return true, false end
        enemy = enemy + 1
        return false, false
    end
    local function zoneOf(mapID)
        local zoneKey = mapID and self:ZoneKeyForMap(mapID)
        local zone = zoneKey and self:ZoneName(zoneKey)
        if not zone and mapID and C_Map and C_Map.GetMapInfo then
            local mi = C_Map.GetMapInfo(mapID)
            zone = mi and mi.name
        end
        return zone
    end
    local function addFound(s, shared)
        local pass, neutral = check(s.faction, s.npc)
        if pass and not seen[s.npc or "?"] then
            list[#list + 1] = { npc = s.npc, zone = zoneOf(s.mapID), mapID = s.mapID, x = s.x, y = s.y,
                price = s.price or (s.copper and GetCoinTextureString and GetCoinTextureString(s.copper)) or nil,
                learned = not shared, shared = shared, neutral = neutral, type = s.type }
            seen[s.npc or "?"] = true
            srcType = srcType or s.type
        end
    end

    for _, s in ipairs(self.db.recipeSources[recipe] or {}) do addFound(s, false) end
    for _, p in pairs(self.db.shared or {}) do
        for _, s in ipairs(p.recipes and p.recipes[recipe] or {}) do addFound(s, true) end
    end
    -- community finds shipped with the addon (Data\Community.lua)
    local cr = ns.Community and ns.Community.recipes
    for _, s in ipairs(cr and cr[recipe] or {}) do addFound(s, true) end
    if info and info.where then
        for _, w in ipairs(info.where) do
            local pass, neutral = check(w.faction, w.npc)
            if pass and not seen[w.npc] then
                list[#list + 1] = { npc = w.npc, zone = w.zone, x = w.x, y = w.y,
                    price = w.price, note = w.note, neutral = neutral, type = info.src }
                seen[w.npc] = true
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
                local okFac = check(t.faction, t.npc)
                if okFac and ((pass == 1) == here) then
                    list[#list + 1] = { npc = t.npc, zone = t.zone, x = t.x, y = t.y, note = t.note, type = "trainer" }
                end
            end
        end
    end
    -- nothing for you, but the other faction can learn it -> say so (AH hint)
    if #list == 0 and enemy > 0 then srcType = "faction" end
    if info and info.faction and short and info.faction ~= "N" and info.faction ~= short and #list == 0 then
        srcType = "faction"
    end
    return srcType or "unknown", list, info and info.note, enemy
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
    local info = ns.RecipeInfo and ns.RecipeInfo[recipe]
    if info and info.mats then
        local t = {}
        for _, m in ipairs(info.mats) do t[m[1]] = m[2] end
        return t, true
    end
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
    query = ns.Lower(query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local names, seen = {}, {}
    local function add(r) if r and not seen[r] then seen[r] = true; names[#names + 1] = r end end
    for charKey, c in pairs(self.db.chars) do
        for r in pairs(c.recipes or {}) do add(r) end
    end
    -- every cooking recipe FarmAtlas knows about, so the unknown ones show (veiled)
    for r in pairs(self.Recipes or {}) do add(r) end
    for r in pairs(self.RecipeInfo or {}) do add(r) end
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
        local match = query == "" or ns.Lower(recipe):find(query, 1, true)
            or (self.localNames and ns.Lower(self:RecipeLabel(recipe)):find(query, 1, true))
        local list, mainKey, craft = {}, nil, exact and math.huge or nil
        for rname, need in pairs(reagents) do
            if not match and ns.Lower(rname):find(query, 1, true) then match = true end
            if not match and self.localNames and ns.Lower(self:MatLabel(rname)):find(query, 1, true) then match = true end
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

------------------------------------------------------------------------
-- Open the profession window on a recipe you know (click in FarmAtlas)
-- Only the game's own C_TradeSkillUI calls are used - no Blizzard frame
-- is touched, so nothing gets tainted.
------------------------------------------------------------------------
local SKILL_LINE = { cooking = 185, fishing = 356, skinning = 393, firstaid = 129,
    leatherworking = 165, tailoring = 197, alchemy = 171, blacksmithing = 164,
    engineering = 202, enchanting = 333, mining = 186, herbalism = 182 }
ns.SKILL_LINE = SKILL_LINE

local function CraftWindowShown()
    for _, name in ipairs({ "ProfessionsFrame", "TradeSkillFrame" }) do
        local fr = _G[name]
        if fr and fr.IsShown then
            local ok, shown = pcall(fr.IsShown, fr)
            if ok and shown then return true end
        end
    end
    return false
end

local PROF_EN = { Cooking = "cooking", Fishing = "fishing", Skinning = "skinning", ["First Aid"] = "firstaid",
    Leatherworking = "leatherworking", Tailoring = "tailoring", Alchemy = "alchemy", Blacksmithing = "blacksmithing",
    Engineering = "engineering", Enchanting = "enchanting", Mining = "mining", Herbalism = "herbalism" }

function ns:RecipeSkillLine(recipe)
    local line = self.db.recipeLine and self.db.recipeLine[recipe]
    if line then return line end
    -- the profession the recipe was read from (its name as the game shows it)
    local c = self:CharData()
    local pname = c and c.recipes and c.recipes[recipe]
    if type(pname) == "string" then
        if GetProfessions and GetProfessionInfo then
            local ok, a, b, cc, d, e, f = pcall(GetProfessions)
            if ok then
                local slots = { a, b, cc, d, e, f }
                for i = 1, 6 do
                    if slots[i] then
                        local ok2, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, slots[i])
                        name, skillLine = ns.Plain(name), ns.Plain(skillLine)
                        if ok2 and name == pname and type(skillLine) == "number" then return skillLine end
                    end
                end
            end
        end
        if PROF_EN[pname] then return SKILL_LINE[PROF_EN[pname]] end
    end
    if (self.RecipeInfo and self.RecipeInfo[recipe]) or (self.Recipes and self.Recipes[recipe]) then
        return SKILL_LINE.cooking
    end
end

-- older profession window (no recipe IDs): pick the recipe in its list
local function SelectInOldWindow(recipe)
    if not (GetNumTradeSkills and GetTradeSkillInfo and SelectTradeSkill) then return end
    local ok, n = pcall(GetNumTradeSkills)
    if not ok or type(n) ~= "number" then return end
    local want = ns:RecipeLabel(recipe)
    for i = 1, n do
        local ok2, name, kind = pcall(GetTradeSkillInfo, i)
        name = ok2 and ns.Plain(name)
        if name and kind ~= "header" and kind ~= "subheader" and (name == recipe or name == want) then
            pcall(SelectTradeSkill, i)
            if TradeSkillFrame_SetSelection then pcall(TradeSkillFrame_SetSelection, i) end
            if TradeSkillFrame_Update then pcall(TradeSkillFrame_Update) end
            return true
        end
    end
end

-- returns true when the game was asked to open the window
function ns:OpenCraft(recipe)
    local L = self.L
    if InCombatLockdown and InCombatLockdown() then
        self:Print(L("craft_combat"))
        return false
    end
    local T = C_TradeSkillUI
    local id = self.db.recipeIDs and self.db.recipeIDs[recipe]
    local line = self:RecipeSkillLine(recipe)
    local asked = false
    if T and id and T.OpenRecipe then
        asked = pcall(T.OpenRecipe, id)
    end
    local triedLine = false
    local function ByLine()
        if triedLine then return false end
        triedLine = true
        if T and line and T.OpenTradeSkill then
            local ok, res = pcall(T.OpenTradeSkill, line)
            return ok and res ~= false
        end
        return false
    end
    if not asked then asked = ByLine() end
    if not asked then
        self:Print(L("craft_manual", self:RecipeLabel(recipe)))
        return false
    end
    -- the window should be up a moment later; if not, try the other way, then say so
    C_Timer.After(0.6, function()
        if CraftWindowShown() then
            if not id then SelectInOldWindow(recipe) end
            return
        end
        if ByLine() then
            C_Timer.After(0.6, function()
                if not CraftWindowShown() then ns:Print(L("craft_manual", ns:RecipeLabel(recipe)))
                elseif not id then SelectInOldWindow(recipe) end
            end)
        else
            ns:Print(L("craft_manual", ns:RecipeLabel(recipe)))
        end
    end)
    return true
end
