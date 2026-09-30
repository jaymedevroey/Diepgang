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
| Nettest (host + client, headless) | `py -3.11 tools/net_test.py` (of `--exe builds/windows/Diepgang.console.exe`) |
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
- [ ] **Stap 6:** een Windows-export (release) bouwen.
  Verificatie: Jayme start de .exe en kan graven.
  - 2026-10-01: build staat in `builds\windows\`, met gebakken shaders. `dig_test` slaagt 3× op de build (met Steam). **Wacht op Jayme.**
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
- [ ] **Stap 6: dragen.** Grijphandschoen: oppakken, dragen (volgt de hand kinematisch, lokaal voorspeld), loslaten/gooien (fysica neemt over). Host simuleert buit, clients interpoleren. Zware stukken met twee dragen.
  Verificatie: nettest: client draagt vondst, host ziet dezelfde positie; screenshot.
- [ ] **Stap 7: lift.** Platform in de centrale schacht, terminal per niveau om de lift te roepen, hendel om naar boven te gaan. Buit op het platform gaat mee.
  Verificatie: test: lift roepen, buit meenemen naar boven.
- [ ] **Stap 8: tuning-menu.** In het spel (F1) alle waarden uit `data/tuning/*.cfg` aanpassen en bewaren.
  Verificatie: waarde aanpassen werkt meteen en blijft na herstart.
- [ ] **Stap 9: playtestbuild.** Build + korte handleiding om met twee instanties (of twee pc's in het LAN) te testen.
  Verificatie: **Poort 1** met Jayme (en Ian/Anir): voelen graven en slepen goed?

## Jayme (parallel)

- [ ] Steamworks-account aanmaken ($100 app fee), W-8BEN en identiteitsgegevens.
- [ ] M0 stap 6: `builds\windows\Diepgang.exe` starten en graven (linkermuis). Laat weten hoe het voelt en welke fps het HUD toont.
