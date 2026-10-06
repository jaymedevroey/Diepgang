extends Node
## Screenshots van de economie (pakket F1): de contractkaarten met voorwaarden (ook met proeftijd en
## onverkochte buit), de taxatie (een vondst in de poort: de onthulling boven de vondst en op het
## scherm), het draagkaartje met een onbekende waarde, het verkoopluik, de winkel aan elke toonbank
## (ook bevroren met schuld), de rapporten, de handscanner en de boor T2 op de planeet.
## Golf 3: de ceremonie (band van de klep door de poort, scan, podium, onthulling in de HUD voor wie
## draagt, het luik dat telt), de toonbanken, de Mol-werf en de Mol voor en na de aankoop, en met
## --only=probe de plekken in de hub en de zichtlijn van de brug.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=economy_preview --no-steam
## --only=cards,gate,shop,report,scanner,probe (standaard alles behalve probe). Beelden: logs/f1_*.png, logs/g3_*.png

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

	if "probe" in only:
		# Golf 3: waar liggen de poort, het luik, de Mol en zijn klep in de hub (voor GateShow en
		# UpgradeShow), en ziet de brug de Mol nog (binnen-17: het podium mag hem niet verbergen)?
		if not mol.ramp_open:
			mol.press(Mol.Cmd.RAMP)
		await _wait(2.5)
		var hubi := hub.affine_inverse()
		for n in ["Appraisal_Gate", "Sell_Hatch", "Mol_Dock", "Mol_Werf", "Niche_Tools", "Niche_Supply", "Vending"]:
			print("[probe] %s hub=%s" % [n, hubi * ship.anchor_position(n)])
		print("[probe] mol body hub=%s yaw=%s" % [hubi * mol.body.global_position, mol.yaw])
		for z in [3.5, 4.4, 5.5, 6.5, 7.5]:
			print("[probe] mol local (0,-1.8,%s) -> hub %s" % [z, hubi * mol.to_world_mol(Vector3(0, -1.8, z))])
		print("[probe] bay %s" % ship.bay)
		_look(hub, Vector3(0.0, 3.0, 13.0), Vector3(4.0, 0.0, 8.0))
		await _shot("g3_probe_ramp", 0.3)
		# Van de brug naar de Mol (binnen-17: het podium mag de Mol niet verbergen).
		for k in 3:
			var from: Vector3 = [Vector3(2.0, 2.6, 15.5), Vector3(4.5, 2.6, 14.5), Vector3(-1.0, 2.6, 15.5)][k]
			_look(hub, from, Vector3(0.0, 3.2, 0.0))
			await _shot("g3_probe_bridge_%d" % k, 0.3)

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
		# Golf 3: het statusscherm in de cabine met de schatting van de buit en de balk van het laadruim.
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
		await _wait(0.3)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.6)
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-34.0)
		await _shot("g3_mol_status", 0.8)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.6)
		# Golf 3: de ceremonie. De drie stukken op de band aan de voet van de klep; de band draagt ze
		# één voor één de poort in (scanstraal, licht, podium), dan verkopen aan het luik.
		var a := c.appraisal
		var reveals := [0]
		a.revealed.connect(func(_i: Dictionary) -> void: reveals[0] += 1)
		var gate_xf := (ship.anchors["Appraisal_Gate"] as Node3D).global_transform
		for k in picks.size():
			var o: FindItem = picks[k]
			o.global_position = gate_xf * Vector3(-3.1 + k * 0.85, o.rest_height() + 0.05, (k - 1) * 0.25)
			o.reset_physics_interpolation()
			o.linear_velocity = Vector3.ZERO
			o.angular_velocity = Vector3.ZERO
		_look(hub, Vector3(0.6, 2.3, 6.0), Vector3(3.4, 0.3, 9.3))
		await _shot("f1_gate_belt", 0.8)
		# Een toeschouwer op de kade: de poort en het podium.
		_look(hub, Vector3(0.9, 1.45, 7.4), Vector3(5.0, 2.3, 9.3))
		await _until(func() -> bool: return a.scanning_id >= 0, 20.0)
		await _shot("f1_gate_scan", 0.45)
		await _until(func() -> bool: return reveals[0] >= 1, 10.0)
		await _shot("f1_gate_stage_rolling", 0.55)
		await _shot("f1_gate_stage", 0.9)
		# Dezelfde plek als de beelden van voor (in de poort): geen zwevende tekst meer.
		_look(hub, GATE_CAM[0], GATE_CAM[1])
		await _until(func() -> bool: return reveals[0] >= 2, 15.0)
		await _shot("f1_gate_reveal_1", 0.55)
		await _shot("f1_gate_reveal_2", 1.0)
		# Close-up van het podium, tijdens de derde onthulling.
		var info := ship.hub_screens.screen_info(HubScreens.APPRAISAL)
		_cam.global_position = (info.center as Vector3) + (info.normal as Vector3) * 2.6 + Vector3(0, -0.6, 0)
		_cam.look_at(info.center)
		await _until(func() -> bool: return reveals[0] >= 3, 15.0)
		await _shot("f1_gate_screen", 1.4)
		await _shot("f1_gate_reveal_3", 1.5)
		# Wie zelf door de poort draagt, krijgt de onthulling onder het vizier.
		var extra := _pick(game, [FindKinds.Kind.CLAW])
		if not extra.is_empty():
			var cl: FindItem = extra[0]
			_free_at(cl, gate_xf * Vector3(-2.0, cl.rest_height() + 0.05, 1.15))
			c.haul.ids.append(cl.find_id)
			p.global_position = gate_xf * Vector3(-2.6, 0.05, 0.4)
			p.rotation.y = -PI / 2.0
			p.head.rotation.x = deg_to_rad(-8.0)
			p.camera.make_current()
			await _wait(0.4)
			game.finds.request_grab(cl.find_id)
			await _wait(0.4)
			for i in 30:
				p.global_position = gate_xf * Vector3(-2.6 + i * 0.08, 0.05, 0.3)
				await get_tree().physics_frame
			await _until(func() -> bool: return reveals[0] >= 4, 10.0)
			await _shot("f1_gate_carrier", 1.1)
			game.finds.request_release(cl.find_id, cl.global_transform, Vector3.ZERO)
		await _until(func() -> bool: return a.unappraised_items().is_empty(), 20.0)
		await _wait(1.5)
		# Verkopen: vlak onder de quota, zodat het scherm aan het luik QUOTA MET stempelt.
		var ready_v := 0
		for o: FindItem in a.appraised_items():
			ready_v += a.value_of(o)
		c.earned = maxi(c.earned, c.quota() - ready_v + 120)
		c.changed.emit()
		await _stand(p, hub, hub.affine_inverse() * ship.anchor_position("Sell_Hatch") + Vector3(-0.35, 0.0, 0.25),
				hub.affine_inverse() * (gate_xf * Vector3(3.05, 1.25, -0.25)))
		await _wait(0.5)
		a.request_sell()
		await _shot("f1_sold", 0.55)
		await _shot("f1_sold_count", 0.6)
		await _shot("f1_sold_settled", 2.4)
		_look(hub, Vector3(2.6, 1.6, 10.8), Vector3(7.4, 1.6, 9.3))
		await _shot("f1_sold_quay", 0.4)

	if only.is_empty() or "shop" in only:
		c.cash = 4200
		c.changed.emit()
		# Golf 3: de toonbanken in de hub, voor de aankoop (de boor T2 op het rek, lege balie, de bokken).
		await _world_shots("voor")
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
		# De rest kopen (zoals aan elke toonbank), dan dezelfde plekken: het gevolg in de wereld.
		c.cash = 30000
		for id: String in Upgrades.ORDER:
			if not c.has_upgrade(id):
				c.upgrades.append(id)
		c.changed.emit()
		await _wait(1.4)
		await _world_shots("na")
		# De boor T2 in de hand (andere kleur, carbidepunt).
		p.global_position = ship.anchor_position(Upgrades.TOOL_RACK) + Vector3(0, 0.05, 0)
		await get_tree().physics_frame
		p.rotation.y = 0.0
		p.head.rotation.x = deg_to_rad(-12.0)
		p.camera.make_current()
		p.select_tool(1)
		await _shot("g3_drill_t2_hand", 0.8)
		p.select_tool(0)
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


## Golf 3: het gereedschapsrek, de uitgiftebalie, de Mol-werf en de Mol, telkens op dezelfde plek.
func _world_shots(tag: String) -> void:
	var hub: Transform3D = main.game.ship.global_transform
	var mol: Mol = main.game.mol
	_look(hub, Vector3(-4.5, 2.7, 24.0), Vector3(-6.8, 2.45, 24.0))
	await _shot("g3_rack_%s" % tag, 0.5)
	_look(hub, Vector3(-3.3, 2.75, 28.0), Vector3(-4.8, 2.15, 28.0))
	await _shot("g3_supply_%s" % tag, 0.3)
	_look(hub, Vector3(12.7, 3.3, 0.5), Vector3(9.9, 1.4, 0.5))
	await _shot("g3_yard_%s" % tag, 0.3)
	_look(hub, Vector3(11.8, 2.4, -1.4), Vector3(9.95, 1.7, -2.6))
	await _shot("g3_yard_kop_%s" % tag, 0.2)
	_look(hub, Vector3(7.5, 3.2, 8.0), Vector3(0.0, 1.5, -1.0))
	await _shot("g3_mol_%s" % tag, 0.3)
	# De boorkop van dichtbij (vooraan, van de kade) en de flank met de bagagebak.
	_look(hub, Vector3(5.5, 3.0, -8.5), Vector3(0.0, 2.6, -5.0))
	await _shot("g3_molkop_%s" % tag, 0.3)
	_look(hub, Vector3(6.2, 2.2, 5.6), Vector3(3.1, 1.8, 2.6))
	await _shot("g3_molflank_%s" % tag, 0.3)


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


## Wachten tot `cond` waar is (hooguit `limit` s): de ceremonie volgt de band, niet de klok.
func _until(cond: Callable, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < limit * 1000.0:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
