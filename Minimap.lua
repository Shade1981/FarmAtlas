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

local function Apply()
    if not button then Create() end
    button:SetShown(not ns.db.settings.hideMinimapButton)
end

ns:On("LOGIN", Apply)
ns:On("MINIMAP_SETTING", Apply)
