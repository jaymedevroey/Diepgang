extends Node
## Hemel en horizon controleren.
## Standaard: de zes controlebeelden van de hemel (docs/research/hemel.md §6), voor één kleurrichting:
##   1 grond, naar de zon   2 grond, van de zon weg   3 grond, naar de reus
##   4 150 m, schuin omlaag  5 340 m, 40° omlaag       6 340 m, naar de horizon
##   tools\godot.cmd --path game --resolution 1280x720 -- --scenario=sky_preview --no-steam --sky=a
##   Beelden: logs/sky/<richting>_<n>.png
## --horizon: automatische controle "nergens hemel onder de horizon" in de hele camera-omhullende
##   van de drop (0-345 m boven de landingsplek, 20 m van de Mol, 8 richtingen, kantelen -55°..+10°,
##   FOV 84°): per beeld een tweede render met een magenta hemel zonder mist; elke magenta pixel
##   onder de echte horizon (kimdaling √(2h/R), marge 0,1°) is een fout. Drukt PASS of FAIL af,
##   bewaart foute beelden (en een masker) in logs/horizon_check/. --far=4000 (camera), --margin=0.1.
##   tools\godot.cmd --path game --resolution 1600x900 -- --scenario=sky_preview --no-steam --horizon
## --views: vaste beelden voor een voor/na-vergelijking in logs/horizon_views/ (hoogtes 340/160/60 m in
##   4 richtingen zoals drop_sequence, de dropcamera, de ophaalcamera op de grond, de grond in
##   4 richtingen, de rand van het speelgebied te voet, en 1740 m hoog). --tint: verre landschap
##   magenta, raster cyaan (welke mesh zie je waar).
## --hub: bouwt De Ekster 1,4 km boven het buitenschip, opent de luiken en kijkt door de baai naar
##   beneden (en door het raam): logs/horizon_views/hub_*.png.

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	if CmdArgs.has("horizon"):
		await _horizon_check()
	elif CmdArgs.has("bench"):
		await _bench()
	elif CmdArgs.has("views"):
		await _views()
	elif CmdArgs.has("hub"):
		await _hub()
	else:
		await _control_shots()
	get_tree().quit(0)


func _control_shots() -> void:
	var game: Game = main.game
	var style := str(CmdArgs.value("sky", "a")).to_lower()
	var out := PerfLog.log_dir().path_join("sky")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 4000.0
	main.add_child(cam)
	cam.make_current()
	game.terrain.add_viewer(cam, 110.0)
	var sun: DirectionalLight3D = main.get_node("Atmosphere/Sun")
	var to_sun := sun.global_basis.z # licht schijnt langs −z: de zon zit langs +z
	var giant: Vector3 = PlanetType.params(game.planet_type, style).sky.giant_dir
	var ground := game.terrain.focus_world + Vector3(-20.0, 1.8, 30.0)
	ground.y = game.terrain.surface_height_at(ground.x, ground.z) + 1.8
	var level := func(v: Vector3, pitch_deg: float) -> Vector3:
		var flat := Vector3(v.x, 0.0, v.z).normalized()
		return (flat * cos(deg_to_rad(pitch_deg)) + Vector3.UP * sin(deg_to_rad(pitch_deg))).normalized()
	var shots := [
		[ground, level.call(to_sun, 12.0)],
		[ground, level.call(-to_sun, 12.0)],
		[ground, giant],
		[ground + Vector3(0, 150, 0), level.call(-to_sun, -20.0)],
		[ground + Vector3(0, 340, 0), level.call(Vector3(0.6, 0, -1), -40.0)],
		[ground + Vector3(0, 340, 0), level.call(Vector3(-0.3, 0, -1), 2.0)],
	]
	for i in shots.size():
		var pos: Vector3 = shots[i][0]
		var look: Vector3 = shots[i][1]
		cam.global_position = pos
		cam.look_at(pos + look, Vector3.UP if absf(look.y) < 0.99 else Vector3.FORWARD)
		# Wachten tot het terrein rond de camera gemesht is (anders zie je gaten waar het nog laadt).
		var floor_pos := Vector3(pos.x, game.terrain.surface_height_at(pos.x, pos.z), pos.z)
		var waited := 0
		while waited < 1200 and not game.terrain.is_area_ready(floor_pos, 80.0):
			await get_tree().process_frame
			waited += 1
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("%s_%d.png" % [style, i + 1])
		cam.get_viewport().get_texture().get_image().save_png(path)
		print("[sky_preview] ", path)


# --- Gemeenschappelijk ------------------------------------------------------------------------

## Camera klaarzetten en wachten tot het terrein rond de landingsplek gemesht is en het verre
## landschap gebouwd.
func _setup_cam(fov: float, far: float) -> Camera3D:
	var game: Game = main.game
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.1
	cam.far = far
	main.add_child(cam)
	cam.make_current()
	game.terrain.add_viewer(cam, 110.0)
	game.surface.finish()
	var c := game.terrain.focus_world
	var waited := 0
	while waited < 1500 and not game.terrain.is_area_ready(c, 100.0):
		await get_tree().process_frame
		waited += 1
	return cam


func _atmosphere() -> Atmosphere:
	return main.get_node("Atmosphere") as Atmosphere


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[sky_preview] ", path)


## Camera op `pos`, gedraaid (yaw rond y, dan pitch), in graden.
static func _aim(cam: Camera3D, pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0)), pos)


# --- Automatische horizoncontrole -----------------------------------------------------------

func _horizon_check() -> void:
	var game: Game = main.game
	var t: TerrainAPI = game.terrain
	var out := PerfLog.log_dir().path_join("horizon_check")
	DirAccess.make_dir_recursive_absolute(out)
	for f in DirAccess.get_files_at(out):
		DirAccess.remove_absolute(out.path_join(f))
	var far := float(CmdArgs.value("far", 4000.0))
	var margin := deg_to_rad(float(CmdArgs.value("margin", 0.1)))
	var cam: Camera3D = await _setup_cam(84.0, far)
	var atmo := _atmosphere()
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var normal_sky := env.sky
	var check_sky := Sky.new()
	var check_mat := ShaderMaterial.new()
	var check_shader := Shader.new()
	check_shader.code = "shader_type sky;\nvoid sky() { COLOR = vec3(0.6, 0.0, 0.6); }\n"
	check_mat.shader = check_shader
	check_sky.sky_material = check_mat
	var c := t.shaft_center_world()
	var gy := t.surface_height_at(c.x, c.z)
	var radius := Tuning.get_f("sky", "planet_radius_m", 30000.0)
	var vp := get_viewport().get_visible_rect().size
	const W := 320
	const H := 180
	var shots := 0
	var failed := 0
	var worst := 0
	var specks := 0
	for h: float in [2.0, 20.0, 60.0, 100.0, 160.0, 250.0, 345.0]:
		for yaw: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
			for pitch: float in [-55.0, -25.0, 0.0, 10.0]:
				var b := Basis(Vector3.UP, deg_to_rad(yaw))
				var pos := Vector3(c.x, gy + h, c.z) + b * Vector3(0.0, 0.0, 20.0)
				pos.y = maxf(pos.y, t.surface_height_at(pos.x, pos.z) + 1.2)
				_aim(cam, pos, yaw, pitch)
				# Gewone render (mist, hemel): die bewaren we als het fout gaat.
				env.sky = normal_sky
				atmo.set_process(true)
				atmo.snap()
				for f in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var normal_img := get_viewport().get_texture().get_image()
				# Controle: magenta hemel, geen mist, geen gloed.
				atmo.set_process(false)
				env.sky = check_sky
				var fog_was := env.fog_enabled
				var vol_was := env.volumetric_fog_enabled
				var glow_was := env.glow_enabled
				var adj_was := env.adjustment_enabled
				var refl_was := env.reflected_light_source
				# Geen weerkaatsing van de hemel: anders telt de metalen boorkop van de Mol als hemel.
				env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
				env.fog_enabled = false
				env.volumetric_fog_enabled = false
				env.glow_enabled = false
				env.adjustment_enabled = false
				for f in 2:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				env.fog_enabled = fog_was
				env.volumetric_fog_enabled = vol_was
				env.glow_enabled = glow_was
				env.adjustment_enabled = adj_was
				env.reflected_light_source = refl_was
				img.resize(W, H, Image.INTERPOLATE_NEAREST)
				var dip := sqrt(2.0 * maxf(pos.y - gy, 0.0) / radius)
				var below := PackedByteArray()
				below.resize(W * H)
				var mask := Image.create(W, H, false, Image.FORMAT_RGB8)
				for y in H:
					for x in W:
						var col := img.get_pixel(x, y)
						var sky := col.b > 0.3 and col.b > col.g + 0.15 and col.r > col.g + 0.15
						if not sky:
							continue
						var ray := cam.project_ray_normal(Vector2((x + 0.5) * vp.x / W, (y + 0.5) * vp.y / H))
						var e := asin(clampf(ray.y, -1.0, 1.0)) + dip
						if e < -margin:
							below[y * W + x] = 1
							mask.set_pixel(x, y, Color(1, 0, 0))
						else:
							mask.set_pixel(x, y, Color(0.3, 0.0, 0.3))
				# Een losse pixel is een speldenprik in het voxelterrein (de mesher laat soms een kiertje
				# van een pixel); een rand of een gat in het landschap is altijd een vlek.
				var bad := 0
				for y in range(1, H - 1):
					for x in range(1, W - 1):
						if below[y * W + x] == 0:
							continue
						var neighbours := 0
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								neighbours += below[(y + dy) * W + x + dx]
						if neighbours > 1:
							bad += 1
						else:
							specks += 1
				shots += 1
				worst = maxi(worst, bad)
				if bad > 0:
					failed += 1
					var stem := "fout_%03d_%03d_%+03d" % [int(h), int(yaw), int(pitch)]
					normal_img.save_png(out.path_join(stem + ".png"))
					mask.save_png(out.path_join(stem + "_masker.png"))
					print("[horizon] FOUT h=%.0f yaw=%.0f pitch=%.0f: %d pixels (van %d) hemel onder de horizon" % [h, yaw, pitch, bad, W * H])
				elif int(yaw) % 90 == 0 and pitch in [-25.0, 0.0] and h in [60.0, 160.0, 345.0]:
					normal_img.save_png(out.path_join("ok_%03d_%03d_%+03d.png" % [int(h), int(yaw), int(pitch)]))
	env.sky = normal_sky
	atmo.set_process(true)
	print("[horizon] %s: %d beelden, %d met hemel onder de horizon (ergste: %d pixels op %d×%d), far %.0f m; losse speldenprikken: %d" % [
			"PASS" if failed == 0 else "FAIL", shots, failed, worst, W, H, far, specks])


# --- Vaste beelden voor voor/na -----------------------------------------------------------

func _views() -> void:
	var game: Game = main.game
	var t: TerrainAPI = game.terrain
	var surf: PlanetSurface = game.surface
	var out := PerfLog.log_dir().path_join("horizon_views")
	DirAccess.make_dir_recursive_absolute(out)
	var cam: Camera3D = await _setup_cam(75.0, 6000.0)
	var tint := CmdArgs.has("tint")
	var prefix := "tint_" if tint else ""
	if tint:
		var m1 := StandardMaterial3D.new()
		m1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m1.albedo_color = Color(0.9, 0.1, 0.8)
		(surf.get_node("FarTerrain") as MeshInstance3D).material_override = m1
		var m2 := StandardMaterial3D.new()
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m2.albedo_color = Color(0.1, 0.8, 0.9)
		(surf.get_node("AreaFromAbove") as MeshInstance3D).material_override = m2
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var c := t.shaft_center_world()
	var gy := t.surface_height_at(c.x, c.z)
	var land := Vector3(c.x, gy, c.z)
	var shots := [] # [naam, positie, doel, fov]
	# Zoals drop_sequence: 40 m achter de landingsplek, licht omlaag.
	for h: float in [340.0, 160.0, 60.0]:
		for yaw: float in [0.0, 90.0, 180.0, 270.0]:
			var b := Basis(Vector3.UP, deg_to_rad(yaw))
			var p := land + Vector3(0.0, h, 0.0) + b * Vector3(0.0, 0.0, 40.0)
			shots.append(["hoogte_%03d_%03d" % [int(h), int(yaw)], p, p + b * Vector3(0.0, -0.18 - h / 1400.0, -1.0), 75.0])
	# De dropcamera (DropCam): begin van de val (omhoog naar het schip), kantelen, op 150 m.
	var mol := land + Vector3(0, 340.0, 0)
	for k: float in [0.0, 0.5, 1.0]:
		var p := mol + Vector3(0, lerpf(-4.0, 14.0, k), 30.0)
		shots.append(["dropcam_k%d" % int(k * 10), p, mol + Vector3(0, lerpf(16.0, -4.0, k), 0) - Vector3(0, 0, 1) * lerpf(0.0, 14.0, k), 72.0])
	# De achtervolgcamera van de val kijkt van boven 220 m bijna recht omlaag (±77°): fijn detail.
	for h: float in [300.0, 220.0, 120.0]:
		var p := land + Vector3(0.0, h, 30.0)
		shots.append(["val_%03d" % int(h), p, p + Vector3(0.0, -h, -h / tan(deg_to_rad(77.0))), 72.0])
	var mol2 := land + Vector3(0, 150.0, 0)
	shots.append(["dropcam_150", mol2 + Vector3(0, 14, 30), mol2 + Vector3(0, -4, -14), 72.0])
	# Ophalen: vaste camera op de grond (14, 1.7, 26) naast de Mol, die de Mol nakijkt.
	var gp := Vector3(c.x + 14.0, 0, c.z + 26.0)
	gp.y = t.surface_height_at(gp.x, gp.z) + 1.7
	for mh: float in [3.0, 30.0, 120.0]:
		shots.append(["lift_%03d" % int(mh), gp, land + Vector3(0, mh + 2.0, 0), 72.0])
	# Op de grond (ooghoogte 1,2 m) in vier richtingen, en te voet aan de rand van het speelgebied.
	for yaw: float in [0.0, 90.0, 180.0, 270.0]:
		var b := Basis(Vector3.UP, deg_to_rad(yaw))
		var p := land + b * Vector3(0.0, 0.0, 7.5)
		p.y = t.surface_height_at(p.x, p.z) + 1.2
		shots.append(["grond_%03d" % int(yaw), p, p + b * Vector3(0.0, 0.07, 1.0), 75.0]) # van de Mol weg
	var edge := Vector3(c.x, 0, 4.0)
	edge.y = t.surface_height_at(edge.x, edge.z) + 1.2
	shots.append(["rand_te_voet", edge, edge + Vector3(0.3, -0.05, -1.0), 75.0])
	var corner := Vector3(6.0, 0, 6.0)
	corner.y = t.surface_height_at(corner.x, corner.z) + 1.2
	shots.append(["hoek_te_voet", corner, corner + Vector3(-1.0, -0.04, -1.0), 75.0])
	# Zo hoog als de hub (zonder hub): wat de hemel tekent.
	shots.append(["hub_hoogte", land + Vector3(0, 1740, 40), land + Vector3(0, 1740 - 0.35 * 100.0, -60), 75.0])
	var atmo := _atmosphere()
	var far_node := surf.get_node("FarTerrain") as MeshInstance3D
	print("[views] driehoeken: ", surf.triangle_counts())
	for s: Array in shots:
		cam.fov = float(s[3])
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		atmo.snap()
		for f in 30:
			await get_tree().process_frame
		var gpu := 0.0
		for f in 20:
			await RenderingServer.frame_post_draw
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		await _save(out.path_join("%s%s.png" % [prefix, s[0]]))
		if not tint and CmdArgs.has("perf"):
			far_node.visible = false
			var gpu2 := 0.0
			for f in 20:
				await RenderingServer.frame_post_draw
				gpu2 += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			far_node.visible = true
			print("[views] %s: gpu %.2f ms (zonder verre landschap %.2f ms), %d primitieven" % [s[0], gpu / 20.0, gpu2 / 20.0, prims])


# --- GPU-tijd van het landschap van hoog in de lucht -------------------------------------------

## --bench: GPU-tijd (gemiddelde van 240 frames) op vier vaste plekken, met en zonder het verre
## landschap en het raster. Op deze pc (RTX 4090) zijn enkel de verhoudingen iets waard.
func _bench() -> void:
	var game: Game = main.game
	var t: TerrainAPI = game.terrain
	var cam: Camera3D = await _setup_cam(75.0, 4000.0)
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	# Meer pixels (--scale=2: 4×), zodat de kost per pixel boven de vaste kost per frame uitkomt.
	get_viewport().scaling_3d_scale = float(CmdArgs.value("scale", 1.0))
	var c := t.shaft_center_world()
	var land := Vector3(c.x, t.surface_height_at(c.x, c.z), c.z)
	var far_nodes := [game.surface.get_node("FarTerrain"), game.surface.get_node("AreaFromAbove")]
	for s: Array in [["340 m", 340.0, -25.0], ["160 m", 160.0, -20.0], ["60 m", 60.0, -12.0], ["grond", 1.2, 2.0]]:
		_aim(cam, land + Vector3(0.0, float(s[1]), 40.0), 0.0, float(s[2]))
		_atmosphere().snap()
		var res := []
		for show in [true, false]:
			for n: Node3D in far_nodes:
				n.visible = show
			for f in 60:
				await RenderingServer.frame_post_draw
			var gpu := 0.0
			for f in 240:
				await RenderingServer.frame_post_draw
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			res.append(gpu / 240.0)
		print("[bench] %s: %.3f ms GPU, zonder verre landschap en raster %.3f ms (verschil %.3f ms)" % [s[0], res[0], res[1], res[0] - res[1]])


# --- De hub: door de open baai naar beneden ---------------------------------------------------

func _hub() -> void:
	var game: Game = main.game
	var t: TerrainAPI = game.terrain
	var out := PerfLog.log_dir().path_join("horizon_views")
	DirAccess.make_dir_recursive_absolute(out)
	var cam: Camera3D = await _setup_cam(75.0, 4000.0)
	cam.near = 0.05
	# Zoals Game de hub bouwt: het buitenschip boven de landingsplek, de hub 1,4 km hoger.
	var exterior := EksterExterior.new()
	exterior.name = "EksterExterior"
	game.add_child(exterior)
	exterior.place_dock_at(EksterExterior.dock_above(t))
	var hub := Ekster.new()
	hub.name = "Ekster"
	hub.game = game
	game.add_child(hub)
	hub.place_dock_at(exterior.dock_position() + Vector3(0.0, Ekster.HUB_ABOVE, 0.0))
	_atmosphere().ship = hub
	hub.doors_open = true
	await get_tree().create_timer(4.0).timeout
	var frame := hub.global_transform
	var bay := hub.bay
	var bc := bay.get_center()
	var shots := [
		# Van op de kade aan de rand van de baai, schuin naar beneden door de open luiken.
		["hub_kade_baai", Vector3(bc.x + 0.5, 1.3, bay.end.z + 1.2), Vector3(bc.x, -30.0, bc.z - 4.0)],
		# Vanaf de galerij, steil naar beneden.
		["hub_galerij_baai", Vector3(11.5, 3.8, -4.5), Vector3(bc.x, -40.0, bc.z + 1.0)],
		# Recht naar beneden boven het midden van de baai.
		["hub_loodrecht", Vector3(bc.x, 5.0, bc.z), Vector3(bc.x + 0.05, -100.0, bc.z + 0.05)],
		# Door het raam, en door het raam naar beneden.
		["hub_venster", Vector3(6.5, 0.6, -6.5), Vector3(4.0, 2.5, -16.0)],
		["hub_venster_omlaag", Vector3(6.5, 1.4, -6.5), Vector3(4.0, -8.0, -16.0)],
	]
	for s: Array in shots:
		cam.global_position = frame * (s[1] as Vector3)
		cam.look_at(frame * (s[2] as Vector3), Vector3.UP)
		_atmosphere().snap()
		for f in 30:
			await get_tree().process_frame
		await _save(out.path_join("%s.png" % s[0]))
