-- loads the real LibProfessionDB (Forever data) + FarmAtlas, then exercises Professions.lua
dofile("/tmp/harness/mock.lua")
GetLocale = GetLocale or function() return "enUS" end
GetBuildInfo = function() return "1.60.1", "70938", "", 16001 end
for line in io.lines("/tmp/pdb/ProfessionDB_Camelot.toc") do
  line = line:gsub("\r",""):gsub("%s+$","")
  if line ~= "" and not line:match("^#") then
    local f = line:gsub("\\","/")
    if not f:match("Data/Forever/%a%a%u%u/") or f:match("enUS") then
      local fn = assert(loadfile("/tmp/pdb/" .. f)); fn("ProfessionDB", {})
    end
  end
end
local E = 0
local function check(c, ...) if not c then E = E + 1; print("ERROR", ...) end end
local ns, first = {}, #MOCK_FRAMES + 1
for line in io.lines("FarmAtlas.toc") do
  if not line:match("^#") and line:match("%.lua%s*$") then
    local f = line:gsub("\\", "/"):gsub("%s+$", ""); assert(loadfile(f))("FarmAtlas", ns)
  end
end
for i = first, #MOCK_FRAMES do local fr = MOCK_FRAMES[i]; if fr.events.ADDON_LOADED and fr.scripts.OnEvent then fr.scripts.OnEvent(fr, "ADDON_LOADED", "FarmAtlas") end end
for i = first, #MOCK_FRAMES do local fr = MOCK_FRAMES[i]; if fr.events.PLAYER_LOGIN and fr.scripts.OnEvent then fr.scripts.OnEvent(fr, "PLAYER_LOGIN") end end
local P = ns.Prof
check(P:Lib(), "lib ready")
local list = P:List(171)
print("alchemy recipes", #list)
check(#list >= 180, "alchemy list size", #list)
local cun
for _, e in ipairs(list) do if e.name == "Elixir of Cunning" then cun = e end end
check(cun and cun.learn == 275 and cun.diff[4] == 285, "Elixir of Cunning tiers")
check(P:Color(cun, 274) == 0 and P:Color(cun, 279) == 1 and P:Color(cun, 281) == 2 and P:Color(cun, 283) == 3 and P:Color(cun, 290) == 4, "colors")
check(math.abs(P:Chance(cun, 282) - 0.6) < 1e-9, "chance", P:Chance(cun, 282))
local lc = P:LearnCost(cun)
print("learn cost", lc and lc.kind, lc and lc.currency, lc and lc.amount, lc and lc.npc)
-- prices: every reagent 1s, vendor vials 4c
ns.GetAHPrice = function(self, id) return 100 end
ns.db.vendorBuy = { [3371] = 4 }
local c, un = P:CraftCost(list[1])
check(c > 0 and not un, "craft cost", c, un)
-- plan 1 -> 300 with every learnable recipe
local plan = P:Plan(171, 1, 300, { unlearned = true })
local gaps = 0
for _, st in ipairs(plan.steps) do
  if st.gap then gaps = gaps + 1; print("GAP", st.from, st.to)
  else print(("%3d-%3d %-34s x%-4d %s%s"):format(st.from, st.to, st.e.name, st.crafts, ns:Money(st.cost), st.learn and (" learn:" .. st.learn.kind) or "")) end
end
check(gaps == 0, "plan has no gap")
check(plan.steps[1].from == 1 and plan.steps[#plan.steps].to == 300, "plan covers range")
print("totals", plan.totals.all, plan.totals.crafts, #plan.mats)
for _, st in ipairs(plan.steps) do check(st.gap or not P.COOLDOWN[st.e.id], "cooldown recipe planned", st.e and st.e.name) end
-- plan with only known recipes and nothing known: a gap
local plan2 = P:Plan(171, 1, 300, {})
check(plan2.steps[1] and plan2.steps[1].gap, "nothing known -> gap")
-- profit
ns.GetAHPrice = function(self, id) if id == cun.out then return 100000 end return 100 end
local pr = P:Profit(171, false)
check(pr[1] and pr[1].e == cun, "profit top", pr[1] and pr[1].e.name)
-- favourites + shopping list
P:ToggleFav(cun); check(P:IsFav(cun) and #P:Favs() == 1, "fav")
P:AddToList(cun, 3); P:AddToList(cun, 2)
local sh = P:Shopping()
check(#sh.recipes == 1 and sh.recipes[1].n == 5, "list count")
local dream for _, m in ipairs(sh.mats) do if m.id == 13463 then dream = m end end
check(dream and dream.need == 15 and dream.missing == 15 - dream.have, "dreamfoil need", dream and dream.need, dream and dream.have, dream and dream.missing)
P:SetListCount(cun.id, 0); check(#P:Shopping().recipes == 0, "remove from list")
-- all professions build
for _, k in ipairs(P.KEYS) do local id = P:ID(k); local l = P:List(id); io.write(k, "=", #l, " ") end print()
print("PROF ERRORS:", E)
