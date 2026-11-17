-- FarmAtlas - auction house prices (optional, read-only)
-- FarmAtlas has no hard dependency: it asks the price addons you already use,
-- first one that knows the item wins. Nothing is scanned or posted here.
local _, ns = ...

local providers = {
    { name = "Auctionator", get = function(itemID)
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        if api and api.GetAuctionPriceByItemID then
            return api.GetAuctionPriceByItemID("FarmAtlas", itemID)
        end
    end },
    { name = "TSM", get = function(itemID)
        if TSM_API and TSM_API.GetCustomPriceValue then
            return TSM_API.GetCustomPriceValue("DBMarket", "i:" .. itemID)
        end
    end },
}
ns.PriceProviders = providers

-- Other addons (e.g. AHSnipe) can plug in: FarmAtlas_AddPriceSource("Name", function(itemID) return copper end)
function FarmAtlas_AddPriceSource(name, fn)
    if type(name) == "string" and type(fn) == "function" then
        table.insert(providers, 1, { name = name, get = fn })
    end
end

-- copper, sourceName, savedAt
-- A live price from a price addon is remembered; when none of them knows the
-- item right now, the last known price is used (with the time it was seen).
function ns:GetAHPrice(key)
    local itemID = self:RealID(key)
    if not itemID then return nil end
    for _, p in ipairs(providers) do
        local ok, v = pcall(p.get, itemID)
        v = ok and ns.Plain(v) or nil
        if type(v) == "number" and v > 0 then
            v = math.floor(v)
            if self.db then
                self.db.priceCache = self.db.priceCache or {}
                local now = time and time() or 0
                local c = self.db.priceCache[itemID]
                if not c or c.c ~= v or now - (c.t or 0) > 3600 then
                    self.db.priceCache[itemID] = { c = v, t = now, src = p.name }
                end
            end
            return v, p.name
        end
    end
    local c = self.db and self.db.priceCache and self.db.priceCache[itemID]
    if c and c.c then return c.c, c.src, c.t end
end

------------------------------------------------------------------------
-- farm / hour: what you really looted in the last 60 minutes
------------------------------------------------------------------------
local HOUR = 3600

local function Log()
    ns.db.farmLog = ns.db.farmLog or {}
    return ns.db.farmLog
end

local function Prune(list, now)
    local i = 1
    while list[i] and now - list[i][1] > HOUR do i = i + 1 end
    if i > 1 then
        for _ = 1, i - 1 do table.remove(list, 1) end
    end
end

ns:On("LOOT_RECORDED", function(key, mapID, cellKey, npcID, count)
    if not (ns.db and ns.db.settings.farmHour) or key == nil then return end
    local log = Log()
    local k = tostring(key)
    log[k] = log[k] or {}
    local now = time and time() or 0
    table.insert(log[k], { now, count or 1 })
    Prune(log[k], now)
end)

-- count looted in the last 60 minutes (nil = nothing yet: N/A)
function ns:FarmHourCount(key)
    local list = self.db and self.db.farmLog and self.db.farmLog[tostring(key)]
    if not list then return nil end
    local now = time and time() or 0
    Prune(list, now)
    if #list == 0 then return nil end
    local n = 0
    for _, e in ipairs(list) do n = n + (e[2] or 1) end
    return n
end

-- the three lines for tooltips: price, farm / hour, owned value
-- returns a list of { left, right } pairs (strings)
function ns:PriceLines(key)
    local s = self.db and self.db.settings
    if not s then return {} end
    local L = self.L
    local out = {}
    local price, src, at = self:GetAHPrice(key)
    -- no AH price anywhere: the vendor price is always known, so Farm / hour
    -- can still be shown in gold (marked "vendor")
    local vendor = self:VendorPrice(key)
    local value, valueTag = price, nil
    if not value and vendor then value, valueTag = vendor, L("pr_vendor_tag") end
    local function Gold(n)
        local t = self:Money(value * n)
        if valueTag then t = t .. " |cff8c96a8(" .. valueTag .. ")|r" end
        return t
    end
    if s.tooltipPrices then
        if price then
            local tag = src or "?"
            if at then tag = tag .. ", " .. (date and date("%m.%d %H:%M", at) or "") end
            out[#out + 1] = { L("pr_price"), self:Money(price) .. " |cff8c96a8(" .. tag .. ")|r" }
        elseif vendor then
            -- no AH price: a short value, so the line never runs over its label
            out[#out + 1] = { L("pr_price"), "|cff8c96a8-|r" }
        else
            out[#out + 1] = { L("pr_price"), "|cff8c96a8-|r" }
        end
        if vendor and vendor > 0 then
            out[#out + 1] = { L("pr_vendor"), self:Money(vendor) }
        end
    end
    if s.farmHour then
        local n = self:FarmHourCount(key)
        if not n then
            out[#out + 1] = { L("pr_hour"), "|cff8c96a8N/A|r" }
        elseif value then
            -- gold first: what the last 60 minutes of looting is worth
            out[#out + 1] = { L("pr_hour"), Gold(n) .. "  |cff8c96a8" .. L("pr_count", n) .. "|r" }
        else
            out[#out + 1] = { L("pr_hour"), L("pr_count", n) }
        end
    end
    if s.ownedValue and self.GetCounts then
        local bags, bank, alts = self:GetCounts(key)
        local total = (bags or 0) + (bank or 0) + (alts or 0)
        if total > 0 then
            out[#out + 1] = { L("pr_owned"), value and (Gold(total) .. "  |cff8c96a8" .. L("pr_count", total) .. "|r")
                or L("pr_count", total) }
        end
    end
    return out
end

-- what a merchant pays for one (from the game's item data; nil when unknown)
function ns:VendorPrice(key)
    local id = self.RealID and self:RealID(key) or key
    if type(id) ~= "number" then return nil end
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local ok, v = pcall(function() return select(11, fn(id)) end)
    v = ok and self.Plain(v) or nil
    if type(v) == "number" and v > 0 then return v end
    return nil
end

function ns:Money(copper)
    if not copper then return "" end
    copper = math.floor(copper + 0.5)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%dg %ds"):format(g, s) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end

-- value of 100 kills from a learned drop rate
function ns:ValuePer100(key, rate)
    local price = self:GetAHPrice(key)
    if not (price and rate) then return nil end
    return price * rate * 100
end
