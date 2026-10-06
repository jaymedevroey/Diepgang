extends Node
## Meting van de worm tegen de Mol (pakket G1, ontwerp2-1 en ontwerp2-3). De echte Worm- en Mol-code,
## versneld (Engine.time_scale 3), per planeet (seed 777 + planeet, zoals de meting van ronde 2).
## A. Midden in de dienst (magmaklok 5:00): de Mol rijdt 120 s in cirkels met vol gas, twee vondsten in
##    het laadruim, de worm begint 60 m weg. Hoe vaak raakt hij de Mol, en wat verliest de lading?
## B. De climax: de hendel, dan rijdt de Mol ±400 m terug langs een spoor 12 m diep; de worm begint
##    ±55 m weg. Drie keer: zonder iets, met een baken in de Mol, en met een ploeg die iets doet (een
##    baken uit de achterklep als de worm dichtbij is, en losslaan als hij bijt).
## tools\godot.cmd --headless --path game -- --scenario=worm_balance --no-steam [--only=mid|climax] [--out=pad]

const TAG := "[worm_balance]"

var main: Node
var _out := PackedStringArray()
var _hits := 0
var _bites := 0


func _ready() -> void:
	main.game.world_loaded.connect(func(_s: Dictionary) -> void: _on_world.call_deferred(), CONNECT_ONE_SHOT)
	get_tree().create_timer(1500.0).timeout.connect(func() -> void:
		_p("time-out")
		_flush()
		get_tree().quit(1))


func _p(s: String) -> void:
	print(TAG, " ", s)
	_out.append(s)


func _on_world() -> void:
	await get_tree().process_frame
	Engine.time_scale = 3.0
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var only := str(CmdArgs.value("only", ""))
	for planet in 3:
		game.host_new_world(777 + planet, planet)
		await game.world_loaded
		await _wait(1.0)
		HazardParams.clear()
		var worm: Worm = game.worm
		worm.rammed.connect(_on_hit)
		_p("=== %s (worm ×%.1f)" % [PlanetType.NAMES[planet], HazardParams.of(game, "worm", 1.0)])
		var home: Vector3 = game.mol.body.global_position
		var home_yaw: float = game.mol.yaw
		if only != "climax":
			await _mid(game)
		if only != "mid":
			for how in ["niets", "baken in de Mol", "ploeg doet iets"]:
				# Elke rit vanaf dezelfde plek (anders staat de Mol al aan het einde van zijn spoor).
				game.mol._rpc_mode(Mol.Mode.PARKED, 0, 0.0)
				game.mol.teleport(home, home_yaw, 0.0)
				await _wait(0.5)
				await _climax(game, how)
		worm.rammed.disconnect(_on_hit)
	_flush()
	Engine.time_scale = 1.0
	get_tree().quit(0)


func _on_hit(_at: Vector3) -> void:
	_hits += 1


## Twee vondsten in het laadruim (vrij, stil neergezet).
func _load_cargo(game: Game) -> Array[FindItem]:
	var mol: Mol = game.mol
	var out: Array[FindItem] = []
	for it: FindItem in game.finds.items:
		if it.freed or not it.carriers.is_empty():
			continue
		game.finds._free(it.find_id)
		await _wait(0.3)
		it.global_position = mol.to_world_mol(Vector3(-0.6 + 1.2 * out.size(), -1.2, 2.4))
		it.linear_velocity = Vector3.ZERO
		it.reset_physics_interpolation()
		out.append(it)
		if out.size() >= 2:
			break
	await _wait(0.5)
	return out


func _loss(items: Array[FindItem]) -> int:
	var lost := 0.0
	for it in items:
		lost += 1.0 - it.condition
	return int(round(lost / maxf(1.0, items.size()) * 100.0))


func _mid(game: Game) -> void:
	var worm: Worm = game.worm
	var mol: Mol = game.mol
	var magma: Magma = game.magma
	magma.elapsed = 300.0
	var cargo := await _load_cargo(game)
	worm.mode = Worm.Mode.ROAM
	worm.pos = mol.body.global_position + Vector3(60.0, -12.0, 0.0)
	worm.vel = Vector3.ZERO
	worm._noises.clear()
	worm._cool = 0.0
	worm._ram_cool = 0.0
	_hits = 0
	var first := -1.0
	var tt := 0.0
	var closest := INF
	mol._rpc_mode(Mol.Mode.DRIVING, 0, 0.0)
	while tt < 120.0:
		# Vol gas en een beetje sturen (een grote cirkel), zoals een speler die naar de volgende blip rijdt.
		mol._input = Vector3(1.0, 0.35, 0.0)
		mol._input_time = Time.get_ticks_msec() / 1000.0
		await get_tree().physics_frame
		tt += get_physics_process_delta_time()
		closest = minf(closest, worm.pos.distance_to(mol.body.global_position))
		if _hits > 0 and first < 0.0:
			first = tt
	mol._input = Vector3.ZERO
	mol._rpc_mode(Mol.Mode.PARKED, 0, 0.0)
	_p("midden (min 5), de Mol rijdt 120 s, worm start 61 m weg: %d keer geraakt (eerste na %.0f s), het dichtst %.0f m → lading −%d%%" % [
			_hits, first, closest, _loss(cargo)])
	for it in cargo:
		it.condition = 1.0


func _climax(game: Game, how: String) -> void:
	var worm: Worm = game.worm
	var mol: Mol = game.mol
	var magma: Magma = game.magma
	var t: TerrainAPI = game.terrain
	# Een spoor van ±400 m: een boog op 12 m diep rond het midden van de concessie (straal 80 m), zoals
	# de meting van ronde 2 (de Mol rijdt naar het begin van de boog en dan de boog af).
	var c := t.shaft_center_world()
	var path: Array[Vector3] = []
	for i in 31:
		var a := float(30 - i) / 30.0 * 3.75
		var px := c.x + cos(a) * 80.0
		var pz := c.z + sin(a) * 80.0
		path.append(Vector3(px, t.surface_height_at(px, pz) - 12.0, pz))
	mol._rpc_mode(Mol.Mode.PARKED, 0, 0.0)
	magma.elapsed = 600.0
	await _wait(0.5)
	path.append(mol.body.global_position) # het laatste punt van het spoor is waar de Mol nu staat
	mol._path = path
	var cargo := await _load_cargo(game)
	for it in cargo:
		it.condition = 1.0
	var start: Vector3 = mol.body.global_position
	worm.mode = Worm.Mode.ROAM
	worm.pos = start + Vector3(-45.0, -15.0, 30.0)
	worm.vel = Vector3.ZERO
	worm._noises.clear()
	worm._cool = 0.0
	worm._ram_cool = 0.0
	var beacons: Beacons = game.beacons
	beacons._rpc_left.rpc(3)
	if how == "baken in de Mol":
		beacons._rpc_spawn.rpc(990 + randi() % 9, mol.to_world_mol(Vector3(0.0, -1.0, 2.0)), Vector3.ZERO)
	var crew := how == "ploeg doet iets"
	_hits = 0
	_bites = 0
	var dropped := 0
	var freed := 0
	var drop_cd := 0.0
	var shake_t := 0.0
	var shake_sign := 1.0
	mol.host_emergency(10.0, "test")
	var tt := 0.0
	var travelled := 0.0
	var last: Vector3 = mol.body.global_position
	while mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING] and tt < 200.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		tt += dt
		drop_cd -= dt
		travelled += mol.body.global_position.distance_to(last)
		last = mol.body.global_position
		if crew and mol.mode == Mol.Mode.EXTRACTING and beacons.has_method("launch_point"):
			# De ploeg kijkt naar de sonar: is de worm binnen 20 m, dan gaat er een baken uit de
			# achterklep (hooguit om de 12 s, zolang er bakens zijn; zoals Beacons.host_launch).
			if beacons.left > 0 and drop_cd <= 0.0 and worm.pos.distance_to(mol.body.global_position) < 20.0 and not worm.biting():
				beacons._rpc_left.rpc(beacons.left - 1)
				beacons._rpc_spawn.rpc(800 + dropped, beacons.launch_point(mol), Vector3.ZERO)
				dropped += 1
				drop_cd = 12.0
			# Bijt hij, dan schudt de piloot hem los: na ±1,2 s reageren, om de 0,25 s links-rechts.
			if worm.biting():
				shake_t += dt
				if shake_t > 1.2 and fmod(shake_t, 0.25) < dt:
					shake_sign = -shake_sign
					worm.host_shake(shake_sign)
					freed += 1
			else:
				shake_t = 0.0
	if worm.has_method("bites_done"):
		_bites = worm.bites_done()
	_p("climax (%s): %d keer geraakt in %.0f s over %.0f m%s → lading −%d%%" % [how, _hits, tt, travelled,
			(", %d bakens uit de klep, %d keer geschud" % [dropped, freed]) if crew else "", _loss(cargo)])
	if mol.mode != Mol.Mode.PARKED:
		mol._rpc_mode(Mol.Mode.PARKED, 0, 0.0)
	for b: RigidBody3D in beacons._items.values():
		if is_instance_valid(b):
			b.queue_free()
	beacons._items.clear()
	beacons._stowed.clear()
	for r: Decal in beacons._rings.values():
		if is_instance_valid(r):
			r.queue_free()
	beacons._rings.clear()


func _wait(s: float) -> void:
	var acc := 0.0
	while acc < s:
		await get_tree().physics_frame
		acc += get_physics_process_delta_time()


func _flush() -> void:
	var path := str(CmdArgs.value("out", ""))
	if path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_out) + "\n")
