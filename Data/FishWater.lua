-- FarmAtlas - fishing places: one marker per water (lake, river, coast), and a
-- new marker only where the catch changes on the same water. Positions were
-- measured on the in-game zone maps and checked by eye; zones that are still
-- being checked have no markers yet.
-- [uiMapID] = { { x, y, name, fish = { [itemID] = fishing skill needed } } }
local _, ns = ...

ns.FISH_SITES = {
    [1411] = {
        { x = 63.6, y = 48.1, name = "Durotar coast", fish = { [6291] = 1, [6303] = 1 } },
        { x = 34.4, y = 28.4, name = "Southfury River", fish = { [6289] = 1, [6291] = 1 } },
    },
    [1412] = {
        { x = 48.5, y = 56.7, name = "Stonebull Lake", fish = { [6289] = 1, [6291] = 1 } },
    },
    [1413] = {
        { x = 72, y = 50.1, name = "Merchant Coast / Ratchet", fish = { [6303] = 1, [6361] = 75, [6358] = 100, [6359] = 100 } },
        { x = 47.8, y = 34.4, name = "The Forgotten Pools", fish = { [6289] = 1, [6291] = 1, [6522] = 75, [6308] = 75 } },
        { x = 63.6, y = 52.3, name = "Merchant Coast / Ratchet", fish = { [6303] = 1, [6361] = 75, [6358] = 100 } },
    },
    [1417] = {
        { x = 27.8, y = 52.1, name = "Arathi coast", fish = { [8365] = 175, [6362] = 175 } },
        { x = 68.4, y = 63.2, name = "Arathi inland waters", fish = { [8365] = 175 } },
        { x = 32.2, y = 93, name = "Faldir's Cove", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [4603] = 225 } },
    },
    [1420] = {
        { x = 66, y = 47, name = "Brightwater Lake", fish = { [6289] = 1, [6291] = 1 } },
        { x = 62, y = 60.4, name = "Tirisfal rivers & lakes", fish = { [6289] = 1 } },
    },
    [1421] = {
        { x = 33.1, y = 39.2, name = "Silverpine west coast", fish = { [6303] = 1, [6361] = 75, [6358] = 100 } },
        { x = 69, y = 28.9, name = "Fenris Isle lake", fish = { [6289] = 1, [6291] = 1, [21071] = 55, [6308] = 75 } },
    },
    [1422] = {
        { x = 69.8, y = 47.5, name = "Western Plaguelands lakes", fish = { [8365] = 175, [13758] = 225, [13760] = 250 } },
        { x = 61.2, y = 66.5, name = "Western Plaguelands lakes", fish = { [8365] = 175, [13758] = 225, [13760] = 250 } },
        { x = 39.5, y = 75.9, name = "Darrowmere Lake", fish = { [8365] = 175, [13758] = 225, [13760] = 250, [13759] = 250 } },
    },
    [1424] = {
        { x = 68.1, y = 22.5, name = "Darrow Hill lakes", fish = { [6289] = 1, [21071] = 55, [6308] = 75 } },
        { x = 60.6, y = 62.8, name = "Southshore coast", fish = { [6361] = 75, [6358] = 100, [6359] = 100 } },
        { x = 59.6, y = 44.4, name = "Darrow Hill lakes", fish = { [6289] = 1, [21071] = 55, [6308] = 75 } },
    },
    [1425] = {
        { x = 90.5, y = 49, name = "Hinterlands east coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [13754] = 205, [13422] = 225, [4603] = 225, [13756] = 250, [13755] = 330 } },
        { x = 50.4, y = 37, name = "Hinterlands lakes", fish = { [8365] = 175, [13758] = 225, [13760] = 250, [13759] = 250 } },
    },
    [1429] = {
        { x = 77.3, y = 56.5, name = "Stone Cairn Lake", fish = { [6289] = 1, [6291] = 1 } },
        { x = 55.4, y = 64.8, name = "Crystal Lake", fish = { [6289] = 1, [6291] = 1 } },
    },
    [1431] = {
        { x = 12.1, y = 73.5, name = "Duskwood river", fish = { [6289] = 1, [6308] = 75 } },
    },
    [1432] = {
        { x = 41.5, y = 43.3, name = "The Loch", fish = { [6289] = 1, [6291] = 1, [6317] = 50, [21071] = 55, [6308] = 75 } },
    },
    [1433] = {
        { x = 44.3, y = 54.5, name = "Lake Everstill", fish = { [6289] = 1, [6308] = 75 } },
    },
    [1434] = {
        { x = 41.4, y = 19.7, name = "Lake Nazferiti", fish = { [6308] = 75, [21153] = 130, [8365] = 175 } },
        { x = 28.3, y = 29.3, name = "Savage Coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [13754] = 205, [13422] = 225, [4603] = 225, [13756] = 250, [13755] = 330 } },
        { x = 34.3, y = 74.6, name = "Booty Bay coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [13754] = 205, [13422] = 225, [4603] = 225, [13756] = 250, [13755] = 330 } },
    },
    [1435] = {
        { x = 76.5, y = 61.7, name = "Misty Reed Strand", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [4603] = 225 } },
        { x = 56.4, y = 50.1, name = "Swamp of Sorrows waters", fish = { [6308] = 75, [8365] = 175 } },
    },
    [1436] = {
        { x = 17.9, y = 50.5, name = "Westfall coast", fish = { [6303] = 1, [6361] = 75, [6358] = 100, [6359] = 100 } },
        { x = 24.6, y = 38.7, name = "Westfall coast", fish = { [6303] = 1 } },
        { x = 65.2, y = 40, name = "Westfall rivers", fish = { [6289] = 1, [6291] = 1 } },
        { x = 65, y = 43.8, name = "Westfall rivers", fish = { [6289] = 1, [6291] = 1, [6308] = 75 } },
    },
    [1437] = {
        { x = 8.3, y = 64.6, name = "Menethil coast / Baradin Bay", fish = { [6361] = 75, [6358] = 100, [6359] = 100 } },
        { x = 8.9, y = 46.8, name = "Wetlands coast pools", fish = { [6359] = 100 } },
        { x = 53.6, y = 37, name = "Wetlands marsh waters", fish = { [6289] = 1 } },
        { x = 47.5, y = 55.4, name = "Wetlands marsh waters", fish = { [6289] = 1, [6308] = 75 } },
    },
    [1438] = {
        { x = 43.3, y = 42, name = "Teldrassil lakes", fish = { [6291] = 1 } },
        { x = 57.9, y = 67.2, name = "Lake Al'Ameth", fish = { [6289] = 1 } },
        { x = 63, y = 93.2, name = "Rut'theran coast", fish = { [6303] = 1 } },
    },
    [1439] = {
        { x = 28.9, y = 44.2, name = "Darkshore coast", fish = { [6303] = 1 } },
        { x = 36.3, y = 42.9, name = "Darkshore rivers", fish = { [6289] = 1, [6291] = 1, [6303] = 1, [6308] = 75, [6361] = 75, [6358] = 100 } },
    },
    [1440] = {
        { x = 11.4, y = 31.1, name = "Zoram Strand", fish = { [6361] = 75, [6358] = 100, [6359] = 100 } },
        { x = 36.6, y = 47.9, name = "Ashenvale lakes (west)", fish = { [6289] = 1, [21071] = 55, [6308] = 75 } },
        { x = 50.9, y = 70.5, name = "Ashenvale lakes (south)", fish = { [6289] = 1, [21071] = 55, [6308] = 75 } },
    },
    [1442] = {
        { x = 63, y = 42.2, name = "Mirkfallon Lake", fish = { [6289] = 1, [21071] = 55, [6308] = 75, [6359] = 100 } },
    },
    [1443] = {
        { x = 17.1, y = 76.6, name = "Shadowprey coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [4603] = 225 } },
        { x = 24.6, y = 36.8, name = "Desolace coast", fish = { [6362] = 175 } },
        { x = 28.9, y = 63.7, name = "Shadowprey coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [4603] = 225 } },
    },
    [1444] = {
        { x = 22.2, y = 41.1, name = "Feathermoon coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [13756] = 250 } },
        { x = 61.4, y = 11.2, name = "Jademir Lake", fish = { [8365] = 175, [13758] = 225, [13760] = 250, [13759] = 250, [13889] = 300, ["Raw Plated Armorfish"] = 300 } },
        { x = 37.5, y = 44, name = "Feathermoon coast", fish = { [6358] = 100, [6359] = 100, [6362] = 175, [13754] = 205, [13422] = 225, [13755] = 225, [4603] = 225, [13756] = 250 } },
        { x = 75.5, y = 43.1, name = "lake north of Camp Mojache", fish = { [8365] = 175, [13758] = 225, [13760] = 250, [13759] = 250, [13889] = 300 } },
        { x = 59.6, y = 45.7, name = "Jademir Lake", fish = { [13889] = 300 } },
    },
    [1445] = {
        { x = 71.7, y = 35.7, name = "Theramore coast", fish = { [6358] = 100, [6359] = 100, [4603] = 225 } },
        { x = 59.5, y = 47.7, name = "Dustwallow inner waters", fish = { [6308] = 75, [6358] = 100, [6359] = 100, [8365] = 175, [6362] = 175, [4603] = 225 } },
        { x = 57.7, y = 58, name = "Dustwallow inland waters", fish = { [8365] = 175 } },
    },
    [1448] = {
        { x = 58.9, y = 52.7, name = "Felwood rivers & ponds", fish = { [6358] = 100, [8365] = 175, [13758] = 225, [13760] = 250, [13759] = 250 } },
    },
}
