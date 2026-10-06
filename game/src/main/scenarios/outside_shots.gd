extends Node
## Vaste beelden buiten, voor een voor/na-vergelijking van de grond, het middenplan, de landingsplek,
## de Mol, het schip, de reus en de eigen dingen per planeet (release-audit golf 3, pakket G4).
## De echte flow: in de hub een opdracht op de gekozen planeet kiezen, droppen (overslaan zodra het
## mag), landen; daarna camera's op vaste plekken t.o.v. de landingsplek (wereldrichtingen, geen
## willekeur), dus voor en na op dezelfde plek en hetzelfde moment.
##
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=outside_shots --no-steam --planet=roestbol --tag=voor
## Beelden: logs/outside/<tag>_<planeet>/NN_<naam>.png. --only=rond,voeten,mol,reus,schip,eigen,rand,plek
## (standaard alles). --fov=75 (beeldhoek van de grondcamera's).

var main: Node
var _cam: Camera3D
var _dir := ""
var _n := 0
var _only: PackedStringArray = []


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p), CONNECT_ONE_SHOT)
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		print("[outside_shots] GEFAALD: time-out")
		get_tree().quit(1))


func _want(part: String) -> bool:
	return _only.is_empty() or part in _only


func _run(p: Player) -> void:
	var game: Game = main.game
	var mol: Mol = game.mol
	var want := str(CmdArgs.value("planet", "roestbol")).to_lower()
	var only := str(CmdArgs.value("only", ""))
	if only != "":
		_only = only.split(",")
	_dir = PerfLog.log_dir().path_join("outside").path_join("%s_%s" % [str(CmdArgs.value("tag", "run")), want])
	DirAccess.make_dir_recursive_absolute(_dir)
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(f))
	_cam = Camera3D.new()
	_cam.name = "QaCam"
	_cam.fov = float(CmdArgs.value("fov", 75.0))
	_cam.near = 0.05
	_cam.far = 8000.0
	main.add_child(_cam)
	await _wait(1.0)
	# Vaste opdracht (de firma kiest bij elke start nieuwe): voor en na dezelfde wereld. --seed=N.
	var pid := maxi(0, PlanetType.Id.keys().find(want.to_upper()))
	var pick := 0
	game.company.options[pick]["planet"] = pid
	game.company.options[pick]["seed"] = int(CmdArgs.value("seed", 4242 + pid * 1000))
	game.company.options[pick]["modifiers"] = []
	game.company.choose(pick)
	while not game.world_ready():
		await get_tree().process_frame
	await _wait(0.5)
	# Droppen, overslaan zodra het mag.
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.6)
	mol.press(Mol.Cmd.DEPART)
	var film := CmdArgs.has("film")
	var t0 := Time.get_ticks_msec()
	while mol.mode != Mol.Mode.PARKED and Time.get_ticks_msec() - t0 < 120000:
		if not film and mol.drop_skippable() and mol.skip_votes == 0:
			mol.vote_skip()
		await get_tree().process_frame
	if film:
		# --film (met Movie Maker): de hele drop zonder overslaan, de landing, en meteen weer naar
		# het schip (het ophalen met het kraanshot), tot de Mol in de hub staat.
		await _wait(4.0)
		p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
		await _wait(0.5)
		mol.press(Mol.Cmd.DEPART)
		while mol.mode != Mol.Mode.DOCKED and Time.get_ticks_msec() - t0 < 400000:
			await get_tree().process_frame
		await _wait(1.5)
		print("[outside_shots] film klaar")
		get_tree().quit(0)
		return
	await _wait(7.0) # het stof van de landing gaat liggen, de titelkaart is weg
	main.hud.visible = false
	var land := mol.body.global_position
	var t: TerrainAPI = game.terrain
	land.y = t.surface_height_at(land.x, land.z)
	print("[outside_shots] %s: geland op %s, speelgebied %s" % [want, land, t.world_size()])

	if _want("rond"):
		# Ooghoogte, 9 m van de landingsplek, naar buiten (8 richtingen; 0 = −z).
		for i in 8:
			var d := _dir_of(i * 45.0)
			await _ground_shot("rond_%03d" % (i * 45), land + d * 9.0, d, -5.0)
	if _want("voeten"):
		# De grond binnen 20 m: schuin naar beneden.
		for yaw in [30.0, 150.0, 270.0]:
			var d := _dir_of(yaw)
			await _ground_shot("voeten_%03d" % int(yaw), land + d * 7.0, d, -32.0)
	if _want("plek"):
		var site := get_tree().current_scene.find_child("LandingSite", true, false) as Node3D
		if site:
			var focus: Vector3 = site.get_meta("focus", site.global_position)
			var from := land + (focus - land).normalized() * 5.5
			var d := focus - from
			d.y = 0.0
			await _ground_shot("plek_vanaf_mol", from, d.normalized(), -4.0)
			var side := d.normalized().rotated(Vector3.UP, 0.6)
			await _ground_shot("plek_dicht", focus - side * 9.0, side, -12.0)
		else:
			print("[outside_shots] geen LandingSite")
	if _want("mol"):
		var side := mol.placed.basis.x
		side.y = 0.0
		side = side.normalized()
		var fwd := -mol.placed.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		await _look_shot("mol_held", land + side * 11.0 - fwd * 5.0 + Vector3.UP * 1.7, land + Vector3.UP * 2.0)
		await _look_shot("mol_dicht", land + side * 4.6 + fwd * 1.0 + Vector3.UP * 1.3, land + Vector3.UP * 1.2 + fwd * 0.5)
		await _look_shot("mol_achter", land - fwd * 6.5 + side * 2.0 + Vector3.UP * 1.0, land + Vector3.UP * 1.5)
	if _want("reus"):
		var sky: Dictionary = PlanetType.params(game.planet_type).get("sky", {})
		var g: Vector3 = sky.get("giant_dir", Vector3(0, 0.4, -1))
		_cam.fov = 26.0
		var from := land + Vector3(g.z, 0.0, -g.x).normalized() * 14.0
		from.y = _ground(from) + 1.7
		await _look_shot("reus_zoom", from, from + g * 100.0)
		_cam.fov = float(CmdArgs.value("fov", 75.0))
	if _want("schip"):
		var ex: EksterExterior = game.exterior
		if ex:
			_cam.fov = 38.0
			await _look_shot("schip_vanaf_grond", land + Vector3(14.0, 1.7, 22.0), ex.global_position)
			_cam.fov = float(CmdArgs.value("fov", 75.0))
			# De motoren van dichtbij (in de ruimte van het schip: de straalpijpen eindigen op z 85,4).
			await _look_shot("schip_motor", ex.to_global(Vector3(30.0, 14.0, 128.0)), ex.to_global(Vector3(0.0, 3.0, 92.0)))
			await _look_shot("schip_romp", ex.to_global(Vector3(-42.0, -6.0, -20.0)), ex.to_global(Vector3(0.0, 0.0, 0.0)))
	if _want("eigen"):
		await _planet_shots(game, land)
	if _want("rand"):
		# Vlak buiten de rand, laag, langs de rand kijkend (buiten2-9), en van binnen naar de rand.
		var size := t.world_size()
		var spots := [[Vector3(size.x + 2.5, 0.0, size.z * 0.4), Vector3(0, 0, 1)], [Vector3(size.x * 0.6, 0.0, -2.5), Vector3(1, 0, 0)]]
		for i in spots.size():
			var at: Vector3 = spots[i][0]
			at.y = game.surface.far_height(at.x, at.z) + 1.6
			var to: Vector3 = spots[i][1]
			await _look_shot("rand_buiten_%d" % i, at, at + to * 20.0 + Vector3.DOWN * 4.0)
	print("[outside_shots] klaar: %d beelden in %s" % [_n, _dir])
	get_tree().quit(0)


## Eigen dingen per planeet: de buttes en de mist (Fossielwereld), de kristallen (Kristalmaan), de
## kraterwand en de rotsen (Roestbol).
func _planet_shots(game: Game, land: Vector3) -> void:
	var lf := game.surface.landform
	if lf is LandformFossiel:
		var f := lf as LandformFossiel
		var best := Vector4.ZERO
		var bd := INF
		for b in f.buttes:
			var d := Vector2(b.x, b.y).distance_to(Vector2(land.x, land.z))
			if d < bd:
				bd = d
				best = b
		if bd < INF:
			var c := Vector3(best.x, 0.0, best.y)
			c.y = game.surface.far_height(c.x, c.z)
			var away := Vector3(land.x - c.x, 0.0, land.z - c.z).normalized()
			var at := c + away * (best.z + 70.0)
			at.y = game.surface.far_height(at.x, at.z) + 1.7
			await _look_shot("butte_dicht", at, c + Vector3.UP * best.w * 0.45)
			at = c + away.rotated(Vector3.UP, 0.9) * (best.z + 30.0)
			at.y = game.surface.far_height(at.x, at.z) + 1.7
			await _look_shot("butte_voet", at, c + Vector3.UP * best.w * 0.3)
		# De klif met de geulen (en de mist erin) van hoog, zoals in de drop op ±119 m.
		var to_cliff := Vector3(f.cliff_c.x - land.x, 0.0, f.cliff_c.y - land.z).normalized()
		await _look_shot("klif_119m", land + Vector3.UP * 125.0 - to_cliff * 17.0, land + to_cliff * 380.0 + Vector3.UP * 30.0)
		var g0 := land + Vector3(to_cliff.z, 0.0, -to_cliff.x) * 14.0
		g0.y = _ground(g0) + 1.7
		await _look_shot("klif_grond", g0, g0 + to_cliff * 300.0 + Vector3.UP * 40.0)
	elif lf is LandformKristal:
		# Het dichtste kristal van de ader: zoek de meshes van de kristallen.
		var best := Vector3.ZERO
		var bd := INF
		for mi: MeshInstance3D in get_tree().current_scene.find_children("Crystals*", "MeshInstance3D", true, false):
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for k in range(0, verts.size(), 7):
				var c := mi.global_transform * verts[k]
				var d := Vector2(c.x, c.z).distance_to(Vector2(land.x, land.z))
				if d < bd:
					bd = d
					best = c
		if bd < INF:
			var away := Vector3(land.x - best.x, 0.0, land.z - best.z).normalized()
			var at := best + away * 14.0
			at.y = game.surface.far_height(at.x, at.z) + 1.7
			await _look_shot("kristal_dicht", at, Vector3(best.x, game.surface.far_height(best.x, best.z) + 2.0, best.z))
			at = best + away.rotated(Vector3.UP, -0.7) * 30.0
			at.y = game.surface.far_height(at.x, at.z) + 1.7
			await _look_shot("kristal_middel", at, Vector3(best.x, game.surface.far_height(best.x, best.z) + 2.5, best.z))
	else:
		var r := lf as LandformRoestbol
		for yaw in [0.0, 120.0, 240.0]:
			var d := _dir_of(yaw)
			await _look_shot("wand_%03d" % int(yaw), land + Vector3.UP * 1.7 + d * 20.0, land + d * 400.0 + Vector3.UP * 60.0)
		if r:
			pass


func _dir_of(yaw_deg: float) -> Vector3:
	var a := deg_to_rad(yaw_deg)
	return Vector3(sin(a), 0.0, -cos(a))


## Op ooghoogte (1,7 m boven de grond op `at`) in richting `d`, `pitch_deg` omhoog (negatief = omlaag).
func _ground_shot(name: String, at: Vector3, d: Vector3, pitch_deg: float) -> void:
	var t: TerrainAPI = main.game.terrain
	var pos := at
	pos.y = _ground(at) + 1.7
	var look := d * cos(deg_to_rad(pitch_deg)) + Vector3.UP * sin(deg_to_rad(pitch_deg))
	await _look_shot(name, pos, pos + look * 10.0)
	if t == null:
		return


func _ground(at: Vector3) -> float:
	var game: Game = main.game
	if game.surface and game.surface.outside(at.x, at.z) > 0.0:
		return game.surface.far_height(at.x, at.z)
	return game.terrain.surface_height_at(at.x, at.z)


func _look_shot(name: String, from: Vector3, at: Vector3) -> void:
	_cam.global_position = from
	var up := Vector3.UP if absf((at - from).normalized().y) < 0.98 else Vector3.FORWARD
	_cam.look_at(at, up)
	_cam.make_current()
	# Wachten tot het terrein rond het doel geladen is (enkel in het speelgebied).
	var t: TerrainAPI = main.game.terrain
	var w := 0
	while w < 300 and main.game.surface.outside(from.x, from.z) <= 0.0 and not t.is_area_ready(from, 30.0):
		await get_tree().process_frame
		w += 1
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	_n += 1
	var path := _dir.path_join("%02d_%s.png" % [_n, name])
	get_viewport().get_texture().get_image().save_png(path)
	print("[outside_shots] ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
