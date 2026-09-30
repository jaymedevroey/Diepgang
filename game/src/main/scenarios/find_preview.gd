extends Node
## Screenshots van een blootgelegde korst en daarna de vrijgekomen vondst.
## tools\godot.cmd --path game -- --scenario=find_preview --no-steam

var main: Node
var _cam: Camera3D
var _step := 0
var _frame := 0


func on_terrain_loaded(_stats: Dictionary) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var it := finds.items[int(CmdArgs.value("find", 0))]
	var p := it.global_position
	# Een kuil graven die de korst half blootlegt, van bovenaf schuin.
	var side := Vector3(1, 0, 0.4).normalized()
	for i in 6:
		t.debug_dig(p + side * (1.1 + i * 0.35) + Vector3(0, 0.25 + i * 0.3, 0), 1.0)
	t.debug_dig(p + side * 0.9 + Vector3(0, 0.1, 0), 0.75)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	main.add_child(_cam)
	_cam.global_position = p + side * 1.9 + Vector3(0, 1.0, 0)
	_cam.look_at(p)
	_cam.make_current()
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 5.0
	lamp.spot_range = 8.0
	lamp.spot_angle = 40.0
	lamp.shadow_enabled = true
	_cam.add_child(lamp)
	lamp.position = Vector3(0.2, 0.25, 0)
	_step = 1


func _process(_delta: float) -> void:
	if _step == 0 or main.terrain.queued_ops() > 0:
		return
	_frame += 1
	var finds: FindField = main.game.finds
	var it := finds.items[int(CmdArgs.value("find", 0))]
	if _step == 1 and _frame == 40:
		_shot("find_1")
		# Twee slagen: barsten zichtbaar.
		finds._rpc_state(it.find_id, 2.0, 1.0, Strata.Tool.HOUWEEL)
	elif _step == 1 and _frame == 60:
		_shot("find_2")
		finds._free(it.find_id)
		_step = 2
		_frame = 0
	elif _step == 2 and _frame == 12:
		_shot("find_3")
		for id: int in finds.crusts:
			var d: float = finds.crusts[id].global_position.distance_to(it.global_position)
			if d < 3.0:
				print("[preview] andere korst %d op %.2f m" % [id, d])
	elif _step == 2 and _frame == 150:
		_shot("find_4")
		get_tree().quit(0)


func _shot(name: String) -> void:
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[preview] ", path)
