-- FarmAtlas - professions window: Recipes / Skill-up / Profit / Favourites / Shopping list
-- Logic and data: Professions.lua. Only reads and shows; the "Open" button asks
-- the game to open its own profession window (same as the Recipes tab).
local _, ns = ...
local L = ns.L
local P = ns.Prof

local UI = {}
ns.ProfUI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local C = {
    bg      = { 0.047, 0.055, 0.070, 0.97 },
    panel   = { 0.078, 0.088, 0.108, 1 },
    card    = { 0.100, 0.112, 0.136, 1 },
    hover   = { 0.130, 0.146, 0.176, 1 },
    border  = { 0.165, 0.185, 0.225, 1 },
    accent  = { 0.247, 0.780, 0.922, 1 },
    gold    = { 1.000, 0.820, 0.000, 1 },
    text    = { 0.92, 0.94, 0.97 },
    muted   = { 0.55, 0.59, 0.66 },
    green   = { 0.35, 0.85, 0.35 },
    red     = { 0.95, 0.35, 0.35 },
}
local W, H = 980, 600
local LEFT_W = 176
local ROW = 22

------------------------------------------------------------------------
-- widgets
------------------------------------------------------------------------
local function SetBG(f, color, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(color or C.panel))
    f:SetBackdropBorderColor(unpack(border or C.border))
end

local function Font(parent, size, r, g, b, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    if size then
        local path, _, flags = fs:GetFont()
        if path then fs:SetFont(path, size, flags) end
    end
    if r then fs:SetTextColor(r, g, b) else fs:SetTextColor(unpack(C.text)) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Button(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 90, h or 22)
    SetBG(b, C.card)
    b.text = Font(b, 11)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label or "")
    function b:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(C.accent[1] * 0.35, C.accent[2] * 0.35, C.accent[3] * 0.35, 1)
            self:SetBackdropBorderColor(unpack(C.accent))
        else
            self:SetBackdropColor(unpack(C.card))
            self:SetBackdropBorderColor(unpack(C.border))
        end
    end
    function b:Fit(minW)
        self:SetWidth(math.max(minW or 40, math.floor((self.text:GetStringWidth() or 0) + 20)))
    end
    b:SetScript("OnEnter", function(self)
        if not self.active then self:SetBackdropColor(unpack(C.hover)) end
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.active then self:SetBackdropColor(unpack(C.card)) end
        GameTooltip:Hide()
    end)
    return b
end

local function Check(parent, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT")
    SetBG(b.box, C.card)
    b.mark = b.box:CreateTexture(nil, "ARTWORK")
    b.mark:SetTexture(WHITE)
    b.mark:SetPoint("TOPLEFT", 3, -3)
    b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    b.mark:SetVertexColor(unpack(C.accent))
    b.text = Font(b, 11, unpack(C.muted))
    b.text:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
    function b:Update(label)
        if label then self.text:SetText(label) end
        self.mark:SetShown(get() and true or false)
        self:SetWidth((self.text:GetStringWidth() or 0) + 26)
    end
    b:SetScript("OnClick", function(self) set(not get()); self:Update() end)
    return b
end

local function Icon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

local function Money(c)
    if not c then return "|cff8c96a8-|r" end
    return ns:Money(c)
end

-- a list with a fixed number of rows over any amount of data (mouse wheel)
local function List(parent, rows, rowH, build, fill)
    local f = CreateFrame("Frame", nil, parent)
    f.rows, f.data, f.offset = {}, {}, 0
    f.rowH = rowH
    for i = 1, rows do
        local r = CreateFrame("Button", nil, f, "BackdropTemplate")
        r:SetHeight(rowH - 2)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
        r:SetPoint("TOPRIGHT", -6, -(i - 1) * rowH)
        SetBG(r, C.card)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(C.hover))
            if f.onEnter and self.item then f.onEnter(self, self.item) end
        end)
        r:SetScript("OnLeave", function(self)
            if self.selected then self:SetBackdropColor(C.accent[1] * 0.25, C.accent[2] * 0.25, C.accent[3] * 0.25, 1)
            else self:SetBackdropColor(unpack(C.card)) end
            GameTooltip:Hide()
        end)
        r:SetScript("OnClick", function(self, btn) if f.onClick and self.item then f.onClick(self.item, btn, self) end end)
        build(r)
        f.rows[i] = r
    end
    f.thumb = f:CreateTexture(nil, "OVERLAY")
    f.thumb:SetTexture(WHITE)
    f.thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
    f.thumb:SetWidth(3)
    function f:Refresh()
        local n = #self.data
        local maxOff = math.max(0, n - #self.rows)
        if self.offset > maxOff then self.offset = maxOff end
        for i, r in ipairs(self.rows) do
            local item = self.data[i + self.offset]
            r.item = item
            if item then
                r.selected = (self.selected ~= nil and self.selected == item.key)
                if r.selected then r:SetBackdropColor(C.accent[1] * 0.25, C.accent[2] * 0.25, C.accent[3] * 0.25, 1)
                else r:SetBackdropColor(unpack(C.card)) end
                fill(r, item)
                r:Show()
            else
                r:Hide()
            end
        end
        if n > #self.rows then
            local hgt = #self.rows * self.rowH
            local th = math.max(16, hgt * #self.rows / n)
            self.thumb:SetHeight(th)
            self.thumb:ClearAllPoints()
            self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(hgt - th) * self.offset / maxOff)
            self.thumb:Show()
        else
            self.thumb:Hide()
        end
    end
    function f:SetData(d, keep)
        self.data = d or {}
        if not keep then self.offset = 0 end
        self:Refresh()
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        self.offset = math.max(0, self.offset - delta * 3)
        self:Refresh()
    end)
    return f
end

local function ItemTooltip(owner, itemID)
    if not itemID then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
    if not ok then GameTooltip:AddLine(P:ItemName(itemID)) end
    GameTooltip:Show()
end

local function ColorName(e, skill)
    local col = P:Color(e, skill)
    local c = col and P.COLORS[col] or C.text
    return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, e.name)
end

local function Tiers(e)
    local d = e.diff
    if d and not e.unanchored then
        local c = P.COLORS
        local function col(i, v) return ("|cff%02x%02x%02x%d|r"):format(c[i][1] * 255, c[i][2] * 255, c[i][3] * 255, v) end
        return col(1, d[1]) .. "  " .. col(2, d[2]) .. "  " .. col(3, d[3]) .. "  " .. col(4, d[4])
    end
    local grey = (d and d[4]) or e.grey
    if grey then return L("pf_grey_only", grey) end
    return L("pf_tiers_unknown")
end

-- open the atlas on an item FarmAtlas knows how to farm
local function ShowFarm(itemID)
    if ns.UI and ns.UI.Open then ns.UI:Open(nil, itemID) end
end

------------------------------------------------------------------------
-- window
------------------------------------------------------------------------
function UI:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "FarmAtlasProfFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    SetBG(f, C.bg, { 0.22, 0.25, 0.30, 1 })
    tinsert(UISpecialFrames, "FarmAtlasProfFrame")

    local fancy = not (ns.db and ns.db.settings and ns.db.settings.fancy == false)
    if fancy then
        local marble = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        marble:SetPoint("TOPLEFT", 1, -1)
        marble:SetPoint("BOTTOMRIGHT", -1, 1)
        local ok = pcall(marble.SetTexture, marble, "Interface\\FrameGeneral\\UI-Background-Marble")
        if ok then
            marble:SetHorizTile(true); marble:SetVertTile(true)
            marble:SetVertexColor(0.35, 0.42, 0.55, 0.35)
        else marble:Hide() end
        local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -6, 6)
        border:SetPoint("BOTTOMRIGHT", 6, -6)
        border:SetFrameLevel(f:GetFrameLevel() + 30)
        border:EnableMouse(false)
        if not pcall(border.SetBackdrop, border, { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 26 }) then border:Hide() end
        -- the profession's painting, faint, behind the header
        f.art = f:CreateTexture(nil, "BACKGROUND", nil, 2)
        f.art:SetPoint("TOPRIGHT", -1, -1)
        f.art:SetSize(512, 256)
        f.art:SetBlendMode("ADD")
        f.art:SetAlpha(0.35)
    end

    -- header
    f.icon = Icon(f, 30)
    f.icon:SetPoint("TOPLEFT", 16, -12)
    f.title = Font(f, 18, nil, nil, nil, "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -1)
    if fancy then pcall(f.title.SetFont, f.title, "Fonts\\MORPHEUS.TTF", 22, "OUTLINE") end
    f.sub = Font(f, 11, unpack(C.muted))
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    local close = CreateFrame("Button", nil, f)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -12, -12)
    close.x = Font(close, 16, 0.55, 0.59, 0.66, "GameFontHighlightLarge")
    close.x:SetPoint("CENTER")
    close.x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)

    -- professions (left)
    f.profButtons = {}
    local prev
    for _, key in ipairs(P.KEYS) do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b:SetSize(LEFT_W - 16, 32)
        SetBG(b, C.card)
        b.key = key
        b.ic = Icon(b, 20)
        b.ic:SetPoint("LEFT", 6, 0)
        b.ic:SetTexture(P.ICON[key])
        b.name = Font(b, 11)
        b.name:SetPoint("TOPLEFT", b.ic, "TOPRIGHT", 7, 1)
        b.skill = Font(b, 10, unpack(C.muted))
        b.skill:SetPoint("BOTTOMLEFT", b.ic, "BOTTOMRIGHT", 7, -1)
        if prev then b:SetPoint("TOP", prev, "BOTTOM", 0, -4) else b:SetPoint("TOPLEFT", 16, -64) end
        b:SetScript("OnClick", function() UI:SetProf(key) end)
        b:SetScript("OnEnter", function(s) if s.key ~= UI.prof then s:SetBackdropColor(unpack(C.hover)) end end)
        b:SetScript("OnLeave", function(s) if s.key ~= UI.prof then s:SetBackdropColor(unpack(C.card)) end end)
        f.profButtons[#f.profButtons + 1] = b
        prev = b
    end

    -- tabs (top)
    f.tabs = {}
    local tprev
    for _, t in ipairs({ "recipes", "skillup", "profit", "fav", "list" }) do
        local b = Button(f, "", 100, 24)
        b.key = t
        if tprev then b:SetPoint("LEFT", tprev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", LEFT_W + 8, -64) end
        b:SetScript("OnClick", function() UI:SetTab(t) end)
        f.tabs[#f.tabs + 1] = b
        tprev = b
    end

    local body = CreateFrame("Frame", nil, f)
    body:SetPoint("TOPLEFT", LEFT_W + 8, -96)
    body:SetPoint("BOTTOMRIGHT", -16, 16)
    f.body = body

    f.note = Font(f, 10, unpack(C.muted))
    f.note:SetPoint("BOTTOMLEFT", LEFT_W + 8, 4)

    self:BuildRecipes(body)
    self:BuildSkillUp(body)
    self:BuildProfit(body)
    self:BuildFav(body)
    self:BuildList(body)

    f:SetScript("OnShow", function() UI:Refresh() end)
    self.tab = "recipes"
end

------------------------------------------------------------------------
-- Recipes tab: list + details
------------------------------------------------------------------------
function UI:BuildRecipes(body)
    local p = CreateFrame("Frame", nil, body)
    p:SetAllPoints()
    self.pRecipes = p

    local search = CreateFrame("EditBox", nil, p, "BackdropTemplate")
    search:SetSize(250, 24)
    search:SetPoint("TOPLEFT", 0, 0)
    SetBG(search, C.panel)
    search:SetFontObject(ChatFontNormal)
    search:SetTextInsets(8, 8, 0, 0)
    search:SetAutoFocus(false)
    search.ph = Font(search, 11, 0.42, 0.45, 0.52)
    search.ph:SetPoint("LEFT", 8, 0)
    search:SetScript("OnTextChanged", function(s)
        s.ph:SetShown(s:GetText() == "")
        UI:FillRecipes()
    end)
    search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    p.search = search

    p.knownOnly = Check(p, function() return UI.knownOnly end, function(v) UI.knownOnly = v; UI:FillRecipes() end)
    p.knownOnly:SetPoint("LEFT", search, "RIGHT", 10, 0)
    p.count = Font(p, 10, unpack(C.muted))
    p.count:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 2, -6)

    local list = List(p, 19, ROW, function(r)
        r.ic = Icon(r, 16)
        r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11)
        r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0)
        r.name:SetWidth(240)
        r.lvl = Font(r, 11, unpack(C.muted))
        r.lvl:SetPoint("RIGHT", -8, 0)
        r.lvl:SetJustifyH("RIGHT")
        r.mark = Font(r, 11)
        r.mark:SetPoint("RIGHT", r.lvl, "LEFT", -6, 0)
    end, function(r, it)
        local e = it.e
        r.ic:SetTexture(P:ItemIcon(e.out))
        r.name:SetText(ColorName(e, UI.skill))
        r.lvl:SetText(e.learn and tostring(e.learn) or (e.grey and ("<" .. e.grey) or "?"))
        local m = ""
        if P:IsFav(e) then m = m .. "|cffffd200*|r" end
        if P:Known(e) then m = m .. "|cff59d959+|r" end
        r.mark:SetText(m)
    end)
    list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -22)
    list:SetSize(390, 19 * ROW)
    list.onClick = function(it) UI.selected = it.e; list.selected = it.key; list:Refresh(); UI:FillDetail() end
    list.onEnter = function(r, it) if it.e.out then ItemTooltip(r, it.e.out) end end
    p.list = list

    -- details
    local d = CreateFrame("Frame", nil, p, "BackdropTemplate")
    d:SetPoint("TOPLEFT", list, "TOPRIGHT", 12, 46)
    d:SetPoint("BOTTOMRIGHT", 0, 0)
    SetBG(d, C.panel)
    p.detail = d
    d.icon = Icon(d, 36)
    d.icon:SetPoint("TOPLEFT", 12, -12)
    d.iconBtn = CreateFrame("Button", nil, d)
    d.iconBtn:SetAllPoints(d.icon)
    d.iconBtn:SetScript("OnEnter", function(s) if UI.selected then ItemTooltip(s, UI.selected.out) end end)
    d.iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    d.name = Font(d, 15, nil, nil, nil, "GameFontNormalLarge")
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 10, -2)
    d.name:SetWidth(300)
    d.state = Font(d, 11, unpack(C.muted))
    d.state:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.star = Button(d, "*", 26, 22)
    d.star:SetPoint("TOPRIGHT", -10, -10)
    d.star:SetScript("OnClick", function() if UI.selected then P:ToggleFav(UI.selected) end end)
    d.tiers = Font(d, 12)
    d.tiers:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -12)
    d.learn = Font(d, 11, unpack(C.muted))
    d.learn:SetPoint("TOPLEFT", d.tiers, "BOTTOMLEFT", 0, -6)
    d.learn:SetWidth(470)
    d.learn:SetWordWrap(true)
    d.rHead = Font(d, 12, unpack(C.gold))
    d.rHead:SetPoint("TOPLEFT", d.learn, "BOTTOMLEFT", 0, -12)
    d.reag = {}
    for i = 1, 8 do
        local r = CreateFrame("Button", nil, d, "BackdropTemplate")
        r:SetSize(470, 22)
        SetBG(r, C.card)
        if i == 1 then r:SetPoint("TOPLEFT", d.rHead, "BOTTOMLEFT", 0, -4) else r:SetPoint("TOPLEFT", d.reag[i - 1], "BOTTOMLEFT", 0, -2) end
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(200)
        r.have = Font(r, 11); r.have:SetPoint("LEFT", 250, 0)
        r.price = Font(r, 11); r.price:SetPoint("RIGHT", -60, 0); r.price:SetJustifyH("RIGHT")
        r.farm = Button(r, "", 50, 18); r.farm:SetPoint("RIGHT", -3, 0)
        r.farm:SetScript("OnClick", function(s) if s.id then ShowFarm(s.id) end end)
        r:SetScript("OnEnter", function(s) if s.id then ItemTooltip(s, s.id) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        d.reag[i] = r
    end
    d.cost = Font(d, 11)
    d.cost:SetPoint("TOPLEFT", d.reag[8], "BOTTOMLEFT", 0, -8)
    d.sale = Font(d, 11)
    d.sale:SetPoint("TOPLEFT", d.cost, "BOTTOMLEFT", 0, -4)
    d.alts = Font(d, 10, unpack(C.muted))
    d.alts:SetPoint("TOPLEFT", d.sale, "BOTTOMLEFT", 0, -4)
    d.cd = Font(d, 10, 1, 0.6, 0.3)
    d.cd:SetPoint("TOPLEFT", d.alts, "BOTTOMLEFT", 0, -4)

    d.count = CreateFrame("EditBox", nil, d, "BackdropTemplate")
    d.count:SetSize(40, 22)
    d.count:SetPoint("BOTTOMLEFT", 12, 12)
    SetBG(d.count, C.card)
    d.count:SetFontObject(ChatFontNormal)
    d.count:SetJustifyH("CENTER")
    d.count:SetNumeric(true)
    d.count:SetAutoFocus(false)
    d.count:SetText("1")
    d.count:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
    d.add = Button(d, "", 90, 22)
    d.add:SetPoint("LEFT", d.count, "RIGHT", 6, 0)
    d.add:SetScript("OnClick", function()
        if UI.selected then P:AddToList(UI.selected, tonumber(d.count:GetText()) or 1) end
    end)
    d.open = Button(d, "", 90, 22)
    d.open:SetPoint("LEFT", d.add, "RIGHT", 6, 0)
    d.open:SetScript("OnClick", function() if UI.selected then ns:OpenCraft(UI.selected.name) end end)
end

function UI:FillRecipes()
    local p = self.pRecipes
    if not (p and self.profID) then return end
    local q = (p.search:GetText() or ""):lower()
    local data, known, total = {}, 0, 0
    for _, e in ipairs(P:List(self.profID)) do
        total = total + 1
        local k = P:Known(e)
        if k then known = known + 1 end
        local ok = not self.knownOnly or k
        if ok and q ~= "" then
            ok = e.name:lower():find(q, 1, true) ~= nil
            if not ok then
                for id in pairs(e.r) do
                    if P:ItemName(id):lower():find(q, 1, true) then ok = true; break end
                end
            end
        end
        if ok then data[#data + 1] = { e = e, key = e.id } end
    end
    p.count:SetText(L("pf_count", total, known))
    p.list:SetData(data, true)
    if not self.selected or self.selected.prof ~= self.profID then
        self.selected = data[1] and data[1].e
        p.list.selected = self.selected and self.selected.id
        p.list:Refresh()
    end
    self:FillDetail()
end

local SRC_ORDER = { "auto", "trainer", "vendor", "quest", "drop", "container" }
local function SourceLine(e)
    local src = P:Sources(e)
    local parts = {}
    for _, k in ipairs(SRC_ORDER) do
        if src.kinds[k] then
            local s = L("pf_src_" .. k)
            local lst = src[k]
            if type(lst) == "table" and lst[1] then
                local names = {}
                for i = 1, math.min(2, #lst) do
                    local n = lst[i].name or "?"
                    if lst[i].faction then n = n .. " (" .. lst[i].faction .. ")" end
                    if lst[i].cost then
                        for _, part in ipairs(lst[i].cost) do
                            if part.copper then n = n .. " " .. ns:Money(part.copper)
                            elseif part.currencyID then
                                local cname = "?"
                                if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                                    local ok, ci = pcall(C_CurrencyInfo.GetCurrencyInfo, part.currencyID)
                                    if ok and ci and ci.name then cname = ci.name end
                                end
                                n = n .. " " .. (part.amount or "?") .. " " .. cname
                            end
                        end
                    end
                    names[#names + 1] = n
                end
                s = s .. ": " .. table.concat(names, ", ")
                local more = (lst.total or #lst) - #names
                if more > 0 then s = s .. " " .. L("pf_more", more) end
            end
            parts[#parts + 1] = s
        end
    end
    if #parts == 0 then parts[1] = L("pf_src_unknown") end
    local line = L("pf_src") .. ": " .. table.concat(parts, "  ·  ")
    if src.borrowed then line = line .. "  " .. L("pf_unconfirmed") end
    return line
end

function UI:FillDetail()
    local d = self.pRecipes and self.pRecipes.detail
    if not d then return end
    local e = self.selected
    d:SetShown(e ~= nil)
    if not e then return end
    d.icon:SetTexture(P:ItemIcon(e.out))
    d.name:SetText(ColorName(e, self.skill))
    local known = P:Known(e)
    d.state:SetText(known and ("|cff59d959" .. L("pf_known") .. "|r") or L("pf_unknown"))
    d.star.text:SetText(P:IsFav(e) and "|cffffd200*|r" or "*")
    d.star.tooltip = L("pf_fav_add")
    local t = Tiers(e)
    if e.reqBorrowed then t = t .. "  " .. L("pf_unconfirmed") end
    d.tiers:SetText(t)
    d.learn:SetText(SourceLine(e))
    d.rHead:SetText(L("pf_reagents"))
    local ids = {}
    for id in pairs(e.r) do ids[#ids + 1] = id end
    table.sort(ids)
    for i, r in ipairs(d.reag) do
        local id = ids[i]
        r.id = id
        if id then
            local need, have = e.r[id], P:Have(id)
            r.ic:SetTexture(P:ItemIcon(id))
            r.name:SetText(P:ItemName(id))
            r.have:SetText(("%s%d|r / %d"):format(have >= need and "|cff59d959" or "|cffff5959", have, need))
            local pr, kind = P:Price(id)
            r.price:SetText(pr and (ns:Money(pr * need) .. (kind == "vendor" and " |cff8c96a8(" .. L("pf_vendor_short") .. ")|r" or "")) or ("|cff8c96a8" .. L("pf_unpriced") .. "|r"))
            r.farm.id = id
            r.farm.text:SetText(L("pf_farm"))
            r.farm.tooltip = L("pf_farm_tip")
            r.farm:SetShown(P:Farmable(id))
            r:Show()
        else
            r:Hide()
        end
    end
    local cost, unpriced = P:CraftCost(e)
    d.cost:SetText(L("pf_cost", Money(cost)) .. (unpriced and (" |cff8c96a8(" .. L("pf_unpriced") .. ")|r") or ""))
    local sale = P:SalePrice(e)
    d.sale:SetText(sale and L("pf_sale", Money(sale)) or "")
    local alts = P:KnownBy(e)
    d.alts:SetText(#alts > 0 and L("pf_known_by", table.concat(alts, ", ")) or "")
    d.cd:SetText(P.COOLDOWN[e.id] and L("pf_cooldown") or "")
    d.add.text:SetText(L("pf_add"))
    d.open.text:SetText(L("pf_open"))
    d.open:SetShown(known)
end

------------------------------------------------------------------------
-- Skill-up tab
------------------------------------------------------------------------
local function SumBox(parent)
    local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    b:SetSize(120, 44)
    SetBG(b, C.card)
    b.k = Font(b, 10, unpack(C.muted)); b.k:SetPoint("TOP", 0, -6); b.k:SetJustifyH("CENTER")
    b.v = Font(b, 12); b.v:SetPoint("BOTTOM", 0, 7); b.v:SetJustifyH("CENTER")
    return b
end

function UI:BuildSkillUp(body)
    local p = CreateFrame("Frame", nil, body)
    p:SetAllPoints()
    self.pSkill = p
    p.cur = Font(p, 12)
    p.cur:SetPoint("TOPLEFT", 0, -4)
    p.targets = {}
    local prev
    for _, t in ipairs({ 75, 150, 225, 300 }) do
        local b = Button(p, tostring(t), 46, 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", p.cur, "RIGHT", 60, 0) end
        b.t = t
        b:SetScript("OnClick", function() UI.target = t; UI:FillSkillUp() end)
        p.targets[#p.targets + 1] = b
        prev = b
    end
    local s = function() return ns.db.settings end
    p.own = Check(p, function() return s().pfOwn ~= false end, function(v) s().pfOwn = v; UI:FillSkillUp() end)
    p.own:SetPoint("LEFT", prev, "RIGHT", 16, 0)
    p.unl = Check(p, function() return s().pfUnlearned ~= false end, function(v) s().pfUnlearned = v; UI:FillSkillUp() end)
    p.unl:SetPoint("LEFT", p.own, "RIGHT", 14, 0)

    p.boxes = {}
    local bprev
    for _, k in ipairs({ "all", "ah", "vendor", "learn", "crafts" }) do
        local b = SumBox(p)
        b.key = k
        if bprev then b:SetPoint("LEFT", bprev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 0, -34) end
        p.boxes[k] = b
        bprev = b
    end
    p.addAll = Button(p, "", 150, 24)
    p.addAll:SetPoint("LEFT", bprev, "RIGHT", 10, 0)
    p.addAll:SetScript("OnClick", function() if UI.plan then P:AddPlan(UI.plan) end end)

    local steps = List(p, 9, ROW + 2, function(r)
        r.range = Font(r, 11, unpack(C.muted)); r.range:SetPoint("LEFT", 6, 0); r.range:SetWidth(70)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 80, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(250)
        r.crafts = Font(r, 11); r.crafts:SetPoint("LEFT", 370, 0)
        r.cost = Font(r, 11); r.cost:SetPoint("LEFT", 430, 0)
        r.learn = Font(r, 10, unpack(C.muted)); r.learn:SetPoint("RIGHT", -8, 0); r.learn:SetJustifyH("RIGHT"); r.learn:SetWidth(200)
    end, function(r, it)
        local st = it.st
        r.range:SetText(st.from .. " - " .. st.to)
        if st.gap then
            r.ic:SetTexture(134400)
            r.name:SetText("|cffff5959" .. L("pf_gap", st.from, st.to) .. "|r")
            r.crafts:SetText(""); r.cost:SetText(""); r.learn:SetText("")
            return
        end
        r.ic:SetTexture(P:ItemIcon(st.e.out))
        r.name:SetText(st.e.name)
        r.crafts:SetText("x" .. st.crafts)
        r.cost:SetText(Money(st.cost) .. (st.unpriced and " |cff8c96a8+?|r" or ""))
        local l = ""
        if st.learn then
            if st.learn.kind == "vendor" then
                l = L("pf_learn_vendor", st.learn.npc or "")
                if st.learn.copper then l = l .. " " .. ns:Money(st.learn.copper) end
            elseif st.learn.kind == "ah" then l = L("pf_learn_ah") .. " " .. Money(st.learn.copper)
            else l = L("pf_learn_trainer") end
        end
        r.learn:SetText(l)
    end)
    steps:SetPoint("TOPLEFT", 0, -88)
    steps:SetPoint("TOPRIGHT", 0, -88)
    steps:SetHeight(9 * (ROW + 2))
    steps.onClick = function(it) UI.step = it.st; steps.selected = it.key; steps:Refresh(); UI:FillMats() end
    steps.onEnter = function(r, it) if it.st.e then ItemTooltip(r, it.st.e.out) end end
    p.steps = steps

    p.mHead = Font(p, 12, unpack(C.gold))
    p.mHead:SetPoint("TOPLEFT", steps, "BOTTOMLEFT", 0, -8)
    local mats = List(p, 6, ROW, function(r)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(240)
        r.need = Font(r, 11); r.need:SetPoint("LEFT", 290, 0)
        r.cost = Font(r, 11); r.cost:SetPoint("LEFT", 400, 0)
        r.farm = Button(r, "", 50, 18); r.farm:SetPoint("RIGHT", -4, 0)
        r.farm:SetScript("OnClick", function(s) if s.id then ShowFarm(s.id) end end)
    end, function(r, it)
        local m = it.m
        r.ic:SetTexture(P:ItemIcon(m.id))
        r.name:SetText(P:ItemName(m.id))
        local have = P:Have(m.id)
        r.need:SetText(("%s%d|r / %d"):format(have >= m.need and "|cff59d959" or "|cffff5959", have, m.need))
        r.cost:SetText(m.price and (ns:Money(m.price) .. " " .. (m.kind == "vendor" and L("pf_vendor_short") or "AH")) or ("|cff8c96a8" .. L("pf_unpriced") .. "|r"))
        r.farm.id = m.id
        r.farm.text:SetText(L("pf_farm"))
        r.farm.tooltip = L("pf_farm_tip")
        r.farm:SetShown(P:Farmable(m.id))
    end)
    mats:SetPoint("TOPLEFT", p.mHead, "BOTTOMLEFT", 0, -4)
    mats:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    mats:SetHeight(6 * ROW)
    mats.onEnter = function(r, it) ItemTooltip(r, it.m.id) end
    p.mats = mats
end

function UI:FillSkillUp()
    local p = self.pSkill
    if not (p and self.profID) then return end
    local cur, max = self.skill, self.maxSkill
    p.cur:SetText(L("pf_skill", cur and (cur .. " / " .. (max or 300)) or L("pf_not_learned")))
    local from = cur or 1
    local target = self.target
    if not target or target <= from then
        target = (from < 75 and 75) or (from < 150 and 150) or (from < 225 and 225) or 300
        if max and max > from and max < target then target = max end
        self.target = target
    end
    for _, b in ipairs(p.targets) do b:SetActive(b.t == target) end
    local s = ns.db.settings
    p.own:Update(L("pf_own"))
    p.unl:Update(L("pf_unlearned"))
    local plan = (from < target) and P:Plan(self.profID, from, target, { own = s.pfOwn ~= false, unlearned = s.pfUnlearned ~= false })
        or { steps = {}, totals = { all = 0, ah = 0, vendor = 0, learn = 0, crafts = 0 }, mats = {} }
    self.plan = plan
    local tot = plan.totals
    local vals = { all = Money(tot.all) .. (tot.unpriced and " |cff8c96a8+?|r" or ""), ah = Money(tot.ah), vendor = Money(tot.vendor),
        learn = Money(tot.learn), crafts = tostring(tot.crafts) }
    for k, b in pairs(p.boxes) do
        b.k:SetText(L("pf_sum_" .. k))
        b.v:SetText(vals[k])
    end
    p.addAll.text:SetText(L("pf_add_all"))
    p.addAll:Fit(150)
    local data = {}
    for i, st in ipairs(plan.steps) do data[#data + 1] = { st = st, key = i } end
    p.steps:SetData(data)
    self.step = nil
    p.steps.selected = nil
    p.steps:Refresh()
    self:FillMats()
end

function UI:FillMats()
    local p = self.pSkill
    if not p then return end
    local data = {}
    if self.step and not self.step.gap then
        p.mHead:SetText(L("pf_materials") .. ": " .. self.step.e.name .. "  x" .. self.step.crafts)
        for id, n in pairs(self.step.mats) do
            local pr, kind = P:Price(id)
            data[#data + 1] = { m = { id = id, need = n, price = pr, kind = kind }, key = id }
        end
        table.sort(data, function(a, b) return a.m.need > b.m.need end)
    elseif self.plan then
        p.mHead:SetText(L("pf_materials") .. " (" .. L("pf_sum_all") .. ")")
        for _, m in ipairs(self.plan.mats) do data[#data + 1] = { m = m, key = m.id } end
    end
    p.mats:SetData(data)
end

------------------------------------------------------------------------
-- Profit tab
------------------------------------------------------------------------
function UI:BuildProfit(body)
    local p = CreateFrame("Frame", nil, body)
    p:SetAllPoints()
    self.pProfit = p
    local s = function() return ns.db.settings end
    p.known = Check(p, function() return s().pfProfitKnown ~= false end, function(v) s().pfProfitKnown = v; UI:FillProfit() end)
    p.known:SetPoint("TOPLEFT", 0, -2)
    p.hint = Font(p, 10, unpack(C.muted))
    p.hint:SetPoint("LEFT", p.known, "RIGHT", 16, 0)
    p.head = Font(p, 10, unpack(C.muted))
    p.head:SetPoint("TOPLEFT", 26, -30)
    local list = List(p, 19, ROW, function(r)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(280)
        r.cost = Font(r, 11); r.cost:SetPoint("LEFT", 320, 0)
        r.sale = Font(r, 11); r.sale:SetPoint("LEFT", 440, 0)
        r.profit = Font(r, 11, unpack(C.green)); r.profit:SetPoint("LEFT", 560, 0)
        r.margin = Font(r, 11); r.margin:SetPoint("RIGHT", -10, 0); r.margin:SetJustifyH("RIGHT")
    end, function(r, it)
        local x = it.x
        r.ic:SetTexture(P:ItemIcon(x.e.out))
        r.name:SetText(ColorName(x.e, UI.skill))
        r.cost:SetText(ns:Money(x.cost))
        r.sale:SetText(ns:Money(x.sale))
        r.profit:SetText("+" .. ns:Money(x.profit))
        r.margin:SetText(math.floor(x.margin * 100 + 0.5) .. "%")
    end)
    list:SetPoint("TOPLEFT", 0, -46)
    list:SetPoint("TOPRIGHT", 0, -46)
    list:SetHeight(19 * ROW)
    list.onEnter = function(r, it) ItemTooltip(r, it.x.e.out) end
    list.onClick = function(it) UI:ShowRecipe(it.x.e) end
    p.list = list
    p.empty = Font(p, 12, unpack(C.muted))
    p.empty:SetPoint("TOP", 0, -120)
    p.empty:SetWidth(600)
    p.empty:SetWordWrap(true)
    p.empty:SetJustifyH("CENTER")
end

function UI:FillProfit()
    local p = self.pProfit
    if not (p and self.profID) then return end
    p.known:Update(L("pf_known_only"))
    p.hint:SetText(L("pf_profit_hint"))
    p.head:SetText(L("pf_col_recipe") .. string.rep(" ", 70))
    local data = {}
    for _, x in ipairs(P:Profit(self.profID, ns.db.settings.pfProfitKnown ~= false)) do data[#data + 1] = { x = x, key = x.e.id } end
    p.list:SetData(data)
    p.empty:SetText(#data == 0 and L("pf_profit_none") or "")
end

------------------------------------------------------------------------
-- Favourites tab (every profession)
------------------------------------------------------------------------
function UI:BuildFav(body)
    local p = CreateFrame("Frame", nil, body)
    p:SetAllPoints()
    self.pFav = p
    local list = List(p, 21, ROW, function(r)
        r.pi = Icon(r, 16); r.pi:SetPoint("LEFT", 4, 0)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", r.pi, "RIGHT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(320)
        r.lvl = Font(r, 11, unpack(C.muted)); r.lvl:SetPoint("LEFT", 400, 0)
        r.known = Font(r, 11); r.known:SetPoint("LEFT", 470, 0)
        r.del = Button(r, "x", 22, 18); r.del:SetPoint("RIGHT", -4, 0)
        r.del:SetScript("OnClick", function(s) if s.e then P:ToggleFav(s.e) end end)
    end, function(r, it)
        local e = it.e
        r.pi:SetTexture(P.ICON[P:KeyFor(e.prof)] or 134400)
        r.ic:SetTexture(P:ItemIcon(e.out))
        r.name:SetText(e.name)
        r.lvl:SetText(e.learn and tostring(e.learn) or "")
        r.known:SetText(P:Known(e) and ("|cff59d959" .. L("pf_known") .. "|r") or ("|cff8c96a8" .. L("pf_unknown") .. "|r"))
        r.del.e = e
    end)
    list:SetPoint("TOPLEFT", 0, 0)
    list:SetPoint("TOPRIGHT", 0, 0)
    list:SetHeight(21 * ROW)
    list.onClick = function(it) UI:ShowRecipe(it.e) end
    list.onEnter = function(r, it) ItemTooltip(r, it.e.out) end
    p.list = list
    p.empty = Font(p, 12, unpack(C.muted))
    p.empty:SetPoint("TOP", 0, -120)
end

function UI:FillFav()
    local p = self.pFav
    if not p then return end
    local data = {}
    for _, e in ipairs(P:Favs()) do data[#data + 1] = { e = e, key = e.id } end
    p.list:SetData(data, true)
    p.empty:SetText(#data == 0 and L("pf_fav_none") or "")
end

------------------------------------------------------------------------
-- Shopping list tab
------------------------------------------------------------------------
function UI:BuildList(body)
    local p = CreateFrame("Frame", nil, body)
    p:SetAllPoints()
    self.pList = p
    p.rHead = Font(p, 12, unpack(C.gold))
    p.rHead:SetPoint("TOPLEFT", 0, -2)
    p.clear = Button(p, "", 110, 22)
    p.clear:SetPoint("TOPRIGHT", 0, 0)
    p.clear:SetScript("OnClick", function() P:ClearList() end)
    local recipes = List(p, 6, ROW, function(r)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(360)
        r.minus = Button(r, "-", 22, 18); r.minus:SetPoint("RIGHT", -60, 0)
        r.n = Font(r, 11); r.n:SetPoint("RIGHT", -34, 0); r.n:SetJustifyH("CENTER"); r.n:SetWidth(24)
        r.plus = Button(r, "+", 22, 18); r.plus:SetPoint("RIGHT", -4, 0)
        r.minus:SetScript("OnClick", function(s) if s.it then P:SetListCount(s.it.e.id, s.it.n - 1) end end)
        r.plus:SetScript("OnClick", function(s) if s.it then P:SetListCount(s.it.e.id, s.it.n + 1) end end)
    end, function(r, it)
        r.ic:SetTexture(P:ItemIcon(it.e.out))
        r.name:SetText(it.e.name)
        r.n:SetText(tostring(it.n))
        r.minus.it, r.plus.it = it, it
    end)
    recipes:SetPoint("TOPLEFT", 0, -28)
    recipes:SetPoint("TOPRIGHT", 0, -28)
    recipes:SetHeight(6 * ROW)
    recipes.onEnter = function(r, it) ItemTooltip(r, it.e.out) end
    p.recipes = recipes

    p.mHead = Font(p, 12, unpack(C.gold))
    p.mHead:SetPoint("TOPLEFT", recipes, "BOTTOMLEFT", 0, -10)
    p.total = Font(p, 12)
    p.total:SetPoint("TOPRIGHT", recipes, "BOTTOMRIGHT", 0, -10)
    p.total:SetJustifyH("RIGHT")
    local mats = List(p, 11, ROW, function(r)
        r.ic = Icon(r, 16); r.ic:SetPoint("LEFT", 4, 0)
        r.name = Font(r, 11); r.name:SetPoint("LEFT", r.ic, "RIGHT", 6, 0); r.name:SetWidth(240)
        r.need = Font(r, 11); r.need:SetPoint("LEFT", 290, 0)
        r.miss = Font(r, 11); r.miss:SetPoint("LEFT", 380, 0)
        r.cost = Font(r, 11); r.cost:SetPoint("LEFT", 470, 0)
        r.farm = Button(r, "", 50, 18); r.farm:SetPoint("RIGHT", -4, 0)
        r.farm:SetScript("OnClick", function(s) if s.id then ShowFarm(s.id) end end)
    end, function(r, it)
        local m = it.m
        r.ic:SetTexture(P:ItemIcon(m.id))
        r.name:SetText(P:ItemName(m.id))
        r.need:SetText(("%s%d|r / %d"):format(m.missing == 0 and "|cff59d959" or "|cffff5959", m.have, m.need))
        r.miss:SetText(m.missing > 0 and ("|cffff5959-" .. m.missing .. "|r") or "|cff59d959OK|r")
        r.cost:SetText(m.missing > 0 and (m.cost and ns:Money(m.cost) or ("|cff8c96a8" .. L("pf_unpriced") .. "|r")) or "")
        r.farm.id = m.id
        r.farm.text:SetText(L("pf_farm"))
        r.farm.tooltip = L("pf_farm_tip")
        r.farm:SetShown(m.missing > 0 and P:Farmable(m.id))
    end)
    mats:SetPoint("TOPLEFT", p.mHead, "BOTTOMLEFT", 0, -4)
    mats:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    mats:SetHeight(11 * ROW)
    mats.onEnter = function(r, it) ItemTooltip(r, it.m.id) end
    p.mats = mats
    p.empty = Font(p, 12, unpack(C.muted))
    p.empty:SetPoint("TOP", 0, -60)
    p.empty:SetWidth(600)
    p.empty:SetWordWrap(true)
    p.empty:SetJustifyH("CENTER")
end

function UI:FillList()
    local p = self.pList
    if not p then return end
    local sh = P:Shopping()
    p.rHead:SetText(L("pf_tab_list"))
    p.clear.text:SetText(L("pf_clear"))
    p.clear:Fit(110)
    local rdata, mdata = {}, {}
    for _, it in ipairs(sh.recipes) do rdata[#rdata + 1] = { e = it.e, n = it.n, key = it.e.id } end
    for _, m in ipairs(sh.mats) do mdata[#mdata + 1] = { m = m, key = m.id } end
    p.recipes:SetData(rdata, true)
    p.mats:SetData(mdata, true)
    p.mHead:SetText(L("pf_materials"))
    p.total:SetText(L("pf_list_total", ns:Money(sh.total)) .. (sh.unpriced and " |cff8c96a8+?|r" or ""))
    p.empty:SetText(#rdata == 0 and L("pf_list_none") or "")
    p.mHead:SetShown(#rdata > 0)
    p.total:SetShown(#rdata > 0)
end

------------------------------------------------------------------------
-- state
------------------------------------------------------------------------
function UI:ShowRecipe(e)
    self:SetProf(P:KeyFor(e.prof) or self.prof, true)
    self.selected = e
    self:SetTab("recipes")
    local p = self.pRecipes
    p.search:SetText("")
    -- scroll the list to it
    for i, it in ipairs(p.list.data) do
        if it.e == e then p.list.offset = math.max(0, i - 5); break end
    end
    p.list.selected = e.id
    p.list:Refresh()
    self:FillDetail()
end

function UI:SetProf(key, quiet)
    self.prof = key
    self.profID = P:ID(key)
    self.target = nil
    if not quiet then self.selected = nil end
    self:Refresh()
end

function UI:SetTab(t)
    self.tab = t
    self:Refresh()
end

function UI:DefaultProf()
    -- the first main profession this character has, else Cooking
    for _, k in ipairs(P.KEYS) do
        if k ~= "cooking" and k ~= "firstaid" and k ~= "fishing" and P:Skill(k) then
            if #P:List(P:ID(k)) > 0 then return k end
        end
    end
    return "cooking"
end

function UI:Refresh()
    local f = self.frame
    if not (f and f:IsShown()) then return end
    if not self.prof then self.prof = self:DefaultProf(); self.profID = P:ID(self.prof) end
    self.skill, self.maxSkill = P:Skill(self.prof)
    f.icon:SetTexture(P.ICON[self.prof])
    f.title:SetText("|cff3fc7ebFarm|r|cffffd200Atlas|r  " .. L("pf_title"))
    f.sub:SetText(L("cat_" .. self.prof) .. (self.skill and ("  ·  " .. self.skill .. " / " .. (self.maxSkill or 300)) or ""))
    if f.art then
        local ok = pcall(f.art.SetTexture, f.art, "Interface\\AddOns\\FarmAtlas\\Media\\Themes\\" .. self.prof)
        f.art:SetShown(ok)
    end
    for _, b in ipairs(f.profButtons) do
        local n = #P:List(P:ID(b.key))
        b.name:SetText(L("cat_" .. b.key))
        local s, m = P:Skill(b.key)
        b.skill:SetText(s and (s .. " / " .. (m or 300)) or (n > 0 and (n .. " " .. L("pf_recipes_short")) or "-"))
        b.ic:SetDesaturated(not s)
        if b.key == self.prof then
            b:SetBackdropColor(C.accent[1] * 0.35, C.accent[2] * 0.35, C.accent[3] * 0.35, 1)
            b:SetBackdropBorderColor(unpack(C.accent))
        else
            b:SetBackdropColor(unpack(C.card))
            b:SetBackdropBorderColor(unpack(C.border))
        end
    end
    for _, b in ipairs(f.tabs) do
        b.text:SetText(L("pf_tab_" .. b.key))
        b:Fit(96)
        b:SetActive(b.key == self.tab)
    end
    self.pRecipes:SetShown(self.tab == "recipes")
    self.pSkill:SetShown(self.tab == "skillup")
    self.pProfit:SetShown(self.tab == "profit")
    self.pFav:SetShown(self.tab == "fav")
    self.pList:SetShown(self.tab == "list")
    self.pRecipes.search.ph:SetText(L("pf_search"))
    self.pRecipes.knownOnly:Update(L("pf_known_only"))
    local note = ""
    if not P:Lib() then note = L("pf_lib_missing")
    elseif #P:List(self.profID) == 0 then note = L("pf_scan_hint") end
    f.note:SetText(note)
    if self.tab == "recipes" then self:FillRecipes()
    elseif self.tab == "skillup" then self:FillSkillUp()
    elseif self.tab == "profit" then self:FillProfit()
    elseif self.tab == "fav" then self:FillFav()
    elseif self.tab == "list" then self:FillList() end
end

function UI:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end

function UI:Open(key)
    self:Build()
    if key then self.prof = key; self.profID = P:ID(key) end
    self.frame:Show()
    self:Refresh()
end

-- redraw at most twice a second when data changes
local pending = false
local function Soon()
    if pending or not (UI.frame and UI.frame:IsShown()) then return end
    pending = true
    C_Timer.After(0.5, function() pending = false; UI:Refresh() end)
end
ns:On("PROF_CHANGED", Soon)
ns:On("ITEM_INFO", Soon)
ns:On("INVENTORY_CHANGED", Soon)
ns:On("LANG_CHANGED", Soon)
