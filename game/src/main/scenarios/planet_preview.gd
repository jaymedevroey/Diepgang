extends Node
## Screenshots van de vorm van de planeet (generator): van bovenaf met een tijdelijke zon, schuin
## over het oppervlak, en in de grootste grot met een lamp. logs/planeet_*.png
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=planet_preview --no-steam [--seed=N]

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var t: TerrainAPI = main.terrain
	var size := t.world_size()
	var holder := Node3D.new()
	main.add_child(holder)
	var cam := Camera3D.new()
	cam.far = 900.0
	cam.fov = 60.0
	holder.add_child(cam)
	t.add_viewer(cam, 160.0)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.4
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 400.0
	holder.add_child(sun)
	var env: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var fog_was := env.fog_enabled
	env.fog_enabled = false

	var c := Vector3(size.x * 0.5, 0, size.z * 0.5)
	# 1. Van bovenaf.
	await _shot(cam, c + Vector3(-60, t.surface_height_at(c.x, c.z) + 150, 120), c + Vector3(0, t.surface_height_at(c.x, c.z), 0), "planeet_boven")
	# 2. Schuin over het oppervlak naar de rand.
	var p := c + Vector3(-30, 0, 40)
	p.y = t.surface_height_at(p.x, p.z) + 6.0
	await _shot(cam, p, p + Vector3(-80, -8, 60), "planeet_oppervlak")
	# 3. In de grootste grot, met een lamp.
	var gen: PlanetGenerator = t._generator
	var best := Vector4.ZERO
	for cav in gen._caverns:
		if cav.w > best.w:
			best = cav
	var cave := Vector3(best.x, best.y, best.z) * TerrainAPI.VOXEL_SIZE
	sun.visible = false
	var lamp := OmniLight3D.new()
	lamp.omni_range = 40.0
	lamp.light_energy = 3.0
	holder.add_child(lamp)
	lamp.global_position = cave + Vector3(0, 2, 0)
	await _shot(cam, cave + Vector3(-best.w * 0.25, 1.0, best.w * 0.2), cave + Vector3(best.w * 0.3, -2.0, -best.w * 0.2), "planeet_grot")
	env.fog_enabled = fog_was
	get_tree().quit(0)


func _shot(cam: Camera3D, from: Vector3, at: Vector3, name: String) -> void:
	cam.global_position = from
	cam.look_at(at)
	cam.make_current()
	var t: TerrainAPI = main.terrain
	var t0 := Time.get_ticks_msec()
	while not t.is_area_ready(at, 12.0) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	await get_tree().create_timer(float(CmdArgs.value("settle", 6.0))).timeout
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[planet_preview] ", path)
