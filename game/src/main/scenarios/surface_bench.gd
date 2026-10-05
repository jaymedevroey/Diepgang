extends Node
## Bouwtijd van het verre landschap per planeet (PlanetSurface, de log zegt hoe lang elke stap duurde).
## Standaard meteen na het maken van de wereld wachten (geen voxelterrein dat intussen streamt: de
## kost van de code zelf); met --contended zoals in het spel (het voxelterrein laadt tegelijk).
## tools\godot.cmd --headless --path game -- --scenario=surface_bench --no-steam [--contended]

var main: Node


func _ready() -> void:
	main.game.player_spawned.connect(func(_p: Player) -> void: _run.call_deferred(), CONNECT_ONE_SHOT)
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print("[surface_bench] GEFAALD: time-out")
		get_tree().quit(1))


func _run() -> void:
	var game: Game = main.game
	var contended := "--contended" in OS.get_cmdline_user_args()
	await get_tree().create_timer(1.0).timeout
	for planet in [PlanetType.Id.ROESTBOL, PlanetType.Id.FOSSIELWERELD, PlanetType.Id.KRISTALMAAN]:
		if "--idle" in OS.get_cmdline_user_args():
			var w0 := Time.get_ticks_msec()
			while _voxel_tasks() > 0 and Time.get_ticks_msec() - w0 < 60000:
				await get_tree().process_frame
			print("[surface_bench] voxelwerk stil na %d ms" % (Time.get_ticks_msec() - w0))
		print("[surface_bench] voxeltaken bij de start: %d" % _voxel_tasks())
		var t0 := Time.get_ticks_msec()
		game._rebuild_world(4242 + int(planet), planet)
		if contended:
			var logged := false
			while not game.world_ready():
				await get_tree().process_frame
				if not logged and _voxel_tasks() == 0:
					logged = true
					print("[surface_bench] oude voxeltaken weg na %d ms" % (Time.get_ticks_msec() - t0))
		else:
			game.surface.finish()
		print("[surface_bench] %s: klaar na %d ms" % [PlanetType.Id.keys()[planet], Time.get_ticks_msec() - t0])
		while not game.world_ready():
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)


func _voxel_tasks() -> int:
	var st: Dictionary = VoxelEngine.get_stats()
	return int(st.thread_pools.general.tasks) + int(st.thread_pools.general.active_threads)
