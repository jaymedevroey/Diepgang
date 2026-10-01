# DIEPGANG — Game Design Document

> Werktitel. Versie 2.1, 1 oktober 2026 (v2: 30 september). Wijzigingen in v2.1: zie §14.
> 3D online co-op opgravingsgame voor Steam, volledig te bouwen door een AI-codeeragent op Jayme's pc thuis.

---

## 1. Samenvatting

**Pitch:** Online co-op voor 1–4 spelers in first-person 3D. Jullie zijn robotjes van **Diepgang BV**, een louche opgravingsfirma. Met **de Mol**, jullie grote rijdende drilboor, boor je je een weg naar beneden in een afgesloten opgravingsput. Daar graaf je door volledig vervormbare aarde naar fossielen, relieken en schatten, en sleep je ze naar het laadruim van de Mol voor de lava van onderen alles opslokt. In het depot verkoop je de buit, zet je de mooiste vondsten in je **museum** en upgrade je gereedschap, uitrusting en de Mol.

**Hoofdhaak: archeologie in plaats van mijnbouw.** Een skelet komt in 3–8 losse stukken uit de grond. Elk stuk moet apart uitgebikt en heel naar boven gebracht worden. In het depot bouw je het weer in elkaar. Het museum groeit zichtbaar tussen runs, met gaten waar een bot ontbreekt. Dat geeft een verzameldoel, een trofee om aan vrienden te tonen, en iets wat GONE DIGGING, Deep Rock Galactic en R.E.P.O. niet hebben.

| | |
|---|---|
| Genre | Co-op opgraven + fysieke buit + extractie ("friendslop" met progressie) |
| Spelers | 1–4 online (Steam), solo volledig speelbaar |
| Camera | First-person |
| Prijs | €8,99, met launchkorting |
| Doelgroep | Vriendengroepen die R.E.P.O., PEAK en Lethal Company spelen, plus fans van A Game About Digging A Hole |
| Engine | Godot 4.7.2 (vastgepind) |
| Doel | Demo op Steam Next Fest, 14–21 juni 2027, daarna Early Access |
| Engelse titel | Nog te kiezen na een check op Steam en merken. Niet "Deep Work": dat is een boektitel |

---

## 2. Markt en onderscheid

### Vergelijkbare games (stand eind september 2026)
| Game | Wat | Prijs | Reviews | Les |
|---|---|---|---|---|
| Deep Rock Galactic | co-op FPS, vervormbare grotten | $29,99 | 97% van 171k | Graven in co-op werkt, maar het is een shooter |
| DRG: Rogue Core (EA mei 2026) | roguelite DRG | $29,99 | 69% van 7,5k, piek 21k → ~370 spelers | Upgrades die enkel +% geven en een repetitieve lus kosten spelers |
| A Game About Digging A Hole | solo graven + upgrades | $4,99 | 90% van 11,4k, 1M+ verkocht | Graven op zich is satisfying. Klachten: kort, upgrades te vroeg maximaal |
| R.E.P.O. | fysieke buit, extractie, proximity voice | $9,99 | 96% van 139k, piek ~230k | Fysica-komedie + voice = clips |
| PEAK | co-op klimmen | $7,99 | 95% van 146k | Kleine team, lage prijs, sterke viraliteit |
| Keep Digging | co-op voxel graven | $6,99 | 77% van 1,2k | Klachten: performance, "recht naar beneden = klaar", ~2 u inhoud, geld niet gedeeld |
| Digging Together | co-op graven met rollen | $3,99 | 45% van 24 | Te weinig inhoud, gladde besturing, crashes, upgrades die niets voelen |

**Concurrenten in aantocht:**
- **GONE DIGGING**: co-op graven naar buit en gereedschap upgraden, Early Access in Q2 2027. Het dichtst bij ons concept.
- **DIG Raiders**: co-op graven en extractie.

Het venster is ongeveer 6–18 maanden.

### Waarom wij anders zijn
- **Tegenover Deep Rock Galactic:** geen shooter. De dreiging komt uit de omgeving (lava, bevingen, gas), plus één wezen dat je ontwijkt. Goedkoop, dwaas, sociaal.
- **Tegenover A Game About Digging A Hole:** co-op, herspeelbare sites, fysieke buit, en upgrades die nieuwe acties openen in plaats van enkel percentages.
- **Tegenover de zwakke klonen:** genoeg inhoud, een gedeelde kas, goede performance en geen manier om het spel over te slaan.
- **Tegenover GONE DIGGING:** archeologie, uitbikken, het museum, en een neergegane speler die zelf buit wordt.

### Waarom het goed bij de AI-bouwer past
Het spel speelt zich volledig ondergronds af:
- Er zijn geen lucht, bomen, gras, water of gebouwen nodig.
- Rots is procedureel (ruis, lagen, shader).
- De duisternis beperkt wat je ziet, wat zowel art-werk als performance scheelt.
- Licht doet het zware werk: gloeiende kristallen en lava.

Het depot is een **ondergrondse hal** bovenaan de put, waar de Mol tussen diensten staat, geen gebouw aan de oppervlakte.

---

## 3. Kernlus

```
Depot → opdracht kiezen → met de Mol naar beneden boren → scannen → graven → korst uitbikken
→ buit naar het laadruim van de Mol slepen (of de Mol dichterbij rijden) → onrust/lava stijgt
→ extractie: de Mol rijdt terug omhoog → verkopen → museum aanvullen → upgraden → volgende opdracht
```

### Een dienst (15–20 minuten)
1. **Opdracht kiezen**, bijvoorbeeld: "Haal €2.500 aan vondsten boven. Bonus voor een compleet skelet."
2. **Afdalen.** De Mol boort zich vanuit het depot door de lagen naar beneden, met de hele bemanning aan boord. Door de ramen zie je de lagen voorbijschuiven. Hij stopt op een diepte die de piloot kiest (zolang zijn boorkop die laag aankan).
3. **Scannen.** Een ping toont vage blips: "iets groots, 12 m, schuin onder".
4. **Graven.** Je boort tunnels naar de vondst toe.
5. **Uitbikken.** Elke vondst zit in een **korst**. Met het houweel bik je die weg zonder schade, maar traag. Boren door de korst gaat sneller, maar verlaagt de waarde.
6. **Slepen.** Met de grijphandschoen draag je buit voor je uit. Zware stukken draag je met twee, maar dan ga je trager. Laat je iets vallen, dan telt de fysica: het botst, breekt of rolt weg.
7. **Onrust en lava.** Een onrustmeter loopt op met de tijd en met lawaai (boren, explosies). Bij elke drempel beeft de put: rotsblokken vallen in onstabiele zones en de lava stijgt een stuk. Tussen de drempels stijgt de lava ook traag.
8. **Extractie.** De piloot trekt aan de hendel. Na een aftelling met claxon rijdt de Mol terug omhoog door zijn eigen tunnel. Wie niet aan boord is, blijft achter en verliest wat hij droeg. Wat in het laadruim ligt, telt.
9. **Uitbetaling.** De waarde hangt af van hoe gaaf de vondst is, plus een eventuele bonus. Wie de opdracht niet haalt, betaalt een **boete** en verliest reputatie. **Upgrades blijven altijd behouden.** Reputatie bepaalt welke sites je mag doen.

### Waarom deze lus werkt
- De quota met boete zorgt voor spanning: "nog één fossiel of nu naar boven?"
- De lava stijgt van onderen, terwijl de beste vondsten diep zitten. Dat is de hebzucht-tegen-veiligheid-afweging.
- Uitbikken tegenover boren is een voortdurende afweging tussen tijd en waarde.
- Samen dragen en fysica-ongelukken leveren de clips.
- De Mol is de veilige thuis in het donker, maar elke meter die hij rijdt maakt lawaai: dichter bij de vondsten rijden of de onrust laag houden?

---

## 4. Wereld

### De put
- Een afgesloten volume van ongeveer **64 × 160 × 64 m**. Voxels van 0,5 m, dus 128 × 320 × 128.
- Procedureel per run (seed), met handgemaakte set pieces: oude mijngangen, grotten, fossielbedden.
- **Terrein kan je enkel wegnemen, nooit toevoegen.** Daardoor maakt de volgorde van graafacties niet uit en blijft de synchronisatie eenvoudig.

### Lagen
Elke laag heeft een eigen kleur **en** een eigen patroon, voor leesbaarheid en voor kleurenblinden.

| Laag | Graven met | Vondsten | Gevaar |
|---|---|---|---|
| Klei | alles | munten, flessen, rommel | weinig |
| Zandsteen | boor T1 | fossielen, oud gereedschap | onstabiele zones |
| Graniet | boor T2 | geodes, goud, grote skeletten | gasbellen |
| Kristal | boor T2 | lichtgevende kristallen (breekbaar) | gas, de Graafworm |

**Regels:**
- De boor-tier bepaalt of je een laag *doorkomt*. Het houweel bikt korsten in *elke* laag.
- De waarde zit verspreid over alle lagen, dus recht naar beneden graven levert niets extra op. Samen met de lava die van onderen stijgt voorkomt dat de skip die Keep Digging kapotmaakte.

### Sites
| Site | Early Access | Kenmerk |
|---|---|---|
| Oude Kolenmijn | ja | begeleide eerste opdracht (tutorial), klei + zandsteen, bestaande gangen |
| Fossielbed | ja | veel grote, zware skeletten in stukken: samenwerken |
| Kristalgrotten | ja | breekbare, lichtgevende buit, gas, de Graafworm |
| Vulkanische Pijp | later | snelle lava, basalt, hittepak |
| Verzonken Stad | later | ingestorte ruïnes in de rots (zuilen, trappen), relieken |

Na Early Access komen nog een eindeloze "diepe dienst" en een wekelijkse site met een vast zaad.

### Vondsten (procedurele families)
Honderd handgemaakte modellen is niet realistisch. Vijf families met veel variatie wel:

1. **Skeletten:** botvormen per soort gecombineerd, 3–8 stukken per skelet, voor het museum.
2. **Relieken:** beelden, maskers en vazen uit bouwblokken met varianten.
3. **Kristallen en geodes:** procedurele meshes, gloeiend en breekbaar.
4. **Metalen:** goudklompen, munten, oude machines.
5. **Rommel:** grappige vondsten (oude tv, tuinkabouter, fietsbel) die weinig waard zijn maar leuk om te vinden.

Elke waardeklasse heeft zijn eigen geluid en glans.

---

## 5. Gereedschap en uitrusting (±8 in Early Access)

**Principe:** elke upgrade laat je iets *nieuws* doen, niet enkel iets sneller.

**Slots:** 2 handgereedschappen, 1 gadget en verbruiksgoederen.

| Item | Upgrades en wat ze openen |
|---|---|
| **Houweel** (start) | sneller bikken, precisiemodus |
| **Boor** T1 → T2 | zandsteen, daarna graniet en kristal. Snel en luid, beschadigt buit |
| **Grijphandschoen** | zwaardere stukken solo, groter bereik, demper tegen botsschade |
| **Scanner** | T1: blips. T2: waarde en type. **Nooit** "alles zichtbaar". De Mol heeft een vaste sonar (T1, 24 m) in de cabine; de handscanner is voor te voet |
| **Takel en touw** | anker plaatsen en buit door schachten omhoog lieren |
| **Ladders** | zelf verticale routes maken |
| **Springlading** (verbruik) | grote kraters, maar een beving en kans op schade |
| **Lichtbakens** (verbruik) | route markeren, de Graafworm afschrikken |
| **Walkietalkie** | praten buiten het bereik van proximity voice |
| **Helmlamp** | bereik en helderheid |
| **De Mol** | zie §5A. Upgrades komen later |

**Economie:**
- Een **gedeelde teamkas** per savegame (de host bewaart).
- Alles maximaal upgraden duurt ±10–12 uur.
- Cosmetica (helmen, verf, schermgezichten) koop je apart, of verdien je via speciale vondsten.

**Bewust weggelaten:**
- Jetpack: maakt alle andere verticale oplossingen overbodig.
- Verzekering: maakt voorzichtig uitbikken zinloos.
- Stutten: instortingen voegen geen terrein toe, dus er valt niets te stutten.
- Een Mol die zonder betere boorkop dieper kan: zou een lagen-skip zijn. De boorkop van de Mol volgt dezelfde laagregels als de handboor.

---

## 5A. De Mol (rijdende drilboor en basis)

> Toegevoegd in v2.1 op vraag van Jayme. Werknaam. Vervangt de lift uit M1.

Een grote rupsvoertuig-drilboor (±10 m lang, ±6 m breed) van Diepgang BV: vooraan een draaiende boorkop met snijtanden, daarachter een cabine met ramen en koplampen, een laadruim en een motor met uitlaat. De Mol is jullie **basis**, jullie **transport** en jullie **extractie** in één.

**Rol in een dienst**
- **Afdalen:** de Mol boort vanuit het depot naar beneden tot de diepte die de piloot kiest.
- **Rijden:** tijdens de dienst kan hij verder rijden en grote tunnels boren (±6 m breed), ook schuin omhoog of omlaag (begrensde helling).
- **Laadruim:** buit die erin ligt bij vertrek, telt. De capaciteit is beperkt (gewicht).
- **Extractie:** terug omhoog door zijn eigen tunnel (zie §3).
- **Neergegane robots** sleep je naar de Mol om ze te repareren (§6).

**Besturing:** één piloot in de cabine; iedereen mag piloot worden. De anderen rijden mee, binnen of op het dek.

**Traag, luid en beperkt** (zodat met de hand graven en uitbikken de kern blijven):
- traag (±1,5 m/s rijden, trager tijdens het boren);
- **luid**: rijden en boren doen de onrust sterk stijgen, en de Graafworm komt erop af;
- **brandstof** per dienst is beperkt;
- de **boorkop** volgt de laagregels (T1: klei en zandsteen; betere koppen zijn upgrades).

**Binnenruimte (klein):** een cabine (stoel, stuur, dieptemeter, sonar: ronde beeldbuis met vage blips en hun hoogte, zie [de-mol.md](de-mol.md)), een laadruim met laadklep, en een werkbank (upgrades, later). Warm licht en een gezellige thuis in het donker, zoals de drop pod in Deep Rock Galactic.

**Upgrades (later):** boorkop (graniet, kristal), snelheid, brandstoftank, laadruim, hitteschild tegen lava, lier/kraan, lampen, cosmetica (verf, stickers).

**Techniek:** de host simuleert de Mol (de piloot stuurt invoer), kinematisch (AnimatableBody3D), met grote terreinbewerkingen vooraan. Wie meerijdt, staat op een bewegend platform; clients interpoleren. Het lift-platform uit M1 is hiervoor de basis.

---

## 6. Gevaren en wezens

- **Lava:** een stijgend vlak met shader en een dodelijke zone. Geen stromingssimulatie.
- **Instortingen:** vallende rotsblokken (fysica-objecten) met stof in **gemarkeerde onstabiele zones**. Spannend en vermijdbaar, en het terrein verandert er niet door.
- **Gasbellen:** een zichtbare gele waas, en de T2-scanner toont ze. Ze ontploffen bij vonken, bijvoorbeeld van de boor.
- **Graafworm** (het enige wezen in Early Access):
  - Hij zwemt onzichtbaar door de aarde, zonder het terrein te veranderen.
  - Je merkt hem aan gerommel, trillingen, stof en een markering op de grond.
  - Hij komt af op lawaai en duikt enkel op in open ruimtes.
  - Hij slokt losliggende buit op en sleurt die weg, en kan spelers omverduwen.
  - Lichtbakens en lokaas houden hem op afstand. Er zijn geen wapens.
- **Later:** een kristalspin (trekt spelers mee, via een gescripte "gesleept"-toestand op de client van het slachtoffer) en een lavaslang.

### Neergaan: je wordt zelf buit
- Een neergegane robot wordt een **draagbaar object**.
- Je team moet je naar de Mol slepen om je te repareren. Dat hergebruikt het draagsysteem en levert gegarandeerd grappige momenten op.
- Ben je volledig kapot, dan kijk je mee als spookdrone. Je kan niet praten met de levenden, en dat is de grap.
- Je progressie verlies je nooit, enkel wat je droeg.

---

## 7. Co-op, solo en gebruiksgemak

- **Co-op:**
  - Grote stukken samen dragen.
  - Iemand bedient de takel, iemand verlicht, iemand scant.
  - Proximity voice plus walkietalkie.
- **Solo:** volledig speelbaar. De lava is trager, de handschoen is sterker en de takel goedkoper.
- **Schalen met het aantal spelers:** meer vondsten en een grotere quota. **Niet** extra onrust per speler, want meer spelers maken al vanzelf meer lawaai.
- **Pings en markers, een liftkompas, en een "vast"-knop** om te voorkomen dat je verdwaalt of klem zit.
- **Stoppen met spelen:**
  - Als de host stopt, eindigt de sessie netjes en wordt alles opgeslagen.
  - Wie tijdens een dienst binnenkomt, kijkt mee tot de volgende dienst.
- **Griefing** is onder vrienden deel van de fun. Voor publieke lobbies: stemmen om te kicken, en de hendel vraagt bevestiging.
- **Instellingen:**
  - FOV, muisgevoeligheid, toetsen aanpassen, grafische presets.
  - **Helderheidskalibratie**.
  - Schermschok en hoofdbeweging uit te zetten.
  - Audiokanalen apart instelbaar, en per speler dempen.
  - Push-to-talk.
- **Taal:** eerst Engels, daarna Nederlands.
- **Controller en Steam Deck:** basisondersteuning.

---

## 8. Stijl

**Richting (v2.1, Jayme):** de vibe van **Deep Rock Galactic** (gestileerd, chunky, licht in het donker) met de warmte en speelsheid van **PEAK** en de zachte vormen en voertuigen van **Astroneer**. Gestileerd, niet fotorealistisch. **Alle modellen in Blender** (headless scripts), geen AI-gegenereerde modellen.

- **Beeld:** donker als bewuste stijlkeuze. Enkel wat verlicht is, heeft detail.
  - Palet: 6–8 kleuren plus 2 emissieve accenten.
  - Warm amber voor de helmlampen, cyaan voor de kristallen, oranje voor de lava, en een eigen aardetint per laag.
  - Glow, mist, vignet en lichte korrel.
- **Robots:**
  - Afgeronde lijven met gebevelde randen.
  - Een groot schermgezicht met pixelogen voor emotes, een meeverende antenne en kleine ledematen.
  - Eigen kleur per speler, plus hoedjes.
- **Animatie:** volledig procedureel: wiebel, squash & stretch, veren. De worm is een segmentketting.
- **Juice:** schermschok, stofwolken, brokken en vonken per materiaal, en een "ding" per waardeklasse.
- **Geluid:**
  - De boor klinkt anders per materiaal.
  - Gerommel van bevingen, de worm die door de aarde zwemt.
  - Gelaagde synthese, 3–5 varianten per geluid.
- **Muziek:**
  - Depot: rustige piano en strijkers.
  - In de put: donkere ambient-lagen die opbouwen met diepte en onrust.
  - Geen melodieuze actietracks, want die klinken met code gemaakt "MIDI-achtig".

---

## 9. Techniek

| Onderdeel | Keuze |
|---|---|
| Engine | Godot **4.7.2** (standaard, geen .NET), Forward+, **Jolt** physics (standaard sinds 4.6), GDScript |
| Terrein | **godot_voxel 1.7 GDExtension** (werkt met de standaard Godot-editor en exporttemplates), `VoxelTerrain` zonder LOD, Transvoxel smooth mesher, blokgrootte 16. Afgeschermd achter een eigen `TerrainAPI`-laag |
| Terrein-sync | Eigen code: graafacties `(op, centrum, straal, tick)` gaan via de host naar iedereen. Enkel wegnemen, dus volgorde maakt niet uit. Wie later binnenkomt, krijgt het zaad en de lijst met graafacties. Graafacties per tick bundelen en de herbouw van collision beperken |
| Netwerk | **GodotSteam 4.20.x GDExtension** met ingebouwde `SteamMultiplayerPeer`: lobbies, uitnodigingen via vriendenlijst, Valve-relay (geen port forwarding). Niet combineren met de losse steam-multiplayer-peer-extensie |
| Spelers | De client bepaalt de eigen beweging, anderen interpoleren |
| Buit | De host simuleert (Jolt RigidBody). Clients zetten buit op kinematisch en interpoleren. **Vastgehouden buit volgt de hand kinematisch, meteen op je eigen scherm.** Losgelaten of gegooid neemt de fysica weer over. Samen dragen: de buit hangt tussen beide handen en je beweegt trager. Na een graafactie in de buurt: buit wakker maken en een klein duwtje geven |
| Voice | Steam voice-API naar een `AudioStreamPlayer3D` per speler (proximity). Push-to-talk, dempen en volume per speler |
| IK en animatie | Ingebouwde `IKModifier3D`-nodes (sinds 4.6) en `SpringBoneSimulator3D` voor antennes |
| Tests | GUT of gdUnit4, headless. Botspelers en 2–4 lokale instanties via ENet |
| Controle en tuning | Een tuning-menu in het spel (alle "gevoel"-waarden in databestanden) en speel-logs die de agent analyseert |

**Performance-regels:**
- Collision na graven wordt op de hoofdthread herbouwd. Beperk graven tot 5–10 acties per seconde per speler en bundel per frame.
- Buit krijgt convex- of box-colliders, nooit trimesh, met CCD en een minimale grootte.
- Hooguit 4–8 lampen met schaduw (de helmlampen). De rest zonder schaduw, met kort bereik.
- Geen SDFGI.
- Shader-baker aan, tegen haperingen op Windows.

### Assets (alles met code)
| Categorie | Pijplijn |
|---|---|
| Robots, gereedschap, lift, props | Blender headless (bpy-scripts) → .glb. Vertexkleuren of paletatlas |
| Kristallen, vondsten-families | GDScript SurfaceTool/ArrayMesh, procedureel |
| Terrein-materialen | Triplanar shader + Texture2DArray, gebakken met numpy/Pillow |
| VFX | GPUParticles3D + shaders. Lava als emissieve ruis-shader |
| Geluidseffecten | numpy-synthese + pedalboard + rFXGen → WAV/OGG |
| Muziek | Python MIDI → sfizz/FluidSynth met **VSCO 2 CE** (CC0) en Salamander Piano (CC-BY, credit vermelden) + gesynthetiseerde drones → stems voor dynamische muziek |
| Fonts | OFL (Google Fonts), OFL.txt in de credits |
| Iconen | Eigen SVG, Kenney (CC0) of game-icons.net (CC-BY, credit vermelden) |
| Steam-capsules | Renders + Pillow-compositie op de vereiste formaten |
| Trailer | Camerapaden en botacties als script. **Opgenomen op Jayme's pc** (echte Forward+-look), montage met ffmpeg |

**Licenties:** houd een `CREDITS.md` bij. Gebruik geen Sonatina (beperkende licentie). Zijn er toch AI-gegenereerde assets, dan moet dat vermeld worden op Steam. Procedurele code geldt als code en hoeft niet vermeld te worden.

---

## 10. Planning en poorten

> Herzien op 1 oktober 2026 (v2.1). M0 en M1 waren in een dag klaar in plaats van in een maand. Op vraag van Jayme komt het uiterlijk eerst en Steam/voice en de kernlus daarna (oude M2/M3 en M4/M5 gewisseld). Het netwerk zelf zit er al in sinds M1.

| Mijlpaal | Doel | Inhoud | Poort |
|---|---|---|---|
| **M0 Opzet** | ✅ 1 oktober 2026 | Repo, Godot 4.7.2, voxel- en GodotSteam-extensies samen, Windows-export, render- en performancetest | Jayme start de build en kan graven |
| **M1 Graafspeelgoed** | ✅ 1 oktober | First-person robot, graven, korsten uitbikken, dragen, lift. **Al met netwerk** (ENet, host/join). Tuning-menu | **Poort 1:** voelen graven en slepen goed? |
| **M2 Uiterlijk** (was M5) | half oktober | Stijlgids, rotstexturen per laag, Blender-modellen (**de Mol**, gereedschap, fossielen, puin), sfeer en licht (stof in de lucht, kristallen, kleurgrading), ambient geluid en muziek, eigen stijl voor menu's en HUD, instellingen | "Ziet het eruit als een game?" |
| **M3 Inhoud** (was M4) | eind oktober | **De Mol** werkend (afdalen, rijden en boren, laadruim, extractie; vervangt de lift), Fossielbed en Kristalgrotten, Graafworm, gas, alle ±8 items, **depot met teamkas en museum** (vooruitgehaald uit de kernlus), cosmetica | |
| **M4 Samen** (was M2) | begin november | Steam-lobby's en uitnodigingen, voice, getest met 150 ms vertraging | **Poort 2:** 30 min met drie vrienden zonder problemen, en is het leuk? |
| **M5 Kernlus** (was M3) | half november | Opdrachten, quota, boete, lava, onrust, **opslaan**, host die vertrekt, Oude Kolenmijn volledig met tutorial | De eerste versie die "een game" is |
| **M6 Demo** | december | Demo, capsules, trailer, Steam-pagina | Steam-pagina "Coming Soon" zodra het Steamworks-account er is. **Next Fest juni 2027** blijft de vaste datum (inschrijven voor 25 april); een eerdere Next Fest kan als de deadlines het toelaten |

**Wat het tempo bepaalt:** hoe snel Jayme, Ian en Anir kunnen playtesten, en de wachttijden bij Steam. Niet het programmeren. De data kloppen als er per mijlpaal binnen enkele dagen getest wordt.

### Stopcriteria
- **Poort 1 faalt** (graven en slepen voelen niet goed): bijsturen of stoppen, na enkele weken in plaats van maanden.
- **Poort 2 faalt** (netwerk werkt niet betrouwbaar): terug naar een eenvoudiger model, of pivoteren.
- **GONE DIGGING blijkt bij release bijna identiek:** archeologie en het museum nog verder als hoofdzaak naar voren schuiven.

---

## 11. Rolverdeling

**AI-bouwer (Claude):** alle code, 3D-modellen, animaties, shaders, geluid, muziek, UI, tests, builds, Steam-teksten en de montage van de trailer.

**Jayme:**
1. **Nu al:** een Steamworks-account aanmaken ($100 app fee, terug te verdienen na $1.000 omzet), plus belasting- (W-8BEN) en identiteitsgegevens. Daar zit een wachttijd op.
2. Elke build testen op de eigen Windows-pc. De agent ziet enkel de eenvoudigere renderer, dus de echte Forward+-look en de performance moet Jayme controleren.
3. Per poort playtesten met Ian en Anir.
4. Trailerbeelden opnemen op de eigen pc.
5. Beslissen bij elke poort.

---

## 12. Belangrijkste risico's

| Risico | Aanpak |
|---|---|
| De voxel-extensie is instabiel of botst met GodotSteam | Meteen testen in M0. De `TerrainAPI`-laag maakt vervangen mogelijk |
| Dragen via het netwerk voelt slecht | Kinematisch volgen met lokale voorspelling, testen met 100–200 ms vertraging |
| Haperingen door collision-herbouw | Graven beperken en bundelen, kleine blokken, vroeg profileren op een mid-range pc |
| De agent ziet de echte look niet | In M0 testen of Forward+ via lavapipe werkt. Anders enkel effecten die de eenvoudige renderer ook toont, plus Jayme's screenshots en helderheidskalibratie |
| Steam-administratie | Nu starten |
| Concurrentie (GONE DIGGING, Q2 2027) | Het museum en de archeologie als unieke haak, en een demo op Next Fest in juni |

---

## 13. Startinstructies voor de bouw op Jayme's pc

**Te installeren:**
- Godot 4.7.2 (standaard, niet .NET) met exporttemplates
- Blender (recent, voor de headless modelscripts)
- Python 3.11+ (numpy, Pillow, mido, pedalboard)
- Git
- Later: sfizz of FluidSynth, en ffmpeg

**Repo-structuur (voorstel):**
```
diepgang/
  docs/GDD.md            ← dit document
  tasks/todo.md          ← afvinkbare taken per mijlpaal
  tasks/lessons.md
  game/                  ← Godot-project
    addons/ (godot_voxel, godotsteam, gut)
    src/ (terrain, net, player, loot, tools, ui, audio)
    data/tuning/         ← alle "gevoel"-waarden
    tests/
  tools/
    blender/             ← bpy-scripts → .glb
    audio/               ← synthese- en muziekscripts
    store/               ← capsule-generatie
  CREDITS.md
```

### M0-takenlijst
- [ ] **Stap 1:** repo en Godot 4.7.2-project aanmaken, Jolt aanzetten.
  Verificatie: het project opent zonder fouten.
- [ ] **Stap 2:** godot_voxel 1.7 GDExtension toevoegen, een `VoxelTerrain` van 128×320×128 met gelaagde generator, en `do_sphere` bij klikken.
  Verificatie: graven werkt, en de laadtijd en het geheugen zijn gemeten.
- [ ] **Stap 3:** GodotSteam 4.20.x GDExtension toevoegen naast godot_voxel.
  Verificatie: beide laden samen zonder conflict, en de Steam-init lukt met test-appid 480.
- [ ] **Stap 4:** een `TerrainAPI`-laag rond het graven.
  Verificatie: graven gaat enkel via die laag.
- [ ] **Stap 5:** een stresstest met 4 gesimuleerde gravers plus 30 fysica-objecten.
  Verificatie: frametijd en collision-pieken zijn gelogd.
- [ ] **Stap 6:** een Windows-export (release) bouwen.
  Verificatie: Jayme start de .exe en kan graven.
- [ ] **Stap 7:** de renderertest, Forward+ tegenover Compatibility.
  Verificatie: besluit genoteerd welke effecten verifieerbaar zijn.

---

## 14. Wijzigingen

### v2 → v2.1 (1 oktober 2026, met Jayme)
1. **De Mol** toegevoegd (§5A): een rijdende drilboor als basis, transport en extractie. Vervangt de lift en de vaste liftschacht.
2. **Planning herzien** (§10): uiterlijk eerst, dan inhoud, dan Steam/voice, dan de kernlus. Data ingekort: M0 en M1 waren in een dag klaar.
3. **Stijl vastgelegd** (§8): Deep Rock Galactic + PEAK + Astroneer. Alle modellen in Blender.

### v1 → v2 (onafhankelijke review)

1. Een quota met boete toegevoegd, omdat er zonder faalconditie geen spanning is.
2. Een centrale liftschacht die je naar elke diepte roept, in plaats van eindeloos verticaal slepen. De jetpack is geschrapt.
3. Terrein kan enkel weggenomen worden. Instortingen die terrein toevoegen en een tunnelende worm zijn geschrapt.
4. Korsten in plaats van fijn uitgraven, en duidelijk vastgelegd welk gereedschap welke laag doet.
5. Liftupgrades geven snelheid en capaciteit, geen diepere start.
6. Dragen is kinematisch met lokale voorspelling. Fysica enkel bij loslaten.
7. First-person, met pings, een liftkompas en een "vast"-knop.
8. Netwerk vanaf M1, voice in M2, opslaan en host-vertrek in M3.
9. Early Access verkleind tot 3 sites, 1 wezen en ±8 items. Verzekering, de "alles zichtbaar"-scanner en de lavaslang zijn geschrapt.
10. Renderverificatie en een tuning-menu toegevoegd, en het museum gekozen als hoofdhaak.

---

## 15. Bronnen

- Deep Rock Galactic: https://store.steampowered.com/app/548430/
- DRG: Rogue Core: https://store.steampowered.com/app/2605790/ · https://steamcharts.com/app/2605790
- A Game About Digging A Hole: https://store.steampowered.com/app/3244220/ · https://spilled.gg/a-game-about-digging-a-hole/
- R.E.P.O.: https://store.steampowered.com/app/3241660/ · https://en.wikipedia.org/wiki/R.E.P.O.
- PEAK: https://www.gamedeveloper.com/production/how-co-op-climbing-hit-peak-achieved-2-million-sales-for-less-than-200-000-
- Lethal Company: https://www.pushtotalk.gg/p/how-lethal-company-sold-10-million-copies
- Keep Digging: https://store.steampowered.com/app/3585800/ · https://steamcommunity.com/app/3585800/negativereviews/
- Digging Together: https://store.steampowered.com/app/3938040/
- GONE DIGGING: https://store.steampowered.com/app/4247230/
- DIG Raiders: https://store.steampowered.com/app/4368640/
- Friendslop-markt: https://howtomarketagame.com/2026/07/30/is-friendslop-saturated/
- Godot 4.6: https://godotengine.org/releases/4.6/ · Godot 4.7: https://godotengine.org/releases/4.7/
- Godot-builds: https://github.com/godotengine/godot-builds/releases
- godot_voxel: https://github.com/Zylann/godot_voxel/releases · https://voxel-tools.readthedocs.io/en/latest/getting_the_module/ · https://voxel-tools.readthedocs.io/en/latest/performance/ · https://voxel-tools.readthedocs.io/en/latest/multiplayer/
- GodotSteam: https://godotsteam.com/blog/category/multiplayerpeer/ · https://godotsteam.com/tutorials/voice/
- Godot Movie Maker: https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html
- Steam app fee: https://partner.steamgames.com/doc/gettingstarted/appfee
- Next Fest juni 2027: https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/june_2027
- Steam builds uploaden: https://partner.steamgames.com/doc/sdk/uploading
- Steam AI-regels 2026: https://www.generationamiga.com/2026/01/17/valve-rewrites-steams-ai-disclosure-rules-for-developers/
- VSCO 2 CE: https://versilian-studios.com/vsco-community/
- Steam-capsuleformaten: https://presskit.gg/field-guides/steam-capsule-art-guide
