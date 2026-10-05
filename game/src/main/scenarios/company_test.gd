extends Node
## Test van de firma (M3 stap 7, 8 en 11): opdrachten, na een dienst het erts verkocht en de
## vondsten in het laadruim tot ze getaxeerd en verkocht zijn (F1), vervangrobots, het kwartaal
## (gehaald / gemist met boete), het incidentrapport, en bewaren en laden. Solo, op het schip,
## headless. Een dienst wordt nagebootst (Company.host_shift_end); de echte drop en het ophalen test
## ship_test, de taxatie en de upgrades in detail economy_test.
## tools\godot.cmd --headless --path game -- --scenario=company_test --no-steam

const SAVE := "test_company"

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("[company_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(_p: Player) -> void:
	var game: Game = main.game
	var c: Company = game.company
	var finds: FindField = game.finds
	var reports: Array = []
	c.report_ready.connect(func(r: Dictionary) -> void: reports.append(r))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % SAVE))
	await _wait(0.5)

	# 1. Een nieuwe firma en drie opdrachten.
	c.host_setup(SAVE)
	_expect(c.cash == Tuning.get_i("company", "start_cash", 0) and c.quarter == 1 and c.shift == 1, "nieuwe firma: kas €%d, kwartaal 1, dienst 1" % c.cash)
	_expect(c.options.size() == 3 and int(c.options[0].risk) == Company.Risk.LOW and int(c.options[2].risk) == Company.Risk.HIGH, "drie opdrachten: laag, middel, hoog risico")
	var base := int(Tuning.get_f("company", "quota_base", 5000.0))
	_expect(c.quota() == int(round(base * 0.4)), "quota voor 1 robot: 40%% van €%d (€%d)" % [base, c.quota()])
	_expect(not c.contract_ready(), "nog geen opdracht")
	c.choose(2)
	await get_tree().process_frame
	while not game.world_ready():
		await get_tree().physics_frame
	_expect(c.contract_ready() and int(c.contract.risk) == Company.Risk.HIGH and game.pit_seed == int(c.contract.seed), "opdracht met hoog risico gekozen (nieuwe wereld)")
	# Risico × een eventuele hete kern (voorwaarde van de opdracht, F1).
	_expect(is_equal_approx(c.contract_magma(), Company.magma_factor(Company.Risk.HIGH) * Contracts.magma_factor(c.contract.modifiers)),
			"het magma stijgt sneller (×%.2f)" % c.contract_magma())

	# 2. Een dienst: twee vondsten en wat erts, één achterblijver en één gesmolten robot. Het erts wordt
	# meteen verkocht; de vondsten wachten in het laadruim op de taxatie (F1).
	var a := finds.items[0]
	var b := finds.items[1]
	for it: FindItem in [a, b]:
		it.set_freed()
	b.condition = 0.5
	var damage := (a.base_value - a.value()) + (b.base_value - b.value())
	var ore_value := 40
	c.host_melted()
	var cash0 := c.cash
	var ids := [a.find_id, b.find_id]
	c.host_shift_end([a, b], 6, ore_value, 1)
	await _wait(0.3)
	var ore_paid := int(round(ore_value * Company.pay_factor(Company.Risk.HIGH) * Contracts.ore_factor(c.haul.contract.get("modifiers", []))))
	var bonus := ore_paid - ore_value
	var costs := 2 * Tuning.get_i("company", "replacement_cost", 250)
	_expect(c.cash == cash0 + ore_paid - costs, "kas: +€%d erts (met bonus €%d), −€%d vervanging → €%d" % [ore_paid, bonus, costs, c.cash])
	_expect(c.earned == ore_paid - costs and c.shift == 1 and c.haul_open(), "verdiend €%d; de dienst staat open tot de buit verkocht is" % c.earned)
	_expect(finds.item(ids[0]) != null and finds.item(ids[1]) != null, "de vondsten liggen nog in het laadruim (taxatie)")
	_expect(reports.size() == 1, "incidentrapport na de dienst")
	if not reports.is_empty():
		var r: Dictionary = reports[0]
		_expect(int(r.haul_count) == 2 and (r.sold as Array).is_empty() and int(r.ore_value) == ore_value, "rapport: 2 vondsten te taxeren, erts (€%d)" % ore_value)
		_expect(int(r.left_behind) == 1 and int(r.melted) == 1 and int(r.costs) == costs, "rapport: 1 achtergebleven, 1 gesmolten, −€%d" % costs)
		_expect(int(r.damage) == damage and int(r.bonus) == bonus, "rapport: schade €%d, bonus €%d" % [damage, bonus])
	_expect(not c.contract_ready() and c.options.size() == 3, "na de dienst: nieuwe opdrachten, opnieuw kiezen")
	# Taxeren en verkopen: geld in de kas, de dienst sluit af.
	var appr: Appraisal = c.appraisal
	appr.host_appraise(a)
	appr.host_appraise(b)
	var finds_value := appr.value_of(a) + appr.value_of(b)
	_p.global_position = game.ship.anchor_position("Sell_Hatch") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	var cash_sell := c.cash
	appr.request_sell()
	await _wait(0.3)
	_expect(c.cash == cash_sell + finds_value and finds.item(ids[0]) == null and finds.item(ids[1]) == null,
			"verkocht aan het luik: +€%d, weg uit het laadruim" % finds_value)
	_expect(not c.haul_open() and c.shift == 2, "alles verkocht: dienst afgesloten, nu dienst 2")

	# 3. Einde van het kwartaal: doel gehaald (zonder buit: meteen afgesloten). Geen schuld, dus geen rente.
	c.cash = 1000
	var q1 := c.quota()
	c.shift = 3
	c.earned = q1 + 100
	var rep0 := c.reputation
	c.host_shift_end([], 0, 0, 0)
	await _wait(0.2)
	_expect(c.quarter == 2 and c.shift == 1 and c.earned == 0 and c.reputation == rep0 + 1, "kwartaal gehaald: reputatie +1, kwartaal 2")
	var q2 := int(round(q1 * Tuning.get_f("company", "quota_growth", 1.4) / 10.0)) * 10
	_expect(c.quota() == q2, "het volgende doel is hoger (€%d)" % c.quota())
	_expect(reports.back().get("quarter_result", "") == "gehaald" and str(reports.back().get("type", "")) == "quarter", "kwartaalrapport meldt: gehaald")

	# 4. Doel gemist: boete (schuld) en reputatie −1.
	c.shift = 3
	c.earned = 400
	var cash1 := c.cash
	c.host_shift_end([], 0, 0, 0)
	await _wait(0.2)
	var fine := int(round((q2 - 400) * Tuning.get_f("company", "fine_factor", 0.5)))
	_expect(c.cash == cash1 - fine and c.reputation == rep0, "kwartaal gemist: boete €%d, reputatie terug naar %d" % [fine, c.reputation])
	_expect(reports.back().get("quarter_result", "") == "gemist" and int(reports.back().get("fine", 0)) == fine, "rapport meldt: gemist, met de boete")

	# 5. Bewaren en laden.
	var saved := {"cash": c.cash, "quarter": c.quarter, "shift": c.shift, "reputation": c.reputation, "earned": c.earned}
	_expect(FileAccess.file_exists(c.save_path()), "bewaard in %s" % c.save_path())
	c.cash = 123456
	c.quarter = 99
	c.host_setup(SAVE)
	_expect(c.cash == saved.cash and c.quarter == saved.quarter and c.shift == saved.shift and c.reputation == saved.reputation and c.earned == saved.earned,
			"geladen: kas €%d, kwartaal %d, dienst %d, reputatie %d" % [c.cash, c.quarter, c.shift, c.reputation])
	_expect(not c.contract_ready(), "na laden: opnieuw een opdracht kiezen")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path()))
	_finish()


func _finish() -> void:
	print("[company_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[company_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[company_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
