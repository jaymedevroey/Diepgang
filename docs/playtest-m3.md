# Diepgang — playtest (versie 0.11.0)

**Vraag: voelt een volledige dienst als een spel?** Een opdracht kiezen, droppen, graven, overleven tot je terug bent, en wat je vond verkopen.

## Starten

1. Start `Diepgang.exe`.
2. Kies **PLAY SOLO**, **HOST** of **JOIN**.
3. Iedereen moet **dezelfde versie** hebben. Die staat linksonder in het startmenu. Bij een andere versie weigert het spel met een melding.

## Samen spelen over het internet

### Tailscale (aangeraden)

1. **Installeren.** Iedereen installeert Tailscale (tailscale.com/download) en logt in.
2. **Uitnodigen.** De host nodigt de anderen uit via login.tailscale.com/admin, dan Users, dan "Invite users".
3. **Hosten.** De host kiest HOST en drukt Esc. In het pauzemenu staat het adres naast **Tailscale:** (het begint met `100.`).
4. **Meedoen.** De anderen kiezen JOIN en typen dat adres in.
5. **Firewall.** De eerste keer dat je host, vraagt Windows of Diepgang het netwerk mag gebruiken. Kies **Toestaan**, en vink privé én openbaar aan.
6. **Lukt het niet?**
   - Doe `ping 100.x.x.x` in een opdrachtprompt.
   - Antwoord maar geen verbinding? Dan blokkeert de firewall: Windows-beveiliging > Firewall > Een app toestaan > Diepgang.
   - Geen antwoord? Dan zit je nog niet in hetzelfde Tailscale-netwerk.

### Port forwarding (zonder Tailscale)

1. **Vast adres.** Geef je pc een vast adres in je modem. Je adres staat in het pauzemenu naast "Same network".
2. **De regel.** Maak in je modem een regel aan voor **UDP-poort 24565**, naar dat adres.
3. **Firewall.** Laat Diepgang toe, zoals hierboven.
4. **Adres doorgeven.** Je vrienden typen je publieke IP in. Dat vind je op `whatismyip.com`.
5. **Werkt het niet?** Deelt je provider één adres over veel klanten (CGNAT), dan werkt port forwarding niet. Gebruik dan Tailscale.

## Nieuw in 0.11

Nog altijd zonder geluid: dat komt er met echte opnames, niet met nagemaakte piepjes.

- **De worm heet nu the Gulper** en heeft een nieuw model.
  - Hij **grijpt wie hij raakt** en sleurt je mee.
  - Loskomen kan op drie manieren: een maat slaat hem 2× met het houweel, iemand gooit een baken, of je spartelt zelf (spatie).
  - Op de sonar en de HUD is hij rood-oranje, met de afstand erbij.
  - Midden in de dienst duwt hij de Mol enkel; de grote aanval komt bij het vertrek.
  - Wie aan het stuur zit, schudt hem los door links-rechts te sturen.
- **Lichtbakens (G)** gooi je nu als een fakkel. De gloeiende ring op de vloer is de veilige zone.
- **Klappen voel je:**
  - Wie omvergaat, ziet het beeld even stilvallen, met een flits.
  - Daarna glijdt de camera naar buiten, zonder in je robot of de Mol te zitten.
  - Een beving en een instorting kondigen zich langer aan.
  - Gas waarschuwt met een gele schermrand.
- **Samen dragen:**
  - Zware stukken hebben twee handgrepen, en je staat dichter bij elkaar.
  - Op elke planeet ligt er nu iets zwaars: een loonzak op Rustbowl, een reuzengeode op Crystal Moon.
- **Verkopen:**
  - Een band brengt je vondsten van de Mol door de taxatiepoort.
  - Elk stuk krijgt een groot scherm met de prijs.
  - Al in het veld zie je een schatting ('€460–800 ESTIMATE').
  - Gekochte upgrades zie je op de Mol en op je gereedschap.
  - Het laadruim groeit met de ploeg: 60 kg alleen, tot 120 kg met vier.
- **Opdrachten:** het risico hangt af van de planeet (Rustbowl veilig, Crystal Moon gevaarlijk). Upgrades kosten meer en het kwartaaldoel is wat hoger (alleen: €2.400 in het eerste kwartaal).
- **Beeld:**
  - De planeten hebben meer kleur en reliëf.
  - De landingsplek heeft containers en een eigen verhaal per planeet.
  - De drop is gefilmd als een film.
  - Grotten hebben decor per planeet, en erts en korst zien er nieuw uit.
  - De Mol boort sneller als de neus omlaag staat.
- **Uitnodigen:** de adressenlijst toont geen adressen van virtuele machines meer.

## Nieuw in 0.10

- **Gevaar:**
  - **De graafworm** komt af op lawaai: boren, de Mol, PINGs, de toeter. Op de sonar zie je hem als een grote stip. Hij duikt op in open ruimtes, slokt losse buit op en gooit je omver.
  - **Je eigen bescherming:** je hebt 3 lichtbakens (G) die hem op afstand houden.
  - **Gas** zit vanaf 35 m. Gele bellen ontploffen door vonken van de boor.
  - **Instortingen** worden waarschijnlijker naarmate je dieper gaat.
  - **Bevingen** gooien echte rotsen en duwen je omver.
- **Neergaan:**
  - Robots hebben levens. Neer betekent ragdoll: je ploeg heeft 90 s om je naar de Mol te dragen.
  - Smelt je, dan vlieg je als drone mee tot het einde.
  - Een vertrekkende Mol lokt de worm.
- **Geld en voortgang:**
  - Na het ophalen draag je je vondsten door de **taxatiepoort**. Daar wordt elk stuk één voor één onthuld, en je verkoopt aan het **verkoopluik**.
  - Een volledig skelet levert dubbel op.
  - Upgrades koop je aan het gereedschapsrek, de uitgiftebalie en de Mol-werf:
    - de boor T2 (graniet en kristal);
    - de boorkop T2 voor de Mol;
    - een handscanner (Q);
    - een helmlamp;
    - een groter laadruim.
  - Het laadruim heeft een gewichtslimiet.
  - Schuld bevriest je upgrades.
- **Planeten:**
  - **Rustbowl** heeft kampen met rommel.
  - **Fossil World** heeft Titan-skeletten in stukken. Zware stukken draag je met twee; alleen kan je ze enkel slepen.
  - **Crystal Moon** heeft breekbare, gloeiende kristallen, meer gas en een wakkere worm.
- **Gevoel en beeld:**
  - Je kan sprinten en hurken.
  - Je ziet je handen.
  - Een vondst vrijleggen is een moment.
  - De Mol is zwaar en traag.
  - De drop toont de horizon.
  - Er zijn grotten met eigen licht.
  - De hub en de planeten hebben veel meer detail.
  - Alle tekst staat in het Engels.

## Een dienst

1. **Opdracht kiezen.** Druk E aan de opdrachttafel op de brug. Elke kaart toont een planeet, een risico en 2 à 3 voorwaarden.
2. **Droppen.** Ga in de Mol staan en trek aan de hendel (LAUNCH). Spatie slaat de film over; in co-op moet iedereen stemmen.
3. **Graven.**
   - Het houweel is stil en veilig.
   - De boor is snel, maar luid en beschadigt vondsten.
   - Erts gaat in de trechter van de Mol, vondsten in het laadruim.
4. **Overleven.**
   - Het magma stijgt (HUD bovenaan), en lawaai maakt onrust en lokt de worm.
   - Hou elkaar in het oog: wie neer is, moet gedragen worden.
5. **Terug.** Trek aan de hendel in de Mol. Wie niet aan boord is, blijft achter.
6. **Verkopen.** Draag elk stuk door de taxatiepoort en verkoop het aan het luik. Koop daarna upgrades.

Een kwartaal telt 3 diensten. Haal je het doel niet, dan krijg je een boete (schuld).

## Besturing

| Toets | Wat |
|---|---|
| ZQSD / muis / spatie | lopen, kijken, springen |
| Shift / Ctrl | sprinten / hurken |
| Linkermuis (vasthouden) | graven met het actieve gereedschap |
| 1 / 2 / wieltje | houweel / boor |
| Q | handscanner (als je hem gekocht hebt) |
| G | lichtbaken gooien (tegen de worm) |
| Spatie (gegrepen) | spartelen om los te komen |
| E | gebruiken: knop, terminal, oppakken, neerzetten, mee dragen, erts storten, verkopen |
| Linkermuis (terwijl je draagt) | gooien |
| F | sonar-PING in de Mol (4 per dienst, luid) |
| In de stoel | ZQSD gas en draaien, spatie/Ctrl neus, C buitenzicht, H toeter, E uitstappen; links-rechts schudt de worm los |
| Esc | pauze, instellingen, adressen om uit te nodigen |

## Laat na het spelen weten

1. **Gevaar:** is er nu genoeg? Te veel? Wanneer was het het spannendst?
2. **De worm:** zag je hem komen? Was het eerlijk? Kwam je los toen hij je greep?
3. **Geld:** wilde je iets kopen? Haalde je het doel?
4. **Samen:** moest je samenwerken, bijvoorbeeld bij zware stukken of iemand redden?
5. **Gevoel:** lopen, graven, de Mol, de drop. Wat voelde goed, wat niet?
6. **Fouten:** wat liep er mis, en waar?
