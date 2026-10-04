# Planeten: een rijk oppervlak, een onzichtbare rand en drie identiteiten

Onderzoek van 2026-10-04, voor Godot 4.7 Forward+ op een mid-range pc. Dit is enkel onderzoek: er is niets gebouwd.

**Aanleiding (Jayme).** Een planeet ziet er veel te kaal uit. Bij de drop zie je duidelijk het speelgebied met wat kleine heuvels, en de rest is een vlakke strook niets.

**Bekeken:**
- de dropreeks `logs/drop_seq/na_lead/`: beelden 026–046 (de val van 300 m tot de grond) en 065–080 (de grond, en vaste hoogtes van 340, 160 en 60 m);
- `final_vs_voor_hoogtepunten.png` in de worktree van de QA-agent;
- de code: `planet_surface.gd`, `planet_generator.gd`, `terrain.gdshader`, `planet_type.gd`, `atmosphere.gd`;
- de instellingen: `ship.cfg` (dropcamera), `terrain.cfg`, `sky.cfg`;
- de documenten: [hemel.md](hemel.md) §2 en §5, [drop-en-ophalen.md](drop-en-ophalen.md), GDD §4 en §8, en de stijlgids.

**Beslist door Jayme:**
- Roestbol krijgt hemel A ("karamel met een blauwe krans").
- Fossielwereld krijgt hemel B ("teal boven roest").
- Kristalmaan krijgt hemel C ("paars gouden uur").
- Een opdracht op de terminal kiest de planeet.

## Kort

1. **Er zijn niet te weinig driehoeken. Er is een dichtheidsklif.**
   - Binnen het speelgebied: ±350 kraters per km², scherp gevormd in voxels, met rotsblokken.
   - Erbuiten: een glad raster met cellen van 7,8 m, minder kraters (en die zijn vervaagd), geen rotsblokken en één egaal ruispatroon.
   - Het oog ziet dus de rand van het detail, en leest het speelgebied als een "level".
2. **Van 300 m ziet de dropcamera ±900 × 440 m grond, bijna recht van boven.**
   - De mesa's en grote kraters liggen op 0,7–2,5 km en vallen dus buiten beeld.
   - Van op de grond ligt de kim op ±350 m.
   - De zone die telt is de ring van 125 tot ±450 m van de landingsplek. Daar ligt nu het minst.
3. **Van 300 m hoog is er nergens schaduw.** De zon werpt schaduw tot 140 m van de camera, en het verre landschap werpt er zelf geen. Reliëf leest daardoor plat.
4. **"Kaal" moet "zonder planten" betekenen, niet "leeg".** Elk kaal biome in de voorbeelden heeft landvormen en minstens één landmark: de mesa's in de duinen van Helldivers 2, de rotsen op Embrion, het torentje aan de kim in Outer Wilds.
5. **Zet het speelgebied ín een landvorm** die 3–6 keer groter is dan het vierkant en er niet op gecentreerd is: een kraterbodem, een terras onder een wand, een bekken met een kristalader.
   - De rand van die landvorm ligt op 250–600 m, aan één of twee kanten.
   - Nooit een kom die het vierkant omsluit: die herhaalt het vierkant.
6. **Eén wereldfunctie, twee manieren van tekenen.**
   - De landvorm en de spreiding (kraters, rotsen, spitsen, botten) liggen op een raster in wereldruimte.
   - Binnen het speelgebied worden ze voxels, erbuiten meshes.
   - De dichtheid loopt door over de rand en dooft pas na 300 m of meer geleidelijk uit.
7. **Van boven lees je waarden en schaduw, geen ruis.**
   - Drie waardegroepen, met accenten die aan landvormen vastzitten: donker zand in laagtes, licht stof op hoogtes, sporen van stofduivels.
   - Overal rustvlakken tussen het detail.
8. **Elke planeet heeft één signatuurvorm, op alle schalen** (zoals de exotische planeten van No Man's Sky en de biomen van DRG):
   - Roestbol: een gelaagde kraterrand met donkere duinsikkels.
   - Fossielwereld: een wit badland met een reuzenskelet dat uit de wand erodeert.
   - Kristalmaan: een kristalader die het bekken doorsnijdt en oplicht in de lage zon.
9. **Landmarks:**
   - één grote die je van overal ziet;
   - drie of vier middelgrote, één per kwadrant aan de kim;
   - kleine om de 50–80 m.

   Hoe hoger iets is, hoe belangrijker (Breath of the Wild). **DIG-geel is enkel voor DIG-spullen**, zodat geel van boven altijd "mensen, DIG" betekent.
10. **DIG-setdressing vertelt een verhaal en helpt je oriënteren:**
    - een pijpleiding dwars door het beeld tot voorbij de kim (die verbergt het vierkant);
    - een verlaten boortoren met een rood licht;
    - de terrassen van een oude dagbouwput;
    - een gecrashte Mol.

    Hooguit vijf DIG-dingen in beeld van 300 m, en wisselend per dienst. Herhaling was de grootste klacht over Starfield.
11. **Volgorde van werken:**
    - waardeschetsen op de echte dropbeelden, per planeet;
    - een blokmodel van Roestbol, bekeken vanuit de dropcamera (enkel de grote vormen);
    - de details;
    - de andere twee planeten, als data in `PlanetType`.

    Budgetten leggen we vast als aantallen (draw calls, driehoeken). Cijfers van deze RTX 4090 bewijzen niets.

## 1. Waarom het nu kaal leest

### Wat de dropcamera ziet

- **Boven 220 m** hangt de camera 18 m boven de Mol en kijkt ±80° omlaag, met een beeldhoek van 70–78° (`ship.cfg`).
- **Op 300 m** ziet ze ±900 × 440 m grond (de zwarte balken meegerekend), ±0,5 m per pixel op 1080p.
  - Het hele speelgebied staat in beeld, met ±325 m ernaast aan elke kant.
  - Een rotsblok van 2 m is 4 pixels groot: textuur. Vormen lezen pas vanaf ±10 m.
- **Op de grond** (ooghoogte, planeetstraal 30 km) ligt de kim op √(2Rh) ≈ 350 m. Verder zie je enkel wat hoog genoeg is: op 1 km moet iets 7 m hoog zijn om boven de kim uit te komen.

### Wat er misloopt

| # | Oorzaak (in de code) | Waar je het ziet | Gevolg |
|---|---|---|---|
| 1 | **Een dichtheidsklif.** In de generator liggen 22 kraters en 70 rotsblokken, enkel binnen het vierkant. De rotsblokken bestaan enkel als voxels, en die laden tot ±110 m rond de landingsplek. De fijne ring heeft cellen van 7,8 m: kleine kraters worden er brij. | 026, 032: een gedetailleerde vlek van ±220 m, eromheen glad | Het speelgebied leest als een level op een plaat |
| 2 | **Geen schaduw.** De zon werpt schaduw tot 140 m (`atmosphere.gd`), en het verre landschap heeft `cast_shadow` uit. | 026–032 en 069–076: kraters enkel door hun helling getekend | Reliëf leest plat; van boven geen diepte |
| 3 | **Behangpapier.** De kleurvlekken van 9 m en 280 m zijn overal dezelfde ruis, los van de vormen. Er zijn geen rustvlakken. | 026, 032, 074: een gelijkmatig "mazelen"-patroon | Geen hiërarchie; het oog vindt niets |
| 4 | **Geen grote vormen dichtbij.** Mesa's en grote kraters liggen pas na 0,7–2,5 km. De heuvels worden pas hoger met de afstand (5 m tot 80 m, 40 m tot 600 m). | 026–040; 073 (de enige mesa ligt ver in de waas) | Niets kadert het speelgebied; vlak eromheen |
| 5 | **Eén kleur en één laag voor alles.** Het verre landschap is altijd klei, met een smalle waardeband onder ±30% waas. | 069–080 | Geen waardegroepen; alles is middenoranje |
| 6 | **Geen landmarks of menselijke sporen.** De paaltjes verdwijnen bewust boven 170 m. | 065–068: in elke richting dezelfde kim | Geen oriëntatie, geen verhaal |
| 7 | **De rotsblokken zijn gladde ellipsoïden.** | 040, 046, 066 | Ze lezen als broodjes of koepels, niet als rots |
| 8 | **De horizon heeft overal dezelfde gekartelde rimpelrij** (ridged noise), en maar één diepteplan. | 043, 046, 065–067 | Geen diepte, geen silhouet om te onthouden |

De hemel is sinds de vorige ronde in orde ([hemel.md](hemel.md)). Wat ontbreekt, is wat ertussen hoort: landvormen, schaduw, waarde en verhaal in de eerste 450 m.

## 2. Wat andere games doen

**Helldivers 2**
- **31 biomen, gebouwd uit een paar families.** Zand, oerwereld, ijs, hei, moeras, bos, oase en enkele speciale ([wiki](https://helldivers.wiki.gg/wiki/Biomes)).
- **Per familie een kit.** De artiest van de zandbiomen beschrijft zijn werk: materialen voor terrein en rots, een pijplijn voor de kleurcorrectie, generatoren voor duinen en kraters, en varianten zoals Mineral, Acid, Spiky en Moon ([Lemaire, ArtStation](https://www.artstation.com/artwork/V2VNBb)).
- **Ook het leegste biome heeft vormen:** in de duinwoestijn breken rotsige mesa's de zee van duinen ([wiki](https://helldivers.wiki.gg/wiki/Biomes)).
- **Kaarten worden samengesteld** uit stukken, plekken met buit (POI's) en vijandkampen ([GamingBolt](https://gamingbolt.com/helldivers-2-features-terrain-deformation-and-procedural-generation)).
- **Kleine POI's zijn verhaaltjes:** graven, een neergestorte Pelican met een logboek, een gestrand wrak ([wiki](https://helldivers.wiki.gg/wiki/Points_of_Interest)).
- **De rand is een straf, geen muur.** Het speelveld ligt iets verhoogd, met een greppel aan de rand; wie verder gaat, krijgt artillerie ([TheGamer](https://www.thegamer.com/helldivers-2-player-drives-out-of-bounds-off-edge-of-world/)).
- **Les:** weinig basisvormen, veel variatie via kleur en setdressing.

**Deep Rock Galactic**
- **Handgemaakte grotvormen**, gemengd met instellingen per biome: kleuren, ruis en setdressing ([Unreal-interview](https://www.unrealengine.com/developer-interviews/guns-gold-and-glory-in-the-caverns-of-deep-rock-galactic)).
- **Elke biome heeft één signatuur:** rode zoutkristallen, blauwe kristallen, groen uranium. In Sandblasted Corridors zijn dat zachte zandsteen, reusachtige fossiele beenderen en zandstormen ([wiki](https://deeprockgalactic.wiki.gg/wiki/Sandblasted_Corridors), [Hoxxes](https://deeprockgalactic.wiki.gg/wiki/Hoxxes)).
- **Kleur komt uit echt licht**, niet uit een tint over het hele scherm ([Waltorious](https://waltoriouswritesaboutgames.com/2023/06/21/rainbow-in-the-dark-deep-rock-galactic/)).

**Astroneer**
- **Low-poly zonder textures; de kleur doet het werk** ([blog](https://blog.astroneer.space/p/the-art-of-astroneer-low-poly/)).
- **Op Calidor heeft elke landvorm een eigen bodemkleur:** lichtoranje duinen, donkeroranje mesa's ([wiki](https://astroneer.fandom.com/wiki/Calidor)).
- **Les:** laat de kleur de landvorm en de hoogte tonen.

**No Man's Sky**
- **Terrein uit wiskunde:** domain warping en helling-erosie ([Murray, GDC 2017](https://www.gdcvault.com/play/1024514/Building-Worlds-Using)).
- **De keten:** voxels, dan polygonen, dan textuur, dan bevolking ([McKendrick, GDC 2017](https://www.gdcvault.com/play/1024265/Continuous_World_Generation_in__No_Man_s_Sky_)).
- **Worlds Part I (2024):**
  - gevarieerdere planeetvormen (bergen, diepe valleien, vlaktes) met minder herhaling;
  - rotsen en planten op de GPU, voor dichtere werelden ([Hello Games](https://www.nomanssky.com/worlds-part-i-update/)).
- **Exotische planeten hangen aan één herhaalde vorm:** pilaren, botspitsen of scherven ([TheGamer](https://www.thegamer.com/no-mans-sky-best-exotic-planets/)).

**Lethal Company**
- **Elke maan is handgemaakt door één ontwikkelaar.** Ze heeft:
  - één terreinthema;
  - een groot complex dat je vanaf de landingsplek ziet;
  - weer en mist.
- **Licht wijst de weg:** op Dine leidt een pad van lampen naar de ingang ([TheGamer](https://www.thegamer.com/lethal-company-every-moon-explained-tips-guide/)).
- **Les:** identiteit met weinig middelen.

**Outer Wilds**
- **Leegte mag, als ze bewust is.** Gladde, lege zones zonder blikvangers maken het ene torentje aan de kim des te sterker ([Verneau](https://www.pointnthink.fr/en/loan-verneau-creative-lead-at-mobius-digital-on-outer-wilds/)).
- **Les:** ons probleem is niet de leegte, maar dat er geen tegenpool is.

**Starfield**
- **Het oppervlak bestaat uit tegels van ±1 km** met POI's erop ([Starfield Portal](https://starfieldportal.com/article/starfield-player-explains-tiles-in-world-map)).
- **De grootste klacht is herhaling:** dezelfde plekken, notities en lijken op elke planeet ([ScreenRant](https://screenrant.com/starfield-shattered-space-pois-repetitive/)).

**Ook bruikbaar**
- **Breath of the Wild:** heuvels als driehoeken.
  - Grote zijn landmarks, middelgrote verbergen en onthullen, kleine zijn textuur.
  - Hoger betekent belangrijker.
  - Kleine dingen tussen de torens trekken je verder (door Nintendo "zwaartekracht" genoemd) ([Kotaku](https://kotaku.com/breath-of-the-wilds-biggest-design-secret-lots-of-tria-1819113140)).
- **Subnautica:** het wrak van de Aurora is van bijna overal te zien en wijst het oosten aan ([wiki](https://subnautica.fandom.com/wiki/Aurora)).
- **Horizon Zero Dawn:** plaatsing op de GPU volgens regels en dichtheidskaarten ([GDC 2017](https://gdcvault.com/play/1024700/GPU-Based-Run-Time-Procedural)).
- **Smith en Worch:** laat de speler zelf raden wat hier gebeurd is ([GDC 2010](https://gdcvault.com/play/1012647/What-Happened-Here-Environmental)).
- **Neil Blevins:** primaire, secundaire en tertiaire vormen, met rustplekken tussen het detail ([lessen](http://www.neilblevins.com/art_lessons/composition_primary_secondary_and_tertiary_shapes/composition_primary_secondary_and_tertiary_shapes.htm)).
- **Lynch:** paden, randen, wijken, knooppunten en landmarks maken een plek leesbaar ([samenvatting](https://www.architecturecourses.org/design/kevin-lynchs-5-elements-city-guide-urban-design)).

### Echte geologie als referentie

| Referentie | Wat we eruit halen | Voor |
|---|---|---|
| HiRISE: [gelaagde mesa in Arabia Terra](https://www.uahirise.org/ESP_059289_1890), [ritmische lagen in Danielson](https://science.nasa.gov/photojournal/rhythmic-layering-in-danielson-crater-on-mars/) | Trappen van harde en zachte lagen, met donker zand op de treden | Roestbol: wanden, mesa's |
| HiRISE: [sporen van stofduivels](https://www.uahirise.org/ESP_031199_2070), [een stofduivel van 20 km hoog](https://www.jpl.nasa.gov/news/12-mile-high-martian-dust-devil-caught-in-act/) | Donkere krullen op licht stof. Van boven herken je de stofduivel aan zijn schaduw | Roestbol: het dropbeeld |
| [Donkere duinen op een lichte kraterbodem](https://arxiv.org/pdf/2109.05711) | Donkere sikkels op licht: pure waarde | Roestbol |
| [Wadi al-Hitan](https://en.wikipedia.org/wiki/Wadi_al_Hitan) | Walvisskeletten die uit woestijnsediment eroderen, pilaren uitgeslepen door de wind, plateaus met steile randen | Fossielwereld |
| [De Witte Woestijn](https://thearabweekly.com/egypts-white-desert-natural-museum-chalk-rock-sculptures) | Paddenstoelen van krijt, door zandstralen gevormd | Fossielwereld: middelgrote vormen |
| [Dinosaur Provincial Park](https://en.wikipedia.org/wiki/Dinosaur_Provincial_Park) | Gelaagde badlands en hoodoos, met beenderen die eruit eroderen | Fossielwereld |
| [Salar de Uyuni](https://www.livescience.com/scientists-solve-mystery-behind-strange-honeycomb-pattern-in-salt-deserts) | Zeshoeken die van boven een patroon vormen | Kristalmaan: vlaktes (bij ons op een schaal van 10–30 m) |
| [Naica](https://en.wikipedia.org/wiki/Cave_of_the_Crystals), [straalkraters](https://en.wikipedia.org/wiki/Ray_system) | Kristallen tot 12 m; lichte stralen rond een jonge krater | Kristalmaan |
| [De maan op de terminator](https://www.nasa.gov/image-article/at-the-edge-of-light/), [diamond dust](https://en.wikipedia.org/wiki/Diamond_dust) | Een lage zon toont elk reliëf; glinsterend gruis in de lucht | Kristalmaan: licht en sfeer |

## 3. Regels voor onze planeten

### 3.1 Drie schalen

| Schaal | Grootte | Voorbeelden | Waar | Hoe gebouwd |
|---|---|---|---|---|
| **Macro** | 300 m – km | kraterrand, wand of escarpment, bekken, mesa, duinzee | Eén landvorm per concessie. Zijn rand ligt op 250–600 m aan één of twee kanten. Verder 2–3 silhouetplannen aan de kim | Hoogtefunctie in `PlanetShape` (nieuw), gebruikt door generator en ring |
| **Meso** | 10–200 m | ruggen, geulen, droge rivierbedding, rotsvelden (in clusters), spitsen, hoodoos, duinvelden, kristalclusters | Om de ±60–100 m één, gegroepeerd, met 30–40% rust ertussen. Zelfde dichtheid binnen en buiten de rand | Binnen: SDF-vormen (graafbaar). Buiten: ring en MultiMesh |
| **Micro** | < 10 m | rotsjes van 0,3–3 m, kiezels, barsten, ribbels, sporen | Enkel tot ±150 m van de camera. Van 300 m enkel als gemiddelde kleur | Shader en MultiMesh; binnen eventueel VoxelInstancer |

### 3.2 Het speelgebied in een landvorm

- **Groot en niet in het midden.** De landvorm is 750–1500 m groot. De concessie ligt naast zijn rand of op zijn bodem.
- **Geen vierkant herhalen.** Randen van landvormen zijn gebogen of schuin, nooit evenwijdig aan de assen. `far_height()` in `planet_surface.gd` vermijdt een kom rond het vierkant al bewust.
- **De voet van de landvorm komt het speelgebied binnen:** een terras, een puinhelling, een bedding, een ader. Zo loopt zijn vorm door tot onder je voeten.
- **Beperking:** in de generator ligt het oppervlak 30 voxels (15 m) onder de bovenkant van het volume. Binnen het speelgebied blijft het reliëf dus binnen ±15 m. Hogere dingen (wanden, spitsen, torens) staan erbuiten, tenzij het volume hoger wordt (open vraag 2).
- **Lijnen die het vierkant negeren:** een pijpleiding, een kristalader of een bedding loopt schuin door de concessie en verder. Het oog volgt de lijn, niet de rand.

### 3.3 Detail over de rand

- **Dezelfde verdeling aan beide kanten.** Kraters, rotsblokken en spitsen liggen op een hash-raster in wereldruimte (de hash van Hoskins, met een kleine seed: zie de lessen). Hetzelfde raster levert binnen voxels en buiten meshes.
- **Rotsblokken ook van boven.** Waar het voxelterrein niet geladen is, staan dezelfde rotsblokken als MultiMesh. Ze vallen weg waar de voxels er zijn, met dezelfde `near_cutoff`-truc als het raster nu.
- **Fijner raster in de ring.** Cellen van ≤ 4 m tot 450 m van het midden; nu zijn dat 7,8 m.
- **Uitdoven, maar geleidelijk.** De dichtheid dooft pas uit tussen 450 m en 1,5 km. Daarna tellen enkel silhouetten.

### 3.4 Landmarks

| Soort | Aantal | Grootte | Zichtbaar van | Voorbeeld |
|---|---|---|---|---|
| Groot | 1 per dienst | ≥ 30 m hoog of ≥ 150 m breed | van overal; in het dropbeeld op 300 m | boortoren, reuzenskelet, kristalspits, dagbouwput |
| Middel | 3–4, één per kwadrant | 10–30 m | van de grond, aan de kim | mesa-rest, wrak, spitsengroep, bord |
| Klein | om de 50–80 m in het speelgebied | 2–10 m | tot ±150 m | rotscluster, krater, bot, meetpaal, kist |

**Nakijken:** van op de landingsplek heeft elke richting van 90° minstens één silhouet boven de kim.

### 3.5 Kleur en waarde

1. **De hemel blijft het lichtste vlak.** Geen terrein mag bleker zijn dan de hemel erachter ([hemel.md](hemel.md) §2).
2. **Drie waardegroepen per beeld** (licht, midden, donker), plus één donker en één licht accent. Die accenten hangen aan landvormen, niet aan ruis.
3. **De kleur volgt de vorm** (Astroneer):
   - laagtes: donker zand;
   - hoogtes en randen: licht stof;
   - wanden: banden op hun echte hoogte.
4. **Warm licht, koele schaduw** in de tint van de hemel (teal of paars). Volgens Quilez is er buiten genoeg met drie lichten: zon, hemel en terugkaatsing, met occlusie enkel op het vullicht ([outdoors lighting](https://iquilezles.org/articles/outdoorslighting/)).
5. **Gereserveerde kleuren:**
   - DIG-geel `#F2B705` en baken-amber `#FFB45A` enkel voor DIG;
   - cyaan `#4FE3F0` enkel voor kristal (stijlgids).
6. **Rustvlakken:** 30–40% van het dropbeeld is egaal (stof, kalk, gruis).

### 3.6 Wat de dropcamera moet tonen

| Hoogte | Wat je ziet | Wat er moet zijn |
|---|---|---|
| **300 m** (bijna recht van boven, ±900 × 440 m, 0,5 m per pixel) | Macro | De rand van de landvorm als boog of wand in beeld. Drie waardegroepen. Het grote landmark met zijn lange schaduw. Eén DIG-lijn (pijpleiding of meetpalen). Sporen van de sfeer (stofduivels, mist). Geen detailrand rond het vierkant |
| **150 m** (in of net onder de stoflaag, ±500 × 250 m) | Meso | Rotsvelden in clusters, geulen, banden in de wanden, duinsikkels of hoodoos, de bakenring rond de landingsplek, middelgrote DIG-dingen. De waas wordt dunner: een onthulling |
| **50 m** (achter de staart, met de horizon) | Kim en diepte | Drie diepteplannen: een rug dichtbij, een mesa of wand in het midden, een verre reeks. Het grote landmark als silhouet. Micro-rotsjes rond de landingsplek |
| **Grond** (4 richtingen) | Oriëntatie | Een silhouet per kwadrant. Spreiding tot aan de kim (±350 m). Geen kale strook tussen het speelgebied en de verte |

## 4. De drie planeten

De kleuren hieronder zijn **doelkleuren op het scherm** (met een pipet te meten op een screenshot), zoals in [hemel.md](hemel.md) §5. Het albedo in de shader stem je af tot je die kleuren haalt. Volgens de stijlgids zijn er geen kleuren buiten de gids: deze paletten gaan er dus eerst in.

### 4.1 Roestbol (hemel A)

**Identiteit.** Een oude Marskrater met perzikkleurig stof, waar donkere duinen kruipen en een vorige DIG-ploeg een put achterliet.

| Rol | Kleur |
|---|---|
| Roest in de zon / in de schaduw | `#B5532E` / `#5A2E35` (A) |
| Licht stof op hoogtes en randen | `#D9A27E` |
| Donker basaltzand (duinen, sporen) | `#3E2626` |
| Banden in de wand (licht, midden, donker) | `#E0B48C`, `#B86A44`, `#7A3A2A` |
| Verre rand in de waas | `#C99A86` (A) |
| Horizon / waasband / krans | `#E8C49A` / `#F3D9B5` / `#A9C4D8` (A) |

**Macro.**
- Een krater van 1,2–2 km.
- De concessie ligt op de bodem, dicht bij de binnenwand.
- De gelaagde rand (60–120 m) maakt een boog op 250–500 m aan één kant.
- Andere recepten per seed: de voet van een gelaagde mesa, of een duinzee tussen yardangs.

**Meso.**
- Donkere barchanduinen aan de kant onder de wind.
- Yardangs: ruggen in de windrichting, 50–200 m lang en 5–15 m hoog.
- Trappen van puin onder de rand.
- Een droge geul die door de concessie loopt.

**Spreiding.**
- Gefacetteerde rotsen in 6 varianten (0,3–8 m), in clusters op hellingen en onder de rand.
- Plaatsteen op de terrassen.

**DIG.**
- Een oude dagbouwput naast de concessie: terrassen van 5 m, Ø 150–300 m.
- Een boortoren met een rood licht.

**Sfeer.**
- De stoflaag op 120–200 m ([hemel.md](hemel.md) §4).
- Eén tot drie stofduivels: een kolom, een spoor en een schaduw. Van boven zie je vooral het spoor en de schaduw.
- Soms een stofstorm als muur aan de kim ([haboob, 1–3 km hoog](https://www.pbs.org/newshour/science/3-things-to-know-about-haboobs-massive-dust-storms-in-the-southwest)).

**Herkenbaar van boven:** een perzikkleurige bodem met donkere sikkels en krullen, een gebogen gelaagde wand, en de terrassen van de put.

**Risico's.**
- Alles één tint: de waardegroepen moeten het dragen.
- Te veel een Mars-simulatie: hou het gestileerd, met facetten en grote vormen.
- De stofduivels zijn transparant: hou ze klein in beeld.

### 4.2 Fossielwereld (hemel B)

**Identiteit.** Een wit badland onder een teal lucht, waar reuzenskeletten uit de lagen eroderen: archeologie die je van boven al ziet.

| Rol | Kleur |
|---|---|
| Kalksteen in de zon / in de schaduw (koel) | `#E2CFA8` / `#7C8C8E` |
| Mergel, okerband | `#C9A46E` |
| IJzerband (roest) | `#B0482A` (B) |
| Grijsblauwe kleilaag | `#8C9AA0` |
| Versteend bot / glans | `#3A2A2E` / `#6B4A3A` |
| Lage stofmist in de geulen | `#E9B48F` (B) |
| Zenit / horizon / reus | `#1F5E6E` / `#BFE0D2` / `#B48FC4` (B) |

De kalksteen in de zon is iets donkerder dan de horizon, zoals de regel vraagt.

**Botten.** De botten zijn donker: versteend, zoals de beenderen in echte badlands. Bot in de stijlgidskleur `#E8DCC0` valt weg tegen kalk (open vraag 3).

**Macro.**
- Een terras onder een escarpment van 60–100 m met banden van roest, oker en crème.
- De wand buigt op 200–400 m rond één kant.
- Een droge bedding loopt schuin door de concessie.
- In de verte buttes (resten van het plateau).

**Meso.**
- Hoodoos en krijtpaddenstoelen van 3–15 m.
- Geulen in de wand.
- Een vlak van botfragmenten (ribben van 3–8 m die uit de grond steken) langs de bedding.

**Spreiding.**
- Platte kalkplaten en rotsblokken met banden.
- Kleine botjes, gegroepeerd, nooit uniform.

**Groot landmark.** Een reuzenskelet van 40–80 m dat half uit de wand komt, met een duidelijke schedel en ribbenkast.

**DIG.** Een bord: "FOSSILS ARE NOT SOUVENIRS. FOSSILS ARE INVENTORY."

**Sfeer.**
- Warme mist in de bedding en aan de voet van de wand.
- Je valt uit het teal in een warme stofzee, zoals hemel B op 340 m al beschrijft.
- Zandslierten die van de ruggen waaien.

**Herkenbaar van boven:** een crème bodem met een gestreepte wand en een donkere ribbenkast, en warme mist in een geul.

**Risico's.**
- Lichte grond onder een lichte horizon: weinig contrast en verblinding na AgX.
- Een skelet dat leest als losse stokken: de silhouetten moeten groot en onmiskenbaar zijn.
- Het skelet is een groot Blender-werk.
- De lagen onder de grond moeten mee veranderen (GDD §4: lagen per type).

### 4.3 Kristalmaan (hemel C)

**Identiteit.** Een kleine donkere maan in een eeuwig gouden uur, waar een kristalader door het bekken loopt die oplicht in de lage zon.

| Rol | Kleur |
|---|---|
| Basaltgruis in strijklicht / lange schaduw | `#8A5A4A` / `#35263F` |
| Lichte kristalkorst (zeshoeken op de vlaktes) | `#B8A2B6` |
| Kristal: lichaam / zonkant / binnengloed | `#D8CCF0` / `#FFD9A8` / `#4FE3F0` |
| Waas | `#D98F7A` (C) |
| Horizon aan de zonkant / van de zon weg / zenit | `#F2A65A` / `#6B5A8E` / `#2B2350` (C) |

**Macro.**
- Een ondiep bekken van 1–1,5 km. De rand is aan de zonkant goud belicht en aan de andere kant violet.
- De kristalader is een breuklijn met clusters van 5–60 m. Ze loopt schuin langs of door de concessie, en verder.
- Met een kleinere planeetstraal (10–15 km in plaats van 30 km) wordt de kromming zichtbaar: een "kleine maan" (open vraag 9).

**Meso.**
- Een jonge straalkrater met lichte stralen.
- Wanden van basaltzuilen (zeshoekig, zoals de korst).
- Kleinere kraters met kristallen op de rand.

**Spreiding.**
- Hoekig basalt.
- Kristalgroepjes van 0,3–3 m, enkel langs de ader en op de kraterranden.
- Lichte korst in zeshoeken van 10–30 m (in de shader).

**DIG.**
- Een verlaten kristalzaag.
- Een bord: "DO NOT LICK THE CRYSTALS (AGAIN)".

**Sfeer.**
- Geen wolken.
- Glinsterend kristalstof rond de camera.
- Een zonnezuil boven de lage zon.
- Glinsters op de kristallen, die flikkeren met de kijkhoek.
- Lange schaduwen, die tijdens de drop een grote schaduwafstand nodig hebben.

**Herkenbaar van boven:** een donkere violette grond met een schuine lijn die goud fonkelt, lichte stralen en heel lange schaduwen.

**Risico's.**
- Te veel emissie en bloom: enkel de binnengloed in de schaduw mag gloeien.
- Doorzichtige kristallen geven overdraw: maak ze ondoorzichtig met nep-doorschijnendheid (fresnel en emissie).
- Een te donkere grond: het oppervlak moet lichter blijven dan de grotten.
- Overlap met de kristallaag diep in Roestbol (cyaan aders): hier lavendel met goud.

### 4.4 DIG-setdressing (alle planeten)

| Ding | Grootte | Plaats | Van 300 m | Tekst (in het spel) |
|---|---|---|---|---|
| Verlaten boortoren | 30–45 m | 200–500 m | silhouet, rood licht, lange schaduw | "CONCESSION 7A — DEPLETED. THANK YOU FOR YOUR SACRIFICE." |
| Pijpleiding op schragen | Ø 1,5 m, lijn van 1–3 km | schuin door de ring, tot voorbij de kim | lijn plus schaduwlijn | "SLURRY LINE 3 — 412 KM TO PROCESSING" |
| Oude dagbouwput | Ø 150–300 m | naast de concessie | concentrische ringen | "PIT 7A-2: CLOSED. RECLAMATION BUDGET: 0" |
| Gecrashte Mol | 10 m, scheef | 100–300 m | een gele vlek | "ASSET M-07 WRITTEN OFF. COST DEDUCTED FROM CREW WAGES." |
| Landingsbakens | 6–8 lampjes, ring van 22 m | de landingsplek | doelring | "LANDING ZONE — PLEASE CRASH RESPONSIBLY" |
| Meetpalen met vlagjes | 2 m, rijen | schuine lijnen | een stippellijn | "SURVEYED BY DIG GEO DEPT. REMOVAL WILL BE INVOICED." |
| Reclamebord | 8 × 4 m | bij de landingsplek | een gele rechthoek | "THIS PLANET IS PROPERTY OF DIG. SO ARE YOU." · "SAFETY IS OUR #4 PRIORITY" · "DAYS WITHOUT INCIDENT: 0" |
| Paal van een concurrent | 3 m | zeldzaam | — | "CLAIM VOID — ACQUIRED BY DIG" |

**Regels tegen rommel:**
- Per dienst één groot ding en twee tot vier middelgrote, uit een pool per planeet. Nooit twee diensten na elkaar hetzelfde grote ding.
- Kleine dingen enkel in clusters rond de grote, zodat ze samen een verhaal vertellen.
- Ongeveer één dienst op tien een zeldzame grap ([drop-en-ophalen.md](drop-en-ophalen.md): de 50ste drop).

## 5. Techniek voor Godot 4.7 (mid-range)

Mid-range betekent hier de RTX 3060- of 4060-klasse, nog altijd de meest voorkomende kaarten op Steam ([guru3d](https://www.guru3d.com/story/steam-survey-april-2026-shows-rtx-3060-still-leading-gpu-market/)). De budgetten zijn eigen voorstellen en moeten op zo'n kaart gemeten worden.

| Onderdeel | Aanpak | Budget | Valkuil |
|---|---|---|---|
| **`PlanetShape`** (wereldfunctie) | Macrohoogte, maskers (rand, duin, strata, ader) en celrasters voor kraters, rotsen en spitsen. De generator gebruikt hem binnen, `PlanetSurface` erbuiten | ≤ 0,5 s extra op de werkthread | GDScript is traag: de macrovorm op een grof raster uitrekenen en interpoleren |
| **Verre ring** | Cellen van 2–4 m tot 450 m, daarna zoals nu. Per hoekpunt: holte, helling en masker (COLOR), en de hoogte vóór de kromming (UV2), zodat strata horizontaal blijven | alles samen ≤ 200k driehoeken (nu 80k + 18k) | Naden en T-verbindingen tussen fijn en grof (dezelfde randpunten delen, zoals nu) |
| **Schaduw tijdens de drop** | `directional_shadow_max_distance` volgt de hoogte, bv. tussen 140 en 700 m. Vier splits met blend. De ring werpt schaduw. Na de landing terug naar 140 m ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)) | schaduw van rotstegels enkel tot ±300 m | Pancaking en acne op grote driehoeken. Onder de grond moet alles terug zijn zoals nu (les: eerst onder de grond kijken) |
| **Macrokleur en strata** | Kleur uit maskers in plaats van de egale vlekken. Steiler dan 35°: banden op de hoogte vóór de kromming. Hoge frequenties uitdoven met `fwidth` ([Quilez](https://iquilezles.org/articles/bandlimiting/)). Een lichtere variant van `terrain.gdshader` voor de ring. Palet per planeet in `PlanetType` | geen voronoi verder dan 90 m | Grote seeds in shaderruis (les) |
| **Spreiding** | MultiMesh per tegel van 64 m en per mesh, deterministisch uit (seed, tegel). Regels: helling, hoogte, maskers, clusterruis, minimumafstand. Drie ringen: tot 150 m alles, tot 450 m de middelgrote en grote, tot 1,5 km enkel ≥ 15 m. `visibility_range_end` per tegel, met dithering in de shader | ≤ 150 draw calls, ≤ 30k zichtbare instanties, ≤ 400k driehoeken | Een MultiMesh wordt als geheel gecult en krijgt één LOD (het dichtste punt van zijn AABB): daarom tegels ([MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html), [LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)). Uitdoven met "Self" maakt het object transparant: dithering is goedkoper ([visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)) |
| **Binnen het speelgebied** | Rotsblokken blijven SDF in de voxels, zodat je ze kunt graven. Kleine versiering eventueel met `VoxelInstancer`: die werkt met `VoxelTerrain` (enkel LOD0) en verdwijnt waar je graaft ([docs](https://voxel-tools.readthedocs.io/en/latest/instancing/), [changelog](https://voxel-tools.readthedocs.io/en/latest/changelog/)) | — | In co-op testen of elke peer hetzelfde ziet |
| **Rotsen en landmarks** | Blender via Python. Rotsen: 6–8 per planeet, gefacetteerd, 60–400 driehoeken (groot ≤ 1500). Landmarks ≤ 20k driehoeken. LOD's maakt Godot automatisch bij het importeren van een glb. Een rotsveld van ver als één mesh (HLOD) | ≤ 10 landmarks in beeld | Impostors zijn bij low-poly niet nodig. Ooit wel: [godot-imposter](https://github.com/zhangjt93/godot-imposter) (MIT, dan in CREDITS.md) |
| **Sfeer** | Stoflaag: één transparant vlak met gaten. Stofduivel: een getwiste kegel uit code met scrollende ruis, plus een spoor en een schaduw als decal. Mist in de geulen: vlakken op vaste hoogte met depth fade. Kristalstof: GPUParticles3D enkel rond de camera | ≤ 2 grote transparante lagen tegelijk, ≤ 2k deeltjes | Overdraw over het hele scherm. Transparante dingen werpen geen schaduw |
| **Meten** | `drop_sequence` logt `RenderingServer.get_rendering_info()` (draw calls, primitieven) per vast beeld. Beeldcontroles in Python: detailenergie binnen en buiten het vierkant op het beeld van 300 m, en een waardehistogram | ≤ 1,5 M driehoeken en ≤ 1500 draw calls tijdens de drop, 60 fps op 1080p (mid-range) | Tijden van deze pc zijn geen bewijs; aantallen wel |

**Wat eerst bouwen**, omdat het de meeste kaalheid wegneemt voor het minste werk:
1. De meetbare controlebeelden (zie §6).
2. Schaduw tijdens de drop, en vertexholtes in de ring.
3. `PlanetShape` met de spreiding in wereldruimte (detail loopt door over de rand).
4. Macrokleur aan vormen gebonden.

Pas daarna de landvorm per planeet, de modellen en de sfeer. Externe addons zijn niet nodig. [Terrain3D](https://github.com/TokisanGames/Terrain3D) (MIT) is enkel een referentie voor "macro variation" in een shader.

## 6. Stappenplan

| Stap | Wat | Verificatie |
|---|---|---|
| 0 | Dit onderzoek; Jayme beantwoordt de open vragen | Jayme keurt de richting goed |
| 1 | **Concepten.** Per planeet een referentiebord (de foto's en games hierboven) en **waardeschetsen op de echte frames**: 026 (300 m), een beeld op 150 m, 046 (vlak voor de klap) en 067 (de grond). Overgeschilderd in drie waarden plus accenten: landvorm, landmark, DIG-ding, sfeer. Gemaakt in Python of Blender over de screenshot, of als AI-overschildering als Jayme dat goedvindt (open vraag 6) | Jayme kiest per planeet. Op geen enkele schets zie je de rand van het vierkant |
| 2 | **Techniekbasis zonder nieuwe look:** controlebeelden met cijfers, de schaduw tijdens de drop, `PlanetShape` met de huidige vormen, de attributen in de ring | Voor en na op dezelfde seed: gelijk, op de schaduw na. Alle tests uit CLAUDE.md slagen. Draw calls en driehoeken staan in de samenvatting |
| 3 | **Blokmodel van Roestbol vanuit de dropcamera:** enkel macro en grote meso (krater, rand, duinvelden, put) in vlakke paletkleuren, zonder fijne spreiding | 4 dropbeelden (300/150/50 m en vlak voor de klap) en 4 grondbeelden, op een voor/na-blad zoals `final_vs_voor_hoogtepunten.png`. Detailenergie buiten/binnen ≥ 0,7. `sky_preview --horizon` geeft 0 fouten. Jayme keurt |
| 4 | **Detail van Roestbol:** spreiding, strata, kleurmaskers, DIG-setdressing, stoflaag en stofduivels | Dezelfde beelden, plus close-ups op de grond en drie seeds naast elkaar (variatie). Het budget gemeten. Alle tests |
| 5 | **Fossielwereld als data** in `PlanetType` (recept voor de landvorm, palet, spreidingsset, setdressing, sfeer), plus het skelet | Dezelfde beelden. **Duimnageltest:** drie beelden van 300 m op 200 px breed, zonder naam, aan Jayme. Is de planeet herkenbaar? |
| 6 | **Kristalmaan**, op dezelfde manier | Idem |
| 7 | **Meting op mid-range** | Jayme of een tester met een kaart uit de RTX 3060-klasse: fps tijdens de drop en op de grond |

## 7. Open vragen voor Jayme

1. **De concessie:** helemaal verbergen, of van boven bewust tonen als DIG-claim (bakens of meetpalen in een vierkant)? Mijn voorstel: de rand van het terrein verbergen, de claim eventueel subtiel tonen.
2. **Mag het voxelvolume hoger worden** (bijvoorbeeld 40 m lucht erbij), zodat de voet van een wand of een kristalspits in het speelgebied kan staan en te graven is? Lucht kost weinig: lege blokken zijn uniform.
3. **Botten op Fossielwereld:** donker en versteend (leesbaar van boven), of crème zoals de vondsten nu?
4. **Kristallen op Kristalmaan:** lavendel met gouden glinsters en een cyaan binnengloed (zoals voorgesteld), of enkel goud en roze?
5. **Eén vaste landvorm per planeettype** (herkenbaar, goedkoper), of twee à drie recepten per type?
6. **Mogen concepten AI-overschilderingen zijn?** Ze komen niet in het spel. Anders worden het waardeschetsen uit code of Blender.
7. **Stofduivels en stormen:** enkel decor, of later ook een gevaar (een mutator, zoals de zandstorm in DRG)?
8. **De toon van de DIG-teksten en -verhalen** (de oude put, de afgeschreven Mol): klopt die?
9. **Een kleinere straal voor Kristalmaan** (10–15 km), zodat je de kromming ziet?
10. **Waar testen we op mid-range?**

## Zekerheid

- **Uit bronnen:**
  - de biomen en POI's van Helldivers 2, en de randgreppel (een speler, via TheGamer);
  - de biomen van DRG, Calidor, de manen van Lethal Company, Worlds Part I;
  - de geologie;
  - de Godot-documentatie over MultiMesh, LOD, visibility ranges en schaduw;
  - VoxelInstancer met `VoxelTerrain` (changelog 1.0).
- **Gemeten in onze code:**
  - de beeldhoek van de dropcamera, de schaduw tot 140 m, het raster van 7,8 m, 15 m lucht boven het oppervlak;
  - 80k driehoeken in het verre landschap.
- **Eigen voorstellen en schattingen:**
  - de paletten, maten, dichtheden en budgetten;
  - de 450 m van de dressing-ring;
  - de drempel van 0,7 voor de detailverhouding.
- **Niet gevonden:** uitleg van Arrowhead zelf over wat er voorbij de rand van een missie ligt. ArtStation en het Unreal-interview gaven een 403; wat daarover staat, komt uit de zoekresultaten.
