-- FarmAtlas - minimap farm areas (no library needed)
--   * a translucent circle when the farm area fits on the minimap
--   * the item icon on the minimap edge (direction) when it is further away
--   * a colored glow around the minimap while you stand inside a farm area
-- Position math uses map coordinates -> world yards (C_Map.GetWorldPosFromMapPos),
-- no restricted APIs.
local _, ns = ...
local L = ns.L

local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local UPDATE_EVERY = 0.15
local MAX_PINS = 24

-- minimap diameter in yards per zoom level (same values HereBeDragons uses)
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }

local pins, glow = {}, nil
local spots = {}        -- cached { itemID, mapID, x, y, r, cr, cg, cb, cont, wx, wy, wr }
local dirty = true

------------------------------------------------------------------------
-- world positions
------------------------------------------------------------------------
local worldCache = {}
local function WorldPos(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local key = mapID .. ":" .. x .. ":" .. y
    local c = worldCache[key]
    if c == nil then
        local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
        if ok and cont and pos then
            c = { cont, pos.x, pos.y }
        else
            c = false
        end
        worldCache[key] = c
    end
    if c then return c[1], c[2], c[3] end
end

local function Rebuild()
    wipe(spots)
    dirty = false
    if not (ns.db and ns.db.settings.showOnMinimap) then return end
    for itemID in pairs(ns.db.tracked) do
        local data = ns.Items[itemID]
        local cr, cg, cb = ns:GetTrackColor(itemID)
        local function add(mapID, x, y, r)
            local cont, wx, wy = WorldPos(mapID, x, y)
            if not cont then return end
            -- radius in yards: measure along the map's x axis
            local _, ex = WorldPos(mapID, math.min(1, x + r), y)
            local _, _, ey = WorldPos(mapID, math.min(1, x + r), y)
            local wr = 0
            if ex then wr = math.sqrt((ex - wx) ^ 2 + (ey - wy) ^ 2) end
            spots[#spots + 1] = { itemID = itemID, mapID = mapID, cont = cont, wx = wx, wy = wy,
                wr = math.max(wr, 15), cr = cr, cg = cg, cb = cb }
        end
        if data then
            for _, s in ipairs(data.spots or {}) do
                local mapID = ns:ResolveZone(s.z)
                if mapID then add(mapID, s.x / 100, s.y / 100, (s.r or 6) / 100) end
            end
        end
        -- your learned spots (the strongest cell per zone)
        for _, lz in ipairs(ns:GetLearnedZones(itemID)) do
            local best
            for _, c in ipairs(lz.cells) do if not best or c.n > best.n then best = c end end
            if best and not data then add(lz.mapID, best.x / 100, best.y / 100, 0.02) end
        end
    end
end

------------------------------------------------------------------------
-- pins
------------------------------------------------------------------------
local function NewPin()
    local p = CreateFrame("Frame", nil, Minimap)
    p:SetFrameStrata(Minimap:GetFrameStrata())
    p:SetFrameLevel(Minimap:GetFrameLevel() + 4)

    p.area = CreateFrame("Frame", nil, p)
    p.area:SetPoint("CENTER")
    p.areaTex = p.area:CreateTexture(nil, "BACKGROUND")
    p.areaTex:SetTexture(CIRCLE)
    p.areaTex:SetAllPoints()

    p.icon = CreateFrame("Frame", nil, p)
    p.icon:SetSize(16, 16)
    p.icon:SetPoint("CENTER")
    p.icon:SetFrameLevel(p:GetFrameLevel() + 2)
    p.ring = p.icon:CreateTexture(nil, "BACKGROUND")
    p.ring:SetTexture(CIRCLE)
    p.ring:SetPoint("TOPLEFT", -2, 2)
    p.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    p.tex = p.icon:CreateTexture(nil, "ARTWORK")
    p.tex:SetAllPoints()
    p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = p.icon:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(p.tex)
    p.tex:AddMaskTexture(mask)

    p.icon:EnableMouse(true)
    p.icon:SetScript("OnEnter", function(self)
        local s = p.spot
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns:GetItemColoredName(s.itemID))
        GameTooltip:AddLine(ns:ZoneName(ns:ZoneKeyForMap(s.mapID) or s.mapID), 0.7, 0.7, 0.7)
        if p.dist then
            GameTooltip:AddLine(L("mm_dist", math.floor(p.dist + 0.5)), 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    p.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.icon:SetScript("OnMouseUp", function()
        if p.spot and ns.UI then ns.UI:Open(nil, p.spot.itemID) end
    end)
    return p
end

local function Glow()
    if glow then return glow end
    glow = CreateFrame("Frame", nil, Minimap)
    glow:SetFrameLevel(Minimap:GetFrameLevel() + 3)
    glow:SetPoint("CENTER")
    glow.dots = {}
    for i = 1, 40 do
        local d = glow:CreateTexture(nil, "OVERLAY")
        d:SetColorTexture(1, 1, 1, 1)
        d:SetSize(5, 3)
        glow.dots[i] = d
    end
    glow:Hide()
    return glow
end

local function ShowGlow(r, g, b)
    local gl = Glow()
    local w = Minimap:GetWidth()
    gl:SetSize(w, w)
    local radius = w / 2 - 2
    for i, d in ipairs(gl.dots) do
        local a = (i / #gl.dots) * 2 * math.pi
        d:ClearAllPoints()
        d:SetPoint("CENTER", gl, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
        d:SetRotation(a + math.pi / 2)
        d:SetVertexColor(r, g, b, 0.95)
    end
    gl:Show()
end

------------------------------------------------------------------------
-- update loop
------------------------------------------------------------------------
local function HideAll()
    for _, p in ipairs(pins) do p:Hide() end
    if glow then glow:Hide() end
end

local function Update()
    if not (ns.db and ns.db.settings.showOnMinimap) or not Minimap:IsVisible() then
        HideAll()
        return
    end
    if dirty then Rebuild() end
    if #spots == 0 then HideAll() return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then HideAll() return end
    local px, py = pos:GetXY()
    local cont, pwx, pwy = WorldPos(mapID, px, py)
    worldCache[mapID .. ":" .. px .. ":" .. py] = nil -- player moves: don't cache
    if not cont then HideAll() return end

    local zoom = Minimap:GetZoom() or 0
    local indoors = IsIndoors and IsIndoors()
    local diameter = (indoors and INDOOR or OUTDOOR)[zoom] or 466
    local w = Minimap:GetWidth()
    local scale = w / diameter           -- pixels per yard
    local mapRadius = w / 2

    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing
    if rotate and GetPlayerFacing then
        local ok, f = pcall(GetPlayerFacing)
        if ok then facing = ns.Plain(f) end
    end
    local cosF, sinF
    if facing then cosF, sinF = math.cos(facing), math.sin(facing) end

    local used, inside = 0, nil
    for _, s in ipairs(spots) do
        if s.cont == cont and used < MAX_PINS then
            -- world: x grows north, y grows west
            local north = s.wx - pwx
            local west = s.wy - pwy
            local dist = math.sqrt(north * north + west * west)
            if dist <= s.wr then inside = inside or s end
            local sx, sy = -west * scale, north * scale
            if facing then
                sx, sy = sx * cosF - sy * sinF, sx * sinF + sy * cosF
            end
            local pd = math.sqrt(sx * sx + sy * sy)
            local rpx = s.wr * scale
            used = used + 1
            local p = pins[used] or NewPin()
            pins[used] = p
            p.spot, p.dist = s, math.max(0, dist - s.wr)
            p.ring:SetVertexColor(s.cr, s.cg, s.cb, 1)
            p.tex:SetTexture(ns:GetItemIcon(s.itemID))
            p:ClearAllPoints()
            if pd + rpx <= mapRadius - 2 and dist > s.wr then
                -- whole area fits: translucent circle + icon in the middle
                p:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
                p:SetSize(rpx * 2, rpx * 2)
                p.area:SetSize(rpx * 2, rpx * 2)
                p.areaTex:SetVertexColor(s.cr, s.cg, s.cb, 1)
                p.area:SetAlpha(0.28)
                p.area:Show()
                p.icon:SetAlpha(1)
            elseif dist > s.wr then
                -- too far: icon on the minimap edge, pointing to the area
                local k = (mapRadius - 8) / math.max(pd, 1)
                p:SetPoint("CENTER", Minimap, "CENTER", sx * k, sy * k)
                p:SetSize(16, 16)
                p.area:Hide()
                p.icon:SetAlpha(0.85)
            else
                -- you are inside: the glow shows it, no extra pin
                p.area:Hide()
                p:Hide()
                used = used - 1
                p = nil
            end
            if p then p:Show() end
        end
    end
    for i = used + 1, #pins do pins[i]:Hide() end
    if inside then ShowGlow(inside.cr, inside.cg, inside.cb) elseif glow then glow:Hide() end
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    -- restricted positions (instances, secret values) must never spam errors
    if not pcall(Update) then HideAll() end
end)

local function MarkDirty() dirty = true end
ns:On("TRACKING_CHANGED", MarkDirty)
ns:On("LEARNED_CHANGED", MarkDirty)
ns:On("DB_READY", MarkDirty)
