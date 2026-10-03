# Een schip bouwen met scripts (Blender) zonder dat het een doos wordt

Onderzoek voor De Ekster, 2026-10-03. Aanleiding: de eerste versie van het schip was een achthoekig prisma met cilinders erop, en binnen een rechthoekige hangar met platte wanden. Jayme vond dat letterlijk een doos, en daar was geen onderzoek aan voorafgegaan. Dit document gaat over *hoe* je zo'n model met code bouwt en controleert.

Wat het schip moet *zijn* (vorm en indeling) staat in [schip-ontwerp.md](schip-ontwerp.md).

De API-namen zijn nagekeken op de lokale Blender 5.2.1, headless. Een proef heeft gewerkt: een romp lofted met `bridge_loops`, een MANIFOLD-boolean, bevel met `harden_normals`, Weighted Normal, een Geometry Nodes-boom vanuit Python, en silhouetrenders met Workbench.

## 1. Waarom de vorige poging een doos was

De vorige poging had drie problemen:

- **Geen versmalling.** Het silhouet van opzij en van boven was een rechthoek.
- **Geen hiërarchie.** Alle onderdelen waren ongeveer even groot en even kaal.
- **Grote vlakke wanden.** Er waren geen platen, geen verdiepte panelen en geen schaduwlijnen.

Professionals werken altijd in deze volgorde: eerst het silhouet, dan de tweede laag vormen, dan pas de details. Je blokt uit op ware grootte, met een mens als maatstaf, en je controleert het silhouet uit meerdere hoeken voor er detail bijkomt ([80.lv, CGMA-ruimteschip](https://80.lv/articles/004adk-005cgcgma-student-project-a-spaceship)).

Ontwerp voor de camera's die het schip echt zien. De Ekster wordt vooral van onderen gezien: vanaf de planeet, en van dichtbij tijdens de drop. **De buik en het zijprofiel zijn de belangrijkste kanten**; het bovendek mag eenvoudiger.

## 2. Vormregels

**Drie maten van vormen.** Er zijn grote massa's, middelgrote vormen erop, en kleine details. Een goede spreiding over die drie leest prettig ([Neil Blevins](http://www.neilblevins.com/art_lessons/composition_primary_secondary_and_tertiary_shapes/composition_primary_secondary_and_tertiary_shapes.htm)).

**70/30, nooit 50/50.** Deel vormen ongelijk, en duw het detail naar één kant ([Blender Bros](https://www.blenderbros.com/blog/the-most-important-rule-in-3d)).

**Ongeveer 30% detail, 70% rust.** Dichte clusters geven het oog houvast; de lege vlakken laten het rusten.

**Geen baksteen.** Dit is een samenvatting, geschreven als regels die een script kan volgen:

- De romp is een loft door 6 à 10 doorsneden die variëren in breedte, hoogte, hoogteligging en afschuining. De neus en de staart lopen af tot 20 à 40% van het midden.
- Geen loodrechte zijwanden: 5 à 15° uitlopend of naar binnen, met zwaar afgeschuinde boven- en onderhoeken.
- Lege ruimte: 3 à 5 grote massa's (romp, motorblok, brugtoren, zijkassen, staartboom), verbonden met smallere halzen of pylonen. Zo valt er licht tussen, en er komen overhangen.
- Eén sterk asymmetrisch element op een symmetrische basis, zoals een kraanarm, een brug die uit het midden staat of een antennemast.
- Vanuit de naam: een ekster heeft een wigvormige kop, een lange staart (ongeveer de helft van de lichaamslengte) en zwart-wit vlakken met blauwgroene glans. Een lichte buik zie je precies vanaf de grond.

**Panelen volgen de bouw.** Naden liggen waar vormen veranderen en waar het ding in het echt uit stukken zou bestaan. Details volgen de naden ([Polycount](https://polycount.com/discussion/170822/spaceship-car-panelling-methods)).

**Gelaagde platen tegen vlakke wanden.** Losse schalen 5 à 15 cm van de romp, met een dikte en een afschuining. Elke plaat geeft een schaduwlijn en een trapje in het silhouet, zoals het pantser van een keverslak ([Nature](https://www.nature.com/articles/s41467-019-13215-0)).

**Afschuiningen per laag** (eigen vuistregel uit de bronnen). We kijken met een verticale FOV van 80°. Bij 1080p geeft dat:

| Afstand | Pixels per meter | Gevolg |
|---|---|---|
| 340 m | ±1,9 | het schip is ±95 px lang; niets onder 0,5 m is zichtbaar |
| 20 m | ±32 | |
| 5 m | ±129 | |

Breedte van de afschuining per laag:

| Laag | Breedte |
|---|---|
| Romp | 0,15–0,4 m |
| Platen | 0,05–0,1 m |
| Kleine details | 0,02–0,04 m |

1 segment geeft de facetten van DRG, 2 à 3 segmenten het ronde van Astroneer. Voor de slijtage in de vertexkleuren zijn minstens 2 segmenten nodig, anders smeert de rand over het hele vlak ([PropGon](https://propgon.com/en/hard-surface-modeling-blender-game-art-guide/)).

**Kleine details in clusters.** Leg ze in groepjes, in verdiepte panelen, bij de motoren, de baai, de kraan en de brug, en nergens anders. Leg de meeste in de rijrichting en draai er één dwars om op te vallen ([Rebel Scale](https://www.rebelscale.com/techniques/adding-greeblies/)).

**Schaal tonen.** Een schip van 50 m leest als 50 m door zaken op mensenmaat ([Creative Bloq](https://www.creativebloq.com/sci-fi/video-game-spaceship-design-21619331)):

- rijen kleine ramen (0,6 × 1 m) per dek, om de 3 à 4 m;
- deuren van 1,2 × 2,2 m;
- relingen, ladders en navigatielichten.

**DRG en Astroneer.**

- DRG gebruikt hoekige, gefacetteerde vormen die hun polygonen tonen, bijna niets ronds, en sterk licht-donkercontrast ([Steam](https://steamcommunity.com/app/548430/discussions/1/4956744526887613964/), [Unwinnable](https://unwinnable.com/2018/08/28/deep-rock-galactic/)).
- Astroneer gebruikt geen texturen: enkel vlakke kleur, vertexkleur en licht ([Unreal](https://www.unrealengine.com/en-US/spotlights/how-system-era-softworks-leveraged-ue4-to-create-astroneer-s-wonderful-universe)).
- Wij blijven bij vertexkleur (slijtage, holtes, kleur per eiland) plus enkele materialen. Godot-decals gebruiken we enkel voor sjablonen en gevarenstrepen.

## 3. Technieken in code

**Romp als loft (de hoofdtechniek, getest).**

- Maak ringen met evenveel punten en dezelfde draairichting, en verbind ze met `bmesh.ops.bridge_loops`. Sluit de uiteinden met `edgeloop_fill`.
- Strijk de doorsneden glad (Catmull-Rom), niet de mesh. Zo blijft de romp gefacetteerd maar toch gebogen.
- Bewaar per vlak (u, v): het segment langs de lengte en rond de ring. Dan wordt het panelenpatroon gewoon rechthoeken in (u, v), zoals in shape grammars ([Müller e.a. 2006](https://dl.acm.org/doi/abs/10.1145/1179352.1141931)).

**Andere vormen.**

- **Ronde motorkappen:** een grove kooi met Subdivision Surface (met creases), toepassen, `dissolve_limit` en dan bevel.
- **Buizen, relingen, een staartboom of een mast:** een curve met `bevel_mode`, `taper_object` en `use_fill_caps`.
- **Snelle stutten:** de Skin-modifier.
- **Symmetrie:** de helft bouwen en spiegelen; het asymmetrische deel komt erna.

**Platen, panelen en ramen.**

- **Plaat:** vlakken dupliceren, Solidify (0,08–0,15 m, `offset=1`, even offset, rim), 3 à 8 cm optillen, en daarna Bevel.
- **Verdiept paneel:** `inset_region` met `depth` negatief.
- **Ramen en lampjes:** `inset_individual` en daarna het emissieve materiaal.
- **Referentiecode (MIT):**
  - [Sci-fi-Panels](https://github.com/joshuabloemer/Sci-fi-Panels) snijdt met `bisect_plane` en extrudeert de stroken.
  - [SpaceshipGenerator](https://github.com/a1studmuffin/SpaceshipGenerator) kiest details volgens de richting van het vlak: motoren op de buik, ramen op de zijkant. Bruikbaar als patroon, maar de ruwe uitvoer is generiek.

**Booleans die werken.**

- Blender 5.2 heeft de solver MANIFOLD: snel en robuust, maar alle delen moeten gesloten zijn ([CG Channel](https://www.cgchannel.com/2025/07/blender-4-5-lts-is-out-check-out-its-5-key-features/)).
- Snijders zijn gesloten en hebben hun schaal toegepast. Laat ze 1 à 5 mm uitsteken (nooit op hetzelfde vlak). Gebruik één boolean met een collectie snijders, niet tien na elkaar.
- Volgorde: Boolean, dan Bevel, dan Weighted Normal. Na het toepassen opruimen: `remove_doubles`, `dissolve_degenerate`, `recalc_face_normals` ([Artisticrender](https://artisticrender.com/boolean-modifier-problems-and-how-to-solve-them/)).

**Normalen.** Bevel met `harden_normals` en `miter_outer='MITER_ARC'`, Weighted Normal (`keep_sharp`) als laatste ([handleiding](https://docs.blender.org/manual/en/latest/modeling/modifiers/generate/bevel.html)). Zo is er geen normal map nodig; zo werken ook Star Citizen en Alien: Isolation (mid-poly).

**Geometry Nodes vanuit Python** werkt headless (`GeometryNodeTree`, sockets, `InstanceOnPoints`, toepassen). Het is handig om klinknagels, roosters en lampjes langs een curve te zetten, met Realize Instances als laatste stap. De namen veranderen per Blender-versie, dus we blijven bij 5.2 ([CGWire](https://blog.cg-wire.com/blender-scripting-geometry-nodes-2/)). Het alternatief is Array met `FIT_CURVE` plus een Curve-modifier.

**Vertexkleur.** `FLOAT_COLOR` wordt correct geëxporteerd (0,5 blijft 0,5). Na een Blender-update opnieuw testen ([glTF-IO #542](https://github.com/KhronosGroup/glTF-Blender-IO/issues/542)).

## 4. Het interieur: een bouwdoos, geen dozen

**Regels voor een bouwdoos** ([Skyrim, Game Developer](https://www.gamedeveloper.com/design/skyrim-s-modular-approach-to-level-design), [Level Design Book](https://book.leveldesignbook.com/process/blockout/metrics/modular)):

- vaste maten die veelvouden van elkaar zijn;
- vaste deurkozijnen;
- gangen minstens 2× zo breed als een speler;
- vloeren met echte dikte.

**Maten** ([Level Design Book](https://book.leveldesignbook.com/process/blockout/metrics)):

| Onderdeel | Maat |
|---|---|
| Deur | 1,1–1,25 × 2,2–2,5 m |
| Trap | treden van 15 × 25 cm, helling 30–35°, een bordes om de 12 à 16 treden |

**Voorstel voor De Ekster:**

- Een raster van 2 m, met modules van 4 m in de hangar.
- Drie hoogtes: 3 m (gangen), 6 m (terminal, museum) en 9 à 12 m (hangar). Zo ga je van laag en donker naar hoog en licht ("compression and release", [Livingetc](https://www.livingetc.com/advice/compression-and-release-architecture)).
- Stukken:
  - vloer en wand;
  - wand met deur en wand met raam;
  - binnen- en buitenhoek;
  - zuil;
  - plafond, ook met lamp;
  - een spant om de 4 m (geeft ritme);
  - een loopbrug met reling van 1,05 m;
  - een trap;
  - opvulstukken.
- De stukken gaan als één glb naar Godot en worden daar geplaatst volgens een indelingstabel. Collision: simpele dozen, en hellingen in plaats van treden.

## 5. Zelf controleren voor Jayme het ziet

**Geometrie:**

- geen niet-gesloten randen;
- geen losse punten of nulvlakken;
- normalen naar buiten;
- geen n-gons groter dan 8;
- het aantal driehoeken per deel.

**Silhouet (Workbench, orthografisch, zwart op wit, ±0,1 s per beeld):**

| Meting | Grens |
|---|---|
| Vulling van de bounding box (een doos is 1,0; een eenvoudige loft gaf 0,71) | vlag boven 0,8 |
| Convexiteit (inkepingen) | onder 0,9 |
| Aandeel van de omtrek dat horizontaal of verticaal loopt (een baksteen is dat bijna helemaal) | vlag boven 60 à 70% |
| Grootste vlakke stuk | vlag boven ±8% van de buitenkant |

Verder een **duimnageltest**: herken je het silhouet nog op 64 px ([Disney](https://www.waltdisney.org/sites/default/files/2020-05/T&T_Silhouette-final2.pdf))?

De grenzen zijn een startpunt. Ze worden bijgesteld op het eerste ontwerp dat Jayme goedkeurt.

**Beelden:**

- een draaiende Workbench-reeks (8 à 12 beelden, met holtes en schaduw);
- twee beelden met de echte camera: vanaf de grond op 340 m, en van op 10 à 30 m tijdens de drop;
- daarna in Godot, met venster (headless toont niets).

**Budget:**

| Onderdeel | Budget |
|---|---|
| Buitenkant van dichtbij | 60–150k driehoeken, in 8 à 15 meshes per zone (dan valt wat buiten beeld is weg) |
| Grove versie voor veraf (vanaf ±150 m, met `visibility_range`) | 3–8k |
| Interieurstukken | 200–3.000 per stuk, hergebruikt |

Godot maakt zelf ook LOD's ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html)). `OccluderInstance3D` werkt het best met veel kleinere ruimtes.

## 6. Werkwijze voor De Ekster

1. **Opdracht als data:** lengte 48 à 56 m, de binnenruimtes die de romp moet omvatten, de dropbaai, en de twee camera's.
2. **Een schip als parameters:** de doorsneden, en welke massa's er zijn (staartboom, zijkassen, brug uit het midden, motoren, vorm van de baai, vinnen).
3. **Ontwerpvoorstellen voor Jayme:**
   - 9 à 12 varianten, enkel de grove loft;
   - per variant silhouetten (zijkant, boven, voor), een beeld van schuin onder, een duimnagel en de metingen;
   - samen op één genummerd blad;
   - Jayme kiest, daarna 1 à 2 rondes variaties daarrond;
   - het silhouet ligt vast voor er detail bijkomt.
4. Romp als loft, gespiegeld en gecontroleerd.
5. De tweede laag: motoren, brug, zijkassen, staartboom, pylonen en één asymmetrisch element.
6. Panelen: ongelijke verdeling, 20 à 30% opgetilde platen, enkele verdiepte panelen, en de baai met een boolean.
7. Schaal: ramen, deuren, relingen en navigatielichten.
8. Kleine details enkel bij de motoren, de baai, de kraan en de brug, met voorrang voor de buik.
9. Afwerking: afschuiningen per laag, normalen, slijtage, controles, meshes per zone en de grove versie voor veraf.
10. Interieur uit de bouwdoos.
11. Elke build maakt silhouetten, metingen, een draaiende reeks, de twee camerabeelden en de budgetcijfers. Daarna een screenshot in Godot.

## Licenties

- Wat wij met Blender maken is van ons. Scripts die bpy gebruiken moeten GPL-compatibel zijn als je ze verspreidt ([blender.org](https://www.blender.org/about/license/)).
- MIT: SpaceshipGenerator, Sci-fi-Panels, [Building Tools](https://github.com/ranjian0/building_tools).
- GPL-3.0: [Geometry Script](https://github.com/carson-katri/geometry-script), [NodeToPython](https://github.com/BrendanParmer/NodeToPython).
- We gebruiken ze als voorbeeld en schrijven zelf. Wat we toch overnemen, komt in `CREDITS.md`.
