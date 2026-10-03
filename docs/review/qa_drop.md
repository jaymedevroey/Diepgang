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
| Het grote vierkant (hulpmiddel) | `py -3.11 tools/contact_sheet.py logs/drop_seq/na --horizon` (rand van het terrein aan de zijkanten lager dan in het midden, hemel in de onderste hoeken, waas in de baai) |
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
