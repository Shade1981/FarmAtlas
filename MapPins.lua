-- FarmAtlas - World map pins (data provider + pin mixins)
local _, ns = ...
local L = ns.L

local AREA_TEMPLATE = "FarmAtlasAreaPinTemplate"
local ICON_TEMPLATE = "FarmAtlasIconPinTemplate"
local SHAPE_TEMPLATE = "FarmAtlasShapePinTemplate"
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
-- Shape pin: a farm area shaped like the real spots (grid cells from loot)
--   info.region (Shapes.lua), info.cr/cg/cb; drawn only on the zone's own map
------------------------------------------------------------------------
FarmAtlasShapePinMixin = CreateFromMixins(MapCanvasPinMixin)

function FarmAtlasShapePinMixin:OnLoad()
    if self.faBuilt then return end
    self.faBuilt = true
    self.SetPassThroughButtons = function() end
    self.SetPropagateMouseClicks = function() end
    self.SetPropagateMouseMotion = function() end
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self.FillFrame = CreateFrame("Frame", nil, self)
    self.FillFrame:SetAllPoints()
    self.EdgeFrame = CreateFrame("Frame", nil, self)
    self.EdgeFrame:SetAllPoints()
    self.squares, self.dashes = {}, {}
    self:EnableMouse(false)
end

function FarmAtlasShapePinMixin:ApplyFrameLevel()
    self:SetFrameLevel(BaseLevel(self) - 2)
end

local function CanvasSize(map)
    local c = map:GetCanvas()
    return c:GetWidth(), c:GetHeight()
end

function FarmAtlasShapePinMixin:OnAcquired(info)
    self.info = info
    local reg = info.region
    local cw, ch = CanvasSize(self:GetMap())
    local cell = ns.SHAPE_CELL or 2
    local w = (reg.maxX - reg.minX) / 100 * cw
    local h = (reg.maxY - reg.minY) / 100 * ch
    local cpx, cpy = cell / 100 * cw, cell / 100 * ch
    self:SetSize(math.max(w, 1), math.max(h, 1))
    local r, g, b = info.cr, info.cg, info.cb
    -- cells tile exactly (no overlap), so one alpha on the frame looks even
    self.FillFrame:SetAlpha(math.min((ns.db.settings.areaAlpha or 0.12) * 1.5, 0.4))
    local used = 0
    for _, c in ipairs(reg.cells) do
        used = used + 1
        local t = self.squares[used]
        if not t then
            t = self.FillFrame:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, 1)
            self.squares[used] = t
        end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", self.FillFrame, "TOPLEFT", (c[1] * cell - reg.minX) / 100 * cw, -((c[2] * cell - reg.minY) / 100 * ch))
        t:SetSize(cpx, cpy)
        t:SetVertexColor(r, g, b, 1)
        t:Show()
    end
    for i = used + 1, #self.squares do self.squares[i]:Hide() end
    -- dashed outline along the outer edges (like quest areas)
    local d = 0
    local dash = math.max(2, math.min(4, cpx / 6))
    local function Dash(x, y, horizontal, len)
        d = d + 1
        local t = self.dashes[d]
        if not t then
            t = self.EdgeFrame:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(1, 1, 1, 1)
            self.dashes[d] = t
        end
        t:ClearAllPoints()
        t:SetPoint("CENTER", self.EdgeFrame, "TOPLEFT", x, -y)
        if horizontal then t:SetSize(len, dash) else t:SetSize(dash, len) end
        t:SetVertexColor(r, g, b, 0.95)
        t:Show()
    end
    for _, c in ipairs(reg.cells) do
        local x0 = (c[1] * cell - reg.minX) / 100 * cw
        local y0 = (c[2] * cell - reg.minY) / 100 * ch
        local function has(dx, dy) return reg.set[(c[1] + dx) .. ":" .. (c[2] + dy)] end
        if not has(0, -1) then Dash(x0 + cpx * 0.25, y0, true, cpx * 0.35); Dash(x0 + cpx * 0.75, y0, true, cpx * 0.35) end
        if not has(0, 1) then Dash(x0 + cpx * 0.25, y0 + cpy, true, cpx * 0.35); Dash(x0 + cpx * 0.75, y0 + cpy, true, cpx * 0.35) end
        if not has(-1, 0) then Dash(x0, y0 + cpy * 0.25, false, cpy * 0.35); Dash(x0, y0 + cpy * 0.75, false, cpy * 0.35) end
        if not has(1, 0) then Dash(x0 + cpx, y0 + cpy * 0.25, false, cpy * 0.35); Dash(x0 + cpx, y0 + cpy * 0.75, false, cpy * 0.35) end
    end
    for i = d + 1, #self.dashes do self.dashes[i]:Hide() end
    self:SetPosition((reg.minX + reg.maxX) / 200, (reg.minY + reg.maxY) / 200)
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
    local sz = info.small or 22
    if self.SetSize then self:SetSize(sz, sz) end
    if self.SetAlpha then self:SetAlpha(info.nodePin == "known" and 0.85 or 1) end
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
    if info.nodePin then
        tip:AddLine(ns:GetItemName(info.itemID) or "?", 1, 1, 1)
        if info.nodePin == "site" and info.site then
            tip:ClearLines()
            ns:FishSiteTooltip(tip, info.site)
        elseif info.nodePin == "water" then
            tip:AddLine(L("np_water"), 0.55, 0.8, 1, true)
            if info.spot and info.spot.lvl then tip:AddLine(info.spot.lvl, 0.8, 0.8, 0.8) end
        elseif info.nodePin == "learned" then
            tip:AddLine(L("np_learned", info.n or 1), 0.6, 1, 0.6)
        else
            tip:AddLine(L("np_known"), 0.8, 0.8, 0.8)
        end
        tip:Show()
        return
    end
    if info.guideArea then
        local a = info.guideArea
        tip:AddLine(L("g_area_title"), 1, 0.82, 0)
        tip:AddLine(a.label, 1, 1, 1)
        if a.step.mobs then tip:AddLine(L("g_mobs") .. " " .. a.step.mobs, 0.8, 0.8, 0.8, true) end
        if a.note then tip:AddLine(a.note, 0.6, 0.85, 1, true) end
        tip:AddLine(" ")
        tip:AddLine(a.focus and L("g_area_hint") or L("g_pin_guide"), 0.8, 0.8, 0.8, true)
        tip:Show()
        return
    end
    if info.trainer then
        tip:AddLine(info.label or "?", 1, 0.82, 0)
        tip:AddLine(L("cat_" .. info.prof) .. (info.rank and (" - " .. info.rank) or (" - " .. L("g_trainer"))), 1, 1, 1)
        if info.special then
            -- a quest giver or book vendor, not a trainer: say so, with what is needed
            tip:AddLine(L("g_special"), 1, 0.5, 0.3, true)
            if info.need then tip:AddLine(L("g_need", info.need), 1, 0.5, 0.3) end
        end
        if info.sub then tip:AddLine(info.sub, 0.7, 0.7, 0.7, true) end
        if info.guide then tip:AddLine(L("g_pin_guide"), 0.4, 1, 0.45, true) end
        if info.town then tip:AddLine(L("g_pin_town"), 0.25, 0.78, 0.92, true) end
        if not (info.guide or info.town) then
            tip:AddLine(" ")
            tip:AddLine(L("g_pin_hint"), 0.8, 0.8, 0.8, true)
        end
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
    if self.info.guideArea then
        if button == "RightButton" and self.info.guideArea.focus then ns:SetGuideFocus(nil) end
        return
    end
    if self.info.trainer then
        if button == "RightButton" and not (self.info.guide or self.info.town) then ns:SetTrainerPins(self.info.prof, false) end
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

-- Combat: acquiring or releasing pins from addon code marks the map canvas
-- dirty with a tainted value; the map then redraws Blizzard's own pins in a
-- tainted state and the client blocks Button:SetPassThroughButtons() for them.
-- So during combat FarmAtlas never acquires/releases pins: it only hides its
-- own pins when the shown map changes, and redraws once combat is over.
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local combatDeferred = false

local function HideOwnPins(map)
    for _, tpl in ipairs({ AREA_TEMPLATE, ICON_TEMPLATE, SHAPE_TEMPLATE }) do
        for pin in map:EnumeratePinsByTemplate(tpl) do pin:Hide() end
    end
end

function Provider:RemoveAllData()
    local map = self:GetMap()
    if not map then return end
    if InCombat() then
        combatDeferred = true
        self.faDrawnMap = nil
        HideOwnPins(map)
        return
    end
    map:RemoveAllPinsByTemplate(AREA_TEMPLATE)
    map:RemoveAllPinsByTemplate(ICON_TEMPLATE)
    map:RemoveAllPinsByTemplate(SHAPE_TEMPLATE)
end

function Provider:RefreshAllData()
    local map = self:GetMap()
    if not map then return end
    if InCombat() then
        combatDeferred = true
        if map:GetMapID() ~= self.faDrawnMap then
            self.faDrawnMap = nil
            HideOwnPins(map)
        end
        return
    end
    combatDeferred = false
    self:RemoveAllData()
    self.faDrawnMap = nil
    if not ns.db then return end
    local mapID = map:GetMapID()
    if not mapID then return end
    self.faDrawnMap = mapID

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
        for _, t in ipairs(ns:MapTrainerList()) do
            local x, y
            if t.mapID == mapID then x, y = t.x / 100, t.y / 100
            elseif zoneLevel then x, y = Translate(t.mapID, t.x / 100, t.y / 100, 0, mapID) end
            if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
                local cc = ns.CAT_COLORS[t.prof] or ns.CAT_COLORS.learned
                -- ring: gold = current guide step, blue = the place you are in, else the profession color
                local r, g, b = cc[1], cc[2], cc[3]
                if t.guide then r, g, b = 1, 0.82, 0 elseif t.town then r, g, b = 0.247, 0.780, 0.922 end
                map:AcquirePin(ICON_TEMPLATE, { trainer = true, icon = ns.Guides[t.prof].icon, x = x, y = y,
                    cr = r, cg = g, cb = b,
                    label = t.npc, prof = t.prof, sub = t.note, rank = t.rank, guide = t.guide, town = t.town,
                    special = t.special, need = t.need })
            end
        end
    end
    -- guide: where to fish / skin for the clicked step and the step you are on
    if ns.GuideAreas then
        for _, area in ipairs(ns:GuideAreas()) do
            if area.maps[mapID] then
                local spots = ns:GuideAreaSpots(area, mapID)
                -- the marker goes on a real spot (the one nearest to you), never on
                -- the average of several spots: that can fall on dry land
                local px, py
                if C_Map and C_Map.GetPlayerMapPosition then
                    local p = C_Map.GetPlayerMapPosition(mapID, "player")
                    if p then px, py = p:GetXY(); if px then px, py = px * 100, py * 100 end end
                end
                local best, bestD
                local wantFish = {}
                for _, e in ipairs(spots) do
                    local s = e.spot
                    if area.prof == "fishing" and ns.FISH_SITES then
                        wantFish[e.itemID] = true
                    else
                        local info = { itemID = e.itemID, zoneKey = s.z, spot = s, x = s.x / 100, y = s.y / 100,
                            r = (s.r or 6) / 100, cr = 1, cg = 0.82, cb = 0 }
                        map:AcquirePin(AREA_TEMPLATE, info)
                        map:AcquirePin(ICON_TEMPLATE, info)
                        local d = px and ((s.x - px) ^ 2 + (s.y - py) ^ 2) or (best and math.huge or 0)
                        if not bestD or d < bestD then best, bestD = s, d end
                    end
                end
                -- fishing step: the fishing places of this map that offer the step's fish
                if area.prof == "fishing" and ns.FISH_SITES then
                    for _, site in ipairs(ns.FISH_SITES[mapID] or {}) do
                        local any
                        for id in pairs(wantFish) do if site.fish[id] then any = id end end
                        if any then
                            map:AcquirePin(ICON_TEMPLATE, { itemID = any, x = site.x / 100, y = site.y / 100, small = 18,
                                nodePin = "site", site = site, cr = 1, cg = 0.82, cb = 0 })
                            local d = px and ((site.x - px) ^ 2 + (site.y - py) ^ 2) or (best and math.huge or 0)
                            if not bestD or d < bestD then best, bestD = { x = site.x, y = site.y, r = 3 }, d end
                        end
                    end
                end
                -- one guide marker on the edge of that spot (right-click clears a clicked step);
                -- no spot on this map = no marker, instead of a pin in the middle of nowhere
                if best then
                    local gx, gy = best.x / 100, (best.y - (best.r or 6) * 0.7) / 100
                    map:AcquirePin(ICON_TEMPLATE, { guideArea = area, icon = ns.Guides[area.prof].icon,
                        x = math.max(0.03, math.min(0.97, gx)), y = math.max(0.03, math.min(0.97, gy)),
                        cr = 1, cg = 0.82, cb = 0 })
                end
            end
        end
    end

    if not ns.db.settings.showOnMap then return end

    local drawnSites = {}
    for itemID in pairs(ns.db.tracked) do
        local cr, cg, cb = ns:GetTrackColor(itemID)
        local data = ns.Items[itemID]
        local learnedZones = {}
        for _, lz in ipairs(ns:GetLearnedZones(itemID)) do learnedZones[lz.mapID] = lz end
        -- real-shape areas on the zone's own map (enough loot recorded there)
        local shaped = {}
        -- herbs / ore are single nodes: an area shape would only draw blobs
        -- around each gathered node, so these keep their exact dots instead
        local cat = (data and data.cat) or (ns.db.learned[itemID] and ns.db.learned[itemID].cat)
        local isNode = cat == "herbalism" or cat == "mining"
        -- exact node positions from an installed node addon (Questie / GatherMate2)
        local ext = ns.ExternalNodes and ns:ExternalNodes(itemID) or nil
        -- area shapes from learned loot are retired: with a few loots they only
        -- drew confusing blobs. Exact spots are shown as small item icons instead.
        if false and ns.LearnedRegions and learnedZones[mapID] and not isNode then
            local regions = ns:LearnedRegions(itemID, mapID)
            if #regions > 0 then
                shaped[mapID] = true
                for _, reg in ipairs(regions) do
                    map:AcquirePin(SHAPE_TEMPLATE, { itemID = itemID, region = reg, cr = cr, cg = cg, cb = cb })
                end
                if not data then
                    local reg = regions[1]
                    map:AcquirePin(ICON_TEMPLATE, { itemID = itemID, zoneKey = ns:ZoneKeyForMap(mapID) or mapID,
                        x = reg.cx / 100, y = reg.cy / 100, cr = cr, cg = cg, cb = cb, learnedCount = learnedZones[mapID].n })
                end
            end
        end

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
                        -- the real shape replaces the circle; the icon stays.
                        -- exact nodes known for this zone: no circle and no icon at all
                        if cat == "fishing" and ns.FISH_SITES then
                            -- fish: drawn below as one marker per water, never a circle over land
                        elseif not (isNode and ext and ext[zMap] and #ext[zMap] > 0) then
                            if not shaped[zMap] then map:AcquirePin(AREA_TEMPLATE, info) end
                            map:AcquirePin(ICON_TEMPLATE, info)
                        end
                    end
                end
            end
        end

        -- fishing places: one marker per water (a new one where the catch changes)
        if cat == "fishing" and ns.FishSitesFor then
            for _, e in ipairs(ns:FishSitesFor(itemID)) do
                if not drawnSites[e.site] then
                    local wx, wy = Translate(e.mapID, e.site.x / 100, e.site.y / 100, 0, mapID)
                    if wx then
                        drawnSites[e.site] = true
                        map:AcquirePin(ICON_TEMPLATE, { itemID = itemID, x = wx, y = wy, small = 18,
                            nodePin = "site", site = e.site, cr = cr, cg = cg, cb = cb })
                    end
                end
            end
        end

        -- exact nodes of this zone (only on the zone's own map: hundreds of them)
        if ext and ext[mapID] then
            for _, pt in ipairs(ext[mapID]) do
                map:AcquirePin(ICON_TEMPLATE, {
                    itemID = itemID, x = pt[1] / 100, y = pt[2] / 100, small = 11, nodePin = "known", node = true,
                    cr = cr, cg = cg, cb = cb,
                })
            end
        end

        -- learned spots (small solid dots) where no shape is drawn
        for zMap, lz in pairs(learnedZones) do
            if shaped[zMap] then lz = { cells = {} } end
            for _, c in ipairs(lz.cells) do
                -- only on the zone's own map (on a continent they are just noise)
                if zMap == mapID then
                    map:AcquirePin(ICON_TEMPLATE, {
                        itemID = itemID, x = c.x / 100, y = c.y / 100, small = 13, nodePin = "learned", n = c.n,
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

-- redraw once combat is over if something changed during combat
local regen = CreateFrame("Frame")
ns:SafeRegister(regen, "PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if not combatDeferred then return end
    combatDeferred = false
    if installed and WorldMapFrame and WorldMapFrame:IsShown() and Provider.GetMap and Provider:GetMap() then
        pcall(Provider.RefreshAllData, Provider)
    end
end)

-- town trainers changed -> redraw the open world map
ns:On("TOWN_TRAINERS_CHANGED", function()
    if WorldMapFrame and WorldMapFrame:IsShown() and Provider.GetMap and Provider:GetMap() then
        pcall(Provider.RefreshAllData, Provider)
    end
end)
