# Diepgang — stijlgids

Versie 1, 1 oktober 2026. **Concept: wacht op akkoord van Jayme.** Bron voor alles wat ik maak in M2 Uiterlijk.
Richting (GDD §8): Deep Rock Galactic (gestileerd, chunky, licht in het donker) + PEAK (warm, speels, menselijk) + Astroneer (zachte vormen, speelgoedachtige voertuigen). Alle modellen in Blender, geen AI-modellen.

## In één zin

**Warme lampjes van een louche firma in een koude, eeuwenoude diepte.**
Alles wat van ons is (robots, de Mol, gereedschap, lampen) is warm, geel, afgerond en een beetje knullig. Alles wat van de diepte is (rots, kristal, lava, de worm) is groot, oud en koud of gevaarlijk gekleurd.

## Vijf pijlers

- **Licht is de held.** Waar geen lamp is, is het (bijna) zwart. Wat licht geeft, is het mooiste in beeld.
- **De lagen zijn het landschap.** Elke tunnelwand toont een doorsnede van de aarde. Elke diepte heeft een eigen kleur, patroon en mist.
- **Chunky en zacht.** Dikke vormen, alles afgeschuind, proporties iets overdreven. Leesbaar in het donker op 20 m.
- **Alles reageert.** Stof, brokken, vonken, schokken, geluid, wiebelen.
- **Charme.** Robots met schermgezichten, een louche firma met goedkope stickers, rommel als vondst.

## Palet

Rots (laag verzadigd, geeft rust):

| Laag | Basis | Licht | Donker | Patroon |
|---|---|---|---|---|
| Klei (0 tot −25 m) | `#6E4A35` | `#9A6B4C` | `#3E2A1F` | egaal, kleine kiezels, droge barstjes |
| Zandsteen (−25 tot −70 m) | `#B08A55` | `#D1AD72` | `#7A5B34` | horizontale banden |
| Graniet (−70 tot −115 m) | `#5F646B` | `#9A9EA3` | `#2A2D33` | spikkels (zwart, wit, roze `#A88378`) |
| Kristalgesteente (−115 m en dieper) | `#232838` | `#3A4260` | `#12141D` | lichtgevende aders |

Licht (enkel deze dingen gloeien):

| Rol | Kleur |
|---|---|
| Helmlamp, lampen van ons | amber `#FFB45A` |
| Kristal | cyaan `#4FE3F0` |
| Lava, gevaar | oranje `#FF5A1F`, kern `#FFC24A` |

Diepgang BV (machines, gereedschap, UI):

| Rol | Kleur |
|---|---|
| Bedrijfsgeel (de Mol, accenten) | `#F2B705` |
| Antraciet (frames, machines) | `#23262B` |
| Staal | `#8C9096` |
| Waarschuwing | geel/zwarte strepen |

Robots: romp crème `#E9E1D3`, hoofdschaal en panelen in de spelerskleur: amber `#F28C1E`, cyaan `#33BFF2`, limoen `#8CE040`, magenta `#E65AB8`. *(Voorstel; nu is de hele robot in de spelerskleur.)*

Vondsten: bot `#E8DCC0`, korst `#B7A27E`, brons `#B0763A`, goud `#F0C24B`.

Duisternis: mist `#120D0A` (warm bijna-zwart), schaduwtint `#1A2230` (koel).

## Licht

- Omgevingslicht bijna nul, maar nooit puur zwart: 2–4% warme mist, zodat vormen nog lezen.
- **Warm = van ons, koud = van de diepte, oranje = gevaar.** Kleurgrading: hooglichten warm, schaduwen koel.
- Hooguit 4–8 lampen met schaduw (helmlampen, koplampen van de Mol). Alle andere lampen zonder schaduw en met kort bereik.
- Stof zweeft zichtbaar in elke lichtbundel.
- Gloed (bloom) enkel op emissieve dingen: lamplenzen, kristal, lava, schermen.
- Elke laag een eigen misttint: klei roodbruin, zandsteen goud, graniet blauwgrijs, kristal indigo.

## Vormtaal

- **Afschuinen**: geen enkele harde rand. Afschuining minstens 1/10 van de kleinste maat van het onderdeel. Afgeschuinde randen vangen licht: dat is het DRG-trucje.
- **Overdrijven**: grepen dikker, koppen groter, gereedschap 1,2–1,4× realistisch.
- **Silhouet eerst**: elk object moet als zwarte vorm herkenbaar zijn. Een bot leest als bot, de Mol als drilboor.
- **Geen details kleiner dan 2 cm**: onleesbaar en flikkert.
- Machines: geklonken platen, dikke bouten, waarschuwingsstrepen, "Diepgang BV"-stickers, krassen en vuil langs de randen.
- Natuur: grote, grillige vormen. Detail zit in de textuur, niet in de geometrie.
- Polygonen: de Mol 15–25k driehoeken, robot 5–8k, gereedschap 1–3k, vondsten 0,5–2k.

## Materialen

- **Geen foto-texturen.** Gestileerd, "handgeschilderd": grote vlakken, enkele lijnen, geen fijne ruis van ver. Gebakken met Python, triplanar op het terrein.
- Modellen: één paletatlas of vertexkleuren, zodat alles uit hetzelfde palet komt.
- Ruwheid per klasse: rots 0,9 · geverfd metaal 0,5 (kale randen 0,3) · bot 0,65 · kristal 0,1 + gloed.
- Randslijtage: lichtere, kale randen op geverfd metaal.

## Per onderdeel

- **Terrein**: zie palet. Laaggrenzen golven licht en zijn zichtbaar als een duidelijke lijn in de wand.
- **Robots**: rond hoofd met scherm, pixelogen (cyaan), antenne met bolletje in de spelerskleur, crème romp, kleine ledematen. Hoedjes later.
- **De Mol**: bedrijfsgeel met antraciet, enorme boorkop van kaal staal met snijtanden, ronde cabineramen met warm licht binnen, koplampen, uitlaat met rook, "DIEPGANG BV" in stencil op de flank, deuken en stickers. Binnen: houten werkbank, warme lampjes, rommelig.
- **Gereedschap**: Diepgang-geel met antraciet, dikke grepen, kale stalen koppen, een sticker of tape.
- **Vondsten**: botten ivoor met okervlekken. Relieken brons en goud. Kristallen cyaan, glazig, gloeiend. Rommel herkenbaar en grappig.
- **Effecten**: dikke stofwolken in de laagkleur, brokjes in rotsvorm (geen kubussen), vonken amber-wit, lava met warmtegloed.
- **UI**: "goedkope bedrijfshuisstijl": geel/antraciet, stencilkoppen, schermen in de wereld met een amberen dotmatrix. HUD minimaal.

## Letters (Google Fonts, OFL)

- Koppen en borden: **Bungee** (chunky, signalisatie).
- Tekst: **Nunito** (rond, vriendelijk).
- Schermen in de wereld: **VT323** (dotmatrix).

## Geluid (kort)

Fysiek, warm en een tikje komisch. Gelaagde synthese, 3–5 varianten per geluid. Muziek: piano en strijkers in het depot, donkere ambient-lagen in de put die aanzwellen met diepte en onrust. Geen melodieuze actiemuziek (GDD §8).

## Doen en niet doen

| Doen | Niet doen |
|---|---|
| Grote vormen, duidelijke silhouetten | Fijne details, dunne staafjes |
| Licht als blikvanger | Alles gelijkmatig verlicht |
| Eén palet voor alles | Losse kleuren per object |
| Gestileerde texturen | Foto-texturen, realistisch vuil |
| Afgeschuinde randen | Scherpe, kale kubussen |
| Gloed op wat licht geeft | Gloed op alles |

## Hoe ik controleer (bij elke screenshot)

- **Silhouet**: in zwart-wit nog herkenbaar?
- **Waarden**: grijswaardenversie heeft licht, middentoon en donker, geen grijze soep.
- **Palet**: geen kleuren buiten deze gids.
- **Laag**: zie je meteen op welke diepte je bent?
- **Licht**: de lamp en wat gloeit, trekken het oog.

## Open vragen voor Jayme

1. Robots: crème romp met gekleurde schaal (zoals Astroneer), of helemaal in de spelerskleur (zoals nu)?
2. Diepgang BV-geel als bedrijfskleur voor de Mol, het gereedschap en de UI?
3. Letters: Bungee, Nunito en VT323, of liever iets anders?
