# Onderzoek: HUD en menu's

1 oktober 2026. Aanleiding: M2 vraagt een "eigen stijl voor menu's en HUD, instellingen" (GDD §M2). Wat afgeleid is en niet uit een bron komt, staat als *[afgeleid]*. Wat ik niet kon nakijken, staat als *(niet geverifieerd)*.

Bronnen die niet bereikbaar waren (403 of betaalmuur) en dus **niet** gebruikt zijn: Game UI Database ([DRG-pagina](https://gameuidatabase.com/gameData.php?id=400)), ArtStation van DRG-UI-artiest Kenneth Faigh, de PC Gamer-review van PEAK, GameSpot en Semantic Scholar. Screenshots heb ik niet zelf bekeken: posities komen uit wiki's die het scherm beschrijven.

---

## 1. Kader: welke soort UI, en wanneer

- **Vier soorten** (Fagerholt & Lorentzon, *Beyond the HUD*, Chalmers/DICE 2009). Twee assen: zit het in de fictie, en zit het in de 3D-ruimte? *Diegetisch* = beide (scherm in de wereld). *Niet-diegetisch* = geen van beide (klassieke HUD). *Ruimtelijk* = in 3D maar niet in de fictie (outline, markering boven een object). *Meta* = in de fictie maar plat op het scherm (barsten in een vizier, bloed aan de rand). [overzicht](https://nastyrodent.com/diegetic-and-non-diegetic-ui/) · [thesis](https://www.scirp.org/reference/referencespapers?referenceid=1986513)
- **Diegetisch is niet automatisch beter.** Llanos & Jørgensen (DiGRA 2011): geen vast verband tussen "onzichtbare" UI en betrokkenheid; spelers verkiezen vaak een overlay omdat die duidelijker is. [DiGRA](https://dl.digra.org/index.php/dl/article/view/514)
- Iacovides e.a. (CHI PLAY 2015): de HUD weghalen verhoogde de immersie **enkel bij ervaren spelers**. [UCL](https://discovery.ucl.ac.uk/id/eprint/1470398/)
- Peacocke e.a. (2018, 4 experimenten): **gezondheid** las men best van een HUD. **Munitie** las men best als getal op het wapen zelf (35% minder schoten voor herladen). **Navigatie** ging best met een lijn in de wereld; een minimap kwam dichtbij. Conclusie: de eigenschappen en de plaats van een display tellen, niet de categorie. [York](https://www.yorku.ca/mack/ec2018.html)
- Marcus Andrews (DICE, 2010): "functionality preservation" eerst. Far Cry 2 moest voor zijn diegetische kaart toch HUD-elementen als vangnet houden. [Game Developer](https://www.gamedeveloper.com/design/game-ui-discoveries-what-players-want)

---

## 2. Per game

### Deep Rock Galactic (belangrijkste referentie)

**HUD** (posities volgens de [officiële wiki](https://deeprockgalactic.wiki.gg/wiki/Heads-up_display)):
- Linksonder: eigen schild en gezondheid onder je naam, met klasse-icoon en rang. Daaronder de teamgenoten (icoon, naam, gezondheidsbalk) en actieve perks.
- Rechtsonder: munitie, granaten en fakkels. De naam van je gereedschap verschijnt enkel bij het wisselen of met de laserpointer in de hand.
- Midden onder: wat je draagt aan grondstoffen, plus statuseffecten en temperatuur (enkel als ze actief zijn).
- Rechtsboven: hoofd- en nevendoel. De **teamopslag** verschijnt enkel als je de laserpointer vasthoudt en kort bij het afgeven van mineralen.
- Boven midden: diepte en kompas (uit te zetten) en berichten van Mission Control.
- Midden: kruisdraad. Cooldowns rechts van het midden.
- **UI Scale** schaalt enkel de missie-HUD.

**Laserpointer = de ping** ([wiki](https://deeprockgalactic.wiki.gg/wiki/Laser_Pointer)): bij het indrukken krijgen teamgenoten en sleutelobjecten even een outline door muren. Op een oppervlak toont hij **afstand en de naam van het materiaal**. Mikken op een grondstof geeft een groene flits en een ping, op een vijand een rode. Markeringen ziet het hele team door muren. Met de pointer in de hand tonen teamgenoten 4 grijze blokjes voor hun munitie.
- Lof: "een ping is duizend woorden waard", werkt zonder voice. [Digital Thriving](https://digitalthrivingplaybook.org/example/overview-of-collaborative-ping-systems/)
- Kritiek: je moet de pointer telkens uitnemen; spelers willen een aparte ping-knop zoals in recentere games. Anderen vinden het net goed zo, want permanente outlines leiden af. [Steam](https://steamcommunity.com/app/548430/discussions/1/601901034049165392/)

**Kaart**: de Terrain Scanner is een 3D-overlay zolang je Tab vasthoudt; je kan dan **niet bewegen**. Teamgenoten zijn pijlen in klassekleur, mineralen gele piramides. [wiki](https://deeprockgalactic.wiki.gg/wiki/Terrain_Scanner)

**Menu en lobby**:
- Startscherm "Press any key", daarna een kort hoofdmenu ([Interface In Game](https://interfaceingame.com/games/deep-rock-galactic/)). "Continue" laadt meteen de Space Rig. Kritiek: het hoofdmenu had geen Exit-knop, je moest eerst de rig inladen. [Steam](https://steamcommunity.com/app/548430/discussions/3/1696040635909090423/)
- **De Space Rig is de lobby.** Een missie kies je aan een terminal voor een hologram. Daarna gaat de drop pod open; de missie start als de host er 15 s in staat (5 s als het hele team erin staat). [wiki](https://deeprockgalactic.wiki.gg/wiki/Space_Rig)
- Wie binnenkomt, kiest eerst klasse en uitrusting en verschijnt in een eigen cabine; tijdens een missie komt hij met een drop pod. Vlak voor de start en in sommige fases kan niemand binnen. De host kiest privé / publiek / wachtwoord, kan dat wisselen in het pauzemenu en kan spelers kicken. Server browser via een "Quick Join"-terminal of Tab in de rig. [wiki](https://deeprockgalactic.wiki.gg/wiki/Multiplayer)

**Instellingen** ([analyse 2021](https://rgm7620.wordpress.com/2021/11/11/video-game-accessibility/)): elk HUD-element op **zichtbaar / uit / dynamisch**, met presets; UI-schaal; UI-animaties uit te zetten; lettergrootte en vervaltijd van de chat; **hoofdbeweging en schermschok als schuifregelaar**, niet enkel aan/uit; volledige herconfiguratie voor toetsenbord én controller; aparte volumes (o.a. Mission Control en voice chat). Toen nog geen kleurenblindmodus. "Dynamisch" toont gezondheid enkel als het nodig is. [Steam](https://steamcommunity.com/app/548430/discussions/3/3814039097895378347/)

**Letters**: de devs noemden **Heavitas** (een zware display-letter) "minstens voor de roadmap" ([devtracker](https://devtrackers.gg/deep-rock-galactic/p/76dde08a-drg-fonts)). In juli 2018 werd de eigen UI-letter vervangen door iets Roboto-achtigs en werd de UI groter. Kritiek: "soulless", te veel tekstverwerker; een verdediger: makkelijk te lezen tussen de zwermen. [Steam](https://steamcommunity.com/app/548430/discussions/1/1729828401687996598/)

### PEAK

**HUD**: in de kern **één uithoudingsbalk**. Honger, verwonding, gewicht, gif, kou, hitte, doornen, slaperigheid en vloek nemen elk een stuk van die balk in, met een eigen icoon. Bonusuithouding staat eronder; boven 100% loopt het buiten de balk met een stippellijn. "Numb" verbergt de balk volledig. [wiki](https://peak.wiki.gg/wiki/Stamina_bar) · [Wikipedia](https://en.wikipedia.org/wiki/Peak_(video_game))
- 3 itemslots (1–3) plus een vaste rugzakslot (4); de rugzak opent een **radiaal menu** met 4 plaatsen. Ping met de middelste muisknop toont een **wijzend handje**; emotewiel op R. [wiki](https://peak.wiki.gg/wiki/How_to_play)
- Letter: **Darumadrop One** (Google Fonts, handgeschreven en rond), voor logo, menu's én toetsprompts. [wiki](https://peak.wiki.gg/wiki/Peak_(game))
- Lof van spelers: één balk waar alles aan knaagt "keeps the UI clean" en is makkelijk te begrijpen. [Steam](https://steamcommunity.com/app/3527290/discussions/0/592900978988064699/)
- Let op: het vaak geciteerde "text is evil" ging over **communicatie in het team** (ruzies op Discord), niet over UI. [Game Developer](https://www.gamedeveloper.com/production/how-co-op-climbing-hit-peak-achieved-2-million-sales-for-less-than-200-000-)

**Menu en lobby**: hoofdmenu met "Host Game" en daaronder "Play Offline" (icoon met één klimmer in plaats van meerdere) ([TheGamer](https://www.thegamer.com/peak-how-to-play-solo-guide-tips-tricks/)). Host Game → je stapt uit een **lift in een luchthaven**. Daar: een uitnodigingskiosk (opent de Steam-vriendenlijst), een gate-kiosk die een boarding pass toont en de expeditie start, een paspoort voor je uiterlijk, een fotohokje, een spiegel en speelgoed (schaak, basket, klimmuur). Geen statuseffecten in de luchthaven. [wiki](https://peak.wiki.gg/wiki/Airport) · [Deltia](https://deltiasgaming.com/how-to-invite-friends-in-peak/) Tijdens het spel: Esc → Invite Friends; wie terugkomt, verschijnt aan het laatste kampvuur. [Game Rant](https://gamerant.com/peak-how-join-invite-friends-mid-game/)

**Instellingen** ([wiki](https://peak.wiki.gg/wiki/Settings)): FOV 60–100 plus **extra FOV tijdens klimmen**; lobbymodus (standaard "Invite Only"); **kamercode verbergen** (standaard aan); keuze van toetsiconen (Auto / gamepad 1 / gamepad 2 / muis en toetsenbord); minder camerabeweging (enkel in het hoofdmenu); fobie-modi; fotosensitiviteit; kleurenblindmodus die **patronen** op bessen zet; microfoon met spraakactivatie / push-to-talk / push-to-mute; 4 volumes.
- Kritiek: bij release **geen toetsen herconfigureren**. Klachten van linkshandigen en **AZERTY**-spelers; de dev: "we hope to add it later" ([Steam](https://steamcommunity.com/app/3527290/discussions/0/592900345012738938/)). Kwam er pas in 1.30.a. Hoofdbeweging gaf misselijkheid; de dev verwees naar de instelling en naar een mod. [Steam](https://steamcommunity.com/app/3527290/discussions/0/592900978988023854/)

### Lethal Company

**HUD** ([wiki](https://lethal.miraheze.org/wiki/HUD)):
- Linksboven: oranje **boog** voor uithouding; je gezondheid is de **dekking van een figuurtje in die boog** (lege omtrek = gezond, bijna vol rood = kritiek); gewicht ernaast; batterij-icoon dat knippert onder 25%.
- **Barsten in het helmvizier** groeien met je verwondingen (meta-UI).
- Boven: klok, enkel buiten; waarschuwingen in tekst ("The autopilot ship will leave at midnight").
- Rechtsboven: toetshints voor wat je vasthoudt. Onder: 4 blauwe slots. De scanner kleurt buit groen, gevaar rood, schip en ingang blauw.
- Prompts verschijnen pas als ze nuttig zijn (bv. aan een ladder). Vormen: cirkels en vierkanten, transparant, geen ornament; blauw/groen voor info, rood/oranje voor alarm. [Indieklem](https://indieklem.com/11-whats-behind-the-interface-of-lethal-company/)
- Letters: **3270font** (naar de IBM 3270-terminal) voor UI en terminal; het logo in Segoe Semi Bold, "glitchy and worn". Door het pixeleffect oogt de letter ruwer. [Fonts In Use](https://fontsinuse.com/uses/68901/lethal-company-video-game)

**Menu en lobby**: bij het opstarten Online of LAN. Hosten: publiek of privé, en een van 3 saves. "Join a crew" toont publieke lobbies. [TheGamer](https://www.thegamer.com/lethal-company-multiplayer-guide/) Het **schip is de lobby**: maanroute kiezen door commando's te typen in de terminal (`moons`, `route`, `confirm`), en de host trekt aan een **hendel** met de hint "Start Game". [Steam](https://steamcommunity.com/app/1966720/discussions/0/4034728757140030928/) · [Game Rant](https://gamerant.com/lethal-company-all-terminal-commands/)

**Kritiek**: geen FOV-schuif (intern vast op 66, omdat sommige wezens reageren op je zichtveld) → klachten over misselijkheid ([Steam](https://steamcommunity.com/app/1966720/discussions/0/3958162152970697277/)). Ook vaste toetsen ([Steam](https://steamcommunity.com/app/1966720/discussions/0/3958162152968484286/)) en **geen kruisdraad**: wie het midden van het scherm niet goed ziet, kan kleine sleutels moeilijk oppakken. [Steam](https://steamcommunity.com/app/1966720/discussions/0/4141690481119171882/)

### R.E.P.O.

- Rechtsboven: quota en aantal extractiepunten. Gezondheid hangt als **groene meter op de rug** van elke robot, en teamgenoten kunnen er per 10 punten van doorgeven. Tab opent een kaart (buit geel, kapotte robots rood, stippellijn naar het actieve extractiepunt). [Steam-gids](https://steamcommunity.com/sharedfiles/filedetails/?id=3543163806)
- De **kar telt zelf**: een schermpje aan de handgreep toont de totale waarde van wat erin ligt ([wiki](https://repogame.fandom.com/wiki/C.A.R.T.) · [GamesRadar](https://www.gamesradar.com/games/horror/how-to-play-repo/), enkel via zoekfragmenten gelezen). Buit die je beschadigt, verliest waarde. [Wikipedia](https://en.wikipedia.org/wiki/R.E.P.O.)
- Menu: Host Game → melding over een goede internetverbinding → lobbymenu met Invite (Steam-overlay), kleur kiezen en Start. Je hervat door dezelfde save opnieuw te hosten. [Game Rant](https://gamerant.com/repo-how-play-online-friends/) Eerst geen publieke lobbies (de devs vreesden hackers). [GamerBlurb](https://gamerblurb.com/articles/repo-public-lobbies-explained) Latere "Find Match" en lobbywachtwoorden: *(niet geverifieerd welke versie)*.

### Astroneer

- Zo goed als geen HUD: zuurstof (horizontaal, lichtblauw) en stroom (verticaal, felgeel) staan **op de rugzak**. [wiki](https://astroneer.wiki.gg/wiki/Backpack) De tetherlijn tekent de weg naar huis; de dikte van het gele lijntje op een kabel toont hoeveel stroom erdoor gaat. [Game Developer](https://www.gamedeveloper.com/business/an-analysis-of-astroneer-s-ui-system)
- Kritiek: veel wordt nooit uitgelegd (zelfde bron). De printer-UI werd rommelig: eindeloos links/rechts bladeren, spelers vroegen categorieën en zoeken; dat kwam er in januari 2023. [Steam](https://steamcommunity.com/app/361420/discussions/3/3053986162878107604/)
- Co-op: 2–4 spelers, vrienden springen in en uit; de basis en de save zijn van de host. [GameSkinny](https://www.gameskinny.com/tips/astroneer-how-to-play-multiplayer-on-steam-xbox-one-and-windows-10/) Hoofdmenu als 3D-scène: *(niet geverifieerd)*.

### Content Warning

- Linksonder zuurstof met gezondheid eronder, onderaan uithouding, rechtsonder 3 slots. [wiki](https://contentwarning.wiki.gg/wiki/Player) Met de camera in de hand toont rechtsboven het percentage "Film" en de toetsen van de camera. [Sportskeeda](https://www.sportskeeda.com/esports/how-extend-recording-time-content-warning)
- Lobby: "Play With Friends" → save → Host → je staat op de **bovenverdieping van een huisje**. Uitnodigen via een uitnodigingsplek (E) of de Steam-overlay; het spel begint als je de **voordeur** opent. [TheGamer](https://www.thegamer.com/content-warning-host-join-multiplayer-game/)

### Valheim

- HUD ([wiki](https://valheim.weirdgloop.org/w/HUD)): gezondheid en 3 voedselvakjes linksonder; sneltoetsbalk bovenaan; minimap rechtsboven met statuseffecten ernaast; **uithouding midden onder, enkel zichtbaar als ze niet vol is**; besturingshints rechtsonder.
- Toegankelijkheid (2021): tekst klein en met weinig contrast, ook op de maximale UI-schaal; HUD weggestopt in de hoeken; geen ondertitels; wel volledig herconfigureerbare toetsen en schermschok uit te zetten. [Game Accessibility Nexus](https://www.gameaccessibilitynexus.com/blog/2021/02/14/accessibility-impressions-valheim/) Later kwamen aparte tabs "Gameplay" en "Accessibility" en "Reduce lighting flashes". [versiegeschiedenis](https://valheim.weirdgloop.org/w/Version_history)
- Menu: Start Game → personage kiezen (met het kampvuur op de achtergrond) → wereld kiezen. Join Game heeft tabs Recent / Favourites / Friends / Community plus "Join IP". [Mobalytics](https://mobalytics.gg/gamebase/guides/valheim-world-settings-guide) · [Holy](https://www.holy.gg/en/post/join-valheim-server-ip-community-browser)

### Subnautica

- 4 ronde meters linksonder (zuurstof, gezondheid, honger, dorst) op één halfdoorzichtige achtergrond. **Zuurstof is groter** omdat die het snelst verandert, met kleine belletjes als animatie; bij een lage waarde knippert de meter rood en verschijnt er een tekstje. Diepte boven midden, kompas eronder, 5 slots onderaan. Het hoofdmenu is een 3D-titel boven een geanimeerde oceaan. [analyse](https://0252.home.blog/2020/01/16/quest-take-a-peeper-into-subnautica/) · [wiki](https://wiki.subnautica.com/sn/HUD) · [zuurstof](https://wiki.subnautica.com/sn/Oxygen)
- De PDA is diegetisch (je houdt hem vast) en spreekt waarschuwingen uit ("Oxygen. Thirty seconds"). [Medium](https://medium.com/@tht13/beneath-the-surface-narrative-design-and-emotional-immersion-in-subnautica-e314f958a997)

### Hydroneer

- Geen inventaris: je draagt één ding tegelijk. Volgens een speler "the devs wanted a minimal UI so everything is physical objects" (geen dev-citaat). [Steam](https://steamcommunity.com/app/1106840/discussions/0/3839927819743607414/)
- Kritiek: losgelaten voorwerpen vallen **naast** het punt waar je kijkt, en de schaduw die toont waar iets valt is **afhankelijk van de belichting moeilijk te zien**. [TheXboxHub](https://www.thexboxhub.com/hydroneer-review/)

### Satisfactory

- Gezondheid linksonder (10 segmenten), sneltoetsbalk midden onder (10 slots), kompas boven midden met bakens en voertuigen, sneltoetsen rechtsonder, mijlpaal rechtsboven, to-do-lijst rechts; H verbergt de HUD in bouwmodus. [wiki](https://satisfactory.wiki.gg/wiki/HUD) Een bedrijfs-AI (ADA) vertelt wat je moet doen en verpakt de humor van het bedrijf. [wiki](https://satisfactory.wiki.gg/wiki/ADA)
- Kritiek: tekst "a tad too small"; de UI-schaal was experimenteel, schaalde niet alles en duwde knoppen buiten beeld. [Steam](https://steamcommunity.com/app/526870/discussions/0/3047235309990447517/) In november 2025 nog fixes voor de lettergrootte op de Steam Deck. [Steam Deck HQ](https://steamdeckhq.com/news/satisfactory-further-improves-font-size-steam-deck/)

### Abiotic Factor

- Instellingen ([wiki](https://abioticfactor.wiki.gg/wiki/Settings)): FOV 60–115, "Show Durability Crosshair", "VOIP Speaker On Hud", vervaging achter de inventaris, **keuze van de achtergrond van het hoofdmenu**, tutorialpopups resetten, een eigen tab Toegankelijkheid. Drie kleurenblindmodi, grootte van de ondertitels, sprekeraanduiding, filters voor arachnofobie en **misofonie** (eet- en drinkgeluiden). [Dot Esports](https://dotesports.com/abiotic-factor/news/players-praise-abiotic-factors-unique-but-welcome-accessibility-option) · [Family Gaming DB](https://www.familygamingdatabase.com/accessibility/Abiotic+Factor)
- Kritiek: HUD te druk dicht bij het midden; F10 verbergt alles of niets, spelers willen per element kiezen. [Steam](https://steamcommunity.com/app/427410/discussions/5/591778624389238483/) Tekst "somewhat small", wisselend contrast. [Family Gaming DB](https://www.familygamingdatabase.com/accessibility/Abiotic+Factor)

---

## 3. Patronen over de games heen

| Patroon | Waar | Wat het oplevert |
|---|---|---|
| **De hub is de lobby** en starten is een fysieke actie | DRG (drop pod), PEAK (gate), Lethal (hendel), Content Warning (voordeur) | Wachten is spelen; iedereen ziet wie klaar staat |
| Uitnodigen via een **kiosk in de wereld** én via het pauzemenu | PEAK, Content Warning, DRG (Quick Join-terminal) | Nieuwe spelers vinden het zonder uitleg |
| Eigen status **linksonder of linksboven**, doel **rechtsboven**, slots **onderaan** | DRG, Valheim, Subnautica, Satisfactory, CW / Lethal / DRG, R.E.P.O., Satisfactory | Spelers zoeken het daar al |
| Een meter **verschijnt pas als hij iets zegt** | Valheim (uithouding), DRG ("dynamisch", teamopslag bij afgeven) | Rustig beeld |
| **Eén** samengestelde meter | PEAK | Eén plek om te kijken |
| Ping die **naam + afstand** geeft en door muren te zien is | DRG | Samenwerken zonder voice |
| Een **bedrijfsstem** voor meldingen | DRG (Mission Control), Satisfactory (ADA), Lethal (waarschuwingen) | Uitleg die ook sfeer is |
| Status op het lichaam | Astroneer (rugzak), R.E.P.O. (rugmeter), Lethal (vizierbarsten) | Je ziet ook de anderen hun toestand |

---

## 4. Ontwerpregels voor Diepgang

1. **Het depot is het menu.** Het hoofdmenu heeft enkel: Verder (hosten), Meedoen, Instellingen, Stoppen. Daarna sta je meteen in het depot. Uitnodigen gebeurt aan een **kiosk/prikbord in het depot** en via Esc. De missie start met de hendel van de Mol (met bevestiging, GDD §7), zoals de drop pod van DRG. Een Stoppen-knop staat altijd in het hoofdmenu (klacht bij DRG). Het GAG vraagt: starten zonder lagen menu's. [GAG](https://gameaccessibilityguidelines.com/basic/)
2. **Diegetisch waar het niets kost aan leesbaarheid.** Dieptemeter en scannerscherm in de cabine van de Mol (VT323, amber), de spelerskleur op de antenne, emotes op het schermgezicht. **Gezondheid, gevaar en onrust komen wél op de HUD**, want dat leest men het best van een overlay (Peacocke 2018). *[afgeleid]*
3. **Weinig vaste HUD, en alles kan dynamisch.** Elk element krijgt "altijd / dynamisch / uit" (zoals DRG). Standaard dynamisch: het komt in beeld bij een verandering en vervaagt na enkele seconden. *[afgeleid: tijd tunen via `game/data/tuning/`]*
4. **Indeling** *[afgeleid uit de patronen]*: midden een **kleine stip** (uit te zetten; vondsten en sleutels zijn klein, zie de klacht bij Lethal) met de prompt er vlak onder. Linksonder je eigen toestand en wat je draagt (gewicht, waarde). Rechtsboven de quota, alleen bij een verandering of met de scanner in de hand (zoals de teamopslag in DRG). Boven midden de diepte en de richting naar de Mol (liftkompas). Midden onder de meldingen. Links de teamgenoten met een spreekicoon.
5. **De onrustmeter in de stijl van PEAK.** Eén balk waar verschillende bronnen (tijd, boren, explosies) in eigen kleur en icoon een stuk van innemen. Zo zie je meteen wat de onrust deed oplopen. *[afgeleid]*
6. **De ping is de laserpointer van DRG, maar op een eigen knop.** Hij toont de **laag of het materiaal + de afstand**, is voor het team door de rots te zien, en spreekt een kort stemlijntje. Niet als gereedschap dat je moet uitnemen (klacht bij DRG).
7. **Interactieprompts:** contextueel, vlak bij het midden, met het juiste icoon voor het apparaat (instelling "Auto / gamepad / toetsenbord", zoals PEAK). Bij vasthouden een vulring rond de toets *[afgeleid; DRG gebruikt vasthouden voor bouwen en herstellen, met voortgang op het scherm, [mod.io](https://mod.io/g/drg/m/adjustable-hold-e)]*. Het icoon is minstens zo groot als de tekst. [XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)
8. **Letters:** **Bungee** (enkel hoofdletters) enkel voor korte koppen en labels: XAG wil gewone zinnen niet in hoofdletters, en bij een stijlvolle letter een gewone als alternatief. **Nunito** voor alle lopende tekst en cijfers. **VT323** enkel op schermen in de wereld, nooit voor kleine HUD-tekst die je moet kunnen lezen. Les van DRG: hou de persoonlijkheid in koppen en schermen, maar maak de cijfers saai en leesbaar.
9. **Grootte en contrast:** minstens **18 px op 1080p** (36 px op 4K) voor PC, schaalbaar **tot 200%**, en een omlijning of schaduw achter HUD-tekst. [XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101) Ons palet: geel #F2B705 op antraciet #23262B = **8,35:1** (ruim boven 4,5:1); geel op wit = 1,82:1, dus **nooit** gebruiken. *[eigen berekening, WCAG-formule]*
10. **Nooit enkel kleur.** Waardeklassen van vondsten krijgen een icoon of vorm + een eigen "ding" (zoals de patronen op de bessen van PEAK en de gekleurde scanner van Lethal). [GAG](https://gameaccessibilityguidelines.com/basic/)
11. **Een stem van DIEPGANG BV** ("de Opzichter" over de radio) voor quota, bevingen en "de Mol vertrekt", zoals Mission Control. Altijd met ondertitels en een korte melding op het scherm, met een eigen volumeregelaar (DRG). *[afgeleid]*
12. **Neerzetten moet zichtbaar zijn in het donker.** Een losgelaten stuk landt waar je kijkt, en de voorvertoning is een oplichtende omtrek, geen schaduw (Hydroneer-klacht). Onze put is bewust donker (GDD §8). *[afgeleid]*
13. **Het pauzemenu pauzeert niets in co-op** *[afgeleid; DRG en PEAK tonen invite/host-opties in Esc]*. Inhoud: Hervatten, Vrienden uitnodigen, Instellingen, Spelers (per speler dempen/volume; de host: kicken, lobby open/dicht), Terug naar depot, Verlaten.
14. **Kaart en scanner als toestel met een scherm in de wereld**, niet als overlay die je bevriest (DRG). Een optionele lijn in de wereld naar de Mol helpt het best bij navigatie (Peacocke). *[afgeleid]*
15. **Toetsen herconfigureren en AZERTY vanaf dag één.** Bij PEAK kwamen de klachten van AZERTY-spelers en linkshandigen. Jayme speelt op een Belgisch toetsenbord. *[afgeleid: in Godot standaard `physical_keycode` gebruiken, zodat WASD op AZERTY ZQSD wordt; UI-schaal via `Window.content_scale_factor`]*

---

## 5. Minimale instellingen voor een PC-co-opgame

Gebaseerd op wat DRG, PEAK, Valheim en Abiotic Factor hebben, op klachten (Lethal: FOV en toetsen, PEAK: toetsen en hoofdbeweging, Satisfactory: tekstgrootte) en op de basisrichtlijnen van [GAG](https://gameaccessibilityguidelines.com/basic/). Alles wordt opgeslagen, werkt meteen en is bereikbaar vanuit het hoofdmenu **en** in het spel (bij PEAK enkel vanuit het hoofdmenu: vermijden).

**Spel**
- Taal
- FOV (bv. 60–110)
- Hoofdbeweging en schermschok als schuifregelaar
- Kruisdraad aan/uit
- HUD per element: altijd / dynamisch / uit, plus HUD-schaal
- Vasthouden of wisselen voor sprinten, hurken en dragen *[afgeleid]*
- Lobbymodus: enkel uitnodiging / vrienden / publiek
- Kamercode verbergen (voor streamers)

**Beeld**
- Venstermodus, resolutie, vsync, maximum fps, renderschaal
- Preset plus losse opties (schaduwen, AO, texturen)
- **Helderheidskalibratie** (GDD; de put is donker)
- Vignet, korrel en bewegingsonscherpte uit te zetten *[afgeleid]*
- Fotosensitiviteit: minder flitsen (Valheim, PEAK)

**Geluid**
- Master, effecten, muziek, stemmen, Opzichter apart
- Microfoonkeuze; spraakactivatie / push-to-talk / push-to-mute
- Volume en dempen per speler
- Mono *[afgeleid]*

**Besturing**
- Volledig herconfigureerbaar voor toetsenbord en controller
- Gevoeligheid per apparaat, X/Y omkeren
- Keuze van de toetsiconen

**Toegankelijkheid**
- UI-/tekstschaal tot 200%
- Ondertitels (aan/uit, grootte, achtergrond, naam van de spreker)
- Kleurenblind via iconen en patronen, niet via een filter
- Filter voor schrille geluiden (zoals de misofoniefilter van Abiotic Factor) *[afgeleid]*
- Tutorialtips resetten
