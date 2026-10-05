extends Node
## Metingen en filmpjes van hoe de speler aanvoelt (release-audit pakket B: lopen, gereedschap,
## dragen, vondsten). Elke deel meet of filmt één handeling op een vaste plek, zodat voor en na
## vergelijkbaar zijn. Tijden in speltijd (ook juist bij Movie Maker met --fixed-fps).
##
##   Metingen (CSV + logregels, `--out=map`, standaard logs/feel_bench):
##     --part=judder        camerastappen per beeld tijdens zijwaarts lopen (venster, onbeperkte fps)
##     --part=judder_mol    idem, als piloot in een rijdende Mol
##     --part=move          optrekken, remmen, sprinten, hurken, springen, een val van 6 m
##     --part=dig           houweel en boor in klei, boor in zandsteen, oververhitten (headless)
##     --part=crust         een korst uitbikken: houweel, boor vasthouden, boor met tikjes (headless)
##   Filmpjes (Movie Maker, `--write-movie x.avi --fixed-fps 30`):
##     --part=film_swing    houweel tegen een kleiwand, wisselen naar de boor en terug
##     --part=film_crust    een korst uitbikken tot de vondst vrijkomt (de beloning)
##     --part=film_carry    oppakken, rondkijken, lopen, tegen de wand gooien
##     --part=film_hard     houweel en boor op zandsteen, boor op graniet (vonken)
##     --part=film_drill    boren in klei tot hij oververhit
##     --part=film_ore      erts delven en storten in de trechter
##     --part=film_move     lopen, sprinten, hurken, springen en landen
## tools\godot.cmd --headless --path game -- --scenario=feel_bench --part=dig --no-steam

var main: Node
var part := ""
var out_dir := ""
var _csv: Array[String] = []
var _t0 := 0.0
var _game_t := 0.0


func _ready() -> void:
	part = str(CmdArgs.value("part", "dig"))
	out_dir = str(CmdArgs.value("out", PerfLog.log_dir().path_join("feel_bench")))
	DirAccess.make_dir_recursive_absolute(out_dir)
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("[feel_bench] GEFAALD: time-out")
		get_tree().quit(1))


func _physics_process(delta: float) -> void:
	_game_t += delta


func _now() -> float:
	return _game_t - _t0


func _log(s: String) -> void:
	print("[feel_bench] t=%.2f %s" % [_now(), s])
	_csv.append("%.3f;# %s" % [_now(), s])


func _run(p: Player) -> void:
	await _wait(1.0)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_t0 = _game_t
	match part:
		"judder": await _judder(p)
		"judder_mol": await _judder_mol(p)
		"move": await _move(p, false)
		"dig": await _dig(p)
		"crust": await _crust(p)
		"film_swing": await _film_swing(p)
		"film_crust": await _film_crust(p)
		"film_carry": await _film_carry(p)
		"film_hard": await _film_hard(p)
		"film_drill": await _film_drill(p)
		"film_ore": await _film_ore(p)
		"film_move": await _move(p, true)
		_:
			print("[feel_bench] onbekend deel: ", part)
	var f := FileAccess.open(out_dir.path_join("%s.csv" % part), FileAccess.WRITE)
	if f:
		for l in _csv:
			f.store_line(l)
		f.close()
	print("[feel_bench] klaar: ", part)
	get_tree().quit(0)


# --- Hulp -------------------------------------------------------------------------------------

func _wait(s: float) -> void:
	var end := _game_t + s
	while _game_t < end:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Afstand langs de kijkrichting tot de rots, uit de terreindata.
func _wall_dist(p: Player, max_d := 4.0) -> float:
	var t: TerrainAPI = main.terrain
	var from := p.head.global_position
	var dir := -p.head.global_basis.z
	var d := 0.0
	while d < max_d:
		if t.sdf_at(from + dir * d) < 0.0:
			return d
		d += 0.02
	return INF


## Kamer (tunnel langs -X) met het midden op c; de wand aan de +X-kant.
func _room(c: Vector3, r := 2.4) -> void:
	for dx in [0.0, -2.0, -4.0, -6.0]:
		main.terrain.debug_dig(c + Vector3(dx, 0, 0), r)


## Speler in de kamer, kijkend naar +X (de wand), voeten op de vloer.
func _place(p: Player, at: Vector3, pitch_deg := 0.0, yaw_deg := -90.0) -> void:
	p.velocity = Vector3.ZERO
	p.global_position = at
	p.rotation = Vector3(0, deg_to_rad(yaw_deg), 0)
	p.head.rotation.x = deg_to_rad(pitch_deg)
	p.reset_physics_interpolation()


func _ready_area(p: Player, c: Vector3) -> void:
	var t: TerrainAPI = main.terrain
	t.add_viewer(p, 40.0, 20.0)
	var n := 0
	while not t.is_area_ready(c, 12.0) and n < 300:
		await _wait(0.1)
		n += 1


## Plek in de klei naast de landingsplek, met een kamer, en de speler erin.
func _clay_room(p: Player, dz := 18.0) -> Vector3:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x + 24.0, sc.z + dz)
	var c := Vector3(sc.x + 24.0, top - 7.0, sc.z + dz)
	p.set_physics_process(false)
	p.global_position = c
	await _ready_area(p, c)
	_room(c)
	await _wait(0.6)
	_place(p, c + Vector3(1.0, -1.7, 0))
	p.set_physics_process(true)
	await _wait(0.8)
	return c


func _layer_room(p: Player, height: float) -> Vector3:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var c := Vector3(sc.x + 30.0, height, sc.z + 30.0)
	p.set_physics_process(false)
	p.global_position = c
	await _ready_area(p, c)
	_room(c)
	await _wait(0.6)
	_place(p, c + Vector3(1.0, -1.7, 0))
	p.set_physics_process(true)
	await _wait(0.8)
	return c


## Dichtstbijzijnde vondst bij de speler, vrijgemaakt in een kuil, of nog in zijn korst.
func _nearest_find(p: Player) -> FindItem:
	var best: FindItem = null
	for cand: FindItem in main.game.finds.items:
		if best == null or cand.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = cand
	return best


## Kuil voor een vondst; de speler op 2 m, kijkend naar de vondst.
func _face_find(p: Player, it: FindItem, dist := 2.2, drop := 0.4) -> void:
	var here := it.global_position
	await _ready_area(p, here)
	for dx in [-2.0, 0.0, 2.0]:
		main.terrain.debug_dig(here + Vector3(dx, 0.9, dist - 0.3), 2.0)
	await _wait(1.0)
	p.global_position = here + Vector3(0, -drop, dist)
	p.rotation = Vector3.ZERO
	p.reset_physics_interpolation()
	await _wait(0.6)
	_aim_at(p, here)


func _aim_at(p: Player, target: Vector3) -> void:
	var dir := target - p.head.global_position
	p.rotation.y = atan2(-dir.x, -dir.z)
	p.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


# --- Haperen bij een hoge beeldfrequentie -----------------------------------------------------

func _uncap() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


## Gelijkmatigheid: per beeld de camerastap gedeeld door de beeldtijd (snelheid). Bij 60 Hz-stappen
## zonder interpolatie zijn veel beelden 0 en andere dubbel; met interpolatie is elke stap gelijk.
func _measure_steps(p: Player, frames: int, tag: String) -> void:
	var cam := p.camera
	var last := cam.global_position
	var last_t := Time.get_ticks_usec()
	var zero := 0
	var speeds: Array[float] = []
	for i in frames:
		await get_tree().process_frame
		var now_pos := cam.global_position
		var now_t := Time.get_ticks_usec()
		var step := now_pos.distance_to(last)
		var dt := (now_t - last_t) / 1000000.0
		if step < 0.0005:
			zero += 1
		if dt > 0.0:
			speeds.append(step / dt)
		_csv.append("%d;%d;%.5f;%.3f" % [Engine.get_frames_drawn(), Engine.get_physics_frames(), step, dt * 1000.0])
		last = now_pos
		last_t = now_t
	var mean := 0.0
	for s in speeds:
		mean += s
	mean /= maxf(1.0, speeds.size())
	var var_sum := 0.0
	for s in speeds:
		var_sum += (s - mean) * (s - mean)
	var cv := sqrt(var_sum / maxf(1.0, speeds.size())) / maxf(mean, 0.0001)
	_log("%s: %d van %d beelden zonder camerabeweging, spreiding snelheid per beeld %.0f%%, fps=%d" % [
			tag, zero, frames, cv * 100.0, Engine.get_frames_per_second()])


func _judder(p: Player) -> void:
	_uncap()
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var at := Vector3(sc.x - 30.0, 0, sc.z + 25.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.3
	_place(p, at, -5.0, 0.0)
	await _ready_area(p, at)
	await _wait(1.0)
	Input.action_press("move_right")
	await _wait(0.6)
	await _measure_steps(p, 300, "zijwaarts lopen")
	Input.action_release("move_right")


func _judder_mol(p: Player) -> void:
	_uncap()
	var mol: Mol = main.game.mol
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
	p.reset_physics_interpolation()
	await _wait(0.3)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.6)
	Input.action_press("move_forward")
	await _wait(2.0)
	await _measure_steps(p, 300, "als piloot in de rijdende Mol")
	Input.action_release("move_forward")


# --- Bewegen --------------------------------------------------------------------------------------

func _move(p: Player, film: bool) -> void:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var at := Vector3(sc.x - 30.0, 0, sc.z + 25.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.3
	_place(p, at, -6.0, 180.0)
	await _ready_area(p, at)
	await _wait(1.0)
	var phases := [["walk", "move_forward", 1.4], ["stop", "", 0.8], ["sprint", "move_forward+sprint", 1.6], ["stop", "", 1.0],
			["crouch", "move_forward+crouch", 1.2], ["stop", "", 0.8], ["strafe", "move_left", 1.0], ["stop", "", 0.6]]
	for ph: Array in phases:
		var acts: PackedStringArray = (ph[1] as String).split("+", false)
		for a in acts:
			if InputMap.has_action(a):
				Input.action_press(a)
		var ts := _now()
		var reached := -1.0
		var top := 0.0
		while _now() - ts < float(ph[2]):
			await get_tree().physics_frame
			var v := Vector2(p.velocity.x, p.velocity.z).length()
			top = maxf(top, v)
			_csv.append("%.3f;%s;%.3f;%.3f;%.3f;eye=%.3f" % [_now(), ph[0], v, p.velocity.y, p.global_position.y, p.camera.global_position.y - p.global_position.y])
		for a in acts:
			if InputMap.has_action(a):
				Input.action_release(a)
		_log("%s: topsnelheid %.2f m/s" % [ph[0], top])
	# Optrekken en remmen: tijd tot 90 % en tot stilstand.
	Input.action_press("move_forward")
	var ts2 := _now()
	var t90 := -1.0
	while _now() - ts2 < 1.0:
		await get_tree().physics_frame
		if t90 < 0.0 and Vector2(p.velocity.x, p.velocity.z).length() > 0.9 * 4.5 * 0.999:
			t90 = _now() - ts2
	Input.action_release("move_forward")
	var ts3 := _now()
	var tstop := -1.0
	while _now() - ts3 < 1.0:
		await get_tree().physics_frame
		if tstop < 0.0 and Vector2(p.velocity.x, p.velocity.z).length() < 0.05:
			tstop = _now() - ts3
	_log("optrekken tot 90%%: %.3f s, remmen tot stilstand: %.3f s" % [t90, tstop])
	# Sprong ter plaatse.
	await _wait(0.4)
	var y0 := p.global_position.y
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var apex := y0
	var ts4 := _now()
	var landed := -1.0
	while _now() - ts4 < 1.6:
		await get_tree().physics_frame
		apex = maxf(apex, p.global_position.y)
		if landed < 0.0 and _now() - ts4 > 0.1 and p.is_on_floor():
			landed = _now() - ts4
	_log("sprong: %.2f m hoog, %.2f s in de lucht" % [apex - y0, landed])
	# Val van 6 m: landen (camera-dip in de oogpositie t.o.v. de voeten).
	await _wait(0.5)
	var rest_eye := p.camera.global_position.y - p.global_position.y
	p.global_position += Vector3(0, 6.0, 0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var ts5 := _now()
	var was_floor := false
	var dip := 0.0
	var land_t := -1.0
	while _now() - ts5 < 2.2:
		await get_tree().process_frame
		var eye := p.camera.global_position.y - p.global_position.y
		if land_t >= 0.0:
			dip = maxf(dip, rest_eye - eye)
		if p.is_on_floor() and not was_floor and _now() - ts5 > 0.2:
			land_t = _now()
			_log("geland na 6 m")
		was_floor = p.is_on_floor()
		_csv.append("%.3f;fall;%.3f;%.3f;eye=%.3f;rot_x=%.4f" % [_now(), p.global_position.y, p.velocity.y, eye, p.camera.rotation.x])
	_log("landing: oog zakt %.3f m (rust %.2f m)" % [dip, rest_eye])
	if film:
		# Rondkijken: een snelle draai, dan lopen naar de camera toe.
		for i in 10:
			p.rotate_y(deg_to_rad(-9.0))
			await get_tree().process_frame
		await _wait(0.8)


# --- Graven -----------------------------------------------------------------------------------

func _dig(p: Player) -> void:
	var c := await _clay_room(p)
	_log("laag=%s" % Strata.NAMES[main.terrain.layer_at(c + Vector3(3, 0, 0))])
	# Houweel tegen de wand.
	var d0 := _wall_dist(p)
	p.pickaxe.auto_swing = true
	var sw := [0]
	p.pickaxe.swung.connect(func() -> void: sw[0] += 1)
	var ts := _now()
	var got := -1.0
	while _now() - ts < 6.0:
		await _frames(3)
		var d := _wall_dist(p)
		_csv.append("%.3f;pick_wall;%d;%.3f" % [_now(), sw[0], d - d0])
		if got < 0.0 and d - d0 >= 1.0:
			got = _now() - ts
			_log("houweel klei: 1 m in de wand na %.2f s (%d slagen)" % [got, sw[0]])
	p.pickaxe.auto_swing = false
	_log("houweel klei: %.2f m in 6 s (%d slagen)" % [_wall_dist(p, 6.0) - d0, sw[0]])
	await _wait(0.8)
	# Boor in een verse wand.
	await _drill_run(p, c + Vector3(0, 0, -5.0), "klei", 11.0)
	# Zandsteen.
	var cs := await _layer_room(p, Strata.TOPS_M[2] - 12.0)
	_log("laag=%s" % Strata.NAMES[main.terrain.layer_at(cs + Vector3(3, 0, 0))])
	p.select_tool(0)
	await _wait(0.4)
	var d1 := _wall_dist(p)
	p.pickaxe.auto_swing = true
	await _wait(2.2)
	p.pickaxe.auto_swing = false
	_log("houweel zandsteen: %.2f m in 2,2 s" % (_wall_dist(p, 6.0) - d1))
	await _drill_run(p, cs + Vector3(0, 0, -5.0), "zandsteen", 9.0, false)


func _drill_run(p: Player, c: Vector3, tag: String, secs: float, new_room := true) -> void:
	if new_room:
		_room(c)
		await _wait(0.6)
		_place(p, c + Vector3(1.0, -1.7, 0))
		await _wait(0.8)
	p.select_tool(1)
	await _wait(0.4)
	p.drill.heat = 0.0
	var d0 := _wall_dist(p)
	var wx0 := p.head.global_position.x + d0
	p.drill.auto_use = true
	var ts := _now()
	var got := -1.0
	var oh := false
	var at3 := -1.0
	while _now() - ts < secs:
		await _frames(3)
		var d := _wall_dist(p, 6.0)
		var wx := p.head.global_position.x + d
		_csv.append("%.3f;drill_%s;%.2f;%.3f;%s" % [_now(), tag, p.drill.heat, wx - wx0, p.drill.overheated])
		if got < 0.0 and wx - wx0 >= 1.0:
			got = _now() - ts
			_log("boor %s: 1 m na %.2f s (met aanloop)" % [tag, got])
		if at3 < 0.0 and _now() - ts >= 3.0:
			at3 = wx - wx0
			_log("boor %s: %.2f m in 3 s" % [tag, at3])
		if p.drill.overheated and not oh:
			oh = true
			_log("boor %s: oververhit na %.2f s, %.2f m" % [tag, _now() - ts, wx - wx0])
		# Bijlopen zoals een speler.
		if d < 6.0 and d > 1.4:
			p.global_position.x += d - 1.1
	p.drill.auto_use = false
	_log("boor %s: %.2f m in %.0f s" % [tag, p.head.global_position.x + _wall_dist(p, 6.0) - wx0, secs])
	await _wait(0.6)


# --- Korst ------------------------------------------------------------------------------------

func _crust(p: Player) -> void:
	var finds: FindField = main.game.finds
	p.set_physics_process(false)
	var used := {}
	for mode in ["houweel", "boor", "boor_tik"]:
		var it: FindItem = null
		for cand: FindItem in finds.items:
			if cand.freed or used.has(cand.find_id) or cand.global_position.y < Strata.TOPS_M[2]:
				continue
			if it == null or cand.global_position.distance_to(p.global_position) < it.global_position.distance_to(p.global_position):
				it = cand
		used[it.find_id] = true
		await _face_find(p, it)
		var crust: Crust = finds.crusts[it.find_id]
		var max_hp := crust.max_hp
		var ts := _now()
		var hits := [0]
		if mode == "houweel":
			p.select_tool(0)
			p.pickaxe.auto_swing = true
			var cb := func() -> void: hits[0] += 1
			p.pickaxe.swung.connect(cb)
			while not it.freed and _now() - ts < 14.0:
				await get_tree().physics_frame
			p.pickaxe.auto_swing = false
			p.pickaxe.swung.disconnect(cb)
		else:
			p.select_tool(1)
			p.drill.heat = 0.0
			await _wait(0.3)
			ts = _now()
			while not it.freed and _now() - ts < 14.0:
				p.drill.auto_use = true
				if mode == "boor_tik":
					await _wait(0.45)
					p.drill.auto_use = false
					await _wait(0.35)
				else:
					await get_tree().physics_frame
			p.drill.auto_use = false
			p.select_tool(0)
		_log("korst %s: %s (€%d, levens %.0f) vrij=%s na %.2f s%s, gaafheid %d%%" % [mode, it.display_name(), it.base_value, max_hp,
				it.freed, _now() - ts, (" (%d slagen)" % hits[0]) if mode == "houweel" else "", int(round(it.condition * 100))])
		await _wait(1.0)


# --- Filmpjes ---------------------------------------------------------------------------------

func _film_swing(p: Player) -> void:
	await _clay_room(p)
	p.head.rotation.x = deg_to_rad(-8.0)
	await _wait(0.6)
	p.pickaxe.auto_swing = true
	await _wait(3.4)
	p.pickaxe.auto_swing = false
	await _wait(0.8)
	p.select_tool(1)
	await _wait(1.0)
	p.select_tool(0)
	await _wait(1.2)
	# Naar beneden hakken.
	p.head.rotation.x = deg_to_rad(-60.0)
	p.pickaxe.auto_swing = true
	await _wait(2.4)
	p.pickaxe.auto_swing = false
	await _wait(1.0)


func _film_crust(p: Player) -> void:
	var it := _nearest_find(p)
	await _face_find(p, it)
	_log("korst: %s (€%d)" % [it.display_name(), it.base_value])
	p.pickaxe.auto_swing = true
	var ts := _now()
	while not it.freed and _now() - ts < 14.0:
		await get_tree().physics_frame
	p.pickaxe.auto_swing = false
	_log("vrij na %.2f s" % (_now() - ts))
	await _wait(3.5)


func _film_carry(p: Player) -> void:
	var finds: FindField = main.game.finds
	var it := _nearest_find(p)
	var here := it.global_position
	await _ready_area(p, here)
	for dx in [-2.0, 0.0, 2.0, 4.0]:
		main.terrain.debug_dig(here + Vector3(dx, 0.9, 1.6), 2.3)
	await _wait(0.5)
	finds._free(it.find_id)
	await _wait(2.5)
	p.global_position = it.global_position + Vector3(0, -0.2, 1.8)
	p.rotation = Vector3.ZERO
	p.reset_physics_interpolation()
	await _wait(0.3)
	_aim_at(p, it.global_position)
	await _wait(0.6)
	finds.request_grab(it.find_id)
	await _wait(1.0)
	# Muisflits: 90° in 0,2 s, dan terug.
	for i in 6:
		p.rotate_y(deg_to_rad(15.0))
		await get_tree().process_frame
	await _wait(1.0)
	for i in 6:
		p.rotate_y(deg_to_rad(-15.0))
		await get_tree().process_frame
	await _wait(0.6)
	p.head.rotation.x = deg_to_rad(-5.0)
	Input.action_press("move_right")
	await _wait(1.2)
	Input.action_release("move_right")
	await _wait(0.6)
	# Gooien tegen de wand.
	p.rotation.y = deg_to_rad(-90.0)
	p.head.rotation.x = deg_to_rad(5.0)
	await _wait(0.5)
	var c0 := it.condition
	p.carry.drop(true)
	await _wait(2.5)
	_log("gegooid: gaafheid %.2f -> %.2f" % [c0, it.condition])


func _film_hard(p: Player) -> void:
	await _layer_room(p, Strata.TOPS_M[2] - 12.0)
	p.head.rotation.x = deg_to_rad(-6.0)
	p.select_tool(0)
	await _wait(0.4)
	p.pickaxe.auto_swing = true
	await _wait(2.4)
	p.pickaxe.auto_swing = false
	await _wait(0.6)
	p.select_tool(1)
	await _wait(0.4)
	p.drill.auto_use = true
	await _wait(3.0)
	p.drill.auto_use = false
	await _wait(0.6)
	await _layer_room(p, Strata.TOPS_M[1] - 15.0)
	p.head.rotation.x = deg_to_rad(-6.0)
	p.select_tool(1)
	await _wait(0.4)
	p.drill.auto_use = true
	await _wait(2.5)
	p.drill.auto_use = false
	await _wait(0.6)


func _film_drill(p: Player) -> void:
	await _clay_room(p)
	p.head.rotation.x = deg_to_rad(-6.0)
	p.select_tool(1)
	await _wait(0.6)
	p.drill.auto_use = true
	var ts := _now()
	while _now() - ts < 9.0:
		await _frames(3)
		var d := _wall_dist(p, 6.0)
		if d < 6.0 and d > 1.4:
			p.global_position.x += minf(d - 1.1, 0.05)
		if p.drill.overheated and _now() - ts > 2.0:
			break
	await _wait(2.5)
	p.drill.auto_use = false
	await _wait(2.0)


func _film_ore(p: Player) -> void:
	var ores: OreField = main.game.ores
	var best: OreCluster = null
	for c in ores.clusters:
		if best == null or c.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position):
			best = c
	var here := best.global_position + best.global_basis.y * 0.2
	await _ready_area(p, here)
	var out := best.global_basis.y
	out.y = 0.0
	out = out.normalized() if out.length() > 0.1 else Vector3.BACK
	for k in [1.2, 2.6, 4.0]:
		main.terrain.debug_dig(here + out * k + Vector3(0, 0.6, 0), 1.6)
	await _wait(1.0)
	p.global_position = here + out * 1.9 + Vector3(0, -0.9, 0)
	p.rotation = Vector3.ZERO
	p.reset_physics_interpolation()
	await _wait(0.5)
	_aim_at(p, here)
	await _wait(0.3)
	p.select_tool(0)
	p.pickaxe.auto_swing = true
	await _wait(2.8)
	p.pickaxe.auto_swing = false
	_log("erts in de zak: %d" % OreField.units(ores.bag_of(p.peer_id)))
	await _wait(0.8)
	# Storten in de trechter van de Mol.
	var mol: Mol = main.game.mol
	var chute := mol.chute_position()
	p.global_position = chute + (mol.body.global_basis.z * 1.6) + Vector3(0, -0.6, 0)
	p.reset_physics_interpolation()
	await _wait(0.3)
	_aim_at(p, chute)
	await _wait(0.6)
	ores.deposit()
	await _wait(0.5)
	_log("gestort: %d erts in de Mol (€%d)" % [OreField.units(ores.hold), OreField.value(ores.hold)])
	await _wait(2.0)
