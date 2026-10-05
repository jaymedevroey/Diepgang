class_name Worm
extends Node3D
## De Graafworm (GDD §6), het enige wezen in Early Access. Staat op elk peer op Game/Worm.
## - Zwemt onzichtbaar door de rots en verandert het terrein niet. Je merkt hem aan gerommel, stof
##   uit het plafond en een markering op de vloer (barsten, springende steentjes) boven waar hij zwemt,
##   en op de sonar van de Mol als een grote stip die nadert (playtest 2026-10-06).
## - Komt af op lawaai: boorhappen, de Mol die boort of rijdt, een PING, de toeter, een ontploffing,
##   de Mol die vertrekt. Hij weet niet waar je bent, enkel waar het lawaai was.
## - Valt enkel uit in open ruimtes (grotten, de tunnel van de Mol, de oppervlakte): in een smalle,
##   zelfgegraven gang ben je veilig. Eerst een waarschuwing (barsten, stofgeiser, gerommel), dan een
##   boog door de ruimte: wie geraakt wordt gaat omver (Rescue), losse buit wordt opgeslokt en ergens
##   ver weg in een grot gedumpt (je kan hem gaan zoeken).
## - Lichtbakens (Beacons) houden hem op afstand: daar valt hij niet uit, hij zwemt weg.
## - Op het einde van de dienst (het magma dichtbij, de Mol vertrekt) is hij sneller en valt hij vaker
##   uit; de Mol die vertrekt lokt hem, en hij ramt de Mol op de terugweg (de lading lijdt, de Mol valt
##   stil): ontwerp-7, de climax.
## Netwerk: de host simuleert (plek, aandacht, uitvallen, wie geraakt wordt); de clients krijgen de plek
## 8× per seconde en elke uitval als plan (dezelfde boog op elk peer, zoals de rotsen van een beving).

enum Mode { SLEEP, ROAM, HUNT, LUNGE, CARRY, REPELLED }

## Hij begint een uitval (op elk peer; voor geluid en tests). `at`: waar hij uit de rots komt.
signal lunge_started(at: Vector3)
## Hij slokte een vondst op (op elk peer).
signal swallowed(find_id: int)
## Hij dumpte vondsten in een grot (op elk peer).
signal spat(find_ids: PackedInt32Array)
## Hij ramde de Mol (op elk peer).
signal rammed(at: Vector3)

const SYNC_INTERVAL := 0.125
## Drager-id van opgeslokte buit (geen speler heeft deze id).
const BELLY := -7

var game: Node # Game
var mode := Mode.SLEEP
## Plek van de kop (wereld, in de rots). Host: gesimuleerd; clients: van de host, vloeiend.
var pos := Vector3.ZERO
var vel := Vector3.ZERO
## Hoe onrustig (0 = slaapt, 1 = valt uit), voor gerommel en de sonar.
var activity := 0.0
var visual: WormVisual

# Host.
var _target := Vector3.ZERO
var _noises: Array = [] # [plek, luidheid, tijd (s)]
var _cool := 20.0
var _ram_cool := 0.0
var _wander_t := 0.0
var _repel_t := 0.0
var _carried := PackedInt32Array()
var _lair := Vector3.ZERO
var _lunge: Dictionary = {} # host: lopende uitval
var _sync_t := 0.0
var _rng := RandomNumberGenerator.new()
var _clock := 0.0 # speltijd (s): lawaai vervaagt in speltijd
var _mol_noise_t := 0.0
var _last_mode_mol := -1
# Clients.
var _net_pos := Vector3.ZERO
# Tekens (lokaal).
var _marker_t := 0.0
var _marker: Decal
var _marker_k := 0.0
var _dust_t := 0.0


func _ready() -> void:
	_rng.randomize()
	visual = WormVisual.new()
	visual.name = "Visual"
	visual.worm = self
	add_child(visual)
	_marker = Decal.new()
	_marker.name = "Marker"
	_marker.size = Vector3(3.4, 2.0, 3.4)
	_marker.texture_albedo = _crack_texture()
	_marker.modulate = Color(0.12, 0.09, 0.07)
	_marker.albedo_mix = 0.85
	_marker.upper_fade = 0.5
	_marker.lower_fade = 0.5
	_marker.visible = false
	add_child(_marker)


## Nieuwe wereld: slapen, diep in een grot ver van de landingsplek.
func attach_terrain(terrain: TerrainAPI) -> void:
	mode = Mode.SLEEP
	activity = 0.0
	vel = Vector3.ZERO
	_noises.clear()
	_carried = PackedInt32Array()
	_lunge = {}
	_cool = 20.0
	_ram_cool = 0.0
	_last_mode_mol = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.pit_seed * 3301 + 5
	var c := terrain.shaft_center_world()
	var caves := terrain.caverns()
	var best := Vector3(c.x + 60.0, 90.0, c.z + 60.0)
	var best_d := -1.0
	for i in 8:
		if caves.is_empty():
			break
		var cv: Vector4 = caves[rng.randi() % caves.size()]
		var d := Vector2(cv.x - c.x, cv.z - c.z).length()
		if d > best_d and cv.y < terrain.surface_height_at(cv.x, cv.z) - 80.0:
			best_d = d
			best = Vector3(cv.x, cv.y - cv.w / PlanetGenerator.CAVERN_SQUASH - 6.0, cv.z)
	pos = best
	_net_pos = pos
	_target = pos
	if visual:
		visual.stop()
	_marker.visible = false


# --- Vragen -----------------------------------------------------------------------------------

## Spanning van de dienst (0..1): hoe dicht het magma bij de noodophaling staat. Vertrekt de Mol
## (aftellen, terugrit, de grijper), dan 1: de climax.
func tension() -> float:
	var magma: Magma = game.magma
	if magma == null or not magma.running:
		return 0.0
	var mol: Mol = game.mol
	if mol and mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING, Mol.Mode.GRAPPLE_DOWN]:
		return 1.0
	var start := Tuning.get_f("magma", "start_depth", 310.0)
	var recall := Tuning.get_f("magma", "recall_depth", 60.0)
	return clampf(inverse_lerp(start, recall, magma.depth()), 0.0, 1.0)


func is_awake() -> bool:
	return mode != Mode.SLEEP


## De sonar van de Mol: waar de worm lijkt te zitten (onzeker, meer met lawaai), en hoe sterk (0 = niet
## te zien). Grote stip; een PING maakt hem scherp.
func sonar_echo(origin: Vector3, noise: float, sharp: bool) -> Dictionary:
	var shown := pos if multiplayer.is_server() else _net_pos
	var d := origin.distance_to(shown)
	var reach := Tuning.get_f("worm", "sonar_m", 70.0)
	if mode == Mode.SLEEP or d > reach:
		return {"on": false}
	var t := Time.get_ticks_msec() / 1000.0
	var wobble := (2.5 + 4.0 * noise) * (0.3 if sharp else 1.0)
	var jitter := Vector3(sin(t * 1.3 + 0.7), 0.0, cos(t * 1.1)) * wobble
	var strength := clampf(1.0 - d / reach, 0.15, 1.0) * clampf(activity + 0.4, 0.0, 1.0)
	return {"on": true, "pos": shown + jitter, "strength": strength, "dist": d}


# --- Horen (host) -------------------------------------------------------------------------------

## Host: lawaai op `where` met deze luidheid. Dichtbij elkaar telt samen.
func hear(where: Vector3, loudness: float) -> void:
	if not multiplayer.is_server() or loudness <= 0.0:
		return
	var now := _clock
	for n: Array in _noises:
		if (n[0] as Vector3).distance_to(where) < 6.0:
			var keep := _fade(n, now)
			n[0] = (n[0] as Vector3).lerp(where, 0.5)
			n[1] = minf(keep + loudness, 12.0)
			n[2] = now
			return
	_noises.append([where, minf(loudness, 12.0), now])
	if _noises.size() > 24:
		_noises.pop_front()


## Host: een speler groef (TerrainSync). Enkel de boor is luid (het houweel is stil).
func host_player_op(_sender: int, op: Dictionary) -> void:
	if op.get("op", -1) == TerrainAPI.Op.SPHERE_REMOVE and int(op.get("tool", -1)) >= Strata.Tool.BOOR_T1 and op.has("h"):
		hear(op.h, Tuning.get_f("worm", "loud_drill_bite", 0.12) * _mult())


## Host: de Mol maakte lawaai (PING, toeter): onrust-eenheden omgerekend naar luidheid.
func host_mol_noise(amount: float, where: Vector3) -> void:
	hear(where, amount * Tuning.get_f("worm", "loud_per_unrest", 0.25) * _mult())


func _fade(n: Array, now: float) -> float:
	return float(n[1]) * exp(-(now - float(n[2])) / maxf(1.0, Tuning.get_f("worm", "memory_s", 25.0)))


func _score(n: Array, now: float) -> float:
	var d := (n[0] as Vector3).distance_to(pos)
	var h := Tuning.get_f("worm", "hear_m", 45.0) * (1.0 + 0.5 * tension())
	return _fade(n, now) / (1.0 + (d / h) * (d / h))


func _mult() -> float:
	return HazardParams.of(game, "worm", 1.0)


# --- Verloop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if game == null or game.terrain == null:
		return
	if multiplayer.is_server():
		_host_step(delta)
		_sync_t += delta
		if _sync_t >= SYNC_INTERVAL:
			_sync_t = 0.0
			_rpc_state.rpc(pos, mode, activity)
	else:
		pos = pos.lerp(_net_pos, minf(1.0, delta * 6.0))
	var want := 0.0
	match mode:
		Mode.ROAM, Mode.REPELLED:
			want = 0.4
		Mode.HUNT, Mode.CARRY:
			want = 0.75
		Mode.LUNGE:
			want = 1.0
	activity = move_toward(activity, want, delta * 0.8) if multiplayer.is_server() else activity
	_signs(delta)


func _host_step(dt: float) -> void:
	var magma: Magma = game.magma
	if magma == null or not magma.running:
		return
	_cool -= dt
	_ram_cool -= dt
	var mult := _mult()
	if mode == Mode.SLEEP:
		if magma.elapsed * mult >= Tuning.get_f("worm", "wake_s", 150.0):
			mode = Mode.ROAM
			print("[worm] wakker na %.0f s" % magma.elapsed)
		return
	_feed_mol(dt)
	var now := _clock
	var tens := tension()
	var speed := Tuning.get_f("worm", "roam_speed", 2.5)
	match mode:
		Mode.ROAM:
			_wander_t -= dt
			if _wander_t <= 0.0 or pos.distance_to(_target) < 4.0:
				_wander_t = 15.0
				_target = _wander_point()
			_pick_noise(now, tens)
		Mode.HUNT:
			speed = lerpf(Tuning.get_f("worm", "hunt_speed", 4.5), Tuning.get_f("worm", "climax_speed", 7.5), tens)
			if not _pick_noise(now, tens):
				mode = Mode.ROAM
			elif pos.distance_to(_target) < Tuning.get_f("worm", "lunge_reach", 9.0) + 5.0:
				_strike(now)
		Mode.LUNGE:
			return
		Mode.CARRY:
			speed = Tuning.get_f("worm", "hunt_speed", 4.5)
			_target = _lair
			if pos.distance_to(_lair) < 5.0:
				_deposit()
		Mode.REPELLED:
			speed = Tuning.get_f("worm", "hunt_speed", 4.5)
			_repel_t -= dt
			if _repel_t <= 0.0:
				mode = Mode.ROAM
				_wander_t = 0.0
	speed *= mult
	_swim(dt, speed)
	_carry_loot()


## Continu lawaai van de Mol (boren, rijden) en het vertrek (de motor spint op: dat lokt hem).
func _feed_mol(dt: float) -> void:
	var mol: Mol = game.mol
	if mol == null or mol.body == null or mol.mode == Mol.Mode.DOCKED:
		return
	if mol.mode != _last_mode_mol:
		if mol.mode == Mol.Mode.COUNTDOWN:
			hear(mol.placed.origin, Tuning.get_f("worm", "loud_depart", 6.0) * _mult())
		_last_mode_mol = mol.mode
	_mol_noise_t += dt
	if _mol_noise_t < 0.5:
		return
	var loud := 0.0
	if mol.drilling:
		loud += Tuning.get_f("worm", "loud_mol_drill", 1.2)
	var top := maxf(0.1, Tuning.get_f("mol", "open_speed", 1.8))
	loud += Tuning.get_f("worm", "loud_mol_drive", 0.6) * clampf(absf(mol.speed) / top, 0.0, 1.0)
	if mol.mode == Mol.Mode.EXTRACTING:
		loud += Tuning.get_f("worm", "loud_mol_drill", 1.2) # de terugrit: de motor op volle toeren
	if loud > 0.0:
		hear(mol.body.global_position, loud * _mol_noise_t * _mult())
	_mol_noise_t = 0.0


## Het luidste lawaai dat hij hoort (boven de drempel): daar gaat hij heen. False als er niets is.
func _pick_noise(now: float, tens: float) -> bool:
	var best: Array = []
	var best_s := 0.0
	for n: Array in _noises:
		var s := _score(n, now)
		if s > best_s:
			best_s = s
			best = n
	_noises = _noises.filter(func(n: Array) -> bool: return _fade(n, now) > 0.02)
	var need := Tuning.get_f("worm", "hunt_score", 0.35) * lerpf(1.0, 0.5, tens)
	if best.is_empty() or best_s < need:
		return false
	_target = best[0]
	if mode == Mode.ROAM:
		mode = Mode.HUNT
		print("[worm] jaagt op lawaai bij %s (score %.2f)" % [_target, best_s])
	return true


## Rondzwerven in de buurt van de ploeg, wat lager dan zij: dreiging in het midden van de dienst.
func _wander_point() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for pl: Player in game.players.get_children():
		sum += pl.global_position
		n += 1
	var mol: Mol = game.mol
	if n == 0 and mol and mol.body:
		sum = mol.body.global_position
		n = 1
	var c := sum / maxi(n, 1)
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(18.0, 40.0)
	return Vector3(c.x + cos(a) * r, c.y - _rng.randf_range(6.0, 16.0), c.z + sin(a) * r)


func _swim(dt: float, speed: float) -> void:
	var t: TerrainAPI = game.terrain
	var to := _target - pos
	var want := to.normalized() * speed if to.length() > 0.5 else Vector3.ZERO
	# Bakens: wegzwemmen.
	var beacons: Beacons = game.beacons
	if beacons:
		var b := beacons.nearest(pos)
		var r := Tuning.get_f("worm", "repel_m", 14.0)
		if b != Vector3.INF and b.distance_to(pos) < r:
			want += (pos - b).normalized() * speed * 1.5
	vel = vel.lerp(want, minf(1.0, dt * Tuning.get_f("worm", "turn_rate", 1.6)))
	pos += vel * dt
	# Binnen de concessie, boven het magma, onder het oppervlak.
	var size := t.world_size()
	pos.x = clampf(pos.x, 10.0, size.x - 10.0)
	pos.z = clampf(pos.z, 10.0, size.z - 10.0)
	var magma: Magma = game.magma
	var floor_y := (magma.level if magma.visible else 0.0) + Tuning.get_f("worm", "min_above_magma", 12.0)
	var ceil_y := t.surface_height_at(pos.x, pos.z) - Tuning.get_f("worm", "below_surface", 4.0)
	pos.y = clampf(pos.y, minf(floor_y, ceil_y - 2.0), ceil_y)


## Host: dicht bij het lawaai. Is er iemand of losse buit in een open ruimte, dan valt hij uit; was
## het de Mol, dan ramt hij hem. Anders verliest hij zijn interesse in dat lawaai.
func _strike(now: float) -> void:
	var mol: Mol = game.mol
	var reach := Tuning.get_f("worm", "lunge_reach", 9.0)
	# De Mol (gelokt: toeter, vertrek, of hij rijdt luid terug).
	if mol and mol.body and _ram_cool <= 0.0 and _target.distance_to(mol.body.global_position) < 10.0 \
			and pos.distance_to(mol.body.global_position) < Tuning.get_f("worm", "ram_m", 7.0) + 6.0 \
			and mol.mode in [Mol.Mode.PARKED, Mol.Mode.DRIVING, Mol.Mode.AUTO_DOWN, Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING, Mol.Mode.GRAPPLE_DOWN]:
		_ram(mol)
		return
	if _cool > 0.0:
		return
	var aim := Vector3.INF
	var best := INF
	for pl: Player in game.players.get_children():
		if pl.seated or not game.rescue or game.rescue.life_of(pl.peer_id) == Rescue.Life.BROKEN:
			continue
		if mol and mol.body and mol.contains_point(pl.global_position):
			continue
		var d := pl.global_position.distance_to(_target)
		if d < reach + 4.0 and d < best:
			best = d
			aim = pl.global_position
	if aim == Vector3.INF:
		for it: FindItem in game.finds.items:
			if not it.freed or not it.carriers.is_empty() or (mol and mol.body and mol.contains_point(it.global_position)):
				continue
			var d := it.global_position.distance_to(_target)
			if d < reach and d < best:
				best = d
				aim = it.global_position
	if aim == Vector3.INF or not _try_lunge(aim):
		# Niets te pakken of geen ruimte: dit lawaai is niets meer waard.
		for n: Array in _noises:
			if (n[0] as Vector3).distance_to(_target) < 8.0:
				n[1] = float(n[1]) * 0.25
		_cool = maxf(_cool, 4.0)


## Host: een uitval naar `aim` plannen (enkel in een open ruimte, niet bij een baken).
func _try_lunge(aim: Vector3) -> bool:
	var t: TerrainAPI = game.terrain
	var beacons: Beacons = game.beacons
	if beacons and beacons.nearest(aim).distance_to(aim) < Tuning.get_f("worm", "repel_m", 14.0):
		_repel()
		return false
	var open := Tuning.get_f("worm", "open_m", 1.2)
	var floor_hit := t.raycast(aim + Vector3.UP * 1.0, aim + Vector3.DOWN * 3.0)
	var ground: Vector3 = floor_hit.position if not floor_hit.is_empty() else aim
	# Open ruimte: 2 m boven de vloer nog minstens open_m vrij rondom (een zelfgegraven gang is te krap).
	var mid := ground + Vector3.UP * 2.0
	if not t.data_loaded(mid) or t.sdf_at(mid) < open:
		return false
	var dir := Vector3(aim.x - pos.x, 0.0, aim.z - pos.z)
	if dir.length() < 0.5:
		dir = Vector3(cos(_rng.randf() * TAU), 0.0, sin(_rng.randf() * TAU))
	dir = dir.normalized()
	var half := Tuning.get_f("worm", "arc_len", 9.0) * 0.5
	var e := _surface_along(ground, -dir, half)
	var x := _surface_along(ground, dir, half)
	if e.is_empty() or x.is_empty():
		return false
	# De kop gaat in het midden op arc_height boven de vloer door (borsthoogte: wie daar staat, ligt).
	var h := Tuning.get_f("worm", "arc_height", 1.3)
	var ceil_hit := t.raycast(mid, mid + Vector3.UP * (h + 2.0))
	if not ceil_hit.is_empty():
		h = clampf((ceil_hit.position as Vector3).y - ground.y - 1.2, 0.8, h)
	var en: Vector3 = e.normal
	var xn: Vector3 = x.normal
	var ep: Vector3 = e.position
	var xp: Vector3 = x.position
	var p0: Vector3 = ep - en * 2.2
	var p3: Vector3 = xp - xn * 2.2
	# B(0,5) = (p0 + 3 p1 + 3 p2 + p3) / 8: de hoogte van p1 en p2 zo kiezen dat de top op de vloer + h ligt.
	var peak := ground.y + h
	var cy := (8.0 * peak - p0.y - p3.y) / 6.0
	var p1 := ep.lerp(xp, 0.25)
	var p2 := ep.lerp(xp, 0.75)
	p1.y = cy
	p2.y = cy
	var tel := Tuning.get_f("worm", "telegraph_s", 1.3)
	var burst := Tuning.get_f("worm", "burst_s", 1.6)
	mode = Mode.LUNGE
	_lunge = {"path": [p0, p1, p2, p3], "t": 0.0, "tel": tel, "burst": burst, "hit": {}, "eaten": 0, "exit": p3}
	_rpc_lunge.rpc(p0, p1, p2, p3, e.position, x.position, tel, burst)
	print("[worm] valt uit bij %s" % aim)
	return true


## Een punt op de rots: vanaf `from` een eind in richting `dir`, dan naar beneden (vloer), of de wand
## die ertussen staat. {position, normal} of leeg.
func _surface_along(from: Vector3, dir: Vector3, dist: float) -> Dictionary:
	var t: TerrainAPI = game.terrain
	var start := from + Vector3.UP * 1.0
	var wall := t.raycast(start, start + dir * dist)
	if not wall.is_empty():
		return {"position": wall.position, "normal": wall.normal}
	var probe := start + dir * dist
	var down := t.raycast(probe, probe + Vector3.DOWN * 6.0)
	if down.is_empty():
		return {}
	return {"position": down.position, "normal": down.normal}


func _repel() -> void:
	mode = Mode.REPELLED
	_repel_t = 8.0
	var beacons: Beacons = game.beacons
	var b := beacons.nearest(pos) if beacons else Vector3.INF
	var away := (pos - b) if b != Vector3.INF else Vector3(1, 0, 0)
	away.y = 0.0
	_target = pos + away.normalized() * 25.0 + Vector3.DOWN * 6.0
	_cool = maxf(_cool, 10.0)
	print("[worm] een baken: weggezwommen")


## Host, per tick: de lopende uitval raakt spelers en slokt buit op.
func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _lunge.is_empty():
		return
	_lunge.t = float(_lunge.t) + delta
	var tel: float = _lunge.tel
	var burst: float = _lunge.burst
	var u: float = (float(_lunge.t) - tel) / burst
	if u < 0.0:
		return
	if u > 1.25:
		_end_lunge()
		return
	var path: Array = _lunge.path
	var head := WormVisual.bezier(path, clampf(u, 0.0, 1.0))
	var r := Tuning.get_f("worm", "hit_radius", 1.9)
	var mol: Mol = game.mol
	var hit: Dictionary = _lunge.hit
	var tangent := (WormVisual.bezier(path, clampf(u + 0.02, 0.0, 1.0)) - head).normalized()
	for pl: Player in game.players.get_children():
		if hit.has(pl.peer_id) or pl.seated:
			continue
		if mol and mol.body and mol.contains_point(pl.global_position):
			continue
		var body := pl.global_position + Vector3.UP * 0.7
		if body.distance_to(head) < r:
			hit[pl.peer_id] = true
			var push := tangent * Tuning.get_f("worm", "hit_push", 7.0) + Vector3.UP * 3.5
			game.rescue.host_damage(pl.peer_id, Tuning.get_f("worm", "hit_damage", 0.45), push, true, "worm")
	if int(_lunge.eaten) < Tuning.get_i("worm", "swallow_max", 3):
		var sr := Tuning.get_f("worm", "swallow_radius", 2.2)
		for it: FindItem in game.finds.items:
			if not it.freed or not it.carriers.is_empty() or it.global_position.distance_to(head) > sr:
				continue
			if mol and mol.body and mol.contains_point(it.global_position):
				continue
			_lunge.eaten = int(_lunge.eaten) + 1
			_carried.append(it.find_id)
			_rpc_swallow.rpc(it.find_id)
			if int(_lunge.eaten) >= Tuning.get_i("worm", "swallow_max", 3):
				break


func _end_lunge() -> void:
	pos = _lunge.exit
	vel = Vector3.ZERO
	_lunge = {}
	_cool = lerpf(Tuning.get_f("worm", "lunge_cd", 40.0), Tuning.get_f("worm", "lunge_cd_climax", 16.0), tension()) / _mult()
	if not _carried.is_empty():
		_lair = _pick_lair()
		mode = Mode.CARRY
		print("[worm] sleept %d vondsten weg naar %s" % [_carried.size(), _lair])
	else:
		mode = Mode.ROAM
		_wander_t = 0.0
	# Het lawaai dat hem hierheen bracht, is "opgelost".
	for n: Array in _noises:
		if (n[0] as Vector3).distance_to(pos) < 14.0:
			n[1] = float(n[1]) * 0.3


## Een grot ver van hier, boven het magma: daar dumpt hij zijn buit.
func _pick_lair() -> Vector3:
	var t: TerrainAPI = game.terrain
	var magma: Magma = game.magma
	var min_d := Tuning.get_f("worm", "lair_min_m", 50.0)
	var best := pos + Vector3(min_d, -10.0, 0.0)
	var best_d := -1.0
	for c: Vector4 in t.caverns():
		var floor_y := c.y - c.w / PlanetGenerator.CAVERN_SQUASH + 1.0
		if magma.visible and floor_y < magma.level + 25.0:
			continue
		var p := Vector3(c.x, floor_y, c.z)
		var d := p.distance_to(pos)
		if d >= min_d and (best_d < 0.0 or d < best_d):
			best_d = d
			best = p
	return best


## Host: opgeslokte buit reist mee in de buik.
func _carry_loot() -> void:
	for id in _carried:
		var it: FindItem = game.finds.item(id)
		if it:
			it.global_position = pos


## Host: de buit dumpen op de vloer van de grot.
func _deposit() -> void:
	var t: TerrainAPI = game.terrain
	var ids := PackedInt32Array()
	var xfs: Array = []
	var k := 0
	for id in _carried:
		var it: FindItem = game.finds.item(id)
		if it == null:
			continue
		var a := float(k) * 2.1
		var p := _lair + Vector3(cos(a), 0.0, sin(a)) * (1.0 + k * 0.8)
		var down := t.raycast(p + Vector3.UP * 3.0, p + Vector3.DOWN * 8.0)
		if not down.is_empty():
			p = (down.position as Vector3) + Vector3.UP * (it.rest_height() + 0.15)
		ids.append(id)
		xfs.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p))
		k += 1
	_carried = PackedInt32Array()
	if not ids.is_empty():
		_rpc_spit.rpc(ids, xfs)
		print("[worm] %d vondsten gedumpt bij %s" % [ids.size(), _lair])
	mode = Mode.ROAM
	_wander_t = 0.0


## Host: de Mol rammen. De lading lijdt (elke vondst in het laadruim), de Mol valt stil, wie staat
## gaat omver. Een baken in of bij de Mol houdt hem tegen.
func _ram(mol: Mol) -> void:
	var beacons: Beacons = game.beacons
	if beacons and beacons.nearest(mol.body.global_position).distance_to(mol.body.global_position) < Tuning.get_f("worm", "repel_m", 14.0):
		_repel()
		return
	_ram_cool = Tuning.get_f("worm", "ram_cd", 14.0)
	var mp := mol.body.global_position
	var side := (pos - mp)
	side.y = minf(side.y, 0.0)
	side = side.normalized() if side.length() > 0.1 else Vector3.DOWN
	var at := mp + side * 3.0
	mol.speed = 0.0 # de Mol valt stil en moet opnieuw op gang komen
	var loss := Tuning.get_f("worm", "ram_cargo_loss", 0.12)
	for it: FindItem in mol.cargo_contents():
		var cond := maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss)
		if cond < it.condition - 0.001:
			game.finds._rpc_condition.rpc(it.find_id, cond)
	for pl: Player in game.players.get_children():
		if not pl.seated and mol.contains_point(pl.global_position) and game.rescue.is_ok(pl.peer_id):
			var push := -side * 3.0 + Vector3.UP * 2.0
			game.rescue.host_damage(pl.peer_id, Tuning.get_f("worm", "ram_knock_damage", 0.05), push, true, "worm")
	_rpc_ram.rpc(at, side)
	for n: Array in _noises:
		if (n[0] as Vector3).distance_to(mp) < 12.0:
			n[1] = float(n[1]) * 0.4
	print("[worm] ramt de Mol")


# --- Op elk peer ---------------------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state(p: Vector3, m: int, act: float) -> void:
	if _net_pos == Vector3.ZERO or _net_pos.distance_to(p) > 30.0:
		pos = p
	_net_pos = p
	mode = m as Mode
	activity = act


@rpc("authority", "call_local", "reliable")
func _rpc_lunge(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, emerge: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	visual.play_lunge([p0, p1, p2, p3], emerge, exit, tel, burst)
	lunge_started.emit(emerge)


@rpc("authority", "call_local", "reliable")
func _rpc_ram(at: Vector3, side: Vector3) -> void:
	var mol: Mol = game.mol
	if mol and mol.visual:
		mol.visual.jolt(1.0)
	visual.play_ram(at, side)
	var p: Player = game.local_player
	if p and p.camera_fx:
		var k := 1.0 - smoothstep(4.0, 30.0, p.global_position.distance_to(at))
		p.camera_fx.add_trauma(0.7 * k)
		p.camera_fx.hold_rumble(5.0 * k)
	rammed.emit(at)
	if p and mol and mol.body and (p.seated or mol.contains_point(p.global_position)):
		game.notice.emit("Something slammed into the Mole! The cargo took a beating.", "alarm")


@rpc("authority", "call_local", "reliable")
func _rpc_swallow(find_id: int) -> void:
	var it: FindItem = game.finds.item(find_id)
	if it == null:
		return
	visual.gulp(it.global_position)
	if not it.carriers.is_empty():
		it.last_carriers = it.carriers
	it.carriers = PackedInt32Array([BELLY])
	it.visible = false
	it.collision_layer = 0
	if multiplayer.is_server():
		it.freeze = true
	it.update_interpolation()
	game.finds.carriers_changed.emit(it)
	swallowed.emit(find_id)
	var p: Player = game.local_player
	if p and p.global_position.distance_to(it.global_position) < 30.0:
		game.notice.emit("The worm swallowed the %s!" % it.display_name().to_lower(), "warn")


@rpc("authority", "call_local", "reliable")
func _rpc_spit(ids: PackedInt32Array, xfs: Array) -> void:
	for k in ids.size():
		var it: FindItem = game.finds.item(ids[k])
		if it == null:
			continue
		var xf: Transform3D = xfs[k]
		it.carriers = PackedInt32Array()
		it.visible = true
		it.collision_layer = Layers.LOOT
		it.global_transform = xf
		it.reset_physics_interpolation()
		it.last_safe = xf.origin
		it.push_snapshot(xf)
		if multiplayer.is_server():
			it.freeze = false
			it.linear_velocity = Vector3.ZERO
			it.angular_velocity = Vector3.ZERO
			it.sleeping = false
		it.update_interpolation()
		game.finds.carriers_changed.emit(it)
	spat.emit(ids)


## Late joiner: waar hij is, wat hij doet, en wat er in zijn buik zit.
func send_state(peer: int) -> void:
	_rpc_state.rpc_id(peer, pos, mode, activity)
	for id in _carried:
		_rpc_swallow.rpc_id(peer, id)


# --- Tekens (lokaal) -----------------------------------------------------------------------------

## Gerommel, stof uit het plafond en een markering op de vloer boven waar hij zwemt.
func _signs(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var p: Player = game.local_player
	if cam == null or p == null or mode == Mode.SLEEP or activity <= 0.01:
		_marker.visible = false
		return
	var t: TerrainAPI = game.terrain
	var d := cam.global_position.distance_to(pos)
	var k := (1.0 - smoothstep(5.0, Tuning.get_f("worm", "rumble_m", 30.0), d)) * activity
	if k > 0.02 and p.camera_fx and p.camera == cam:
		var in_mol: bool = game.mol != null and game.mol.body != null and (p.seated or game.mol.contains_point(p.global_position))
		var damp := 0.6 if in_mol else 1.0
		p.camera_fx.hold_rumble(2.2 * k * damp)
		p.camera_fx.hold_trauma(0.22 * k * damp)
	# Stof dat uit het plafond sijpelt boven de camera.
	_dust_t -= delta
	if k > 0.3 and _dust_t <= 0.0:
		_dust_t = lerpf(1.2, 0.35, k)
		var c := cam.global_position + Vector3(randf_range(-3, 3), 0.0, randf_range(-3, 3))
		var up := t.raycast(c, c + Vector3.UP * 6.0)
		if not up.is_empty():
			var col := Strata.DEBRIS_COLORS[t.layer_at(up.position)]
			game.fx.grit_puff((up.position as Vector3) - Vector3(0, 0.1, 0), Vector3.DOWN, col)
	# De markering op de vloer: boven de worm, waar de rots ophoudt.
	_marker_t -= delta
	var md := Tuning.get_f("worm", "marker_m", 24.0)
	if _marker_t <= 0.0:
		_marker_t = 0.3
		var floor_p := _floor_above(pos) if d < md + 12.0 else Vector3.INF
		if floor_p != Vector3.INF and floor_p.distance_to(cam.global_position) < md:
			if not _marker.visible or _marker.global_position.distance_to(floor_p) > 6.0:
				_marker.global_position = floor_p + Vector3.UP * 0.6
			_marker.visible = true
			_marker_k = activity
			var col := Strata.DEBRIS_COLORS[t.layer_at(floor_p - Vector3.UP * 0.3)]
			game.fx.grit_puff(floor_p + Vector3(randf_range(-1, 1), 0.05, randf_range(-1, 1)), Vector3.UP, col)
			if randf() < 0.5 + 0.4 * activity:
				visual.hop_pebble(floor_p + Vector3(randf_range(-1.2, 1.2), 0.1, randf_range(-1.2, 1.2)), col)
		else:
			_marker_k = 0.0
	if _marker.visible:
		var target := _floor_above(pos) if Engine.get_process_frames() % 6 == 0 else Vector3.INF
		if target != Vector3.INF:
			_marker.global_position = _marker.global_position.lerp(target + Vector3.UP * 0.6, minf(1.0, delta * 8.0))
		_marker.modulate.a = move_toward(_marker.modulate.a, 0.9 * _marker_k, delta * 2.0)
		_marker.rotation.y += delta * 0.4
		if _marker.modulate.a <= 0.01 and _marker_k <= 0.0:
			_marker.visible = false


## De vloer boven een punt in de rots (de eerste open lucht erboven), of INF.
func _floor_above(from: Vector3) -> Vector3:
	var t: TerrainAPI = game.terrain
	var p := from
	for i in 28:
		if not t.data_loaded(p):
			return Vector3.INF
		if t.sdf_at(p) > 0.4:
			return p - Vector3.UP * 0.35
		p.y += 0.5
	return Vector3.INF


## Barsten voor de markering op de vloer: een stervormig patroon (eenmalig gebakken, gedeeld).
static var _cracks: ImageTexture


static func _crack_texture() -> ImageTexture:
	if _cracks:
		return _cracks
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# Een lichte kom in het midden.
	for y in n:
		for x in n:
			var r := Vector2(x - n * 0.5, y - n * 0.5).length() / (n * 0.5)
			var bowl := clampf(1.0 - r / 0.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, bowl * bowl * 0.3))
	# Barsten: kronkelende lijnen vanuit het midden, dunner naar het einde.
	for i in 9:
		var a := rng.randf() * TAU
		var p := Vector2(n * 0.5, n * 0.5)
		for s in 7:
			a += rng.randf_range(-0.5, 0.5)
			var q := p + Vector2(cos(a), sin(a)) * rng.randf_range(4.0, 7.5)
			var w := lerpf(2.2, 0.7, float(s) / 7.0)
			var steps := int(p.distance_to(q) * 2.0) + 1
			for k in steps:
				var c := p.lerp(q, float(k) / steps)
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var px := int(c.x) + dx
						var py := int(c.y) + dy
						if px < 0 or py < 0 or px >= n or py >= n:
							continue
						var cov := clampf(w + 0.5 - Vector2(dx, dy).length(), 0.0, 1.0)
						var old := img.get_pixel(px, py)
						img.set_pixel(px, py, Color(1, 1, 1, maxf(old.a, cov)))
			p = q
	_cracks = ImageTexture.create_from_image(img)
	return _cracks
