-- FarmAtlas - where to learn Cooking recipes (WoW Forever)
-- Sources: warcrafttavern.com Forever cooking guide, kami-labs.fr, warcraft.wiki.gg.
-- Recipe names are English, exactly as in the in-game recipe book.
-- src: "trainer" | "vendor" | "quest" | "drop" | "unknown"
-- faction: "A" (Alliance), "H" (Horde) or nil (both)
-- where: list of { npc, zone (English zone name), x, y, faction, price, note }
-- Anything missing here is learned in-game: FarmAtlas scans every vendor,
-- trainer and your Cooking window (see Recipes.lua).
local _, ns = ...

ns.Trainers = {
    { npc = "Alegorn", zone = "Darnassus", x = 48.9, y = 21.3, faction = "A" },
    { npc = "Daryl Riknussun", zone = "Ironforge", x = 60.4, y = 38.1, faction = "A" },
    { npc = "Stephen Ryback", zone = "Stormwind City", x = 78.3, y = 53.1, faction = "A" },
    { npc = "Cook Ghilm", zone = "Dun Morogh", x = 68.4, y = 54.5, faction = "A" },
    { npc = "Gremlock Pilsnor", zone = "Dun Morogh", x = 47.6, y = 52.4, faction = "A", note = "Kharanos" },
    { npc = "Tomas", zone = "Elwynn Forest", x = 44.3, y = 66.0, faction = "A", note = "Goldshire" },
    { npc = "Zarrin", zone = "Teldrassil", x = 57.1, y = 61.2, faction = "A", note = "Dolanaar" },
    { npc = "Crystal Boughman", zone = "Redridge Mountains", x = 17.7, y = 43.6, faction = "A", note = "Lakeshire" },
    { npc = "Hnaz Blunderflame", zone = "Mount Hyjal", x = 15.6, y = 50.2, faction = "A", note = "Elderwild" },
    { npc = "Katherine Lee", zone = "Alterac Mountains", x = 12.5, y = 65.7, faction = "A", note = "Dalaran" },
    { npc = "Aska Mistrunner", zone = "Thunder Bluff", x = 51.0, y = 52.3, faction = "H" },
    { npc = "Eunice Burch", zone = "Undercity", x = 62.6, y = 44.8, faction = "H" },
    { npc = "Zamja", zone = "Orgrimmar", x = 57.4, y = 53.8, faction = "H" },
    { npc = "Cook Torka", zone = "Durotar", x = 51.1, y = 42.5, faction = "H", note = "Razor Hill" },
    { npc = "Pyall Silentstride", zone = "Mulgore", x = 45.1, y = 61.5, faction = "H", note = "Bloodhoof Village" },
    { npc = "William Pickman", zone = "Tirisfal Glades", x = 61.8, y = 51.5, faction = "H", note = "Brill" },
    { npc = "Duhng", zone = "The Barrens", x = 55.2, y = 31.8, faction = "H", note = "Crossroads" },
    { npc = "Gorg", zone = "Riverglades", x = 58.8, y = 44.5, faction = "H", note = "Rog'mar" },
    { npc = "Mudduk", zone = "Stranglethorn Vale", x = 31.4, y = 28.0, faction = "H", note = "Grom'gol" },
    { npc = "Ortak Lomgok", zone = "Mount Hyjal", x = 13.2, y = 52.8, faction = "H", note = "Elderwild" },
    { npc = "Zerril Softbreeze", zone = "Zephras Isle", x = 43.8, y = 43.9 },
    { npc = "Nyalah Brightfire", zone = "Zephras Isle", x = 60.6, y = 72.7, note = "Valanaar" },
}

ns.Recipes = {
    -- Trainer recipes --------------------------------------------------------
    ["Charred Wolf Meat"]   = { src = "trainer" },
    ["Herb Baked Egg"]      = { src = "trainer" },
    ["Roasted Boar Meat"]   = { src = "trainer" },
    ["Boiled Clams"]        = { src = "trainer" },
    ["Coyote Steak"]        = { src = "trainer" },
    ["Crab Cake"]           = { src = "trainer" },
    ["Dry Pork Ribs"]       = { src = "trainer" },
    ["Goblin Deviled Clams"] = { src = "trainer" },
    ["Spider Sausage"]      = { src = "trainer" },

    -- Vendor recipes with known sellers -------------------------------------
    ["Brilliant Smallfish"] = { src = "vendor", where = {
        { npc = "Tharynn Bouden", zone = "Elwynn Forest", x = 41.8, y = 67.0, faction = "A", note = "Goldshire" },
        { npc = "Khara Deepwater", zone = "Loch Modan", x = 40.4, y = 39.4, faction = "A" },
        { npc = "Catherine Leland", zone = "Stormwind City", x = 45.8, y = 58.2, faction = "A", note = "Canals" },
        { npc = "Harn Longcast", zone = "Mulgore", x = 46.6, y = 59.2, faction = "H", note = "Bloodhoof Village" },
        { npc = "Martine Tramblay", zone = "Tirisfal Glades", x = 65.8, y = 59.6, faction = "H" },
        { npc = "Nyalah Brightfire", zone = "Zephras Isle", x = 60.6, y = 72.7, note = "Valanaar" },
    } },
    ["Longjaw Mud Snapper"] = { src = "vendor", where = {
        { npc = "Tharynn Bouden", zone = "Elwynn Forest", x = 41.8, y = 67.0, faction = "A", note = "Goldshire" },
        { npc = "Khara Deepwater", zone = "Loch Modan", x = 40.4, y = 39.4, faction = "A" },
        { npc = "Harn Longcast", zone = "Mulgore", x = 46.6, y = 59.2, faction = "H" },
        { npc = "Killian Sanatha", zone = "Silverpine Forest", x = 33.0, y = 17.8, faction = "H" },
    } },
    ["Bristle Whisker Catfish"] = { src = "vendor", where = {
        { npc = "Kilxx", zone = "The Barrens", x = 62.8, y = 38.2, note = "Ratchet" },
        { npc = "Lindea Rabonne", zone = "Hillsbrad Foothills", x = 50.6, y = 61.0, faction = "A", note = "Southshore" },
        { npc = "Derak Nightfall", zone = "Hillsbrad Foothills", x = 63.0, y = 19.6, faction = "H", note = "Tarren Mill" },
        { npc = "Gritta Chumwater", zone = "Riverglades", x = 78.4, y = 55.0, note = "Powderfuse Port" },
    } },
    ["Curiously Tasty Omelet"] = { src = "vendor", where = {
        { npc = "Kendor Kabonka", zone = "Stormwind City", x = 74.6, y = 37.6, faction = "A", note = "Old Town" },
        { npc = "Ormer Ironbraid", zone = "Wetlands", x = 38.0, y = 51.2, faction = "A", note = "quest: Ormer's Revenge" },
        { npc = "Nerrist", zone = "Stranglethorn Vale", x = 32.6, y = 29.2, faction = "H", note = "Grom'gol" },
        { npc = "Keena", zone = "Arathi Highlands", x = 74.0, y = 32.6, faction = "H", note = "Hammerfall" },
    } },
    ["Mithril Head Trout"] = { src = "vendor", where = {
        { npc = "Kelsey Yance", zone = "Stranglethorn Vale", x = 28.2, y = 74.4, note = "Booty Bay" },
        { npc = "Stuart Fleming", zone = "Wetlands", x = 8.2, y = 58.6, faction = "A", note = "Menethil Harbor" },
        { npc = "Heldan Galesong", zone = "Darkshore", x = 37.0, y = 56.2, faction = "A" },
        { npc = "Wik'Tar", zone = "Ashenvale", x = 11.8, y = 34.0, faction = "H", note = "Zoram'gar Outpost" },
        { npc = "Wulan", zone = "Desolace", x = 26.2, y = 69.8, faction = "H", note = "Shadowprey Village" },
    } },
    ["Filet of Redgill"] = { src = "vendor", where = {
        { npc = "Kelsey Yance", zone = "Stranglethorn Vale", x = 28.2, y = 74.4, note = "Booty Bay" },
    } },
    ["Poached Sunscale Salmon"] = { src = "vendor", where = {
        { npc = "Gikkix", zone = "Tanaris", x = 66.6, y = 22.0, price = "2g", note = "Steamwheedle Port" },
    } },
    ["Cooked Spotted Yellowtail"] = { src = "vendor", where = {
        { npc = "Gikkix", zone = "Tanaris", x = 66.6, y = 22.0, price = "1g 60s", note = "Steamwheedle Port" },
    } },
    ["Lean Wolf Steak"] = { src = "vendor", where = {
        { npc = "Super-Seller 680", zone = "Desolace", price = "16s" },
    } },
    ["Plain Ol' Paletusk"] = { src = "vendor", where = {
        { npc = "Martha Wellsworth", zone = "Riverglades", price = "20s" },
    } },
    ["Tender Wolf Steak"] = { src = "vendor", where = {
        { npc = "Dirge Quikcleave", zone = "Tanaris", x = 52.6, y = 28.1, note = "Gadgetzan inn" },
    } },
    ["Hot Lion Chops"] = { src = "vendor", where = {
        { npc = "Vendor-Tron 1000", zone = "Desolace", note = "south of Thunder Axe Fortress" },
        { npc = "Zargh", zone = "The Barrens", faction = "H", note = "The Crossroads" },
    } },
    ["Lean Venison"] = { src = "vendor", where = {
        { npc = "Vendor-Tron 1000", zone = "Desolace", note = "south of Thunder Axe Fortress" },
    } },
    ["Heavy Kodo Stew"] = { src = "vendor", where = {
        { npc = "Vendor-Tron 1000", zone = "Desolace", note = "south of Thunder Axe Fortress" },
    } },
    ["Crocolisk Gumbo"] = { src = "vendor", where = {
        { npc = "Kendor Kabonka", zone = "Stormwind City", x = 74.6, y = 37.6, faction = "A", note = "Old Town" },
    } },
    ["Scorpid Surprise"]  = { src = "vendor", faction = "H" },
    ["Crocolisk Steak"]   = { src = "vendor", faction = "A", note = "vendor or quest" },
    ["Cooked Crab Claw"]  = { src = "vendor", note = "vendor or drop" },

    -- Vendor recipes, seller not yet known (FarmAtlas learns them) -----------
    ["Rainbow Fin Albacore"] = { src = "vendor" },
    ["Rockscale Cod"]        = { src = "vendor" },
    ["Roast Raptor"]         = { src = "vendor" },
    ["Plated Armorfish"]     = { src = "vendor" },
    ["Grilled Squid"]        = { src = "vendor" },
    ["Nightfin Soup"]        = { src = "vendor" },
    ["Baked Salmon"]         = { src = "vendor" },
    ["Lobster Stew"]         = { src = "vendor" },
    ["Barbecued Buzzard Wing"] = { src = "vendor", note = "vendor or quest" },

    -- Azeroth Commerce Authority smoothies (new in Forever) ------------------
    ["Venomous Smoothie"]  = { src = "vendor", note = "Azeroth Commerce Authority vendor" },
    ["Slimy Smoothie"]     = { src = "vendor", note = "Azeroth Commerce Authority vendor" },
    ["Mrrggl Smrrthle"]    = { src = "vendor", note = "Azeroth Commerce Authority vendor" },
    ["Calcified Smoothie"] = { src = "vendor", note = "Azeroth Commerce Authority vendor" },
    ["Spicy Smoothie"]     = { src = "vendor", note = "Azeroth Commerce Authority vendor" },
    ["Wicked Smoothie"]    = { src = "vendor", note = "Azeroth Commerce Authority vendor" },

    -- Quests / drops ----------------------------------------------------------
    ["Dirge's Kickin' Chimaerok Chops"] = { src = "quest", where = {
        { npc = "Dirge Quikcleave", zone = "Tanaris", x = 52.6, y = 28.1, note = "Gadgetzan inn" },
    } },
    ["Clamlette Surprise"] = { src = "quest", where = {
        { npc = "Dirge Quikcleave", zone = "Tanaris", x = 52.6, y = 28.1, note = "Gadgetzan inn, level 35+" },
    } },
    ["Soothing Turtle Bisque"]  = { src = "quest" },
    ["Smoked Desert Dumplings"] = { src = "quest", note = "Silithus" },
    ["Kaldorei Spider Kabob"]   = { src = "quest", faction = "A" },
    ["Dig Rat Stew"]            = { src = "quest" },
    ["Savory Deviate Delight"]  = { src = "drop" },
    ["Savory Whimsyfin Delight"] = { src = "drop" },
    ["Runn Tum Tuber Surprise"] = { src = "drop" },
}
