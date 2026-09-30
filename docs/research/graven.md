# Onderzoek: hoe graven goed aanvoelt

1 oktober 2026. Aanleiding: playtest M0, "graven voelt oké, maar het is gewoon klikken en er gaat een bolletje weg".
Twee onderzoeken: (1) hoe andere games het doen, (2) hoe het technisch vloeiend kan met godot_voxel 1.7. Wat afgeleid is en niet uit een bron komt, staat als *[afgeleid]*.

## Wat andere games doen

| Game | Wat we eruit halen |
|---|---|
| **Deep Rock Galactic** | Houweel: 1 slag per 0,7 s, hapt een brok "iets breder dan de speler, niet zo hoog". Hardheid = aantal slagen (1–3, bedrock 5). Zware slag: vasthouden + vuren, 30 s cooldown. Boor: 1,5 tikken/s van ±2 × 2,2 × 1 m, 50% trager lopen, hittemeter (oververhit na ±5,5 s, 8 s pauze). Spelers "tap-drillen" als ritme. Van klikken naar vasthouden gegaan: precisie werd lastiger. [wiki](https://deeprockgalactic.wiki.gg/wiki/Pickaxe) · [boor](https://deeprockgalactic.wiki.gg/wiki/Reinforced_Power_Drills) |
| **A Game About Digging A Hole** | Klikken is "snappy" en "oddly satisfying", maar geeft "pijnlijke vingers": spelers vroegen om vasthouden. Alle ertsen klinken hetzelfde. Zwevende restjes voxels blijven haken en een ruimte ziet er nooit "schoon" uit. [GameGrin](https://www.gamegrin.com/reviews/a-game-about-digging-a-hole-review/) · [Twin Geeks](https://thetwingeeks.com/2025/04/17/a-game-about-digging-a-hole-down-in-a-hole/) |
| **Astroneer** | Vasthouden = continu wegzuigen. Modi (graven, ophogen, vlakken). De Analyzer-uitbreiding graaft enkel één soort terrein: vergelijkbaar met onze korst. [wiki](https://astroneer.wiki.gg/wiki/Terrain_Tool) · [blog](https://blog.astroneer.space/p/augments/) |
| **Keep Digging** | Schop best op vloeren, houweel best op wanden (breedte hangt af van kijkrichting). Boor = vasthouden, maar smaller en minder opbrengst: dezelfde afweging tussen snelheid en buit als bij ons. [Steam](https://steamcommunity.com/app/3585800/discussions/0/840626862747102802/) |
| **Minecraft** | Barsten groeien in stappen op het blok. De archeologie-borstel: vasthouden, de vondst komt in 4,8 s geleidelijk tevoorschijn, met eigen geluid per materiaal en een afrondingsgeluid. Laat je los, dan loopt het terug. [breken](https://minecraft.wiki/w/Breaking) · [borstel](https://minecraft.wiki/w/Brush) |
| **Teardown** | Muren breken laag per laag (pleister → baksteen → brokjes). Het fysica-puin is een groot deel van het plezier. |
| **SteamWorld Dig** | Bewust tegels op spelergrootte, zodat je niet blijft haken aan kleine stukjes. [deep dive](https://www.gamedeveloper.com/design/game-design-deep-dive-the-digging-mechanic-in-i-steamworld-dig-i-) |
| **No Man's Sky / Space Engineers** | 3 vaste groottes, klein = beste opbrengst. Twee vuurmodi: "verzamelen" tegenover "vernielen" (snel, maar buit weg). |
| **PowerWash Simulator** | Een "ding" + flits wanneer een onderdeel helemaal schoon is. Anticipatie en beloning als kern. [80.lv](https://80.lv/articles/level-design-of-powerwash-simulator) |

## Wat er bij ons misloopt

1. Terrein verdwijnt **op het moment van de klik**, niet op een inslag. Er is geen gereedschap, geen zwaai en geen gewicht.
2. Altijd een **perfecte bol** van 0,9 m, gecentreerd op het oppervlak: een lens van ±0,9 m diep die wegfloept.
3. Geen feedback: geen stof, brokjes, schok of geluid.
4. De wanden zijn gladde blobs. Transvoxel kan geen detail kleiner dan één voxel (0,5 m) tonen; dat moet uit de shader komen.

## Technische feiten (godot_voxel 1.7, gecontroleerd in de broncode)

- `do_sphere`, `do_path`, `do_hemisphere` en `do_mesh` in MODE_REMOVE met `sdf_strength = 1` doen exact `nieuw = max(huidig, -kwast)`. Dat is **commutatief en idempotent**: onze netwerkaanpak (volgorde maakt niet uit) klopt.
- `sdf_strength < 1`, `grow_sphere` en `smooth_sphere` zijn **niet** commutatief of idempotent. Die dus niet gebruiken voor gesynchroniseerd graven. "Geleidelijk" graven doe je met **dunne happen** (kwastcentrum achter het oppervlak), niet met een halve sterkte.
- `do_path(punten, stralen)` tekent een afgeronde kegel per segment: één `do_path` per frame geeft een naadloze groef of boorkop.
- `do_*` werkt in voxelcoördinaten van het terrein; `VoxelToolTerrain.raycast` in wereldcoördinaten.
- Kosten: per **opnieuw gemesht blok per frame**, niet per op. Edits in hetzelfde blok in één frame vallen samen. De collision wordt nog altijd op de hoofdthread gebouwd (3–5× duurder dan meshen, [issue #124](https://github.com/Zylann/godot_voxel/issues/124) staat open). Budget: `voxel/threads/main/time_budget_ms` (8 ms).
- De officiële demo doet gewoon elk frame een grote `do_sphere`; er is geen voorbeeld van geleidelijk graven.
- Edits in niet-geladen gebied vallen weg, en zonder stream gaan bewerkte blokken verloren bij het ontladen. Nu is de hele put altijd geladen; later een `VoxelStreamMemory` of het op-logboek opnieuw afspelen.
- Netwerk: per netwerktick één "streep" per speler (gequantiseerde punten + straal), dedupliceren op (speler, streep, volgnummer). Varianten en rotaties uit een hash van dat id, nooit uit een RNG. Lokale voorspelling is veilig dankzij max-semantiek, maar kan niet teruggedraaid worden: valideer dus aan de clientkant op dezelfde manier.
- Wanden laten lijken op rots: triplanaire detail-normal-maps op 2 schalen ([Ben Golus](https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a)), en ruis in wereldruimte in de kwast (vaste seed, zodat naast elkaar liggende happen één ruw oppervlak vormen en de op deterministisch blijft).

## Patronen die werken (gerangschikt op impact)

1. **Houweel en boor zijn twee verschillende modellen.**
   - Houweel: ritmisch. Vasthouden = automatisch zwaaien (±0,55–0,7 s), een losse klik = één precieze slag. Terrein weg **op het inslagframe**, als een platte, ruwe schilfer langs de normaal, niet als een bol.
   - Boor: echt continu, dunne happen elk frame via een kegel (`do_path`), aanloop van ±0,2 s, trager lopen, hittemeter. Sneller dan het houweel, maar ruwer, luider, en het beschadigt buit.
2. **Gewicht bij de inslag:** 2–4 frames hit-stop, camera-kick, lichte schok die schaalt met de hardheid, gereedschap dat terugveert. *[afgeleid: standaard "juice"]*
3. **Puin in de kleur van de laag:** stofwolk en vonken, 2–6 kleine steentjes per slag (enkel cosmetisch, lokaal, verdwijnen na enkele seconden), en een continue gruisstraal bij de boor.
4. **Geluid per materiaal**, 3–5 varianten, ±5–10% toonhoogte. Een aparte "klink" wanneer je een korst of vondst raakt. De boorloop verandert onder belasting.
5. **Voortgang op de korst:** meerdere slagen per schilfer, met zichtbare barsten. Klaar = "ding" + oplichten van de vondst.
6. **Richthulp:** een markering van wat er gaat verdwijnen, en een vizier dat van toestand verandert (buiten bereik, hard, korst, "boor beschadigt vondst").
7. **Schone geometrie:** gangen op spelergrootte, en geen zwevende snippers die blijven haken.

## Valkuilen

- Terrein weghalen bij de invoer in plaats van bij de inslag; uniforme bollen.
- Enkel klikken (vermoeiend) of enkel vasthouden (geen precisie).
- Eén geluid voor alles.
- Kwasten kleiner dan ±1 voxel: die floepen in plaats van te groeien.
- Een boor die gewoon beter is dan het houweel.
- Fysisch puin dat via het netwerk gaat: puin blijft lokaal, enkel terreinbewerkingen worden gesynchroniseerd.
