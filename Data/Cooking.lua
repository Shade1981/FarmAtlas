-- FarmAtlas - Cooking ingredients (WoW Forever)
-- Sources: mob names, levels, zones and drop chances from the WoW Forever item
-- database (metabot.gg, Classic-based drop data). Map positions are approximate
-- areas where those mobs live; your own loot refines them in-game (Learn.lua).
--
-- Spot fields: z = zone key (Zones.lua), x/y = area centre in map %, r = radius %,
-- mobs, lvl, drop = drop chance text, note = hint. Item names are ALWAYS English,
-- exactly as they appear in the in-game recipe book.
-- Keys: numeric item ID, or the English item name when the ID is not known yet
-- (FarmAtlas links the real ID the first time you loot it).
local _, ns = ...

ns:AddItems("cooking", {
    ---------------------------------------------------------------- BOAR / PORK
    [769] = { name = "Chunk of Boar Meat", tags = "boar pork pig disznó vaddisznó hús",
        uses = { "Roasted Boar Meat", "Plain Ol' Paletusk" },
        spots = {
            { z = 1411, x = 42, y = 38, r = 9, mobs = "Dire Mottled Boar, Elder Mottled Boar", lvl = "6-10", drop = "98% / 82%", note = "Razormane Grounds - best spot in the game" },
            { z = 1411, x = 55, y = 46, r = 7, mobs = "Dire Mottled Boar", lvl = "7-10", drop = "98%", note = "around Razor Hill" },
            { z = 1432, x = 42, y = 32, r = 9, mobs = "Mangy Mountain Boar, Mountain Boar", lvl = "10-15", drop = "82%" },
            { z = 1436, x = 55, y = 46, r = 8, mobs = "Goretusk, Young Goretusk", lvl = "12-15", note = "Sentinel Hill loop" },
            { z = 1429, x = 40, y = 80, r = 8, mobs = "Stonetusk Boar", lvl = "5-6" },
        } },
    [2886] = { name = "Crag Boar Rib", tags = "boar rib pork disznó borda",
        uses = { "Beer Basted Boar Ribs" },
        spots = {
            { z = 1426, x = 45, y = 54, r = 9, mobs = "Large Crag Boar, Crag Boar, Elder Crag Boar, Scarred Crag Boar", lvl = "5-10", drop = "46-53%", note = "Kharanos / Chill Breeze Valley" },
        } },
    [2677] = { name = "Boar Ribs", tags = "boar rib pork disznó borda",
        uses = { "Dry Pork Ribs" },
        spots = {
            { z = 1432, x = 79, y = 62, r = 8, mobs = "Elder Mountain Boar", lvl = "16-17", drop = "34%", note = "Farstrider Lodge area" },
            { z = 1413, x = 42, y = 90, r = 5, mobs = "Agam'ar, Raging Agam'ar (elite)", lvl = "24-28", drop = "43-45%", note = "inside Razorfen Kraul (dungeon)" },
            { z = 1413, x = 49, y = 94, r = 4, mobs = "Withered Battle Boar, Battle Boar Horror", lvl = "34-37", drop = "45-46%", note = "inside Razorfen Downs (dungeon)" },
        } },
    [3172] = { name = "Boar Intestines", tags = "boar pork disznó belsőség",
        spots = {
            { z = 1432, x = 79, y = 62, r = 8, mobs = "Elder Mountain Boar", lvl = "16-17", drop = "39%" },
            { z = 1413, x = 42, y = 90, r = 5, mobs = "Agam'ar (elite)", lvl = "24-28", drop = "49%", note = "inside Razorfen Kraul (dungeon)" },
            { z = 1413, x = 49, y = 94, r = 4, mobs = "Withered Battle Boar, Battle Boar Horror", lvl = "34-37", drop = "51%", note = "inside Razorfen Downs (dungeon)" },
        } },
    [723] = { name = "Goretusk Liver", tags = "boar liver máj",
        uses = { "Goretusk Liver Pie" },
        spots = {
            { z = 1433, x = 26, y = 62, r = 9, mobs = "Great Goretusk, Bellygrub", lvl = "16-24", drop = "37-38%" },
            { z = 1436, x = 55, y = 46, r = 9, mobs = "Goretusk, Young Goretusk", lvl = "12-15", drop = "32-33%" },
        } },
    [731] = { name = "Goretusk Snout", tags = "boar snout",
        uses = { "Westfall Stew" },
        spots = {
            { z = 1436, x = 55, y = 46, r = 9, mobs = "Goretusk, Young Goretusk", lvl = "12-15" },
        } },

    ---------------------------------------------------------------- WOLVES
    [2672] = { name = "Stringy Wolf Meat", tags = "wolf farkas",
        uses = { "Charred Wolf Meat", "Spiced Wolf Meat" },
        spots = {
            { z = 1420, x = 50, y = 50, r = 14, mobs = "Ravenous Darkhound", lvl = "9-10", drop = "88%" },
            { z = 1421, x = 48, y = 40, r = 14, mobs = "Worg, Mottled Worg, Bloodsnout Worg", lvl = "10-17", drop = "82-87%" },
            { z = 1429, x = 62, y = 66, r = 10, mobs = "Prowler", lvl = "9-10", drop = "86%" },
            { z = 1412, x = 50, y = 68, r = 12, mobs = "Prairie Wolf Alpha", lvl = "9-10", drop = "82%" },
        } },
    [2673] = { name = "Coyote Meat", tags = "coyote prérifarkas",
        uses = { "Coyote Steak" },
        spots = {
            { z = 1436, x = 60, y = 30, r = 12, mobs = "Coyote, Coyote Packleader", lvl = "10-12", drop = "51-54%" },
        } },
    [1015] = { name = "Lean Wolf Flank", tags = "wolf farkas",
        uses = { "Lean Wolf Steak" },
        spots = {
            { z = 1440, x = 55, y = 42, r = 14, mobs = "Ghostpaw Alpha, Ghostpaw Runner, Ghostpaw Howler", lvl = "19-28", drop = "59-65%" },
            { z = 1431, x = 60, y = 46, r = 13, mobs = "Black Ravager, Young Black Ravager, Rabid Dire Wolf", lvl = "20-25", drop = "55-58%" },
        } },
    [12203] = { name = "Red Wolf Meat", tags = "wolf farkas",
        uses = { "Hot Wolf Ribs", "Filet o' Flank", "Flank au Poivre" },
        spots = {
            { z = 1444, x = 70, y = 45, r = 12, mobs = "Longtooth Runner", lvl = "40-41", drop = "54%" },
            { z = 1425, x = 50, y = 50, r = 15, mobs = "Silvermane Stalker", lvl = "47-48", drop = "50%" },
            { z = 1422, x = 50, y = 50, r = 15, mobs = "Diseased Wolf", lvl = "53-54", drop = "51%" },
            { z = 1423, x = 50, y = 50, r = 16, mobs = "Plaguehound, Plaguehound Runt, Frenzied Plaguehound", lvl = "53-58", drop = "50-51%" },
        } },
    [12208] = { name = "Tender Wolf Meat", tags = "wolf farkas",
        uses = { "Tender Wolf Steak" },
        spots = {
            { z = 1422, x = 50, y = 50, r = 15, mobs = "Diseased Wolf", lvl = "53-54", drop = "51%" },
            { z = 1423, x = 50, y = 50, r = 16, mobs = "Plaguehound, Plaguehound Runt, Frenzied Plaguehound", lvl = "53-58", drop = "50%" },
            { z = 1425, x = 50, y = 50, r = 15, mobs = "Silvermane Stalker", lvl = "47-48", drop = "47%" },
        } },

    ---------------------------------------------------------------- BEARS / CATS / STAGS
    [3173] = { name = "Bear Meat", tags = "bear medve",
        uses = { "Smoked Bear Meat" },
        spots = {
            { z = 1440, x = 62, y = 58, r = 13, mobs = "Giant Ashenvale Bear, Elder Ashenvale Bear", lvl = "25-30", drop = "56-71%" },
            { z = 1439, x = 44, y = 40, r = 12, mobs = "Thistle Bear, Rabid Thistle Bear", lvl = "11-14", drop = "45-47%" },
            { z = 1421, x = 45, y = 40, r = 12, mobs = "Giant Grizzled Bear", lvl = "12-13", drop = "45%" },
            { z = 1432, x = 34, y = 22, r = 10, mobs = "Black Bear Patriarch", lvl = "16-17", drop = "45%" },
        } },
    [3730] = { name = "Big Bear Meat", tags = "bear medve",
        uses = { "Big Bear Steak", "Bear Brisket", "Bear Bruscitti" },
        spots = {
            { z = 1440, x = 62, y = 58, r = 13, mobs = "Giant Ashenvale Bear, Elder Ashenvale Bear, Ashenvale Bear", lvl = "21-30", drop = "42-45%" },
            { z = 1424, x = 46, y = 38, r = 11, mobs = "Elder Gray Bear, Vicious Gray Bear", lvl = "22-26", drop = "41-42%" },
        } },
    [3731] = { name = "Lion Meat", tags = "lion oroszlán",
        uses = { "Hot Lion Chops" },
        spots = {
            { z = 1416, x = 50, y = 56, r = 12, mobs = "Mountain Lion, Hulking Mountain Lion", lvl = "32-34", drop = "66-67%" },
            { z = 1424, x = 56, y = 30, r = 11, mobs = "Feral Mountain Lion, Starving Mountain Lion", lvl = "23-28", drop = "42-56%" },
        } },
    [12202] = { name = "Tiger Meat", tags = "tiger tigris cat",
        uses = { "Prowler Steak", "Swiftstrike Steak" },
        spots = {
            { z = 1418, x = 50, y = 45, r = 17, mobs = "Ridge Stalker, Ridge Stalker Patriarch, Ridge Huntress", lvl = "36-41", drop = "59-63%", note = "best spot" },
            { z = 1434, x = 34, y = 14, r = 10, mobs = "Young Stranglethorn Tiger, Elder Stranglethorn Tiger", lvl = "30-35", drop = "55-59%" },
            { z = 1434, x = 40, y = 22, r = 8, mobs = "Stranglethorn Tigress", lvl = "37-38", drop = "60%" },
            { z = 1452, x = 48, y = 14, r = 12, mobs = "Frostsaber, Frostsaber Stalker, Frostsaber Huntress, Frostsaber Cub", lvl = "55-60", drop = "45-47%", note = "Frostsaber Rock" },
        } },
    [5471] = { name = "Stag Meat", tags = "stag deer szarvas vad",
        uses = { "Lean Venison", "Savory Stag Sliders", "Steaming Stag Steak", "Cleansing Stew" },
        spots = {
            { z = 1440, x = 60, y = 48, r = 15, mobs = "Elder Shadowhorn Stag, Shadowhorn Stag, Wild Buck", lvl = "18-27", drop = "49-53%", note = "best spot" },
            { z = 1447, x = 55, y = 40, r = 15, mobs = "Mosshoof Runner, Mosshoof Stag, Mosshoof Courser", lvl = "45-53", drop = "46-48%" },
            { z = 1442, x = 45, y = 55, r = 12, mobs = "Great Courser, Antlered Courser", lvl = "22-25", drop = "35-36%" },
        } },

    ---------------------------------------------------------------- RAPTORS / LIZARDS / CROCS / TURTLES
    [12184] = { name = "Raptor Flesh", tags = "raptor dino",
        uses = { "Roast Raptor", "Twice-Spiced Raptor Slice", "Raging Raptor Ribs", "Raptor Rouladen", "Prehistoric Pulled Raptor", "Specklefin Feast" },
        spots = {
            { z = 1445, x = 40, y = 28, r = 13, mobs = "Bloodfen Scytheclaw, Bloodfen Screecher, Bloodfen Raptor, Bloodfen Lashtail", lvl = "35-41", drop = "50-53%", note = "best spot" },
            { z = 1449, x = 58, y = 64, r = 14, mobs = "Ravasaur", lvl = "48-49", drop = "49%" },
            { z = 1434, x = 34, y = 50, r = 10, mobs = "Jungle Stalker", lvl = "40-41", drop = "48%" },
        } },
    [3685] = { name = "Raptor Egg", tags = "raptor egg tojás",
        uses = { "Tasty Raptor Bites", "Curiously Tasty Omelet" },
        spots = {
            { z = 1437, x = 60, y = 45, r = 14, mobs = "Highland Razormaw, Mottled Razormaw, Elder Razormaw, Mottled Raptor, Highland Scytheclaw", lvl = "22-29", drop = "62-72%", note = "the only real spot - very high drop" },
        } },
    [5470] = { name = "Thunder Lizard Tail", tags = "lizard gyík",
        uses = { "Crispy Lizard Tail" },
        spots = {
            { z = 1442, x = 55, y = 62, r = 12, mobs = "Cliff Stormer, Raging Cliff Stormer", lvl = "15-19", drop = "60-63%" },
            { z = 1413, x = 56, y = 22, r = 12, mobs = "Thunderhead, Stormhide, Stormsnout", lvl = "18-23", drop = "51-59%" },
        } },
    [2924] = { name = "Crocolisk Meat", tags = "croc krokodil",
        uses = { "Crocolisk Steak" },
        spots = {
            { z = 1434, x = 28, y = 55, r = 11, mobs = "Elder Saltwater Crocolisk, Saltwater Crocolisk", lvl = "35-40", drop = "47-61%" },
            { z = 1437, x = 35, y = 45, r = 11, mobs = "Wetlands Crocolisk", lvl = "23-24", drop = "50%" },
            { z = 1432, x = 40, y = 52, r = 10, mobs = "Loch Crocolisk", lvl = "14-15", drop = "44%" },
            { z = 1411, x = 62, y = 78, r = 9, mobs = "Dreadmaw Crocolisk", lvl = "9-11", drop = "41%" },
        } },
    [3667] = { name = "Tender Crocolisk Meat", tags = "croc krokodil",
        uses = { "Crocolisk Gumbo" },
        spots = {
            { z = 1445, x = 52, y = 22, r = 13, mobs = "Drywallow Vicejaw, Drywallow Snapper, Mottled Drywallow Crocolisk, Drywallow Daggermaw", lvl = "36-41", drop = "62-67%", note = "best spot" },
            { z = 1437, x = 35, y = 45, r = 11, mobs = "Wetlands Crocolisk", lvl = "23-24", drop = "59%" },
            { z = 1435, x = 60, y = 60, r = 12, mobs = "Sawtooth Snapper", lvl = "41-42", drop = "59%" },
        } },
    [3712] = { name = "Turtle Meat", tags = "turtle teknős",
        uses = { "Soothing Turtle Bisque", "Savory Turtle Stew", "Grand Lobster Banquet" },
        spots = {
            { z = 1447, x = 55, y = 80, r = 13, mobs = "Coralshell Tortoise, Coralshell Lurker", lvl = "50-52", drop = "39-47%" },
            { z = 1425, x = 80, y = 52, r = 10, mobs = "Saltwater Snapjaw", lvl = "49-50", drop = "41%" },
            { z = 1445, x = 55, y = 45, r = 12, mobs = "Mudrock Tortoise, Mudrock Burrower", lvl = "36-37", drop = "39-41%" },
            { z = 1446, x = 70, y = 42, r = 11, mobs = "Steeljaw Snapper, Surf Glider", lvl = "42-50", drop = "39-40%" },
        } },

    ---------------------------------------------------------------- BIRDS / BATS / EGGS
    [729] = { name = "Stringy Vulture Meat", tags = "vulture keselyű bird",
        uses = { "Westfall Stew" },
        spots = {
            { z = 1441, x = 75, y = 62, r = 13, mobs = "Salt Flats Vulture, Salt Flats Scavenger", lvl = "30-34", drop = "49-51%" },
            { z = 1436, x = 50, y = 50, r = 16, mobs = "Fleshripper, Greater Fleshripper, Young Fleshripper", lvl = "10-17", drop = "31-37%" },
        } },
    [1080] = { name = "Tough Condor Meat", tags = "condor bird keselyű",
        uses = { "Redridge Goulash" },
        spots = {
            { z = 1433, x = 55, y = 45, r = 14, mobs = "Dire Condor", lvl = "18-19", drop = "35%", note = "only source" },
        } },
    [3404] = { name = "Buzzard Wing", tags = "buzzard bird roc szárny",
        uses = { "Soaring Pamplona", "Grand Lobster Banquet" },
        spots = {
            { z = 1446, x = 45, y = 45, r = 15, mobs = "Searing Roc, Fire Roc, Roc", lvl = "41-49", drop = "42-44%", note = "best spot" },
            { z = 1430, x = 50, y = 50, r = 14, mobs = "Sky Shadow", lvl = "55-56", drop = "42% (1-2)" },
            { z = 1422, x = 50, y = 50, r = 15, mobs = "Carrion Vulture", lvl = "50-52", drop = "41% (1-2)" },
        } },
    [12223] = { name = "Meaty Bat Wing", tags = "bat denevér szárny",
        uses = { "Crispy Bat Wing", "Bat Hachee" },
        spots = {
            { z = 1420, x = 50, y = 42, r = 15, mobs = "Vampiric Duskbat, Greater Duskbat", lvl = "6-9", drop = "39-40%", note = "open world - best spot" },
            { z = 1421, x = 45, y = 68, r = 4, mobs = "Vile Bat, Blood Seeker (elite)", lvl = "22-24", drop = "44-45%", note = "inside Shadowfang Keep (dungeon)" },
        } },
    [6889] = { name = "Small Egg", tags = "egg tojás bird",
        uses = { "Herb Baked Egg", "Gingerbread Cookie", "Egg Nog", "Breakfast Omelette", "Skywall Souffle" },
        spots = {
            { z = 1432, x = 50, y = 60, r = 14, mobs = "Mountain Buzzard", lvl = "15-16", drop = "71%", note = "best spot" },
            { z = 1433, x = 55, y = 45, r = 14, mobs = "Dire Condor", lvl = "18-19", drop = "67%" },
            { z = 1436, x = 50, y = 50, r = 16, mobs = "Fleshripper, Greater Fleshripper", lvl = "13-17", drop = "63-64%" },
            { z = 1438, x = 50, y = 50, r = 15, mobs = "Strigid Hunter", lvl = "8-9", drop = "61% (1-2)" },
        } },
    [12207] = { name = "Giant Egg", tags = "egg tojás bird owl",
        uses = { "Monster Omelet", "Giant Scrambled Eggs", "Sunrise Omelette", "Cleansing Stew", "Clamlette Surprise" },
        spots = {
            { z = 1448, x = 50, y = 42, r = 15, mobs = "Ironbeak Screecher, Ironbeak Hunter, Ironbeak Owl", lvl = "48-53", drop = "45-48%", note = "best spot" },
            { z = 1452, x = 58, y = 40, r = 15, mobs = "Winterspring Owl, Winterspring Screecher", lvl = "54-59", drop = "43-45%" },
            { z = 1446, x = 45, y = 45, r = 14, mobs = "Roc, Fire Roc, Searing Roc", lvl = "41-49", drop = "35-41%", note = "central Tanaris desert" },
            { z = 1425, x = 45, y = 55, r = 13, mobs = "Primitive Owlbeast, Savage Owlbeast", lvl = "44-47", drop = "32-35%" },
        } },

    ---------------------------------------------------------------- SPIDERS / SCORPIDS / MISC
    [5465] = { name = "Small Spider Leg", tags = "spider pók láb",
        uses = { "Kaldorei Spider Kabob" },
        spots = {
            { z = 1421, x = 45, y = 40, r = 13, mobs = "Mist Creeper, Moss Stalker", lvl = "12-14", drop = "69-71%" },
            { z = 1432, x = 30, y = 30, r = 11, mobs = "Wood Lurker, Cliff Lurker", lvl = "13-18", drop = "69-71%" },
            { z = 1438, x = 55, y = 65, r = 10, mobs = "Giant Webwood Spider", lvl = "10-11", drop = "67%" },
            { z = 1429, x = 62, y = 52, r = 5, mobs = "Mother Fang (rare)", lvl = "10", drop = "97%", note = "Jasperlode Mine" },
        } },
    [2251] = { name = "Gooey Spider Leg", tags = "spider pók láb",
        uses = { "Gooey Spider Cake" },
        spots = {
            { z = 1417, x = 50, y = 50, r = 15, mobs = "Giant Plains Creeper, Plains Creeper", lvl = "32-36", drop = "45-48%" },
            { z = 1424, x = 50, y = 40, r = 13, mobs = "Elder Moss Creeper, Giant Moss Creeper", lvl = "24-27", drop = "39-42%" },
            { z = 1440, x = 50, y = 70, r = 10, mobs = "Wildthorn Lurker", lvl = "28-29", drop = "39%" },
        } },
    [1081] = { name = "Crisp Spider Meat", tags = "spider pók",
        uses = { "Redridge Goulash" },
        spots = {
            { z = 1422, x = 50, y = 50, r = 14, mobs = "Venom Mist Lurker", lvl = "50-51", drop = "77%" },
            { z = 1417, x = 50, y = 50, r = 15, mobs = "Giant Plains Creeper, Plains Creeper", lvl = "32-36", drop = "51-54%" },
            { z = 1424, x = 50, y = 40, r = 13, mobs = "Elder Moss Creeper, Giant Moss Creeper", lvl = "24-27", drop = "45-47%" },
            { z = 1440, x = 50, y = 70, r = 10, mobs = "Wildthorn Lurker", lvl = "28-29", drop = "46%" },
        } },
    [12205] = { name = "White Spider Meat", tags = "spider pók",
        uses = { "Spider Sausage" },
        spots = {
            { z = 1447, x = 60, y = 40, r = 14, mobs = "Timberweb Recluse", lvl = "47-48", drop = "57%", note = "best spot" },
            { z = 1427, x = 50, y = 50, r = 15, mobs = "Greater Lava Spider, Searing Lava Spider", lvl = "45-49", drop = "53%" },
            { z = 1422, x = 50, y = 50, r = 15, mobs = "Plague Lurker, Carrion Lurker", lvl = "52-55", drop = "49-50%" },
            { z = 1425, x = 60, y = 70, r = 10, mobs = "Witherbark Broodguard", lvl = "44-45", drop = "50%" },
        } },
    [5466] = { name = "Scorpid Stinger", tags = "scorpid skorpió",
        uses = { "Scorpid Surprise" },
        spots = {
            { z = 1411, x = 48, y = 58, r = 14, mobs = "Clattering Scorpid, Armored Scorpid, Venomtail Scorpid, Corrupted Scorpid", lvl = "5-11", drop = "57-72%" },
        } },
    [12037] = { name = "Mystery Meat", tags = "mystery rejtélyes",
        uses = { "Mystery Stew", "Cookie's Feast" },
        spots = {
            { z = 1451, x = 40, y = 46, r = 15, mobs = "Stonelash Flayer, Stonelash Scorpid, Stonelash Pincer", lvl = "54-58", drop = "47-49%" },
            { z = 1446, x = 50, y = 60, r = 15, mobs = "Scorpid Dunestalker, Scorpid Tail Lasher", lvl = "43-47", drop = "48-49%" },
        } },
    [20424] = { name = "Sandworm Meat", tags = "sandworm worm féreg",
        uses = { "Smoked Desert Dumplings" },
        spots = {
            { z = 1451, x = 50, y = 40, r = 17, mobs = "Dredge Striker, Dredge Crusher", lvl = "55-58", drop = "39%" },
        } },
    [21024] = { name = "Chimaerok Tenderloin", tags = "chimaerok",
        uses = { "Dirge's Kickin' Chimaerok Chops" },
        spots = {
            { z = 1444, x = 32, y = 82, r = 8, mobs = "Arcane Chimaerok, Chimaerok Devourer, Chimaerok (elite)", lvl = "60-62", drop = "46-49%", note = "Isle of Dread - bring a group" },
        } },
    [5051] = { name = "Dig Rat", tags = "rat patkány",
        uses = { "Dig Rat Stew" },
        spots = {
            { z = 1441, x = 50, y = 50, r = 17, mobs = "Dig Rat", lvl = "1", drop = "50%", note = "Cooking 1-300 route needs ~212" },
        } },

    ---------------------------------------------------------------- KODO / STRIDER
    [5467] = { name = "Kodo Meat", tags = "kodo",
        uses = { "Roasted Kodo Meat" },
        spots = {
            { z = 1413, x = 45, y = 62, r = 14, mobs = "Wooly Kodo, Greater Barrens Kodo, Barrens Kodo", lvl = "19-26", drop = "46-56%", note = "south Barrens" },
            { z = 1412, x = 50, y = 60, r = 14, mobs = "Kodo Calf, Kodo Matriarch", lvl = "7-12", drop = "42-48%" },
        } },
    [12204] = { name = "Heavy Kodo Meat", tags = "kodo",
        uses = { "Heavy Kodo Stew", "Cookie's Feast" },
        spots = {
            { z = 1443, x = 53, y = 58, r = 12, mobs = "Dying Kodo, Ancient Kodo, Aged Kodo", lvl = "34-37", drop = "40-55%", note = "Kodo Graveyard - only source" },
        } },
    [5469] = { name = "Strider Meat", tags = "strider",
        uses = { "Strider Stew" },
        spots = {
            { z = 1439, x = 42, y = 62, r = 13, mobs = "Foreststrider, Foreststrider Fledgling, Giant Foreststrider", lvl = "11-19", drop = "39-45%" },
            { z = 1413, x = 50, y = 40, r = 15, mobs = "Greater Plainstrider, Fleeting Plainstrider, Ornery Plainstrider", lvl = "11-17", drop = "40-41%" },
        } },

    ---------------------------------------------------------------- CRABS / CLAMS / MURLOCS / FRENZY
    [2674] = { name = "Crawler Meat", tags = "crab crawler rák",
        uses = { "Crab Cake" },
        spots = {
            { z = 1436, x = 28, y = 56, r = 11, mobs = "Sand Crawler", lvl = "13-14", drop = "43%" },
            { z = 1440, x = 15, y = 28, r = 10, mobs = "Spined Crawler", lvl = "20-21", drop = "42%", note = "Zoram Strand coast" },
            { z = 1439, x = 38, y = 42, r = 11, mobs = "Encrusted Tide Crawler", lvl = "18-20", drop = "40%" },
        } },
    [2675] = { name = "Crawler Claw", tags = "crab crawler rák olló",
        uses = { "Cooked Crab Claw", "Pincer Bites" },
        spots = {
            { z = 1436, x = 28, y = 56, r = 11, mobs = "Sand Crawler", lvl = "13-14", drop = "44%" },
            { z = 1439, x = 38, y = 42, r = 11, mobs = "Encrusted Tide Crawler", lvl = "18-20" },
        } },
    [12206] = { name = "Tender Crab Meat", tags = "crab rák",
        uses = { "Briny Seafood Stew" },
        spots = {
            { z = 1435, x = 85, y = 35, r = 10, mobs = "Monstrous Crawler, Silt Crawler", lvl = "40-44", drop = "33-38%", note = "Misty Reed Strand coast" },
            { z = 1434, x = 28, y = 66, r = 10, mobs = "Southern Sand Crawler", lvl = "40-41", drop = "36%" },
        } },
    [5503] = { name = "Clam Meat", tags = "clam kagyló",
        uses = { "Clam Chowder" },
        spots = {
            { z = 1436, x = 28, y = 56, r = 11, mobs = "Sand Crawler (open the clams they drop)", lvl = "13-14" },
            { z = 1439, x = 38, y = 42, r = 11, mobs = "Tide crawlers (open the clams)", lvl = "10-20" },
        } },
    [7974] = { name = "Zesty Clam Meat", tags = "clam kagyló clamlette",
        uses = { "Undermine Clam Chowder", "Clam Linguine", "Clamlette Surprise" },
        spots = {
            { z = 1446, x = 68, y = 30, r = 10, mobs = "Steeljaw Snapper (Big-mouth Clam)", lvl = "42-43", note = "east coast, south of Steamwheedle Port - open the clams", drop = "clam ~100% meat" },
            { z = 1425, x = 80, y = 52, r = 10, mobs = "Saltwater Snapjaw (Big-mouth Clam)", lvl = "49-50", note = "east coast turtles, ~40% clam drop" },
            { z = 1435, x = 88, y = 42, r = 9, mobs = "Coastal murlocs and crawlers (Big-mouth Clam)", lvl = "37-44", note = "Misty Reed Strand / Stagalbog coast" },
            { z = 1447, x = 50, y = 55, r = 12, mobs = "Spitelash naga (Big-mouth Clam)", lvl = "45-50" },
        } },
    [4655] = { name = "Giant Clam Meat", tags = "clam kagyló",
        uses = { "Giant Clam Scorcho" },
        spots = {
            { z = 1434, x = 26, y = 60, r = 10, mobs = "Giant Clam (underwater object, STV coast)", lvl = "35+", note = "open the Giant Clams on the sea floor" },
        } },
    [1468] = { name = "Murloc Fin", tags = "murloc fin uszony",
        uses = { "Murloc Fin Soup", "Mrrggl Smrrthle" },
        spots = {
            { z = 1436, x = 28, y = 40, r = 11, mobs = "Murloc Minor Oracle, Murloc Warrior, Murloc Tidehunter, Murloc Oracle, Murloc Raider", lvl = "11-19", drop = "42-77%", note = "Westfall coast - best spot" },
            { z = 1437, x = 15, y = 30, r = 9, mobs = "Bluegill Raider", lvl = "28-29", drop = "42%" },
        } },
    [730] = { name = "Murloc Eye", tags = "murloc eye szem",
        uses = { "Westfall Stew", "Briny Seafood Stew" },
        spots = {
            { z = 1437, x = 15, y = 30, r = 9, mobs = "Bluegill Raider", lvl = "28-29", drop = "47%" },
            { z = 1421, x = 60, y = 40, r = 10, mobs = "Vile Fin Lakestalker, Vile Fin Tidecaller", lvl = "17-19", drop = "37-40%" },
            { z = 1436, x = 28, y = 40, r = 11, mobs = "Murloc Tidehunter, Murloc Oracle, Murloc Hunter", lvl = "16-19", drop = "35-38%" },
        } },
    [5468] = { name = "Soft Frenzy Flesh", tags = "frenzy fish hal",
        uses = { "Fillet of Frenzy" },
        spots = {
            { z = 1416, x = 40, y = 70, r = 9, mobs = "Lake Frenzy", lvl = "15-16", drop = "52%" },
            { z = 1411, x = 54, y = 40, r = 10, mobs = "Muck Frenzy", lvl = "14-15", drop = "49%" },
            { z = 1421, x = 60, y = 40, r = 10, mobs = "Reef Frenzy", lvl = "14-15", drop = "46%" },
        } },

    ---------------------------------------------------------------- SMOOTHIE REAGENTS (new in Forever)
    [3174] = { name = "Spider Ichor", tags = "spider pók ichor smoothie",
        uses = { "Slimy Smoothie" },
        spots = {
            { z = 1431, x = 45, y = 30, r = 12, mobs = "Black Widow Hatchling, Carrion Recluse, Naraxis (rare)", lvl = "24-27", drop = "47-53%" },
            { z = 1440, x = 50, y = 70, r = 10, mobs = "Wildthorn Lurker, Wildthorn Venomspitter", lvl = "24-29", drop = "46-51%" },
            { z = 1442, x = 55, y = 75, r = 11, mobs = "Deepmoss Creeper, Deepmoss Webspinner", lvl = "16-20", drop = "47%" },
        } },
    [1475] = { name = "Small Venom Sac", tags = "venom méreg smoothie",
        uses = { "Venomous Smoothie" },
        spots = {
            { z = 1442, x = 55, y = 75, r = 11, mobs = "Deepmoss Webspinner, Deepmoss Venomspitter, Deepmoss Creeper", lvl = "16-20", drop = "10-11%" },
            { z = 1433, x = 52, y = 46, r = 12, mobs = "Greater Tarantula, Tarantula", lvl = "15-20", drop = "9-11%" },
            { z = 1411, x = 48, y = 58, r = 12, mobs = "Corrupted Scorpid", lvl = "10-11", drop = "11%" },
        } },
    [5637] = { name = "Large Fang", tags = "fang agyar smoothie",
        uses = { "Calcified Smoothie" },
        spots = {
            { z = 1435, x = 50, y = 50, r = 15, mobs = "Swamp Jaguar, Shadow Panther", lvl = "36-40", drop = "11-13%", note = "best spot" },
            { z = 1434, x = 40, y = 22, r = 10, mobs = "Shadowmaw Panther, Stranglethorn Tigress", lvl = "37-38", drop = "7-8%" },
            { z = 1418, x = 50, y = 45, r = 15, mobs = "Ridge Huntress", lvl = "38-39", drop = "8%" },
        } },
    [4402] = { name = "Small Flame Sac", tags = "flame láng smoothie whelp",
        uses = { "Spicy Smoothie" },
        spots = {
            { z = 1445, x = 45, y = 75, r = 11, mobs = "Searing Hatchling, Searing Whelp", lvl = "41-43", drop = "13%", note = "Wyrmbog" },
            { z = 1418, x = 15, y = 60, r = 11, mobs = "Scalding Whelp, Scorched Guardian (elite)", lvl = "41-45", drop = "13-14%" },
        } },
    [8146] = { name = "Wicked Claw", tags = "claw karom smoothie",
        uses = { "Wicked Smoothie" },
        spots = {
            { z = 1419, x = 50, y = 40, r = 14, mobs = "Felbeast", lvl = "50-51", drop = "12%" },
            { z = 1423, x = 50, y = 50, r = 16, mobs = "Noxious Plaguebat, Plaguebat, Monstrous Plaguebat", lvl = "53-58", drop = "7-9%" },
        } },

    ---------------------------------------------------------------- VENDOR REAGENTS (buy, not farm)
    ["Mild Spices"]     = { name = "Mild Spices", tags = "spice fűszer vendor reagent", vendor = "Cooking Supplies vendors (next to cooking trainers)", spots = {} },
    ["Hot Spices"]      = { name = "Hot Spices", tags = "spice fűszer vendor reagent", vendor = "Cooking Supplies vendors", spots = {} },
    ["Soothing Spices"] = { name = "Soothing Spices", tags = "spice fűszer vendor reagent", vendor = "Cooking Supplies vendors", spots = {} },
    ["Simple Flour"]    = { name = "Simple Flour", tags = "flour liszt vendor reagent", vendor = "Cooking Supplies / Trade Goods vendors", spots = {} },
    ["Refreshing Spring Water"] = { name = "Refreshing Spring Water", tags = "water víz vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Ice Cold Milk"]   = { name = "Ice Cold Milk", tags = "milk tej vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Melon Juice"]     = { name = "Melon Juice", tags = "juice lé vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Moonberry Juice"] = { name = "Moonberry Juice", tags = "juice lé vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Sweet Nectar"]    = { name = "Sweet Nectar", tags = "nectar vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Morning Glory Dew"] = { name = "Morning Glory Dew", tags = "dew vendor reagent", vendor = "Innkeepers and Food & Drink vendors", spots = {} },
    ["Alterac Swiss"]   = { name = "Alterac Swiss", tags = "cheese sajt vendor reagent clamlette", vendor = "Horde: Innkeeper Pala (Thunder Bluff 45.9, 64.8), Freewind Post innkeeper (Thousand Needles)  -  Alliance: Ben Trias (Stormwind 66.4, 73.7)", spots = {} },
})
