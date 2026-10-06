# DIEPGANG — Game Design Document

> Werktitel. Versie 3, 2 oktober 2026 (v2.1: 1 oktober, v2: 30 september). Wijzigingen in v3: zie §14.
> 3D online co-op opgravingsgame voor Steam, volledig te bouwen door een AI-codeeragent op Jayme's pc thuis.

---

## 1. Samenvatting

**Pitch:** Online co-op voor 1–4 spelers in first-person 3D. Jullie zijn goedkope robotjes van **DIG** (Diepgang Interplanetaire Grondwerken), een louche intergalactisch bedrijf dat van planeet naar planeet trekt om te stelen wat onder de grond zit. Elke dienst begint in **de Mol**, jullie rijdende boormachine, die vanuit het moederschip **De Ekster** op een planeet gedropt wordt. Daar boor je je naar beneden door volledig vervormbare grond, delf je erts, bik je alien-fossielen en relieken uit hun korst en sleep je alles naar het laadruim, voor het magma van onderen alles opslokt. Daarna rijdt de Mol terug naar boven en pikt het schip jullie op. Aan boord taxeer je de buit, verkoop je hem of zet je hem in het **museum** van de Raad van Bestuur, en upgrade je gereedschap en de Mol.

**Hoofdhaak: archeologie op vreemde planeten in plaats van enkel mijnbouw.** Een skelet komt in 3–8 losse stukken uit de grond. Elk stuk moet apart uitgebikt en heel naar boven gebracht worden. Aan boord bouw je het weer in elkaar: het museum groeit zichtbaar tussen diensten, met gaten waar een bot ontbreekt. Erts is het vaste inkomen, vondsten zijn de grote uitbetaling en de verzameling. Daarbovenop: **de drop**. Elke dienst begint met de hele ploeg in de Mol die door de atmosfeer valt.

> Naam van het bedrijf en het schip: voorstel van de agent (DIG, De Ekster). Jayme kan ze vervangen.

| | |
|---|---|
| Genre | Co-op opgraven + fysieke buit + extractie ("friendslop" met progressie) |
| Spelers | 1–4 online (Steam), solo volledig speelbaar |
| Camera | First-person |
| Prijs | €8,99, met launchkorting |
| Doelgroep | Vriendengroepen die R.E.P.O., PEAK, Lethal Company en Helldivers 2 spelen, plus fans van A Game About Digging A Hole en Deep Rock Galactic |
| Engine | Godot 4.7.2 (vastgepind) |
| Doel | Demo op Steam Next Fest, 14–21 juni 2027 (demo eerder, februari–maart 2027), daarna Early Access |
| Toon | Louche bedrijf met humor: cynische berichten van het hoofdkantoor, boetes, "werknemer van de dienst". De robots zijn schattig |
| Engelse titel | Nog te kiezen na een check op Steam en merken |

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
| A Game About Digging A Hole Together | 4 spelers online, crossplay (aangekondigd 29–30 sep 2026, H2 2026) | ? | — | De co-op-versie van een miljoenenhit: "co-op graven" is geen haak meer |
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
Het spel speelt zich grotendeels ondergronds af, en het oppervlak van een planeet is kaal:
- Er zijn geen bomen, gras, water of gebouwen nodig; de hemel is een shader.
- Rots is procedureel (ruis, lagen, shader).
- De duisternis beperkt wat je ziet, wat zowel art-werk als performance scheelt.
- Licht doet het zware werk: gloeiende kristallen en lava.

De basis is het **moederschip De Ekster**: één interieur (dropbaai, terminal, taxatie, museum), geen gebouwen op de planeet.

> **Bijgestuurd 2026-10-03 (Jayme):** de binnenkant volgt de Super Destroyer van Helldivers 2, met DIG-humor: laadrek → werkdek met upgradenissen en een tv met DIG-nieuws → gang → brug met de opdrachttafel → trap naar de hangar met de Mol voor een raamwand. Eén dek met kleine trappen, geen verdiepingen. **Het museum komt later**, niet in M3 (zie [schip-interieur-niveaus](research/schip-interieur-niveaus.md)).

---

## 3. Kernlus

```
De Ekster (moederschip) → planeet en opdracht kiezen → drop met de Mol → boren naar beneden
→ sonar → graven, erts delven, korsten uitbikken → buit naar het laadruim → magma en onrust stijgen
→ extractie: de Mol rijdt naar boven en wordt opgepikt → taxatie aan boord → verkopen of museum → upgraden
```

### Een dienst (15–20 minuten)
1. **Aan boord van De Ekster** kies je op de terminal een planeet: 2–3 keuzes, elk met een opdracht (en later mutators, §4).
2. **Drop.** Iedereen stapt in de Mol, de piloot trekt aan de drophendel. De Mol valt door de atmosfeer (gloed, schokken, stuwraketten) en landt in een stofwolk. De drop is meteen ook het laadscherm: het terrein laadt terwijl je valt. In beeld: het **heldenshot** (keuze Jayme, [drop-en-ophalen](research/drop-en-ophalen.md)). Eén vaste camera achter de vallende Mol, het schip krimpt boven in beeld, en bij de landing een knip naar binnen in de stofwolk.
3. **Afdalen.** De Mol boort zich in de grond, zelf gestuurd of met de autopiloot.
4. **Zoeken.** De sonar luistert stil (kort bereik, vaag). Een **PING** geeft een scherp beeld tot ver, maar maakt lawaai.
5. **Graven en delven.** Erts gaat in je ertszak en geef je af aan de trechter van de Mol. Vondsten zitten in een **korst**: met het houweel bik je die weg zonder schade, maar traag; boren gaat sneller, maar verlaagt de waarde.
6. **Slepen.** Vondsten draag je fysiek naar het laadruim. Zware stukken draag je met twee, maar dan ga je trager. Valt iets, dan telt de fysica: het botst, breekt of rolt weg.
7. **Magma en onrust.**
   - Magma stijgt van onderen: dat is de **enige klok**.
   - Onrust stijgt alleen door lawaai: boren, de Mol, pings en explosies.
   - Bij elke drempel beeft de planeet: rotsblokken vallen in gemarkeerde zones en het magma maakt een sprong.
8. **Extractie.** De piloot trekt aan de vertrekhendel. Na een aftelling rijdt de Mol zijn eigen spoor terug naar de oppervlakte. De Ekster laat een grijper zakken en pikt hem op.
   - Wie niet aan boord is, blijft achter: hij komt als vervangrobot terug op het schip.
   - De firma rekent de vervanging aan, en wat hij droeg, is weg.
9. **Taxatie aan boord.**
   - Je draagt de vondsten uit het laadruim door de **taxatiepoort**. Elk stuk wordt één voor één onthuld: soort, gaafheid, waarde.
   - **Verkopen** = geld in de teamkas. **Schenken** aan het museum = reputatie en ontgrendelingen.
   - Erts wordt automatisch verkocht.
10. **Quota.**
    - Een kwartaal is 3 diensten, met een geldoel dat schaalt met het aantal spelers.
    - Wie het doel mist, krijgt een **boete** (schuld) en verliest reputatie.
    - **Upgrades en het museum blijven altijd behouden.** Reputatie bepaalt welke planeten je mag doen.
    - Eerste versie (M3): drie concessies per dienst met een risico (meer opbrengst, sneller magma), doel €2.000 voor 4 spelers (40/65/85/100% voor 1–4), ×1,25 per kwartaal, boete 50% van het tekort. Cijfers in `company.cfg`.
    - **Bijgestuurd 2026-10-05 (release-audit, F1):** doel €5.000 voor 4 spelers, ×1,4 per kwartaal. Een dienst is pas afgesloten als de buit verkocht is (of het hoofdkantoor hem opkoopt aan 60% als je tekent); pas dan valt het oordeel over het kwartaal. **Schuld bevriest de rekening** (geen upgrades) en kost 10% rente per dienst; **reputatie onder 0 = proeftijd**: geen opdracht met hoog risico. Elke opdracht heeft 2–3 voorwaarden (een troef van de planeet, risico's, soms een doelvondst). Een volledige skeletset verkocht na dezelfde dienst = dubbele waarde. Zie lessons.md (2026-10-05, F1).

### Waarom deze lus werkt
- De quota met boete zorgt voor spanning: "nog één fossiel of nu naar boven?"
- Het magma stijgt van onderen, terwijl de beste vondsten diep zitten. Dat is de hebzucht-tegen-veiligheid-afweging. Het is de enige klok: geen tweede timer erbovenop. *DRG: Rogue Core* verloor zijn spelers deels door een strenge timer.
- Uitbikken tegenover boren is een voortdurende afweging tussen tijd en waarde. Erts is zeker geld, een vondst is een gok met een grote uitbetaling.
- Samen dragen en fysica-ongelukken leveren de clips. De drop en de grijper zijn de twee grote momenten van elke dienst.
- De Mol is de veilige thuis in het donker, maar elke meter die hij boort maakt lawaai.

---

## 4. Wereld

### De planeet (per dienst nieuw, uit een zaad)
- **Speelgebied ±250 × 250 m, ±300 m diep.** Voxels van 0,5 m (500 × 600 × 500).
  - Het terrein laadt rond de spelers en de Mol (streaming).
  - Graafacties worden per blok opnieuw toegepast zodra dat blok laadt, zodat elke peer hetzelfde ziet.
- **Bovenaan een oppervlak in open lucht:** een kale buitenaardse vlakte met kraters en rotsblokken, onder een vreemde hemel met manen en ringen. De Ekster hangt hoog in de lucht.
- **Rand:** een onbreekbare buitenmuur, het concessiegebied van DIG. De Mol stopt ervoor.
- **Grotten** op elke diepte, waarvan enkele groot genoeg voor de Mol.
- **Terrein kan je enkel wegnemen, nooit toevoegen.** Daardoor maakt de volgorde van graafacties niet uit en blijft de synchronisatie eenvoudig.

### Lagen
Elk planeettype heeft 4–5 lagen van ±60 m, elk met een eigen kleur **en** een eigen patroon (leesbaar, ook voor kleurenblinden). Voorbeeld voor het eerste type, **Roestbol** (roestwoestijn):

| Laag | Graven met | Erts | Vondsten | Gevaar |
|---|---|---|---|---|
| Stof en klei | alles | koper | rommel van vorige bezoekers, munten | weinig |
| Zandsteen | boor T1 | ijzer | fossielen, oud gereedschap | onstabiele zones |
| Basalt/graniet | boor T2 | goud | geodes, grote skeletten, relieken | gasbellen |
| Kristal | boor T2 | kristal | lichtgevende kristallen (breekbaar) | gas, de Graafworm |
| (Kern) | boor T3 | zeldzaam | — | magma dichtbij |

**Regels:**
- De boor-tier bepaalt of je een laag *doorkomt*. Het houweel bikt korsten en delft erts in *elke* laag.
- De waarde zit verspreid, ook opzij: rijke zakken, fossielbedden en grotten liggen op elke diepte. Recht naar beneden graven levert niets extra op. Samen met het magma dat van onderen stijgt voorkomt dat de skip die Keep Digging kapotmaakte.

### Planeettypes (in plaats van vaste sites)
| Type | Early Access | Kenmerk |
|---|---|---|
| Roestbol | ja | begeleide eerste opdracht (tutorial), roestwoestijn, klei + zandsteen bovenaan |
| Fossielwereld | ja | veel grote, zware skeletten in stukken: samenwerken |
| Kristalmaan | ja | breekbare, lichtgevende buit, gas, de Graafworm |
| Vulkaanplaneet | later | snel magma, basalt, hittepak |
| Verzonken beschaving | later | ingestorte ruïnes in de rots (zuilen, trappen), relieken |
| Waterwereld | later (idee playtest 2026-10-06) | onder water graven: druk die met de diepte stijgt, risico op implosie |

Na Early Access komen nog een eindeloze "diepe dienst" en een wekelijkse planeet met een vast zaad.

### Buit
- **Erts** (vast inkomen): aders en clusters in de rots, met per laag een eigen soort.
  - Je delft het met houweel of boor. Het gaat in je **ertszak** (±40 stuks) en je geeft het af aan de trechter van de Mol.
  - Het telt enkel als de Mol terugkomt.
- **Vondsten** (de haak), in vijf families met veel variatie:
  1. **Skeletten:** alien-fossielen in 3–8 stukken per skelet, voor het museum.
  2. **Relieken:** beelden, maskers en vazen van verdwenen beschavingen, uit bouwblokken met varianten.
  3. **Kristallen en geodes:** gloeiend en breekbaar.
  4. **Metalen:** goudklompen, munten, oude machines.
  5. **Rommel van eerdere bezoekers** (een tuinkabouter, een oude tv, een fles): weinig waard maar grappig. Een concurrent was hier al.
- Elke vondst zit in een korst. Ze liggen geconcentreerd in fossielbedden en rond grotten, niet uniform. Elke waardeklasse heeft een eigen geluid en glans.
- **Samen dragen op elke planeet (golf 3, ontwerp-8):** niet enkel de Titans van Fossielwereld zijn te zwaar voor één robot. Op Roestbol ligt in een deel van de kampen de loonzak van een vorige ploeg (24 kg), op de Kristalmaan in een deel van de kristalgrotten een reuzengeode (26 kg, breekbaar): ±2 en ±4 per wereld. Zware stukken hebben **twee handgrepen** (de uiteinden): met twee houdt elk zijn greep vast en spant de vondst ertussen; het touw is de afstand tussen de grepen plus de armen (een titanschedel ±3 m, was 4,9 m). Ter goedkeuring van Jayme: beide zijn vergrote versies van een bestaand model (muntzak, geode), geen nieuw model.

---

## 5. Gereedschap en uitrusting (±8 in Early Access)

**Principe:** elke upgrade laat je iets *nieuws* doen, niet enkel iets sneller.

**Slots:** 2 handgereedschappen, 1 gadget en verbruiksgoederen.

| Item | Upgrades en wat ze openen |
|---|---|
| **Houweel** (start) | sneller bikken, precisiemodus |
| **Boor** T1 → T2 | zandsteen, daarna graniet en kristal. Snel en luid, beschadigt buit |
| **Grijphandschoen** | zwaardere stukken solo, groter bereik, demper tegen botsschade |
| **Scanner** | T1: blips. T2: waarde en type. **Nooit** "alles zichtbaar". De Mol heeft een vaste sonar (T1: stil 12 m, PING 24 m maar luid) in de cabine; de handscanner is voor te voet (F1: Q, in de linkerhand, één stille puls tot 10 m) |
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

> Toegevoegd in v2.1 op vraag van Jayme. Werknaam. Vervangt de lift uit M1. In v3: gedropt vanuit De Ekster, opgepikt met een grijper.

Een grote rupsvoertuig-drilboor (±10 m lang, ±6 m breed) van DIG: vooraan een draaiende boorkop met snijtanden, daarachter een cabine met ramen en koplampen, een laadruim en een motor met uitlaat. De Mol is jullie **basis**, jullie **transport** en jullie **extractie** in één.

**Rol in een dienst**
- **Drop:** de Mol hangt in de dropbaai van De Ekster en wordt met de hele ploeg erin op de planeet gedropt (gloed, stuwraketten, landing in een stofwolk).
- **Afdalen:** de Mol boort vanaf de oppervlakte naar beneden, zelf gestuurd of met de autopiloot.
- **Rijden:** tijdens de dienst kan hij verder rijden en grote tunnels boren (±6 m breed), ook schuin omhoog of omlaag (begrensde helling).
- **Laadruim:** buit die erin ligt bij vertrek, telt. De capaciteit is beperkt (gewicht).
- **Extractie:** terug omhoog door zijn eigen tunnel; aan de oppervlakte laat De Ekster een grijper zakken die hem oppikt (zie §3).
- **Ertstrechter:** spelers geven hun erts af aan een trechter aan de Mol.
- **Neergegane robots** sleep je naar de Mol om ze te repareren (§6).

**Besturing:** één piloot in de cabine; iedereen mag piloot worden. De anderen rijden mee, binnen of op het dek.

**Traag, luid en beperkt** (zodat met de hand graven en uitbikken de kern blijven):
- traag (±1,5 m/s rijden, trager tijdens het boren); **uitzondering (golf 3):** met de neus omlaag boort hij sneller, tot ±2,7 m/s bij de grootste helling (±1,1 m/s verticaal), voor piloot en autopiloot gelijk. De afdaling naar het zandsteen duurde 2:40, 15–30 % van de dienst stilzitten (ontwerp2-8); nu ±1:10. Rijden blijft traag;
- **luid**: rijden en boren doen de onrust sterk stijgen, en de Graafworm komt erop af;
- **brandstof** per dienst is beperkt;
- de **boorkop** volgt de laagregels (T1: klei en zandsteen; betere koppen zijn upgrades).

**Binnenruimte (klein):** een cabine (stoel, stuur, dieptemeter, sonar: ronde beeldbuis met vage blips en hun hoogte, zie [de-mol.md](de-mol.md)), een laadruim met laadklep, en een werkbank (upgrades, later). Warm licht en een gezellige thuis in het donker, zoals de drop pod in Deep Rock Galactic.

**Upgrades (later):** boorkop (graniet, kristal), snelheid, brandstoftank, laadruim, hitteschild tegen lava, lier/kraan, lampen, cosmetica (verf, stickers).
- **Sinds 2026-10-05 (F1) te koop aan de Mol-werf:** boorkop T2 (graniet en kristal) en een groter laadruim (60 → 140 kg). Te zwaar: de hendel weigert, en wat niet past, valt eruit als de grijper vastklikt.

**Techniek:** de host simuleert de Mol (de piloot stuurt invoer), kinematisch (AnimatableBody3D), met grote terreinbewerkingen vooraan. Wie meerijdt, staat op een bewegend platform; clients interpoleren. Het lift-platform uit M1 is hiervoor de basis.

---

## 6. Gevaren en wezens

- **Magma:** een stijgend vlak met shader en een dodelijke zone, de enige klok van een dienst. Geen stromingssimulatie. Het slokt losse buit op. Eerst 2 min stil, dan steeds sneller (zonder bevingen na ±21 min boven); elke beving zet de klok 40 s vooruit; op −60 m komt de noodophaling ([onderzoek](research/magma-en-onrust.md), cijfers in `magma.cfg`).
- **Instortingen:** vallende rotsblokken (fysica-objecten) met stof in **gemarkeerde onstabiele zones**. Spannend en vermijdbaar, en het terrein verandert er niet door. **Hoe dieper, hoe groter de kans** (playtest 2026-10-06): dieper liggen meer zones, en een instorting laat puin achter dat je wegbikt (losse blokken, geen nieuw terrein).
- **Gasbellen:** een zichtbare gele waas, en de T2-scanner toont ze. Ze ontploffen bij vonken, bijvoorbeeld van de boor.
- **Graafworm** (het enige wezen in Early Access):
  - Hij zwemt onzichtbaar door de aarde, zonder het terrein te veranderen.
  - Je merkt hem aan gerommel, trillingen, stof en een markering op de grond.
  - Hij komt af op lawaai en duikt enkel op in open ruimtes.
  - Hij slokt losliggende buit op en sleurt die weg, en kan spelers omverduwen.
  - Lichtbakens en lokaas houden hem op afstand. Er zijn geen wapens.
  - Op de sonar van de Mol verschijnt hij als **grote stip** die nadert (playtest 2026-10-06).
- **Later:** een kristalspin (trekt spelers mee, via een gescripte "gesleept"-toestand op de client van het slachtoffer) en een lavaslang. Idee uit de playtest van 2026-10-06: kleine grotwezens ("googlies") in grotten met goede buit, zodat een grot verleidelijk én gevaarlijk is.

### Neergaan: je wordt zelf buit
- Een neergegane robot wordt een **draagbaar object**: een **ragdoll** (ook bij een harde klap of val even), zodat slepen en vallen grappig is (playtest 2026-10-06).
- Je team moet je naar de Mol slepen om je te repareren. Dat hergebruikt het draagsysteem en levert gegarandeerd grappige momenten op.
- Ben je volledig kapot, dan kijk je mee als spookdrone. Je kan niet praten met de levenden, en dat is de grap.
- Je progressie verlies je nooit, enkel wat je droeg.

### Uitwerking (pakket F2, 2026-10-05; keuzes waar het GDD zweeg, ter info voor Jayme)
Cijfers in `rescue.cfg`, `worm.cfg`, `beacon.cfg`, `gas.cfg` en `collapse.cfg`.
- **Levens en neergaan.** Een robot heeft levens (100%). Vallen in de put (niet uit De Ekster), rotsen (klein 15%, groot 40% en even omver), de worm (45% en omver), gas en de hittezone (20%/s) kosten levens. Op 0% ga je neer: een ragdoll die je ploeg 90 s lang naar de Mol kan brengen. Een robot weegt 24 kg, dus dezelfde regels als zware buit (pakket F3): alleen sleep je hem over de grond, met twee til je hem. In de Mol: na 4 s recht met 50%; in de Mol herstel je ook langzaam.
- **Niemand die kan dragen** (solo, of de rest ligt neer): na 2,5 s krabbel je recht en strompel je zelf naar de Mol (traag, zonder gereedschap), met dezelfde tijd. Zo blijft solo speelbaar.
- **Kapot** (de tijd is op, of gesmolten): spookdrone tot de dienst voorbij is. Een wrak telt als achtergebleven, gesmolten als gesmolten. **Smelten zet je dus niet meer in de Mol** (ontwerp-7: dat was de snelste weg naar huis). Ligt iedereen neer of is iedereen kapot, dan haalt DIG de Mol op.
- **Graafworm.** Slaapt de eerste 2,5 min, zwerft daarna rond de ploeg en jaagt op lawaai (boor, Mol, PING, toeter, ontploffing). Hij valt enkel uit waar 2 m boven de vloer nog ruimte is: in een smalle, zelfgegraven gang ben je veilig. Eerst 1,3 s waarschuwing, dan een boog op borsthoogte door de ruimte. Opgeslokte buit dumpt hij in een grot minstens 50 m verder. De toeter lokt hem naar de Mol (de piloot redt zo de gravers).
- **Lichtbakens.** Drie per dienst voor de ploeg (G), ze branden 2 min; binnen 14 m valt de worm niet uit en ramt hij de Mol niet. Pakket F1 kan er meer verkopen.
- **Gas.** Bellen in grotten (zichtbaar) en opgesloten in de rots (die sissen eerst 2 s als je ze openbreekt), pas vanaf 35 m diep en dieper meer, niet bij de landingsplek. De boor, de boorkop van de Mol, een andere ontploffing en het magma ontsteken ze; het houweel niet.
- **Instortingen.** Hoe dieper, hoe meer onstabiele zones en hoe groter de kans dat een zone tussen de bevingen door vanzelf instort (vanaf 20 m, groeiend met de diepte, de onrust en het einde van de dienst). Grote rotsen blijven liggen als puin dat je tegenhoudt en wegbikt.
- **De climax.** De spanning groeit met het magma; vertrekt de Mol, dan is ze vol: de worm is sneller, valt vaker uit en hoort verder. De motor van de vertrekkende Mol lokt hem, en op de terugweg ramt hij de Mol: elke vondst in het laadruim verliest 12% gaafheid, de Mol valt even stil en wie staat gaat omver. Een baken in de Mol houdt hem af. Een oververhitte Mol wordt nog opgehaald, maar de lading verschroeit (−40%).
- **Het magma als klok** staat onder de grond altijd in de HUD, met wanneer het op jouw diepte is.
- **Per planeet en per opdracht.** De factoren van pakket F3 (`planets.cfg`: `gas_mult`, `worm_mult`, `quake_mult`; Kristalmaan meer gas en een onrustigere worm) en de voorwaarden van pakket F1: "Shaky ground" geeft meer onstabiele zones en twee keer zoveel kans op een instorting, "Hot core" laat het magma sneller stijgen.

### Golf 3 (pakket G2, 2026-10-06; ter info voor Jayme)
Geluid blijft een apart spoor: de code geeft enkel haken (signalen) waar een geluid hoort (`Gas.fuse_lit`, `Gas.exploded`, `Collapse.started`, `Unrest.quake_warning`/`rumble_level()`/`rock_landed`/`rubble_chipped`, `Rescue.damaged`, `ImpactFx.hit`, `FindField.shattered`). Wat je nu ziet aankomen, zonder geluid:
- **Beving (golf 3):** in de 4 s aankondiging hapert de helmlamp steeds vaker, sijpelt er gruis uit het plafond vóór je en rolt het beeld steeds harder; bij de hoofdschok vallen er rotsen in beeld.
- **Instorting (golf 3):** de waarschuwing duurt 2,2 s (was 1,6) en zwelt aan: rollen, steentjes uit het plafond van de zone, de lamp hapert. Puin is echte rots (laagkleur, facetten) die barst en krimpt per slag en in brokken uiteenvalt.
- **Gas (golf 3):** in een bel staat de waarschuwing op een donker plaatje en gloeit de rand van het scherm geel, nog vóór er een vonk is. De lont duurt 0,9 s (was 0,6) met vonken, een aanzwellende oranje gloed en een trillend beeld.
- **Een klap (golf 3):** hit-stop (het beeld blijft 0,14 s staan), een flits in de kleur van de bron en een FOV-stoot, dan glijdt het beeld naar een volgcamera die nooit in je robot, een maat of de Mol zit (in de Mol een vast camerapunt). Gedragen draait ze mee met je drager. Opstaan in de kijkrichting van de camera.
- **Een maat dragen (golf 3):** alleen hou je hem onder de oksels vóór je (zijn gezicht naar jou, de benen slepen met stof); met twee ligt hij tussen jullie in.
- **Spookdrone (golf 3):** "ROBOT BROKEN" staat 4 s in beeld, daarna een zoeker met REC, de ploeg en je toetsen.

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

- **Drie plekken:**
  - **De Ekster:** buiten in **Helldivers-stijl** (gekozen door Jayme op 3 oktober 2026, na onderzoek: [schip-ontwerp](research/schip-ontwerp.md), [nostromo-stijl](research/nostromo-stijl.md)). Een lang oorlogsschip van ±170 m met hamerkop en kaak, een lange rug en twee motorarmen. Donker grijs met gele DIG-lijnen, en containers met gestolen lading op de rug. Binnen: een aparte ruimte waar je rondloopt (dropbaai met de Mol, terminal, taxatiepoort, museum, werkbank). De binnenkant wordt ontworpen in overleg met Jayme.
  - **Het oppervlak van een planeet:** kaal en buitenaards, met een sterke hemel (manen, ringen, nevel). Geen bomen of water.
  - **Ondergronds:** donker, de kern van het spel.
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
| Terrein | **godot_voxel 1.7 GDExtension** (werkt met de standaard Godot-editor en exporttemplates), `VoxelTerrain` zonder LOD, Transvoxel smooth mesher, blokgrootte 16. Afgeschermd achter een eigen `TerrainAPI`-laag. Vanaf v3 **streaming**: een `VoxelViewer` per speler en op de Mol; graafacties staan in een ruimtelijk op-logboek en worden opnieuw toegepast zodra een blok laadt |
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

> Herzien op 2 oktober 2026 (v3). Uiterlijk en de Mol zijn klaar (M2). Op vraag van Jayme komt nu **eerst de kernlus**, met de nieuwe wereld (planeet, moederschip, drop). **Geluid en Steam/voice beslist Jayme zelf** en komen later. Alles wat gebouwd wordt, werkt meteen in co-op via het bestaande netwerk.

| Mijlpaal | Doel | Inhoud | Poort |
|---|---|---|---|
| **M0 Opzet** | ✅ 1 oktober 2026 | Repo, Godot 4.7.2, voxel- en GodotSteam-extensies samen, Windows-export, render- en performancetest | Jayme start de build en kan graven |
| **M1 Graafspeelgoed** | ✅ 1 oktober | First-person robot, graven, korsten uitbikken, dragen, lift. Al met netwerk (ENet, host/join). Tuning-menu | **Poort 1:** voelen graven en slepen goed? |
| **M2 Uiterlijk** | ✅ 1 oktober | De Mol (model en werking), gereedschap, vondsten en puin in Blender, rots en licht, HUD en menu's, sonar | "Ziet het eruit als een game?" |
| **M3 Kernlus** | oktober | **De planeet** (±250 × 300 m met streaming, oppervlak en hemel, erts, gespreide vondsten). **De Ekster** (moederschip als basis), **drop** en **extractie met de grijper**. Opdracht en quota, teamkas, taxatie, opslaan (museum uitgesteld, Jayme 2026-10-03). Magma en onrust met bevingen. Sonar met PING | De eerste versie die "een game" is |
| **M4 Inhoud** | november | Graafworm, gas, alle ±8 items, 3 planeettypes, neergaan en redden, cosmetica, mutators, opdrachten met uitdaging | |
| **M5 Samen** | Jayme beslist | Steam-lobby's en uitnodigingen, voice, getest met 150 ms vertraging | **Poort 2:** 30 min met drie vrienden zonder problemen, en is het leuk? |
| **M6 Geluid** | Jayme beslist | Inslagen per materiaal, de Mol, sfeer, muziek | |
| **M7 Demo** | februari–maart 2027 | Demo (vroeg, lang laten staan), capsules, trailer, Steam-pagina | Steam-pagina "Coming Soon" zodra het Steamworks-account er is. **Next Fest juni 2027** blijft de vaste datum (inschrijven voor 25 april) |

**Wat het tempo bepaalt:** hoe snel Jayme, Ian en Anir kunnen playtesten, en de wachttijden bij Steam. Niet het programmeren.

### Stopcriteria
- **Poort 1 faalt** (graven en slepen voelen niet goed): bijsturen of stoppen, na enkele weken in plaats van maanden.
- **Poort 2 faalt** (netwerk werkt niet betrouwbaar): terug naar een eenvoudiger model, of pivoteren.
- **GONE DIGGING of A Game About Digging A Hole Together blijkt bij release bijna identiek:** archeologie, het museum en de drop met de Mol nog verder als hoofdzaak naar voren schuiven.

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
| Concurrentie (GONE DIGGING Q2 2027, A Game About Digging A Hole Together H2 2026) | Archeologie, het museum en de drop met de Mol als haak; demo vroeg (februari–maart 2027) en lang laten staan |
| Grote wereld met streaming (250 × 300 m) | Op-logboek per blok, viewers per speler, vroeg meten op een mid-range pc; vondsten als data tot iemand in de buurt komt |

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

### v2.1 → v3 (2 oktober 2026, met Jayme)
1. **Nieuwe achtergrond:** jullie werken voor een louche intergalactisch bedrijf (DIG) dat planeten leegrooft, met humor. Het depot wordt het moederschip **De Ekster** in een baan om de planeet.
2. **Begin en einde van een dienst:** de Mol wordt met de ploeg erin op de planeet **gedropt** (zoals in Helldivers), en aan het einde rijdt hij naar de oppervlakte waar het schip hem met een **grijper** oppikt.
3. **Grotere wereld:** ±250 × 250 m en ±300 m diep in plaats van 64 × 64 × 160 m, met streaming, en een oppervlak in open lucht. Per dienst een nieuwe planeet. Sites worden planeettypes.
4. **Buit:** erts als vast inkomen (ertszak, trechter aan de Mol) én alien-vondsten in een korst voor het museum.
5. **Lava wordt magma**, de enige klok. Onrust volgt enkel lawaai.
6. **Sonar:** stil kort en vaag, een PING scherp maar luid (onderzoek: "nooit alles zichtbaar").
7. **Planning:** eerst de kernlus (M3), dan inhoud (M4). Steam/voice en geluid beslist Jayme. Alles blijft co-op via het bestaande netwerk.
8. Onderzoek naar plezier en design: [research/plezier-en-design.md](research/plezier-en-design.md).

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
