-- FarmAtlas - main window
local _, ns = ...
local GetItemInfo = ns.GetItemInfo

local UI = {}
ns.UI = UI
local L = ns.L

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
}

local W, H = 860, 540
local RAIL = 60          -- width of the section rail on the left
local LIST_W = 300
local ROW_H = 42

------------------------------------------------------------------------
-- Small widget helpers
------------------------------------------------------------------------
local function SetBG(frame, color, border)
    if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
    frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    frame:SetBackdropColor(unpack(color))
    local b = border or C.border
    frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local function Font(parent, template, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    if size then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path, size, flags)
    end
    if r then fs:SetTextColor(r, g, b) end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function RoundIcon(parent, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    holder.ring = holder:CreateTexture(nil, "BACKGROUND")
    holder.ring:SetTexture(WHITE)
    holder.ring:SetPoint("TOPLEFT", -1, 1)
    holder.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    holder.ring:SetVertexColor(unpack(C.border))
    holder.icon = holder:CreateTexture(nil, "ARTWORK")
    holder.icon:SetAllPoints()
    holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return holder
end

local function FlatButton(parent, label, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 24)
    SetBG(b, C.card)
    b.text = Font(b, "GameFontHighlightSmall")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b.active = false
    function b:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(C.accent[1] * 0.35, C.accent[2] * 0.35, C.accent[3] * 0.35, 1)
            self:SetBackdropBorderColor(unpack(C.accent))
            self.text:SetTextColor(1, 1, 1)
        else
            self:SetBackdropColor(unpack(C.card))
            self:SetBackdropBorderColor(unpack(C.border))
            self.text:SetTextColor(unpack(C.text))
        end
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
    b:SetActive(false)
    return b
end

-- grow a button to its (translated) label, never below its design width
local function Fit(b, minW)
    b.minW = b.minW or minW or b:GetWidth()
    local w = (b.text:GetStringWidth() or 0) + 18
    b:SetWidth(math.max(b.minW, math.floor(w + 0.5)))
end

local function Toggle(parent, labelKey, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    b.box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    b.box:SetSize(14, 14)
    b.box:SetPoint("LEFT")
    SetBG(b.box, C.card)
    b.check = b.box:CreateTexture(nil, "ARTWORK")
    b.check:SetTexture(WHITE)
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetVertexColor(unpack(C.accent))
    b.text = Font(b, "GameFontHighlightSmall", nil, unpack(C.muted))
    b.text:SetPoint("LEFT", b.box, "RIGHT", 6, 0)
    b.labelKey = labelKey
    function b:Update()
        self.check:SetShown(get() and true or false)
        self.text:SetText(L(self.labelKey))
        self:SetWidth(self.text:GetStringWidth() + 26)
    end
    b:SetScript("OnClick", function(self) set(not get()); self:Update() end)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(unpack(C.text)) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(C.muted)) end)
    b:Update()
    return b
end

-- Plain scroll frame with mouse wheel and a slim thumb
local function ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(1, 1)
    sf:SetScrollChild(child)
    sf.child = child

    sf.track = sf:CreateTexture(nil, "OVERLAY")
    sf.track:SetTexture(WHITE)
    sf.track:SetVertexColor(1, 1, 1, 0.04)
    sf.track:SetPoint("TOPRIGHT", 0, 0)
    sf.track:SetPoint("BOTTOMRIGHT", 0, 0)
    sf.track:SetWidth(3)
    sf.thumb = sf:CreateTexture(nil, "OVERLAY", nil, 1)
    sf.thumb:SetTexture(WHITE)
    sf.thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
    sf.thumb:SetWidth(3)

    function sf:UpdateThumb()
        local viewH, contentH = self:GetHeight(), self.child:GetHeight()
        if contentH <= viewH + 1 then
            self.thumb:Hide(); self.track:Hide(); return
        end
        self.thumb:Show(); self.track:Show()
        local th = math.max(20, viewH * viewH / contentH)
        local maxScroll = contentH - viewH
        local pos = (self:GetVerticalScroll() / maxScroll) * (viewH - th)
        self.thumb:SetHeight(th)
        self.thumb:ClearAllPoints()
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -pos)
    end

    function sf:SetContentHeight(h)
        self.child:SetHeight(math.max(1, h))
        local maxScroll = math.max(0, h - self:GetHeight())
        if self:GetVerticalScroll() > maxScroll then self:SetVerticalScroll(maxScroll) end
        self:UpdateThumb()
    end

    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, self.child:GetHeight() - self:GetHeight())
        local v = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(v)
        self:UpdateThumb()
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        self.child:SetWidth(w)
        self:UpdateThumb()
    end)
    return sf
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
function UI:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "FarmAtlasFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    SetBG(f, C.bg, { 0.22, 0.25, 0.30, 1 })
    tinsert(UISpecialFrames, "FarmAtlasFrame")

    -- soft accent glow at the top
    local glow = f:CreateTexture(nil, "BORDER")
    glow:SetTexture(WHITE)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", -1, -1)
    glow:SetHeight(2)
    glow:SetVertexColor(unpack(C.accent))

    -- Header ---------------------------------------------------------
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetHeight(54)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local logo = RoundIcon(header, 30)
    self.logo = logo
    logo:SetPoint("LEFT", 16, -2)
    logo.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
    logo.ring:SetVertexColor(unpack(C.accent))

    local title = Font(header, "GameFontNormalLarge", 18)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 2)
    title:SetText("|cff3fc7ebFarm|r|cffffd200Atlas|r")
    self.title = title
    local byline = Font(header, "GameFontHighlightSmall", 10, unpack(C.muted))
    byline:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    byline:SetText("v" .. ns.version .. "  ·  by Shade")
    self.byline = byline
    local sub = Font(header, "GameFontHighlightSmall", nil, unpack(C.muted))
    sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 10, 0)
    self.sub = sub

    local close = CreateFrame("Button", nil, header)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -12, -14)
    close.x = Font(close, "GameFontHighlightLarge", 16, unpack(C.muted))
    close.x:SetPoint("CENTER")
    close.x:SetText("X")
    close:SetScript("OnClick", function() f:Hide() end)
    self.closeButton = close
    close:SetScript("OnEnter", function(s) s.x:SetTextColor(1, 0.35, 0.35) end)
    close:SetScript("OnLeave", function(s) s.x:SetTextColor(unpack(C.muted)) end)

    -- language: one button (current language) with a small menu
    self.langButtons = {}
    local langBtn = FlatButton(header, "EN", 40, 22)
    langBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
    langBtn.tooltip = "Language / Nyelv / Langue / Sprache / Idioma"
    self.langButton = langBtn
    local menu = CreateFrame("Frame", nil, langBtn, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetPoint("TOPRIGHT", langBtn, "BOTTOMRIGHT", 0, -2)
    menu:SetSize(116, 6 + #ns.LANGS * 22)
    SetBG(menu, C.bg, C.accent)
    menu:EnableMouse(true)
    menu:Hide()
    for i, lg in ipairs(ns.LANGS) do
        local lb = FlatButton(menu, lg.name, 108, 20)
        lb:SetPoint("TOPLEFT", 4, -3 - (i - 1) * 22)
        lb.lang = lg.key
        lb:SetScript("OnClick", function()
            menu:Hide()
            ns:SetLang(lg.key)
        end)
        self.langButtons[#self.langButtons + 1] = lb
    end
    langBtn:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    f:HookScript("OnHide", function() menu:Hide() end)
    local prevLang = langBtn
    local gear = FlatButton(header, "", 26, 22)
    gear:SetPoint("RIGHT", prevLang, "LEFT", -10, 0)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetSize(16, 16)
    gear.icon:SetPoint("CENTER")
    gear.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    gear:SetScript("OnClick", function() if ns.Options then ns.Options:Toggle() end end)
    gear.tooltip = L("op_title") .. "  (/farm config)"
    self.gearButton = gear
    self.goalsButton = FlatButton(header, "", 70, 22)
    self.goalsButton:SetPoint("RIGHT", gear, "LEFT", -6, 0)
    self.goalsButton:SetScript("OnClick", function() if ns.Goals then ns.Goals:Toggle() end end)
    self.bestButton = FlatButton(header, "", 90, 22)
    self.bestButton:SetPoint("RIGHT", self.goalsButton, "LEFT", -6, 0)
    self.bestButton:SetScript("OnClick", function() if ns.BestFarm then ns.BestFarm:Toggle() end end)

    -- Search ---------------------------------------------------------
    local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    self.search = search
    search:SetPoint("TOPLEFT", 16 + RAIL, -60)
    search:SetPoint("TOPRIGHT", -16, -60)
    search:SetHeight(32)
    SetBG(search, C.panel)
    search:SetFontObject(ChatFontNormal)
    search:SetTextColor(unpack(C.text))
    search:SetAutoFocus(false)
    search:SetTextInsets(34, 10, 0, 0)
    local sicon = search:CreateTexture(nil, "OVERLAY")
    sicon:SetSize(14, 14)
    sicon:SetPoint("LEFT", 12, 0)
    sicon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    sicon:SetVertexColor(unpack(C.muted))
    search.placeholder = Font(search, "GameFontHighlight", nil, 0.42, 0.45, 0.52)
    search.placeholder:SetPoint("LEFT", 34, 0)
    local function UpdatePlaceholder()
        search.placeholder:SetShown(search:GetText() == "" and not search:HasFocus())
    end
    search:SetScript("OnEditFocusGained", function(s)
        s:SetBackdropBorderColor(unpack(C.accent)); UpdatePlaceholder()
    end)
    search:SetScript("OnEditFocusLost", function(s)
        s:SetBackdropBorderColor(unpack(C.border)); UpdatePlaceholder()
    end)
    search:SetScript("OnTextChanged", function()
        UpdatePlaceholder()
        UI.scroll = 0
        UI:RefreshList()
    end)
    search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(s)
        s:ClearFocus()
        local first = UI.results and UI.results[1]
        if type(first) == "table" then first = first.mainKey end
        if first ~= nil then UI:Select(first) end
    end)

    -- Section rail (left): Atlas / Recipes / Guides / Tracked -------
    self.rail = {}
    local railPrev
    for _, sec in ipairs(ns.SECTIONS) do
        local b = FlatButton(f, "", 44, 44)
        b.text:Hide()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(28, 28)
        b.icon:SetPoint("CENTER")
        b.icon:SetTexture(sec.icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if railPrev then b:SetPoint("TOP", railPrev, "BOTTOM", 0, -8)
        else b:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -60) end
        b.key = sec.key
        b:SetScript("OnClick", function()
            if sec.key == "atlas" then
                UI.cat = UI.lastAtlasCat or "all"
            else
                UI.cat = sec.key
            end
            UI.scroll = 0
            UI:RefreshChips()
            UI:RefreshList()
        end)
        b:HookScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L("sec_" .. sec.key), 1, 1, 1)
            GameTooltip:AddLine(L("sec_" .. sec.key .. "_tip"), 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        self.rail[#self.rail + 1] = b
        railPrev = b
    end

    -- Guide chips (shown in the Guides section): one profession at a time
    self.guideChips = {}
    local gprev
    for _, prof in ipairs(ns.GUIDE_ORDER or {}) do
        local chip = FlatButton(f, "", 110, 26)
        if gprev then chip:SetPoint("LEFT", gprev, "RIGHT", 4, 0)
        else chip:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10) end
        chip.prof = prof
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(16, 16)
        chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        chip.icon:SetTexture(ns.Guides[prof] and ns.Guides[prof].icon)
        -- icon-only chips (too many professions for one row) name themselves on hover
        chip:HookScript("OnEnter", function(self)
            if self.compact then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(L("cat_" .. self.prof), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        chip:HookScript("OnLeave", function() GameTooltip:Hide() end)
        chip:SetScript("OnClick", function()
            ns.db.settings.guideProf = prof
            UI.scroll = 0
            UI:RefreshChips()
            UI:RefreshList()
        end)
        chip:Hide()
        self.guideChips[#self.guideChips + 1] = chip
        gprev = chip
    end

    -- Category chips (Atlas section) ---------------------------------
    self.cat = "all"
    self.chips = {}
    local prev
    for _, cat in ipairs(ns.CATEGORIES) do
        local chip = FlatButton(f, "", 96, 26)
        chip.text:ClearAllPoints()
        chip.text:SetPoint("CENTER", 8, 0)
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(14, 14)
        chip.icon:SetPoint("RIGHT", chip.text, "LEFT", -6, 0)
        chip.icon:SetTexture(cat.icon)
        chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        else chip:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -10) end
        chip:SetScript("OnClick", function()
            UI.cat = cat.key
            UI.lastAtlasCat = cat.key
            UI.scroll = 0
            UI:RefreshChips()
            UI:RefreshList()
        end)
        chip.key = cat.key
        self.chips[#self.chips + 1] = chip
        prev = chip
    end

    -- Body -----------------------------------------------------------
    local list = CreateFrame("Frame", nil, f, "BackdropTemplate")
    self.list = list
    list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -58)
    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16 + RAIL, 44)
    list:SetWidth(LIST_W)
    SetBG(list, C.panel)

    self.count = Font(list, "GameFontHighlightSmall", nil, unpack(C.muted))
    self.count:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 2, 4)
    self.count:SetText("")

    -- "On me": only items in your bags (recipes: only what you can cook now)
    -- sits in the gap between the category chips and the list, touching neither
    local own = FlatButton(f, "", 80, 15)
    self.ownedButton = own
    own:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 0, 2)
    own.text:ClearAllPoints()
    own.text:SetPoint("CENTER", 8, 0)
    own.icon = own:CreateTexture(nil, "ARTWORK")
    own.icon:SetSize(12, 12)
    own.icon:SetPoint("RIGHT", own.text, "LEFT", -5, 0)
    own.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
    own.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    own:SetScript("OnClick", function()
        ns.db.settings.ownedOnly = not ns.db.settings.ownedOnly
        UI.scroll = 0
        UI:RefreshList()
    end)

    self.rows = {}
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.scroll = math.max(0, math.min((UI.maxScroll or 0), (UI.scroll or 0) - delta))
        UI:RefreshList(true)
    end)
    list.thumb = list:CreateTexture(nil, "OVERLAY")
    list.thumb:SetTexture(WHITE)
    list.thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 0.55)
    list.thumb:SetWidth(3)

    -- guide sub-tabs: one profession at a time
    list.guideTabs = {}
    local prevTab
    for _, prof in ipairs(ns.GUIDE_ORDER or {}) do
        local b = FlatButton(list, "", 92, 24)
        if prevTab then b:SetPoint("LEFT", prevTab, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 6, -6) end
        b.prof = prof
        b:SetScript("OnClick", function()
            ns.db.settings.guideProf = prof
            UI.scroll = 0
            UI:RefreshList()
        end)
        b:Hide()
        list.guideTabs[#list.guideTabs + 1] = b
        prevTab = b
    end

    list.empty = Font(list, "GameFontHighlight", nil, unpack(C.muted))
    list.empty:SetPoint("TOPLEFT", 16, -20)
    list.empty:SetPoint("TOPRIGHT", -16, -20)
    list.empty:SetWordWrap(true)
    list.empty:SetJustifyH("CENTER")

    local detail = CreateFrame("Frame", nil, f, "BackdropTemplate")
    self.detail = detail
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 12, 0)
    detail:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 44)
    SetBG(detail, C.panel)
    self:BuildDetail(detail)

    -- Footer ---------------------------------------------------------
    local s = function() return ns.db.settings end
    local t1 = Toggle(f, "t_pins", function() return s().showOnMap end,
        function(v) s().showOnMap = v; ns:Fire("TRACKING_CHANGED") end)
    t1:SetPoint("BOTTOMLEFT", 16, 14)
    local t2 = Toggle(f, "t_continent", function() return s().showOnContinent end,
        function(v) s().showOnContinent = v; ns:Fire("TRACKING_CHANGED") end)
    t2:SetPoint("LEFT", t1, "RIGHT", 16, 0)
    local t3 = Toggle(f, "t_learn", function() return s().learn end,
        function(v) s().learn = v end)
    t3:SetPoint("LEFT", t2, "RIGHT", 16, 0)
    local t4 = Toggle(f, "t_tooltip", function() return s().tooltip end,
        function(v) s().tooltip = v end)
    t4:SetPoint("LEFT", t3, "RIGHT", 16, 0)
    local t5 = Toggle(f, "t_minimap", function() return s().showOnMinimap end,
        function(v) s().showOnMinimap = v; ns:Fire("TRACKING_CHANGED") end)
    t5:SetPoint("LEFT", t4, "RIGHT", 16, 0)
    self.toggles = { t1, t2, t3, t4, t5 }

    local clear = FlatButton(f, "", 130, 22)
    self.clearButton = clear
    clear:SetPoint("BOTTOMRIGHT", -16, 12)
    clear:SetScript("OnClick", function() ns:ClearTracked() end)
    self.stats = Font(f, "GameFontHighlightSmall", nil, unpack(C.muted))
    self.stats:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", -2, 4)
    self.stats:SetJustifyH("RIGHT")

    f:SetScript("OnShow", function()
        UI:ApplyLocale()
        UI:RefreshAll()
    end)
    self:ApplyLocale()
end

------------------------------------------------------------------------
-- Result list
------------------------------------------------------------------------
function UI:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, self.list, "BackdropTemplate")
    row:SetHeight(ROW_H - 4)
    row:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", -9, -6 - (i - 1) * ROW_H)
    SetBG(row, C.panel, { 0, 0, 0, 0 })

    row.strip = row:CreateTexture(nil, "ARTWORK")
    row.strip:SetTexture(WHITE)
    row.strip:SetPoint("TOPLEFT", 0, 0)
    row.strip:SetPoint("BOTTOMLEFT", 0, 0)
    row.strip:SetWidth(3)

    row.icon = RoundIcon(row, 28)
    row.icon:SetPoint("LEFT", 10, 0)
    row.name = Font(row, "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -1)
    row.name:SetPoint("RIGHT", -26, 0)
    row.sub = Font(row, "GameFontHighlightSmall", nil, unpack(C.muted))
    row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 1)
    row.sub:SetPoint("RIGHT", -26, 0)

    -- red veil for recipes you don't know yet (like an item you can't use)
    row.veil = row:CreateTexture(nil, "OVERLAY", nil, 2)
    row.veil:SetTexture(WHITE)
    row.veil:SetAllPoints()
    row.veil:SetVertexColor(0.75, 0.08, 0.08, 0.22)
    row.veil:Hide()

    row.dot = row:CreateTexture(nil, "OVERLAY")
    row.dot:SetSize(8, 8)
    row.dot:SetPoint("RIGHT", -10, 0)
    row.dot:SetTexture(WHITE)
    local mask = row:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(row.dot)
    row.dot:AddMaskTexture(mask)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if self.guide then UI:GuideClick(self.guide, button) return end
        if self.recipe and button == "LeftButton" and not IsControlKeyDown() and not IsShiftKeyDown() then
            UI:RecipeClick(self.recipe.name, self.itemID)
            return
        end
        if not self.itemID then return end
        if IsControlKeyDown() then
            local g = ns:GetGoal(self.itemID)
            ns:SetGoal(self.itemID, g and g.need or 20)
            UI:Select(self.itemID)
        elseif button == "RightButton" or IsShiftKeyDown() then
            ns:ToggleTracked(self.itemID)
        else
            UI:Select(self.itemID)
        end
    end)
    row:SetScript("OnEnter", function(self)
        if UI.selected ~= self.itemID or not self.itemID then self:SetBackdropColor(unpack(C.hover)) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.guide then UI:GuideTooltip(self.guide) return end
        local rc = self.recipe
        if rc then
            ns:AddRecipeTooltip(GameTooltip, rc.name)
            if #rc.alts > 0 then
                GameTooltip:AddLine(L("known_by", table.concat(rc.alts, ", ")), 0.6, 0.6, 0.6, true)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(rc.known and L("rc_click_known") or L("rc_click_unknown"), 0.8, 0.8, 0.8)
            if self.itemID then GameTooltip:AddLine(L("rc_click_track"), 0.8, 0.8, 0.8) end
            GameTooltip:Show()
            return
        end
        local realID = ns:RealID(self.itemID)
        if realID and GetItemInfo(realID) then
            GameTooltip:SetHyperlink("item:" .. realID)
        else
            GameTooltip:AddLine(ns:GetItemName(self.itemID))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("row_hint"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("row_ctrl"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if self.guide then UI:FillGuideRow(self, self.guide) return end
        UI:StyleRow(self)
    end)
    self.rows[i] = row
    return row
end

function UI:StyleRow(row)
    local id = row.itemID
    if not id then return end
    local selected = (UI.selected == id)
    if selected then
        row:SetBackdropColor(C.accent[1] * 0.18, C.accent[2] * 0.18, C.accent[3] * 0.18, 1)
    else
        row:SetBackdropColor(unpack(C.panel))
    end
    local cat = ns:GetCategory(id)
    local cc = ns.CAT_COLORS[cat] or ns.CAT_COLORS.learned
    row.strip:SetVertexColor(cc[1], cc[2], cc[3], selected and 1 or 0.55)
    if ns:IsTracked(id) then
        row.dot:Show()
        row.dot:SetVertexColor(ns:GetTrackColor(id))
    else
        row.dot:Hide()
    end
end

local function SubLine(id)
    local data = ns.Items[id]
    local cat = ns:GetCategory(id)
    local parts = { L("cat_" .. cat) }
    local lo, hi, skill = ns:ItemLevelRange(id)
    if lo then
        if skill then parts[#parts + 1] = "|cffffd200" .. L("lvl_skill", lo) .. "|r"
        else
            local r, g, b = ns:LevelColor(lo .. "-" .. (hi or lo))
            parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
                L("lvl_range", lo .. (hi and hi ~= lo and ("-" .. hi) or "")))
        end
    end
    if data then
        local zones = {}
        for _, s in ipairs(data.spots) do zones[s.z] = true end
        local nz = 0
        for _ in pairs(zones) do nz = nz + 1 end
        if nz > 0 then parts[#parts + 1] = (nz == 1) and L("zone1") or L("zones", nz) end
    end
    local l = ns.db.learned[id]
    if l and (l.total or 0) > 0 then parts[#parts + 1] = "|cffcc8cff" .. L("looted", l.total) .. "|r" end
    return table.concat(parts, "  ·  ")
end

function UI:RefreshList(keepResults)
    if not self.frame then return end
    local recipeMode = self.cat == "recipes"
    local guideMode = self.cat == "guide"
    if not keepResults or not self.results then
        if guideMode then
            self.results = ns:GuideRows(self.search:GetText(), ns:GuideProf())
            -- jump to where you are: the first current step, with a little context above
            for i, r in ipairs(self.results) do
                if r.first then self.scroll = math.max(0, i - 3); break end
            end
        elseif recipeMode then
            self.results = ns:SearchRecipes(self.search:GetText())
            if ns.db.settings.ownedOnly then
                -- "on me": only what you can cook right now
                local keep = {}
                for _, rc in ipairs(self.results) do
                    if rc.known and rc.craft and rc.craft > 0 then keep[#keep + 1] = rc end
                end
                self.results = keep
            end
        else
            self.results = ns:Search(self.search:GetText(), self.cat)
            if ns.db.settings.ownedOnly then
                -- "on me": only what is in your bags
                local keep = {}
                for _, id in ipairs(self.results) do
                    if (ns:GetCounts(id) or 0) > 0 then keep[#keep + 1] = id end
                end
                self.results = keep
            end
        end
    end
    if self.ownedButton then
        self.ownedButton:SetShown(not guideMode)
        self.ownedButton:SetActive(ns.db.settings.ownedOnly and true or false)
        self.ownedButton.text:SetText(L(recipeMode and "own_btn_rc" or "own_btn"))
        self.ownedButton:SetWidth(self.ownedButton.text:GetStringWidth() + 34)
        self.ownedButton.tooltip = L(recipeMode and "own_tip_rc" or "own_tip")
    end
    local results = self.results
    local listH = self.list:GetHeight()
    -- guide mode: sub-tabs on top of the list
    local top = 0
    for _, b in ipairs(self.list.guideTabs or {}) do b:Hide() end
    if guideMode then self:RefreshChips() end
    local visible = math.max(1, math.floor((listH - 8 - top) / ROW_H))
    self.maxScroll = math.max(0, #results - visible)
    self.scroll = math.max(0, math.min(self.scroll or 0, self.maxScroll))

    for i = 1, math.max(visible, #self.rows) do
        local row = self:GetRow(i)
        row.veil:Hide()
        row.icon.icon:SetDesaturated(false)
        row.icon.icon:SetVertexColor(1, 1, 1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 6, -6 - top - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", -9, -6 - top - (i - 1) * ROW_H)
        local id = (i <= visible) and results[i + self.scroll]
        row.guide = nil
        if id and guideMode then
            row.recipe = nil
            row.itemID = nil
            self:FillGuideRow(row, id)
            row:Show()
        elseif id and recipeMode then
            local rc = id
            row.recipe = rc
            row.itemID = rc.mainKey
            row.icon.icon:SetTexture(rc.mainKey ~= nil and ns:GetItemIcon(rc.mainKey) or "Interface\\Icons\\INV_Scroll_03")
            local col = rc.known and "|cff66e070" or "|cffd08080"
            row.name:SetText(col .. ns:RecipeLabel(rc.name) .. "|r")
            local parts = {}
            for _, r in ipairs(rc.reagents) do
                local enough = r.need > 0 and r.have >= r.need
                local c = enough and "|cff66e070" or "|cffd0d4dc"
                parts[#parts + 1] = c .. ns:MatLabel(r.name) .. (r.need > 0 and (" " .. r.have .. "/" .. r.need) or "") .. "|r"
            end
            local lead
            if not rc.known then lead = "|cffff6666" .. L("rc_unknown") .. "|r"
            elseif rc.craft and rc.craft > 0 then lead = "|cff66e070" .. L("rc_craft", rc.craft) .. "|r"
            elseif rc.craft then lead = "|cffffaa44" .. L("rc_craft0") .. "|r" end
            row.sub:SetText((lead and (lead .. "  ·  ") or "") .. table.concat(parts, ", "))
            if row.itemID ~= nil then self:StyleRow(row) else row:SetBackdropColor(unpack(C.panel)); row.dot:Hide() end
            row.strip:SetVertexColor(rc.known and 0.3 or 0.85, rc.known and 0.9 or 0.2, rc.known and 0.35 or 0.2, 0.8)
            row.veil:SetShown(not rc.known)
            row.icon.icon:SetDesaturated(not rc.known)
            if rc.known then row.icon.icon:SetVertexColor(1, 1, 1) else row.icon.icon:SetVertexColor(1, 0.45, 0.45) end
            row:Show()
        elseif id then
            row.recipe = nil
            row.itemID = id
            row.icon.icon:SetTexture(ns:GetItemIcon(id))
            row.name:SetText(ns:GetItemColoredName(id))
            row.sub:SetText(SubLine(id))
            self:StyleRow(row)
            row:Show()
        else
            row.itemID = nil
            row.recipe = nil
            row:Hide()
        end
    end

    -- thumb
    local thumb = self.list.thumb
    if self.maxScroll > 0 then
        local trackH = listH - 12 - top
        local th = math.max(20, trackH * visible / #results)
        local pos = (self.scroll / self.maxScroll) * (trackH - th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", self.list, "TOPRIGHT", -3, -6 - top - pos)
        thumb:SetHeight(th)
        thumb:Show()
    else
        thumb:Hide()
    end

    if guideMode then
        self.list.empty:SetText(L("g_empty"))
    elseif ns.db.settings.ownedOnly then
        self.list.empty:SetText(L(recipeMode and "own_empty_rc" or "own_empty"))
    elseif recipeMode then
        self.list.empty:SetText(L("rc_empty"))
    else
        self.list.empty:SetText(L("empty"))
    end
    self.list.empty:SetShown(#results == 0)
    local n = #results
    if guideMode then
        n = 0
        for _, r in ipairs(results) do if r.kind == "step" then n = n + 1 end end
    end
    self.count:SetText(n == 1 and L("result1") or L("results", n))
end

------------------------------------------------------------------------
-- Guide rows
------------------------------------------------------------------------
local BOOK_ICON = "Interface\\Icons\\INV_Misc_Book_09"

local function GuideTitle(r)
    local s = r.step
    local range = s.from and (s.from .. "-" .. s.to) or tostring(s.at or "")
    if s.kind == "craft" then return range .. "  " .. ns:RecipeLabel(s.recipe) end
    if s.kind == "area" then
        local z = ns:ZoneLabel(s.zones[1]) .. ((#s.zones > 1) and (" +" .. (#s.zones - 1)) or "")
        return range .. "  " .. z
    end
    if s.kind == "special" then
        -- Expert / Artisan of Cooking and Fishing: a book or a quest, never a trainer
        return range .. "  " .. L(s.how == "quest" and "g_how_quest" or "g_how_book", s.rank or "")
    end
    return range .. "  " .. L("g_train", s.rank or "")
end

local function GuideSub(r)
    local s = r.step
    if s.kind == "craft" then
        local mats = ns:GuideStepMats(s)
        local t
        if mats and s.count then
            local parts = {}
            for _, m in ipairs(mats) do parts[#parts + 1] = m.total .. " " .. ns:MatLabel(m.name) end
            t = table.concat(parts, ", ")
        else
            t = s.item .. (s.extra and (" + " .. s.extra) or "")
        end
        if s.count then t = t .. "  ·  " .. L("g_crafts", s.count) end
        return t
    elseif s.kind == "area" then
        if s.nodes then
            local names = {}
            for _, n in ipairs(s.nodes) do
                local k = ns.ItemsByName[n:lower()]
                names[#names + 1] = k ~= nil and ns:GetItemName(k) or n
            end
            return table.concat(names, ", ")
        end
        return s.mobs or ns.GuideNote(s) or ns:ZoneList(s.zones)
    elseif s.kind == "special" then
        local names = {}
        local list = ns:GuideTrainers(r.prof, s.npcs)
        for _, t in ipairs(list) do names[#names + 1] = t.npc .. " (" .. (ns:ZoneLabel(t.zone) or "?") .. ")" end
        return table.concat(names, ", ")
    elseif s.kind == "train" and ns.Guides[r.prof] and ns.Guides[r.prof].ranked then
        -- only some trainers teach this rank: name the nearest ones
        local names = {}
        local list = ns:GuideTrainers(r.prof, nil, ns.RANK_CAP[s.rank])
        for i = 1, math.min(3, #list) do names[#names + 1] = list[i].npc .. " (" .. (ns:ZoneLabel(list[i].zone) or "?") .. ")" end
        if #list > 3 then names[#names + 1] = "..." end
        if #names > 0 then return table.concat(names, ", ") end
    end
    return L("g_any_trainer")
end

function UI:FillGuideRow(row, r)
    row.guide = r
    row.dot:Hide()
    local cc = ns.CAT_COLORS[r.prof] or ns.CAT_COLORS.learned
    if r.kind == "header" then
        row:SetBackdropColor(unpack(C.card))
        row.icon.icon:SetTexture(r.icon)
        local skill = r.skill and ("|cff8c96a8(" .. L("g_skill", r.skill) .. ")|r") or ("|cff8c96a8(" .. L("g_noprof") .. ")|r")
        row.name:SetText(("|cff%02x%02x%02x%s|r  %s"):format(math.floor(cc[1] * 255), math.floor(cc[2] * 255), math.floor(cc[3] * 255), ns.Upper(L("cat_" .. r.prof)), skill))
        local function OnOff(v) return v and ("|cff66e070" .. L("on") .. "|r") or ("|cffff6666" .. L("off") .. "|r") end
        row.sub:SetText(L("g_town") .. ": " .. OnOff(ns:TownAlertOn(r.prof)) .. "   ·   " .. L("g_pins") .. ": " .. OnOff(ns:TrainerPinsOn(r.prof)))
        row.strip:SetVertexColor(cc[1], cc[2], cc[3], 1)
        return
    end
    local s = r.step
    row:SetBackdropColor(unpack(r.current and { 0.07, 0.16, 0.09, 1 } or C.panel))
    local icon
    if s.kind == "craft" then
        local key = s.item and ns.ItemsByName[s.item:lower()]
        icon = key ~= nil and ns:GetItemIcon(key) or nil
    elseif s.kind == "train" or s.kind == "special" then
        icon = BOOK_ICON
    end
    row.icon.icon:SetTexture(icon or (ns.Guides[r.prof] and ns.Guides[r.prof].icon) or BOOK_ICON)
    local col = r.current and "|cff66e070" or (r.done and "|cff6c7480" or "|cffe8ecf2")
    row.name:SetText(col .. GuideTitle(r) .. "|r")
    local sub = GuideSub(r) or ""
    if r.current then sub = "|cff66e070> " .. L("g_here") .. "|r  ·  " .. sub end
    if s.faction then sub = sub .. "  |cff8c96a8[" .. (s.faction == "A" and "Alliance" or "Horde") .. "]|r" end
    row.sub:SetText(sub)
    row.strip:SetVertexColor(cc[1], cc[2], cc[3], r.current and 1 or 0.35)
end

function UI:GuideTooltip(r)
    if r.kind == "header" then
        GameTooltip:AddLine(L("cat_" .. r.prof), 1, 0.82, 0)
        GameTooltip:AddLine(r.skill and L("g_skill", r.skill) or L("g_noprof"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("g_trainers"), 1, 0.82, 0)
        local list = ns:GuideTrainers(r.prof)
        for i = 1, math.min(6, #list) do
            local t = list[i]
            local loc = (ns:ZoneLabel(t.zone) or "?") .. ((t.x and t.y) and (" %.1f, %.1f"):format(t.x, t.y) or "") .. (t.note and (" (" .. t.note .. ")") or "")
            GameTooltip:AddDoubleLine(t.npc, t.learned and L("g_exact") or "", 1, 1, 1, 0.8, 0.55, 1)
            GameTooltip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
        end
        if #list > 6 then GameTooltip:AddLine(L("more", #list - 6), 0.55, 0.59, 0.66) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("g_head_left"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L("g_head_right"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        return
    end
    local s = r.step
    GameTooltip:AddLine(GuideTitle(r), 1, 0.82, 0)
    local note = ns.GuideNote(s)
    if s.kind == "craft" then
        local mats, exact = ns:GuideStepMats(s)
        GameTooltip:AddLine(L("g_mats") .. (s.count and ("  |cffcccccc" .. L("g_crafts", s.count) .. "|r") or ""), 1, 0.82, 0)
        if mats then
            for _, m in ipairs(mats) do
                local have = ns:HaveCount(m.name)
                local right, r, g, b = "", 0.8, 0.8, 0.8
                if have then
                    right = L("g_have", have)
                    if have >= (m.total or m.per or 1) then r, g, b = 0.4, 1, 0.4 else r, g, b = 1, 0.6, 0.25 end
                end
                GameTooltip:AddDoubleLine("   " .. (m.total and (m.total .. " x ") or "") .. ns:MatLabel(m.name) .. "  |cff999999(" .. L("g_each", m.per) .. ")|r",
                    right, 1, 1, 1, r, g, b)
            end
            if exact then GameTooltip:AddLine("   " .. L("g_mats_exact"), 0.55, 0.59, 0.66, true) end
        else
            GameTooltip:AddLine("   " .. ns:MatLabel(s.item) .. (s.extra and (" + " .. s.extra) or ""), 1, 1, 1)
        end
        local srcType, sources, srcNote = ns:RecipeSources(s.recipe)
        if s.trainer then
            srcType, sources = "trainer", {}
            -- ranked trainers: list the ones who teach recipes of this skill range
            local cap = s.cap or ns:CapForSkill(s.from) -- s.cap: only higher-rank trainers teach this recipe
            if ns.Guides[r.prof] and ns.Guides[r.prof].ranked and cap > 75 then sources = ns:GuideTrainers(r.prof, nil, cap) end
        end
        if s.npcs then srcType, sources = "vendor", ns:GuideTrainers(r.prof, s.npcs) end
        if s.trainer == nil and s.note and #sources == 0 then srcNote = ns.GuideNote(s) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("rc_where"), 1, 0.82, 0)
        if srcType == "faction" then
            GameTooltip:AddLine(L("src_enemy"), 1, 0.5, 0.25, true)
        elseif srcType == "trainer" and #sources == 0 then
            GameTooltip:AddLine(L("g_any_trainer"), 0.8, 0.8, 0.8)
        elseif #sources == 0 then
            GameTooltip:AddLine(srcNote or L("src_unknown"), 0.7, 0.7, 0.7, true)
        end
        for i = 1, math.min(4, #sources) do
            local src = sources[i]
            local loc = (ns:ZoneLabel(src.zone) or "?") .. ((src.x and src.y) and (" %.1f, %.1f"):format(src.x, src.y) or "")
            if src.note then loc = loc .. " (" .. src.note .. ")" end
            if src.neutral then loc = loc .. " [" .. L("src_neutral") .. "]" end
            GameTooltip:AddDoubleLine(src.npc or "?", src.price or "", 1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
        end
        if #sources > 4 then GameTooltip:AddLine(L("more", #sources - 4), 0.55, 0.59, 0.66) end
    elseif s.kind == "area" then
        GameTooltip:AddLine(L("g_zones"), 1, 0.82, 0)
        GameTooltip:AddLine("   " .. ns:ZoneList(s.zones), 1, 1, 1, true)
        if s.nodes then
            GameTooltip:AddLine(L("g_nodes"), 1, 0.82, 0)
            for _, n in ipairs(s.nodes) do
                local k = ns.ItemsByName[n:lower()]
                GameTooltip:AddLine("   " .. (k ~= nil and ns:GetItemColoredName(k) or n), 1, 1, 1)
            end
        elseif s.mobs then
            GameTooltip:AddLine(L("g_mobs"), 1, 0.82, 0)
            GameTooltip:AddLine("   " .. s.mobs, 1, 1, 1, true)
        end
    else
        GameTooltip:AddLine(s.kind == "special" and L("g_npcs") or L("g_trainers"), 1, 0.82, 0)
        local list = ns:GuideTrainers(r.prof, s.kind == "special" and s.npcs or nil, s.kind == "train" and ns.RANK_CAP[s.rank] or nil)
        for i = 1, math.min(6, #list) do
            local t = list[i]
            local loc = (ns:ZoneLabel(t.zone) or "?") .. ((t.x and t.y) and (" %.1f, %.1f"):format(t.x, t.y) or "") .. (t.note and (" (" .. t.note .. ")") or "")
            if t.faction == "N" then loc = loc .. " [" .. L("src_neutral") .. "]" end
            GameTooltip:AddDoubleLine(t.npc, t.learned and L("g_exact") or "", 1, 1, 1, 0.8, 0.55, 1)
            GameTooltip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
        end
        if #list > 6 then GameTooltip:AddLine(L("more", #list - 6), 0.55, 0.59, 0.66) end
    end
    if note then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(note, 0.6, 0.85, 1, true)
    end
    local action, arg = ns:GuideAction(r)
    if action then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(action == "item" and L("g_click_item", ns:MatLabel(r.step.item)) or L("g_click_map"), 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

function UI:GuideClick(r, button)
    local action, arg = ns:GuideAction(r)
    if action == "area" then
        ns:SetGuideFocus(arg.prof, arg.step)
        if arg.zone then ns:ShowPoint({ zone = arg.zone }) end
    elseif action == "pins" then
        if button == "RightButton" then
            ns:SetTrainerPins(arg, not ns:TrainerPinsOn(arg))
        else
            ns:SetTownAlert(arg, not ns:TownAlertOn(arg))
        end
        self:RefreshList(true)
    elseif action == "item" then
        -- cooking step: the material is tracked and the map opens where to farm it
        self:Select(arg)
        self:OpenBest(arg)
    elseif action == "point" then
        ns:ShowPoint(arg)
    end
end

function UI:RefreshChips()
    local section = ns:SectionOf(self.cat)
    for _, b in ipairs(self.rail or {}) do b:SetActive(b.key == section) end
    for _, chip in ipairs(self.chips) do
        chip:SetShown(section == "atlas")
        chip:SetActive(chip.key == self.cat)
    end
    local current = section == "guide" and ns:GuideProf()
    -- all profession chips on one row: icon + name when they fit, else only
    -- the chosen one keeps its name and the others show their icon
    local total, widths = 0, {}
    for i, chip in ipairs(self.guideChips or {}) do
        chip:SetShown(section == "guide")
        chip.text:SetText(L("cat_" .. chip.prof))
        widths[i] = math.max(84, math.floor((chip.text:GetStringWidth() or 0) + 16 + 22))
        total = total + widths[i] + (i > 1 and 4 or 0)
        chip:SetActive(chip.prof == current)
    end
    local room = (self.search and self.search.GetWidth and self.search:GetWidth()) or 0
    local compact = room > 0 and total > room
    for i, chip in ipairs(self.guideChips or {}) do
        local small = compact and chip.prof ~= current
        chip.compact = small
        chip.text:SetShown(not small)
        chip.text:ClearAllPoints()
        chip.icon:ClearAllPoints()
        if small then
            chip:SetWidth(34)
            chip.icon:SetPoint("CENTER")
        else
            chip:SetWidth(widths[i])
            chip.text:SetPoint("CENTER", 10, 0)
            chip.icon:SetPoint("RIGHT", chip.text, "LEFT", -5, 0)
        end
    end
end

function UI:RefreshStats()
    local items, spots = ns:CountLearned()
    local text = L("stats", ns:CountTracked(), items, spots)
    local sharers = ns:CountSharers()
    if sharers > 0 then text = text .. L("sync_status", sharers) end
    self.stats:SetText(text)
end

------------------------------------------------------------------------
-- Detail pane
------------------------------------------------------------------------
-- Put an item link into the chat input, in the chat type you are using
-- (party, guild, whisper...): the open chat box, else the last one you typed
-- in (it keeps its chat type), else the default one. The chat functions moved
-- between client versions (ChatFrameUtil in the Midnight-based client,
-- ChatEdit_* in older ones), so both are looked up.
local function ChatFn(name)
    local U = ChatFrameUtil
    return (U and U[name]) or _G["ChatEdit_" .. name]
end

local function CallBox(name)
    local fn = ChatFn(name)
    if not fn then return end
    local ok, eb = pcall(fn)
    if ok and type(eb) == "table" and eb.Insert then return eb end
end

function UI:PutLinkInChat(link)
    if type(link) ~= "string" then return false end
    -- the search box keeps its focus after a click: a link sent while it has
    -- focus would land in the search (shift-click helper), not in the chat
    if self.search and self.search.ClearFocus then self.search:ClearFocus() end
    local eb = CallBox("GetActiveWindow")
    local active = eb ~= nil
    eb = eb or CallBox("GetLastActiveWindow") or CallBox("ChooseBoxForSend")
        or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame1EditBox
    if not eb then return false end
    local ok = pcall(function()
        if not active then
            local activate = ChatFn("ActivateChat")
            if activate then activate(eb) else eb:Show() end
        end
        eb:SetFocus()
        eb:Insert(link)
    end)
    return ok and type(eb:GetText()) == "string" and eb:GetText():find(link, 1, true) ~= nil
end

function UI:BuildDetail(d)
    -- top block
    d.icon = RoundIcon(d, 46)
    d.icon:SetPoint("TOPLEFT", 16, -16)
    d.name = Font(d, "GameFontNormalLarge", 16)
    d.name:SetPoint("TOPLEFT", d.icon, "TOPRIGHT", 12, -2)
    d.name:SetPoint("RIGHT", -150, 0)

    -- goal input (top right)
    d.goalBtn = FlatButton(d, "", 34, 22)
    d.goalBtn:SetPoint("TOPRIGHT", -16, -16)
    d.goalEdit = CreateFrame("EditBox", nil, d, "BackdropTemplate")
    d.goalEdit:SetSize(44, 22)
    d.goalEdit:SetPoint("RIGHT", d.goalBtn, "LEFT", -4, 0)
    SetBG(d.goalEdit, C.card)
    d.goalEdit:SetFontObject(GameFontHighlightSmall)
    d.goalEdit:SetJustifyH("CENTER")
    d.goalEdit:SetAutoFocus(false)
    d.goalEdit:SetNumeric(true)
    d.goalEdit:SetMaxLetters(4)
    local function ApplyGoal()
        d.goalEdit:ClearFocus()
        if UI.selected then ns:SetGoal(UI.selected, d.goalEdit:GetNumber()) end
    end
    d.goalEdit:SetScript("OnEnterPressed", ApplyGoal)
    d.goalEdit:SetScript("OnEscapePressed", function(e) e:ClearFocus() end)
    d.goalBtn:SetScript("OnClick", ApplyGoal)
    d.goalLabel = Font(d, "GameFontHighlightSmall", nil, unpack(C.gold))
    d.goalLabel:SetPoint("RIGHT", d.goalEdit, "LEFT", -6, 0)
    d.goalLabel:SetJustifyH("RIGHT")

    d.inv = Font(d, "GameFontHighlightSmall", nil, unpack(C.muted))
    d.badge = Font(d, "GameFontHighlightSmall")
    d.badge:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
    d.inv:SetPoint("LEFT", d.badge, "RIGHT", 12, 0)
    d.inv:SetPoint("RIGHT", d, "RIGHT", -16, 0)

    d.track = FlatButton(d, "", 140, 24)
    d.track:SetPoint("BOTTOMLEFT", d.icon, "BOTTOMRIGHT", 12, -14)
    d.track:SetScript("OnClick", function()
        if UI.selected then ns:ToggleTracked(UI.selected) end
    end)
    d.open = FlatButton(d, "", 120, 24)
    d.open:SetPoint("LEFT", d.track, "RIGHT", 8, 0)
    d.open:SetScript("OnClick", function() UI:OpenBest(UI.selected) end)
    d.link = FlatButton(d, "", 56, 24)
    d.link:SetPoint("LEFT", d.open, "RIGHT", 8, 0)
    d.link:SetScript("OnClick", function()
        local id = UI.selected
        if not id then return end
        local _, link = ns:ItemInfo(id)
        if link then
            UI:PutLinkInChat(link)
        else
            -- item not in the client cache yet: ask for it and try once more
            local rid = ns:RealID(id)
            if rid and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, rid) end
            C_Timer.After(0.5, function()
                local _, l = ns:ItemInfo(id)
                if l then UI:PutLinkInChat(l) end
            end)
        end
    end)

    d.uses = Font(d, "GameFontHighlightSmall", nil, 0.62, 0.86, 0.45)
    d.uses:SetPoint("TOPLEFT", d.icon, "BOTTOMLEFT", 0, -26)
    d.uses:SetPoint("RIGHT", -16, 0)
    d.uses:SetWordWrap(true)

    local sep = d:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(WHITE)
    sep:SetVertexColor(unpack(C.border))
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", d.uses, "BOTTOMLEFT", 0, -10)
    sep:SetPoint("RIGHT", -16, 0)
    d.sep = sep

    d.scroll = ScrollArea(d)
    d.scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -8)
    d.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    d.cards = {}
    d.heads = {}

    -- welcome state
    d.welcome = Font(d, "GameFontHighlight", nil, unpack(C.muted))
    d.welcome:SetPoint("TOPLEFT", 24, -30)
    d.welcome:SetPoint("RIGHT", -24, 0)
    d.welcome:SetWordWrap(true)
    d.welcome:SetSpacing(4)
    d.welcome:SetText(L("welcome"))
end

-- track the item and open the map on the best farm zone for your level
function UI:OpenBest(id)
    if id == nil then return end
    local data = ns.Items[id]
    if data and data.spots and data.spots[1] then
        ns:ShowOnMap(self:BestSpot(data).z, id)
    else
        local lz = ns:GetLearnedZones(id)[1]
        if lz then
            ns:SetTracked(id, true)
            ns:OpenMapID(lz.mapID)
        end
    end
end

function UI:BestSpot(data)
    local level = UnitLevel("player") or 60
    local best, bestScore
    for i, s in ipairs(data.spots) do
        local lo, hi = ns:ParseLevels(s.lvl)
        local score = i * 0.1
        if hi and hi > level + 2 then score = score + 100 end -- too dangerous
        if not bestScore or score < bestScore then best, bestScore = s, score end
    end
    return best or data.spots[1]
end

local function GetHead(d, i)
    local h = d.heads[i]
    if h then return h end
    h = Font(d.scroll.child, "GameFontNormal", 12, unpack(C.gold))
    d.heads[i] = h
    return h
end

local function GetCard(d, i)
    local card = d.cards[i]
    if card then return card end
    card = CreateFrame("Button", nil, d.scroll.child, "BackdropTemplate")
    SetBG(card, C.card)
    card.strip = card:CreateTexture(nil, "ARTWORK")
    card.strip:SetTexture(WHITE)
    card.strip:SetPoint("TOPLEFT", 1, -1)
    card.strip:SetPoint("BOTTOMLEFT", 1, 1)
    card.strip:SetWidth(3)
    card.title = Font(card, "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 14, -8)
    card.level = Font(card, "GameFontHighlightSmall")
    card.level:SetPoint("TOPRIGHT", -12, -9)
    card.level:SetJustifyH("RIGHT")
    card.line2 = Font(card, "GameFontHighlightSmall", nil, unpack(C.text))
    card.line2:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.line2:SetPoint("RIGHT", -12, 0)
    card.line3 = Font(card, "GameFontHighlightSmall", nil, unpack(C.muted))
    card.line3:SetPoint("TOPLEFT", card.line2, "BOTTOMLEFT", 0, -3)
    card.line3:SetPoint("RIGHT", -12, 0)
    card.go = Font(card, "GameFontHighlightSmall", nil, unpack(C.accent))
    card.go:SetPoint("BOTTOMRIGHT", -12, 8)
    card.go:SetJustifyH("RIGHT")
    card.go:SetText(L("show_on_map"))
    card.go:Hide()
    -- red veil: a recipe you don't know yet
    card.veil = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.veil:SetTexture(WHITE)
    card.veil:SetPoint("TOPLEFT", 1, -1)
    card.veil:SetPoint("BOTTOMRIGHT", -1, 1)
    card.veil:SetVertexColor(0.75, 0.08, 0.08, 0.22)
    card.veil:Hide()
    card:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(C.hover))
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.6)
        if (self.zoneKey or self.mapID or self.point) and not self.recipe then self.go:Show() end
        if self.recipe then
            -- what the recipe makes: the game's own item tooltip when known
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            ns:AddRecipeTooltip(GameTooltip, self.recipe)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(self.unknown and L("rc_click_unknown") or L("rc_click_known"), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(C.card))
        self:SetBackdropBorderColor(unpack(C.border))
        self.go:Hide()
        GameTooltip:Hide()
    end)
    card:SetScript("OnClick", function(self)
        if self.recipe then
            UI:RecipeClick(self.recipe)
        elseif self.point then
            ns:ShowPoint(self.point)
        elseif self.mapID then
            ns:SetTracked(UI.selected, true)
            ns:OpenMapID(self.mapID)
        elseif self.zoneKey then
            ns:ShowOnMap(self.zoneKey, UI.selected)
        end
    end)
    d.cards[i] = card
    return card
end

function UI:RefreshDetail()
    local d = self.detail
    if not d then return end
    local id = self.selected
    local hasItem = id ~= nil
    for _, w in ipairs({ d.icon, d.name, d.badge, d.inv, d.track, d.open, d.link, d.uses, d.sep, d.scroll,
        d.goalBtn, d.goalEdit, d.goalLabel }) do
        w:SetShown(hasItem)
    end
    d.welcome:SetShown(not hasItem)
    if not hasItem then return end

    local data = ns.Items[id]
    local cat = ns:GetCategory(id)
    local cc = ns.CAT_COLORS[cat] or ns.CAT_COLORS.learned

    d.icon.icon:SetTexture(ns:GetItemIcon(id))
    local _, quality = ns:GetItemName(id)
    local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if qc then d.icon.ring:SetVertexColor(qc.r, qc.g, qc.b) end
    d.name:SetText(ns:GetItemColoredName(id))
    d.badge:SetText(("|cff%02x%02x%02x%s|r"):format(cc[1] * 255, cc[2] * 255, cc[3] * 255, ns.Upper(L("cat_" .. cat))))
    if data and data.unverified then
        d.badge:SetText(d.badge:GetText() .. "  |cffff9933" .. L("unverified") .. "|r")
    end
    local ahPrice, ahSource = ns:GetAHPrice(id)
    if ahPrice then
        d.badge:SetText(d.badge:GetText() .. "  |cffffd200" .. L("ah_price", ns:Money(ahPrice), ahSource) .. "|r")
    end

    local tracked = ns:IsTracked(id)
    d.track:SetActive(tracked)
    d.track.text:SetText(tracked and L("tracking") or L("track"))
    Fit(d.track, 140)

    local goal = ns:GetGoal(id)
    if not d.goalEdit:HasFocus() then d.goalEdit:SetText(goal and tostring(goal.need) or "") end
    local bags, bank, alts = ns:GetCounts(id)
    d.inv:SetText(L("inv_line", bags, bank, alts))

    if data and data.uses and #data.uses > 0 then
        d.uses:SetText(L("used_for") .. "  " .. table.concat(data.uses, ",  "))
    else
        d.uses:SetText("")
    end

    -- cards
    for _, c in ipairs(d.cards) do c:Hide() end
    for _, h in ipairs(d.heads) do h:Hide() end
    local child = d.scroll.child
    local width = d.scroll:GetWidth() - 10
    local y, ci, hi = 0, 0, 0
    local playerLevel = UnitLevel("player") or 1

    local function Head(text)
        hi = hi + 1
        local h = GetHead(d, hi)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -y)
        h:SetText(text)
        h:Show()
        y = y + 20
    end

    local function Card(title, lvlText, lr, lg, lb, l2, l3, strip, zoneKey, mapID, point, recipe, unknown)
        ci = ci + 1
        local card = GetCard(d, ci)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
        card:SetWidth(width)
        card.title:SetText(title)
        card.level:SetText(lvlText or "")
        card.level:SetTextColor(lr or 1, lg or 1, lb or 1)
        card.line2:SetText(l2 or "")
        card.line3:SetText(l3 or "")
        card.strip:SetVertexColor(strip[1], strip[2], strip[3], 1)
        card.zoneKey, card.mapID, card.point = zoneKey, mapID, point
        card.recipe = recipe
        card.unknown = unknown and true or false
        card.veil:SetShown(card.unknown)
        local hgt = 30 + (l2 and l2 ~= "" and 14 or 0) + (l3 and l3 ~= "" and 14 or 0)
        card:SetHeight(math.max(hgt, 40))
        card:Show()
        y = y + card:GetHeight() + 6
    end

    -- Recipes that use this ingredient ---------------------------------
    local recipes = ns:RecipesForItem(id)
    if #recipes > 0 then
        Head(L("recipes_head") .. "  |cff8c96a8(" .. #recipes .. ")|r")
        if not ns:HasScannedRecipes() then
            Card(L("scan_hint"), nil, nil, nil, nil, nil, nil, C.gold)
        end
        local srcLabel = { trainer = L("src_trainer"), vendor = L("src_vendor"), quest = L("src_quest"),
            drop = L("src_drop"), faction = L("src_faction") }
        for _, recipe in ipairs(recipes) do
            local mine, altsKnow = ns:RecipeKnown(recipe)
            local status, sr, sg, sb, strip
            if mine then
                status, sr, sg, sb, strip = L("known"), 0.3, 0.9, 0.35, { 0.3, 0.9, 0.35 }
            else
                status, sr, sg, sb, strip = L("not_known"), 1, 0.4, 0.4, { 0.85, 0.2, 0.2 }
            end
            local l2, l3, point
            if not mine then
                local srcType, sources, note = ns:RecipeSources(recipe)
                local parts = {}
                for i = 1, math.min(2, #sources) do
                    local s = sources[i]
                    local loc = ns:ZoneLabel(s.zone) or "?"
                    if s.x and s.y then loc = loc .. (" %.1f, %.1f"):format(s.x, s.y) end
                    local txt = (s.npc or "?") .. " - " .. loc
                    if s.price then txt = txt .. "  " .. s.price end
                    if s.note then txt = txt .. " (" .. s.note .. ")" end
                    if s.neutral then txt = txt .. " |cff8c96a8[" .. L("src_neutral") .. "]|r" end
                    if s.learned then txt = txt .. " |cffcc8cff" .. L("seen") .. "|r"
                    elseif s.shared then txt = txt .. " |cffcc8cff" .. L("src_shared") .. "|r" end
                    parts[#parts + 1] = txt
                end
                local label = srcLabel[srcType]
                if #parts > 0 then
                    l2 = (label and ("|cffffd200" .. label .. ":|r ") or "") .. parts[1]
                    if parts[2] then l3 = parts[2] end
                    if #sources > 2 then l3 = (l3 and (l3 .. "   ") or "") .. "|cff8c96a8" .. L("more", #sources - 2) .. "|r" end
                    local s1 = sources[1]
                    if s1.zone or s1.mapID then
                        point = { zone = s1.zone, mapID = s1.mapID, x = s1.x, y = s1.y,
                            label = recipe, sub = (s1.npc or "?") .. (s1.price and ("  " .. s1.price) or "") }
                    end
                elseif srcType == "faction" then
                    l2 = "|cffff8040" .. L("src_enemy") .. "|r"
                elseif label then
                    l2 = "|cffffd200" .. label .. "|r" .. (note and (" - " .. note) or "")
                else
                    l2 = L("src_unknown")
                end
            end
            if #altsKnow > 0 then
                local t = L("known_by", table.concat(altsKnow, ", "))
                l3 = l3 and (l3 .. "   " .. t) or t
            end
            Card(ns:RecipeLabel(recipe), status, sr, sg, sb, l2, l3, strip, nil, nil, point, recipe, not mine)
        end
        y = y + 6
    end

    if data and #data.spots > 0 then
        Head(L("where") .. "  |cff8c96a8" .. L("areas", #data.spots) .. "|r")
        local best = self:BestSpot(data)
        for _, s in ipairs(data.spots) do
            local lr, lg, lb = 1, 1, 1
            local isSkill = s.lvl and tostring(s.lvl):find("skill")
            if s.lvl and not isSkill then lr, lg, lb = ns:LevelColor(s.lvl) end
            local lvlText = s.lvl and (isSkill and s.lvl or (L("lv") .. " " .. s.lvl)) or ""
            if s.drop then lvlText = lvlText .. "   |cff66ff66" .. s.drop .. "|r" end
            local _, hiLvl = ns:ParseLevels(s.lvl)
            local title = ns:ZoneName(s.z)
            if s == best then title = title .. "  |cff3fc7eb" .. L("recommended") .. "|r" end
            if hiLvl and not isSkill and hiLvl > playerLevel + 2 then
                title = title .. "  |cffff5555" .. L("dangerous") .. "|r"
            end
            local l3 = s.note
            local lz = ns:ResolveZone(s.z)
            if lz then
                for _, z in ipairs(ns:GetLearnedZones(id)) do
                    if z.mapID == lz then
                        l3 = (l3 and (l3 .. "  ·  ") or "") .. "|cffcc8cff" .. L("looted_here", z.n) .. "|r"
                    end
                end
            end
            Card(title, lvlText, lr, lg, lb, s.mobs, l3, { lr, lg, lb }, s.z)
        end
        y = y + 6
    end

    -- Vendor-bought reagent ---------------------------------------------
    if data and data.vendor then
        Head(L("buy_head"))
        Card(L("buy_where"), nil, nil, nil, nil, data.vendor, nil, C.gold)
        y = y + 6
    end

    local learned = ns:GetLearnedZones(id)
    if #learned > 0 then
        Head(L("discoveries") .. "  |cff8c96a8" .. L("from_loot") .. "|r")
        local mobs = ns:GetLearnedMobs(id)
        local mobNames = {}
        for i = 1, math.min(4, #mobs) do
            local m = mobs[i]
            local label = m.name .. (m.lvl and (" (" .. m.lvl .. ")") or "")
            if m.rate then
                local txt = L("drop_rate", label, math.floor(m.rate * 100 + 0.5), m.n, m.kills)
                local v = ns:ValuePer100(id, m.rate)
                if v then txt = txt .. " |cffffd200" .. L("per100", ns:Money(v)) .. "|r" end
                mobNames[#mobNames + 1] = txt
            else
                mobNames[#mobNames + 1] = L("drop_count", label, m.n)
            end
        end
        for _, lz in ipairs(learned) do
            local info = C_Map.GetMapInfo(lz.mapID)
            local zk = ns:ZoneKeyForMap(lz.mapID)
            Card(zk and ns:ZoneName(zk) or (info and info.name) or ("Map " .. lz.mapID), L("looted", lz.n), 0.8, 0.55, 1,
                L("spots_rec", #lz.cells),
                #mobNames > 0 and (L("top_sources") .. table.concat(mobNames, ", ")) or nil,
                ns.CAT_COLORS.learned, nil, lz.mapID)
        end
    elseif (not data or #data.spots == 0) and not (data and data.vendor) then
        Head(L("no_data"))
        Card(L("loot_once"), nil, nil, nil, nil,
            L("will_remember"), nil, ns.CAT_COLORS.learned)
    end

    d.scroll:SetContentHeight(y)
end

------------------------------------------------------------------------
-- Public
------------------------------------------------------------------------
------------------------------------------------------------------------
-- Recipe click: known -> open the profession window on it,
-- unknown -> a small box: you can't make it yet, and where to learn it
------------------------------------------------------------------------
function UI:RecipeClick(recipe, itemID)
    if not recipe then return end
    if itemID ~= nil and itemID ~= self.selected then self:Select(itemID) end
    local mine = ns:RecipeKnown(recipe)
    if mine then
        if self.recipeBox then self.recipeBox:Hide() end
        ns:OpenCraft(recipe)
    else
        self:ShowRecipeBox(recipe)
    end
end

local function SourceText(s)
    local loc = ns:ZoneLabel(s.zone) or "?"
    if s.x and s.y then loc = loc .. (" %.1f, %.1f"):format(s.x, s.y) end
    local txt = "|cffffffff" .. (s.npc or "?") .. "|r  -  " .. loc
    if s.price then txt = txt .. "   |cffffd200" .. s.price .. "|r" end
    if s.note then txt = txt .. "  (" .. s.note .. ")" end
    if s.neutral then txt = txt .. "  |cff8c96a8[" .. L("src_neutral") .. "]|r" end
    if s.learned then txt = txt .. "  |cffcc8cff" .. L("seen") .. "|r"
    elseif s.shared then txt = txt .. "  |cffcc8cff" .. L("src_shared") .. "|r" end
    return txt
end

function UI:ShowRecipeBox(recipe)
    local b = self.recipeBox
    if not b then
        b = CreateFrame("Frame", "FarmAtlasRecipeBox", UIParent, "BackdropTemplate")
        self.recipeBox = b
        b:SetSize(360, 120)
        b:SetFrameStrata("DIALOG")
        b:SetToplevel(true)
        b:SetClampedToScreen(true)
        b:EnableMouse(true)
        SetBG(b, C.bg, { 0.75, 0.2, 0.2, 1 })
        tinsert(UISpecialFrames, "FarmAtlasRecipeBox")
        b.strip = b:CreateTexture(nil, "ARTWORK")
        b.strip:SetTexture(WHITE)
        b.strip:SetPoint("TOPLEFT", 1, -1)
        b.strip:SetPoint("TOPRIGHT", -1, -1)
        b.strip:SetHeight(3)
        b.strip:SetVertexColor(0.85, 0.2, 0.2, 1)
        b.head = Font(b, "GameFontNormal", 13, 1, 0.4, 0.4)
        b.head:SetPoint("TOPLEFT", 14, -12)
        b.head:SetPoint("RIGHT", -34, 0)
        b.name = Font(b, "GameFontHighlight", 13, unpack(C.text))
        b.name:SetPoint("TOPLEFT", b.head, "BOTTOMLEFT", 0, -4)
        b.name:SetPoint("RIGHT", -14, 0)
        b.body = Font(b, "GameFontHighlightSmall", nil, unpack(C.muted))
        b.body:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -10)
        b.body:SetPoint("RIGHT", -14, 0)
        b.body:SetWordWrap(true)
        b.body:SetJustifyV("TOP")
        b.body:SetSpacing(3)
        local x = CreateFrame("Button", nil, b)
        x:SetSize(22, 22)
        x:SetPoint("TOPRIGHT", -6, -6)
        x.t = Font(x, "GameFontNormal", 14, unpack(C.muted))
        x.t:SetPoint("CENTER")
        x.t:SetText("x")
        x:SetScript("OnClick", function() b:Hide() end)
        x:SetScript("OnEnter", function(s) s.t:SetTextColor(1, 1, 1) end)
        x:SetScript("OnLeave", function(s) s.t:SetTextColor(unpack(C.muted)) end)
        b.map = FlatButton(b, "", 150, 22)
        b.map:SetPoint("BOTTOMLEFT", 14, 12)
        b.map:SetScript("OnClick", function(s)
            if s.point then ns:ShowPoint(s.point) end
        end)
        b.ok = FlatButton(b, "OK", 70, 22)
        b.ok:SetPoint("BOTTOMRIGHT", -14, 12)
        b.ok:SetScript("OnClick", function() b:Hide() end)
    end
    b:ClearAllPoints()
    if self.frame and self.frame:IsShown() and self.detail then
        b:SetPoint("TOP", self.detail, "TOP", 0, -40)
    else
        b:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    end

    b.head:SetText(L("rc_cant"))
    b.name:SetText(ns:RecipeLabel(recipe))
    local lines = {}
    local srcType, sources, note = ns:RecipeSources(recipe)
    local srcLabel = { trainer = L("src_trainer"), vendor = L("src_vendor"), quest = L("src_quest"),
        drop = L("src_drop"), faction = L("src_faction") }
    local label = srcLabel[srcType]
    local point
    if sources and #sources > 0 then
        lines[#lines + 1] = "|cffffd200" .. L("rc_where") .. (label and ("  (" .. label .. ")") or "") .. "|r"
        for i = 1, math.min(5, #sources) do
            lines[#lines + 1] = SourceText(sources[i])
        end
        if #sources > 5 then lines[#lines + 1] = L("more", #sources - 5) end
        for _, s in ipairs(sources) do
            if s.zone or s.mapID then
                point = { zone = s.zone, mapID = s.mapID, x = s.x, y = s.y, label = recipe,
                    sub = (s.npc or "?") .. (s.price and ("  " .. s.price) or "") }
                break
            end
        end
    elseif srcType == "faction" then
        lines[#lines + 1] = "|cffff8040" .. L("src_enemy") .. "|r"
    elseif label then
        lines[#lines + 1] = "|cffffd200" .. label .. "|r" .. (note and (" - " .. note) or "")
    else
        lines[#lines + 1] = L("src_unknown")
    end
    local _, alts = ns:RecipeKnown(recipe)
    if alts and #alts > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = "|cffcc8cff" .. L("known_by", table.concat(alts, ", ")) .. "|r"
    end
    b.body:SetText(table.concat(lines, "\n"))
    b.map.point = point
    b.map.text:SetText(L("show_on_map"))
    b.map:SetShown(point ~= nil)
    local h = 12 + 16 + 4 + 16 + 10 + (b.body:GetStringHeight() or 40) + 46
    b:SetHeight(math.max(120, math.floor(h)))
    b:Show()
end

function UI:Select(itemID)
    self.selected = itemID
    self.detail.scroll:SetVerticalScroll(0)
    self:RefreshList(true)
    self:RefreshDetail()
end

function UI:RefreshAll()
    if not (self.frame and self.frame:IsShown()) then return end
    self:RefreshChips()
    self:RefreshList()
    self:RefreshDetail()
    self:RefreshStats()
end

function UI:Open(query, itemID)
    self:Build()
    self.frame:Show()
    if query then
        self.search:SetText(query)
        self.cat = "all"
        self:RefreshAll()
        if self.results and #self.results == 1 then self:Select(self.results[1]) end
    end
    if itemID then self:Select(itemID) end
end

function UI:Toggle()
    self:Build()
    self.frame:SetShown(not self.frame:IsShown())
end

function UI:ApplyLocale()
    if not self.frame then return end
    self.sub:SetText(L("subtitle"))
    self.search.placeholder:SetText(L("placeholder"))
    for _, chip in ipairs(self.chips) do
        chip.text:SetText(L("cat_" .. chip.key))
        chip:SetWidth(math.max(96, math.floor((chip.text:GetStringWidth() or 0) + 40)))
    end
    self.list.empty:SetText(L("empty"))
    local d = self.detail
    d.open.text:SetText(L("open_best"))
    Fit(d.open, 120)
    d.link.text:SetText(L("link"))
    Fit(d.link, 56)
    d.link.tooltip = L("link_tip")
    d.welcome:SetText(L("welcome"))
    for _, c in ipairs(d.cards) do c.go:SetText(L("show_on_map")) end
    self.clearButton.text:SetText(L("clear"))
    Fit(self.clearButton, 130)
    for _, t in ipairs(self.toggles) do t:Update() end
    for _, lb in ipairs(self.langButtons) do lb:SetActive(lb.lang == ns:Lang()) end
    if self.langButton then self.langButton.text:SetText(ns:Lang():upper()) end
    self.goalsButton.text:SetText(L("goals_btn"))
    Fit(self.goalsButton, 70)
    self.bestButton.text:SetText("|cffffd200" .. L("bf_btn") .. "|r")
    Fit(self.bestButton, 90)
    d.goalLabel:SetText(L("goal_label"))
    d.goalBtn.text:SetText(L("goal_set"))
    Fit(d.goalBtn, 34)
    d.goalBtn.tooltip = L("goal_tip")
end

ns:On("LANG_CHANGED", function()
    UI:ApplyLocale()
    UI:RefreshAll()
end)
ns:On("TRACKING_CHANGED", function() UI:RefreshAll() end)
ns:On("INVENTORY_CHANGED", function() UI:RefreshAll() end)
ns:On("RECIPES_CHANGED", function() UI:RefreshAll() end)
ns:On("GOALS_CHANGED", function() UI:RefreshAll() end)
ns:On("LEARNED_CHANGED", function() UI:RefreshAll() end)
ns:On("ITEM_INFO", function() UI:RefreshAll() end)

------------------------------------------------------------------------
-- Quick search
--   Alt + click any item (bags, chat link, recipe reagent) -> FarmAtlas opens on it
--   Shift + click an item while the FarmAtlas search box is focused -> its name is typed in
-- Only post-hooks (hooksecurefunc): nothing of Blizzard's behaviour is replaced.
------------------------------------------------------------------------
local function OpenForLink(link)
    if type(link) ~= "string" or not link:find("item:") then return end
    local key = ns:KeyForLink(link)
    local name = link:match("%[(.-)%]")
    if key ~= nil then
        UI:Open(ns:GetItemName(key), key)
    elseif name then
        UI:Open(name)
    end
end

local function SearchHasFocus()
    return UI.search and UI.frame and UI.frame:IsShown() and UI.search:HasFocus()
end

local function TypeLinkIntoSearch(link)
    if not SearchHasFocus() or type(link) ~= "string" then return end
    local key = link:find("item:") and ns:KeyForLink(link)
    local name = (key ~= nil and key ~= false) and ns:GetItemName(key) or link:match("%[(.-)%]")
    if name then
        UI.search:SetText(name)
        UI.search:SetCursorPosition(#name)
        UI.cat = "all"
        UI:RefreshAll()
    end
end

if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
        if IsAltKeyDown() and not IsControlKeyDown() then
            OpenForLink(link)
        elseif IsShiftKeyDown() then
            TypeLinkIntoSearch(link)
        end
    end)
end
if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", function(link) TypeLinkIntoSearch(link) end)
end
-- the Midnight-based client moved it into ChatFrameUtil
if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link) TypeLinkIntoSearch(link) end)
end
-- chat links: Alt + click
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link, text)
        if IsAltKeyDown() and type(link) == "string" and link:find("^item:") then
            OpenForLink(text or ("|H" .. link .. "|h[?]|h"))
        end
    end)
end

------------------------------------------------------------------------
-- Fancy look (experimental, Settings > General > "Fancy look"): an ornate
-- frame, a marble backdrop, the zone you stand in painted behind the header
-- and the farm zone of the selected item behind its details. Only visuals:
-- every widget keeps working the same; turning it off needs a /reload.
------------------------------------------------------------------------
do
    local function Fancy() return not (ns.db and ns.db.settings and ns.db.settings.fancy == false) end

    local function TryTexture(tex, path)
        local ok, res = pcall(tex.SetTexture, tex, path)
        return ok and res ~= false
    end

    -- a clipped window onto a zone's map art, centred on (cx, cy) (0..1)
    local function MapArt(parent, level)
        local clip = CreateFrame("Frame", nil, parent)
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(level)
        clip.canvas = CreateFrame("Frame", nil, clip)
        clip.canvas:SetFrameLevel(level)
        clip.tiles = {}
        clip.shade = CreateFrame("Frame", nil, clip)
        clip.shade:SetAllPoints()
        clip.shade:SetFrameLevel(level + 1)
        return clip
    end

    local function ShowMapArt(clip, mapID, cx, cy, zoom, alpha)
        for _, t in ipairs(clip.tiles) do t:Hide() end
        if not (mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then clip:Hide(); return false end
        local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
        local ok2, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        local L1 = ok and layers and layers[1]
        if not (L1 and ok2 and textures and #textures > 0 and L1.layerWidth > 0 and L1.tileWidth > 0) then clip:Hide(); return false end
        local W, H = clip:GetWidth(), clip:GetHeight()
        if not W or W < 10 or not H or H < 10 then clip:Hide(); return false end
        local cols = math.ceil(L1.layerWidth / L1.tileWidth)
        local rows = math.ceil(L1.layerHeight / L1.tileHeight)
        local scale = math.max(W * (zoom or 1.6) / L1.layerWidth, H / L1.layerHeight)
        local mw, mh = L1.layerWidth * scale, L1.layerHeight * scale
        local ox = math.min(0, math.max(W - mw, W / 2 - (cx or 0.5) * mw))
        local oy = math.min(0, math.max(H - mh, H / 2 - (cy or 0.5) * mh))
        local cv = clip.canvas
        cv:ClearAllPoints()
        cv:SetPoint("TOPLEFT", clip, "TOPLEFT", ox, -oy)
        cv:SetSize(mw, mh)
        local tw, th = L1.tileWidth * scale, L1.tileHeight * scale
        local i = 0
        for r = 0, rows - 1 do
            for c = 0, cols - 1 do
                i = i + 1
                local t = clip.tiles[i]
                if not t then t = cv:CreateTexture(nil, "BACKGROUND"); clip.tiles[i] = t end
                if textures[i] then
                    t:SetTexture(textures[i])
                    t:SetSize(tw, th)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", cv, "TOPLEFT", c * tw, -r * th)
                    t:SetAlpha(alpha or 0.5)
                    t:Show()
                end
            end
        end
        clip:Show()
        return true
    end

    local function Gradient(frame, layer, orient, from, to)
        local t = frame:CreateTexture(nil, layer or "ARTWORK")
        t:SetTexture(WHITE)
        if t.SetGradient and CreateColor then
            t:SetGradient(orient, CreateColor(unpack(from)), CreateColor(unpack(to)))
        else
            t:SetVertexColor(from[1], from[2], from[3], (from[4] + to[4]) / 2)
        end
        return t
    end

    -- move a widget into the layer above the art (keeps its anchors)
    local function Lift(fg, w, base)
        if not w then return end
        if w.IsObjectType and w:IsObjectType("FontString") then w:SetParent(fg); return end
        if w.SetParent then w:SetParent(fg) end
        if w.SetFrameLevel then w:SetFrameLevel(base) end
    end

    local function PlayerSpot()
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        local x, y = 0.5, 0.5
        if pos then x, y = pos:GetXY() end
        return mapID, x or 0.5, y or 0.5
    end

    local function ItemSpot(id)
        local data = ns.Items[id]
        if data and data.spots and data.spots[1] then
            local s = UI:BestSpot(data)
            local mapID = s and ns:ResolveZone(s.z)
            if mapID then return mapID, (s.x or 50) / 100, (s.y or 50) / 100 end
        end
        local lz = ns.GetLearnedZones and ns:GetLearnedZones(id)[1]
        if lz and lz.cells and lz.cells[1] then
            local best = lz.cells[1]
            for _, c in ipairs(lz.cells) do if (c.n or 0) > (best.n or 0) then best = c end end
            return lz.mapID, best.x / 100, best.y / 100
        end
    end

    local function SkinMain(self)
        local f = self.frame
        local base = f:GetFrameLevel()

        -- marble backdrop + vignette
        local marble = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        marble:SetPoint("TOPLEFT", 1, -1)
        marble:SetPoint("BOTTOMRIGHT", -1, 1)
        if TryTexture(marble, "Interface\\FrameGeneral\\UI-Background-Marble") then
            marble:SetHorizTile(true); marble:SetVertTile(true)
            marble:SetVertexColor(0.35, 0.42, 0.55, 0.35)
        else
            marble:Hide()
        end
        local vig = Gradient(f, "BACKGROUND", "VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 })
        vig:SetPoint("BOTTOMLEFT", 1, 1); vig:SetPoint("BOTTOMRIGHT", -1, 1); vig:SetHeight(140)

        -- ornate gold frame around the window
        local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
        border:SetPoint("TOPLEFT", -6, 6)
        border:SetPoint("BOTTOMRIGHT", 6, -6)
        border:SetFrameLevel(base + 30)
        border:EnableMouse(false)
        local okB = pcall(border.SetBackdrop, border, { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 26 })
        if not okB then border:Hide() end

        -- the zone you are in, painted behind the header
        local header = self.title and self.title:GetParent()
        if header then
            local hb = header:GetFrameLevel()
            local art = MapArt(header, hb + 1)
            art:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
            art:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
            art:SetHeight(56)
            local fade = Gradient(art.shade, "ARTWORK", "HORIZONTAL", { 0.03, 0.035, 0.05, 0.95 }, { 0.03, 0.035, 0.05, 0.35 })
            fade:SetAllPoints()
            local low = Gradient(art.shade, "OVERLAY", "VERTICAL", { 0.047, 0.055, 0.070, 1 }, { 0.047, 0.055, 0.070, 0 })
            low:SetPoint("BOTTOMLEFT"); low:SetPoint("BOTTOMRIGHT"); low:SetHeight(18)
            local line = art.shade:CreateTexture(nil, "OVERLAY")
            line:SetTexture(WHITE); line:SetVertexColor(1, 0.82, 0, 0.35)
            line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
            local fg = CreateFrame("Frame", nil, header)
            fg:SetAllPoints(header)
            fg:SetFrameLevel(hb + 4)
            for _, w in ipairs({ self.title, self.byline, self.sub, self.logo }) do Lift(fg, w, hb + 5) end
            for _, b in ipairs({ self.closeButton, self.langButton, self.gearButton, self.goalsButton, self.bestButton }) do
                if b and b.SetFrameLevel then b:SetFrameLevel(hb + 6) end
            end
            self.headerArt = art
        end
        if self.title then
            pcall(self.title.SetFont, self.title, "Fonts\\MORPHEUS.TTF", 24, "OUTLINE")
            self.title:SetShadowOffset(1, -1)
            self.title:SetShadowColor(0, 0, 0, 1)
        end
        if self.logo then
            local glow = self.logo:CreateTexture(nil, "OVERLAY")
            glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            glow:SetBlendMode("ADD")
            glow:SetVertexColor(0.25, 0.78, 0.92, 0.8)
            glow:SetPoint("CENTER")
            glow:SetSize(58, 58)
        end

        -- the farm zone of the selected item, painted behind its details
        local d = self.detail
        if d then
            local db = d:GetFrameLevel()
            local art = MapArt(d, db + 1)
            art:SetPoint("TOPLEFT", d, "TOPLEFT", 1, -1)
            art:SetPoint("TOPRIGHT", d, "TOPRIGHT", -1, -1)
            art:SetPoint("BOTTOM", d.sep, "TOP", 0, 2)
            local fade = Gradient(art.shade, "ARTWORK", "HORIZONTAL", { 0.06, 0.07, 0.09, 0.97 }, { 0.06, 0.07, 0.09, 0.30 })
            fade:SetAllPoints()
            local low = Gradient(art.shade, "OVERLAY", "VERTICAL", { 0.078, 0.088, 0.108, 1 }, { 0.078, 0.088, 0.108, 0 })
            low:SetPoint("BOTTOMLEFT"); low:SetPoint("BOTTOMRIGHT"); low:SetHeight(26)
            art.zone = art.shade:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            art.zone:SetPoint("BOTTOMRIGHT", -10, 8)
            art.zone:SetTextColor(1, 0.82, 0, 0.9)
            pcall(art.zone.SetFont, art.zone, "Fonts\\MORPHEUS.TTF", 13, "OUTLINE")
            art:Hide()
            local fg = CreateFrame("Frame", nil, d)
            fg:SetAllPoints(d)
            fg:SetFrameLevel(db + 4)
            for _, w in ipairs({ d.name, d.badge, d.inv, d.uses, d.goalLabel, d.welcome }) do Lift(fg, w) end
            for _, w in ipairs({ d.icon, d.goalBtn, d.goalEdit, d.track, d.open, d.link }) do Lift(fg, w, db + 5) end
            -- bigger, glowing item icon
            if d.icon then
                d.icon.glow = d.icon:CreateTexture(nil, "OVERLAY")
                d.icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                d.icon.glow:SetBlendMode("ADD")
                d.icon.glow:SetPoint("CENTER")
                d.icon.glow:SetSize(88, 88)
            end
            if d.name then
                local path, _, flags = d.name:GetFont()
                pcall(d.name.SetFont, d.name, path, 18, flags)
                d.name:SetShadowOffset(1, -1)
            end
            self.detailArt = art
        end

        f:HookScript("OnShow", function()
            if self.headerArt then
                local m, x, y = PlayerSpot()
                ShowMapArt(self.headerArt, m, x, y, 1.15, 0.55)
            end
        end)
    end

    --------------------------------------------------------------------
    -- Profession themes: every profession (Atlas filters, Recipes, Guide
    -- tabs) gets its own colour wash and a still life of its own icons in
    -- the corner, plus its name in the header - you always see which tab
    -- you are on. Overlay only (no mouse), so nothing under it changes.
    --------------------------------------------------------------------
    local THEMES = {
        cooking        = { "Interface\\Icons\\INV_Misc_Food_15", "Interface\\Icons\\Spell_Fire_Fire", "Interface\\Icons\\INV_Misc_Food_14", "Interface\\Icons\\INV_Misc_Food_19" },
        fishing        = { "Interface\\Icons\\Trade_Fishing", "Interface\\Icons\\INV_Misc_Fish_02", "Interface\\Icons\\INV_Misc_Fish_14", "Interface\\Icons\\INV_Misc_Fish_09" },
        skinning       = { "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Interface\\Icons\\INV_Misc_LeatherScrap_02", "Interface\\Icons\\INV_Misc_Pelt_Bear_01", "Interface\\Icons\\INV_Weapon_ShortBlade_01" },
        mining         = { "Interface\\Icons\\Trade_Mining", "Interface\\Icons\\INV_Ore_Copper_01", "Interface\\Icons\\INV_Ore_Iron_01", "Interface\\Icons\\INV_Ingot_03" },
        herbalism      = { "Interface\\Icons\\Trade_Herbalism", "Interface\\Icons\\INV_Misc_Flower_02", "Interface\\Icons\\INV_Misc_Herb_07", "Interface\\Icons\\INV_Misc_Herb_01" },
        alchemy        = { "Interface\\Icons\\Trade_Alchemy", "Interface\\Icons\\INV_Potion_51", "Interface\\Icons\\INV_Potion_11", "Interface\\Icons\\INV_Potion_76" },
        blacksmithing  = { "Interface\\Icons\\Trade_BlackSmithing", "Interface\\Icons\\INV_Hammer_20", "Interface\\Icons\\INV_Ingot_05", "Interface\\Icons\\INV_Stone_GrindingStone_01" },
        engineering    = { "Interface\\Icons\\Trade_Engineering", "Interface\\Icons\\INV_Gizmo_01", "Interface\\Icons\\INV_Misc_Gear_01", "Interface\\Icons\\INV_Misc_Bomb_08" },
        enchanting     = { "Interface\\Icons\\Trade_Engraving", "Interface\\Icons\\INV_Enchant_DustArcane", "Interface\\Icons\\INV_Enchant_EssenceMagicLarge", "Interface\\Icons\\INV_Enchant_ShardBrilliantLarge" },
        leatherworking = { "Interface\\Icons\\Trade_LeatherWorking", "Interface\\Icons\\INV_Misc_LeatherScrap_03", "Interface\\Icons\\INV_Misc_Pelt_Bear_03", "Interface\\Icons\\INV_Chest_Leather_09" },
        tailoring      = { "Interface\\Icons\\Trade_Tailoring", "Interface\\Icons\\INV_Fabric_Linen_01", "Interface\\Icons\\INV_Fabric_Silk_01", "Interface\\Icons\\INV_Misc_Bag_09" },
        firstaid       = { "Interface\\Icons\\Spell_Holy_SealOfSacrifice", "Interface\\Icons\\INV_Misc_Bandage_15", "Interface\\Icons\\INV_Misc_Bandage_12", "Interface\\Icons\\INV_Potion_51" },
    }

    local function ThemeKey(self)
        local sec = ns:SectionOf(self.cat)
        if sec == "guide" then return ns.db and ns.db.settings.guideProf or "cooking" end
        if sec == "recipes" then return "cooking" end
        if sec == "atlas" and self.cat ~= "all" then return self.cat end
    end

    local function BuildTheme(self)
        local f = self.frame
        local th = CreateFrame("Frame", nil, f)
        th:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -56)
        th:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        th:SetFrameLevel(f:GetFrameLevel() + 25)
        th:EnableMouse(false)
        -- colour wash rising from the bottom
        th.wash = th:CreateTexture(nil, "BACKGROUND")
        th.wash:SetTexture(WHITE)
        th.wash:SetPoint("BOTTOMLEFT"); th.wash:SetPoint("BOTTOMRIGHT")
        th.wash:SetHeight(170)
        th.wash:SetBlendMode("ADD")
        -- thin profession-coloured line under the header
        th.line = th:CreateTexture(nil, "ARTWORK")
        th.line:SetTexture(WHITE)
        th.line:SetPoint("TOPLEFT"); th.line:SetPoint("TOPRIGHT"); th.line:SetHeight(2)
        -- still life in the bottom-right corner
        th.icons = {}
        local spots = { { 230, -18, 2, 0.11 }, { 84, -230, 116, 0.09 }, { 70, -150, 6, 0.08 }, { 60, -56, 196, 0.07 } }
        for i, sp in ipairs(spots) do
            local tx = th:CreateTexture(nil, "ARTWORK")
            tx:SetSize(sp[1], sp[1])
            tx:SetPoint("BOTTOMRIGHT", th, "BOTTOMRIGHT", sp[2], sp[3] + 40)
            tx:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tx:SetAlpha(sp[4])
            th.icons[i] = tx
        end
        -- the profession's own illustration (Media/Themes/<key>.tga), glowing
        -- over the panel (additive: its dark parts vanish, its lights shine)
        th.art = th:CreateTexture(nil, "OVERLAY")
        th.art:SetSize(520, 260)
        th.art:SetPoint("BOTTOMRIGHT", th, "BOTTOMRIGHT", -6, 38)
        th.art:SetBlendMode("ADD")
        th.art:SetAlpha(0.62)
        th:Hide()
        self.theme = th
        -- the profession's name and icon in the header
        local header = self.title and self.title:GetParent()
        if header then
            local badge = CreateFrame("Frame", nil, header)
            badge:SetSize(200, 24)
            if self.bestButton then badge:SetPoint("RIGHT", self.bestButton, "LEFT", -14, 0)
            else badge:SetPoint("CENTER", header, "CENTER", 40, -2) end
            badge:SetFrameLevel(header:GetFrameLevel() + 6)
            badge.icon = badge:CreateTexture(nil, "OVERLAY")
            badge.icon:SetSize(22, 22)
            badge.icon:SetPoint("RIGHT", badge, "RIGHT", 0, 0)
            badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            badge.text:SetPoint("RIGHT", badge.icon, "LEFT", -6, 0)
            badge.text:SetJustifyH("RIGHT")
            pcall(badge.text.SetFont, badge.text, "Fonts\\MORPHEUS.TTF", 17, "OUTLINE")
            badge:Hide()
            self.themeBadge = badge
        end
    end

    function UI:ApplyTheme()
        local th = self.theme
        if not th then return end
        local key = ThemeKey(self)
        local icons = key and THEMES[key]
        if not icons then
            th:Hide()
            if self.themeBadge then self.themeBadge:Hide() end
            return
        end
        local c = ns.CAT_COLORS[key] or ns.CAT_COLORS.learned or { 1, 1, 1 }
        if th.wash.SetGradient and CreateColor then
            th.wash:SetGradient("VERTICAL", CreateColor(c[1], c[2], c[3], 0.16), CreateColor(c[1], c[2], c[3], 0))
        else
            th.wash:SetVertexColor(c[1], c[2], c[3], 0.08)
        end
        th.line:SetVertexColor(c[1], c[2], c[3], 0.7)
        local hasArt = TryTexture(th.art, "Interface\\AddOns\\FarmAtlas\\Media\\Themes\\" .. key)
        th.art:SetShown(hasArt)
        for i, tx in ipairs(th.icons) do
            tx:SetTexture(icons[i] or icons[1])
            tx:SetShown(not hasArt)          -- the icon still life only if the picture is missing
        end
        th:Show()
        local badge = self.themeBadge
        if badge then
            badge.icon:SetTexture(ns.Guides[key] and ns.Guides[key].icon or icons[1])
            badge.text:SetText(L("cat_" .. key))
            badge.text:SetTextColor(c[1], c[2], c[3])
            badge:Show()
        end
    end

    local origChips = UI.RefreshChips
    function UI:RefreshChips(...)
        origChips(self, ...)
        if self.theme then pcall(self.ApplyTheme, self) end
    end

    local origBuild = UI.Build
    function UI:Build()
        local first = not self.frame
        origBuild(self)
        if first and self.frame and Fancy() then
            local ok, err = pcall(SkinMain, self)
            if not ok and ns.Print then ns:Print("Fancy look: " .. tostring(err)) end
            ok, err = pcall(BuildTheme, self)
            if not ok and ns.Print then ns:Print("Fancy look: " .. tostring(err)) end
            pcall(self.ApplyTheme, self)
        end
    end

    local origDetail = UI.RefreshDetail
    function UI:RefreshDetail()
        origDetail(self)
        local art, d = self.detailArt, self.detail
        if not (art and d) then return end
        pcall(function()
            local id = self.selected
            if id == nil then art:Hide(); return end
            local mapID, x, y = ItemSpot(id)
            if not mapID or not ShowMapArt(art, mapID, x, y, 1.9, 0.6) then art:Hide(); return end
            local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
            art.zone:SetText(info and info.name or "")
            if d.icon and d.icon.glow then
                local _, quality = ns:GetItemName(id)
                local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if qc then d.icon.glow:SetVertexColor(qc.r, qc.g, qc.b, 0.9) else d.icon.glow:SetVertexColor(1, 1, 1, 0.6) end
            end
        end)
    end
end
