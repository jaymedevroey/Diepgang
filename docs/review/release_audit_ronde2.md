# Release-audit ronde 2, 6 oktober 2026 (v0.10.0)

- **Lat:** dezelfde als in ronde 1, een publieke Steam-demo. Bekeken zijn gameplay en gevoel, en uiterlijk.
- **Werkwijze:** vijf reviewers. Opdracht: [release_audit_ronde2_opdracht.md](release_audit_ronde2_opdracht.md).
- **Volledige rapporten**, met bewijs en ±1.000 beelden en films: `logs/review2/<rol>/rapport.md`. Die worden niet gecommit.
- **✔** = door de lead zelf nagekeken.

## Oordeel

**Nog niet op demo-niveau, maar een grote stap.** Het basisgevoel zit nu boven de lat: lopen, graven, de Mol, de drop en smelten. De structuur van een extractiegame staat er ook: een doel, een winkel, een tegenstander, een climax en een beloning.

Wat de demo nog tegenhoudt:
1. **De nieuwe gevaren verliezen hun moment.** Je hoort ze niet aankomen, de worm leest slecht, en bij een klap kruipt de camera in je eigen robot.
2. **Het geldmoment heeft geen show.** De taxatie is zwevende tekst, de winkel een formulier, en upgrades zie je niet.
3. **Buiten op ooghoogte** zijn de grond en het middenplan nog programmer art.

## Vorige punten (87)

| Rol | Opgelost | Beter, niet genoeg | Niet | Erger |
|---|---|---|---|---|
| ontwerp (16) | 11 | 5 | 0 | 0 |
| gevoel (20) | 17 | 3 | 0 | 0 |
| buiten (14) | 4 | 9 | 0 | 1 |
| binnen (18) | 9 | 9 | 0 | 0 |
| ui (19) | 15 | 4 | 0 | 0 |
| **Samen** | **56** | **30** | **0** | **1** |

- **Erger geworden:** buiten-14. De kloofmist van Fossielwereld, grijze blokken met een harde rand, staat door het nieuwe volgshot nu in elke drop.
- **Uit een fix gekomen (ui2-04):** de grotere sonar (ui-05) bedekt in buitenzicht de pilootstrook. "Horn" en "Get out" zijn weg.
- **Vroeger blokkerend, nu Ernstig:** binnen-01, de ondergrond als bruine soep.

## Nieuwe bevindingen, per thema

**Blokkerend: 1.** Alle andere nieuwe punten zijn Ernstig of lichter.

### A. Gevaar dat zijn moment verliest

- **gevoel2-01 (Blokkerend) ✔: je merkt de gevaren niet op tijd.**
  - Geen enkel gevaar maakt geluid. In `src/hazards/` speelt niets iets af.
  - De waarschuwing van de worm is een stofwolkje van ±40 px. Zijn kop is 0,5 s in beeld voor hij raakt.
  - De melding bij gas komt 0,5 s voor je omvalt.
- **binnen2-01 ✔:** de worm ramt dwars door het laadruim van de Mol. De melding valt buiten de balk.
- **binnen2-02, ui2-05: de worm leest slecht.**
  - In het donker is het een zwarte ribbelbuis, en de kop lijkt op een straalmotor.
  - Op de sonar is hij groen, net als een vondst, en hij heeft geen naam (TREMOR of BIG CONTACT).
- **gevoel2-02, binnen2-03:** bij omver of neer is er een harde knip zonder klapmoment. Daarna zit de camera ±0,8 s in je eigen robot. Gedragen kijk je 10 s naar het hoofd van je maat.
- **ui2-02:** "GAS · NO DRILLING" is geel op gele mist, en ook de HUD bovenaan wordt daar onleesbaar.
- **binnen2-04:** instortingspuin is een glad beige twintigvlak.
- **gevoel, middel:** de ram van de worm voel je amper, de lichtbakens zijn zwak, en een kristal breekt klein.

### B. Gevaar op de verkeerde plek (balans)

- **ontwerp2-1 ✔: de worm ramt de rijdende Mol op elk moment.**
  - Gemeten op minuut 5: 9 rammen in 2 minuten rijden. Daarna is de lading nog 25% waard.
  - Dat breekt de Mol als veilige thuis, de autopiloot en de zijscan.
- **ontwerp2-2:** wie voorzichtig met het houweel werkt, loopt weinig risico.
  - Gas: 0–1 bel binnen bereik.
  - Instortingen: op de helft van de plekken ligt geen zone.
  - De worm grijpt geen spelers, terwijl de playtesters juist dat wilden.
- **ontwerp2-3:** één lichtbaken in de Mol zet de hele climax uit.

### C. Het geldmoment zonder show

- **ui2-01, gevoel2-04, binnen: de taxatie aan de poort is zwevende tekst zonder dieptetest.**
  - Teksten overlappen elkaar, en wie draagt, ziet zijn eigen onthulling niet.
  - Bij een verkoop komen er twee meldingen.
- **ui2-11, binnen:** de winkel is een webformulier, kopen verandert niets in de wereld, en upgrades zie je nergens.
- **ontwerp2-4, ui2-12: je beslist blind.**
  - De draagkaart toont geen kg en de waarde als "€ ?".
  - De quota telt pas na de verkoop, dus tijdens de eerste dienst staat er €0.

### D. Buiten op ooghoogte

- **buiten2-1:** de grond is op alle drie de planeten nog programmer art: platte platen, zebrastrepen op Rustbowl, vlekkenruis. De waardespreiding is 5–8, in de concepten 22–24.
- **buiten2-6:** het middenplan blijft leeg, de props zijn te klein.
- **buiten2-4, buiten2-5:**
  - de buttes zijn gelaagde taarten;
  - het vuil op de Mol leest als stickers;
  - de kristallen van Kristalmaan zijn van dichtbij plastic.
- **buiten2-2, buiten2-3:**
  - het volgshot staat ±2,3 s stil;
  - in het kraanshot hangt de Mol 5–6 s voor lege lucht, en je ziet de grijper niet zakken.

### E. Samen dragen

- **gevoel2-03:** de titanschedel zweeft 2–3 m van beide dragers, met handen in de lucht, en het touw laat 4,9 m toe. Het leest als telekinese.

### F. Tekst, borden en toetsen

- **ui2-07:** de nieuwe tekst breekt de stijlregels opnieuw:
  - "REP -1" met een koppelteken;
  - "10 M" en "KG" tegenover "kg";
  - "€2000" zonder komma;
  - vijf namen voor de contracttafel;
  - Team funds tegenover Crew funds.
- **ui2-08:** de borden spreken de regels tegen. In het laadruim staat "MAX 400 KG" (de limiet is 60 kg), en het prijsbord noemt touw, ladder en walkie-talkie, die niet bestaan.
- **ui2-09:** toetsen staan hard in de tekst ("WASD", "Press Q"), en dat klopt niet op AZERTY.
- **ui2-10 ✔:** de uitnodiging toont het VirtualBox-adres als "Same network". Die netwerkkaart heet "Ethernet 3", en de filter op de naam van de lead miste hem.

### G. Kleinere ontwerppunten

- **ontwerp2-5:** het risicolabel houdt geen rekening met de planeet. Kristalmaan LOW is gevaarlijker dan Roestbol HIGH.
- **ontwerp2-6:** een Titanset (62–120 kg) past nooit in het gewone laadruim.
- **ontwerp2-7:** de boorwaarden voor graniet en kristal ontbreken in `drill.cfg`. Met boor T2 gaat graniet daardoor sneller dan zandsteen.
- **ontwerp2-8:** de afdaling duurt 2:40 tot het zandsteen en 5:22 tot het graniet, en al die tijd zit je stil.
- **ontwerp2-9 tot -11:**
  - de taxatie is een draagklus;
  - solo heb je alles gekocht na 5–8 diensten;
  - de proeftijd sluit net de kaart die het meest opbrengt.

## Voorstellen van de reviewers (de sterkste, samengevoegd)

| # | Voorstel | Van | Moeite |
|---|---|---|---|
| 1 | **Een kleine geluidspas voor enkel de gevaren** (6–8 geluiden: gerommel van de worm, gesis van gas, krakend gesteente, klap), plus grotere tekens in beeld. Geluid is M6 en Jaymes beslissing, maar drie reviewers zeggen dat de gevaren zonder geluid hun moment missen. | gevoel, binnen | S–M |
| 2 | **De worm grijpt een speler en sleurt hem 15–30 m mee**, en de ploeg moet hem bevrijden (zoals de Smoker in L4D2 of de Snare Flea in Lethal Company). Midden in de dienst duwt hij de Mol enkel. Daarbij een dreigingstaal: een naam, rood of amber op sonar en kompas, de vloer die openbarst, een lijf dat oplicht. | ontwerp, ui, binnen | M |
| 3 | **De taxatie als ceremonie:** een scanstraal, licht per waardeklasse, een rollende teller, de set-voortgang en een quotabalk die vult (zoals R.E.P.O. en Lethal Company). Upgrades die je ziet op je gereedschap en de Mol. | ui, gevoel, binnen | M |
| 4 | **Een schatting in het veld:** kg en een waardebereik op de draagkaart, "HAUL ±€X–Y · kg · QUOTA" in de Mol, balken bij de klep. De exacte waarde blijft voor de poort. | ontwerp, ui | S |
| 5 | **Een klapmoment** (hit-stop, flits, FOV-stoot) en een volgcamera die lijven en de Mol ontwijkt. **Samen tillen met twee handgrepen.** | gevoel | S–M |
| 6 | **Grotten als bestemming:** set pieces uit de seed (een oud DIG-kamp met werklampen, een gestrande oude Mol, een reuzenribbenkast) met goede buit. Past in GDD §4. Ook een gecomponeerde landingsplek met een voorgrond. | binnen, buiten | M |
| 7 | **Een actieve climax:** geen baken dat werkt in een rijdende Mol, taken tijdens de rit, standhouden aan de oppervlakte tot de grijper vastzit (zoals Helldivers 2 en DRG). | ontwerp | M |
| 8 | **Een grondpass per planeet:** drie waardegroepen en klein detail binnen 20 m, en de platen en strepen eruit. | buiten | M–L |
| 9 | **Eén bron voor alle tekst en toetsen:** een tabel met alle teksten, een test die de stijlregels bewaakt, en toetsen uit de bindings (met glyphs voor de controller). | ui | S–M |
| 10 | **Gevaar buiten** (bijvoorbeeld een stofstorm over de kraterwand). Dit verandert het GDD. | buiten | M |

## Wat Jayme moet goedkeuren (het oordeel van de reviewers)

- **Ja:**
  - de hand;
  - de nissen HR en Break Room;
  - het interieur van de Mol;
  - de titanschedel en de kristallen;
  - de contracten, de schuld en de proeftijd;
  - de handscanner, met de eenheden in kleine letters;
  - de rompshader van het schip en de props in het middenplan, mits verbeterd.
- **Nee, in deze vorm:**
  - het lijf van de worm en hoe hij in de UI staat;
  - het Titan-bekken;
  - de verweerde Mol (het vuil leest als stickers);
  - de buttes.
- **Richting goed, uitvoering nog niet:** de badlands in het speelgebied van Fossielwereld.

## De playtest ("niet genoeg gevaar", "meer dingen om mee te spelen")

- **Half opgelost.** Het gevaar is er nu, maar het zit op de verkeerde plek: veel voor wie met de Mol rijdt, weinig voor wie voorzichtig graaft. Je hoort het ook niet aankomen.
- **Om mee te spelen** is er buiten, in de hub en in de Mol nog weinig.

## Niet bekeken

Zoals in ronde 1 vallen buiten de opdracht:
- de uitleg voor nieuwe spelers;
- stabiliteit en performance;
- een mid-range-pc;
- co-op met echte spelers.

Nog niets is met echte invoer gespeeld.
