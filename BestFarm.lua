-- FarmAtlas - "Best farm now": what is worth the most per hour for YOUR
-- skills and level. value / hour = auction price x items per hour.
--   price: AH Snipe 14-day median (its own saved price history) when it is
--          installed, else the price addons in Prices.lua, else the vendor price
--   items per hour: measured from your own farming (FarmAtlas keeps a running
--          rate per item), else a typical rate for that kind of farm (estimate)
-- Read-only: nothing is scanned, posted or bought here.
local _, ns = ...
local L = ns.L

local BestFarm = {}
ns.BestFarm = BestFarm

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, ROW_H, MAX_ROWS = 400, 44, 12
local SESSION_GAP = 300      -- loots further apart than 5 min = a new farming session
local MIN_MEASURED = 600     -- 10 min of your own farming before a rate counts as measured
local HIST_DAYS = 14

-- typical items per hour when you have not farmed it yet (shown as an estimate)
local EST_RATE = { herbalism = 45, mining = 35, fishing = 90, skinning = 60, cooking = 45 }
local NEED_PROF = { herbalism = true, mining = true, fishing = true, skinning = true }

------------------------------------------------------------------------
-- your own farming rate per item (kept across sessions)
------------------------------------------------------------------------
ns:On("LOOT_RECORDED", function(key, mapID, cellKey, npcID, count)
    if key == nil or not ns.db then return end
    ns.db.farmRate = ns.db.farmRate or {}
    local k = tostring(key)
    local r = ns.db.farmRate[k] or { n = 0, secs = 0 }
    local now = time and time() or 0
    if r.last and now - r.last <= SESSION_GAP then r.secs = r.secs + (now - r.last) end
    r.n = r.n + (count or 1)
    r.last = now
    ns.db.farmRate[k] = r
    if BestFarm.frame and BestFarm.frame:IsShown() then BestFarm:Refresh() end
end)

-- items / hour from your own farming, plus the minutes it is based on
function ns:MeasuredRate(key)
    local r = self.db and self.db.farmRate and self.db.farmRate[tostring(key)]
    if not (r and r.secs and r.secs >= MIN_MEASURED and r.n and r.n > 0) then return nil end
    return r.n / r.secs * 3600, math.floor(r.secs / 60), r.n
end

------------------------------------------------------------------------
-- price
------------------------------------------------------------------------
-- AH Snipe keeps the lowest buyout of every day for 14 days: the median of
-- those days is a steadier price than one snapshot
local function SnipeMedian(itemID)
    local db = rawget(_G, "AHSnipeDB")
    local h = type(db) == "table" and type(db.hist) == "table" and db.hist[itemID]
    if type(h) ~= "table" then return nil end
    local today, vals = math.floor((time and time() or 0) / 86400), {}
    for day, v in pairs(h) do
        if type(day) == "number" and type(v) == "number" and v > 0 and today - day < HIST_DAYS then vals[#vals + 1] = v end
    end
    local n = #vals
    if n == 0 then return nil end
    table.sort(vals)
    local med = (n % 2 == 1) and vals[(n + 1) / 2] or math.floor((vals[n / 2] + vals[n / 2 + 1]) / 2)
    return med, n
end

-- copper, source label
function ns:FarmPrice(key)
    local id = self:RealID(key)
    if type(id) == "number" then
        local ok, med, days = pcall(SnipeMedian, id)
        if ok and med then return med, L("bf_src_hist", days) end
    end
    local v, src = self:GetAHPrice(key)
    if v then return v, src end
    v = self:VendorPrice(key)
    if v then return v, L("bf_src_vendor") end
end

function ns:HasPriceAddon()
    return rawget(_G, "AHSnipe_GetPrice") ~= nil or (Auctionator and Auctionator.API) ~= nil or rawget(_G, "TSM_API") ~= nil
end

------------------------------------------------------------------------
-- what you can farm now
------------------------------------------------------------------------
local function SkinReq(level)
    if level <= 10 then return 1 elseif level <= 20 then return (level - 10) * 10 end
    return level * 5
end

local function SpotOK(cat, sp, skill, plevel)
    local lvl = sp.lvl and tostring(sp.lvl)
    if cat == "herbalism" or cat == "mining" or cat == "fishing" then
        local need = lvl and tonumber(lvl:match("skill%s*(%d+)"))
        return not need or (skill or 0) >= need
    end
    local a = ns:ParseLevels(lvl)
    if not a then return true end
    if a > plevel + 3 then return false end
    if cat == "skinning" then return (skill or 0) >= SkinReq(a) end
    return true
end

-- the ranked list: { key, cat, price, src, rate, measured, minutes, value, zone }
function ns:BestFarms()
    local plevel = (UnitLevel and ns.Plain(UnitLevel("player"))) or 60
    if type(plevel) ~= "number" then plevel = 60 end
    local skills = {}
    for cat in pairs(NEED_PROF) do skills[cat] = self:ProfSkill(cat) end
    local out, noPrice = {}, 0
    for key, data in pairs(self.Items) do
        local cat = data.cat
        if EST_RATE[cat] and data.spots and #data.spots > 0 and (not NEED_PROF[cat] or skills[cat]) then
            local zone
            for _, sp in ipairs(data.spots) do
                if SpotOK(cat, sp, skills[cat], plevel) then zone = sp.z break end
            end
            if zone then
                local price, src = self:FarmPrice(key)
                if price then
                    local rate, minutes = self:MeasuredRate(key)
                    local measured = rate ~= nil
                    rate = rate or EST_RATE[cat]
                    out[#out + 1] = { key = key, cat = cat, price = price, src = src, rate = rate,
                        measured = measured, minutes = minutes, value = price * rate, zone = zone }
                else
                    noPrice = noPrice + 1
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return tostring(a.key) < tostring(b.key)
    end)
    return out, noPrice
end

------------------------------------------------------------------------
-- window
------------------------------------------------------------------------
local function SetBG(f, r, g, b, a, br, bg, bb)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br or 0.165, bg or 0.185, bb or 0.225, 1)
end

local function ZoneName(z)
    local mi = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(z)
    local n = mi and ns.Plain(mi.name)
    if type(n) == "string" then return n end
    local zd = ns.Zones and ns.Zones[z]
    return zd and zd.name or tostring(z)
end

function BestFarm:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "FarmAtlasBestFarmFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(WIDTH, 140)
    f:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    SetBG(f, 0.047, 0.055, 0.070, 0.95, 0.22, 0.25, 0.30)
    f:Hide()
    tinsert(UISpecialFrames, "FarmAtlasBestFarmFrame") -- Esc closes it

    local top = f:CreateTexture(nil, "BORDER")
    top:SetTexture(WHITE)
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(2)
    top:SetVertexColor(1, 0.82, 0)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.t = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.t:SetPoint("CENTER")
    close.t:SetText("X")
    close.t:SetTextColor(0.55, 0.59, 0.66)
    close:SetScript("OnClick", function() f:Hide() end)

    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", 12, -28)
    f.sub:SetPoint("TOPRIGHT", -12, -28)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetTextColor(0.55, 0.59, 0.66)
    f.sub:SetWordWrap(true)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("BOTTOMLEFT", 12, 8)
    f.hint:SetPoint("BOTTOMRIGHT", -12, 8)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetTextColor(0.55, 0.59, 0.66)
    f.hint:SetWordWrap(true)

    self.rows = {}
end

function BestFarm:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    local f = self.frame
    row = CreateFrame("Button", nil, f, "BackdropTemplate")
    row:SetHeight(ROW_H - 4)
    SetBG(row, 0.100, 0.112, 0.136, 1)

    row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.rank:SetPoint("LEFT", 6, 0)
    row.rank:SetWidth(16)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 24, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("TOPRIGHT", -8, -5)
    row.value:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
    row.sub:SetPoint("RIGHT", -8, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.e and ns.UI then ns.UI:Open(nil, self.e.key) end
    end)
    row:SetScript("OnEnter", function(self)
        local e = self.e
        if not e then return end
        self:SetBackdropBorderColor(1, 0.82, 0, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns:GetItemColoredName(e.key))
        GameTooltip:AddDoubleLine(L("bf_value"), L("bf_hour", ns:Money(e.value)), 0.8, 0.8, 0.8, 1, 0.82, 0)
        GameTooltip:AddDoubleLine(L("bf_price_l"), ns:Money(e.price), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine("   " .. tostring(e.src or ""), 0.6, 0.6, 0.6)
        GameTooltip:AddDoubleLine(L("bf_rate_l"), L("bf_rate", math.floor(e.rate + 0.5)), 0.8, 0.8, 0.8, 1, 1, 1)
        if e.measured then
            GameTooltip:AddLine("   " .. L("bf_tip_measured", e.minutes or 0), 0.4, 0.88, 0.44, true)
        else
            GameTooltip:AddLine("   " .. L("bf_tip_est"), 1, 0.62, 0.25, true)
        end
        GameTooltip:AddDoubleLine(L("bf_zone_l"), ZoneName(e.zone), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("bf_tip_click"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.165, 0.185, 0.225, 1)
        GameTooltip:Hide()
    end)
    self.rows[i] = row
    return row
end

function BestFarm:Refresh()
    if not (self.frame and ns.db) then return end
    local f = self.frame
    f.title:SetText("|cffffd200" .. L("bf_title") .. "|r")
    f.sub:SetText(L("bf_sub"))
    local subH = math.max(12, math.floor((f.sub:GetStringHeight() or 12) + 0.5))
    local top = 28 + subH + 8
    local list, noPrice = ns:BestFarms()
    local n = math.min(MAX_ROWS, #list)
    for i = 1, n do
        local e = list[i]
        local row = self:GetRow(i)
        row.e = e
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 8, -top - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", -8, -top - (i - 1) * ROW_H)
        row.rank:SetText(i)
        row.icon:SetTexture(ns:GetItemIcon(e.key))
        row.name:SetText(ns:GetItemColoredName(e.key))
        row.value:SetText(L("bf_hour", ns:Money(e.value)))
        local tag = e.measured and ("|cff66e070" .. L("bf_measured") .. "|r") or ("|cffff9e40" .. L("bf_est") .. "|r")
        row.sub:SetText(ns:Money(e.price) .. "  ·  " .. L("bf_rate", math.floor(e.rate + 0.5)) .. " " .. tag .. "  ·  " .. ZoneName(e.zone))
        row:Show()
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide(); self.rows[i].e = nil end

    local hints = {}
    if n == 0 then hints[#hints + 1] = L("bf_empty") end
    if not ns:HasPriceAddon() then hints[#hints + 1] = L("bf_noaddon") end
    if noPrice > 0 then hints[#hints + 1] = L("bf_noprice", noPrice) end
    hints[#hints + 1] = L("bf_hint")
    f.hint:SetText(table.concat(hints, "\n"))
    local hintH = math.max(14, math.floor((f.hint:GetStringHeight() or 14) + 0.5))
    f:SetHeight(top + n * ROW_H + hintH + 16)
end

function BestFarm:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() return end
    self.frame:Show()
    self:Refresh()
end
