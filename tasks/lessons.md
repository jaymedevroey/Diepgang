# Lessen

Wat we onderweg leerden en wat het GDD bijstuurt. Nieuwste bovenaan.

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
