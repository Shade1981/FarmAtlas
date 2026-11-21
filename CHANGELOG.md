# FarmAtlas 1.7.0 - Master Crafter

- New: Professions window ("Professions" button at the top, or /farm prof): every recipe of all 12 professions, known or not - learn skill and the orange / yellow / green / grey levels, where to learn it (trainer, vendor with its price, drop, quest), reagents with how many you have, cost of one craft and its auction house price
- New: skill-up planner - the cheapest way from your skill to 75 / 150 / 225 / 300 with auction house and vendor prices, your own materials first; recipes with a cooldown (camp items, transmutes, Mooncloth) are left out
- New: profit list (what is worth crafting now, 5% AH cut taken off), favourites, and a shopping list with missing materials and their cost
- New: every material FarmAtlas knows how to farm has a Farm button that opens the atlas on it
- Skill levels and sources: LibProfessionDB (MIT, by Pimptasty), installed with FarmAtlas by the CurseForge app; recipes and reagents are read from your own profession windows; vendor prices you see at merchants are remembered
- Fixed: known recipes, bags and bank are kept per character again - also when two characters share a first name (WoW Forever "First Last" names) or the game does not tell the realm name
- Fixed: synchronisation and restore in guild and group with WoW Forever full names
- Community data: 12 players, 125 items, 276 NPCs with kill counts, 37 trainer positions, 4 fishing schools

# FarmAtlas 1.6.2

- Fixed: characters sharing a first name overwrote each other's known recipes and bags - open each profession once more after updating
- Fixed: with a rotating minimap the FarmAtlas icons, areas and trainers pointed the wrong way
- Better sync between guild and group members
- Community data: 10 players, 122 items, 257 NPCs with kill counts, 34 trainer positions, 4 fishing schools

# FarmAtlas 1.6.1

- Fixed: a sync problem in party and guild

# FarmAtlas 1.6.0 - The Complete Atlas

- New: every crafting guide step lists its exact materials in total (per craft x crafts) and how many you have; reagents per craft from the metabot.gg and seemeta.com recipe tables (both read from the Forever client), cross-checked with the wow-professions.com totals. Your own profession window's reagents win once you know the recipe
- New: Enchanting 1-300 guide (12 professions now). Route from wow-professions.com Forever, cross-checked with method.gg and rankedboost.com - only steps at least two of them agree on. Trainers filtered by the rank they really teach (in-game titles); Annora (Uldaman) is the only Artisan trainer. Positions, Mote of Magic and formula vendors from the Questie Forever database
- Fixed: fishing schools were never recorded in WoW Forever - the client reports the bobber as the loot source even for a school. Schools are now recognised from the world tooltip ("Oily Blackmouth School"): after you move the mouse onto a school once, the catches nearby (45 s, renewed by every catch) are saved as a school spot, shown on the map and used by the school alert. A chat line tells you when a new school spot is recorded
- New: fishable wreckage, debris and oil spills are recorded too - recognised from the tooltip (English names, or any object under the mouse while you cast). Each spot is shown on the world map with what you caught there. Settings > Map & minimap
- Sync: fishing schools (P), fishable wreckage spots and catches (O/Q) and trainer positions (T) are shared with guild / group members too; older versions ignore the new messages. The release's community data now also carries wreckage spots
- Restore after a reinstall: a restore that is still running stays open past the first 15 minutes (closes after 2 minutes of silence, at most 1 hour)
- Fixed: shift-clicking an item link into the FarmAtlas search box works with the Midnight-based chat (ChatFrameUtil)
- Community data: 4 players, 56 items, 51 NPCs with kill counts, 5 recipe sources, 2 fishing schools, 3 trainer positions
- New: louder bite while fishing - music and ambience are turned down and effects up while you fish; your own volumes come back 20 seconds after your last cast, also after a /reload or logout. Settings > Map & minimap

# FarmAtlas 1.5.1

- Fixed: fighting with the world map open could print "ADDON_ACTION_BLOCKED: Button:SetPassThroughButtons()" - during combat FarmAtlas no longer acquires or releases map pins (that tainted the map canvas and Blizzard's own pins were then blocked); it hides its pins if you switch maps in combat and redraws them right after the fight. Switching the map from FarmAtlas during combat waits until the fight is over. Thanks to laykes for the report

# FarmAtlas 1.5.0

- New: Blacksmithing 1-300 guide (wow-professions.com route; ranks cross-checked with method.gg) - trainers with the highest rank each can teach, Artisan only at Brikk Keencraft (Booty Bay), Imperial Plate plans from Derotain Mudsipper's quests (Gadgetzan, level 50)
- New: Engineering 1-300 guide (wow-professions.com route, 1-225 cross-checked with icy-veins.com) - Artisan only at Buzzek Bracketswing (Gadgetzan), schematic vendors for Thorium Widget and Thorium Tube
- 225-300 of both guides comes from the Forever beta (the sources say so)
- Community data now also ships recipe sources (trainers, vendors, drops), fishing schools and trainer positions players saw in game; each release keeps everything the previous one had
- New: restore after a fresh install / new computer - at login FarmAtlas says hello to your guild and group; a member who once received your finds (and has more than you now) sends them back to you only. Merged by the larger value, so nothing is ever doubled; only accepted right after your own hello. Works with members on 1.5.0 or newer
- Fixed: long settings pages (town alerts, trainer pins for 11 professions) ran out of the window - they now scroll, with a scroll bar

# FarmAtlas 1.4.0

- New: Best farm now window (header button, /farm best) - ranks what you can farm right now (your Herbalism / Mining / Fishing / Skinning skill and your level) by gold per hour
- Prices: AH Snipe's 14-day median of daily lowest buyouts when AH Snipe is installed, else Auctionator / TSM, else vendor price
- Items per hour: measured from your own farming (from 10 minutes on), shown as an estimate until then
- Uses the AH Snipe 3 price API (realm- and faction-aware median, listed quantity) when available
- Fixed: remembered auction prices are kept per realm and faction
- New: Mining 1-300 and Herbalism 1-300 guides (wow-professions.com route, cross-checked with icy-veins.com); the map marks only the step's ores / herbs; junior trainers listed only up to 75
- Guide tabs show the profession icon; when they do not fit on one row, only the chosen one keeps its name
- Includes everything from 1.3.2 (Tailoring guide, recipe click for every profession)

# FarmAtlas 1.3.2

- New: Tailoring 1-300 guide - trainers with the highest rank each can teach, the Artisan trainers (Daryl Stack, Timothy Worthington), pattern vendors Qia and Pexmit and the Horde quest alternative, at exact positions
- Fixed: clicking a known recipe opens the right profession window for every profession (not only Cooking) and selects the recipe in older-style windows
- Fixed: Mount Hyjal NPCs (e.g. Elderwild cooking trainers) now get their map position
- Guide tabs fit on one row in every language

# FarmAtlas 1.3.1

- New: First Aid 1-300 guide - all trainers, the Expert book vendors (and the two manuals), the Triage quest doctors who also teach the last bandages, at exact positions
- New: Alchemy 1-300 guide - trainers with the highest rank each can teach (rank steps only list those who teach it), recipe vendors for Nature Protection Potion, Elixir of Superior Defense and Superior Mana Potion
- New: fishing schools are learned for every fish (position of each school you fished from) with an optional proximity warning for tracked fish
- New: community data shipped with the addon, merged at run time and never overwriting your own data
- Fixed: Expert / Artisan book and quest steps (e.g. Nat Pagle) are no longer shown as trainers
- Fixed: guide skill detection on characters without a main profession; Daryl Riknussun position; Cooked Crab Claw count
- Routes cross-checked on wowhead.com, wow-professions.com and method.gg; every NPC position, vendor and quest checked against more than one source

# FarmAtlas 1.3.0

- Fixed: learning works with auto loot (gathered and looted items were often not recorded before)
- New: Mining and Herbalism - every ore and herb with its zones and required skill
- New: exact herb / ore positions read at run time from Questie or GatherMate2 when installed (local only, nothing copied or sent)
- New: fishing places on the water itself, one per lake / river / coast; tooltip lists what you can catch there and the skill needed
- New: small icons where you gathered (map + minimap); options for icon size and auto-hide when you are close
- Removed: the area blobs drawn from a few loots (they were more confusing than helpful)
- New: Leatherworking 1-300 guide with all trainers and pattern vendors at exact positions
- New: left-side menu (Atlas, Recipes, Guides, Tracked)
- Fixed: two fishing trainer positions; guide markers no longer land on dry land
- Everything in English, Hungarian, French, German and Spanish

# FarmAtlas 1.2.1

- New: every meat, leather, scale and fish lists all the zones where it can be farmed - 746 new farm areas in 410 more zones, with mobs, levels and drop chances (compiled from public WoW Classic drop and fishing data); 3 new fish: Raw Slitherskin Mackerel, Raw Sagefish, Raw Greater Sagefish
- Fixed: the minimap button could disappear when a minimap button collector (e.g. OneForAll) and a minimap skin that groups buttons (e.g. EllesmereUI Minimap) were used together; FarmAtlas now makes sure it shows in the collector bar
- New: FarmAtlas in the game's addon compartment menu next to the minimap (left-click: open, Shift: goals, right-click: map pins)

# FarmAtlas 1.2.0

- New: French, German and Spanish interface (header language menu, settings, /farm lang fr|de|es); starts in the game client's language. On non-English clients item, recipe and zone names follow the game, and recipes are recognised by the item they make
- Fixed: accented letters in upper-case labels (e.g. profession headers) and Hungarian guide notes
- New: Guide tab - Cooking, Fishing and Skinning 1-300 for WoW Forever, faction-aware, with your current step highlighted
- Trainers of your current guide step marked on the world map and minimap automatically
- Town alert: a movable, resizable banner when you arrive at a town / village / camp with a trainer you switched on, plus map and minimap marks (marks only right after login); /farm banner
- Every trainer of a profession on the world map on demand (right-click the Guide header or /farm trainers), exact WoW Forever coordinates, faction-filtered
- Farm areas follow the real shape of the spots (from recorded loot, yours + shared + community) on the world map and minimap, instead of circles
- Auction house prices (optional: Auctionator / TSM / AHSnipe) on item and mob tooltips, last known price as fallback
- Farm / hour on tooltips in gold (value looted in the last 60 minutes; vendor price when no AH price is known) and the value of what you own (bags, bank, alts)
- Settings window: gear button in the atlas header or /farm config
- Recipes tab: all 123 WoW Forever cooking recipes; unknown ones get a red veil but the full recipe is readable on hover: the game's own item tooltip (exact Use: text), skill colors, reagents, fire / oven, where to learn
- Materials listed in leveling order with the level / fishing skill on each row
- Click a known recipe to open the profession window on it; click an unknown one to see where to buy / learn it (with a map marker)
- "On me" list filter: only items in your bags; on the Recipes tab "Craftable now"
- Price addons can plug in with FarmAtlas_AddPriceSource()
- New: "What's new" window after each update (/farm news)
- Stability hardening against the new client restrictions (minimap, sync, recipe scanning)
- Fixed: farm goals window layout with large goals (count no longer overlaps the goal box)

# FarmAtlas 1.1.1

- Fixed: Lua error on mob tooltips ("Secret values are only allowed during untainted execution") in combat / restricted situations
- Tooltip, kill counting and loot learning now skip restricted (secret) values safely

# FarmAtlas 1.1.0

Faction-aware recipe sources.

- Recipe sellers added for 45+ vendor Cooking recipes (WoW Forever vendors)
- FarmAtlas knows your faction: it never sends you to a vendor of the other faction
- Neutral-town vendors (Booty Bay, Gadgetzan, Steamwheedle Port, Everlook, Ratchet) are marked "both factions"
- If only the other faction can buy a recipe, FarmAtlas tells you to check the Auction House
- Recipes tab tooltip shows where to learn a recipe you don't know yet
- Recipe vendors you discover are shared in the background with party / raid / guild (faction-filtered on arrival)
- Fixed: "Spotted Yellowtail" recipe name

# FarmAtlas 1.0.0

First public release for WoW Forever.

- Farm atlas: 100+ cooking meats, leathers, scales and fish with farm areas, mobs, levels and drop chances
- Translucent quest-style farm areas on the world map
- Minimap: farm area circles, edge direction icons, glow while you stand in a farm area
- Recipes tab: recipes you know, filter by ingredient, how many you can make now
- Farm goals with progress bar and notification
- Bags / bank / alts counts in tooltips and the atlas
- Learns loot spots and real drop rates while you play
- Background sharing with party / raid / guild (no buttons)
- Alt + click any item to open it in FarmAtlas
- English and Hungarian interface (item names always English)
