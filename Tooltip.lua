-- FarmAtlas - mob tooltips: "drops Chunk of Boar Meat" on hover
local _, ns = ...

local function AddLines(tooltip)
    if not (ns.db and ns.db.settings.tooltip and ns.mobIndex) then return end
    local _, unit = tooltip:GetUnit()
    if not unit or UnitIsPlayer(unit) then return end
    local name = UnitName(unit)
    if not name then return end

    local items = {}
    local seen = {}
    local known = ns.mobIndex[string.lower(name)]
    if known then
        for id in pairs(known) do items[#items + 1] = id; seen[id] = true end
    end
    -- learned drops by NPC id
    local guid = UnitGUID(unit)
    local npcID = guid and ns.NpcFromGUID(guid)
    if npcID then
        for id in pairs(ns.db.learned) do
            if not seen[id] and ns:MobDrops(id, npcID) then
                items[#items + 1] = id
                seen[id] = true
            end
        end
    end
    if #items == 0 then return end

    table.sort(items, function(a, b) return (ns:GetItemName(a)) < (ns:GetItemName(b)) end)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff3fc7ebFarm|r|cffffd200Atlas|r")
    for i = 1, math.min(5, #items) do
        local id = items[i]
        local icon = ns:GetItemIcon(id)
        local mark = ns:IsTracked(id) and ("  |cff3fc7eb" .. ns.L("tracked_tag") .. "|r") or ""
        tooltip:AddLine(("|T%s:14:14:0:0:64:64:5:59:5:59|t %s%s"):format(icon, ns:GetItemColoredName(id), mark))
    end
    tooltip:Show()
end

-- Item tooltips: how many you have everywhere, goal progress, recipes
local function AddItemLines(tooltip)
    if not (ns.db and ns.db.settings.tooltip) then return end
    if not tooltip.GetItem then return end
    local _, link = tooltip:GetItem()
    local key = link and ns:KeyForLink(link)
    if key == nil then return end
    local L = ns.L
    local bags, bank, alts = ns:GetCounts(key)
    tooltip:AddLine(" ")
    tooltip:AddLine("|cff3fc7ebFarm|r|cffffd200Atlas|r")
    tooltip:AddLine(L("tt_have", bags, bank, alts), 1, 1, 1)
    local goal = ns:GetGoal(key)
    if goal then
        local have = ns:GoalHave(key)
        local done = have >= goal.need
        tooltip:AddLine(L("tt_goal", have, goal.need), done and 0.3 or 1, done and 0.9 or 0.62, done and 0.35 or 0.25)
    end
    local recipes = ns:RecipesForItem(key)
    if #recipes > 0 then
        local known = 0
        for _, r in ipairs(recipes) do if ns:RecipeKnown(r) then known = known + 1 end end
        tooltip:AddLine(L("tt_recipes", #recipes, known), 0.55, 0.85, 0.35)
    end
    tooltip:Show()
end

local function Install()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
            if tooltip == GameTooltip or tooltip == ItemRefTooltip then AddItemLines(tooltip) end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetItem", AddItemLines)
        if ItemRefTooltip then ItemRefTooltip:HookScript("OnTooltipSetItem", AddItemLines) end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            if tooltip == GameTooltip then AddLines(tooltip) end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", AddLines)
    end
end

ns:On("LOGIN", Install)
