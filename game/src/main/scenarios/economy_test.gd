extends Node
## Test van de economie en de voortgang (pakket F1): de voorwaarden van een opdracht, na de dienst
## de buit in het laadruim (waarde verborgen), de taxatiepoort (één voor één, juiste waarde, doelbonus),
## het verkoopluik (geld, afstand), een volledige set (bonus), onverkochte buit bij het tekenen
## (opkoop), het kwartaal (gemist: boete, proeftijd, bevroren rekening, rente), upgrades kopen (prijs,
## afstand, schuld) en wat ze openen (boor T2 ook bij de host, boorkop T2, scanner, lamp, laadruim met
## gewichtslimiet), de voorwaarden in het spel (magma, brandstof, onrust, extra bedden), en bewaren
## en laden (ook met een open buit). Solo, op het schip, headless. Een dienst wordt nagebootst
## (Company.host_shift_end), de echte drop test ship_test.
## tools\godot.cmd --headless --path game -- --scenario=economy_test --no-steam

const SAVE := "test_economy"

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("[economy_test] GEFAALD: time-out")
		for f in _failures:
			print("[economy_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var game: Game = main.game
	var c: Company = game.company
	var a: Appraisal = c.appraisal
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	var reveals: Array = []
	var sales: Array = []
	var reports: Array = []
	a.revealed.connect(func(info: Dictionary) -> void: reveals.append([info, Time.get_ticks_msec()]))
	a.sold.connect(func(info: Dictionary) -> void: sales.append(info))
	c.report_ready.connect(func(r: Dictionary) -> void: reports.append(r))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://saves/%s.json" % SAVE))
	await _wait(0.5)

	# 1. Een nieuwe firma: quota en voorwaarden op de kaarten.
	c.host_setup(SAVE)
	_expect(c.quota() == 2000, "quota solo kwartaal 1: €%d (40%% van €5000)" % c.quota())
	var ok_mods := true
	for o: Dictionary in c.options:
		var mods: Array = o.modifiers
		var perk := str(mods[0].id)
		var risks := mods.filter(func(m: Dictionary) -> bool: return str(m.id) in Contracts.RISKS).size()
		if mods.size() < 2 or mods.size() > 3 or not perk in Contracts.PERKS[int(o.planet)] or risks != int(o.risk):
			ok_mods = false
		for m: Dictionary in mods:
			if str(Contracts.describe(m)[0]).length() < 10:
				ok_mods = false
	_expect(ok_mods, "elke kaart: 2-3 voorwaarden, een troef van haar planeet, zoveel risico's als haar risico (%s)" %
			" | ".join(c.options.map(func(o: Dictionary) -> String: return ", ".join((o.modifiers as Array).map(func(m: Dictionary) -> String: return str(m.id))))))

	# 2. Een opdracht kiezen: de voorwaarden gaan mee naar de wereld. Op Roestbol: elke planeet heeft nu
	# haar eigen buit (F3), en enkel daar zit zeker een schedel, een dijbeen en een kabouter.
	var rustbowl := 1
	for i in c.options.size():
		if int(c.options[i].planet) == PlanetType.Id.ROESTBOL:
			rustbowl = i
	c.choose(rustbowl)
	await get_tree().process_frame
	while not game.world_ready():
		await get_tree().physics_frame
	_expect(c.contract_ready() and c.world_mods == c.contract.modifiers, "opdracht gekozen, de wereld kent haar voorwaarden")
	# Vaste voorwaarden voor de rest van de test: een botten-opkoper en een schedel als doel.
	c.contract.modifiers = [{"id": Contracts.BONE_BUYER}, {"id": Contracts.TARGET, "kind": FindKinds.Kind.SKULL}]
	c.contract.risk = Company.Risk.MID

	# 3. Einde van de dienst: erts verkocht, vondsten blijven in het laadruim (waarde verborgen).
	var finds := _pick(game, [FindKinds.Kind.SKULL, FindKinds.Kind.FEMUR, FindKinds.Kind.GNOME])
	_expect(finds.size() == 3, "drie vondsten om mee te testen (schedel, dijbeen, kabouter)")
	var spots := [Vector3(-0.8, -1.2, 2.6), Vector3(0.0, -1.2, 3.0), Vector3(0.8, -1.2, 3.4)]
	for i in finds.size():
		_free_at(finds[i], mol.to_world_mol(spots[i]))
	finds[1].condition = 0.8
	await _wait(0.4)
	var cash0 := c.cash
	c.host_shift_end(mol.cargo_contents(), 10, 120, 0)
	await _wait(0.3)
	var ore_paid := int(round(120 * Company.pay_factor(Company.Risk.MID)))
	_expect(c.cash == cash0 + ore_paid and c.haul_open() and (c.haul.ids as Array).size() == 3,
			"na de dienst: erts verkocht (+€%d), drie vondsten wachten op de taxatie" % ore_paid)
	_expect(game.finds.item(finds[0].find_id) != null and not a.is_appraised(finds[0].find_id) and main.hud._appraised_value(finds[0]) == -1,
			"de vondsten liggen nog in het laadruim, hun waarde is onbekend")
	_expect(not reports.is_empty() and int(reports.back().get("haul_count", 0)) == 3 and str(reports.back().type) == "shift",
			"incidentrapport: 3 vondsten te taxeren")

	# 4. De taxatiepoort: één voor één, met de juiste waarde (opbrengst, opkoper, doelbonus).
	var gate := ship.anchor_position("Appraisal_Gate") + Vector3(0, 1.0, 0)
	_expect(a.in_gate(gate) and not a.in_gate(gate + Vector3(0, 0, 3.0)), "de poort herkent wat erdoor gaat")
	# In de poort zetten zoals na het dragen (los, stil, net boven de vloer): een bevroren lichaam dat
	# verspringt, krijgt in Jolt een snelheid mee en zou "botsen".
	var floor_y := ship.anchor_position("Appraisal_Gate").y
	for i in 2:
		var it: FindItem = finds[i]
		it.global_position = Vector3(gate.x, floor_y + it.rest_height() + 0.05, gate.z + (i - 0.5) * 0.7)
		it.linear_velocity = Vector3.ZERO
		it.angular_velocity = Vector3.ZERO
	await _wait(3.0)
	_expect(reveals.size() == 2, "twee vondsten door de poort: twee onthullingen (%d)" % reveals.size())
	if reveals.size() == 2:
		var gap := float(reveals[1][1] - reveals[0][1]) / 1000.0
		_expect(gap >= Tuning.get_f("economy", "reveal_gap_s", 1.1) * 0.8, "één voor één (%.2f s ertussen)" % gap)
		var skull: Dictionary = reveals[0][0] if int(reveals[0][0].kind) == FindKinds.Kind.SKULL else reveals[1][0]
		var want := int(round(350 * 1.0 * Company.pay_factor(Company.Risk.MID) * Tuning.get_f("economy", "mod_bone_buyer", 1.4)))
		_expect(int(skull.value) == want and int(skull.bonus) == Contracts.target_bonus(FindKinds.Kind.SKULL),
				"schedel: €%d (350 × gaaf × %.2f × opkoper %.1f) en de doelbonus €%d" % [int(skull.value), Company.pay_factor(1), 1.4, int(skull.bonus)])
	_expect(a.appraised_value(finds[1].find_id) == int(round(180 * 0.8 * Company.pay_factor(1) * 1.4)) and main.hud._appraised_value(finds[1]) > 0,
			"dijbeen 80%%: €%d, nu ook zichtbaar in de HUD" % a.appraised_value(finds[1].find_id))

	# 5. Het verkoopluik: enkel van dichtbij, en enkel wat getaxeerd is.
	p.global_position = ship.anchor_position("Terminal_Use") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	var cash1 := c.cash
	a.request_sell()
	await _wait(0.2)
	_expect(c.cash == cash1 and sales.is_empty(), "verkopen van ver weg: niets")
	p.global_position = ship.anchor_position("Sell_Hatch") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	var expect_gain := a.value_of(finds[0]) + a.value_of(finds[1])
	var skull_id := finds[0].find_id
	a.request_sell()
	await _wait(0.3)
	_expect(c.cash == cash1 + expect_gain and sales.size() == 1 and int(sales[0].count) == 2, "verkocht: 2 vondsten, +€%d in de kas" % expect_gain)
	_expect(game.finds.item(skull_id) == null and c.haul_open(), "het verkochte is weg; de kabouter wacht nog")

	# 6. Tekenen met onverkochte buit: het hoofdkantoor koopt hem op aan 60%.
	var gnome_value := a.value_of(finds[2])
	var cash2 := c.cash
	var shift_before := c.shift
	# Weer Roestbol (F3): daar is elk skelet licht genoeg voor het gewone laadruim (stap 7).
	var next := 0
	for i in c.options.size():
		if int(c.options[i].planet) == PlanetType.Id.ROESTBOL:
			next = i
	c.choose(next)
	await get_tree().process_frame
	_expect(not c.haul_open() and c.cash == cash2 + int(round(gnome_value * Tuning.get_f("economy", "unsold_factor", 0.6))),
			"onverkochte kabouter opgekocht aan 60%% (+€%d), de dienst is afgesloten" % int(round(gnome_value * 0.6)))
	_expect(c.shift == shift_before + 1, "volgende dienst (%d)" % c.shift)
	while not game.world_ready():
		await get_tree().physics_frame

	# 7. Een volledig skelet (pakket F3: een echte set uit een bed, met set_id/set_size zoals FindField ze
	# maakt; vroeger nagebootst met metadata): verkocht na dezelfde dienst = bonus. Het lichtste skelet van
	# deze wereld, zodat het in het gewone laadruim past.
	var bones: Array[FindItem] = []
	var lightest := INF
	var sets := game.finds.sets()
	for id: String in sets:
		var kg := 0.0
		for it: FindItem in sets[id]:
			kg += it.mass
		if kg < lightest:
			lightest = kg
			bones.assign(sets[id])
	_expect(bones.size() >= 3 and bones[0].set_size == bones.size() and lightest <= mol.cargo_capacity(),
			"een echt skelet uit een bed: %s, %d stukken, %d kg" % [bones[0].set_label() if not bones.is_empty() else "geen", bones.size(), int(lightest)])
	for i in bones.size():
		_free_at(bones[i], mol.to_world_mol(Vector3(-0.9 + (i % 3) * 0.9, -1.2, 2.2 + (i / 3) * 0.8)))
	c.contract.modifiers = []
	await _wait(0.4)
	c.host_shift_end(mol.cargo_contents(), 0, 0, 0)
	await _wait(0.2)
	for it: FindItem in bones:
		a.host_appraise(it)
	var set_value := 0
	for it: FindItem in bones:
		set_value += a.appraised_value(it.find_id)
	var cash3 := c.cash
	sales.clear()
	a.request_sell()
	await _wait(0.3)
	var bonus := int(round(set_value * Tuning.get_f("economy", "set_bonus", 1.0)))
	_expect(not sales.is_empty() and int(sales[0].set_bonus) == bonus and bonus > 0 and c.cash == cash3 + set_value + bonus,
			"volledig skelet van %d stukken: €%d plus set-bonus €%d" % [bones.size(), set_value, bonus])
	_expect(not c.haul_open(), "alles verkocht: de dienst sluit vanzelf af")

	# 8. Kwartaal gemist: boete (schuld), proeftijd (geen hoog risico), bevroren rekening, rente.
	c.shift = Tuning.get_i("company", "shifts", 3)
	c.earned = 100
	c.cash = 200
	var rep0 := c.reputation
	reports.clear()
	c.contract = c.options[0]
	c.host_shift_end([], 0, 0, 0)
	await _wait(0.3)
	var fine := int(round((c.quota() / Tuning.get_f("company", "quota_growth", 1.4) - 100) * Tuning.get_f("company", "fine_factor", 0.5)))
	var q_report: Dictionary = reports.back() if not reports.is_empty() else {}
	_expect(str(q_report.get("type", "")) == "quarter" and str(q_report.get("quarter_result", "")) == "gemist",
			"kwartaalrapport: gemist (geen buit: meteen afgesloten)")
	_expect(c.cash < 0 and c.reputation == rep0 - 1 and c.quarter == 2, "boete: kas %s (schuld), reputatie %d, kwartaal 2" % [UiTheme.euro(c.cash), c.reputation])
	_expect(c.on_probation() and c.option_locked(2) and not c.option_locked(0), "proeftijd: de kaart met hoog risico is op slot")
	c.choose(2)
	await get_tree().process_frame
	_expect(not c.contract_ready(), "hoog risico kiezen op proeftijd: geweigerd")
	_expect(Upgrades.blocker(c, Upgrades.DRILL_T2).begins_with("Account frozen"), "met schuld: de rekening is bevroren")
	p.global_position = ship.anchor_position("Niche_Tools") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	c.buy(Upgrades.DRILL_T2, Upgrades.TOOL_RACK)
	await _wait(0.2)
	_expect(not c.has_upgrade(Upgrades.DRILL_T2), "kopen met schuld lukt niet")
	var debt := -c.cash
	c.contract = c.options[0]
	c.host_shift_end([], 0, 0, 0)
	await _wait(0.2)
	var interest := int(ceil(debt * Tuning.get_f("company", "debt_interest", 0.1)))
	_expect(c.cash == -debt - interest and int(c.last_report.get("interest", 0)) == interest, "rente op de schuld: −€%d" % interest)

	# 9. Upgrades kopen: prijs voor de ploeg, enkel aan de juiste toonbank en van dichtbij.
	c.cash = 20000
	var price := Upgrades.price(Upgrades.DRILL_T2, 1)
	_expect(price == int(round(Tuning.get_f("economy", "price_drill_t2", 6000.0) * 0.4)), "boor T2 solo: €%d (40%% van de prijs voor 4)" % price)
	c.buy(Upgrades.DRILL_T2, Upgrades.SUPPLY_DESK)
	await _wait(0.2)
	_expect(not c.has_upgrade(Upgrades.DRILL_T2), "niet te koop aan de verkeerde toonbank")
	var op := game.terrain.make_sphere_op(1, p.global_position + Vector3(0, 0, -1.0), 0.5)
	op["tool"] = Strata.Tool.BOOR_T2
	_expect(game.terrain_sync._validate(1, op) == "gereedschap niet gekocht", "zonder upgrade weigert de host een T2-hap")
	c.buy(Upgrades.DRILL_T2, Upgrades.TOOL_RACK)
	await _wait(0.2)
	_expect(c.has_upgrade(Upgrades.DRILL_T2) and c.cash == 20000 - price, "boor T2 gekocht: −€%d" % price)
	_expect(Strata.can_dig(Strata.Layer.GRANIET, Upgrades.drill_tier(c)) and Strata.can_dig(Strata.Layer.KRISTAL, Upgrades.drill_tier(c)),
			"boor T2 graaft graniet en kristal")
	await get_tree().create_timer(0.1).timeout
	_expect(game.terrain_sync._validate(1, op) == "", "de host aanvaardt nu een T2-hap (zelfde controle als de client)")
	p.global_position = ship.anchor_position("Mol_Werf") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	c.buy(Upgrades.MOL_HEAD_T2, Upgrades.MOLE_YARD)
	c.buy(Upgrades.CARGO, Upgrades.MOLE_YARD)
	await _wait(0.2)
	var granite_top := game.terrain.surface_height_at(mol.placed.origin.x, mol.placed.origin.z) - Strata.TOPS_M[Strata.Layer.GRANIET]
	_expect(mol.tier() == Strata.Tool.BOOR_T2 and mol.auto_target(2) > granite_top, "boorkop T2: de Mol boort graniet, de autopiloot gaat er tot −%d m in" % int(mol.auto_target(2)))
	_expect(is_equal_approx(mol.cargo_capacity(), Tuning.get_f("economy", "cargo_kg_t2", 140.0)), "groter laadruim: %d kg" % int(mol.cargo_capacity()))
	p.global_position = ship.anchor_position("Niche_Supply") + Vector3(0, 0.1, 0)
	await _wait(0.2)
	c.buy(Upgrades.SCANNER, Upgrades.SUPPLY_DESK)
	c.buy(Upgrades.LAMP, Upgrades.SUPPLY_DESK)
	await _wait(0.2)
	var lamp := p.find_child("HelmetLamp", true, false) as SpotLight3D
	_expect(lamp != null and is_equal_approx(lamp.spot_range, Tuning.get_f("economy", "lamp2_range", 42.0)), "helmlamp T2: bundel tot %d m" % int(lamp.spot_range if lamp else 0.0))

	# 10. De handscanner: blips binnen 10 m, nooit alles.
	var scanner := p.camera.find_child("HandScanner", true, false) as HandScanner
	var target: FindItem = null
	for it: FindItem in game.finds.items:
		if not it.freed:
			target = it
			break
	p.global_position = target.global_position + Vector3(4.0, 0.0, 0.0)
	await _wait(0.2)
	_expect(scanner != null and scanner.pulse(), "de scanner pulst (Q)")
	var far := 0
	for b: Array in scanner.blips:
		if (b[0] as Vector3).distance_to(p.camera.global_position) > Tuning.get_f("economy", "scan_range_m", 10.0) + 2.0:
			far += 1
	var near_count := 0
	for it: FindItem in game.finds.items:
		if it.global_position.distance_to(p.camera.global_position) <= 10.0:
			near_count += 1
	_expect(scanner.blips.size() >= 1 and far == 0 and scanner.blips.size() <= mini(near_count, HandScanner.MAX_BLIPS),
			"%d blips, allemaal binnen het bereik (van %d vondsten op de planeet)" % [scanner.blips.size(), game.finds.items.size()])
	_expect(not scanner.pulse(), "meteen nog eens: aan het opladen")
	await _wait(0.4)
	_expect(scanner.raised(), "de scanner staat in beeld")

	# 11. Laadruim met gewicht: te zwaar = de grijper laat vallen wat niet past.
	c.upgrades.erase(Upgrades.CARGO)
	# De zwaarste vondsten die je alleen tilt, tot boven 60 kg (welke soorten dat zijn, hangt nu van de planeet af).
	var heavy: Array[FindItem] = []
	var by_mass: Array = game.finds.items.filter(func(x: FindItem) -> bool: return not x.freed and x.mass >= 6.0 and FindKinds.liftable_alone(x.mass))
	by_mass.sort_custom(func(x: FindItem, y: FindItem) -> bool: return x.mass > y.mass)
	var kg_total := 0.0
	for it: FindItem in by_mass:
		if kg_total > 64.0 or heavy.size() >= 7:
			break
		heavy.append(it)
		kg_total += it.mass
	for i in heavy.size():
		_free_at(heavy[i], mol.to_world_mol(Vector3(-1.0 + (i % 3) * 1.0, -1.1, 1.6 + (i / 3) * 1.2)))
	await _wait(0.3)
	_expect(mol.overloaded() and mol.cargo_mass() > 60.0, "laadruim: %d kg van %d kg, te zwaar" % [int(mol.cargo_mass()), int(mol.cargo_capacity())])
	mol._jettison_overload()
	await _wait(0.1)
	var out := 0
	for it: FindItem in heavy:
		if not mol.contains_point(it.global_position):
			out += 1
	_expect(not mol.overloaded() and out >= 1, "de grijper liet %d vondsten vallen, nu %d kg" % [out, int(mol.cargo_mass())])
	c.upgrades.append(Upgrades.CARGO)

	# 12. Voorwaarden in het spel: magma, brandstof, onrust uit zichzelf, extra bedden.
	c.contract = {"seed": 5, "risk": Company.Risk.LOW, "planet": 0, "name": "TEST",
			"modifiers": [{"id": Contracts.HOT_CORE}, {"id": Contracts.LOW_FUEL}, {"id": Contracts.UNSTABLE}]}
	_expect(is_equal_approx(c.contract_magma(), Company.magma_factor(0) * Tuning.get_f("economy", "mod_hot_core", 1.25)), "hete kern: magma ×%.2f" % c.contract_magma())
	mol.fuel = 1.0
	c.host_landed()
	_expect(is_equal_approx(mol.fuel, Tuning.get_f("economy", "mod_low_fuel", 0.65)), "krappe brandstof: de Mol landt met %d%%" % int(mol.fuel * 100.0))
	game.magma.host_start(1.0)
	var u0 := game.unrest.value
	await _wait(2.0)
	_expect(game.unrest.value > u0 + 0.1, "onstabiele grond: onrust uit zichzelf (%.2f → %.2f)" % [u0, game.unrest.value])
	game.magma.host_stop()
	var seed_v := 777
	c.world_mods = []
	game.host_new_world(seed_v, 1)
	var plain := game.finds.items.size()
	c.world_mods = [{"id": Contracts.FOSSIL_BEDS}]
	game.host_new_world(seed_v, 1)
	var rich := game.finds.items.size()
	_expect(rich > plain, "rijke fossielbedden: %d vondsten tegen %d (zelfde seed)" % [rich, plain])
	c.world_mods = []
	c.contract = {}

	# 13. Bewaren en laden: upgrades, en een open buit wordt bij het laden opgekocht.
	c.cash = 500
	var free_one: FindItem = null
	for it: FindItem in game.finds.items:
		if not it.freed:
			free_one = it
			break
	_free_at(free_one, mol.to_world_mol(spots[0]))
	await _wait(0.3)
	c.contract = c.options[0]
	c.host_shift_end(mol.cargo_contents(), 0, 0, 0)
	await _wait(0.2)
	var open_value := a.value_of(free_one)
	var saved := {"cash": c.cash, "upgrades": c.upgrades.duplicate(), "quarter": c.quarter, "shift": c.shift, "rep": c.reputation}
	c.cash = 99999
	c.upgrades = []
	c.host_setup(SAVE)
	_expect(c.upgrades.size() == 5 and c.reputation == saved.rep and c.quarter == saved.quarter,
			"geladen: %d upgrades, reputatie %d, kwartaal %d" % [c.upgrades.size(), c.reputation, c.quarter])
	_expect(not c.haul_open() and c.cash == int(saved.cash) + int(round(open_value * 0.6)) and c.shift == int(saved.shift) + 1,
			"de open buit is bij het laden opgekocht (+€%d), volgende dienst" % int(round(open_value * 0.6)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(c.save_path()))
	_finish()


## Vondsten van deze soorten (de eerste die nog in de rots zitten).
func _pick(game: Game, kinds: Array) -> Array[FindItem]:
	var out: Array[FindItem] = []
	var used := {}
	for k in kinds:
		for it: FindItem in game.finds.items:
			if int(it.kind) == int(k) and not it.freed and not used.has(it.find_id):
				used[it.find_id] = true
				out.append(it)
				break
	return out


## Een vondst vrij in de wereld zetten (zoals na het uitbikken), stil op `at`.
func _free_at(it: FindItem, at: Vector3) -> void:
	var crust: Crust = it.get_parent().crusts.get(it.find_id)
	if crust:
		crust.queue_free()
		it.get_parent().crusts.erase(it.find_id)
	it.set_freed()
	it.global_position = at
	it.reset_physics_interpolation()
	it.linear_velocity = Vector3.ZERO
	it.freeze = false


func _finish() -> void:
	print("[economy_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[economy_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[economy_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
