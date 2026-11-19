-- FarmAtlas - leveling guide logic (data in Data/Guides.lua)
local _, ns = ...
local L = ns.L

local PROF_NAMES = { cooking = "Cooking", fishing = "Fishing", skinning = "Skinning", leatherworking = "Leatherworking",
    firstaid = "First Aid", alchemy = "Alchemy" }

-- highest skill of each rank: a trainer must reach it to teach that rank
local RANK_CAP = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }
ns.RANK_CAP = RANK_CAP
-- the trainer rank a recipe in this skill range needs (guides with ranked trainers)
function ns:CapForSkill(from)
    from = from or 0
    if from < 75 then return 75 elseif from < 150 then return 150 elseif from < 225 then return 225 end
    return 300
end

local function MyFaction()
    local f = UnitFactionGroup and UnitFactionGroup("player")
    if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

local function FactionOK(fac, mine)
    return not fac or fac == "N" or not mine or fac == mine
end

-- Current skill in a profession, nil if not learned (or unknown).
function ns:ProfSkill(prof)
    local want = PROF_NAMES[prof]
    if not want then return nil end
    local ok, a, b, c, d, e, f = pcall(function() if GetProfessions then return GetProfessions() end end)
    if ok and GetProfessionInfo then
        -- not ipairs: the first slots are empty for a character without a main
        -- profession, and ipairs would stop there before Fishing / Cooking
        local slots = { a, b, c, d, e, f }
        for i = 1, 6 do
            local idx = slots[i]
            if idx then
                local ok2, name, _, rank, maxRank, _, _, line = pcall(GetProfessionInfo, idx)
                -- skill line ID first: works on every client language
                local byLine = ns.SKILL_LINE and ns.SKILL_LINE[prof] and ns.Plain(line) == ns.SKILL_LINE[prof]
                if ok2 and (byLine or ns.Plain(name) == want) and type(rank) == "number" then
                    return rank, type(maxRank) == "number" and maxRank or nil
                end
            end
        end
    end
    -- older skill-line API
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() do
            local ok3, name, header, _, rank, _, _, maxRank = pcall(GetSkillLineInfo, i)
            if ok3 and not header and name == want and type(rank) == "number" then
                return rank, type(maxRank) == "number" and maxRank or nil
            end
        end
    end
    return nil
end

-- is this NPC named anywhere in the guides? (only those get their spot recorded at a vendor)
function ns:IsGuideNPC(npc)
    if not self.guideNPCs then
        local t = {}
        for _, g in pairs(self.Guides) do
            if type(g.trainers) == "table" then for _, x in ipairs(g.trainers) do t[x.npc] = true end end
            for _, s in ipairs(g.steps) do for _, x in ipairs(s.npcs or {}) do t[x.npc] = true end end
        end
        self.guideNPCs = t
    end
    return self.guideNPCs[npc] or false
end

-- Remember where a trainer stands the first time their window is opened.
function ns:RecordTrainerPos(npc, mapID, x, y)
    if not (npc and mapID and x and y and self.db) then return end
    self.db.trainerPos = self.db.trainerPos or {}
    self.db.trainerPos[npc] = { mapID = mapID, x = x, y = y }
end

-- Trainers for a profession, filtered to your faction (neutral = both),
-- with coordinates where known. Your current zone first.
-- need: only trainers who can train up to this skill (t.max; nil max = no limit)
function ns:GuideTrainers(prof, list, need)
    local g = self.Guides[prof]
    if not g then return {} end
    local mine = MyFaction()
    local src = list or (g.trainers == "cooking" and self.Trainers or g.trainers) or {}
    local cur
    if C_Map and C_Map.GetBestMapForUnit then
        local m = C_Map.GetBestMapForUnit("player")
        local mi = m and C_Map.GetMapInfo(m)
        cur = mi and mi.name
    end
    local out = {}
    for pass = 1, 2 do
        for _, t in ipairs(src) do
            local here = (t.zone == cur)
            if FactionOK(t.faction, mine) and ((pass == 1) == here) and not (need and t.max and t.max < need) then
                local e = { npc = t.npc, zone = t.zone, x = t.x, y = t.y, note = t.note, faction = t.faction, mapID = t.mapID, max = t.max }
                local learned = self.db and self.db.trainerPos and self.db.trainerPos[t.npc]
                if learned then e.mapID, e.x, e.y, e.learned = learned.mapID, learned.x, learned.y, true end
                if not e.x then
                    -- the same NPC may have coordinates in the recipe data
                    local w = self:NPCSpot(t.npc)
                    if w then e.x, e.y = w.x, w.y; e.zone = e.zone or w.zone end
                end
                if not e.mapID and e.zone then e.mapID = self:ResolveZoneName(e.zone) end
                out[#out + 1] = e
            end
        end
    end
    return out
end

-- coordinates of an NPC from the recipe vendor data, if any
function ns:NPCSpot(npc)
    if not self.npcSpots then
        local t = {}
        for _, info in pairs(self.Recipes or {}) do
            for _, w in ipairs(info.where or {}) do
                if w.npc and w.x and w.y and not t[w.npc] then t[w.npc] = w end
            end
        end
        self.npcSpots = t
    end
    return self.npcSpots[npc]
end

-- Trainer map pins: which professions are switched on (default: all)
function ns:TrainerPinsOn(prof)
    local s = self.db and self.db.settings
    if not s then return false end
    s.trainerPins = s.trainerPins or {}
    if s.trainerPins[prof] == nil then return false end
    return s.trainerPins[prof]
end

function ns:SetTrainerPins(prof, on)
    self.db.settings.trainerPins = self.db.settings.trainerPins or {}
    self.db.settings.trainerPins[prof] = on and true or false
    self:Fire("TRACKING_CHANGED")
end

-- trainers of the guide step you are on now (train / special steps only)
local curCache, curAt = nil, -100
function ns:GuideCurrentTrainers()
    local now = GetTime and GetTime() or 0
    if curCache and now - curAt < 3 then return curCache end
    local out = {}
    if self.db and self.db.settings.guideTrainers == false then curCache, curAt = out, now; return out end
    for _, prof in ipairs(self.GUIDE_ORDER) do
        local skill = self:ProfSkill(prof)
        if skill then
            for _, r in ipairs(self:GuideRows("", prof)) do
                local s = r.step
                if r.current and s and (s.kind == "train" or s.kind == "special") then
                    for _, t in ipairs(self:GuideTrainers(prof, s.kind == "special" and s.npcs or nil, s.kind == "train" and RANK_CAP[s.rank] or nil)) do
                        if t.mapID and t.x and t.y then
                            out[#out + 1] = { prof = prof, npc = t.npc, mapID = t.mapID, x = t.x, y = t.y,
                                note = t.note, rank = s.rank, guide = true, special = s.kind == "special",
                                need = s.kind == "special" and s.at or nil }
                        end
                    end
                end
            end
        end
    end
    curCache, curAt = out, now
    return out
end
ns:On("TRACKING_CHANGED", function() curCache = nil end)

-- everything the world map shows: guide step + town + "all trainers" switch
function ns:MapTrainerList()
    local out, seen = {}, {}
    local function add(list, flag)
        for _, t in ipairs(list) do
            if not seen[t.npc] then
                seen[t.npc] = true
                local e = {}
                for k, v in pairs(t) do e[k] = v end
                if flag then e[flag] = true end
                out[#out + 1] = e
            end
        end
    end
    add(self:GuideCurrentTrainers(), "guide")
    if self.TownTrainers then add(self:TownTrainers(), "town") end
    add(self:TrainerPins())
    return out
end

-- the minimap shows the town trainers and the current guide step
function ns:MinimapTrainerList()
    local out, seen = {}, {}
    for _, list in ipairs({ self:GuideCurrentTrainers(), self.TownTrainers and self:TownTrainers() or {} }) do
        for _, t in ipairs(list) do
            if not seen[t.npc] then seen[t.npc] = true; out[#out + 1] = t end
        end
    end
    return out
end

-- every trainer / guide NPC with coordinates for the switched-on professions
-- (your faction + neutral): { prof, npc, mapID, x, y, note, rank }
function ns:TrainerPins()
    local out = {}
    for _, prof in ipairs(self.GUIDE_ORDER) do
        if self:TrainerPinsOn(prof) then
            local seen = {}
            for _, t in ipairs(self:GuideTrainers(prof)) do
                if t.mapID and t.x and t.y and not seen[t.npc] then
                    seen[t.npc] = true
                    out[#out + 1] = { prof = prof, npc = t.npc, mapID = t.mapID, x = t.x, y = t.y, note = t.note, learned = t.learned }
                end
            end
            for _, s in ipairs(self.Guides[prof].steps) do
                if s.kind == "special" and s.npcs then
                    for _, t in ipairs(self:GuideTrainers(prof, s.npcs)) do
                        if t.mapID and t.x and t.y and not seen[t.npc] then
                            seen[t.npc] = true
                            out[#out + 1] = { prof = prof, npc = t.npc, mapID = t.mapID, x = t.x, y = t.y, note = t.note, rank = s.rank, learned = t.learned }
                        end
                    end
                end
            end
        end
    end
    return out
end

local function Note(step)
    local n = step.note
    if type(n) == "table" then return ns.FixGlyphs(n[ns:Lang()] or n.en) end
    return n
end
ns.GuideNote = Note

-- Rows for the guide tab: a header per profession, then its steps.
-- query filters by profession / recipe / material / zone / mob text.
function ns:GuideRows(query, onlyProf)
    query = query and ns.Lower(query):gsub("^%s+", ""):gsub("%s+$", "") or ""
    local mine = MyFaction()
    local rows = {}
    for _, prof in ipairs(self.GUIDE_ORDER) do
      if not onlyProf or onlyProf == prof then
        local g = self.Guides[prof]
        local skill, maxSkill = self:ProfSkill(prof)
        local profName = L("cat_" .. prof)
        local steps = {}
        local currentMarked = false
        for _, s in ipairs(g.steps) do
            if FactionOK(s.faction, mine) then
                local hay = table.concat({ prof, profName, s.recipe or "", s.item or "", s.extra or "", s.mobs or "",
                    s.rank or "", table.concat(s.zones or {}, " "), Note(s) or "",
                    s.recipe and ns:RecipeLabel(s.recipe) or "", s.item and ns:MatLabel(s.item) or "",
                    ns:ZoneList(s.zones or {}) }, " ")
                hay = ns.Lower(hay)
                if query == "" or hay:find(query, 1, true) then
                    local r = { kind = "step", prof = prof, step = s, skill = skill }
                    local lo = s.from or s.at or 0
                    local hi = s.to or s.at or 0
                    if skill then
                        if s.kind == "train" or s.kind == "special" then
                            -- done once you are past it, or the rank is already learned
                            -- (your skill cap is above this step's old cap)
                            r.done = skill > (s.at or 0) + 25 or (maxSkill and maxSkill > (s.at or 0) + 25) or false
                            r.current = not r.done and skill >= (s.at or 0) - 0 and skill < (s.at or 0) + 25
                        else
                            r.done = skill >= hi
                            r.current = skill >= lo and skill < hi
                        end
                    end
                    if r.current and s.kind ~= "train" and s.kind ~= "special" then
                        r.first = not currentMarked
                        currentMarked = true
                    end
                    steps[#steps + 1] = r
                end
            end
        end
        if #steps > 0 or onlyProf then
            rows[#rows + 1] = { kind = "header", prof = prof, skill = skill, icon = g.icon }
            for _, r in ipairs(steps) do rows[#rows + 1] = r end
        end
      end
    end
    return rows
end

-- which guide sub-tab to show: the saved one, else the first profession you have
function ns:GuideProf()
    local s = self.db and self.db.settings
    if s and s.guideProf and self.Guides[s.guideProf] then return s.guideProf end
    for _, p in ipairs(self.GUIDE_ORDER) do if self:ProfSkill(p) then return p end end
    return self.GUIDE_ORDER[1]
end

------------------------------------------------------------------------
-- Guide areas on the map: where to fish / skin for a step
------------------------------------------------------------------------
local function StepLabel(prof, s)
    return L("cat_" .. prof) .. " " .. (s.from or "") .. "-" .. (s.to or "")
end

local function AreaFor(prof, s, flag)
    local maps = {}
    for _, z in ipairs(s.zones or {}) do
        local id = ns:ResolveZoneName(z)
        if id then maps[id] = true end
    end
    return { prof = prof, step = s, maps = maps, label = StepLabel(prof, s), note = Note(s), [flag] = true }
end

-- the area step you clicked in the guide (stays until you click another or right-click its pin)
function ns:SetGuideFocus(prof, s)
    self.guideFocus = s and AreaFor(prof, s, "focus") or nil
    self:Fire("TRACKING_CHANGED")
end

-- clicked step + the area steps you are on now
function ns:GuideAreas()
    local out = {}
    if self.guideFocus then out[1] = self.guideFocus end
    if self.db and self.db.settings.guideAreas == false then return out end
    for _, prof in ipairs(self.GUIDE_ORDER) do
        if self:ProfSkill(prof) then
            for _, r in ipairs(self:GuideRows("", prof)) do
                local s = r.step
                if r.current and s and s.kind == "area" and not (self.guideFocus and self.guideFocus.step == s) then
                    out[#out + 1] = AreaFor(prof, s, "current")
                end
            end
        end
    end
    return out
end

-- farm spots of the step's profession inside one zone (mob level matched to the skill for skinning)
function ns:GuideAreaSpots(area, mapID)
    local s = area.step
    local lo, hi
    if area.prof == "skinning" and s.from then lo, hi = math.floor(s.from / 5) - 2, math.ceil(s.to / 5) + 3 end
    local out = {}
    for id, data in pairs(self.Items) do
        if data.cat == area.prof then
            for _, sp in ipairs(data.spots or {}) do
                if self:ResolveZone(sp.z) == mapID then
                    local ok = true
                    if lo then
                        local a, b = self:ParseLevels(sp.lvl)
                        if a and (b < lo or a > hi) then ok = false end
                    end
                    if ok then out[#out + 1] = { itemID = id, spot = sp } end
                end
            end
        end
    end
    return out
end

-- Where clicking a step should take you.
function ns:GuideAction(r)
    if r.kind == "header" then return "pins", r.prof end
    local s = r.step
    if not s then return end
    if s.kind == "craft" then
        local key = s.item and self.ItemsByName[s.item:lower()]
        if key ~= nil then return "item", key end
        return nil
    elseif s.kind == "area" then
        return "area", { prof = r.prof, step = s, zone = s.zones and s.zones[1] }
    else
        local list = self:GuideTrainers(r.prof, s.kind == "special" and s.npcs or nil, s.kind == "train" and RANK_CAP[s.rank] or nil)
        local t = list[1]
        if t then return "point", { zone = t.zone, mapID = t.mapID, x = t.x, y = t.y, label = t.npc, sub = t.note } end
    end
end
