-- FarmAtlas - profession leveling guides (1-300) for WoW Forever
-- Source: wow-professions.com WoW Forever Cooking / Fishing / Skinning guides
-- (Nov 2026, based on the Forever beta). The guides give no coordinates for
-- fishing / skinning trainers: FarmAtlas records the exact spot the first
-- time you open a trainer's window (db.trainerPos) and shows it from then on.
--
-- step kinds:
--   craft : { from, to, recipe, item = raw material, extra = other material, count }
--   area  : { from, to, zones = {...}, mobs = "..." }        (fishing / skinning)
--   train : { at, rank }                                     (any trainer of the profession)
--   special : { at, npcs = {...} }                           (book / quest NPC)
-- faction: "A" / "H" = only that faction; nil = both
local _, ns = ...

local function T(npc, zone, faction, note) return { npc = npc, zone = zone, faction = faction, note = note } end

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
              npcs = { T("Wulan", "Desolace", "H", "Shadowprey Village"), T("Shandrina", "Ashenvale", "A", "Mystral Lake") },
              note = { en = "Buy the Expert Cookbook (needs Cooking 125)", hu = "Vedd meg az Expert Cookbookot (Főzés 125 kell)" } },
            { kind = "craft", from = 130, to = 175, recipe = "Curiously Tasty Omelet", item = "Raptor Egg", extra = "Hot Spices", count = 50 },
            { kind = "craft", from = 130, to = 175, recipe = "Goblin Deviled Clams", item = "Tangy Clam Meat", extra = "Hot Spices", count = 50 },
            { kind = "craft", from = 130, to = 175, recipe = "Hot Lion Chops", item = "Lion Meat", extra = "Hot Spices", count = 50, faction = "H" },
            { kind = "craft", from = 175, to = 225, recipe = "Roast Raptor", item = "Raptor Flesh", extra = "Hot Spices", count = 55 },
            { kind = "craft", from = 175, to = 225, recipe = "Mithril Head Trout", item = "Raw Mithril Head Trout", count = 55 },
            { kind = "craft", from = 175, to = 225, recipe = "Soothing Turtle Bisque", item = "Turtle Meat", extra = "Soothing Spices", count = 55,
              note = { en = "Recipe from a quest: Christoph Jeffcoat (Horde, Hillsbrad) / Chef Jessen (Alliance)", hu = "Recept küldetésből: Christoph Jeffcoat (Horda, Hillsbrad) / Chef Jessen (Szövetség)" } },
            { kind = "special", at = 225, rank = "Artisan",
              npcs = { T("Zamja", "Orgrimmar", "H", "quest: To Gadgetzan You Go!"), T("Daryl Riknussun", "Ironforge", "A", "quest: I Know A Guy..."),
                       T("Dirge Quikcleave", "Tanaris", "N", "Gadgetzan - Clamlette Surprise") },
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
            T("Lumak", "Orgrimmar", "H"), T("Armand Cromwell", "Undercity", "H"), T("Kah Mistrunner", "Thunder Bluff", "H"),
            T("Lau'Tiki", "Durotar", "H", "Sen'jin Village coast"), T("Uthan Stillwater", "Mulgore", "H", "Stonebull Lake"),
            T("Clyde Kellen", "Tirisfal Glades", "H", "Brightwater Lake"),
            T("Arnold Leland", "Stormwind City", "A"), T("Grimnur Stonebrand", "Ironforge", "A"), T("Astaia", "Darnassus", "A"),
            T("Lee Brown", "Elwynn Forest", "A", "Crystal Lake"), T("Paxton Ganter", "Dun Morogh", "A", "Iceflow Lake"),
            T("Androl Oakhand", "Teldrassil", "A", "Rut'theran Village dock"),
            T("Baelann Swiftcurrent", "Zephras Isle", nil, "Valanaar"), T("Fenn Fairweather", "Zephras Isle", nil, "Shen'dar Village"),
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
            T("Thuwd", "Orgrimmar", "H"), T("Killian Hagey", "Undercity", "H"), T("Mooranta", "Thunder Bluff", "H"),
            T("Kagil", "Durotar", "H", "Valley of Trials - up to 75"), T("Nawka Wildsong", "Mulgore", "H", "Camp Narache - up to 75"),
            T("Yonn Deepcut", "Mulgore", "H", "Bloodhoof Village"), T("Margaret Weaver", "Tirisfal Glades", "H", "Deathknell - up to 75"),
            T("Rand Rhobart", "Tirisfal Glades", "H"),
            T("Maris Granger", "Stormwind City", "A"), T("Balthus Stoneflayer", "Ironforge", "A"), T("Eladriel", "Darnassus", "A"),
            T("Riley Peltskinner", "Elwynn Forest", "A", "Northshire - up to 75"), T("Helene Peltskinner", "Elwynn Forest", "A", "Goldshire"),
            T("Brighid Stormflayer", "Dun Morogh", "A", "up to 75"), T("Terunne Bearshaper", "Teldrassil", "A", "Shadowglen - up to 75"),
            T("Radnaal Maneweaver", "Teldrassil", "A"),
            T("Ishlee Breezewhisper", "Zephras Isle", nil, "Valanaar"), T("Mendalass Tattermend", "Zephras Isle", nil, "Shen'dar Village"),
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
