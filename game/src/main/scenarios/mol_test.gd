extends Node
## Test van de Mol (GDD §5A). Solo, headless: steun, instappen, rijden en boren, autopiloot,
## meerijden (speler en vondst in het laadruim), extractie met samenvatting, en hard gesteente.
## tools\godot.cmd --headless --path game -- --scenario=mol_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _summary := Vector2i(-1, -1)


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("[mol_test] GEFAALD: time-out")
		for f in _failures:
			print("[mol_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	var t: TerrainAPI = main.terrain
	var finds: FindField = main.game.finds
	mol.summary.connect(func(count: int, value: int) -> void: _summary = Vector2i(count, value))
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.5)

	# 1. Staat op de grond, zakt niet weg.
	var y0 := mol.body.global_position.y
	await _wait(1.0)
	_expect(absf(mol.body.global_position.y - y0) < 0.05 and mol.depth() < 0.5,
			"de Mol staat stil op het oppervlak (diepte %.2f m)" % mol.depth())
	_expect(mol.ramp_open, "laadklep staat open bij de start")

	# 2. Een vondst vrijmaken en in het laadruim leggen.
	var it: FindItem = finds.items[0]
	for i in 6:
		if it.freed:
			break
		p.global_position = it.global_position + Vector3(0, 0.3, 1.2)
		finds.hit_crust(it.find_id, Strata.Tool.HOUWEEL, it.global_position)
		await _wait(0.35)
	_expect(it.freed, "vondst vrijgemaakt")
	it.freeze = false
	it.global_transform = Transform3D(Basis.from_euler(Vector3(0, mol.yaw, 0)), mol.to_world_mol(Vector3(0.6, -1.0, 2.8)))
	it.linear_velocity = Vector3.ZERO
	it.angular_velocity = Vector3.ZERO
	await _wait(1.5)
	_expect(mol.cargo_contents().has(it), "vondst ligt in het laadruim")

	# 3. Instappen en plaatsnemen.
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	await _wait(0.3)
	_expect(mol.contains_point(p.global_position), "speler staat in de Mol")
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.3)
	_expect(mol.pilot == p.peer_id and p.seated and mol.mode == Mol.Mode.DRIVING, "speler zit aan het stuur")

	# 4. Zelf rijden en boren (W ingedrukt): klep gaat dicht, er wordt geboord.
	var start := mol.body.global_position
	var ops_before: int = t.op_log().size()
	Input.action_press("move_forward")
	await _wait(4.0)
	Input.action_release("move_forward")
	await _wait(1.5)
	var moved := (mol.body.global_position - start).length()
	_expect(moved > 5.0, "de Mol rijdt vooruit (%.1f m)" % moved)
	_expect(t.op_log().size() > ops_before, "de kop boort zich een weg (%d ops)" % (t.op_log().size() - ops_before))
	_expect(not mol.ramp_open, "laadklep ging dicht tijdens het rijden")
	_expect(absf(mol.speed) < 0.2, "staat weer stil na het loslaten")

	# 5. Autopiloot naar −20 m.
	mol.press(Mol.Cmd.AUTO, 20.0)
	await _wait(0.2)
	_expect(mol.mode == Mol.Mode.AUTO_DOWN, "autopiloot gestart")
	var t0 := Time.get_ticks_msec()
	while mol.mode == Mol.Mode.AUTO_DOWN and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().physics_frame
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_expect(mol.mode != Mol.Mode.AUTO_DOWN, "autopiloot klaar in %.0f s" % secs)
	_expect(mol.depth() > 18.0 and mol.depth() < 26.0, "op diepte aangekomen (%.1f m)" % mol.depth())
	_expect(absf(rad_to_deg(mol.pitch)) < 0.5, "waterpas geparkeerd (%.1f°)" % rad_to_deg(mol.pitch))
	_expect(mol.ramp_open, "laadklep open op diepte")
	await _wait(1.0)
	_expect(mol.contains_point(p.global_position) and p.seated, "piloot reed mee")
	_expect(mol.cargo_contents().has(it), "vondst reed mee in het laadruim")

	# 6. Uitstappen en de tunnel in lopen.
	mol.leave_seat()
	await _wait(0.3)
	_expect(not p.seated and mol.pilot == 0 and mol.mode == Mol.Mode.PARKED, "uitgestapt, de Mol staat geparkeerd")
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.4, 1.0)))
	await _wait(0.5)

	# 7. Vertrekhendel: aftellen, dan zelf terug naar boven met de vondst.
	var fuel_before := mol.fuel
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.2)
	_expect(mol.mode == Mol.Mode.COUNTDOWN, "aftellen gestart")
	t0 = Time.get_ticks_msec()
	while mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING] and Time.get_ticks_msec() - t0 < 90000:
		await get_tree().physics_frame
	secs = (Time.get_ticks_msec() - t0) / 1000.0
	_expect(mol.mode == Mol.Mode.PARKED, "extractie klaar in %.0f s" % secs)
	_expect(mol.depth() < 1.0, "terug aan het oppervlak (%.2f m)" % mol.depth())
	_expect(mol.body.global_position.distance_to(start) < 4.0, "terug bij het vertrekpunt (%.1f m)" % mol.body.global_position.distance_to(start))
	_expect(mol.contains_point(p.global_position), "speler reed mee naar boven")
	_expect(_summary.x >= 1 and _summary.y > 0, "samenvatting: %d vondst(en), €%d" % [_summary.x, _summary.y])
	_expect(mol.fuel <= fuel_before, "brandstof %d%%" % int(mol.fuel * 100.0))

	# 8. Hard gesteente: in graniet weigert de T1-kop.
	var c := t.shaft_center_world()
	var deep := Vector3(c.x + 20.0, 60.0, c.z)
	_expect(t.layer_at(deep + Vector3(0, 0, -8.0)) == Strata.Layer.GRANIET, "testplek ligt in graniet")
	mol.leave_seat()
	p.global_position = deep # de speler is de kijker: eerst moet het terrein daar geladen zijn
	await _wait(3.0)
	for dz in [-4.0, 0.0, 4.0]:
		t.debug_dig(deep + Vector3(0, 0, dz), 3.6)
	await _wait(1.0)
	mol.teleport(deep + Vector3(0, 0.6, 0), 0.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	await _wait(1.0)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.3)
	var hard_start := mol.body.global_position
	Input.action_press("move_forward")
	await _wait(2.5)
	_expect(mol.blocked, "kop te zwak voor graniet: geblokkeerd")
	Input.action_release("move_forward")
	var crept := (mol.body.global_position - hard_start) * Vector3(1, 0, 1)
	_expect(crept.length() < 2.6, "rijdt niet door graniet (%.2f m)" % crept.length())

	print("[mol_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[mol_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[mol_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
