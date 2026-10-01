extends Node
## Screenshots van de rots op elke laag, zoals je ze in het spel ziet (voor/na vergelijken).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=terrain_preview --no-steam --shot=naam
## Per laag een tunnel zoals de Mol hem boort (bollen van 3,2 m), met kapsporen van een houweel
## in de wand, gezien met dezelfde helmlamp als de speler. Twee beelden per laag:
##   <shot>_<laag>.png        langs de tunnel (scherende hoek op de wanden)
##   <shot>_<laag>_wand.png   de bekapte wand van dichtbij
## --only=klei,graniet om enkel bepaalde lagen te maken.

const DEPTHS := {"klei": 12.0, "zandsteen": 48.0, "graniet": 92.0, "kristal": 130.0}

var main: Node
var _queue: Array = []
var _cam: Camera3D
var _frames := -1
var _shot := ""
var _gpu: Array[float] = []


func on_terrain_loaded(_stats: Dictionary) -> void:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x, sc.z)
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for layer: String in DEPTHS:
		if not only.is_empty() and layer not in only:
			continue
		var c := Vector3(sc.x - 12.0, top - DEPTHS[layer], sc.z)
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
		_queue.append([layer, c + Vector3(1.5, -0.4, -0.9), c + Vector3(16.0, -0.6, 0.8)])
		_queue.append([layer + "_wand", c + Vector3(7.0, -0.2, 0.2), c + Vector3(10.5, 0.0, 3.4)])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_cam = Camera3D.new()
	_cam.fov = 80.0
	main.add_child(_cam)
	_cam.make_current()
	# Exact de helmlamp van de speler (player.gd).
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
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
	_frames += 1
	if _frames > 20:
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	if _frames == 50:
		var avg := 0.0
		for g in _gpu:
			avg += g
		print("[preview] %s: GPU %.2f ms" % [_shot, avg / maxf(1.0, _gpu.size())])
		_gpu.clear()
		var path := PerfLog.log_dir().path_join("%s_%s.png" % [CmdArgs.value("shot", "terrein"), _shot])
		get_viewport().get_texture().get_image().save_png(path)
		print("[preview] ", path)
		_frames = -1
		_next()
