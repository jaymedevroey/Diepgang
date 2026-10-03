extends Node
## Screenshots van De Ekster: spawn, hangar, terminal, taxatie, museum, baai, van buiten, en de drop.
## tools\godot.cmd --path game --resolution 1280x720 -- --scenario=ship_preview --no-steam
## --only=naam,naam om enkel bepaalde shots te maken (spawn, hangar, terminal, taxatie, museum,
## baai, buiten, onder, planeet, drop).

var main: Node
var _cam: Camera3D


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(p: Player) -> void:
	var game: Game = main.game
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	var only := str(CmdArgs.value("only", "")).split(",", false)
	await _wait(1.5)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.far = 3000.0
	main.add_child(_cam)

	if only.is_empty() or "spawn" in only:
		p.camera.make_current()
		await _shot("ekster_spawn", 0.5)
	if only.is_empty() or "hangar" in only:
		_look(ship, Vector3(9.0, 6.5, 14.0), Vector3(-2.0, 2.0, -8.0))
		await _shot("ekster_hangar")
		_look(ship, Vector3(-9.0, 1.7, 13.0), Vector3(0.0, 2.5, -4.0))
		await _shot("ekster_mol_achter")
	if only.is_empty() or "terminal" in only:
		_look(ship, Vector3(1.5, 1.7, -14.0), Vector3(0.0, 2.8, -19.5))
		await _shot("ekster_terminal")
		_look(ship, Vector3(-6.0, 1.7, -19.0), Vector3(0.0, 4.5, -23.0))
		await _shot("ekster_venster")
	if only.is_empty() or "taxatie" in only:
		_look(ship, Vector3(-2.0, 1.7, 9.0), Vector3(-8.0, 2.0, 12.5))
		await _shot("ekster_taxatie")
	if only.is_empty() or "museum" in only:
		_look(ship, Vector3(12.5, 1.7, 8.5), Vector3(23.0, 1.5, 6.0))
		await _shot("ekster_museum")
	if only.is_empty() or "baai" in only:
		_look(ship, Vector3(5.5, 4.5, -12.5), Vector3(0.0, 0.0, -4.0))
		await _shot("ekster_baai")
	if only.is_empty() or "buiten" in only:
		_look(ship, Vector3(-55.0, 18.0, -60.0), Vector3(6.0, 2.0, -2.0))
		await _shot("ekster_buiten")
		_look(ship, Vector3(70.0, 4.0, 40.0), Vector3(6.0, 2.0, -2.0))
		await _shot("ekster_buiten_achter")
	if only.is_empty() or "onder" in only:
		_look(ship, Vector3(30.0, -40.0, 20.0), Vector3(0.0, 0.0, -2.0))
		await _shot("ekster_onder")
	if only.is_empty() or "planeet" in only:
		# Vanaf de planeet: het schip in de lucht.
		var land := game.terrain.focus_world + Vector3(30.0, 2.0, 40.0)
		_cam.global_position = land
		_cam.look_at(ship.global_position)
		_cam.make_current()
		await _shot("ekster_vanaf_planeet", 1.0)
	if only.is_empty() or "drop" in only:
		# In de Mol stappen en droppen; beelden onderweg en na de landing.
		p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
		await _wait(0.5)
		p.camera.make_current()
		mol.press(Mol.Cmd.DEPART)
		await _wait(0.5)
		await _shot("ekster_drop_aftellen", 0.1)
		while mol.mode == Mol.Mode.DROP_COUNTDOWN and mol.countdown > 1.0:
			await get_tree().process_frame
		_look(ship, Vector3(6.0, 4.5, -14.0), Vector3(0.0, -2.0, -2.0))
		await _shot("ekster_luiken", 0.6)
		while mol.mode != Mol.Mode.DROPPING:
			await get_tree().process_frame
		await _shot("ekster_val_1", 1.6)
		await _shot("ekster_val_2", 3.0)
		while mol.mode == Mol.Mode.DROPPING and mol.thrust < 0.1:
			await get_tree().process_frame
		await _shot("ekster_remmen", 0.8)
		while mol.mode == Mol.Mode.DROPPING:
			await get_tree().process_frame
		await _shot("ekster_geland", 0.5)
		await _shot("ekster_geland_binnen", 2.0)
	get_tree().quit(0)


func _look(ship: Ekster, local_pos: Vector3, local_target: Vector3) -> void:
	_cam.global_position = ship.global_transform * local_pos
	_cam.look_at(ship.global_transform * local_target)
	_cam.make_current()


func _shot(shot_name: String, settle := 0.4) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[ship_preview] ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
