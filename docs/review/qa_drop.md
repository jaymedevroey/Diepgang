# QA-review: de drop en de binnenkant van De Ekster

Onafhankelijke review van de build van 2026-10-03 (commit b01fd61), vóór de verbeteringen van art,
level, cine en horizon. Alles hieronder is gezien op beelden uit de echte renderer (1600×900) of
gemeten in een headless test. Fase 3 (na het samenvoegen) vult de kolom "na" aan.

## Gereedschap

| Wat | Hoe |
| --- | --- |
| Opname van de hele drop | `tools\godot.cmd --path game --resolution 1600x900 -- --scenario=drop_sequence --tag=na [--repeat] [--skip] [--horizon] [--kade] [--left-behind] [--step=0.5] --no-steam` → `logs/drop_seq/na/`: beelden (tijd in de naam = **speltijd**), `tijdlijn.csv` (elke frame: toestand van de Mol, hoogte, camera, cinematic, muis, HUD), `samenvatting.txt` (duur per fase, camerawissels, fouten in de log) |
| Contactblad | `py -3.11 tools/contact_sheet.py logs/drop_seq/na [--match=drop1]` |
| Voor/na naast elkaar | `py -3.11 tools/contact_sheet.py logs/drop_seq/na --compare=logs/drop_seq/voor [--match=drop1] [--samples=6]` |
| Knippen, zwarte beelden, sprongen | `py -3.11 tools/contact_sheet.py logs/drop_seq/na --diff [--match=drop1]` |
| Het grote vierkant (hulpmiddel) | `py -3.11 tools/contact_sheet.py logs/drop_seq/na --horizon` (de rand van het terrein wijkt af van een gladde boog: een vierkant plateau heeft knikken, een planeet niet; hemel in de onderste hoeken; waas in de baai). Een schip of de Mol in beeld geeft valse meldingen: altijd de beelden zelf bekijken |
| De hele rondgang als speler | `tools\godot.cmd --headless --path game -- --scenario=drop_flow_test [--variant=main\|skip\|left_behind\|on_doors] --no-steam` |
| De drop als client | `py -3.11 tools/net_test.py --scenario=net_drop_flow_test [--port=N]` |

De tests gebruiken echte invoer waar het kan (E aan de terminal en de hendel via het vizier, Enter
op de knop, de bewegingstoetsen om in en uit de Mol te lopen, Esc, SPATIE). Ze tellen elke fout in
de log (`qa_error_log.gd`). Wat nog niet in het spel zit, staat als "NOG NIET BESCHIKBAAR".

**Let op bij tijden:** een beeld opslaan houdt het spel even op. De val duurt 13 s speltijd, maar
tussen de bestanden van een opname zat 21 tot 33 s. Duren altijd in speltijd lezen (tijdlijn.csv).

## Bevindingen vóór de verbeteringen

P0 = breekt de illusie of de werking, P1 = schaadt duidelijk, P2 = afwerking.

| ID | Waar | Wat | Prio | Wie |
| --- | --- | --- | --- | --- |
| QA-1 | val, beelden 031–036; hoogte 340 m | Het landschap is een vierkant plateau; aan de randen valt het weg in de hemel. Oorzaak: de verre ring stopt ±475 m van het midden (`PlanetSurface.RING`), daarachter is enkel hemel. | P0 | horizon |
| QA-2 | de open baai van de hub | Wie in de hub blijft en door de open luiken kijkt, ziet de hele wereld als een klein tegeltje in de waas (1740 m hoog). | P0 | horizon (+ art: schacht onder de baai) |
| QA-3 | ophalen | Het buitenbeeld bij het vertrek van de planeet komt nooit als je de drop meereed: `DropCam._t` telt door van de val. ±38 s naar de muur van de Mol kijken. | P1 | cine |
| QA-4 | tweede opdracht | Na een nieuwe wereld houdt de sonar echo's van vrijgegeven vondsten: elke frame een script-fout (780× in één run), het sonarscherm loopt niet meer. | P0 | lead |
| QA-5 | tweede drop | Het incidentrapport ligt over de aftelbanner. | P1 | level |
| QA-6 | val | Het vizier blijft midden in het buitenbeeld; prompts komen van de verborgen camera. | P1 | level + cine |
| QA-7 | hub | "0 m KLEI" en "graven (vasthouden)" in een ruimteschip. | P1 | level |
| QA-8 | aftellen | 8 s stilstaand beeld in de cabine, de luiken zie of voel je niet, dan een harde knip naar buiten. | P1 | cine |
| QA-9 | val | Eén vast volgshot van 13 s, donkere platte onderkant van het schip, stuwraketten als witte vierkantjes, geen klap in beeld, harde knip naar binnen; de tweede drop is identiek. | P1 | cine |
| QA-10 | val | Geen eigen geluid voor de drop; de geluiden van de Mol zijn 3D aan de Mol, de luisteraar hangt 30 m verder (afgeleid uit de code). | P1 | cine |
| QA-11 | landingsplek | Een raster van donkere lijnen op de vlakke landingsplek (van boven en te voet). | P1 | horizon |
| QA-12 | val | De concessiegrens leest van boven als een wit vierkant; binnen detail, buiten glad. | P1 | horizon |
| QA-13 | co-op | De host kan droppen terwijl een client de nieuwe wereld nog laadt (gemeten in `net_drop_flow_test`). | P1 | lead |
| QA-14 | val, alle peers | Het eerste beeld van de buitencamera staat ±1400 m van de Mol: hij rekent met de oude plek van de Mol (een AnimatableBody geeft na een sprong een tick lang nog de oude plek). Gemeten bij host en client. | P1 | cine |
| QA-15 | hub, luiken | De vloer van de luiken valt al weg bij 0–2 % open; wie erop staat valt door dichte luiken, en kan onder de landende Mol terechtkomen. | P2 | level |
| QA-16 | terminal | Een open terminal ververst niet als de Mol vertrekt (KIEZEN blijft aan). | P2 | level |
| QA-17 | terminal | De tekst op het scherm valt achter de stijlen; de prompt ligt op de tekst; het laden van de wereld (5–10 s) toont niets. | P2 | art / level |
| QA-18 | hemel | Sterren in de lichte waas op 340 m; de hub toont zwarte ruimte, 1400 m lager is het dag. | P2 | horizon |
| QA-19 | allerlei | Camerabeeld van de Mol toont de ringplaneet in de hub; meldingen stapelen; afspraken over de toets om over te slaan. | P2 | cine / level |
| QA-22 | nieuwe wereld in co-op | Atmosphere doet één frame een straal op de oude, al weggehaalde wereld (fout bij host en client). | P2 | horizon |

## Stand van de nieuwe tests op de build van vóór (2026-10-03)

Ze falen op de gekende fouten, en enkel daarop:

| Test | Resultaat | Faalt op |
| --- | --- | --- |
| `drop_flow_test` (main) | 70/76 | QA-14 (2×, beide drops), QA-3, QA-16, QA-5, QA-4 (781 fouten in de log) |
| `drop_flow_test --variant=skip` | 27/28 | QA-14 |
| `drop_flow_test --variant=left_behind` | 28/28 | — (de springer landt op de open klep: mag) |
| `drop_flow_test --variant=on_doors` | 14/15 | QA-15 (de vloer valt weg bij 0 % open) |
| `net_drop_flow_test` | 4 mislukt | QA-13, QA-14 (bij de client), QA-22 (fout in de log bij host en client) |

Nog niet beschikbaar (de nieuwe drop van cine): overslaan met SPATIE, Player.cinematic, aftellen
5 s als iedereen in de Mol zit, de korte tweede drop, de overdracht 0,6–0,8 s na de klap.

## Wat werkte (voor)

Camera en muis terug na de landing en na het ophalen; de speler blijft in de Mol bij beide sprongen;
met echte invoer uit de Mol en terug, op de grond en niet in de rots; de klep af tot op de kade in de
hub; twee keer kort na elkaar kiezen (de laatste telt); kiezen terwijl de Mol weg is kan niet; de
tweede drop landt op de nieuwe landingsplek; wie later door de baai springt, landt veilig.
Alle bestaande tests slaagden (ship_test 38/38, net_ship_test 11/11).

## Fase 3: na het samenvoegen (main 86301e7)

Opnames in de echte renderer (1600×900): `drop_sequence` met `--repeat`, `--skip`, `--horizon`,
`--kade`, `--left-behind`, en `ship_preview` (de hub op ooghoogte). Elk beeld bekeken, plus de
voor/na-bladen (`na_vs_voor_*.png`, `hub_na_vs_hub_voor_1.png`), `--diff` en `--horizon`.

### Wat de tests vonden: fout in het spel of in de test

| Test faalde op | Oordeel | Wie | Oorzaak en kleinste oplossing |
| --- | --- | --- | --- |
| buitenbeeld 1425 m van de Mol (main, skip, net) | **spel** (QA-14, kleiner) | cine | Het eerste beeld van het buitenbeeld (1 à 2 frames) staat goed, maar het model van de Mol hangt aan `body`, en dat lichaam staat na de sprong nog één physics-tick in de hub (AnimatableBody, zie lessons.md). Gezien in `na/130_drop2_dropping_t090.7.png`: grond, geen Mol, geen balken. Oplossing: in `Player._update_drop_cam` pas naar buiten knippen als ook `mol.body.global_position` bij `mol.placed.origin` is (of het eerste beeld zwart houden). De test meet dit nu als "beelden waarin het lichaam nog in de hub stond". |
| overslaan: geen sprong naar 150 m (skip, net, `na_skip`) | **spel** | cine | `_handle_skip` roept `_snap_short_entry()` op vanuit de invoer, buiten de physics-tick. De host zet de Mol op 150 m, maar de volgende `_drop` leest `body.global_position` (nog de oude plek) en zet hem terug. Gevolg: zwart, "Drop ingekort.", en dan valt de Mol gewoon verder vanaf ±300 m, aan 55 m/s (9,3–9,7 s in plaats van 10,7 s; `na_skip/026_drop1_op_300m_t015.0.png`). Bij de client springt de Mol één frame naar 150 m en terug naar 305 m (log van `net_drop_flow_test`). Oplossing: in `_handle_skip` enkel een vlag zetten en de sprong doen in `_drop()` (zoals na de val door de hub), en in `_drop` met `placed.origin` rekenen. |
| client-buitenbeeld 180 m van de Mol (net) | **spel** | cine | Gevolg van de vorige: het frame waarin de Mol bij de client heen en weer springt. |
| `!is_inside_tree()` in de log (net, host 1–26×, client 0–8×) | **spel** | lead | Meteen na `[game] nieuwe wereld`, enkel in co-op, zonder scriptspoor (de motor zelf vraagt `get_global_transform` op een node die net uit de boom is). Vermoeden (niet bewezen): het oude terrein wordt in `_rebuild_world` met `remove_child` weggehaald en leeft nog tot het einde van het frame terwijl godot_voxel er nog resultaten voor aflevert. Wisselvallig (0 in de run van de lead). |
| KIEZEN-knop staat aan terwijl de Mol weg is | **test** | — | Ontwerp van level: de knop blijft aan en het menu zegt waarom het niet kan. De test drukt nu op de knop en controleert dat er niets verandert en dat er "Kan nu niet: de Mol staat niet in de baai." staat. Geslaagd. |
| hendel start het tweede aftellen niet, en alles daarna | **test** | — | De test opende de terminal en drukte dan E voor de hendel; E sluit nu het menu (level). Nu trekt een "andere speler" aan de hendel terwijl de terminal open staat: precies QA-16. Geslaagd. |
| volle aftelling 8 s na uitstappen (left_behind) | **test** | — | Ontwerp: 5 s als iedereen aan boord is **bij de hendel**; uitstappen verlengt dat niet. De 8 s test nu de nettest (client op de kade bij de hendel: 8,0 s; springt erin: 5,6 s in totaal). |
| geland 5,6 m boven het oppervlak (left_behind) | **test** | — | Op het dak van de Mol geland (lokaal y 2,8): de Mol staat recht onder de baai. Mag; de test kent nu grond, klep, dak, onder en cabine, en weigert enkel onder of in de cabine. De speler loopt er gewoon af en de Mol in. |
| luiken "−100 % open" (on_doors) | **test** | — | Mijn meting nam het verkeerde moment. Nu: de hoek van de luiken als de speler drie ticks geen steun meer heeft: 16–50 graden (de botsvorm draait mee en het luik zwaait sneller weg dan je valt). Vóór: 0–2 % (door dichte luiken). Geslaagd. |
| de hendel weigert; het aftellen begon nooit (net) | **test** | — | De client laadt nog: de hendel weigert terecht met een melding (QA-13 werkt). De host trok maar één keer. Nu trekt hij elke seconde opnieuw, zoals een speler; het aftellen begint zodra de client klaar is. |
| tip aan de terminal | **test** | — | De tekst is nu "E: opdracht kiezen". |

Stand na de aanpassingen (de echte fouten blijven falen tot ze opgelost zijn):

| Test | Resultaat |
| --- | --- |
| `drop_flow_test` main | 88/89 (QA-14) |
| `drop_flow_test --variant=skip` | 37/39 (overslaan springt niet) |
| `drop_flow_test --variant=left_behind` | 30/30 |
| `drop_flow_test --variant=on_doors` | 15/15 |
| `net_drop_flow_test` | 20/25 (QA-14, overslaan, 180 m, fouten in de log bij host en client) |

### Wat ik nagekeken heb en klopt

- **Het grote vierkant is weg** (QA-1, QA-2): op elke hoogte van 4 tot 1740 m en in 8 richtingen
  (`na_horizon/`), tijdens de val (`na/026`–`046`), van de grond (`na/065`–`068`), door de baai van
  de hub (`na/081`–`083`: een schacht met de grond eronder) en bij de val van wie achterbleef
  (`na_left/061`–`082`). Van hoog een gebogen planeet in de waas: geen rand, geen hemel onder de horizon.
- **De drop is een reeks** (QA-8, QA-9): aftellen met rood licht, trillen en de buikcamera die de
  luiken toont (`na/011`–`020`); 1,2 s val in de cabine; het shot onder het buitenschip
  (`na/024`–`025`); het volgshot met snelheidsstrepen en balken (`026`–`040`); het remmen met
  stuwraketten en vooruit over het dak (`041`–`046`); binnen in de klap, stempel, besturing na 0,70 s.
  De tweede drop is kort: 5,8–6,0 s in plaats van 10,7 s, zonder het shot onder het schip.
- **Aftellen**: 5,0 s als iedereen aan boord is, 8,0 s als niet; niet over te slaan.
- **Camera, besturing, botsing, plek** na elke landing (beide drops, ook na overslaan): eigen camera
  met eigen FOV, los, op de vloer, HUD en vizier terug, met echte invoer uit de Mol (12,6–13,8 m), op
  het oppervlak, hoofd niet in de rots, binnen het speelgebied, en terug in de Mol.
- **Toetsen tijdens het buitenbeeld** verplaatsen de speler niet; **Esc** opent en sluit de pauze.
- **Ophalen** (QA-3): het buitenbeeld bij het vertrek staat er weer (`na/095`–`106`), daarna binnen.
- **Terug in de hub**: luiken dicht, rapport, met echte invoer de klep af tot op de kade.
- **Twee keer kiezen** (de laatste telt), **kiezen terwijl de Mol weg is** (gebeurt niet, het menu
  zegt waarom), **een open terminal bij het vertrek** ververst (QA-16).
- **QA-4** (sonar): 0 fouten in de log over twee nieuwe werelden (solo).
- **QA-13**: de hendel weigert zolang een client laadt; de drop vertrekt pas als iedereen de wereld heeft.
- **QA-5**: het rapport verdwijnt bij het aftellen (na 0,5 s geen overlap meer).
- **QA-7** deels: geen "0 m KLEI" meer in de hub; een doel ("KIES EEN OPDRACHT") in de plaats.
- **QA-17**: de tekst van de terminal is leesbaar (`ekster_terminal.png`); tijdens het laden staat er
  "DE EKSTER VLIEGT NAAR CONCESSIE …" (laden ±3 s).
- **Stemming in co-op**: de client alleen kan niet overslaan (1/2).
- Muis: de hele opname gevangen, behalve met de terminal open.

Niet zelf nagekeken: het geluid (enkel dat de bestanden `drop_*.wav` er zijn), een echte
middenklasse-pc, en spelen met toetsenbord en muis in een venster.

### Visuele bevindingen na, gerangschikt

| # | Prio | Waar | Wat | Wie |
| --- | --- | --- | --- | --- |
| 1 | P1 | `na_skip/026` | Overslaan toont zwart en "Drop ingekort.", maar de Mol valt gewoon verder vanaf ±300 m (zie hierboven). | cine |
| 2 | P1 | `na/130_drop2_dropping_t090.7` | Eén frame buitenbeeld zonder Mol bij de sprong naar buiten (QA-14). | cine |
| 3 | P2 | `na/030`, `033` (ingezoomd) | Het terrein op 150–300 m onder de camera heeft een fijn dambordpatroon (aliasing van de facetten en ruis op afstand); in beweging kruipt dat. | horizon |
| 4 | P2 | `na/118_drop2_drop_countdown_t084.7` | Het rapport vervaagt nog 0,3 s over de aftelbanner heen (de teksten lopen door elkaar). Meteen weg, of de banner pas daarna. | level |
| 5 | P2 | `na/011`, `016` | Tijdens het aftellen staan nog "Stap in de Mol en trek aan de hendel" en twee andere meldingen onderaan: drie regels plus doel, marker en banner. | level |
| 6 | P2 | `na/067`, `047` | De landingsplek is nu een veld zeshoekige platen met donkere voegen: beter dan het raster, maar het leest als tegels en houdt abrupt op aan de rand. | horizon |
| 7 | P2 | `na_left/082` | Wie na de drop door de baai springt, landt op het dak van de Mol (die staat er recht onder). Hij kan eraf; enkel ter info. | — |
| 8 | P2 | `ekster_spawn`, `na/010` | Het houweel blijft in de hand in de hub (rest van QA-7). | level |
| 9 | P2 | `na/046` | De klap zelf: weinig stof in beeld vlak voor de knip naar binnen. | cine |
| 10 | P2 | `na_horizon/084`–`091` | Op 1740 m hangt de hub als een klein donker blok in de lucht boven de landingsplek (enkel van de diagnosecamera's, niet in het spel gezien). | — |

Voor de lead: `game/src/world/planet_air.gdshaderinc.uid` en `planet_deck.gdshader.uid` ontstaan bij
het importeren maar staan niet in main. (Opgelost in 0abdab3.)

## Eindcontrole: voor en na (main 0abdab3, 2026-10-04)

Dezelfde plekken en momenten als de voorset (`logs/drop_seq/voor`, `logs/hub_voor`), opnieuw
opgenomen in de echte renderer (1600×900): `drop_sequence --tag=final --repeat`, `final_skip`
(`--skip --repeat`), `final_horizon`, `final_kade`, `final_left`, en `ship_preview` (de elf
hubshots en `--only=hud`). Elk beeld van "final" bekeken; daarnaast `--diff`, `--horizon` en de
tijdlijnen. Alle fouten in de log: 0 in elke opname.

**Voor/na-bladen** (in `logs/drop_seq/` en `logs/` van de QA-worktree):

| Blad | Wat |
| --- | --- |
| `drop_seq/final_vs_voor_hoogtepunten.png` | twaalf momenten naast elkaar, van de terminal tot de tweede drop |
| `drop_seq/final_vs_voor_hoogte.png` | het grote vierkant: 340, 160 en 60 m boven de landingsplek, 4 richtingen |
| `drop_seq/final_vs_voor_drop1.png` | de hele eerste drop, fase per fase |
| `drop_seq/final_vs_voor_terug.png` | het ophalen tot in de hub |
| `hub_final_vs_hub_voor_1.png`, `_2.png` | de hub op ooghoogte, met HUD |
| `drop_seq/final_horizon_horizon_.png` | 4 tot 1740 m in 8 richtingen (enkel na) |

### Tests op 0abdab3

`drop_flow_test` main 89/89, skip 39/39, left_behind 30/30, on_doors 15/15; `net_drop_flow_test`
25/25 (drie keer na elkaar). Eén aanpassing aan de nettest: een volledig zwart beeld (de dip bij
het overslaan) telt niet voor de afstand tot de Mol, zoals al in `drop_flow_test`. In dat zwarte
beeld staat de camera nog op zijn vorige plek, omdat de test vóór de `_process` van de camera meet.
De hele lijst van CLAUDE.md, `hub_screens_test`, `net_test` en `net_ship_test` slagen.

### Per oorspronkelijke bevinding

| ID | Stand | Bewijs |
| --- | --- | --- |
| QA-1 groot vierkant (val, 340 m) | **opgelost** | `final_vs_voor_hoogte.png`; `final/026`–`046`; `final_horizon/069`–`124`: een gebogen planeet in de waas, nergens een rand of hemel onder de horizon |
| QA-2 de wereld als tegel door de baai | **opgelost** | `final/081`–`083`: een schacht met de grond eronder; `final_left/061`–`063` |
| QA-3 geen buitenbeeld bij het ophalen | **opgelost** | `final/095`–`106`, `final_vs_voor_terug.png`; test |
| QA-4 sonar na een nieuwe wereld | **opgelost** | 0 fouten in de log over drie werelden (opnames en tests) |
| QA-5 rapport over de aftelbanner | **opgelost** | `final/117` (rapport) → `final/118` (meteen weg, enkel de banner) |
| QA-6 HUD tijdens het filmpje | **opgelost** (rest: zie 4 hieronder) | `final/024`–`046`: geen vizier, geen prompts; tijdlijn: vizier uit tijdens de val |
| QA-7 graaf-HUD in het schip | **opgelost** | `hub_final_vs_hub_voor_2.png` (spawn, werkdek): geen "0 m KLEI", geen houweel, een doel in de plaats |
| QA-8 aftellen 8 s stilstaand | **opgelost** | `final/011`–`022`: rood licht, trillen, buikcamera met de luiken, 5 s als iedereen aan boord is |
| QA-9 één vlak shot, harde knippen | **opgelost** | `final/021`–`049`: val door de hub, shot onder het schip, volgshot met strepen en balken, remmen, stof, binnen in de klap; tweede drop kort (`final/128`–`143`, 5,8 s i.p.v. 10,7 s) |
| QA-10 geen geluid | **deels** | `drop_*.wav` (14 klanken) bestaan en worden afgespeeld; niet met het oor nagekeken |
| QA-11 raster op de landingsplek | **grotendeels** | `final/066`–`068`: geen raster meer; zeshoekige platen met lichte voegen die met de afstand wegvallen (leest nog een beetje als tegels, van dichtbij) |
| QA-12 wit vierkant (concessiegrens) | **opgelost** | `final_vs_voor_hoogte.png` (160 en 60 m) |
| QA-13 drop terwijl een client laadt | **opgelost** | `net_drop_flow_test`: de hendel weigert met een melding tot de client klaar is |
| QA-14 eerste buitenbeeld zonder Mol | **opgelost** | tests: 0 beelden; bij de sprong 1 à 2 frames volledig zwart (`final/023`) |
| QA-15 vallen door dichte luiken | **opgelost** | `on_doors`: steun pas kwijt bij ±50 graden |
| QA-16 open terminal ververst niet | **opgelost** | test (tekst "De Mol is op weg…", KIEZEN zegt waarom niet) |
| QA-17 terminal onleesbaar, laden zonder iets | **opgelost** | `hub_final/ekster_terminal.png`, `final/003`–`009` ("DE EKSTER VLIEGT NAAR CONCESSIE …") |
| QA-18 hemel en hoogte sluiten niet aan | **niet** | `hub_final/ekster_venster.png`: nog steeds zwarte ruimte met sterren, terwijl 1.400 m lager dag is |
| QA-19 kleine resten | **opgelost** | camerascherm in de hub toont de buik (`final/117`); meldingen niet dubbel; SPATIE = overslaan |
| QA-22 straal op de oude wereld | **opgelost** | 0 fouten bij host en client (`net_drop_flow_test`, drie keer) |

Overslaan (gevraagd door Jayme): `final_skip/023`–`026`: SPATIE in het shot onder het schip, zwart,
"Drop ingekort.", de Mol op ±145 m, landing na 6,96 s val i.p.v. 10,65 s; daarna dezelfde
overdracht. Het aftellen zelf is niet over te slaan. Herhaald kiezen: twee opdrachten kort na
elkaar (de laatste telt), kiezen terwijl de Mol weg is (gebeurt niet), en een tweede drop naar een
nieuwe wereld: alles nagekeken in de tests en in `final/116`–`157`.

Camera, besturing, botsing en plek na elke landing en na het ophalen: eigen camera met eigen FOV,
muis gevangen, de speler los en op de vloer, met echte invoer uit de Mol (12,6–13,8 m) tot op het
oppervlak, hoofd niet in de rots, binnen het speelgebied, en terug; in de hub met echte invoer de klep
af tot op de kade. Wie in de hub bleef, ziet geen filmpje en kan later zelf door de baai springen.

### Wat nog zwak is, gerangschikt

| # | Prio | Waar | Wat | Wie |
| --- | --- | --- | --- | --- |
| 1 | P2 | `final/030`, `033` (ingezoomd) | Het terrein 150–300 m onder het volgshot heeft nog een fijn dambordpatroon; zachter dan voor, maar in beweging kruipt het. | horizon |
| 2 | P2 | `final/046`, `final/142` | De echte schaduw van de Mol vlak voor de klap is een groot donker vlak met zaagtandranden (schaduwkaart te grof op die afstand). Valt op in het laatste buitenbeeld. | horizon |
| 3 | P2 | `final/046`, `final/142` | Twee donkere pluimpjes in de lucht boven de Mol (rook van de uitlaten, tegen de lichte hemel): lijken vuil op de lens. | cine |
| 4 | P2 | `final/095` | Het vizier staat nog ±0,6 s midden in het buitenbeeld van het ophalen (het vervaagt i.p.v. meteen weg). | level / cine |
| 5 | P2 | `final/023`, `final_skip/023` | De sprong van de hub naar buiten gaat door 1 à 2 volledig zwarte frames. Bewust (geen beeld zonder Mol), maar in het echt nakijken of het als een flits leest. | cine |
| 6 | P2 | `hub_final/ekster_venster.png` | QA-18: de ramen van de hub tonen zwarte ruimte met sterren, de planeet eronder is dag. | horizon / art |
| 7 | P3 | `final_left/082` | Wie na de drop door de baai springt, landt op het dak van de Mol (die staat er recht onder). Hij kan eraf. | — |

Niet zelf nagekeken: het geluid met het oor, een middenklasse-pc, en spelen met toetsenbord en muis
in een venster.
