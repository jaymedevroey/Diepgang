# Lessen

Wat we onderweg leerden en wat het GDD bijstuurt. Nieuwste bovenaan.

## 2026-10-01 — Houweel (graafgevoel)

- **Playtest-les: "technisch klaar" is niet "af" voor Jayme.** Een zwart scherm met een bolletje oogt als niks, ook al werkt alles. Bij elke build die Jayme test: vooraf zeggen wat hij wel en niet mag verwachten, en zelf eerst screenshots bekijken.
- Screenshots van het spel neem ik zelf: `-- --autodig --pitch=-30 --shot=naam --frames=47,600`. Zo zie ik elke visuele wijziging voor Jayme ze ziet.
- Een schilfer met eigen kwast (copy → max → paste van het SDF-kanaal) werkt en blijft commutatief. `is_solid()` rondt af naar de dichtstbijzijnde voxel (0,5 m): voor ondiepe bewerkingen testen met een straal, niet met één punt.
- Helmlamp exact op het oog = geen zichtbare schaduw in putjes. Hoger en opzij zetten (zoals op een helm) maakt reliëf leesbaar.
- Gereedschap in beeld: `use_z_clip_scale` + `use_fov_override` (Godot 4.5+) tegen door muren steken, plus een eigen vullicht op renderlaag 2, anders is het zwart buiten de lampkegel.
- Stof als egale radiale schijf leest als een lichtflits. Ruistextuur + lage alpha werkt beter.

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
