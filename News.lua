-- FarmAtlas - "What's new" window
-- Shown once after every update when you enter the world. OK or X closes it,
-- and it stays closed until the next version. /farm news opens it again.
local _, ns = ...

-- newest first; hu texts may use ő/ű (fixed below for the WoW font)
local HISTORY = {
    { v = "1.2.0", date = "2026-11-17",
      en = {
        "New: Guide tab - Cooking, Fishing and Skinning 1-300 for WoW Forever. It shows where you are now, what to make or where to go next, and the trainers of your faction.",
        "Trainers: click a step to see it on the map. The first time you open a trainer's window FarmAtlas records the exact spot.",
        "New: auction house prices from Auctionator or TSM (optional) on item tooltips and cards, plus the value of 100 kills from real drop rates.",
        "Other price addons can plug in with FarmAtlas_AddPriceSource().",
        "New: this \"What's new\" window - after every update you see the changes once.",
        "Stability: tooltips, minimap pins, loot learning, kill counting, recipe scanning and sync are protected against the new client restrictions (no more Lua error popups in combat or instances).",
      },
      hu = {
        "Új: Útmutató fül - Főzés, Horgászat és Nyúzás 1-300 WoW Foreverre. Megmutatja, hol tartasz, mit készíts vagy hova menj, és a frakciód trénereit.",
        "Trénerek: egy lépésre kattintva a térképen látod. Amikor először megnyitod egy tréner ablakát, a FarmAtlas felírja a pontos helyét.",
        "Új: aukciósházi árak az Auctionatorból vagy a TSM-ből (nem kötelező) a tárgy-tooltipeken és kártyákon, plusz 100 ölés értéke a valódi drop-arányból.",
        "Más ár-addonok is bekapcsolódhatnak a FarmAtlas_AddPriceSource() függvénnyel.",
        "Új: ez a frissítési ablak - minden frissítés után egyszer megmutatja az újdonságokat.",
        "Stabilitás: a tooltip, a minimap-jelölők, a loot-tanulás, a kill-számlálás, a recept-figyelés és a szinkron védett az új kliens korlátozásaival szemben (nincs több Lua-hibaablak harcban vagy instance-ban).",
      } },
    { v = "1.1.1", date = "2026-11-16",
      en = { "Fixed: Lua error popup on mob tooltips (\"Secret values are only allowed during untainted execution\")." },
      hu = { "Javítva: Lua-hibaablak a mobok tooltipjén (\"Secret values are only allowed during untainted execution\")." } },
    { v = "1.1.0", date = "2026-11-16",
      en = {
        "Recipe sellers for 45+ vendor Cooking recipes (WoW Forever vendors).",
        "Faction-aware: FarmAtlas never sends you to a vendor of the other faction.",
        "Neutral-town vendors (Booty Bay, Gadgetzan, Steamwheedle Port, Everlook, Ratchet) are marked \"both factions\".",
        "If only the other faction can buy a recipe, FarmAtlas tells you to check the Auction House.",
        "Recipes tab tooltip shows where to learn recipes you don't know yet.",
        "Recipe vendors you discover are shared in the background with party / raid / guild.",
      },
      hu = {
        "Eladók 45+ eladós főzőrecepthez (WoW Forever eladók).",
        "Frakciófigyelés: a FarmAtlas sosem küld a másik frakció eladójához.",
        "A semleges városok eladói (Booty Bay, Gadgetzan, Steamwheedle Port, Everlook, Ratchet) \"mindkét frakció\" jelölést kapnak.",
        "Ha egy receptet csak a másik frakció vehet meg, a FarmAtlas az Auction House-t javasolja.",
        "A Receptek fülön a tooltip megmutatja, hol tanulható egy még nem ismert recept.",
        "A felfedezett recept-eladók a háttérben megosztódnak a party / raid / guild tagjaival.",
      } },
    { v = "1.0.0", date = "2026-11-16",
      en = {
        "First release: farm atlas for 100+ cooking meats, leathers, scales and fish.",
        "Translucent farm areas on the world map, circles and direction icons on the minimap.",
        "Recipes tab, farm goals, bag / bank / alt counts, real drop rates learned while you play.",
        "Background sharing with party / raid / guild. English and Hungarian interface.",
      },
      hu = {
        "Első kiadás: farm-atlasz 100+ főzési húshoz, bőrhöz, pikkelyhez és halhoz.",
        "Áttetsző farmterületek a világtérképen, körök és irányjelzők a minimapen.",
        "Receptek fül, farm célok, táska / bank / alt darabszámok, valós drop-arányok játék közben.",
        "Háttér-megosztás party / raid / guild tagokkal. Magyar és angol felület.",
      } },
}
ns.NewsHistory = HISTORY

local TEXT = {
    en = { title = "What's new", ok = "OK", hint = "Type /farm news to open this window again." },
    hu = { title = "Újdonságok", ok = "OK", hint = "A /farm news paranccsal bármikor újra megnyithatod." },
}

local fixMap = { ["ő"] = "ö", ["ű"] = "ü", ["Ő"] = "Ö", ["Ű"] = "Ü" }
local function Fix(s) return (s:gsub("\197[\145\177\144\176]", fixMap)) end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local frame

local function BuildText(lang)
    local out = {}
    for i, h in ipairs(HISTORY) do
        local head = i == 1 and "|cff3fc7eb" or "|cffffd200"
        out[#out + 1] = ("%sv%s|r  |cff8c96a8%s|r"):format(head, h.v, h.date)
        for _, line in ipairs(h[lang] or h.en) do out[#out + 1] = "  - " .. line end
        out[#out + 1] = " "
    end
    local s = table.concat(out, "\n")
    if lang == "hu" then s = Fix(s) end
    return s
end

local function MarkSeen()
    if ns.db then ns.db.newsSeen = ns.version end
end

local function Build()
    local f = CreateFrame("Frame", "FarmAtlasNewsFrame", UIParent, "BackdropTemplate")
    f:SetSize(480, 420)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if not f.SetBackdrop and BackdropTemplateMixin then Mixin(f, BackdropTemplateMixin) end
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        f:SetBackdropColor(0.047, 0.055, 0.070, 0.97)
        f:SetBackdropBorderColor(0.247, 0.780, 0.922, 1)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 16, -14)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -46)
    scroll:SetPoint("BOTTOMRIGHT", -34, 64)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(420, 10)
    scroll:SetScrollChild(child)
    f.body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.body:SetPoint("TOPLEFT")
    f.body:SetWidth(420)
    f.body:SetJustifyH("LEFT")
    f.body:SetJustifyV("TOP")
    f.body:SetSpacing(2)
    f.child = child

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("BOTTOMLEFT", 16, 22)

    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(100, 24)
    ok:SetPoint("BOTTOMRIGHT", -16, 14)
    ok:SetScript("OnClick", function() f:Hide() end)
    f.ok = ok

    f:SetScript("OnHide", MarkSeen)
    tinsert(UISpecialFrames, "FarmAtlasNewsFrame") -- Esc closes it too
    f:Hide()
    return f
end

function ns:ShowNews()
    frame = frame or Build()
    local lang = (ns.Lang and ns:Lang()) or "en"
    local t = TEXT[lang] or TEXT.en
    frame.title:SetText(("|cff3fc7ebFarm|r|cffffd200Atlas|r  %s  |cff8c96a8v%s|r"):format(lang == "hu" and Fix(t.title) or t.title, ns.version or "?"))
    frame.body:SetText(BuildText(lang))
    frame.child:SetHeight(math.max(10, (frame.body:GetStringHeight() or 0) + 8))
    frame.hint:SetText(lang == "hu" and Fix(t.hint) or t.hint)
    frame.ok:SetText(t.ok)
    frame:Show()
end

-- once per new version, a few seconds after entering the world, never in combat
local function MaybeShow()
    if not ns.db or ns.db.newsSeen == ns.version then return end
    if InCombatLockdown and InCombatLockdown() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            pcall(ns.ShowNews, ns)
        end)
        return
    end
    pcall(ns.ShowNews, ns)
end

ns:On("LOGIN", function()
    if C_Timer and C_Timer.After then C_Timer.After(4, MaybeShow) else MaybeShow() end
end)
