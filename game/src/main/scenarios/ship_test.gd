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
var _lowest := INF # laagste hoogte t.o.v. de hangarvloer tijdens het lopen
## Van het loslaten tot de landing, in speltijd: de lange en de korte drop (doel ±11 s en ±7 s
## van het loslaten tot de besturing, zie docs/research/drop-en-ophalen.md).
const FULL_MAX_S := 11.5
const SHORT_MAX_S := 6.8


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
	var missing := ship.missing_anchors()
	_expect(missing.is_empty(), "het model van de hub heeft alles uit het contract (ontbreekt: %s)" % (", ".join(missing) if not missing.is_empty() else "niets"))
	var preview_only := ship.model.find_children("Sign_*", "", true, false) + ship.model.find_children("Cam_*", "", true, false) \
			+ ship.model.find_children("Look_*", "", true, false)
	_expect(preview_only.is_empty() and not (ship.anchors["Collision"] as Node3D).visible,
			"botsvorm verborgen, geen previewpunten in het spel (%d)" % preview_only.size())
	_expect(mol.mode == Mol.Mode.DOCKED and mol.body.global_position.distance_to(ship.dock_transform().origin) < 0.05,
			"de Mol staat in de dropbaai")
	var y0 := p.global_position.y
	await _wait(1.0)
	_expect(absf(p.global_position.y - y0) < 0.3, "speler staat stil op de vloer van het schip (Δy %.2f)" % (p.global_position.y - y0))

	# 2. Hendel van buiten de Mol: gebeurt niets.
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.3)
	_expect(mol.mode == Mol.Mode.DOCKED, "droppen kan enkel vanuit de Mol")

	# 2b. Te voet door de hub, met echte invoer en de fysica: van het laadrek de trap op naar het
	# werkdek, door de gang naar de brug, de verhoging op tot aan de terminal (ringtreden), eraf,
	# de trap af naar de kade en de klep op, de Mol in. Hoogtes t.o.v. de hangarvloer (layout.py).
	var use := ship.global_transform.affine_inverse() * ship.anchor_position("Terminal_Use")
	var route := [
		["het werkdek (de trap op vanuit het laadrek)", Vector3(3.0, 1.2, 29.5)],
		["de gang", Vector3(3.0, 1.2, 19.0)],
		# Recht de gang uit (niet schuin langs de stijlen van het schot), dan de verhoging op.
		["de brug, voor de gang", Vector3(3.0, 1.2, 16.0)],
		["de terminal, boven op de verhoging", use],
		["de brug, naast de verhoging", Vector3(2.8, 1.2, 16.6)],
		["de bovenkant van de trap naar de kade", Vector3(0.75, 1.2, 12.6)],
		["de kade", Vector3(0.75, 0.0, 8.8)],
		["de Mol, via de klep", ship.global_transform.affine_inverse() * mol.to_world_mol(Vector3(0.0, -1.5, 2.0))],
	]
	_lowest = INF
	var always_in_hub := true
	for leg: Array in route:
		var arrived: bool = await _walk_to(p, ship, leg[1], 0.3)
		var local := ship.global_transform.affine_inverse() * p.global_position
		always_in_hub = always_in_hub and ship.contains(p.global_position)
		_expect(arrived and absf(local.y - (leg[1] as Vector3).y) < 0.1,
				"te voet naar %s (op %.2f m, verwacht %.2f m)" % [leg[0], local.y, (leg[1] as Vector3).y])
		if leg[1] == use:
			# Aan de terminal: kijken naar de tafel, E.
			p.rotation.y = 0.0
			p.head.rotation.x = 0.0
			await get_tree().physics_frame
			var knob := p.aimed_interactable()
			_expect(knob != null and knob.hint == "E: opdrachtterminal", "aan de terminal: E opent de opdrachten (%s)" % (knob.hint if knob else "niets"))
			if knob:
				knob.used.emit(p)
				await get_tree().process_frame
				_expect(main._terminal.visible, "het opdrachtenscherm gaat open")
				main._terminal.close()
	_expect(always_in_hub and _lowest > -0.1, "onderweg altijd in de hub, nergens door de vloer (laagste %.2f m)" % _lowest)
	_expect(mol.contains_point(p.global_position), "te voet in de Mol geraakt")

	# 3. In de Mol, zonder opdracht: niets. Een opdracht kiezen maakt een nieuwe wereld.
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.4)
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.3)
	_expect(mol.mode == Mol.Mode.DOCKED, "zonder opdracht geen drop")
	var want_seed := int(game.company.options[1].seed)
	game.company.choose(1)
	await get_tree().process_frame
	while not game.terrain.is_loaded:
		await get_tree().physics_frame
	await _wait(0.5)
	_expect(game.company.contract_ready() and game.pit_seed == want_seed, "opdracht gekozen: nieuwe wereld uit zijn seed (%d)" % game.pit_seed)
	t = game.terrain # de nieuwe wereld
	_expect(ship.contains(p.global_position) and mol.contains_point(p.global_position), "de ploeg blijft in de hub, in de Mol")
	# In de Mol, hendel: aftellen, luiken open, vallen. De eerste drop van de sessie is de lange.
	_expect(mol.next_drop_variant() == Mol.DropVariant.FULL, "eerste drop van de sessie: de lange")
	await _drop_and_check(p, mol, game, "lange drop", FULL_MAX_S, 3.0)
	t = game.terrain
	var mp := mol.body.global_position
	var ground := t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM
	_expect(absf(mp.y - ground) < 0.6, "de Mol staat op de grond (%.2f m)" % (mp.y - ground))
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
	var start := Time.get_ticks_msec()
	var saw_grapple := false
	var saw_lift := false
	var saw_lift_shot := false
	var inside_lift := true
	while mol.mode != Mol.Mode.DOCKED and Time.get_ticks_msec() - start < 90000:
		await get_tree().process_frame # na de physics-tick van Mol én speler (anders een tick verschil)
		if mol.mode == Mol.Mode.GRAPPLE_DOWN:
			saw_grapple = true
		if mol.mode == Mol.Mode.LIFTING:
			saw_lift = true
			saw_lift_shot = saw_lift_shot or p.drop_cam.current
			if not mol.contains_point(p.global_position):
				if inside_lift:
					print("[ship_test] uit de Mol tijdens het ophalen: lokaal %s, Mol op %s, vy %.1f" % [
						mol.to_local_mol(p.global_position), mol.body.global_position, mol.vertical_speed])
				inside_lift = false
	_expect(saw_grapple and saw_lift, "grijper zakte en trok de Mol omhoog")
	_expect(saw_lift_shot and not p.drop_cam.current and p.camera.current,
			"buitenbeeld bij het ophalen, en terug door de eigen camera in de hub")
	_expect(mol.mode == Mol.Mode.DOCKED, "terug in de baai (%.0f s)" % ((Time.get_ticks_msec() - start) / 1000.0))
	_expect(inside_lift, "speler bleef in de Mol tijdens het ophalen")
	await _wait(3.0)
	_expect(not ship.doors_open and ship.door_amount < 0.05, "luiken weer dicht")
	_expect(_summary.z == 0, "samenvatting: niemand achtergebleven (%d)" % _summary.z)
	_expect(ship.contains(p.global_position), "speler is terug op het schip")

	# 6. Nog een drop (nieuwe opdracht, nieuwe wereld): nu de korte. Met het gewone aftellen van 8 s:
	# solo zit iedereen aan boord, dus maar 5 s.
	Tuning.set_value("ship", "drop_countdown_s", 8.0)
	game.company.choose(0 if game.company.contract != game.company.options[0] else 2)
	await get_tree().process_frame
	while not game.terrain.is_loaded:
		await get_tree().physics_frame
	await _wait(0.5)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.5)
	_expect(mol.next_drop_variant() == Mol.DropVariant.SHORT, "tweede drop van de sessie: de korte")
	await _drop_and_check(p, mol, game, "korte drop", SHORT_MAX_S, Tuning.get_f("ship", "drop_countdown_all_in_s", 5.0))

	print("[ship_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[ship_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Eén drop vanuit de Mol in de hub: het aftellen (`countdown` verwacht), de val door de luiken, het
## buitenbeeld, de landing en de overdracht van de besturing. Tijden in speltijd (physics-ticks).
func _drop_and_check(p: Player, mol: Mol, game: Game, label: String, max_s: float, countdown: float) -> void:
	var ship: Ekster = game.ship
	var local_before := mol.to_local_mol(p.global_position)
	var tool_before := p.active_tool.visible
	mol.press(Mol.Cmd.DEPART)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_expect(mol.mode == Mol.Mode.DROP_COUNTDOWN and absf(mol.countdown - countdown) < 0.2,
			"%s: aftellen van %.1f s (verwacht %.1f)" % [label, mol.countdown, countdown])
	while mol.mode == Mol.Mode.DROP_COUNTDOWN:
		await get_tree().physics_frame
	_expect(ship.doors_open and not mol.ramp_open, "%s: luiken open, klep dicht bij het vertrek" % label)
	var hz := float(Engine.physics_ticks_per_second)
	var ticks0 := Engine.get_physics_frames()
	var always_inside := true
	var max_down := 0.0
	var landed_speed := INF
	var hub_fall := 0.0 # zo diep viel de Mol in de hub voor de sprong naar buiten
	var hub_y := ship.dock_transform().origin.y
	var saw_cam := false
	var cam_in_hub := false
	var cine_all := true
	var frames := 0
	var start := Time.get_ticks_msec()
	while mol.mode == Mol.Mode.DROPPING and Time.get_ticks_msec() - start < 60000:
		await get_tree().process_frame # na de physics-tick van Mol én speler
		frames += 1
		if not mol.contains_point(p.global_position):
			always_inside = false
		max_down = maxf(max_down, -mol.vertical_speed)
		if mol.mode == Mol.Mode.DROPPING:
			landed_speed = -mol.vertical_speed
			# Vanaf het tweede frame (headless lopen soms twee ticks in één frame: de speler zag het
			# loslaten dan nog niet in zijn _process).
			if frames >= 2:
				cine_all = cine_all and p.cinematic and not p.active_tool.visible
			if mol.in_hub():
				hub_fall = maxf(hub_fall, hub_y - mol.body.global_position.y)
			if p.drop_cam.current and not saw_cam:
				saw_cam = true
				cam_in_hub = p.drop_cam.first_frame_pos.y > game.exterior.dock_position().y + 200.0
	var fall_s := (Engine.get_physics_frames() - ticks0) / hz
	print("[ship_test] %s: van het loslaten tot de landing %.2f s speltijd" % [label, fall_s])
	_expect(mol.mode == Mol.Mode.PARKED and fall_s <= max_s, "%s: geland na %.1f s speltijd (hooguit %.1f)" % [label, fall_s, max_s])
	_expect(hub_fall > 4.0, "%s: eerst %.1f m door de luiken van de hub gevallen" % [label, hub_fall])
	_expect(saw_cam and not cam_in_hub, "%s: buitenbeeld na de sprong naar buiten (gezien %s, eerste beeld %.0f m boven de baai buiten)" % [
			label, saw_cam, p.drop_cam.first_frame_pos.y - game.exterior.dock_position().y])
	_expect(cine_all, "%s: de hele val een filmpje (geen besturing, geen gereedschap)" % label)
	_expect(always_inside, "%s: speler bleef de hele val in de Mol" % label)
	_expect(max_down > 25.0, "%s: vrije val haalt snelheid (max %.0f m/s)" % [label, max_down])
	_expect(landed_speed < 4.5, "%s: zachte landing (%.1f m/s)" % [label, landed_speed])
	await get_tree().process_frame
	_expect(p.camera.current and not p.drop_cam.current, "%s: bij de klap terug door de eigen camera" % label)
	var hand0 := Engine.get_physics_frames()
	while p.cinematic and (Engine.get_physics_frames() - hand0) / hz < 3.0:
		await get_tree().physics_frame
	var hand_s := (Engine.get_physics_frames() - hand0) / hz
	_expect(not p.cinematic and hand_s <= Tuning.get_f("ship", "drop_handover_s", 0.7) + 0.3,
			"%s: besturing terug %.2f s na de landing" % [label, hand_s])
	_expect(p.active_tool.visible == tool_before, "%s: gereedschap terug in de hand" % label)
	await _wait(1.0)
	var moved := mol.to_local_mol(p.global_position).distance_to(local_before)
	_expect(moved < 0.1 and p.is_on_floor(), "%s: zelfde plek in de Mol (%.3f m), op de vloer" % [label, moved])
	var before := p.global_position
	Input.action_press("move_forward")
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_expect(p.global_position.distance_to(before) > 0.3 and mol.contains_point(p.global_position),
			"%s: lopen kan weer (%.2f m)" % [label, p.global_position.distance_to(before)])
	await _wait(1.0)


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[ship_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Te voet naar `local` (t.o.v. de hub) met echte invoer: naar het doel kijken en vooruit. True als
## hij er binnen de tijd raakt (horizontaal op `reach` m na). Daarna even stilstaan.
func _walk_to(p: Player, ship: Ekster, local: Vector3, reach: float) -> bool:
	var target := ship.global_transform * local
	var start := Time.get_ticks_msec()
	var limit := 3000.0 + 600.0 * Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length()
	var arrived := false
	Input.action_press("move_forward")
	while Time.get_ticks_msec() - start < limit:
		var to := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		if to.length() < reach:
			arrived = true
			break
		p.rotation.y = atan2(-to.x, -to.y)
		_lowest = minf(_lowest, (ship.global_transform.affine_inverse() * p.global_position).y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for i in 20:
		await get_tree().physics_frame
		_lowest = minf(_lowest, (ship.global_transform.affine_inverse() * p.global_position).y)
	return arrived
