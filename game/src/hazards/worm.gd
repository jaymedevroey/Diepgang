class_name Worm
extends Node3D
## De Graafworm (GDD §6), voor de ploeg "the Gulper": het enige wezen in Early Access. Staat op elk
## peer op Game/Worm.
## - Zwemt onzichtbaar door de rots en verandert het terrein niet. Je merkt hem aan gerommel, stof
##   uit het plafond en een markering op de vloer (barsten, springende steentjes) boven waar hij zwemt,
##   en op de sonar van de Mol als een grote rode stip die nadert (playtest 2026-10-06, ui2-05).
## - Komt af op lawaai: boorhappen, de Mol die boort of rijdt, een PING, de toeter, een ontploffing,
##   de Mol die vertrekt. Hij weet niet waar je bent, enkel waar het lawaai was. Wie lang stilstaat
##   boven waar hij rondsluipt, voelt hij ook (ontwerp2-2): de tekens zeggen "ga weg".
## - Valt uit in open ruimtes (grotten, de tunnel van de Mol, de oppervlakte): eerst een waarschuwing
##   (de vloer barst open met een gloed en scherven, gerommel), dan een boog door de ruimte. In een
##   smalle gang breekt hij enkel door de wand als het daar lang luid was (de boor; het houweel is stil).
## - Wie hij raakt, grijpt hij (golf 3, playtest "een worm die je opslokt"; de Smoker van L4D2): hij
##   sleurt je 15-30 m over de vloer weg van de ploeg. De ploeg bevrijdt je (twee houweelslagen op de
##   kop, of een baken bij hem), of je spartelt zelf los (Spatie). Lukt dat niet, dan bijt hij nog eens
##   en spuwt je uit. Losse buit slokt hij op en dumpt hij ver weg in een grot.
## - Lichtbakens (Beacons) houden hem op afstand: daar valt hij niet uit, hij zwemt weg. Een baken dat in
##   een rijdende Mol ligt, telt niet (de motor overstemt het).
## - De Mol: midden in de dienst duwt hij hem hooguit (de Mol valt stil, de lading blijft heel), en
##   daarna laat hij de Mol een tijd met rust (ontwerp2-1: de Mol is de veilige thuis). Na de hendel
##   (de climax) jaagt hij op de Mol en bijt hij zich vast in de romp: de lading lijdt zolang hij bijt
##   en de Mol rijdt trager. De piloot schudt hem los (sturen, links-rechts), de ploeg gooit een baken
##   uit de achterklep (G in een rijdende Mol), of slaat hem los aan de oppervlakte (ontwerp2-3).
## Netwerk: de host simuleert (plek, aandacht, uitvallen, grijpen, bijten, wie geraakt wordt); de
## clients krijgen de plek 8× per seconde en elke uitval, greep en beet als plan (zelfde pad op elk
## peer). Een slag van een client op de kop meldt hij; de host controleert de afstand opnieuw.

enum Mode { SLEEP, ROAM, HUNT, LUNGE, CARRY, REPELLED, GRAB, BITE }

## Eén naam overal in het spel (ui2-05): "the Gulper" in zinnen, GULPER op de sonar en in de HUD.
const NAME := "Gulper"

## Hij begint een uitval (op elk peer; voor geluid en tests). `at`: waar hij uit de rots komt.
signal lunge_started(at: Vector3)
## Hij slokte een vondst op (op elk peer).
signal swallowed(find_id: int)
## Hij dumpte vondsten in een grot (op elk peer).
signal spat(find_ids: PackedInt32Array)
## Hij raakte de Mol: een duw midden in de dienst of een beet in de climax (op elk peer).
signal rammed(at: Vector3)
## Hij grijpt een speler (op elk peer).
signal grabbed(peer: int)
## Hij laat een speler los (op elk peer). `reason`: hit, beacon, struggle, done, down.
signal released(peer: int, reason: String)
## Hij bijt zich vast in de Mol (climax), en laat los: hit, beacon, shake, done, lost (op elk peer).
signal bite_started(at: Vector3)
signal bite_ended(reason: String)
## Een slag op zijn kop (op elk peer; voor geluid en beeld).
signal hurt(at: Vector3)
## Het slachtoffer spartelt, of de piloot schudt aan de Mol (op elk peer; voor geluid).
signal struggled

const SYNC_INTERVAL := 0.125
## Drager-id van opgeslokte buit (geen speler heeft deze id).
const BELLY := -7
## Hoogte van zijn prooi boven de vloer als hij iemand sleurt (m).
const HOLD_H := 0.9
## Het model (worm.glb): de oorsprong van de kop zit achteraan de schedel; de lip zit LIP_AHEAD ervoor,
## het midden van de schedel SKULL_AHEAD, en wat hij vasthoudt hangt MOUTH_AHEAD ervoor, tussen de
## flappen.
const LIP_AHEAD := 2.2
const SKULL_AHEAD := 1.1
const MOUTH_AHEAD := 2.9
## Bijten en duwen: de oorsprong van de kop zoveel m buiten de romp (de lip ±0,3 m ervan).
const BITE_NODE := 2.5

var game: Node # Game
var mode := Mode.SLEEP
## Plek van de kop (wereld, in de rots). Host: gesimuleerd; clients: van de host, vloeiend.
var pos := Vector3.ZERO
var vel := Vector3.ZERO
## Hoe onrustig (0 = slaapt, 1 = valt uit), voor gerommel en de sonar.
var activity := 0.0
var visual: WormVisual
## De kop als doelwit voor het houweel (laag CRUST, enkel als hij boven de grond is).
var hitbox: StaticBody3D

# Host.
var _target := Vector3.ZERO
var _target_loud := 0.0
var _noises: Array = [] # [plek, luidheid, tijd (s)]
var _cool := 20.0
var _ram_cool := 0.0
var _shove_cool := 0.0
var _mol_deaf_t := 0.0
var _grab_cool := 0.0
var _wander_t := 0.0
var _repel_t := 0.0
var _carried := PackedInt32Array()
var _lair := Vector3.ZERO
var _lunge: Dictionary = {} # host: lopende uitval
var _grab: Dictionary = {} # host: wie hij vasthoudt en waarheen hij sleurt
var _bite: Dictionary = {} # host: waar hij in de Mol bijt (t.o.v. de Mol)
var _bites_done := 0
var _prowl_peer := -1
var _sensed := {} # peer -> seconden dat hij hem voelt
var _hit_ms := {} # peer -> laatste slag (ms)
var _sync_t := 0.0
var _rng := RandomNumberGenerator.new()
var _clock := 0.0 # speltijd (s): lawaai vervaagt in speltijd
var _mol_noise_t := 0.0
var _last_mode_mol := -1
# Clients.
var _net_pos := Vector3.ZERO
## Op elk peer: wie hij vasthoudt (voor HUD en speler), of -1.
var held_peer := -1
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
	hitbox = StaticBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.top_level = true
	hitbox.collision_layer = Layers.CRUST
	hitbox.collision_mask = 0
	hitbox.set_meta("worm", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.25
	cs.shape = sh
	cs.disabled = true
	hitbox.add_child(cs)
	add_child(hitbox)


## Nieuwe wereld: slapen, diep in een grot ver van de landingsplek.
func attach_terrain(terrain: TerrainAPI) -> void:
	mode = Mode.SLEEP
	activity = 0.0
	vel = Vector3.ZERO
	_noises.clear()
	_carried = PackedInt32Array()
	_lunge = {}
	_grab = {}
	_bite = {}
	held_peer = -1
	_cool = 20.0
	_ram_cool = 0.0
	_shove_cool = 0.0
	_mol_deaf_t = 0.0
	_grab_cool = 0.0
	_last_mode_mol = -1
	_sensed.clear()
	_prowl_peer = -1
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
	if _climax():
		return 1.0
	var start := Tuning.get_f("magma", "start_depth", 310.0)
	var recall := Tuning.get_f("magma", "recall_depth", 60.0)
	return clampf(inverse_lerp(start, recall, magma.depth()), 0.0, 1.0)


func is_awake() -> bool:
	return mode != Mode.SLEEP


## Houdt hij nu iemand vast (op elk peer)?
func holds(peer: int) -> bool:
	return held_peer == peer and peer >= 0


## Bijt hij nu in de Mol (op elk peer)?
func biting() -> bool:
	return mode == Mode.BITE


## Hoeveel keer hij deze wereld al in de Mol beet (host; voor metingen).
func bites_done() -> int:
	return _bites_done


## Hoe snel de Mol nog kan (Mol._extract): trager zolang hij bijt.
func mol_drag() -> float:
	return Tuning.get_f("worm", "bite_slow", 0.45) if mode == Mode.BITE else 1.0


## Na zoveel seconden magmaklok wordt hij wakker (per planeet: een rustigere worm slaapt langer).
func wake_after() -> float:
	return Tuning.get_f("worm", "wake_s", 150.0) / maxf(0.1, _mult())


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
	if mode in [Mode.BITE, Mode.GRAB, Mode.LUNGE]:
		wobble *= 0.3 # boven de grond: je weet precies waar hij is
	var jitter := Vector3(sin(t * 1.3 + 0.7), 0.0, cos(t * 1.1)) * wobble
	var strength := clampf(1.0 - d / reach, 0.15, 1.0) * clampf(activity + 0.4, 0.0, 1.0)
	return {"on": true, "pos": shown + jitter, "strength": strength, "dist": d, "attacking": mode in [Mode.LUNGE, Mode.GRAB, Mode.BITE]}


## Waar de kop nu boven de grond is (wereld), of Vector3.INF als hij in de rots zit. Host: uit de
## simulatie; clients: uit het beeld.
func head_world() -> Vector3:
	if multiplayer.is_server():
		match mode:
			Mode.GRAB:
				return _grab_skull()
			Mode.BITE:
				return _bite_head()
			Mode.LUNGE:
				if not _lunge.is_empty():
					var u := (float(_lunge.t) - float(_lunge.tel)) / float(_lunge.burst)
					if u >= 0.0 and u <= 1.0:
						var lp: Array = _lunge.path
						var h := WormVisual.bezier(lp, lunge_param(u))
						var tg := (WormVisual.bezier(lp, lunge_param(minf(1.0, u + 0.03))) - h).normalized()
						return h + tg * SKULL_AHEAD
	return visual.head_world() if visual else Vector3.INF


## De tijd van een uitval (0..1) naar de plek op de boog: traag uit de rots (je ziet hem komen), snel
## door de ruimte, en weer trager de rots in (binnen2-02: "de uitval duurt twee frames").
static func lunge_param(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * x)


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


## De Mol vertrekt: aftellen, terugrit, de grijper. Dan jaagt hij op de Mol zelf (de climax).
func _climax() -> bool:
	var mol: Mol = game.mol if game else null
	return mol != null and mol.body != null and mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING, Mol.Mode.GRAPPLE_DOWN]


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
		Mode.LUNGE, Mode.GRAB, Mode.BITE:
			want = 1.0
	activity = move_toward(activity, want, delta * 0.8) if multiplayer.is_server() else activity
	_signs(delta)
	# Het doelwit voor het houweel volgt de kop (op elk peer: wie slaat, ziet wat hij raakt).
	var head := visual.head_world() if visual else Vector3.INF
	var cs := hitbox.get_child(0) as CollisionShape3D
	var on := head != Vector3.INF and mode in [Mode.LUNGE, Mode.GRAB, Mode.BITE]
	cs.disabled = not on
	if on:
		hitbox.global_position = head


func _host_step(dt: float) -> void:
	var magma: Magma = game.magma
	if magma == null or not magma.running:
		return
	_cool -= dt
	_ram_cool -= dt
	_shove_cool -= dt
	_mol_deaf_t -= dt
	_grab_cool -= dt
	var mult := _mult()
	if mode == Mode.SLEEP:
		if magma.elapsed >= wake_after():
			mode = Mode.ROAM
			print("[worm] wakker na %.0f s" % magma.elapsed)
		return
	_feed_mol(dt)
	var now := _clock
	var tens := tension()
	var speed := Tuning.get_f("worm", "roam_speed", 2.5)
	var mol: Mol = game.mol
	# De climax: hij jaagt op de Mol zelf, niet op waar het lawaai was (de Mol rijdt weg).
	if _climax() and mode in [Mode.ROAM, Mode.HUNT] and _ram_cool <= 0.0:
		if mode == Mode.ROAM:
			print("[worm] de climax: jaagt op de Mol")
		mode = Mode.HUNT
	match mode:
		Mode.ROAM:
			_wander_t -= dt
			var prowl: Player = game.player_node(_prowl_peer) if _prowl_peer >= 0 else null
			if prowl and _sense_ok(prowl):
				# Rondsluipen onder een speler: hij volgt hem van onderuit.
				_target = prowl.global_position + Vector3(0.0, -Tuning.get_f("worm", "prowl_depth", 7.0), 0.0)
			if _wander_t <= 0.0 or (prowl == null and pos.distance_to(_target) < 4.0):
				_wander_t = Tuning.get_f("worm", "prowl_s", 14.0)
				_target = _wander_point()
			_sense(dt)
			_pick_noise(now, tens)
		Mode.HUNT:
			speed = lerpf(Tuning.get_f("worm", "hunt_speed", 4.5), Tuning.get_f("worm", "climax_speed", 7.5), tens)
			if _climax() and mol and mol.body:
				_target = mol.body.global_position
				_target_loud = 99.0
				if pos.distance_to(_target) < Tuning.get_f("worm", "ram_m", 7.0) + 6.0:
					_strike(now)
			elif not _pick_noise(now, tens):
				mode = Mode.ROAM
			elif pos.distance_to(_target) < Tuning.get_f("worm", "lunge_reach", 9.0) + 5.0:
				_strike(now)
		Mode.LUNGE:
			return
		Mode.GRAB:
			_grab_step(dt)
			return
		Mode.BITE:
			_bite_step(dt)
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


## Continu lawaai van de Mol (boren, rijden) en het vertrek (de motor spint op: dat lokt hem). Na een
## duw hoort hij de Mol een tijd niet (ontwerp2-1): dan zoekt hij de ploeg.
func _feed_mol(dt: float) -> void:
	var mol: Mol = game.mol
	if mol == null or mol.body == null or mol.mode == Mol.Mode.DOCKED:
		return
	if mol.mode != _last_mode_mol:
		if mol.mode == Mol.Mode.COUNTDOWN:
			hear(mol.placed.origin, Tuning.get_f("worm", "loud_depart", 6.0) * _mult())
			_rpc_climax_warn.rpc()
		_last_mode_mol = mol.mode
	_mol_noise_t += dt
	if _mol_noise_t < 0.5:
		return
	var loud := 0.0
	if mol.drilling:
		loud += Tuning.get_f("worm", "loud_mol_drill", 1.0)
	var top := maxf(0.1, Tuning.get_f("mol", "open_speed", 1.8))
	loud += Tuning.get_f("worm", "loud_mol_drive", 0.3) * clampf(absf(mol.speed) / top, 0.0, 1.0)
	if mol.mode == Mol.Mode.EXTRACTING:
		loud += Tuning.get_f("worm", "loud_mol_drill", 1.0) # de terugrit: de motor op volle toeren
	if loud > 0.0 and (_mol_deaf_t <= 0.0 or _climax()):
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
	_target_loud = _fade(best, now)
	if mode == Mode.ROAM:
		mode = Mode.HUNT
		_prowl_peer = -1
		print("[worm] jaagt op lawaai bij %s (score %.2f)" % [_target, best_s])
	return true


## Kan hij deze speler voelen (rechtop, te voet, onder de grond, niet in de Mol)?
func _sense_ok(pl: Player) -> bool:
	if pl == null or pl.seated or game.rescue == null or not game.rescue.is_ok(pl.peer_id):
		return false
	var mol: Mol = game.mol
	if mol and mol.body and mol.contains_point(pl.global_position):
		return false
	var p := pl.global_position
	return game.terrain.surface_height_at(p.x, p.z) - p.y > 4.0


## Wie te lang boven hem staat, voelt hij (ontwerp2-2: ook wie stil werkt, loopt risico). De tekens
## (gerommel, de markering, de seismograaf in de HUD) zeggen het eerst: ga weg.
func _sense(dt: float) -> void:
	var near := Tuning.get_f("worm", "sense_m", 9.0)
	for pl: Player in game.players.get_children():
		var peer := pl.peer_id
		if not _sense_ok(pl) or pos.distance_to(pl.global_position) > near:
			_sensed[peer] = maxf(0.0, float(_sensed.get(peer, 0.0)) - dt * 2.0)
			continue
		_sensed[peer] = float(_sensed.get(peer, 0.0)) + dt
		if float(_sensed[peer]) >= Tuning.get_f("worm", "sense_s", 5.0):
			_sensed[peer] = 0.0
			hear(pl.global_position, Tuning.get_f("worm", "breach_loud", 3.0) + 1.0)
			print("[worm] voelt een speler boven zich (%d)" % peer)


## Rondzwerven in de buurt van de ploeg, wat lager dan zij; soms sluipt hij onder een speler
## (prowl_chance): dreiging in het midden van de dienst, ook voor wie stil werkt.
func _wander_point() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	var candidates: Array[Player] = []
	for pl: Player in game.players.get_children():
		sum += pl.global_position
		n += 1
		if _sense_ok(pl):
			candidates.append(pl)
	_prowl_peer = -1
	if not candidates.is_empty() and _rng.randf() < Tuning.get_f("worm", "prowl_chance", 0.35):
		var pick: Player = candidates[_rng.randi() % candidates.size()]
		_prowl_peer = pick.peer_id
		return pick.global_position + Vector3(0.0, -Tuning.get_f("worm", "prowl_depth", 7.0), 0.0)
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
	# Bakens: wegzwemmen (niet een baken dat in een rijdende Mol ligt).
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


## Host: dicht bij het lawaai. De Mol: in de climax bijt hij, midden in de dienst duwt hij hooguit.
## Is er iemand of losse buit in een open ruimte, dan valt hij uit; in een krappe gang breekt hij
## door de wand als het daar lang luid was. Anders verliest hij zijn interesse in dat lawaai.
func _strike(now: float) -> void:
	var mol: Mol = game.mol
	var reach := Tuning.get_f("worm", "lunge_reach", 9.0)
	if mol and mol.body and _target.distance_to(mol.body.global_position) < 10.0 \
			and pos.distance_to(mol.body.global_position) < Tuning.get_f("worm", "ram_m", 7.0) + 6.0:
		if _climax():
			if _ram_cool <= 0.0:
				_start_bite(mol)
			return
		if mol.mode in [Mol.Mode.PARKED, Mol.Mode.DRIVING, Mol.Mode.AUTO_DOWN] and _shove_cool <= 0.0:
			_shove(mol)
			return
	if _cool > 0.0:
		return
	var aim := Vector3.INF
	var best := INF
	for pl: Player in game.players.get_children():
		if pl.seated or not game.rescue or not game.rescue.is_ok(pl.peer_id):
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
	if aim != Vector3.INF and (_try_lunge(aim) or _try_breach(aim, _target_loud)):
		return
	if mode != Mode.HUNT:
		return # een baken stuurde hem weg
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
	_begin_lunge([p0, p1, p2, p3], ep, en, xp, Tuning.get_f("worm", "telegraph_s", 1.6), Tuning.get_f("worm", "burst_s", 1.9))
	print("[worm] valt uit bij %s" % aim)
	return true


## Host: door de wand of de vloer van een krappe gang naast `aim` breken (ontwerp2-2). Enkel als het
## daar lang luid was (`loud` >= breach_loud: de boor, of hij voelde iemand), met een langere
## waarschuwing op de rots waar hij doorkomt.
func _try_breach(aim: Vector3, loud: float) -> bool:
	if loud < Tuning.get_f("worm", "breach_loud", 3.0):
		return false
	var t: TerrainAPI = game.terrain
	var beacons: Beacons = game.beacons
	if beacons and beacons.nearest(aim).distance_to(aim) < Tuning.get_f("worm", "repel_m", 14.0):
		_repel()
		return false
	var chest := aim + Vector3.UP * 0.9
	if not t.data_loaded(chest):
		return false
	var best := {}
	var best_d := INF
	var dirs: Array[Vector3] = [Vector3.DOWN]
	for i in 8:
		var a := TAU * i / 8.0
		dirs.append(Vector3(cos(a), -0.15, sin(a)).normalized())
	for d: Vector3 in dirs:
		var hit := t.raycast(chest, chest + d * 2.6)
		if hit.is_empty():
			continue
		var dist := chest.distance_to(hit.position)
		# Liever een wand dan de vloer (dan zie je hem komen).
		if d == Vector3.DOWN:
			dist += 0.8
		if dist < best_d:
			best_d = dist
			best = hit
	if best.is_empty():
		return false
	var s: Vector3 = best.position
	var n: Vector3 = best.normal
	var side := n.cross(Vector3.UP)
	if side.length() < 0.2:
		side = n.cross(Vector3.RIGHT)
	side = side.normalized()
	var p0 := s - n * 3.2 - side * 0.8
	var p1 := s + n * 1.4
	var p2 := chest + n * 0.2
	var p3 := s - n * 3.2 + side * 1.6
	_begin_lunge([p0, p1, p2, p3], s, n, s + side * 0.6, Tuning.get_f("worm", "breach_telegraph_s", 2.0), Tuning.get_f("worm", "breach_burst_s", 1.4))
	print("[worm] breekt door de wand bij %s" % aim)
	return true


func _begin_lunge(path: Array, emerge: Vector3, normal: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	mode = Mode.LUNGE
	_prowl_peer = -1
	_lunge = {"path": path, "t": 0.0, "tel": tel, "burst": burst, "hit": {}, "eaten": 0, "exit": path[3], "emerge": emerge}
	_rpc_lunge.rpc(path[0], path[1], path[2], path[3], emerge, normal, exit, tel, burst)


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
	var beacons: Beacons = game.beacons
	_repel_from(beacons.nearest(pos) if beacons else Vector3.INF, 8.0)
	_cool = maxf(_cool, 10.0)
	print("[worm] een baken: weggezwommen")


func _repel_from(from: Vector3, seconds: float) -> void:
	mode = Mode.REPELLED
	_repel_t = seconds
	var away := (pos - from) if from != Vector3.INF else Vector3(1, 0, 0)
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(cos(_rng.randf() * TAU), 0.0, sin(_rng.randf() * TAU))
	_target = pos + away.normalized() * 25.0 + Vector3.DOWN * 6.0


## Host, per tick: de lopende uitval grijpt of raakt spelers en slokt buit op.
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
	var head := WormVisual.bezier(path, lunge_param(clampf(u, 0.0, 1.0)))
	pos = head
	var r := Tuning.get_f("worm", "hit_radius", 1.9)
	var mol: Mol = game.mol
	var hit: Dictionary = _lunge.hit
	var tangent := (WormVisual.bezier(path, lunge_param(clampf(u + 0.03, 0.0, 1.0))) - head).normalized()
	for pl: Player in game.players.get_children():
		if hit.has(pl.peer_id) or pl.seated:
			continue
		if mol and mol.body and mol.contains_point(pl.global_position):
			continue
		var body := pl.global_position + Vector3.UP * 0.7
		var mouth := head + tangent * (LIP_AHEAD - 0.2)
		if body.distance_to(mouth) < r and u <= 1.0:
			hit[pl.peer_id] = true
			if _start_grab(pl, mouth, tangent):
				return
			var push := tangent * Tuning.get_f("worm", "hit_push", 7.0) + Vector3.UP * 3.5
			game.rescue.host_damage(pl.peer_id, Tuning.get_f("worm", "hit_damage", 0.45), push, true, "worm")
	if int(_lunge.eaten) < Tuning.get_i("worm", "swallow_max", 3):
		var sr := Tuning.get_f("worm", "swallow_radius", 2.2)
		for it: FindItem in game.finds.items:
			if not it.freed or not it.carriers.is_empty() or it.global_position.distance_to(head + tangent * (LIP_AHEAD - 0.2)) > sr:
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
	_quiet_noise_near(pos, 14.0, 0.3)


## Het lawaai dat hem hierheen bracht, is "opgelost".
func _quiet_noise_near(at: Vector3, radius: float, k: float) -> void:
	for n: Array in _noises:
		if (n[0] as Vector3).distance_to(at) < radius:
			n[1] = float(n[1]) * k


# --- Grijpen (host) ----------------------------------------------------------------------------------

## Host: de kop raakt een speler: hem grijpen en wegsleuren. False als hij hem niet grijpt (al iemand
## in de muil, net nog iemand gegrepen, of de klap legt hem meteen neer).
func _start_grab(pl: Player, head: Vector3, tangent: Vector3) -> bool:
	if not _grab.is_empty() or _grab_cool > 0.0 or Tuning.get_f("worm", "grab_chance", 1.0) <= 0.0:
		return false
	var rescue: Rescue = game.rescue
	var peer := pl.peer_id
	if not rescue.is_ok(peer) or _rng.randf() > Tuning.get_f("worm", "grab_chance", 1.0):
		return false
	var flat := Vector3(tangent.x, 0.0, tangent.z)
	flat = flat.normalized() if flat.length() > 0.05 else Vector3(1, 0, 0)
	if not rescue.host_grab(peer, flat * 2.0 + Vector3.UP, Tuning.get_f("worm", "grab_damage", 0.2)):
		return false
	var t: TerrainAPI = game.terrain
	var down := t.raycast(pl.global_position + Vector3.UP * 0.8, pl.global_position + Vector3.DOWN * 2.5)
	var ground: Vector3 = (down.position as Vector3) if not down.is_empty() else pl.global_position
	# Het pad van zijn prooi: van waar hij hem greep, over de vloer weg. De kop zit MOUTH_AHEAD erachter.
	var path := PackedVector3Array([pl.global_position + Vector3.UP * HOLD_H])
	path.append_array(_drag_path(ground, flat, peer))
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	_grab = {"peer": peer, "path": path, "len": length, "s": 0.0, "t": 0.0, "hp": Tuning.get_i("worm", "grab_hits", 2),
			"grip": 0.0, "chew": 0.0, "dot": 0.0, "struggle_ms": 0}
	_lunge = {}
	mode = Mode.GRAB
	_prowl_peer = -1
	_rpc_grab.rpc(peer, path, Tuning.get_f("worm", "grab_speed", 2.6))
	print("[worm] grijpt speler %d en sleurt hem %.0f m weg" % [peer, length])
	return true


## Een pad over de vloer, weg van de rest van de ploeg en de Mol, enkel waar het open is (1 m boven de
## vloer nog vrij). Elke stap 1 m; botst het, dan draait hij bij. Punten op HOLD_H boven de vloer.
func _drag_path(start: Vector3, dir: Vector3, victim: int) -> PackedVector3Array:
	var t: TerrainAPI = game.terrain
	var mol: Mol = game.mol
	var away := dir
	var crew := Vector3.ZERO
	var n := 0
	for pl: Player in game.players.get_children():
		if pl.peer_id != victim:
			crew += pl.global_position
			n += 1
	if mol and mol.body:
		crew += mol.body.global_position
		n += 1
	if n > 0:
		var from_crew := start - crew / n
		from_crew.y = 0.0
		if from_crew.length() > 0.5:
			away = (away + from_crew.normalized() * 1.5).normalized()
	var want := Tuning.get_f("worm", "grab_drag_m", 20.0)
	var free := Tuning.get_f("worm", "grab_open_m", 0.55)
	var pts := PackedVector3Array()
	var p := start
	var d := away
	var total := 0.0
	for i in 64:
		if total >= want:
			break
		var stepped := false
		for k: int in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5]:
			var dd := d.rotated(Vector3.UP, k * 0.35)
			var q := p + dd
			if not t.data_loaded(q + Vector3.UP):
				continue
			var hit := t.raycast(q + Vector3.UP * 1.2, q + Vector3.DOWN * 2.5)
			if hit.is_empty():
				continue
			var fq: Vector3 = hit.position
			if absf(fq.y - p.y) > 0.9:
				continue
			if t.sdf_at(fq + Vector3.UP * 1.0) < free:
				continue
			if mol and mol.body and mol.contains_point(fq + Vector3.UP):
				continue
			p = fq
			d = d.lerp(dd, 0.6).normalized()
			stepped = true
			break
		if not stepped:
			break
		pts.append(p + Vector3.UP * HOLD_H)
		total += 1.0
	return pts


## Waar zijn prooi nu is (tussen de flappen), of INF.
func _grab_head() -> Vector3:
	if _grab.is_empty():
		return Vector3.INF
	var p := sample_path(_grab.path, float(_grab.s))
	if float(_grab.chew) > 0.0:
		p += Vector3(sin(_clock * 17.0), absf(sin(_clock * 9.0)) * 0.6, cos(_clock * 13.0)) * 0.25
	return p


## Het midden van de schedel terwijl hij iemand sleurt (daar raakt het houweel), of INF.
func _grab_skull() -> Vector3:
	if _grab.is_empty():
		return Vector3.INF
	var s := float(_grab.s) - (MOUTH_AHEAD - SKULL_AHEAD)
	var path: PackedVector3Array = _grab.path
	if s >= 0.0 or path.size() < 2:
		return sample_path(path, s)
	var d := (path[1] - path[0]).normalized()
	return path[0] + d * s


## Waar de romp van wie hij vasthoudt hoort (host, Rescue._host_bodies): dwars in de muil, voor de kop,
## en hij schudt hem heen en weer.
func hold_transform(peer: int) -> Transform3D:
	if _grab.is_empty() or int(_grab.peer) != peer:
		return Transform3D(Basis(), pos)
	var head := _grab_head()
	var s := float(_grab.s)
	var fwd := sample_path(_grab.path, s + 0.6) - sample_path(_grab.path, maxf(0.0, s - 0.6))
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3(1, 0, 0)
	var side := fwd.cross(Vector3.UP).normalized()
	side = side.rotated(fwd, sin(_clock * 6.0) * 0.35)
	var face := side.cross(fwd).normalized()
	# Romp: y langs de zijkant (dwars in de muil), het gezicht (-z) naar boven.
	var b := Basis(side.cross(-face), side, -face).orthonormalized()
	return Transform3D(b, head)


func _grab_step(dt: float) -> void:
	var g := _grab
	var peer: int = g.peer
	var rescue: Rescue = game.rescue
	var pl: Player = game.player_node(peer)
	if pl == null or rescue.life_of(peer) != Rescue.Life.KNOCKED or not rescue.is_held(peer):
		_end_grab("down")
		return
	var length: float = g.len
	g.s = minf(length, float(g.s) + Tuning.get_f("worm", "grab_speed", 2.6) * dt)
	g.t = float(g.t) + dt
	var head := _grab_head()
	pos = head + Vector3.DOWN * 1.2
	# Hij knaagt: levens weg, in stapjes (geen melding per tick).
	g.dot = float(g.dot) + Tuning.get_f("worm", "grab_dps", 0.05) * dt
	if float(g.dot) >= 0.025:
		rescue.host_damage(peer, float(g.dot), Vector3.ZERO, false, "worm", true)
		g.dot = 0.0
		if rescue.life_of(peer) != Rescue.Life.KNOCKED:
			_end_grab("down")
			return
	# Een baken bij hem: loslaten.
	var beacons: Beacons = game.beacons
	if beacons and beacons.nearest(head).distance_to(head) < Tuning.get_f("worm", "grab_beacon_m", 7.0):
		_end_grab("beacon")
		return
	g.grip = maxf(0.0, float(g.grip) - Tuning.get_f("worm", "grab_grip_decay", 0.08) * dt)
	# Aan het einde van zijn pad: nog eens bijten, dan uitspuwen.
	var min_t := Tuning.get_f("worm", "grab_min_s", 5.0)
	if float(g.s) >= length - 0.01 and float(g.t) >= min_t:
		g.chew = float(g.chew) + dt
		if float(g.chew) >= Tuning.get_f("worm", "grab_chew_s", 1.2):
			_end_grab("done")


## Host: het slachtoffer spartelt (Spatie, via Rescue.request_flail).
func host_struggle(peer: int) -> void:
	if mode != Mode.GRAB or _grab.is_empty() or int(_grab.peer) != peer:
		return
	var now := Time.get_ticks_msec()
	if now - int(_grab.struggle_ms) < 110:
		return
	_grab.struggle_ms = now
	_grab.grip = float(_grab.grip) + Tuning.get_f("worm", "grab_struggle", 0.11)
	_rpc_struggled.rpc()
	if float(_grab.grip) >= 1.0:
		_end_grab("struggle")


func _end_grab(reason: String) -> void:
	if _grab.is_empty():
		return
	var peer: int = _grab.peer
	var head := _grab_head()
	var s := float(_grab.s)
	var fwd := sample_path(_grab.path, s + 0.6) - sample_path(_grab.path, maxf(0.0, s - 0.6))
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3(1, 0, 0)
	var rescue: Rescue = game.rescue
	if rescue.is_held(peer):
		var push := fwd * 3.0 + Vector3.UP * 2.5 if reason == "done" else -fwd * 1.5 + Vector3.UP * 1.5
		var dmg := Tuning.get_f("worm", "grab_end_damage", 0.35) if reason == "done" else 0.0
		rescue.host_release_grab(peer, push, dmg)
	_grab = {}
	_grab_cool = Tuning.get_f("worm", "grab_cd", 50.0)
	_cool = maxf(_cool, lerpf(Tuning.get_f("worm", "lunge_cd", 40.0), Tuning.get_f("worm", "lunge_cd_climax", 16.0), tension()) / _mult())
	pos = head + Vector3.DOWN * 4.0
	vel = Vector3.ZERO
	if reason in ["hit", "beacon"]:
		_repel_from(head, 10.0)
	else:
		mode = Mode.ROAM
		_wander_t = 0.0
	_quiet_noise_near(head, 14.0, 0.2)
	_rpc_grab_end.rpc(peer, reason, head)
	print("[worm] laat speler %d los (%s)" % [peer, reason])


# --- De Mol (host) -------------------------------------------------------------------------------

## Waar zijn kop de romp raakt: een straal van buiten naar het midden van de Mol, van de kant waar
## hij zit (iets lager dan het midden, niet onder de rupsen). {position, normal} in wereld.
func _hull_contact(mol: Mol) -> Dictionary:
	var mp := mol.body.global_position
	var dir := pos - mp
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.5:
		flat = mol.body.global_basis.x
	flat = flat.normalized()
	var from := dir.normalized() if dir.length() > 0.5 else -flat
	var d := (flat + Vector3.UP * clampf(from.y, -0.35, 0.15)).normalized()
	var aim := mp + Vector3.DOWN * 0.6
	var hit: Dictionary = game.terrain.raycast(aim + d * 10.0, aim, Layers.LIFT)
	if not hit.is_empty() and hit.collider == mol.body:
		return {"position": hit.position, "normal": hit.normal}
	return {"position": aim + d * 2.6, "normal": d}


## Host: midden in de dienst een duw tegen de Mol (ontwerp2-1). De Mol valt stil en wie staat gaat
## omver, maar de lading blijft heel. Daarna laat hij de Mol een tijd met rust en zoekt hij de ploeg.
func _shove(mol: Mol) -> void:
	var beacons: Beacons = game.beacons
	var mp := mol.body.global_position
	if beacons and beacons.nearest(mp).distance_to(mp) < Tuning.get_f("worm", "repel_m", 14.0):
		_repel()
		return
	var c := _hull_contact(mol)
	_shove_cool = Tuning.get_f("worm", "shove_cd", 60.0)
	_mol_deaf_t = Tuning.get_f("worm", "mol_deaf_s", 40.0)
	mol.speed = 0.0
	_knock_aboard(mol, c.normal)
	_quiet_noise_near(mp, 16.0, 0.1)
	mode = Mode.ROAM
	_wander_t = 0.0
	pos = (c.position as Vector3) + (c.normal as Vector3) * 3.0 + Vector3.DOWN * 3.0
	vel = Vector3.ZERO
	_rpc_ram.rpc(c.position, c.normal, false)
	print("[worm] duwt de Mol (de lading blijft heel)")


## Wie in de Mol rechtop staat, gaat omver (de stoel houdt de piloot vast).
func _knock_aboard(mol: Mol, normal: Vector3) -> void:
	for pl: Player in game.players.get_children():
		if not pl.seated and mol.contains_point(pl.global_position) and game.rescue.is_ok(pl.peer_id):
			var push := -normal * 3.0 + Vector3.UP * 2.0
			game.rescue.host_damage(pl.peer_id, Tuning.get_f("worm", "ram_knock_damage", 0.05), push, true, "worm")


## Host: de climax (ontwerp-7, ontwerp2-3). Hij bijt zich vast in de romp: de lading lijdt zolang hij
## bijt, de Mol rijdt trager. Een baken in een rijdende Mol telt niet; een baken buiten de Mol wel.
func _start_bite(mol: Mol) -> void:
	var beacons: Beacons = game.beacons
	var mp := mol.body.global_position
	if beacons and beacons.nearest(mp).distance_to(mp) < Tuning.get_f("worm", "repel_m", 14.0):
		_repel_from(beacons.nearest(mp), 5.0)
		_ram_cool = 3.0
		print("[worm] een baken bij de Mol: weggezwommen")
		return
	var c := _hull_contact(mol)
	var inv := mol.body.global_transform.affine_inverse()
	_bite = {"local": inv * (c.position as Vector3), "normal": mol.body.global_basis.inverse() * (c.normal as Vector3),
			"t": 0.0, "hp": Tuning.get_i("worm", "bite_hits", 2), "shake": 0, "sign": 0, "tick": 0.0}
	mode = Mode.BITE
	mol.speed = 0.0
	_knock_aboard(mol, c.normal)
	_rpc_ram.rpc(c.position, c.normal, true)
	_rpc_bite.rpc(_bite.local, _bite.normal)
	print("[worm] bijt zich vast in de Mol")


func _bite_head() -> Vector3:
	var mol: Mol = game.mol
	if _bite.is_empty() or mol == null or mol.body == null:
		return Vector3.INF
	var n := mol.body.global_basis * (_bite.normal as Vector3)
	return mol.body.global_transform * (_bite.local as Vector3) + n * (BITE_NODE - SKULL_AHEAD)


func _bite_step(dt: float) -> void:
	var mol: Mol = game.mol
	if not _climax() or _bite.is_empty():
		_end_bite("lost")
		return
	var b := _bite
	b.t = float(b.t) + dt
	var head := _bite_head()
	pos = head
	b.tick = float(b.tick) + dt
	if float(b.tick) >= 1.0:
		b.tick = float(b.tick) - 1.0
		var loss := Tuning.get_f("worm", "bite_cargo_loss_s", 0.035)
		for it: FindItem in mol.cargo_contents():
			var cond := maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss)
			if cond < it.condition - 0.001:
				game.finds._rpc_condition.rpc(it.find_id, cond)
	var beacons: Beacons = game.beacons
	if beacons and beacons.nearest(head).distance_to(head) < Tuning.get_f("worm", "repel_m", 14.0) * 0.7:
		_end_bite("beacon")
		return
	if float(b.t) >= Tuning.get_f("worm", "bite_s", 6.0):
		_end_bite("done")


## Host (Mol._extract): de piloot stuurt terwijl hij bijt. Elke keer van links naar rechts (of terug)
## schudt de Mol; na bite_shakes laat hij los.
func host_shake(steer: float) -> void:
	if mode != Mode.BITE or _bite.is_empty():
		return
	var sgn := 0 if absf(steer) < 0.5 else (1 if steer > 0.0 else -1)
	if sgn == 0 or sgn == int(_bite.sign):
		return
	_bite.sign = sgn
	_bite.shake = int(_bite.shake) + 1
	_rpc_struggled.rpc()
	if int(_bite.shake) >= Tuning.get_i("worm", "bite_shakes", 4):
		_end_bite("shake")


func _end_bite(reason: String) -> void:
	var head := _bite_head()
	_bite = {}
	_bites_done += 1
	_ram_cool = Tuning.get_f("worm", "bite_cd", 10.0)
	if head != Vector3.INF:
		pos = head + Vector3.DOWN * 4.0
	vel = Vector3.ZERO
	var mol: Mol = game.mol
	var from := mol.body.global_position if mol and mol.body else pos + Vector3.UP
	_repel_from(from, Tuning.get_f("worm", "bite_repel_s", 4.0) if reason != "beacon" else 8.0)
	_rpc_bite_end.rpc(reason)
	print("[worm] laat de Mol los (%s)" % reason)


# --- Slagen (lokaal → host) -----------------------------------------------------------------------

## Lokaal: het houweel raakte de kop (Pickaxe). Meteen beeld; de host beslist.
func request_hit(at: Vector3) -> void:
	if visual:
		visual.flinch(at)
	if Net.is_host():
		host_hit(Net.my_id(), at)
	else:
		_rpc_hit.rpc_id(1, at)


@rpc("any_peer", "reliable")
func _rpc_hit(at: Vector3) -> void:
	if multiplayer.is_server():
		host_hit(multiplayer.get_remote_sender_id(), at)


## Host: een slag op de kop. Dezelfde controle als bij de client (de kop binnen het bereik van het
## houweel), met wat speling voor de vertraging.
func host_hit(sender: int, at: Vector3) -> void:
	if not mode in [Mode.GRAB, Mode.BITE, Mode.LUNGE]:
		return
	var pl: Player = game.player_node(sender)
	if pl == null or not game.rescue.can_act(sender) or holds(sender):
		return
	var head := head_world()
	if head == Vector3.INF:
		return
	var reach := Tuning.get_f("worm", "hit_reach", 5.5)
	if pl.global_position.distance_to(head) > reach or at.distance_to(head) > 3.0:
		print("[worm] slag van %d geweigerd (%.1f m van de kop)" % [sender, pl.global_position.distance_to(head)])
		return
	var now := Time.get_ticks_msec()
	if now - int(_hit_ms.get(sender, -10000)) < 250:
		return
	_hit_ms[sender] = now
	_rpc_hurt.rpc(at)
	match mode:
		Mode.GRAB:
			_grab.hp = int(_grab.hp) - 1
			if int(_grab.hp) <= 0:
				_end_grab("hit")
		Mode.BITE:
			_bite.hp = int(_bite.hp) - 1
			if int(_bite.hp) <= 0:
				_end_bite("hit")


# --- Buit ---------------------------------------------------------------------------------------

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


## Een punt op een pad (polylijn) op afstand `s` van het begin.
static func sample_path(pts: PackedVector3Array, s: float) -> Vector3:
	if pts.is_empty():
		return Vector3.ZERO
	if s <= 0.0:
		return pts[0]
	for i in range(1, pts.size()):
		var seg := pts[i].distance_to(pts[i - 1])
		if s <= seg:
			return pts[i - 1].lerp(pts[i], s / maxf(seg, 0.0001))
		s -= seg
	return pts[pts.size() - 1]


# --- Op elk peer ---------------------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state(p: Vector3, m: int, act: float) -> void:
	if _net_pos == Vector3.ZERO or _net_pos.distance_to(p) > 30.0:
		pos = p
	_net_pos = p
	mode = m as Mode
	activity = act


@rpc("authority", "call_local", "reliable")
func _rpc_lunge(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, emerge: Vector3, normal: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	if not multiplayer.is_server():
		mode = Mode.LUNGE
	visual.play_lunge([p0, p1, p2, p3], emerge, normal, exit, tel, burst)
	lunge_started.emit(emerge)


@rpc("authority", "call_local", "reliable")
func _rpc_grab(peer: int, path: PackedVector3Array, speed: float) -> void:
	held_peer = peer
	if not multiplayer.is_server():
		mode = Mode.GRAB
	visual.play_grab(path, speed)
	grabbed.emit(peer)
	var me: Player = game.local_player
	if me and me.peer_id == peer:
		game.notice.emit("The %s has you! Mash %s to break free." % [NAME, Settings.key_of("jump")], "alarm")
	elif me and me.global_position.distance_to(path[0]) < 45.0:
		game.notice.emit("The %s grabbed %s! Hit it with your pickaxe, or throw a beacon at it!" % [NAME, game.rescue._name_of(peer)], "alarm")


@rpc("authority", "call_local", "reliable")
func _rpc_grab_end(peer: int, reason: String, at: Vector3) -> void:
	held_peer = -1
	visual.end_grab(at)
	released.emit(peer, reason)
	var me: Player = game.local_player
	if me == null or me.global_position.distance_to(at) > 45.0:
		return
	var who: String = "You" if me.peer_id == peer else game.rescue._name_of(peer)
	match reason:
		"struggle":
			game.notice.emit("%s broke free!" % who, "info")
		"hit", "beacon":
			game.notice.emit(("The %s let go of you!" % NAME) if me.peer_id == peer else ("You drove the %s off %s!" % [NAME, who]), "info")


@rpc("authority", "call_local", "reliable")
func _rpc_bite(local: Vector3, normal: Vector3) -> void:
	if not multiplayer.is_server():
		mode = Mode.BITE
	var mol: Mol = game.mol
	visual.play_bite(local, normal)
	if mol and mol.body:
		bite_started.emit(mol.body.global_transform * local)
	var me: Player = game.local_player
	if me and mol and mol.body and (me.seated or mol.contains_point(me.global_position)):
		var how := ("Rock the Mole (%s / %s)" % [Settings.key_of("move_left"), Settings.key_of("move_right")]) if me.seated \
				else ("%s in the hold: beacon out the back" % Settings.key_of("beacon"))
		game.notice.emit("The %s bit the Mole! %s to shake it off!" % [NAME, how], "alarm")


## De Mol vertrekt en de worm is wakker: hij hoort de motor (ontwerp2-3: wat de ploeg dan kan doen).
@rpc("authority", "call_local", "reliable")
func _rpc_climax_warn() -> void:
	var me: Player = game.local_player
	var mol: Mol = game.mol
	if me == null or mol == null or mol.body == null or not is_awake():
		return
	if me.seated or mol.contains_point(me.global_position):
		game.notice.emit("The %s hears the engine! %s: beacon out the back hatch." % [NAME, Settings.key_of("beacon")], "warn")


@rpc("authority", "call_local", "reliable")
func _rpc_bite_end(reason: String) -> void:
	visual.end_bite()
	bite_ended.emit(reason)
	var me: Player = game.local_player
	var mol: Mol = game.mol
	if me and mol and mol.body and (me.seated or mol.contains_point(me.global_position)) and reason in ["hit", "beacon", "shake"]:
		game.notice.emit("The %s let go of the Mole!" % NAME, "mol")


@rpc("authority", "call_local", "reliable")
func _rpc_ram(at: Vector3, normal: Vector3, bite: bool) -> void:
	var mol: Mol = game.mol
	if mol and mol.visual and mol.body:
		var local_n := mol.body.global_basis.inverse() * normal
		mol.visual.ram_hit(local_n, 1.0 if bite else 0.8)
	if mol and mol.ride_feel():
		mol.ride_feel().ram_hit(mol.body.global_basis.inverse() * normal, 1.0 if bite else 0.8)
	if not bite:
		visual.play_ram(at, normal)
	var p: Player = game.local_player
	if p and p.camera_fx:
		var k := 1.0 - smoothstep(4.0, 30.0, p.global_position.distance_to(at))
		p.camera_fx.add_trauma(1.0 * k)
		p.camera_fx.hold_rumble(6.0 * k)
	rammed.emit(at)
	if not bite and p and mol and mol.body and (p.seated or mol.contains_point(p.global_position)):
		game.notice.emit("The %s shoved the Mole! It's after the crew now." % NAME, "warn")


@rpc("authority", "call_local", "reliable")
func _rpc_hurt(at: Vector3) -> void:
	if visual and not (game.local_player and at.distance_to(game.local_player.global_position) < 0.01):
		visual.flinch(at)
	hurt.emit(at)


@rpc("authority", "call_local", "reliable")
func _rpc_struggled() -> void:
	if visual:
		visual.jerk()
	struggled.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_swallow(find_id: int) -> void:
	var it: FindItem = game.finds.item(find_id)
	if it == null:
		return
	visual.gulp(it.global_position)
	if not it.carriers.is_empty():
		it.last_carriers = it.carriers
	# Twee "dragers" die geen speler zijn: niemand kan hem pakken, en hij telt niet als gesleept (F3).
	it.carriers = PackedInt32Array([BELLY, BELLY - 1])
	it.visible = false
	it.collision_layer = 0
	if multiplayer.is_server():
		it.freeze = true
	it.update_interpolation()
	game.finds.carriers_changed.emit(it)
	swallowed.emit(find_id)
	var p: Player = game.local_player
	if p and p.global_position.distance_to(it.global_position) < 30.0:
		game.notice.emit("The %s swallowed the %s!" % [NAME, it.display_name().to_lower()], "warn")


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


## Late joiner: waar hij is, wat hij doet, wat er in zijn buik zit, en wie hij vasthoudt of bijt.
func send_state(peer: int) -> void:
	_rpc_state.rpc_id(peer, pos, mode, activity)
	for id in _carried:
		_rpc_swallow.rpc_id(peer, id)
	if not _grab.is_empty():
		var rest := PackedVector3Array([_grab_head()])
		var path: PackedVector3Array = _grab.path
		var s := float(_grab.s)
		var acc := 0.0
		for i in range(1, path.size()):
			acc += path[i].distance_to(path[i - 1])
			if acc > s:
				rest.append(path[i])
		_rpc_grab.rpc_id(peer, int(_grab.peer), rest, Tuning.get_f("worm", "grab_speed", 2.6))
	if not _bite.is_empty():
		_rpc_bite.rpc_id(peer, _bite.local, _bite.normal)


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
	# De markering op de vloer: boven de worm, waar de rots ophoudt (niet als hij boven de grond is).
	_marker_t -= delta
	var md := Tuning.get_f("worm", "marker_m", 24.0)
	if _marker_t <= 0.0:
		_marker_t = 0.3
		var floor_p := _floor_above(pos) if d < md + 12.0 and not mode in [Mode.GRAB, Mode.BITE] else Vector3.INF
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
