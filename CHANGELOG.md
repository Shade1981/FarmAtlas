# FarmAtlas 1.1.2

- Hardening for the new client restrictions: minimap pins, addon sync and recipe scanning can no longer show Lua error popups in instances or combat
- Minimap facing value is checked before use

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
