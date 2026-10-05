extends Node
## Screenshots van de rots op elke laag, zoals je ze in het spel ziet (voor/na vergelijken).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=terrain_preview --no-steam --shot=naam
## Per laag een tunnel zoals de Mol hem boort (bollen van 3,2 m), met kapsporen van een houweel
## in de wand, en de dichtstbijzijnde echte grot uit de seed, gezien met dezelfde helmlamp als de
## speler. De dieptes volgen Strata (de grote planeet: het oppervlak ligt op ±285 m). Beelden:
##   <shot>_p<planeet>_<laag>.png        langs de tunnel (scherende hoek op de wanden)
##   <shot>_p<planeet>_<laag>_wand.png   de bekapte wand van dichtbij
##   <shot>_p<planeet>_<laag>_grot.png   een grot uit de seed, van op de vloer
## --only=klei,graniet om enkel bepaalde lagen te maken; --planet=0|1|2 (Roestbol, Fossielwereld,
## Kristalmaan); --magma=1 laat het magma op zijn plek (anders ver weg).

const LAYERS := ["klei", "zandsteen", "graniet", "kristal"]

var main: Node
var _queue: Array = []
var _cam: Camera3D
var _frames := -1
var _shot := ""
var _gpu: Array[float] = []
var _started := false


func on_terrain_loaded(_stats: Dictionary) -> void:
	if _started:
		return
	var game: Game = main.game
	var planet := int(CmdArgs.value("planet", 0))
	if planet != int(game.planet_type):
		game.host_new_world(game.pit_seed, planet) # komt hier terug als die wereld geladen is
		return
	_started = true
	var t: TerrainAPI = main.terrain
	if not CmdArgs.has("magma"):
		game.magma.debug_depth = 900.0
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x, sc.z)
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ys := {"klei": top - 25.0, "zandsteen": (Strata.TOPS_M[1] + Strata.TOPS_M[2]) * 0.5,
			"graniet": (Strata.TOPS_M[0] + Strata.TOPS_M[1]) * 0.5, "kristal": Strata.TOPS_M[0] * 0.5}
	for li in LAYERS.size():
		var layer: String = LAYERS[li]
		if not only.is_empty() and layer not in only:
			continue
		var c := Vector3(sc.x - 12.0, ys[layer], sc.z + 18.0 * (li - 1.5))
		# Tunnel van 22 m langs x, zoals de Mol hem boort.
		var x := 0.0
		while x < 22.0:
			# Zoals Mol._bore: een bol plus happen uit wand en plafond (niet de vloer).
			var bites: Array = []
			for k in 6:
				var d := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
				if d.y < -0.2:
					continue
				var r := rng.randf_range(0.45, 0.95)
				bites.append([c + Vector3(x, 0, 0) + d * (3.2 - r * 0.4), r])
			t.apply_op(t.make_sphere_op(0, c + Vector3(x, 0, 0), 3.2, bites))
			x += 0.9
		# Kapsporen: kleine happen in de rechterwand, zoals een houweel ze maakt.
		for i in 26:
			var p := c + Vector3(rng.randf_range(6.0, 13.0), rng.randf_range(-1.2, 1.6), 3.0 + rng.randf_range(0.0, 0.5))
			t.debug_dig(p, rng.randf_range(0.55, 0.9))
		var floor_y := c.y - 2.9
		_queue.append([layer, Vector3(c.x + 1.0, floor_y + 1.2, c.z - 0.8), c + Vector3(18.0, -1.2, 0.6)])
		_queue.append([layer + "_wand", Vector3(c.x + 8.0, floor_y + 1.6, c.z + 0.4), c + Vector3(10.5, 0.2, 3.4)])
		# De dichtstbijzijnde grot in deze laag (een middelgrote: daar kom je het eerst).
		var best := Vector4.ZERO
		var bd := 1e9
		for cv: Vector4 in t.caverns():
			if int(t.layer_at(Vector3(cv.x, cv.y, cv.z))) != 3 - li:
				continue
			var dd := Vector2(cv.x - sc.x, cv.z - sc.z).length() + absf(cv.w - 12.0) * 3.0
			if dd < bd:
				bd = dd
				best = cv
		if best != Vector4.ZERO:
			var cc := Vector3(best.x, best.y, best.z)
			var eye := cc + Vector3(best.w * 0.45, 0.0, best.w * 0.15)
			var fy := eye.y
			while t.generated_rock_depth(Vector3(eye.x, fy, eye.z)) < 0.0 and fy > eye.y - 20.0:
				fy -= 0.25
			eye.y = fy + 1.2
			_queue.append([layer + "_grot", eye, Vector3(cc.x - best.w * 0.3, eye.y + 0.5, cc.z)])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_cam = Camera3D.new()
	_cam.fov = 80.0
	main.add_child(_cam)
	_cam.make_current()
	# Zo diep is er geen speler: de camera laadt zelf het terrein rond zich.
	t.add_viewer(_cam, 70.0, 0.0)
	# Exact de helmlamp van de speler (player.gd).
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	lamp.light_volumetric_fog_energy = 1.6
	lamp.shadow_enabled = true
	_cam.add_child(lamp)
	lamp.position = Vector3(0.18, 0.22, 0.05)
	var fill := SpotLight3D.new()
	fill.light_color = Color(1.0, 0.8, 0.58)
	fill.light_energy = Tuning.get_f("player", "lamp_fill_energy", 0.9)
	fill.spot_range = 13.0
	fill.spot_angle = 80.0
	fill.spot_angle_attenuation = 1.6
	fill.light_volumetric_fog_energy = 0.3
	_cam.add_child(fill)
	fill.position = lamp.position
	_next()


func _next() -> void:
	if _queue.is_empty():
		get_tree().quit(0)
		return
	var item: Array = _queue.pop_front()
	_shot = item[0]
	_cam.global_position = item[1]
	_cam.look_at(item[2])
	_frames = 0


func _process(_delta: float) -> void:
	if _frames < 0 or main.terrain.queued_ops() > 0:
		return
	if _frames == 0 and not main.terrain.is_area_ready(_cam.global_position, 20.0):
		return # eerst laden en meshen rond de camera
	_frames += 1
	if _frames > 40:
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	if _frames == 80:
		var avg := 0.0
		for g in _gpu:
			avg += g
		print("[preview] %s: GPU %.2f ms" % [_shot, avg / maxf(1.0, _gpu.size())])
		_gpu.clear()
		var path := PerfLog.log_dir().path_join("%s_p%d_%s.png" % [CmdArgs.value("shot", "terrein"), int(main.game.planet_type), _shot])
		get_viewport().get_texture().get_image().save_png(path)
		print("[preview] ", path)
		_frames = -1
		_next()
