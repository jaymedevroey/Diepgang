extends Node
## Screenshots van het magma: van boven in een schacht, in een tunnel vlak erboven, in een grot, en
## van ver. Het magma wordt op een vaste diepte gezet (los van de klok).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=magma_preview --no-steam
## --depth=60 diepte van het magma onder de landingsplek.

var main: Node
var _queue: Array = []
var _cam: Camera3D
var _frames := -1
var _shot := ""
var _gpu: Array[float] = []


func on_terrain_loaded(_stats: Dictionary) -> void:
	var t: TerrainAPI = main.terrain
	var magma: Magma = main.game.magma
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x, sc.z)
	var depth := float(CmdArgs.value("depth", 60.0))
	var level := top - depth
	# Schacht naar beneden tot onder het magma, een tunnel erlangs, en een grot.
	var c := Vector3(sc.x + 24.0, 0.0, sc.z + 6.0)
	var y := level + 26.0
	while y > level - 6.0:
		t.apply_op(t.make_sphere_op(0, Vector3(c.x, y, c.z), 3.4))
		y -= 1.2
	var x := 0.0
	while x < 26.0:
		t.apply_op(t.make_sphere_op(0, Vector3(c.x + x, level + 1.2, c.z), 3.0))
		x += 0.9
	var cave := Vector3(c.x - 18.0, level + 3.0, c.z + 16.0)
	for k in 14:
		var o := Vector3(randf_range(-7.0, 7.0), randf_range(-3.0, 4.0), randf_range(-7.0, 7.0))
		t.apply_op(t.make_sphere_op(0, cave + o, randf_range(4.0, 6.5)))
	magma.host_start()
	magma.debug_depth = depth
	_queue.append(["schacht", Vector3(c.x + 1.0, level + 14.0, c.z + 1.5), Vector3(c.x, level, c.z)])
	_queue.append(["tunnel", Vector3(c.x + 22.0, level + 2.6, c.z + 0.6), Vector3(c.x + 2.0, level + 0.5, c.z)])
	_queue.append(["grot", cave + Vector3(6.0, 5.0, 7.0), cave + Vector3(-2.0, -3.0, -2.0)])
	_queue.append(["ver", Vector3(c.x + 1.0, level + 30.0, c.z + 2.4), Vector3(c.x, level, c.z)])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_cam = Camera3D.new()
	_cam.fov = 80.0
	main.add_child(_cam)
	_cam.make_current()
	_cam.global_position = c + Vector3(0.0, level, 0.0)
	t.add_viewer(_cam, 90.0, 30.0) # het terrein rond de camera laden (zo diep is er geen speler)
	# De helmlamp van de speler (player.gd).
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	lamp.shadow_enabled = true
	_cam.add_child(lamp)
	lamp.position = Vector3(0.18, 0.22, 0.05)
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
	if _frames < 0 or main.terrain.queued_ops() > 0 or not main.terrain.is_area_ready(_cam.global_position, 24.0):
		return
	_frames += 1
	if _frames > 20:
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
	if _frames == 60:
		var avg := 0.0
		for g in _gpu:
			avg += g
		print("[preview] %s: GPU %.2f ms" % [_shot, avg / maxf(1.0, _gpu.size())])
		_gpu.clear()
		var path := PerfLog.log_dir().path_join("magma_%s.png" % _shot)
		get_viewport().get_texture().get_image().save_png(path)
		print("[preview] ", path)
		_frames = -1
		_next()
