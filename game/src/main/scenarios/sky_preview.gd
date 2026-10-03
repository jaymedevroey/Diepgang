extends Node
## De zes controlebeelden van de hemel (docs/research/hemel.md §6), voor één kleurrichting:
##   1 grond, naar de zon   2 grond, van de zon weg   3 grond, naar de reus
##   4 150 m, schuin omlaag  5 340 m, 40° omlaag       6 340 m, naar de horizon
## tools\godot.cmd --path game --resolution 1280x720 -- --scenario=sky_preview --no-steam --sky=a
## Beelden: logs/sky/<richting>_<n>.png

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var style := str(CmdArgs.value("sky", "a")).to_lower()
	var out := PerfLog.log_dir().path_join("sky")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 4000.0
	main.add_child(cam)
	cam.make_current()
	game.terrain.add_viewer(cam, 110.0)
	var sun: DirectionalLight3D = main.get_node("Atmosphere/Sun")
	var to_sun := sun.global_basis.z # licht schijnt langs −z: de zon zit langs +z
	var giant: Vector3 = PlanetType.params(game.planet_type, style).sky.giant_dir
	var ground := game.terrain.focus_world + Vector3(-20.0, 1.8, 30.0)
	ground.y = game.terrain.surface_height_at(ground.x, ground.z) + 1.8
	var level := func(v: Vector3, pitch_deg: float) -> Vector3:
		var flat := Vector3(v.x, 0.0, v.z).normalized()
		return (flat * cos(deg_to_rad(pitch_deg)) + Vector3.UP * sin(deg_to_rad(pitch_deg))).normalized()
	var shots := [
		[ground, level.call(to_sun, 12.0)],
		[ground, level.call(-to_sun, 12.0)],
		[ground, giant],
		[ground + Vector3(0, 150, 0), level.call(-to_sun, -20.0)],
		[ground + Vector3(0, 340, 0), level.call(Vector3(0.6, 0, -1), -40.0)],
		[ground + Vector3(0, 340, 0), level.call(Vector3(-0.3, 0, -1), 2.0)],
	]
	for i in shots.size():
		var pos: Vector3 = shots[i][0]
		var look: Vector3 = shots[i][1]
		cam.global_position = pos
		cam.look_at(pos + look, Vector3.UP if absf(look.y) < 0.99 else Vector3.FORWARD)
		# Wachten tot het terrein rond de camera gemesht is (anders zie je gaten waar het nog laadt).
		var floor_pos := Vector3(pos.x, game.terrain.surface_height_at(pos.x, pos.z), pos.z)
		var waited := 0
		while waited < 1200 and not game.terrain.is_area_ready(floor_pos, 80.0):
			await get_tree().process_frame
			waited += 1
		for f in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := out.path_join("%s_%d.png" % [style, i + 1])
		cam.get_viewport().get_texture().get_image().save_png(path)
		print("[sky_preview] ", path)
	get_tree().quit(0)

