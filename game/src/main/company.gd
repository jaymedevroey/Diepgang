class_name Company
extends Node
## De firma (GDD §3 Quota, §5 Economie): teamkas, reputatie, het kwartaal met zijn quota, de
## opdracht van deze dienst, en het incidentrapport na elke dienst. De host beslist en bewaart
## (user://saves/<naam>.json); iedereen krijgt de toestand.
## - Opdracht: aan de terminal in de hub kies je één van drie concessies, elk met een risico
##   (meer opbrengst, sneller magma). Kiezen = een nieuwe wereld uit die seed. Zonder opdracht
##   geen drop.
## - Na de dienst: alles in het laadruim wordt verkocht (tijdelijk, tot de taxatiepoort er is),
##   × de opbrengst van de opdracht, min de vervangrobots. Na `shifts` diensten: doel gehaald
##   (reputatie +1, het volgende doel hoger) of gemist (boete = schuld, reputatie −1). Upgrades en
##   het museum blijven altijd.
## Getallen in company.cfg.

## De toestand veranderde (op elke peer): terminal en HUD bijwerken.
signal changed
## Een dienst is voorbij: het incidentrapport (op elke peer).
signal report_ready(report: Dictionary)

enum Risk { LOW, MID, HIGH }
const RISK_NAMES := ["LAAG", "MIDDEL", "HOOG"]
const RISK_KEYS := ["low", "mid", "high"]
const SAVE_VERSION := 1

var game: Node # Game
## Bewaren: enkel als er een naam is (het echte spel, of een test die het vraagt).
var save_name := ""

var cash := 0
var reputation := 0
var quarter := 1
## Dienst binnen het kwartaal (1..shifts).
var shift := 1
## Verdiend dit kwartaal (netto, na kosten).
var earned := 0
## Diensten in totaal (ook de seed van de opdrachten hangt hiervan af).
var shifts_total := 0
## Opdrachten om uit te kiezen: [{seed, risk, name}, ...]
var options: Array = []
## Gekozen opdracht (leeg = nog niet gekozen).
var contract: Dictionary = {}
var last_report: Dictionary = {}
## Host: robots die smolten deze dienst (kosten).
var _melted := 0
var _company_seed := 0


# --- Toestand ------------------------------------------------------------------------------------

## Host: een nieuwe firma, of de bewaarde laden.
func host_setup(name: String) -> void:
	save_name = name
	if save_name == "" or not _load():
		cash = Tuning.get_i("company", "start_cash", 0)
		reputation = 0
		quarter = 1
		shift = 1
		earned = 0
		shifts_total = 0
		_company_seed = randi()
	contract = {}
	_make_options()
	_broadcast()


## Het geldoel van dit kwartaal voor deze ploeg.
func quota() -> int:
	var n := clampi(game.players.get_child_count(), 1, 4)
	var share := Tuning.get_f("company", "quota_p%d" % n, [0.4, 0.65, 0.85, 1.0][n - 1])
	var base := Tuning.get_f("company", "quota_base", 2000.0) * pow(Tuning.get_f("company", "quota_growth", 1.25), quarter - 1)
	return int(round(base * share / 10.0)) * 10


func contract_ready() -> bool:
	return not contract.is_empty()


static func pay_factor(risk: int) -> float:
	return Tuning.get_f("company", "pay_" + RISK_KEYS[risk], [1.0, 1.15, 1.35][risk])


static func magma_factor(risk: int) -> float:
	return Tuning.get_f("company", "magma_" + RISK_KEYS[risk], [0.85, 1.0, 1.2][risk])


## Tempo van het magma voor de gekozen opdracht.
func contract_magma() -> float:
	return magma_factor(int(contract.risk)) if contract_ready() else 1.0


func _make_options() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _company_seed * 7349 + shifts_total * 131 + 17
	options = []
	# Drie opdrachten op drie verschillende planeten (in een andere volgorde per dienst).
	var planets := [PlanetType.Id.ROESTBOL, PlanetType.Id.FOSSIELWERELD, PlanetType.Id.KRISTALMAAN]
	for i in range(planets.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = planets[i]
		planets[i] = planets[j]
		planets[j] = tmp
	for r in [Risk.LOW, Risk.MID, Risk.HIGH]:
		var s := rng.randi_range(1, 999999)
		options.append({"seed": s, "risk": r, "planet": int(planets[r]), "name": "CONCESSIE %d" % (s % 97 + 1)})


func state() -> Dictionary:
	return {"cash": cash, "reputation": reputation, "quarter": quarter, "shift": shift, "earned": earned,
			"shifts_total": shifts_total, "options": options, "contract": contract, "company_seed": _company_seed}


func _apply(s: Dictionary) -> void:
	cash = int(s.get("cash", 0))
	reputation = int(s.get("reputation", 0))
	quarter = int(s.get("quarter", 1))
	shift = int(s.get("shift", 1))
	earned = int(s.get("earned", 0))
	shifts_total = int(s.get("shifts_total", 0))
	options = s.get("options", [])
	contract = s.get("contract", {})
	_company_seed = int(s.get("company_seed", 0))


func _broadcast() -> void:
	_rpc_state.rpc(state())


@rpc("authority", "call_local", "reliable")
func _rpc_state(s: Dictionary) -> void:
	_apply(s)
	changed.emit()


## Late joiner.
func send_state(peer: int) -> void:
	_rpc_state.rpc_id(peer, state())
	if not last_report.is_empty():
		_rpc_report.rpc_id(peer, last_report, false)


# --- Opdracht kiezen -----------------------------------------------------------------------------

## Aan de terminal (elke speler): opdracht `index` kiezen. De host beslist.
func choose(index: int) -> void:
	if multiplayer.is_server():
		_host_choose(index)
	else:
		_rpc_choose.rpc_id(1, index)


@rpc("any_peer", "reliable")
func _rpc_choose(index: int) -> void:
	if multiplayer.is_server():
		_host_choose(index)


func _host_choose(index: int) -> void:
	var mol: Mol = game.mol
	if index < 0 or index >= options.size() or mol == null or mol.mode != Mol.Mode.DOCKED:
		return
	if contract == options[index]:
		return
	contract = options[index]
	_broadcast()
	game.host_new_world(int(contract.seed), int(contract.get("planet", 0)))
	game.notice_all("Opdracht gekozen: %s (risico %s)." % [contract.name, RISK_NAMES[int(contract.risk)]], "info")
	_save()


# --- Einde van een dienst ------------------------------------------------------------------------

## Host: een robot smolt in het magma (vervanging, kosten).
func host_melted() -> void:
	_melted += 1


## Host: de Mol staat terug in de baai. Verkopen, kosten, het kwartaal, en het rapport.
func host_shift_end(cargo: Array, ore_units: int, ore_value: int, left_behind: int) -> void:
	var risk := int(contract.get("risk", Risk.LOW))
	var factor := pay_factor(risk)
	var sold: Array = []
	var finds_value := 0
	var damage := 0
	for it: FindItem in cargo:
		finds_value += it.value()
		damage += it.base_value - it.value()
		sold.append([FindKinds.NAMES[it.kind], it.value(), int(round(it.condition * 100.0))])
	var gross := finds_value + ore_value
	var bonus := int(round(gross * (factor - 1.0)))
	var robots := left_behind + _melted
	var costs := robots * Tuning.get_i("company", "replacement_cost", 120)
	var net := gross + bonus - costs
	cash += net
	earned += net
	shifts_total += 1
	var report := {
		"shift_total": shifts_total, "quarter": quarter, "shift": shift, "contract": contract.get("name", ""),
		"risk": risk, "factor": factor, "sold": sold, "finds_value": finds_value, "ore_units": ore_units,
		"ore_value": ore_value, "bonus": bonus, "left_behind": left_behind, "melted": _melted, "costs": costs,
		"damage": damage, "quakes": game.unrest.stage, "net": net, "earned": earned, "quota": quota(),
	}
	# Einde van het kwartaal?
	if shift >= Tuning.get_i("company", "shifts", 3):
		var q := quota()
		if earned >= q:
			reputation += 1
			report["quarter_result"] = "gehaald"
		else:
			var fine := int(round((q - earned) * Tuning.get_f("company", "fine_factor", 0.5)))
			cash -= fine
			reputation -= 1
			report["quarter_result"] = "gemist"
			report["fine"] = fine
		quarter += 1
		shift = 1
		earned = 0
	else:
		shift += 1
	report["cash"] = cash
	report["reputation"] = reputation
	_melted = 0
	contract = {}
	_make_options()
	# Het verkochte is weg uit het laadruim.
	for it: FindItem in cargo:
		game.finds.host_remove(it.find_id)
	last_report = report
	_broadcast()
	_rpc_report.rpc(report, true)
	_save()


@rpc("authority", "call_local", "reliable")
func _rpc_report(report: Dictionary, show: bool) -> void:
	last_report = report
	if show:
		report_ready.emit(report)


# --- Bewaren -------------------------------------------------------------------------------------

func save_path() -> String:
	return "user://saves/%s.json" % save_name


func _save() -> void:
	if save_name == "" or not multiplayer.is_server():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var data := state()
	data["version"] = SAVE_VERSION
	data["contract"] = {} # na laden opnieuw kiezen (de wereld wordt dan opnieuw gemaakt)
	var f := FileAccess.open(save_path(), FileAccess.WRITE)
	if f == null:
		push_error("company: kan %s niet bewaren" % save_path())
		return
	f.store_string(JSON.stringify(data, "\t"))


func _load() -> bool:
	if not FileAccess.file_exists(save_path()):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if not parsed is Dictionary:
		push_error("company: %s is geen geldige save" % save_path())
		return false
	_apply(parsed)
	print("[company] geladen: kas €%d, kwartaal %d, dienst %d" % [cash, quarter, shift])
	return true
