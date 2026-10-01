# Onderzoek: wat Diepgang leuker en beter maakt

1 oktober 2026. Vraag van Jayme: "een uitgebreid rapport en onderzoek naar wat er nog beter kan of toegevoegd kan worden aan de game, qua plezier en design".

**Aanpak.** Vier onderzoekssporen met bronnen, samengevoegd met een eigen audit van de build (commit 1329884) en wat ik zag toen ik zelf speelde:
1. vergelijkbare games: wat spelers prijzen en waarover ze klagen;
2. opgraven, vinden, verzamelen en het museum;
3. samenspel, communicatie en grappige momenten;
4. spelgevoel, progressie, herspeelbaarheid en de Steam-demo.

Cijfers over verkoop, spelers en wishlists komen uit pers, Steam-statistieken (SteamDB, steamcharts) en marketingblogs, en niet altijd uit eerste hand. Wat onzeker is, staat als *(onzeker)*. Wat mijn eigen afleiding is en niet uit een bron komt, staat als *[afgeleid]*.

---

## In het kort: de twaalf belangrijkste punten

1. **Er is concurrentie bijgekomen. "Co-op graven" is geen haak meer.**
   - *A Game About Digging A Hole Together* is aangekondigd op 29–30 september 2026: 4 spelers, crossplay, nog in 2026.
   - *GONE DIGGING* komt in Q2 2027.
   - *DIG Raiders* is sinds september 2026 uit.

   Wat ons onderscheidt, moet je in 5 seconden zien: **archeologie** (breekbare vondsten, uitbikken tegenover boren, skeletten in het museum) en **de Mol**. Zet de Steam-pagina zo vroeg mogelijk online en breng de demo uit in februari–maart 2027, niet pas tijdens Next Fest.
2. **Eerst de kernlus, dan pas meer moois.** Nu is er geen reden om iets op te graven: geen opdracht, geen kas, geen tijdsdruk, geen verlies. Een eerste speelbare lus (opdracht → dienst → lava → depot met taxatie → kas) weegt zwaarder dan alles hieronder.
3. **Eén drukklok, niet drie.**
   - De lava is de zichtbare klok.
   - Onrust volgt enkel wat je zelf doet (lawaai).
   - Een gemiste quota kost geld of schuld, nooit je museum of je upgrades.

   *DRG: Rogue Core* verloor in vier maanden ±95% van zijn spelers, onder meer door een strenge missietimer bovenop een spel over verkennen.
4. **Maak van de sonar een rol en een risico, geen kaart.**
   - Stil luisteren geeft weinig: kort bereik, vaag.
   - Een **actieve ping** geeft een scherp beeld, maar maakt lawaai: onrust stijgt en de worm hoort het.
   - Ploeggenoten staan er ook op als blips.

   Zo is elke ping een beslissing van de ploeg (Barotrauma), en de radarman een echte rol (Lethal Company). Nu toont de sonar een kwart van alle vondsten tegelijk; dat zit te dicht tegen "alles zichtbaar".
5. **Onthul in twee momenten.**
   - In de put zie je enkel de *familie* en de *klasse*: licht in de klassekleur lekt door de barsten van de korst.
   - Wat het precies is en wat het waard is, onthult de **taxatie in het depot**: één voor één, van goedkoop naar duur, met de hele ploeg erbij (Animal Crossing, Stardew Valley, Two Point Museum).
6. **Eén taal voor zeldzaamheid, overal dezelfde.** Gebruik kleur plus patroon plus geluid op de sonar, de korst, het laadruim en het museumbordje. Rommel krijgt een eigen, grappige "bonk" (Terraria, Diablo).
7. **Het museum is het einddoel en de reden om terug te komen.**
   - Zichtbare gaten met hints.
   - Het eerste stuk van elke soort hangt er al ("uit het archief van de firma").
   - Namen van wie het vond op de bordjes.
   - Een vleugel per laag.
   - Beloningen bij mijlpalen.
   - Een bot dat je op zijn plek *klikt*: geen puzzel.
8. **Dingen die een tweede speler vragen, met een trage uitweg voor solo.**
   - Zware stukken samen dragen.
   - De piloot als **operator**: lichten, toeter die de worm lokt, ploeg op de sonar.
   - **Meerijders krijgen werk**: korsten bikken aan een werkbank in het laadruim terwijl de Mol rijdt.

   Barotrauma-spelers klagen dat "90% van de tijd wachten" is.
9. **Neergaan moet leuk blijven.**
   - Een gedragen robot praat nog, krakend.
   - De spookdrone kan piepen of een lichtje laten knipperen.
   - Iedereen is terug bij de volgende dienst.
10. **Waardeverlies zie en hoor je meteen**: "−€", een krak en een gezicht dat grimast, met een maximum per klap (R.E.P.O.).
11. **Upgrades zijn werkwoorden, en laat in het spel komen mods met een nadeel** (zoals de overclocks van DRG), bijvoorbeeld "stille boor: −60% lawaai, −30% snelheid". Spreid ze traag uit: *A Game About Digging A Hole* kreeg kritiek omdat alles te vroeg maximaal was.
12. **Herspeelbaarheid uit de systemen die we al hebben**:
    - mutators volgens de regels van DRG;
    - een wekelijkse put met een vast zaad;
    - opdrachten met een uitdagingsversie;
    - set pieces in de rots (een oude tunnelboor, een verzegelde crypte).

---

## 1. Waar de game nu staat

### Wat er is
- **Graven:** houweel (ritmisch, schilfers) en boor T1 (continu, hitte, luid), met puin in de kleur van de laag.
- **Vondsten:**
  - 12 soorten in families per laag, elk in een korst.
  - Houweel = gaaf, boor = sneller maar schade.
  - Bij het vrijkomen een gloed, goud voor kostbare stukken.
- **Dragen:** alleen of met twee, gooien, botsschade.
- **De Mol:**
  - rijden en boren, autopiloot, laadruim, extractie, buitenzicht;
  - de sonar;
  - opscheppen van vondsten die de boorkop raakt (30% waarde);
  - stopt voor de rand van de put.
- **Afwerking:** HUD, menu's, instellingen, sfeer per laag, rots-shader, gereedschap en vondsten in Blender.
- **Netwerk:** host en join via IP (ENet), getest met de nettest (22 controles).

### Wat er nog ontbreekt voor "een game"
- opdracht en quota, geld en teamkas;
- het depot en het museum;
- lava en onrust, de Graafworm, gas;
- de items: handscanner, takel, ladders, springlading, bakens;
- opslaan, neergaan en redden;
- geluid en muziek;
- Steam en voice;
- de tutorial.

Er is nu **geen enkele reden om iets op te graven** behalve het opgraven zelf. Dat weegt zwaarder dan alle andere punten in dit rapport.

### Wat ik zag bij het zelf spelen
- **De sonar is sterk.**
  - Bij de start staan 7 van de 36 vondsten op het scherm, op −30 m zijn het er 9.
  - Met 24 m bereik in een put van 64 × 64 m zie je een kwart van alle vondsten tegelijk, met afstand, richting en hoogte.
- **De Mol is snel en de put is klein.**
  - Boren gaat aan 3 m/s, door een vrije tunnel aan 5 m/s. Het GDD zegt ±1,5 m/s.
  - De put oversteken duurt ±20 s. Ik reed binnen een halve minuut tegen de buitenmuur.
  - De Mol voelt daardoor eerder als een auto dan als een trage, luide reus.
- **Opscheppen kan een sluiproute worden.** Een ploeg kan van blip naar blip rijden. Zolang lawaai en brandstof niets kosten, is dat de snelste manier om geld te verdienen. Dan slaat de Mol het graven over: dat is precies wat *Keep Digging* de das omdeed ("recht naar beneden = klaar").
- **Met de neus omlaag de grond in boren is leuk.** Het camerascherm toont de kleivloer met barsten en de diepte loopt op. Maar niets zegt je nog *waarom* je dieper zou gaan.
- **De eerste vondst is altijd rommel.** De vijf vondsten rond de start liggen in de klei, dus het is een fles of een kabouter. De haak van het spel (archeologie, botten) komt pas veel later in beeld.
- **Zwevende restjes terrein** na het graven zijn bewust gelaten (lessons.md). Spelers van *A Game About Digging A Hole* noemden precies dat ("dirt fragments" die blijven haken) als ergernis.

---

## 2. De markt in oktober 2026

| Game | Stand | Wat we ervan leren |
|---|---|---|
| **R.E.P.O.** | EA februari 2025. ±18,5 miljoen verkocht, piek 266k spelers, in 2026 nog 17–48k *(pers)* | Breekbare buit plus fysica werkt. Een dode speler wordt een hoofd dat je draagt. Klachten: herhaling, solo is zwak, je moet de wiki lezen om het te begrijpen. |
| **PEAK** | $7,99. In een jam van 4 weken gemaakt voor minder dan $200k, ±15 miljoen verkocht *(pers)* | Wrijving is ingebouwd: je rugzak kan enkel een vriend openen, één speler leest de gids voor. Doden worden geesten en blijven meepraten. Elke dag een vaste kaart. |
| **Lethal Company** | $9,99, ±10 miljoen, solo-ontwikkelaar | De **radarman** op het schip is volgens gidsen de belangrijkste rol. De quota stijgt tot je faalt. Walkietalkies kosten een hand. De Leviathan-worm kondigt zich aan met gerommel. |
| **Content Warning** | 24 u gratis → 6,2 miljoen claims, daarna 1 miljoen verkocht | Clips zitten in het spel zelf: je filmt je vrienden. Behoud na 30 dagen ±3%. |
| **Deep Rock Galactic** | 8 jaar na de start nog ±4,5k spelers | Een nieuwe speler is "nooit een blok aan het been". Geen PvP. De terugrit naar de pod is het hoogtepunt. |
| **DRG: Rogue Core** | 69%, van ±10k naar ±500 gemiddelde spelers in 4 maanden *(steamcharts)* | Een "vijandig" upgradesysteem (ploeggenoten onderhandelen over gedeelde keuzes) en een strenge timer die verkennen afstraft. **Onze belangrijkste waarschuwing.** |
| **A Game About Digging A Hole** | 1M+ verkocht à €4,99, viraal op TikTok | Klachten: kort, upgrades te vroeg maximaal, restjes aarde die blijven haken, een einde dat plots een ander genre wordt. **Together** (co-op) is aangekondigd voor H2 2026. |
| **Keep Digging** | 77% | Performance (5–15 fps), weinig inhoud, "recht naar beneden is optimaal", opslaan, uitnodigen. |
| **GONE DIGGING** | EA Q2 2027 | Overdag graven, 's nachts buit offeren aan een wezen. Het dichtst bij ons, in hetzelfde venster. |
| **DIG Raiders** | september 2026, 83% van 85 reviews | Haperingen bij het graven in co-op en AI-achtige assets. De niche loopt vol met slordige games. |
| **Barotrauma** | 94% | Rollen in een onderzeeër. Een actieve sonarping lokt monsters, stil luisteren niet. |
| **Dome Keeper** | demo met een mediaan van 1,5 u speeltijd → 40k wishlists in een maand | De demo is de marketing; laat hem staan na het festival. |
| **Abiotic Factor** | 96% | Klachten: geen kaart of kompas, onduidelijke doelen. Ondergronds verdwalen is een echte ergernis. |
| **Hydroneer** | | Online co-op met fysica bleek te moeilijk; de ontwikkelaars vielen terug op split-screen. Wij hebben het al werkend: een voorsprong. |
| **RV There Yet?** | 4,5M+ verkocht, 9 weken werk | Een gedeeld voertuig bindt een groep, maar het mag nooit vastlopen. |

**Wat in dit genre telkens werkt:**
- informatie of kunnen dat verdeeld is, zodat je moet praten;
- falen dat grappiger is dan slagen;
- een spel dat je in één zin of één clip van 5 seconden snapt;
- neergegane spelers die in het spel blijven;
- een prijs van $5–13;
- een demo die lang blijft staan;
- updates die elk een piek geven.

**Wat dit genre telkens doodt:**
- performance en netcode, zeker bij voxelgraafgames;
- herhaling na 5–10 uur;
- co-op waarin spelers tegen elkaar werken, of een straffe timer;
- een slap of ander einde;
- verdwalen;
- een wiki nodig hebben om het te begrijpen;
- AI-achtige of herhaalde assets;
- gedoe met lobby's en uitnodigen;
- "recht naar beneden graven is optimaal".

---

## 3. Vinden, uitbikken, taxeren en het museum

### Wat een vondst bevredigend maakt
- **Onthul in stappen.**
  - In Minecraft komt een vondst onder de borstel in 4 stappen tevoorschijn; stop je, dan zakt hij terug.
  - In Two Point Museum komt er eerst een animatie die de spanning opbouwt, dan pas de inhoud.
  - In Genshin Impact verraadt de kleur van de vallende ster de zeldzaamheid voor je het voorwerp ziet.
- **Stel de identificatie uit.** In Animal Crossing graaf je "onbekende fossielen" op; pas Blathers vertelt wat het is. Een vondst wordt zo twee momenten: vinden, en weten wat het is. (Loewenstein: weten *dat* er iets is maar niet *wat*, drijft je voort.)
- **Zeldzaamheid lees je in één oogopslag, met meerdere zintuigen.** Diablo gebruikt een luide klank, een lichtzuil en een ster op de kaart. Terraria heeft een grijze klasse voor rommel.
- **"Ding"-momenten.** De "DING" in PowerWash Simulator was een tijdelijk geluid. Het bleef, en elke opdracht is opgedeeld in stukjes met elk een eigen ding.
- **Houd iets geheim.** Dredge toont zijn monsters zo weinig mogelijk. De encyclopedie toont silhouetten met hints, en zeldzame vangsten hebben een verborgen pech-teller.
- **Wat je zelf maakte, is meer waard** (het IKEA-effect, Norton e.a. 2012), maar enkel als het af is. Een vondst die je zorgvuldig uitbikte en die dan valt en breekt, doet dus pijn. Dat is goede pijn, zolang het je eigen schuld is.
- **Bijna-raak motiveert enkel als je er zelf invloed op had** (Clark e.a. 2009). Gaafheid hangt bij ons helemaal van de spelers af: een balk "91%, 4% te weinig voor het museum" is dus eerlijk.

### Wat werkt in verzamelingen en musea
- **Zichtbare gaten.**
  - Animal Crossing heeft 21 skeletten in delen.
  - Sets van 7–12 stukken voelen haalbaar. Rond 40–60% stijgt de motivatie (Yu-kai Chou).
- **Een voorsprong cadeau.** Een stempelkaart van 10 met 2 stempels al gezet werd vaker afgemaakt (34%) dan een kaart van 8 zonder (19%), terwijl je voor beide 8 stempels nodig had (Nunes & Drèze 2006).
- **Elk stuk maakt het beter.** In Two Point Museum maakt elk onderdeel een skelet mooier, en een volledig skelet is "Pristine". Dubbele stukken verkoop je of bestudeer je voor een blijvende bonus.
- **Namen op de bordjes.** Animal Crossing toont wie het schonk en wanneer. In co-op is dat goud waard.
- **Mijlpalen.** Stardew Valley beloont 5, 10, 15 … schenkingen en volledige sets. Jurassic World Evolution werkt met drempels: 50% = uitbroeden, 100% = alles.
- **Gedeelde voortgang.** In PowerWash Simulator 2 houden gasten hun voortgang; recensenten noemden dat de beste verbetering *(onzeker: samenvatting)*.

### Wat busywork wordt
- **Lange schoonmaak-minigames.** Dinosaur Fossil Hunter: gelijkende wervels werden gokwerk.
- **Laatste stukken die bijna nooit vallen.** Dat leidt tot opgeven, niet tot doorzetten.
- **Een vondst die bij een fout helemaal weg is** (Minecraft).
- **Onderhoud van tentoonstellingen** (het vuil in Two Point Museum).

### Uit de echte archeologie
- **Context:** een vondst zonder vindplaats verliest waarde.
- **Stratigrafie:** de laag zegt hoe oud iets is, dus een vondst in de verkeerde laag is verdacht.
- **Zeven:** kleine vondsten komen vooral uit de zeef.
- **Gipsjassen:** fossielen worden in het veld ingepakt en pas in het lab uitgehaald.
- **Schatvondsten** worden in het VK getaxeerd, en de beloning wordt verdeeld.
- **Vervalsingen en vergissingen:** Piltdown en de "Brontosaurus" met de verkeerde kop.
- **Vloeken:** toeristen sturen gestolen stukken van Pompeii terug met brieven over hun pech.

Voor een louche opgravingsfirma is plunderen tegenover netjes werken een mooie satire.

### Aanbevelingen (vinden → korst → dragen → museum)

| # | Wat | Waarom | Kost |
|---|---|---|---|
| V1 | **Klasse door de barsten:** de korst barst in 3–4 stappen; vanaf stap 2 lekt licht in de klassekleur. Laatste slag: een eigen geluid per klasse en een korte lichtzuil in de tunnel. Rommel krijgt een "bonk". | Genshin, Minecraft, Diablo | S–M |
| V2 | **Eén taal voor zeldzaamheid** (4–5 klassen, kleur + patroon + geluid) op sonar, korst, laadruim en bordje | Diablo, Terraria; past bij de regel voor kleurenblinden in het GDD | S |
| V3 | **De korst in platen:** elke afgebikte plaat geeft een klein geluid en een klein vonkje, met een "DING" op het einde. Het trage houweel voelt zo als beloning, niet als straf. | PowerWash Simulator | S |
| V4 | **Taxatie in het depot:** in de put zie je familie, klasse en gaafheid; soort, ouderdom en waarde komen bij de taxatietafel, één voor één, van goedkoop naar duur | Animal Crossing, Stardew, Two Point | M |
| V5 | **Eerlijke bijna-raak:** gaafheid tegenover de museumlijn ("91%, 4% te weinig") | Clark 2009 | S |
| V6 | **Pech-bescherming:** botten die het museum nog mist, verschijnen vaker dan dubbele stukken; een verborgen teller voor zeldzame vondsten | Dredge, Yu-kai Chou | S |
| V7 | **Gaten met hints, eerste stuk cadeau:** een ontbrekend bot is een gipsen of draadmodel met een hint ("Zandsteen, Fossielbed, onder 40 m"); het eerste bot van elke soort hangt er al | Dredge, Nunes & Drèze | M |
| V8 | **Diepte = ouderdom:** een museumvleugel per laag (klei → kristal), 7–12 stukken per vleugel, met mijlpalen (cosmetica, een nieuwe site, een gereedschapsmodus) | Animal Crossing, Stardew | M |
| V9 | **Namen op de bordjes en een eigen vondstenboek:** wie het uitbikte, wie het droeg, datum, gaafheid. Het boek blijft bij de speler, ook bij een andere host. | Animal Crossing, PowerWash 2 | S–M |
| V10 | **Volledig gaat voor gaaf:** een volledig skelet komt tot leven (pose, licht). Een gaver stuk vervangt een minder gaaf. Dubbele stukken verkoop je of bestudeer je voor een blijvende bonus (bv. de T2-scanner herkent die soort). | Two Point Museum | M |
| V11 | **Monteren = klikken:** draag het bot naar de sokkel, het springt op zijn plek. Grap: een kop op de staart zetten levert de prijs "Cope" op. | Unpacking, de Bone Wars | M |
| V12 | **Context-bonus met één knop:** een vondst taggen of fotograferen voor je hem lostrekt geeft +X% en die foto op het bordje. Botten van hetzelfde skelet in één dienst geven een extra bonus. | archeologische context | S–M |
| V13 | **Gipsjas (verbruik):** de vondst wordt bijna onbreekbaar maar zwaarder (samen dragen), en moet in het depot opengezaagd worden: een tweede onthulling | paleontologie | M |
| V14 | **Zeven:** van boorgruis rond een korst blijft "gruis" over, dat je in de zeef in het laadruim schudt voor kleine vondsten (tanden, munten). Een troost voor wie boorde, en werk voor een vierde speler. | archeologie | M |
| V15 | **Aangeven of heler:** schatvondsten geef je aan bij de Oudhedendienst (half geld, reputatie, museumplek) of verkoop je zwart (volle prijs, maar "hitte" bij de firma) | de Treasure Act als satire | M |
| V16 | **Zeldzame raadsels: vervalsingen en vloeken.** Een vals reliek verraadt zich in de verkeerde laag of bij een test in het depot. Een vervloekt stuk laat de sonar haperen of de onrust stijgen zolang het in het laadruim ligt. | Piltdown, Pompeii *(onbewezen of het leuk is: eerst proberen)* | M–L |
| V17 | **De eerste vondst is een bot** *[afgeleid]*: rond de start ligt minstens één fossielstuk, ook al is het klei, zodat de haak meteen in beeld is | eigen playtest | S |

---

## 4. Samen spelen

### Principes
- **De spelers maken de inhoud; de systemen maken het waarschijnlijk.** PEAK, Lethal Company en R.E.P.O. wonnen met een goedkope, leesbare lus en sociale systemen, niet met veel inhoud. Aggro Crab: de game "rekent erop dat jij en je vrienden het verschil maken".
- **Spanning is de opzet, falen de clou.** Zeekerss noemt Lethal Company "een game over lachen met de dood".
- **Afstand bepaalt hoe je praat.**
  - Proximity voice met galm in Lethal Company.
  - Walkietalkies die je in je hand moet houden.
  - De kaart in Sea of Thieves ligt onderdeks, zodat de stuurman niet kan sturen én lezen.
- **Afhankelijkheid moet fysiek zijn, de rest mag optioneel.**
  - DRG: zonder één klasse mis je iets, maar een nieuwe speler is altijd waardevol.
  - Overcooked: meer taken dan spelers.
- **Falen moet je kunnen lezen en iemand de schuld kunnen geven, zonder neerwaartse spiraal.** De bediening mag nooit de oorzaak zijn. Human: Fall Flat 2 werd geschrapt omdat het "te stijf, te gepolijst" was.
- **Per ongeluk je vrienden raken is komedie** (Helldivers 2), mits je het kan uitzetten (PEAK).
- **De microfoon als mechaniek:**
  - in Phasmophobia hoort de geest je;
  - in Lethal Company horen de honden je, en push-to-talk dempt je;
  - YAPYAP: spreuken door te praten, monsters die op geluid afkomen.

  Fluisteren mag altijd.
- **Pings zijn de ruggengraat, voice is de saus.** Respawn testte de ping van Apex een maand met gedempte microfoons. De laserpointer van DRG benoemt materialen en markeert door muren.

### De Mol als gedeeld voertuig
- **Wat werkt: de informatie verdelen.** Sea of Thieves, Backseat Drivers en de radarman in Lethal Company lieten dat zien: een bestuurder met halve informatie levert voortdurend gesprekken op. In DRG is de boor-dozer een werkstation dat je samen bijtankt, herstelt en verdedigt.
- **Valkuil: de verveelde passagier.** "90% van de tijd wachten tot je je werk mag doen" (Barotrauma). Over de radarman in Lethal Company zijn de meningen verdeeld ("naar een monitor zitten kijken"). De les: geef de piloot meer informatiewerk aan de console, geen klusjes elders.
- **Valkuil: verveelde doden.** Er bestaat een mod die letterlijk "DeadAndBored" heet. R.E.P.O. gaf doden later een hoofd met een batterij waarmee ze kunnen praten en monsters lokken.

### Wat betrouwbaar grappige verhalen maakt
1. breekbare, fysieke buit;
2. neergegane ploeggenoten als voorwerp;
3. gezichten die met je stem bewegen (in R.E.P.O. gaat de kaak open met het volume);
4. onvolledige aanwijzingen onder tijdsdruk ("Links! Links! Nee, RECHTS!");
5. monsters die op je stem reageren;
6. aan elkaar vastzitten (Chained Together);
7. explosies en per ongeluk elkaar raken;
8. opnemen in het spel zelf (Content Warning);
9. silhouetten die je herkent in een gecomprimeerde clip van 15 seconden.

### Solo en 1–4 spelers
- De grootste klacht over Lethal Company: de quota schaalt niet met het aantal spelers.
- DRG schaalt wel, en geeft solospelers Bosco, een drone die je met dezelfde laserpointer stuurt.
- Barotrauma-bots "zijn geen goede piloten" en bevelen geven is een klus.

### Aanbevelingen

| # | Wat | Waarom | Kost |
|---|---|---|---|
| C1 | **De sonar als station:** de knoppen op de sonarkast worden echt. **PING** = actief: scherp beeld, maar lawaai en onrust. **BEREIK** = kort of lang. Een tweede speler kan aan de kast staan terwijl de piloot rijdt; solo pingt de piloot vanuit de stoel. | Barotrauma, Lethal Company, Sea of Thieves | S–M |
| C2 | **Ploeg en worm op de sonar:** ploeggenoten als eigen blips, de worm als een blip die vervaagt en schuift | Lethal Company-radar | S |
| C3 | **De piloot als operator:** lichten, laadklep, een ping voor de ploeg, en de **toeter** die lawaai maakt en de worm naar de Mol lokt om gravers te redden | Lethal Company-terminal | S–M |
| C4 | **Werk tijdens de rit:** een werkbank in het laadruim waar meerijders korsten bikken terwijl de Mol rijdt; reistijd wordt waarde | Barotrauma, Overcooked, DRG Doretta | M |
| C5 | **Losse lading die schuift bij wild rijden**, met sjorplekken die vastklikken; de ploeg kan de piloot de schuld geven *(netwerkrisico: eerst prototype en nettest)* | DRG, eigen afleiding | M |
| C6 | **Walkietalkie met een prijs:** kost een hand (botst met samen dragen), heeft een batterij, geeft een ruis-stoot bij iedereen als iemand neergaat | Lethal Company | S–M |
| C7 | **Een worm die je stem hoort, met een fluistergrens:** het micvolume telt mee in het lawaai van de put. Gewoon praten op afstand is veilig, roepen vlakbij niet. Een antenne die oplicht als je luid bent. Uit te zetten voor streamers en toegankelijkheid. | Phasmophobia, Lethal Company, YAPYAP | M |
| C8 | **Contextuele ping als vaste lijn:** één knop markeert een vondst, korst, gevaar of de worm, met een piepje en de naam. Test één keer met gedempte microfoons. | Apex, DRG | S–M |
| C9 | **Schermgezichten die met je stem bewegen** (mond of golf), grimassen bij schade, angst en waardeverlies | R.E.P.O. | S |
| C10 | **Waardeverlies luid, met een maximum per klap:** krak, "−€X", grimas. Eén klap kan nooit een hele vondst kapotmaken. | R.E.P.O., Keep Talking | S |
| C11 | **Solo-uitwegen voor stukken van twee personen:** traag slepen of lieren, en solo minder zware stukken | Lethal Company-klachten | S–M |
| C12 | **Gedragen robots praten krakend**; wie achterblijft, kost meer dan wie meegenomen wordt (Lethal Company: 8% tegenover 20%) | Lethal Company, R.E.P.O., PEAK | S |
| C13 | **De spookdrone krijgt een stem zonder woorden:** een batterij om te piepen, een lampje of een vage blip op de sonar. Geesten praten onderling en stemmen over "de Mol vertrekt". Terug bij de volgende dienst, zodat niemand meer dan ±10 min stilzit. | DeadAndBored, R.E.P.O. | S–M |
| C14 | **Quota schaalt met de ploeg**, bijvoorbeeld 1p 40%, 2p 65%, 3p 85%, 4p 100% *[afgeleid; in data/tuning]* | Lethal Company, DRG | S |
| C15 | **De Mol is de lobby:** tussen diensten wacht je in de Mol met wat fysica-speelgoed; meedoen enkel tussen diensten; wie wegvalt, wordt een draagbaar voorwerp | Lethal Company-mods | M |
| C16 | **Ritme van een sessie:** diensten van 10–15 min, 3 diensten per quota (±40 min per cyclus), met een terugrit naar de Mol op een aftelling als hoogtepunt | Lethal Company, DRG | S |
| C17 | **Begrensd per ongeluk raken:** springlading en boor duwen ploeggenoten omver, de handschoen kan een vriend oppakken; schakelaars voor de host | Helldivers 2, PEAK | S |
| C18 | **"Incidentrapport van de firma"** na elke dienst met prijzen ("Meeste waarde gesloopt", "Werknemer van de dienst"). Later: een zwarte doos van 30 s van de kopcamera om als clip te bewaren. | Content Warning | S / M–L |
| C19 | **Een solo-helper** (een klein Mol-droneke dat je met de ping stuurt: houdt de andere kant van een zwaar stuk vast, verlicht, redt één keer) | DRG Bosco | L, na EA |

---

## 5. Spelgevoel

Het geluid komt op vraag van Jayme als laatste, maar het weegt het zwaarst. Daarom staat het hier toch.

1. **Geluid per slag en per materiaal is het belangrijkste.**
   - Spelers noemen het telkens: Minecraft "vooral door de geluiden", de "tink" van erts in DRG, de "crisp clunk" in A Game About Digging A Hole.
   - Wij synthetiseren alles. Dat is een voordeel: met **modale synthese** (een paar resonante tonen plus een ruisstoot) maak je elke klap.
     - Rots, kristal en metaal klinken na.
     - Klei is vooral ruis.
   - Drie lagen per slag: inslag, lijf (toonhoogte volgens hardheid), staart van puin.
   - Telkens ±6–10% toonhoogte en ±2–3 dB, en nooit twee keer na elkaar dezelfde variant.
   - Vondsten krijgen een eigen geluid, duidelijk anders dan rots.
2. **Hit-stop op het houweel:**
   - 30–60 ms op harde rots en bij het breken van een korst;
   - niets op klei;
   - niets op de boor.

   (Sakurai; Vlambeer, "The Art of Screenshake".)
3. **Schermschok met "trauma"** (Eiserloh, GDC 2016): schok = trauma², met Perlin-ruis en trauma dat uitdooft.
   - De boor geeft lage, constante trauma; het houweel korte pieken.
   - In first person heel klein houden, met een schuifregelaar.
4. **Barsten in stappen op de korst**, met een toonhoogte die per slag stijgt. Bij de 4e slag: hit-stop, een klinkend geluid en een glinstering. Grotendeels gedaan; geluid en hit-stop ontbreken nog.
5. **Duidelijke feedback als het gereedschap het niet kan**: een klank, vonken, terugveren, een trilling en een hint ("boor T2 nodig"). Nu ketst het houweel af, maar een hint ontbreekt.
6. **Trilling op de controller** per gereedschap en materiaal, met de waarden in `data/tuning/`.
7. **Elke gereedschapsklasse moet je horen en zien:** een extra laag in het geluid, grotere brokken, andere vonken. Niet enkel een getal.

| # | Wat | Kost |
|---|---|---|
| G1 | Synthesizer voor inslagen per materiaal (modaal + ruis), met varianten en een eigen geluid per vondstklasse | M |
| G2 | Hit-stop op houweel en korst, schok met trauma, schuifregelaar | S |
| G3 | "Kan niet" duidelijk maken (klank, vonken, hint) | S |
| G4 | Trillingsprofielen in tuning | S |
| G5 | Zwevende restjes terrein na het graven opruimen (dunne snippers mee wegnemen), en kleine randjes laten opstappen | M |

---

## 6. Progressie en wat je bijhoudt

- **Upgrades die enkel procenten geven, zijn de zwakke plek van het genre.** DRG: Rogue Core kreeg kritiek op kleine bonussen ("+5% herladen"). De overclocks van het originele DRG veranderen hoe een wapen werkt, mét een nadeel. Drill Core werd verweten dat nieuwe technologie "enkel cijfers" verbetert.
- **"Te vroeg maximaal" is de bekendste klacht over A Game About Digging A Hole.** Bewaar upgrades die je spel veranderen tot laat.
- **Een upgrade mag de spanning niet wegnemen.** In Dome Keeper haalt automatisch herstel van de koepel de spanning weg. Geef manieren om lava, onrust en quota te *beheren*, nooit om ze uit te zetten.
- **Gedeelde tegenover eigen voortgang.**
  - Saves die enkel bij de host staan, laten vrienden met lege handen (R.E.P.O., Big Walk).
  - De populairste R.E.P.O.-mod deelt upgrades met de ploeg.

  Voorstel:
  - een **firmasave bij de host**: kas, Mol, depot, sites;
  - een **eigen profiel per speler**: cosmetica, rang, "gevonden door" in het museum, prestaties.

  Gasten gaan altijd vooruit.
- **Cosmetica als doel**, zonder FOMO: in DRG kan je gemiste items later nog krijgen. Bij ons kan het museum die rol spelen: sets ontgrendelen cosmetica.

| # | Wat | Kost |
|---|---|---|
| P1 | Elke trap is een nieuw werkwoord of zichtbaar gedrag. Laat in het spel **mods met een nadeel**, bijvoorbeeld "Stille boor: −60% lawaai, −30% snelheid" of "Zwaar houweel: korst in 3 slagen, 15% kans op een schilfer van de vondst". | M |
| P2 | **Tempo:** een eerste nieuw werkwoord in dienst 1; de eerste 2 uur om de 2 diensten een ontgrendeling, daarna om de 3–4; de laatste trap rond 10–12 uur. In playtests loggen wanneer. | S |
| P3 | Firmasave bij de host plus een eigen profiel per speler | M |
| P4 | **Klassen van gaafheid:** gaaf, geschilferd, gebroken. Houweel tegenover boor bepaalt de klasse; gaaf is 2–3× waard. Zo wordt de afweging uitbikken tegenover boren dé keuze. | M |

---

## 7. Herspeelbaarheid

- **Mutators volgens DRG:**
  - hoogstens 2 per opdracht, waarvan hoogstens 1 positief;
  - er is altijd een opdracht zonder waarschuwing;
  - een waarschuwing betaalt +15–50%.

  DRG heeft 18 waarschuwingen en 10 anomalieën; wij hebben er 8–12 nodig voor EA. Voorbeelden:
  - instabiel plafond;
  - gasbel (lawaai ×2);
  - snelle lava;
  - rijke ader;
  - breekbare vondsten;
  - magnetische storing (scanner uit).
- **Wekelijkse put met een vast zaad:**
  - DRG Deep Dives: één zaad voor iedereen, 3 delen, één beloning per week.
  - Lethal Company Challenge Moons: met een ranglijst. Zeekerss: vooral "een gedeelde ervaring".
- **Eindeloze dienst:** de quota stijgt elke cyclus tot je faalt (Lethal Company).
- **Opdrachten met een uitdagingsversie:** Dome Keeper heeft 25 Guild Assignments, elk gewoon en als uitdaging. Goedkope inhoud uit bestaande systemen.
- **Set pieces in de rots:**
  - een begraven oude tunnelboor;
  - een verzegelde crypte voor twee spelers;
  - een waterader;
  - een kristalgeode;
  - een groot fossiel dat je voorzichtig moet vrijleggen.

| # | Wat | Kost |
|---|---|---|
| H1 | 8–12 mutators met de regels van DRG | M |
| H2 | Wekelijkse "Diepe Dienst" met een vast zaad, een cosmetische beloning per week en een ranglijst op museumwaarde | M |
| H3 | Opdrachten met een uitdagingsversie en een badge | S–M |
| H4 | 6–10 set pieces in het voxelveld | M–L |
| H5 | **Breedte loont meer dan diepte:** waardevolle zakken liggen opzij rond stukken die de sonar kan vinden, en diepere lagen graven trager | S |

---

## 8. Demo en lancering

- **Next Fest versterkt, het ontdekt niet.**
  - Februari 2026, 182 games: mediaan 806 wishlists, 70e percentiel 1.839, 95e percentiel 13.461.
  - Wishlists vóór het festival voorspellen het resultaat het sterkst (Spearman 0,825).
  - Juni 2026 was het grootste festival ooit (±4.382 demo's) met een mediaan van ±200 wishlists.

  *(How To Market A Game)*
- **De demo vroeg uitbrengen** gaf ±2,5× de mediaan tegenover uitbrengen tijdens het festival. Parcel Simulator ging met een demo van 10–20% van de game van ±11 naar ±362 wishlists per dag.
- **68–88% van de wishlists komt van mensen die de demo niet spelen.** Pagina, capsule en trailer doen het meeste werk. Co-op-games hebben de laagste verhouding van spelen naar wishlisten: dat is normaal.
- **Lengte van de demo:**
  - mediaan 30–90 min (GMTK), of 20–40 min en stoppen voor je "klaar" bent (presskit.gg);
  - sloten tonen op wat nog komt;
  - de demo laten staan.
- **Trailer:** gameplay in de eerste 5 s, de haak binnen 10–15 s.
- **Capsule:** leesbaar op 120 × 45 px, genre in minder dan 1 s, meerdere robots (co-op).
- **Streamers:** 200–400 contacten een week voor het festival (Keymailer ±$25/maand). Muziek zonder licenties, zodat het veilig is om te streamen. Proximity voice is de clipmachine.
- **Prijs:** €9 / $9,99 is goed; niet hoger. Vriendengroepen kopen 4 stuks. Boven $10 converteert slechter (GameDiscoverCo).
- **Doelen:**
  - ≥7k wishlists voor het festival, 15k+ bij de lancering;
  - de eerste week verkoop je typisch 15–25% van je wishlists *(secundaire bronnen)*.
- **AI-melding op Steam:** sinds januari 2026 gaat de melding over gegenereerde inhoud die *in de game zit*. Ontwikkelhulpmiddelen vallen erbuiten.
  - Onze modellen, shaders en geluid zijn code die een AI-agent schreef. Dat is waarschijnlijk geen "vooraf gegenereerde AI-asset" *(onzeker; bewust beslissen)*.
  - In juni 2026 meldde 26,5% van de demo's AI-gebruik; daarvan haalde er maar één de top 10 (correlatie, geen bewijs).
  - Geen AI-beelden in de marketing.

| # | Wat | Kost |
|---|---|---|
| D1 | **Steam-pagina nu** (zodra het Steamworks-account er is), met een trailer die in 5 s toont: boor breekt door → gloeiende vondst → lava stijgt → ploeg rijdt omhoog. Capsule testen op 120 × 45. | S–M |
| D2 | **Demo in februari–maart 2027:** Oude Kolenmijn + 2–3 diensten Fossielbed, lagen 1–2, 30–45 min, co-op met Steam-uitnodigingen, sloten op wat nog komt, een eindkaart met "wishlist". Eerst een Steam Playtest. De demo blijft staan na het festival. | M |
| D3 | **Positioneringszin** die ons onderscheidt van AGADAH Together en GONE DIGGING, bijvoorbeeld: "Graaf fossielen op, niet door. Bik ze voorzichtig uit, sleep ze samen naar je boormachine, en bouw je museum voor de lava komt." *[afgeleid]* | S |
| D4 | Een plan voor streamers (±300 contacten, co-op-groepen) | S |
| D5 | EA 4–8 weken na Next Fest juni 2027, €9 met regionale prijzen | S |

---

## 9. Risico's in ons eigen ontwerp

| Risico | Wat er kan misgaan | Voorstel |
|---|---|---|
| **Sonar te sterk** | Je ziet een kwart van alle vondsten tegelijk; zoeken en verkennen vallen weg | Stil = kort (±12 m) en vaag; ping = scherp maar luid (C1). Kleine vondsten pas op korte afstand. Testen met en zonder. |
| **De Mol als oogstmachine** | Van blip naar blip rijden en alles opscheppen voor 30% is sneller dan graven | Boren met de Mol maakt veel lawaai (onrust, worm) en kost brandstof. Opgeschepte stukken zijn altijd "gebroken" (P4) en komen nooit in het museum. Zo nodig de Mol trager (GDD: ±1,5 m/s). |
| **Drie klokken** | Lava + onrust + quota voelen als een straf (Rogue Core) | Eén zichtbare klok (lava); onrust enkel door eigen lawaai; falen = schuld, niets kwijt |
| **De put is te klein voor de Mol** | 64 m oversteken in 20 s; de Mol staat snel tegen de rand | Trager rijden, of een grotere put (performance meten op mid-range) |
| **"Recht naar beneden"** | De beste vondsten diep, dus recht naar beneden | Waarde opzij in zakken (H5), lava van onder, set pieces |
| **Verdwalen** | Ondergronds zonder kaart (Abiotic Factor) | Kompas naar de Mol bestaat al; daarbij een spoor van broodkruimels (DRG) en een toeter die je in de verte hoort |
| **Zwevende restjes terrein** | Blijven haken (AGADAH) | Opruimen (G5) |
| **Netwerkfysica in een rijdende Mol** | Schuivende lading die op elk scherm anders ligt | Vastsjorren bij rijden bestaat al; schuiven (C5) enkel na een prototype met de nettest |

---

## 10. Voorstel: wat wanneer

Volgorde van de planning (GDD §10): M3 Inhoud, M4 Samen, M5 Kernlus, M6 Demo. Mijn voorstel is om **een klein stuk van de kernlus naar voren te halen**, zodat elke playtest vanaf nu zegt of het *spel* leuk is, en niet enkel of het graven goed voelt.

**Nu, als eerste stap van M3 (een "verticale plak"):**
- opdracht met quota (C14 schaalt), kas, lava als enige klok;
- een depot met **taxatietafel** (V4) en een eerste museumzaal met gaten (V7, V8);
- de sonar als rol: PING en ploeg op de sonar (C1, C2);
- opgeschepte vondsten zijn "gebroken" (risico Mol);
- de eerste vondst is een bot (V17);
- klasse door de barsten (V1), een taal voor zeldzaamheid (V2);
- het incidentrapport na een dienst (C18).

**Verder in M3:**
- de Graafworm met aankondiging (gerommel, stof, blip) en een toeter die lokt (C3);
- gas;
- items als werkwoorden (P1);
- werkbank in het laadruim (C4);
- gaafheidsklassen (P4);
- monteren = klikken (V11);
- namen op de bordjes (V9).

**M4 Samen:**
- Steam-uitnodigingen;
- voice met een worm die je hoort (C7), gezichten die meepraten (C9), walkietalkie (C6);
- ping (C8);
- gedragen robots die praten (C12), spookdrone (C13);
- de Mol als lobby (C15);
- firmasave en profiel (P3).

**M5 Kernlus:**
- mutators (H1), opdrachten met een uitdaging (H3), wekelijkse put (H2);
- tempo van de upgrades (P2), mods met een nadeel (P1);
- solo-uitwegen (C11);
- zwevende restjes opruimen (G5).

**Geluid** (op vraag van Jayme als laatste, maar vóór de demo): G1, de trillingen (G4), de hit-stop met geluid (G2).

**M6 Demo:** D1–D5. De demo vroeg (februari–maart), de pagina meteen.

**Later (na EA):** solo-helper (C19), gipsjas (V13), zeven (V14), aangeven of heler (V15), vervalsingen en vloeken (V16), zwarte doos (C18), set pieces (H4).

## 11. Wat ik niet zou doen

- **Geen tweede of derde klok bovenop de lava**, en geen straf die je museum of je upgrades afpakt.
- **Geen keuzes waarbij ploeggenoten tegen elkaar onderhandelen** (Rogue Core) en geen PvP (DRG).
- **Geen lange schoonmaak-minigame** voor fossielen (Dinosaur Fossil Hunter).
- **Geen ander genre op het einde** (AGADAH).
- **Geen bot-micromanagement** voor solo (Barotrauma).
- **Geen AI-beelden in de marketing.**

## 12. Open vragen voor Jayme

1. Haal je een klein stuk van de kernlus (quota, kas, lava, taxatie, eerste museumzaal) naar voren, vóór de rest van M3?
2. Sonar: mag hij zwakker worden (stil = kort en vaag) met een PING-knop die lawaai maakt? Of wil je hem zoals hij nu is?
3. Mogen opgeschepte vondsten altijd "gebroken" zijn (niet voor het museum)?
4. Moet de Mol trager (GDD: ±1,5 m/s), of de put groter?
5. Een worm die je stem hoort: leuk, of liever niet?
6. Positionering naast *A Game About Digging A Hole Together*: is "archeologie + de Mol + het museum" de juiste kern?

---

## Bronnen

Verzameld door vier onderzoekssporen. Bij een paar sites (Checkpoint, GameSpot PowerWash 2, TechRaptor, ScienceDirect) lukte het lezen niet en is enkel de zoeksamenvatting gebruikt. Review-thema's met aantallen komen van VaporLens (een AI-samenvatting van Steam-reviews) en zijn enkel richtinggevend.

**Vergelijkbare games**
- R.E.P.O.: https://en.wikipedia.org/wiki/R.E.P.O. · https://steamcharts.com/app/3241660 · https://gameworldobserver.com/2025/03/04/co-op-horror-game-repo-steam-charts-strong-debut · https://www.gamesradar.com/games/horror/repo-revive/
- PEAK: https://www.gamedeveloper.com/production/how-co-op-climbing-hit-peak-achieved-2-million-sales-for-less-than-200-000- · https://www.gamedeveloper.com/business/peak-co-developer-aggro-crab-shares-lessons-in-friendslop · https://peak.wiki.gg/wiki/How_to_play · https://80.lv/articles/climbing-sim-peak-was-meant-to-be-friendslop-game-from-the-start
- Lethal Company: https://www.pushtotalk.gg/p/how-lethal-company-sold-10-million-copies · https://newsletter.gamediscover.co/p/what-can-we-learn-from-lethal-companys · https://lethal-company.fandom.com/wiki/Guide:Camera_duty · https://lethal.miraheze.org/wiki/Walkie-Talkie · https://primagames.com/tips/how-to-survive-earth-leviathan-worm-in-lethal-company
- Content Warning: https://en.wikipedia.org/wiki/Content_Warning · https://www.gamesradar.com/a-24-hour-free-giveaway-sent-steams-new-viral-co-op-mega-hit-to-the-moon-with-62-million-owners-after-its-first-day/
- Deep Rock Galactic en Rogue Core: https://www.gamedeveloper.com/marketing/developing-a-live-game-that-never-truly-left-early-access-with-deep-rock-galactic · https://gamerant.com/deep-rock-galactic-interview-season-1-co-op-design-battle-pass-progression/ · https://en.wikipedia.org/wiki/Deep_Rock_Galactic:_Rogue_Core · https://gamingbolt.com/deep-rock-galactic-rogue-core-early-access-review-no-no-dig-up · https://deeprockgalactic.wiki.gg/wiki/Mutators · https://deeprockgalactic.wiki.gg/wiki/Deep_Dives · https://deeprockgalactic.wiki.gg/wiki/Laser_Pointer
- Graafgames: https://en.wikipedia.org/wiki/A_Game_About_Digging_a_Hole · https://www.gamingonlinux.com/2026/10/a-game-about-digging-a-hole-together-announced/ · https://www.gamesmarket.global/rokaplay-and-mipumi-announce-a-game-about-digging-a-hole-together/ · https://www.pcgamesn.com/keep-digging/steam-launch · https://store.steampowered.com/app/4247230/GONE_DIGGING/ · https://www.cbr.com/dig-raiders-extraction-game-review/ · https://www.gamegrin.com/reviews/a-game-about-digging-a-hole-review/
- Overige: https://howtomarketagame.com/2022/10/17/how-dome-keeper-achieved-a-million-dollar-launch/ · https://cogconnected.com/review/barotrauma-review/ · https://www.pcgamesn.com/abiotic-factor/steam-reviews · https://www.pcgamer.com/mining-sandbox-hydroneer-now-has-multiplayer-vehicles-and-an-optimized-code-rework/ · https://www.gamedeveloper.com/design/what-i-astroneer-i-s-devs-learned-while-leaving-early-access · https://en.wikipedia.org/wiki/RV_There_Yet%3F · https://howtomarketagame.com/2026/07/30/is-friendslop-saturated/

**Vinden, verzamelen en museum**
- https://minecraft.wiki/w/Archaeology · https://nookipedia.com/wiki/Fossil · https://nookipedia.com/wiki/Museum · https://stardewvalleywiki.com/Museum · https://gamingbolt.com/two-point-museum-review-carefully-curated-oddity · https://www.thegamer.com/two-point-museum-how-to-upgrade-exhibits-buzz-knowledge/ · https://screenrant.com/dinosaur-fossil-hunter-game-review/ · https://jurassicworld-evolution.fandom.com/wiki/Fossil_Center
- https://www.gamedeveloper.com/production/leveraging-the-unseen-to-turn-players-worst-fears-against-them-in-dredge · https://dredge.wiki.gg/wiki/Aberrations · https://www.futurlab.co.uk/news/world-intellectual-property-day-how-did-powerwash-simulator-come-to-be · https://www.gamedeveloper.com/marketing/unpacking-a-narrative-through-1-000-household-items · https://www.diablowiki.net/Legendary · https://terraria.wiki.gg/wiki/Rarity
- Psychologie: https://yukaichou.com/advanced-gamification/game-design-technique-collection-sets/ · https://pubmed.ncbi.nlm.nih.gov/19217383/ · https://www.science.org/doi/10.1126/science.1077349 · https://myscp.onlinelibrary.wiley.com/doi/abs/10.1016/j.jcps.2011.08.002 · https://learningloop.io/plays/psychology/endowed-progress-effect
- Archeologie: https://www.nhm.ac.uk/discover/fossil-preparation.html · https://en.wikipedia.org/wiki/Small_finds · https://finds.org.uk/treasure/valuation-museum-acquisition-and-reward · https://en.wikipedia.org/wiki/Piltdown_Man · https://en.wikipedia.org/wiki/Bone_Wars · https://edition.cnn.com/travel/article/pompeii-artifacts-returned-scli-intl/index.html

**Samen spelen**
- https://www.escapistmagazine.com/how-sea-of-thieves-gets-maps-right/ · https://www.gamedeveloper.com/design/respawn-played-with-muted-mics-to-get-i-apex-legends-i-smart-comms-system-just-right · https://www.gamedeveloper.com/design/finding-the-fun-in-bomb-defusal-with-i-keep-talking-and-nobody-explodes-i- · https://www.gamedeveloper.com/design/game-design-deep-dive-building-truly-cooperative-play-in-i-overcooked-i- · https://www.gamedeveloper.com/production/-human-fall-flat-2-is-cancelled-we-are-making-human-fall-flat-3-no-brakes-games-founder-looks-back-on-a-defining-decade
- https://steamcommunity.com/app/602960/discussions/0/4349995356617398535 (Barotrauma, "90% wachten") · https://thunderstore.io/c/lethal-company/p/Quixler/DeadAndBored/v/1.0.0/ · https://www.destructoid.com/how-does-death-head-battery-work-in-r-e-p-o/ · https://en.wikipedia.org/wiki/Phasmophobia_(video_game) · https://indiegame.com/en/archives/21460 (YAPYAP) · https://store.steampowered.com/app/3558400/Backseat_Drivers/ · https://deeprockgalactic.wiki.gg/wiki/APD-B317 (Bosco) · https://www.argentics.io/what-makes-friendslop-games-work-as-art-and-production

**Spelgevoel, progressie, demo**
- https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/ · https://archive.org/details/the-art-of-screenshake · http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf · https://www.researchgate.net/publication/220792085_Sound_synthesis_for_impact_sounds_in_video_games · https://www.resetera.com/threads/more-satisfying-mining-in-games.1128900/ · https://www.gamedeveloper.com/design/game-design-deep-dive-the-digging-mechanic-in-i-steamworld-dig-i-
- https://gazettely.com/2025/03/games/a-game-about-digging-a-hole-review/ · https://joshanthony.info/2023/05/24/design-dive-dome-keeper/ · https://domekeeper.wiki.gg/wiki/Guild_Assignments · https://www.gamesradar.com/lethal-company-gets-truly-competitive-as-patch-47-adds-leaderboards-for-replayable-challenge-moons-and-terrifyingly-makes-enemies-even-more-lethal/
- https://howtomarketagame.com/2026/04/13/making-sense-of-the-february-2026-steam-next-fest/ · https://howtomarketagame.com/2026/06/30/nobody-plays-demos-and-that-is-ok/ · https://howtomarketagame.com/2025/08/26/the-demo-effect-from-7000-wishlists-to-42000/ · https://presskit.gg/field-guides/steam-next-fest-guide · https://gmtk.substack.com/p/how-to-make-a-great-steam-next-fest · https://newsletter.gamediscover.co/p/when-demos-can-radically-expand-your · https://www.derek-lieu.com/blog/2022/10/24/how-to-hook-the-audience-and-how-quickly-to-do-it · https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/
