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

-- copper, sourceName  (nil when no price addon knows the item)
function ns:GetAHPrice(key)
    local itemID = self:RealID(key)
    if not itemID then return nil end
    for _, p in ipairs(providers) do
        local ok, v = pcall(p.get, itemID)
        v = ok and ns.Plain(v) or nil
        if type(v) == "number" and v > 0 then return math.floor(v), p.name end
    end
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
