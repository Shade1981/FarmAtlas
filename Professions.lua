-- FarmAtlas - professions: every recipe, skill-up planner, profit list,
-- favourites and a shopping list.
--
-- Where the data comes from:
--   * the game itself: when you open a profession window, every recipe of that
--     profession (known or not) is read with its exact reagents and the skill
--     where it turns grey (C_TradeSkillUI). Stored per account in db.profScan.
--   * LibProfessionDB (optional, MIT, by Pimptasty): learn skill and the
--     orange / yellow / green / grey tiers, recipe sources - built from WoW
--     Forever's own game files. Values it borrowed from Classic are shown as
--     unconfirmed, as its author asks.
--   * prices: the price addons FarmAtlas already reads (Prices.lua) and the
--     vendor prices you have seen at merchants.
-- Read-only: nothing is bought, crafted or posted here.
local _, ns = ...
local L = ns.L

local P = {}
ns.Prof = P

P.KEYS = { "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring",
    "cooking", "firstaid", "mining", "herbalism", "skinning", "fishing" }
P.ICON = {
    alchemy = "Interface\\Icons\\Trade_Alchemy", blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
    enchanting = "Interface\\Icons\\Trade_Engraving", engineering = "Interface\\Icons\\Trade_Engineering",
    leatherworking = "Interface\\Icons\\Trade_LeatherWorking", tailoring = "Interface\\Icons\\Trade_Tailoring",
    cooking = "Interface\\Icons\\INV_Misc_Food_15", firstaid = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
    mining = "Interface\\Icons\\Trade_Mining", herbalism = "Interface\\Icons\\Trade_Herbalism",
    skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", fishing = "Interface\\Icons\\Trade_Fishing",
}
P.AH_CUT = 0.05                 -- the auction house keeps 5% of a sale
P.MERCHANTS_FAVOR = 3402        -- WoW Forever currency for some recipe vendors
-- recipes with a cooldown: never planned for skill-ups. Camp features (all 12
-- professions, 1 hour shared - wow-professions.com camping guide), campfire
-- kits (5 min), transmutes and Mooncloth (daily). IDs: LibProfessionDB Forever.
P.COOLDOWN = {
    [11479]=true, [11480]=true, [17187]=true, [17559]=true, [17560]=true, [17561]=true, [17562]=true, [17563]=true,
    [17564]=true, [17565]=true, [17566]=true, [18560]=true, [25146]=true, [1229432]=true, [1229504]=true, [1229517]=true,
    [1229705]=true, [1229737]=true, [1229745]=true, [1230117]=true, [1230161]=true, [1230171]=true, [1230564]=true, [1230643]=true,
    [1230656]=true, [1262975]=true, [1262978]=true, [1262980]=true, [1262982]=true, [1262985]=true, [1262990]=true, [1262996]=true,
    [1262998]=true, [1263001]=true, [1263005]=true, [1263031]=true, [1263032]=true, [1263034]=true, [1263041]=true, [1263056]=true,
    [1263067]=true, [1263070]=true, [1263071]=true, [1263073]=true, [1263078]=true, [1263079]=true, [1263080]=true, [1263082]=true,
    [1263083]=true, [1263425]=true, [1283400]=true, [1291341]=true, [1317279]=true,
}
local UNPRICED = 1e9            -- a reagent without any price: avoided by the planner

function P:ID(key) return ns.SKILL_LINE and ns.SKILL_LINE[key] end
function P:KeyFor(profID)
    for k, id in pairs(ns.SKILL_LINE or {}) do if id == profID then return k end end
end

-- LibProfessionDB, when installed and loaded for this client
function P:Lib()
    local LS = _G.LibStub
    if not LS then return nil end
    local ok, DB = pcall(LS, "LibProfessionDB-1.0", true)
    if not (ok and DB and DB.IsReady) then return nil end
    local ok2, ready = pcall(DB.IsReady, DB)
    if ok2 and ready then return DB end
end

local function Plain(v) return ns.Plain(v) end
local function Num(v) v = Plain(v); return type(v) == "number" and v or nil end

------------------------------------------------------------------------
-- reading the profession window (called from Recipes.lua's scan)
------------------------------------------------------------------------
local cache = {}                -- [profID] = built recipe list (cleared when data changes)
function P:Invalidate(profID)
    if profID then cache[profID] = nil else wipe(cache) end
    ns:Fire("PROF_CHANGED")
end

local function ReadSchematic(T, id, e)
    if not T.GetRecipeSchematic then return end
    local ok, schem = pcall(T.GetRecipeSchematic, id, false)
    if not (ok and schem) then return end
    local out = Num(schem.outputItemID)
    if out and out > 0 then e.o = out end
    e.q1, e.q2 = Num(schem.quantityMin), Num(schem.quantityMax)
    local r, complete = {}, true
    for _, slot in ipairs(schem.reagentSlotSchematics or {}) do
        local required = Plain(slot.required)
        local first = slot.reagents and slot.reagents[1]
        local itemID = first and Num(first.itemID)
        local qty = Num(slot.quantityRequired) or 1
        if required ~= false and itemID then
            r[itemID] = (r[itemID] or 0) + qty
        elseif required ~= false and not itemID and slot.reagents and #slot.reagents > 0 then
            complete = false
        end
    end
    if complete then e.r = r end
end

function P:OnScan(profID, ids)
    if type(profID) ~= "number" or type(ids) ~= "table" or not ns.db then return end
    local T = C_TradeSkillUI
    if not (T and T.GetRecipeInfo) then return end
    ns.db.profScan = ns.db.profScan or {}
    local store = ns.db.profScan[profID] or {}
    ns.db.profScan[profID] = store
    local learned = {}
    for _, rid in ipairs(ids) do
        local id = Num(rid)
        local ok, info = pcall(T.GetRecipeInfo, rid)
        if id and ok and info then
            local e = store[id] or {}
            local name = Plain(info.name)
            if type(name) == "string" and name ~= "" then e.n = name end
            e.g = Num(info.maxTrivialLevel) or e.g
            if not e.r then ReadSchematic(T, rid, e) end
            store[id] = e
            if Plain(info.learned) then learned[id] = true end
        end
    end
    local c = ns:CharData()
    c.profLearned = c.profLearned or {}
    c.profLearned[profID] = learned
    if T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        if ok and info and Num(info.professionID) == profID then
            c.profSkill = c.profSkill or {}
            c.profSkill[profID] = { Num(info.skillLevel), Num(info.maxSkillLevel), time() }
        end
    end
    self:Invalidate(profID)
end

------------------------------------------------------------------------
-- your skill in a profession (live, else the last one seen)
------------------------------------------------------------------------
function P:Skill(key)
    local cur, max = ns:ProfSkill(key)
    if cur then return cur, max end
    local c = ns:CharData()
    local s = c.profSkill and c.profSkill[self:ID(key)]
    if s then return s[1], s[2] end
end

------------------------------------------------------------------------
-- one recipe list per profession: the library's data + what the game told us
------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        n = ok and Plain(n)
        if type(n) == "string" and n ~= "" then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        n = ok and Plain(n)
        if type(n) == "string" and n ~= "" then return n end
    end
end

function P:List(profID)
    if cache[profID] then return cache[profID] end
    local list, byID = {}, {}
    local DB = self:Lib()
    if DB and DB.HasProfession and DB:HasProfession(profID) then
        local ok, recipes = pcall(DB.GetRecipes, DB, profID)
        for id, r in pairs(ok and recipes or {}) do
            local hidden = DB.IsHiddenRecipe and DB:IsHiddenRecipe(id)
            if not hidden then
                local borrowed = DB.IsBorrowed and DB:IsBorrowed(id, "requiredSkill")
                local e = {
                    id = id, prof = profID, name = r.name, out = r.craftedItemId, item = r.itemId,
                    r = r.reagents, diff = r.difficulty, req = r.requiredSkill, reqBorrowed = borrowed and true or nil,
                    auto = DB.IsAutoTaughtRecipe and DB:IsAutoTaughtRecipe(id) or nil,
                }
                list[#list + 1] = e
                byID[id] = e
            end
        end
    end
    local store = ns.db and ns.db.profScan and ns.db.profScan[profID] or {}
    for id, s in pairs(store) do
        local e = byID[id]
        if not e then
            e = { id = id, prof = profID }
            list[#list + 1] = e
            byID[id] = e
        end
        -- the game's own words win: this client's name, the reagents it asks for
        e.name = s.n or e.name
        if s.r and next(s.r) then e.r = s.r end
        e.out = s.o or e.out
        e.grey = s.g
        e.q1, e.q2 = s.q1, s.q2
        e.scanned = true
    end
    for _, e in ipairs(list) do
        e.name = e.name or SpellName(e.id) or ("#" .. e.id)
        e.r = e.r or {}
        -- tiers without a real learn skill (see LibProfessionDB's README):
        -- shown as unknown, never used as thresholds
        local d = e.diff
        if d and (e.req == nil or e.reqBorrowed) and d[1] == 1 then e.unanchored = true end
        e.learn = (not e.unanchored) and d and d[1] or nil
        if not d and e.grey then e.greyOnly = true end
    end
    table.sort(list, function(a, b)
        local la, lb = a.learn or (a.diff and a.diff[1]) or 999, b.learn or (b.diff and b.diff[1]) or 999
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    list.byID = byID
    cache[profID] = list
    return list
end

function P:Get(profID, id)
    local list = self:List(profID)
    return list.byID[id]
end

-- is it known on this character / on others (by recipe ID, else by name)
function P:Known(e)
    local c = ns:CharData()
    local L1 = c.profLearned and c.profLearned[e.prof]
    if L1 then return L1[e.id] and true or false end
    return c.recipes and c.recipes[e.name] and true or false
end

function P:KnownBy(e)
    local out, me = {}, ns:CharKey()
    for key, c in pairs(ns.db.chars or {}) do
        if key ~= me and type(c) == "table" then
            local L1 = c.profLearned and c.profLearned[e.prof]
            if (L1 and L1[e.id]) or (not L1 and c.recipes and c.recipes[e.name]) then
                out[#out + 1] = c.name or tostring(key):match("%-([^@]+)") or key
            end
        end
    end
    return out
end

-- 0 cannot learn yet, 1 orange, 2 yellow, 3 green, 4 grey, nil unknown
function P:Color(e, skill)
    if not skill then return nil end
    local d = e.diff
    if d and not e.unanchored then
        if skill < d[1] then return 0 elseif skill < d[2] then return 1
        elseif skill < d[3] then return 2 elseif skill < d[4] then return 3 end
        return 4
    end
    local grey = (d and d[4]) or e.grey
    if grey and skill >= grey then return 4 end
end
P.COLORS = { [0] = { 0.85, 0.25, 0.25 }, { 1, 0.5, 0.25 }, { 1, 1, 0 }, { 0.25, 0.75, 0.25 }, { 0.5, 0.5, 0.5 } }

-- chance of a skill point at this skill (the usual player estimate)
function P:Chance(e, skill)
    local d = e.diff
    if not d or e.unanchored then return nil end
    if skill < d[1] then return 0 end
    if skill < d[2] then return 1 end
    if skill >= d[4] then return 0 end
    return (d[4] - skill) / math.max(1, d[4] - d[2])
end

------------------------------------------------------------------------
-- where a recipe comes from
------------------------------------------------------------------------
function P:Sources(e)
    local DB = self:Lib()
    local out = { kinds = {} }
    if e.auto then out.kinds.auto = true end
    if DB and DB.GetRecipeSources then
        local ok, src = pcall(DB.GetRecipeSources, DB, e.id)
        if ok and src then
            for kind, lst in pairs(src) do
                if type(lst) == "table" and #lst > 0 then
                    out.kinds[kind] = true
                    out[kind] = lst
                end
            end
        end
        out.borrowed = DB.IsBorrowed and DB:IsBorrowed(e.id, "sources") and true or nil
    end
    -- what FarmAtlas saw itself at trainers and vendors
    local seen = ns.db and ns.db.recipeSources and ns.db.recipeSources[e.name]
    if seen then out.seen = seen end
    return out
end

-- cost of learning: vendor copper / currency, the recipe on the auction house, trainer (unknown)
function P:LearnCost(e)
    local DB = self:Lib()
    local best
    if DB and DB.GetRecipeSources then
        local ok, src = pcall(DB.GetRecipeSources, DB, e.id)
        local my = UnitFactionGroup and Plain(UnitFactionGroup("player"))
        for _, v in ipairs(ok and src and src.vendor or {}) do
            if not v.faction or v.faction == my then
                for _, part in ipairs(v.cost or {}) do
                    if part.copper then
                        if not best or (best.copper and part.copper < best.copper) then best = { kind = "vendor", copper = part.copper, npc = v.name } end
                    elseif part.currencyID then
                        best = best or { kind = "vendor", currency = part.currencyID, amount = part.amount, npc = v.name }
                    end
                end
                best = best or { kind = "vendor", npc = v.name }
            end
        end
    end
    if not best and e.item then
        local p = ns:GetAHPrice(e.item)
        if p then best = { kind = "ah", copper = p } end
    end
    return best
end

------------------------------------------------------------------------
-- prices: the vendor price you have seen, else the auction house
------------------------------------------------------------------------
local function VendorBuy(itemID)
    local v = ns.db and ns.db.vendorBuy and ns.db.vendorBuy[itemID]
    if v then return v end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetVendorPriceByItemID then
        local ok, p = pcall(api.GetVendorPriceByItemID, "FarmAtlas", itemID)
        p = ok and Num(p)
        if p and p > 0 then return p end
    end
end

-- copper per item, "vendor" / "ah"
function P:Price(itemID)
    local vb = VendorBuy(itemID)
    local ah = ns:GetAHPrice(itemID)
    if vb and (not ah or vb <= ah) then return vb, "vendor" end
    if ah then return ah, "ah" end
end

-- remember what merchants sell (unlimited stock, plain gold) for the reagent prices
local function ScanMerchantPrices()
    if not ns.db then return end
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    ns.db.vendorBuy = ns.db.vendorBuy or {}
    for i = 1, n do
        local price, qty, avail, extended
        local okI, info = pcall(function()
            if C_MerchantFrame and C_MerchantFrame.GetItemInfo then return C_MerchantFrame.GetItemInfo(i) end
        end)
        if okI and type(info) == "table" then
            price, qty, avail, extended = Num(info.price), Num(info.stackCount), Num(info.numAvailable), Plain(info.hasExtendedCost)
        elseif GetMerchantItemInfo then
            local ok, _, _, p, q, a, _, _, ext = pcall(GetMerchantItemInfo, i)
            if ok then price, qty, avail, extended = Num(p), Num(q), Num(a), Plain(ext) end
        end
        local id = GetMerchantItemID and Num(GetMerchantItemID(i))
        if id and price and price > 0 and not extended and (avail == nil or avail < 0) then
            ns.db.vendorBuy[id] = math.floor(price / math.max(1, qty or 1) + 0.5)
        end
    end
end
do
    local f = CreateFrame("Frame")
    ns:SafeRegister(f, "MERCHANT_SHOW")
    f:SetScript("OnEvent", function() C_Timer.After(0.3, function() pcall(ScanMerchantPrices) end) end)
end

-- your own bags + bank
function P:Have(itemID)
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, itemID, true)
        n = ok and Num(n)
        if n then return n end
    end
    if GetItemCount then
        local ok, n = pcall(GetItemCount, itemID, true)
        if ok and Num(n) then return Num(n) end
    end
    return 0
end

-- one craft: cost, any reagent without a price
function P:CraftCost(e, own)
    local total, unpriced = 0, false
    for id, q in pairs(e.r or {}) do
        local use = 0
        if own then use = math.min(q, own[id] or 0) end
        local buy = q - use
        if buy > 0 then
            local p = self:Price(id)
            if p then total = total + p * buy else unpriced = true end
        end
    end
    return total, unpriced
end

-- what one craft sells for on the auction house (after the 5% cut)
function P:SalePrice(e)
    if not e.out then return nil end
    local p = ns:GetAHPrice(e.out)
    if not p then return nil end
    local q = ((e.q1 or 1) + (e.q2 or e.q1 or 1)) / 2
    return math.floor(p * q * (1 - self.AH_CUT))
end

-- can FarmAtlas show where to farm this?
function P:Farmable(itemID)
    if ns.Items and ns.Items[itemID] then return true end
    local le = ns.db and ns.db.learned and ns.db.learned[itemID]
    return le and le.zones and next(le.zones) and true or false
end

------------------------------------------------------------------------
-- skill-up planner: the cheapest recipe for every point, from -> to
--   opts.own        use what is in your bags and bank first (free)
--   opts.unlearned  also plan with recipes you can learn from a trainer or vendor
------------------------------------------------------------------------
function P:Obtainable(e)
    if self:Known(e) then return true, nil end
    if e.auto then return true, nil end
    local src = self:Sources(e)
    if src.kinds.trainer or (src.seen and src.seen[1]) then return true, self:LearnCost(e) end
    if src.kinds.vendor then return true, self:LearnCost(e) end
    if e.item and ns:GetAHPrice(e.item) then return true, { kind = "ah", copper = ns:GetAHPrice(e.item) } end
    return false
end

function P:Plan(profID, from, to, opts)
    opts = opts or {}
    local list = self:List(profID)
    local own = {}
    if opts.own then
        for _, e in ipairs(list) do for id in pairs(e.r) do if own[id] == nil then own[id] = self:Have(id) end end end
    end
    local cands = {}
    for _, e in ipairs(list) do
        if e.diff and not e.unanchored and next(e.r) and e.diff[4] > from and e.diff[1] < to and not self.COOLDOWN[e.id] then
            local known = self:Known(e)
            local ok, learn = true, nil
            if not known then
                if opts.unlearned then ok, learn = self:Obtainable(e) else ok = false end
            end
            if ok then cands[#cands + 1] = { e = e, known = known, learn = learn } end
        end
    end
    local steps, acquired = {}, {}
    local cur
    local s = from
    while s < to do
        local best, bestCost, bestUnpriced
        for _, c in ipairs(cands) do
            local ch = self:Chance(c.e, s)
            if ch and ch > 0 then
                local per, unpriced = self:CraftCost(c.e, opts.own and own or nil)
                if unpriced then per = per + UNPRICED end
                local cost = per / ch
                if not c.known and not acquired[c] and c.learn and c.learn.copper then cost = cost + c.learn.copper end
                if not bestCost or cost < bestCost then best, bestCost, bestUnpriced = c, cost, unpriced end
            end
        end
        if not best then
            steps[#steps + 1] = { gap = true, from = s, to = to }
            break
        end
        local crafts = 1 / self:Chance(best.e, s)
        if not cur or cur.c ~= best then
            cur = { c = best, e = best.e, from = s, to = s, crafts = 0, mats = {}, cost = 0,
                learn = (not best.known and not acquired[best]) and (best.learn or { kind = "trainer" }) or nil }
            steps[#steps + 1] = cur
            acquired[best] = true
        end
        cur.to = s + 1
        cur.crafts = cur.crafts + crafts
        if bestUnpriced then cur.unpriced = true end
        s = s + 1
    end
    -- whole crafts, materials, money; own materials are used up in order
    local totals = { all = 0, ah = 0, vendor = 0, learn = 0, crafts = 0, unpriced = false }
    local mats = {}
    for _, st in ipairs(steps) do
        if not st.gap then
            st.crafts = math.ceil(st.crafts - 1e-9)
            totals.crafts = totals.crafts + st.crafts
            for id, q in pairs(st.e.r) do
                local need = q * st.crafts
                st.mats[id] = need
                local m = mats[id] or { id = id, need = 0, have = self:Have(id) }
                mats[id] = m
                m.need = m.need + need
                local free = 0
                if opts.own then
                    free = math.min(need, own[id] or 0)
                    own[id] = (own[id] or 0) - free
                end
                local buy = need - free
                local p, kind = self:Price(id)
                if buy > 0 then
                    if p then
                        st.cost = st.cost + p * buy
                        totals[kind] = totals[kind] + p * buy
                        m.cost = (m.cost or 0) + p * buy
                    else
                        st.unpriced = true
                        totals.unpriced = true
                    end
                end
                m.price, m.kind = p, kind
            end
            if st.learn and st.learn.copper then totals.learn = totals.learn + st.learn.copper end
            totals.all = totals.all + st.cost
        end
    end
    totals.all = totals.all + totals.learn
    local mlist = {}
    for _, m in pairs(mats) do mlist[#mlist + 1] = m end
    table.sort(mlist, function(a, b) return (a.cost or 0) > (b.cost or 0) end)
    return { steps = steps, totals = totals, mats = mlist, from = from, to = to }
end

------------------------------------------------------------------------
-- profit: what is worth crafting and selling right now
------------------------------------------------------------------------
function P:Profit(profID, knownOnly)
    local out = {}
    for _, e in ipairs(self:List(profID)) do
        if next(e.r) and (not knownOnly or self:Known(e)) then
            local sale = self:SalePrice(e)
            if sale then
                local cost, unpriced = self:CraftCost(e)
                if not unpriced and cost > 0 and math.floor(sale - cost) >= 1 then
                    out[#out + 1] = { e = e, cost = cost, sale = sale, profit = sale - cost,
                        margin = (sale - cost) / cost }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.profit > b.profit end)
    return out
end

------------------------------------------------------------------------
-- favourites and the shopping list (account wide)
------------------------------------------------------------------------
function P:IsFav(e) return ns.db.profFav and ns.db.profFav[e.id] and true or false end
function P:ToggleFav(e)
    ns.db.profFav = ns.db.profFav or {}
    ns.db.profFav[e.id] = (not ns.db.profFav[e.id]) and e.prof or nil
    ns:Fire("PROF_CHANGED")
end
function P:Favs()
    local out = {}
    for id, prof in pairs(ns.db.profFav or {}) do
        local e = type(prof) == "number" and self:Get(prof, id)
        if e then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function P:AddToList(e, n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    ns.db.shopList = ns.db.shopList or {}
    local cur = ns.db.shopList[e.id]
    ns.db.shopList[e.id] = { p = e.prof, n = (cur and cur.n or 0) + n }
    ns:Fire("PROF_CHANGED")
end
function P:AddPlan(plan)
    for _, st in ipairs(plan.steps) do
        if not st.gap and st.crafts > 0 then self:AddToList(st.e, st.crafts) end
    end
end
function P:SetListCount(id, n)
    if not (ns.db.shopList and ns.db.shopList[id]) then return end
    n = math.floor(tonumber(n) or 0)
    if n <= 0 then ns.db.shopList[id] = nil else ns.db.shopList[id].n = n end
    ns:Fire("PROF_CHANGED")
end
function P:ClearList()
    ns.db.shopList = {}
    ns:Fire("PROF_CHANGED")
end

function P:Shopping()
    local recipes, mats = {}, {}
    for id, it in pairs(ns.db.shopList or {}) do
        local e = self:Get(it.p, id)
        if e then
            recipes[#recipes + 1] = { e = e, n = it.n }
            for rid, q in pairs(e.r) do
                local m = mats[rid] or { id = rid, need = 0 }
                mats[rid] = m
                m.need = m.need + q * it.n
            end
        end
    end
    local list, total, unpriced = {}, 0, false
    for _, m in pairs(mats) do
        m.have = self:Have(m.id)
        m.missing = math.max(0, m.need - m.have)
        m.price, m.kind = self:Price(m.id)
        if m.missing > 0 then
            if m.price then m.cost = m.price * m.missing; total = total + m.cost else unpriced = true end
        end
        list[#list + 1] = m
    end
    table.sort(list, function(a, b)
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        return (a.cost or 0) > (b.cost or 0)
    end)
    table.sort(recipes, function(a, b) return a.e.name < b.e.name end)
    return { recipes = recipes, mats = list, total = total, unpriced = unpriced }
end

------------------------------------------------------------------------
-- item names / icons, loaded on demand
------------------------------------------------------------------------
function P:ItemName(id)
    if not id then return "?" end
    local n = C_Item and C_Item.GetItemNameByID and Plain(C_Item.GetItemNameByID(id))
    if type(n) ~= "string" or n == "" then
        n = GetItemInfo and Plain((GetItemInfo(id)))
    end
    if type(n) == "string" and n ~= "" then return n end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return "#" .. id
end
function P:ItemIcon(id)
    if not id then return 134400 end
    local i = C_Item and C_Item.GetItemIconByID and Plain(C_Item.GetItemIconByID(id))
    if not i and GetItemIcon then i = Plain(GetItemIcon(id)) end
    return i or 134400
end

ns:On("RECIPES_CHANGED", function() P:Invalidate() end)
