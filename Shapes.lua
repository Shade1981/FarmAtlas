-- FarmAtlas - farm areas shaped like the real mob / fish spots
-- Your loot (and the shared / community loot) is recorded on a 2% x 2% grid.
-- Neighbouring cells are joined into regions: small gaps are closed, the edge
-- gets a one-cell margin, so the area follows where the mobs really are
-- instead of a circle. Until there is enough loot in a zone, the built-in
-- circle stays.
local _, ns = ...

local CELL = ns.LEARN_CELL or 2
local MIN_ZONE_LOOT = 10   -- loot in a zone before the shape replaces the circle
local MIN_REGION_LOOT = 2  -- smaller groups are treated as noise

local function key(gx, gy) return gx .. ":" .. gy end

local N8 = { { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 0, 1 }, { 1, 1 } }
local N4 = { { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }

local function Dilate(set, nbrs)
    local out = {}
    for k, v in pairs(set) do
        out[k] = v
        for _, d in ipairs(nbrs) do
            local nk = key(v[1] + d[1], v[2] + d[2])
            if not out[nk] then out[nk] = { v[1] + d[1], v[2] + d[2] } end
        end
    end
    return out
end

local function Erode(set, nbrs, keep)
    local out = {}
    for k, v in pairs(set) do
        local inside = true
        for _, d in ipairs(nbrs) do
            if not set[key(v[1] + d[1], v[2] + d[2])] then inside = false; break end
        end
        if inside or keep[k] then out[k] = v end
    end
    return out
end

-- regions of one item in one zone:
-- { cells = { {gx, gy}, ... }, set = {[key]=true}, n, minX, maxX, minY, maxY (percent), cx, cy }
local cache, cacheAt = {}, {}
function ns:LearnedRegions(itemID, mapID)
    local ck = tostring(itemID) .. "@" .. tostring(mapID)
    local now = GetTime and GetTime() or 0
    if cache[ck] and now - (cacheAt[ck] or 0) < 10 then return cache[ck] end

    local zone
    for _, lz in ipairs(self:GetLearnedZones(itemID)) do
        if lz.mapID == mapID then zone = lz break end
    end
    local regions = {}
    if not zone or (zone.n or 0) < MIN_ZONE_LOOT then
        cache[ck], cacheAt[ck] = regions, now
        return regions
    end

    -- base grid from the loot cells
    local base, loot = {}, {}
    for _, c in ipairs(zone.cells) do
        local gx, gy = math.floor(c.x / CELL), math.floor(c.y / CELL)
        local k = key(gx, gy)
        base[k] = { gx, gy }
        loot[k] = (loot[k] or 0) + (c.n or 0)
    end
    -- close small gaps (dilate + erode), then a one-cell margin (4-neighbours: rounder edge)
    local closed = Erode(Dilate(base, N8), N8, base)
    local shape = Dilate(closed, N4)

    -- connected regions (8-neighbours)
    local seen = {}
    for k, v in pairs(shape) do
        if not seen[k] then
            local r = { cells = {}, set = {}, n = 0, sx = 0, sy = 0, w = 0 }
            local stack = { v }
            seen[k] = true
            while #stack > 0 do
                local c = table.remove(stack)
                local kk = key(c[1], c[2])
                r.cells[#r.cells + 1] = c
                r.set[kk] = true
                local l = loot[kk] or 0
                r.n = r.n + l
                if l > 0 then r.sx, r.sy, r.w = r.sx + c[1] * l, r.sy + c[2] * l, r.w + l end
                for _, d in ipairs(N8) do
                    local nk = key(c[1] + d[1], c[2] + d[2])
                    if shape[nk] and not seen[nk] then
                        seen[nk] = true
                        stack[#stack + 1] = shape[nk]
                    end
                end
            end
            if r.n >= MIN_REGION_LOOT then
                local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
                for _, c in ipairs(r.cells) do
                    minX, maxX = math.min(minX, c[1]), math.max(maxX, c[1])
                    minY, maxY = math.min(minY, c[2]), math.max(maxY, c[2])
                end
                r.minX, r.maxX = minX * CELL, (maxX + 1) * CELL
                r.minY, r.maxY = minY * CELL, (maxY + 1) * CELL
                r.cx = (r.sx / r.w + 0.5) * CELL
                r.cy = (r.sy / r.w + 0.5) * CELL
                r.sx, r.sy, r.w = nil, nil, nil
                regions[#regions + 1] = r
            end
        end
    end
    table.sort(regions, function(a, b) return a.n > b.n end)
    cache[ck], cacheAt[ck] = regions, now
    return regions
end

ns:On("LEARNED_CHANGED", function() wipe(cache); wipe(cacheAt) end)
ns.SHAPE_CELL = CELL
