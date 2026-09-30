extends Node
## M0 stap 5: 4 gesimuleerde gravers + 30 fysica-objecten. Logt frametijden naar logs/.
## tools\godot.cmd --path game -- --scenario=stress --duration=60 --no-steam
## Elke graver graaft via TerrainAPI.request_dig, dus met dezelfde snelheidslimiet als een speler.

const BOT_COUNT := 4
const BODY_COUNT := 30
const WARMUP_S := 2.0
const DIG_RADIUS_M := 1.0
const DIG_STEP_M := 0.35

var main: Node
var duration := 60.0

var _t: TerrainAPI
var _rng := RandomNumberGenerator.new()
var _bots: Array[Dictionary] = []
var _bodies: Array[RigidBody3D] = []
var _lamps: Array[SpotLight3D] = []
var _camera: Camera3D
var _perf := PerfLog.new(PackedStringArray(["process_ms", "physics_ms", "ops_total", "ops_frame", "awake_bodies", "draw_calls", "static_mem_mb"]))
var _running := false
var _elapsed := 0.0
var _last_us := 0
var _last_ops := 0
var _drop_timer := 0.0
var _drop_index := 0


func _ready() -> void:
	duration = float(CmdArgs.value("duration", 60.0))
	_rng.seed = 42
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func on_terrain_loaded(_stats: Dictionary) -> void:
	_t = main.terrain
	var sc := _t.shaft_center_world()
	for i in BOT_COUNT:
		var ang := i * TAU / BOT_COUNT + 0.4
		var start := sc + Vector3(cos(ang), 0.0, sin(ang)) * 10.0
		start.y = _t.surface_height_at(start.x, start.z) - 0.5
		_bots.append({
			"id": 101 + i,
			"pos": start,
			"dir": Vector3(cos(ang), -0.45, sin(ang)).normalized(),
			"turn": _rng.randf_range(2.0, 4.0),
		})
		# Elke graver heeft een helmlamp met schaduw: samen het GDD-budget van 4 schaduwlampen.
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(1.0, 0.78, 0.5)
		lamp.light_energy = 4.0
		lamp.spot_range = 18.0
		lamp.spot_angle = 40.0
		lamp.shadow_enabled = true
		add_child(lamp)
		_lamps.append(lamp)

	for i in BODY_COUNT:
		_bodies.append(_make_body(i))

	_camera = Camera3D.new()
	_camera.fov = 80.0
	_camera.near = 0.05
	add_child(_camera)
	_camera.make_current()
	_running = true
	print("[stress] gestart: %d gravers, %d objecten, %.0f s" % [BOT_COUNT, BODY_COUNT, duration])


func _physics_process(delta: float) -> void:
	if not _running:
		return
	var inner_min := Vector3(2.5, 3.0, 2.5)
	var inner_max := _t.world_size() - Vector3(2.5, 0.0, 2.5)
	for bot in _bots:
		bot.turn -= delta
		if bot.turn <= 0.0:
			bot.turn = _rng.randf_range(2.0, 4.0)
			var turned: Vector3 = bot.dir.rotated(Vector3.UP, _rng.randf_range(-0.9, 0.9))
			turned.y = clampf(turned.y + _rng.randf_range(-0.3, 0.15), -0.7, 0.3)
			bot.dir = turned.normalized()
		# Terugkaatsen enkel als de graver naar de rand toe beweegt.
		var d: Vector3 = bot.dir
		var p: Vector3 = bot.pos
		if (p.x < inner_min.x and d.x < 0.0) or (p.x > inner_max.x and d.x > 0.0):
			d.x = -d.x
		if (p.z < inner_min.z and d.z < 0.0) or (p.z > inner_max.z and d.z > 0.0):
			d.z = -d.z
		if p.y < inner_min.y and d.y < 0.0:
			d.y = -d.y
		if p.y > _t.surface_height_at(p.x, p.z) - 3.0 and d.y > -0.3:
			d.y = -0.45
		bot.dir = d.normalized()
		var next: Vector3 = bot.pos + bot.dir * DIG_STEP_M
		if _t.request_dig(bot.id, next, DIG_RADIUS_M):
			bot.pos = next

	# Om de halve seconde valt er een object in de tunnel achter een graver.
	_drop_timer += delta
	if _elapsed > 5.0 and _drop_timer > 0.5:
		_drop_timer = 0.0
		var body := _bodies[_drop_index % _bodies.size()]
		var bot: Dictionary = _bots[_drop_index % _bots.size()]
		_drop_index += 1
		body.global_position = bot.pos - bot.dir * 2.0 + Vector3.UP * 0.3
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false


func _process(delta: float) -> void:
	if not _running:
		return
	for i in _bots.size():
		var bot: Dictionary = _bots[i]
		_lamps[i].global_position = bot.pos - bot.dir * 1.2 + Vector3.UP * 0.4
		_safe_look_at(_lamps[i], bot.pos + bot.dir * 3.0)
	var lead: Dictionary = _bots[0]
	var want: Vector3 = lead.pos - lead.dir * 3.0 + Vector3.UP * 0.6
	_camera.global_position = _camera.global_position.lerp(want, minf(1.0, delta * 4.0)) if _elapsed > 0.1 else want
	_safe_look_at(_camera, lead.pos)

	var now := Time.get_ticks_usec()
	_elapsed += delta
	if _last_us > 0 and _elapsed > WARMUP_S:
		var awake := 0
		for b in _bodies:
			awake += int(not b.sleeping)
		var ops := _t.ops_applied_total
		_perf.add(PackedFloat32Array([
			_elapsed,
			(now - _last_us) / 1000.0,
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			ops,
			ops - _last_ops,
			awake,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			OS.get_static_memory_usage() / 1048576.0,
		]))
		_last_ops = ops
	_last_us = now
	if _elapsed >= duration + WARMUP_S:
		_finish()


func _finish() -> void:
	_running = false
	var stamp := PerfLog.timestamp()
	var method := RenderingServer.get_current_rendering_method()
	var dir := PerfLog.log_dir()
	var csv := dir.path_join("stress_%s_%s.csv" % [method, stamp])
	_perf.write_csv(csv)
	var summary := _perf.summary()
	summary["renderer"] = method
	summary["adapter"] = RenderingServer.get_video_adapter_name()
	summary["duration_s"] = duration
	summary["ops_applied"] = _t.ops_applied_total
	summary["ops_per_s"] = _t.ops_applied_total / (duration + WARMUP_S)
	summary["voxel_engine"] = VoxelEngine.get_stats()
	summary["terrain"] = _t.get_stats()
	var json := dir.path_join("stress_%s_%s.json" % [method, stamp])
	FileAccess.open(json, FileAccess.WRITE).store_string(JSON.stringify(summary, "  "))
	print("[stress] klaar. CSV: %s" % csv)
	print("[stress] samenvatting: %s" % JSON.stringify(summary))
	get_tree().quit(0)


static func _safe_look_at(node: Node3D, target: Vector3) -> void:
	var to := target - node.global_position
	if to.length_squared() < 0.0001 or absf(to.normalized().y) > 0.99:
		return
	node.look_at(target)


func _make_body(i: int) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = 1 << 1
	body.collision_mask = 1 | (1 << 1) | (1 << 2)
	body.continuous_cd = true
	body.mass = _rng.randf_range(2.0, 20.0)
	var size := _rng.randf_range(0.3, 0.8)
	var shape := CollisionShape3D.new()
	var mesh := MeshInstance3D.new()
	if i % 2 == 0:
		var box := BoxMesh.new()
		box.size = Vector3(size, size * 0.7, size * 1.2)
		var bs := BoxShape3D.new()
		bs.size = box.size
		shape.shape = bs
		mesh.mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = size * 0.5
		sphere.height = size
		sphere.radial_segments = 8
		sphere.rings = 4
		shape.shape = sphere.create_convex_shape()
		mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(_rng.randf_range(0.05, 0.15), 0.5, _rng.randf_range(0.5, 0.9))
	mesh.material_override = mat
	body.add_child(shape)
	body.add_child(mesh)
	add_child(body)
	var bot: Dictionary = _bots[i % _bots.size()]
	body.global_position = bot.pos + Vector3(_rng.randf_range(-2, 2), 2.0 + i * 0.3, _rng.randf_range(-2, 2))
	return body
