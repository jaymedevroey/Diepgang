extends RefCounted
## Teksten van DIG-nieuws, de tv op het werkdek (HubScreens). Aanvullen mag vrij: elke lijst
## mag groeien, de tv kiest willekeurig (nooit twee keer na elkaar dezelfde).
## - "kop|onderregel": de onderregel is optioneel.
## - Reclame: "PRODUCT|slogan|prijs".
## - Plaatshouders worden ingevuld met de echte stand van de firma:
##   {planet} {cash} {earned} {quota} {quarter} {shift} {shifts} {left} {rep} {contract}
##   {risk} {magma} {replacement} {robots} {temp} {share} {up} {down}
## Kort houden: een kop past in twee regels (± 50 tekens), een onderregel in één (± 60).
## Geen symbolen als ▲ ► ● ■: het schermlettertype (VT323) kent ze niet (€ × · é ë wel).

## Nieuwskoppen (het robotje achter de desk leest ze voor).
const NEWS: Array[String] = [
	"Hoofdkantoor verhoogt veiligheid: helmen nu optioneel|De besparing gaat naar de bonuspot van de directie.",
	"Robot vindt fossiel, mag het niet houden|Juridische dienst: 'Alles wat je opgraaft, is van DIG.'",
	"Magma 'minder heet dan gedacht', zegt manager|Hij was nog nooit beneden.",
	"DIG wint prijs voor Meest Verbeterde Werkgever|Vorig jaar laatste, nu voorlaatste.",
	"Kantine van De Ekster sluit wegens gebrek aan eters|Het menu blijft wel betalend.",
	"Concurrent liet tuinkabouter achter op {planet}|Onze juristen onderzoeken of we hem mogen verkopen.",
	"Raad van Bestuur keurt eigen loonsverhoging goed|Unaniem. De stagiair onthield zich.",
	"Nieuw beleid: wie smelt, betaalt zijn vervanging|{replacement} per robot. Uit uw kas, niet uit de onze.",
	"Pauzes voortaan digitaal|Ze duren nul seconden en tellen als werktijd.",
	"Onderzoek: 9 op 10 robots tevreden|De tiende werd vervangen.",
	"Hoofdkantoor verhuist naar planeet zonder magma|'Puur toeval', aldus de woordvoerder.",
	"De Mol krijgt nieuwe zetels|Dezelfde zetels, met een nieuw stickertje.",
	"Vakbond van robots opgericht en meteen ontbonden|De voorzitter werd 'herbestemd'.",
	"{planet} officieel 'grotendeels onbewoond'|De bewoners zijn het oneens, maar hebben geen advocaat.",
	"Robot werkt 400 diensten zonder één klacht|Zijn spraakmodule bleek stuk.",
	"Directie 'voorzichtig optimistisch' over cijfers|Vooral over haar eigen bonus.",
	"DIG noemt plunderen voortaan 'erfgoedbeheer'|De opbrengst blijft dezelfde.",
	"Oude tv gevonden in de grond van {planet}|Hij toont dit programma. Niemand weet hoe.",
	"Directeur geeft toespraak over hard werken|Vanuit zijn hangmat, op een andere planeet.",
	"Klachtenlijn van DIG nu dag en nacht bereikbaar|Ze wordt dag en nacht niet opgenomen.",
	"Robot vraagt opslag, krijgt een sticker|Het is wel een mooie sticker.",
	"Verzekering dekt nu ook magma|Behalve als het warm is.",
	"Ploeg van {robots} haalt record: niemand vergeten|Het hoofdkantoor zoekt uit wat er misging.",
	"Hoofdkantoor schrapt het woord 'veilig'|Het stond toch nergens anders meer.",
	"Nieuwe concessie: {contract}|Risico {risk}. Het hoofdkantoor wenst u 'veel succes, of niet'.",
]

## Reclame: PRODUCT|slogan|prijs.
const ADS: Array[String] = [
	"DIG-HELM LITE|Nu zonder helm. Lichter dan ooit.|€49,99",
	"VERVANGROBOT|Net als de vorige, maar dan nieuw.|{replacement} per stuk",
	"MAGMACRÈME SPF 5|Voor wie toch nog even wil blijven.|€19,95",
	"DE MOL PREMIUM|Dezelfde Mol, maar u mag 'premium' zeggen.|€9.999 per maand",
	"DIG-KOFFIE|Gezet met echt grondwater van {planet}.|€6,50 per slok",
	"ZUURSTOF PLUS|Ademen zonder reclame.|€4,99 per minuut",
	"HOUWEEL DELUXE|Slaat even hard. Kost dubbel zoveel.|€299",
	"DIG-VERZEKERING|Wij dekken alles. Behalve wat gebeurt.|vanaf €12 per dienst",
	"ROBOTOLIE 'ZOALS VROEGER'|Gerecycleerd uit robots van vroeger.|€3,20 per liter",
	"KNUFFELMOL|Voor de kinderen thuis. U heeft geen thuis.|€24,99",
	"OPLAADPAUZE PLUS|Dertig seconden extra rust per dienst.|€15 per pauze",
	"DIG-PARAPLU|Tegen stof, regen en verantwoordelijkheid.|€34,50",
]

## Veiligheidsmededelingen (die vooral geld besparen).
const SAFETY: Array[String] = [
	"Brandblussers vervangen door een foto van een brandblusser|Bij brand: de foto stevig vasthouden.",
	"Leuningen weg om gewicht te sparen|Gelieve gewoon niet te vallen.",
	"Bij een beving: rustig blijven en doorwerken|Paniek kost tijd, en tijd kost geld.",
	"Het magma is heet|Dat staat nu in het handboek. Vragen kosten €5.",
	"Nooduitgangen zijn voortaan betalend|Prijs aan de uitgang.",
	"Wie smelt, legt eerst zijn badge op een veilige plek|De badge is eigendom van DIG.",
	"Alarmlichten uit om stroom te sparen|Dus nooit meer alarm. Goed nieuws!",
	"Draag altijd uw helm|Helm niet inbegrepen. Zie reclame.",
	"Til zware vondsten met de knieën|Geen knieën? Leen die van een collega.",
	"Laat geen collega achter in de put|Vervanging kost {replacement}. Per collega.",
	"Lawaai maakt bevingen, bevingen maken magma|Magma maakt kosten. Fluister.",
]

## Het weer op de planeet van de opdracht.
const WEATHER: Array[String] = [
	"Droog, stoffig, kans op magma 100%|Aan de oppervlakte fris, in de diepte: 'ja'.",
	"Wind uit het zuiden, stof uit alle richtingen|Zicht: slecht. Productiviteit: verwacht normaal.",
	"Het magma stijgt vandaag ×{magma}|Aanbevolen kledij: niets wat smelt.",
	"Morgen: zoals vandaag, maar met minder robots|Overmorgen: nieuwe robots.",
	"Bevingen verwacht bij lawaai|Graaf zacht. Of snel. Liefst allebei.",
	"Opklaringen boven, magma onder|Midden: u.",
]

## Beursnieuws over het DIG-aandeel.
const SHARES: Array[String] = [
	"DIG-aandeel +{up}% na vervangen van robots|Analisten: 'Efficiëntie!'",
	"Beurs reageert positief op slecht nieuws|Slecht voor u, goed voor de beurs.",
	"Aandeel {down}% lager: directie schrapt de koffie|Het aandeel herstelt meteen.",
	"DIG-aandeel stijgt, niemand weet waarom|De boekhouder is op vakantie. Al drie jaar.",
	"Dividend uitbetaald aan de aandeelhouders|De robots krijgen applaus. Opgenomen, niet live.",
]

## Werknemer van het kwartaal (de plek blijft leeg).
const EMPLOYEE: Array[String] = [
	"Niemand kwam in aanmerking. Probeer harder.",
	"De vorige winnaar smolt tijdens de uitreiking.",
	"Prijs: een fotolijstje. Foto niet inbegrepen.",
	"Volgend kwartaal misschien u. Waarschijnlijk niet.",
	"Kandidaten beoordeeld op stilte en kostprijs.",
]

## Commentaar bij de quota, van slecht naar goed (deel van de quota: < 1/3, < 2/3, < 1, gehaald).
const QUOTA_REMARKS: Array[String] = [
	"Ver achter. Er wordt al over vervanging gesproken.",
	"Achter op schema. Het hoofdkantoor noteert uw namen.",
	"Bijna. 'Bijna' is geen bedrag.",
	"Gehaald. Het volgende doel wordt dus hoger.",
]

## Lopende balk onderaan (kort).
const TICKER: Array[String] = [
	"DIG: wij graven, u betaalt",
	"Kas van de ploeg: {cash}",
	"Kwartaal {quarter}, dienst {shift}/{shifts}: {earned} van {quota}",
	"Reputatie bij het hoofdkantoor: {rep}",
	"Vervangrobots nu {replacement} per stuk (prijs kan zonder reden stijgen)",
	"Gevonden voorwerpen zijn eigendom van DIG",
	"De kantine is gesloten. De kantine was nooit open.",
	"Klachten? Kanaal 0. Kanaal 0 bestaat niet.",
	"Laat niemand achter: vervanging kost {replacement}",
	"Weer op {planet}: stoffig, magma stijgend",
	"Aandeel DIG: {share} (+{up}%)",
	"Hoofdkantoor: 'Wij zijn trots op u.' (automatisch bericht)",
	"Overuren worden niet betaald, wel geteld",
	"Tip van de dag: graven gaat sneller naar beneden",
	"Gevonden: 1 tuinkabouter. Eigenaar mag zich melden en betalen.",
	"Nieuwe regel: lachen in de Mol kost €1 per keer",
	"Dit programma wordt u aangeboden door DIG",
	"Opdracht: {contract}",
	"Nog {left} dienst(en) dit kwartaal",
	"Morgen op DIG-nieuws: hetzelfde",
]
