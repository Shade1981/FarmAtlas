-- FarmAtlas - farm goals: "I need 20x Raptor Flesh" with a small tracker window
-- c.goals[key] = { need = n, done = bool }, c.goalOrder = { key, ... }
local _, ns = ...
local L = ns.L

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROW_H = 46
local WIDTH = 330

local Goals = {}
ns.Goals = Goals

------------------------------------------------------------------------
-- data
------------------------------------------------------------------------
local function CD() return ns:CharData() end

function ns:GetGoalList()
    local c = CD()
    c.goalOrder = c.goalOrder or {}
    -- drop stale order entries
    local list = {}
    for _, key in ipairs(c.goalOrder) do
        if c.goals[key] then list[#list + 1] = key end
    end
    c.goalOrder = list
    return list
end

function ns:SetGoal(key, need)
    local c = CD()
    need = tonumber(need)
    if not need or need <= 0 then
        c.goals[key] = nil
    else
        local g = c.goals[key]
        if not g then
            g = {}
            c.goals[key] = g
            c.goalOrder = c.goalOrder or {}
            table.insert(c.goalOrder, key)
        end
        g.need = math.floor(need)
        g.done = nil
    end
    self:CheckGoals(true)
    self:Fire("GOALS_CHANGED")
end

function ns:GetGoal(key)
    return CD().goals[key]
end

function ns:GoalHave(key)
    local bags, bank, alts, altList = self:GetCounts(key)
    local have = bags
    if self.db.settings.goalCountBank ~= false then have = have + bank end
    return have, bags, bank, alts, altList
end

local function Notify(key, have, need)
    local name = ns:GetItemName(key)
    local msg = L("goal_reached", name, have, need)
    if RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.82, b = 0 })
    end
    if PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960, "Master")
    end
    ns:Print(msg)
end

-- silent = only update flags (used when a goal is set/edited)
function ns:CheckGoals(silent)
    local c = CD()
    for key, g in pairs(c.goals) do
        local have = self:GoalHave(key)
        if have >= g.need then
            if not g.done and not silent then Notify(key, have, g.need) end
            g.done = true
        else
            g.done = nil
        end
    end
end

------------------------------------------------------------------------
-- window
------------------------------------------------------------------------
local function SetBG(f, r, g, b, a, br, bg, bb)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(br or 0.165, bg or 0.185, bb or 0.225, 1)
end

function Goals:Build()
    if self.frame then return end
    local f = CreateFrame("Frame", "FarmAtlasGoalsFrame", UIParent, "BackdropTemplate")
    self.frame = f
    f:SetSize(WIDTH, 120)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    SetBG(f, 0.047, 0.055, 0.070, 0.92, 0.22, 0.25, 0.30)

    local top = f:CreateTexture(nil, "BORDER")
    top:SetTexture(WHITE)
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)
    top:SetHeight(2)
    top:SetVertexColor(1, 0.82, 0)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -6, -6)
    close.t = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    close.t:SetPoint("CENTER")
    close.t:SetText("X")
    close.t:SetTextColor(0.55, 0.59, 0.66)
    close:SetScript("OnClick", function() f:Hide(); ns.db.settings.goalsHidden = true end)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("BOTTOMLEFT", 12, 8)
    f.hint:SetPoint("BOTTOMRIGHT", -12, 8)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetTextColor(0.55, 0.59, 0.66)
    f.hint:SetWordWrap(true)

    self.rows = {}
end

function Goals:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    local f = self.frame
    row = CreateFrame("Frame", nil, f, "BackdropTemplate")
    row:SetHeight(ROW_H - 4)
    row:SetPoint("TOPLEFT", 8, -32 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", -8, -32 - (i - 1) * ROW_H)
    SetBG(row, 0.100, 0.112, 0.136, 1)
    row:EnableMouse(true)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(26, 26)
    row.icon:SetPoint("LEFT", 8, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 1)
    row.name:SetPoint("RIGHT", -74, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetStatusBarTexture(WHITE)
    row.bar:SetHeight(8)
    row.bar:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.bar:SetPoint("RIGHT", -140, 0)
    row.bar:SetMinMaxValues(0, 1)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetTexture(WHITE)
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetVertexColor(1, 1, 1, 0.08)

    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.bar, "BOTTOMLEFT", 0, -3)
    row.sub:SetPoint("RIGHT", -74, 0)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)

    -- "have / need" between the bar and the goal box (room for 4 + 4 digits)
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.count:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
    row.count:SetPoint("RIGHT", row.bar, "RIGHT", 66, 0)
    row.count:SetJustifyH("RIGHT")
    row.count:SetWordWrap(false)

    row.edit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    row.edit:SetSize(42, 20)
    row.edit:SetPoint("RIGHT", -24, 0)
    SetBG(row.edit, 0.078, 0.088, 0.108, 1)
    row.edit:SetFontObject(GameFontHighlightSmall)
    row.edit:SetJustifyH("CENTER")
    row.edit:SetAutoFocus(false)
    row.edit:SetNumeric(true)
    row.edit:SetMaxLetters(4)
    row.edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        ns:SetGoal(row.key, self:GetNumber())
    end)
    row.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); Goals:Refresh() end)
    row.edit:SetScript("OnEditFocusLost", function(self)
        if row.key and ns:GetGoal(row.key) and self:GetNumber() ~= ns:GetGoal(row.key).need then
            ns:SetGoal(row.key, self:GetNumber())
        end
    end)

    row.del = CreateFrame("Button", nil, row)
    row.del:SetSize(16, 16)
    row.del:SetPoint("RIGHT", -4, 0)
    row.del.t = row.del:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.del.t:SetPoint("CENTER")
    row.del.t:SetText("x")
    row.del.t:SetTextColor(0.6, 0.6, 0.6)
    row.del:SetScript("OnClick", function() ns:SetGoal(row.key, 0) end)
    row.del:SetScript("OnEnter", function(s) s.t:SetTextColor(1, 0.35, 0.35) end)
    row.del:SetScript("OnLeave", function(s) s.t:SetTextColor(0.6, 0.6, 0.6) end)

    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and row.key and ns.UI then ns.UI:Open(nil, row.key) end
    end)
    row:SetScript("OnEnter", function(self)
        if not self.key then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ns:GetItemColoredName(self.key))
        local _, bags, bank, alts, altList = ns:GoalHave(self.key)
        GameTooltip:AddDoubleLine(L("inv_bags"), bags, 0.7, 0.7, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(L("inv_bank"), bank, 0.7, 0.7, 0.7, 1, 1, 1)
        for _, a in ipairs(altList) do
            local cc = a.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[a.class]
            GameTooltip:AddDoubleLine(a.name, a.n, cc and cc.r or 0.8, cc and cc.g or 0.8, cc and cc.b or 0.8, 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("goal_row_hint"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.rows[i] = row
    return row
end

function Goals:Refresh()
    if not ns.db then return end
    local list = ns:GetGoalList()
    if #list == 0 then
        if self.frame then self.frame:Hide() end
        return
    end
    self:Build()
    local f = self.frame
    if ns.db.settings.goalsHidden then f:Hide() return end
    f.title:SetText("|cffffd200" .. L("goals_title") .. "|r")

    for i, key in ipairs(list) do
        local row = self:GetRow(i)
        local g = ns:GetGoal(key)
        local have, bags, bank, alts = ns:GoalHave(key)
        row.key = key
        row.icon:SetTexture(ns:GetItemIcon(key))
        row.name:SetText(ns:GetItemColoredName(key))
        local pct = math.min(1, have / math.max(1, g.need))
        row.bar:SetValue(pct)
        if have >= g.need then
            row.bar:SetStatusBarColor(0.30, 0.85, 0.35)
            row.count:SetText("|cff4dd94d" .. have .. "/" .. g.need .. "|r")
            row:SetBackdropBorderColor(0.30, 0.85, 0.35, 0.8)
        else
            row.bar:SetStatusBarColor(1, 0.62, 0.25)
            row.count:SetText(have .. "/" .. g.need)
            row:SetBackdropBorderColor(0.165, 0.185, 0.225, 1)
        end
        local parts = { L("inv_bags_short", bags) }
        if bank > 0 then parts[#parts + 1] = L("inv_bank_short", bank) end
        if alts > 0 then parts[#parts + 1] = "|cffcc8cff" .. L("inv_alts_short", alts) .. "|r" end
        row.sub:SetText(table.concat(parts, "  ·  "))
        if not row.edit:HasFocus() then row.edit:SetText(tostring(g.need)) end
        row:Show()
    end
    for i = #list + 1, #self.rows do self.rows[i]:Hide(); self.rows[i].key = nil end

    f.hint:SetText(L("goals_hint"))
    -- room for the hint however many lines it takes in this language
    local hintH = math.max(14, math.floor((f.hint:GetStringHeight() or 14) + 0.5))
    f:SetHeight(32 + #list * ROW_H + hintH + 16)
    f:Show()
end

function Goals:Toggle()
    ns.db.settings.goalsHidden = not ns.db.settings.goalsHidden
    if #ns:GetGoalList() == 0 then
        ns:Print(L("goals_empty"))
        ns.db.settings.goalsHidden = false
        return
    end
    self:Refresh()
end

ns:On("GOALS_CHANGED", function()
    ns.db.settings.goalsHidden = false
    Goals:Refresh()
end)
ns:On("INVENTORY_CHANGED", function()
    ns:CheckGoals(false)
    Goals:Refresh()
end)
ns:On("LANG_CHANGED", function() Goals:Refresh() end)
ns:On("ITEM_INFO", function() Goals:Refresh() end)
ns:On("LOGIN", function()
    C_Timer.After(2, function()
        ns:ScanInventory()
        Goals:Refresh()
    end)
end)
