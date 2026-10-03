# Magma en onrust: hoe andere games het doen

Onderzoek, 2026-10-03.

**Aanleiding.** GDD §3 en §6 zeggen dit:

1. Magma stijgt van onderen. Het is de **enige klok** van een dienst: een stijgend vlak met een shader en een dodelijke zone, zonder stromingssimulatie. Het slokt losse buit op.
2. Onrust stijgt **enkel door lawaai**: boren, de Mol, pings en explosies. Er komt geen extra onrust per speler bij.
3. Bij elke drempel beeft de planeet. Rotsblokken vallen in **gemarkeerde** zones (fysica en stof, het terrein verandert niet) en het magma maakt een sprong.
4. Upgrades mogen magma en onrust *beheren*, nooit uitzetten.

Er waren nog geen cijfers: hoe snel het magma stijgt, hoeveel lawaai een actie maakt, hoe lang een waarschuwing duurt. Geluid is aan Jayme: hieronder staan geluiden enkel als **[plaatshouder]**.

## Kort

1. **Een zichtbare klok die geleidelijk erger wordt, werkt. Een harde omslag niet.**
   - *DRG: Rogue Core* wordt in één keer "kritiek", en dan komt er om de 20 s een onsterfelijke worm bij. Spelers vroegen om een "zachte timer". De makers gaven binnen een dag meer tijd.
   - Wat wel werkt: de mist en de lava in PEAK, de oplopende golven bij Point Extraction in DRG, en de noodophaling in Helldivers 2 als de tijd op is.
2. **Begin traag en word dan gestaag sneller.**
   - In de Kiln van PEAK begint de lava pas na 3 min te stijgen, en na 20 min is ze boven.
   - Voorstel: 2 min stil, en zonder bevingen is het magma na 21 min aan het oppervlak. Een gewone ploeg met ±5 bevingen haalt ±17,5 min.
3. **Lawaai is een prijs, geen straf.** Elke beving zet de magmaklok **40 s vooruit**. Zo betaal je je lawaai in tijd, en dat kies je zelf.
   - Toon het eigen lawaai, zoals Barotrauma en Subnautica dat op de sonar doen.
   - Lethal Company toont dat een teller die langzaam weer zakt goed werkt.
4. **Waarschuw in lagen, en zwaarder naarmate het gevaar groter is.**
   - Spelers klagen dat bevingen in DRG weinig waarschuwing geven. Voor een zwerm geeft DRG wel 20 s.
   - Voorstel in drie lagen: een voorschok bij 80% onrust, 4 s aankondiging voor de beving, en per rots 1,2 s een stofstraal voor hij valt.
5. **Lees de tijd af als afstand, niet als klok:** een merkteken op de dieptemeter van de Mol, de afstand op de HUD zodra je dichtbij komt, en gloed van onderen die de rots opwarmt. (In Lethal Company zie je de klok enkel buiten. Spannend, maar daar is het ook de enige info.)
6. **Magma aanraken is niet meteen dood.** Er is een hittezone, en wie erin valt, zinkt 1,5 s lang. In die tijd kan een ploegmaat hem eruit trekken. Losse buit is weg (zoals in Minecraft). De Mol houdt het even uit.
7. **De klok is gedeelde toestand bij de host:** `{starttijd, voorsprong}`. Elke peer rekent de hoogte zelf uit. Enkel de host beslist over schade en verlies.

## 1. Stijgend gevaar als enige klok

### Hoe anderen het doen

- **DRG: Rogue Core.**
  - Als de tijd op is, wordt de dreiging "kritiek". 30 s later komt een ReaperWorm, en daarna elke 20 s nog een ([wiki](https://deeprockgalactic.wiki.gg/wiki/Rogue_Core:ReaperWorm)).
  - Wat spelers zeggen: "alles is goed en dan zijn de vijanden plots oneindig". Een run van 30 min ging verloren in de lift. De achterblijver straft de hele ploeg. En twee drukmiddelen samen (munitie en tijd) is te veel ([Steam](https://steamcommunity.com/app/2605790/discussions/0/838376971028276655/), [GamesRadar](https://www.gamesradar.com/games/fps/deep-rock-galactic-roguelike-spin-off-launches-to-mostly-positive-steam-reviews-that-cant-decide-if-they-love-or-hate-its-timer-and-shared-progression-tool/)).
  - Patch 00.07.09 kwam binnen 24 uur: +10% tijd op diepte 1, +5% op diepte 2, en een tragere escalatie ([dlcompare](https://www.dlcompare.com/gaming-news/deep-rock-galactic-rogue-core-responds-swiftly-to-community-feedback-77265)).
  - Later kwam een tempokeuze: voorzichtig, standaard of roekeloos ([patch](https://roguecore.wikily.gg/patch-notes/1834602721184902)).
- **DRG.**
  - Point Extraction heeft een zachte klok. De eerste zwerm komt na 4:29 (3:59 op hoge moeilijkheid), daarna om de 5:40, 5:30 en minstens 5:20. Kleinere golven komen sneller, 1 s per golf ([Swarm](https://deeprockgalactic.wiki.gg/wiki/Swarm)).
  - Gewone zwermen komen om de 160 à 500 s, afhankelijk van de moeilijkheid. Ze worden **20 s op voorhand** aangekondigd door Mission Control, met muziek.
- **PEAK.**
  - De mist begint te stijgen als iedereen een hoogte voorbij is, of na 1000 s. Hij komt lineair dichterbij.
  - In de Kiln is het lava: ze start 3 min na het kampvuur, en na 20 min is ze boven. Ze doet 25 Injury en ±30 Heat per seconde ([Fog](https://peak.wiki.gg/wiki/Fog)).
- **Lethal Company.**
  - Een dag duurt 700 s ([Time](https://lethal-company.fandom.com/wiki/Time)). Je landt om 8:00, en om middernacht vertrekt het schip.
  - De klok staat enkel op het scherm als je buiten bent. Om 22:12 komt een waarschuwing ([HUD](https://lethal.miraheze.org/wiki/HUD)).
  - In de loop van de dag komen er monsters bij. Het advies aan nieuwe spelers: 's morgens doorwerken, weg als het donker wordt ([wiki](https://lethal.miraheze.org/wiki/Lethal_Company)).
- **Dome Keeper.**
  - Een cyclus duurt `60 + 45·√(tegels/1000)·ijzer%` s ([Relic Hunt](https://domekeeper.wiki.gg/wiki/Relic_Hunt)). Je ziet een aftelling, en er gaat een alarm af.
  - De sfeer verandert per soort monster, zodat ervaren spelers "veel uit de ambient lezen" ([Game Developer](https://www.gamedeveloper.com/business/how-dome-keeper-focuses-on-systems-that-feed-into-one-another)).
  - Te vroeg terug is verspilde tijd, te laat terug kost schade. "Net op tijd binnen" is de grote kick ([Anthony](https://joshanthony.info/2023/05/24/design-dive-dome-keeper/)).
- **Spelunky.** In HD komt na 2:30 de tekst "A terrible chill runs up your spine!" en verschijnt de geest. In Spelunky 2 gebeurt dat na 3:00, met grijze mist en muziek die trager en lager wordt ([HD](https://spelunky.fandom.com/wiki/Ghost_(HD)), [2](https://spelunky.fandom.com/wiki/Ghost_(2))).
- **Risk of Rain 2.**
  - Moeilijkheid = `(spelerfactor + minuten × 0,0506 × moeilijkheid × spelers^0,2) × 1,15^etappes`.
  - Op de HUD vult een balk zich met namen die oplopen van "Easy" tot "HAHAHAHA". Dat is grappig en meteen leesbaar ([wiki](https://riskofrain2.wiki.gg/wiki/Difficulty)).
- **Helldivers 2.** Als de tijd op is, vertrekt de Super Destroyer: geen steun meer en geen versterking. Een noodshuttle komt wel nog vanzelf. Je verliest dus geen alles-of-niets ([Extraction](https://helldivers.wiki.gg/wiki/Extraction)).
- **Platformers.**
  - In "Rising Tides of Lava" (NSMBU) stijgt de lava en zakt ze weer, met veilige pauzes ([Mario Wiki](https://www.mariowiki.com/Rising_Tides_of_Lava)).
  - In Celeste (Core) zet je met schakelaars de lava om: ze kan stijgen of zakken. Dat is beheren, niet uitzetten ([wiki](https://celeste.ink/wiki/Core)).
  - In de Roblox-game "The Floor Is LAVA!" heb je 15 s om te klimmen. Daarna is er 40 s lava die je **langzaam** doodt, en dan 20 s pauze ([wiki](https://roblox.fandom.com/wiki/Player:TheLegendOfPyro/The_Floor_Is_LAVA!)).
- **Keep Digging.** Recht naar beneden graven was te sterk ([Vaporlens](https://vaporlens.app/app/3585800/keep_digging)). Bij ons stopt het magma van onderen dat, samen met de waarde die opzij verspreid ligt (GDD §4).

### Tempo

- Geen enkel goed voorbeeld begint meteen op volle kracht. PEAK wacht 3 min, en DRG wacht 4:29 tot de eerste golf.
- Waar het zwaarder wordt, gaat dat geleidelijk: RoR2 per minuut, DRG Point Extraction per golf. Waar het in één keer omslaat (Rogue Core), komt kritiek.
- **Afgeleid:** traag starten, dan een bijna constante snelheid die licht oploopt. Constant is het makkelijkst te schatten ("nog 40 m, dat haal ik"). Het lichte versnellen zorgt voor een duidelijk einde zonder harde knip.

### Hoe lees je hoeveel tijd je nog hebt?

- Een klok of balk op de HUD (Dome Keeper, RoR2, Rogue Core), een stem (Mission Control) of een tekst (Spelunky, Lethal Company om 22:12).
- Iets in de wereld zelf: de mist in PEAK, die je zicht ook echt wegneemt, de muziek van Spelunky, de ambient van Dome Keeper.
- **Bij ons** is de klok zelf zichtbaar, want het is het magma. Dat is het sterkste wat je kunt hebben, zolang je het van ver ziet (§4) en de afstand kunt aflezen (Aanbeveling G).

### Eerlijk of straffend?

- **Eerlijk:** zichtbaar en geleidelijk, gekoppeld aan keuzes van de spelers, een waarschuwing die groeit met het gevaar, een zachte afloop (Helldivers 2), en een vluchtweg. In DRG hebben de spleten van een beving veilige plekjes, zodat je eruit kunt ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/AntiFrustrationFeatures/DeepRockGalactic)).
- **Straffend:** een harde omslag, een aanwijzing die je mist in de drukte (bevingen in DRG tijdens een zwerm, [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/ThatOneLevel/DeepRockGalactic)), twee klokken tegelijk, en de hele ploeg straffen voor één achterblijver.

## 2. Lawaai en onrust

- **DRG.** Gewoon boren en schieten roept geen zwerm op: zwermen komen op een timer ([Swarm](https://deeprockgalactic.wiki.gg/wiki/Swarm)). Alleen grote machines trekken aan. Als de Drilldozer in een wand boort, start er **altijd** een zwerm, en die duurt zolang hij boort ([Escort Duty](https://deeprockgalactic.fandom.com/wiki/Escort_Duty)). Dat lijkt sterk op onze Mol.
- **Barotrauma.** Lawaai heeft een bereik: actieve sonar 80 m, motor 50/60/70 m bij volle kracht, reactor 40 m, handsonar 60 m. Met de passieve sonar zie je hoe luid je eigen duikboot is ([wiki](https://barotraumagame.com/wiki/Common_Misconceptions)). Actief pingen = gezien worden. Dat is precies onze PING.
- **Subnautica.** De sonar van de Cyclops toont het lawaai als een blauwe bol: klein bij gewone snelheid, bijna het hele scherm bij volle snelheid. "Silent running" halveert het lawaai en kost 1 energie per seconde ([wiki](https://subnautica.fandom.com/wiki/Cyclops)).
- **Lethal Company.** De Eyeless Dog hoort je als `afstand < 18 × luidheid`, en zonder zichtlijn telt de helft. Een geluid van 0,25 of meer telt +1 verdenking. De verdenking **zakt met 1 per 4 s**, en bij 9 valt hij aan ([Eyeless Dog](https://lethal.miraheze.org/wiki/Eyeless_Dog)). Dat is een teller met een drempel en traag verval.
- **Alien: Isolation.**
  - Er zijn drie standen van stappen (sluipen, wandelen, lopen). Wapens en zelfs een tik met de sleutel wekken veel sneller de aandacht.
  - Een "menace gauge" meet de druk. Zit die aan zijn top, dan trekt de director het alien terug om de speler rust te geven ([Game Developer](https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation)).
- **Hunt: Showdown.** Kraaien, honden en stervende paarden zijn geluidsvallen die je plek verraden ([PC Gamer](https://www.pcgamer.com/lets-hear-it-for-hunt-showdowns-incredible-sound-design/)). Lawaai wordt zo een signaal dat iedereen leest.
- **Iron Lung.** Je merkt het monster enkel aan geluid en foto's, en het wordt in de loop van het spel agressiever ([wiki](https://iron-lung.fandom.com/wiki/The_Monster_(Game))).

**Wat dat voor ons betekent [afgeleid]:**

- **Een meter met bronnen.** Een balk in de stijl van PEAK, waarin elke bron een eigen kleur heeft (zie [hud-menu](hud-menu.md) #5, maar zonder "tijd": GDD zegt enkel lawaai).
- **Ook in de wereld.** Een seismograaf op het dashboard van de Mol, stof dat begint te vallen, kleine schokken.
- **Verval: ja, maar traag**, en enkel na een stille periode, zoals in Lethal Company en Alien: Isolation. "Even stil zijn" mag een beetje helpen. Wachten kost zelf al magmatijd, dus misbruik loont niet.
- **Stemmen zijn nooit lawaai.** In Lethal Company horen monsters wel geluid, maar bij ons is praten de kern van de fun.

## 3. Bevingen en vallende rotsen

**DRG (Magma Core).**
- De eerste beving komt na (willekeurig 3–60)² s, de volgende telkens na 2–6 min.
- Een beving duurt 9 s. Dwergen bewegen ×0,5, wezens ×0,75. De grond kan openscheuren tot spleten vol hete rots.
- De waarschuwing is enkel gerommel ([wiki](https://deeprockgalactic.wiki.gg/wiki/Magma_Core)).

**DRG (Salt Pits).** Zoutstalactieten vallen als je erop schiet of als er iets ontploft: 20 directe en 1000 kinetische schade, in een straal van **1,5 m** ([wiki](https://deeprockgalactic.wiki.gg/wiki/Salt_Pits)). Spelers kijken zelden naar boven en zien ze te laat.

**Waarschuwingstijd.** Waarnemen, beslissen en drukken duurt bij een gemiddelde speler meer dan 0,3 s. Voor beginners, of als er veel op het scherm gebeurt, is tot 3 s nodig. Hoe dodelijker de aanval, hoe langer en opvallender de waarschuwing. Voor gevaar achter of boven je: geluid en trilling samen ([note.com](https://note.com/darkangels_417/n/nb520b22d60f7?hl=en)).

**Schok.** Eiserloh gebruikt "trauma" van 0 tot 1. De schok is trauma² of trauma³, gestuurd met Perlin-ruis, en het trauma ebt vanzelf weg ([GDC 2016](https://archive.org/details/GDC2016Eiserloh)). KidsCanCode gebruikt standaard een exponent van 2, een verval van 0,8/s en een rol van "spaarzaam" 0,1 rad ([recept](https://kidscancode.org/godot_recipes/3.x/2d/screen_shake/index.html)). `CameraFx` doet dit al: trauma², max 2,2°, verval 1,6/s.

**Afgeleid voor ons:**
- Omdat de zones altijd zichtbaar zijn, is de beving zelf een tweede waarschuwing, geen verrassing.
- Een zone moet je kunnen verlaten in de aankondigingstijd, ook met buit. Wandelen gaat 4,5 m/s; samen dragen gaat trager.

## 4. Magma dat leest in het donker

**Hoe artiesten het doen** ([80.lv](https://80.lv/articles/making-lava-for-games), [ShareTextures](https://www.sharetextures.com/blog/6-free-lava-magma-textures)): een donkere, afgekoelde korst met heldere scheuren (dat leest als lava op elke afstand), een kleurverloop volgens de temperatuur, trage stroming, een randlicht op de rots erlangs, en hittetrilling, die enkel werkt als er genoeg gloeiend oppervlak onder zit. Volgens Nature Manufacture hangt de kost voor 80% af van beeldeffecten en deeltjes, niet van de geometrie.

**Licht.** In Minecraft geeft lava het maximale licht (15) ([wiki](https://minecraft.wiki/w/Lava)). Lava is daar dus ook een lamp. In Godot verlicht emissie niets zonder GI ([rots-en-licht](rots-en-licht.md)). Er is dus een echte lamp nodig, of een nepgloed in de terreinshader.

**Godot.**
- Met `global uniform` deel je één waarde met alle shaders. Je zet die met `RenderingServer.global_shader_parameter_set`, en dat is goedkoop. De uniform moet wel in de projectinstellingen bestaan ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html)).
- `render_mode fog_disabled` zet de mist uit op een materiaal ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).
- Een schermtextuur (`hint_screen_texture`) wordt in 3D één keer per frame gekopieerd, na de ondoorzichtige pass ([docs](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)).
- Volumetrische mist (enkel in Forward+) heeft een beperkt bereik. Een `FogVolume` kan emissie hebben, en een lamp telt er minder zwaar door mee als je zijn `volumetric_fog_energy` op 0 zet ([docs](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)).
- Een spotschaduw is veel goedkoper dan een omnischaduw ([rots-en-licht](rots-en-licht.md)).

## 5. Wat magma doet met spelers, buit en de Mol

- **Spelers.** In Valheim doodt lava je in 1 à 2 s, ongeacht je weerstand ([wiki](https://valheim.fandom.com/wiki/Lava)), en de lava in PEAK is bijna even snel (§1). De hete rots in DRG doet 10 schade per 0,5–1 s: pijnlijk, maar niet meteen dood. In de Roblox-game sterf je langzaam. **[afgeleid]** In co-op werkt een neergaan met een reddingskans het best, en dat systeem hebben we al: een neergegane robot wordt draagbaar (GDD §6).
- **Buit.** In Minecraft is alles wat in lava valt meteen weg, behalve netherite ([wiki](https://minecraft.wiki/w/Lava)). In Terraria verbrandt enkel gewone (witte) buit en overleven zeldzamere spullen ([wiki](https://terraria.wiki.gg/wiki/Lava)). Het GDD kiest: losse buit is weg. Een vuurvast zeldzaam stuk kan later een leuke uitzondering zijn.
- **Voertuig.** Er is geen goed voorbeeld. Het GDD heeft al een "hitteschild" als upgrade.

## 6. Multiplayer: één klok bij de host

- Klokken gelijkzetten doe je met tijdstempels en een geschatte offset (Zachary Booth Simpson, [timesync](http://www.mine-control.com/zack/timesync/timesync.html)).
- Godot heeft daar geen node voor. Er ligt een voorstel ([#6104](https://github.com/godotengine/godot-proposals/issues/6104)).
- `player.gd` en `mol.gd` schatten de offset al (`_clock_offset = minf(...)`). Die kun je hergebruiken.
- Les uit de drop: stuur **toestand**, geen eenmalig bericht, anders mist wie later binnenkomt de klok ([drop-en-ophalen](drop-en-ophalen.md) §4).

## Aanbeveling voor Diepgang

Alle cijfers hieronder zijn **eigen voorstellen** om mee te beginnen. Ze horen in `game/data/tuning/magma.cfg` en `unrest.cfg`.

### A. De magmacurve

De klok loopt op `t_eff = t_dienst + voorsprong`. Elke beving telt `quake_advance_s = 40` bij de voorsprong.

| t_eff | Snelheid |
|---|---|
| 0–2:00 | 0: "de planeet slaapt", enkel gloed onderaan |
| 2:00–5:00 | loopt op van 0 naar 0,22 m/s |
| 5:00–21:00 | loopt lineair op van 0,22 naar 0,38 m/s |
| daarna | 0,38 m/s |

Het magma start op **−310 m**, 10 m onder de kern. Een beving van 40 s is vroeg in de dienst een sprong van ±9 m, laat ±14 m. De sprong is een golf over **10 s**, geen knip.

De tabel geeft de echte dienstklok. Een gewone ploeg heeft 5 bevingen, om de ±3 min vanaf 3:30. Een luide ploeg heeft 8 bevingen, om de ±2 min vanaf 3:00.

| Magma op | Wat is weg | Zonder bevingen | Gewone ploeg (5) | Luide ploeg (8) |
|---|---|---|---|---|
| −290 m | onderkant kern | 5:00 | 4:20 | 4:20 |
| −240 m | kern | 8:30 | 7:10 | 7:00 |
| −180 m | kristal | 12:10 | 10:10 | 9:30 |
| −120 m | basalt | 15:25 | 12:45 | 12:05 |
| −60 m | zandsteen; **de grijper komt vanzelf** | 18:20 | 15:00 | 14:20 |
| 0 m | **uitbarsting** | 21:05 | 17:45 | 16:00 |

- Met de T1-boorkop (tot −120 m) komt het magma pas in de laatste ±5 min echt dichtbij. Met betere boorkoppen ben je dieper en dus langer in gevaar. Zo groeit de moeilijkheid vanzelf mee.
- Bij −60 m komt de grijper automatisch: 90 s aanvliegen, 20 s aftellen (drop-en-ophalen A). Dat is de noodophaling van Helldivers 2.
- Bij 0 m is alles wat nog op de planeet is weg. Er is geen tweede klok.
- **De Mol gaat sneller omhoog dan het magma.** Hij rijdt 6 m/s onder 22°, dus ±2,25 m/s verticaal, tegenover hooguit 0,38 m/s voor het magma. De terugrit van −250 m duurt ±2 min. Gevaar is er dus vooral voor wie te voet ver van de Mol is, of als de Mol diep geparkeerd staat.
- **Solo** krijgt vanzelf minder bevingen (±3, dus ±19 min). Een aparte solofactor pas toevoegen als tests dat vragen.

### B. Onrust

Eén **trap = 100** onrust. Bij 100 komt een beving, daarna begint de volgende trap bij 0.

| Bron | Onrust | Opmerking |
|---|---|---|
| Handboor (draait) | 0,3/s | de hitte van de boor beperkt dat volgehouden tot ±0,2/s |
| Houweel, gewone slag | 0 | met de hand is stil: een duidelijke regel |
| Houweel, afketsen op te harde rots | 0,3 per keer | |
| Mol rijden | 0,25/s bij volle snelheid | evenredig met de snelheid |
| Mol boren | 0,6/s | de luidste bron |
| PING | 5 per ping | 20 pings = 1 beving. `sonar_ping_noise` gaat van 1,0 naar 5 |
| Springlading (later) | 30 | plus een lokale rotsval binnen 15 m |
| Stemmen, stappen, botsende buit | 0 | |

- **Voorschok bij 80.**
- **Verval:** 0,1/s, maar enkel na 15 s zonder lawaai, en nooit onder het begin van de trap.
- **Minstens 90 s tussen twee bevingen.** De onrust telt intussen door, maar de beving wacht.
- **Verwachting.** Een gewone ploeg van 4 komt op ±490 onrust, dus 4 à 5 bevingen. Solo komt op ±320, dus 3.
  - De afdaling van de Mol (±220 s boren) plus een paar pings brengen de eerste beving rond 3,5 min.
  - Dat is net bij aankomst, veilig in de Mol. Een gratis uitleg van wat een beving is.

### C. Verloop van een beving

| Moment | Wat er gebeurt |
|---|---|
| ≥ 80% onrust | Om de 8–15 s een kleine schok (trauma 0,3). Stof sijpelt in de zones in de buurt, de naald van de seismograaf trekt. [plaatshouder: diep gerommel] |
| 100%, T−4 s | Trauma loopt op van 0,2 naar 0,45. Stofstralen uit de actieve zones. HUD: "BEVING". [plaatshouder: zin van de Opzichter] |
| T0–T6 s | Hoofdschok, trauma 0,7. Wandelen ×0,85 (gok). Rotsen vallen verspreid tussen T0 en T5, elk na 1,2 s stofstraal. |
| T0–T10 s | Golf van het magma: 40 s van de curve. |
| T6–T16 s | Het stof blijft hangen en het trauma ebt weg. De volgende trap start. |

### D. Zones en rotsen

- **Zone:** een straal van 4 m (8 m breed) aan het plafond van een grot of tunnel, in alle lagen behalve klei, het meest in zandsteen. Wandelend ben je er in ±1 s uit, dragend ruim binnen de 4 s. (De stalactiet in DRG: straal 1,5 m.)
- **Markering, altijd zichtbaar in het licht van de helmlamp:** scheuren, hangende stenen, een fijne stofsliert, en oud waarschuwingslint of een bord van DIG (rommel van vorige bezoekers). De scanner T2 toont de zones.
- **Per beving:** enkel zones binnen 40 m van een speler of de Mol, hooguit 6. Per zone 3–6 rotsen van Ø 0,4–1,2 m. Hooguit 30 rotsen tegelijk, na 40 s vervagen ze.
- **Schade:** kleine rots 15% en 0,3 s wankelen; grote rots 40% en 1,2 s omver; buit krijgt de botsschade die al bestaat. De Mol en wie erin zit: niets, het rammelt alleen.

### E. Schermschok

De bestaande `CameraFx` blijft (trauma², max 2,2°). Gebruik voor bevingen een **ondergrens**, `trauma = max(trauma, vloer)`, in plaats van steeds trauma toe te voegen. Zo vecht het verval er niet tegen.

| Moment | Trauma | Hoek |
|---|---|---|
| Voorschok | puls 0,3 | ≈ 0,2° |
| Aankondiging | 0,2 → 0,45 | tot ≈ 0,45° |
| Hoofdschok | 0,7 | ≈ 1,1° |
| Rots die inslaat | +0,35 binnen 3 m, tot 0 op 12 m | |
| In de Mol | × 0,6 | |

De schuifregelaar `interface/camera_shake` geldt voor alles.

### F. Magma raken

- **Hittezone, 0–3 m boven het magma:** 20% schade per seconde (na 5 s neer), met een rode rand en hittetrilling.
- **Contact:** de robot gaat neer en zinkt **1,5 s** lang. Een ploegmaat kan hem eruit trekken met het draagsysteem. Daarna is hij weg: een spookdrone, de vervanging wordt aangerekend, en wat hij droeg is weg. Grap: een duim omhoog tijdens het zinken.
- **Losse buit:** gloeit op en is na 1,5 s weg. Erts in de zak van een gezonken robot is ook weg.
- **De Mol:** ondergedompeld loopt de hitte op van 0 naar 100% in 25 s (met het hitteschild 50 s). Alarm in de cabine als het magma op 40, 20 en 10 m onder de Mol staat. Bij 100% is de Mol weg, met de lading. Dat is het ergste wat kan gebeuren, en het kan enkel als niemand rijdt.

### G. Aflezen

- **Mol:** een rood merkteken op de dieptemeter, "MAGMA HIER ≈ m:ss" (uit de curve, zonder toekomstige bevingen), "TERUGRIT ≈ m:ss", de seismograaf, en een rode band op de sonar als het magma binnen bereik is.
- **HUD:** de afstand tot het magma onder je, zichtbaar onder 60 m, met een andere kleur onder 30 en onder 15 m. De onrustbalk met bronnen (boren, Mol, ping, explosie).
- **Wereld:** gloed van onderen, opgewarmde rots, hittetrilling, gensters.
- **Stem:** de Opzichter meldt elke laag die het magma inneemt ("de kern is weg") en de grijper. [plaatshouder]

### H. Beelden in Godot

1. **Eén vlak:** een ondoorzichtige `PlaneMesh` van 260 × 260 m (de randen verdwijnen in de buitenmuur) die `magma_y` volgt. De shader: twee lagen ruis in wereldruimte, een korst (albedo ±0,04) en scheuren (emissie 2–4, boven de HDR-drempel, van oranje naar geel), stroming 0,03 m/s, een puls van 6–10 s. Eén draw call; het terrein verbergt het meeste.
2. **Global uniform `magma_height`** in `terrain.gdshader` en `crust.gdshader`. Rots tot 12 m boven het magma warmt op naar donkerrood, vooral vlakken die naar beneden kijken, met een heldere rand van 0–0,5 m vlak boven het magma. Zo gloeit de plek waar magma en rots elkaar raken, zonder transparantie of dieptetextuur.
3. **Eén `OmniLight3D` zonder schaduw**, enkel voor de eigen speler, op `(cam.x, magma_y + 1,5, cam.z)`. Bereik 40 m, energie van 0 op 45 m afstand tot 4 op 5 m, met lerp. 5 stralen naar beneden temperen hem als er rots tussen zit; anders licht hij plafonds door de rots heen op.
4. **Gensters:** `GPUParticles3D` rond de camera, enkel onder 30 m, hooguit 150. **Hittetrilling** met `hint_screen_texture`, enkel onder 20 m, uit te zetten per grafische preset.
5. **Mist:** `fog_light_color` schuift naar donkeroranje als je dichterbij komt. Een `FogVolume` met emissie boven het magma enkel op de hoogste preset (Forward+).
6. Meten op een mid-range pc: cijfers van de 4090 bewijzen niets.

### I. Netwerk

- De host bezit `shift_start_ms` (de klok van de host), `magma_advance_s`, `unrest`, `stage` en `quake {index, start_ms}`. Hij stuurt ze betrouwbaar bij elke wijziging, en elke 2 s opnieuw voor wie later binnenkomt. De clients schatten de tijd van de host met de bestaande min-offset en rekenen `magma_y` elk frame zelf uit.
- **Onrust telt enkel bij de host**, op wat hij zelf ziet: de boorhappen via `TerrainAPI`, de Mol die hij simuleert, en de pings. De clients krijgen de waarde 4 keer per seconde voor de HUD.
- **Schade, neergaan en verlies beslist enkel de host**, met een marge van 0,3 m. De clients tonen enkel het beeld.
- **Rotsen:** de startpunten komen uit het zaad (planeet, nummer van de beving, zone). `TerrainAPI` zegt of het plafond er nog is, met hetzelfde antwoord op elke peer. De val is vast (recht naar beneden, vanaf de tijd van de host), en de host beoordeelt de treffers bij de inslag. Daarna is de fysica lokaal en enkel voor het beeld.
- **Tests:** `magma_test` (de curve, de voorsprong, de minimale tijd tussen bevingen, het verval), en een netscenario: de magmahoogte van de client wijkt minder dan 5 cm af van die van de host, en de beving start op dezelfde tick.

### J. Beheren, nooit uitzetten

- **Demper op de boor:** −30% lawaai.
- **Stille modus van de Mol:** −50% lawaai en +50% brandstof (zoals de Cyclops).
- **Seismograaf T2:** de voorschok al vanaf 65%, en een precieze balk.
- **Koelpatroon (verbruik):** het magma staat 30 s stil. Dome Keeper heeft iets gelijkaardigs: een middel dat de golf 0,2 cyclus uitstelt ([NamuWiki](https://en.namu.wiki/w/Dome%20Keeper)).
- **Hitteschild van de Mol:** 25 → 50 s.
- **Nooit** iets dat het magma of de onrust stopt. Automatisch herstel nam in Dome Keeper "veel spanning weg" ([Steam](https://steamcommunity.com/app/1637320/discussions/0/3367027665175061202/)).
- **Planeten:** Roestbol (de tutorial) curve ×0,8, de Vulkaanplaneet ×1,3. Een tempokeuze per opdracht met meer beloning, zoals in Rogue Core, kan later.

## Zekerheid

- **Vast** (uit wiki's en docs): de cijfers van DRG (bevingen, zwermen, stalactieten), de Kiln van PEAK, de 700 s en 22:12 van Lethal Company, de Eyeless Dog, de formules van Dome Keeper en RoR2, de bereiken van Barotrauma, de regels voor buit in Minecraft en Terraria, en de Godot-docs.
- **Minder zeker** (enkel uit een samenvatting van een zoekresultaat, de pagina zelf kon ik niet openen): de tempokeuze van Rogue Core, "1 à 2 s" in Valheim, en de klachten over weinig waarschuwing bij bevingen in DRG.
- **Niet gevonden:** voor Noita, Downwell en Super Meat Boy geen bruikbare klok of cijfers. Ze zijn weggelaten.
- **Eigen voorstellen:** alle cijfers in de Aanbeveling. De afdaling van de Mol (±220 s) en het lawaai van een gewone dienst zijn schattingen. Eerst testen met `magma_test` en een echte dienst.

## Bronnen

- DRG: [Magma Core](https://deeprockgalactic.wiki.gg/wiki/Magma_Core), [Swarm](https://deeprockgalactic.wiki.gg/wiki/Swarm), [Salt Pits](https://deeprockgalactic.wiki.gg/wiki/Salt_Pits), [Escort Duty](https://deeprockgalactic.fandom.com/wiki/Escort_Duty), [TV Tropes: ThatOneLevel](https://tvtropes.org/pmwiki/pmwiki.php/ThatOneLevel/DeepRockGalactic), [TV Tropes: AntiFrustrationFeatures](https://tvtropes.org/pmwiki/pmwiki.php/AntiFrustrationFeatures/DeepRockGalactic)
- Rogue Core: [Steam "remove timer"](https://steamcommunity.com/app/2605790/discussions/0/838376971028276655/), [GamesRadar](https://www.gamesradar.com/games/fps/deep-rock-galactic-roguelike-spin-off-launches-to-mostly-positive-steam-reviews-that-cant-decide-if-they-love-or-hate-its-timer-and-shared-progression-tool/), [dlcompare](https://www.dlcompare.com/gaming-news/deep-rock-galactic-rogue-core-responds-swiftly-to-community-feedback-77265), [ReaperWorm](https://deeprockgalactic.wiki.gg/wiki/Rogue_Core:ReaperWorm), [Update 1](https://roguecore.wikily.gg/patch-notes/1834602721184902)
- PEAK: [Fog](https://peak.wiki.gg/wiki/Fog)
- Lethal Company: [Time](https://lethal-company.fandom.com/wiki/Time), [HUD](https://lethal.miraheze.org/wiki/HUD), [Lethal Company](https://lethal.miraheze.org/wiki/Lethal_Company), [Eyeless Dog](https://lethal.miraheze.org/wiki/Eyeless_Dog)
- Dome Keeper: [Relic Hunt](https://domekeeper.wiki.gg/wiki/Relic_Hunt), [Game Developer](https://www.gamedeveloper.com/business/how-dome-keeper-focuses-on-systems-that-feed-into-one-another), [Josh Anthony](https://joshanthony.info/2023/05/24/design-dive-dome-keeper/), [NamuWiki](https://en.namu.wiki/w/Dome%20Keeper), [Steam](https://steamcommunity.com/app/1637320/discussions/0/3367027665175061202/)
- Overige games: [Spelunky HD](https://spelunky.fandom.com/wiki/Ghost_(HD)), [Spelunky 2](https://spelunky.fandom.com/wiki/Ghost_(2)), [RoR2](https://riskofrain2.wiki.gg/wiki/Difficulty), [Helldivers 2](https://helldivers.wiki.gg/wiki/Extraction), [Mario](https://www.mariowiki.com/Rising_Tides_of_Lava), [Celeste](https://celeste.ink/wiki/Core), [Roblox](https://roblox.fandom.com/wiki/Player:TheLegendOfPyro/The_Floor_Is_LAVA!), [Keep Digging](https://vaporlens.app/app/3585800/keep_digging), [Barotrauma](https://barotraumagame.com/wiki/Common_Misconceptions), [Subnautica](https://subnautica.fandom.com/wiki/Cyclops), [Alien: Isolation](https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation), [Hunt](https://www.pcgamer.com/lets-hear-it-for-hunt-showdowns-incredible-sound-design/), [Iron Lung](https://iron-lung.fandom.com/wiki/The_Monster_(Game)), [Valheim](https://valheim.fandom.com/wiki/Lava), [Minecraft](https://minecraft.wiki/w/Lava), [Terraria](https://terraria.wiki.gg/wiki/Lava)
- Design en techniek: [Eiserloh GDC 2016](https://archive.org/details/GDC2016Eiserloh), [KidsCanCode](https://kidscancode.org/godot_recipes/3.x/2d/screen_shake/index.html), [Telegraphing (note.com)](https://note.com/darkangels_417/n/nb520b22d60f7?hl=en), [80.lv](https://80.lv/articles/making-lava-for-games), [ShareTextures](https://www.sharetextures.com/blog/6-free-lava-magma-textures), [Simpson timesync](http://www.mine-control.com/zack/timesync/timesync.html), [Godot #6104](https://github.com/godotengine/godot-proposals/issues/6104)
- Godot-docs: [volumetrische mist](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html), [spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html), [global uniforms](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html), [schermtextuur](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)
