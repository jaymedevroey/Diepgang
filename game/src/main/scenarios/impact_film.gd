extends Node
## Films en metingen voor pakket G2 (release-audit golf 3: neergaan, klap, kleinere gevaren, dragen).
## Elke take speelt één moment op een vaste plek, zodat voor en na vergelijkbaar zijn (zelfde seed,
## zelfde plek, zelfde tijd in speltijd). Voor Movie Maker:
##   tools\godot.cmd --path game --resolution 1280x720 --write-movie logs/x.avi --fixed-fps 30 -- --scenario=impact_film --take=quake --no-steam --out=…
## Takes (--take=…):
##   quake      grot op 45 m: de aankondiging van een beving, de hoofdschok, een grote rots op je hoofd
##   gas        grot op 70 m: in een gasbel staan (HUD), dan de boor: de ontploffing uit eigen ogen
##   collapse   grot op 110 m: een zone stort in, het puin blijft liggen, je bikt het weg
##   downed     aan de oppervlakte neer; een ploegmaat draagt je de Mol in (je eigen beeld)
##   carry_mate een ploegmaat ligt neer: jij sleept hem alleen naar de Mol
##   heavy      titanschedel: alleen slepen, dan met twee tillen en samen lopen (eigen beeld en opzij)
##   crystal    een glowshard tegen de wand gooien: hij breekt
##   drone      je robot gaat kapot: de spookdrone (beelden na 1 s en 6 s)
##   solo       solo neer: wat de HUD belooft
##   scanner    de handscanner in je hand (beelden)
##   sprint     lopen en sprinten aan de oppervlakte
##   crouch     (headless) gehurkt de spleet van feel_bench in, loslaten: blijf je vast?
## Beelden (--out=map) heten <take>_<moment>.png. Eindigt zelf.

const TAG := "[impact_film]"

var main: Node
var game: Game
var t: TerrainAPI
var p: Player
var _take := "quake"
var _out := "C:/Dev/Diepgang/logs/review_fix3/G2/beelden"
var _cam: Camera3D
var _mate: Player
var _mate_goal := Vector3.INF
var _mate_speed := 1.5
var _body: RobotRig # lijf van de eigen robot voor beelden van opzij
var _gt := 0.0


func _ready() -> void:
	_take = str(CmdArgs.value("take", "quake"))
	_out = str(CmdArgs.value("out", _out))
	DirAccess.make_dir_recursive_absolute(_out)
	main.game.player_spawned.connect(func(pl: Player) -> void:
		if pl.is_local and p == null:
			_run.call_deferred(pl))
	get_tree().create_timer(600.0).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out")
		get_tree().quit(1))


func _physics_process(delta: float) -> void:
	_gt += delta
	if _mate and _mate_goal != Vector3.INF:
		var d := _mate_goal - _mate.global_position
		d.y = 0.0
		if d.length() > 0.2:
			var next := _mate.global_position + d.normalized() * minf(d.length(), _mate_speed * delta)
			var hit := t.raycast(next + Vector3.UP * 1.2, next + Vector3.DOWN * 2.0, Layers.TERRAIN | Layers.LIFT)
			if not hit.is_empty():
				next.y = (hit.position as Vector3).y + 0.02
			_mate.global_position = next
			_mate.rotation.y = atan2(-d.x, -d.z)


func _run(pl: Player) -> void:
	p = pl
	game = main.game
	t = main.terrain
	while not game.world_ready():
		await get_tree().process_frame
	await _wait(1.5)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_log("take %s" % _take)
	match _take:
		"quake": await _quake()
		"gas": await _gas()
		"collapse": await _collapse()
		"downed": await _downed()
		"carry_mate": await _carry_mate()
		"heavy": await _heavy()
		"crystal": await _crystal()
		"drone": await _drone()
		"solo": await _solo()
		"scanner": await _scanner()
		"sprint": await _sprint()
		"crouch": await _crouch()
		_: _log("onbekende take")
	_log("klaar")
	get_tree().quit(0)


# --- Hulp ----------------------------------------------------------------------------------------

func _log(s: String) -> void:
	print(TAG, " t=%.2f %s" % [_gt, s])


func _wait(s: float) -> void:
	var end := _gt + s
	while _gt < end:
		await get_tree().physics_frame


func _until(cond: Callable, timeout: float) -> bool:
	var t0 := _gt
	while _gt - t0 < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


func _snap(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _out.path_join("%s_%s.png" % [_take, name])
	get_viewport().get_texture().get_image().save_png(path)
	_log("beeld " + path)


func _ready_area(c: Vector3, r := 12.0) -> void:
	t.add_viewer(p, 40.0, 20.0)
	var n := 0
	while not t.is_area_ready(c, r) and n < 300:
		await _wait(0.1)
		n += 1


## Grot op `depth` m onder het oppervlak, `off` van de landingsplek (zoals threat_film): [midden, vloer].
func _cave(depth: float, off: Vector3, radius := 7.0) -> Array:
	var sc := t.shaft_center_world()
	var x := sc.x + off.x
	var z := sc.z + off.z
	var c := Vector3(x, t.surface_height_at(x, z) - depth, z)
	p.set_physics_process(false)
	p.global_position = c
	p.reset_physics_interpolation()
	await _ready_area(c, radius + 6.0)
	t.debug_dig(c, radius)
	t.debug_dig(c + Vector3(radius * 0.6, -radius * 0.25, 0.0), radius * 0.75)
	t.debug_dig(c + Vector3(-radius * 0.6, -radius * 0.25, 0.0), radius * 0.75)
	var hit := {}
	var t0 := _gt
	while _gt - t0 < 30.0:
		await _wait(0.2)
		hit = t.raycast(c, c + Vector3.DOWN * (radius + 3.0))
		if t.sdf_at(c) > radius * 0.5 and not hit.is_empty() and (hit.position as Vector3).distance_to(c) > radius * 0.7 \
				and t.collision_ready(hit.position):
			break
	await _wait(0.5)
	var ground: Vector3 = hit.position if not hit.is_empty() else c + Vector3.DOWN * radius
	return [c, ground]


## Op de vloer op deze plek, kijkend naar `look`.
func _stand(at: Vector3, look: Vector3) -> void:
	var hit := t.raycast(at + Vector3.UP * 2.5, at + Vector3.DOWN * 6.0, Layers.TERRAIN | Layers.LIFT)
	if not hit.is_empty():
		at.y = (hit.position as Vector3).y + 0.05
	p.velocity = Vector3.ZERO
	p.global_position = at
	p.reset_physics_interpolation()
	_aim(look)


func _aim(look: Vector3) -> void:
	var dir := look - (p.global_position + Vector3.UP * 1.2)
	p.rotation.y = atan2(-dir.x, -dir.z)
	p.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


## Lopen zonder invoer (een venster vangt de muis niet altijd): schuiven aan `speed` naar `to`.
func _walk(to: Vector3, speed: float, look_down := -10.0, turn := true) -> void:
	p.set_physics_process(false)
	var last := _gt
	var t0 := _gt
	while _gt - t0 < 25.0:
		await get_tree().physics_frame
		var dt := _gt - last
		last = _gt
		var d := to - p.global_position
		d.y = 0.0
		if d.length() < 0.2:
			break
		if turn:
			p.rotation.y = atan2(-d.x, -d.z)
		p.head.rotation.x = deg_to_rad(look_down)
		var next := p.global_position + d.normalized() * minf(speed * dt, d.length())
		var hit := t.raycast(next + Vector3.UP * 1.2, next + Vector3.DOWN * 2.0, Layers.TERRAIN | Layers.LIFT)
		if not hit.is_empty():
			next.y = (hit.position as Vector3).y + 0.02
		p.velocity = d.normalized() * speed
		p.global_position = next
	p.velocity = Vector3.ZERO
	p.set_physics_process(true)


func _observer(from: Vector3, target: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 70.0
		_cam.near = 0.05
		main.add_child(_cam)
	_cam.global_position = from
	_cam.look_at(target)
	_cam.make_current()
	if _body:
		_body.visible = true


## Terug naar de eigen ogen (het filmlijf weer weg).
func _own_view() -> void:
	p.camera.make_current()
	if _body:
		_body.visible = false


func _free_loose(it: FindItem, at: Vector3) -> void:
	var crust: Crust = it.get_parent().crusts.get(it.find_id)
	if crust:
		crust.queue_free()
		it.get_parent().crusts.erase(it.find_id)
	it.set_freed()
	it.global_position = at
	it.reset_physics_interpolation()
	it.linear_velocity = Vector3.ZERO
	it.freeze = false


func _room_at(room: Vector3) -> void:
	for dx in [-3.0, -1.0, 1.0, 3.0, 5.0]:
		for dz in [-2.0, 0.0, 2.0]:
			t.debug_dig(room + Vector3(dx, 0.0, dz), 2.6)
	await _wait(1.2)


func _spawn_mate(at: Vector3) -> Player:
	game._spawn(2, 1, at)
	await _wait(0.4)
	var m := game.player_node(2)
	m.global_position = at
	return m


## Een kamer in de klei, 12 m onder het oppervlak naast de landingsplek.
func _clay_room() -> Vector3:
	var sc := t.shaft_center_world()
	var top := t.surface_height_at(sc.x + 24.0, sc.z + 18.0)
	var room := Vector3(sc.x + 24.0, top - 12.0, sc.z + 18.0)
	p.set_physics_process(false)
	p.global_position = room
	await _ready_area(room)
	await _room_at(room)
	return room


# --- Takes ---------------------------------------------------------------------------------------

## Beving: 4 s aankondiging, dan de hoofdschok; 1,8 s na T0 valt een grote rots op je hoofd.
func _quake() -> void:
	var r: Array = await _cave(45.0, Vector3(-35.0, 0.0, 15.0), 7.5)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	_stand(ground + Vector3(2.5, 0.05, 0.0), ground + Vector3(-5.0, 2.0, 0.0))
	p.set_physics_process(true)
	game.magma.host_start()
	game.magma.elapsed = 60.0
	await _wait(1.5)
	var u: Unrest = game.unrest
	u.quake_started.connect(func(_i: int) -> void: _log("hoofdschok T0"))
	u.local_knockdown.connect(func(s: float) -> void: _log("omver door rots (%.2f m)" % s))
	game.rescue.life_changed.connect(func(peer: int, life: int) -> void: _log("leven peer %d -> %d" % [peer, life]))
	u.zones = [Vector4(ground.x - 2.0, c.y + 3.0, ground.z, 3.5)] as Array[Vector4]
	var plan: Array = u._host_plan()
	plan.append(u.host_rock_entry(p.global_position + Vector3(0.0, 3.4, 0.0), 1.0, 1.8))
	u.value = 0.0
	u._since_quake = 0.0
	_log("aankondiging (%d rotsen)" % plan.size())
	u._rpc_quake(1, plan)
	await _wait(2.0)
	await _snap("aankondiging")
	await _wait(2.4)
	await _snap("hoofdschok")
	await _wait(1.6)
	await _snap("geraakt")
	await _wait(0.6)
	await _snap("volgcamera")
	await _wait(8.0)
	_log("eind: leven %d" % p.life)


## Gas: eerst in de bel (HUD), dan naar de rand, de boor in de wand: de ontploffing.
func _gas() -> void:
	var r: Array = await _cave(70.0, Vector3(35.0, 0.0, 25.0), 7.0)
	var ground: Vector3 = r[1]
	var gas: Gas = game.gas
	var pk := Gas.Pocket.new()
	pk.id = gas.pockets.size()
	pk.center = ground + Vector3(-2.0, 2.2, 0.0)
	pk.radius = 3.2
	gas.pockets.append(pk)
	gas._refresh_open(pk)
	pk.opened_at = -100.0
	# In de bel: kan je de waarschuwing lezen?
	_stand(ground + Vector3(-1.4, 0.05, 0.6), ground + Vector3(-6.0, 1.6, 0.0))
	p.set_physics_process(true)
	p.select_tool(1)
	await _wait(2.5)
	await _snap("in_de_bel")
	_stand(ground + Vector3(4.5, 0.05, 0.0), pk.center)
	await _wait(1.5)
	await _snap("waas")
	p.drill.auto_use = true
	_stand(ground + Vector3(1.2, 0.05, 0.0), pk.center + Vector3(-3.4, -0.6, 0.0))
	var t0 := _gt
	var lit := false
	while _gt - t0 < 3.0 and not pk.gone:
		await get_tree().physics_frame
		if not pk.igniting and _gt - t0 > 1.0:
			gas.host_ignite(pk.id, pk.center) # zeker zijn van de vonk in de film
		if pk.igniting and not lit:
			lit = true
			_log("lont")
	p.drill.auto_use = false
	_log("ontploft")
	await _wait(0.05)
	await _snap("klap")
	await _wait(0.4)
	await _snap("na_klap")
	await _wait(5.0)


## Instorting: waarschuwing, rotsen, puin, en het puin wegbikken met het vizier erop.
func _collapse() -> void:
	var r: Array = await _cave(110.0, Vector3(-30.0, 0.0, -30.0), 7.0)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	var zone := Vector4(ground.x - 2.5, c.y + 4.0, ground.z, 4.0)
	game.unrest.zones = [zone] as Array[Vector4]
	_stand(ground + Vector3(4.5, 0.05, 2.0), Vector3(zone.x, zone.y - 2.0, zone.z))
	p.set_physics_process(true)
	await _wait(2.0)
	game.collapse.host_collapse(zone)
	_log("instorting")
	await _wait(0.8)
	await _snap("waarschuwing")
	await _wait(1.6)
	await _snap("rotsen")
	await _wait(3.0)
	var rubble: Rubble = null
	for rb: RigidBody3D in game.unrest._rocks:
		if rb is Rubble and (rb as Rubble).blocks and is_instance_valid(rb):
			if rubble == null or (rb as Rubble).size > rubble.size:
				rubble = rb
	if rubble == null:
		_log("geen puin")
		return
	var side := (p.global_position - rubble.global_position)
	side.y = 0.0
	side = side.normalized() if side.length() > 0.1 else Vector3.RIGHT
	_stand(rubble.global_position + side * (1.3 + rubble.size * 0.5), rubble.global_position)
	await get_tree().physics_frame
	_aim(rubble.global_position)
	await _wait(0.8)
	await _snap("puin")
	p.pickaxe.auto_swing = true
	var hits := 0
	var t0 := _gt
	var last_hp := rubble.hp
	while _gt - t0 < 9.0 and is_instance_valid(rubble) and game.unrest.rock(rubble.rock_id) != null:
		_aim(rubble.global_position)
		await get_tree().physics_frame
		if is_instance_valid(rubble) and rubble.hp < last_hp:
			last_hp = rubble.hp
			hits += 1
			if hits == 2:
				await _snap("puin_2_slagen")
	p.pickaxe.auto_swing = false
	_log("weggebikt na %d slagen" % hits)
	await _wait(0.4)
	await _snap("weggebikt")
	await _wait(1.0)


## Neer aan de oppervlakte; een ploegmaat draagt je naar de Mol (je eigen beeld).
func _downed() -> void:
	var mol: Mol = game.mol
	var back := mol.to_world_mol(Vector3(0.0, -1.5, 14.0))
	back.y = t.surface_height_at(back.x, back.z) + 0.1
	_stand(back, mol.body.global_position)
	await _wait(1.0)
	_mate = await _spawn_mate(back + mol.body.global_basis.x * 3.0)
	await _wait(1.0)
	game.rescue.life_changed.connect(func(peer: int, life: int) -> void: _log("leven peer %d -> %d" % [peer, life]))
	_log("klap: neer")
	game.rescue.host_damage(p.peer_id, 2.0, mol.body.global_basis.z * 4.0 + Vector3.UP * 3.0, true, "film")
	await _wait(0.1)
	await _snap("klap")
	await _wait(0.5)
	await _snap("neer")
	await _wait(2.5)
	var torso := game.rescue.ragdoll_of(p.peer_id).torso.global_position
	_mate_goal = torso + (back - mol.body.global_position).normalized() * 1.0
	await _wait(3.0)
	_mate_goal = Vector3.INF
	_mate.rotation.y = atan2(-(torso - _mate.global_position).x, -(torso - _mate.global_position).z)
	game.rescue._carry(2, p.peer_id)
	_log("gedragen")
	await _wait(1.5)
	await _snap("gedragen")
	_mate_speed = 1.5
	_mate_goal = mol.to_world_mol(Vector3(0.0, -1.45, 1.0))
	await _wait(9.0)
	await _snap("in_de_mol")
	_mate_goal = Vector3.INF
	await _until(func() -> bool: return p.life == Rescue.Life.OK, 10.0)
	await _wait(0.2)
	await _snap("opgestaan")
	await _wait(1.5)
	_log("eind: leven %d" % p.life)


## Een ploegmaat ligt neer: jij sleept hem alleen naar de Mol (eigen beeld).
func _carry_mate() -> void:
	var mol: Mol = game.mol
	var back := mol.to_world_mol(Vector3(0.0, -1.5, 12.0))
	back.y = t.surface_height_at(back.x, back.z) + 0.1
	_mate = await _spawn_mate(back)
	await _wait(0.4)
	game.rescue.host_damage(2, 2.0, Vector3(0.0, 2.0, 2.0), true, "film")
	await _wait(2.0)
	var torso := game.rescue.ragdoll_of(2).torso.global_position
	_stand(torso + mol.body.global_basis.z * 2.0 + Vector3(0.0, 0.3, 0.0), torso)
	p.set_physics_process(true)
	await _wait(0.8)
	game.rescue.request_carry(2)
	await _wait(1.0)
	await _snap("opgepakt")
	var goal := mol.to_world_mol(Vector3(0.0, -1.45, 1.0))
	await _walk(goal, Tuning.get_f("player", "move_speed", 4.5) * p.carry.move_multiplier(), -12.0)
	await _snap("in_de_mol")
	await _until(func() -> bool: return game.rescue.life_of(2) == Rescue.Life.OK, 8.0)
	await _wait(1.0)


## Titanschedel: alleen slepen, dan met twee tillen; beelden uit eigen ogen en van opzij.
func _heavy() -> void:
	var finds: FindField = game.finds
	var at := t.spawn_point() + Vector3(0.0, 0.0, 12.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.1
	p.global_position = at
	await _ready_area(at)
	await _wait(1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var big := finds._place(rng, func() -> Array: return [at + Vector3(rng.randf_range(-3, 3), -8.0, 0.0), FindKinds.Kind.TITAN_SKULL], 10)
	if big == null:
		_log("geen titanschedel")
		return
	_free_loose(big, at + Vector3(0.0, 0.6, -2.2))
	await _wait(1.5)
	_stand(at, big.global_position)
	# Van opzij: de eigen robot is lokaal onzichtbaar (eerste persoon), dus voor de film een lijf erbij
	# (zoals threat_film); het volgt de speler, met de armen in de draagstand.
	_body = RobotRig.new()
	_body.name = "FilmRig"
	p.add_child(_body)
	_body.setup(p.color)
	_body.set_carrying(true)
	_body.visible = false
	await _wait(0.3)
	# Alleen slepen.
	finds.request_grab(big.find_id)
	await _wait(0.8)
	await _snap("slepen_eigen")
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	await _walk(p.global_position - fwd * 2.5, Tuning.get_f("player", "move_speed", 4.5) * p.carry.move_multiplier(), -25.0, false)
	await _wait(0.4)
	await _snap("slepen_eigen_2")
	var mid0 := p.global_position
	_observer(mid0 + p.global_basis.x * 4.0 + Vector3.UP * 1.8 - fwd * 1.5, mid0 + fwd * 1.0 + Vector3.UP * 0.4)
	await _wait(0.2)
	await _snap("slepen_opzij")
	_own_view()
	# Een maat pakt de andere kant.
	var far_end := big.global_position + fwd * 1.6
	_mate = await _spawn_mate(far_end)
	_mate.rotation.y = atan2(-(big.global_position - _mate.global_position).x, -(big.global_position - _mate.global_position).z)
	await _wait(0.4)
	finds._grab(2, big.find_id)
	if _mate.rig:
		_mate.rig.set_carrying(true) # (in het spel komt dat met CARRY_ON van de maat)
	await _wait(1.2)
	_log("dragers %s, gesleept=%s" % [big.carriers, big.dragged()])
	for gap in [2.0, 3.2, 4.6]:
		var me_at := p.global_position
		_mate.global_position = me_at + fwd * gap
		_mate.global_position.y = t.surface_height_at(_mate.global_position.x, _mate.global_position.z) + 0.05
		_mate.rotation.y = atan2(fwd.x, fwd.z) # naar mij toe
		p.rotation.y = atan2(-fwd.x, -fwd.z)
		p.head.rotation.x = deg_to_rad(-14.0)
		await _wait(1.2)
		_log("uit elkaar %.1f m: schedel %.2f m van mijn oog, %.2f m van de maat" % [gap,
				big.global_position.distance_to(p.camera.global_position), big.global_position.distance_to(_mate.global_position + Vector3.UP * 1.2)])
		_own_view()
		await _snap("samen_%d_eigen" % int(gap * 10))
		var mid := (p.global_position + _mate.global_position) * 0.5
		var side := fwd.cross(Vector3.UP).normalized()
		_observer(mid + side * 5.5 + Vector3.UP * 2.0, mid + Vector3(0.0, 0.8, 0.0))
		await _wait(0.1)
		await _snap("samen_%d_opzij" % int(gap * 10))
		_own_view()
	# Samen zijwaarts lopen: de schedel tussen de twee (van opzij gefilmd).
	var side2 := fwd.cross(Vector3.UP).normalized()
	_mate.global_position = p.global_position + fwd * 3.0
	await _wait(0.6)
	var mid2 := (p.global_position + _mate.global_position) * 0.5
	_observer(mid2 + side2 * 7.0 + Vector3.UP * 2.2 + fwd * 0.0, mid2 + Vector3(0.0, 0.8, 0.0) + side2 * -2.0)
	_mate_speed = Tuning.get_f("player", "move_speed", 4.5) * p.carry.move_multiplier()
	_mate_goal = _mate.global_position - side2 * 4.0
	await _walk(p.global_position - side2 * 4.0, _mate_speed, -14.0, false)
	await _wait(1.0)
	await _snap("samen_lopen_opzij")
	_own_view()
	await _wait(0.5)


## Een glowshard tegen de wand: breken.
func _crystal() -> void:
	var finds: FindField = game.finds
	var room := await _clay_room()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var shard := finds._place(rng, func() -> Array: return [room + Vector3(rng.randf_range(-3, 3), -6.0, -3.0), FindKinds.Kind.GLOWSHARD], 10)
	if shard == null:
		_log("geen glowshard")
		return
	_free_loose(shard, room + Vector3(1.0, -1.6, 0.0))
	await _wait(2.0)
	_stand(shard.global_position + Vector3(-1.6, 0.0, 0.0), shard.global_position)
	p.set_physics_process(true)
	await _wait(1.0)
	finds.request_grab(shard.find_id)
	await _wait(1.0)
	_aim(p.global_position + Vector3(-6.0, 1.0, 0.0))
	await _wait(0.8)
	p.carry.drop(true)
	_log("gegooid")
	var broke := await _until(func() -> bool: return shard.is_shattered(), 2.5)
	_log("gebroken=%s" % broke)
	await _wait(0.1)
	await _snap("breuk")
	await _wait(0.3)
	await _snap("breuk_na")
	await _wait(2.0)


## Kapot: de spookdrone.
func _drone() -> void:
	var r: Array = await _cave(40.0, Vector3(25.0, 0.0, 25.0), 6.0)
	var ground: Vector3 = r[1]
	_stand(ground + Vector3(2.0, 0.05, 0.0), ground + Vector3(-3.0, 1.0, 0.0))
	p.set_physics_process(true)
	game.magma.host_start()
	await _wait(1.0)
	_mate = await _spawn_mate(ground + Vector3(-2.0, 0.05, 1.5))
	await _wait(0.5)
	game.rescue.host_break(p.peer_id, false)
	await _wait(1.0)
	await _snap("na_1s")
	await _wait(5.0)
	await _snap("na_6s")
	await _wait(1.0)


## Solo neer: wat belooft de HUD?
func _solo() -> void:
	var r: Array = await _cave(40.0, Vector3(25.0, 0.0, 25.0), 6.0)
	var ground: Vector3 = r[1]
	_stand(ground + Vector3(2.0, 0.05, 0.0), ground + Vector3(-3.0, 1.0, 0.0))
	p.set_physics_process(true)
	await _wait(1.0)
	game.rescue.host_damage(p.peer_id, 2.0, Vector3(1.0, 1.5, 0.0), true, "film")
	await _wait(0.8)
	await _snap("neer")
	await _wait(2.5)
	await _snap("strompelen")
	await _wait(1.0)


## De handscanner in de hand.
func _scanner() -> void:
	var c: Company = game.company
	if not c.has_upgrade(Upgrades.SCANNER):
		c.upgrades.append(Upgrades.SCANNER)
	c.changed.emit()
	var at := t.spawn_point() + Vector3(3.0, 0.0, -6.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.1
	p.global_position = at
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(-20.0)
	p.reset_physics_interpolation()
	await _wait(1.5)
	var scanner := p.camera.find_child("HandScanner", true, false) as HandScanner
	if scanner == null:
		_log("geen scanner")
		return
	scanner.pulse()
	await _wait(1.0)
	await _snap("in_de_hand")
	p.head.rotation.x = deg_to_rad(10.0)
	await _wait(0.6)
	await _snap("in_de_hand_omhoog")


## Lopen en sprinten aan de oppervlakte (echte invoer).
func _sprint() -> void:
	var at := t.spawn_point() + Vector3(0.0, 0.0, 10.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.3
	p.velocity = Vector3.ZERO
	p.global_position = at
	p.rotation.y = PI
	p.head.rotation.x = deg_to_rad(-5.0)
	p.reset_physics_interpolation()
	await _ready_area(at)
	await _wait(1.0)
	Input.action_press("move_forward")
	await _wait(1.5)
	await _snap("lopen")
	_log("lopen: fov %.1f" % p.camera.fov)
	Input.action_press("sprint")
	await _wait(1.5)
	await _snap("sprint")
	_log("sprint: fov %.1f, %.2f m/s" % [p.camera.fov, Vector2(p.velocity.x, p.velocity.z).length()])
	Input.action_press("move_right")
	await _wait(0.6)
	_log("sprint in een bocht: rol %.2f°" % rad_to_deg(p.camera.rotation.z))
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _wait(1.0)
	_log("weer lopen: fov %.1f" % p.camera.fov)
	Input.action_release("move_forward")
	await _wait(0.6)


## Gehurkt de spleet van feel_bench in (oppervlakte, 30 m W, 25 m Z van de schacht), loslaten.
func _crouch() -> void:
	var sc := t.shaft_center_world()
	var at := Vector3(sc.x - 30.0, 0, sc.z + 25.0)
	at.y = t.surface_height_at(at.x, at.z) + 0.3
	p.velocity = Vector3.ZERO
	p.global_position = at
	p.rotation = Vector3(0, deg_to_rad(180.0), 0)
	p.head.rotation.x = deg_to_rad(-6.0)
	p.reset_physics_interpolation()
	await _ready_area(at)
	await _wait(1.0)
	# Dezelfde fasen als feel_bench --part=move: lopen, sprinten, dan gehurkt de spleet in.
	for ph: Array in [["move_forward", 1.4], ["", 0.8], ["move_forward+sprint", 1.6], ["", 1.0], ["move_forward+crouch", 1.2]]:
		var acts: PackedStringArray = (ph[0] as String).split("+", false)
		for a in acts:
			Input.action_press(a)
		await _wait(float(ph[1]))
		for a in acts:
			Input.action_release(a)
	await _wait(0.8)
	_log("na loslaten: gehurkt=%s, oog %.2f" % [p.crouching, p.camera.global_position.y - p.global_position.y])
	await _wait(2.0)
	_log("2 s later: gehurkt=%s, oog %.2f, pos %s" % [p.crouching, p.camera.global_position.y - p.global_position.y, p.global_position])
