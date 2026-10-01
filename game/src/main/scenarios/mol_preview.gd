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
	if only.is_empty() or "cabine" in only or "afdalen" in only:
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
		await _wait(0.3)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.5)
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-4)
		await _shot("mol_cabine", 0.8)
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
		p.chase.activate()
		await _shot("mol_buitenzicht", 3.0)
		p.chase.orbit_yaw = deg_to_rad(35.0)
		p.chase.orbit_pitch = deg_to_rad(-25.0)
		while mol.mode == Mol.Mode.AUTO_DOWN:
			await get_tree().physics_frame
		await _shot("mol_buitenzicht_onder", 2.0)
		p.camera.make_current()
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
