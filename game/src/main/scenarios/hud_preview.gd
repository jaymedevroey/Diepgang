extends Node
## Screenshots van de HUD in alle toestanden (logs/hud_*.png):
##   korst      mikken op een korst (ring met slagen, uitleg)
##   vondst     mikken op een vrije vondst (E: oppakken, waarde)
##   dragen     een vondst dragen (kaartje linksonder)
##   ver        ver van de Mol (kompas met de richting en afstand)
##   piloot     in de stoel (besturing onderaan)
##   vertrek    de Mol telt af (banner), met meldingen
##   resultaat  eindoverzicht van een dienst
##   pauze      pauzemenu met uitnodigen
##   magma      in een grot: magma dichtbij, onrust hoog, een zone aan het plafond, en een beving
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=hud_preview --no-steam [--only=korst,dragen]

var main: Node


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(p: Player) -> void:
	var finds: FindField = main.game.finds
	var mol: Mol = main.game.mol
	var t: TerrainAPI = main.terrain
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var want := func(n: String) -> bool: return only.is_empty() or n in only
	await _wait(2.0)
	p.set_physics_process(false)
	if only.size() == 1 and only[0] == "magma":
		await _magma(p, t)
		get_tree().quit(0)
		return

	# Een vondst met korst die nog in de rots zit: open ruimte ervoor graven en ernaar kijken.
	var it: FindItem = finds.items[1]
	var here := it.global_position
	t.debug_dig(here + Vector3(0, 0.6, 1.6), 1.8)
	await _wait(1.0)
	if want.call("korst"):
		_look_at(p, here + Vector3(0, 0.25, 1.7), here)
		finds.hit_crust(it.find_id, Strata.Tool.HOUWEEL, here) # één slag: de ring toont wat er nog rest
		await _shot("hud_korst", 0.8)
	for i in 20:
		if it.freed:
			break
		finds.hit_crust(it.find_id, Strata.Tool.HOUWEEL, here)
		await _wait(0.3)
	await _wait(1.2)
	if want.call("vondst"):
		_look_at(p, it.global_position + Vector3(0, 0.5, 1.6), it.global_position)
		await _shot("hud_vondst", 0.5)
	if want.call("dragen"):
		_look_at(p, it.global_position + Vector3(0, 0.5, 1.6), it.global_position)
		await _wait(0.2)
		finds.request_grab(it.find_id)
		await _shot("hud_dragen", 0.8)
		p.carry.drop(false)
		await _wait(0.5)
	if want.call("ver"):
		var far := mol.to_world_mol(Vector3(-30, 0, 18))
		far.y = t.surface_height_at(far.x, far.z) + 1.0
		p.global_position = far
		p.rotation.y = deg_to_rad(40)
		p.head.rotation.x = deg_to_rad(-5)
		await _shot("hud_ver", 1.2)
	if want.call("piloot") or want.call("vertrek") or want.call("resultaat"):
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
		p.set_physics_process(true)
		await _wait(0.4)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.6)
		if want.call("piloot"):
			await _shot("hud_piloot", 0.8)
		if want.call("vertrek"):
			mol.leave_seat()
			await _wait(0.4)
			p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw + PI), mol.to_world_mol(Vector3(0.6, -1.4, 1.5)))
			main.hud.toast("Autopilot: descending to −40 m", "mol")
			main.hud.toast("Hard layer: autopilot stops at 61 m", "warn")
			mol._path = [mol.body.global_position + mol.body.global_basis.z * 8.0, mol.body.global_position] # alsof hij gereden heeft
			mol.press(Mol.Cmd.DEPART)
			await _shot("hud_vertrek", 2.5)
		if want.call("resultaat"):
			main.hud.show_result(3, 245, 1)
			await _shot("hud_resultaat", 0.8)
	if want.call("pauze"):
		main._pause.open()
		main._pause._toggle_invite()
		await _shot("hud_pauze", 0.6)
		main._pause.close()
	get_tree().quit(0)


## Grot 20 m diep, het magma 22 m onder de speler, onrust 85%, een zone aan het plafond; dan een beving.
func _magma(p: Player, t: TerrainAPI) -> void:
	var game: Game = main.game
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x + 20.0, sc.z + 20.0)
	var c := Vector3(sc.x + 20.0, top - 20.0, sc.z + 20.0)
	for k in 10:
		t.debug_dig(c + Vector3(randf_range(-5, 5), randf_range(-1.5, 2.0), randf_range(-5, 5)), randf_range(3.5, 5.0))
	t.debug_dig(c + Vector3(0, -3.0, 0), 4.5)
	var zone := Vector3(c.x + 3.0, c.y + 4.0, c.z - 2.0)
	game.unrest.zones = [Vector4(zone.x, zone.y, zone.z, 4.0)] as Array[Vector4]
	game.magma.debug_depth = 20.0 + 1.2 + 22.0
	game.unrest.value = 85.0
	_look_at(p, c + Vector3(-4.0, -1.5, 4.0), zone)
	t.add_viewer(p, 60.0, 30.0)
	while not t.is_area_ready(c, 20.0):
		await _wait(0.2)
	await _shot("hud_magma", 1.5)
	Tuning.set_value("unrest", "min_gap_s", 0.0)
	game.unrest.value = 100.0
	await _shot("hud_beving_komt", 1.0)
	await _shot("hud_beving", 4.4)
	await _shot("hud_beving_rotsen", 1.6)


func _look_at(p: Player, from: Vector3, target: Vector3) -> void:
	p.global_position = from - Vector3(0, 1.2, 0) # ogen op 1,2 m boven de voeten
	var dir := target - from
	p.rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	p.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _shot(name: String, settle := 0.4) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[hud_preview] ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout
