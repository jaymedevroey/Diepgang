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
| ontwerp-1 | G1 | klaar (niet met echte invoer gespeeld) | Gevaar voor de spelers zelf midden in de dienst: grijpen, rondsluipen, doorbreken | threat_test (99), net_threat_test (29) |
| ontwerp-7 | G1 | klaar (standhouden aan de oppervlakte niet gedaan) | Een baken in een rijdende Mol telt niet; de ram is een beet die duurt (2,5%/s per vondst, max 5 s, Mol aan 55%); de piloot schudt hem los (4× links-rechts); G gooit een baken door de achterklep; aan de oppervlakte sla je hem van de Mol | worm_balance: terugrit zonder iets −13/−38/−63%, met een ploeg die iets doet −5/−18/−23% |
| ontwerp2-1 | G1 | klaar | Midden in de dienst duwt de worm de Mol hooguit (Mol valt stil, wie staat gaat omver, lading heel), daarna 40 s doof voor de Mol en 60 s geen duw; rijden lokt minder (0,6 → 0,3) | worm_balance: 120 s rijden voor 8× geraakt en −75% lading, na 2× en 0% |
| ontwerp2-2 | G1 | klaar | Hij grijpt wie hij raakt; breekt na lang boorlawaai door een smalle gangwand (houweel blijft stil); sluipt onder wie 5 s binnen 9 m blijft; gas ook ondiep (22 m) en bij de landing (35% binnen 70 m); instortingen ×2,5 dicht bij een speler | worm_balance --only=gas: bellen binnen bereik 0–1 → 1–5 |
| ontwerp2-3 | G1 | klaar | Zie ontwerp-7: één baken zet de climax niet meer uit | worm_balance |
| binnen2-01 | G1 | klaar | De lip van de kop stopt tegen de romp op de flank (zichtbaar in het volgshot) en trekt terug de grond in | threat_test (vier kanten en beet); G1: film |
| binnen2-02 | G1 | klaar (ter goedkeuring: model) | Nieuw model: drie flappen, vlezige muil met drie kransen tanden en tongen, gloed diep in de keel, gloeiende naden en stippen, bleke buik; uitval met 1,6 s waarschuwing (rots barst open en gloeit), kegel scherven, kop komt traag uit de rots | G1: voor_na_*.png, films |
| gevoel2-05 | G1 | deels | Model slaat opzij en kantelt, cabinecamera helt en schokt, lichten haperen, vonken. Open: de zijwaartse ruk leest weinig in stilstaand beeld; de schok van binnen niet gefilmd | G1: voor_na_*.png |
| gevoel2-07 | G1 | klaar | Baken als fakkel: worp met de linkerhand, 18 m licht met vonken, gloeiende ring op de vloer zo groot als de veilige zone (14 m), sputtert de laatste 8 s | G1: films |
| ui2-05 | G1 | klaar (ter goedkeuring: naam) | Eén naam: the Gulper; rood-oranje op de sonar met eigen teken, bovenaan dichtbij ('! GULPER 4 m · ATTACKING'); HUD-rij met icoon; rode gloed rond het scherm. Open: merkteken op het kompas | G1: beelden |
| gevoel2-01 | G2 | klaar (beeld; geluid apart) | Beving: haperende helmlamp (bug: de lamp van de lokale speler werd niet gevonden), gruis vóór je, rotsen in beeld; instorting 2,2 s aanzwellende waarschuwing; gas: gele schermrand in de bel, lont 0,9 s met vonken en gloed; geluidshaken fuse_lit, rubble_chipped, ImpactFx.hit (de worm: G1) | G2: voor_na/*.png (impact_film) |
| gevoel2-02 | G2 | klaar | Klapmoment: 0,14 s stilstand, flits in de kleur van de bron, FOV-stoot, dan glijden naar een volgcamera die nooit in je robot, een maat of de wand zit; vast punt in de Mol; gedragen schuin opzij; opstaan in de kijkrichting | G2: voor_na/*.png |
| binnen2-03 | G2 | klaar | Zie gevoel2-02; gegrepen door de worm staat de camera vóór de muil. Open: ±0,1 s door het lijf van de worm (geen botsvorm) | G2: take grabbed, lunge voor/na |
| gevoel2-03 | G2 | klaar | Twee handgrepen, de vondst spant tussen de dragers; touw = afstand tussen de grepen plus armen (3,0 m i.p.v. 4,9) | net_test (Carry.team_limit) |
| gevoel2-06 | G2 | klaar (ter goedkeuring: draagstand) | Alleen hou je je maat vóór je met zijn gezicht naar jou, benen slepen met stof; met twee ligt hij tussen jullie | G2: voor_na |
| binnen2-07 | G2 | klaar | Handen op de greep, armen van de maat reiken ernaar (RobotRig.reach); scanner 7 cm hoger met hand zichtbaar | G2: voor_na |
| binnen-10 | G2 | klaar | Een vondst in je handen houdt een rand van licht | G2: voor_na |
| gevoel2-08 | G2 | klaar | Glazen scherven, lichtflits, 'SHATTERED' en '−58%' groot, schok | G2: voor_na |
| gevoel2-09 | G2 | deels | Puin met de korst-shader in de laagkleur: barst, krimpt, schudt per slag, valt in brokken. Open: zandsteenpuin onder de helmlamp blijft licht | G2: voor_na |
| binnen2-04 | G2 | deels | Zie gevoel2-09 | G2: voor_na |
| gevoel2-10 | G2 | klaar | Ontploffing eerst uit eigen ogen (flits), grotere vuurbal, rook die blijft hangen, stofgolf | G2: voor_na |
| ui2-02 | G2 | klaar | Mist en stof doven uit voor de camera; GAS op een HUD-plaatje van G6; gele schermrand | G2: voor_na |
| ui2-03 | G2 | klaar | ROBOT BROKEN 4 s, daarna een zoeker met REC, de ploeg en toetsen uit de bindings (ZQSD op AZERTY); geen dubbele melding | G2: voor_na |
| ui2-15 | G2 | klaar | Solo: 'Nobody to carry you · rebooting' | G2 |
| gevoel-08 | G2 | klaar | Zie gevoel2-01; geen beige waas meer | G2: voor_na |
| gevoel-19 | G2 | deels | Verse kuil in een donkere versie van de laagkleur. Open: bleke klei uit de terreinshader | G2 |
| binnen-05 | G2 | klaar | Zie gevoel2-01 | G2: voor_na |
| gevoel2-13 | G2 | klaar | 'Too low to stand up' en je schuift vanzelf naar een plek met ruimte | headless: recht na het loslaten |
| gevoel2-14 | G2 | klaar | Onderste regel van de scanner in beeld op 1080p | G2 |
| gevoel2-15 | G2 | klaar | Geen witte schijven meer voor de camera | G2 |
| gevoel2-16 | G2 | klaar | Sprint: FOV +7° (80 → 87), langere en hogere passen, kantelen in de bocht; uit met Head bob | G2: feel_bench |
| ontwerp-8 | G2 | deels (ter goedkeuring: loonzak, reuzengeode) | F3: zware stukken met twee, zijscan. G2: zware stukken op elke planeet (loonzak in kampen op Roestbol, reuzengeode op Kristalmaan); een maat dragen en redden (F2/G2). Open: zijscan enkel als de Mol rijdt | find_test |
| ui2-01 | G3 | klaar | Geen zwevende tekst meer; groot podiumscherm boven de poort (soort, gaafheid als stempel, oplopende teller, doelbonus/skelet 3/5, quotabalk); scherm op het luik telt per stuk op; één verkoopmelding | G3: vergelijk_poort, vergelijk_luik, g3_ceremonie.mp4 |
| gevoel2-04 | G3 | klaar | Wie zelf draagt krijgt de onthulling boven het vizier (HudReveal); aan het luik gaan de stukken één voor één het luik in, teller op ooghoogte, quotabalk vult, stempel QUOTA MET; geluidshaken via Appraisal.cue | G3: g3_ceremonie.mp4 |
| binnen2-10 | G3 | klaar | De poort doet zelf iets: lopende band, scanstraal over het stuk, lichtstroken wit/goud/fel goud per waardeklasse, regenboog bij een compleet skelet, lamp kleurt het stuk | G3: vergelijk_poort |
| binnen2-11 | G3 | klaar (ter goedkeuring) | Zichtbare upgrades: gouden tanden op de boorkop, bagagebakken op de flanken, boor T2 oranje met gouden punt, helmlamp T2 zichtbaar bij anderen; Mol-werf met boorkop en bagagebak op een bok met prijskaartje, daarna INSTALLED ON THE MOLE | G3: vergelijk_upgrades_hub |
| ui2-11 | G3 | klaar | Winkelkaarten met het echte model, draaiend; boor T2 op het schaduwbord met prijskaartje (daarna ISSUED TO CREW); pakje schuift over de uitgiftebalie | G3: vergelijk_winkel |
| ui2-12 | G3 | klaar | Statusscherm in de Mol: HAUL-bandbreedte en HOLD-balk; laadmeter boven de klep (rood bij te zwaar); melding bij het inladen; quota linksboven in hub en Mol | G3: vergelijk_veld |
| ontwerp2-4 | G3 | klaar | Draagkaartje en prompt tonen kg en een bandbreedte ('€460–800 ESTIMATE') waar de echte waarde altijd in valt; exacte prijs aan de poort | economy_test controleert de bandbreedte voor elke vondst |
| ontwerp2-5 | G3 | klaar | Risicolabel = planeet (Roestbol 0, Fossielwereld 1, Kristalmaan 2) + voorwaarden; Kristalmaan nooit LOW, Roestbol nooit HIGH; regel per kaart over worm en gas; kaarten van veilig naar gevaarlijk | economy_test |
| ontwerp2-6 | G3 | klaar | Laadruim groeit met de ploeg (60/80/100/120 kg, upgrade +80); draagkaartje zegt of een Titanset past; solo enkel met de upgrade (bewust, en het spel zegt het) | economy_test |
| ontwerp2-9 | G3 | klaar | Een band van de klep van de Mol door de poort naar het luik (host zet de snelheid, stopt onder de scanner). Open: nog 2–4 m dragen van het laadruim naar de band | net_economy_test: vondst rijdt van de klep tot in de poort, ook bij de client |
| ontwerp2-10 | G3 | deels | Upgrades ×1,5 (solo samen €15.600 i.p.v. €10.400); de automaat verkoopt pakken van 2 lichtbakens. Open: geen nieuwe upgrade-niveaus, tempo niet gemeten | economy_test |
| ontwerp2-11 | G3 | klaar | Proeftijd sluit de veiligste kaart, niet de rijkste | economy_test |
| ontwerp-3 | G3 | deels (niet gespeeld) | Quotabasis €6.000 (solo €2.400 in kwartaal 1); quota en buitschatting zichtbaar | economy_test |
| ontwerp-10 | G3 | klaar | Het label zegt wat de planeet vraagt (planeet en risico apart kiezen niet gebouwd) | economy_test |
| ui-03 | G3 | klaar | Hologram = kaart van de drie opdrachten, de gekozen planeet groot naar voren met haar voorwaarden; DIG-amber op een dichte plaat, '+35%' | G3: vergelijk_hologram |
| ui2-14 | G3 | klaar | Eigen planeetbeeld op de kaarten (kloof en kraters, ribbenkast, kristalpieken en facetten) | G3: vergelijk_kaarten |
| buiten-3 | G4 | deels | Grijsblauwe geulbodems, lagen in de hellingen, barsten in de laagtes; drop-IQR 16,3 (was 9–14). Op ooghoogte nog bleek | G4: metingen.txt |
| buiten-4 | G4 | deels | Rustbowl lichter (L* 22 → 36), violet basalt in laagtes, perzik op ruggen, donkere stenen; drop-IQR 17,8. Blijft één oranje tint | G4: metingen.txt |
| buiten-5 | G4 | klaar | Buitenbeeld start bij het zakken van de grijper, lichtbundel volgt de grijper, kraanshot op de grond met de reus, laatste stuk schip boven in beeld | G4: film ophalen |
| buiten-6 | G4 | klaar | Kristallen met cyane kern die door het glas gloeit, minder witte glans | G4: voor_na/ |
| buiten-7 | G4 | deels | Buttes met overhangende kaprots, erosiegroeven en puinhelling. Open: lagen nog regelmatig, zaagtand kraterwand Rustbowl en richels van de klif | G4: voor_na/ |
| buiten-8 | G4 | deels | Rotsen in het speelgebied met eigen kleur per planeet en scherpere vlakken. Open: voxelvorm (koepels op Rustbowl) in de generator | G4: voor_na/ |
| buiten-9 | G4 | klaar | Reus van Crystal Moon met banden en brede lichte kant, verder van de zon, minder waas | G4: voor_na/ |
| buiten-10 | G4 | deels | Roetstrepen langs de stroming, halo's rond ±136 loop- en buiklichten. Open: massa's blijven dozen | G4: voor_na/ |
| buiten-12 | G4 | klaar (ter goedkeuring) | Containers en brandstoftank i.p.v. meetpaaltjes, ring van 5 grote groepen op 40–64 m, grotere stenen; gecomponeerde landingsplek (kamp bij de oude gang op Rustbowl, opgraving op Fossil World, neergestorte sonde op Crystal Moon) | G4: voor_na/ |
| buiten-14 | G4 | klaar | Geen mist meer in de kloven en op de puinhelling; van boven dunner met zachtere rand | G4: voor_na/ |
| buiten2-1 | G4 | deels | Geen veelhoekplaten, zebrastrepen of vlekkenruis meer; laagtes en ruggen met eigen kleur, zandvlakken, kiezels, gruis, brandvlek op de landingsplek; GroundScatter tot ±34 m. IQR op ooghoogte ±verdubbeld (Rustbowl 4,3 → 7,7, Fossil 6,6 → 8,9, Crystal 4,4 → 8,0), concept 22–24 | G4: metingen.txt, voor_na/ |
| buiten2-2 | G4 | klaar | Val in plannen: hoog volgshot met de reus (±1,3 s vast beeld), stoflaag op 110–210 m, knip naar de flank bij het ontsteken, grondcamera de laatste 26 m; beeldverschil hoge fase 7,8 → 12,1 | G4: film drop |
| buiten2-3 | G4 | klaar | Zie buiten-5 | G4: film ophalen |
| buiten2-4 | G4 | deels | Zie buiten-7 | G4: voor_na/ |
| buiten2-5 | G4 | klaar (ter goedkeuring) | Stof op de Mol in de grondkleur van de planeet, zachte gradiënt van onder, geen druppellijnen, half zoveel spikkels | G4: voor_na/ |
| buiten2-6 | G4 | klaar | Zie buiten-12 | G4: voor_na/ |
| buiten2-7 | G4 | klaar | Klap van buiten zichtbaar: stofgolf naar de camera, brokken, stoot, 0,9 s buiten (was 0,22 s) | G4: film drop |
| buiten2-8 | G4 | klaar | Kortere vlammen met kleurverloop en schokdiamanten | G4: film drop |
| buiten2-9 | G4 | deels | Scheuren en zaagtand niet meer gezien met het voxelterrein geladen. Open: lichte strook van buiten de rand op Fossil World | G4 |
| gevoel-17 | G4 | klaar | Zie buiten2-7 | G4: film drop |
| gevoel2-11 | G4 | klaar | Zie buiten2-2 | G4: film drop |
| gevoel2-12 | G4 | klaar | Zie buiten2-7; het belletje van de overdracht wacht op de knip naar binnen | G4: film drop |
| binnen-01 | G5 | deels (veel beter; ter goedkeuring) | Set pieces uit de seed in ±1 op 3 grotten, de 2 dichtste kleigrotten altijd (DIG-kamp, oude Mol, reuzenribbenkast, geodekamer) met goede buit; startgrot ±60 m van het midden met de oude toegangstunnel van de vorige ploeg (werklamp en bord zichtbaar van de landingsplek). Open: buitenbeeld van de Mol ondergronds nog een bruine buis; eerste 70 m nog warm | G5: na_gang_naar_startgrot.png, na_set_pieces.png |
| binnen-03 | G5 | klaar (ter goedkeuring: koper turkoois) | Erts als donkere knol van ±0,7 m met kristalnaalden in alle richtingen en klompjes blank metaal; koper turkoois tegen rode klei; glinsters als harde facetjes | G5: vergelijk_erts |
| binnen-04 | G5 | klaar (ter goedkeuring) | Korst als concretie per planeet en laag (ijzersteen met calcietaders, zwarte vuursteen met witte korst, obsidiaan met roze aders), gefacetteerd, barsten die de vondst tonen en groeien met schade | G5: vergelijk_korst |
| binnen-06 | G5 | deels | Rivieren van open lava, celpatroon vervaagt met de afstand, afgekoelde schilfers. Open: geen stromend front, geen vonkenfonteinen | G5: vergelijk_magma |
| binnen-08 | G5 | deels | Per planeet: graniet als gneisbanden (Fossielwereld) of basalt met zuilen (Kristalmaan), botbedden, zeshoekige insluitsels, eigen decor en set pieces. Open: vormen van gangen en grotten nog gelijk | G5: vergelijk_lagen, vergelijk_grotten |
| binnen2-05 | G5 | klaar | Smelten: lava stijgt van onder in beeld (pulserend, strepen, vonken), scherm en gereedschap gloeien; onder het magma volledig lava; één melding | G5: vergelijk_smelten |
| binnen2-06 | G5 | klaar (ter goedkeuring) | Decor per planeet en laag (paddenstoelen met gloeiende lamellen en gloeiwormdraden, parasolzwammen, beugelzwammen en zoutkorsten, roze scherven, kwartsgeodes); druipsteen in de laagkleur | G5: vergelijk_grotdecor |
| binnen2-08 | G5 | klaar (ter goedkeuring) | Bekken herwerkt (vleugels met kam, plaat met druppelgaten, schaambeenboog); bone.gdshader met okervlekken, donkere holtes, putjes en haarscheurtjes. Reviewer: duidelijk beter, bekken leest nog wat als masker | G5: vergelijk_botten |
| binnen2-09 | G5 | klaar | Glinsters flitsen als facetten naar de lamp; knollen met donkere korst en zeskantig kristal, geen halo | G5: vergelijk_erts |
| binnen2-12 | G5 | deels | Barsten dunner, onregelmatig en onderbroken met lichte stofrand; druipsteen niet meer zwart. Open: op een licht plafond nog een zachter net | G5 |
| binnen2-14 | G5 | klaar | Merklaag met golvende, zachte randen, korrel, roestvlekken en knolletjes | G5 |
| binnen2-15 | G5 | deels | Boorkopcamera zonder mist, nachtzicht met randdetectie (feed.gdshader). Open: geen markers voor vondsten of laaggrenzen | G5: vergelijk_molscherm |
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

