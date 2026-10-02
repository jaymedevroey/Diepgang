# Diepgang — playtest M1 (poort 1)

**Vraag van poort 1: voelen graven en slepen goed?** (GDD §10)
Niet: is het mooi, is het af, is er genoeg te doen. Enkel: is het leuk om te graven, uit te bikken en dingen te dragen?

## Starten

1. Start `Diepgang.exe` (Steam mag open staan, is nog niet nodig).
2. Kies in het startmenu:
   - **Solo spelen**
   - **Hosten**: je IP-adres staat daarna linksboven in beeld. Geef dat aan de anderen.
   - **Meedoen**: typ het IP van de host en klik op Meedoen.

**Samen spelen gaat voorlopig via het netwerk thuis (LAN).** Spelen Ian en Anir van thuis uit, dan moet de host poort **24565 (UDP)** openzetten op zijn router, of jullie gebruiken samen een virtueel LAN zoals Tailscale of ZeroTier (gratis): dan vul je het Tailscale-IP van de host in. Uitnodigen via Steam, zonder gedoe met IP's, komt later (M4).

## Besturing

| Toets | Wat |
|---|---|
| ZQSD / muis / spatie | lopen, kijken, springen |
| Linkermuis (vasthouden) | graven met het actieve gereedschap |
| 1 / 2 / wieltje | houweel / boor T1 |
| E | vondst oppakken of neerzetten, knop of rail bedienen |
| Linkermuis (terwijl je draagt) | gooien |
| V | vliegen aan/uit (om snel rond te kijken) |
| F1 | tuning-menu (alle gevoel-waarden) |
| F3 | infopaneel aan/uit |
| Esc | muis loslaten |

## Wat er is

- **Houweel**: graaft klei (bovenste ±25 m). Op hardere rots ketst het af.
- **Boor T1**: graaft ook zandsteen. Snel en luid, raakt oververhit, je loopt trager.
- **Vondsten**: 12 soorten, elk in een bleke korst. Klei: rommel en munten; zandsteen: botten en een oude mijnwerkerslamp; diep zandsteen (net boven het graniet): ook geodes en goud. Er liggen er 5 ondiep rond de start. Het vizier wordt **geel** als je op een korst mikt.
  - Houweel: 4 slagen, de vondst blijft gaaf.
  - Boor: sneller, maar de vondst verliest gaafheid, en dus waarde.
- **Dragen**: E. Zware stukken maken je trager; met twee dragen gaat sneller. Hard laten vallen of gooien kost gaafheid.
- **De Mol** (jullie boormachine en basis) staat bij de start voor je, met de laadklep open. Loop de klep op.
  - **Besturen:** E op de stoel in de cabine. W/S gas, A/D draaien, spatie/Ctrl neus omhoog/omlaag, **C buitenzicht**, H toeter. Rondkijken met de muis; E op een knop drukt hem in, E ergens anders = uitstappen.
  - **Autopiloot:** de gele knoppen 20 M / 40 M / 60 M. Hij boort een spiraal naar beneden en opent onderaan de klep.
  - **Laadruim** (achteraan): wat erin ligt, rijdt mee en telt.
  - **Vertrekhendel** (rood, rechts op de console): 10 s aftellen, daarna rijdt hij vanzelf zijn spoor terug naar boven. Wie niet aan boord is, klimt te voet naar boven. Boven wordt bijgetankt.
  - **Sonar** (de ronde groene beeldbuis rechts van het camerascherm): vage blips van vondsten tot 24 m ver. Groter = zwaarder, ▲/▼ = boven of onder de Mol. Rechts staat het dichtstbijzijnde doel: afstand, richting op de klok (12 uur = vooruit) en hoogte. In buitenzicht staat de sonar rechtsonder.
  - Rijdt de boorkop in een vondst, dan schept hij hem op in het laadruim, maar zwaar beschadigd (30%). Bij "! DICHTBIJ" dus beter stoppen en zelf uitbikken.
  - De boorkop (T1) kan klei en zandsteen aan; op graniet (vanaf ±70 m) blokkeert hij, en ook voor de buitenmuur van de put stopt hij ("! RAND PUT").

Er is nog **geen** opdracht, geld, lava, depot of museum: dat is M3.

## Laat na het spelen weten

1. **Graven met het houweel**: tempo, gevoel van een slag, geluid. Te traag, te snel, goed?
2. **Boren**: voelt de boor krachtig? Is de hitte leuk of irritant?
3. **Uitbikken**: herken je een korst? Is de afweging houweel (veilig) tegenover boor (snel, schade) interessant?
4. **Dragen**: voelt oppakken, dragen en gooien goed? Samen dragen geprobeerd?
5. **De Mol**: rijden, afdalen, laadruim, terug naar boven: begrijpelijk en leuk? Hoe ziet hij eruit?
6. **Wat was het leukste moment, en wat het meest irritante?**
7. Alles wat vreemd liep (vastzitten, dingen die verdwijnen, haperingen): graag met wat je deed.

Waarden die je in F1 aanpast en bewaart, komen in `%APPDATA%\Godot\app_userdata\Diepgang\tuning\`. Stuur die bestanden mee als je iets beter vond.
