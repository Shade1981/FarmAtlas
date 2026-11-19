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
local MAX_PINS = 80

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
    local seenSites = {}
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
        -- real-shape regions (enough loot recorded in that zone)
        local shaped = {}
        local cat = (data and data.cat) or (ns.db.learned[itemID] and ns.db.learned[itemID].cat)
        if false and ns.LearnedRegions and cat ~= "herbalism" and cat ~= "mining" then
            for _, lz in ipairs(ns:GetLearnedZones(itemID)) do
                local regions = ns:LearnedRegions(itemID, lz.mapID)
                local cell = ns.SHAPE_CELL or 2
                for _, reg in ipairs(regions) do
                    local cont, wx, wy = WorldPos(lz.mapID, reg.cx / 100, reg.cy / 100)
                    if cont then
                        shaped[lz.mapID] = true
                        local cells, far = {}, 0
                        for _, c in ipairs(reg.cells) do
                            local cc, cx, cy = WorldPos(lz.mapID, (c[1] + 0.5) * cell / 100, (c[2] + 0.5) * cell / 100)
                            if cc == cont then
                                cells[#cells + 1] = { cx, cy }
                                far = math.max(far, math.sqrt((cx - wx) ^ 2 + (cy - wy) ^ 2))
                            end
                        end
                        local _, ax, ay = WorldPos(lz.mapID, 0, 0)
                        local _, bx, by = WorldPos(lz.mapID, cell / 100, 0)
                        local cellYds = (ax and bx) and math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) or 30
                        spots[#spots + 1] = { itemID = itemID, mapID = lz.mapID, cont = cont, wx = wx, wy = wy,
                            wr = math.max(far + cellYds / 2, 15), cr = cr, cg = cg, cb = cb,
                            region = reg, cells = cells, cellYds = cellYds }
                    end
                end
            end
        end
        local ext = ns.ExternalNodes and ns:ExternalNodes(itemID) or nil
        if data then
            for _, s in ipairs(data.spots or {}) do
                local mapID = ns:ResolveZone(s.z)
                -- herbs / ore: exact nodes replace the area; fish keep their water area
                local exact = cat ~= "fishing" and ext and ext[mapID] and #ext[mapID] > 0
                if cat == "fishing" and ns.FISH_SITES then
                    -- fish: the fishing places below, never a circle over land
                elseif mapID and not shaped[mapID] and not exact then add(mapID, s.x / 100, s.y / 100, (s.r or 6) / 100) end
            end
        end
        -- fishing places: one icon per water (shared by every tracked fish there)
        if cat == "fishing" and ns.FishSitesFor then
            for _, e in ipairs(ns:FishSitesFor(itemID)) do
                if not seenSites[e.site] then
                    seenSites[e.site] = true
                    local cont, wx, wy = WorldPos(e.mapID, e.site.x / 100, e.site.y / 100)
                    if cont then
                        spots[#spots + 1] = { itemID = itemID, mapID = e.mapID, cont = cont, wx = wx, wy = wy,
                            wr = 6, dot = true, site = e.site, cr = cr, cg = cg, cb = cb }
                    end
                end
            end
        end
        -- exact nodes from an installed node addon: small icons like the gathered ones
        if ext then
            for mapID, list in pairs(ext) do
                for _, pt in ipairs(list) do
                    local cont, wx, wy = WorldPos(mapID, pt[1] / 100, pt[2] / 100)
                    if cont then
                        spots[#spots + 1] = { itemID = itemID, mapID = mapID, cont = cont, wx = wx, wy = wy,
                            wr = 6, dot = true, ext = true, cr = cr, cg = cg, cb = cb }
                    end
                end
            end
        end
        -- every place a node / item was actually gathered: a small exact dot,
        -- right from the first gather (no waiting for the area shape)
        for _, lz in ipairs(ns:GetLearnedZones(itemID)) do
            for _, c in ipairs(lz.cells) do
                local cont, wx, wy = WorldPos(lz.mapID, c.x / 100, c.y / 100)
                if cont then
                    spots[#spots + 1] = { itemID = itemID, mapID = lz.mapID, cont = cont, wx = wx, wy = wy,
                        wr = 6, dot = true, cr = cr, cg = cg, cb = cb }
                end
            end
        end
        -- your learned spots (the strongest cell per zone)
        for _, lz in ipairs(ns:GetLearnedZones(itemID)) do
            local best
            for _, c in ipairs(lz.cells) do if not best or c.n > best.n then best = c end end
            if best and not data and not shaped[lz.mapID] then add(lz.mapID, best.x / 100, best.y / 100, 0.02) end
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
        if s.site then
            ns:FishSiteTooltip(GameTooltip, s.site)
        else
            GameTooltip:AddLine(ns:GetItemColoredName(s.itemID))
        end
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
            local isInside
            if s.region then
                if mapID == s.mapID then
                    local cell = ns.SHAPE_CELL or 2
                    isInside = s.region.set[math.floor(px * 100 / cell) .. ":" .. math.floor(py * 100 / cell)] and true
                else
                    isInside = dist <= s.cellYds
                end
            else
                isInside = dist <= s.wr
            end
            if isInside and not s.dot then inside = inside or s end
            local sx, sy = -west * scale, north * scale
            if facing then
                sx, sy = sx * cosF - sy * sinF, sx * sinF + sy * cosF
            end
            local pd = math.sqrt(sx * sx + sy * sy)
            local rpx = s.wr * scale
            local hideIn = ns.db.settings.nodeHideRange or 15
            if s.dot and (pd > mapRadius - 6 or (hideIn > 0 and dist <= hideIn)) then
                -- exact gathered spot off the minimap, or you are standing right
                -- at it: hidden, so the game's own herb / ore blip shows underneath
            elseif s.dot then
                used = used + 1
                local p = pins[used] or NewPin()
                pins[used] = p
                p.spot, p.dist = s, dist
                p.tex:SetTexture(ns:GetItemIcon(s.itemID))
                p:ClearAllPoints()
                if p.cellFrame then p.cellFrame:Hide() end
                p.icon:ClearAllPoints()
                p.icon:SetPoint("CENTER")
                p.icon:SetAlpha(s.ext and 0.8 or 1)
                p.ring:SetVertexColor(s.cr, s.cg, s.cb, 1)
                p.area:Hide()
                p:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
                local sz = ns.db.settings.nodeIconSize or 14
                p:SetSize(sz, sz)
                p.icon:SetSize(sz, sz)
                p:Show()
            else
            used = used + 1
            local p = pins[used] or NewPin()
            pins[used] = p
            p.spot, p.dist = s, math.max(0, dist - s.wr)
            p.ring:SetVertexColor(s.cr, s.cg, s.cb, 1)
            p.tex:SetTexture(ns:GetItemIcon(s.itemID))
            p:ClearAllPoints()
            -- pins are reused: reset what the shape branch changes
            if p.cellFrame then p.cellFrame:Hide() end
            p.icon:ClearAllPoints()
            p.icon:SetPoint("CENTER")
            p.icon:SetSize(16, 16)
            if s.region and (pd - rpx <= mapRadius or isInside) then
                -- real shape: the cells as squares, rotated with the minimap
                p:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
                p:SetSize(w, w)
                p.area:Hide()
                p.cellFrame = p.cellFrame or CreateFrame("Frame", nil, p)
                p.cellFrame:SetAllPoints(Minimap)
                p.cellFrame:SetAlpha(0.3)
                p.cellTex = p.cellTex or {}
                local side = s.cellYds * scale
                local n = 0
                for _, c in ipairs(s.cells) do
                    local cn, cwst = c[1] - pwx, c[2] - pwy
                    local cx, cy = -cwst * scale, cn * scale
                    if facing then cx, cy = cx * cosF - cy * sinF, cx * sinF + cy * cosF end
                    if math.sqrt(cx * cx + cy * cy) <= mapRadius - side * 0.5 then
                        n = n + 1
                        local t = p.cellTex[n]
                        if not t then
                            t = p.cellFrame:CreateTexture(nil, "BACKGROUND")
                            t:SetColorTexture(1, 1, 1, 1)
                            p.cellTex[n] = t
                        end
                        t:ClearAllPoints()
                        t:SetPoint("CENTER", Minimap, "CENTER", cx, cy)
                        t:SetSize(side, side)
                        if t.SetRotation then t:SetRotation(facing or 0) end
                        t:SetVertexColor(s.cr, s.cg, s.cb, 1)
                        t:Show()
                    end
                end
                for i = n + 1, #p.cellTex do p.cellTex[i]:Hide() end
                p.cellFrame:Show()
                -- the icon sits on the busiest part of the area
                p.icon:ClearAllPoints()
                p.icon:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
                p.icon:SetAlpha(isInside and 0 or 1)
            elseif pd + rpx <= mapRadius - 2 and dist > s.wr then
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
            if p then
                -- standing next to the icon's spot: hide the icon (not the area),
                -- so the game's own herb / ore blip underneath can be seen
                if hideIn > 0 and dist <= hideIn then p.icon:SetAlpha(0) end
                p:Show()
            end
            end
        end
    end
    for i = used + 1, #pins do pins[i]:Hide() end
    if inside then ShowGlow(inside.cr, inside.cg, inside.cb) elseif glow then glow:Hide() end
end

------------------------------------------------------------------------
-- trainer icons on the minimap (town trainers + current guide step)
------------------------------------------------------------------------
local tpins = {}
local function NewTrainerPin()
    local p = CreateFrame("Frame", nil, Minimap)
    p:SetSize(18, 18)
    p:SetFrameStrata(Minimap:GetFrameStrata())
    p:SetFrameLevel(Minimap:GetFrameLevel() + 6)
    p.ring = p:CreateTexture(nil, "BACKGROUND")
    p.ring:SetTexture(CIRCLE)
    p.ring:SetPoint("TOPLEFT", -2, 2)
    p.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    p.tex = p:CreateTexture(nil, "ARTWORK")
    p.tex:SetAllPoints()
    p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = p:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(p.tex)
    p.tex:AddMaskTexture(mask)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(self)
        local t = self.t
        if not t then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(t.npc, 1, 0.82, 0)
        GameTooltip:AddLine(L("cat_" .. t.prof) .. " - " .. (t.rank or L("g_trainer")), 1, 1, 1)
        if t.special then
            GameTooltip:AddLine(L("g_special"), 1, 0.5, 0.3, true)
            if t.need then GameTooltip:AddLine(L("g_need", t.need), 1, 0.5, 0.3) end
        end
        if t.note then GameTooltip:AddLine(t.note, 0.7, 0.7, 0.7, true) end
        if self.dist then GameTooltip:AddLine(L("mm_dist", math.floor(self.dist + 0.5)), 1, 1, 1) end
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return p
end

local function HideTrainers() for _, p in ipairs(tpins) do p:Hide() end end

local function UpdateTrainers()
    if not (ns.db and ns.MinimapTrainerList) or not Minimap:IsVisible() then HideTrainers() return end
    local list = ns:MinimapTrainerList()
    if #list == 0 then HideTrainers() return end
    local cont, pwx, pwy = ns:PlayerWorldPos()
    if not cont then HideTrainers() return end
    local zoom = Minimap:GetZoom() or 0
    local indoors = IsIndoors and IsIndoors()
    local diameter = (indoors and INDOOR or OUTDOOR)[zoom] or 466
    local w = Minimap:GetWidth()
    local scale = w / diameter
    local mapRadius = w / 2
    local facing
    if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
        local ok, f = pcall(GetPlayerFacing)
        if ok then facing = ns.Plain(f) end
    end
    local used = 0
    for _, t in ipairs(list) do
        local c, wx, wy = WorldPos(t.mapID, t.x / 100, t.y / 100)
        if c == cont then
            local north, west = wx - pwx, wy - pwy
            local sx, sy = -west * scale, north * scale
            if facing then
                local cf, sf = math.cos(facing), math.sin(facing)
                sx, sy = sx * cf - sy * sf, sx * sf + sy * cf
            end
            local pd = math.sqrt(sx * sx + sy * sy)
            if pd <= mapRadius - 6 then
                used = used + 1
                local p = tpins[used] or NewTrainerPin()
                tpins[used] = p
                p.t, p.dist = t, math.sqrt(north * north + west * west)
                p.tex:SetTexture(ns.Guides[t.prof].icon)
                local cc = ns.CAT_COLORS[t.prof] or ns.CAT_COLORS.learned
                if t.guide then p.ring:SetVertexColor(1, 0.82, 0, 1)
                else p.ring:SetVertexColor(0.247, 0.780, 0.922, 1) end
                p:ClearAllPoints()
                p:SetPoint("CENTER", Minimap, "CENTER", sx, sy)
                p:Show()
            end
        end
    end
    for i = used + 1, #tpins do tpins[i]:Hide() end
end

local ticker = CreateFrame("Frame")
local elapsed = 0
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < UPDATE_EVERY then return end
    elapsed = 0
    -- restricted positions (instances, secret values) must never spam errors
    if not pcall(Update) then HideAll() end
    if not pcall(UpdateTrainers) then HideTrainers() end
end)

local function MarkDirty() dirty = true end
ns:On("TRACKING_CHANGED", MarkDirty)
ns:On("LEARNED_CHANGED", MarkDirty)
ns:On("DB_READY", MarkDirty)
