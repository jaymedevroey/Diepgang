# De Mol — ontwerp

Versie 3, 1 oktober 2026 (gebouwd en getest; sonar erbij). Uitwerking van GDD §5A. Stijl: [stijlgids](stijlgids.md) (DRG + PEAK + Astroneer, alles in Blender).

## Waarom hij eruitziet zoals hij eruitziet

De Mol boort een tunnel en moet daar zelf doorheen. Dat bepaalt de vorm, net als bij een echte tunnelboormachine:

1. **De boorkop is het breedste deel** (Ø 6,0 m). Alles erachter past in de geboorde tunnel (Ø ±6,4 m).
2. **De romp is een afgeschuinde doos** (4,8 × 4,2 m doorsnede) die net binnen de ronde tunnel valt.
3. **De rupsbanden staan schuin onder de romp** (30°), zodat ze op een ronde tunnelvloer rusten in plaats van op een vlakke weg.
4. **Vooruit kijken kan niet**: de boorkop zit ervoor. De piloot stuurt via een **camera in de naaf van de boorkop**, op een groot scherm in de cabine. Opzij kijk je door patrijspoorten naar de tunnelwand (en de lagen die voorbijschuiven).
5. **De uitlaat en de motor zitten bovenop achteraan**, de enige plek waar nog ruimte is in de ronde tunnel.
6. **Instappen gaat achteraan via een laadklep** die naar de tunnelvloer zakt. Achteraan, omdat vooraan de boorkop zit.
7. **Hellingen tot ±25°.** Binnen kan je dan nog staan (rupsvoertuigen en mensen houden niet van steiler). Afdalen bij de start gaat daarom in een **spiraal** naar beneden.

## Maten (Godot-assen: −Z vooruit, Y omhoog; oorsprong = midden van de romp-as)

| Onderdeel | Positie (z) | Maat |
|---|---|---|
| Boorkop | −7,0 tot −5,4 | Ø 6,0 m, draait rond Z |
| Schild (stilstaand, met koplampen) | −5,4 tot −3,8 | Ø 5,6 m |
| Romp | −3,8 tot +4,2 | 4,8 breed × 4,2 hoog |
| Rupsbanden (2×) | −3,4 tot +3,8 | 7,2 lang, 0,9 breed, onderkant op y ≈ −3,0 |
| Motorblok + 2 uitlaten | +1,6 tot +4,0, bovenop | tot y = +2,9 |
| Laadklep | scharnier op z = +4,2, y = −1,5 | 2,6 m, open = schuin naar de vloer |

**Binnen** (vloer op y = −1,5, plafond op y = +1,8, binnenbreedte 4,2 m):

| Zone | z | Wat staat er |
|---|---|---|
| Cabine | −3,6 tot −1,6 | stoel, console van wand tot wand met een paneel dat 35° naar de piloot kantelt: autopilootknoppen (20/40/60 M), meters met bewegende naald (diepte, snelheid, brandstof), klep, licht, toeter, vertrekhendel; daarboven het grote camerascherm, links een statusscherm (stand, diepte, helling, brandstof, laadruim) en rechts de sonarkast |
| Woonruimte | −1,6 tot +1,6 | werkbank (upgrades later), kastjes, bankjes, koffieapparaat, patrijspoort links en rechts, kooilampen |
| Laadruim | +1,6 tot +4,2 | sjorrails, vrachtvloer met waarschuwingsstrepen, de laadklep |

## Uiterlijk

- Bedrijfsgeel `#F2B705` met antraciet `#23262B`, kaal staal voor de boorkop en de rupsen.
- Geklonken platen met dikke bouten, panelen met naden, waarschuwingsstrepen rond het schild.
- "DIEPGANG BV" en "DE MOL · M-01" op de flanken, een paar stickers, deuken.
- Boorkop: drie spiraalarmen met snijtanden (±30), een rand met tanden, een middennaaf met camera en lichtring.
- Licht: 4 koplampen in het schild (2 met schaduw), 2 oranje zwaailichten bovenop, warme kooilampen binnen, het blauwige camerascherm en het groene sonarscherm in de cabine.
- Randen lichter (geverfd metaal sleet eraf), holtes donkerder: gebakken in vertexkleuren in Blender, gebruikt door een eigen shader in Godot.

## Werking in het spel

**Besturen** (één piloot; iedereen mag): E op de stoel of de twee stuurhendels ernaast (in de cabine volstaat E). De hendels bewegen mee met wat de Mol doet (rupsverschil bij draaien). W/S gas, A/D draaien, spatie/Ctrl neus omhoog/omlaag (max. ±25°), H toeter. In de stoel kijk je rond met de muis; E op een knop drukt hem in, E ergens anders = uitstappen. Je kijkt naar het camerascherm (bewakingsmonitor: CAM 1, REC, vizier, diepte en laag), of met **C naar buiten** (camera achter de Mol, kiest in een tunnel zelf de vrije richting terug langs de tunnel).

**Boren:** vooruit rijden in rots boort grote bollen weg vooraan (Ø 6,4 m). Draaien schaaft ook langs de flanken. Achteruit kan enkel door een vrije tunnel.
- Snelheid: 3 m/s door rots, 5 m/s door een vrije tunnel; autopiloot 6 m/s.
- De boorkop volgt de laagregels: **T1 = klei en zandsteen**. Op graniet blokkeert hij met vonken en gekrijs.
- **De buitenmuur van de put** kan hij niet aan: hij stopt ervoor (op het statusscherm "! RAND PUT"), en draaien dat kop of staart in de muur zou zwaaien, gebeurt niet. Achteruit kan langs de eigen tunnel.
- Rots herkent hij in een ring zo breed als de romp met de rupsen. Tilt de steun hem op (een grotvloer, een bult), dan maakt hij kopruimte vrij boven de rupsen. Bij draaien schaaft hij langs de echte omtrek van de romp.
- Brandstof per dienst beperkt (meter in de cabine).
- Valt de grond onder hem weg (grot), dan zakt hij tot hij steun vindt.

**Sonar:** rechts naast het camerascherm staat een sonarkast met een ronde groene beeldbuis (GDD §4, scanner T1: vage blips, nooit "alles zichtbaar").
- Kop boven: vooruit is boven op het scherm, rechts is rechts. Een veeg draait rond (2,4 s); waar hij een vondst raakt, licht een blip op die daarna uitdooft. Het echolampje op de kast flitst mee.
- Bereik 24 m. Vaag: elke echo wijkt wat af (0,5 m + 5 cm per meter afstand), elke veeg anders.
- Grootte van de blip = gewicht (klein, middel, groot). ▲ of ▼ naast een blip: meer dan 2,5 m boven of onder de Mol. Rechts een dieptestrook (±20 m) met alle echo's op hun hoogte.
- Het doel (dichtstbijzijnde echo, met haakjes) staat in tekst: afstand, richting op de klok ("2 UUR"), hoogte ("6 M ONDER" of "GELIJK") en grootte. Dichter dan 8 m: "! DICHTBIJ · STOP HIER".
- Lawaai: rijden en vooral boren geven ruis op het scherm (RUIS) en onzekerdere echo's. Stilstaan geeft een scherp beeld (STIL).
- In buitenzicht (C) staat hetzelfde sonarbeeld rechtsonder in de HUD (instelling *Sonar in buitenzicht*).
- Vondsten die gedragen worden of in het laadruim liggen, staan er niet op. Lokaal op elke peer: de vondsten staan overal (seed), er gaat niets over het netwerk.

**Boorkop in een vondst:** raakt de boorkop (of het schaven bij draaien) een vondst die nog in de rots zit, dan schept hij hem op: de korst spat weg en de vondst ligt in het laadruim, maar met hoogstens **30% gaafheid** (melding voor de ploeg). Zo blijft er nooit een korst in de tunnel of in de Mol zweven, en loont het om op tijd te stoppen en zelf uit te bikken.

**Afdalen (autopiloot):** knoppen in de cabine (−20, −40, −60 m). De Mol boort een spiraal (straal 11 m) naar beneden op 22°, komt daarna waterpas en opent de laadklep. Stuit hij op te hard gesteente, dan stopt hij op die diepte. Vondsten op zijn weg schept hij op (zie hierboven).

**Extractie:** de vertrekhendel start een aftelling van 10 s (claxon, zwaailichten). Daarna rijdt de Mol automatisch zijn eigen spoor terug naar boven (lussen in het spoor worden overgeslagen). Boven: overzicht van wat in het laadruim ligt, en er wordt bijgetankt. Wie niet aan boord was, klimt te voet naar boven (komt terug bij de spawn achter de Mol).

**Meerijden:** wie in de Mol staat, beweegt exact mee (positie en kijkrichting), ook in de spiraal; je eigen stappen komen daarbovenop. Draaien en kantelen schaaft de tunnel over de hele lengte van de Mol vrij.

**Laadruim:** wat erin ligt, telt. Zolang de Mol rijdt, zitten losse vondsten in de Mol vastgesjord en volgen ze hem exact (op wrijving alleen schoven ze bij 22° en 6 m/s weg); staat hij stil, dan neemt de fysica het weer over.

**Netwerk:** de host simuleert de Mol, de piloot stuurt enkel zijn invoer. Wie in of op de Mol staat, stuurt zijn positie **ten opzichte van de Mol**, net zoals vondsten in het laadruim. Zo staat iedereen op elk scherm netjes binnen, ook als de Mol rijdt.

**Vervangt:** de lift en de vaste liftschacht (GDD v2.1). De put heeft geen schacht meer; de Mol staat bij de start bovenaan in het midden.

## Later (niet nu)

Upgrades (boorkop T2, snelheid, tank, laadruim, hitteschild, lier), onrust door lawaai (M5), het depot als garage (M3), verf en stickers als cosmetica.
