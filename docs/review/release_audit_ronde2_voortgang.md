# Release-audit ronde 2: voortgang per punt

Bron: [release_audit_ronde2.md](release_audit_ronde2.md); details in `logs/review2/<rol>/rapport.md`.
Jayme (2026-10-06): alles aanpakken (golf 3); geluid niet uit code, enkel echte opnames (apart spoor, zie onderaan).
Hier staan de oude punten die 'beter, niet genoeg' of 'erger' waren en alle nieuwe punten.

## Pakketten

- **G1**: Worm en climax (10 punten)
- **G2**: Neergaan, klap, kleinere gevaren, dragen (22 punten)
- **G3**: Geldmoment en economie (16 punten)
- **G4**: Buiten en drop (22 punten)
- **G5**: Ondergrond (12 punten)
- **G6**: Tekst, toetsen, HUD-stijl, hub, snelle fouten (15 punten)

## Status

| ID | Pakket | Status | Wat er gedaan is | Verificatie |
|---|---|---|---|---|
| ontwerp-1 | G1 | open | | |
| ontwerp-7 | G1 | open | | |
| ontwerp2-1 | G1 | open | | |
| ontwerp2-2 | G1 | open | | |
| ontwerp2-3 | G1 | open | | |
| binnen2-01 | G1 | open | | |
| binnen2-02 | G1 | open | | |
| gevoel2-05 | G1 | open | | |
| gevoel2-07 | G1 | open | | |
| ui2-05 | G1 | open | | |
| gevoel2-01 | G2 | open | | |
| gevoel2-02 | G2 | open | | |
| binnen2-03 | G2 | open | | |
| gevoel2-03 | G2 | open | | |
| gevoel2-06 | G2 | open | | |
| binnen2-07 | G2 | open | | |
| binnen-10 | G2 | open | | |
| gevoel2-08 | G2 | open | | |
| gevoel2-09 | G2 | open | | |
| binnen2-04 | G2 | open | | |
| gevoel2-10 | G2 | open | | |
| ui2-02 | G2 | open | | |
| ui2-03 | G2 | open | | |
| ui2-15 | G2 | open | | |
| gevoel-08 | G2 | open | | |
| gevoel-19 | G2 | open | | |
| binnen-05 | G2 | open | | |
| gevoel2-13 | G2 | open | | |
| gevoel2-14 | G2 | open | | |
| gevoel2-15 | G2 | open | | |
| gevoel2-16 | G2 | open | | |
| ontwerp-8 | G2 | open | | |
| ui2-01 | G3 | open | | |
| gevoel2-04 | G3 | open | | |
| binnen2-10 | G3 | open | | |
| binnen2-11 | G3 | open | | |
| ui2-11 | G3 | open | | |
| ui2-12 | G3 | open | | |
| ontwerp2-4 | G3 | open | | |
| ontwerp2-5 | G3 | open | | |
| ontwerp2-6 | G3 | open | | |
| ontwerp2-9 | G3 | open | | |
| ontwerp2-10 | G3 | open | | |
| ontwerp2-11 | G3 | open | | |
| ontwerp-3 | G3 | open | | |
| ontwerp-10 | G3 | open | | |
| ui-03 | G3 | open | | |
| ui2-14 | G3 | open | | |
| buiten-3 | G4 | open | | |
| buiten-4 | G4 | open | | |
| buiten-5 | G4 | open | | |
| buiten-6 | G4 | open | | |
| buiten-7 | G4 | open | | |
| buiten-8 | G4 | open | | |
| buiten-9 | G4 | open | | |
| buiten-10 | G4 | open | | |
| buiten-12 | G4 | open | | |
| buiten-14 | G4 | open | | |
| buiten2-1 | G4 | open | | |
| buiten2-2 | G4 | open | | |
| buiten2-3 | G4 | open | | |
| buiten2-4 | G4 | open | | |
| buiten2-5 | G4 | open | | |
| buiten2-6 | G4 | open | | |
| buiten2-7 | G4 | open | | |
| buiten2-8 | G4 | open | | |
| buiten2-9 | G4 | open | | |
| gevoel-17 | G4 | open | | |
| gevoel2-11 | G4 | open | | |
| gevoel2-12 | G4 | open | | |
| binnen-01 | G5 | open | | |
| binnen-03 | G5 | open | | |
| binnen-04 | G5 | open | | |
| binnen-06 | G5 | open | | |
| binnen-08 | G5 | open | | |
| binnen2-05 | G5 | open | | |
| binnen2-06 | G5 | open | | |
| binnen2-08 | G5 | open | | |
| binnen2-09 | G5 | open | | |
| binnen2-12 | G5 | open | | |
| binnen2-14 | G5 | open | | |
| binnen2-15 | G5 | open | | |
| ui-07 | G6 | klaar | TextLint bewaakt stijlregels en woordenlijst over alle spelertekst en Blender-opschriften; ui_test kijkt ook wat op het scherm staat | ui_test --only=text; G6: interior_terminal_na |
| ui2-07 | G6 | klaar | Echt minteken (UiTheme.signed), m/kg, € met komma, overal 'contract table', 'team funds', magmaregel herschreven, boete-tekst, PAY in procenten | ui_test; G6: f1_scanner, hud_buitenzicht |
| ui2-08 | G6 | klaar | Laadruim leest de limiet uit economy.cfg (MAX 60 KG / EXTENDED HOLD 140 KG), rek enkel DRILL T2, prijslijst zichtbaar met enkel scanner en lamp, dozen met niet-bestaande items weg | G6: hub_r10d_laadruim_bord, hub_z12_prijslijst, hub_z13_rekbord |
| ui2-09 | G6 | klaar (toetsenbord; controller: herkenning en namen klaar, geen standaardknoppen) | Elke toets uit Settings.key_of of {actie} via Settings.fill_keys(), ook in meldingen van de host | ui_test |
| ui2-10 | G6 | klaar | StartMenu.is_host_only weert VirtualBox (192.168.56.0/24), VMware, Hyper-V, WSL en internetdeling; op Jaymes pc enkel Tailscale en 192.168.0.54 | ui_test |
| ui2-04 | G6 | klaar | Pilootstrook links van de sonar of erboven; ui_test controleert overlap bij 100/125/150% interface | ui_test; G6: hud_buitenzicht |
| ui-09 | G6 | deels (TREMOR en GAS bij G1/G2) | Robot en bakens op één HUD-plaatje met toetsblokje, één kleurregel (UiTheme.state_color), draw_chip/draw_key | G6: hud_dreiging |
| ui2-06 | G6 | deels (TREMOR en GAS bij G1/G2) | Zie ui-09 | G6: hud_dreiging |
| ui-13 | G6 | klaar | Alle consolelabels in Bungee op een donker plaatje, even groot | G6: hud_piloot (voor), hud_piloot_console (na) |
| ui2-13 | G6 | klaar | Magmachip weg in de stoel, stempel 40 px lager | G6: hud_stempel |
| binnen-12 | G6 | deels | Voetsporen in 4 varianten, olie niet meer onder de vloerpijl. Open: vloeren nog vrij schoon | G6: hub_z01, hub_z02, hub_z04 |
| binnen-17 | G6 | klaar (ter goedkeuring) | Verlichte bak SELL HATCH met pijl aan de kant van de brug | G6: hub_n10_brug_naar_mol |
| binnen2-13 | G6 | deels | Modderrand op de Mol golft, vlekken in het laadruim i.p.v. zwarte sleuven. Open: vloeren nog vrij schoon | G6: hub_r10c, mol_binnen |
| ontwerp2-7 | G6 | klaar | drill.cfg: graniet 0,08/1,6, kristal 0,07/1,8; tuning_test bewaakt dat dieper trager en heter boort | tuning_test |
| ontwerp2-8 | G6 | klaar (ter goedkeuring) | Neus omlaag boort sneller tot 2,7 m/s bij 25° (piloot en autopiloot); verticaal ±1,14 m/s i.p.v. 0,49; GDD §5A aangevuld (golf 3) | mol_test: −25 m in 29 s |

## Geluid (apart spoor)

Jayme: geen geluid uit code, "da trekt op niks". Enkel echte opnames van een bron die echt goed is, met zijn toestemming per download. De pakketten voorzien enkel haken (signalen) waar een geluid hoort.

