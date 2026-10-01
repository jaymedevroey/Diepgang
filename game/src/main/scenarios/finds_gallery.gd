extends Node
## Alle soorten vondsten naast elkaar onder studiolicht, met naam en waarde (logs/vondsten.png),
## plus de rotsbrokjes (logs/puin.png).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=finds_gallery --no-steam

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var t: TerrainAPI = main.terrain
	var stage := Node3D.new()
	main.add_child(stage)
	stage.global_position = Vector3(t.world_size().x * 0.5, t.world_size().y + 20.0, t.world_size().z * 0.5)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 8)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.13, 0.11)
	fm.roughness = 1.0
	floor.material_override = fm
	floor.position = Vector3(0, -0.36, 0)
	stage.add_child(floor)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.78)
	key.light_energy = 1.4
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.6, 0.72, 1.0)
	fill.light_energy = 1.2
	fill.omni_range = 8.0
	fill.position = Vector3(-2.5, 1.5, 2.5)
	stage.add_child(fill)

	var n := FindKinds.KEYS.size()
	var cols := 4
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = FindKinds.mesh(i)
		var mats := FindKinds.materials(i)
		for k in mats.size():
			mi.set_surface_override_material(k, mats[k])
		var row := i / cols
		var col := i % cols
		var aabb := mi.mesh.get_aabb()
		mi.position = Vector3((col - (cols - 1) * 0.5) * 0.85, -0.36 - aabb.position.y, row * 0.85 - 0.9)
		# Voorkant (−z) naar de camera; de geode met zijn open kant (+x) erheen.
		mi.rotation_degrees = Vector3(0, 155 if FindKinds.KEYS[i] != "Geode" else -60, 0)
		stage.add_child(mi)
		var label := Label3D.new()
		label.text = "%s\n€%d · %d kg" % [FindKinds.NAMES[i], FindKinds.BASE_VALUES[i], int(FindKinds.MASSES[i])]
		label.font = UiTheme.body(800)
		label.font_size = 40
		label.pixel_size = 0.0012
		label.modulate = UiTheme.CREAM
		label.outline_size = 10
		label.position = Vector3(mi.position.x, -0.33, mi.position.z + 0.33)
		label.rotation_degrees = Vector3(-60, 0, 0)
		stage.add_child(label)
	var cam := Camera3D.new()
	cam.fov = 40.0
	stage.add_child(cam)
	cam.position = Vector3(0, 2.2, 2.6)
	cam.look_at(stage.global_position + Vector3(0, -0.35, 0.0))
	cam.make_current()
	await _shot("vondsten")
	# Puin: brokjes in een hoopje, in de kleur van elke laag.
	for c in stage.get_children():
		if c is MeshInstance3D and c != floor or c is Label3D:
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for layer in 4:
		for k in 9:
			var ch := MeshInstance3D.new()
			ch.mesh = FindKinds.chunk(k)
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Strata.DEBRIS_COLORS[layer].darkened(rng.randf_range(0.1, 0.35))
			cm.roughness = 1.0
			ch.material_override = cm
			var sz := rng.randf_range(0.06, 0.12)
			ch.scale = Vector3(sz, sz * rng.randf_range(0.6, 1.0), sz)
			ch.position = Vector3((layer - 1.5) * 0.45 + rng.randf_range(-0.1, 0.1), -0.33, rng.randf_range(-0.1, 0.1))
			ch.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
			stage.add_child(ch)
	cam.position = Vector3(0, 0.45, 1.1)
	cam.look_at(stage.global_position + Vector3(0, -0.33, 0))
	await _shot("puin")
	get_tree().quit(0)


func _shot(name: String) -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[gallery] ", path)
