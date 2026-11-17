-- FarmAtlas - minimap button (no library needed)
local _, ns = ...
local L = ns.L

local button

local function UpdatePosition()
    local angle = math.rad(ns.db.settings.minimapAngle or 220)
    local radius = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Create()
    button = CreateFrame("Button", "FarmAtlasMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function(_, btn)
        if btn == "LeftButton" and IsShiftKeyDown() then
            if ns.Goals then ns.Goals:Toggle() end
        elseif btn == "RightButton" then
            ns.db.settings.showOnMap = not ns.db.settings.showOnMap
            ns:Fire("TRACKING_CHANGED")
            ns:Print(ns.db.settings.showOnMap and L("c_pins_on") or L("c_pins_off"))
        else
            ns.UI:Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            ns.db.settings.minimapAngle = math.deg(math.atan2(cy - my, cx - mx)) % 360
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddDoubleLine("|cff3fc7ebFarm|r|cffffd200Atlas|r", "by Shade", nil, nil, nil, 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L("mm_tracking", ns:CountTracked()), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("mm_hint"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("mm_goals"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("mm_drag"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UpdatePosition()
end

------------------------------------------------------------------------
-- Minimap button collectors (OneForAll, MinimapButtonBag, ElvUI...) move
-- the button into their own bar. A second minimap skin that groups
-- buttons (e.g. EllesmereUI Minimap) may have hidden it on the minimap
-- just before - then the bar skips it and the button is gone everywhere.
-- Once the button sits in another addon's named bar, FarmAtlas makes sure
-- it is shown there (unless you switched it off). An unnamed container is
-- a skin's own drawer: that one is left alone.
------------------------------------------------------------------------
local function InCollectorBar()
    local p = button and button:GetParent()
    if not p or p == Minimap then return false end
    local ok, name = pcall(p.GetName, p)
    return ok and type(name) == "string" and name ~= ""
end

local function Rescue()
    if not button or ns.db.settings.hideMinimapButton then return end
    if not InCollectorBar() then return end
    if not button:IsShown() then button:Show() end
    -- another addon's Show() hook may zero the alpha again: set it after
    if (button:GetAlpha() or 1) < 0.99 then button:SetAlpha(1) end
end

local function SafeRescue() pcall(Rescue) end

local function Apply()
    if not button then
        Create()
        -- collectors re-parent the button: check right after they did
        if hooksecurefunc then
            pcall(hooksecurefunc, button, "SetParent", function()
                if C_Timer and C_Timer.After then C_Timer.After(0, SafeRescue) else SafeRescue() end
            end)
        end
    end
    button:SetShown(not ns.db.settings.hideMinimapButton)
    SafeRescue()
end

ns:On("LOGIN", function()
    Apply()
    -- collectors scan a few seconds after login (OneForAll: 5 s and 15 s)
    if C_Timer and C_Timer.After then
        for _, t in ipairs({ 3, 8, 18, 30 }) do C_Timer.After(t, SafeRescue) end
    end
end)
ns:On("MINIMAP_SETTING", Apply)

------------------------------------------------------------------------
-- Addon compartment (the game's addon menu next to the minimap): FarmAtlas
-- is always reachable there, even when another addon hides the button.
------------------------------------------------------------------------
function FarmAtlas_OnAddonCompartmentClick(_, mouseButton)
    if not ns.db then return end
    if mouseButton == "RightButton" then
        ns.db.settings.showOnMap = not ns.db.settings.showOnMap
        ns:Fire("TRACKING_CHANGED")
        ns:Print(ns.db.settings.showOnMap and L("c_pins_on") or L("c_pins_off"))
    elseif IsShiftKeyDown and IsShiftKeyDown() then
        if ns.Goals then ns.Goals:Toggle() end
    elseif ns.UI then
        ns.UI:Toggle()
    end
end

function FarmAtlas_OnAddonCompartmentEnter(_, menuButton)
    if not ns.db then return end
    GameTooltip:SetOwner(menuButton or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddDoubleLine("|cff3fc7ebFarm|r|cffffd200Atlas|r", "by Shade", nil, nil, nil, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L("mm_tracking", ns:CountTracked()), 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L("mm_hint"), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L("mm_goals"), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function FarmAtlas_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
