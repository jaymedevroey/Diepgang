# Onderzoek: rots en licht

1 oktober 2026. Vraag: hoe krijgen we gestileerde rots en grotlicht mooi (DRG + Astroneer + PEAK, "licht is de held") op ons Transvoxel-terrein met voxels van 0,5 m, in Godot 4.7.2 Forward+?
Werkwijze: webbronnen gelezen, bron per bewering. *[afgeleid]* = mijn eigen conclusie, niet uit een bron. **Niet geverifieerd** = de bron kon ik niet openen of vond ik niet.

**Huidige stand.** `game/src/terrain/terrain.gdshader`: lagen per wereldhoogte met een golvende grens, een eigen patroon per laag, procedurele reliëfnormalen (fbm-gradiënt op twee schalen), donkerdere holtes en cyaan aders in het kristal. `main.tscn`: AgX, SSAO, glow (bloom 0,05), mist en volumetrische mist 0,015, ambient 0,12. `player.gd`: helmlamp (spot, energie 5, 20 m, 52°, schaduw, boven en naast het oog) plus een brede, zwakke vullamp. Dat is een goede basis. Dit onderzoek gaat over wat erbij moet, en wat duur of riskant is.

## 1. Wat andere games doen

**Deep Rock Galactic**
- Het hoekige uiterlijk komt uit een beperking van de techniek. Art director Robert Friis: "initially born out of a technical limitation in the way we generate our caves - no smooth surfaces" ([Unreal Engine-interview](https://www.unrealengine.com/developer-interviews/guns-gold-and-glory-in-the-caverns-of-deep-rock-galactic); de pagina gaf 403, het citaat komt uit een zoekresultaat: **niet zelf gelezen**).
- De art director bouwde de stijl rond de sterktes en beperkingen van de terreintech, zodat personages en vijanden in de omgeving passen. Felle kleuren zijn een bewuste keuze. CEO Søren Lundgaard: "We did not want to look similar to all the other brown-gray-gritty looking shooters." Fakkels zaten er van bij het begin in en zijn "critical to add depth to the exploration and mining part". ([Unwinnable](https://unwinnable.com/2018/08/28/deep-rock-galactic/))
- Fakkel: je hebt er 4, ze geven 30 s vol licht, daarna minstens 20 s een zwakke gloed, en een nieuwe laadt in 12 s. De kleur is die van de klasse. ([wiki](https://deeprockgalactic.wiki.gg/wiki/High-Intensity_Flare))
- Zaklamp: spelers meten ±5 m, met een harde afsnijding. Een speler (geen ontwikkelaar) legt uit dat dit bewust is: de lamp dient enkel om niet tegen muren te lopen. ([Steam](https://steamcommunity.com/app/548430/discussions/1/2577697791642784259/)) Er is geen officieel cijfer.
- Geen kleurfilter over het scherm: "all of the colors in Deep Rock Galactic are real". De kleur komt uit lampen en materialen. ([blog](https://waltoriouswritesaboutgames.com/2023/06/21/rainbow-in-the-dark-deep-rock-galactic/))
- Mineralen: Nitra (rood), goud en Morkite (donker cyaan) zitten "in wall surface veins". Andere grondstoffen steken als brokken uit wand of vloer. ([wiki](https://deeprockgalactic.wiki.gg/wiki/Resources)) Hoe de aders technisch getekend worden (textuur, decal of aparte mesh): **niet gevonden**.
- Hoe de terreinshader werkt (triplanar, vertexkleur, handgeschilderd): **geen officiële bron gevonden**. Spelers merken op dat DRG bijna geen bump maps gebruikt en de polygonen net benadrukt, en dat "the factor that is thrown in to make it beautiful is the lighting" ([Steam, spelers](https://steamcommunity.com/app/548430/discussions/1/4956744526887613964/)).

**Astroneer**: geen texturen en geen UV's, enkel kleur, vorm en "extremely flat shading". Het terrein is gefacetteerd, de machines zijn minder gefacetteerd zodat ze afsteken. Gekozen omdat het past bij een klein team. ([Astroneer-blog, Paul Pepera](https://blog.astroneer.space/p/the-art-of-astroneer-low-poly/)) Het spel heeft 107 terreinkleuren ([wiki](https://astroneer.wiki.gg/wiki/Terrain)).

**Valheim**: "low-resolution textures and sparse polygonal detail with modern materials, lighting and post effects" ([FAQ](https://www.valheimgame.com/faq/)).

**Lethal Company**: rendert altijd op 860×520, met HDRP-volumetrische mist, posterisatie op het volumetrische licht (niet op de kleur) en randdetectie. Dat komt uit de analyse van Acerola ([samenvatting](https://daily.dev/posts/the-strange-graphics-of-lethal-company-5knvykwlu), [video](https://www.youtube.com/watch?v=Z_-am00EXIc)).

**Teardown**: "doesn't implement global illumination (light does not bounce off surfaces)". Wel geraytracede AO en zachte schaduwen. ([80.lv](https://80.lv/articles/teardown-developer-breaks-down-multiplayer-and-voxel-destruction-tech))

**PEAK, Hydroneer**: geen bruikbare bron over shaders of licht gevonden. De interviews gaan over het ontwerp ([80.lv](https://80.lv/articles/climbing-sim-peak-was-meant-to-be-friendslop-game-from-the-start)).

**Wat we eruit halen** *[afgeleid]*: vorm en kleur moeten het werk doen, het licht onthult ze. Weinig fijne ruis. Geen schermtint. Zonder GI kan het er goed uitzien (Teardown, DRG) als schaduw, AO en contrast kloppen. Contrast tussen natuur (gefacetteerd, koud) en wat van ons is (glad, warm) zit al in de stijlgids.

## 2. Technieken voor een gestileerde rotsshader

**Triplanar en goedkopere varianten**
- Triplanar betekent 3 samples per textuur. De gewichten komen uit `abs(normaal)`. De scherpte stel je in met een offset (0 tot 0,5) en een exponent (1 tot 8, standaard 2). Op de negatieve assen spiegel je de U, en normal maps meng je met een "whiteout"-blend. ([Catlike Coding](https://catlikecoding.com/unity/tutorials/advanced-rendering/triplanar-mapping/))
- De demo van godot_voxel gebruikt scherpte 8 en een "topness" = `smoothstep(0.46, 0.54, normal.y)` die een boven- en een zijtextuur mengt ([voxelgame](https://github.com/Zylann/voxelgame/blob/master/project/smooth_terrain/transvoxel_terrain.gdshader)).
- Biplanar heeft 2 samples nodig in plaats van 3. Je moet de afgeleiden berekenen vóór de askeuze en `textureGrad` gebruiken, anders krijg je lijntjes van 1 pixel. Met k=8 ziet het er bijna uit als triplanar. ([Inigo Quilez](https://iquilezles.org/articles/biplanar/))
- Dithered triplanar haalt het naar 1 sample, maar steunt op TAA. Conditionele triplanar (een as overslaan als haar gewicht 0 is) is iets sneller en kost geen kwaliteit. ([Ryan DowlingSoka](https://ryandowlingsoka.com/unreal/triplanar-dither-biplanar/)) Wij gebruiken MSAA 2× zonder TAA (`project.godot`), dus dithered valt af *[afgeleid]*.
- Alternatief: een tegelbare **3D-textuur** die je in wereldruimte bemonstert. Dan heb je geen triplanar, geen naden en geen uitrekking *[afgeleid]*. Godot heeft `NoiseTexture3D` (standaard 64³, optie `seamless`) ([docs](https://docs.godotengine.org/en/stable/classes/class_noisetexture3d.html)). Of 3D-texturen mipmaps krijgen, staat niet in de import-docs ([docs](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)): **te testen**.

**Procedurele ruis en aliasing**
- Band-limiting: demp een octaaf zodra haar golflengte kleiner wordt dan een pixel, bv. `cos(x) * smoothstep(2π, 0, fwidth(x))`. Bij fbm verdubbelt de filterbreedte per octaaf. ([Inigo Quilez](https://iquilezles.org/articles/bandlimiting/))
- Kosten van onze shader *[afgeleid]*: `fbm_grad` doet 4 fbm-evaluaties × 3 octaven × 2 schalen = 24 vnoise (192 hashes), plus nog 4 vnoise voor kleur, per pixel. Op een RTX 4090 merk je dat niet, maar dat bewijst niets voor mid-range (CLAUDE.md).

**Lagen, hellingen, nat**
- Hou het simpel: "simple meshes with barely any normal maps and simple, no noise-materials". Gebruik meerkleurige mist voor diepte. ([Christoffer Radsby, 80.lv](https://80.lv/articles/tips-on-stylized-environment-building))
- Een masker voor wat naar boven wijst, uit de wereldnormaal; nattigheid als aparte functie ([Ludovico Antonicelli, 80.lv](https://80.lv/articles/setting-up-rock-shaders-in-unreal-engine-4)). Hoogte-blend tussen materialen ([Catlike Coding](https://catlikecoding.com/unity/tutorials/advanced-rendering/triplanar-mapping/)).

**Facetten (het DRG-uiterlijk)**
- godot_voxel documenteert het low-poly uiterlijk: `NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));` voor Vulkan. In OpenGL zijn dFdx en dFdy omgewisseld. Een blokkerig uiterlijk krijg je door de SDF in de generator te verzadigen. ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/))
- Met voxels van 0,5 m krijg je facetten van ±0,25 tot 0,5 m. Die van DRG lijken groter *[afgeleid, niet gemeten]*. `mesh_optimization_enabled` zou de driehoeken kunnen vergroten, maar die optie is niet beschreven ([API](https://voxel-tools.readthedocs.io/en/latest/api/VoxelMesherTransvoxel/)). Het effect op uiterlijk en botsing is **onbekend**.

**Kromming en randlicht**
- Kromming kun je in schermruimte schatten: kijk hoe snel de normaal verandert. Convex wordt licht, concaaf donker. Dat is het "cavity"-effect van Blender ([cavifree](https://github.com/federicocasares/cavifree), via zoekresultaat). Afgeschuinde randen die licht vangen is volgens de stijlgids "het DRG-trucje".
- Godot heeft `RIM`/`RIM_TINT` en `BACKLIGHT` als uitgangen van de fragmentshader ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)). Rim werkt per lamp. Bij een lamp op het hoofd zie je dus weinig rim, bij de lamp van een teamgenoot wel *[afgeleid]*.

## 3. godot_voxel: wat de shader binnenkrijgt

- `texturing_mode` van VoxelMesherTransvoxel ([API](https://voxel-tools.readthedocs.io/en/latest/api/VoxelMesherTransvoxel/)):
  - `TEXTURES_NONE` (de onze): "fastest if you can use a shader to apply textures procedurally".
  - `TEXTURES_MIXEL4_S4`: de smooth-terrain-pagina noemt dit nog `TEXTURES_BLEND_4_OVER_16`.
  - `TEXTURES_SINGLE_S4`.
- **Single** (sinds 1.5, [changelog](https://voxel-tools.readthedocs.io/en/latest/changelog/)): 8 bit in het kanaal INDICES. Je bewerkt het als blokvoxels, met de modus SET. Het kent geen verloop ("painting has no falloff"). De mesher zet de info in `CUSTOM1`. ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/))
- **Mixel4**: INDICES en WEIGHTS, elk 16 bit. `CUSTOM1.x` bevat 4 indices als 4 bytes, `CUSTOM1.y` 4 gewichten. Je decodeert met `floatBitsToUint` en bitshifts, en normaliseert dan de gewichten. Er kunnen hooguit 4 materialen per voxel samenkomen, anders krijg je artefacten. ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/))
- `CUSTOM0` bevat de Transvoxel-data voor de naden tussen LOD-niveaus: `VERTEX = get_transvoxel_position(VERTEX, CUSTOM0)`, samen met `u_transition_mask` ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/), [broncode](https://github.com/Zylann/godot_voxel/blob/master/meshers/transvoxel/voxel_mesher_transvoxel.cpp)). Wij gebruiken `VoxelTerrain` met één LOD, dus die naadcode is niet nodig *[afgeleid; de docs zeggen het niet expliciet]*. Bij een overstap naar VoxelLodTerrain wel. De include-bestanden (`transvoxel.gdshaderinc`, `triplanar.gdshaderinc`, `lod_fade.gdshaderinc`, …) staan in de [voxelgame-repo](https://github.com/Zylann/voxelgame/tree/master/project/addons/zylann.voxel/shaders), niet in onze GDExtension-map `addons/zylann.voxel`.
- Andere uniforms die de engine zet: `u_block_local_transform`, `u_lod_fade`, `u_voxel_cell_size` en de uniforms voor detail-normalmaps (enkel LOD) ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/)). Terreinnodes hebben `gi_mode` (sinds 1.1) en een schaduwinstelling (sinds 1.3) ([changelog](https://voxel-tools.readthedocs.io/en/latest/changelog/)).
- Normalen komen volgens een zoekresultaat uit de SDF-gradiënt: **niet geverifieerd in de code**. Uit lessons.md weten we dat de SDF rond een uitgegraven bol ±5 cm ruis heeft. Uitgegraven wanden kunnen dus wat hobbelig belicht zijn *[afgeleid]*.

## 4. Licht en sfeer in Godot 4.7

**GI in een terrein dat je kunt afgraven**
- SDFGI is "one of the most demanding" van de GI-technieken. Na een meshwijziging moet de camera eerst weg en terugkomen voor SDFGI het bijwerkt. ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_sdfgi.html)) SDFGI uit en weer aan zetten geeft "bright flashes (especially in a dark scene)" ([issue](https://github.com/godotengine/godot/issues/39961)). VoxelGI moet vooraf gebakken worden en lekt bij dunne wanden, LightmapGI kan enkel in de editor ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html)). Conclusie: geen van de drie voor ons.
- SSIL is dynamisch, maar enkel in schermruimte, "a complement" ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)).
- Terugkaatsing faken: The Last of Us berekende "flashlight bounce lighting" ([GDC Vault](https://gdcvault.com/play/1020475/In-Game-and-Cinematic-Lighting)). Een forumtip: een onzichtbare puntlamp op het raakpunt, met de gemiddelde kleur van het oppervlak ([ResetEra](https://www.resetera.com/threads/why-are-flashlights-in-games-such-crap.177740/)).

**Omgevingslicht**
- SSAO "only acts on *ambient* light" ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)). Met ±3% ambient doet onze SSAO dus bijna niets *[afgeleid]*. `ssao_light_affect` (standaard 0) laat SSAO ook op direct licht werken: "not physically accurate, but some artists prefer this" (zelfde bron). In de shader doet `AO_LIGHT_AFFECT` hetzelfde voor ons `AO`-kanaal ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).
- `volumetric_fog_emission` is "useful to establish an ambient color" ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)).

**Volumetrische mist**
- Standaardwaarden: density 0,05, anisotropy 0,2, length 64, detail_spread 2, temporal reprojection aan op 0,9, gi_inject 1, ambient_inject 0 ([klasse-docs](https://docs.godotengine.org/en/stable/classes/class_environment.html)).
- Hou `length` "as low as possible". Temporal reprojection geeft "ghosting" en een spoor achter bewegende lampen. Een lagere waarde geeft minder spoor maar meer jitter. Enkel lichtbundels zonder algemene mist: density 0,0001 en de volumetric fog energy van de lamp op 200 tot 5000. FogVolume-ruis houd je op 64³ of kleiner. ([docs 4.7](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html))
- Ringen of banden in donkere mist: zet `Use Debanding` aan (Rendering > Anti Aliasing, enkel zichtbaar met geavanceerde instellingen) ([forum](https://forum.godotengine.org/t/volumetric-fog-causes-light-rings-banding-when-scene-is-dark/115318/3)).

**Lampen**
- `spot_attenuation`: 0 = constant en zacht afgesneden aan de rand, 2 = fysisch (kwadratisch), standaard 1. `spot_angle` is de halve openingshoek. ([docs](https://docs.godotengine.org/en/stable/classes/class_spotlight3d.html)) Onze 52° is dus een kegel van 104° *[afgeleid]*.
- Een spotschaduw is "significantly faster" dan een omnischaduw. De schaduwatlas is standaard 4096, verdeeld als 4+4+16+64. Zet PCSS (`light_size`) enkel op een handvol lampen. Er is een distance fade voor lamp en schaduw. Verhoog liever de normal bias dan de bias. ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html))
- Met `shadow_opacity` < 1 laat een schaduw wat licht door ("faked global illumination"). `light_projector` projecteert een textuur. ([docs](https://docs.godotengine.org/en/stable/classes/class_light3d.html))

**Tonemapping, gloed, kleur**
- AgX "maintains the hue of colors as they become brighter" en is de traagste tonemapper ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)). Sinds 4.6 heeft hij `agx_contrast` (standaard 1,25) en `agx_white` (16,29) ([4.6](https://godotengine.org/releases/4.6/), [klasse-docs](https://docs.godotengine.org/en/stable/classes/class_environment.html)).
- Sinds 4.6 komt de gloed vóór de tonemapping, met Screen als standaard ([4.6](https://godotengine.org/releases/4.6/)). `Bloom` "sends screen to glow processor": alles gloeit dan mee. `HDR Threshold` (standaard 1,0) beslist wat genoeg licht heeft om te gloeien. ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html))
- Kleurcorrectie met een 3D-LUT van 17³, 33³, 51³ of 65³, toegepast ná de tonemapping (zelfde bron).
- In 4.7 zijn er AreaLight3D en HDR-uitvoer bijgekomen ([4.7](https://godotengine.org/releases/4.7/)). Voor ons is dat nu niet nodig.

**Stof in de bundel**: geen bron gevonden. Voorstel *[afgeleid]*: GPUParticles3D rond de camera met een *belicht* materiaal (niet unshaded). De stofjes zijn dan onzichtbaar in het donker en lichten op in de bundel.

## 5. Aanbevelingen, gesorteerd op effect per moeite

1. **Debanding aan** (5 min). Donkere verlopen en mist geven anders banden.
2. **`glow_bloom` naar 0** en emissie van kristal, lava en lenzen boven de HDR-drempel (energie 2 tot 4) (10 min). Zo gloeit enkel wat emissief is, zoals de stijlgids vraagt. Nu gloeit ook belichte rots wat mee.
3. **Holtes ook in direct licht** (15 min): `ssao_light_affect` ±0,3 en `AO_LIGHT_AFFECT` ±0,5 in de terreinshader. Vergelijk met screenshots.
4. **Masker voor boven en onder** (1 u): vlakken die naar boven wijzen (`n.y` > ±0,5, zachte overgang zoals in de voxelgame-demo) worden lichter, droger en stoffiger in de laagkleur. Plafonds worden iets donkerder en koeler. Vloer en wand lezen dan meteen verschillend in het donker. In de diepere lagen: lage, holle plekken iets donkerder en minder ruw (nat).
5. **Laaggrens als lijn** (1 u): op elke grens een smalle, donkere band (±10 cm) met een lichtere lip erboven. Laat de grens golven met ruis, niet enkel met sinussen. De stijlgids vraagt "een duidelijke lijn in de wand".
6. **Fijne ruis dempen met afstand** (1 u): band-limiting met `fwidth(wpos)` op de fijne korrel, de spikkels en de fijne bump. We hebben geen TAA, dus fijne ruis flikkert op afstand en onder scherpe hoeken.
7. **Volumetrische mist bijstellen** (2 u): `volumetric_fog_length` op ±24 tot 32 m (meer detail in gangen). Temporal reprojection lager (0,6 tot 0,8) tegen spoortjes achter de helmlamp. Volumetric fog energy van de helmlamp hoger dan die van de vullamp, zodat de bundel leest. Misttint per laag: een script past fog- en volumetric-albedo aan op basis van de diepte van de camera. Alle waarden in `data/tuning/`.
8. **Stof in de bundel** (2 tot 3 u): 200 tot 400 kleine, belichte deeltjes die traag rond de camera zweven. Na het graven een FogVolume met ruis (≤64³) die een paar seconden blijft hangen. Dan reageert de lucht op het graven.
9. **Nep-terugkaatsing van de helmlamp** (3 tot 4 u): een straal vanuit de lamp, een zwakke OmniLight3D zonder schaduw iets vóór het raakpunt, in de laagkleur van die diepte (`strata.gd` kent die). Energie volgens de afstand, en de lamp beweegt zacht mee (lerp) zodat hij niet flikkert. Enkel voor de eigen speler. Dat neemt de "zwart gat"-vlakheid weg zonder GI. SSIL als goedkopere test ernaast zetten.
10. **Randen vangen licht** (2 u): kromming uit `fwidth` van de gladde wereldnormaal, geschaald met de pixelgrootte (`fwidth(wpos)`). Convexe randen 10 tot 20% lichter, concave plekken donkerder. Dat is het DRG-trucje met de afgeschuinde randen, maar dan voor rots.
11. **Facetten A/B** (2 u): de vlakke normaal (`dFdx`/`dFdy`) half mengen met de gladde normaal, en minder grove bump. Screenshots naast elkaar voor Jayme. Facetten en sterke bump vechten tegen elkaar: kies er één als hoofdtoon. `mesh_optimization_enabled` apart testen voor grotere facetten (let op de botsing).
12. **Ruis bakken naar een 3D-textuur** (1 dag): R = grove hoogte, G = fijne hoogte, B = spikkels, A = aders. Getegeld in wereldruimte, 1 tot 2 samples per pixel in plaats van ±200 hashes. Reliëf uit voorberekende gradiënten of uit 3 extra samples. Eerst meten op een mid-range kaart. Mipmaps van 3D-texturen eerst testen.
13. **Kristal geeft licht** (2 tot 3 u): emissie verlicht niets zonder GI. Zet daarom bij grote kristalclusters een handvol cyaan OmniLight3D zonder schaduw met een kort bereik (2 tot 4 m), geplaatst door de generator. Een trage puls in de emissie van de aders.
14. **Schaduwbudget** (1 u): spotlampen houden (geen omni met schaduw). Atlas-kwadranten afstemmen op 4 helmlampen en 2 koplampen. Distance fade op de lampen van anderen. PCSS enkel op de eigen lamp of uit. Normal bias boven bias.
15. **Koel ambient, warme lamp** (1 u): ambient in de schaduwtint `#1A2230` op 2 tot 4%, plus een kleine `volumetric_fog_emission`. Zo krijg je de split warm/koud van de stijlgids zonder LUT. Een LUT pas later, als finishing.
16. **AgX houden en de contrast bijstellen** (30 min): AgX houdt het amber en het cyaan zuiver. Test `agx_contrast` tussen 1,25 en 1,5 en de belichting op een gewone laptop, niet enkel op deze monitor. Bied later een helderheidsschuif in de instellingen aan.
17. **Materiaal per voxel (`TEXTURES_SINGLE_S4`)** (1 tot 2 dagen): enkel als ertsaders echte voxeldata moeten worden, die je ziet verschijnen als je graaft. Zolang lagen en aders een functie van de positie zijn, volstaat de shader.
18. **Geen SDFGI** voor het terrein. Kost veel, werkt niet bij afgraven en flitst in het donker.

## 6. Voorgestelde shaderopbouw

Ingangen:
- Uit de mesh: wereldpositie en gladde wereldnormaal.
- Uniforms uit `strata.gd`: grenzen, kleuren (basis, licht, donker), ruwheid per laag, seed. Alles via `data/tuning/`.
- Eén tegelbare 3D-ruistextuur (later; voorlopig de huidige vnoise).
- `TIME` voor de puls.

Stappen in `fragment()`:
1. **Laag**: `y = wpos.y + warp(ruis)`. Bepaal de laag en de afstand tot de dichtste grens. Op de grens: de lijn (donkere band met een lichte lip).
2. **Grote variatie**: lage frequentie (±5 m), ±10% helderheid binnen de laag. Dat breekt herhaling.
3. **Patroon per laag**: banden, spikkels, kiezels of aders. Band-limited met `fwidth`.
4. **Maskers**: boven (`n.y`), onder, kromming (`fwidth` van de normaal), holte (grove ruis).
5. **Normaal**: glad, optioneel gemengd met de facet, plus een bump die met de afstand wegvalt. Gebruik de gladde normaal voor de maskers, niet de gebumpte.
6. **Samenstellen**: albedo = patroon × holte × stoftint boven × koelte onder × randlicht. Ruwheid per laag, lager in natte holtes. Emissie van de aders × puls.
7. **Uit**: `ALBEDO`, `ROUGHNESS`, `NORMAL`, `EMISSION`, `AO` plus `AO_LIGHT_AFFECT`. Specular laag houden (rots 0,9 ruw), zodat de lamp geen plastic glans geeft.

`vertex()` blijft zoals nu, zolang we VoxelTerrain gebruiken. Pas bij VoxelLodTerrain: `get_transvoxel_position` en de `lod_fade`-discard toevoegen, en de include-bestanden (MIT) in `CREDITS.md` zetten.

## 7. Valkuilen

- **Naden bij LOD-overgangen**: niet van toepassing op VoxelTerrain. Bij VoxelLodTerrain zijn ze verplicht. Triplanar en 3D-ruis in wereldruimte blijven over LOD-niveaus heen gelijk; enkel de normaal verschilt *[afgeleid]*.
- **Spiegeling en uitrekking bij triplanar**: U spiegelen op de negatieve assen, scherpte 4 tot 8. Biplanar enkel met `textureGrad` ([iq](https://iquilezles.org/articles/biplanar/)).
- **Aliasing van ruis**: zonder TAA flikkert fijne procedurele ruis. Altijd met de afstand laten wegvallen.
- **Teken van de facetnormaal**: de formule verschilt tussen Vulkan en OpenGL ([docs](https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/)). Controleer met een screenshot: binnenstebuiten belichte facetten verraden een verkeerd teken.
- **Te donker of te helder**: SSAO en AO doen niets zonder ambient. Gloed met bloom > 0 laat alles gloeien. Test op een gewoon scherm en met een andere belichting, niet enkel op deze pc.
- **Banding** in donkere verlopen en mist: debanding aan.
- **Spoortjes** van de helmlamp in de volumetrische mist (temporal reprojection) ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)).
- **Emissie verlicht niets** zonder GI: echte lampjes nodig waar het telt.
- **Prestaties**: de huidige procedurele shader is zwaar per pixel. Cijfers van de RTX 4090 bewijzen niets voor mid-range.

## Niet bereikbaar of niet geverifieerd

- De interviews van Unreal Engine met Ghost Ship en System Era, de blog van Ben Golus over triplanar normal mapping, de Polycount-thread over Astroneer en het ArtStation-artikel over de flashlight bounce gaven 403. Het citaat van Robert Friis komt enkel uit een zoekresultaat.
- Geen bron gevonden over de terreinshader van DRG, de manier waarop DRG aders tekent, of de shaders en het licht van PEAK en Hydroneer.
- Niet gecontroleerd in de broncode: dat Transvoxel-normalen uit de SDF-gradiënt komen, en dat VoxelTerrain `u_transition_mask` nooit zet.
