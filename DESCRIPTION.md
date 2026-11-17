# FarmAtlas

**Find where to farm every cooking meat, leather, scale and fish - right on your world map and minimap.**

Made for **WoW Forever**. Search *boar*, *raptor*, *stag* or *Giant Egg* and FarmAtlas shows you the best farm areas with mob names, levels and drop chances, marks them on your map, tells you which recipes use the ingredient, and counts what you already have in your bags, bank and on your alts.

GatherMate covers herbs and ore. FarmAtlas covers everything else you have to *kill* for.

---

## New in 1.2.1 - Giga Database Update

- **Every farm spot:** each meat, leather, scale and fish lists all the zones where it can be farmed - **746 new farm areas in 410 more zones**, with mobs, levels and drop chances.
- 3 new fish: Raw Slitherskin Mackerel, Raw Sagefish, Raw Greater Sagefish.
- The minimap button stays visible next to button collectors and minimap skins; FarmAtlas is also in the game's addon menu.

## New in 1.2.0

- **Leveling guides**: Cooking, Fishing and Skinning 1-300 for WoW Forever, faction-aware, with your current step highlighted and the places marked on the map.
- **Trainers** of your current step on the map and minimap, exact WoW Forever coordinates, plus a **town banner** when you arrive somewhere with a trainer you care about.
- **Real farm shapes**: areas follow where the mobs and fish really are, learned from loot.
- **Farm / hour in gold** and auction house prices (Auctionator / TSM / AHSnipe, vendor price as fallback) on tooltips.
- **Click a recipe** to open your profession window on it, or see where to learn it.
- **French, German and Spanish** interface.

![Cooking, Fishing and Skinning leveling guides](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/guide-list.png)



---

## Features

**Farm atlas**
- 100+ farmable materials built in: cooking meats & ingredients, leather, hides & scales, fish.
- Every material lists its farm areas with mob names, level range and drop chance.
- A **recommended** zone for your level, and dangerous zones are flagged.
- Search by item, mob, zone or keyword (`boar`, `wolf`, `rugged`, `squid`...).
- Materials are listed in **leveling order**, with the level or fishing skill on every row.
- **On me** filter: only what is in your bags.

![Materials in leveling order with level and fishing skill](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/fish-list.png)





**Map & minimap**
- Translucent, quest-style farm areas with a dashed outline on the world map.
- Track several items at once, each in its own color.
- **Minimap**: the area when it is close, an edge icon pointing the way when it is far, and a colored glow when you are standing inside it.
- Areas take the **real shape** of the spot once enough loot is recorded (yours, your group's and the community's).

![Farm areas and drop chances on the world map](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/map-tooltip.jpg)



**Leveling guides**
- **Cooking, Fishing and Skinning 1-300**, each on its own tab: what to make, where to go, which rank to train next.
- Click a step: the place is marked in gold on the world map; cooking steps show where to farm the material.
- The trainers of your current step appear on the map and minimap automatically.
- **Town alert**: a movable, resizable banner when you arrive at a town, village or camp with a trainer of a profession you switched on.

**Recipes**
- **Recipes tab**: all 123 WoW Forever cooking recipes. The ones you don't know have a red veil, but the whole recipe is readable on hover - the game's own item tooltip with the exact effect, skill colors and reagents.
- **Click** a known recipe to open your profession window on it; click an unknown one to see where to buy or learn it, with the place on the map.
- **Craftable now** filter: only the recipes you have every ingredient for.
- Reads your Cooking window automatically - no buttons.

![All WoW Forever cooking recipes](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/recipe-list.png)



![Where to learn a recipe you do not know yet](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/recipe-popup.png)



**Goals**
- Set how many you need (e.g. 20x Raptor Flesh). A progress bar counts your bags and bank, and you get an on-screen message and a sound when the goal is reached.

**Bags, bank & alts**
- Item tooltips and the atlas show how many you have on this character, in the bank and on your alts.

**Prices & farm / hour**
- Auction house price on item and mob tooltips from Auctionator, TSM or AHSnipe (all optional); the last known price, or the vendor price, when none is open.
- **Farm / hour in gold**: what you really looted in the last 60 minutes and what it is worth, plus the value of everything you own.

**Settings**
- Gear button in the atlas (or `/farm config`): every switch, grouped by topic. A short "What's new" window after each update.

**Learns while you play**
- Every meat, hide or fish you loot is saved with its exact spot and source mob.
- **Real WoW Forever drop rates** from your own kills (e.g. `Mottled Boar: 42% (21/50)`).

**Automatic sharing (no buttons)**
- Discoveries are shared in the background with your **party, raid and guild** members who also use FarmAtlas, through Blizzard's hidden addon channel (like GatherMate2). Turn it off with `/farm sync`.

**Quick search**
- **Alt + click** any item (bags, chat link, recipe reagent) to open it in FarmAtlas.

**Languages**
- English, Hungarian, French, German and Spanish interface. On a French, German or Spanish game client FarmAtlas starts in that language, and item, recipe and zone names are shown the way your game names them (English names work in the search too).

![Five interface languages](https://raw.githubusercontent.com/Shade1981/FarmAtlas/main/media/desc/lang-menu.png)



---

## Commands

| Command | |
| --- | --- |
| `/farm` | open FarmAtlas (also: minimap button, world map button) |
| `/farm boar` | open with a search |
| `/farm goals` | farm goals window |
| `/farm config` | settings |
| `/farm trainers` | every trainer of a profession on the map |
| `/farm banner` | move / resize the town banner |
| `/farm news` | what's new |
| `/farm sync` | background sharing on/off |
| `/farm lang en` / `hu` / `fr` / `de` / `es` | interface language |
| `/farm help` | all commands |

---

## Help the community map

Drop chances and areas start from Classic-based data and get more precise with every player. Your `WTF\Account\<ACCOUNT>\SavedVariables\FarmAtlas.lua` file contains everything you and your guild discovered - share it with the author and it gets merged into the next release for everyone.

## Feedback

Found a wrong spot or a bug? Leave a comment with a screenshot. For Lua errors, `/farm debug` shows blocked-action reports.

---

*Created by **Shade**. Free and open source (MIT).*

---

# FarmAtlas (magyar)

**Megmutatja, hol farmolhatsz húst, bőrt, pikkelyt és halat - a világtérképen és a minimapon.**

- Keress rá bármire (pl. *boar*, *raptor*), és látod a farmterületeket mobokkal, szintekkel, esési eséllyel.
- Áttetsző zónák a térképen, irányjelzés és keret a minimapon.
- **Útmutató**: Főzés, Horgászat és Nyúzás 1-300, trénerekkel a térképen és település-jelzéssel.
- A farmterületek a valódi alakot követik, ahogy gyűlik a loot.
- **Receptek** fül: mind a 123 főzőrecept, kattintásra megnyílik a szakma ablak, vagy megmutatja, hol tanulható.
- **Farm / óra aranyban** és AH-árak a tooltipen (Auctionator / TSM / AHSnipe, vagy vendor ár).
- Farm célok, táska / bank / alt számláló, valódi esési arányok a saját öléseidből.
- Automatikus megosztás party / raid / guild társakkal - gombnyomás nélkül.
- Magyar, angol, francia, német és spanyol felület (`/farm lang hu`); angol kliensen a tárgynevek angolul maradnak, ahogy a receptkönyvben.

*Készítette: **Shade***
