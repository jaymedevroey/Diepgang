# Release-audit: voortgang per punt

Bron: [release_audit.md](release_audit.md). De volledige bevindingen staan in `logs/review/<rol>/rapport.md`.

Jayme, 2026-10-05 's avonds: alles aanpakken en blijven vergelijken met alle punten. Morgen doen we de audit opnieuw.

## Golven

**Golf 1** (5 pakketten tegelijk, elk een eigen worktree, elk zijn eigen bestanden):
- **A:** hub, UI en tekst;
- **B:** de speler (lopen, gereedschap, dragen, vondsten);
- **C:** de Mol, de drop en het ophalen;
- **D:** de ondergrond en de gevaren in beeld;
- **E:** de planeten buiten.

**Golf 2** (op golf 1):
- **F1:** economie en voortgang (verkopen, upgrades, boor T2, quota, contracten);
- **F2:** dreiging en climax (graafworm, gas, neergaan en redden, gevaren per planeet).

**Buiten de opdracht** (Jayme): geluid (M6), Steam en voice (M5).

## Status

Legenda: **open**, **bezig**, **klaar** (met verificatie), **deels**, **niet** (met de reden).

| ID | Ernst | Pakket | Status | Wat er gedaan is | Verificatie |
|---|---|---|---|---|---|
| ontwerp-1 | Blokkerend | F2 | open | | |
| ontwerp-2 | Blokkerend | F1 (+A: tekst "interest") | deels (tekst klaar, economie bij F1) | 'Interest is accruing' vervangen door 'Head office has noticed.' | A1 |
| ontwerp-3 | Ernstig | F1 | open | | |
| ontwerp-4 | Ernstig | F1 | open | | |
| ontwerp-5 | Ernstig | F2 | open | | |
| ontwerp-6 | Ernstig | C | open | | |
| ontwerp-7 | Ernstig | F2 | open | | |
| ontwerp-8 | Ernstig | F2 | open | | |
| ontwerp-9 | Ernstig | F1 | open | | |
| ontwerp-10 | Ernstig | F1 | open | | |
| ontwerp-11 | Middel | B | open | | |
| ontwerp-12 | Middel | D | open | | |
| ontwerp-13 | Middel | B | open | | |
| ontwerp-14 | Middel | C | open | | |
| ontwerp-15 | Middel | C | open | | |
| ontwerp-16 | Klein | B | open | | |
| gevoel-01 | Blokkerend | B | open | | |
| gevoel-02 | Blokkerend | B | open | | |
| gevoel-03 | Blokkerend | B | open | | |
| gevoel-04 | Ernstig | C | open | | |
| gevoel-05 | Ernstig | C | open | | |
| gevoel-06 | Ernstig | B | open | | |
| gevoel-07 | Ernstig | A | klaar | F1 (tuning) en V (vliegen) enkel met CmdArgs.dev_mode() (debug-build of --dev) | ui_test op een release-export: F1 vrij, met --dev gebonden |
| gevoel-08 | Ernstig | D | open | | |
| gevoel-09 | Ernstig | B | open | | |
| gevoel-10 | Ernstig | B | open | | |
| gevoel-11 | Ernstig | B | open | | |
| gevoel-12 | Ernstig | D | open | | |
| gevoel-13 | Middel | C | open | | |
| gevoel-14 | Middel | C | open | | |
| gevoel-15 | Middel | B | open | | |
| gevoel-16 | Middel | B | open | | |
| gevoel-17 | Middel | C | open | | |
| gevoel-18 | Middel | C | open | | |
| gevoel-19 | Klein | B | open | | |
| gevoel-20 | Klein | C | open | | |
| buiten-1 | Blokkerend | C | open | | |
| buiten-2 | Ernstig | E | open | | |
| buiten-3 | Ernstig | E | open | | |
| buiten-4 | Ernstig | E | open | | |
| buiten-5 | Ernstig | C | open | | |
| buiten-6 | Ernstig | E | open | | |
| buiten-7 | Middel | E | open | | |
| buiten-8 | Middel | D | open | | |
| buiten-9 | Middel | E | open | | |
| buiten-10 | Middel | E | open | | |
| buiten-11 | Middel | E | open | | |
| buiten-12 | Middel | D | open | | |
| buiten-13 | Klein | C | open | | |
| buiten-14 | Klein | E | open | | |
| binnen-01 | Blokkerend | D | open | | |
| binnen-02 | Ernstig | D (+F1: boor T2) | open | | |
| binnen-03 | Ernstig | D | open | | |
| binnen-04 | Ernstig | B | open | | |
| binnen-05 | Ernstig | D | open | | |
| binnen-06 | Ernstig | D | open | | |
| binnen-07 | Middel | D | open | | |
| binnen-08 | Middel | D | open | | |
| binnen-09 | Middel | B | open | | |
| binnen-10 | Middel | B | open | | |
| binnen-11 | Middel | B | open | | |
| binnen-12 | Middel | A | open | | |
| binnen-13 | Middel | A | deels (Godot klaar, model bij A2) | Zie ui-02 | A1: na/interior_taxatie_* |
| binnen-14 | Middel | C | open | | |
| binnen-15 | Klein | C | open | | |
| binnen-16 | Klein | B | open | | |
| binnen-17 | Klein | A | open | | |
| binnen-18 | Klein | A | open | | |
| ui-01 | Blokkerend | A | open | | |
| ui-02 | Blokkerend | A | deels (Godot klaar, model bij A2) | Alle 'later/coming soon/M4/Playtest/T2-hint/Steam later' weg; werkbank, nissen, automaat, kast en band geven een DIG-regel zonder belofte; versielabel v0.9 | A1: na/interior_taxatie_*, na/menu.png |
| ui-03 | Ernstig | A (+F1: inhoud) | klaar (inhoud volgt in F1) | Contractbalie als DIG-console met drie werkorders (planeetbolletje, bijnaam, risicostempel, pay/magma, vak CONDITIONS voor F1); één bevestiging (SIGNED, COURSE SET); hologram = draadmodel van de planeet + claim | A1: firma_terminal, hud_menu_gekozen, interior_terminal_* |
| ui-04 | Ernstig | A | klaar | De bron geeft de soort mee (Mol.notice/Game.notice: mol/warn/alarm/contract); alarm = grote rode melding + rode gloed rond het scherm (HudAlarm); de rand pulseert bij beving en voorschok; de aftelling wordt rood bij noodophaling; dikkere onrustbalk | A1: hud_beving*, hud_noodophaling, hud_magma; magma_test op de soort |
| ui-05 | Ernstig | A | klaar | Alle HUD-tekst ≥ 18 px, toetsen 18–20 px; sonar in buitenzicht ×1,4 | ui_test controleert 57 HUD-labels; A1: na/720p_* |
| ui-06 | Ernstig | A | klaar | Zie gevoel-07 | ui_test op een release-export |
| ui-07 | Middel | A | deels (Godot klaar, bordjes CR/cents bij A2) | Stijlregels in lessons.md; UiTheme.cap/euro_signed/num/count; hoofdletters, 'the Mole', m, minteken, meervoud; dubbele Off weg; 'Missed = fine' herschreven | A1 |
| ui-08 | Middel | A | klaar | Rapport als papieren formulier rechts (DIG-kop, kosten rood met minteken, stempel APPROVED/QUOTA MET/MISSED); doel blijft zichtbaar; vervaagt; laatste dienst op het firmabord | A1 |
| ui-09 | Middel | A | klaar | Gele rand links aan elk HUD-element, eigen icoon per soort vondst (4 SVG's), CONDITION in palet-geel, info-icoon, kompasafstand op een plaatje, doel groter in crème | A1 |
| ui-10 | Middel | A | klaar | Laagchip donker met laagkleur als rand; bovenste laag per planeet CLAY/LIMESTONE/BASALT | A1: gezien op Kristalmaan |
| ui-11 | Middel | A | klaar | Aftelling met een getal van 124 px dat klopt bij elke tel; laatste drie rood met flits; ABOARD enkel in co-op | A1 |
| ui-12 | Middel | A | klaar | Eén gele hoofdknop, uitleg vast onder de knop met focus, camera's aangepast (Mol rechts bij JOIN) | A1: na/menu* |
| ui-13 | Middel | A | deels (Mol-schermen bij C) | Firmabord minder en grotere regels; kompas weg in de stoel. Schermtalen in de Mol, LAUNCH-label, QUIET/NOISY en CLAY op elke planeet doorgegeven aan C | A1 |
| ui-14 | Klein | A | klaar | Solo is INVITE een gewone knop; dubbele 'paused' weg; HUD verborgen met pauzemenu | A1 |
| ui-15 | Klein | A | klaar | Zichtbare scrollbalk, uitleg 18 px, hoofd-/pauzemenu weg zolang instellingen open | A1 |
| ui-16 | Klein | A | klaar | Draaiende boorkop + DIG SAFETY BRIEFING | A1: na/ui_laadscherm.png |
| ui-17 | Klein | A | klaar | Gebalanceerde koppen, ticker vernieuwd na een dienst, LIVE enkel op de kast, overal DIG NEWS, prijsetiket past | A1 |
| ui-18 | Klein | A | klaar | Donkere stempel met ruwe gele rand | A1: hud_stempel, drop_kristal_034 |
| ui-19 | Klein | A | klaar | Prompt 128 px onder het vizier | A1 |
