# Lessen

Wat we onderweg leerden en wat het GDD bijstuurt. Nieuwste bovenaan.

## 2026-10-01 — M0 stap 1

- **De agent draait op Jayme's pc zelf en ziet de echte renderer.** Godot opent Vulkan 1.4 Forward+ op de RTX 4090. Risico "de agent ziet de echte look niet" (GDD §12) is daarmee grotendeels weg: screenshots en Movie Maker-opnames in Forward+ kan de agent zelf maken.
  - **Maar:** een RTX 4090 zegt niets over performance op een mid-range pc. Performancecijfers van deze machine gelden als ondergrens, niet als bewijs. Test op mid-range blijft nodig (M5).
- **GodotSteam staat op Codeberg.** De GitHub-releases bevatten enkel modulebuilds (eigen editor + templates). De GDExtension-releases (`vX.Y-gde`) staan op codeberg.org/godotsteam/godotsteam.
- **godot_voxel heeft twee soorten 1.7-releases:** `v1.7` is een custom Godot-build met de module, `v1.7x` is de GDExtension (voor Godot 4.5+). Wij gebruiken `v1.7x`, zodat de officiële Godot-editor en exporttemplates blijven werken.
- De `python` in PATH wijst naar een hermes-venv. Voor projectscripts `py -3.11` gebruiken, of een eigen venv in `tools/.venv`.
- Godot-editor staat in `%LOCALAPPDATA%\Programs\Godot\4.7.2\`. Aanroepen via `tools\godot.cmd`.
