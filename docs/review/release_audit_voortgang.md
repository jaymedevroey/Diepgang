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
| ontwerp-11 | Middel | B | klaar (druk volgt met F2) | Houweel 4,9 s gaaf tegenover boor 1,1 s 87% / tikjes 90%; heet boren 2,2× schade | B: metingen |
| ontwerp-12 | Middel | D | deels (dreiging: F2) | Onstabiele zones ook in klei; toast 'The quake pushed the magma up X m'; haak local_knockdown voor neergaan | D |
| ontwerp-13 | Middel | B | klaar (erts als munt voor upgrades: F1) | Zie gevoel-16 | B |
| ontwerp-14 | Middel | C | open | | |
| ontwerp-15 | Middel | C | open | | |
| ontwerp-16 | Klein | B | klaar | Eerste vondst = een bot uit een rij die met de seed wisselt (4 soorten in 9 seeds) | find_test: nieuwe controle |
| gevoel-01 | Blokkerend | B | klaar | Optrekken 0,017 → 0,12 s, remmen 0,10 s; sprint (Shift, 6,8 m/s), hurken (Ctrl, 2,2 m/s); coyote-tijd en sprongbuffer; landingsdip + stof; head bob en kanteling met instelling. Open: anderen zien je niet hurken | B: feel_bench-metingen en films |
| gevoel-02 | Blokkerend | B | klaar | Physics-interpolatie aan; standaard uit op Main, aan voor wat per tick beweegt (speler, Mol, vondsten, steentjes); CamRig op de geïnterpoleerde plek; resets na elke sprong (Mol ook de tick erna). Open: vallende rotsen (D) en grijper (C) nog 60 Hz | Stilstaande beelden bij ±340 fps: lopen 246/300 → 1/300, piloot 225/300 → 1/300; drop_sequence --repeat 0 fouten |
| gevoel-03 | Blokkerend | B | klaar | Hit-stop 0,11 s bij de breuk; licht en sterretjes in de glans van de waardeklasse; brokken weg van de speler, stof 0,35 s later en laag; de vondst springt naar je toe met naam en waarde (in _reveal_text, voor F1) | B: korst_voor_na.png |
| gevoel-04 | Ernstig | C | open | | |
| gevoel-05 | Ernstig | C | open | | |
| gevoel-06 | Ernstig | B | klaar | Twee robothanden, veer (zwaarder = slapper, sleept na, kantelt), belicht als de handen; schade vanaf 3 m/s met plafond; '−€X' in de wereld; anderen zien de drager grimassen | B: na/carry_bot.png, na/film_carry.mp4 |
| gevoel-07 | Ernstig | A | klaar | F1 (tuning) en V (vliegen) enkel met CmdArgs.dev_mode() (debug-build of --dev) | ui_test op een release-export: F1 vrij, met --dev gebonden |
| gevoel-08 | Ernstig | D | klaar | Aanzwellende aankondiging, hoofdschok in 3 golven met traag rollen; camerarotatie hoofdschok 0,85° → 2,7° max, aankondiging 0,3° → 0,9°; in de Mol ×0,6. Open: buitenzicht Mol (C) | D: audit_under --only=schok |
| gevoel-09 | Ernstig | B | klaar | Zwaai als boog op het vizier, wisselanimatie 0,28 s, ademhaling in rust | B: zwaai_voor_na.png |
| gevoel-10 | Ernstig | B | klaar | Vonken uitgerekt langs hun snelheid, kegel rond de normaal, onzichtbaar < 0,6 m van de camera | B: vonken_voor_na.png, graniet_voor_na.png |
| gevoel-11 | Ernstig | B | klaar | Boor in klei 2,6 → 5,0 m in 3 s (±2,4× houweel), zandsteen 1,8 m en heter; houweel ketst op zandsteen (GDD-tabel); boor bijt op vast ritme in speltijd | B: metingen feel_bench |
| gevoel-12 | Ernstig | D | klaar | heat_m werkt: rode kloppende rand, schudden, alarm; smelten 1,5 s (wit-oranje, zwart, vervanger), gensters voor anderen, signaal melting | magma_test aangepast; D: magma.avi |
| gevoel-13 | Middel | C | open | | |
| gevoel-14 | Middel | C | open | | |
| gevoel-15 | Middel | B | klaar | Bit en kop gloeien met de hitte, stoom en hangende boor bij oververhitting; boor schuift naar voren bij contact, bereik 2,3 m | B: boor_voor_na.png |
| gevoel-16 | Middel | B | klaar | Tik met fonkels en '+1 Copper' per slag; storten: brokjes in de trechter, gerammel, '+€X'; clusters 2–3 eenheden; waarden in ore.cfg (8/12/20/32); zak van 30 | B: films |
| gevoel-17 | Middel | C | open | | |
| gevoel-18 | Middel | C | open | | |
| gevoel-19 | Klein | B | klaar | Zie binnen-09 | D: blad_na_merge |
| gevoel-20 | Klein | C | open | | |
| buiten-1 | Blokkerend | C | open | | |
| buiten-2 | Ernstig | E | open | | |
| buiten-3 | Ernstig | E | open | | |
| buiten-4 | Ernstig | E | open | | |
| buiten-5 | Ernstig | C | open | | |
| buiten-6 | Ernstig | E | open | | |
| buiten-7 | Middel | E | open | | |
| buiten-8 | Middel | D | klaar | Rotsblokken als veelvlak met vorm per planeet (gehakt, krijtblok, basaltzuil), in groepjes | D: blad_oppervlak |
| buiten-9 | Middel | E | open | | |
| buiten-10 | Middel | E | open | | |
| buiten-11 | Middel | E | open | | |
| buiten-12 | Middel | D | deels | Grondpatroon per planeet (windribbels, krijtplaten en gruis, glinsters op zeshoeken), geen craquelé meer; rotsgroepen om de ±60 m. Open: palen, kisten, botten in het middenplan (E) | D: blad_oppervlak |
| buiten-13 | Klein | C | open | | |
| buiten-14 | Klein | E | open | | |
| binnen-01 | Blokkerend | D | klaar (ter goedkeuring: lamp, decor) | Klei gevlekt en fijn gelaagd met merklagen om de ±8 m; gloeiende knollen; CaveDecor (zwammen/kristallen, ≤2 lampjes per grot, druipsteen); grotvormen in de SDF; helmlamp warm wit i.p.v. amber; koele schaduwen onder de grond. Open: rommel van vorige ploegen, flare; Mol-koplampen nog amber (C) | D: blad_lagen_p0, blad_grotten, blad_mol |
| binnen-02 | Ernstig | D (+F1: boor T2) | deels (bereikbaar met T2: F1) | Zandsteen met scheve gelaagdheid en ijzerband, graniet koel en blokkig, kristallaag met zeskantige kristallen en lichtgevende clusters | D: blad_lagen_* |
| binnen-03 | Ernstig | D | klaar | Verkleuring rond erts (koper groen-turkoois, ijzer roestzwart), glinsters ±10 cm die nooit onder enkele pixels zakken en oplichten bij kijken, naalden in alle richtingen | D: blad_erts |
| binnen-04 | Ernstig | B | klaar (ter goedkeuring) | Korst = gefacetteerde knol met kleur per laag en hint per familie (botten steken uit), krimpt per slag | B: na/korsten.png |
| binnen-05 | Ernstig | D | klaar | Gehakte rotsen met botsvorm en interpolatie, stofsliert en -wolk, stofwaas bij de hoofdschok, steentjes, haperende lamp; haken voor geluid | D: blad_beving, na/beving_sheet, beving.avi |
| binnen-06 | Ernstig | D | klaar (ter goedkeuring) | Magma als raster met reliëf rond de camera (deining, platen, bellen), open lava naast korst met barsten, rook, flakkerende lamp, trillende lucht. Open: vonkenfonteinen | D: blad_magma, magma.avi |
| binnen-07 | Middel | D | klaar | Geen barstjes/naadlijnen meer onder de grond, gruis op vloeren; korst enkel de bovenste meter | D |
| binnen-08 | Middel | D | klaar (ter goedkeuring: paletten) | Underground: palet en patroon per planeet en laag (Fossielwereld krijt/vuursteen/mergel/botbedden, Kristalmaan violette as/obsidiaan/roze insluitsels); stof, puin, zwammen in planeetkleur. Open: puinvorm per planeet | D: blad_planeten |
| binnen-09 | Middel | B | klaar | B: decal en stof; D: verse snede in de terreinshader (donkerder, vochtig, zonder stof, diepere holtes, breukrand; ook bij anderen; dooft in 35 s) | D: blad_hakken, blad_na_merge |
| binnen-10 | Middel | B | klaar | Zie gevoel-06 | B: na/carry_bot.png |
| binnen-11 | Middel | B | klaar (ter goedkeuring) | Nieuwe gelede robothand (Glove/Glove_Open) met korte donkere onderarm; referentiestudie DRG/Lethal Company/R.E.P.O. | B: blender/* |
| binnen-12 | Middel | A | deels | Eigen hub-shader (slijtage, vuil, strepen, krassen, roet), decals (voetsporen, olie, koffie), licht per zone (warm/tl/koud/natrium), reflectieprobes en nevel. Open: de Mol is nog schoon (C), mid-range niet gemeten | A2: binnen-12/, route/ |
| binnen-13 | Middel | A | klaar | Zie ui-02 | A1 + A2 |
| binnen-14 | Middel | C | open | | |
| binnen-15 | Klein | C | open | | |
| binnen-16 | Klein | B | klaar (ter goedkeuring) | Nieuwe schedel en dikkere rib; randlicht en fonkels per waardeklasse | B: blender/skull_*, na/vondsten.png |
| binnen-17 | Klein | A | klaar | Taxatiepoort slanker, APPRAISAL op masten boven de poort; verkoopluik met raam en verlicht kantoortje | A2: binnen-17/ |
| binnen-18 | Klein | A | klaar | MIND THE STEPS leesbaar vanaf de spawn; TO THE MOLE / TO THE BRIDGE met eigen pijl | A2: binnen-18/ |
| ui-01 | Blokkerend | A | klaar | Oorzaak: de kop van de middenbalk hing voor het bord; balk korter, bord lager en naar voren; alle 279 opschriften van voren gefotografeerd, geen enkel nog bedekt | A2: ui-01/, ui-01/alle_borden/ |
| ui-02 | Blokkerend | A | klaar | Godot (A1) en model (A2): geen ontwikkelaarstaal meer; nissen worden HUMAN RESOURCES en BREAK ROOM | A1 + A2 |
| ui-03 | Ernstig | A (+F1: inhoud) | klaar (inhoud volgt in F1) | Contractbalie als DIG-console met drie werkorders (planeetbolletje, bijnaam, risicostempel, pay/magma, vak CONDITIONS voor F1); één bevestiging (SIGNED, COURSE SET); hologram = draadmodel van de planeet + claim | A1: firma_terminal, hud_menu_gekozen, interior_terminal_* |
| ui-04 | Ernstig | A | klaar | De bron geeft de soort mee (Mol.notice/Game.notice: mol/warn/alarm/contract); alarm = grote rode melding + rode gloed rond het scherm (HudAlarm); de rand pulseert bij beving en voorschok; de aftelling wordt rood bij noodophaling; dikkere onrustbalk | A1: hud_beving*, hud_noodophaling, hud_magma; magma_test op de soort |
| ui-05 | Ernstig | A | klaar | Alle HUD-tekst ≥ 18 px, toetsen 18–20 px; sonar in buitenzicht ×1,4 | ui_test controleert 57 HUD-labels; A1: na/720p_* |
| ui-06 | Ernstig | A | klaar | Zie gevoel-07 | ui_test op een release-export |
| ui-07 | Middel | A | klaar | Godot (A1) en bordjes (A2): CR/cents → € | A1 + A2 |
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
