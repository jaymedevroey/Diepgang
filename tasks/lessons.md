# Lessen

Wat we onderweg leerden en wat het GDD bijstuurt. Nieuwste bovenaan.

## 2026-10-05 — Alles in het Engels: woordenlijst

Jayme: alle tekst in het spel in het Engels, ook de namen. Docs, commentaar en logregels blijven Nederlands; Nederlandse identifiers (`PlanetType.Id.ROESTBOL`) en dev-opties (`--planet=roestbol`) mogen blijven. Getallen met een decimale punt (12.5 m). Hou de DIG-humor: idiomatisch vertalen, niet woord voor woord.

| Nederlands | Engels |
|---|---|
| De Ekster (het schip) / De Mol | The Magpie / The Mole |
| Roestbol / Fossielwereld / Kristalmaan | Rustbowl / Fossil World / Crystal Moon |
| DIG, Diepgang | DIG, Diepgang (namen blijven) |
| opdracht / concessie / dienst / kwartaal / quota | contract / claim / shift / quarter / quota |
| kas (teamkas) / boete / bonus / netto | funds (team funds) / fine / bonus / net |
| incidentrapport / risico laag, middel, hoog | incident report / risk LOW, MEDIUM, HIGH |
| vondst / gaafheid / erts / korst / puin | find / condition / ore / crust / rubble |
| houweel / boor / sonar, PING | pickaxe / drill / sonar, PING |
| vertrekhendel, VERTREK / aftellen / luiken / baai | launch lever, LAUNCH / countdown / hatches / bay |
| laadruim / trechter / ertszak | cargo hold / hopper / ore bag |
| grijper / ophalen / noodophaling / achterblijven | grapple / pickup / emergency extraction / left behind |
| beving / onrust / voorschok / onstabiele zone | quake / unrest / foreshock / unstable zone |
| vervangrobot / smelten | replacement robot / melt |
| taxatie / verkoopluik / automaat / kast | appraisal / sell hatch / vending machine / locker |
| laadrek / werkdek / gang / spuitcabine / brug / opdrachttafel / kade / hangar | loading rack / work deck / corridor / paint booth / bridge / contract table / quay / hangar |
| klei / zandsteen / graniet / kristal | clay / sandstone / granite / crystal |
| Spatie · overslaan | Space · skip |

## 2026-10-05 — Bouwtijd van een wereld, en de planeet in het speelgebied

- **De drop wachtte niet op het verre landschap.** Enkel op het voxelterrein: wie snel na het kiezen de hendel trok, viel in een vierkant zonder omgeving. Nu wacht alles op `Game.world_ready()` (terrein én landschap); ook de tests (die wachtten op `terrain.is_loaded` en faalden daarna 24 keer).
- **GDScript op veel draden tegelijk is trager dan op weinig.** Het voxelterrein genereerde met 12 draden (godot_voxel: de helft van de 24 logische kernen) GDScript, en die houden een globale vergrendeling van de engine bezet (objectaanroepen). Al het andere GDScript op een werkthread werd tot 15× trager: het verre landschap 7–12 s in plaats van ±1 s. Met 4 draden (`voxel/threads/count` in project.godot) laadt het terrein zelf ook sneller: bij de start 1,2–1,5 s in plaats van 2,7–4,3 s, een nieuwe planeet staat er in 1,8–2,6 s (was tot 12 s). 2 draden is weer trager.
  - Gemeten met `--scenario=surface_bench --contended --idle`. Een eigen kopie van de generator hielp niet (het is geen gedeeld object, het is de engine). Eerst het landschap en dan het terrein (na elkaar) was met 12 draden beter, met 4 niet meer.
  - **Op een mid-range pc opnieuw meten** (M5): daar zijn het standaard ook 4–6 draden, maar met minder kernen.
- **De kleur van de landvorm vervaagde rond het speelgebied bewust naar neutraal**, omdat het voxelterrein geen tint kreeg. Daardoor zag je de rand toch. Nu bakt PlanetSurface de tint over het speelgebied in een kleine textuur (2 m per texel) voor het voxelterrein, en vervaagt er niets meer: duinen en stofsporen, de bedding, de korst (met naden op hetzelfde zeshoekrooster als de platen erbuiten) en de stralen lopen door.
- **Vormen in het speelgebied via een raster:** `Landform.near_height` (duinen, een bedding) wordt bij het maken van de wereld op een raster van 3 m gebakken (±20–50 ms op de hoofdthread) en de generator leest het bilineair uit. Rechtstreeks de landvorm aanroepen vanuit de voxeldraden kan niet (gedeelde toestand, en elke objectaanroep kost daar veel).

## 2026-10-04 — Drie planeten (Roestbol, Fossielwereld, Kristalmaan)

- **"Kaal" kwam van een detailsprong aan de rand, niet van te weinig driehoeken.** Binnen het speelgebied kraters en rotsen, erbuiten een glad raster: het oog ziet waar het detail stopt. Daarom staat het speelgebied nu IN een landvorm (kraterwand, klif, bekken met een kristalader), en lopen vlekken in de grondkleur over de rand heen.
- **Van 300 m was er nergens schaduw** (de zon tekende schaduw tot 140 m). Nu groeit de schaduwafstand mee met de hoogte (sky.cfg drop_shadow_m).
- **Hoekpuntkleuren zijn 8-bit (0..1):** een tint boven 1 (lichter maken) viel weg. De tint gaat er gehalveerd in en de shader verdubbelt (gevonden door de kristal-agent).
- **MultiMesh-kleuren met vertex_color_use_as_albedo hebben `vertex_color_is_srgb` nodig**, anders worden ze roze-wit.
- **GDScript zonder `fract()` en met een ongetypeerde `floor()`:** `x - floorf(x)`; en een variabele uit een ongetypeerde lijst (`for level in [0.25, ...]`) moet je zelf typen.
- **Een landvorm-functie op een werkthread:** objectaanroepen en allocaties zijn er 10–100× trager dan rekenen (FastNoiseLite-aanroepen, een nieuwe PackedArray per hoekpunt). Ruis vooraf in een tabel, geen allocaties per hoekpunt.
- **De bouwtijd van een wereld is enkel vergelijkbaar onder dezelfde omstandigheden:** de eerste wereld bij de start (±0,5 s) tegenover een wereld na een opdracht terwijl het voxelterrein streamt (2–9 s, sterk wisselend als er meer Godot-processen draaien).
- **Concepten met AI-overschilderingen van het echte dropbeeld** (Higgsfield, ±1,5 credit per beeld) gaven Jayme in één keer een richting om op te bouwen.
- **Drie agents, elk één planeet in een eigen bestand (landform_<planeet>.gd)**, met de gedeelde code (shader, palet, generator) bij de lead: samenvoegen gaf geen enkel conflict, en de agents gaven precieze voorstellen voor de gedeelde bestanden.

## 2026-10-04 — De verhoging stond pal voor de gang

- **Na uren polijsten vond Jayme in één blik wat wij misten:** de verhoging met de opdrachttafel stond recht voor de uitgang van de gang. Ze is Ø 5,8 m (met de treden) en de brug is maar 5 m diep, dus waar ze staat, vult ze de hele diepte. De level-agent meldde zelfs dat robots daar vastliepen, en de lead verschoof toen de terminalplek in plaats van de verhoging zelf.
- **Eerst de looproute, dan pas details.** Voor elke ronde: vanuit elke deuropening op ooghoogte recht vooruit kijken langs de hoofdroute (laadrek → werkdek → gang → brug → trap → Mol). Wat de route blokkeert, verplaats je bij de bron, je loopt er niet omheen.
- **Meld een agent "vast bij X", vraag dan of X zelf op de verkeerde plek staat.**
- Opgelost: de verhoging staat nu aan bakboord (x 3,3), tussen de wand en de trap naar de kade. Gang → trap en brug → galerij zijn vrij. Alles op de verhoging (terminalplek, scherm, hologram, kroon) is nu relatief tot `DAIS`, zodat ze nog eens kan verhuizen.

## 2026-10-03 — Kritische ronde: interieur en drop (vijf agents: art, level, cine, horizon, QA)

- **Eerst onderzoeken met beelden, dan pas bouwen.** Een opnamescenario (`drop_sequence`) legde de hele overgang vast (terminal → kiezen → aftellen → val → landing → besturing, plus vaste camera's op 340/160/60 m). Pas daarmee werd "het grote vierkant" meetbaar: het verre landschap hield op 492–696 m van de landingsplek op, en van hoger dan ±55 m zag je de hemel eronder.
- **Het vierkant was geen mistprobleem.** Oorzaak: eindig, plat terrein tegen een gebogen hemelhorizon, plus twee verschillende mistmodellen. Mist alleen had ≥95 % nodig op 600 m en had dan ook de landingsplek begraven. Opgelost met een verre ring tot 6,5 km die met de planeet meebuigt (o²/2R), en een automatische controle "geen hemel onder de horizonlijn" (`sky_preview --horizon`).
- **De witte lijn rond het speelgebied** was de hemel door een kier van 0,5 m: de rok stond verkeerd om, en Godot telt kloksgewijs als voorkant.
- **Grote seeds breken shaderruis**: een seed van ±762.000 × 7,31 past niet in 32-bit floats, en het voronoi-patroon werd een regelmatig raster op de landingsplek.
- **Na een sprong de gezette plek van de Mol lezen (`Mol.placed`), niet zijn body**: de buitencamera stond één beeld lang 1,4 km verderop, in de hub. Dat gebeurde bij iedereen, ook bij de host.
- **`pow()` van een licht negatief getal geeft NaN**; in een additieve shader werd dat een witte bol door de gloed.
- **Eén convexe botsvorm per vondst kostte ±45 ms**: 158 vondsten bevroren het spel 8–12 s na het kiezen van een opdracht. Nu één vorm per soort, gedeeld (0,46 s).
- **Sonarcontacten overleven een nieuwe wereld niet**: de id's worden hergebruikt en wezen naar vrijgegeven vondsten (honderden fouten per seconde). `Sonar.reset()` bij een nieuwe wereld.
- **Een capsule blijft hangen in de hoek tussen een helling en een deurstijl.** Robots liepen van de gang schuin naar de terminal en bleven daar vastzitten. Opgelost door de plek van de terminal te verplaatsen, de stijl af te schuinen en de botsvorm van de muur vlak te maken. Getest met echte invoer en de fysica, vanuit zes richtingen.
- **E-knoppen keken door muren** (de straal botste niet tegen de hub). Nu een zichtlijncontrole.
- **Een drop moet op een speler wachten die de wereld nog bouwt**, anders valt die client in het niets (`Game.world_ready_everywhere()`).
- **Opnames rekken de speltijd** (10–47 fps tijdens het opslaan). Duur dus altijd in speltijd meten, nooit uit de tijd in de bestandsnamen.
- **De gebruikslimiet stopte alle vijf agents tegelijk.** Ze verder laten gaan met SendMessage werkte zonder werk te verliezen: elk had zijn eigen worktree.
- **Elk horizontaal onderdeel toetsen aan ooghoogte (vloer + 1,2 m)**: de balk onder het terminalscherm sneed het beeld bij de belangrijkste handeling precies doormidden.

## 2026-10-03 — De binnenkant van De Ekster (met vijf agents)

- **Wacht met bouwen tot het onderzoek af is, en toon eerst de plattegrond.** Ronde 2 (gebouwd vóór het onderzoek klaar was) kreeg een onnodig hoge hangar van 16 m. Ronde 3 ging plan → blokmodel → details, en het plan werd in één keer goedgekeurd.
- **Wat Jayme schrapt, blijft weg.** Het museum ("hoeft nog niet") dook toch op als skeletten en vitrines in een blokmodel. Een geschrapt idee hoort in de opdracht aan elke agent als expliciet verbod.
- **Eerst een gedeelde basis, dan parallel werken.** `layout.py` (maten, helpers, en het contract van namen met het spel), `build.py` (overleeft een zone die faalt) en één bestand per zone. Elke agent werkt in een eigen worktree aan enkel zijn bestanden; samenvoegen gaf geen enkel conflict.
- **Agents vinden elkaars fouten.** De schermagent zag dat het taxatiescherm dwars door de poort stak, het firmabord achter de spanten zat en de tafel het hologram half verborg; de werkingsagent zag dat de ringtreden van de verhoging niet te beklimmen waren. Doorgeven aan de agent die het bestand bezit, terwijl hij nog bezig is (SendMessage), werkt goed.
- **Een capsule (straal 0,35) klimt geen trede van 0,15 m** zonder stapcode. Trappen in de botsvorm altijd als helling; de speler kan nu ook lage randen opstappen (`step_height` in `player.cfg`), enkel tegen de hub.
- **Een .cfg schrijven met PowerShell `Set-Content -Encoding utf8` zet er een BOM voor**, en dan laadt het hele tuningbestand niet.
- **Python op Windows schrijft standaard CRLF** (`open(p, "w")`). Voor bestanden in de repo altijd `newline="\n"`.
- **Agents delen één scratchpad.** Een testscript van de ene agent overschreef dat van een andere. Elke agent een eigen submap geven.
- **Drie agents kozen elk een eigen `ScreenAmber`.** Nieuwe paletnamen per zone: in Blender wint de laatste `PALETTE.update`, in Godot staat er één in `MolVisual`. Nieuwe materialen bij het samenvoegen meteen in `MolVisual.MATS`/`EMISSIVE`, anders ziet de game het ruwe glb-materiaal.

## 2026-10-03 — De Ekster, de drop en de hemel

- **Eerst onderzoek, dan ontwerpen, dan bouwen.** Het schip uit een plattegrond in code (dozen) was een doos, en Jayme walgde ervan. Pas na onderzoek (voorbeelden, vormregels, hoe artiesten het bouwen) en een ontwerp in klei dat hij goedkeurde, werd het iets. Voor elk nieuw groot model: onderzoek in `docs/research/`, dan enkel de vorm (klei) tonen, dan pas details.
- **Meer details maken een doosvorm niet mooier.** Drie Nostromo-ontwerpen met honderden details bleven "blokken aan elkaar". Wat werkte: verhoudingen afmeten op één sterk voorbeeld (de Super Destroyer, van opzij en van onder), schuine vlakken, lange lijnen, open ruimte tussen massa's.
- **Ontwerpen tonen in de echte look van de game** (`concept_preview`: machine-shader, hemel, licht, de echte camerahoeken), niet als grijze Workbench-klodders.
- **Blender start niet in de repo:** een relatief uitvoerpad (`logs/x.png`) kwam in `C:\logs\`. Paden in scripts altijd tegen de repo oplossen.
- **`kit._MATS` bewaart materialen:** na `read_factory_settings` zijn ze weg (ReferenceError). Leegmaken bij een nieuwe scène.
- **Een AnimatableBody met `sync_to_physics` loopt een tick achter**: wie meerijdt met de verplaatsing per tick, zakt bij een snel stijgende Mol steeds verder door de vloer. Tijdens drop en ophalen zit je nu vast op een vaste plek in de Mol. Meet in tests na de physics-tick (`process_frame`), anders zie je een tick verschil.
- **Gaten in het terrein vallen pas op met een lichte hemel.** Waar het voxelterrein nog laadt, zie je de hemel onder de horizon. Met de oude donkerbruine hemel leek dat op een plas, met de nieuwe op een wit meer. Previews wachten nu tot het terrein gemesht is. Het grove raster van het speelgebied valt in de shader weg dichter dan 90 m (daar ligt het echte terrein), zodat het geen gaten of tunnels afsluit.
- **De hemel is het lichtste vlak** (Carlson). Een donker zenit boven zonnige grond maakt alles bruin. Hemellichamen staan áchter de atmosfeer: `lucht = achtergrond × T + (1 − T) × waas`.
- **Een sprong van de Mol (hub ↔ buitenschip):** wie meerijdt, moet expliciet mee (signaal `snapped`), en daarna een paar ticks vast blijven: de botsvorm van de Mol komt pas een tick later aan, anders val je door de vloer.
- **Waarom een AnimatableBody achterloopt:** met `sync_to_physics` zet Godot de node na `global_transform = x` meteen terug op de vorige plek; de nieuwe plek staat pas na de physics-stap in de node. Wie dezelfde tick `body.global_position` leest, krijgt de oude plek. Zo stuurde de host na de sprong naar de hub nog één pakketje met de plek onder het buitenschip, de client schoof de Mol daardoor 1.400 m omhoog in plaats van te springen, en de client viel eruit (1 op 4 runs). Nu houdt de Mol de laatst gezette plek bij (`Mol.placed`) en stuurt die door. Nettest daarna 8 op 8.
- **Onder de grond was alles zwart, en geen test zag het.** Atmosphere zet de zon uit onder de grond; dan is `LIGHT0_DIRECTION` in de hemelshader nul, en `normalize(0)` geeft NaN. Die NaN zat in de weerkaatsing van elk materiaal: enkel emissie bleef over. Les: na een wijziging aan hemel of licht ook een beeld **onder de grond** bekijken, niet enkel aan de oppervlakte. Alle tests slagen met een zwart scherm.
- **Previews zonder speler** (terrain_preview, magma_preview) bleven zwart: het laadscherm verdwijnt pas als je speler spawnt. Nu sluit het ook als er geen speler komt.
- **`queue_free` haalt een kind niet meteen weg.** `while get_child_count() > 3: get_child(0).queue_free()` liep eindeloos bij de vierde melding kort na elkaar, tot het geheugen vol was (PCRE2 "no more memory", stille crash). Eerst `remove_child`, dan `queue_free`.
- **`sin()`-hash op de GPU geeft naden** bij grote coördinaten (wereldmeters): rechte lijnen door een voronoi-patroon. De hash van Dave Hoskins (zonder sin) heeft dat niet. En F2 − F1 in 3×3 geeft ook naden: gebruik de echte afstand tot de rand (IQ, 5×5).
- **Vondsten werden opgezocht op hun plaats in de lijst** (`items[id]`). Zodra het magma er één weghaalt, wijst elke id naar de verkeerde vondst. Nu een woordenboek op id.
- **Verval vóór de drempelcontrole** haalt een volle trap net onder de 100: de beving kwam nooit als het stil was. Eerst de drempel, dan het verval.
- **Een vlak gevaar heeft een rand nodig**: zonder de gloeiende rand in de rotsshader (waar rots en magma elkaar raken) leek het magma een plaat die door de rots steekt.
- **Commit nooit als een test in dezelfde run faalde,** ook niet als hij "meestal" slaagt: commit 8e853db ging mee met een wankele `net_ship_test`.
- **ENet verbreekt standaard na 5 s zonder antwoord.** De nettest faalde 2 op 3 toen de pc trager was (terrein laden 8 s i.p.v. 4 s, ook op de oude commit gemeten): de client hing bij het opbouwen van de wereld en werd buitengegooid. Nu 20–60 s geduld per peer (`NetSession._patient`).
- **Godot-mist kan geen nevel die met de hoogte van de camera verandert** (de hoogtemist hangt enkel af van de hoogte van het punt). Voorlopig schaalt de dichtheid met de hoogte van de camera. Een eigen mist in de terrein-shader (`FOG`) zet de volumetrische mist in de grotten uit; dat is uitgesteld.

## 2026-10-03 — Grote planeet met streaming

- **GDScript-lambda's kunnen geen twee waarden teruggeven**: `return p, -1` in een lambda die als argument meegaat, wordt gelezen als een extra argument van de aanroep ("Too many arguments"). Een Array teruggeven.
- **Een effect in een shader eerst bekijken van dichtbij**: de ertsfonkels waren als confetti (vierkante cellen van 7 cm, 40% aan). Kleine ronde fonkels (3 cm, ±14% aan) en een zachte verkleuring lezen als erts.
- De nettest duurt langer met streaming (beide kanten laden): limiet 180 s (scenario) / 220 s (net_test.py).

- **godot_voxel 1.7x, eenheden (gemeten):** `VoxelViewer.view_distance` is in **wereldeenheden** (meter bij een terrein met schaal 0,5), `VoxelTerrain.max_view_distance` in **voxels**. Eerst gaf ik voxels aan de viewer: alles tot 220 m laadde.
- **Laden gebeurt in een kubus rond de viewer**, afgerond op datablokken (8 m). Een punt op 120 m schuin is dus nog geladen. Tests met "ver weg" moeten langs één as verder dan view_m + 8 m liggen, of met een kleinere view_m.
- **Bewerkingen kunnen vlak na het laden verloren gaan** als viewers overlappen (speler in de Mol): een laadantwoord voor een blok dat al bestaat overschrijft het volledig (`apply_data_block_response` → `try_set_block`, gezien in de broncode). Gemeten: 1 op 4–6 keer. Oplossing: ops zijn idempotent, dus na elke op en na elk geladen blok 4 s lang één voxel per op nakijken en zo nodig opnieuw toepassen (`ops_repaired`). Enkel vertrouwen op `block_loaded` is niet genoeg (komt soms voor het blok bruikbaar is).
- **VoxelStreamMemory** houdt bewerkte blokken bij als ze ontladen worden; ops voor niet-geladen gebied wachten per datablok en gaan in het logboek bij ontvangst (voor late joiners).
- **Vangnet voor buit: een "veilige plek" moet echt in de lucht liggen.** Net onder het oppervlak losgelaten (een speler in de wand) zakte een vondst door de botsvorm, en het vangnet zette hem telkens terug in de grond. Nu: last_safe enkel bij sdf > 0, en terugzetten zoekt omhoog tot er ruimte is.
- **De host moet ruimer valideren dan de client zichzelf beperkt** (host_slack ×2): met streaming heeft de host langere frames en komen ops gebundeld binnen; één geweigerde (al voorspelde) op = een andere wereld bij de client.

## 2026-10-02 — Repo op GitHub

- **De GitHub-koppeling (MCP) mag geen repo aanmaken** (403 "Resource not accessible by integration"). Wel: `gh` via winget, Jayme logt één keer in met de apparaatcode (github.com/login/device), daarna `gh repo create --private --source . --push` en `gh release create`.
- Repo: https://github.com/jaymedevroey/Diepgang (privé). Builds gaan als zip in een Release (niet in git: de exe is 109 MB, boven de limiet van 100 MB per bestand).
- In `builds\windows` blijven `~RF….TMP`-kopieën achter van overschreven bestanden: niet meezippen.

## 2026-10-01 — Sonar in de Mol

- **Een hulpmiddel dat je naar iets toe leidt, verandert wat spelers ermee doen.** Met de sonar rijd je recht op vondsten af, en de boorkop boorde er dwars doorheen: de korst bleef in de Mol zweven (de test zag de vondst op Mol-hoogte). Bij elke nieuwe "kijk"-functie nagaan wat er gebeurt als spelers hem volgen tot het einde. Hier: de boorkop schept op, beschadigd (zelf uitbikken blijft lonen).
- **Een scherm in de wereld is vanuit de stoel klein.** Eerst de hoek uitrekenen (afstand, FOV, pixels per graad) en dan pas het ontwerp: 1 mm = 1 pixel op het scherm, tekst ≥ 40 px, blips ≥ 7 px. De kast werd daarvoor 15% groter.
- **Vage echo's laten het doel verspringen** tussen twee vondsten op bijna dezelfde afstand. Hysterese: een ander wordt pas doel als hij duidelijk dichterbij is.
- **GDScript: geen eigen methode `_set` noemen**: dat is de virtuele `Object._set(property, value)`.
- **Een nieuw `class_name`-script** is headless pas bekend na `--import` (klassencache); anders "Could not find type".
- Echo's in wereldruimte bewaren en elke frame in kop-boven omrekenen: draait de Mol, dan draaien de blips mee, zonder te wachten op de volgende veeg.
- **Zelf spelen vond een oude fout die geen test zag:** met de neus omlaag tot tegen de buitenmuur van de put kwam rots in de cabine. `make_sphere_op` schuift een bol die niet in het graafbare deel past naar binnen; de Mol boorde dus "raak" maar de romp bleef in de rots. De buitenmuur moet voor de Mol tellen als ondoorboorbaar (`TerrainAPI.sphere_fits`), net als graniet. En buiten de wereld is `is_solid` false: "geen rots", dus gaf hij zelfs gas.
- **Een proefring moet zo breed zijn als wat erdoor moet**: de rupsen liggen op 3,11 m van de as, de ring op 2,4 m. Rots daartussen zag hij niet, de steun tilde hem op en de cabine schoof in onbeboorde rots.
- **`is_solid` (dichtste voxel) en `sdf_at` (geïnterpoleerd) zijn het oneens op de rand.** Een rompunt met sdf +0,15 telde als rots: zo'n "1 punt" in een test is echt (de rots raakt de wand), maar wisselvallig. Een wisselvallige test eerst 3-4 keer draaien en de punten loggen.

## 2026-10-01 — Gereedschap, vondsten en puin

- **Een eigen `vertex()` in een shader moet `POSITION` in elke tak schrijven.** Enkel in de viewmodel-tak schrijven liet alle andere meshes met die shader verdwijnen (de Mol was onzichtbaar).
- **Een GLB statisch instantiëren om er meshes uit te halen lekt** als je de scène niet vrijgeeft: mesh + transform bewaren en `root.free()`.
- **Kleine voorwerpen op de machine-shader**: de ruis voor slijtage en vuil is op Mol-schaal gemaakt. Op een houweel werd het vlekkerig: `detail_scale` (×7) en minder slijtage (0,35 voor gereedschap, 0,7 voor vondsten).
- **Soort per vondst uit de seed en de laag** (`FindKinds.pick_kind`): elke peer kiest dezelfde, zonder netwerkverkeer.
- Puin als echte rotsbrokjes (lage ico-bollen met ruis) leest meteen als rots; kubusjes leken op Minecraft.

## 2026-10-01 — Rots en licht

- **Willekeurig gekantelde voronoi-facetten lezen als tegels of glas-in-lood**, zeker met lijnen op de randen. Wat wél werkt voor de DRG-look: de normaal afronden op een rooster van richtingen (gekwantiseerde normaal). Een gebogen wand valt dan uiteen in vlakken die zijn vorm volgen, en buurvlakken lijken op elkaar, zoals een grof gemodelleerde rots.
- **Een helmlamp vlak naast de camera belicht alles frontaal**: vlakken verschillen dan nauwelijks. Contrast moet ook uit de kleur komen (tint per vlak, bolle randen licht, holtes donker). Test met een tunnel en een scherende kijkhoek, niet met een close-up van een wand.
- **Gladde geometrie verraadt alles.** De boorkop van de Mol maakte perfecte buizen. Een paar extra boldeuken per boorbol (door de host berekend en in de op meegestuurd) maakt ruwe wanden, deterministisch en met de snelle native `do_sphere`.
- **Afstand tot de voronoi-grens**: F2−F1 is geen afstand en geeft ongelijke, dikke lijnen. Exact: (d2² − d1²) / (2·|c2 − c1|).
- **`AO` met `AO_LIGHT_AFFECT` tekent alles wat je in AO steekt ook in het licht**: celranden in AO werden donkere veelhoeken. Enkel echte holtes erin.
- **Afschuining die de kanteling naar nul brengt aan een celrand tekent een omtrek** (het licht springt terug). Liever harde grenzen tussen vlakken.
- Glow met bloom > 0 laat alles gloeien; bloom 0 en enkel emissie boven de HDR-drempel. SSAO werkt enkel op ambient tenzij `ssao_light_affect`.
- Een eerlijke voor/na: een tijdelijke `git worktree` op de vorige commit, met dezelfde preview erin gekopieerd.

## 2026-10-01 — HUD en menu's

- **UI-maten zonder stretch-modus zijn pixels**: op 1440p werd alles klein. `display/window/stretch/mode = canvas_items`, basis 1920×1080, aspect `expand`.
- **Een laadscherm met `MOUSE_FILTER_STOP` dat nog vervaagt, vangt de klik waarmee je de muis wil vangen.** Bij het vervagen op IGNORE zetten, en de muis meteen vangen zodra je in de put staat.
- **Esc in menu's via `_input`, niet `_unhandled_input`**: een knop met focus verwerkt `ui_cancel` zelf.
- **`DisplayServer.keyboard_get_keycode_from_physical` bestaat niet headless** (fout per frame). Toetsnamen cachen en headless de fysieke code tonen.
- **Testen met computer use:** `open_application` start een *tweede* exemplaar als de game al draait (toetsen gaan dan naar het verkeerde venster): eerst alle exemplaren afsluiten. De **Escape-toets komt via computer use niet aan** in de game (andere toetsen wel; vastgesteld met `--log-keys`). Esc daarom headless testen met een echt event (`ui_test`). Absolute muissprongen geven grote rukken in een first-person camera: kleine stapjes.
- Vertexkleuren uit Blender in Godot met `vertex_color_is_srgb`, anders veel te licht.

## 2026-10-01 — De Mol

- **Een test die enkel zittend meerijdt, bewijst niets over staand meerijden.** Jayme stond in de rijdende Mol: hij gleed 4 m weg en zijn blik draaide 180° mee. De vloer van een AnimatableBody neemt een CharacterBody niet mee in draaiing. Oplossing: wie in de Mol staat, krijgt elke tick de verplaatsing en draaiing van de Mol erbij (`Player._ride_mol`), platformsnelheid uit, en de Mol simuleert vóór de spelers (`process_physics_priority`). Elke fix nu eerst met een test die zonder de fix faalt.
- **Toestand die je onthoudt tussen ticks (hier: de Mol-positie voor het meerijden) moet je wissen bij elke overgang** (gaan zitten, uitstappen, teleporteren). Anders kreeg je na een rit de hele verplaatsing in één keer en viel je door de map. Vangnet: wie onder y = −10 valt, komt terug in de Mol. Tests mogen de speler na een actie niet zelf verplaatsen: dat verborg deze fout.
- **Een lang voertuig dat rond zijn midden draait, zwaait met kop en staart door de tunnelwand.** Over de hele lengte vrijschaven bij elke 3° draaien of kantelen. Let op het teken: offsets langs `forward()` zijn + naar de kop, lokale z is − naar de kop (eerst gespiegeld: de kop werd niet vrijgeschaafd en de camera zat in de rots). Tests moeten tot het uiterste puntje meten.
- De eerste `net_test` meteen na een scriptwijziging faalde één keer en slaagde daarna 5× op rij; vermoedelijk bouwen host en client tegelijk de scriptcache. Bij een fout: eerst opnieuw draaien en de uitvoer lezen.
- **Geen anti-aliasing + elk frame het model 1 cm verschuiven (trillen) = zinderende "glitch".** MSAA 4× aan, trillen enkel met de camera.
- **Coplanaire vlakken flikkeren** (vloerplaat op exact de hoogte van de uitgesneden romp). Altijd een paar mm afstand.
- **Een lamp in het voorvlak van zijn eigen behuizing, met schaduw, verlicht niets** (camerascherm bleef zwart). In de preview leek het te werken door stof voor de camera.
- **Gereedschapsstralen moeten de Mol meetellen**, anders graaf je van binnenuit door de wand.
- **Zelf spelen met toetsenbord en muis (computer use) vindt dingen die scripts missen**: de stoel was niet te vinden, het scherm zwart, de straal door de wand. Doen vóór een build naar Jayme gaat. Let op: AZERTY, dus vooruit = Z.

- **Blender headless:** `join` verloor objectposities → wereldmatrix rechtstreeks in de meshdata zetten. Na het verplaatsen van objecten eerst `view_layer.update()`, anders klopt `matrix_world` niet (een wiel stond op de oorsprong).
- **Open meshes (kegels) krijgen soms binnenstebuiten normalen** van `recalc_face_normals`: expliciet naar buiten zetten.
- **Slijtage uit vertexkleuren alleen werkt niet op grote vlakken:** een vlak met enkel hoekpunten interpoleert de "rand"-waarde over het hele vlak (dunne platen werden camouflage). Oplossing in de shader: kromming per pixel `length(fwidth(NORMAL)) / length(fwidth(VERTEX))` × vertexkleur.
- **AnimatableBody3D met `sync_to_physics`:** een verplaatsing van buiten een physics-tick wordt overschreven (het lichaam leest zijn positie terug uit de physics). Verplaatsen via `Mol.teleport()`. Een tweede AnimatableBody als kind onder een bewegende visuele hiërarchie belandde op een onzinplek: de klep is nu een vorm van het Mol-lichaam zelf.
- **Steun op voxelterrein:** de SDF rond een uitgeboorde bol is ±5 cm ruis. Zonder dode zone tilde de steun de Mol telkens op en daalde hij nooit. Dode zone [-0,12; +0,2] m.
- **Fysica-objecten op een rijdend platform** (22°, 6 m/s) schuiven, slapen of krijgen klapschade. Vastsjorren in Mol-ruimte zolang hij rijdt is betrouwbaar.
- **Deeltjes aan een rijdend voertuig in wereldruimte** belanden in het voertuig (de Mol rijdt door zijn eigen gruis). Kopdeeltjes in lokale ruimte, naar buiten spattend; enkel het stofspoor achteraan in wereldruimte.
- **Een console die van de bestuurder wegkantelt, zie je vanuit de stoel van opzij.** Paneel 35° naar de bestuurder, knoppen erop, opschriften erbij.
- **SubViewport-textuur op een mesh staat ondersteboven** t.o.v. de UV's uit Blender: `1 - UV.y` in de shader.
- Headless tests: invoer die op `MOUSE_MODE_CAPTURED` wacht, werkt niet headless; daar een uitzondering voor `DisplayServer.get_name() == "headless"`.

## 2026-10-01 — M1 stap 1-6

- **Netwerk: wat de client voorspelt, moet de host altijd aanvaarden.** Terrein wegnemen is niet terug te draaien. Daarom doen client en host exact dezelfde gereedschapscontrole (`TerrainSync.tool_allows`) en weigert de client zelf voor hij voorspelt.
- **Speltijd ≠ echte tijd** (tot 20% verschil in headless). Validatie op de host in echte tijd met ruime marge onder het echte tempo van het gereedschap, anders weigert hij eerlijke spelers.
- **Losse fysica-objecten kunnen door de binnenkant van het terrein vallen** (concave collider, geen volume). Vangnet: vastzitten in de rots of onder de put = terug naar de laatste veilige plek.
- **Plaatsing uit de seed** (vondsten) spaart netwerkverkeer, maar vraagt regels die op elke peer gelijk zijn (min. afstand tussen vondsten: korsten overlapten eerst).
- Spelerstoestand enkel sturen naar peers met een geladen wereld (anders "node not found"-fouten bij wie nog laadt).
- Godot-RPC: getypeerde arrays als parameter vermijden; `Array` of `Packed*Array` gebruiken.
- GDScript: `:=` faalt op waarden uit een ongetypeerde node (`game.terrain.…`): expliciet typeren.
- Lange Python-edits niet als Bash-heredoc (breekt op quotes): als bestand in de scratchpad zetten en uitvoeren.
- **`Path.write_text` schrijft op Windows CRLF** (tekstmodus). Git zet het in de index om naar LF (`.gitattributes`), maar de werkbestanden blijven CRLF. Altijd `write_text(..., newline="
")`.
- Windows-console (cp1252): geen `→` of andere niet-ASCII-tekens in `print` van hulpscripts, of `sys.stdout.reconfigure(encoding="utf-8")`.

## 2026-10-01 — Houweel (graafgevoel)

- **Playtest-les: "technisch klaar" is niet "af" voor Jayme.** Een zwart scherm met een bolletje oogt als niks, ook al werkt alles. Bij elke build die Jayme test: vooraf zeggen wat hij wel en niet mag verwachten, en zelf eerst screenshots bekijken.
- Screenshots van het spel neem ik zelf: `-- --autodig --pitch=-30 --shot=naam --frames=47,600`. Zo zie ik elke visuele wijziging voor Jayme ze ziet.
- Een schilfer met eigen kwast (copy → max → paste van het SDF-kanaal) werkt en blijft commutatief. `is_solid()` rondt af naar de dichtstbijzijnde voxel (0,5 m): voor ondiepe bewerkingen testen met een straal, niet met één punt.
- Helmlamp exact op het oog = geen zichtbare schaduw in putjes. Hoger en opzij zetten (zoals op een helm) maakt reliëf leesbaar.
- Gereedschap in beeld: `use_z_clip_scale` + `use_fov_override` (Godot 4.5+) tegen door muren steken, plus een eigen vullicht op renderlaag 2, anders is het zwart buiten de lampkegel.
- Stof als egale radiale schijf leest als een lichtflits. Ruistextuur + lage alpha werkt beter.
- **Bekend probleem (bewust gelaten, Jayme 2026-10-01):** schilfers kunnen dunne, zwevende plaatjes terrein achterlaten, vooral aan het oppervlak. A Game About Digging A Hole kreeg daar kritiek op. Mogelijke oplossingen: `separate_floating_chunks` (VoxelTool), of na een schilfer dunne restjes (<1 voxel dik) mee wegnemen.

## 2026-10-01 — M0 stap 2–7

### Besluit renderertest (stap 7)
Twee screenshots van dezelfde tunnelscène: `logs/render_forward_plus.png` en `logs/render_gl_compatibility.png`.
- **Forward+ is en blijft de doelrenderer.** De agent draait op Jayme's pc en ziet Forward+ zelf (Vulkan, RTX 4090): screenshots via `--scenario=render` of `--shot=naam`.
- In **Compatibility** ontbreken volumetrische mist (Godot waarschuwt zelf), SSAO, SSR en SDFGI. De gloed van emissieve kristallen en lava werkt er wel, net als de schaduw van de helmlamp, gewone mist en de lagen-shader. Het beeld is in grote lijnen hetzelfde.
- Gevolg: effecten mogen Forward+-only zijn, zolang het spel in Compatibility nog leesbaar blijft. Een Compatibility-fallback voor zwakke pc's of de Steam Deck beslissen we in M5.
- De lavapipe-test uit GDD §12 is niet meer nodig.

### Performance
- Stresstest (4 gravers × 8 ops/s + 30 objecten) op de RTX 4090: gemiddeld 0,63 ms per frame, maximaal 8,7 ms. Graven kost ±0,6 ms extra in het frame waarin het gebeurt. Ops worden per physics-tick gebundeld (±4 per tick).
- **Dit zegt niets over een mid-range pc.** Het budget is er ruim, maar de meting moet in M5 herhaald worden op zwakkere hardware. De stresstest kan ongewijzigd op elke pc draaien.
- In release-builds geeft `OS.get_static_memory_usage()` 0 terug (Godot houdt dat enkel in debug-builds bij). Geheugen dus meten in de editor of via Taakbeheer.

### Extensies en export
- **De eerste import na het toevoegen van een GDExtension eindigt met een segfault bij het afsluiten.** De import zelf is dan al klaar, en de volgende runs lopen normaal. Dat gebeurde bij godot_voxel en bij GodotSteam. Onschadelijk, maar schrik er niet van.
- **godot_voxel `v1.7x` heeft geen `template_debug`-DLL:** `windows.debug` wijst naar de editor-DLL. Release-exports werken, debug-exports zijn niet getest.
- **Headless release-builds** geven bij het afsluiten een stroom `Parameter "material" is null` (dummy-renderer die `VoxelTerrain` opruimt). Enkel headless en onschadelijk.
- **De shader-baker werkt enkel bij een export met GPU:** exporteer dus niet headless. `tools/export_windows.cmd` doet dat goed. Met baker is het pck ±2,2 MB, zonder 71 KB.
- Export-preset: `data/tuning/*.cfg` staat expliciet in de include-filter (geen resources, anders ontbreken ze).
- **GodotSteam 4.22.1 in plaats van 4.20.x (GDD §9):** nieuwste GDExtension, Steamworks SDK 1.65, drop-in. `steamInitEx(app_id, embed_callbacks)` met app_id 480 werkt zonder `steam_appid.txt`.

### Code
- **Vector2/Vector3 zijn 32-bits floats.** Tijdstempels (`Time.get_ticks_*`) daar niet in bewaren: door de afronding kan een verstreken tijd licht negatief uitvallen. De snelheidslimiet verloor zo in de release-build een token. Gebruik gewone floats (64-bit).
- Het terrein-node heeft schaal 0,5 (1 voxel = 0,5 m). `TerrainAPI` rekent wereldcoördinaten om naar voxelruimte. `do_sphere` en `get_voxel_f` werken in voxelruimte.
- De `PitGenerator` vult blokken ver van elk oppervlak uniform, zonder per-voxel-werk. Daardoor laadt de hele put in ±2 s, ook met een generator in GDScript.
- Fysieke toetscodes (`physical_keycode`): WASD wordt op AZERTY vanzelf ZQSD.

## 2026-10-01 — M0 stap 1

- **De agent draait op Jayme's pc zelf en ziet de echte renderer.** Godot opent Vulkan 1.4 Forward+ op de RTX 4090. Het risico "de agent ziet de echte look niet" (GDD §12) is daarmee grotendeels weg: screenshots en Movie Maker-opnames in Forward+ kan de agent zelf maken.
  - **Maar:** een RTX 4090 zegt niets over performance op een mid-range pc. Performancecijfers van deze machine gelden als ondergrens, niet als bewijs. Test op mid-range blijft nodig (M5).
- **GodotSteam staat op Codeberg.** De GitHub-releases bevatten enkel modulebuilds (eigen editor + templates). De GDExtension-releases (`vX.Y-gde`) staan op codeberg.org/godotsteam/godotsteam.
- **godot_voxel heeft twee soorten 1.7-releases:** `v1.7` is een custom Godot-build met de module, `v1.7x` is de GDExtension (voor Godot 4.5+). Wij gebruiken `v1.7x`, zodat de officiële Godot-editor en exporttemplates blijven werken.
- De `python` in PATH wijst naar een hermes-venv. Voor projectscripts `py -3.11` gebruiken, of een eigen venv in `tools/.venv`.
- Godot-editor staat in `%LOCALAPPDATA%\Programs\Godot\4.7.2\`. Aanroepen via `tools\godot.cmd`.
