-- FarmAtlas - World map pins (data provider + pin mixins)
local _, ns = ...
local L = ns.L

local AREA_TEMPLATE = "FarmAtlasAreaPinTemplate"
local ICON_TEMPLATE = "FarmAtlasIconPinTemplate"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function BaseLevel(pin)
    local ok, lvl = pcall(function()
        return pin:GetMap():GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_AREA_POI")
    end)
    return (ok and lvl) or 2000
end

local function MakeCircle(frame, layer, sub)
    local tex = frame:CreateTexture(nil, layer, nil, sub or 0)
    tex:SetTexture(WHITE)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return tex, mask
end

------------------------------------------------------------------------
-- Area pin: a translucent circle that scales with the map
------------------------------------------------------------------------
FarmAtlasAreaPinMixin = CreateFromMixins(MapCanvasPinMixin)

function FarmAtlasAreaPinMixin:OnLoad()
    -- some clients run OnLoad twice (template + map canvas); building the
    -- textures twice left an untinted white circle under the colored one
    if self.faBuilt then return end
    self.faBuilt = true
    -- MapCanvas calls these protected methods on pins; from addon code that
    -- triggers "blocked from an action only available to the Blizzard UI".
    self.SetPassThroughButtons = function() end
    self.SetPropagateMouseClicks = function() end
    self.SetPropagateMouseMotion = function() end
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    -- Fill lives on its own child frame and the FRAME gets the transparency:
    -- frame alpha is applied by every client, texture alpha was ignored here.
    self.FillFrame = CreateFrame("Frame", nil, self)
    self.FillFrame:SetAllPoints()
    self.Fill = self.FillFrame:CreateTexture(nil, "BACKGROUND")
    self.Fill:SetTexture(CIRCLE_MASK)
    self.Fill:SetAllPoints()
    -- dashed outline like the quest areas, on a separate fully visible layer
    self.DotFrame = CreateFrame("Frame", nil, self)
    self.DotFrame:SetAllPoints()
    self.Dots = {}
    for i = 1, 48 do
        local d = self.DotFrame:CreateTexture(nil, "ARTWORK")
        d:SetColorTexture(1, 1, 1, 1)
        d:Hide()
        self.Dots[i] = d
    end
    self:EnableMouse(false)
end

function FarmAtlasAreaPinMixin:ApplyFrameLevel()
    self:SetFrameLevel(BaseLevel(self) - 2)
end

function FarmAtlasAreaPinMixin:OnAcquired(info)
    self.info = info
    local map = self:GetMap()
    local size
    if map.DenormalizeHorizontalSize then
        size = map:DenormalizeHorizontalSize(info.r * 2)
    else
        size = map:GetCanvas():GetWidth() * info.r * 2
    end
    if info.learned then size = math.max(size, 6) end
    self:SetSize(size, size)
    local r, g, b = info.cr, info.cg, info.cb
    local alpha = math.min(ns.db.settings.areaAlpha or 0.12, 0.35)
    self.Fill:SetVertexColor(r, g, b, 1)
    if info.learned then
        -- your own loot spots: small solid dots, no outline
        self.FillFrame:SetAlpha(0.9)
        for _, d in ipairs(self.Dots) do d:Hide() end
    else
        self.FillFrame:SetAlpha(alpha)
        local radius = size / 2
        local count = math.max(12, math.min(#self.Dots, math.floor(size * math.pi / 9)))
        local dot = math.max(2, math.min(4, size / 70))
        for i, d in ipairs(self.Dots) do
            if i <= count then
                local a = (i / count) * 2 * math.pi
                d:ClearAllPoints()
                d:SetPoint("CENTER", self.DotFrame, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
                d:SetSize(dot * 1.8, dot)
                d:SetRotation(a + math.pi / 2)
                d:SetVertexColor(r, g, b, 0.95)
                d:Show()
            else
                d:Hide()
            end
        end
    end
    self:SetPosition(info.x, info.y)
end

------------------------------------------------------------------------
-- Icon pin: item icon with a colored ring, keeps a readable size
------------------------------------------------------------------------
FarmAtlasIconPinMixin = CreateFromMixins(MapCanvasPinMixin)

function FarmAtlasIconPinMixin:OnLoad()
    -- some clients run OnLoad twice (template + map canvas); building the
    -- textures twice left an untinted white circle under the colored one
    if self.faBuilt then return end
    self.faBuilt = true
    -- MapCanvas calls these protected methods on pins; from addon code that
    -- triggers "blocked from an action only available to the Blizzard UI".
    self.SetPassThroughButtons = function() end
    self.SetPropagateMouseClicks = function() end
    self.SetPropagateMouseMotion = function() end
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 0.85, 1.35)
    self:SetSize(22, 22)

    self.Shadow = MakeCircle(self, "BACKGROUND", -1)
    self.Shadow:SetPoint("TOPLEFT", -4, 4)
    self.Shadow:SetPoint("BOTTOMRIGHT", 4, -4)
    self.Shadow:SetVertexColor(0, 0, 0, 0.55)

    self.Ring = MakeCircle(self, "BACKGROUND")
    self.Ring:SetPoint("TOPLEFT", -2, 2)
    self.Ring:SetPoint("BOTTOMRIGHT", 2, -2)

    self.Icon = self:CreateTexture(nil, "ARTWORK")
    self.Icon:SetAllPoints()
    self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = self:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(self.Icon)
    self.Icon:AddMaskTexture(mask)

    self.Highlight = MakeCircle(self, "OVERLAY")
    self.Highlight:SetAllPoints()
    self.Highlight:SetVertexColor(1, 1, 1, 0.25)
    self.Highlight:Hide()

    self:EnableMouse(true)
    if self.SetMouseClickEnabled then self:SetMouseClickEnabled(true) end
end

function FarmAtlasIconPinMixin:ApplyFrameLevel()
    self:SetFrameLevel(BaseLevel(self) + 2)
end

function FarmAtlasIconPinMixin:OnAcquired(info)
    self.info = info
    self.Icon:SetTexture(info.icon or ns:GetItemIcon(info.itemID))
    self.Ring:SetVertexColor(info.cr, info.cg, info.cb, 1)
    self:SetPosition(info.x, info.y)
end

function FarmAtlasIconPinMixin:OnMouseEnter()
    local info = self.info
    if not info then return end
    self.Highlight:Show()
    local tip = GameTooltip
    tip:SetOwner(self, "ANCHOR_RIGHT")
    if info.trainer then
        tip:AddLine(info.label or "?", 1, 0.82, 0)
        tip:AddLine(L("cat_" .. info.prof) .. (info.rank and (" - " .. info.rank) or (" - " .. L("g_trainer"))), 1, 1, 1)
        if info.sub then tip:AddLine(info.sub, 0.7, 0.7, 0.7, true) end
        tip:AddLine(" ")
        tip:AddLine(L("g_pin_hint"), 0.8, 0.8, 0.8, true)
        tip:Show()
        return
    end
    if info.waypoint then
        tip:AddLine(info.label or "?", 1, 0.82, 0)
        if info.sub then tip:AddLine(info.sub, 1, 1, 1, true) end
        tip:AddLine(" ")
        tip:AddLine(L("tt_wp_hint"), 0.8, 0.8, 0.8)
        tip:Show()
        return
    end
    tip:AddLine(ns:GetItemColoredName(info.itemID))
    tip:AddLine(ns:ZoneName(info.zoneKey), 0.7, 0.7, 0.7)
    local s = info.spot
    if s then
        if s.mobs then tip:AddLine(L("tt_source") .. ": |cffffffff" .. s.mobs .. "|r", 0.6, 0.6, 0.6, true) end
        if s.lvl then
            local r, g, b = 1, 1, 1
            if not tostring(s.lvl):find("skill") then r, g, b = ns:LevelColor(s.lvl) end
            tip:AddDoubleLine(L("tt_level"), s.lvl, 0.6, 0.6, 0.6, r, g, b)
        end
        if s.drop then tip:AddDoubleLine(L("tt_drop"), s.drop, 0.6, 0.6, 0.6, 0.4, 1, 0.4) end
        if s.note then tip:AddLine(s.note, 1, 0.82, 0, true) end
    end
    if info.learnedCount and info.learnedCount > 0 then
        tip:AddLine(L("tt_looted", info.learnedCount), 0.8, 0.55, 1)
    end
    local data = ns.Items[info.itemID]
    if data and data.uses and #data.uses > 0 then
        tip:AddLine(" ")
        tip:AddLine(L("used_for") .. " " .. table.concat(data.uses, ", "), 0.55, 0.85, 0.35, true)
    end
    tip:AddLine(" ")
    tip:AddLine(L("tt_pin_hint"), 0.8, 0.8, 0.8)
    tip:Show()
end

function FarmAtlasIconPinMixin:OnMouseLeave()
    self.Highlight:Hide()
    GameTooltip:Hide()
end

function FarmAtlasIconPinMixin:OnMouseUp(button)
    if not self.info then return end
    if self.info.trainer then
        if button == "RightButton" then ns:SetTrainerPins(self.info.prof, false) end
        return
    end
    if self.info.waypoint then
        if button == "RightButton" then ns.waypoint = nil; ns:Fire("TRACKING_CHANGED") end
        return
    end
    if button == "RightButton" then
        ns:SetTracked(self.info.itemID, false)
    else
        if ns.UI then ns.UI:Open(nil, self.info.itemID) end
    end
end

------------------------------------------------------------------------
-- Coordinate translation (zone -> currently shown map)
------------------------------------------------------------------------
local rectCache = {}

local function GetZoneRect(zoneMapID, onMapID)
    local key = zoneMapID .. ">" .. onMapID
    if rectCache[key] ~= nil then return unpack(rectCache[key]) end
    if not (C_Map and C_Map.GetMapRectOnMap) then rectCache[key] = {} return end
    local ok, left, right, top, bottom = pcall(C_Map.GetMapRectOnMap, zoneMapID, onMapID)
    if ok and left and right and right > left then
        rectCache[key] = { left, right, top, bottom }
        return left, right, top, bottom
    end
    rectCache[key] = {}
end

-- x, y, r in 0-1 of zoneMapID; returns translated values or nil
local function Translate(zoneMapID, x, y, r, mapID)
    if zoneMapID == mapID then return x, y, r end
    if not ns.db.settings.showOnContinent then return end
    local left, right, top, bottom = GetZoneRect(zoneMapID, mapID)
    if not left then return end
    local w, h = right - left, bottom - top
    return left + x * w, top + y * h, r * w
end

------------------------------------------------------------------------
-- Data provider
------------------------------------------------------------------------
local Provider = CreateFromMixins(MapCanvasDataProviderMixin)
ns.MapProvider = Provider

function Provider:RemoveAllData()
    local map = self:GetMap()
    map:RemoveAllPinsByTemplate(AREA_TEMPLATE)
    map:RemoveAllPinsByTemplate(ICON_TEMPLATE)
end

function Provider:RefreshAllData()
    self:RemoveAllData()
    if not ns.db then return end
    local map = self:GetMap()
    local mapID = map:GetMapID()
    if not mapID then return end

    -- single waypoint (recipe vendor / trainer)
    local wp = ns.waypoint
    if wp then
        local x, y
        if wp.mapID == mapID then x, y = wp.x / 100, wp.y / 100
        else x, y = Translate(wp.mapID, wp.x / 100, wp.y / 100, 0, mapID) end
        if x then
            map:AcquirePin(ICON_TEMPLATE, { waypoint = true, icon = "Interface\\Icons\\INV_Scroll_03",
                x = x, y = y, cr = 1, cg = 0.82, cb = 0, label = wp.label, sub = wp.sub })
        end
    end
    -- profession trainers (Guide tab: click a profession header to switch them)
    if ns.TrainerPins then
        local mi = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local zoneLevel = mi and mi.mapType and mi.mapType >= 3
        for _, t in ipairs(ns:TrainerPins()) do
            local x, y
            if t.mapID == mapID then x, y = t.x / 100, t.y / 100
            elseif zoneLevel then x, y = Translate(t.mapID, t.x / 100, t.y / 100, 0, mapID) end
            if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local cc = ns.CAT_COLORS[t.prof] or ns.CAT_COLORS.learned
                map:AcquirePin(ICON_TEMPLATE, { trainer = true, icon = ns.Guides[t.prof].icon, x = x, y = y,
                    cr = cc[1], cg = cc[2], cb = cc[3], label = t.npc, prof = t.prof, sub = t.note, rank = t.rank })
            end
        end
    end
    if not ns.db.settings.showOnMap then return end

    for itemID in pairs(ns.db.tracked) do
        local cr, cg, cb = ns:GetTrackColor(itemID)
        local data = ns.Items[itemID]
        local learnedZones = {}
        for _, lz in ipairs(ns:GetLearnedZones(itemID)) do learnedZones[lz.mapID] = lz end

        -- built-in areas
        if data then
            for _, s in ipairs(data.spots) do
                local zMap = ns:ResolveZone(s.z)
                if zMap then
                    local x, y, r = Translate(zMap, s.x / 100, s.y / 100, (s.r or 6) / 100, mapID)
                    if x then
                        local lz = learnedZones[zMap]
                        local info = {
                            itemID = itemID, zoneKey = s.z, spot = s,
                            x = x, y = y, r = r, cr = cr, cg = cg, cb = cb,
                            learnedCount = lz and lz.n or 0,
                        }
                        map:AcquirePin(AREA_TEMPLATE, info)
                        map:AcquirePin(ICON_TEMPLATE, info)
                    end
                end
            end
        end

        -- learned spots (small solid dots)
        for zMap, lz in pairs(learnedZones) do
            for _, c in ipairs(lz.cells) do
                local x, y, r = Translate(zMap, c.x / 100, c.y / 100, 0.006, mapID)
                if x then
                    map:AcquirePin(AREA_TEMPLATE, {
                        itemID = itemID, x = x, y = y, r = r, learned = true,
                        cr = cr, cg = cg, cb = cb,
                    })
                end
            end
            -- one icon per learned zone without built-in data
            if not data and lz.cells[1] then
                local best = lz.cells[1]
                for _, c in ipairs(lz.cells) do if c.n > best.n then best = c end end
                local x, y = Translate(zMap, best.x / 100, best.y / 100, 0, mapID)
                if x then
                    map:AcquirePin(ICON_TEMPLATE, {
                        itemID = itemID, zoneKey = ns:ZoneKeyForMap(zMap) or zMap,
                        x = x, y = y, cr = cr, cg = cg, cb = cb, learnedCount = lz.n,
                    })
                end
            end
        end
    end
end

function Provider:OnMapChanged()
    self:RefreshAllData()
end

------------------------------------------------------------------------
-- Map overlay button + banner
------------------------------------------------------------------------
local function CreateMapButton()
    local parent = WorldMapFrame.ScrollContainer or WorldMapFrame
    local btn = CreateFrame("Button", "FarmAtlasMapButton", parent, "BackdropTemplate")
    btn:SetSize(120, 24)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
    btn:SetFrameStrata("HIGH")
    btn:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    btn:SetBackdropColor(0.06, 0.07, 0.09, 0.88)
    btn:SetBackdropBorderColor(0.25, 0.78, 0.92, 0.7)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(16, 16)
    btn.icon:SetPoint("LEFT", 5, 0)
    btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.text:SetPoint("RIGHT", -6, 0)
    btn.text:SetJustifyH("LEFT")

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.db.settings.showOnMap = not ns.db.settings.showOnMap
            ns:Fire("TRACKING_CHANGED")
        elseif ns.UI then
            ns.UI:Toggle()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.25, 0.78, 0.92, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("FarmAtlas")
        local n = ns:CountTracked()
        if n == 0 then
            GameTooltip:AddLine(L("mb_nothing"), 0.7, 0.7, 0.7)
        else
            for id in pairs(ns.db.tracked) do
                local r, g, b = ns:GetTrackColor(id)
                GameTooltip:AddLine((ns:GetItemName(id)), r, g, b)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("mb_hint"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.78, 0.92, 0.7)
        GameTooltip:Hide()
    end)

    function btn:Update()
        local n = ns:CountTracked()
        local state = ns.db.settings.showOnMap and "" or (" |cffff5555" .. L("mb_off") .. "|r")
        if n == 0 then
            self.text:SetText("FarmAtlas" .. state)
        else
            self.text:SetText(L("mb_tracking", n) .. state)
        end
        self:SetWidth(math.max(110, self.text:GetStringWidth() + 36))
    end
    btn:Update()
    ns.MapButton = btn

    -- small goals icon next to it
    local g = CreateFrame("Button", "FarmAtlasMapGoalsButton", parent, "BackdropTemplate")
    g:SetSize(24, 24)
    g:SetPoint("RIGHT", btn, "LEFT", -4, 0)
    g:SetFrameStrata("HIGH")
    g:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    g:SetBackdropColor(0.06, 0.07, 0.09, 0.88)
    g:SetBackdropBorderColor(1, 0.82, 0, 0.7)
    g.icon = g:CreateTexture(nil, "ARTWORK")
    g.icon:SetSize(16, 16)
    g.icon:SetPoint("CENTER")
    g.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    g.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    g:SetScript("OnClick", function() if ns.Goals then ns.Goals:Toggle() end end)
    g:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine(L("goals_title"), 1, 0.82, 0)
        GameTooltip:AddLine(L("mb_goals_hint"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    g:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 0.7)
        GameTooltip:Hide()
    end)
end

------------------------------------------------------------------------
-- Hook up
------------------------------------------------------------------------
local installed = false
local function Install()
    if installed or not WorldMapFrame or not WorldMapFrame.AddDataProvider then return end
    installed = true
    WorldMapFrame:AddDataProvider(Provider)
    CreateMapButton()
end

local function Refresh()
    if ns.MapButton then ns.MapButton:Update() end
    if installed and WorldMapFrame:IsShown() then Provider:RefreshAllData() end
end

ns:On("LOGIN", Install)
ns:On("TRACKING_CHANGED", Refresh)
ns:On("LEARNED_CHANGED", Refresh)
ns:On("LANG_CHANGED", Refresh)

local f = CreateFrame("Frame")
ns:SafeRegister(f, "ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_WorldMap" then Install() end
end)
