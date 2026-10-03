# Taken

Afvinkbare taken per mijlpaal. Bron: [docs/GDD.md](../docs/GDD.md) §10 en §13.

## Hoe testen

| Wat | Commando (vanuit de repo) |
|---|---|
| Spelen in de editor-build | `tools\godot.cmd --path game` |
| Graaftest (headless) | `tools\godot.cmd --headless --path game -- --scenario=dig_test --no-steam` |
| Stresstest (venster, 60 s) | `tools\godot.cmd --path game -- --scenario=stress --duration=60 --no-steam` |
| Rendertest | `tools\godot.cmd --path game -- --scenario=render --no-steam` (+ `--rendering-method gl_compatibility` vóór `--`) |
| Windows-build | `tools\export_windows.cmd` → `builds\windows\Diepgang.exe` |
| Build online zetten (andere toestellen) | build in `builds\Diepgang-windows.zip` (enkel exe, pck, dll's, LEESMIJ), dan `gh release create vX.Y.Z builds/Diepgang-windows.zip --prerelease` op [jaymedevroey/Diepgang](https://github.com/jaymedevroey/Diepgang) (privé) |
| Nettest (host + client, headless) | `py -3.11 tools/net_test.py` (of `--exe builds/windows/Diepgang.console.exe`) |
| Vondsten, dragen, de Mol, sonar, schip en drop, tuning, menu's (headless) | `tools\godot.cmd --headless --path game -- --scenario=find_test --no-steam` (ook `carry_test`, `mol_test`, `sonar_test`, `mol_edge_test`, `stream_test`, `ore_test`, `ship_test`, `tuning_test`, `ui_test`) |
| Schip, hemel en ontwerpen (screenshots) | `--scenario=ship_preview` · `--scenario=sky_preview --sky=a\|b\|c` · `--scenario=concept_preview --model=res://assets/models/ekster_exterior.glb --close` |
| Buitenkant van De Ekster bouwen | `"C:\Program Files\Blender Foundation\Blender 5.2lender.exe" -b --factory-startup --python tools/blender/ekster_exterior.py`, daarna `--import` |
| Rots per laag (voor/na) | `--scenario=terrain_preview --shot=naam` (tunnel en bekapte wand per laag, met GPU-tijd; `--only=klei,kristal`) |
| HUD en menu (screenshots) | `--scenario=hud_preview` (korst, vondst, dragen, ver, piloot, vertrek, resultaat, pauze) · `--scenario=ui_preview` · `-- --menu-shot --menu-settings --menu-join` |
| Screenshots | `-- --autodig --pitch=-30 --shot=naam --frames=60,300` · `--scenario=robot_preview` · `find_preview` · `carry_preview` · `mol_preview` (`--only=buiten,zij,rups,achter,binnen,cabine,afdalen`, of `--only=sonar`) · `--menu-shot` |
| Model van de Mol bouwen | `"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -b --factory-startup --python tools/blender/mol.py -- game/assets/models/mol.glb`, daarna `tools\godot.cmd --headless --path game --import` |
| Twee instanties met de hand | `tools\godot.cmd --path game -- --host` en `tools\godot.cmd --path game -- --join=127.0.0.1` |

Logs, CSV's en screenshots komen in `logs/` (editor) of `builds\windows\logs\` (build).

## M0 Opzet (half oktober 2026)

- [x] **Stap 1:** repo en Godot 4.7.2-project aanmaken, Jolt aanzetten.
  Verificatie: het project opent zonder fouten.
  - 2026-10-01: Godot 4.7.2 + exporttemplates geïnstalleerd (SHA512 gecontroleerd). Headless import en run zonder fouten; windowed run toont `Forward+` op de RTX 4090, physics = `Jolt Physics`.
- [x] **Stap 2:** godot_voxel 1.7 GDExtension toevoegen, een `VoxelTerrain` van 128×320×128 met gelaagde generator, en `do_sphere` bij klikken.
  Verificatie: graven werkt, en de laadtijd en het geheugen zijn gemeten.
  - 2026-10-01: godot_voxel `v1.7x`. `PitGenerator` (oppervlak, liftschacht, 10 grotten, buitenmuur) + lagen-shader. Graven met de linkermuis. `dig_test` slaagt (11 controles).
  - Gemeten (editor, RTX 4090): volledige put geladen en gemesht in **1,8–2,2 s**. Statisch geheugen **93 MB** headless, **119 MB** met venster; videogeheugen **89 MB**. In de release-build 0,3 s laadtijd (headless).
- [x] **Stap 3:** GodotSteam 4.20.x GDExtension toevoegen naast godot_voxel.
  Verificatie: beide laden samen zonder conflict, en de Steam-init lukt met test-appid 480.
  - 2026-10-01: GodotSteam **4.22.1** gekozen (nieuwer dan GDD, zie lessons.md). `steamInitEx(480)` → status 0, ingelogd als Jayme. `dig_test` slaagt met beide extensies geladen, ook in de release-build. `SteamMultiplayerPeer` is ingebouwd.
- [x] **Stap 4:** een `TerrainAPI`-laag rond het graven.
  Verificatie: graven gaat enkel via die laag.
  - 2026-10-01: [terrain_api.gd](../game/src/terrain/terrain_api.gd). Graafwachtrij per physics-tick, snelheidslimiet per speler (8/s, burst 3), op-logboek, buit wakker maken. `dig_test` controleert automatisch dat geen script buiten `src/terrain/` de voxel-extensie aanroept.
- [x] **Stap 5:** een stresstest met 4 gesimuleerde gravers plus 30 fysica-objecten.
  Verificatie: frametijd en collision-pieken zijn gelogd.
  - 2026-10-01, release-build, 1600×900, vsync uit, RTX 4090: 60 s, 32 graafacties/s. Frametijd gem. **0,63 ms**, p99 **1,44 ms**, max **8,7 ms**, 0 frames boven 16,7 ms. Frames met graafactie gem. 1,20 ms (max 2,5) tegenover 0,63 ms zonder. Ops worden gebundeld (±4 per tick). **Geldt niet voor mid-range**, zie lessons.md.
- [x] **Stap 6:** een Windows-export (release) bouwen.
  Verificatie: Jayme start de .exe en kan graven.
  - 2026-10-01: build staat in `builds\windows\`, met gebakken shaders. `dig_test` slaagt 3× op de build (met Steam). Jayme speelt de builds sindsdien.
- [x] **Stap 7:** de renderertest, Forward+ tegenover Compatibility.
  Verificatie: besluit genoteerd welke effecten verifieerbaar zijn.
  - 2026-10-01: besluit in lessons.md. Forward+ blijft de doelrenderer; de agent ziet hem zelf.

## Graafgevoel (voor M1, na playtest M0)

Aanleiding: "het is gewoon klikken en er gaat een bolletje weg". Onderzoek: [docs/research/graven.md](../docs/research/graven.md).

- [x] **Houweel** — 2026-10-01
  - Zichtbaar houweel met zwaai (aanzet → slag → hit-stop → terugveren), ±0,55 s. Vasthouden = doorhakken, klik tijdens terugveren wordt onthouden.
  - Terrein breekt af op het inslagmoment als een platte, ruwe schilfer (`TerrainAPI.request_chip`, max-semantiek, ruis in wereldruimte). Test: vloer zakt 0,45 m per slag.
  - Graaft enkel klei (GDD §4). Op zandsteen en dieper ketst het af: vonken, metalen klink, rood vizier + hint.
  - Juice: camera-kick en schok, stofwolk, gruis, 3–5 echte steentjes (lokaal), geluid per slag (klei, klink, woesj, kruimels; `tools/audio/synth_dig.py`).
  - Rotsshader met reliëf-normalen op 2 schalen en donkere holtes. Kost ±0,25 ms op de RTX 4090.
  - Waarden in `data/tuning/pickaxe.cfg` en `camera.cfg`.
- [x] **Jayme test het houweel** — 2026-10-01: "al iets beter, niet perfect". Door naar M1.
  - Bekend probleem, bewust gelaten: soms blijven dunne zwevende stukjes terrein over (vooral aan het oppervlak). Later: `separate_floating_chunks` of een minimale dikte.

## M1 Graafspeelgoed (begin november 2026)

Doel (GDD §10): first-person robot, graven, korsten uitbikken, dragen, lift. **Al met netwerk** tussen twee lokale instanties. Tuning-menu. **Poort 1: voelen graven en slepen goed?**

Netwerkmodel (GDD §9): host-autoritatief voor terrein en buit; elke speler bepaalt zijn eigen beweging. Solo = host zonder gasten, zelfde codepad.

- [x] **Stap 1: netwerkbasis.** `NetSession` (ENet lokaal, later Steam), host/join via argumenten, spelers spawnen met eigen kleur, beweging gesynchroniseerd met interpolatie. Wereld-init (seed + op-logboek) voor wie binnenkomt.
  Verificatie: twee instanties op één pc zien elkaar bewegen; geautomatiseerde nettest slaagt.
  - 2026-10-01: `Net`-autoload (solo/host/join), `Game` (wereld-init, spawns, kleuren, klaar-melding), `Player` (lokaal of geïnterpoleerd, 20 Hz, 100 ms buffer). `py -3.11 tools/net_test.py` slaagt: positie van de client bij de host klopt tot op 0,00 m.
- [x] **Stap 2: terrein-sync.** Graafacties via de host (validatie: snelheid, afstand, gereedschap/laag), lokale voorspelling voor je eigen slagen, broadcast naar de rest.
  Verificatie: nettest vergelijkt een checksum van het terrein op host en client na dezelfde reeks slagen.
  - 2026-10-01: `TerrainSync`. Nettest: 4 slagen van de host voor de join (via logboek), 3 tijdens het laden van de client (gebufferd), 6 van de client (voorspeld + gevalideerd). MD5 van het volledige SDF-kanaal is identiek op host en client, 0 geweigerde ops.
- [x] **Stap 3: de robot.** Procedureel robotlijf (rond lijf, schermgezicht, antenne die meeveert) voor andere spelers; eigen handen/gereedschap in first-person.
  Verificatie: screenshot van de andere speler.
  - 2026-10-01: model uit `tools/blender/robot.py` (Blender 5.2 headless → `assets/models/robot.glb`). `RobotRig`: lopen, hoofd volgt kijkhoek, verende antenne, squash & stretch, zwaai met houweel. Schermgezicht-shader met pixelogen (knipperen, knijpen bij een slag, "blij" klaar voor later). Zwaai gaat als actie over het netwerk. Screenshots: `logs/robots_2.png` (4 kleuren) en `logs/coop_2.png` (andere speler via het netwerk). Preview: `--scenario=robot_preview`.
- [x] **Stap 4: boor T1.** Continu, kegelvormig, aanloop, trager lopen, hittemeter, gruisstraal, motorgeluid onder belasting; graaft zandsteen. Gesynchroniseerd als "streep" per netwerktick.
  Verificatie: dig_test + nettest met boor; screenshot.
  - 2026-10-01: `Drill`: aanloop 0,22 s, dunne happen (bol r 0,8 m, 0,15 m voorbij het raakpunt langs de kijkrichting) 8×/s = 1,2 m/s, slipt met vonken en gekrijs op graniet. Hitte (oververhit na 5,5 s, 4 s stil), 50% trager lopen, gruisstraal + stof, trillende camera. Naadloze motor-/gegrom-/gekrijsloops (`tools/audio/synth_drill.py`, loop-vlag via `set_loops.py`). Wisselen met 1/2/wieltje; anderen zien je boor en horen hem (luid, tot 45 m).
  - Keuze: happen gaan als losse bol-ops (8/s) i.p.v. een "streep"; volstaat qua bandbreedte en blijft max-semantiek.
  - Client en host doen dezelfde gereedschapscontrole (`TerrainSync.tool_allows`), anders kan een voorspelde op later geweigerd worden en lopen de werelden uiteen. Nettest: 4 boorhappen + houweel-in-zandsteen lokaal geweigerd, checksum gelijk.
- [x] **Stap 5: vondsten met korst.** Een eerste vondstfamilie (fossielstukken) in het terrein, elk in een korst. Houweel bikt de korst weg zonder schade; boor is sneller maar verlaagt de waarde. Vrij = fysica-object.
  Verificatie: test: korst weg → vondst los, waarde klopt per gereedschap.
  - 2026-10-01: `FossilModel` (dijbeen, wervel, rib, schedel, klauw; procedureel), `Crust` (bleke gespikkelde schil, barsten groeien met de schade, oplichten bij een raak), `FindItem`, `FindField` (36 vondsten uit de seed, 5 ondiep rond de spawn, min. 2 m uit elkaar). Houweel: 4 slagen, 100% gaaf. Boor: 8 happen in 0,8 s, ±67% gaaf. Vrij: korst springt, "ding", vondst licht op, host graaft ruimte en simuleert; clients interpoleren (20 Hz). Late joiners krijgen de toestand mee.
  - Tests: `--scenario=find_test` (15 controles) en de nettest (vondst vrij bij client en host, zelfde plek, checksum gelijk). Screenshots: `logs/find_2.png` (korst met barsten), `logs/find_3.png` (vrijkomen).
  - Gevonden en opgelost: vondsten konden overlappen (korsten 0,58 m uit elkaar).
- [x] **Stap 6: dragen.** Grijphandschoen: oppakken, dragen (volgt de hand kinematisch, lokaal voorspeld), loslaten/gooien (fysica neemt over). Host simuleert buit, clients interpoleren. Zware stukken met twee dragen.
  Verificatie: nettest: client draagt vondst, host ziet dezelfde positie; screenshot.
  - 2026-10-01: `Carry` (E oppakken/neerzetten, linkermuis gooien). Host beslist wie draagt (max. 2), de drager ziet de vondst meteen in zijn hand; loslaten = laatste positie + snelheid naar de host. Gewicht vertraagt (1 − massa / (30 × dragers), min. 0,4). Harde klap kost gaafheid. Handen vol = gereedschap weg; anderen zien je robot met de armen vooruit.
  - Vangnet: een losse vondst die in de rots belandt of onder de put valt, gaat terug naar zijn laatste veilige plek (de nettest vond dit).
  - Tests: `--scenario=carry_test` (10 controles), nettest (client draagt, positie gelijk bij host). Screenshot `logs/carry.png`.
  - Onstabiele test gevonden en opgelost: host valideert treffers in echte tijd, gereedschap telt in speltijd; die kunnen 20% verschillen. Grenzen nu ruim onder het echte tempo.
- [x] **Stap 7: lift.** Platform in de centrale schacht, terminal per niveau om de lift te roepen, hendel om naar boven te gaan. Buit op het platform gaat mee.
  Verificatie: test: lift roepen, buit meenemen naar boven.
  - 2026-10-01: `Lift` (platform als AnimatableBody3D, reling met 4 openingen, bedieningspaal met ▲/▼ en dieptedisplay, hangende lamp, kabels, portaal met motor). Vier roeprails langs de schachtwand: E = lift naar jouw diepte (de "terminal per niveau" werkt zo op elke diepte). Werklampjes + dieptecijfers om de 12 m. 4 m/s met zacht optrekken/afremmen (3 m/s²): een bruuske stop lanceerde vondsten van het platform (lift_test vond het). `Interactable` voor knoppen en rails; E bedient eerst een knop, anders oppakken.
  - Tests: `--scenario=lift_test` (10 controles: roepen, snelheid, speler en vondst rijden mee, ▼, te ver = geweigerd), nettest (lift op dezelfde hoogte bij host en client). Screenshot `logs/lift.png`.
- [x] **Stap 8: tuning-menu.** In het spel (F1) alle waarden uit `data/tuning/*.cfg` aanpassen en bewaren.
  Verificatie: waarde aanpassen werkt meteen en blijft na herstart.
  - 2026-10-01: `TuningMenu` (F1): tab per bestand, veld per waarde, uitleg uit het bestand als tooltip. Wijzigingen werken meteen. Bewaren: in de editor naar `data/tuning/` (commentaar blijft staan), in een build naar `user://tuning/`. De host stuurt zijn waarden naar alle clients (bij binnenkomen en bij elke wijziging), anders lopen de werelden uiteen.
  - Tests: `--scenario=tuning_test` (9 controles), nettest (waarde van de host komt aan bij de client). Screenshot `logs/tuning.png`.
- [x] **Stap 9: playtestbuild.** Build + korte handleiding om met twee instanties (of twee pc's in het LAN) te testen.
  - 2026-10-01: startmenu (solo, hosten met IP in beeld, meedoen via IP), handleiding `docs/playtest-m1.md` (ook als `LEESMIJ.txt` in de build). Build getest: dig/find/carry/lift-test en de nettest met twee exe's slagen; stresstest gem. 0,95 ms, max. 9,5 ms.
- [ ] **Poort 1** met Jayme (en Ian/Anir): voelen graven en slepen goed? Vragenlijst in `docs/playtest-m1.md`.

## Planning (herzien 2026-10-02, GDD v3 §10)

Volgorde op vraag van Jayme: eerst mooi, dan inhoud, dan Steam/voice, dan de kernlus.

Stijl: Deep Rock Galactic + PEAK + Astroneer. Alle modellen in Blender (geen AI-modellen).

- [ ] **M2 Uiterlijk** (half oktober): stijlgids, rotstexturen, Blender-modellen (de Mol, gereedschap, fossielen, puin), sfeer en licht, ambient geluid en muziek, menu- en HUD-stijl, instellingen.
  - [x] **De Mol** (model + volledige werking, vooruitgenomen uit M3), 2026-10-01. Ontwerp: [docs/de-mol.md](../docs/de-mol.md).
    - Model in Blender ([mol.py](../tools/blender/mol.py), 94k driehoeken): boorkop met spiraalarmen, schild, romp, rupsen, motor, interieur (cabine met schuine console, woonruimte, laadruim), slijtage in vertexkleuren.
    - Werking: rijden en boren, steun op het terrein, autopiloot (spiraal), laadruim, extractie met samenvatting, bijtanken, achterblijvers, buitenzicht (C), camerascherm, meters, knoppen vanuit de stoel.
    - Verificatie: `mol_test` 34 controles (o.a. van de spawn de klep op lopen, afdalen tot −20, vondst rijdt mee, extractie, graniet blokkeert); nettest met een client als piloot (19 controles).
    - 2026-10-01, ronde 2 na feedback van Jayme: staand meerijden (gleed weg, blik draaide), draaien in de rots (romp in de stenen), flikkeren (coplanaire vloer, geen AA, model-trillen), stoel niet te vinden (stuurhendels + E in de cabine), zwart camerascherm, gereedschap door de wand. `mol_test` 42 controles; de nieuwe controles falen zonder de fixes. Zelf gespeeld in de build met toetsenbord en muis: instappen, rijden, in de rots draaien, staand afdalen tot −61 m, uitstappen.
    - 2026-10-01, ronde 3: uitstappen na een rit (vooral in buitenzicht) zette je ver weg en je viel door de map. Opgelost en door Jayme getest ("het werkt"). Vangnet bij vallen onder de wereld. `mol_test` 47 controles.
    - Open: Jayme speelt het en zegt wat beter moet.
  - [x] **HUD en menu's**, 2026-10-01. Research: [docs/research/hud-menu.md](../docs/research/hud-menu.md) (DRG, PEAK, Lethal Company, R.E.P.O. e.a.).
    - Huisstijl in code (`UiTheme`): Bungee, Nunito, VT323; geel/antraciet; knoppen met een "lip", schakelaars, schuifregelaars.
    - Hoofdmenu met 3D-decor (de Mol aan de rand van de put, nachtlucht, werflamp; `tools/blender/menu_set.py`), laadscherm met tips, pauzemenu (co-op loopt door), instellingen (beeld, geluid, besturing, toetsen omzetten, interface, HUD per onderdeel uit/dynamisch/altijd), knopgeluiden.
    - HUD: vizier met ring per toestand en hitteboog, kompas met diepte/laag en richting naar de Mol, gereedschap, draagkaartje, meldingen, vertrekbanner, eindoverzicht, ploeg, besturing van de Mol; toetsblokjes volgen de eigen toetsen. UI schaalt mee met de resolutie (basis 1080p).
    - Verificatie: `ui_test` 14 controles (Esc sluit menu's, toets omzetten werkt in het spel, bewaren, pauze); `hud_preview`-screenshots bekeken; zelf gespeeld in de build (menu, instellingen, toets omzetten, laadscherm, spel).
    - Open: Jayme speelt het. Nog niet: Steam-uitnodigingen (M4), ondertitels en de stem van de firma (komt met geluid), ping (M3).
  - [x] **Rots en licht in de put**, 2026-10-01. Research: [docs/research/rots-en-licht.md](../docs/research/rots-en-licht.md).
    - Rots-shader: low-poly-facetten (gekwantiseerde normaal) met een tint per vlak, bolle randen licht en holtes donker, stof op vloeren, koele plafonds, een naad met lip op elke laaggrens. Per laag: klei met droge modderbarsten, zandsteen met banden, graniet met spikkels, kristal met spaarzame gloeiende aders.
    - Sfeer (`Atmosphere`): misttint en omgevingslicht per laag, nachtlucht met maan boven de put, kleurgrading, stofjes in het licht, nep-terugkaatsing van de helmlamp, helmlamp met brede gloed, helderheid uit de instellingen.
    - De Mol boort ruwe tunnels (happen uit wand en plafond, vloer glad).
    - Verificatie: voor/na-beelden per laag met dezelfde camera (`terrain_preview`, logs/rots_voor_na.png); GPU-tijd gelijk of lager dan de oude shader (1080p); alle tests en de nettest groen.
    - Open: Jayme speelt het. Later: echte kristallen en stalactieten als modellen (M3: Kristalgrotten), de oppervlakte rond de put.
  - [x] **Gereedschap, vondsten en puin in Blender**, 2026-10-01.
    - Gereedschap ([tools.py](../tools/blender/tools.py)): houweel (rubberen greep, tape, stalen kop), boor met accu, lampje en draaiende spiraal, robothandschoen in de spelerskleur. In first person met een eigen FOV en z-clip in de machine-shader (niet door de wand).
    - Vondsten ([finds.py](../tools/blender/finds.py), `FindKinds`): 12 soorten in families per laag. Klei: muntenbuidel, oude fles, tuinkabouter, oude tv. Zandsteen: dijbeen, wervel, rib, schedel, klauw, mijnwerkerslamp. Diep zandsteen (14 m boven het graniet): ook geode en goudklomp. Elke soort heeft een naam, waarde en gewicht; kostbare vondsten (≥ €200) gloeien goud bij het vrijkomen.
    - Puin: rotsbrokjes (3 vormen) in plaats van kubusjes, bij houweel, boor en de Mol.
    - Verificatie: `tool_preview` (studio + first person), `finds_gallery` (logs/vondsten.png, logs/puin.png), `find_preview` in de rots (korst → barst → vondst vrij met brokjes) bekeken. Alle tests en de nettest groen.
    - Open: Jayme speelt het. Bij afsluiten melden de tests nog "resources still in use": geluiden die nog spelen (crust_break, find_ding). Oplossen bij het geluid.
  - [x] **Sonar in de Mol** (vraag van Jayme), 2026-10-01. Ontwerp: [docs/de-mol.md](../docs/de-mol.md) (Sonar).
    - Sonarkast in Blender rechts naast het camerascherm (ronde beeldbuis met chromen ring, knoppen, echolampje). Beeld in een eigen shader: kop boven, draaiende veeg met naloop, vage blips (grootte = gewicht), ▲/▼ voor boven/onder, haakjes rond het doel, dieptestrook. Tekst: afstand, klok, hoogte, grootte, "! DICHTBIJ". Ruis bij rijden en boren. In buitenzicht rechtsonder in de HUD.
    - Nieuwe regel: de boorkop schept een vondst die hij raakt op in het laadruim, met hoogstens 30% gaafheid. Zonder die regel bleef de korst in de Mol zweven (de test zag de vondst op Mol-hoogte 0,0 m).
    - Verificatie: `sonar_test` 21 controles (klok/richting, echo's binnen bereik en enkel daar, vaag maar dichtbij, gedragen = weg, opscheppen: vrij, geen korst, in het laadruim, ≤ 30%, melding); de opschep-controles falen zonder de regel. Nettest: client ziet de opgeschepte vondst in het laadruim met dezelfde gaafheid (22 controles). Screenshots `logs/sonar_*.png` bekeken (stoel, dichtbij, diep, rijden met ruis en waarschuwing, buitenzicht). Alle tests groen.
    - Open: Jayme speelt het. Later: ping-geluid (met het geluid), T2 (soort en waarde), de handscanner te voet.
    - Zelf gespeeld in de build (toetsenbord en muis): aan het stuur, gedraaid tot het doel op 12 uur stond, erheen gereden (9 → 6 m, "! DICHTBIJ"). Daarbij een oude fout van de Mol gevonden: met de neus omlaag schuin de grond in tot tegen de **rand van de put** kwam er rots in de cabine (boorbollen werden aan de buitenmuur naar binnen geschoven) en zat hij vast. Opgelost: de buitenmuur blokkeert ("! RAND PUT"), draaien zwaait niet in de muur, rots-voeler zo breed als de romp met rupsen, kopruimte vrijmaken als de steun hem optilt, schaven langs de echte omtrek van de romp. `mol_edge_test` (10 controles) speelt de rit na; zonder de fix 7 fouten (8 rotspunten in de romp, vast tegen de muur), met de fix 3× op rij groen.
- [x] **Onderzoek plezier en design** (vraag van Jayme), 2026-10-01: [docs/research/plezier-en-design.md](../docs/research/plezier-en-design.md). Vier onderzoekssporen met bronnen (vergelijkbare games; vinden en museum; samenspel; spelgevoel, progressie en demo) plus een eigen audit en playtest. Twaalf hoofdpunten, ±60 aanbevelingen met kost, een voorstel per mijlpaal en zes open vragen voor Jayme.
  - Open: Jayme kiest (o.a. een stuk kernlus naar voren halen, de sonar als rol met PING, opgeschepte vondsten altijd "gebroken", tempo van de Mol).
- [ ] **M3 Kernlus** (oktober, GDD v3 §3–4): de planeet, De Ekster, drop en extractie, en een dienst met een doel. Alles co-op via het bestaande netwerk, elke stap met de nettest.
  - [x] **1. Grote planeet met streaming** (250 × 250 × 300 m), 2026-10-03.
    - TerrainAPI streamt (viewers per speler en op de Mol, VoxelStreamMemory, ops die wachten op hun blok, nakijken en herstellen van overschreven bewerkingen). PlanetGenerator: vlakte met kraters, rotsblokken en een vlakke landingsplek, 46 grotten (5 groot), 26 gangen, buitenmuur enkel onder het oppervlak. Lagen herschaald.
    - Verificatie: `stream_test` 16 controles (gat blijft na ontladen en herladen, op voor niet-geladen gebied wordt toegepast als je er komt, echte collision rond de Mol); nettest 22 controles groen (3× op rij); alle tests aangepast en groen. Laden tot speelbaar 3,5–4,2 s, ±130 MB (headless). `drive_perf` met venster op deze pc: 6–7 ms gemiddeld, p99 ≤ 13 ms, max 25 ms, geen frames boven 33 ms (RTX 4090: geen bewijs voor mid-range). Screenshots `logs/planeet_*.png` bekeken.
    - Open: het landschap voorbij de rand (stap 3), grotwanden van dichtbij beoordelen, meten op een mid-range pc.
  - [x] **2. Vondsten en erts in de grote wereld**, 2026-10-03.
    - Vondsten: 158 over de planeet (5 bij de landing, de eerste een bot; 8 fossielbedden; 45 achter grotwanden; 60 verspreid op elke diepte); soort per laag uitgebreid met graniet en kristal. Getekend tot 70 m. (Alle nodes blijven bestaan, bevroren in de rots: 158 is licht genoeg; "enkel nodes in de buurt" bleek niet nodig.)
    - Erts: 316 clusters (korte ader koper bij de landing, aders per laag, clusters uit grotwanden); koper, ijzer, zilver, lichtkristal. Houweel = 1 eenheid per slag, boor trager per tik. Ertszak (40) in de HUD, storten in de nieuwe trechter in het laadruim van de Mol, telt bij de extractie. De rotswand fonkelt in de kleur van erts dat vlak achter het oppervlak zit.
    - Verificatie: `ore_test` 13 controles (plaatsing, delven, zak vol, storten enkel bij de trechter, glinsteren), `find_test`, nettest 26 controles (client delft 2 erts en stort, host en client zelfde zak, laadruim en levens). Screenshots `logs/erts_*.png` bekeken (fonkels eerst veel te zwaar, bijgestuurd).
  - [x] **3. Oppervlak en hemel**, 2026-10-03.
    - Hemel (planet_sky.gdshader) per planeettype (PlanetType, nu Roestbol): stoffige horizon, donkere top, een kleine zon met gloed, een grote geringde planeet laag aan de hemel, nevel, weinig sterren. Zon met schaduw aan de oppervlakte (dooft uit onder de grond), helder omgevingslicht en verder zicht boven de grond.
    - Verre landschap (PlanetSurface): ring tot ±475 m met dezelfde hoogtefunctie, heuvels en mesa's naar de horizon; rok langs de rand. Concessiegrens: paaltjes met knipperlichtjes om de 16 m en onzichtbare muren (laag BOUNDS) voor spelers.
    - Verificatie: screenshots `logs/oppervlak.png`, `hemel_reus.png`, `hemel_zon.png` bekeken; `stream_test` 18 controles (muur aan de rand houdt je tegen, verre landschap bestaat).
    - Open: De Ekster in de lucht komt met stap 4/5 (het schip zelf).
  - [ ] **4. De Ekster:** moederschip in Blender (dropbaai met de Mol, terminal, taxatiepoort, museumzaal, werkbank). Je begint en eindigt hier.
    Verificatie: screenshots, zelf rondgelopen.
    - 2026-10-03, eerste poging (een doos, zonder onderzoek) afgekeurd door Jayme. Daarna onderzoek: [schip-ontwerp](../docs/research/schip-ontwerp.md), [schip-bouwen-in-blender](../docs/research/schip-bouwen-in-blender.md), [nostromo-stijl](../docs/research/nostromo-stijl.md). Ook vier vormrichtingen en drie Nostromo-ontwerpen werden afgekeurd ("blokken aan elkaar"). Jayme koos de **Helldivers-stijl**.
    - [x] **Buitenkant**, 2026-10-03: de vorm eerst in klei (verhoudingen afgemeten op de Super Destroyer: hamerkop met kaak, hoog middenstuk, lange rug, twee schuine motorarmen met open ruimte). Jayme keurde de vorm goed ("zo is goed"). Daarna details in lagen ([ekster_exterior.py](../tools/blender/ekster_exterior.py)): panelen in tinten, gele lijnen, zijluiken, de baai met grijper, rijen ramen en looplichten, navigatielichten, bloemmotoren, pantserplaten, containers met gestolen lading op de rug, een kraan, koelvinnen, de buik met lichtjes, DE EKSTER, DIG-0017 en een ekster als embleem. ±170 m lang.
      Verificatie: `concept_preview --model=res://assets/models/ekster_exterior.glb --close` in de game bekeken (boeg, flank, rug, motoren, buik, van onder, vanaf de planeet, drop). Overzicht: `logs/concepts/ekster_buitenkant.png`.
    - [ ] **Binnenkant** (een aparte ruimte waar je volledig in rondloopt): eerst met Jayme overleggen voor het begint (zijn vraag).
    - De oude doos-Ekster ([ekster.py](../tools/blender/ekster.py), klasse `Ekster`) werkt nog als speelbare hub tot de binnenkant er is.
  - [ ] **5. Drop:** de Mol valt met de ploeg erin op de planeet (gloed, stuwraketten, landing); het terrein laadt intussen.
    Verificatie: test: iedereen blijft in de Mol, landing op het oppervlak, terrein geladen bij de landing; nettest; screenshots.
    - 2026-10-03: werking klaar. Hendel in de Mol (aftellen), luiken open, vrije val tot 42 m/s, remmen met stuwraketten (vlammen, gloed) tot 3 m/s, stofwolk bij de landing. Wacht boven de grond als de collision er nog niet is. Wie in de Mol zit, zit vast op zijn plek (de botsvorm van de Mol loopt een tick achter). Uit het schip springen: je landt op de grond (val begrensd op 40 m/s). `ship_test` (21 controles) dekt drop, landing, springen en ophalen.
    - Onderzoek: [drop-en-ophalen](../docs/research/drop-en-ophalen.md). Jayme koos het **heldenshot**: één vaste buitencamera achter de Mol, het schip boven in beeld, en bij de landing een knip naar binnen. De huidige draaiende camera moet dus nog vervangen worden, net als de melding "Geland op" (wordt een stempel in de wereld).
  - [ ] **6. Extractie met de grijper:** de Mol rijdt naar boven, De Ekster pikt hem op, terug in de dropbaai; achterblijvers worden vervangen (kosten).
    Verificatie: test met speler binnen en buiten; nettest.
    - 2026-10-03: werking klaar (grijper zakt, klep dicht, optrekken tot in de baai, luiken dicht, achterblijvers naar het schip). Nog te doen volgens het onderzoek: aankomsttijd en baken, 20 s instappen, de ladder voor wie te laat is, vervangingsfactuur, rustfase in de baai.
  - [ ] **7. Opdracht, quota, teamkas, opslaan:** terminal met 2–3 planeten, kwartaal van 3 diensten, boete, kas, opslaan bij de host.
    Verificatie: test (doel gehaald / gemist / opslaan en laden).
  - [ ] **8. Taxatie en museum:** taxatiepoort met onthulling één voor één, verkopen of schenken, museum met skeletsets, gaten met hints, namen op de bordjes.
    Verificatie: test + screenshots.
  - [ ] **9. Magma en onrust:** magma stijgt (de enige klok), onrust door lawaai, bevingen, vallende rotsen in gemarkeerde zones.
    Verificatie: test + screenshots.
  - [ ] **Hemel opnieuw** (onderzoek [hemel](../docs/research/hemel.md)): nieuwe shader (kleuren van een kunstenaar met natuurkundige weging, hemellichamen achter de atmosfeer, geringde reus echt in 3D met schaduwen, virtuele grond onder de horizon), mist neemt de kleur van de hemel aan, minder gloed, AgX-contrast. Drie kleurrichtingen klaar (`--sky=a|b|c`, `sky_preview`, `logs/sky/hemel_richtingen.png`); **Jayme kiest nog**.
  - [ ] **10. Sonar met PING:** stil 12 m en vaag, PING tot 24 m maar luid.
    Verificatie: `sonar_test`.
  - [ ] **11. Incidentrapport** na elke dienst (prijzen, waarde, schade).
- [ ] **M4 Inhoud** (november): Graafworm, gas, alle ±8 items, 3 planeettypes, neergaan en redden, cosmetica, mutators, opdrachten met uitdaging, tutorial-opdracht.
- [ ] **M5 Samen** (Jayme beslist): Steam-lobby's en uitnodigingen, voice, test met 150 ms vertraging. Poort 2.
- [ ] **M6 Geluid** (Jayme beslist).
- [ ] **M7 Demo** (februari–maart 2027): demo, capsules, trailer, Steam-pagina.

## Jayme (parallel)

- [ ] Steamworks-account aanmaken ($100 app fee), W-8BEN en identiteitsgegevens.
- [x] M0 stap 6: `builds\windows\Diepgang.exe` starten en graven. 2026-10-01: Jayme speelt de builds (graven, de Mol).
