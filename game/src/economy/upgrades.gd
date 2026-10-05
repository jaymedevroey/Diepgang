class_name Upgrades
extends RefCounted
## Upgrades van de ploeg (GDD §5: "elke upgrade laat je iets nieuws doen", §5A De Mol). Je koopt ze
## samen uit de teamkas aan een toonbank in de hub; ze blijven altijd (GDD §3.10), ook na een gemist
## kwartaal. De host beslist (Company.buy) en bewaart ze in de save van de firma.
##
## Elke upgrade opent een werkwoord, geen percentage:
## - Boor T2 (gereedschapsrek): te voet door graniet en kristal (Strata.MIN_TOOL), waar ±70% van de
##   waarde ligt (ontwerp-4).
## - Handscanner T1 (uitgiftebalie): blips van vondsten tot 10 m, te voet (Q); nooit "alles zichtbaar".
## - Helmlamp T2 (uitgiftebalie): een bundel die een hele grot verlicht (42 m): erts en korsten van
##   ver zien.
## - Boorkop T2 (Mol-werf): de Mol boort door graniet en kristal (zelfde laagregels als de handboor).
## - Groter laadruim (Mol-werf): de grijper tilt meer op (cargo_kg).
## Prijzen in economy.cfg, voor een ploeg van 4; een kleinere ploeg betaalt het deel van haar quota.

const DRILL_T2 := "drill_t2"
const SCANNER := "scanner"
const LAMP := "lamp"
const MOL_HEAD_T2 := "mol_head_t2"
const CARGO := "cargo"

## Toonbanken in de hub (lege punten uit tools/blender/interior/layout.py).
const TOOL_RACK := "Niche_Tools"
const SUPPLY_DESK := "Niche_Supply"
const MOLE_YARD := "Mol_Werf"
const COUNTERS := [TOOL_RACK, SUPPLY_DESK, MOLE_YARD]
## Naam van de toonbank (kop van het menu en de knop in de hub).
const COUNTER_NAMES := {TOOL_RACK: "Tool rack", SUPPLY_DESK: "Supply desk", MOLE_YARD: "Mole yard"}
## Midden in een zin ("the Mole" blijft met een hoofdletter, zie de stijlregels in lessons.md).
const COUNTER_IN_TEXT := {TOOL_RACK: "tool rack", SUPPLY_DESK: "supply desk", MOLE_YARD: "Mole yard"}

## Volgorde in de winkel.
const ORDER: Array[String] = [DRILL_T2, SCANNER, LAMP, MOL_HEAD_T2, CARGO]

## id -> {counter, name, does (wat je ermee kan, één regel), detail, requires}
const CATALOG := {
	DRILL_T2: {"counter": TOOL_RACK, "name": "Drill T2",
		"does": "Dig through granite and crystal on foot",
		"detail": "Carbide bit. The deep layers hold gold, geodes and the big skulls.", "requires": ""},
	SCANNER: {"counter": SUPPLY_DESK, "name": "Hand scanner",
		"does": "Press Q: blips of finds within 10 m, on foot",
		"detail": "Quiet and short-ranged. Shows where, never what.", "requires": ""},
	LAMP: {"counter": SUPPLY_DESK, "name": "Floodlight helmet lamp",
		"does": "Light up a whole cave: spot ore and crusts from 40 m",
		"detail": "Twice the reach of the standard bulb. Battery not included (it is).", "requires": ""},
	MOL_HEAD_T2: {"counter": MOLE_YARD, "name": "Mole drill head T2",
		"does": "The Mole bores through granite and crystal",
		"detail": "Drive the Mole into the deep layers. The magma is down there too.", "requires": ""},
	CARGO: {"counter": MOLE_YARD, "name": "Extended cargo hold",
		"does": "The grapple lifts 140 kg instead of 60 kg",
		"detail": "Bring the whole skeleton home. Reinforced floor, same old ramp.", "requires": ""},
}


static func exists(id: String) -> bool:
	return CATALOG.has(id)


static func info(id: String) -> Dictionary:
	return CATALOG.get(id, {})


## Prijs voor een ploeg van `players` robots: de prijs voor 4 × het deel van de quota (company.cfg).
static func price(id: String, players: int) -> int:
	var n := clampi(players, 1, 4)
	var share := Tuning.get_f("company", "quota_p%d" % n, [0.4, 0.65, 0.85, 1.0][n - 1])
	return int(round(Tuning.get_f("economy", "price_" + id, 5000.0) * share / 10.0)) * 10


static func owned(c: Company, id: String) -> bool:
	return c != null and c.upgrades.has(id)


## Waarom deze upgrade nu niet te koop is ("" = te koop): al gekocht, eerst een andere, bevroren
## rekening (schuld), of te weinig geld.
static func blocker(c: Company, id: String) -> String:
	if not exists(id):
		return "Unknown item"
	if owned(c, id):
		return "Owned"
	var req: String = info(id).get("requires", "")
	if req != "" and not owned(c, req):
		return "Needs %s first" % str(info(req).get("name", req))
	if c.cash < 0:
		return "Account frozen: clear your debt first"
	if c.cash < price(id, c.team_size()):
		return "Not enough funds"
	return ""


# --- Wat de upgrades doen ----------------------------------------------------------------------

## Handboor: T1, of T2 met de upgrade.
static func drill_tier(c: Company) -> Strata.Tool:
	return Strata.Tool.BOOR_T2 if owned(c, DRILL_T2) else Strata.Tool.BOOR_T1


## Boorkop van de Mol.
static func mol_tier(c: Company) -> Strata.Tool:
	return Strata.Tool.BOOR_T2 if owned(c, MOL_HEAD_T2) else Strata.Tool.BOOR_T1


## Wat de grijper kan optillen (kg).
static func cargo_kg(c: Company) -> float:
	return Tuning.get_f("economy", "cargo_kg_t2" if owned(c, CARGO) else "cargo_kg", 140.0 if owned(c, CARGO) else 60.0)


static func has_scanner(c: Company) -> bool:
	return owned(c, SCANNER)


## De helmlamp van een speler (lokaal en de kopieën van anderen) naar het niveau van de ploeg.
## De lamp en zijn gloed hangen onder CamRig (lokaal) of Head (kopie), zie Player._ready.
static func apply_lamp(p: Node3D, c: Company) -> void:
	if p == null or not is_instance_valid(p):
		return
	var t2 := owned(c, LAMP)
	for l: SpotLight3D in p.find_children("*", "SpotLight3D", true, false):
		if not l.has_meta("lamp_base"):
			if l.name == "LampFill" or l.name == "HelmetLamp":
				l.set_meta("lamp_base", [l.spot_range, l.spot_angle, l.light_energy])
			else:
				continue
		var base: Array = l.get_meta("lamp_base")
		if l.name == "HelmetLamp":
			l.spot_range = Tuning.get_f("economy", "lamp2_range", 42.0) if t2 else float(base[0])
			l.spot_angle = Tuning.get_f("economy", "lamp2_angle", 58.0) if t2 else float(base[1])
			l.light_energy = float(base[2]) * (Tuning.get_f("economy", "lamp2_energy", 1.6) if t2 else 1.0)
		else:
			l.spot_range = Tuning.get_f("economy", "lamp2_fill_range", 22.0) if t2 else float(base[0])
