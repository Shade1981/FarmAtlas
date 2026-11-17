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

local W, H = 800, 540
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
    logo:SetPoint("LEFT", 16, -2)
    logo.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
    logo.ring:SetVertexColor(unpack(C.accent))

    local title = Font(header, "GameFontNormalLarge", 18)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 2)
    title:SetText("|cff3fc7ebFarm|r|cffffd200Atlas|r")
    local byline = Font(header, "GameFontHighlightSmall", 10, unpack(C.muted))
    byline:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    byline:SetText("v" .. ns.version .. "  ·  by Shade")
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
    close:SetScript("OnEnter", function(s) s.x:SetTextColor(1, 0.35, 0.35) end)
    close:SetScript("OnLeave", function(s) s.x:SetTextColor(unpack(C.muted)) end)

    -- language switch (HU | EN)
    self.langButtons = {}
    local prevLang
    for _, lang in ipairs({ "en", "hu" }) do
        local lb = FlatButton(header, lang:upper(), 34, 22)
        if prevLang then lb:SetPoint("RIGHT", prevLang, "LEFT", -4, 0)
        else lb:SetPoint("RIGHT", close, "LEFT", -10, 0) end
        lb.lang = lang
        lb:SetScript("OnClick", function() ns:SetLang(lang) end)
        lb.tooltip = "Language / Nyelv"
        self.langButtons[#self.langButtons + 1] = lb
        prevLang = lb
    end
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

    -- Search ---------------------------------------------------------
    local search = CreateFrame("EditBox", nil, f, "BackdropTemplate")
    self.search = search
    search:SetPoint("TOPLEFT", 16, -60)
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

    -- Category chips -------------------------------------------------
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
    list:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 44)
    list:SetWidth(LIST_W)
    SetBG(list, C.panel)

    self.count = Font(list, "GameFontHighlightSmall", nil, unpack(C.muted))
    self.count:SetPoint("BOTTOMLEFT", list, "TOPLEFT", 2, 4)
    self.count:SetText("")

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
            -- what it makes: the game's own item tooltip, when FarmAtlas knows the item
            local made = ns:RecipeItemID(rc.name)
            if made then
                GameTooltip:SetHyperlink("item:" .. made)
                GameTooltip:AddLine(" ")
            else
                GameTooltip:AddLine(rc.name, 1, 0.82, 0)
                GameTooltip:AddLine(L("rc_effect_unknown"), 0.6, 0.6, 0.6, true)
            end
            GameTooltip:AddLine(rc.known and L("rc_known") or L("rc_unknown"),
                rc.known and 0.3 or 1, rc.known and 0.9 or 0.4, rc.known and 0.35 or 0.4)
            GameTooltip:AddLine(" ")
            for _, r in ipairs(rc.reagents) do
                local enough = r.need > 0 and r.have >= r.need
                local right = r.need > 0 and (r.have .. " / " .. r.need) or tostring(r.have)
                GameTooltip:AddDoubleLine(r.name, right, 1, 1, 1,
                    enough and 0.3 or 1, enough and 0.9 or 0.5, enough and 0.35 or 0.4)
            end
            if #rc.alts > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("known_by", table.concat(rc.alts, ", ")), 0.6, 0.6, 0.6, true)
            end
            if not rc.known then
                local srcType, sources, note = ns:RecipeSources(rc.name)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("rc_where"), 1, 0.82, 0)
                if srcType == "faction" then
                    GameTooltip:AddLine(L("src_enemy"), 1, 0.5, 0.25, true)
                elseif #sources == 0 then
                    GameTooltip:AddLine(note or L("src_unknown"), 0.7, 0.7, 0.7, true)
                end
                for i = 1, math.min(4, #sources) do
                    local s = sources[i]
                    local loc = (s.zone or "?") .. ((s.x and s.y) and (" %.1f, %.1f"):format(s.x, s.y) or "")
                    if s.note then loc = loc .. " (" .. s.note .. ")" end
                    if s.neutral then loc = loc .. " [" .. L("src_neutral") .. "]" end
                    GameTooltip:AddDoubleLine(s.npc or "?", s.price or "", 1, 1, 1, 1, 0.82, 0)
                    GameTooltip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
                end
                if #sources > 4 then GameTooltip:AddLine(L("more", #sources - 4), 0.55, 0.59, 0.66) end
            end
            if self.itemID then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L("row_hint"), 0.8, 0.8, 0.8)
            end
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
        else
            self.results = ns:Search(self.search:GetText(), self.cat)
        end
    end
    local results = self.results
    local listH = self.list:GetHeight()
    -- guide mode: sub-tabs on top of the list
    local top = guideMode and 32 or 0
    local current = guideMode and ns:GuideProf()
    for _, b in ipairs(self.list.guideTabs or {}) do
        b:SetShown(guideMode)
        if guideMode then
            b.text:SetText(L("cat_" .. b.prof))
            b:SetActive(b.prof == current)
        end
    end
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
            row.name:SetText(col .. rc.name .. "|r")
            local parts = {}
            for _, r in ipairs(rc.reagents) do
                local enough = r.need > 0 and r.have >= r.need
                local c = enough and "|cff66e070" or "|cffd0d4dc"
                parts[#parts + 1] = c .. r.name .. (r.need > 0 and (" " .. r.have .. "/" .. r.need) or "") .. "|r"
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
    if s.kind == "craft" then return range .. "  " .. s.recipe end
    if s.kind == "area" then
        local z = s.zones[1] .. ((#s.zones > 1) and (" +" .. (#s.zones - 1)) or "")
        return range .. "  " .. z
    end
    return range .. "  " .. L("g_train", s.rank or "")
end

local function GuideSub(r)
    local s = r.step
    if s.kind == "craft" then
        local t = s.item .. (s.extra and (" + " .. s.extra) or "")
        if s.count then t = t .. "  ·  " .. L("g_crafts", s.count) end
        return t
    elseif s.kind == "area" then
        return s.mobs or ns.GuideNote(s) or table.concat(s.zones, ", ")
    elseif s.kind == "special" then
        local names = {}
        local list = ns:GuideTrainers(r.prof, s.npcs)
        for _, t in ipairs(list) do names[#names + 1] = t.npc .. " (" .. t.zone .. ")" end
        return table.concat(names, ", ")
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
        row.name:SetText(("|cff%02x%02x%02x%s|r  %s"):format(math.floor(cc[1] * 255), math.floor(cc[2] * 255), math.floor(cc[3] * 255), string.upper(L("cat_" .. r.prof)), skill))
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
            local loc = t.zone .. ((t.x and t.y) and (" %.1f, %.1f"):format(t.x, t.y) or "") .. (t.note and (" (" .. t.note .. ")") or "")
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
        GameTooltip:AddLine(L("g_mats"), 1, 0.82, 0)
        GameTooltip:AddLine("   " .. s.item .. (s.extra and (" + " .. s.extra) or ""), 1, 1, 1)
        if s.count then GameTooltip:AddLine("   " .. L("g_crafts", s.count), 0.8, 0.8, 0.8) end
        local srcType, sources, srcNote = ns:RecipeSources(s.recipe)
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
            local loc = (src.zone or "?") .. ((src.x and src.y) and (" %.1f, %.1f"):format(src.x, src.y) or "")
            if src.note then loc = loc .. " (" .. src.note .. ")" end
            if src.neutral then loc = loc .. " [" .. L("src_neutral") .. "]" end
            GameTooltip:AddDoubleLine(src.npc or "?", src.price or "", 1, 1, 1, 1, 0.82, 0)
            GameTooltip:AddLine("   " .. loc, 0.7, 0.7, 0.7, true)
        end
        if #sources > 4 then GameTooltip:AddLine(L("more", #sources - 4), 0.55, 0.59, 0.66) end
    elseif s.kind == "area" then
        GameTooltip:AddLine(L("g_zones"), 1, 0.82, 0)
        GameTooltip:AddLine("   " .. table.concat(s.zones, ", "), 1, 1, 1, true)
        if s.mobs then
            GameTooltip:AddLine(L("g_mobs"), 1, 0.82, 0)
            GameTooltip:AddLine("   " .. s.mobs, 1, 1, 1, true)
        end
    else
        GameTooltip:AddLine(s.kind == "special" and L("g_npcs") or L("g_trainers"), 1, 0.82, 0)
        local list = ns:GuideTrainers(r.prof, s.kind == "special" and s.npcs or nil)
        for i = 1, math.min(6, #list) do
            local t = list[i]
            local loc = t.zone .. ((t.x and t.y) and (" %.1f, %.1f"):format(t.x, t.y) or "") .. (t.note and (" (" .. t.note .. ")") or "")
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
        GameTooltip:AddLine(action == "item" and L("g_click_item", r.step.item) or L("g_click_map"), 0.8, 0.8, 0.8)
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
    for _, chip in ipairs(self.chips) do chip:SetActive(chip.key == self.cat) end
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
            if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
            ChatFrame_OpenChat(link)
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
        if self.zoneKey or self.mapID or self.point then self.go:Show() end
        if self.recipe then
            -- what the recipe makes: the game's own item tooltip when known
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local made = ns:RecipeItemID(self.recipe)
            if made then
                GameTooltip:SetHyperlink("item:" .. made)
            else
                GameTooltip:AddLine(self.recipe, 1, 0.82, 0)
                GameTooltip:AddLine(L("rc_effect_unknown"), 0.6, 0.6, 0.6, true)
            end
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
        if self.point then
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
    d.badge:SetText(("|cff%02x%02x%02x%s|r"):format(cc[1] * 255, cc[2] * 255, cc[3] * 255, string.upper(L("cat_" .. cat))))
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
        card.veil:SetShown(unknown and true or false)
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
                    local loc = s.zone or "?"
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
            Card(recipe, status, sr, sg, sb, l2, l3, strip, nil, nil, point, recipe, not mine)
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
    for _, chip in ipairs(self.chips) do chip.text:SetText(L("cat_" .. chip.key)) end
    self.list.empty:SetText(L("empty"))
    local d = self.detail
    d.open.text:SetText(L("open_best"))
    d.link.text:SetText(L("link"))
    d.link.tooltip = L("link_tip")
    d.welcome:SetText(L("welcome"))
    for _, c in ipairs(d.cards) do c.go:SetText(L("show_on_map")) end
    self.clearButton.text:SetText(L("clear"))
    for _, t in ipairs(self.toggles) do t:Update() end
    for _, lb in ipairs(self.langButtons) do lb:SetActive(lb.lang == ns:Lang()) end
    self.goalsButton.text:SetText(L("goals_btn"))
    d.goalLabel:SetText(L("goal_label"))
    d.goalBtn.text:SetText(L("goal_set"))
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
-- chat links: Alt + click
if SetItemRef then
    hooksecurefunc("SetItemRef", function(link, text)
        if IsAltKeyDown() and type(link) == "string" and link:find("^item:") then
            OpenForLink(text or ("|H" .. link .. "|h[?]|h"))
        end
    end)
end
