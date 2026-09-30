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
- [ ] **Jayme test het houweel** in `builds\windows\Diepgang.exe`.
- [ ] **Boor** (na akkoord op het houweel): continu, kegelvormig, aanloop, trager lopen, hittemeter, gruisstraal, motorgeluid onder belasting.

## Jayme (parallel)

- [ ] Steamworks-account aanmaken ($100 app fee), W-8BEN en identiteitsgegevens.
- [ ] M0 stap 6: `builds\windows\Diepgang.exe` starten en graven (linkermuis). Laat weten hoe het voelt en welke fps het HUD toont.
