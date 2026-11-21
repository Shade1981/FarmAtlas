-- FarmAtlas - Inventory: counts farm materials in bags and bank on every character
-- db.chars["Realm-Name"] = { class, faction, bags = { [key] = n }, bank = { [key] = n },
--                            bankTime, recipes = { [recipeName] = true }, goals = { ... } }
local _, ns = ...

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetItemLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink

local function SlotCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        return info and info.stackCount or 0
    end
    local _, count = GetContainerItemInfo(bag, slot)
    return count or 0
end

-- WoW Forever: characters can share a first name ("Shade Hun", "Shade Tide"), and
-- UnitName gives only the first name, so the key also carries the character's GUID.
local charKeyCache
function ns:CharKey()
    if charKeyCache then return charKeyCache end
    local realm, name = GetRealmName() or "?", UnitName("player") or "?"
    local guid = UnitGUID and ns.Plain(UnitGUID("player"))
    if type(guid) ~= "string" or guid == "" then return realm .. "-" .. name end
    local key = realm .. "-" .. name .. "@" .. guid
    local chars = self.db and self.db.chars
    if chars and not chars[key] then
        -- one time: take over the old name-only entry, if no other character did
        local old = chars[realm .. "-" .. name]
        if old then
            chars[key] = old
            chars[realm .. "-" .. name] = nil
        end
    end
    if chars then
        chars[key] = chars[key] or { bags = {}, bank = {}, recipes = {}, goals = {} }
        chars[key].name = name
    end
    charKeyCache = key
    return key
end

function ns:CharData(key)
    key = key or self:CharKey()
    local chars = self.db.chars
    if not chars[key] then
        chars[key] = { bags = {}, bank = {}, recipes = {}, goals = {} }
    end
    local c = chars[key]
    c.bags = c.bags or {}; c.bank = c.bank or {}; c.recipes = c.recipes or {}; c.goals = c.goals or {}
    return c
end

-- data key for an item link (only materials FarmAtlas knows or learned)
function ns:KeyForLink(link)
    if not link then return end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end
    local name = link:match("%[(.-)%]")
    -- a cooked item in your bags teaches FarmAtlas what its recipe makes
    if name and ns.IsRecipeName and ns.db and not (ns.db.recipeOut and ns.db.recipeOut[name]) and ns:IsRecipeName(name) then
        ns:SetRecipeItem(name, itemID)
    end
    if ns.Items[itemID] then return itemID end
    local key = name and ns.ItemsByName[string.lower(name)]
    if key ~= nil then
        ns.db.idAlias[key] = itemID
        return key
    end
    if ns.db.learned[itemID] then return itemID end
end

local function ScanBags(bags)
    local out = {}
    for _, bag in ipairs(bags) do
        local n = GetNumSlots(bag) or 0
        for slot = 1, n do
            local key = ns:KeyForLink(GetItemLink(bag, slot))
            if key ~= nil then out[key] = (out[key] or 0) + SlotCount(bag, slot) end
        end
    end
    return out
end

local BAGS = { 0, 1, 2, 3, 4 }
local function BankBags()
    local list = { BANK_CONTAINER or -1 }
    local first = (NUM_BAG_SLOTS or 4) + 1
    for i = first, first + (NUM_BANKBAGSLOTS or 6) - 1 do list[#list + 1] = i end
    return list
end

local bankOpen = false
local pending = false

function ns:ScanInventory()
    local c = self:CharData()
    c.class = select(2, UnitClass("player"))
    c.faction = UnitFactionGroup("player")
    c.bags = ScanBags(BAGS)
    if bankOpen then
        c.bank = ScanBags(BankBags())
        c.bankTime = time()
    end
    self:Fire("INVENTORY_CHANGED")
end

local function QueueScan()
    if pending then return end
    pending = true
    C_Timer.After(0.6, function()
        pending = false
        ns:ScanInventory()
    end)
end

-- Counts for a data key: this character's bags, bank, and other characters.
function ns:GetCounts(key)
    local me = self:CharKey()
    local bags, bank, alts, altList = 0, 0, 0, {}
    for charKey, c in pairs(self.db.chars) do
        local b = (c.bags and c.bags[key]) or 0
        local k = (c.bank and c.bank[key]) or 0
        if charKey == me then
            bags, bank = b, k
        elseif b + k > 0 then
            alts = alts + b + k
            altList[#altList + 1] = { name = c.name or (charKey:match("%-([^@]+)") or charKey), n = b + k, class = c.class }
        end
    end
    table.sort(altList, function(a, b) return a.n > b.n end)
    return bags, bank, alts, altList
end

local f = CreateFrame("Frame")
ns:SafeRegister(f, "PLAYER_LOGIN")
ns:SafeRegister(f, "BAG_UPDATE")
ns:SafeRegister(f, "BANKFRAME_OPENED")
ns:SafeRegister(f, "BANKFRAME_CLOSED")
ns:SafeRegister(f, "PLAYERBANKSLOTS_CHANGED")
f:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "BANKFRAME_OPENED" then
        bankOpen = true
        C_Timer.After(0.2, function() if bankOpen then ns:ScanInventory() end end)
        return
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false -- bank contents are no longer readable; keep the last snapshot
        return
    end
    QueueScan()
end)
