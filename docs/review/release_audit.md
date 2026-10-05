# Release-audit, 5 oktober 2026

**De lat:** een publieke Steam-demo. Een vreemde speelt zonder uitleg, en een streamer of recensent kijkt mee.

**Bekeken:** gameplay en gevoel, en uiterlijk. Dat deden vijf reviewers: ontwerp, gevoel, uiterlijk buiten, uiterlijk binnen en interface.

**Opdracht:** [release_audit_opdracht.md](release_audit_opdracht.md).

Er zijn 87 bevindingen. De volledige rapporten, met bewijs (±600 beelden, 12 films en metingen), staan in `logs/review/<rol>/rapport.md`. Ze worden niet gecommit.

Met **✔** gemarkeerd: dat heb ik als lead zelf nagekeken (beeld, code of meting).

## Oordeel

**Nog niet klaar voor een publieke demo.**

**Wat wel staat:**
- de techniek;
- het begin en het einde van een dienst (terminal, drop, grijper, rapport);
- de DIG-humor;
- de horizon.

**Wat ontbreekt:**
- **Het midden van een dienst** heeft geen dreiging en geen doel.
- **De ondergrond is eentonig.** Daar speel je het grootst deel van de tijd.
- **Bewegen en de Mol voelen gewichtloos.**
- **In de eerste minuut** zie je een pijnlijk bord en overal "coming soon".

Dit laatste kan in een paar uur weg. De rest is werk van weken en valt grotendeels samen met wat al gepland was: M3 stap 8 (verkopen), upgrades, en M4 (wezens, gas, items).

## Blokkerend: hier valt een demo op af

**1. Het midden van de dienst is leeg.** Ernst: L. (ontwerp-1, ontwerp-12, gevoel-08, binnen-05, ui-04)
- Van minuut 2 tot 12 is er geen dreiging:
  - geen wezen, geen gas;
  - robots hebben geen levens;
  - je verliest enkel iets door te smelten of achter te blijven.
- Het magma bereikt de diepste laag die je kan bewerken pas na 12–14 minuten. De HUD toont het magma pas binnen 60 m, dus de klok is lang onzichtbaar.
- Een beving voel je nauwelijks: het beeld schudt minder dan bij één houweelslag. De rotsen zijn gladde bollen, en de waarschuwing is een gewone toast.

**2. Geld heeft geen doel, en falen kost niets.** Ernst: L. (ontwerp-2, ontwerp-3)
- Er is niets te kopen. Reputatie ontgrendelt niets.
- Schuld heeft geen gevolg.
- Een gemist kwartaal kost €78.
- De quota (solo ±€267) haal je met één schedel. "Nog één fossiel of nu naar boven?" komt nooit voor.

**3. De ondergrond is één bruine soep. ✔** Ernst: L. (binnen-01, binnen-02, binnen-08, ontwerp-4, ontwerp-5)
- Tot −70 m is alles klei. Wand, vloer, puin, erts en korst hebben dezelfde oranjebruine tint onder de amber lamp.
- Er is geen eigen lichtbron en geen grotdecor.
- Graniet en kristal (dieper dan −145 m) kan je niet bereiken. ✔ Er is enkel een houweel en een boor T1, en de Mol is ook T1. Volgens de meting ligt 60–78% van de vondstwaarde daar.
- De drie planeten hebben dezelfde ondergrond, dezelfde buit en dezelfde gevaren. Ze spelen dus identiek.

**4. Bewegen voelt gewichtloos en het beeld hapert. ✔** Ernst: M. (gevoel-01, gevoel-02)
- Er is geen sprint en geen hurken.
- ✔ De snelheid springt meteen van 0 naar 4,5 m/s.
- Een val van 6 m geeft geen camerareactie. Ook bij het lopen beweegt de camera niet mee.
- ✔ Physics-interpolatie staat uit. Boven 60 Hz staat de camera in 2 van de 3 beelden stil en springt hij daarna. Dat geldt ook voor meerijden en dragen.

**5. De drop toont zijn mooiste beelden niet. ✔** Ernst: M. (buiten-1, gevoel-17)
- Ruim de helft van de val kijkt de camera recht omlaag op een vlak veld. Je ziet geen hemel, geen reus en geen kim.
- Van opzij, op dezelfde hoogtes, zijn de beelden wel sterk.
- Er komt zo geen enkel bruikbaar Steam-beeld uit de drop.

**6. De eerste minuut in de hub. ✔** Ernst: S, snelle winst. (ui-01, ui-02, ui-06, gevoel-07, binnen-13)
- ✔ Het bord "BRIDGE · CONTRACTS" leest **"CUNTRACTS"**. Een plaatje bedekt de bovenkant van de C en de O, in het eerste beeld.
- Overal staat ontwikkelaarstaal:
  - "something will go here later", "coming in a later version";
  - "UNDER CONSTRUCTION", "COMING SOON";
  - "(coming in M4)", "Playtest 0.9";
  - een hint naar een boor T2 die niet bestaat.
- ✔ F1 (tuningmenu) en V (vliegen) werken in elke build.

**7. Een vondst vrijleggen heeft geen beloningsmoment.** Ernst: M. (gevoel-03, binnen-04, ontwerp-9, binnen-16)
- De gloed als de korst breekt, verdwijnt in de stofwolk.
- De korst is altijd hetzelfde beige ei.
- De waarde staat meteen in de HUD.
- Er zijn geen sets en geen onthulling. De duurste vondst leest het slechtst.

## Ernstig: duidelijk onder demo-niveau

| Thema | Wat | IDs | Moeite |
|---|---|---|---|
| **De Mol** | Maakt graven overbodig: wie van blip naar blip rijdt, scoort zonder uit te stappen. De autopiloot boort 2× zo snel als zelf sturen. Hij rijdt 5 m/s (het GDD zegt 1,5). Er is geen gewicht: de cabine beweegt niet, en gas en draaien gaan in één tick aan en uit. | ontwerp-6, gevoel-04 | M |
| **Ophalen** | 28–38 s vast, met de blik op slot en zicht op de binnenwand. Het buitenbeeld is een geel blokje aan een draad van 1 px. | gevoel-05, buiten-5 | M |
| **Geen climax** | De noodophaling beslist voor jou, en de terugrit kan niet mislukken. Smelten is een teleport plus een melding. De hittezone wordt niet gebruikt. | ontwerp-7, gevoel-12 | M–L |
| **Co-op** | Niets vraagt om twee spelers. Passagiers hebben niets te doen. | ontwerp-8 | L |
| **Contract kiezen** | Een plat formulier met een doorschijnend hologram dat hetzelfde toont. De opties liggen binnen ±9% van elkaar. HIGH geeft +35% zonder extra risico als je in de klei blijft. | ontwerp-10, ui-03 | M |
| **Dragen** | Geen hand, de vondst zit vast aan je blik, een worp tegen de wand kost 0% gaafheid, en er komt geen "−€". | gevoel-06, binnen-10 | M |
| **Erts** | Glinsters zijn puntjes van 3 cm, en koper is oranje op oranje. Delven en storten geven bijna niets terug. | binnen-03, gevoel-16, ontwerp-13 | M |
| **Magma (beeld)** | Eén plat vlak zo groot als de wereld, met een patroon dat op een voetbal lijkt. | binnen-06 | M |
| **Planeten buiten** | Roestbol is één bruine waas zonder koel accent. Fossielwereld is uitgebleekt. Kristalmaan oogt als placeholder (stickers, papierstroken, matte kristallen). | buiten-3, buiten-4, buiten-6 | M |
| **Rand van het speelgebied ✔** | Van op de grond loopt langs de paaltjes een rechte trede of geul, op alle drie de planeten. Van boven is hij weg. | buiten-2 | M |
| **First person** | De hand is een oranje want met een "deegrol". Het houweel steekt in plaats van te zwaaien, en er is geen wisselanimatie. Vonken worden neonstaafjes voor de camera. | binnen-11, gevoel-09, gevoel-10 | M |
| **Lagen** | Een laag voelt niet harder: het is aan of uit. De "snelle" boor is niet sneller dan het houweel. | gevoel-11, ontwerp-11 | S–M |
| **HUD** | Veel tekst is 13–17 px, terwijl onze eigen ondergrens 18 px is. Onleesbaar op 720p of op stream. | ui-05 | S–M |

## Middel en klein (polish)

- **Ontwerp:**
  - de PING is geen beslissing (ontwerp-14);
  - de autopiloot brengt je enkel naar de laag met rommel (ontwerp-15);
  - de eerste vondst is altijd dezelfde klauw (ontwerp-16).
- **Gevoel:**
  - de PING heeft geen moment (gevoel-13);
  - harde knippen bij de hendel, het instappen en het uitstappen (gevoel-14, gevoel-20);
  - oververhitting van de boor zie je niet (gevoel-15);
  - eerste rit met de autopiloot: meteen rode meldingen over een kapotte vondst (gevoel-18);
  - stof en kuil van het houweel lezen slecht op klei (gevoel-19).
- **Buiten:**
  - zaagtanden op kliffen (buiten-7);
  - rotsen zijn zachte broden (buiten-8);
  - de ring en de reus (buiten-9);
  - het schip van buiten is een blokmodel (buiten-10);
  - door de baai altijd dezelfde maan (buiten-11);
  - overal hetzelfde craquelé (buiten-12);
  - de snelheidslijnen (buiten-13);
  - de mistplaat (buiten-14).
- **Binnen:**
  - tunnelvloeren lezen als tegels (binnen-07);
  - hakken toont weinig vooruitgang (binnen-09);
  - de hub is een blokout zonder materiaal of slijtage (binnen-12);
  - de Mol is binnen een crème doos (binnen-14);
  - de trechter lijkt op een lamp (binnen-15);
  - de Mol is verborgen vanaf de brug (binnen-17);
  - vloertekst staat ondersteboven (binnen-18).
- **Interface:**
  - het Engels is niet consistent: "Missed = fine.", "drive The Mole" tegenover "Drive the Mole", € tegenover CR/CENTS, "Off, Off, On" (ui-07);
  - het rapport is een kaal bonnetje (ui-08);
  - de HUD heeft geen eigen gezicht (ui-09);
  - de laagchip (ui-10);
  - een kleine drop-aftelling (ui-11);
  - het hoofdmenu (ui-12);
  - de schermen in de wereld (ui-13);
  - het pauzemenu, de instellingen, het laadscherm, de tv en de stempel (ui-14 t/m 19).

## Snelle winst (uren, weinig risico)

1. Het bord "CONTRACTS" vrijmaken (ui-01).
2. Alle "coming soon", "later", "M4", "Playtest" en de T2-hint weg. Lege nissen worden decor (ui-02, binnen-13).
3. F1 en V enkel in een ontwikkelaarsbuild (ui-06, gevoel-07).
4. "Interest is accruing" weg. Schade met een min-teken (ontwerp-2, ui-08).
5. Het Engels gelijktrekken (ui-07).
6. Physics-interpolatie aanzetten, en daarna de testreeks draaien (gevoel-02).
7. De HUD-tekst naar minstens 18 px, en waarschuwingen in de waarschuwingsstijl (ui-05, ui-04).

## Wat al op demo-niveau zit (niet kapot maken)

- De DIG-humor: de tv, de borden en de teksten.
- De opdrachttafel met het hologram, en de looproute door de hub. Die is van elke deur vrij.
- De drop en de grijper als ritueel (tijden, licht, knip in de klap), en de eerste minuut op de planeet (een bot op ≤7 m, een koperader).
- De horizon en het verre landschap. Het gouden uur op Kristalmaan, het reuzenskelet, en de silhouetten in tegenlicht op Roestbol.
- De Mol van buiten, de robots, de slag van het houweel en de barsten van de korst.

## Niet bekeken

- Buiten de opdracht:
  - de uitleg voor nieuwe spelers;
  - stabiliteit en performance;
  - een mid-range-pc;
  - co-op met echte vertraging.
- **Geluid.** Dat is Jayme's beslissing (M6), maar eerlijk: een demo met bijna geen geluid valt ook daarop af. De beving, de PING en het smelten missen hun moment het hardst.
