extends Node
## Vier robots naast elkaar voor screenshots: stilstaan, lopen, zwaaien, springen.
## tools\godot.cmd --path game -- --scenario=robot_preview --no-steam --shot=robots --frames=20,60

var main: Node
var _rigs: Array[RobotRig] = []
var _t := 0.0
var _frame := -1


func on_terrain_loaded(_stats: Dictionary) -> void:
	var t: TerrainAPI = main.terrain
	var base := t.spawn_point() + Vector3(-3.0, 0, 0)
	for i in 4:
		var rig := RobotRig.new()
		main.add_child(rig)
		var pos := base + Vector3(0, 0, -2.4 + i * 1.6)
		pos.y = t.surface_height_at(pos.x, pos.z)
		rig.global_position = pos
		rig.rotation.y = deg_to_rad(-90 + (i - 1.5) * 12.0)
		rig.setup(Game.COLORS[i])
		_rigs.append(rig)

	var cam := Camera3D.new()
	cam.fov = 55.0
	main.add_child(cam)
	cam.global_position = base + Vector3(4.2, 1.5, 0.0)
	cam.look_at(base + Vector3(0, 0.75, 0))
	cam.make_current()
	for off in [Vector3(1.5, 2.2, -2.5), Vector3(1.5, 2.2, 2.5)]:
		var lamp := SpotLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.55)
		lamp.light_energy = 6.0
		lamp.spot_range = 10.0
		lamp.spot_angle = 45.0
		lamp.shadow_enabled = true
		main.add_child(lamp)
		lamp.global_position = base + off
		lamp.look_at(base + Vector3(0, 0.6, off.z * 0.4))
	_frame = 0


func _process(delta: float) -> void:
	if _frame < 0:
		return
	_frame += 1
	_t += delta
	_rigs[1].velocity = -_rigs[1].global_basis.z * 3.5 # loopt ter plaatse
	if _frame % 40 == 1:
		_rigs[2].swing()
	_rigs[3].on_floor = fmod(_t, 1.2) > 0.5
	_rigs[3].velocity = Vector3(0, 3.0 if not _rigs[3].on_floor else -4.0, 0)
	_rigs[0].look_pitch = sin(_t) * 0.4
	var shots := str(CmdArgs.value("frames", "60")).split(",")
	for i in shots.size():
		if _frame == int(shots[i]):
			var path := PerfLog.log_dir().path_join("%s_%d.png" % [CmdArgs.value("shot", "robots"), i + 1])
			get_viewport().get_texture().get_image().save_png(path)
			print("[preview] screenshot: ", path)
			if i == shots.size() - 1:
				get_tree().quit(0)
