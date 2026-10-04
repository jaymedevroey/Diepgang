extends Node
## Opname van de hele overgang, zoals de speler ze ziet: aan de terminal een opdracht kiezen, de
## nieuwe wereld laden, in de Mol stappen, de hendel, het aftellen, de luiken, de val, het remmen,
## de landing en de eerste seconden met besturing (rondkijken in de Mol, uitstappen, de horizon).
## Daarna buitencamera's boven de landingsplek (alle richtingen, meerdere hoogtes) en door de open
## baai van de hub naar beneden, om de rand van de wereld te zoeken. Met --repeat ook terug naar
## het schip (het ophalen, met het buitenbeeld) en een tweede keer droppen.
##
## Beelden: logs/drop_seq/<tag>/NNN_<moment>_t<speltijd>.png (tag: --tag=naam, standaard "run").
## De tijd in de naam is SPELTIJD: het opslaan van een beeld houdt het spel even op, dus de echte
## tijd tussen twee bestanden zegt niets over hoe lang iets in het spel duurt.
## Daarnaast in dezelfde map: tijdlijn.csv (elke frame: speltijd, toestand van de Mol, hoogte,
## camera, cinematic, muis, HUD) en samenvatting.txt (duur van elke fase in speltijd, de
## camerawissels, en de fouten in de log).
##
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=drop_sequence --tag=voor --no-steam
## Opties:
##   --step=0.5      seconden speltijd tussen beelden tijdens het aftellen en de val
##   --repeat        terug naar het schip (ophalen) en een tweede keer droppen
##   --skip          tijdens de eerste drop overslaan zodra het buitenbeeld er is (actie skip_cinematic)
##   --no-outside    geen buitencamera's boven de landingsplek en in de hub
##   --horizon       extra buitencamera's: 7 hoogtes (4 m tot 1740 m) × 8 richtingen
##   --kade          tijdens het aftellen om de beurt ook een beeld vanaf de kade in de hub
##   --left-behind   de speler blijft bij de eerste drop in de hub (kijkt naar de baai) en springt
##                   daarna zelf door de open baai naar beneden (beelden van de val)
##   --strict        afsluiten met code 1 als er fouten in de log stonden
## Contactblad: py -3.11 tools/contact_sheet.py logs/drop_seq/<tag>
## Voor/na:     py -3.11 tools/contact_sheet.py logs/drop_seq/na --compare=logs/drop_seq/voor

const ErrorLog := preload("res://src/main/scenarios/qa_error_log.gd")
## Hoogtes (m boven de grond) waarop tijdens de val een extra beeld komt: vergelijkbaar voor en na,
## ook als de val anders getimed is.
const CROSSINGS := [300.0, 200.0, 100.0, 50.0, 20.0]

var main: Node
var _cam: Camera3D
var _dir := ""
var _n := 0
var _gt := 0.0 # speltijd sinds de start van de opname
var _t0 := 0
var _log: Logger
var _rows: PackedStringArray = []
var _p: Player
var _mol: Mol
var _last_h := INF
var _skip_seen_at := -1.0


func _ready() -> void:
	_log = ErrorLog.new()
	OS.add_logger(_log)
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(900.0).timeout.connect(func() -> void:
		print("[drop_sequence] GEFAALD: time-out")
		_write_files()
		get_tree().quit(1))


func _process(delta: float) -> void:
	_gt += delta
	if _p == null or _mol == null or _mol.body == null:
		return
	var h := _height()
	# Overslaan zichtbaar maken: de Mol springt in één frame tientallen meters omlaag (buiten de hub).
	if _mol.mode == Mol.Mode.DROPPING and _last_h < 1000.0 and _last_h - h > 40.0 and _skip_seen_at < 0.0:
		_skip_seen_at = _gt
		print("[drop_sequence] de Mol sprong van %.0f naar %.0f m (overslaan?) op %.2f s" % [_last_h, h, _gt])
	_last_h = h
	var hud: Hud = main.hud
	var cine: Variant = _p.get("cinematic")
	_rows.append("%.3f,%.3f,%s,%.2f,%.2f,%.2f,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d" % [
		_gt, (Time.get_ticks_msec() - _t0) / 1000.0, _mode_name(_mol), h, _mol.vertical_speed, _mol.thrust,
		_cam_kind(), "-" if cine == null else str(int(cine)), Input.mouse_mode, int(hud.visible),
		int(hud.crosshair.is_visible_in_tree() and hud.crosshair.modulate.a > 0.05), int(hud._banner.visible),
		int(hud._result.visible), int(_mol.contains_point(_p.global_position)),
		int(main.game.ship != null and main.game.ship.contains(_p.global_position)), Engine.get_frames_per_second()])


func _run(p: Player) -> void:
	var game: Game = main.game
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	_p = p
	_mol = mol
	_dir = PerfLog.log_dir().path_join("drop_seq").path_join(str(CmdArgs.value("tag", "run")))
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	_t0 = Time.get_ticks_msec()
	_gt = 0.0
	_cam = Camera3D.new()
	_cam.name = "QaCam"
	_cam.fov = 75.0
	_cam.near = 0.1
	_cam.far = 8000.0
	main.add_child(_cam)
	await _wait(1.5)

	# 1. Aan de opdrachttafel, het menu open.
	_stand_at_terminal(p, ship)
	await _wait(0.6)
	await _shot("terminal_zicht")
	main._terminal.open(game.company)
	await _shot("terminal_menu", 0.6)
	main._terminal.close()
	# 2. Kiezen: de nieuwe wereld laadt (wat ziet de speler intussen?).
	# --planet=roestbol|fossielwereld|kristalmaan: de opdracht op die planeet (anders de middelste).
	var pick := 1
	var want := str(CmdArgs.value("planet", "")).to_lower()
	for i in game.company.options.size():
		if want != "" and PlanetType.NAMES[int(game.company.options[i].get("planet", 0))].to_lower() == want:
			pick = i
	game.company.choose(pick)
	for k in 6:
		await _shot("na_kiezen_%d" % k, 0.5)
	while not game.terrain.is_loaded:
		await get_tree().process_frame
	await _shot("wereld_geladen", 0.5)

	# 3. In de Mol, de hendel.
	await _drop_once(p, mol, ship, "drop1", CmdArgs.has("skip"), CmdArgs.has("left-behind"))

	# 3b. Achtergebleven: zelf door de open baai van de hub springen.
	if CmdArgs.has("left-behind"):
		await _jump_through_bay(p, ship, game)

	# 4. Na de landing: rondkijken in de Mol, uitstappen, de horizon vanaf de grond.
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.4)
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		p.rotation.y = mol.yaw + deg_to_rad(yaw)
		p.head.rotation.x = 0.0
		await _shot("mol_binnen_%03d" % int(yaw), 0.4)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.0, 7.5))
	await _wait(0.8)
	for yaw in [0.0, 90.0, 180.0, 270.0]:
		p.rotation.y = mol.yaw + deg_to_rad(yaw)
		p.head.rotation.x = deg_to_rad(4.0)
		await _shot("buiten_grond_%03d" % int(yaw), 0.4)

	# 5. Buitencamera's boven de landingsplek en door de open baai van de hub: de rand van de wereld.
	if not CmdArgs.has("no-outside"):
		var land := mol.body.global_position
		for h in [340.0, 160.0, 60.0]:
			for yaw in [0.0, 90.0, 180.0, 270.0]:
				var b := Basis(Vector3.UP, deg_to_rad(yaw))
				_cam.global_position = land + Vector3(0.0, h, 0.0) + b * Vector3(0.0, 0.0, 40.0)
				_cam.look_at(_cam.global_position + b * Vector3(0.0, -0.18 - h / 1400.0, -1.0), Vector3.UP)
				_cam.make_current()
				await _shot("hoogte_%03d_%03d" % [int(h), int(yaw)], 0.3)
		await _hub_views(ship)
		p.camera.make_current()
	if CmdArgs.has("horizon"):
		await _horizon_views(mol.body.global_position)
		p.camera.make_current()

	# 6. Terug naar het schip en nog eens.
	if CmdArgs.has("repeat"):
		p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
		await _wait(0.6)
		mol.press(Mol.Cmd.DEPART)
		var start := _gt
		var last := -10.0
		var lift_start := -1.0
		while mol.mode != Mol.Mode.DOCKED and _gt - start < 180.0:
			await get_tree().process_frame
			if mol.mode == Mol.Mode.LIFTING and lift_start < 0.0:
				lift_start = _gt
			# Het buitenbeeld bij het vertrek dicht opvolgen (de eerste 8 s van het ophalen).
			var every := 0.5 if lift_start >= 0.0 and _gt - lift_start < 8.0 else 2.0
			if _gt - last > every:
				last = _gt
				await _shot("terug_%s" % _mode_name(mol), 0.0)
		await _shot("terug_in_hub", 1.5)
		_stand_at_terminal(p, ship)
		await _wait(0.5)
		game.company.choose(0 if game.company.contract != game.company.options[0] else 2)
		while not game.terrain.is_loaded:
			await get_tree().process_frame
		await _wait(0.5)
		await _drop_once(p, mol, ship, "drop2", false, false)
		await _shot("drop2_na_landing", 1.0)
	_write_files()
	print("[drop_sequence] klaar: %d beelden in %s, %d fouten in de log" % [_n, _dir, _log.count()])
	for m in _log.first(5):
		print("[drop_sequence] FOUT in de log: ", m)
	get_tree().quit(1 if CmdArgs.has("strict") and _log.count() > 0 else 0)


## Eén drop: in de Mol stappen, hendel, beelden om de --step seconden (speltijd) tot 5 s na de
## landing; rond de landing en de overdracht dichter. `skip`: overslaan zodra het buitenbeeld er
## is. `stay`: de speler stapt na de hendel uit en kijkt vanaf de kade in de hub naar de baai.
func _drop_once(p: Player, mol: Mol, ship: Ekster, tag: String, skip: bool, stay: bool) -> void:
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	p.rotation.y = mol.yaw
	p.head.rotation.x = 0.0
	await _wait(0.6)
	p.camera.make_current()
	await _shot("%s_in_mol" % tag)
	mol.press(Mol.Cmd.DEPART)
	if stay:
		await get_tree().physics_frame
		_stand_on_quay(p, ship)
	var step := float(CmdArgs.value("step", 0.5))
	var start := _gt
	var landed_at := -1.0
	var skip_tries := 0
	var outside_since := -1.0
	var next_crossing := 0
	_skip_seen_at = -1.0
	while _gt - start < 120.0:
		var mode := _mode_name(mol)
		await _shot("%s_%s" % [tag, mode], 0.0)
		if CmdArgs.has("kade") and mol.mode == Mol.Mode.DROP_COUNTDOWN:
			_kade_camera(ship)
			await _shot("%s_kade" % tag, 0.0)
			p.camera.make_current()
		# Overslaan: enkel in het buitenbeeld (een tijdje, buiten de hub), hoog genoeg; een paar keer
		# proberen tot de Mol springt.
		var outside := mol.mode == Mol.Mode.DROPPING and get_viewport().get_camera_3d() is DropCam and _height() < 1000.0
		if outside and outside_since < 0.0:
			outside_since = _gt
		if skip and _skip_seen_at < 0.0 and skip_tries < 6 and outside and _gt - outside_since > 0.3 and _height() > 200.0 \
				and mol.drop_variant == Mol.DropVariant.FULL:
			if InputMap.has_action("skip_cinematic"):
				skip_tries += 1
				_press_action("skip_cinematic")
				print("[drop_sequence] overslaan gevraagd op %.2f s (poging %d, %.0f m)" % [_gt, skip_tries, _height()])
			elif skip_tries == 0:
				skip_tries = 99
				print("[drop_sequence] NOG NIET BESCHIKBAAR: geen actie skip_cinematic")
		if mol.mode == Mol.Mode.PARKED and landed_at < 0.0:
			landed_at = _gt
		if landed_at >= 0.0 and _gt - landed_at > 5.0:
			break
		# Vaste hoogtes tijdens de val: een extra beeld als de Mol er voorbij gaat.
		var dt := step if landed_at < 0.0 or _gt - landed_at > 1.6 else minf(step, 0.3)
		var waited := 0.0
		while waited < dt:
			await get_tree().process_frame
			waited += get_process_delta_time()
			if mol.mode == Mol.Mode.DROPPING and next_crossing < CROSSINGS.size() and _height() < CROSSINGS[next_crossing]:
				while next_crossing < CROSSINGS.size() and _height() < CROSSINGS[next_crossing]:
					next_crossing += 1
				await _shot("%s_op_%03dm" % [tag, int(CROSSINGS[next_crossing - 1])], 0.0)
	if skip:
		print("[drop_sequence] overslaan: sprong van de Mol %s, drop werd %s" % [
			"gezien op %.2f s" % _skip_seen_at if _skip_seen_at >= 0.0 else "NIET gezien",
			Mol.DropVariant.keys()[mol.drop_variant]])


## De hub met open luiken (de Mol is op de planeet): door de baai naar beneden kijken, zoals wie
## achterbleef. Plekken t.o.v. de baai van de hub.
func _hub_views(ship: Ekster) -> void:
	if ship == null:
		return
	var dock := ship.dock_transform().origin
	var views := [
		["hub_baai_recht", dock + Vector3(0.5, 4.0, 0.5), dock + Vector3(0.0, -100.0, 0.1)],
		["hub_baai_rand", ship.global_transform * Vector3(2.0, 1.2, 5.0), ship.global_transform * Vector3(2.0, -60.0, -40.0)],
		["hub_baai_kade", ship.global_transform * Vector3(0.75, 1.2, 8.8), ship.global_transform * Vector3(0.75, -3.0, 0.0)],
	]
	for v: Array in views:
		_cam.global_position = v[1]
		_cam.look_at(v[2], Vector3.UP)
		_cam.make_current()
		await _shot(str(v[0]), 0.4)


## Grote reeks buitencamera's (--horizon): 7 hoogtes × 8 richtingen, licht naar beneden kijkend.
## Boven 900 m 300 m opzij (daar hangt de hub).
func _horizon_views(land: Vector3) -> void:
	for h in [1740.0, 1000.0, 600.0, 340.0, 120.0, 30.0, 4.0]:
		for i in 8:
			var yaw := i * 45.0
			var b := Basis(Vector3.UP, deg_to_rad(yaw))
			var off := 300.0 if h > 900.0 else 40.0
			var base := land + b * Vector3(0.0, 0.0, off)
			var t: TerrainAPI = main.game.terrain
			var ground := t.surface_height_at(base.x, base.z) if t else land.y
			_cam.global_position = Vector3(base.x, maxf(land.y, ground) + h, base.z)
			_cam.look_at(_cam.global_position + b * Vector3(0.0, -tan(deg_to_rad(12.0)), -1.0), Vector3.UP)
			_cam.make_current()
			await _shot("horizon_%04d_%03d" % [int(h), int(yaw)], 0.3)


## Achtergebleven: van de kade de open baai op, en vallen tot op de grond (eerste persoon).
func _jump_through_bay(p: Player, ship: Ekster, game: Game) -> void:
	p.camera.make_current()
	p.global_position = ship.global_transform * Vector3(2.0, 0.3, 5.0)
	p.velocity = Vector3.ZERO
	p.head.rotation.x = deg_to_rad(-35.0)
	var start := _gt
	var last := -10.0
	var left_hub := false
	while _gt - start < 60.0:
		await get_tree().process_frame
		left_hub = left_hub or not ship.contains(p.global_position)
		if _gt - last > 0.5:
			last = _gt
			await _shot("achter_val", 0.0)
		if left_hub and p.is_on_floor():
			break
	var t: TerrainAPI = game.terrain
	print("[drop_sequence] achtergebleven: na %.1f s op de grond (%.2f m boven het oppervlak)" % [
		_gt - start, p.global_position.y - t.surface_height_at(p.global_position.x, p.global_position.z)])
	p.head.rotation.x = 0.0
	await _shot("achter_geland", 0.5)


func _stand_at_terminal(p: Player, ship: Ekster) -> void:
	var use := ship.anchor_position("Terminal_Use")
	p.global_position = use + Vector3(0.0, 0.05, 0.0)
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(12.0)
	p.camera.make_current()


## Op de kade achter de Mol, kijkend naar de baai.
func _stand_on_quay(p: Player, ship: Ekster) -> void:
	p.global_position = ship.global_transform * Vector3(0.75, 0.05, 8.8)
	p.velocity = Vector3.ZERO
	var to := ship.dock_transform().origin - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = deg_to_rad(-15.0)
	p.camera.make_current()


func _kade_camera(ship: Ekster) -> void:
	_cam.global_position = ship.global_transform * Vector3(3.0, 1.6, 11.0)
	_cam.look_at(ship.dock_transform().origin + Vector3(0.0, -1.0, 0.0), Vector3.UP)
	_cam.make_current()


func _press_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


## Hoogte van de Mol (onderkant rupsen) boven het oppervlak onder hem.
func _height() -> float:
	var t: TerrainAPI = main.game.terrain
	var mp := _mol.body.global_position
	if t == null:
		return INF
	return mp.y - (t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM)


func _cam_kind() -> String:
	var c := get_viewport().get_camera_3d()
	if c == null:
		return "geen"
	if _p and c == _p.camera:
		return "speler"
	if c is DropCam:
		return "dropcam"
	if c is MolChaseCam:
		return "chase"
	if c == _cam:
		return "qa"
	return str(c.name)


func _mode_name(mol: Mol) -> String:
	return str(Mol.Mode.keys()[mol.mode]).to_lower()


func _shot(moment: String, settle := 0.4) -> void:
	if settle > 0.0:
		await _wait(settle)
	await RenderingServer.frame_post_draw
	_n += 1
	var path := _dir.path_join("%03d_%s_t%05.1f.png" % [_n, moment, _gt])
	get_viewport().get_texture().get_image().save_png(path)
	print("[drop_sequence] ", path)


## Tijdlijn en samenvatting (fases en camerawissels in speltijd, fouten).
func _write_files() -> void:
	if _dir == "":
		return
	var f := FileAccess.open(_dir.path_join("tijdlijn.csv"), FileAccess.WRITE)
	if f:
		f.store_line("speltijd,echte_tijd,mol,hoogte,vy,stuwkracht,camera,cinematic,muis,hud,vizier,banner,rapport,in_mol,in_hub,fps")
		for r in _rows:
			f.store_line(r)
		f.close()
	var lines: PackedStringArray = ["Samenvatting (speltijd in s)", ""]
	lines.append("Fases van de Mol:")
	var prev_mode := ""
	var prev_cam := ""
	var mode_start := 0.0
	var cam_start := 0.0
	var cams: PackedStringArray = []
	for r in _rows:
		var c := r.split(",")
		var t := float(c[0])
		if c[2] != prev_mode:
			if prev_mode != "":
				lines.append("  %8.2f  %-15s %6.2f s" % [mode_start, prev_mode, t - mode_start])
			prev_mode = c[2]
			mode_start = t
		if c[6] != prev_cam:
			if prev_cam != "":
				cams.append("  %8.2f  %-10s %6.2f s" % [cam_start, prev_cam, t - cam_start])
			prev_cam = c[6]
			cam_start = t
	if not _rows.is_empty():
		var t_end := float(_rows[_rows.size() - 1].split(",")[0])
		lines.append("  %8.2f  %-15s %6.2f s (tot het einde)" % [mode_start, prev_mode, t_end - mode_start])
		cams.append("  %8.2f  %-10s %6.2f s (tot het einde)" % [cam_start, prev_cam, t_end - cam_start])
	lines.append("")
	lines.append("Camera's (zonder de qa-buitencamera's is elke wissel een knip of overgang):")
	lines.append_array(cams)
	lines.append("")
	lines.append("Fouten in de log: %d" % _log.count())
	for m in _log.first(10):
		lines.append("  " + m)
	var s := FileAccess.open(_dir.path_join("samenvatting.txt"), FileAccess.WRITE)
	if s:
		s.store_string("\n".join(lines) + "\n")
		s.close()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
