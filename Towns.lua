-- FarmAtlas - trainers in the town / village / camp you walk into
--   * a banner (movable, resizable) when you arrive somewhere that has a
--     trainer of a profession you switched on
--   * those trainers are marked on the world map and the minimap while you are there
--   * right after login / reload you only get the marks, the banner waits
--     until you leave and come back
-- Positions are compared in world yards (C_Map.GetWorldPosFromMapPos).
local _, ns = ...
local L = ns.L

local NEAR = 200        -- yards: a trainer this close is "in this town"
local LEAVE = 280       -- yards: you have left once every trainer is this far
local CHECK_EVERY = 1.0
local CITY_MAPS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }

local here = {}         -- trainers of the place you are in (list)
local hereKey           -- names joined, "" when none
local silent = true     -- true until the first check after login / reload

------------------------------------------------------------------------
-- settings
------------------------------------------------------------------------
-- Town alerts per profession. Until you choose, a profession you have is on.
function ns:TownAlertOn(prof)
    local s = self.db and self.db.settings
    if not s then return false end
    s.townAlerts = s.townAlerts or {}
    if s.townAlerts[prof] ~= nil then return s.townAlerts[prof] end
    return self:ProfSkill(prof) ~= nil
end

function ns:SetTownAlert(prof, on)
    self.db.settings.townAlerts = self.db.settings.townAlerts or {}
    self.db.settings.townAlerts[prof] = on and true or false
    hereKey = nil -- re-evaluate (no banner for a switch)
    silent = true
    self:Fire("TRACKING_CHANGED")
end

local function BannerSettings()
    local s = ns.db.settings
    s.banner = s.banner or {}
    local b = s.banner
    if b.on == nil then b.on = true end
    b.scale = b.scale or 1
    return b
end

------------------------------------------------------------------------
-- positions
------------------------------------------------------------------------
local cache = {}
local function World(mapID, x, y)
    local key = mapID .. ":" .. x .. ":" .. y
    local c = cache[key]
    if c == nil then
        c = false
        if C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x / 100, y / 100))
            if ok and cont and pos then c = { cont, pos.x, pos.y } end
        end
        cache[key] = c
    end
    if c then return c[1], c[2], c[3] end
end

function ns:PlayerWorldPos()
    if not (C_Map and C_Map.GetBestMapForUnit) then return end
    local mapID = ns.Plain(C_Map.GetBestMapForUnit("player"))
    if not mapID then return end
    local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return end
    local px, py = pos.x, pos.y
    if pos.GetXY then px, py = pos:GetXY() end
    px, py = ns.Plain(px), ns.Plain(py)
    if not (px and py) then return end
    local cont, wx, wy = World(mapID, px * 100, py * 100)
    return cont, wx, wy, mapID
end

-- every trainer of the professions with town alerts on (your faction + neutral)
local candCache, candAt = nil, -100
local function Candidates()
    local now = GetTime and GetTime() or 0
    if candCache and now - candAt < 5 then return candCache end
    local out = {}
    for _, prof in ipairs(ns.GUIDE_ORDER) do
        if ns:TownAlertOn(prof) then
            for _, t in ipairs(ns:GuideTrainers(prof)) do
                if t.mapID and t.x and t.y then
                    out[#out + 1] = { prof = prof, npc = t.npc, mapID = t.mapID, x = t.x, y = t.y, note = t.note }
                end
            end
        end
    end
    candCache, candAt = out, now
    return out
end
local function Nearby(radius)
    local cont, px, py, mapID = ns:PlayerWorldPos()
    if not cont then return {}, mapID end
    local list = {}
    for _, t in ipairs(Candidates()) do
        local inCity = CITY_MAPS[mapID] and t.mapID == mapID
        local c, wx, wy = World(t.mapID, t.x, t.y)
        local d = (c == cont) and math.sqrt((wx - px) ^ 2 + (wy - py) ^ 2) or nil
        if inCity or (d and d <= radius) then
            t.dist = d
            list[#list + 1] = t
        end
    end
    table.sort(list, function(a, b) return (a.dist or 0) < (b.dist or 0) end)
    return list, mapID
end

-- the trainers of the place you stand in (for map / minimap marks)
function ns:TownTrainers()
    return here
end

------------------------------------------------------------------------
-- banner
------------------------------------------------------------------------
local banner

local function PlaceName(mapID)
    local sub = GetMinimapZoneText and ns.Plain(GetMinimapZoneText())
    if mapID and CITY_MAPS[mapID] and C_Map.GetMapInfo then
        local mi = C_Map.GetMapInfo(mapID)
        if mi and mi.name then return mi.name end
    end
    if sub and sub ~= "" then return sub end
    local zone = GetZoneText and ns.Plain(GetZoneText())
    return zone or "?"
end

local function BuildBanner()
    local f = CreateFrame("Frame", "FarmAtlasTownBanner", UIParent)
    f:SetSize(460, 120)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local b = BannerSettings()
        local point, _, rel, x, y = self:GetPoint(1)
        b.point, b.rel, b.x, b.y = point, rel, x, y
    end)
    f:SetScript("OnMouseWheel", function(self, delta)
        local b = BannerSettings()
        b.scale = math.max(0.6, math.min(2.0, (b.scale or 1) + delta * 0.1))
        self:SetScale(b.scale)
    end)

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.02, 0.03, 0.05, 0.55)
    f.line = f:CreateTexture(nil, "BORDER")
    f.line:SetColorTexture(0.247, 0.780, 0.922, 0.9)
    f.line:SetPoint("TOPLEFT", 40, -44)
    f.line:SetPoint("TOPRIGHT", -40, -44)
    f.line:SetHeight(1)

    f.kicker = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.kicker:SetPoint("TOP", 0, -8)
    f.kicker:SetTextColor(0.55, 0.59, 0.66)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", f.kicker, "BOTTOM", 0, -2)
    local path, _, flags = f.title:GetFont()
    if path then f.title:SetFont(path, 22, flags) end
    f.title:SetTextColor(1, 0.82, 0)
    f.lines = {}
    for i = 1, 4 do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOP", f, "TOP", 0, -52 - (i - 1) * 18)
        f.lines[i] = fs
    end
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOM", 0, 6)

    f:SetScript("OnUpdate", function(self, dt)
        if self.unlocked or not self.hold then return end
        self.hold = self.hold - dt
        if self.hold <= 0 then
            local a = self:GetAlpha() - dt * 1.5
            if a <= 0 then self:Hide(); self.hold = nil else self:SetAlpha(a) end
        end
    end)
    f:Hide()
    return f
end

local function PlaceBanner(f)
    local b = BannerSettings()
    f:ClearAllPoints()
    if b.point then f:SetPoint(b.point, UIParent, b.rel or b.point, b.x or 0, b.y or 0)
    else f:SetPoint("TOP", UIParent, "TOP", 0, -150) end
    f:SetScale(b.scale or 1)
end

local function Fill(f, place, list)
    f.kicker:SetText(L("tb_kicker"))
    f.title:SetText(place)
    local byProf = {}
    for _, t in ipairs(list) do
        byProf[t.prof] = byProf[t.prof] or {}
        table.insert(byProf[t.prof], t)
    end
    local i = 0
    for _, prof in ipairs(ns.GUIDE_ORDER) do
        local ts = byProf[prof]
        if ts and i < #f.lines then
            i = i + 1
            local names = {}
            for k = 1, math.min(2, #ts) do
                local t = ts[k]
                names[#names + 1] = t.npc .. (t.dist and (" |cff8c96a8(" .. L("mm_dist", math.floor(t.dist + 0.5)) .. ")|r") or "")
            end
            f.lines[i]:SetText(("|T%s:16:16:0:0:64:64:5:59:5:59|t  |cffffd200%s:|r  %s"):format(
                ns.Guides[prof].icon, L("cat_" .. prof), table.concat(names, ", ")))
            f.lines[i]:Show()
        end
    end
    for k = i + 1, #f.lines do f.lines[k]:Hide() end
    f:SetHeight(64 + i * 18)
end

function ns:ShowTownBanner(place, list)
    banner = banner or BuildBanner()
    PlaceBanner(banner)
    Fill(banner, place, list)
    banner.hint:SetText("")
    banner:SetAlpha(1)
    banner.hold = 6
    banner:Show()
end

-- /farm banner: unlock to drag + mouse wheel for size, again to lock
function ns:ToggleBannerEdit()
    banner = banner or BuildBanner()
    PlaceBanner(banner)
    banner.unlocked = not banner.unlocked
    banner:EnableMouse(banner.unlocked)
    banner:EnableMouseWheel(banner.unlocked)
    if banner.unlocked then
        Fill(banner, L("tb_sample_place"), {
            { prof = "cooking", npc = "Zamja", dist = 32 },
            { prof = "fishing", npc = "Lumak", dist = 58 },
        })
        banner.hint:SetText(L("tb_edit_hint"))
        banner.bg:SetColorTexture(0.10, 0.25, 0.32, 0.75)
        banner:SetAlpha(1)
        banner.hold = nil
        banner:Show()
    else
        banner.bg:SetColorTexture(0.02, 0.03, 0.05, 0.55)
        banner.hint:SetText("")
        banner:Hide()
    end
    return banner.unlocked
end

function ns:SetBannerOn(on)
    BannerSettings().on = on and true or false
end

function ns:BannerOn()
    return BannerSettings().on
end

------------------------------------------------------------------------
-- checking
------------------------------------------------------------------------
local function Check()
    if not ns.db or not ns.Guides then return end
    local radius = (hereKey and hereKey ~= "") and LEAVE or NEAR
    local list, mapID = Nearby(radius)
    local names = {}
    for _, t in ipairs(list) do names[#names + 1] = t.npc end
    local key = table.concat(names, ",")
    if key == hereKey then
        here = list -- distances refresh
        return
    end
    local wasEmpty = (hereKey == nil or hereKey == "")
    hereKey = key
    here = list
    ns:Fire("TOWN_TRAINERS_CHANGED")
    if key ~= "" and wasEmpty and not silent and ns:BannerOn() then
        if not (InCombatLockdown and InCombatLockdown()) then
            ns:ShowTownBanner(PlaceName(mapID), list)
        end
    end
    silent = false
end
ns.CheckTown = Check

local f = CreateFrame("Frame")
ns:SafeRegister(f, "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", function(_, event, isLogin, isReload)
    if event == "PLAYER_ENTERING_WORLD" then
        -- after login / reload: marks only, no banner until you come back
        if isLogin or isReload then silent = true; hereKey = nil end
    end
    pcall(Check)
end)
local elapsed = 0
f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < CHECK_EVERY then return end
    elapsed = 0
    pcall(Check)
end)
ns:On("TRACKING_CHANGED", function() candCache = nil; pcall(Check) end)
