# Taken

Afvinkbare taken per mijlpaal. Bron: [docs/GDD.md](../docs/GDD.md) §10 en §13.

## M0 Opzet (half oktober 2026)

- [x] **Stap 1:** repo en Godot 4.7.2-project aanmaken, Jolt aanzetten.
  Verificatie: het project opent zonder fouten.
  - 2026-10-01: Godot 4.7.2 + exporttemplates geïnstalleerd (SHA512 gecontroleerd). Headless import en run zonder fouten; windowed run toont `Forward+` op de RTX 4090, physics = `Jolt Physics`.
- [ ] **Stap 2:** godot_voxel 1.7 GDExtension toevoegen, een `VoxelTerrain` van 128×320×128 met gelaagde generator, en `do_sphere` bij klikken.
  Verificatie: graven werkt, en de laadtijd en het geheugen zijn gemeten.
  - Download: `GodotVoxelExtension.zip` (52 MB) van github.com/Zylann/godot_voxel, release `v1.7x` ("for Godot 4.5+").
- [ ] **Stap 3:** GodotSteam 4.20.x GDExtension toevoegen naast godot_voxel.
  Verificatie: beide laden samen zonder conflict, en de Steam-init lukt met test-appid 480.
  - Download: `godotsteam-4.20.1-gdextension-plugin-4.4.zip` (26 MB) van codeberg.org/godotsteam/godotsteam, release `v4.20.1-gde`. Nieuwere GDExtension-versies bestaan (4.21, 4.22, 4.22.1); keuze bij Jayme.
- [ ] **Stap 4:** een `TerrainAPI`-laag rond het graven.
  Verificatie: graven gaat enkel via die laag.
- [ ] **Stap 5:** een stresstest met 4 gesimuleerde gravers plus 30 fysica-objecten.
  Verificatie: frametijd en collision-pieken zijn gelogd.
- [ ] **Stap 6:** een Windows-export (release) bouwen.
  Verificatie: Jayme start de .exe en kan graven.
- [ ] **Stap 7:** de renderertest, Forward+ tegenover Compatibility.
  Verificatie: besluit genoteerd welke effecten verifieerbaar zijn.

## Jayme (parallel)

- [ ] Steamworks-account aanmaken ($100 app fee), W-8BEN en identiteitsgegevens.
