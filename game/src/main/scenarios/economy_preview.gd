extends Node
## Screenshots van de economie (pakket F1): de contractkaarten met voorwaarden (ook met proeftijd en
## onverkochte buit), de taxatie (een vondst in de poort: de onthulling boven de vondst en op het
## scherm), het draagkaartje met een onbekende waarde, het verkoopluik, de winkel aan elke toonbank
## (ook bevroren met schuld), de rapporten, de handscanner en de boor T2 op de planeet.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=economy_preview --no-steam
## --only=cards,gate,shop,report,scanner (standaard alles). Beelden: logs/f1_<naam>.png

## Plan van de hub: de Mol staat op de oorsprong; taxatiepoort plan (12, 0, 18,3) = hub (5, 0, 9,3).
const GATE_CAM := [Vector3(2.9, 1.25, 10.2), Vector3(5.0, 1.0, 9.3)]

var main: Node
var _cam: Camera3D


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _run(p: Player) -> void:
	var game: Game = main.game
	var c: Company = game.company
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	var only := str(CmdArgs.value("only", "")).split(",", false)
	await _wait(1.5)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 3000.0
	main.add_child(_cam)
	var hub := ship.global_transform

	if only.is_empty() or "cards" in only:
		p.camera.make_current()
		main._terminal.open(c)
		await _shot("f1_cards", 0.8)
		main._terminal.close()

	if only.is_empty() or "gate" in only or "report" in only:
		# Een dienst met buit: de Mol staat in de baai met drie vondsten in het laadruim.
		c.choose(1)
		while not game.world_ready():
			await get_tree().process_frame
		var picks := _pick(game, [FindKinds.Kind.SKULL, FindKinds.Kind.GEODE, FindKinds.Kind.FEMUR])
		var spots := [Vector3(-0.8, -1.2, 2.6), Vector3(0.0, -1.2, 3.0), Vector3(0.8, -1.2, 3.4)]
		for i in picks.size():
			_free_at(picks[i], mol.to_world_mol(spots[i]))
		picks[2].condition = 0.72
		await _wait(0.5)
		c.contract.modifiers = [{"id": Contracts.BONE_BUYER}, {"id": Contracts.TARGET, "kind": FindKinds.Kind.SKULL}]
		c.host_shift_end(mol.cargo_contents(), 14, 140, 0)
		await _shot("f1_report_shift", 0.9)
		main.hud._result.visible = false
		# Het draagkaartje: de waarde is nog onbekend.
		p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.6))
		p.rotation.y = mol.yaw + PI
		p.head.rotation.x = deg_to_rad(-25.0)
		p.camera.make_current()
		await _wait(0.4)
		game.finds.request_grab(picks[0].find_id)
		await _shot("f1_carry_unknown", 0.8)
		game.finds.request_release(picks[0].find_id, picks[0].global_transform, Vector3.ZERO)
		await _wait(0.3)
		# De poort: de schedel in de opening, de onthulling boven hem en op het scherm.
		_look(hub, GATE_CAM[0], GATE_CAM[1])
		var gate := ship.anchor_position("Appraisal_Gate")
		var it: FindItem = picks[0]
		it.global_position = gate + Vector3(0.0, it.rest_height() + 0.05, 0.0)
		it.linear_velocity = Vector3.ZERO
		await _shot("f1_gate_reveal_1", 0.45)
		await _shot("f1_gate_reveal_2", 0.55)
		await _shot("f1_gate_reveal_3", 1.0)
		# Close-up van het scherm boven de poort.
		var info := ship.hub_screens.screen_info(HubScreens.APPRAISAL)
		_cam.global_position = (info.center as Vector3) + (info.normal as Vector3) * 2.2
		_cam.look_at(info.center)
		await _shot("f1_gate_screen", 0.2)
		# De andere twee, en dan verkopen aan het luik.
		for k in [1, 2]:
			var o: FindItem = picks[k]
			o.global_position = gate + Vector3(0.0, o.rest_height() + 0.05, (k - 1.5) * 0.7)
			o.linear_velocity = Vector3.ZERO
		await _wait(2.6)
		p.global_position = ship.anchor_position("Sell_Hatch") + Vector3(0, 0.05, 0)
		await get_tree().physics_frame
		_look(hub, Vector3(2.6, 1.6, 10.8), Vector3(7.4, 1.6, 9.3))
		c.appraisal.request_sell()
		await _shot("f1_sold", 0.5)
		await _shot("f1_sold_settled", 1.8)

	if only.is_empty() or "shop" in only:
		c.cash = 4200
		c.changed.emit()
		p.camera.make_current()
		for counter: String in Upgrades.COUNTERS:
			main._shop.open(c, counter)
			await _shot("f1_shop_%s" % counter.to_lower(), 0.6)
			main._shop.close()
		# Een koop: de stempel PURCHASED.
		p.global_position = ship.anchor_position(Upgrades.TOOL_RACK) + Vector3(0, 0.05, 0)
		await get_tree().physics_frame
		main._shop.open(c, Upgrades.TOOL_RACK)
		c.buy(Upgrades.DRILL_T2, Upgrades.TOOL_RACK)
		await _shot("f1_shop_bought", 0.6)
		main._shop.close()
		# Schuld: bevroren.
		c.cash = -640
		c.changed.emit()
		main._shop.open(c, Upgrades.SUPPLY_DESK)
		await _shot("f1_shop_frozen", 0.6)
		main._shop.close()
		# De toonbank in de hub, door de ogen van de speler (de prompt).
		await _stand(p, hub, (hub.affine_inverse() * ship.anchor_position(Upgrades.TOOL_RACK)) + Vector3(2.2, 1.2, 0.0),
				hub.affine_inverse() * ship.anchor_position(Upgrades.TOOL_RACK) + Vector3(0.0, 1.2, 0.0))
		await _shot("f1_counter_prompt", 0.6)

	if only.is_empty() or "report" in only:
		c.reputation = 0
		c.cash = 300
		c.shift = Tuning.get_i("company", "shifts", 3)
		c.earned = 900
		c.contract = c.options[0]
		c.host_shift_end([], 0, 0, 0)
		p.camera.make_current()
		await _shot("f1_report_quarter_missed", 0.9)
		main.hud._result.visible = false
		main._terminal.open(c)
		await _shot("f1_cards_probation", 0.8)
		main._terminal.close()

	if only.is_empty() or "scanner" in only:
		# Op de planeet, bij de landingsplek: daar zitten vijf vondsten ondiep in de grond.
		c.cash = 9000
		for id in [Upgrades.SCANNER, Upgrades.DRILL_T2, Upgrades.LAMP]:
			if not c.has_upgrade(id):
				c.upgrades.append(id)
		c.changed.emit()
		var spawn := game.terrain.spawn_point()
		var at := spawn + Vector3(3.0, 0.0, -6.0)
		at.y = game.terrain.surface_height_at(at.x, at.z) + 0.1
		p.global_position = at
		p.rotation.y = 0.0
		p.head.rotation.x = deg_to_rad(-20.0)
		p.camera.make_current()
		await _wait(1.0)
		p.select_tool(1)
		var scanner := p.camera.find_child("HandScanner", true, false) as HandScanner
		scanner.pulse()
		await _shot("f1_scanner", 1.2)
		await _shot("f1_scanner_late", 2.5)

	get_tree().quit(0)


func _pick(game: Game, kinds: Array) -> Array[FindItem]:
	var out: Array[FindItem] = []
	var used := {}
	for k in kinds:
		for it: FindItem in game.finds.items:
			if int(it.kind) == int(k) and not it.freed and not used.has(it.find_id):
				used[it.find_id] = true
				out.append(it)
				break
	return out


func _free_at(it: FindItem, at: Vector3) -> void:
	var crust: Crust = it.get_parent().crusts.get(it.find_id)
	if crust:
		crust.queue_free()
		it.get_parent().crusts.erase(it.find_id)
	it.set_freed()
	it.global_position = at
	it.reset_physics_interpolation()
	it.linear_velocity = Vector3.ZERO
	it.freeze = false


func _stand(p: Player, hub: Transform3D, local: Vector3, look: Vector3) -> void:
	p.velocity = Vector3.ZERO
	p.global_position = hub * (local + Vector3(0.0, 0.05, 0.0))
	await get_tree().physics_frame
	var eye := p.camera.global_position
	var to := hub * look - eye
	p.rotation.y = atan2(-to.x, -to.z)
	p.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	p.camera.make_current()


func _look(frame: Transform3D, local_pos: Vector3, local_target: Vector3) -> void:
	_cam.global_position = frame * local_pos
	_cam.look_at(frame * local_target)
	_cam.make_current()


func _shot(shot_name: String, settle := 0.4) -> void:
	await _wait(settle)
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[economy_preview] ", path)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
