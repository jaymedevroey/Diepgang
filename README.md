# Diepgang

Co-op opgravingsgame (1–4 spelers) in Godot 4.7.2: kleine robots van een louche opgravingsfirma boren met **de Mol** naar beneden, bikken fossielen en schatten uit hun korst en slepen ze samen naar het laadruim.

- Ontwerp: [docs/GDD.md](docs/GDD.md) · de Mol: [docs/de-mol.md](docs/de-mol.md) · onderzoek: [docs/research/](docs/research/)
- Taken en wat af is: [tasks/todo.md](tasks/todo.md) · lessen: [tasks/lessons.md](tasks/lessons.md)

## Spelen op een andere pc (Windows)

1. Ga naar **Releases** (rechts op de GitHub-pagina) en download de nieuwste `Diepgang-windows.zip`.
2. Pak de zip uit (niet starten vanuit de zip zelf) en start `Diepgang.exe`.
3. Besturing en wat je kan testen: `LEESMIJ.txt` in dezelfde map (ook [docs/playtest-m1.md](docs/playtest-m1.md)).

Windows kan een waarschuwing tonen (SmartScreen: onbekende uitgever) omdat de build niet ondertekend is: *Meer info → Toch uitvoeren*.
Samen spelen gaat voorlopig via het netwerk thuis (Hosten / Meedoen met het IP van de host); uitnodigen via Steam komt later.

## Vanuit de broncode

- Godot **4.7.2** standaard (geen .NET). Open `game/project.godot`; de extensies (godot_voxel, GodotSteam) zitten in `game/addons/`.
- Tests (headless): zie bovenaan [tasks/todo.md](tasks/todo.md).
- Windows-build: `tools\export_windows.cmd` → `builds\windows\Diepgang.exe` (het pad naar Godot staat in `tools\godot.cmd`).
