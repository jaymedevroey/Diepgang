# Diepgang — werkafspraken voor de agent

Co-op opgravingsgame in Godot. Het ontwerp staat in [docs/GDD.md](docs/GDD.md), de taken in [tasks/todo.md](tasks/todo.md), en de lessen in [tasks/lessons.md](tasks/lessons.md). Lees lessons.md voor je aan een nieuwe stap begint.

## Vaste keuzes
- Godot **4.7.2** standaard (geen .NET), GDScript, Forward+, Jolt. Niet upgraden zonder akkoord van Jayme.
- Godot starten via `tools\godot.cmd` (console-variant, output zichtbaar). Headless controle: `tools\godot.cmd --headless --path game --quit-after 30`.
- Terrein enkel via de `TerrainAPI`-laag (`game/src/terrain`). Terrein kan enkel weggenomen worden.
- Alle "gevoel"-waarden in `game/data/tuning/`, niet hardcoded.
- Python-scripts met `py -3.11`, niet de `python` in PATH.

## Testen
- Alle testcommando's staan bovenaan `tasks/todo.md`. Voor elke commit: `dig_test`, `find_test`, `carry_test`, `mol_test`, `sonar_test`, `mol_edge_test`, `stream_test`, `ore_test`, `ship_test`, `magma_test`, `company_test`, `tuning_test`, `ui_test`, `hub_screens_test`, `drop_flow_test`, `economy_test` (headless), `py -3.11 tools/net_test.py`, `py -3.11 tools/net_test.py --scenario=net_ship_test` `py -3.11 tools/net_test.py --scenario=net_drop_flow_test` en `--scenario=net_economy_test`.
- Visuele wijzigingen: zelf een screenshot nemen en bekijken vóór je iets aan Jayme geeft.
- Netwerk: wat de client voorspelt, moet de host aanvaarden (zelfde controles aan beide kanten).

## Werkwijze
- Elke taak heeft een verificatie. Vink pas af in `tasks/todo.md` als die gelukt is, met datum en wat je zag.
- Wat je leert of wat het GDD bijstuurt: in `tasks/lessons.md`.
- Nieuwe externe assets of bibliotheken: meteen in `CREDITS.md` met licentie.
- Performancecijfers van deze pc (RTX 4090) zijn geen bewijs voor mid-range.
- Taal van de docs: Nederlands. Code en identifiers: Engels.
- Tekst in het spel (UI, HUD, hints, bordjes en opschriften in modellen, schermen, tv, namen van planeten en vondsten): **altijd Engels** (Jayme, 2026-10-05: alles vertaald). Volg de woordenlijst in `tasks/lessons.md` (2026-10-05). Docs, commentaar en logregels blijven Nederlands.
