extends Node
## Screenshots van het gereedschap: houweel, boor en handschoen los in beeld (studiolicht), en
## daarna in first person (rust, zwaai, boren). logs/gereedschap_*.png
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=tool_preview --no-steam

var main: Node


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(p: Player) -> void:
	await _wait(1.5)
	# Studio: een donkere ruimte boven de put, sleutellicht + randlicht.
	var stage := Node3D.new()
	main.add_child(stage)
	stage.global_position = p.global_position + Vector3(0, 30, 0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	stage.add_child(cam)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.6
	key.rotation_degrees = Vector3(-35, -40, 0)
	stage.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 2.0
	rim.omni_range = 4.0
	rim.position = Vector3(-0.8, 0.8, -1.2)
	stage.add_child(rim)
	var items := [
		["gereedschap_houweel", PickaxeModel.build(0.0, PickaxeModel.GLOVE, false), Vector3(0, 0.26, -0.02), Vector3(0, 0, 0)],
		["gereedschap_boor", DrillModel.build(0.0, PickaxeModel.GLOVE, false), Vector3(0, 0.08, -0.1), Vector3(0, 0, 0)],
		["gereedschap_hand", PickaxeModel.part("Glove", 0.0, Color(0.2, 0.75, 0.95), false), Vector3(0.05, -0.05, 0.1), Vector3(0, 0, 0)],
	]
	for it: Array in items:
		var model: Node3D = it[1]
		stage.add_child(model)
		var target: Vector3 = stage.global_position + it[2]
		model.global_position = stage.global_position
		for angle in [35.0, 150.0]:
			var a := deg_to_rad(angle)
			var d: float = {"gereedschap_houweel": 1.7, "gereedschap_boor": 1.15}.get(it[0], 0.75)
			cam.global_position = target + Vector3(sin(a) * d, 0.25, cos(a) * d)
			cam.look_at(target)
			cam.make_current()
			await _shot("%s_%d" % [it[0], int(angle)])
		model.queue_free()
	stage.queue_free()

	# In first person: rust, midden in een zwaai, boren.
	p.camera.make_current()
	p.head.rotation.x = deg_to_rad(-25)
	await _shot("gereedschap_fp_houweel", 0.6)
	p.pickaxe.auto_swing = true
	await _wait(0.2)
	await _shot("gereedschap_fp_zwaai", 0.0)
	p.pickaxe.auto_swing = false
	p.select_tool(1)
	p.drill.auto_use = true
	await _shot("gereedschap_fp_boor", 1.2)
	get_tree().quit(0)


func _shot(name: String, settle := 0.3) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[tool_preview] ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
