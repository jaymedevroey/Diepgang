# Diepgang — playtest M3 (de kernlus, versie 0.9.1)

**Vraag: voelt een volledige dienst als een spel?** Opdracht kiezen, droppen, graven en delven, het magma voelen komen, op tijd terug, en het rapport lezen.

## Starten

1. Start `Diepgang.exe`.
2. Kies **PLAY SOLO**, **HOST** of **JOIN** (IP van de host). Samen spelen gaat via het IP-adres van de host: in hetzelfde netwerk zijn LAN-IP, over het internet zijn publieke IP met port forwarding (zie hieronder). Iedereen moet **dezelfde versie** hebben (staat linksonder in het startmenu); het spel weigert anders met een melding.

## Samen spelen over het internet (port forwarding)

De host (één pc) doet dit één keer:

1. **Je eigen IP in het netwerk.** Start het spel, kies HOST, druk Esc: onder het pauzemenu staat je adres (bv. `192.168.1.23`). Zorg dat je pc dat adres houdt: in je modem bij "DHCP"/"vaste IP" je pc reserveren.
2. **Port forwarding in je modem** (meestal op `192.168.1.1` of `192.168.0.1`; bij Telenet via Mijn Telenet, bij Proximus in de Internet Box onder "Port forwarding"): een regel **UDP**, externe poort **24565**, interne poort **24565**, naar het adres uit stap 1.
3. **Windows Firewall.** De eerste keer dat je host, vraagt Windows of Diepgang het netwerk mag gebruiken: kies **Toestaan** (privé en openbaar). Gemist? Windows-beveiliging > Firewall > Een app toestaan > Diepgang.
4. **Je publieke IP**: surf naar `whatismyip.com` (of kijk in je modem bij "WAN"). Dat adres geef je aan je vrienden; zij kiezen JOIN en typen het in.
   - Staat in je modem een ander WAN-adres dan op die site, of begint het met `100.64`–`100.127` of `10.`? Dan deelt je provider één adres over meerdere klanten (CGNAT) en werkt port forwarding niet. Gebruik dan Tailscale.
   - Je kan je eigen publieke IP vaak niet vanuit je eigen netwerk testen: laat een vriend (of je gsm via 4G/5G) verbinden.

Vrienden: pak dezelfde zip uit, start `Diepgang.exe`, JOIN, en typ het publieke IP van de host.

**Sinds 0.8 staat alle tekst in het spel in het Engels** (het schip heet nu *The Magpie*, de Mol *The Mole*). Je begint op **De Ekster**, in het laadrek achteraan het schip. **Sinds 0.5:** de echte binnenkant, zoals de Super Destroyer van Helldivers, met DIG-humor. Loop vooruit: het werkdek (de tv met DIG-nieuws, vier nissen voor latere upgrades), de gang (spuitcabine, firmabord), de brug met de opdrachttafel, en dan de trap af naar de hangar met de Mol voor het grote raam.

## Een dienst

1. **Opdracht kiezen**: E aan de opdrachttafel op de brug (de ronde tafel met het hologram, op de verhoging). Drie concessies, elk met een risico: meer risico = meer geld, maar het magma stijgt sneller. Elke opdracht ligt op een van drie planeten: **Rustbowl** (een reuzenkrater met een verlaten mijnput), **Fossil World** (witte badlands met een reuzenskelet) of **Crystal Moon** (een violet bekken met een kristalader). Kiezen laadt die planeet (±2 s, sinds 0.8). **Nieuw in 0.8:** de planeet loopt door tot in het speelgebied (duinen en stofsporen, een droge bedding, een korst met zeshoeken).
2. **Droppen**: stap in de Mol en trek aan de hendel (LAUNCH, rechts op de console; de HUD wijst hem aan). Na het aftellen (5 s als iedereen in de Mol zit, anders 8 s) valt de Mol door de lanceerschacht, zie je hem van buiten naar de planeet vallen en remmen, en na de landing krijg je de besturing terug. **Nieuw in 0.6:** de hele drop is een korte sequentie met beeld en geluid; de eerste drop is de lange versie, daarna een kortere. **Spatie** slaat het buitenbeeld over (in co-op moet iedereen in de Mol op spatie drukken).
3. **Graven en delven**: houweel (stil, veilig voor vondsten), boor (snel, maar luid en beschadigt vondsten). Vondsten naar het laadruim, erts in de trechter van de Mol.
4. **Het magma** stijgt van onderen: de eerste 2 minuten niet, daarna steeds sneller. Het statusscherm links in de Mol toont hoe ver het onder de Mol staat; dichtbij verschijnt het ook bovenaan in beeld. Wie erin zakt, smelt (een vervanger staat in de Mol, dat kost geld). Op −60 m vertrekt de Mol vanzelf: noodophaling.
5. **Onrust**: lawaai (boren, de Mol, de sonar-PING) maakt de planeet onrustig. Vol = een **beving**: eerst een waarschuwing, dan vallen er rotsen in de gebarsten zones (net van barsten en stof aan het plafond), en het magma maakt een sprong. Het houweel is stil.
6. **Terug**: de vertrekhendel in de Mol. Hij rijdt zijn spoor terug, de grijper van De Ekster pikt hem op. Wie niet in de Mol zit, blijft achter (en kost een vervanger).
7. **Incidentrapport**: wat verkocht werd, de bonus van de opdracht, de kosten, en hoe je ervoor staat in het kwartaal. Drie diensten per kwartaal: haal je het doel niet, dan krijg je een boete.

De firma (kas, kwartaal) wordt bewaard. Het verkopen gebeurt nu nog vanzelf: de taxatiepoort, het verkoopluik, de automaat, de kast en de upgrades staan er al, maar werken nog niet (E geeft uitleg). Het museum komt later.

## Besturing

| Toets | Wat |
|---|---|
| ZQSD / muis / spatie | lopen, kijken, springen |
| Linkermuis (vasthouden) | graven met het actieve gereedschap |
| 1 / 2 / wieltje | houweel / boor |
| E | gebruiken: knop, terminal, oppakken, neerzetten, erts storten |
| Linkermuis (terwijl je draagt) | gooien |
| **F** | **sonar-PING** (in de Mol): scherp beeld tot 24 m, maar luid |
| In de stoel | ZQSD gas en draaien, spatie/Ctrl neus, C buitenzicht, H toeter, E uitstappen |
| V | vliegen aan/uit (om rond te kijken) |
| F1 / F3 | tuning-menu / infopaneel |
| Esc | pauze en instellingen |

## Laat na het spelen weten

1. **Opdracht en kas**: begrijp je wat je moet doen en waarom? Is het doel te hoog, te laag?
2. **Het magma**: voel je de druk? Te traag, te snel, eerlijk? Zie je het komen?
3. **Bevingen**: zag je de zones? Was de waarschuwing genoeg? Leuk of irritant?
4. **Sonar en PING**: gebruik je de PING? Is 12 m stil te weinig?
5. **De drop en het ophalen**: het aftellen, de val, de landing, de grijper. Voelt het spannend, en wordt het niet saai bij de vijfde keer? Kloppen de geluiden (allemaal met code gemaakt, nog door niemand beluisterd)?
6. **De binnenkant**: voelt het als een schip waar je graag rondloopt? Vind je de weg (laadrek → brug → Mol)? Lees je de tv en de bordjes? Wat ontbreekt er, wat is te veel?
7. **Leukste en meest irritante moment.**
8. Alles wat vreemd liep (vastzitten, zwart beeld, haperingen), graag met wat je deed.

Bewaarde firma: `%APPDATA%\Godot\app_userdata\Diepgang\saves\firma.json` (verwijderen = opnieuw beginnen). Tuning-waarden: `...\Diepgang\tuning\`.
