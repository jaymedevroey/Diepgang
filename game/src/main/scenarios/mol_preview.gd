extends Node
## Screenshots van de Mol: buiten, achter (klep open), binnen, cabine, afdalen, onderaan.
## tools\godot.cmd --path game --resolution 1280x720 -- --scenario=mol_preview --no-steam
## --only=naam,naam om enkel bepaalde shots te maken.

var main: Node
var _cam: Camera3D


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	var only := str(CmdArgs.value("only", "")).split(",", false)
	await _wait(1.2)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	main.add_child(_cam)
	var lamp := SpotLight3D.new() # zoals de helmlamp van een speler die kijkt
	lamp.light_color = Color(1.0, 0.8, 0.55)
	lamp.light_energy = 4.0
	lamp.spot_range = 30.0
	lamp.spot_angle = 40.0
	lamp.shadow_enabled = true
	_cam.add_child(lamp)
	lamp.position = Vector3(0.3, 0.3, 0)

	if only.is_empty() or "buiten" in only:
		_look(mol, Vector3(-9.5, 1.2, -12.0), Vector3(0, -0.5, -2.5))
		await _shot("mol_buiten")
	if only.is_empty() or "zij" in only:
		_look(mol, Vector3(-13.0, 2.5, 1.0), Vector3(0, -0.3, 0.0))
		await _shot("mol_zij")
	if only.is_empty() or "rups" in only:
		_look(mol, Vector3(-5.8, -1.6, -1.5), Vector3(-1.4, -2.3, 0.6))
		await _shot("mol_rups")
	if only.is_empty() or "achter" in only:
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-8)
		await _shot("mol_achter", 0.6)
	if only.is_empty() or "binnen" in only:
		p.set_physics_process(false)
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0.6, -1.5, 3.4)))
		p.head.rotation.x = deg_to_rad(-6)
		p.camera.make_current()
		await _shot("mol_binnen", 0.6)
		p.set_physics_process(true)
	if "sonar" in only:
		# Sonar: vanuit de stoel, naar de kast gekeken, van dichtbij, en na het afdalen.
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
		await _wait(0.3)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.5)
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-4)
		await _shot("sonar_cabine", 3.0)
		p._look_yaw = deg_to_rad(-40)
		p.head.rotation.x = deg_to_rad(-2)
		await _shot("sonar_kijk", 0.6)
		_look(mol, Vector3(0.95, 0.42, -2.45), Vector3(1.5, 0.37, -3.28))
		await _shot("sonar_dichtbij", 0.3)
		# PING: de ring halverwege, en het beeld erna (scherp tot 24 m, de knop laadt op).
		mol.press(Mol.Cmd.PING)
		await _shot("sonar_ping_ring", 0.28)
		await _shot("sonar_ping_na", 0.9)
		mol.press(Mol.Cmd.RAMP)
		await _wait(0.5)
		Input.action_press("move_forward")
		await _wait(2.5)
		_look(mol, Vector3(0.95, 0.42, -2.45), Vector3(1.5, 0.37, -3.28))
		Tuning.set_value("mol", "sonar_warn", 40.0) # enkel om de waarschuwing in beeld te krijgen
		await _shot("sonar_rijden", 0.3)
		Tuning.set_value("mol", "sonar_warn", 8.0)
		Input.action_release("move_forward")
		await _wait(2.0)
		p.camera.make_current()
		p._look_yaw = 0.0
		mol.press(Mol.Cmd.AUTO, float(CmdArgs.value("sonar-depth", 30.0)))
		while mol.mode == Mol.Mode.AUTO_DOWN:
			await get_tree().physics_frame
		p._look_yaw = deg_to_rad(-40)
		p.head.rotation.x = deg_to_rad(-2)
		await _shot("sonar_diep", 3.0)
		_look(mol, Vector3(0.95, 0.42, -2.45), Vector3(1.5, 0.37, -3.28))
		await _shot("sonar_diep_dichtbij", 0.1)
		p.camera.make_current()
		p._look_yaw = 0.0
		p.chase.activate()
		await _shot("sonar_buitenzicht", 2.0)
	if only.is_empty() or "cabine" in only or "afdalen" in only:
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
		await _wait(0.3)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.5)
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-4)
		await _shot("mol_cabine", 0.8)
		p.head.rotation.x = deg_to_rad(-38)
		await _shot("mol_dashboard", 0.3)
		p.head.rotation.x = deg_to_rad(-4)
		mol.press(Mol.Cmd.AUTO, 40.0)
		var side := mol.to_world_mol(Vector3(-15.0, 2.0, -14.0))
		_cam.global_position = side
		_cam.look_at(mol.to_world_mol(Vector3(0, -1.0, -8.0)))
		_cam.make_current()
		await _shot("mol_boren", 1.6)
		p.camera.make_current()
		await _shot("mol_scherm", 5.0)
		p._look_yaw = deg_to_rad(80)
		p.head.rotation.x = deg_to_rad(-5)
		await _shot("mol_patrijspoort", 0.3)
		p._look_yaw = 0.0
		# Drie opeenvolgende frames van de vloer en de romp tijdens het rijden (flikkeren?).
		_cam.make_current()
		for k in 3:
			_look(mol, Vector3(-1.2, 0.3, 3.4), Vector3(0.6, -1.5, -0.5))
			await _shot("mol_frame_%d" % k, 0.0)
		p.chase.activate()
		await _shot("mol_buitenzicht", 3.0)
		p.chase.orbit_yaw = deg_to_rad(35.0)
		p.chase.orbit_pitch = deg_to_rad(-25.0)
		while mol.mode == Mol.Mode.AUTO_DOWN:
			await get_tree().physics_frame
		await _shot("mol_buitenzicht_onder", 2.0)
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-4)
		await _shot("mol_scherm_onder", 1.0)
		await _wait(0.5)
		mol.leave_seat()
		await _wait(0.4)
		_look(mol, Vector3(2.0, 0.4, 14.5), Vector3(0, -1.0, 3.0))
		await _shot("mol_onder", 0.4)
	get_tree().quit(0)


func _look(mol: Mol, local_pos: Vector3, local_target: Vector3) -> void:
	_cam.global_position = mol.to_world_mol(local_pos)
	_cam.look_at(mol.to_world_mol(local_target))
	_cam.make_current()


func _shot(name: String, settle := 0.4) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[preview] ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
