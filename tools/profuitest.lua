local src = io.open("/tmp/proftest.lua"):read("a")
-- reuse the loader part of proftest (up to "local P = ns.Prof")
local loader = src:match("^(.-)local P = ns.Prof")
local env = setmetatable({}, { __index = _G })
local fn = assert(load(loader .. "\nreturn ns, check, function() return E end", "loader", "t", _G))
local ns, check, getE = fn()
local P, UI = ns.Prof, ns.ProfUI
ns.GetAHPrice = function(self, id) return 150 end
-- a scan of Alchemy as the game would give it
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetRecipeInfo = function(id) return { name = "Scanned " .. id, learned = (id == 2329), maxTrivialLevel = 95 } end
C_TradeSkillUI.GetRecipeSchematic = function(id) return { outputItemID = 2454, quantityMin = 1, quantityMax = 1, reagentSlotSchematics = { { required = true, quantityRequired = 2, reagents = { { itemID = 765 } } } } } end
C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionID = 171, skillLevel = 50, maxSkillLevel = 75 } end
P:OnScan(171, { 2329, 999999 })
local e = P:Get(171, 2329)
check(e and e.scanned and e.r[765] == 2 and P:Known(e), "scan merged", e and e.name)
check(P:Get(171, 999999) and P:Get(171, 999999).greyOnly, "scan-only recipe kept")
check(select(1, P:Skill("alchemy")) == 50 or ns:ProfSkill("alchemy"), "skill from scan")
-- window
UI:Toggle()
check(UI.frame and UI.frame:IsShown(), "window shown")
for _, k in ipairs(P.KEYS) do UI:SetProf(k) end
UI:SetProf("alchemy")
for _, t in ipairs({ "recipes", "skillup", "profit", "fav", "list" }) do UI:SetTab(t) end
UI:SetTab("recipes")
local p = UI.pRecipes
check(#p.list.data > 100, "recipe rows", #p.list.data)
p.list.onClick(p.list.data[3])
check(UI.selected == p.list.data[3].e, "select")
UI.pRecipes.detail.add:GetScript("OnClick")()
check(next(ns.db.shopList or {}), "added to list")
p.search:SetText("cunning"); p.search:GetScript("OnTextChanged")(p.search)
check(#p.list.data == 1, "search", #p.list.data)
p.search:SetText("dreamfoil"); p.search:GetScript("OnTextChanged")(p.search)
print("search by reagent rows", #p.list.data)
UI:SetTab("skillup")
check(UI.plan and #UI.plan.steps > 0, "plan built")
UI.pSkill.steps.onClick(UI.pSkill.steps.data[1]); check(#UI.pSkill.mats.data > 0, "step mats")
UI.pSkill.addAll:GetScript("OnClick")()
UI:SetTab("list"); check(#UI.pList.recipes.data > 0 and #UI.pList.mats.data > 0, "list tab")
UI:SetTab("profit")
P:ToggleFav(e); UI:SetTab("fav"); check(#UI.pFav.list.data == 1, "fav tab")
UI.pFav.list.onClick(UI.pFav.list.data[1]); check(UI.tab == "recipes" and UI.selected == e, "fav -> recipe")
-- languages
for _, lg in ipairs({ "hu", "fr", "de", "es", "en" }) do ns.db.settings.lang = lg; ns.db.settings.langChosen = true; UI:Refresh() end
-- without the library
local saveLS = LibStub; LibStub = nil; P:Invalidate(); UI:Refresh()
check(#P:List(171) == 2, "scan-only without lib", #P:List(171))
LibStub = saveLS; P:Invalidate()
print("PROFUI ERRORS:", getE())
