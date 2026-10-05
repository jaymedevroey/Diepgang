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
| ontwerp-6 | Ernstig | C | deels (handscanner: F1) | Opgeschepte vondsten kapot (5%), autopiloot nooit sneller dan zelf boren, brandstof voor 600 m boren per dienst | C |
| ontwerp-7 | Ernstig | F2 | open | | |
| ontwerp-8 | Ernstig | F2 | open | | |
| ontwerp-9 | Ernstig | F1 | open | | |
| ontwerp-10 | Ernstig | F1 | open | | |
| ontwerp-11 | Middel | B | klaar (druk volgt met F2) | Houweel 4,9 s gaaf tegenover boor 1,1 s 87% / tikjes 90%; heet boren 2,2× schade | B: metingen |
| ontwerp-12 | Middel | D | deels (dreiging: F2) | Onstabiele zones ook in klei; toast 'The quake pushed the magma up X m'; haak local_knockdown voor neergaan | D |
| ontwerp-13 | Middel | B | klaar (erts als munt voor upgrades: F1) | Zie gevoel-16 | B |
| ontwerp-14 | Middel | C | klaar | 4 PINGs per dienst, onrust 12 (was 5) | sonar_test |
| ontwerp-15 | Middel | C | klaar | Autopilootknoppen per laag: CLAY (−25 m), SAND (bovenkant zandsteen + 8 m), DEEP (25 m boven graniet), per wereld berekend | mol_test |
| ontwerp-16 | Klein | B | klaar | Eerste vondst = een bot uit een rij die met de seed wisselt (4 soorten in 9 seeds) | find_test: nieuwe controle |
| gevoel-01 | Blokkerend | B | klaar | Optrekken 0,017 → 0,12 s, remmen 0,10 s; sprint (Shift, 6,8 m/s), hurken (Ctrl, 2,2 m/s); coyote-tijd en sprongbuffer; landingsdip + stof; head bob en kanteling met instelling. Open: anderen zien je niet hurken | B: feel_bench-metingen en films |
| gevoel-02 | Blokkerend | B | klaar | Physics-interpolatie aan; standaard uit op Main, aan voor wat per tick beweegt (speler, Mol, vondsten, steentjes); CamRig op de geïnterpoleerde plek; resets na elke sprong (Mol ook de tick erna). Open: vallende rotsen (D) en grijper (C) nog 60 Hz | Stilstaande beelden bij ±340 fps: lopen 246/300 → 1/300, piloot 225/300 → 1/300; drop_sequence --repeat 0 fouten |
| gevoel-03 | Blokkerend | B | klaar | Hit-stop 0,11 s bij de breuk; licht en sterretjes in de glans van de waardeklasse; brokken weg van de speler, stof 0,35 s later en laag; de vondst springt naar je toe met naam en waarde (in _reveal_text, voor F1) | B: korst_voor_na.png |
| gevoel-04 | Ernstig | C | klaar | GDD-snelheid (1,3 m/s boren, 1,8 rijden) met hoekversnelling; hendel vol na 33 ms; dreun in de cabine (sterker bij boren), helling tot 1,7° / −3,6°; buitenzicht schokt mee; boorpuin achteraan | C: meting_mol_na.csv |
| gevoel-05 | Ernstig | C | klaar | Grijper zakt al tijdens het aftellen (nog 2,5 s i.p.v. 10,4), optrekken 13 s i.p.v. 17,8; ophalen 38 → ±26 s; vrij rondlopen en -kijken; schok bij vastklikken, duw bij optrekken | C: buiten5_ophalen_roestbol_voor_na.png |
| gevoel-06 | Ernstig | B | klaar | Twee robothanden, veer (zwaarder = slapper, sleept na, kantelt), belicht als de handen; schade vanaf 3 m/s met plafond; '−€X' in de wereld; anderen zien de drager grimassen | B: na/carry_bot.png, na/film_carry.mp4 |
| gevoel-07 | Ernstig | A | klaar | F1 (tuning) en V (vliegen) enkel met CmdArgs.dev_mode() (debug-build of --dev) | ui_test op een release-export: F1 vrij, met --dev gebonden |
| gevoel-08 | Ernstig | D | klaar | Aanzwellende aankondiging, hoofdschok in 3 golven met traag rollen; camerarotatie hoofdschok 0,85° → 2,7° max, aankondiging 0,3° → 0,9°; in de Mol ×0,6. Open: buitenzicht Mol (C) | D: audit_under --only=schok |
| gevoel-09 | Ernstig | B | klaar | Zwaai als boog op het vizier, wisselanimatie 0,28 s, ademhaling in rust | B: zwaai_voor_na.png |
| gevoel-10 | Ernstig | B | klaar | Vonken uitgerekt langs hun snelheid, kegel rond de normaal, onzichtbaar < 0,6 m van de camera | B: vonken_voor_na.png, graniet_voor_na.png |
| gevoel-11 | Ernstig | B | klaar | Boor in klei 2,6 → 5,0 m in 3 s (±2,4× houweel), zandsteen 1,8 m en heter; houweel ketst op zandsteen (GDD-tabel); boor bijt op vast ritme in speltijd | B: metingen feel_bench |
| gevoel-12 | Ernstig | D | klaar | heat_m werkt: rode kloppende rand, schudden, alarm; smelten 1,5 s (wit-oranje, zwart, vervanger), gensters voor anderen, signaal melting | magma_test aangepast; D: magma.avi |
| gevoel-13 | Middel | C | klaar | PING: groene puls in de cabine, plaatshouder-echo; te vroeg of op: klik en knipperend scherm | sonar_test |
| gevoel-14 | Middel | C | klaar | De piloot blijft zitten bij de hendel; de hendel gaat zichtbaar over | C: film/mol_na_*.png |
| gevoel-15 | Middel | B | klaar | Bit en kop gloeien met de hitte, stoom en hangende boor bij oververhitting; boor schuift naar voren bij contact, bereik 2,3 m | B: boor_voor_na.png |
| gevoel-16 | Middel | B | klaar | Tik met fonkels en '+1 Copper' per slag; storten: brokjes in de trechter, gerammel, '+€X'; clusters 2–3 eenheden; waarden in ore.cfg (8/12/20/32); zak van 30 | B: films |
| gevoel-17 | Middel | C | klaar | Landen aan 7 m/s met diepere vering, nog 0,22 s buiten na de klap, dan knip met flits en schok; grotere vlammen, warmtetrilling, meer stof en brokken. Open: stofring van achter nog bescheiden | C: film/landing_na_klap.png |
| gevoel-18 | Middel | C | klaar | Autopiloot rekent zes spiralen na en kiest er een zonder vondst; meldingen samengevoegd | C: film/afdalen_na.mp4 |
| gevoel-19 | Klein | B | klaar | Zie binnen-09 | D: blad_na_merge |
| gevoel-20 | Klein | C | klaar | In- en uitstappen houden de kijkrichting en glijden in 0,3 s met een boogje | C: film/mol_na_*.png |
| buiten-1 | Blokkerend | C | klaar | Volgshot hoog 17° en lager 30° omlaag, traag rollen en inhalen: kim, wand en landmark de hele val in beeld | C: buiten1_drop_roestbol_voor_na.png, na_C_na_*_drop1_op.png |
| buiten-2 | Ernstig | E | klaar | Oorzaak: buitenmuur stak 0,8–1,2 m boven het oppervlak + verre landschap 0,5 m lager; muur nu enkel onder het oppervlak, landschap op exact dezelfde hoogte, naadstrook van ±1 m, rok op de rand van de strook | E: cmp_rand_*.png; sky_preview --horizon 0 fouten |
| buiten-3 | Ernstig | E | deels (ter goedkeuring: badlands in het speelgebied) | Lage badlands (3,2 m) ook op de kalkbodem en in het speelgebied, okerkleurige geulbodems, reliëftint; zon 1,35 → 1,18, vullicht 0,4 → 0,21; op 259 m IQR 3,7 → 8,4, licht 74% → 14%. Open: concept IQR 22,6 | E: meting_voor/na.txt |
| buiten-4 | Ernstig | E | deels | Blauwe krans zichtbaar, reus blauwgrijs en ondoorzichtig, minder mist, donker basalt in laagtes; middentoon 87% → 53%, IQR 6,0 → 8,4. Open: grond blijft één tint | E: meting_voor/na.txt |
| buiten-5 | Ernstig | C | klaar | Zie gevoel-05; kraanshot met de reus erachter tot in de baai, knip in het zwart, dikkere kabel. Open: licht door de patrijspoort | C: na_*_terug*.png |
| buiten-6 | Ernstig | E | klaar | Korstplaten met afschuining in de rotsshader, stralen als zachte linten, kristallen met fresnel, cyane gloed en fonkels | E: cmp_finaal_kristalmaan.png |
| buiten-7 | Middel | E | deels | Cellen gesplitst langs de hoogtelijn (geen zaagtand), lagen op Fossielwereld pas vanaf ±35°. Open: buttes zacht, kraterwand van dichtbij gefacetteerd | E: cmp_wand.png |
| buiten-8 | Middel | D | klaar | Rotsblokken als veelvlak met vorm per planeet (gehakt, krijtblok, basaltzuil), in groepjes | D: blad_oppervlak |
| buiten-9 | Middel | E | klaar | Reus achter minder waas (per planeet), lichtrand; ringprofiel met banden, opening en stofring | E: reus1__.png, cmp_na5_rb_km.png |
| buiten-10 | Middel | E | deels (ter goedkeuring) | Stuwgloed uit 8 motoren en 4 hefstralen, navigatielichten met halo's, flitser, buiklichten, containers in paletkleuren, gele band, slijtage; silhouet ongewijzigd. Open: vlakke rompplaten | E: cmp_schip.png |
| buiten-11 | Middel | E | klaar | Planeetdek onder de hub toont de echte planeet (gebakken kaarten ±496 m en ±4 km, plus ader en skelet) | E: cmp_hub2_*.png |
| buiten-12 | Middel | D | deels | Grondpatroon per planeet (windribbels, krijtplaten en gruis, glinsters op zeshoeken), geen craquelé meer; rotsgroepen om de ±60 m. Open: palen, kisten, botten in het middenplan (E) | D: blad_oppervlak |
| buiten-13 | Klein | C | klaar | Strepen dikker, korter, zacht, in de waaskleur, enkel aan de zijranden | C |
| buiten-14 | Klein | E | klaar | Mistvlak blijft vlak en dooft uit, zachte aanzet, minder dekking | E |
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
| binnen-14 | Middel | C | klaar (ter goedkeuring) | Grijsgroene wanden, donkere band, lampjesslinger, bureaulamp, briefjes, stickers, vuil; licht in plassen | C: binnen14_15_voor_na.png |
| binnen-15 | Klein | C | klaar (ter goedkeuring) | Trechtermond met rooster, geel-zwarte rand, bord ORE met pijl, gemorst erts; buiten de looproute | C: binnen14_15_voor_na.png |
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
| ui-13 | Middel | A | klaar | A1: firmabord, kompas. C: één schermtaal in de cabine, LAUNCH geel op zwart, QUIET: SHARP / NOISY: BLURRY, laagnaam per planeet | C: c_schermen_*.png, c_launch_*.png |
| ui-14 | Klein | A | klaar | Solo is INVITE een gewone knop; dubbele 'paused' weg; HUD verborgen met pauzemenu | A1 |
| ui-15 | Klein | A | klaar | Zichtbare scrollbalk, uitleg 18 px, hoofd-/pauzemenu weg zolang instellingen open | A1 |
| ui-16 | Klein | A | klaar | Draaiende boorkop + DIG SAFETY BRIEFING | A1: na/ui_laadscherm.png |
| ui-17 | Klein | A | klaar | Gebalanceerde koppen, ticker vernieuwd na een dienst, LIVE enkel op de kast, overal DIG NEWS, prijsetiket past | A1 |
| ui-18 | Klein | A | klaar | Donkere stempel met ruwe gele rand | A1: hud_stempel, drop_kristal_034 |
| ui-19 | Klein | A | klaar | Prompt 128 px onder het vizier | A1 |
