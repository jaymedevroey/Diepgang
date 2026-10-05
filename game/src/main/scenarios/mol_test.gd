extends Node
## Test van de Mol (GDD §5A). Solo, headless: steun, instappen, rijden en boren, autopiloot,
## meerijden (speler en vondst in het laadruim), extractie met samenvatting, en hard gesteente.
## tools\godot.cmd --headless --path game -- --scenario=mol_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _summary := Vector3i(-1, -1, -1)


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(420.0).timeout.connect(func() -> void:
		print("[mol_test] GEFAALD: time-out")
		for f in _failures:
			print("[mol_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	var t: TerrainAPI = main.terrain
	var finds: FindField = main.game.finds
	mol.summary.connect(func(count: int, value: int, left: int) -> void: _summary = Vector3i(count, value, left))
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.5)

	# 1. Staat op de grond, zakt niet weg.
	var y0 := mol.body.global_position.y
	await _wait(1.0)
	_expect(absf(mol.body.global_position.y - y0) < 0.05 and mol.depth() < 0.5,
			"de Mol staat stil op het oppervlak (diepte %.2f m)" % mol.depth())
	_expect(mol.ramp_open, "laadklep staat open bij de start")

	# 1b. Van de spawn de laadklep op lopen (echte beweging, botsvormen van klep en vloer).
	p.rotation = Vector3(0, mol.yaw, 0)
	p.head.rotation.x = 0.0
	Input.action_press("move_forward")
	await _wait(3.5)
	Input.action_release("move_forward")
	await _wait(0.4)
	var feet := mol.to_local_mol(p.global_position)
	_expect(mol.contains_point(p.global_position) and feet.z < 3.8, # (tot tegen de kisten in het laadruim)
			"van de spawn de klep op gelopen, tot in de Mol (z %.1f)" % feet.z)
	_expect(feet.y > -1.75 and feet.y < -1.2, "staat op de vloer van de Mol (y %.2f)" % feet.y)

	await _side_scan(p, mol, finds)

	# 2. Een vondst vrijmaken en in het laadruim leggen.
	var it: FindItem = finds.items[0]
	for i in 20: # zoveel slagen als de korst levens heeft (7-13)
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

	# 3b. Vanuit de stoel naar de toeter kijken: de HUD toont de knop, en E (interactie) drukt hem in.
	var horn: Node3D = mol.visual.anchors["Btn_Horn"]
	var to_horn := p.camera.global_position.direction_to(horn.global_position)
	var local_dir := mol.body.global_basis.inverse() * to_horn
	p._look_yaw = atan2(-local_dir.x, -local_dir.z)
	await _wait(0.1)
	var head_dir := (p.head.global_basis.inverse() * to_horn)
	p.head.rotation.x += atan2(head_dir.y, -head_dir.z)
	await _wait(0.1)
	var knob := p.aimed_interactable()
	_expect(knob != null and knob.get_meta("mol_cmd", -1) == Mol.Cmd.HORN, "piloot mikt vanuit de stoel op de toeter (%s)" % (knob.hint if knob else "niets"))
	var aim_auto: Node3D = mol.visual.anchors["Btn_Auto_0"]
	_expect(aim_auto.global_position.distance_to(p.camera.global_position) < 2.2, "autopilootknoppen binnen bereik van de stoel (%.2f m)" % aim_auto.global_position.distance_to(p.camera.global_position))
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.2)
	_expect(p.seated and mol.pilot == p.peer_id, "E op een knop laat de piloot zitten")
	p._look_yaw = 0.0
	p.head.rotation.x = 0.0

	# 4. Zelf rijden en boren (W ingedrukt): klep gaat dicht, er wordt geboord. De Mol is traag
	#    (GDD §5A: ±1,5 m/s, trager bij het boren) en trekt traag op.
	var start := mol.body.global_position
	var ops_before: int = t.op_log().size()
	Input.action_press("move_forward")
	await _wait(0.12)
	_expect(mol.visual.throttle > 0.9, "motor en hendels reageren meteen op het gas (%.2f)" % mol.visual.throttle)
	await _wait(6.0)
	_expect(mol.speed <= Tuning.get_f("mol", "open_speed", 1.8) + 0.01, "rijdt niet sneller dan het GDD (%.2f m/s)" % mol.speed)
	Input.action_release("move_forward")
	await _wait(1.5)
	var moved := (mol.body.global_position - start).length()
	_expect(moved > 5.0, "de Mol rijdt vooruit (%.1f m)" % moved)
	_expect(t.op_log().size() > ops_before, "de kop boort zich een weg (%d ops)" % (t.op_log().size() - ops_before))
	_expect(not mol.ramp_open, "laadklep ging dicht tijdens het rijden")
	_expect(absf(mol.speed) < 0.2, "staat weer stil na het loslaten")
	_expect(mol.depth() < 0.8, "zakt niet weg bij rijden over het oppervlak (diepte %.2f m)" % mol.depth())

	# 5. Autopiloot naar −20 m, met de speler STAAND in de woonruimte (niet in de stoel).
	#    Hij moet mee bewegen: niet wegglijden, niet ronddraaien t.o.v. de Mol.
	mol.leave_seat()
	await _wait(0.3)
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw + 0.5), mol.to_world_mol(Vector3(0.7, -1.4, 0.3)))
	p.velocity = Vector3.ZERO
	await _wait(0.6)
	var stand := mol.to_local_mol(p.global_position)
	var rel_yaw := angle_difference(mol.yaw, p.rotation.y)
	var clay := mol.auto_target(0)
	mol.press(Mol.Cmd.AUTO, 0.0) # de eerste knop: in de klei
	await _wait(0.2)
	_expect(mol.mode == Mol.Mode.AUTO_DOWN, "autopiloot gestart (staand bediend, naar −%.0f m)" % clay)
	var t0 := Time.get_ticks_msec()
	var drift := 0.0
	var yaw_drift := 0.0
	var auto_max := 0.0
	while mol.mode == Mol.Mode.AUTO_DOWN and Time.get_ticks_msec() - t0 < 150000:
		auto_max = maxf(auto_max, absf(mol.speed))
		await get_tree().physics_frame
		var now_local := mol.to_local_mol(p.global_position)
		drift = maxf(drift, Vector2(now_local.x - stand.x, now_local.z - stand.z).length())
		yaw_drift = maxf(yaw_drift, absf(angle_difference(rel_yaw, angle_difference(mol.yaw, p.rotation.y))))
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	_expect(mol.mode != Mol.Mode.AUTO_DOWN, "autopiloot klaar in %.0f s" % secs)
	_expect(mol.depth() > clay - 3.0 and mol.depth() < clay + 5.0, "op diepte aangekomen (%.1f m, doel %.0f m)" % [mol.depth(), clay])
	_expect(auto_max <= Tuning.get_f("mol", "bore_speed", 1.3) + 0.01, "autopiloot niet sneller dan zelf boren (%.2f m/s)" % auto_max)
	_expect(absf(rad_to_deg(mol.pitch)) < 0.5, "waterpas geparkeerd (%.1f°)" % rad_to_deg(mol.pitch))
	_expect(mol.ramp_open, "laadklep open op diepte")
	await _wait(1.0)
	_expect(mol.contains_point(p.global_position), "staande speler reed mee")
	_expect(drift < 0.35, "staande speler gleed niet weg in de spiraal (max. %.2f m)" % drift)
	_expect(rad_to_deg(yaw_drift) < 4.0, "kijkrichting draaide mee met de Mol (max. %.1f° verschil)" % rad_to_deg(yaw_drift))
	_expect(mol.cargo_contents().has(it), "vondst reed mee in het laadruim")
	# Vanuit de Mol naar de wand mikken: het houweel ziet de rots erachter niet (niet door de wand graven).
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw - PI / 2), mol.to_world_mol(Vector3(1.2, -1.4, -0.4)))
	p.head.rotation.x = 0.0
	await _wait(0.2)
	var behind := p.global_position + -p.camera.global_basis.z * 2.5
	var ray := t.tool_raycast(p.camera.global_position, p.camera.global_position - p.camera.global_basis.z * 2.6)
	_expect(ray.is_empty(), "gereedschap gaat niet door de wand van de Mol (rots erachter: %s)" % t.is_solid(behind))

	# Vangnet: onder de wereld gevallen = terug in de Mol.
	p.global_position = Vector3(p.global_position.x, -30.0, p.global_position.z)
	await _wait(0.2)
	_expect(mol.contains_point(p.global_position), "wie onder de wereld valt, komt terug in de Mol")

	# 6. In de tunnel zelf draaien en de neus heffen: er mag geen rots in de romp komen.
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	await _wait(0.4)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.3)
	var yaw0 := mol.yaw
	p.chase.activate() # zoals Jayme: in buitenzicht rijden en dan uitstappen
	Input.action_press("move_right")
	await _wait(5.0)
	Input.action_release("move_right")
	_expect(absf(rad_to_deg(angle_difference(yaw0, mol.yaw))) > 60.0, "piloot draait ter plaatse (%.0f°)" % rad_to_deg(absf(angle_difference(yaw0, mol.yaw))))
	await _wait(0.5)
	_expect(_hull_clear(mol, t), "na het draaien zit er geen rots in de romp")
	var cam_node: Node3D = mol.visual.anchors["Cam_Feed"]
	_expect(not t.is_solid(cam_node.global_position), "kopcamera zit na het draaien niet in de rots (sdf %.2f)" % t.sdf_at(cam_node.global_position))
	Input.action_press("jump")
	await _wait(2.0)
	Input.action_release("jump")
	await _wait(0.3)
	_expect(rad_to_deg(mol.pitch) > 10.0, "neus omhoog (%.0f°)" % rad_to_deg(mol.pitch))
	_expect(_hull_clear(mol, t), "na het kantelen zit er geen rots in de romp")
	Input.action_press("crouch")
	await _wait(1.5)
	Input.action_release("crouch")
	_expect(mol.contains_point(p.global_position) and p.seated, "piloot zit nog in de Mol")

	# Uitstappen met E vanuit het buitenzicht (echte invoer): je staat in de cabine, niet ergens anders.
	var ev_leave := InputEventAction.new()
	ev_leave.action = "interact"
	ev_leave.pressed = true
	Input.parse_input_event(ev_leave)
	await _wait(0.3)
	_expect(not p.seated and mol.pilot == 0 and mol.mode == Mol.Mode.PARKED, "uitgestapt, de Mol staat geparkeerd")
	_expect(p.camera.current, "na het uitstappen weer de eigen camera (niet het buitenzicht)")
	var out_local := mol.to_local_mol(p.global_position)
	_expect(mol.contains_point(p.global_position) and out_local.z < -0.5, "na het uitstappen sta je in de cabine (lokaal %s)" % out_local)
	await _wait(1.5)
	_expect(mol.contains_point(p.global_position), "en je blijft in de Mol staan (niet weggezet, niet gevallen; %.1f m van de Mol)" % p.global_position.distance_to(mol.body.global_position))
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
	_expect(fuel_before < 1.0 and is_equal_approx(mol.fuel, 1.0), "boven bijgetankt (%d%% → 100%%)" % int(fuel_before * 100.0))

	# 8. Hard gesteente: in graniet weigert de T1-kop.
	var c := t.shaft_center_world()
	var deep := Vector3(c.x + 20.0, 60.0, c.z)
	_expect(t.layer_at(deep + Vector3(0, 0, -8.0)) == Strata.Layer.GRANIET, "testplek ligt in graniet")
	mol.leave_seat()
	p.set_physics_process(false) # in massief graniet zou hij door de rots vallen
	p.global_position = deep # de speler is de kijker: eerst moet het terrein daar geladen zijn
	await _wait(3.0)
	for dz in [-4.0, 0.0, 4.0]:
		t.debug_dig(deep + Vector3(0, 0, dz), 3.6)
	await _wait(1.0)
	mol.teleport(deep + Vector3(0, 0.6, 0), 0.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	p.set_physics_process(true)
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


## De zijscan voor wie meerijdt (F3, ontwerp-8): een regel met een vondst opzij, de felste echo vastzetten,
## een pijltje in de wand ernaartoe, en op is op.
func _side_scan(p: Player, mol: Mol, finds: FindField) -> void:
	var scan: SideScan = mol.side_scan
	var m := mol.body.global_position
	var best: FindItem = null
	for it in finds.items:
		var flat := Vector2(it.global_position.x - m.x, it.global_position.z - m.z).length()
		if not it.freed and flat > 4.0 and flat < 28.0 and absf(it.global_position.y - m.y) < 9.0 \
				and (best == null or Sonar.size_of(it) > Sonar.size_of(best)):
			best = it
	_expect(best != null, "een vondst opzij van de Mol voor de zijscan")
	if best == null:
		return
	# De Mol zo gedraaid dat die vondst recht opzij ligt (in het vlak van de zijscan).
	var side := best.global_position - m
	side.y = 0.0
	var fwd := side.normalized().cross(Vector3.UP)
	scan.rows.clear()
	scan.scan_row(Transform3D(Basis.looking_at(fwd, Vector3.UP), m))
	var row: SideScan.Row = scan.rows[0]
	var lit := 0.0
	for b in SideScan.BINS * 2:
		lit = maxf(lit, row.power[b])
	_expect(row.best_id >= 0 and lit > 0.2, "zijscan: een echo opzij (%s op %.0f m, sterkte %.2f)" % [
			best.display_name(), side.length(), lit])
	_expect(scan.lock() != null, "zijscan: de felste echo staat vast")
	var target: FindItem = finds.item(scan.lock().best_id)
	var darts := scan.darts
	scan.mark()
	await _wait(0.3)
	_expect(scan.markers.size() == 1 and scan.darts == darts - 1, "pijltje in de wand (%d over)" % scan.darts)
	if scan.markers.size() == 1:
		var mk: Node3D = scan.markers[0]
		_expect(mk.global_position.distance_to(target.global_position) <= m.distance_to(target.global_position) + 0.5,
				"het pijltje zit tussen de Mol en de vondst (%.1f m ervan)" % mk.global_position.distance_to(target.global_position))
	scan._rpc_darts(0)
	await _wait(1.6) # (afkoelen)
	scan.mark()
	await _wait(0.3)
	_expect(scan.markers.size() == 1, "op is op: geen pijltje meer zonder pijltjes")
	scan.host_refill()
	await _wait(0.1)
	_expect(scan.darts == Tuning.get_i("mol", "side_scan_darts", 6), "pijltjes bijgeladen (%d)" % scan.darts)
	scan.clear()


## Geen rots binnen de romp: punten op 2,3 m van de as, over de hele lengte.
func _hull_clear(mol: Mol, t: TerrainAPI) -> bool:
	var bad := 0
	for z in [-7.6, -6.0, -4.0, -2.0, 0.0, 2.0, 4.0]:
		for k in 8:
			var a := k / 8.0 * TAU
			var local := Vector3(cos(a) * 2.3, sin(a) * 2.0, z)
			if t.is_solid(mol.to_world_mol(local)):
				bad += 1
	if bad > 0:
		print("[mol_test] %d rotspunten in de romp" % bad)
	return bad == 0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[mol_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
