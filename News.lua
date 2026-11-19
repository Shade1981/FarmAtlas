-- FarmAtlas - "What's new" window
-- Shown once after every update when you enter the world. OK or X closes it,
-- and it stays closed until the next version. /farm news opens it again.
local _, ns = ...

-- newest first; hu texts may use ő/ű (fixed below for the WoW font)
local HISTORY = {
    { v = "1.4.0", date = "2026-11-19",
      en = {
        "New: Best farm now (button at the top, /farm best) - what earns the most gold per hour for your skills and level. Prices from AH Snipe's 14-day history (or Auctionator / TSM), items per hour measured from your own farming.",
        "Fixed: remembered auction prices are now kept per realm and faction (they could mix between characters). With AH Snipe 3 its realm- and faction-aware prices are used directly.",
        "New: Mining 1-300 and Herbalism 1-300 guides - which ores / herbs to gather at each skill, the best zones for your faction (the map marks only those nodes), and every trainer (junior trainers only to 75).",
        "New: Tailoring 1-300 guide - every trainer with the rank they teach, the Artisan trainers, and the pattern vendors (Qia, Pexmit) at their exact positions.",
        "Fixed: clicking a known recipe now opens every profession window (e.g. Alchemy, First Aid) and selects the recipe - before, only Cooking opened.",
      },
      hu = {
        "Új: Legjobb farm most (gomb fent, /farm best) - mi hozza a legtöbb aranyat óránként a skilljeiddel és a szinteddel. Árak az AH Snipe 14 napos előzményéből (vagy Auctionator / TSM), a darab/óra a saját farmolásodból mérve.",
        "Javítva: a megjegyzett aukciós árak most realmenként és frakciónként külön tárolódnak (eddig keveredhettek a karakterek között). AH Snipe 3-mal annak realm- és frakció-szerinti árait használja közvetlenül.",
        "Új: Bányászat 1-300 és Gyógynövénygyűjtés 1-300 útmutató - milyen ércet / növényt gyűjts az adott skillnél, a frakciódnak legjobb zónák (a térkép csak azokat jelöli), és minden tréner (a junior trénerek csak 75-ig).",
        "Új: Szabászat 1-300 útmutató - minden tréner a tanított ranggal, az Artisan trénerek és a mintaárusok (Qia, Pexmit) pontos helyen.",
        "Javítva: egy ismert receptre kattintva most minden szakma ablaka megnyílik (pl. Alkímia, Elsősegély), és kijelöli a receptet - eddig csak a Főzés nyílt meg.",
      },
      fr = {
        "Nouveau : Meilleur farm maintenant (bouton en haut, /farm best) - ce qui rapporte le plus d'or par heure selon vos compétences et votre niveau. Prix tirés de l'historique de 14 jours d'AH Snipe (ou Auctionator / TSM), objets par heure mesurés sur votre propre farm.",
        "Corrigé : les prix d'enchères mémorisés sont maintenant gardés par royaume et par faction (ils pouvaient se mélanger). Avec AH Snipe 3, ses prix par royaume et faction sont utilisés directement.",
        "Nouveau : guides Minage 1-300 et Herboristerie 1-300 - quels minerais / herbes récolter à chaque niveau, les meilleures zones pour votre faction (la carte ne marque que ceux-là) et tous les maîtres (les maîtres débutants seulement jusqu'à 75).",
        "Nouveau : guide Couture 1-300 - chaque maître avec le rang qu'il enseigne, les maîtres Artisan et les vendeurs de patrons (Qia, Pexmit) à leur position exacte.",
        "Corrigé : cliquer sur une recette connue ouvre maintenant toutes les fenêtres de métier (ex. Alchimie, Secourisme) et sélectionne la recette - avant, seule la Cuisine s'ouvrait.",
      },
      de = {
        "Neu: Beste Farm jetzt (Knopf oben, /farm best) - was dir mit deinen Fertigkeiten und deiner Stufe das meiste Gold pro Stunde bringt. Preise aus dem 14-Tage-Verlauf von AH Snipe (oder Auctionator / TSM), Stück pro Stunde aus deinem eigenen Farmen gemessen.",
        "Behoben: gemerkte Auktionspreise werden jetzt pro Realm und Fraktion gespeichert (sie konnten sich vermischen). Mit AH Snipe 3 werden dessen Preise pro Realm und Fraktion direkt genutzt.",
        "Neu: Leitfäden Bergbau 1-300 und Kräuterkunde 1-300 - welche Erze / Kräuter bei welchem Skill, die besten Zonen für deine Fraktion (die Karte markiert nur diese) und alle Lehrer (Anfängerlehrer nur bis 75).",
        "Neu: Leitfaden Schneiderei 1-300 - jeder Lehrer mit dem Rang, den er lehrt, die Fachmann-Lehrer und die Musterhändler (Qia, Pexmit) an ihrer genauen Position.",
        "Behoben: Ein Klick auf ein bekanntes Rezept öffnet jetzt jedes Berufsfenster (z. B. Alchemie, Erste Hilfe) und wählt das Rezept aus - vorher öffnete sich nur Kochkunst.",
      },
      es = {
        "Nuevo: Mejor farmeo ahora (botón arriba, /farm best) - lo que más oro por hora te da con tus habilidades y tu nivel. Precios del historial de 14 días de AH Snipe (o Auctionator / TSM), objetos por hora medidos de tu propio farmeo.",
        "Corregido: los precios de subasta recordados ahora se guardan por reino y facción (podían mezclarse). Con AH Snipe 3 se usan directamente sus precios por reino y facción.",
        "Nuevo: guías de Minería 1-300 y Herboristería 1-300 - qué minerales / hierbas recoger en cada nivel, las mejores zonas para tu facción (el mapa solo marca esos) y todos los instructores (los júnior solo hasta 75).",
        "Nuevo: guía de Sastrería 1-300 - cada instructor con el rango que enseña, los instructores Artesanos y los vendedores de patrones (Qia, Pexmit) en su posición exacta.",
        "Corregido: al hacer clic en una receta conocida ahora se abre la ventana de cualquier profesión (p. ej. Alquimia, Primeros auxilios) y se selecciona la receta - antes solo se abría Cocina.",
      },
    },
    { v = "1.3.1", date = "2026-11-19",
      en = {
        "New: First Aid 1-300 and Alchemy 1-300 guides - every trainer (only the ones who really teach your next rank), recipe and manual vendors, the Expert book and the Triage quest, all at their exact positions.",
        "New: fishing schools - FarmAtlas remembers where you fished from a school (any fish) and warns you when you come near a school spot of a fish you track. Setting: Settings > Map & minimap.",
        "New: the addon ships with community finds - added to your own data at run time, never replacing it.",
        "Fixed: book and quest steps (Expert / Artisan Cooking and Fishing, e.g. Nat Pagle) no longer look like trainers - they say what to do and which skill you need.",
        "Fixed: the guide could miss Fishing and Cooking on characters without a main profession; a few trainer positions and counts corrected.",
      },
      hu = {
        "Új: Elsősegély 1-300 és Alkímia 1-300 útmutató - minden tréner (csak akik tényleg tanítják a következő rangot), recept- és könyvárusok, az Expert könyv és a Triage küldetés, mind pontos helyen.",
        "Új: halrajok - a FarmAtlas megjegyzi, hol horgásztál rajból (bármilyen hal), és szól, ha egy követett hal rajhelyéhez közel érsz. Beállítás: Beállítások > Térkép és minimap.",
        "Új: az addon közösségi találatokkal érkezik - futás közben adódik hozzá a saját adataidhoz, sosem írja felül őket.",
        "Javítva: a könyves és küldetéses lépések (Expert / Artisan Főzés és Horgászat, pl. Nat Pagle) már nem trénerként jelennek meg - leírják, mit kell tenni és milyen skill kell.",
        "Javítva: fő szakma nélküli karakteren az útmutató nem látta a Horgászatot és Főzést; néhány tréner helye és darabszám pontosítva.",
      },
      fr = {
        "Nouveau : guides Secourisme 1-300 et Alchimie 1-300 - tous les maîtres (seulement ceux qui enseignent vraiment votre rang suivant), vendeurs de recettes et de manuels, le livre Expert et la quête Triage, à leur position exacte.",
        "Nouveau : bancs de poissons - FarmAtlas retient où vous avez pêché dans un banc (tout poisson) et vous avertit quand vous approchez d'un banc d'un poisson suivi. Option : Options > Carte et minicarte.",
        "Nouveau : l'addon inclut les trouvailles de la communauté - ajoutées à vos données en jeu, sans jamais les remplacer.",
        "Corrigé : les étapes livre et quête (Cuisine et Pêche Expert / Artisan, ex. Nat Pagle) ne ressemblent plus à des maîtres - elles disent quoi faire et la compétence requise.",
        "Corrigé : le guide pouvait ignorer Pêche et Cuisine sur un personnage sans métier principal ; quelques positions de maîtres et quantités corrigées.",
      },
      de = {
        "Neu: Leitfäden Erste Hilfe 1-300 und Alchemie 1-300 - alle Lehrer (nur die, die deinen nächsten Rang wirklich lehren), Rezept- und Handbuchhändler, das Expertenbuch und die Quest Triage, alle an ihrer genauen Position.",
        "Neu: Fischschwärme - FarmAtlas merkt sich, wo du aus einem Schwarm geangelt hast (jeder Fisch), und warnt dich in der Nähe eines Schwarmplatzes eines verfolgten Fisches. Einstellung: Einstellungen > Karte & Minikarte.",
        "Neu: Das Addon bringt Funde der Community mit - sie werden im Spiel zu deinen Daten hinzugefügt und ersetzen sie nie.",
        "Behoben: Buch- und Questschritte (Kochkunst und Angeln Experte / Fachmann, z. B. Nat Pagle) sehen nicht mehr wie Lehrer aus - sie sagen, was zu tun ist und welcher Skill nötig ist.",
        "Behoben: Ohne Hauptberuf konnte der Leitfaden Angeln und Kochkunst übersehen; einige Lehrerpositionen und Mengen korrigiert.",
      },
      es = {
        "Nuevo: guías de Primeros auxilios 1-300 y Alquimia 1-300 - todos los instructores (solo los que de verdad enseñan tu siguiente rango), vendedores de recetas y manuales, el libro Experto y la misión Triage, en su posición exacta.",
        "Nuevo: bancos de peces - FarmAtlas recuerda dónde pescaste en un banco (cualquier pez) y te avisa cuando te acercas al banco de un pez que sigues. Opción: Opciones > Mapa y minimapa.",
        "Nuevo: el addon trae hallazgos de la comunidad - se añaden a tus datos en el juego y nunca los reemplazan.",
        "Corregido: los pasos de libro y misión (Cocina y Pesca Experto / Artesano, p. ej. Nat Pagle) ya no parecen instructores - dicen qué hacer y qué habilidad necesitas.",
        "Corregido: la guía podía no ver Pesca y Cocina en personajes sin profesión principal; corregidas algunas posiciones de instructores y cantidades.",
      },
    },
    { v = "1.3.0", date = "2026-11-18",
      en = {
        "Fixed: learning now works with auto loot - before, gathered and looted items were often not recorded. Your finds are learned and shared with your guild again.",
        "New: Mining and Herbalism - every ore and herb with its zones and the skill it needs. With Questie or GatherMate2 installed, every known vein and herb is shown at its exact place (read on your computer, nothing is copied).",
        "New: fishing places sit on the water itself - one marker per lake, river or coast. Hover it: what you can catch there and the skill you need.",
        "New: small item icons where you gathered, on the map and minimap. Settings: icon size, and hide the icon when you are close so you can see the herb or ore under it.",
        "New: Leatherworking 1-300 guide with all trainers and pattern vendors, at their exact positions.",
        "New layout: a menu on the left side of the window - Atlas, Recipes, Guides, Tracked.",
      },
      hu = {
        "Javítva: a tanulás most már auto-loottal is működik - korábban a gyűjtött és lootolt tárgyakat sokszor nem rögzítette. Amit találsz, újra tanulja és megosztja a guilddel.",
        "Új: Bányászat és Gyógynövény - minden érc és növény a zónáival és a szükséges skillel. Ha fent van a Questie vagy a GatherMate2, minden ismert ér és növény a pontos helyén látszik (a gépeden olvassa ki, semmit nem másol).",
        "Új: a horgászhelyek magán a vízen vannak - tavanként, folyónként, partszakaszonként egy jelölő. Ráállva: mi fogható ott és milyen skill kell hozzá.",
        "Új: kis tárgyikonok ott, ahol gyűjtöttél, a térképen és a minimapon. Beállítás: ikonméret, és elrejtés közelről, hogy lásd alatta a növényt vagy ércet.",
        "Új: Bőrművesség 1-300 útmutató az összes trénerrel és mintaárussal, pontos helyükkel.",
        "Új elrendezés: menü az ablak bal oldalán - Atlasz, Receptek, Útmutatók, Követett.",
      },
      fr = {
        "Corrigé : l'apprentissage fonctionne avec le butin automatique - avant, les objets récoltés et ramassés n'étaient souvent pas enregistrés. Vos trouvailles sont à nouveau apprises et partagées avec votre guilde.",
        "Nouveau : Minage et Herboristerie - chaque minerai et herbe avec ses zones et la compétence requise. Avec Questie ou GatherMate2, chaque filon et herbe connu s'affiche à sa place exacte (lu sur votre ordinateur, rien n'est copié).",
        "Nouveau : les lieux de pêche sont sur l'eau - un repère par lac, rivière ou côte. Survolez-le : ce que vous pouvez y pêcher et la compétence requise.",
        "Nouveau : petites icônes là où vous avez récolté, sur la carte et la minicarte. Options : taille des icônes, et masquage de près pour voir l'herbe ou le minerai dessous.",
        "Nouveau : guide Travail du cuir 1-300 avec tous les maîtres et vendeurs de patrons, à leur position exacte.",
        "Nouvelle disposition : un menu sur le côté gauche de la fenêtre - Atlas, Recettes, Guides, Suivis.",
      },
      de = {
        "Behoben: das Lernen funktioniert jetzt mit automatischem Plündern - vorher wurden gesammelte und geplünderte Gegenstände oft nicht erfasst. Deine Funde werden wieder gelernt und mit deiner Gilde geteilt.",
        "Neu: Bergbau und Kräuterkunde - jedes Erz und Kraut mit seinen Gebieten und der nötigen Fertigkeit. Mit Questie oder GatherMate2 wird jedes bekannte Vorkommen an seinem genauen Ort gezeigt (auf deinem Computer gelesen, nichts wird kopiert).",
        "Neu: Angelplätze liegen auf dem Wasser - eine Markierung pro See, Fluss oder Küste. Maus darüber: was du dort fängst und welche Fertigkeit nötig ist.",
        "Neu: kleine Gegenstandssymbole, wo du gesammelt hast, auf Karte und Minikarte. Einstellungen: Symbolgröße, und Ausblenden aus der Nähe, damit du das Kraut oder Erz darunter siehst.",
        "Neu: Leitfaden Lederverarbeitung 1-300 mit allen Lehrern und Musterhändlern an ihrer genauen Position.",
        "Neues Layout: ein Menü an der linken Fensterseite - Atlas, Rezepte, Leitfäden, Verfolgt.",
      },
      es = {
        "Corregido: el aprendizaje funciona con el botín automático - antes los objetos recogidos y saqueados a menudo no se registraban. Lo que encuentras se vuelve a aprender y a compartir con tu hermandad.",
        "Nuevo: Minería y Herboristería - cada mineral y hierba con sus zonas y la habilidad necesaria. Con Questie o GatherMate2, cada filón y hierba conocido se muestra en su lugar exacto (leído en tu ordenador, no se copia nada).",
        "Nuevo: los lugares de pesca están sobre el agua - un marcador por lago, río o costa. Pasa el ratón: qué puedes pescar allí y la habilidad necesaria.",
        "Nuevo: pequeños iconos donde has recogido, en el mapa y el minimapa. Opciones: tamaño del icono y ocultarlo de cerca para ver la hierba o el mineral debajo.",
        "Nuevo: guía de Peletería 1-300 con todos los instructores y vendedores de patrones en su posición exacta.",
        "Nuevo diseño: un menú en el lado izquierdo de la ventana - Atlas, Recetas, Guías, Seguidos.",
      },
    },
    { v = "1.2.1", date = "2026-11-17",
      en = {
        "Every farm spot: each meat, leather, scale and fish now lists all the zones where it can be farmed (746 new areas in 410 more zones), with mobs, levels and drop chances - and 3 new fish: Slitherskin Mackerel, Sagefish, Greater Sagefish.",
        "The minimap button no longer disappears when two minimap addons are used together (e.g. a button collector bar plus a minimap skin that groups buttons): FarmAtlas makes sure it shows in the collector bar.",
        "FarmAtlas is also in the game's addon menu next to the minimap: always reachable, even if another addon hides the button.",
      },
      hu = {
        "Minden farmhely: minden hús, bőr, pikkely és hal az összes zónát mutatja, ahol farmolható (746 új terület, 410 új zónában), mobokkal, szintekkel, esési eséllyel - és 3 új hal: Slitherskin Mackerel, Sagefish, Greater Sagefish.",
        "A minimap gomb nem tűnik el, ha két minimap addon fut együtt (pl. egy gombgyűjtő sáv és egy gombokat csoportosító minimap skin): a FarmAtlas gondoskodik róla, hogy a gyűjtő sávban látszódjon.",
        "A FarmAtlas a játék minimap melletti addon menüjében is megjelenik: mindig elérhető, akkor is, ha egy másik addon elrejti a gombot.",
      },
      fr = {
        "Tous les lieux de farm : chaque viande, cuir, écaille et poisson indique maintenant toutes les zones où le farmer (746 nouvelles zones de farm dans 410 zones de plus), avec monstres, niveaux et chances de butin - et 3 nouveaux poissons : Slitherskin Mackerel, Sagefish, Greater Sagefish.",
        "Le bouton de la minicarte ne disparaît plus quand deux addons de minicarte sont utilisés ensemble (une barre qui regroupe les boutons et un skin de minicarte qui les range) : FarmAtlas s'assure qu'il apparaît dans la barre.",
        "FarmAtlas est aussi dans le menu des addons du jeu à côté de la minicarte : toujours accessible, même si un autre addon cache le bouton.",
      },
      de = {
        "Alle Farmorte: jedes Fleisch, Leder, jede Schuppe und jeder Fisch zeigt jetzt alle Zonen, in denen man es farmen kann (746 neue Gebiete in 410 weiteren Zonen), mit Gegnern, Stufen und Beutechancen - und 3 neue Fische: Slitherskin Mackerel, Sagefish, Greater Sagefish.",
        "Der Minikarten-Knopf verschwindet nicht mehr, wenn zwei Minikarten-Addons zusammen laufen (eine Knopf-Sammelleiste und ein Minikarten-Skin, der Knöpfe gruppiert): FarmAtlas sorgt dafür, dass er in der Sammelleiste erscheint.",
        "FarmAtlas steht auch im Addon-Menü des Spiels neben der Minikarte: immer erreichbar, auch wenn ein anderes Addon den Knopf versteckt.",
      },
      es = {
        "Todos los lugares de farmeo: cada carne, cuero, escama y pescado muestra ahora todas las zonas donde farmearlo (746 áreas nuevas en 410 zonas más), con enemigos, niveles y probabilidades de botín - y 3 peces nuevos: Slitherskin Mackerel, Sagefish, Greater Sagefish.",
        "El botón del minimapa ya no desaparece cuando se usan dos addons de minimapa a la vez (una barra que recoge botones y un skin de minimapa que los agrupa): FarmAtlas se asegura de que aparezca en la barra.",
        "FarmAtlas también está en el menú de addons del juego junto al minimapa: siempre accesible, aunque otro addon oculte el botón.",
      } },
    { v = "1.2.0", date = "2026-11-17",
      en = {
        "New: French, German and Spanish interface (Language in the settings, or /farm lang fr|de|es). On a French, German or Spanish game client it starts in that language, and item, recipe and zone names are shown the way your game names them (the English names still work in the search).",
        "New: Guide tab - Cooking, Fishing and Skinning 1-300 for WoW Forever, each on its own sub-tab. It shows where you are now, what to make or where to go next, and the trainers of your faction.",
        "Fishing / skinning steps: the places to do them are highlighted in gold on the world map - for the step you are on automatically, and for any step you click.",
        "Cooking steps: a click tracks the material and opens the map where to farm it.",
        "The trainers of your current guide step are marked on the world map and the minimap automatically.",
        "Town alert: when you arrive at a town, village or camp with a trainer of a profession you switched on, a banner names them and they are marked on the map and minimap. Move / resize the banner with /farm banner. Right after login you only get the marks.",
        "Every trainer of a profession on the world map: right-click the profession header in the Guide tab, or /farm trainers. Exact WoW Forever coordinates.",
        "Farm areas follow the real shape of the spots: once enough loot is recorded in a zone (yours, your group's, the community's), the circle is replaced by the area where the mobs and fish really are - on the world map and the minimap.",
        "New: auction house prices from Auctionator, TSM or AHSnipe (optional) on item and mob tooltips - the last known price when none of them is open.",
        "Farm / hour on tooltips in gold: what you really looted in the last 60 minutes and what it is worth (N/A until the first loot), plus the value of what you own (bags, bank, alts). With no AH price it uses the vendor price.",
        "New: Settings window - the gear button in the atlas header or /farm config. Every switch, grouped by topic.",
        "Recipes tab: all 123 WoW Forever cooking recipes. The ones you don't know yet have a red veil, but the whole recipe is readable on hover: the game's own item tooltip with the exact Use: text, skill colors, reagents with what you have, fire / Iron Oven, where to learn it.",
        "Meat, leather, scales and fish are listed in leveling order (lowest level first), with the level / fishing skill on every row.",
        "Click a recipe you know: the profession window opens on it, ready to craft. Click one you don't know: a box tells you that you can't make it yet and where to buy or learn it, with the place on the map.",
        "New \"On me\" button above the list: only the items in your bags. On the Recipes tab it becomes \"Craftable now\": only the recipes you have every ingredient for.",
        "Other price addons can plug in with FarmAtlas_AddPriceSource().",
        "New: this \"What's new\" window - after every update you see the changes once.",
        "Stability: tooltips, minimap pins, loot learning, kill counting, recipe scanning and sync are protected against the new client restrictions (no more Lua error popups in combat or instances).",
      },
      hu = {
        "Új: francia, német és spanyol felület (Nyelv a beállításokban, vagy /farm lang fr|de|es). Francia, német vagy spanyol játékkliensen magától azon a nyelven indul, és a tárgyak, receptek, zónák neve úgy jelenik meg, ahogy a játékod nevezi őket (az angol nevekkel is lehet keresni).",
        "Új: Útmutató fül - Főzés, Horgászat és Nyúzás 1-300 WoW Foreverre, mindegyik külön alfülön. Megmutatja, hol tartasz, mit készíts vagy hova menj, és a frakciód trénereit.",
        "Horgász- és nyúzólépések: a helyek arannyal kiemelve a világtérképen - az aktuális lépésnél magától, bármelyik lépésnél kattintásra.",
        "Főzőlépések: kattintásra követi az alapanyagot, és megnyitja a térképet ott, ahol farmolható.",
        "Az útmutató aktuális lépésének trénerei automatikusan megjelennek a világtérképen és a minimapen.",
        "Település-jelzés: ha olyan városba, faluba vagy campbe érsz, ahol egy általad bekapcsolt szakma trénere van, egy felirat kiírja a nevüket, és megjelöli őket a térképen és a minimapen. A feliratot a /farm banner paranccsal mozgathatod és méretezheted. Belépés után csak a jelölés látszik.",
        "Egy szakma összes trénere a világtérképen: jobb klikk a szakma fejlécén az Útmutató fülön, vagy /farm trainers. Pontos WoW Forever koordináták.",
        "A farmterületek a valódi alakot követik: ha egy zónában elég loot gyűlt össze (a tiéd, a csapatodé, a közösségé), a kör helyett az a terület látszik, ahol a mobok és halak tényleg vannak - a világtérképen és a minimapen is.",
        "Új: aukciósházi árak az Auctionatorból, TSM-ből vagy AHSnipe-ból (nem kötelező) a tárgyak és mobok tooltipjén - ha egyik sincs nyitva, az utolsó ismert ár.",
        "Farm / óra a tooltipeken aranyban: amit az elmúlt 60 percben ténylegesen lootoltál, és mennyit ér (az első lootig N/A), plusz a birtokolt mennyiség értéke (táska, bank, altok). Ha nincs AH ár, a vendor árral számol.",
        "Új: Beállítások ablak - fogaskerék gomb az atlasz fejlécében vagy /farm config. Minden kapcsoló, témák szerint csoportosítva.",
        "Receptek fül: mind a 123 WoW Forever főzőrecept. A még nem ismertek piros fedést kapnak, de a teljes recept olvasható, ha fölé viszed az egeret: a játék saját tárgy-tooltipje a pontos Use: szöveggel, szintszínek, alapanyagok a nálad lévő mennyiséggel, tűz / Iron Oven, hol tanulható.",
        "A húsok, bőrök, pikkelyek és halak szintsorrendben jelennek meg (a legalacsonyabb elöl), minden sorban a szinttel / horgász skill-lel.",
        "Kattints egy ismert receptre: megnyílik a szakma ablak ennél a receptnél, egyből elkészítheted. Ismeretlen receptre kattintva egy ablak kiírja, hogy még nem tudod elkészíteni, és hol veheted meg vagy tanulhatod meg - a helyet a térképen is megmutatja.",
        "Új \"Nálam\" gomb a lista fölött: csak a táskádban lévő tárgyak. A Receptek fülön \"Most elkészíthető\": csak azok a receptek, amelyekhez minden alapanyag nálad van.",
        "Más ár-addonok is bekapcsolódhatnak a FarmAtlas_AddPriceSource() függvénnyel.",
        "Új: ez a frissítési ablak - minden frissítés után egyszer megmutatja az újdonságokat.",
        "Stabilitás: a tooltip, a minimap-jelölők, a loot-tanulás, a kill-számlálás, a recept-figyelés és a szinkron védett az új kliens korlátozásaival szemben (nincs több Lua-hibaablak harcban vagy instance-ban).",
      },
      fr = {
        "Nouveau : interface en français, allemand et espagnol (Langue dans les options, ou /farm lang fr|de|es). Sur un client français, allemand ou espagnol, elle démarre dans cette langue, et les noms des objets, recettes et zones sont affichés comme dans votre jeu (les noms anglais marchent toujours dans la recherche).",
        "Nouveau : onglet Guide - Cuisine, Pêche et Dépeçage 1-300 pour WoW Forever, chacun dans son sous-onglet. Il montre où vous en êtes, quoi fabriquer ou où aller ensuite, et les maîtres de votre faction.",
        "Étapes de pêche / dépeçage : les lieux sont surlignés en doré sur la carte du monde - automatiquement pour l'étape en cours, et pour toute étape cliquée.",
        "Étapes de cuisine : un clic suit le composant et ouvre la carte là où le farmer.",
        "Les maîtres de l'étape en cours sont marqués automatiquement sur la carte du monde et la minicarte.",
        "Alerte de ville : quand vous arrivez dans une ville, un village ou un camp avec un maître d'un métier que vous avez activé, une bannière affiche son nom et il est marqué sur la carte et la minicarte. Déplacez / redimensionnez la bannière avec /farm banner. Juste après la connexion, seulement les marqueurs.",
        "Tous les maîtres d'un métier sur la carte du monde : clic droit sur l'en-tête du métier dans l'onglet Guide, ou /farm trainers. Coordonnées exactes de WoW Forever.",
        "Les zones de farm suivent la vraie forme des lieux : dès qu'assez de butin est enregistré dans une zone (le vôtre, celui du groupe, de la communauté), le cercle est remplacé par la zone où sont vraiment les monstres et les poissons - sur la carte du monde et la minicarte.",
        "Nouveau : prix de l'hôtel des ventes depuis Auctionator, TSM ou AHSnipe (facultatif) dans les infobulles des objets et des monstres - le dernier prix connu si aucun n'est ouvert.",
        "Farm / heure en or dans les infobulles : ce que vous avez vraiment ramassé ces 60 dernières minutes et sa valeur (N/A jusqu'au premier butin), plus la valeur de ce que vous possédez (sacs, banque, rerolls). Sans prix HV, le prix marchand est utilisé.",
        "Nouveau : fenêtre d'options - le bouton engrenage dans l'en-tête de l'atlas ou /farm config. Tous les réglages, rangés par thème.",
        "Onglet Recettes : les 123 recettes de cuisine de WoW Forever. Celles que vous ne connaissez pas ont un voile rouge, mais toute la recette se lit au survol : l'infobulle de l'objet du jeu avec le texte Utiliser exact, couleurs de compétence, composants avec ce que vous avez, feu / four en fer, où l'apprendre.",
        "Viandes, cuirs, écailles et poissons sont listés dans l'ordre de progression (le niveau le plus bas d'abord), avec le niveau / la compétence de pêche sur chaque ligne.",
        "Cliquez sur une recette connue : la fenêtre du métier s'ouvre dessus, prête à fabriquer. Cliquez sur une recette inconnue : une fenêtre indique que vous ne pouvez pas encore la préparer et où l'acheter ou l'apprendre, avec le lieu sur la carte.",
        "Nouveau bouton \"Dans mes sacs\" au-dessus de la liste : seulement les objets de vos sacs. Dans l'onglet Recettes il devient \"Faisable maintenant\" : seulement les recettes dont vous avez tous les ingrédients.",
        "D'autres addons de prix peuvent se brancher avec FarmAtlas_AddPriceSource().",
        "Nouveau : cette fenêtre \"Nouveautés\" - après chaque mise à jour, vous voyez les changements une fois.",
        "Stabilité : infobulles, marqueurs de la minicarte, apprentissage du butin, comptage des victimes, lecture des recettes et synchro sont protégés contre les nouvelles restrictions du client (plus de fenêtres d'erreur Lua en combat ou en instance).",
      },
      de = {
        "Neu: französische, deutsche und spanische Oberfläche (Sprache in den Einstellungen oder /farm lang fr|de|es). Auf einem französischen, deutschen oder spanischen Spielclient startet sie in dieser Sprache, und Namen von Gegenständen, Rezepten und Zonen erscheinen so, wie dein Spiel sie nennt (englische Namen funktionieren in der Suche weiterhin).",
        "Neu: Leitfaden-Reiter - Kochkunst, Angeln und Kürschnerei 1-300 für WoW Forever, jeweils in einem eigenen Unterreiter. Er zeigt, wo du gerade stehst, was du als Nächstes herstellst oder wohin du gehst, und die Lehrer deiner Fraktion.",
        "Angel- / Kürschnerschritte: die Orte sind auf der Weltkarte golden markiert - automatisch für deinen aktuellen Schritt und für jeden angeklickten Schritt.",
        "Kochschritte: ein Klick verfolgt das Material und öffnet die Karte dort, wo man es farmt.",
        "Die Lehrer deines aktuellen Leitfaden-Schritts werden automatisch auf der Weltkarte und der Minikarte markiert.",
        "Ortshinweis: wenn du in einer Stadt, einem Dorf oder Lager mit einem Lehrer eines eingeschalteten Berufs ankommst, nennt ihn ein Banner, und er wird auf Karte und Minikarte markiert. Verschieben / Größe ändern mit /farm banner. Direkt nach dem Einloggen gibt es nur die Marker.",
        "Alle Lehrer eines Berufs auf der Weltkarte: Rechtsklick auf den Berufskopf im Leitfaden-Reiter oder /farm trainers. Genaue WoW-Forever-Koordinaten.",
        "Farmgebiete folgen der echten Form der Orte: sobald genug Beute in einer Zone gespeichert ist (deine, die deiner Gruppe, der Community), ersetzt das Gebiet, wo die Gegner und Fische wirklich sind, den Kreis - auf Weltkarte und Minikarte.",
        "Neu: Auktionshauspreise aus Auctionator, TSM oder AHSnipe (optional) in Gegenstands- und Gegner-Tooltips - der letzte bekannte Preis, wenn keins davon offen ist.",
        "Farm / Stunde in Gold in den Tooltips: was du in den letzten 60 Minuten wirklich geplündert hast und was es wert ist (N/A bis zur ersten Beute), dazu der Wert deines Besitzes (Taschen, Bank, Twinks). Ohne AH-Preis wird der Händlerpreis verwendet.",
        "Neu: Einstellungsfenster - der Zahnrad-Knopf im Atlas-Kopf oder /farm config. Alle Schalter, nach Themen geordnet.",
        "Rezepte-Reiter: alle 123 Kochrezepte von WoW Forever. Unbekannte haben einen roten Schleier, aber das ganze Rezept ist beim Überfahren lesbar: der Gegenstands-Tooltip des Spiels mit dem genauen Benutzen-Text, Fertigkeitsfarben, Zutaten mit deinem Bestand, Feuer / Eisenofen, wo man es lernt.",
        "Fleisch, Leder, Schuppen und Fische sind in Leveling-Reihenfolge aufgelistet (niedrigste Stufe zuerst), mit Stufe / Angelfertigkeit in jeder Zeile.",
        "Klick auf ein bekanntes Rezept: das Berufsfenster öffnet sich dort, bereit zum Herstellen. Klick auf ein unbekanntes: ein Fenster sagt, dass du es noch nicht herstellen kannst und wo du es kaufst oder lernst, mit dem Ort auf der Karte.",
        "Neuer Knopf \"In den Taschen\" über der Liste: nur Gegenstände in deinen Taschen. Im Rezepte-Reiter wird er zu \"Jetzt herstellbar\": nur Rezepte, für die du alle Zutaten hast.",
        "Andere Preis-Addons können sich mit FarmAtlas_AddPriceSource() einklinken.",
        "Neu: dieses \"Neuigkeiten\"-Fenster - nach jedem Update siehst du die Änderungen einmal.",
        "Stabilität: Tooltips, Minikarten-Marker, Beute-Lernen, Tötungszählung, Rezept-Lesen und Sync sind gegen die neuen Client-Einschränkungen geschützt (keine Lua-Fehlerfenster mehr im Kampf oder in Instanzen).",
      },
      es = {
        "Nuevo: interfaz en francés, alemán y español (Idioma en las opciones, o /farm lang fr|de|es). En un cliente francés, alemán o español empieza en ese idioma, y los nombres de objetos, recetas y zonas se muestran como los llama tu juego (los nombres en inglés siguen funcionando en la búsqueda).",
        "Nuevo: pestaña Guía - Cocina, Pesca y Desuello 1-300 para WoW Forever, cada una en su subpestaña. Muestra dónde estás, qué crear o adónde ir después, y los instructores de tu facción.",
        "Pasos de pesca / desuello: los lugares se resaltan en dorado en el mapa del mundo - automáticamente para tu paso actual, y para cualquier paso que pulses.",
        "Pasos de cocina: un clic sigue el material y abre el mapa donde farmearlo.",
        "Los instructores de tu paso actual de la guía se marcan automáticamente en el mapa del mundo y el minimapa.",
        "Aviso de ciudad: al llegar a una ciudad, pueblo o campamento con un instructor de una profesión que activaste, un cartel lo nombra y se marca en el mapa y el minimapa. Mueve / cambia el tamaño del cartel con /farm banner. Justo después de entrar solo aparecen las marcas.",
        "Todos los instructores de una profesión en el mapa del mundo: clic derecho en la cabecera de la profesión en la pestaña Guía, o /farm trainers. Coordenadas exactas de WoW Forever.",
        "Las zonas de farmeo siguen la forma real de los lugares: en cuanto hay suficiente botín registrado en una zona (el tuyo, el de tu grupo, el de la comunidad), el círculo se sustituye por el área donde están de verdad los enemigos y los peces - en el mapa del mundo y el minimapa.",
        "Nuevo: precios de la casa de subastas de Auctionator, TSM o AHSnipe (opcional) en los tooltips de objetos y enemigos - el último precio conocido si ninguno está abierto.",
        "Farmeo / hora en oro en los tooltips: lo que despojaste de verdad en los últimos 60 minutos y cuánto vale (N/A hasta el primer botín), más el valor de lo que tienes (bolsas, banco, alters). Sin precio de subasta se usa el precio de vendedor.",
        "Nuevo: ventana de opciones - el botón del engranaje en la cabecera del atlas o /farm config. Todos los ajustes, agrupados por tema.",
        "Pestaña Recetas: las 123 recetas de cocina de WoW Forever. Las que aún no conoces tienen un velo rojo, pero toda la receta se puede leer al pasar el ratón: el tooltip del objeto del propio juego con el texto Uso exacto, colores de habilidad, ingredientes con lo que tienes, fuego / horno de hierro, dónde aprenderla.",
        "Carnes, cueros, escamas y peces aparecen en orden de subida (el nivel más bajo primero), con el nivel / la habilidad de pesca en cada fila.",
        "Haz clic en una receta conocida: la ventana de la profesión se abre en ella, lista para crear. Haz clic en una desconocida: una ventana te dice que aún no puedes prepararla y dónde comprarla o aprenderla, con el lugar en el mapa.",
        "Nuevo botón \"En mis bolsas\" encima de la lista: solo los objetos de tus bolsas. En la pestaña Recetas se convierte en \"Se puede hacer ya\": solo las recetas para las que tienes todos los ingredientes.",
        "Otros addons de precios pueden conectarse con FarmAtlas_AddPriceSource().",
        "Nuevo: esta ventana de \"Novedades\" - tras cada actualización ves los cambios una vez.",
        "Estabilidad: tooltips, marcas del minimapa, aprendizaje del botín, recuento de muertes, lectura de recetas y sincronización están protegidos frente a las nuevas restricciones del cliente (no más ventanas de error de Lua en combate o en instancias).",
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
    fr = { title = "Nouveautés", ok = "OK", hint = "Tapez /farm news pour rouvrir cette fenêtre." },
    de = { title = "Neuigkeiten", ok = "OK", hint = "Mit /farm news öffnest du dieses Fenster erneut." },
    es = { title = "Novedades", ok = "OK", hint = "Escribe /farm news para volver a abrir esta ventana." },
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
    if ns.db.settings.newsPopup == false then ns.db.newsSeen = ns.version; return end
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
