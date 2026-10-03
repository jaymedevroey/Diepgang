extends Node
## Test van De Ekster en de drop (GDD v3 §3). Solo, headless:
## spawnen op het schip, de Mol in de baai, droppen (speler blijft in de Mol), landen op de
## landingsplek met een zachte snelheid, uit het schip springen (landt op de grond, niet erdoor),
## en het ophalen met de grijper tot terug in de baai.
## tools\godot.cmd --headless --path game -- --scenario=ship_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _summary := Vector3i(-1, -1, -1)


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print("[ship_test] GEFAALD: time-out")
		for f in _failures:
			print("[ship_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var game: Game = main.game
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	var t: TerrainAPI = game.terrain
	mol.summary.connect(func(count: int, value: int, left: int) -> void: _summary = Vector3i(count, value, left))
	Tuning.set_value("ship", "drop_countdown_s", 3.0)
	Tuning.set_value("mol", "countdown_s", 2.0)
	await _wait(1.0)

	# 1. Op het schip, de Mol in de baai.
	_expect(ship != null and ship.contains(p.global_position), "speler spawnt in De Ekster")
	_expect(mol.mode == Mol.Mode.DOCKED and mol.body.global_position.distance_to(ship.dock_transform().origin) < 0.05,
			"de Mol staat in de dropbaai")
	var y0 := p.global_position.y
	await _wait(1.0)
	_expect(absf(p.global_position.y - y0) < 0.3, "speler staat stil op de vloer van het schip (Δy %.2f)" % (p.global_position.y - y0))

	# 2. Hendel van buiten de Mol: gebeurt niets.
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.3)
	_expect(mol.mode == Mol.Mode.DOCKED, "droppen kan enkel vanuit de Mol")

	# 3. In de Mol, hendel: aftellen, luiken open, vallen.
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.4)
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.3)
	_expect(mol.mode == Mol.Mode.DROP_COUNTDOWN, "aftellen voor de drop")
	while mol.mode == Mol.Mode.DROP_COUNTDOWN:
		await get_tree().physics_frame
	_expect(ship.doors_open and not mol.ramp_open, "luiken open, klep dicht bij het vertrek")
	var always_inside := true
	var max_down := 0.0
	var landed_speed := INF
	var last_vy := 0.0
	var start := Time.get_ticks_msec()
	while mol.mode == Mol.Mode.DROPPING and Time.get_ticks_msec() - start < 60000:
		await get_tree().process_frame
		if not mol.contains_point(p.global_position):
			always_inside = false
		max_down = maxf(max_down, -mol.vertical_speed)
		last_vy = mol.vertical_speed
		if mol.mode == Mol.Mode.DROPPING:
			landed_speed = -last_vy
	_expect(mol.mode == Mol.Mode.PARKED, "de Mol is geland (%.1f s)" % ((Time.get_ticks_msec() - start) / 1000.0))
	_expect(always_inside, "speler bleef de hele val in de Mol")
	_expect(max_down > 25.0, "vrije val haalt snelheid (max %.0f m/s)" % max_down)
	_expect(landed_speed < 4.5, "zachte landing (%.1f m/s)" % landed_speed)
	var mp := mol.body.global_position
	var ground := t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM
	_expect(absf(mp.y - ground) < 0.6, "de Mol staat op de grond (%.2f m)" % (mp.y - ground))
	await _wait(1.5)
	_expect(mol.ramp_open and mol.contains_point(p.global_position), "klep open, speler nog in de Mol")

	# 4. Uit het schip springen: landt op de planeet, niet erdoor.
	var jumper_start := ship.global_transform * Vector3(2.0, 0.5, 5.0) # boven de open baai, naast waar de Mol stond
	p.global_position = jumper_start
	p.velocity = Vector3.ZERO
	var t0 := Time.get_ticks_msec()
	var lowest := INF
	while Time.get_ticks_msec() - t0 < 25000:
		await get_tree().physics_frame
		lowest = minf(lowest, p.global_position.y)
		if p.is_on_floor() and p.global_position.y < jumper_start.y - 100.0:
			break
	var surf := t.surface_height_at(p.global_position.x, p.global_position.z)
	_expect(p.is_on_floor() and absf(p.global_position.y - surf) < 2.0,
			"uit het schip gesprongen: op de grond geland (%.1f m boven het oppervlak)" % (p.global_position.y - surf))
	_expect(lowest > surf - 3.0, "niet door de grond gevallen (laagste %.1f m t.o.v. het oppervlak)" % (lowest - surf))

	# 5. Terug in de Mol, vertrekken: grijper komt, trekt de Mol in de baai.
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.4)
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.3)
	_expect(mol.mode == Mol.Mode.COUNTDOWN, "vertrek vanaf de landingsplek")
	start = Time.get_ticks_msec()
	var saw_grapple := false
	var saw_lift := false
	var inside_lift := true
	while mol.mode != Mol.Mode.DOCKED and Time.get_ticks_msec() - start < 90000:
		await get_tree().process_frame # na de physics-tick van Mol én speler (anders een tick verschil)
		if mol.mode == Mol.Mode.GRAPPLE_DOWN:
			saw_grapple = true
		if mol.mode == Mol.Mode.LIFTING:
			saw_lift = true
			if not mol.contains_point(p.global_position):
				if inside_lift:
					print("[ship_test] uit de Mol tijdens het ophalen: lokaal %s, Mol op %s, vy %.1f" % [
						mol.to_local_mol(p.global_position), mol.body.global_position, mol.vertical_speed])
				inside_lift = false
	_expect(saw_grapple and saw_lift, "grijper zakte en trok de Mol omhoog")
	_expect(mol.mode == Mol.Mode.DOCKED, "terug in de baai (%.0f s)" % ((Time.get_ticks_msec() - start) / 1000.0))
	_expect(inside_lift, "speler bleef in de Mol tijdens het ophalen")
	await _wait(3.0)
	_expect(not ship.doors_open and ship.door_amount < 0.05, "luiken weer dicht")
	_expect(_summary.z == 0, "samenvatting: niemand achtergebleven (%d)" % _summary.z)
	_expect(ship.contains(p.global_position), "speler is terug op het schip")

	print("[ship_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[ship_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[ship_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
