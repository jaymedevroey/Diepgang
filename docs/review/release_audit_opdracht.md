# Release-audit (2026-10-05): opdracht voor de reviewers

Jayme wil weten of wat er nu staat echt klaar is voor release. Dit is een **audit, geen bouwronde**: je verandert niets aan het spel, je levert een rapport. Jayme kiest daarna wat er aangepakt wordt.

## De lat: een publieke Steam-demo

- Een vreemde downloadt de demo, speelt zonder uitleg van Jayme, en een streamer of recensent kijkt mee.
- Wees **zo kritisch mogelijk**. Iets onterecht slecht vinden is beter dan iets slechts goedkeuren. Geen beleefdheid, geen "goed genoeg voor een prototype", geen "dat komt later wel".
- Vergelijk met wat er op Steam staat en verkoopt in dit genre (GDD §2): Lethal Company, R.E.P.O., Deep Rock Galactic, PEAK, Content Warning, Helldivers 2 (de hub), Dome Keeper. "Zou dit naast hen op de Steam-pagina standhouden?"

## Wat je bekijkt

- **In scope: gameplay en gevoel, en uiterlijk.**
- **Buiten scope:** onboarding en tutorial, stabiliteit en performance, Steam en voice. Noteer daar enkel iets over als het je echt in de weg zit, in één regel onder "Buiten scope".
- **Geluid** is een beslissing van Jayme (M6): het spel heeft bijna geen geluid. Dat is bekend. Schrijf het niet bij elke bevinding. Noem het enkel waar het ontbreken een specifiek moment aantoonbaar breekt.

## Hoe je het spel beleeft

Je speelt niet met muis en toetsen. Je gebruikt de scenario's, eigen camera's en metingen. Lees eerst `tasks/lessons.md` (de bovenste secties) en `tasks/todo.md` ("Hoe testen").

- **Eenmalig in je worktree:** `tools\godot.cmd --headless --path game --import`.
- **Beelden:** de scenario's in `game/src/main/scenarios/`. De kop van elk bestand zegt wat het doet. Bijvoorbeeld:
  - `drop_sequence`: de hele drop. Opties `--planet=roestbol|fossielwereld|kristalmaan`, `--repeat`, `--horizon`.
  - De previews: `ship_preview`, `interior_preview`, `mol_preview`, `hud_preview`, `magma_preview`, `terrain_preview`, `finds_gallery`, `tool_preview`, `robot_preview`, `sky_preview`, `planet_preview`, `ui_preview`.
  - `play`: met `--autodig --shot=naam --frames=… --pitch=… --yaw=…`.
- **Bewegend beeld:** Godot's Movie Maker, bijvoorbeeld `tools\godot.cmd --path game --resolution 1600x900 --write-movie logs/review/<rol>/film/f.png --fixed-fps 30 -- --scenario=…`. Dat schrijft genummerde frames. Bekijk een reeks frames, niet één beeld.
- **Echte invoer:** `drop_flow_test` (`--variant=…`) en de andere tests gebruiken echte invoer. De waarden voor het gevoel staan in `game/data/tuning/*.cfg`.
- **Eigen tijdelijke scripts en camera's:** die mogen enkel in je eigen worktree, en je commit ze niet. Wat je niet kunt zien of meten, zeg je eerlijk. Raad niet.
- Geen computer-use, en niets aanraken buiten de Godot-vensters die je zelf start.

## Bewijs en vorm

- **Kijk naar elk beeld zelf**, en zoom in waar het om details gaat.
- **Bewaar je bewijs** in `C:\Dev\Diepgang\logs\review\<rol>\`. Dat is de hoofdcheckout, met een absoluut pad. Geef de bestanden duidelijke namen.
- **Elke bevinding bevat:**
  - **ID:** `<rol>-<nr>`.
  - **Ernst:** zie hieronder.
  - **Waar:** de plek in het spel, en het bestand of de scène.
  - **Wat:** wat er mis is, concreet.
  - **Waarom:** vanuit de speler, met een vergelijking met een echte game of ons eigen ontwerp (GDD, stijlgids, research).
  - **Richting:** een richting voor de oplossing.
  - **Moeite:** S, M of L.
  - **Bewijs:** de beelden of de meting.
- **Ernst:**
  - **Blokkerend:** wie de demo speelt of bekijkt, ziet het in de eerste 10–15 minuten, en het schaadt de indruk sterk of maakt iets onspeelbaar of saai.
  - **Ernstig:** duidelijk onder demo-niveau.
  - **Middel:** merkbaar, polish.
  - **Klein:** een detail.
- **Je rapport** schrijf je in het Nederlands, in `C:\Dev\Diepgang\logs\review\<rol>\rapport.md`. Begin met de bevindingen, gerangschikt van Blokkerend naar Klein. Sluit af met hooguit 5 regels over wat wel op demo-niveau zit, zodat dat niet kapot gaat.
- **Je antwoord aan de lead** is hooguit 40 regels: je zwaarste bevindingen eerst, plus het pad naar je rapport.
- **Wees zuinig met gebruik:** Jayme let erop. Grondig kijken, maar geen herhaalde volledige runs als één gerichte run volstaat.

## Ontwerpbronnen

- `docs/GDD.md`
- `docs/stijlgids.md`
- `docs/de-mol.md`
- `docs/research/*.md` (onder andere `plezier-en-design.md`, `graven.md`, `magma-en-onrust.md`, `planeten.md`, `hemel.md`, `hud-menu.md`, `schip-interieur.md`, `drop-en-ophalen.md`, `rots-en-licht.md`)
- `docs/review/qa_drop.md`
