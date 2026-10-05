extends RefCounted
## Teksten van DIG-nieuws, de tv op het werkdek (HubScreens). Aanvullen mag vrij: elke lijst
## mag groeien, de tv kiest willekeurig (nooit twee keer na elkaar dezelfde).
## - "kop|onderregel": de onderregel is optioneel.
## - Reclame: "PRODUCT|slogan|prijs".
## - Plaatshouders worden ingevuld met de echte stand van de firma:
##   {planet} {cash} {earned} {quota} {quarter} {shift} {shifts} {left} {left_shifts} {rep} {contract}
##   {risk} {magma} {replacement} {robots} {temp} {share} {up} {down}
## Kort houden: een kop past in twee regels (± 50 tekens), een onderregel in één (± 60).
## Geen symbolen als ▲ ► ● ■: het schermlettertype (VT323) kent ze niet (€ × · é ë wel).
## Tekst in het Engels (2026-10-05), met een decimale punt in prijzen.

## Nieuwskoppen (het robotje achter de desk leest ze voor).
const NEWS: Array[String] = [
	"Head office boosts safety: helmets now optional|The savings go straight into the board's bonus pot.",
	"Robot finds fossil, is not allowed to keep it|Legal: 'Everything you dig up belongs to DIG.'",
	"Magma 'less hot than expected', says manager|He has never been down there.",
	"DIG wins Most Improved Employer award|Last year dead last, this year second to last.",
	"The Magpie's canteen closes for lack of diners|Meals will still be billed as usual.",
	"Competitor left a garden gnome on {planet}|Our lawyers are checking whether we can sell it.",
	"Board of Directors approves its own pay rise|Unanimous. The intern abstained.",
	"New policy: melt, and you pay for your replacement|{replacement} per robot. From your funds, not ours.",
	"Breaks go digital|They last zero seconds and count as working time.",
	"Survey: 9 out of 10 robots satisfied|The tenth has been replaced.",
	"Head office moves to a planet without magma|'Pure coincidence', says a spokesperson.",
	"The Mole gets new seats|Same seats, new sticker.",
	"Robot union founded and dissolved the same day|The chairman has been 'reassigned'.",
	"{planet} officially 'largely uninhabited'|The inhabitants disagree, but cannot afford a lawyer.",
	"Robot works 400 shifts without a single complaint|Turns out its voice module was broken.",
	"Management 'cautiously optimistic' about figures|Mostly about its own bonus.",
	"DIG now calls looting 'heritage management'|The profits remain the same.",
	"Old TV found in the ground on {planet}|It is showing this very program. Nobody knows how.",
	"Director gives speech on the value of hard work|From his hammock, on another planet.",
	"DIG complaints line now open day and night|Nobody answers it, day and night.",
	"Robot asks for a raise, gets a sticker|It is a very nice sticker, though.",
	"Insurance now covers magma too|Except when it is hot.",
	"Crew of {robots} sets record: nobody left behind|Head office is investigating what went wrong.",
	"Head office drops the word 'safe'|It was not used anywhere else anyway.",
	"New claim: {contract}|Risk: {risk}. Head office says 'good luck, or not'.",
]

## Reclame: PRODUCT|slogan|prijs.
const ADS: Array[String] = [
	"DIG HELMET LITE|Now without the helmet. Lighter than ever.|€49.99",
	"REPLACEMENT ROBOT|Just like the last one, only newer.|{replacement} each",
	"MAGMA CREAM SPF 5|For those who want to stay a bit longer.|€19.95",
	"THE MOLE PREMIUM|The same Mole, but you get to say 'premium'.|€9,999 a month",
	"DIG COFFEE|Brewed with real groundwater from {planet}.|€6.50 a sip",
	"OXYGEN PLUS|Breathe without the ads.|€4.99 a minute",
	"PICKAXE DELUXE|Hits just as hard. Costs twice as much.|€299",
	"DIG INSURANCE|We cover everything. Except what happens.|from €12 a shift",
	"ROBOT OIL 'OLD-FASHIONED'|Recycled from old-fashioned robots.|€3.20 a liter",
	"CUDDLY MOLE|For the kids back home. You have no home.|€24.99",
	"RECHARGE BREAK PLUS|Thirty extra seconds of rest per shift.|€15 a break",
	"DIG UMBRELLA|Against dust, rain and responsibility.|€34.50",
]

## Veiligheidsmededelingen (die vooral geld besparen).
const SAFETY: Array[String] = [
	"Fire extinguishers replaced by a photo of one|In case of fire: hold the photo firmly.",
	"Railings removed to save weight|Please simply do not fall.",
	"During a quake: stay calm and keep working|Panic costs time, and time costs money.",
	"The magma is hot|This is now in the handbook. Questions cost €5.",
	"Emergency exits are now pay-per-use|Prices at the exit.",
	"Melting? Leave your badge somewhere safe first|The badge is property of DIG.",
	"Alarm lights switched off to save power|So, no more alarms. Good news!",
	"Always wear your helmet|Helmet not included. See advertisement.",
	"Lift heavy finds with your knees|No knees? Borrow a colleague's.",
	"Leave no colleague behind in the pit|A replacement costs {replacement}. Per colleague.",
	"Noise makes quakes, quakes make magma|Magma makes costs. Whisper.",
]

## Het weer op de planeet van de opdracht.
const WEATHER: Array[String] = [
	"Dry, dusty, 100% chance of magma|Crisp on the surface. Down deep: 'yes'.",
	"Wind from the south, dust from every direction|Visibility: poor. Productivity: expected as usual.",
	"Magma rising ×{magma} today|Recommended attire: nothing that melts.",
	"Tomorrow: like today, but with fewer robots|The day after: new robots.",
	"Quakes expected wherever there is noise|Dig quietly. Or quickly. Ideally both.",
	"Clear skies above, magma below|In between: you.",
]

## Beursnieuws over het DIG-aandeel.
const SHARES: Array[String] = [
	"DIG shares +{up}% after robots replaced|Analysts: 'Efficiency!'",
	"Market reacts positively to bad news|Bad for you, good for the market.",
	"Shares down {down}%: management cuts the coffee|The stock recovers immediately.",
	"DIG shares rise, nobody knows why|The accountant is on holiday. For three years now.",
	"Dividend paid out to shareholders|The robots get a round of applause. Pre-recorded.",
]

## Werknemer van het kwartaal (de plek blijft leeg).
const EMPLOYEE: Array[String] = [
	"Nobody qualified. Try harder.",
	"Last quarter's winner melted during the ceremony.",
	"Prize: a photo frame. Photo not included.",
	"Next quarter, maybe you. Probably not.",
	"Candidates judged on silence and cost.",
]

## Commentaar bij de quota, van slecht naar goed (deel van de quota: < 1/3, < 2/3, < 1, gehaald).
const QUOTA_REMARKS: Array[String] = [
	"Far behind. Replacements are already being discussed.",
	"Behind schedule. Head office is noting your names.",
	"Almost. 'Almost' is not an amount.",
	"Quota met. So the next target goes up.",
]

## Lopende balk onderaan (kort).
const TICKER: Array[String] = [
	"DIG: we dig, you pay",
	"Crew funds: {cash}",
	"Quarter {quarter}, shift {shift}/{shifts}: {earned} of {quota}",
	"Reputation with head office: {rep}",
	"Replacement robots now {replacement} each (price may rise for no reason)",
	"Found objects are property of DIG",
	"The canteen is closed. The canteen was never open.",
	"Complaints? Channel 0. Channel 0 does not exist.",
	"Leave nobody behind: a replacement costs {replacement}",
	"Weather on {planet}: dusty, magma rising",
	"DIG shares: {share} (+{up}%)",
	"Head office: 'We are proud of you.' (automated message)",
	"Overtime is not paid, but it is counted",
	"Tip of the day: digging goes faster downhill",
	"Found: 1 garden gnome. Owner may come forward and pay.",
	"New rule: laughing in The Mole costs €1 per laugh",
	"This program is brought to you by DIG",
	"Contract: {contract}",
	"{left_shifts} left this quarter",
	"Tomorrow on DIG News: more of the same",
]
