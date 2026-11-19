-- FarmAtlas - settings window (gear button in the atlas header, or /farm config)
-- Every switch in one place, grouped by topic.
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local C = {
    bg     = { 0.047, 0.055, 0.070, 0.97 },
    panel  = { 0.078, 0.088, 0.108, 1 },
    hover  = { 0.130, 0.146, 0.176, 1 },
    border = { 0.165, 0.185, 0.225, 1 },
    accent = { 0.247, 0.780, 0.922, 1 },
    text   = { 0.92, 0.94, 0.97 },
    muted  = { 0.55, 0.59, 0.66 },
}

local function BG(f, color, border)
    if not f.SetBackdrop and BackdropTemplateMixin then Mixin(f, BackdropTemplateMixin) end
    if not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(color))
    local b = border or C.border
    f:SetBackdropBorderColor(b[1], b[2], b[3], b[4] or 1)
end

local function S() return ns.db.settings end

-- every page: a title and a list of controls
--   { "check", labelKey, get, set, hintKey }
--   { "button", labelKey, onClick, hintKey }
--   { "stepper", labelKey, get, set, min, max, step, format }
--   { "head", labelKey }
local function Page(id, titleKey, items) return { id = id, title = titleKey, items = items } end

local function ProfChecks(kind)
    local out = {}
    for _, prof in ipairs(ns.GUIDE_ORDER or {}) do
        if kind == "town" then
            out[#out + 1] = { "check", "cat_" .. prof, function() return ns:TownAlertOn(prof) end,
                function(v) ns:SetTownAlert(prof, v) end }
        else
            out[#out + 1] = { "check", "cat_" .. prof, function() return ns:TrainerPinsOn(prof) end,
                function(v) ns:SetTrainerPins(prof, v) end }
        end
    end
    return out
end

local function Pages()
    local fire = function() ns:Fire("TRACKING_CHANGED") end
    local guide = {
        { "check", "op_guide_areas", function() return S().guideAreas end, function(v) S().guideAreas = v; fire() end, "op_guide_areas_hint" },
        { "check", "op_guide_trainers", function() return S().guideTrainers end, function(v) S().guideTrainers = v; fire() end, "op_guide_trainers_hint" },
        { "head", "op_town" },
    }
    for _, it in ipairs(ProfChecks("town")) do guide[#guide + 1] = it end

    local trainers = { { "head", "op_allpins" } }
    for _, it in ipairs(ProfChecks("all")) do trainers[#trainers + 1] = it end
    trainers[#trainers + 1] = { "head", "tb_name" }
    trainers[#trainers + 1] = { "check", "op_banner_on", function() return ns:BannerOn() end, function(v) ns:SetBannerOn(v) end }
    trainers[#trainers + 1] = { "button", "op_banner_edit", function() ns:ToggleBannerEdit() end, "op_banner_edit_hint" }
    trainers[#trainers + 1] = { "button", "op_banner_reset", function()
        S().banner = { on = ns:BannerOn(), scale = 1 }
        ns:Print(L("op_banner_reset_done"))
    end }

    return {
        Page("general", "op_general", {
            { "lang" },
            { "check", "op_mmbutton", function() return not S().hideMinimapButton end,
                function(v) S().hideMinimapButton = not v; ns:Fire("MINIMAP_SETTING") end },
            { "check", "t_learn", function() return S().learn end, function(v) S().learn = v end, "op_learn_hint" },
            { "check", "t_tooltip", function() return S().tooltip end, function(v) S().tooltip = v end, "op_tooltip_hint" },
            { "check", "op_news", function() return S().newsPopup end, function(v) S().newsPopup = v end },
            { "head", "op_sync" },
            { "check", "op_sync_on", function() return S().sync end,
                function(v) if ns.Sync and v ~= S().sync then ns.Sync:Toggle() else S().sync = v end end, "op_sync_hint" },
            { "check", "op_sync_guild", function() return S().syncGuild end, function(v) S().syncGuild = v end },
        }),
        Page("map", "op_map", {
            { "check", "t_pins", function() return S().showOnMap end, function(v) S().showOnMap = v; fire() end, "op_pins_hint" },
            { "check", "t_continent", function() return S().showOnContinent end, function(v) S().showOnContinent = v; fire() end },
            { "check", "t_minimap", function() return S().showOnMinimap end, function(v) S().showOnMinimap = v; fire() end },
            { "stepper", "op_alpha", function() return S().areaAlpha or 0.12 end,
                function(v) S().areaAlpha = v; fire() end, 0.04, 0.35, 0.02, function(v) return math.floor(v * 100 + 0.5) .. "%" end },
            { "stepper", "op_nodesize", function() return S().nodeIconSize or 14 end,
                function(v) S().nodeIconSize = v; fire() end, 8, 28, 2, function(v) return v .. " px" end },
            { "check", "op_poolalert", function() return S().poolAlert ~= false end, function(v) S().poolAlert = v end, "op_poolalert_hint" },
            { "stepper", "op_nodehide", function() return S().nodeHideRange or 15 end,
                function(v) S().nodeHideRange = v; fire() end, 0, 50, 5, function(v) return v == 0 and L("op_off") or (v .. " " .. L("op_yd")) end },
        }),
        Page("guide", "op_guide", guide),
        Page("trainers", "op_trainers", trainers),
        Page("prices", "op_prices", {
            { "check", "op_price", function() return S().tooltipPrices end, function(v) S().tooltipPrices = v end, "op_price_hint" },
            { "check", "op_hour", function() return S().farmHour end, function(v) S().farmHour = v end, "op_hour_hint" },
            { "check", "op_owned", function() return S().ownedValue end, function(v) S().ownedValue = v end },
            { "button", "op_hour_reset", function() ns.db.farmLog = {}; ns:Print(L("op_hour_reset_done")) end },
        }),
    }
end

------------------------------------------------------------------------
-- widgets
------------------------------------------------------------------------
local function Check(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(16, 16)
    b.box:SetPoint("LEFT", 0, 0)
    BG(b.box, C.panel)
    b.tick = b.box:CreateTexture(nil, "ARTWORK")
    b.tick:SetTexture(WHITE)
    b.tick:SetPoint("TOPLEFT", 3, -3)
    b.tick:SetPoint("BOTTOMRIGHT", -3, 3)
    b.tick:SetVertexColor(unpack(C.accent))
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("LEFT", b.box, "RIGHT", 10, 0)
    b.label:SetJustifyH("LEFT")
    b.hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.hint:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -2)
    b.hint:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    b.hint:SetJustifyH("LEFT")
    b.hint:SetTextColor(unpack(C.muted))
    b:SetScript("OnClick", function(self)
        if self.set then self.set(not self.get()) end
        self:Refresh()
    end)
    function b:Refresh() self.tick:SetShown(self.get and self.get() and true or false) end
    return b
end

local function Button(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    BG(b, C.panel)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(C.hover)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(C.panel)) end)
    return b
end

------------------------------------------------------------------------
-- window
------------------------------------------------------------------------
local Options = {}
ns.Options = Options

function Options:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "FarmAtlasOptionsFrame", UIParent)
    self.frame = f
    f:SetSize(640, 470)
    f:SetPoint("CENTER", 40, -10)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    BG(f, C.bg, { 0.22, 0.25, 0.30, 1 })
    tinsert(UISpecialFrames, "FarmAtlasOptionsFrame")
    f:Hide()

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 16, -14)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- left: page list
    f.nav = CreateFrame("Frame", nil, f)
    f.nav:SetPoint("TOPLEFT", 12, -46)
    f.nav:SetPoint("BOTTOMLEFT", 12, 12)
    f.nav:SetWidth(170)
    BG(f.nav, C.panel)
    f.navButtons = {}

    -- right: the page
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f.nav, "TOPRIGHT", 12, 0)
    f.body:SetPoint("BOTTOMRIGHT", -12, 12)
    BG(f.body, C.panel)
    f.pageTitle = f.body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.pageTitle:SetPoint("TOPLEFT", 14, -12)
    f.widgets = {}
    self.page = "general"
end

function Options:Clear()
    for _, w in ipairs(self.frame.widgets) do w:Hide() end
    self.frame.widgets = {}
end

-- widgets are cheap and pages small: rebuilt each time a page is shown
function Options:ShowPage(id)
    self.page = id
    local f = self.frame
    self:Clear()
    local pages = Pages()
    for i, p in ipairs(pages) do
        local b = f.navButtons[i]
        if not b then
            b = Button(f.nav)
            b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 32)
            b:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * 32)
            f.navButtons[i] = b
        end
        b.label:SetText(L(p.title))
        b:SetScript("OnClick", function() Options:ShowPage(p.id) end)
        if p.id == id then
            b:SetBackdropBorderColor(unpack(C.accent))
            f.pageTitle:SetText(L(p.title))
        else
            b:SetBackdropBorderColor(unpack(C.border))
        end
    end
    local page
    for _, p in ipairs(pages) do if p.id == id then page = p end end
    if not page then return end
    local y = -40
    local width = f.body:GetWidth() - 28
    for _, it in ipairs(page.items) do
        local kind = it[1]
        if kind == "head" then
            local holder = CreateFrame("Frame", nil, f.body)
            holder:SetPoint("TOPLEFT", 14, y - 6)
            holder:SetSize(width, 18)
            local h = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("LEFT")
            h:SetText(L(it[2]))
            h:SetTextColor(1, 0.82, 0)
            table.insert(f.widgets, holder)
            y = y - 30
        elseif kind == "check" then
            local c = Check(f.body)
            c:SetPoint("TOPLEFT", 14, y)
            c:SetWidth(width)
            c.label:SetText(L(it[2]))
            c.get, c.set = it[3], it[4]
            c.hint:SetText(it[5] and L(it[5]) or "")
            c:Refresh()
            table.insert(f.widgets, c)
            y = y - (it[5] and 42 or 28)
        elseif kind == "button" then
            local b = Button(f.body)
            b:SetPoint("TOPLEFT", 14, y)
            b:SetWidth(220)
            b.label:SetText(L(it[2]))
            b:SetScript("OnClick", it[3])
            table.insert(f.widgets, b)
            if it[4] then
                local hint = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                hint:SetPoint("LEFT", b, "RIGHT", 10, 0)
                hint:SetWidth(width - 240)
                hint:SetJustifyH("LEFT")
                hint:SetTextColor(unpack(C.muted))
                hint:SetText(L(it[4]))
            end
            y = y - 34
        elseif kind == "stepper" then
            local get, set, mn, mx, step, fmt = it[3], it[4], it[5], it[6], it[7], it[8]
            local row = CreateFrame("Frame", nil, f.body)
            row:SetPoint("TOPLEFT", 14, y)
            row:SetSize(width, 26)
            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT")
            label:SetText(L(it[2]))
            local minus, plus = Button(row), Button(row)
            minus:SetSize(26, 22); plus:SetSize(26, 22)
            minus.label:SetText("-"); plus.label:SetText("+")
            local val = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            plus:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            val:SetPoint("RIGHT", plus, "LEFT", -8, 0)
            minus:SetPoint("RIGHT", val, "LEFT", -8, 0)
            local function show() val:SetText(fmt(get())) end
            minus:SetScript("OnClick", function() set(math.max(mn, get() - step)); show() end)
            plus:SetScript("OnClick", function() set(math.min(mx, get() + step)); show() end)
            show()
            table.insert(f.widgets, row)
            y = y - 34
        elseif kind == "lang" then
            local row = CreateFrame("Frame", nil, f.body)
            row:SetPoint("TOPLEFT", 14, y)
            row:SetSize(width, 26)
            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT")
            label:SetText(L("op_lang"))
            local prev
            for i = #ns.LANGS, 1, -1 do
                local lang = ns.LANGS[i].key
                local b = Button(row)
                b:SetSize(44, 22)
                b.label:SetText(lang:upper())
                local langName = ns.LANGS[i].name
                b:HookScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:AddLine(langName, 1, 1, 1)
                    GameTooltip:Show()
                end)
                b:HookScript("OnLeave", function() GameTooltip:Hide() end)
                if prev then b:SetPoint("RIGHT", prev, "LEFT", -6, 0) else b:SetPoint("RIGHT", row, "RIGHT", -4, 0) end
                if ns:Lang() == lang then b:SetBackdropBorderColor(unpack(C.accent)) end
                b:SetScript("OnClick", function()
                    ns:SetLang(lang)
                    Options:Refresh()
                end)
                prev = b
            end
            table.insert(f.widgets, row)
            y = y - 34
        end
    end
end

function Options:Refresh()
    if not self.frame then return end
    self.frame.title:SetText("|cff3fc7ebFarm|r|cffffd200Atlas|r  " .. L("op_title"))
    self:ShowPage(self.page or "general")
end

function Options:Toggle()
    self:Build()
    if self.frame:IsShown() then self.frame:Hide() return end
    self.frame:Show()
    self:Refresh()
end

ns:On("LANG_CHANGED", function() if Options.frame and Options.frame:IsShown() then Options:Refresh() end end)
