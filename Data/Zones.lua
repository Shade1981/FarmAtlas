-- FarmAtlas - zone table (Classic uiMapIDs; verified by name at runtime)
local _, ns = ...

local Z = {
    -- Kalimdor
    [1411] = { "Durotar", 1, 10 },
    [1412] = { "Mulgore", 1, 10 },
    [1413] = { "The Barrens", 10, 25 },
    [1438] = { "Teldrassil", 1, 11 },
    [1439] = { "Darkshore", 10, 20 },
    [1440] = { "Ashenvale", 18, 30 },
    [1442] = { "Stonetalon Mountains", 15, 27 },
    [1441] = { "Thousand Needles", 25, 35 },
    [1443] = { "Desolace", 30, 40 },
    [1445] = { "Dustwallow Marsh", 35, 45 },
    [1444] = { "Feralas", 40, 50 },
    [1446] = { "Tanaris", 40, 50 },
    [1447] = { "Azshara", 45, 55 },
    [1448] = { "Felwood", 48, 55 },
    [1449] = { "Un'Goro Crater", 48, 55 },
    [1451] = { "Silithus", 55, 60 },
    [1452] = { "Winterspring", 55, 60 },
    -- Eastern Kingdoms
    [1426] = { "Dun Morogh", 1, 10 },
    [1429] = { "Elwynn Forest", 1, 10 },
    [1420] = { "Tirisfal Glades", 1, 10 },
    [1432] = { "Loch Modan", 10, 20 },
    [1436] = { "Westfall", 10, 20 },
    [1421] = { "Silverpine Forest", 10, 20 },
    [1433] = { "Redridge Mountains", 15, 25 },
    [1431] = { "Duskwood", 18, 30 },
    [1437] = { "Wetlands", 20, 30 },
    [1424] = { "Hillsbrad Foothills", 20, 30 },
    [1416] = { "Alterac Mountains", 30, 40 },
    [1417] = { "Arathi Highlands", 30, 40 },
    [1434] = { "Stranglethorn Vale", 30, 45 },
    [1418] = { "Badlands", 35, 45 },
    [1435] = { "Swamp of Sorrows", 35, 45 },
    [1425] = { "The Hinterlands", 40, 50 },
    [1427] = { "Searing Gorge", 43, 50 },
    [1419] = { "Blasted Lands", 45, 55 },
    [1430] = { "Deadwind Pass", 55, 60 },
    [1428] = { "Burning Steppes", 50, 58 },
    [1422] = { "Western Plaguelands", 51, 58 },
    [1423] = { "Eastern Plaguelands", 53, 60 },
}

for id, z in pairs(Z) do
    ns.Zones[id] = { id = id, name = z[1], min = z[2], max = z[3] }
end
