extends Node
## Screenshots van de rotswanden op elke laag (voor/na vergelijken).
## tools\godot.cmd --path game -- --scenario=terrain_preview --no-steam --shot=terrein
## Per laag: een grot graven, camera met helmlamp erin, screenshot <shot>_<laag>.png.

const DEPTHS := {"klei": 12.0, "zandsteen": 48.0, "graniet": 92.0, "kristal": 130.0}

var main: Node
var _queue: Array = []
var _cam: Camera3D
var _frames := -1
var _current := ""


func on_terrain_loaded(_stats: Dictionary) -> void:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x, sc.z)
	for layer: String in DEPTHS:
		# Grot naast de schacht, weg van de rand.
		var c := sc + Vector3(14.0, top - DEPTHS[layer], 9.0)
		for off in [Vector3.ZERO, Vector3(2.5, 0.6, 1.0), Vector3(-2.2, -0.4, 1.8), Vector3(0.8, 1.2, -2.0), Vector3(3.5, -0.8, -1.2)]:
			t.debug_dig(c + off, 3.0)
		_queue.append([layer, c])
	_cam = Camera3D.new()
	_cam.fov = 75.0
	main.add_child(_cam)
	_cam.make_current()
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
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
	_current = item[0]
	var c: Vector3 = item[1]
	_cam.global_position = c + Vector3(-2.0, -0.6, 2.6)
	_cam.look_at(c + Vector3(2.5, -0.5, -1.5))
	_frames = 0


func _process(_delta: float) -> void:
	if _frames < 0 or main.terrain.queued_ops() > 0:
		return
	_frames += 1
	if _frames == 45:
		var path := PerfLog.log_dir().path_join("%s_%s.png" % [CmdArgs.value("shot", "terrein"), _current])
		get_viewport().get_texture().get_image().save_png(path)
		print("[preview] ", path)
		_frames = -1
		_next()
