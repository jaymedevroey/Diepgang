extends Node
## Films en beelden van de dreiging (pakket F2), voor Movie Maker:
##   tools\godot.cmd --path game --resolution 1280x720 --write-movie logs/review_fix/F2/film/worm.avi --fixed-fps 30 -- --scenario=threat_film --take=worm --no-steam
## Shots (--take=…; niet --shot, dat is van main.gd):
##   model     de Graafworm en een lichtbaken stil in een grot, de camera draait rond (ter goedkeuring)
##   worm      de piloot in de Mol, buitenzicht met de sonar: de worm nadert als grote stip, ramt de
##             Mol en valt uit naast de Mol
##   lunge     te voet in een grot: gerommel, stof, de markering op de vloer, dan de uitval die je raakt
##   gas       een gele waas in een grot, de boor, de ontploffing
##   rescue    een ploegmaat ligt neer, de speler draagt hem naar de Mol, daar wordt hij gerepareerd
##             (--cam=side: van opzij gefilmd)
##   collapse  diep in het zandsteen: een zone stort in, het puin blijft liggen, je bikt het weg
##   hud       beelden (geen film) van de HUD onder de grond: het magma ver weg, voor (--legacy) en na
##   beacon    een lichtbaken gooien in een donkere grot: de worp, het licht, de veilige zone (G1)
##   climax    de hendel, de terugrit over de vlakte (buitenzicht met de sonar), de worm die achtervolgt
##             en ramt (--beacon=1: met een baken in de Mol; --inside=1: van binnen gefilmd) (G1)
##   grab      in een grot: de waarschuwing onder een ploegmaat, de uitval, hij grijpt hem en sleurt
##             hem weg; de speler loopt erheen en slaat hem los met het houweel (G1)
## Eindigt zelf.

const TAG := "[threat_film]"

var main: Node
var game: Game
var t: TerrainAPI
var p: Player
var _cam: Camera3D
var _shot := "model"


func _ready() -> void:
	_shot = str(CmdArgs.value("take", "model"))
	main.game.player_spawned.connect(func(pl: Player) -> void:
		if pl.is_local:
			_run.call_deferred(pl))


func _run(pl: Player) -> void:
	p = pl
	game = main.game
	t = main.terrain
	while not game.world_ready():
		await get_tree().process_frame
	await _wait(1.5)
	print(TAG, " shot ", _shot)
	match _shot:
		"model":
			await _model()
		"worm":
			await _worm()
		"lunge":
			await _lunge()
		"gas":
			await _gas()
		"rescue":
			await _rescue()
		"collapse":
			await _collapse()
		"hud":
			await _hud()
		"beacon":
			await _beacon()
		"climax":
			await _climax()
		"grab":
			await _grab()
	print(TAG, " klaar")
	get_tree().quit(0)


## Een grot op `depth` m onder het oppervlak, `off` m van de landingsplek. Geeft [midden, vloer].
func _cave(depth: float, off: Vector3, radius := 7.0) -> Array:
	var sc := t.shaft_center_world()
	var x := sc.x + off.x
	var z := sc.z + off.z
	var c := Vector3(x, t.surface_height_at(x, z) - depth, z)
	p.set_physics_process(false)
	p.global_position = c
	p.reset_physics_interpolation()
	while not t.is_area_ready(c, radius + 6.0):
		await _wait(0.2)
	t.debug_dig(c, radius)
	t.debug_dig(c + Vector3(radius * 0.6, -radius * 0.25, 0.0), radius * 0.75)
	t.debug_dig(c + Vector3(-radius * 0.6, -radius * 0.25, 0.0), radius * 0.75)
	# Wachten tot de grot ook botsvormen heeft (met Movie Maker loopt de speltijd sneller dan het
	# bouwen van de collision): anders valt de speler door de vloer.
	var hit := {}
	var t0 := _now()
	while _now() - t0 < 30.0:
		await _wait(0.2)
		hit = t.raycast(c, c + Vector3.DOWN * (radius + 3.0))
		# De grot moet er al zijn in de data én in de botsvorm (de vloer ligt ±radius onder het midden).
		if t.sdf_at(c) > radius * 0.5 and not hit.is_empty() and (hit.position as Vector3).distance_to(c) > radius * 0.7 \
				and t.collision_ready(hit.position):
			break
	await _wait(0.5)
	var ground: Vector3 = hit.position if not hit.is_empty() else c + Vector3.DOWN * radius
	print(TAG, " grot op %s: sdf %.1f, vloer %s (%.1f m onder het midden), collision %s, na %.1f s" % [c, t.sdf_at(c),
			ground, c.y - ground.y, t.collision_ready(ground), _now() - t0])
	return [c, ground]


func _stand(at: Vector3, look_at: Vector3) -> void:
	# Op de vloer op deze plek (de vloer van een bolle grot ligt opzij hoger dan in het midden).
	var hit := t.raycast(at + Vector3.UP * 2.5, at + Vector3.DOWN * 6.0, Layers.TERRAIN | Layers.LIFT)
	if not hit.is_empty():
		at.y = (hit.position as Vector3).y + 0.05
	p.global_position = at
	p.reset_physics_interpolation()
	var dir := look_at - (at + Vector3.UP * 1.2)
	p.rotation.y = atan2(-dir.x, -dir.z)
	p.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _observer(from: Vector3, target: Vector3) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 70.0
		_cam.near = 0.05
		main.add_child(_cam)
	# Niet in de rots: van het doel naar `from` tot waar het nog open is.
	var pos := from
	if t.data_loaded(from) and t.sdf_at(from) < 0.4:
		var best := target
		for i in 40:
			var q := target.lerp(from, float(i) / 40.0)
			if t.sdf_at(q) < 0.4:
				break
			best = q
		pos = best
	_cam.global_position = pos
	_cam.look_at(target)
	_cam.make_current()


func _model() -> void:
	var r: Array = await _cave(60.0, Vector3(30.0, 0.0, -20.0), 11.0)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	# Licht: een warme lamp van de ploeg en het lichtbaken op de vloer.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.68)
	lamp.omni_range = 24.0
	lamp.light_energy = 2.2
	main.add_child(lamp)
	lamp.global_position = c + Vector3(-4.0, 3.0, 6.0)
	game.beacons._rpc_spawn(999, ground + Vector3(3.0, 0.6, 3.0), Vector3.ZERO)
	var vis: WormVisual = game.worm.visual
	var e := ground + Vector3(-7.0, -0.5, 0.0)
	var x := ground + Vector3(7.0, -0.5, 0.0)
	vis.hold_pose([e + Vector3(-2.0, -2.0, 0.0), e.lerp(x, 0.25) + Vector3.UP * 4.5, e.lerp(x, 0.75) + Vector3.UP * 4.5, x + Vector3(2.0, -2.0, 0.0)], 0.62, 0.8)
	var target := ground + Vector3(0.0, 2.6, 0.0)
	var head: Node3D = vis._head
	var t0 := _now()
	var dur := 9.0
	var snapped := false
	while _now() - t0 < dur:
		var a := lerpf(-0.6, 0.6, (_now() - t0) / dur)
		_observer(target + Vector3(sin(a) * 10.0, 1.0, cos(a) * 10.0), target)
		if not snapped and _now() - t0 > dur * 0.5:
			snapped = true
			await _snap("worm_model_zij")
		await get_tree().process_frame
	# Recht in de muil: de kaken open, de gloeiende keel.
	var hp := head.global_position
	var fwd := -head.global_basis.z
	_observer(hp + fwd * 6.0 + Vector3.UP * 0.4 + head.global_basis.x * 1.5, hp + fwd * 2.5)
	await _wait(0.6)
	await _snap("worm_model_muil")
	_observer(hp + fwd * 3.0 + head.global_basis.x * 5.5 + Vector3.UP * 1.0, hp + fwd * 1.5)
	await _wait(0.6)
	await _snap("worm_model_kop")


func _worm() -> void:
	var mol: Mol = game.mol
	var worm: Worm = game.worm
	# De piloot in de stoel, buitenzicht (dan staat de sonar rechtsonder in de HUD).
	p.set_physics_process(true)
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0.0, -1.45, -1.0)))
	await _wait(0.4)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.6)
	p.chase.activate()
	game.magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(0.2)
	Tuning.set_value("worm", "hunt_speed", 6.5)
	worm.pos = mol.body.global_position + Vector3(52.0, -14.0, 30.0)
	worm._net_pos = worm.pos
	worm.mode = Worm.Mode.HUNT
	worm._cool = 999.0
	worm._ram_cool = 999.0
	worm._noises.clear()
	worm.hear(mol.body.global_position, 6.0)
	await _wait(1.0)
	mol.press(Mol.Cmd.HORN)
	var t0 := _now()
	while _now() - t0 < 14.0 and worm.pos.distance_to(mol.body.global_position) > 16.0:
		await get_tree().process_frame
	_snap("worm_sonar_dichtbij")
	worm._ram_cool = 0.0
	await _wait(3.0)
	# Uitval naast de Mol, aan de oppervlakte (open ruimte).
	var side := mol.body.global_basis.x
	var aim := mol.body.global_position + side * 9.0
	aim.y = t.surface_height_at(aim.x, aim.z) + 0.2
	worm.pos = aim + Vector3(0.0, -8.0, 6.0)
	worm._cool = 0.0
	worm._try_lunge(aim)
	await _wait(1.6)
	_snap("worm_uitval_buiten")
	await _wait(3.5)


func _lunge() -> void:
	var worm: Worm = game.worm
	var r: Array = await _cave(45.0, Vector3(-35.0, 0.0, 15.0), 7.5)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	# De speler aan de rand van de grot, kijkend over de vloer: daar komt hij vandaan.
	_stand(ground + Vector3(3.0, 0.05, 0.0), ground + Vector3(-5.0, 0.4, 0.0))
	p.set_physics_process(true)
	game.magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(0.3)
	worm.pos = ground + Vector3(-26.0, -6.0, 0.0)
	worm._net_pos = worm.pos
	worm.mode = Worm.Mode.HUNT
	worm._target = ground + Vector3(2.0, -4.0, 0.0)
	worm._cool = 999.0
	worm._noises.clear()
	worm.hear(ground + Vector3(2.0, 0.5, 0.0), 3.0)
	var t0 := _now()
	while _now() - t0 < 7.0:
		await get_tree().process_frame
		if _now() - t0 > 4.0 and _now() - t0 < 4.05:
			_snap("lunge_gerommel")
	worm._cool = 0.0
	worm.pos = ground + Vector3(-12.0, -5.0, 0.0)
	worm._try_lunge(p.global_position)
	await _wait(1.0)
	_snap("lunge_waarschuwing")
	await _wait(0.9)
	_snap("lunge_boog")
	await _wait(4.0)


func _gas() -> void:
	var r: Array = await _cave(70.0, Vector3(35.0, 0.0, 25.0), 7.0)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	var gas: Gas = game.gas
	var pk := Gas.Pocket.new()
	pk.id = gas.pockets.size()
	pk.center = ground + Vector3(-2.0, 2.2, 0.0)
	pk.radius = 3.2
	gas.pockets.append(pk)
	gas._refresh_open(pk)
	pk.opened_at = -100.0
	_stand(ground + Vector3(4.5, 0.05, 0.0), pk.center)
	p.set_physics_process(true)
	p.select_tool(1)
	await _wait(3.0)
	_snap("gas_waas")
	# Boren: de boor raakt de wand achter de waas.
	p.drill.auto_use = true
	_stand(ground + Vector3(1.2, 0.05, 0.0), pk.center + Vector3(-3.4, -0.6, 0.0))
	var t0 := _now()
	while _now() - t0 < 3.0 and not pk.gone:
		await get_tree().process_frame
		if not pk.igniting and _now() - t0 > 1.0:
			gas.host_ignite(pk.id, pk.center) # zeker zijn van de vonk in de film
	p.drill.auto_use = false
	await _wait(0.25)
	_snap("gas_ontploffing")
	await _wait(4.0)


func _rescue() -> void:
	var mol: Mol = game.mol
	var rescue: Rescue = game.rescue
	# Een ploegmaat ligt 12 m van de Mol neer, aan de oppervlakte bij de klep.
	var back := mol.to_world_mol(Vector3(0.0, -1.5, 16.0))
	back.y = t.surface_height_at(back.x, back.z) + 0.1
	game._spawn(2, 1, back)
	var mate := game.player_node(2)
	await _wait(0.4)
	mate.global_position = back
	await _wait(0.2)
	rescue.host_damage(2, 2.0, Vector3(0.0, 2.0, 2.0), true, "film")
	await _wait(2.0)
	var side: bool = str(CmdArgs.value("cam", "")) == "side"
	var torso := rescue.ragdoll_of(2).torso.global_position
	p.set_physics_process(true)
	_stand(torso + mol.body.global_basis.z * 3.5 + Vector3(0.0, 0.3, 0.0), torso)
	p.global_position.y = t.surface_height_at(p.global_position.x, p.global_position.z) + 0.1
	if side:
		# Van opzij: de eigen robot is lokaal onzichtbaar (eerste persoon), dus voor de film een lijf erbij.
		_body = RobotRig.new()
		_body.name = "FilmRig"
		p.add_child(_body)
		_body.setup(p.color)
		_follow_cam()
	await _wait(1.0)
	_snap("rescue_neer")
	await _walk(torso + (p.global_position - torso).normalized() * 1.4, 1.2, side)
	rescue.request_carry(2)
	await _wait(0.5)
	_snap("rescue_dragen")
	# Naar de Mol lopen (de klep op), met de ploegmaat in de armen, aan de draagsnelheid.
	var goal := mol.to_world_mol(Vector3(0.0, -1.45, 1.0))
	await _walk(goal, Tuning.get_f("player", "move_speed", 4.5) * p.carry.move_multiplier(), side)
	if side:
		_follow_cam()
	await _wait(0.6)
	_snap("rescue_in_de_mol")
	await _until(func() -> bool: return rescue.life_of(2) == Rescue.Life.OK, 8.0)
	await _wait(0.6)
	_snap("rescue_gerepareerd")
	await _wait(1.5)


var _body: RobotRig


## Camera van opzij die de speler volgt (4,5 m opzij, iets hoger), voor de film van het redden.
func _follow_cam() -> void:
	var mol: Mol = game.mol
	var at := p.global_position + Vector3.UP * 0.8
	if mol.contains_point(p.global_position):
		# In de Mol: vanuit de cabine naar het laadruim kijken.
		_observer(mol.to_world_mol(Vector3(1.3, 0.3, -2.4)), at)
		return
	var b := Basis(Vector3.UP, p.rotation.y)
	_observer(at + b.x * 5.0 + b.z * 1.5 + Vector3.UP * 1.6, at - b.z * 0.8)


## Lopen zonder invoer (een film met venster vangt de muis niet altijd): de speler schuift aan
## `speed` naar `to`, op de vloer (rots of de Mol). Het oog kijkt mee.
func _walk(to: Vector3, speed: float, side: bool) -> void:
	p.set_physics_process(false)
	var mol: Mol = game.mol
	var t0 := _now()
	var last := _now()
	while _now() - t0 < 20.0:
		await get_tree().physics_frame
		var dt := _now() - last
		last = _now()
		var d := to - p.global_position
		d.y = 0.0
		if d.length() < 0.3:
			break
		p.rotation.y = atan2(-d.x, -d.z)
		p.head.rotation.x = deg_to_rad(-14.0)
		var next := p.global_position + d.normalized() * minf(speed * dt, d.length())
		var hit := t.raycast(next + Vector3.UP * 1.2, next + Vector3.DOWN * 2.0, Layers.TERRAIN | Layers.LIFT)
		if not hit.is_empty():
			next.y = (hit.position as Vector3).y + 0.02
		p.global_position = next
		if side and _cam:
			_follow_cam()
		if _body:
			_body.velocity = d.normalized() * speed
			_body.set_carrying(p.carry.body_peer >= 0)
	if _body:
		_body.velocity = Vector3.ZERO
	p.set_physics_process(true)


func _collapse() -> void:
	var r: Array = await _cave(110.0, Vector3(-30.0, 0.0, -30.0), 7.0)
	var c: Vector3 = r[0]
	var ground: Vector3 = r[1]
	var zone := Vector4(ground.x - 2.5, c.y + 4.0, ground.z, 4.0)
	game.unrest.zones = [zone] as Array[Vector4]
	_stand(ground + Vector3(4.5, 0.05, 2.0), Vector3(zone.x, zone.y - 2.0, zone.z))
	p.set_physics_process(true)
	await _wait(2.0)
	_snap("instorting_zone")
	game.collapse.host_collapse(zone)
	await _wait(0.9)
	_snap("instorting_stof")
	await _wait(2.4)
	_snap("instorting_rotsen")
	await _wait(2.0)
	# Puin wegbikken.
	var rubble: Rubble = null
	for rb: RigidBody3D in game.unrest._rocks:
		if rb is Rubble and (rb as Rubble).blocks and is_instance_valid(rb):
			rubble = rb
	if rubble:
		_stand(rubble.global_position + Vector3(1.6, -rubble.size * 0.5, 0.6), rubble.global_position)
		p.global_position.y = ground.y + 0.05
		await _wait(0.6)
		_snap("instorting_puin")
		p.pickaxe.auto_swing = true
		await _until(func() -> bool: return not is_instance_valid(rubble) or game.unrest.rock(rubble.rock_id) == null, 8.0)
		p.pickaxe.auto_swing = false
		await _wait(0.6)
		_snap("instorting_weggebikt")
	await _wait(1.0)


## De HUD onder de grond, het magma nog ver weg: met --legacy de oude regel (enkel binnen 60 m).
func _hud() -> void:
	var r: Array = await _cave(40.0, Vector3(25.0, 0.0, 25.0), 6.0)
	var ground: Vector3 = r[1]
	_stand(ground + Vector3(2.0, 0.05, 0.0), ground + Vector3(-3.0, 1.0, 0.0))
	game.magma.elapsed = 240.0
	await _wait(1.0)
	var legacy := CmdArgs.has("legacy")
	main.hud.hazard.far_rule = not legacy
	for i in 30:
		await get_tree().process_frame
	_snap("hud_magma_ver_%s" % ("voor" if legacy else "na"))
	if legacy:
		return
	# De worm dichtbij: de seismograaf; en in een gasbel.
	game.worm.mode = Worm.Mode.HUNT
	game.worm.activity = 0.8
	game.worm.pos = ground + Vector3(0.0, -6.0, 4.0)
	await _wait(1.5)
	_snap("hud_worm_dichtbij")
	game.rescue.host_damage(p.peer_id, 0.36, Vector3.ZERO, false, "film")
	await _wait(0.5)
	_snap("hud_robot_schade")
	game.rescue.host_damage(p.peer_id, 2.0, Vector3(1.0, 1.0, 0.0), true, "film")
	await _wait(1.2)
	_snap("hud_neer")


## Een lichtbaken in een donkere grot (gevoel2-07): de speler gooit het over de vloer, het licht en
## de veilige zone; daarna nadert de worm en zwemt weg.
func _beacon() -> void:
	var r: Array = await _cave(50.0, Vector3(-30.0, 0.0, -25.0), 9.0)
	var ground: Vector3 = r[1]
	_stand(ground + Vector3(6.0, 0.05, 0.0), ground + Vector3(-4.0, 0.0, 0.0))
	p.set_physics_process(true)
	game.magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(1.5)
	_snap("baken_voor")
	game.beacons.request_throw(p)
	await _wait(0.15)
	_snap("baken_worp")
	await _wait(2.6)
	_snap("baken_ligt")
	# De worm komt eraan, maar bij het baken valt hij niet uit.
	var worm: Worm = game.worm
	worm.pos = ground + Vector3(-30.0, -6.0, 0.0)
	worm._net_pos = worm.pos
	worm.mode = Worm.Mode.HUNT
	worm._cool = 0.0
	worm._noises.clear()
	worm.hear(ground + Vector3(-2.0, 0.5, 0.0), 6.0)
	await _wait(5.0)
	_snap("baken_worm")
	await _wait(2.0)


## De climax (ontwerp-7, ontwerp2-3): de hendel, dan rijdt de Mol achteruit terug over de vlakte
## (zoals na de hendel een spoor af, hier boven de grond zodat je de worm ziet). Twee vondsten in het
## laadruim. De worm achtervolgt met de climaxsnelheid.
func _climax() -> void:
	var mol: Mol = game.mol
	var worm: Worm = game.worm
	var inside: bool = str(CmdArgs.value("inside", "")) == "1"
	Tuning.set_value("mol", "countdown_s", 3.0)
	# Roestbol heeft een trage worm (×0,7): voor de film zo snel als op Fossielwereld (7,5 m/s).
	Tuning.set_value("worm", "climax_speed", 7.5 / maxf(0.1, HazardParams.of(game, "worm", 1.0)))
	game.magma.elapsed = 600.0
	# Het spoor: 220 m recht achter de Mol, op de grond (de rupsen op het oppervlak).
	var start := mol.body.global_position
	var back := mol.body.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var path: Array[Vector3] = []
	var n := 24
	for i in n + 1:
		var q := start + back * (220.0 * (1.0 - float(i) / n))
		q.y = t.surface_height_at(q.x, q.z) - Mol.TRACK_BOTTOM
		path.append(q)
	path[n] = start
	mol._path.assign(path)
	# Twee vondsten in het laadruim.
	var k := 0
	var cargo: Array[FindItem] = []
	for it: FindItem in game.finds.items:
		if it.freed or not it.carriers.is_empty():
			continue
		game.finds._free(it.find_id)
		await _wait(0.3)
		it.global_position = mol.to_world_mol(Vector3(-0.6 + 1.2 * k, -1.2, 2.4))
		it.linear_velocity = Vector3.ZERO
		it.reset_physics_interpolation()
		cargo.append(it)
		k += 1
		if k >= 2:
			break
	if str(CmdArgs.value("beacon", "")) == "1":
		# Een baken in het laadruim (zoals de ploeg het voor de hendel neerlegt).
		game.beacons._rpc_spawn(99, mol.to_world_mol(Vector3(0.0, -1.0, 1.0)), Vector3.ZERO)
	p.set_physics_process(true)
	if inside:
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw + PI), mol.to_world_mol(Vector3(0.0, -1.45, 0.4)))
		p.head.rotation.x = deg_to_rad(-12.0)
	else:
		p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0.0, -1.45, -1.0)))
		await _wait(0.4)
		mol.press(Mol.Cmd.SEAT)
		await _wait(0.6)
		p.chase.activate()
	await _wait(0.5)
	print(TAG, " climax: lading bij de start %s" % [mol.cargo_contents().map(func(i: FindItem) -> String: return "%d%%" % int(i.condition * 100))])
	# De worm komt van achter (waar de Mol vandaan rijdt), 30 m weg.
	worm.pos = start - back * 30.0 + mol.body.global_basis.x * 10.0 + Vector3(0.0, -10.0, 0.0)
	worm._net_pos = worm.pos
	worm.vel = Vector3.ZERO
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm._cool = 0.0
	worm._ram_cool = 0.0
	mol.press(Mol.Cmd.DEPART)
	var t0 := _now()
	var shots := 0
	var rams := [0]
	worm.rammed.connect(func(_a: Vector3) -> void: rams[0] += 1)
	while _now() - t0 < 48.0 and (mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING] or _now() - t0 < 1.0):
		await get_tree().process_frame
		if _now() - t0 > 6.0 + shots * 6.0 and shots < 4:
			_snap("climax_%d" % shots)
			shots += 1
	print(TAG, " climax: %d keer geramd in %.0f s, lading %s" % [rams[0], _now() - t0, cargo.map(func(i: FindItem) -> String: return "%d%%" % int(i.condition * 100))])
	await _wait(1.0)


## Grijpen en redden (G1): de worm valt uit onder een ploegmaat, grijpt hem en sleurt hem weg; de
## speler loopt erheen en slaat de kop twee keer met het houweel, dan laat hij los.
func _grab() -> void:
	var worm: Worm = game.worm
	var ground := Vector3.ZERO
	var sc := t.starter_cave()
	if str(CmdArgs.value("starter", "")) == "1" and sc.w > 0.0:
		# In de startgrot van G5 (het kamp, de oude toegangsgang): niets graven, de vloer opzoeken.
		var c := Vector3(sc.x, sc.y, sc.z)
		p.set_physics_process(false)
		p.global_position = c
		while not t.is_area_ready(c, sc.w + 6.0):
			await _wait(0.2)
		await _wait(1.0)
		var fl := t.raycast(c, c + Vector3.DOWN * (sc.w + 4.0))
		ground = (fl.position as Vector3) if not fl.is_empty() else c + Vector3.DOWN * sc.w / PlanetGenerator.CAVERN_SQUASH
		print(TAG, " startgrot op %s (straal %.0f m), vloer %s" % [c, sc.w, ground])
	else:
		var r: Array = await _cave(45.0, Vector3(-35.0, 0.0, 15.0), 10.0)
		ground = r[1]
	game._spawn(2, 1, ground + Vector3(0.0, 0.5, 0.0))
	var mate := game.player_node(2)
	await _wait(0.3)
	var spot := ground + Vector3(-1.0, 0.05, 0.0)
	var hit := t.raycast(spot + Vector3.UP * 2.0, spot + Vector3.DOWN * 4.0)
	if not hit.is_empty():
		spot = (hit.position as Vector3) + Vector3.UP * 0.05
	mate.global_position = spot
	_stand(ground + Vector3(6.0, 0.05, 1.5), spot + Vector3.UP * 0.6)
	p.set_physics_process(true)
	p.select_tool(0)
	game.magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(1.5)
	worm.mode = Worm.Mode.HUNT
	worm.pos = spot + Vector3(-12.0, -6.0, 0.0)
	worm._net_pos = worm.pos
	worm._cool = 0.0
	worm._grab_cool = 0.0
	worm._try_lunge(spot)
	var t0 := _now()
	var shots := {}
	while _now() - t0 < 6.0 and not worm.holds(2):
		await get_tree().process_frame
		if game.rescue.is_ok(2):
			mate.global_position = spot
		var dt := _now() - t0
		if dt > 1.0 and not shots.has("w"):
			shots["w"] = true
			_snap("grab_waarschuwing")
		if dt > Tuning.get_f("worm", "telegraph_s", 1.6) + 0.5 and not shots.has("u"):
			shots["u"] = true
			_snap("grab_uitval")
	await _wait(0.6)
	_snap("grab_gegrepen")
	await _wait(1.6)
	_snap("grab_sleuren")
	# Erheen lopen en de kop slaan.
	p.set_physics_process(false)
	var t1 := _now()
	var last := _now()
	while _now() - t1 < 12.0 and worm.holds(2):
		await get_tree().physics_frame
		var dt := _now() - last
		last = _now()
		var head := worm.head_world()
		var rd := game.rescue.ragdoll_of(2)
		if head == Vector3.INF or rd == null:
			continue
		# Naast zijn prooi gaan staan (opzij van het spoor, aan de kant van de speler), en de kop slaan.
		var prey := rd.torso.global_position
		var side := (head - prey).cross(Vector3.UP)
		side.y = 0.0
		side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
		if side.dot(p.global_position - prey) < 0.0:
			side = -side
		var goal := prey.lerp(head, 0.5) + side * 2.3
		var to := goal - p.global_position
		to.y = 0.0
		if to.length() > 0.4:
			var next := p.global_position + to.normalized() * minf(5.0 * dt, to.length())
			var down := t.raycast(next + Vector3.UP * 1.2, next + Vector3.DOWN * 2.0, Layers.TERRAIN)
			if not down.is_empty():
				next.y = (down.position as Vector3).y + 0.02
			p.global_position = next
			p.pickaxe.auto_swing = false
		else:
			p.pickaxe.auto_swing = true
		var look := head - p.camera.global_position
		p.rotation.y = atan2(-look.x, -look.z)
		p.head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
		if p.pickaxe.auto_swing and not shots.has("s"):
			shots["s"] = true
			_snap("grab_slaan")
	p.pickaxe.auto_swing = false
	p.set_physics_process(true)
	await _wait(0.4)
	_snap("grab_los")
	print(TAG, " grab: los = %s" % [not worm.holds(2)])
	await _wait(2.5)


func _snap(name: String) -> void:
	var dir := str(CmdArgs.value("out", "C:/Dev/Diepgang/logs/review_fix/F2/beelden"))
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var path := dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print(TAG, " ", path)


## Speltijd (Movie Maker rekt de echte tijd: altijd in speltijd meten).
var _gt := 0.0


func _process(delta: float) -> void:
	_gt += delta


func _now() -> float:
	return _gt


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _until(cond: Callable, timeout: float) -> bool:
	var t0 := _now()
	while _now() - t0 < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()
