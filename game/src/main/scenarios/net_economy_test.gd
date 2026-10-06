extends Node
## Nettest van de economie (F1, host + client via tools/net_test.py --scenario=net_economy_test):
## de client koopt een upgrade aan de toonbank (via de host, met de afstand en de prijs), aan de
## verkeerde toonbank wordt het geweigerd; na een (nagebootste) dienst ziet de client de buit met een
## onbekende waarde, draagt zelf een vondst door de taxatiepoort (de host taxeert, de client krijgt de
## onthulling) en verkoopt aan het luik. Host en client hebben daarna dezelfde kas en upgrades.
## Wat de client voorspelt, aanvaardt de host: dezelfde controles (Upgrades.blocker, de poort).
## Naam van deze node is "Scenario" op elke peer, zodat de RPC's aankomen.

const TIMEOUT_S := 200.0

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _client_ready := false
var _step := 0 # host -> client: welke stap nu
var _client_done := -1 # client -> host: laatste afgewerkte stap
var _client_info: Dictionary = {}


func _ready() -> void:
	main.game.player_spawned.connect(_on_player_spawned)
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		print("[net_economy_test] GEFAALD: time-out na %.0f s" % TIMEOUT_S)
		for f in _failures:
			print("[net_economy_test] MISLUKT: ", f)
		get_tree().quit(1))


func _on_player_spawned(p: Player) -> void:
	if p.is_local and not Net.is_host():
		_run_client.call_deferred(p)
	elif p.is_local and Net.is_host():
		_run_host.call_deferred(p)


# --- Client ------------------------------------------------------------------------------------

func _run_client(p: Player) -> void:
	var game: Game = main.game
	var c: Company = game.company
	var ship: Ekster = game.ship
	var denied: Array = []
	var reveals: Array = []
	c.buy_denied.connect(func(_id: String, why: String) -> void: denied.append(why))
	c.appraisal.revealed.connect(func(info: Dictionary) -> void: reveals.append(info))
	var scans: Array = []
	c.appraisal.scan_started.connect(func(info: Dictionary) -> void: scans.append(info))
	await _wait(2.0)
	_rpc_client_ready.rpc_id(1)
	# Stap 1: kopen aan het gereedschapsrek, en de scanner aan de verkeerde toonbank.
	await _until(1)
	await _stand(p, ship.anchor_position(Upgrades.TOOL_RACK))
	await _wait(0.5)
	c.buy(Upgrades.DRILL_T2, Upgrades.TOOL_RACK)
	c.buy(Upgrades.SCANNER, Upgrades.TOOL_RACK)
	await _wait(1.0)
	_rpc_done.rpc_id(1, 1, {"upgrades": c.upgrades.duplicate(), "cash": c.cash, "denied": denied.duplicate(),
			"tier": int(Upgrades.drill_tier(c))})
	# Stap 2: de buit staat open; een vondst oppakken in de Mol en door de poort dragen.
	await _until(2)
	var ids: Array = c.haul.get("ids", [])
	var it: FindItem = game.finds.item(int(ids[0])) if not ids.is_empty() else null
	var unknown: bool = it != null and c.appraisal.appraised_value(it.find_id) == -1 and main.hud._appraised_value(it) == -1
	if it:
		await _stand(p, it.global_position + Vector3(0.0, -0.3, 1.2))
		_face(p, it.global_position)
		await _wait(0.5) # de host moet de nieuwe plek kennen (afstand tot de vondst)
		game.finds.request_grab(it.find_id)
		var t0 := Time.get_ticks_msec()
		while not it.carriers.has(p.peer_id) and Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
		var gate := ship.anchor_position("Appraisal_Gate")
		await _stand(p, gate + Vector3(-0.35, 0.0, 0.0))
		_face(p, gate + Vector3(2.0, 1.0, 0.0))
		t0 = Time.get_ticks_msec()
		while reveals.is_empty() and Time.get_ticks_msec() - t0 < 6000:
			await get_tree().process_frame
		game.finds.request_release(it.find_id, it.global_transform, Vector3.ZERO)
		# Van de band af (naast de poort): wie op de band blijft staan, houdt de volgende vondst tegen.
		await _wait(0.3)
		await _stand(p, ship.anchor_position("Appraisal_Gate") + Vector3(0.0, 0.0, 2.3))
	await _wait(0.5)
	_rpc_done.rpc_id(1, 2, {"unknown_before": unknown, "reveals": reveals.size(),
			"value": int(reveals[0].value) if not reveals.is_empty() else -1, "known_after": it != null and main.hud._appraised_value(it) > 0})
	# Stap 3: verkopen aan het luik.
	await _until(3)
	await _stand(p, ship.anchor_position("Sell_Hatch"))
	await _wait(0.5)
	c.appraisal.request_sell()
	await _wait(1.0)
	_rpc_done.rpc_id(1, 3, {"cash": c.cash, "haul_open": c.haul_open(), "earned": c.earned, "scans": scans.size(),
			"reveals": reveals.size(), "sale_items": (c.appraisal.last_sale.get("items", []) as Array).size()})


func _until(step: int) -> void:
	while _step < step:
		await get_tree().process_frame


# --- Host --------------------------------------------------------------------------------------

func _run_host(p: Player) -> void:
	var game: Game = main.game
	var c: Company = game.company
	var mol: Mol = game.mol
	while not _client_ready:
		await get_tree().process_frame
	await _wait(0.5)
	# 1. De client koopt (de host beslist), aan de verkeerde toonbank niet.
	c.cash = 15000 # golf 3: upgrades ×1,5; genoeg voor de boor én de scanner (anders "te weinig geld" i.p.v. "verkeerde toonbank")
	c._broadcast()
	await _wait(0.5)
	_set_step(1)
	await _done(1)
	var price := Upgrades.price(Upgrades.DRILL_T2, c.team_size())
	_expect(c.has_upgrade(Upgrades.DRILL_T2) and c.cash == 15000 - price, "client kocht boor T2 via de host (−€%d, ploeg van 2)" % price)
	_expect(not c.has_upgrade(Upgrades.SCANNER) and "Not sold at this counter" in _client_info.get("denied", []),
			"scanner aan het gereedschapsrek: geweigerd, de client hoort waarom")
	_expect((_client_info.upgrades as Array).has(Upgrades.DRILL_T2) and int(_client_info.cash) == c.cash and int(_client_info.tier) == Strata.Tool.BOOR_T2,
			"client: dezelfde upgrades en kas (€%d), zijn boor is T2" % int(_client_info.cash))
	# 2. Een dienst nabootsen: twee vondsten in het laadruim, de client draagt er een door de poort.
	var picks: Array[FindItem] = []
	for it: FindItem in game.finds.items:
		if not it.freed and picks.size() < 2:
			picks.append(it)
	game.finds._rpc_freed.rpc(picks[0].find_id, 0)
	game.finds._rpc_freed.rpc(picks[1].find_id, 0)
	await _wait(0.3)
	for i in 2:
		picks[i].global_position = mol.to_world_mol(Vector3(-0.5 + i, -1.2, 2.8))
		picks[i].linear_velocity = Vector3.ZERO
	await _wait(0.8)
	c.contract = c.options[0] # zonder nieuwe wereld
	c.host_shift_end(mol.cargo_contents(), 0, 0, 0)
	await _wait(0.5)
	_expect(c.haul_open() and (c.haul.ids as Array).size() == 2, "na de dienst: 2 vondsten wachten op de taxatie")
	_set_step(2)
	await _done(2)
	_expect(bool(_client_info.unknown_before), "client: de waarde van de buit is onbekend tot de taxatie")
	_expect(int(_client_info.reveals) == 1 and int(_client_info.value) == c.appraisal.appraised_value(picks[0].find_id) and bool(_client_info.known_after),
			"client droeg een vondst door de poort: de host taxeerde (€%d), de client zag de onthulling" % int(_client_info.value))
	# 3. Golf 3: de tweede vondst op de band aan de voet van de klep; de band draagt hem de poort in
	# (de host beweegt hem, iedereen ziet de scan en de onthulling). Daarna verkoopt de client alles.
	var gate_xf := (game.ship.anchors["Appraisal_Gate"] as Node3D).global_transform
	picks[1].global_position = gate_xf * Vector3(-2.8, picks[1].rest_height() + 0.05, 0.0)
	picks[1].reset_physics_interpolation()
	picks[1].linear_velocity = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	while not c.appraisal.is_appraised(picks[1].find_id) and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	var bx := (gate_xf.affine_inverse() * picks[1].global_position).x
	_expect(c.appraisal.is_appraised(picks[1].find_id) and bx > -0.5,
			"de band droeg de vondst van de klep de poort in (x %.2f), de host taxeerde hem" % bx)
	await _wait(2.5)
	var cash_before := c.cash
	var gain := c.appraisal.value_of(picks[0]) + c.appraisal.value_of(picks[1])
	_set_step(3)
	await _done(3)
	_expect(c.cash == cash_before + gain and not c.haul_open(), "client verkocht aan het luik: +€%d, de dienst is afgesloten" % gain)
	_expect(int(_client_info.cash) == c.cash and not bool(_client_info.haul_open) and int(_client_info.earned) == c.earned,
			"client: dezelfde kas (€%d) en het kwartaal (€%d)" % [int(_client_info.cash), int(_client_info.earned)])
	_expect(int(_client_info.get("scans", 0)) >= 2 and int(_client_info.get("reveals", 0)) >= 2 and int(_client_info.get("sale_items", 0)) == 2,
			"client zag elke scan en onthulling, en de verkoop per stuk (%d scans, %d onthullingen, %d stukken)" % [
			int(_client_info.get("scans", 0)), int(_client_info.get("reveals", 0)), int(_client_info.get("sale_items", 0))])
	_finish()


func _set_step(step: int) -> void:
	_step = step
	_rpc_step.rpc(step)


func _done(step: int) -> void:
	while _client_done < step:
		await get_tree().process_frame


@rpc("authority", "reliable")
func _rpc_step(step: int) -> void:
	_step = step


@rpc("any_peer", "reliable")
func _rpc_client_ready() -> void:
	_client_ready = true


@rpc("any_peer", "reliable")
func _rpc_done(step: int, info: Dictionary) -> void:
	_client_info = info
	_client_done = step


func _stand(p: Player, at: Vector3) -> void:
	p.velocity = Vector3.ZERO
	p.global_position = at + Vector3(0.0, 0.05, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


func _face(p: Player, target: Vector3) -> void:
	var to := target - p.camera.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _finish() -> void:
	print("[net_economy_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[net_economy_test] MISLUKT: ", f)
	# De client mag ook stoppen.
	_rpc_quit.rpc()
	await _wait(0.5)
	get_tree().quit(0 if _failures.is_empty() else 1)


@rpc("authority", "reliable")
func _rpc_quit() -> void:
	get_tree().quit(0)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[net_economy_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
