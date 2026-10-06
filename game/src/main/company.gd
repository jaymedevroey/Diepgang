class_name Company
extends Node
## De firma (GDD §3 Quota, §5 Economie): teamkas, reputatie, het kwartaal met zijn quota, de
## opdracht van deze dienst, de upgrades van de ploeg, de taxatie van de buit en het incidentrapport.
## De host beslist en bewaart (user://saves/<naam>.json); iedereen krijgt de toestand.
## - Opdracht: aan de terminal in de hub kies je één van drie concessies, elk met een risico
##   (meer opbrengst, sneller magma) en 2-3 voorwaarden (Contracts). Kiezen = een nieuwe wereld uit
##   die seed. Zonder opdracht geen drop.
## - Na de dienst (de Mol in de baai): het erts wordt meteen verkocht (× de opbrengst van de
##   opdracht), min de vervangrobots en de rente op schuld. De vondsten blijven in het laadruim: je
##   draagt ze door de taxatiepoort (onthulling één voor één) en verkoopt ze aan het verkoopluik
##   (Appraisal). Wat onverkocht blijft, koopt het hoofdkantoor op aan unsold_factor als je de
##   volgende opdracht tekent. Pas dan is de dienst afgesloten ("settle").
## - Kwartaal: na `shifts` diensten, bij het afsluiten van de laatste: doel gehaald (reputatie +1,
##   het volgende doel hoger) of gemist (boete = schuld, reputatie −1).
## - Gevolgen (F1; waar het GDD zwijgt): met schuld is de rekening bevroren (geen upgrades) en rekent
##   de firma rente per dienst; met reputatie onder 0 (proeftijd) geeft de firma je de veiligste claim
##   niet (golf 3, ontwerp2-11: "DIG stuurt je naar de rotklus"; GDD: "reputatie bepaalt welke planeten
##   je mag doen"). Upgrades blijven altijd (GDD §3.10).
## - Risico (golf 3, ontwerp2-5): `risk` is wat de voorwaarden vragen (aantal risicoregels, magma,
##   opbrengst); `danger` is het label op de kaart: de planeet zelf telt mee (Kristalmaan is nooit LOW,
##   Roestbol nooit HIGH). De kaarten staan van veilig naar gevaarlijk.
## Getallen in company.cfg en economy.cfg.

## De toestand veranderde (op elke peer): terminal en HUD bijwerken.
signal changed
## Een dienst is voorbij (incidentrapport), of een kwartaal is afgesloten (op elke peer).
signal report_ready(report: Dictionary)
## De lokale speler drukte E aan een toonbank in de hub (Upgrades.COUNTERS).
signal shop_requested(counter: String)
## Bij wie kocht: het mocht niet (de winkel toont waarom).
signal buy_denied(id: String, reason: String)

enum Risk { LOW, MID, HIGH }
const RISK_NAMES := ["LOW", "MEDIUM", "HIGH"]
const RISK_KEYS := ["low", "mid", "high"]
## Sleutels per planeet (PlanetType.Id) in company.cfg (danger_*).
const PLANET_KEYS := ["roestbol", "fossiel", "kristal"]
## Wat de firma zegt als je op proeftijd de veiligste claim wil (golf 3, ontwerp2-11).
const PROBATION_TEXT := "Probation: head office keeps the easy claims for crews in good standing. Meet a quota first."
## 2: upgrades, voorwaarden en de open taxatie (F1). Een save van versie 1 laadt gewoon.
const SAVE_VERSION := 2

var game: Node # Game
## Bewaren: enkel als er een naam is (het echte spel, of een test die het vraagt).
var save_name := ""

var cash := 0
var reputation := 0
var quarter := 1
## Dienst binnen het kwartaal (1..shifts). Na het ophalen blijft hij staan tot de dienst
## afgesloten is (de buit verkocht of de volgende opdracht getekend).
var shift := 1
## Verdiend dit kwartaal (netto, na kosten).
var earned := 0
## Diensten in totaal (ook de seed van de opdrachten hangt hiervan af).
var shifts_total := 0
## Opdrachten om uit te kiezen: [{seed, risk, planet, name, modifiers}, ...]
var options: Array = []
## Gekozen opdracht (leeg = nog niet gekozen).
var contract: Dictionary = {}
## Voorwaarden van de wereld die nu gebouwd is (extra bedden en aders: elke peer genereert ermee).
var world_mods: Array = []
## Gekochte upgrades (Upgrades.ORDER).
var upgrades: Array = []
## De buit van de laatste dienst, tot hij afgesloten is (Appraisal). Leeg = niets open.
## {"contract", "ids": [find_id], "appraised": {id: [waarde, bonus]}, "sold": [[naam, waarde, %]],
##  "sold_value", "set_bonus", "target_bonus", "sets": {set_id: [verkocht, grootte, waarde]},
##  "sets_done": [set_id], "target_paid"}
var haul: Dictionary = {}
## De vorige buit, na het afsluiten (voor het scherm aan de poort): {"sold", "sold_value", "set_bonus",
## "target_bonus", "leftover_count", "leftover_value", "shift_total"}.
var last_haul: Dictionary = {}
var last_report: Dictionary = {}
## Host: robots die smolten deze dienst (kosten).
var _melted := 0
var _company_seed := 0
## Taxatie en verkoop (host beslist, iedereen ziet de onthulling).
var appraisal: Appraisal


func _ready() -> void:
	appraisal = Appraisal.new()
	appraisal.name = "Appraisal"
	appraisal.company = self
	add_child(appraisal)
	if game:
		game.player_spawned.connect(_on_player_spawned)
	# Upgrades die je ziet: de helmlamp van iedereen, de boorkop en het laadruim op de Mol (golf 3).
	changed.connect(func() -> void: Upgrades.apply_visuals(game, self))


## Elke speler: de helmlamp van de ploeg; de lokale speler krijgt de handscanner (gadget, Q).
func _on_player_spawned(p: Player) -> void:
	Upgrades.apply_visuals(game, self)
	if p.is_local and p.camera:
		var scanner := HandScanner.new()
		scanner.name = "HandScanner"
		scanner.player = p
		scanner.game = game
		p.camera.add_child(scanner)


# --- Toestand ------------------------------------------------------------------------------------

## Host: een nieuwe firma, of de bewaarde laden.
func host_setup(name: String) -> void:
	save_name = name
	haul = {}
	if save_name == "" or not _load():
		cash = Tuning.get_i("company", "start_cash", 0)
		reputation = 0
		quarter = 1
		shift = 1
		earned = 0
		shifts_total = 0
		upgrades = []
		_company_seed = randi()
	contract = {}
	world_mods = []
	_make_options()
	_broadcast()


## Robots in de ploeg (1..4): de quota en de prijzen schalen mee.
func team_size() -> int:
	return clampi(game.players.get_child_count(), 1, 4) if game and game.players else 1


## Het geldoel van dit kwartaal voor deze ploeg.
func quota() -> int:
	var n := team_size()
	var share := Tuning.get_f("company", "quota_p%d" % n, [0.4, 0.65, 0.85, 1.0][n - 1])
	var base := Tuning.get_f("company", "quota_base", 5000.0) * pow(Tuning.get_f("company", "quota_growth", 1.4), quarter - 1)
	return int(round(base * share / 10.0)) * 10


func contract_ready() -> bool:
	return not contract.is_empty()


## Ligt er nog buit van de vorige dienst te wachten op taxatie en verkoop?
func haul_open() -> bool:
	return not haul.is_empty()


## Met schuld is de rekening bevroren: geen upgrades.
func in_debt() -> bool:
	return cash < 0


## Proeftijd (reputatie onder 0): geen opdrachten met hoog risico.
func on_probation() -> bool:
	return reputation < 0


## Opdracht `index` mag niet gekozen worden? Op proeftijd geeft de firma je de veiligste claim niet
## (golf 3, ontwerp2-11): je moet je reputatie terugverdienen met een riskantere klus, en de rijkste
## kaart blijft open.
func option_locked(index: int) -> bool:
	return on_probation() and index >= 0 and index == safest_option()


## De veiligste opdracht van de drie (laagste label, dan de minste voorwaarden), of −1.
func safest_option() -> int:
	var best := -1
	for i in options.size():
		if best < 0 or _danger_key(options[i]) < _danger_key(options[best]):
			best = i
	return best


static func _danger_key(o: Dictionary) -> int:
	return int(o.get("danger", o.get("risk", 0))) * 10 + int(o.get("risk", 0))


## Hoe gevaarlijk een planeet zelf is (0..2: worm, gas, bevingen), voor het risicolabel (company.cfg).
static func planet_danger(planet: int) -> int:
	var i := clampi(planet, 0, PLANET_KEYS.size() - 1)
	return clampi(Tuning.get_i("company", "danger_" + PLANET_KEYS[i], i), 0, 2)


## Het risicolabel van een opdracht (Risk): de planeet plus wat de voorwaarden vragen. Som tot
## danger_low_max = LOW, tot danger_mid_max = MEDIUM, daarboven HIGH (company.cfg).
static func danger_of(o: Dictionary) -> int:
	var sum := planet_danger(int(o.get("planet", 0))) + clampi(int(o.get("risk", 0)), 0, 2)
	if sum <= Tuning.get_i("company", "danger_low_max", 1):
		return Risk.LOW
	if sum <= Tuning.get_i("company", "danger_mid_max", 2):
		return Risk.MID
	return Risk.HIGH


## Het label van de gekozen opdracht (of van de buit die nog open staat), voor de schermen.
func contract_danger() -> int:
	var o: Dictionary = contract if contract_ready() else haul.get("contract", {})
	return int(o.get("danger", danger_of(o))) if not o.is_empty() else Risk.LOW


static func pay_factor(risk: int) -> float:
	return Tuning.get_f("company", "pay_" + RISK_KEYS[risk], [1.0, 1.15, 1.35][risk])


static func magma_factor(risk: int) -> float:
	return Tuning.get_f("company", "magma_" + RISK_KEYS[risk], [0.85, 1.0, 1.2][risk])


## Tempo van het magma voor de gekozen opdracht (risico × hete kern).
func contract_magma() -> float:
	if not contract_ready():
		return 1.0
	return magma_factor(int(contract.risk)) * Contracts.magma_factor(contract.get("modifiers", []))


## Voorwaarden van de gekozen opdracht (of van de buit die nog open staat).
func mods() -> Array:
	if contract_ready():
		return contract.get("modifiers", [])
	return (haul.get("contract", {}) as Dictionary).get("modifiers", [])


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


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
	# Drie dezelfde labels (Roestbol met harde voorwaarden, Kristalmaan met zachte: alles MEDIUM) is
	# geen keuze: dan schuiven de planeten één plek op (golf 3, de seeds blijven dezelfde).
	var same := true
	for r in range(1, planets.size()):
		if danger_of({"planet": planets[r], "risk": r}) != danger_of({"planet": planets[0], "risk": 0}):
			same = false
	if same:
		planets.push_back(planets.pop_front())
	for r in [Risk.LOW, Risk.MID, Risk.HIGH]:
		var s := rng.randi_range(1, 999999)
		options.append({"seed": s, "risk": r, "planet": int(planets[r]), "name": "CLAIM %d" % (s % 97 + 1)})
	# De voorwaarden met een eigen rng (zelfde seeds en planeten als vroeger voor dezelfde firma).
	var mrng := RandomNumberGenerator.new()
	mrng.seed = _company_seed * 4421 + shifts_total * 977 + 3
	for o: Dictionary in options:
		o["modifiers"] = Contracts.roll(mrng, int(o.planet), int(o.risk))
		o["danger"] = danger_of(o)
	# Van veilig naar gevaarlijk (het label telt de planeet mee, golf 3).
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _danger_key(a) < _danger_key(b))


func state() -> Dictionary:
	return {"cash": cash, "reputation": reputation, "quarter": quarter, "shift": shift, "earned": earned,
			"shifts_total": shifts_total, "options": options, "contract": contract, "company_seed": _company_seed,
			"upgrades": upgrades, "world_mods": world_mods, "haul": haul, "last_haul": last_haul}


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
	upgrades = s.get("upgrades", [])
	world_mods = s.get("world_mods", [])
	haul = s.get("haul", {})
	last_haul = s.get("last_haul", {})


func _broadcast() -> void:
	_rpc_state.rpc(state())


@rpc("authority", "call_local", "reliable")
func _rpc_state(s: Dictionary) -> void:
	_apply(s)
	changed.emit()


## Late joiner (vóór de wereld: de voorwaarden bepalen mee hoe ze gegenereerd wordt).
func send_state(peer: int) -> void:
	_rpc_state.rpc_id(peer, state())
	if not last_report.is_empty():
		_rpc_report.rpc_id(peer, last_report, false)


func _process(delta: float) -> void:
	if game == null or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	# Onstabiele grond: de onrust stijgt ook als het stil is (en zakt dus niet meer terug).
	var rate := Contracts.unrest_rate(mods()) if contract_ready() else 0.0
	if rate > 0.0 and game.magma and game.magma.running and game.unrest:
		game.unrest.host_add(rate * delta)


## Host: de Mol landde (krappe brandstof voor deze opdracht).
func host_landed() -> void:
	if contract_ready() and game.mol:
		game.mol.fuel = minf(game.mol.fuel, Contracts.fuel(mods()))


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
	# Tekenen sluit de vorige dienst af: wat niet verkocht is, koopt het hoofdkantoor op.
	if haul_open():
		host_settle(true)
	if option_locked(index):
		game.notice_all(PROBATION_TEXT, "warn")
		_broadcast()
		return
	contract = options[index]
	world_mods = contract.get("modifiers", [])
	_broadcast()
	game.host_new_world(int(contract.seed), int(contract.get("planet", 0)))
	# Soort "contract": wie hem net aan de terminal koos, zag dat al (de HUD toont hem dan niet, ui-03).
	game.notice_all("Contract chosen: %s (risk %s)." % [contract.name, RISK_NAMES[contract_danger()]], "contract")
	_save()


# --- Upgrades kopen ------------------------------------------------------------------------------

## Aan een toonbank (elke speler): upgrade `id` kopen. De host beslist (geld, schuld, afstand).
func buy(id: String, counter: String) -> void:
	if multiplayer.is_server():
		_host_buy(multiplayer.get_unique_id(), id, counter)
	else:
		_rpc_buy.rpc_id(1, id, counter)


@rpc("any_peer", "reliable")
func _rpc_buy(id: String, counter: String) -> void:
	if multiplayer.is_server():
		_host_buy(multiplayer.get_remote_sender_id(), id, counter)


func _host_buy(sender: int, id: String, counter: String) -> void:
	var why := Upgrades.blocker(self, id)
	if why == "" and str(Upgrades.info(id).get("counter", "")) != counter:
		why = "Not sold at this counter"
	if why == "" and not _near_anchor(sender, counter):
		why = "Too far from the counter"
	if why != "":
		if sender == multiplayer.get_unique_id():
			_rpc_buy_denied(id, why)
		else:
			_rpc_buy_denied.rpc_id(sender, id, why)
		return
	var price := Upgrades.price(id, team_size())
	cash -= price
	upgrades.append(id)
	_broadcast()
	game.notice_all("Bought: %s (%s). %s." % [str(Upgrades.info(id).name), UiTheme.euro_signed(-price), Settings.fill_keys(Upgrades.does(id, self))], "contract")
	_save()


@rpc("authority", "reliable")
func _rpc_buy_denied(id: String, reason: String) -> void:
	buy_denied.emit(id, reason)


## Host: staat de speler bij dit lege punt van de hub (toonbank, verkoopluik)?
func _near_anchor(sender: int, anchor: String) -> bool:
	var ship: Ekster = game.ship
	var p: Player = game.player_node(sender)
	if ship == null or p == null or not ship.anchors.has(anchor):
		return ship == null and p != null # zonder schip (tests op de planeet): geen afstand
	return p.global_position.distance_to(ship.anchor_position(anchor)) <= Tuning.get_f("economy", "counter_reach_m", 5.0)


# --- Einde van een dienst ------------------------------------------------------------------------

## Host: een robot smolt in het magma (vervanging, kosten).
func host_melted() -> void:
	_melted += 1


## Host: de Mol staat terug in de baai. Het erts wordt verkocht, de kosten en de rente gaan eraf, en
## de vondsten (`cargo`, plus wat een robot aan boord nog draagt) wachten op de taxatie.
func host_shift_end(cargo: Array, ore_units: int, ore_value: int, left_behind: int) -> void:
	var risk := int(contract.get("risk", Risk.LOW))
	var mods_now: Array = contract.get("modifiers", [])
	var factor := pay_factor(risk)
	var ore_paid := int(round(ore_value * factor * Contracts.ore_factor(mods_now)))
	var bonus := ore_paid - ore_value
	var robots := left_behind + _melted
	var costs := robots * Tuning.get_i("company", "replacement_cost", 250)
	var interest := int(ceil(-cash * Tuning.get_f("company", "debt_interest", 0.1))) if cash < 0 else 0
	var net := ore_paid - costs - interest
	cash += net
	earned += net
	shifts_total += 1
	# De buit: wat in het laadruim ligt, en alles wat verder aan boord is (op de klep, in de handen
	# van een robot). Wat op de planeet bleef, is weg.
	var ids: Array = []
	var damage := 0
	for it: FindItem in cargo:
		if is_instance_valid(it) and not ids.has(it.find_id):
			ids.append(it.find_id)
	for it: FindItem in game.finds.items:
		if it.freed and not ids.has(it.find_id) and _aboard(it.global_position):
			ids.append(it.find_id)
	for id in ids:
		var it: FindItem = game.finds.item(int(id))
		damage += it.base_value - it.value()
	var report := {
		"type": "shift", "shift_total": shifts_total, "quarter": quarter, "shift": shift, "contract": contract.get("name", ""),
		"risk": risk, "factor": factor, "sold": [], "finds_value": 0, "ore_units": ore_units,
		"ore_value": ore_value, "bonus": bonus, "left_behind": left_behind, "melted": _melted, "costs": costs,
		"interest": interest, "damage": damage, "quakes": game.unrest.stage, "net": net, "earned": earned,
		"quota": quota(), "haul_count": ids.size(), "last_of_quarter": shift >= Tuning.get_i("company", "shifts", 3),
	}
	_melted = 0
	haul = {"contract": contract.duplicate(true), "ids": ids, "appraised": {}, "sold": [], "sold_value": 0,
			"set_bonus": 0, "target_bonus": 0, "sets": {}, "sets_done": [], "target_paid": false}
	contract = {}
	_make_options()
	report["cash"] = cash
	report["reputation"] = reputation
	last_report = report
	_broadcast()
	_rpc_report.rpc(report, true)
	# Niets mee terug: de dienst is meteen afgesloten (ook het kwartaal).
	if ids.is_empty():
		host_settle(false)
	_save()


## Staat een punt aan boord (in de hub of in de Mol)?
func _aboard(world: Vector3) -> bool:
	var ship: Ekster = game.ship
	return (ship != null and ship.contains(world)) or (game.mol != null and game.mol.contains_point(world))


## Host: de dienst afsluiten. `forced`: er wordt getekend terwijl er nog buit ligt; die koopt het
## hoofdkantoor op aan unsold_factor. Daarna de volgende dienst, of het einde van het kwartaal.
## `quiet`: de verkoop meldde het al (één melding per gebeurtenis, golf 3).
func host_settle(forced: bool, leftover_value := -1, quiet := false) -> void:
	if not haul_open():
		return
	var left := 0
	var left_value := 0
	if leftover_value >= 0:
		left_value = leftover_value
	else:
		for id in haul.get("ids", []):
			var it: FindItem = game.finds.item(int(id))
			if it == null:
				continue
			left += 1
			left_value += appraisal.value_of(it)
			game.finds.host_remove(it.find_id)
	var cleared := int(round(left_value * Tuning.get_f("economy", "unsold_factor", 0.6)))
	cash += cleared
	earned += cleared
	if cleared > 0 or left > 0:
		game.notice_all("Head office bought %s at %d%%: %s." % [UiTheme.count(left, "unsold find") if left > 0 else "your unsold haul",
				int(round(Tuning.get_f("economy", "unsold_factor", 0.6) * 100.0)), UiTheme.euro_signed(cleared)], "contract")
	var sold: Array = haul.get("sold", [])
	last_haul = {"sold": sold, "sold_value": int(haul.get("sold_value", 0)), "set_bonus": int(haul.get("set_bonus", 0)),
			"target_bonus": int(haul.get("target_bonus", 0)), "leftover_count": left, "leftover_value": cleared,
			"shift_total": shifts_total}
	var report := {}
	if shift >= Tuning.get_i("company", "shifts", 3):
		var q := quota()
		report = {"type": "quarter", "quarter": quarter, "quota": q, "earned": earned, "sold": sold,
				"finds_value": int(haul.get("sold_value", 0)), "set_bonus": int(haul.get("set_bonus", 0)),
				"target_bonus": int(haul.get("target_bonus", 0)), "leftover_count": left, "leftover_value": cleared}
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
		report["cash"] = cash
		report["reputation"] = reputation
		report["probation"] = on_probation()
		report["frozen"] = in_debt()
	else:
		shift += 1
		if not forced and not quiet:
			game.notice_all("Haul sold: %s for %s. On to shift %d." % [UiTheme.count(sold.size(), "find"),
					UiTheme.euro(int(haul.get("sold_value", 0)) + int(haul.get("set_bonus", 0)) + int(haul.get("target_bonus", 0))), shift], "contract")
	haul = {}
	_broadcast()
	if not report.is_empty():
		last_report = report
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
	data["world_mods"] = [] # na laden staat de beginwereld er, zonder voorwaarden
	# De vondsten van een open buit bestaan na laden niet meer: enkel hun waarde bewaren.
	if haul_open():
		var left_value := 0
		for id in haul.get("ids", []):
			var it: FindItem = game.finds.item(int(id))
			if it:
				left_value += appraisal.value_of(it)
		data["haul"] = {"left_value": left_value, "sold_value": int(haul.get("sold_value", 0)), "sold": haul.get("sold", [])}
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
	# JSON maakt van elk getal een float: de lijsten opnieuw met ints.
	upgrades = upgrades.filter(func(u: Variant) -> bool: return Upgrades.exists(str(u))).map(func(u: Variant) -> String: return str(u))
	for o: Dictionary in options:
		for k in ["seed", "risk", "planet"]:
			o[k] = int(o.get(k, 0))
		o["danger"] = int(o.get("danger", danger_of(o)))
	# Een buit die openstond toen er bewaard werd: het hoofdkantoor heeft hem intussen opgekocht.
	if haul_open():
		var left_value := int(haul.get("left_value", 0))
		haul = {"ids": [], "sold": haul.get("sold", []), "sold_value": int(haul.get("sold_value", 0)), "set_bonus": 0, "target_bonus": 0}
		host_settle(true, left_value)
	print("[company] geladen: kas €%d, kwartaal %d, dienst %d, %d upgrades" % [cash, quarter, shift, upgrades.size()])
	return true
