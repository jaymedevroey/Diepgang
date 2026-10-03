extends Node
## Screenshots van De Ekster: de hub langs de route (laadrek, werkdek, gang, brug, terminal, kade,
## hangar, taxatie, raam, baai), het buitenschip, en de drop.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=ship_preview --no-steam
## --only=naam,naam om enkel bepaalde shots te maken (spawn, laadrek, werkdek, gang, brug,
## terminal, kade, hangar, taxatie, venster, baai, buiten, onder, planeet, drop, firma).
## Beelden: logs/ekster_<naam>.png

## Vaste camera's in de hub (lokaal t.o.v. de hub: de Mol staat op de oorsprong, voren is −z):
## naam, van, naar. Op ooghoogte van een robot (1,2 m boven de vloer).
const HUB_SHOTS := [
	["laadrek", Vector3(3.0, 1.8, 33.6), Vector3(3.0, 2.2, 21.0)],
	["werkdek", Vector3(5.5, 2.4, 29.5), Vector3(-5.5, 2.2, 24.5)],
	["gang", Vector3(3.0, 2.4, 23.0), Vector3(2.0, 2.8, 1.0)],
	["brug", Vector3(9.0, 2.4, 13.0), Vector3(-4.0, 2.6, -6.5)],
	["kade", Vector3(0.75, 1.2, 9.5), Vector3(0.0, 1.6, -2.0)],
	["hangar", Vector3(11.0, 6.5, 10.5), Vector3(-2.0, 1.0, -5.0)],
	["taxatie", Vector3(0.5, 1.4, 10.5), Vector3(5.0, 2.4, 9.3)],
	["venster", Vector3(6.5, 0.6, -6.5), Vector3(4.0, 2.5, -16.0)],
	["baai", Vector3(11.5, 3.8, -4.5), Vector3(0.0, -0.5, 1.0)],
]

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
	_cam.fov = 75.0
	_cam.near = 0.05
	_cam.far = 3000.0
	main.add_child(_cam)

	if "firma" in only:
		# De opdrachtterminal en het incidentrapport.
		p.camera.make_current()
		main._terminal.open(game.company)
		await _shot("firma_terminal", 0.6)
		main._terminal.close()
		main.hud.show_report({"shift_total": 4, "quarter": 2, "shift": 1, "contract": "CONCESSIE 41", "risk": 2,
				"factor": 1.35, "sold": [["Schedel", 315, 90], ["Dijbeen", 162, 90], ["Geode", 130, 50], ["Oude fles", 40, 100]],
				"finds_value": 647, "ore_units": 18, "ore_value": 112, "bonus": 266, "left_behind": 1, "melted": 1, "costs": 240,
				"damage": 175, "quakes": 3, "net": 785, "earned": 785, "quota": 1000, "cash": 1240, "reputation": 1})
		await _shot("firma_rapport", 0.8)
		main.hud.show_report({"shift_total": 6, "quarter": 2, "shift": 3, "contract": "CONCESSIE 7", "risk": 0,
				"factor": 1.0, "sold": [["Wervel", 60, 100]], "finds_value": 60, "ore_units": 0, "ore_value": 0, "bonus": 0,
				"left_behind": 0, "melted": 0, "costs": 0, "damage": 0, "quakes": 1, "net": 60, "earned": 845, "quota": 1000,
				"quarter_result": "gemist", "fine": 78, "cash": 1222, "reputation": 0})
		await _shot("firma_rapport_gemist", 0.8)
	if only.is_empty() or "spawn" in only:
		p.camera.make_current()
		await _shot("ekster_spawn", 0.5)
	var hub := ship.global_transform
	for s: Array in HUB_SHOTS:
		if only.is_empty() or s[0] in only:
			_look(hub, s[1], s[2])
			await _shot("ekster_" + s[0])
	if only.is_empty() or "terminal" in only:
		# Zoals je aan de opdrachttafel staat, kijkend naar het scherm.
		var use := hub.affine_inverse() * ship.anchor_position("Terminal_Use")
		var screen := hub.affine_inverse() * ship.terminal_screen.global_position
		_look(hub, use + Vector3(0.0, 1.2, 0.3), Vector3(use.x, screen.y - 0.35, screen.z))
		await _shot("ekster_terminal")
	# Het buitenschip (een apart model boven de landingsplek), t.o.v. zijn baai.
	var outside := Transform3D(Basis(), game.exterior.dock_position())
	if only.is_empty() or "buiten" in only:
		_look(outside, Vector3(-55.0, 18.0, -60.0), Vector3(6.0, 2.0, -2.0))
		await _shot("ekster_buiten")
		_look(outside, Vector3(70.0, 4.0, 40.0), Vector3(6.0, 2.0, -2.0))
		await _shot("ekster_buiten_achter")
	if only.is_empty() or "onder" in only:
		_look(outside, Vector3(30.0, -40.0, 20.0), Vector3(0.0, 0.0, -2.0))
		await _shot("ekster_onder")
	if only.is_empty() or "planeet" in only:
		# Vanaf de planeet: het schip in de lucht.
		var land := game.terrain.focus_world + Vector3(30.0, 2.0, 40.0)
		_cam.global_position = land
		_cam.look_at(game.exterior.dock_position())
		_cam.make_current()
		await _shot("ekster_vanaf_planeet", 1.0)
	if only.is_empty() or "drop" in only:
		# In de Mol stappen en droppen; beelden onderweg en na de landing.
		p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
		await _wait(0.5)
		p.camera.make_current()
		game.company.contract = game.company.options[0]
		mol.press(Mol.Cmd.DEPART)
		await _wait(0.5)
		await _shot("ekster_drop_aftellen", 0.1)
		while mol.mode == Mol.Mode.DROP_COUNTDOWN and mol.countdown > 1.0:
			await get_tree().process_frame
		_look(hub, Vector3(11.5, 3.8, -4.5), Vector3(0.0, -1.5, 1.0))
		await _shot("ekster_luiken", 0.6)
		while mol.mode != Mol.Mode.DROPPING:
			await get_tree().process_frame
		await _shot("ekster_val_0", 0.3)
		await _shot("ekster_val_1", 1.3)
		await _shot("ekster_val_2", 2.5)
		while mol.mode == Mol.Mode.DROPPING and mol.thrust < 0.1:
			await get_tree().process_frame
		await _shot("ekster_remmen", 0.8)
		while mol.mode == Mol.Mode.DROPPING:
			await get_tree().process_frame
		await _shot("ekster_geland", 0.5)
		await _shot("ekster_geland_binnen", 2.0)
	get_tree().quit(0)


## Camera op `local_pos`, kijkend naar `local_target`, beide t.o.v. `frame`.
func _look(frame: Transform3D, local_pos: Vector3, local_target: Vector3) -> void:
	_cam.global_position = frame * local_pos
	_cam.look_at(frame * local_target)
	_cam.make_current()


func _shot(shot_name: String, settle := 0.4) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[ship_preview] ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
