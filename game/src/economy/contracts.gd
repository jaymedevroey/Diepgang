class_name Contracts
extends RefCounted
## Voorwaarden van een opdracht (ontwerp-10, ui-03): elke kaart op de terminal krijgt 2-3 regels die
## het spelen veranderen, passend bij de planeet. Een voorwaarde is een Dictionary {"id": ...} (met
## "kind" voor een doelvondst), zodat ze door het netwerk en in de save kan.
##
## Drie soorten:
## - Een troef van de planeet (altijd één): wat hier meer oplevert of meer in de grond zit.
##   Rustbowl: erts, rommel; Fossil World: botten, fossielbedden; Crystal Moon: geodes, ertsaders.
## - Een risico (MEDIUM één, HIGH twee): onstabiele grond (bevingen komen vanzelf), een hete kern
##   (sneller magma), krappe brandstof voor de Mol. Risico kost iets in het midden van de dienst.
## - Een doelvondst (soms): het hoofdkantoor wil één bepaalde soort, met een bonus bij de taxatie.
## Hoog risico betaalt meer (Company.pay_factor) en heeft dus ook meer risicoregels.
## Getallen in economy.cfg (mod_*). Wat de wereld verandert (extra bedden en aders) gebeurt bij het
## maken van de wereld, op elke peer met dezelfde voorwaarden (Company.world_mods).

const BONE_BUYER := "bone_buyer"
const FOSSIL_BEDS := "fossil_beds"
const GEODE_BUYER := "geode_buyer"
const ORE_VEINS := "ore_veins"
const ORE_PRICE := "ore_price"
const SCRAP_BUYER := "scrap_buyer"
const TARGET := "target"
const UNSTABLE := "unstable"
const HOT_CORE := "hot_core"
const LOW_FUEL := "low_fuel"

const PERKS := [
	[ORE_PRICE, SCRAP_BUYER, ORE_VEINS], # Rustbowl
	[BONE_BUYER, FOSSIL_BEDS], # Fossil World
	[GEODE_BUYER, ORE_VEINS], # Crystal Moon
]
const RISKS := [UNSTABLE, HOT_CORE, LOW_FUEL]
## Doelvondsten per planeet (FindKinds.Kind).
const TARGETS := [
	[FindKinds.Kind.GNOME, FindKinds.Kind.TV, FindKinds.Kind.COINS, FindKinds.Kind.LAMP],
	[FindKinds.Kind.SKULL, FindKinds.Kind.FEMUR, FindKinds.Kind.CLAW, FindKinds.Kind.TITAN_SKULL], # F3: ook een titanschedel (met twee)
	[FindKinds.Kind.GEODE, FindKinds.Kind.GOLD, FindKinds.Kind.GLOWSHARD, FindKinds.Kind.BLOOM], # F3: breekbare kristallen
]
## Toon van een regel op de kaart.
enum Tone { GOOD, RISK, TARGET }


## Voorwaarden voor een nieuwe opdracht (uit de rng van de firma: elke peer krijgt ze via de host).
static func roll(rng: RandomNumberGenerator, planet: int, risk: int) -> Array:
	var p := clampi(planet, 0, PERKS.size() - 1)
	var out: Array = []
	var perks: Array = PERKS[p]
	out.append({"id": perks[rng.randi() % perks.size()]})
	var risks := RISKS.duplicate()
	for i in range(risks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = risks[i]
		risks[i] = risks[j]
		risks[j] = tmp
	var n_risk: int = [0, 1, 2][clampi(risk, 0, 2)]
	for i in n_risk:
		out.append({"id": risks[i]})
	# Een doelvondst als er plaats is: altijd bij laag risico (iets om naar te zoeken), anders soms.
	var targets: Array = TARGETS[p]
	if out.size() < 3 and (risk == 0 or rng.randf() < 0.5):
		out.append({"id": TARGET, "kind": int(targets[rng.randi() % targets.size()])})
	return out


static func has(mods: Array, id: String) -> bool:
	for m in mods:
		if m is Dictionary and str(m.get("id", "")) == id:
			return true
	return false


## Factor op de waarde van een vondst van deze soort (opkopers).
static func value_factor(mods: Array, kind: int) -> float:
	var f := 1.0
	var fam := FindKinds.FAMILIES[clampi(kind, 0, FindKinds.FAMILIES.size() - 1)]
	if has(mods, BONE_BUYER) and fam == FindKinds.Family.SKELETON:
		f *= Tuning.get_f("economy", "mod_bone_buyer", 1.4)
	if has(mods, GEODE_BUYER) and (fam == FindKinds.Family.CRYSTAL or kind == FindKinds.Kind.GOLD): # F3: ook glowshard en kristalroos
		f *= Tuning.get_f("economy", "mod_geode_buyer", 1.4)
	if has(mods, SCRAP_BUYER) and fam == FindKinds.Family.JUNK:
		f *= Tuning.get_f("economy", "mod_scrap_buyer", 3.0)
	return f


static func ore_factor(mods: Array) -> float:
	return Tuning.get_f("economy", "mod_ore_price", 1.4) if has(mods, ORE_PRICE) else 1.0


static func magma_factor(mods: Array) -> float:
	return Tuning.get_f("economy", "mod_hot_core", 1.25) if has(mods, HOT_CORE) else 1.0


## Onrust per seconde die de grond zelf maakt (onstabiele grond), anders 0.
static func unrest_rate(mods: Array) -> float:
	return Tuning.get_f("economy", "mod_unstable_rate", 0.12) if has(mods, UNSTABLE) else 0.0


## Brandstof van de Mol bij de landing (deel van de tank).
static func fuel(mods: Array) -> float:
	return Tuning.get_f("economy", "mod_low_fuel", 0.65) if has(mods, LOW_FUEL) else 1.0


static func extra_beds(mods: Array) -> int:
	return Tuning.get_i("economy", "mod_fossil_beds", 4) if has(mods, FOSSIL_BEDS) else 0


static func extra_veins(mods: Array) -> int:
	return Tuning.get_i("economy", "mod_ore_veins", 8) if has(mods, ORE_VEINS) else 0


## De doelvondst (FindKinds.Kind), of −1.
static func target_kind(mods: Array) -> int:
	for m in mods:
		if m is Dictionary and str(m.get("id", "")) == TARGET:
			return int(m.get("kind", -1))
	return -1


static func target_bonus(kind: int) -> int:
	if kind < 0 or kind >= FindKinds.BASE_VALUES.size():
		return 0
	return maxi(FindKinds.BASE_VALUES[kind], Tuning.get_i("economy", "target_bonus_min", 250))


## Tekst en toon van een voorwaarde voor de kaart (Engels, zie de stijlregels in lessons.md).
static func describe(m: Dictionary) -> Array:
	match str(m.get("id", "")):
		BONE_BUYER:
			return ["Bone buyer: skeletons pay ×%s" % _x(Tuning.get_f("economy", "mod_bone_buyer", 1.4)), Tone.GOOD]
		FOSSIL_BEDS:
			return ["Rich fossil beds: %d extra bone beds" % Tuning.get_i("economy", "mod_fossil_beds", 4), Tone.GOOD]
		GEODE_BUYER:
			return ["Gem buyer: crystals, geodes and gold pay ×%s" % _x(Tuning.get_f("economy", "mod_geode_buyer", 1.4)), Tone.GOOD]
		ORE_VEINS:
			return ["Ore veins: %d extra veins of ore" % Tuning.get_i("economy", "mod_ore_veins", 8), Tone.GOOD]
		ORE_PRICE:
			return ["Ore boom: ore pays ×%s" % _x(Tuning.get_f("economy", "mod_ore_price", 1.4)), Tone.GOOD]
		SCRAP_BUYER:
			return ["Scrap collector: junk pays ×%s" % _x(Tuning.get_f("economy", "mod_scrap_buyer", 3.0)), Tone.GOOD]
		UNSTABLE:
			return ["Shaky ground: it quakes on its own", Tone.RISK]
		HOT_CORE:
			return ["Hot core: magma rises %d%% faster" % int(round((Tuning.get_f("economy", "mod_hot_core", 1.25) - 1.0) * 100.0)), Tone.RISK]
		LOW_FUEL:
			return ["Low fuel: the Mole starts at %d%%" % int(round(Tuning.get_f("economy", "mod_low_fuel", 0.65) * 100.0)), Tone.RISK]
		TARGET:
			var k := int(m.get("kind", -1))
			var what := FindKinds.NAMES[k].to_lower() if k >= 0 and k < FindKinds.NAMES.size() else "find"
			return ["Wanted: a %s (+%s)" % [what, UiTheme.euro(target_bonus(k))], Tone.TARGET]
	return [str(m.get("id", "")), Tone.GOOD]


## Wat de planeet zelf vraagt, voor de kaart (golf 3, ontwerp2-5): de worm (en wanneer hij wakker
## wordt), het gas en brokkelige rots, uit dezelfde getallen als het spel (planets.cfg, worm.cfg).
## [tekst, niveau 0..2] (niveau = Company.planet_danger: de kleur op de kaart).
static func planet_hazards(planet: int) -> Array:
	var p := PlanetType.play(clampi(planet, 0, 2) as PlanetType.Id)
	var worm := float(p.get("worm_mult", 1.0))
	var gas := float(p.get("gas_mult", 1.0))
	var wake := Tuning.get_f("worm", "wake_s", 150.0) / maxf(0.1, worm)
	var half_minutes := maxi(1, int(round(wake / 30.0)))
	var worm_word := "sleepy" if worm < 0.85 else ("awake" if worm < 1.25 else "restless")
	var gas_word := "little gas" if gas < 0.65 else ("some gas" if gas < 1.25 else "lots of gas")
	var line := "worm %s (wakes ±%d:%02d) · %s" % [worm_word, half_minutes / 2, 30 * (half_minutes % 2), gas_word]
	if float(p.get("quake_mult", 1.0)) > 1.1:
		line += " · crumbly rock"
	return [line, Company.planet_danger(planet)]


## "1.4" of "3": zonder overbodige nullen.
static func _x(v: float) -> String:
	return str(snappedf(v, 0.01)).trim_suffix(".0")
