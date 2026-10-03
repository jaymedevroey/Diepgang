# De hemel van Roestbol: kunstrichting, techniek en hoogte

Onderzoek, 2026-10-03, voor Godot 4.7 Forward+.

**Aanleiding.** De eerste hemel zag er in de screenshots zo uit:

- een vlakke, modderbruine lucht;
- een geringde reuzenplaneet die leek op een goedkoop plaatje;
- sterren en nevel overdag;
- van 340 m hoog een bruine waas over de planeet, zonder gevoel van atmosfeer.

Er was geen onderzoek aan voorafgegaan. Dit onderzoek las ook de bestaande `planet_sky.gdshader`, `atmosphere.gd`, `planet_type.gd` en `main.tscn`.

Over de bronnen: voor Starfield, Mass Effect, Dune, Subnautica, Risk of Rain 2 en PEAK zijn geen uitleg van de makers gevonden. Wat daarover staat, is eigen waarneming.

## Kort

1. **Het grootste probleem is de verdeling van licht en donker, niet de techniek.**
   - Het zenit staat op sRGB (0,07; 0,05; 0,12), lineair ±0,006: bijna zwart, boven een zonnige grond.
   - Een oranje dat donkerder wordt, wordt bruin. Een warme lucht moet licht blijven; naar het zenit toe verschuift de tint naar roze, mauve of paars.
2. **Hemellichamen staan áchter de atmosfeer, niet erop.** Met één formule, `lucht = achtergrond × T + (1 − T) × waas`, verdwijnen sterren, nevel en de reus vanzelf overdag en laag bij de horizon.
3. **Van 340 m hoog is het meeste onder de horizon de hemel-shader zelf.**
   - De verre ring eindigt 35,6° onder de horizontale lijn, en alles daarboven tekent de hemel.
   - Nu staat daar `horizon*0.45`, donkerbruin. Vandaar de "bruine planeet".
   - De hemel moet daar een virtuele grond tekenen, met nevel ertussen.
4. **De ingebouwde mist van Godot kan geen nevel die met de hoogte verandert.**
   - De hoogtemist hangt enkel af van de hoogte van het punt, niet van de lijn vanaf de camera.
   - Een gedeelde `.gdshaderinc` met een exacte integraal van de nevel over de hoogte, geschreven naar `FOG`, voor het terrein, de verre ring én de hemel, maakt alles naadloos.
5. **De geringde planeet moet echt 3D zijn:**
   - een bol en een vlak die je met de kijkstraal snijdt;
   - getekend in de goede volgorde;
   - de schaduw van de ring op de planeet en die van de planeet op de ring;
   - verstrooiing door de onbelichte kant van de ring.

## 1. Wat er mis is met de huidige hemel

**De lucht is donkerder dan de grond.** Volgens de waarden van Carlson is de lucht het lichtste vlak, dan de vlakke grond, dan hellingen, dan verticalen ([Mitch Albala](https://mitchalbala.com/value-divisions-in-landscape/)). Onze lucht is donkerder dan zonnige roest en leest als een bruine muur.

**De mist heeft overal dezelfde bruine kleur.**

- `fog_light_color` staat op (0,55; 0,36; 0,28), met `fog_aerial_perspective = 0` en `fog_sky_affect = 0.35`. Dat geeft één bruine sluier over grond en lucht.
- Eén vaste mistkleur werkt nooit. Verre grond gaat van doorzichtig naar een verzadigde tint naar bleek, en toppen mogen nooit bleker zijn dan de lucht erachter ([runevision](https://blog.runevision.com/2025/06/notes-on-atmospheric-perspective-and.html)).

**De kleurgrading haalt kleur weg.** In `_grading_lut()` haalt `lerp(lo, o, 0.95)` verzadiging weg, en AgX doet dat al bewust ([AgX PR #106940](https://github.com/godotengine/godot/pull/106940)).

**De reus leest als een plaatje.**

- Hij wordt met `mix()` over de lucht gelegd.
- De nachtkant heeft een minimum van 0,08, donkerder dan een daglucht.
- Er is geen uitdoving bij de horizon.
- De achterste helft van de ring wordt verborgen met de truc `q.y > 0`.
- Ring en planeet werpen geen schaduw op elkaar.
- De banden volgen het scherm, niet de planeet.

**Sterren en nevel** hangen enkel af van de hoogte in de lucht, niet van hoe helder de lucht is.

**`glow_intensity` 0,9** is te hoog: met een donkere lucht wordt het melkachtig in plaats van fonkelend.

**Het verre vlak van de camera.** `OverviewCamera.far = 400`, maar vanaf 340 m moet het minstens ±600 m zijn om de rand van de ring te zien.

## 2. Kunstrichting

### Wat games doen

**Outer Wilds.** Eén atmosfeer-shader die werkt van in de ruimte, op de grond en alles daartussen. Gestart vanuit O'Neil (GPU Gems 2), maar de meeste formules zijn vervangen om één shader te houden ([Mobius](https://www.mobiusdigitalgames.com/news/the-atmosphere-awakens)). Les: één functie voor elke hoogte, geen aparte looks.

**No Man's Sky.**

- Luchten zijn kleurensets die een kunstenaar kiest, geen pure natuurkunde. Er zijn ±8 benoemde kleuren per planeet: lucht, bovenlucht, zon, horizon, mist, hoogtemist, licht, wolken ([NMS-kleuren](https://nmscd.com/nmscolorparser/)).
- Ze lieten zich inspireren door sciencefictionomslagen uit de jaren 70, en manen staan bewust dichterbij dan kan, voor het drama ([Wikipedia](https://en.wikipedia.org/wiki/Development_of_No_Man%27s_Sky)).
- Les: ±8 benoemde kleuren per planeet, verdeeld met natuurkundig gemotiveerde gewichten.

**Destiny 2.**

- De lucht is een personage ([GameSpot](https://www.gamespot.com/articles/bungie-aimed-to-make-destinys-beautiful-skies-epic/1100-6421603/)).
- Planeten zijn 3D-bollen, door de zon belicht en zacht in de atmosfeer gemengd om ze naar achteren te duwen ([80.lv](https://80.lv/articles/creating-breathtaking-game-backgrounds)).

**Halo 4/5.** Grote verre dingen bewegen traag, en wolken- en nevelkaarten binden terrein, verte en lucht samen ([80.lv](https://80.lv/articles/creating-skyboxes-for-aaa-games)).

**World of Warcraft.** De kleuren en vormen van de lucht herhalen de voorgrond, en het licht van de lucht klopt met de scène ([80.lv](https://80.lv/articles/how-to-create-skies-for-3d-games)).

**Journey.** Groene lucht in het begin, het felle blauw bewaard voor het einde als beloning ([Nava](https://twitter.com/matt_nava/status/1503152781795889152)). De kleur van de lucht kan vooruitgang dragen.

**Astroneer.** "Gebogen geometrisch, brede levendige kleuren" die werken van dichtbij, van ver en als duimnagel ([blog](https://blog.astroneer.space/p/the-art-of-astroneer-low-poly/)).

**Deep Rock Galactic.** Geprezen omdat het veel kleur gebruikt in plaats van grijs en bruin ([Waltorious](https://waltoriouswritesaboutgames.com/2023/06/21/rainbow-in-the-dark-deep-rock-galactic/)).

**The Outer Worlds.** Durf met kleur, met Art Nouveau (Mucha, Moebius) als inspiratie ([Game Informer](https://gameinformer.com/2019/02/20/the-story-behind-the-outer-worlds-amazing-art)).

### Regels voor Roestbol

1. **Twee overgangen tegelijk** (Gurney): van boven naar onder (gloed bij de horizon), en van opzij (verblinding rond de zon). Elke hoek van de lucht heeft een andere tint en waarde ([Gurney](http://gurneyjourney.blogspot.com/2011/02/skys-dual-gradations.html)). Met de afstand verschuift dat in stappen die steeds kleiner worden, niet gelijkmatig ([Gurney](http://gurneyjourney.blogspot.com/2013/07/atmospheric-distance-and-value.html)).
2. **Omgekeerd luchtperspectief.** Met stof in de lucht wordt de verte warmer in plaats van blauwer ([Gurney](http://gurneyjourney.blogspot.com/2007/09/reverse-atmospheric-perspective.html)). Goed voor een stofplaneet.
3. **Mars als geloofwaardig voorbeeld** ([phys.org](https://phys.org/news/2015-05-mars-sunsets-earth.html)):
   - Fijn stof slorpt blauw op, dus overdag is de lucht licht karamel.
   - Hetzelfde stof stuurt blauw naar voren, dus rond een lage zon ontstaat een koele blauwe stralenkrans.
   - Gemeten waarden: albedo ±0,95/0,91/0,86 (R/G/B), asymmetrie g ±0,6–0,7, optische dikte 0,3–1,0, schaalhoogte ±11 km ([celestiary](https://github.com/celestiary/web/pull/147), [arXiv](https://arxiv.org/pdf/1905.01073)).
   - Resultaat: warme grond, lichte warme lucht, koele accenten (de stralenkrans, de reus). Buitenaards en toch geloofwaardig.
4. **Geen bruin.**
   - Warme tinten blijven licht.
   - Roestgrond (tint ±15°) heeft een partner nodig: een lichte, minder verzadigde lucht, of een andere kleurfamilie (teal ±190°, paars ±270°).
   - De verzadiging is het hoogst halverwege de lucht en in de zonnegloed; de horizon is lichter en minder verzadigd.
5. **Lichtwaarden** (lineair, vóór tonemapping):

   | Wat | Waarde |
   |---|---|
   | Horizon | ±1,0–2,0 |
   | Zenit (op de grond) | ±0,3–0,6, lager op 340 m |
   | Zonnige grond | ±0,4–0,8 |
   | Zonneschijf | 20–50, zodat enkel de zon gloeit |

### Hemellichamen

**Grootte en plaats.**

- De camera heeft 75° verticaal beeld (de bovenrand ligt op ±+37° als je recht vooruit kijkt).
- De reus loopt van ±+8° tot +35° hoogte. Zijn onderrand die in de waas aan de horizon zakt, geeft diepte; de bovenste helft blijft waar de lucht helder is.
- De planeet beslaat 16–22°, de ringen 2,2–2,5 keer de straal van de planeet.
- De ring staat 15–25° open: een ellips met verhouding ±0,26–0,42.

**De fase klopt met de zon.**

- 110–140° van de zon: een rustige, bijna volle planeet.
- 30–60° van de zon: een dramatische sikkel met ringen die oplichten van achteren, zoals de Cassini-foto "In Saturn's Shadow" ([NASA](https://science.nasa.gov/resource/in-saturns-shadow-with-labels/)).

**Planeetschijn.** De nachtkant krijgt het roestige teruggekaatste licht van Roestbol, ±2–5% van de dagkant, geen zwart of grijs minimum.

**Uitdoving.** Laag bij de horizon kijk je door veel lucht: op 17° hoogte ±3,4 keer zoveel. Met een optische dikte van 0,5 blijft dan ±18% over: de planeet wordt daar donkerder en roder.

**Detail.**

- De planeet: 4–7 brede banden en één storm als blikvanger, met vervormde randen.
- De ring: 2–3 banden, één duidelijke opening en een vage stoffige buitenring.
- Overdag geen nevel.

## 3. Technieken voor Godot 4.7

### Drie niveaus

**A (aanbevolen): gestileerd en analytisch.**

- ±8 kleuren gekozen door een kunstenaar (zoals No Man's Sky), met natuurkundig gemotiveerde gewichten.
- Alles in de hemel-shader en één gedeelde include.
- Goedkoop, goed bij te sturen, en hetzelfde op elke hoogte.

**B: enkelvoudige verstrooiing met ray-marching.**

- In de kwart-resolutie-pas van de hemel ([Godot-blog](https://godotengine.org/article/custom-sky-shaders-godot-4-0/)).
- Rayleigh en Mie (Henyey-Greenstein). Waarden voor Mars ([Maxime Heckel](https://blog.maximeheckel.com/posts/on-rendering-the-sky-sunsets-and-planets/)): β_R = (0,019; 0,013; 0,0057)/km, H = 11,1 km, g = 0,65.
- De knop van Sebastian Lague: β = (400/λ)⁴ × sterkte, met λ = (700, 530, 440) nm. Verschuif λ voor een andere kleur lucht ([code, MIT](https://github.com/SebLague/Solar-System)).

**C: de LUT's van Hillaire 2020** ([paper](https://diglib.eg.org/items/8a3e5350-18b3-46bd-9274-3add5af88c75), [code, MIT](https://github.com/sebh/UnrealEngineSkyAtmosphere)).

- Er is een Godot-port: [voithos/godot-precomputed-atmosphere](https://github.com/voithos/godot-precomputed-atmosphere) (MIT, geen zicht vanuit de ruimte).
- Te zwaar voor hooguit 340 m hoogte en een gestileerde look.

### De formules van niveau A

**Invoer:** d = kijkrichting (EYEDIR), s = richting naar de zon (LIGHT0_DIRECTION), μ = d·s, h = hoogte van de camera, R = gestileerde straal van de planeet.

1. **Kim (horizondaling):** δ ≈ √(2h/R). Hoogte boven de echte horizon: e = asin(d.y) + δ.
2. **Luchtmassa** (Kasten–Young): m(e) = 1 / (sin e + 0,50572 · (e° + 6,07995)^−1,6364) ([Wikipedia](https://en.wikipedia.org/wiki/Air_mass_(astronomy))).
3. **Twee lagen:**
   - een stoflaag van 60–120 m dik (de mist);
   - een hoge waas van 500–1.500 m (de koepel), met k = exp(−h/H_s) voor de lucht boven de camera.
4. **Doorlaatbaarheid,** per kleur, met stof dat blauw opslorpt: T = exp(−τ₀ · k · m · (0,8; 1,0; 1,35)), met τ₀ ±0,4–0,8.
5. **Verstrooiingsfunctie** (Henyey-Greenstein): HG(μ, g) = (1−g²) / (4π (1+g²−2gμ)^1,5), met g ±0,65 ([HG](https://en.wikipedia.org/wiki/Henyey%E2%80%93Greenstein_phase_function)).
6. **Zonlicht door de lucht:** T_zon = exp(−τ₀ · k · m(hoogte zon) · tint). Een lage zon kleurt de waas vanzelf rood.
7. **Waas** = C_horizon · A + C_zon · HG(μ) · G · T_zon, met C_zon de blauwe stralenkrans.
8. **Achtergrond** = C_ruimte + sterren + reus + ringen.
9. **Lucht** = achtergrond · T + (1 − T) · waas.

Die laatste regel doet alles in één keer:

- het zenit wordt donkerder met de hoogte;
- de horizon blijft bleek;
- hemellichamen doven bij de horizon;
- overdag zie je geen sterren.

**Sterren:** zichtbaarheid = 1 − smoothstep(0,02; 0,15; helderheid((1−T) · waas)). Je ziet ze enkel hoog boven het stof, 's nachts, of tegenover een heel lage zon.

**Onder de horizon (e < 0):**

1. Snijd de kijkstraal met de bol van de planeet (of het vlak y = 0).
2. Kleur de grond met zon en omgevingslicht.
3. Leg de nevel uit de include erover.

Dat vervangt `horizon*0.45`.

**Goedkoper alternatief:** drie geschilderde verloopkleuren zon–zenit, kijkrichting–zenit en zon–kijkrichting ([Kelvin van Hoorn](https://kelvinvanhoorn.com/tutorials/godot_skybox_shader/)).

### Nevel tussen jou en de verte (luchtperspectief)

**Wat Godot doet** (nagekeken in [scene_forward_clustered.glsl](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl)):

- dieptemist: 1 − exp(−afstand · fog_density);
- hoogtemist: 1 − exp(min(0, (y − fog_height) · fog_height_density)), dus enkel de hoogte van het punt;
- de twee worden gecombineerd met `max()`.

Grond op y = 0 krijgt dus evenveel hoogtemist of je er nu op staat of 340 m erboven hangt.

**Oplossing:** een gedeelde `aerial.gdshaderinc` met de exacte integraal van Inigo Quilez ([iq](https://iquilezles.org/articles/fog/)).

- Optische dikte voor een dichtheid a · e^(−b·y): τ = (a/b) · e^(−b·ro.y) · (1 − e^(−b·t·rd.y)) / rd.y. Voor bijna horizontale stralen: τ = a · e^(−b·ro.y) · t.
- De kleur hangt af van de richting: waas plus verblinding rond de zon via HG(μ). Eventueel per kleur een eigen uitdoving en instrooiing.
- Terrein en verre ring schrijven het naar `FOG` (rgb = waas, a = 1 − T). Een materiaal dat `FOG` schrijft, slaat de gewone mist en de volumetrische mist over ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).
- De hemel gebruikt dezelfde functie voor zijn virtuele grond. Zo is er geen naad.

**Getallen:** a = 0,0045–0,006 per m aan de grond, en een schaalhoogte van 60–120 m. Met a = 0,005 en 80 m:

| Zicht | Optische dikte | Sluier |
|---|---|---|
| Recht naar beneden vanaf 340 m | 0,39 | ±33% |
| Horizontaal aan de grond over 475 m | 2,4 | ±91% (de rand van de ring verdwijnt) |
| Horizontaal op 340 m over 5 km | 0,36 | ±30% |

Dat vervangt de truc `fog_density × lerp(1, 0.3, hoogte)`.

**Instellingen van de Environment** ([docs](https://docs.godotengine.org/en/stable/classes/class_environment.html)):

| Instelling | Waarde | Opmerking |
|---|---|---|
| `fog_density` | ±0–0,001 | enkel nog voor het schip en losse dingen |
| `fog_aerial_perspective` | 0,8–1,0 | |
| `fog_sun_scatter` | 0,1–0,3 | |
| `fog_sky_affect` | 0–0,15 | de hemel heeft zijn waas al |
| Hoogtemist | 0,05–0,15 | enkel voor stof in kraters |
| Volumetrische mist | — | enkel in de grotten (die werkt maar tot 28 m ver, te kort voor 300–600 m) |

**Later mogelijk:** een nabewerking op de dieptebuffer met dezelfde functie, voor alle objecten.

### De geringde reus, echt in 3D

De planeet is een bol (middelpunt C, straal R_p) ver weg in de richting van de reus. De ring heeft een normaal n, een binnenstraal r_in en een buitenstraal r_uit.

**1. Snijden.**

- Planeet: snijden met de bol ([Heckel](https://blog.maximeheckel.com/posts/on-rendering-the-sky-sunsets-and-planets/)).
- Ring: t_r = −(ro−C)·n / (rd·n), en r = |ro + t_r·rd − C|. De dichtheid komt uit een verloopkleur met openingen.
- **Het dichtste eerst tekenen.** Dat vervangt de truc met de achterste helft.

**2. Planeet kleuren.**

- De banden volgen de breedtegraad van de planeet zelf, met vervorming.
- Een zachte dag-nachtgrens.
- Randverdonkering.
- Een atmosfeerrand aan de kant van de zon.
- Planeetschijn op de nachtkant.

**3. De schaduw van de ring op de planeet** ([Sangil Lee](https://sangillee.com/2024-11-02-create-realistic-saturn-with-shaders/), geen licentie vermeld, dus zelf schrijven). Een straal vanaf het punt naar de zon: raakt die de ring, dan donkerder. Een zachte rand krijg je door 3–7 stralen te middelen.

**4. De schaduw van de planeet op de ring** ([John Whigham](http://johnwhigham.blogspot.com/2011/11/planetary-rings.html)). Ligt een ringpunt achter de planeet ten opzichte van de zon en binnen haar straal, dan donker, met een zachte rand.

**5. De ring belichten.**

- Belichte kant: albedo · (0,35 + 0,65 · |s·n|).
- Onbelichte kant: albedo · α(1−α) · k · HG(rd·s, g ±0,6). Dichte delen worden donker en stoffige delen gloeien, zoals op de foto's van Cassini.

**6. Anti-aliasing:** smoothstep over fwidth op de rand van de planeet en de ring.

**7.** Alles komt in de **achtergrond**, dus achter de atmosfeer.

### Zon, gloed, tonemapping

**Zonneschijf.**

- Los van de zachtheid van de schaduw: `LIGHT0_SIZE` volgt `light_angular_distance`, en die groter maken vervaagt ook de schaduwen.
- Een gestileerde schijf van 1,5–3° met randverdonkering en helderheid 20–50 ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html)).

**Gloed.**

- `glow_hdr_threshold` 1,0–1,5;
- `glow_intensity` 0,3–0,6;
- `glow_bloom` 0;
- niveau 3–5;
- Screen of Additive.

**Tonemapping.**

- AgX (houdt felle oranjes op hun tint), met `tonemap_agx_contrast` ±1,3–1,6 (sinds 4.6, [PR #106940](https://github.com/godotengine/godot/pull/106940)).
- De LUT geeft verzadiging terug (±1,1–1,2) in plaats van ze weg te nemen.
- ACES geeft meer pit, maar verschuift oranje naar geel.
- 4.7 kan HDR-uitvoer, dus SDR en HDR allebei nakijken.

**Hemel verwerken** ([docs](https://docs.godotengine.org/en/stable/classes/class_sky.html)).

- Als de hemel een hoogte-uniform of TIME gebruikt: `process_mode` REALTIME met `radiance_size` 256.
- In de cubemap-pas geen sterren, ringdetail of ruis.
- Ruis in de kwart-resolutie-pas.

### Code om te bestuderen (Godot 4)

| Project | Licentie | Inhoud |
|---|---|---|
| [llama-nl/top-sky](https://github.com/llama-nl/top-sky) | MIT | Rayleigh, Mie en ozon |
| [Zylann/godot_atmosphere_shader](https://github.com/Zylann/godot_atmosphere_shader) | MIT | atmosfeer van binnen en van buiten |
| [voithos/godot-precomputed-atmosphere](https://github.com/voithos/godot-precomputed-atmosphere) | MIT | de LUT's van Hillaire |
| [TokisanGames/Sky3D](https://github.com/TokisanGames/Sky3D) | MIT; sterrenkaart met vermelding | dag-nachtcyclus |
| [rlsl0422/godot-simple-sky](https://github.com/rlsl0422/godot-simple-sky) | MIT | wolken plus atmosfeer |
| [gdquest-demos/godot-4-stylized-sky](https://github.com/gdquest-demos/godot-4-stylized-sky) | code MIT, kunst CC-BY-NC-SA | gestileerde hemel |
| [paddy-exe/GodotStylizedSkyShader](https://github.com/paddy-exe/GodotStylizedSkyShader) | CC BY 4.0 | gestileerde hemel |
| [Dimev Realistic Atmosphere](https://github.com/Dimev/Realistic-Atmosphere-Godot-and-UE4) | MIT, vermelding gevraagd | atmosfeer |
| Shadertoy "Production Sky Rendering" ([slSXRW](https://www.shadertoy.com/view/slSXRW)) | CC BY-NC-SA | enkel om te leren, niet commercieel overnemen |

## 4. Hoogte: van de grond tot 340 m

**Meetkunde.**

- Op 340 m ligt de rand van de ring (475 m) 35,6° onder de horizontale lijn; daarboven tekent de hemel.
- Op een planeet zo groot als de aarde zakt de kim op 340 m maar 0,6°: niets leest als "planeet".
- Een gestileerde straal van 20–40 km geeft 10,6–7,5° kimdaling en een horizon op 3,7–5,2 km. Op de grond (2 m) ligt de horizon dan 280–400 m ver, ongeveer bij de ring.
- Enkel de verre ring buigen: y −= d² / (2R), ±3–6 m op 475 m ([world bending](https://notslot.com/tutorials/2020/04/world-bending-effect)).

**Virtuele grond in de hemel.** Snijden met een bol van straal R, met een grove kleur, kraterringen en donkere vlekken, en dezelfde nevel-include. Over de laatste 100 m van de ring vloeit zijn kleur over in die van de virtuele grond.

**Mesa's aan de horizon.** Een profiel met platte toppen op een vaste afstand (2–4 km). Hun hoogte in de lucht hangt af van de hoogte van de camera, zodat ze correct onder de horizonlijn zakken als je stijgt.

**Optioneel:** een tweede, heel goedkope ring tot 2–4 km (5–10k driehoeken), met een verder vlak voor de camera. Zoals de "scaled space" van KSP ([wiki](https://wiki.kerbalspaceprogram.com/wiki/Tutorial:Making_Planets)).

**Stoflaag op 120–200 m.**

- Een vlak van 3–5 km met zachte ruis, van boven door de zon belicht en van onder een vage sluier.
- Het verbergt overgangen in detail en geeft beweging tijdens de drop.
- Het geeft ook een moment: 2–3 s gloeiende waas met deeltjes die langs je omhoog schieten.
- Dit sluit aan bij de wolkenwaas in [drop-en-ophalen.md](drop-en-ophalen.md).

**Alles volgt vloeiend de hoogte van de camera,** zonder schakelaars. Het binnenlicht in het schip blijft apart.

## 5. Drie richtingen voor Roestbol

### A. "Karamel met een blauwe krans" (op Mars gebaseerd, het geloofwaardigst)

| Wat | Kleur |
|---|---|
| Zenit (grond) | #A0705F |
| Midden | #C9977A |
| Horizon | #E8C49A |
| Waasband | #F3D9B5 |
| Krans rond de zon | #A9C4D8 |
| Zon | #FFF4E6 |
| Roest in de zon | #B5532E |
| Roest in de schaduw | #5A2E35 |
| Verre mesa's | #C99A86 |
| Reus (basis, band, storm) | #7FA3B8, #4F7690, #D8E3E8 |
| Planeetschijn | #3A2420 |
| Ringen, gloed van achteren | #E6D6BC, #BFD8E8 |

- **Hemellichamen:** een bijna volle reus op 120° van een zon op 20–25° hoogte, met zijn midden op ±22°.
- **Op de grond:** een lichte, warme koepel met koele accenten. Verre grond wordt perzik.
- **Op 340 m:** het zenit verdiept naar #3B2A4A met vage sterren. De grond is scherp onder een perziksluier van ±30%, met een gloeiende stoflaag eronder. De kim zakt ±8°.

### B. "Teal boven roest" (complementair, het leesbaarst, het meest DRG)

| Wat | Kleur |
|---|---|
| Zenit | #1F5E6E |
| Midden | #4F9AA0 |
| Horizon | #BFE0D2 |
| Lage stofmist | #E9B48F |
| Zon, verblinding | #FFFBF0, #D8F4F0 |
| Roest in de zon | #B0482A |
| Schaduw (paars) | #3E2A3C |
| Reus, banden | #B48FC4, #7A5A9C |
| Ringen | #F0DDB0 |

- **Twee duidelijke lagen:** warm stof laag, koele lucht erboven. Silhouetten springen eruit tegen het teal.
- **Op 340 m:** je kijkt neer op een warme stofzee (#E0A27E) met het terrein erdoor. Daarboven #12384A, met de horizon als een dunne aqua lijn.

### C. "Paars gouden uur" (het dramatischst, de zon staat altijd laag)

| Wat | Kleur |
|---|---|
| Zenit | #2B2350 |
| Lucht weg van de zon | #6B5A8E |
| Band weg van de zon | #C98BA0 |
| Horizon aan de zonkant | #F2A65A |
| Verblinding | #FFE3B0 |
| Waas | #D98F7A |
| Roest in de zon | #C8642F |
| Schaduw | #4A2F4F |
| Reus: belichte sikkel, nachtkant | #F5E6C8, #2A1A22 |
| Planeetschijn | #4A2A22 |
| Ringen: van achteren, belicht | #FFD9A8, #CDB79A |

- **Hemellichamen:** de zon op 8–12°, de reus als sikkel 40–50° van de zon, met ringen die fel oplichten van achteren. Sterk verschil tussen de zonkant en de andere kant.
- **Op 340 m:** strijklicht toont elke krater; gouden waas aan de zonkant, koele waas aan de andere. Sterren enkel in het zenit aan de kant weg van de zon.

## 6. Controlebeelden bij elke versie

**Zes screenshots:**

1. Op de grond, naar de zon.
2. Op de grond, van de zon weg.
3. Op de grond, naar de reus.
4. Op 150 m, in de stoflaag.
5. Op 340 m, 40° naar beneden.
6. Op 340 m, recht naar de horizon.

**Nakijken:**

- De lucht is lichter dan de zonnige grond.
- Geen terrein dat bleker is dan de lucht erachter.
- Overdag geen sterren op de grond.
- De belichte kant van de reus wijst naar de zon.
- Geen naad tussen de verre ring en de virtuele grond.
