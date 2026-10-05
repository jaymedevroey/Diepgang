extends Node
## Test van de dreiging (pakket F2, GDD §6): de Graafworm, lichtbakens, gas, neergaan en redden,
## instortingen met de diepte, het magma als klok in de HUD en de climax. Solo, headless.
## - Worm: slaapt eerst; hoort een boor en zwemt erheen; valt enkel uit in een open ruimte; slokt
##   losse buit op en dumpt hem ver weg in een grot; gooit wie hij raakt omver; een baken houdt hem
##   tegen; hij staat als grote stip op de sonar; de Mol die vertrekt lokt hem, en hij ramt de Mol
##   (de lading lijdt), maar niet met een baken in de Mol.
## - Gas: een boorhap in een open bel ontsteekt hem (het houweel niet, een net opengebroken bel ook
##   niet meteen); de ontploffing graaft een krater, raakt de speler en maakt lawaai.
## - Neergaan: een val doet pijn; solo neer → strompelen → in de Mol gerepareerd. Een ploegmaat neer →
##   dragen (traag) → in de Mol gerepareerd; te lang neer → kapot (spookdrone, telt als achtergebleven).
## - Instortingen: dieper meer zones, een grotere kans, en vanzelf een instorting bij een diepe zone
##   (niet bij een ondiepe); het puin houdt je tegen en je bikt het weg.
## tools\godot.cmd --headless --path game -- --scenario=threat_test --no-steam

const TAG := "[threat_test]"

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var game: Game
var t: TerrainAPI
var p: Player


func _ready() -> void:
	main.game.player_spawned.connect(func(pl: Player) -> void:
		if pl.is_local:
			_run.call_deferred(pl))
	get_tree().create_timer(300.0).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out")
		for f in _failures:
			print(TAG, " MISLUKT: ", f)
		get_tree().quit(1))


func _run(pl: Player) -> void:
	p = pl
	game = main.game
	t = main.terrain
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.0)
	var worm: Worm = game.worm
	var rescue: Rescue = game.rescue
	var magma: Magma = game.magma

	# 0. Een grot onder de grond om in te werken (30 m diep, 40 m van de landingsplek).
	var sc := t.shaft_center_world()
	var cave := Vector3(sc.x, t.surface_height_at(sc.x, sc.z - 40.0) - 30.0, sc.z - 40.0)
	p.set_physics_process(false)
	p.global_position = cave + Vector3.UP * 2.0
	await _until(func() -> bool: return t.is_area_ready(cave, 10.0), 20.0)
	t.debug_dig(cave, 6.0)
	await _wait(1.2)
	var floor_hit := t.raycast(cave, cave + Vector3.DOWN * 10.0)
	var ground: Vector3 = floor_hit.position if not floor_hit.is_empty() else cave + Vector3.DOWN * 5.8
	_expect(not floor_hit.is_empty(), "testgrot gegraven (vloer op %.1f m onder het midden)" % (cave.y - ground.y))
	p.global_position = ground + Vector3(2.5, 0.1, 0.0)
	p.reset_physics_interpolation()
	p.set_physics_process(true)
	await _wait(0.5)

	# 1. Het magma als klok: onder de grond altijd in de HUD, met wanneer het hier is (ontwerp-1).
	main.hud.update(p, game, t)
	var hz: HudHazard = main.hud.hazard
	_expect(hz.always_magma and hz.magma_m > 200.0 and hz._magma_shown(), "het magma staat in de HUD, ook op %d m (ontwerp-1)" % int(hz.magma_m))
	_expect(hz.magma_eta > 60.0 and hz.magma_eta < 3600.0, "met de tijd tot het hier is (%d s)" % int(hz.magma_eta))

	# 2. De worm slaapt de eerste minuten, dan wordt hij wakker.
	_expect(worm.mode == Worm.Mode.SLEEP, "de worm slaapt bij de start")
	magma.elapsed = Tuning.get_f("worm", "wake_s", 150.0) + 1.0
	await _wait(0.3)
	_expect(worm.mode != Worm.Mode.SLEEP, "na wake_s wordt hij wakker (%s)" % Worm.Mode.keys()[worm.mode])

	# 3. Lawaai lokt hem: een boor in de grot, de worm 45 m verderop zwemt erheen.
	worm.pos = cave + Vector3(45.0, -8.0, 0.0)
	worm.vel = Vector3.ZERO
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm._cool = 999.0 # nog niet uitvallen
	var start_d := worm.pos.distance_to(cave)
	for i in 16:
		worm.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": ground + Vector3(0, 0.5, 0)})
		await _wait(0.12)
	await _wait(3.0)
	_expect(worm.mode == Worm.Mode.HUNT, "de boor lokt hem: hij jaagt (%s)" % Worm.Mode.keys()[worm.mode])
	_expect(worm.pos.distance_to(cave) < start_d - 8.0, "hij zwemt naar het lawaai (%.0f → %.0f m)" % [start_d, worm.pos.distance_to(cave)])
	# Het houweel is stil.
	worm._noises.clear()
	worm.host_player_op(1, {"op": TerrainAPI.Op.CHIP, "tool": Strata.Tool.HOUWEEL, "h": ground})
	_expect(worm._noises.is_empty(), "het houweel lokt hem niet")

	# 4. Op de sonar van de Mol: een grote stip (ook als hij verder is dan een PING reikt).
	var mol: Mol = game.mol
	worm.pos = mol.body.global_position + Vector3(30.0, -10.0, 0.0)
	await _wait(0.2)
	var echo := worm.sonar_echo(mol.body.global_position, 0.0, false)
	_expect(echo.get("on", false) and float(echo.strength) > 0.1, "de worm staat op de sonar (%.0f m)" % float(echo.get("dist", -1.0)))
	worm.pos = mol.body.global_position + Vector3(90.0, -10.0, 0.0)
	_expect(not worm.sonar_echo(mol.body.global_position, 0.0, false).get("on", false), "buiten sonar_m niet")

	# 5. Uitvallen enkel in een open ruimte.
	worm.pos = ground + Vector3(-12.0, -6.0, 0.0)
	worm._cool = 0.0
	var solid := ground + Vector3(0.0, -12.0, 0.0)
	_expect(not worm._try_lunge(solid), "niet in de rots (geen open ruimte)")
	# Losse buit en de speler in de grot: hij valt uit, slokt de buit op en gooit de speler omver.
	var it: FindItem = _a_find()
	game.finds._free(it.find_id)
	await _wait(0.6)
	it.global_position = ground + Vector3(0.0, 0.4, 0.0)
	it.linear_velocity = Vector3.ZERO
	it.reset_physics_interpolation()
	p.global_position = ground + Vector3(0.6, 0.1, 0.6)
	await _wait(0.4)
	var started := [false]
	var ate := [-1]
	worm.lunge_started.connect(func(_a: Vector3) -> void: started[0] = true, CONNECT_ONE_SHOT)
	worm.swallowed.connect(func(id: int) -> void: ate[0] = id, CONNECT_ONE_SHOT)
	var aim := ground + Vector3(0.0, 0.3, 0.0)
	_expect(worm._try_lunge(aim), "in de grot valt hij uit")
	_expect(started[0] and worm.mode == Worm.Mode.LUNGE, "eerst de waarschuwing, dan de boog (op elk peer)")
	var health0 := rescue.health_of(p.peer_id)
	var knocked := false
	var t0 := _gt()
	while _gt() - t0 < 5.0:
		await get_tree().physics_frame
		knocked = knocked or rescue.life_of(p.peer_id) == Rescue.Life.KNOCKED
		# De speler blijft staan waar de boog over komt (anders duikt hij weg).
		if rescue.life_of(p.peer_id) == Rescue.Life.OK and not knocked:
			p.global_position = ground + Vector3(0.6, 0.1, 0.6)
	_expect(knocked and rescue.health_of(p.peer_id) < health0, "wie hij raakt, gaat omver als ragdoll (levens %d%%)" % int(rescue.health_of(p.peer_id) * 100))
	_expect(ate[0] == it.find_id and not it.visible and it.carriers.has(Worm.BELLY), "losse buit is opgeslokt")
	_expect(worm.mode == Worm.Mode.CARRY, "hij sleept de buit weg (%s)" % Worm.Mode.keys()[worm.mode])
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.OK and p.ragdoll == null, "na knock_s staat de robot weer op")
	# Dumpen in een grot, ver weg.
	var spat := [false]
	worm.spat.connect(func(_ids: PackedInt32Array) -> void: spat[0] = true, CONNECT_ONE_SHOT)
	worm.pos = worm._lair
	await _wait(0.5)
	_expect(spat[0] and it.visible and it.carriers.is_empty(), "de buit ligt weer ergens (gedumpt)")
	_expect(it.global_position.distance_to(aim) > Tuning.get_f("worm", "lair_min_m", 50.0) * 0.7, "ver weg: %.0f m" % it.global_position.distance_to(aim))

	# 6. Een lichtbaken houdt hem tegen.
	var left := game.beacons.left
	p.global_position = ground + Vector3(2.0, 0.1, 0.0)
	game.beacons._host_throw(1, ground + Vector3(1.0, 1.0, 0.0), Vector3.ZERO)
	await _wait(0.6)
	_expect(game.beacons.left == left - 1 and game.beacons.count_active() >= 1, "een baken gegooid (%d over)" % game.beacons.left)
	worm.mode = Worm.Mode.HUNT
	worm._cool = 0.0
	_expect(not worm._try_lunge(aim) and worm.mode == Worm.Mode.REPELLED, "bij een baken valt hij niet uit: hij zwemt weg")

	# 7. Gas: een bel in een tweede grot.
	var cave2 := cave + Vector3(0.0, 0.0, 22.0)
	t.debug_dig(cave2, 4.5)
	await _wait(1.0)
	var gas: Gas = game.gas
	var pk := Gas.Pocket.new()
	pk.id = gas.pockets.size()
	pk.center = cave2 + Vector3(0.0, -2.5, 0.0)
	pk.radius = 3.0
	gas.pockets.append(pk)
	gas._refresh_open(pk)
	pk.opened_at = -100.0
	_expect(pk.open, "de bel ligt open (een gele waas)")
	gas.host_player_op(1, {"op": TerrainAPI.Op.CHIP, "tool": Strata.Tool.HOUWEEL, "h": cave2})
	_expect(not pk.igniting, "het houweel ontsteekt niets")
	var boom := [false]
	gas.exploded.connect(func(_id: int, _at: Vector3) -> void: boom[0] = true, CONNECT_ONE_SHOT)
	var u0 := game.unrest.value
	var fresh := pk.center + Vector3(2.5, 0.0, 0.0)
	var below := t.raycast(pk.center, pk.center + Vector3.DOWN * 5.0)
	var rock_pt: Vector3 = (below.position as Vector3) + Vector3.DOWN * 0.8 if not below.is_empty() else pk.center + Vector3.DOWN * 3.0
	var sdf0 := t.sdf_at(rock_pt)
	p.global_position = pk.center + Vector3(0.0, -1.0, 2.0)
	var h_before := rescue.health_of(p.peer_id)
	gas.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": fresh})
	_expect(pk.igniting, "een boorhap in de waas ontsteekt hem")
	await _wait(Tuning.get_f("gas", "fuse_s", 0.6) + 0.6)
	_expect(boom[0] and pk.gone, "na fuse_s ontploft hij")
	_expect(t.sdf_at(rock_pt) > sdf0 + 0.3, "een krater in de vloer: de rots kan enkel weg (sdf %.1f → %.1f)" % [sdf0, t.sdf_at(rock_pt)])
	_expect(rescue.health_of(p.peer_id) < h_before or rescue.life_of(p.peer_id) != Rescue.Life.OK, "de speler is geraakt")
	_expect(game.unrest.value > u0 + 10.0, "een ontploffing is luid (onrust +%.0f)" % (game.unrest.value - u0))
	await _until(func() -> bool: return rescue.life_of(p.peer_id) in [Rescue.Life.OK, Rescue.Life.LIMPING], 8.0)
	# Een net opengebroken bel sist eerst (breach_grace_s).
	var pk2 := Gas.Pocket.new()
	pk2.id = gas.pockets.size()
	pk2.center = cave
	pk2.radius = 2.5
	gas.pockets.append(pk2)
	gas._refresh_open(pk2)
	gas.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": cave})
	_expect(pk2.open and not pk2.igniting, "net opengebroken: de boor ontsteekt hem nog niet")
	pk2.gone = true

	# 8. Neergaan solo: neer, dan zelf strompelen, en in de Mol gerepareerd.
	_reset_player()
	await _wait(0.3)
	rescue.host_damage(p.peer_id, 2.0, Vector3(2.0, 0.0, 0.0), true, "test")
	await _wait(0.2)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.DOWNED and p.ragdoll != null, "geen levens meer: neer, als ragdoll")
	_expect(p.ragdoll != null and p.global_position.distance_to(p.ragdoll.torso.global_position) < 0.1, "de speler staat op de plek van zijn romp")
	await _wait(Tuning.get_f("rescue", "limp_delay_s", 2.5) + 0.6)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.LIMPING and p.ragdoll == null, "solo: na even liggen strompel je zelf verder")
	_expect(not p.active_tool.visible, "strompelend: geen gereedschap")
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.0))
	await _wait(Tuning.get_f("rescue", "repair_s", 4.0) + 0.6)
	p.set_physics_process(true)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.OK and absf(rescue.health_of(p.peer_id) - Tuning.get_f("rescue", "repair_health", 0.5)) < 0.15,
			"in de Mol gerepareerd (%d%%)" % int(rescue.health_of(p.peer_id) * 100))

	# 9. Een ploegmaat neer: dragen naar de Mol (een tweede robot, zonder eigen peer).
	_reset_player()
	game._spawn(2, 1, cave + Vector3(0.0, -4.0, 0.0))
	var mate := game.player_node(2)
	await _wait(0.3)
	mate.global_position = ground + Vector3(-1.5, 0.1, 0.0)
	await _wait(0.2)
	rescue.host_damage(2, 2.0, Vector3.ZERO, true, "test")
	await _wait(0.8)
	_expect(rescue.life_of(2) == Rescue.Life.DOWNED and rescue.ragdoll_of(2) != null, "ploegmaat neer: een ragdoll")
	await _wait(Tuning.get_f("rescue", "limp_delay_s", 2.5) + 0.5)
	_expect(rescue.life_of(2) == Rescue.Life.DOWNED, "met een gave ploegmaat strompelt hij niet: hij wacht op hulp")
	p.global_position = rescue.ragdoll_of(2).torso.global_position + Vector3(1.0, 0.2, 0.0)
	await _wait(0.2)
	rescue.request_carry(2)
	await _wait(0.2)
	_expect(rescue.carriers_of(2) == PackedInt32Array([1]) and p.carry.body_peer == 2, "de speler draagt zijn ploegmaat")
	_expect(p.carry.move_multiplier() < 0.5, "alleen dragen gaat traag (×%.2f)" % p.carry.move_multiplier())
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.6))
	p.rotation.y = mol.yaw
	var repaired := await _until(func() -> bool: return rescue.life_of(2) == Rescue.Life.OK, Tuning.get_f("rescue", "repair_s", 4.0) + 3.0)
	p.set_physics_process(true)
	_expect(repaired and rescue.ragdoll_of(2) == null, "in de Mol gerepareerd")
	_expect(p.carry.body_peer == -1 and mol.contains_point(mate.global_position), "losgelaten, en hij staat in de Mol")
	# Te lang neer: kapot, een spookdrone, telt als achtergebleven.
	mate.global_position = ground + Vector3(-1.5, 0.1, 0.0)
	await _wait(0.2)
	rescue.host_damage(2, 2.0, Vector3.ZERO, true, "test")
	await _wait(0.3)
	rescue.info(2).timer = 0.05
	await _wait(0.3)
	_expect(rescue.life_of(2) == Rescue.Life.BROKEN and mate._drone != null and mate.rig != null and not mate.rig.visible,
			"te lang neer: kapot, een spookdrone")
	_expect(rescue.left_behind_override(2) == 1, "een kapotte robot telt als achtergebleven")
	game._despawn(2)
	rescue.host_peer_left(2)
	await _wait(0.2)

	# 10. Vallen doet pijn (in de grot, niet uit De Ekster).
	_reset_player()
	p.global_position = ground + Vector3(2.0, 11.0, 0.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var h0 := rescue.health_of(p.peer_id)
	await _until(func() -> bool: return rescue.health_of(p.peer_id) < h0 - 0.01, 4.0)
	_expect(rescue.health_of(p.peer_id) < h0, "een val van 11 m kost levens (%d%% → %d%%)" % [int(h0 * 100), int(rescue.health_of(p.peer_id) * 100)])
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)

	# 11. Instortingen: dieper meer zones en een grotere kans.
	var shallow := 0
	var deep := 0
	for z: Vector4 in game.unrest.zones:
		var d := t.surface_height_at(z.x, z.z) - z.y
		if d >= 10.0 and d < 60.0:
			shallow += 1
		elif d >= 110.0 and d < 160.0:
			deep += 1
	_expect(deep > shallow, "dieper liggen meer onstabiele zones (%d op 110-160 m, %d op 10-60 m)" % [deep, shallow])
	_expect(Collapse.rate_at(30.0) < Collapse.rate_at(90.0) and Collapse.rate_at(90.0) < Collapse.rate_at(180.0),
			"de kans groeit met de diepte (%.3f / %.3f / %.3f per min)" % [Collapse.rate_at(30.0), Collapse.rate_at(90.0), Collapse.rate_at(180.0)])
	_expect(Collapse.rate_at(10.0) == 0.0, "aan de oppervlakte stort niets in")
	_expect(Collapse.rate_at(90.0, 1.0) > Collapse.rate_at(90.0, 0.0), "onrust maakt het erger")
	# Vanzelf: een diepe zone vlakbij stort in, een ondiepe niet.
	var col: Collapse = game.collapse
	game.unrest.zones = [Vector4(cave.x, cave.y + 5.0, cave.z, 4.0)] as Array[Vector4]
	Tuning.set_value("collapse", "quiet_s", 0.0)
	Tuning.set_value("collapse", "check_s", 0.2)
	Tuning.set_value("collapse", "rate_per_100m", 3000.0)
	Tuning.set_value("collapse", "max_rate", 1000.0)
	var n0 := col.count()
	await _until(func() -> bool: return col.count() > n0, 6.0)
	_expect(col.count() > n0, "een diepe zone stort vanzelf in (na een waarschuwing)")
	var surf_zone := Vector4(cave.x, t.surface_height_at(cave.x, cave.z) - 6.0, cave.z, 4.0)
	game.unrest.zones = [surf_zone] as Array[Vector4]
	var n1 := col.count()
	await _wait(2.0)
	_expect(col.count() == n1, "een ondiepe zone (6 m) niet")
	Tuning.set_value("collapse", "quiet_s", 90.0)
	Tuning.set_value("collapse", "check_s", 4.0)
	Tuning.set_value("collapse", "rate_per_100m", 0.035)
	Tuning.set_value("collapse", "max_rate", 0.12)
	# Puin: blijft liggen, houdt je tegen, en je bikt het weg.
	game.unrest.zones = [] as Array[Vector4]
	await _wait(Tuning.get_f("collapse", "warn_s", 1.6) + Tuning.get_f("collapse", "spread_s", 2.0) + 2.0)
	var rubble: Rubble = null
	for r: RigidBody3D in game.unrest._rocks:
		if r is Rubble and (r as Rubble).blocks and is_instance_valid(r):
			rubble = r
			break
	if rubble == null:
		game.unrest.spawn_rock(game.unrest.host_rock_entry(ground + Vector3(-2.0, 3.0, 0.0), 1.0, 0.0))
		await _wait(2.0)
		rubble = game.unrest.rock(game.unrest._next_rock - 1)
	_expect(rubble != null and rubble.collision_layer & Layers.RUBBLE and p.collision_mask & Layers.RUBBLE, "grote rotsen blijven liggen als puin dat je tegenhoudt")
	if rubble:
		var id := rubble.rock_id
		var hits := 0
		while game.unrest.rock(id) != null and hits < 20:
			p.global_position = rubble.global_position + Vector3(1.2, 0.0, 0.0)
			game.unrest.request_chip(id, false, rubble.global_position)
			hits += 1
			await _wait(0.2)
		_expect(game.unrest.rock(id) == null, "weggebikt in %d slagen" % hits)

	# 12. De climax: spanning naar het einde, de Mol die vertrekt lokt de worm, hij ramt de Mol.
	_expect(worm.tension() < 0.2, "spanning bij het begin laag (%.2f)" % worm.tension())
	magma.debug_depth = 80.0
	await _wait(0.2)
	_expect(worm.tension() > 0.8, "het magma dichtbij: spanning hoog (%.2f)" % worm.tension())
	magma.debug_depth = -1.0
	_reset_player()
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm.pos = mol.body.global_position + Vector3(0.0, -10.0, 25.0)
	mol._path.assign([mol.body.global_position + Vector3(0.0, 0.0, -8.0), mol.body.global_position])
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	await _wait(0.3)
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.4)
	_expect(mol.mode == Mol.Mode.COUNTDOWN and worm.tension() == 1.0, "de hendel: de climax (spanning 1)")
	await _wait(0.6)
	_expect(worm.mode == Worm.Mode.HUNT and worm._target.distance_to(mol.body.global_position) < 6.0, "de motor van de Mol lokt de worm")
	# Rammen: de lading lijdt, de Mol valt stil.
	var cargo: FindItem = _a_find()
	game.finds._free(cargo.find_id)
	await _wait(0.5)
	cargo.global_position = mol.to_world_mol(Vector3(0.6, -1.2, 2.6))
	cargo.reset_physics_interpolation()
	await _wait(0.5)
	var cond0 := cargo.condition
	var rammed := [false]
	worm.rammed.connect(func(_a: Vector3) -> void: rammed[0] = true, CONNECT_ONE_SHOT)
	worm._ram_cool = 0.0
	worm._ram(mol)
	await _wait(0.3)
	_expect(rammed[0] and cargo.condition < cond0 - 0.05, "de worm ramt de Mol: de lading lijdt (%d%% → %d%%)" % [int(cond0 * 100), int(cargo.condition * 100)])
	# Wie in de Mol stond, ging omver (de ram). Een baken in de Mol: geen rammen.
	await _until(func() -> bool: return game.rescue.is_ok(p.peer_id), 4.0)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	game.beacons._host_throw(1, mol.to_world_mol(Vector3(0.0, -1.0, 1.0)), Vector3.ZERO)
	await _wait(0.5)
	print(TAG, " bakens: %d branden, het dichtste %.1f m van de Mol" % [game.beacons.count_active(), game.beacons.nearest(mol.body.global_position).distance_to(mol.body.global_position)])
	worm._ram_cool = 0.0
	worm.mode = Worm.Mode.HUNT
	var cond1 := cargo.condition
	worm._ram(mol)
	await _wait(0.3)
	_expect(worm.mode == Worm.Mode.REPELLED and is_equal_approx(cargo.condition, cond1), "een baken in de Mol houdt hem af")
	p.set_physics_process(true)
	_finish()


func _reset_player() -> void:
	var r: Rescue = game.rescue
	if r.life_of(p.peer_id) != Rescue.Life.OK or r.health_of(p.peer_id) < 1.0:
		r._rpc_reset.rpc(p.peer_id, p.global_position, false)
	p.set_physics_process(true)


## Een vondst ver van alles, om mee te testen.
func _a_find() -> FindItem:
	for it: FindItem in game.finds.items:
		if not it.freed and it.carriers.is_empty():
			return it
	return game.finds.items[0]


func _finish() -> void:
	print(TAG, " %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print(TAG, " MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print(TAG, " %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _gt() -> float:
	return Time.get_ticks_msec() / 1000.0


func _until(cond: Callable, timeout: float) -> bool:
	var t0 := _gt()
	while _gt() - t0 < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()
