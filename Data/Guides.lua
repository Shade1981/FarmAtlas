-- FarmAtlas - profession leveling guides (1-300) for WoW Forever
-- Source: wow-professions.com WoW Forever Cooking / Fishing / Skinning guides
-- (Nov 2026, based on the Forever beta). Trainer coordinates (WoW Forever):
-- fishing from method.gg, skinning from timesaver.gg / method.gg (Nov 2026).
-- Where a source has none, FarmAtlas records the exact spot the first time you
-- open that NPC's window (db.trainerPos) and shows it from then on.
--
-- step kinds:
--   craft : { from, to, recipe, item = raw material, extra = other material, count }
--   area  : { from, to, zones = {...}, mobs = "..." }        (fishing / skinning)
--   train : { at, rank }                                     (any trainer of the profession)
--   special : { at, npcs = {...} }                           (book / quest NPC)
-- faction: "A" / "H" = only that faction; nil = both
local _, ns = ...

local function T(npc, zone, faction, note, mapID, x, y)
    return { npc = npc, zone = zone, faction = faction, note = note, mapID = mapID, x = x, y = y }
end

ns.Guides = {
    ------------------------------------------------------------------
    cooking = {
        icon = "Interface\\Icons\\INV_Misc_Food_15",
        trainers = "cooking", -- uses ns.Trainers (with coordinates)
        steps = {
            { kind = "train", at = 1, rank = "Apprentice" },
            { kind = "craft", from = 1, to = 50, recipe = "Brilliant Smallfish", item = "Raw Brilliant Smallfish", count = 55 },
            { kind = "craft", from = 1, to = 50, recipe = "Slitherskin Mackerel", item = "Raw Slitherskin Mackerel", count = 55 },
            { kind = "craft", from = 1, to = 50, recipe = "Charred Wolf Meat", item = "Stringy Wolf Meat", count = 55 },
            { kind = "craft", from = 1, to = 50, recipe = "Roasted Boar Meat", item = "Chunk of Boar Meat", count = 55 },
            { kind = "craft", from = 1, to = 50, recipe = "Crispy Bat Wing", item = "Meaty Bat Wing", faction = "H" },
            { kind = "craft", from = 1, to = 50, recipe = "Scorpid Surprise", item = "Scorpid Stinger", faction = "H" },
            { kind = "craft", from = 1, to = 50, recipe = "Kaldorei Spider Kabob", item = "Small Spider Leg", faction = "A",
              note = { en = "Recipe: quest \"Recipe of the Kaldorei\" from Zarrin (Teldrassil)", hu = "Recept: \"Recipe of the Kaldorei\" küldetés, Zarrin (Teldrassil)" } },
            { kind = "train", at = 50, rank = "Journeyman" },
            { kind = "craft", from = 50, to = 100, recipe = "Longjaw Mud Snapper", item = "Raw Longjaw Mud Snapper", count = 55 },
            { kind = "craft", from = 50, to = 100, recipe = "Rainbow Fin Albacore", item = "Raw Rainbow Fin Albacore", count = 55 },
            { kind = "craft", from = 50, to = 100, recipe = "Smoked Bear Meat", item = "Bear Meat", count = 70,
              note = { en = "Turns yellow sooner - cook it first", hu = "Hamarabb sárgul - ezt főzd először" } },
            { kind = "craft", from = 50, to = 100, recipe = "Strider Stew", item = "Strider Meat", extra = "Shiny Red Apple", count = 55,
              note = { en = "Alliance: recipe from the quest \"Easy Strider Living\"", hu = "Szövetség: a recept az \"Easy Strider Living\" küldetésből" } },
            { kind = "craft", from = 100, to = 150, recipe = "Bristle Whisker Catfish", item = "Raw Bristle Whisker Catfish", count = 55 },
            { kind = "craft", from = 100, to = 130, recipe = "Cooked Crab Claw", item = "Crawler Claw", extra = "Mild Spices", count = 33, faction = "A" },
            { kind = "special", at = 125, rank = "Expert",
              npcs = { T("Wulan", "Desolace", "H", "Shadowprey Village", 1443, 26.2, 69.8), T("Shandrina", "Ashenvale", "A", "Mystral Lake") },
              note = { en = "Buy the Expert Cookbook (needs Cooking 125)", hu = "Vedd meg az Expert Cookbookot (Főzés 125 kell)" } },
            { kind = "craft", from = 130, to = 175, recipe = "Curiously Tasty Omelet", item = "Raptor Egg", extra = "Hot Spices", count = 50 },
            { kind = "craft", from = 130, to = 175, recipe = "Goblin Deviled Clams", item = "Tangy Clam Meat", extra = "Hot Spices", count = 50 },
            { kind = "craft", from = 130, to = 175, recipe = "Hot Lion Chops", item = "Lion Meat", extra = "Hot Spices", count = 50, faction = "H" },
            { kind = "craft", from = 175, to = 225, recipe = "Roast Raptor", item = "Raptor Flesh", extra = "Hot Spices", count = 55 },
            { kind = "craft", from = 175, to = 225, recipe = "Mithril Head Trout", item = "Raw Mithril Head Trout", count = 55 },
            { kind = "craft", from = 175, to = 225, recipe = "Soothing Turtle Bisque", item = "Turtle Meat", extra = "Soothing Spices", count = 55,
              note = { en = "Recipe from a quest: Christoph Jeffcoat (Horde, Hillsbrad) / Chef Jessen (Alliance)", hu = "Recept küldetésből: Christoph Jeffcoat (Horda, Hillsbrad) / Chef Jessen (Szövetség)" } },
            { kind = "special", at = 225, rank = "Artisan",
              npcs = { T("Zamja", "Orgrimmar", "H", "quest: To Gadgetzan You Go!", 1454, 57.4, 53.8), T("Daryl Riknussun", "Ironforge", "A", "quest: I Know A Guy...", 1455, 60.4, 38.1),
                       T("Dirge Quikcleave", "Tanaris", "N", "Gadgetzan inn - Clamlette Surprise", 1446, 52.6, 28.1) },
              note = { en = "Level 35. Bring 12 Giant Egg, 10 Zesty Clam Meat, 20 Alterac Swiss to Dirge Quikcleave",
                       hu = "35-ös szint. Vigyél 12 Giant Egg-et, 10 Zesty Clam Meat-et, 20 Alterac Swiss-t Dirge Quikcleave-nek" } },
            { kind = "craft", from = 225, to = 300, recipe = "Spotted Yellowtail", item = "Raw Spotted Yellowtail", count = 140 },
            { kind = "craft", from = 225, to = 300, recipe = "Filet of Redgill", item = "Raw Redgill", count = 140,
              note = { en = "Alternative - buy whichever fish is cheaper", hu = "Alternatíva - amelyik hal olcsóbb" } },
        },
    },
    ------------------------------------------------------------------
    fishing = {
        icon = "Interface\\Icons\\Trade_Fishing",
        trainers = {
            T("Lumak", "Orgrimmar", "H", "Valley of Honor", 1454, 69.8, 29.6),
            T("Armand Cromwell", "Undercity", "H", "Magic Quarter", 1458, 80.8, 31.2),
            T("Kah Mistrunner", "Thunder Bluff", "H", "Middle Tier", 1456, 56.0, 46.8),
            T("Lau'Tiki", "Durotar", "H", "south of Sen'jin Village", 1411, 53.2, 81.6),
            T("Uthan Stillwater", "Mulgore", "H", "Stonebull Lake, Bloodhoof Village", 1412, 44.6, 60.6),
            T("Clyde Kellen", "Tirisfal Glades", "H", "Brightwater Lake", 1420, 67.2, 51.0),
            T("Kil'Hiwana", "Ashenvale", "H", "south of Blackfathom Deeps", 1440, 10.8, 33.6),
            T("Lui'Mala", "Desolace", "H", "Shadowprey Village", 1443, 22.6, 72.6),
            T("Katoom the Angler", "The Hinterlands", "H", "Revantusk Village", 1425, 80.2, 81.4),
            T("Arnold Leland", "Stormwind City", "A", "Trade District", 1453, 55.0, 69.6),
            T("Grimnur Stonebrand", "Ironforge", "A", "Forlorn Cavern", 1455, 48.4, 6.4),
            T("Astaia", "Darnassus", "A", "Temple Gardens", 1457, 47.6, 56.6),
            T("Lee Brown", "Elwynn Forest", "A", "Crystal Lake, Goldshire", 1429, 47.6, 62.2),
            T("Paxton Ganter", "Dun Morogh", "A", "Iceflow Lake, Brewnall Village", 1426, 35.6, 40.4),
            T("Androl Oakhand", "Teldrassil", "A", "Rut'theran Village dock", 1438, 55.8, 93.6),
            T("Warg Deepwater", "Loch Modan", "A", "Thelsamar", 1432, 40.6, 39.6),
            T("Matthew Hooper", "Redridge Mountains", "A", "Lakeshire", 1433, 26.8, 50.4),
            T("Harold Riggs", "Wetlands", "A", "Menethil Harbor", 1437, 8.2, 58.6),
            T("Donald Rabonne", "Hillsbrad Foothills", "A", "Southshore", 1424, 50.6, 61.0),
            T("Hunter Moore", "Hillsbrad Foothills", "A", nil, 1424, 54.0, 80.2),
            T("Brannock", "Feralas", "A", "Feathermoon Stronghold", 1444, 32.2, 41.6),
            T("Baelann Swiftcurrent", "Zephras Isle", "N", "Valanaar", 2521, 63.2, 75.8),
            T("Fenn Fairweather", "Zephras Isle", "N", "Shen'dar Village", 2521, 45.0, 48.4),
            T("Myizz Luckycatch", "Stranglethorn Vale", "N", "Booty Bay", 1434, 27.6, 77.0),
            T("Krix", "Riverglades", "N", "Powderfuse Port", 2548, 79.2, 54.8),
        },
        steps = {
            { kind = "train", at = 1, rank = "Apprentice",
              note = { en = "Buy a Fishing Pole and Shiny Baubles from a fishing / trade supply vendor", hu = "Vegyél horgászbotot és Shiny Bauble-t egy horgász- vagy kereskedelmi árustól" } },
            { kind = "area", from = 1, to = 75, zones = { "Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle" }, faction = "H",
              note = { en = "Any lake or river in a starting zone (not the capitals)", hu = "Bármely tó vagy folyó egy kezdőzónában (fővárosok nem)" } },
            { kind = "area", from = 1, to = 75, zones = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Zephras Isle" }, faction = "A",
              note = { en = "Any lake or river in a starting zone (not the capitals)", hu = "Bármely tó vagy folyó egy kezdőzónában (fővárosok nem)" } },
            { kind = "train", at = 50, rank = "Journeyman", note = { en = "Needs level 10", hu = "10-es szint kell" } },
            { kind = "area", from = 75, to = 150, zones = { "The Barrens", "Silverpine Forest", "Orgrimmar", "Undercity", "Thunder Bluff" }, faction = "H",
              note = { en = "Use Nightcrawlers if fish escape", hu = "Ha elszöknek a halak, használj Nightcrawlerst" } },
            { kind = "area", from = 75, to = 150, zones = { "Westfall", "Loch Modan", "Darkshore", "Stormwind City", "Ironforge", "Darnassus" }, faction = "A",
              note = { en = "Use Nightcrawlers if fish escape", hu = "Ha elszöknek a halak, használj Nightcrawlerst" } },
            { kind = "special", at = 125, rank = "Expert",
              npcs = { T("Old Man Heming", "Stranglethorn Vale", "N", "Booty Bay, bottom middle, by the fishing sign") },
              note = { en = "Buy \"Expert Fishing - The Bass and You\" (level 20) and Bright Baubles", hu = "Vedd meg: \"Expert Fishing - The Bass and You\" (20-as szint), plusz Bright Bauble" } },
            { kind = "area", from = 150, to = 225, zones = { "Dustwallow Marsh", "Alterac Mountains", "Arathi Highlands", "Desolace", "Stranglethorn Vale", "Swamp of Sorrows", "Thousand Needles" },
              note = { en = "Bright Baubles on; Dustwallow Marsh is the main spot", hu = "Bright Bauble-lel; a fő hely Dustwallow Marsh" } },
            { kind = "special", at = 225, rank = "Artisan",
              npcs = { T("Nat Pagle", "Dustwallow Marsh", "N", "Tidefury Cove - quest: Nat Pagle, Angler Extreme") },
              note = { en = "Level 35. Catch Feralas Ahi (Feralas), Misty Reed Mahi Mahi (Swamp of Sorrows), Sar'theris Striker (Desolace), Savage Coast Blue Sailfin (Stranglethorn)",
                       hu = "35-ös szint. Fogd ki: Feralas Ahi (Feralas), Misty Reed Mahi Mahi (Swamp of Sorrows), Sar'theris Striker (Desolace), Savage Coast Blue Sailfin (Stranglethorn)" } },
            { kind = "area", from = 225, to = 300, zones = { "Felwood", "Feralas", "The Hinterlands", "Tanaris", "Un'Goro Crater", "Western Plaguelands" },
              note = { en = "Bright Baubles keep fish from escaping", hu = "A Bright Bauble-lel nem szöknek el a halak" } },
        },
    },
    ------------------------------------------------------------------
    skinning = {
        icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
        trainers = {
            T("Thuwd", "Orgrimmar", "H", "The Drag", 1454, 63.2, 45.4),
            T("Killian Hagey", "Undercity", "H", nil, 1458, 70.2, 59.1),
            T("Mooranta", "Thunder Bluff", "H", nil, 1456, 44.5, 43.0),
            T("Kagil", "Durotar", "H", "Valley of Trials - up to 75", 1411, 40.8, 67.9),
            T("Nawka Wildsong", "Mulgore", "H", "Camp Narache - up to 75", 1412, 44.4, 76.8),
            T("Yonn Deepcut", "Mulgore", "H", "Bloodhoof Village", 1412, 45.0, 61.4),
            T("Margaret Weaver", "Tirisfal Glades", "H", "Deathknell - up to 75", 1420, 32.6, 65.8),
            T("Rand Rhobart", "Tirisfal Glades", "H", nil, 1420, 65.5, 60.0),
            T("Dranh", "The Barrens", "H", "Camp Taurajo", 1413, 45.1, 59.1),
            T("Malux", "Desolace", "H", "Shadowprey Village", 1443, 23.3, 69.7),
            T("Kulleg Stonehorn", "Feralas", "H", "Camp Mojache", 1444, 74.5, 43.0),
            T("Maris Granger", "Stormwind City", "A", "Old Town", 1453, 72.2, 62.5),
            T("Balthus Stoneflayer", "Ironforge", "A", "The Great Forge", 1455, 39.7, 32.3),
            T("Eladriel", "Darnassus", "A", "Craftsmen's Terrace", 1457, 64.2, 22.1),
            T("Riley Peltskinner", "Elwynn Forest", "A", "Northshire - up to 75", 1429, 47.0, 40.0),
            T("Helene Peltskinner", "Elwynn Forest", "A", "Goldshire", 1429, 46.3, 62.3),
            T("Brighid Stormflayer", "Dun Morogh", "A", "up to 75", 1426, 29.2, 67.6),
            T("Terunne Bearshaper", "Teldrassil", "A", "Shadowglen - up to 75", 1438, 59.4, 38.7),
            T("Radnaal Maneweaver", "Teldrassil", "A", nil, 1438, 42.0, 50.0),
            T("Wilma Ranthal", "Redridge Mountains", "A", nil, 1433, 83.6, 71.2),
            T("Jayla", "Ashenvale", "A", "Silverwind Refuge", 1440, 49.9, 67.2),
            T("Ishlee Breezewhisper", "Zephras Isle", "N", "Valanaar", 2521, 59.6, 76.0),
            T("Mendalass Tattermend", "Zephras Isle", "N", "Shen'dar Village", 2521, 43.3, 43.4),
        },
        steps = {
            { kind = "train", at = 1, rank = "Apprentice",
              note = { en = "Buy a Skinning Knife. Mobs need 5x their level in Skinning", hu = "Vegyél Skinning Knife-ot. Egy mobhoz a szintje 5-szöröse kell" } },
            { kind = "area", from = 1, to = 75, zones = { "Durotar" }, mobs = "Mottled Boar (Valley of Trials)", faction = "H" },
            { kind = "area", from = 1, to = 75, zones = { "Elwynn Forest" }, mobs = "Young Wolf, Timber Wolf (Northshire)", faction = "A" },
            { kind = "train", at = 50, rank = "Journeyman", note = { en = "Not from the junior trainers", hu = "A kezdő (junior) trénerektől nem" } },
            { kind = "area", from = 75, to = 125, zones = { "Loch Modan" }, mobs = "Elder Mountain Boar, Black Bear Patriarch, Loch Crocolisk (16-17)" },
            { kind = "area", from = 75, to = 150, zones = { "The Barrens" }, mobs = "Sunscale Scytheclaw, Zhevra Charger, Ornery Plainstrider (16-18)",
              note = { en = "West of Northwatch Hold - alternative to Loch Modan", hu = "Northwatch Holdtól nyugatra - Loch Modan helyett" } },
            { kind = "train", at = 125, rank = "Expert" },
            { kind = "area", from = 125, to = 150, zones = { "Wetlands" }, mobs = "Mottled Scytheclaw, Mottled Razormaw (25-27)",
              note = { en = "Whelgar's Excavation Site", hu = "Whelgar's Excavation Site" } },
            { kind = "area", from = 150, to = 225, zones = { "Hillsbrad Foothills" }, mobs = "Cave Yeti, Ferocious Yeti (30-32)",
              note = { en = "Foothill Caverns - Horde from Tarren Mill, Alliance from Southshore", hu = "Foothill Caverns - Horda Tarren Mill felől, Szövetség Southshore felől" } },
            { kind = "area", from = 150, to = 225, zones = { "Duskwood" }, mobs = "Nightbane Worgen, Shadow Weaver, Dark Runner (26-29)",
              note = { en = "Rotting Orchard (Horde via Grom'gol)", hu = "Rotting Orchard (Horda Grom'gol felől)" } },
            { kind = "train", at = 200, rank = "Artisan" },
            { kind = "area", from = 225, to = 280, zones = { "Feralas" }, mobs = "Feral Scar Yeti, Enraged / Hulking Feral Scar (43-46)",
              note = { en = "Feral Scar Vale", hu = "Feral Scar Vale" } },
            { kind = "area", from = 280, to = 300, zones = { "Un'Goro Crater" }, mobs = "Diemetradon, Pterrordax (50-55)",
              note = { en = "Western dinosaur area, fly to Marshal's Refuge", hu = "Nyugati dinós rész, repülj Marshal's Refuge-ba" } },
        },
    },
}
ns.GUIDE_ORDER = { "cooking", "fishing", "skinning" }
