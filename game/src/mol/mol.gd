class_name Mol
extends Node3D
## De Mol: rijdende tunnelboormachine en basis (GDD §5A, docs/de-mol.md).
## - De host simuleert: rijden, boren (grote bol-ops via TerrainSync), steun en vallen,
##   brandstof, autopiloot (spiraal naar beneden) en extractie (eigen spoor terug omhoog).
## - De piloot (één peer) stuurt enkel invoer. Iedereen interpoleert de toestand van de host.
## - Spelers en vondsten in de Mol worden relatief tot de Mol gesynchroniseerd (zie Player, FindField).
## Staat op elk peer op Game/Mol zodat RPC's aankomen. Deze node zelf beweegt niet; `body` wel.

signal mode_changed(mode: Mode)
signal pilot_changed(peer: int)
signal summary(count: int, value: int, left_behind: int)

## Erts van de laatste extractie (gezet net voor `summary`).
var last_ore_units := 0
var last_ore_value := 0
signal message(text: String)

enum Mode { PARKED, DRIVING, AUTO_DOWN, COUNTDOWN, EXTRACTING }
enum Cmd { SEAT, AUTO, HORN, LIGHTS, RAMP, DEPART, WORKBENCH }
enum Event { HORN, BLOCKED, DEPART, BEEP, ARRIVED }

const TIER := Strata.Tool.BOOR_T1
const BORE_RADIUS := 3.2
const BORE_AHEAD := 6.4 # middelpunt van de boorbol voor het midden van de Mol
const BORE_STEP := 0.9 # meter tussen twee boorbollen
## Boorbol iets onder de as: de tunnelvloer ligt dan net onder de rupsen (anders tilt de steun de Mol
## telkens een paar cm op en komt hij nooit vooruit naar beneden).
const BORE_DROP := 0.12
const BORE_BITES := 6 # happen uit de wand per boorbol (ruwe tunnel)
## Steun met dode zone: binnen [-LIFT_AT, FALL_AT] blijft de hoogte staan (voxelruis is ±5 cm).
const LIFT_AT := 0.12
const FALL_AT := 0.2
const TRACK_POINTS := [Vector3(-1.5, -2.55, -2.8), Vector3(1.5, -2.55, -2.8), Vector3(-1.5, -2.55, 0.2),
		Vector3(1.5, -2.55, 0.2), Vector3(-1.5, -2.55, 3.0), Vector3(1.5, -2.55, 3.0)]
const TRACK_BOTTOM := -2.73 # onderkant van de rupsen (lokaal y) waar ze de grond raken
## Straal (vanaf de as) waarbinnen de romp met de rupsen valt: daar mag geen rots zijn.
const HULL_PROBE := 3.15 # rupsen liggen op ±3,11 m; boorbol 3,2 m
## Kopruimte: bollen iets boven de as, die de romp vrijmaken maar nooit de grond onder de rupsen.
const HEADROOM_LIFT := 0.5
const HEADROOM_RADIUS := 3.0
const HEADROOM_EVERY := 0.3 # meter optillen tussen twee keer vrijmaken
## Dikte van buitenmuur + marge (TerrainAPI._clamp_center: 3,5 voxels) in meter.
const EDGE_MARGIN := 2.25
## Binnenruimte (lokaal) voor "staat in de Mol".
const INSIDE := AABB(Vector3(-2.2, -1.65, -3.75), Vector3(4.4, 3.6, 8.1))
const SEND_INTERVAL := 0.05
const INTERP_DELAY_MS := 100.0

var game: Node # Game
var body: AnimatableBody3D
var visual: MolVisual
## Sonar (lokaal op elke peer, enkel bijgewerkt als iemand hier in de Mol kijkt).
var sonar := Sonar.new()

# Toestand (host bepaalt, iedereen kent).
var mode := Mode.PARKED
var pilot := 0
var yaw := 0.0
var pitch := 0.0
var speed := 0.0
var drilling := false
var blocked := false
## Geblokkeerd door de buitenmuur van de put (niet door te hard gesteente).
var at_edge := false
var ramp_open := true
var lights_on := true
var fuel := 1.0
var countdown := 0.0
var auto_depth := 0.0

# Host.
var _input := Vector3.ZERO # throttle, steer, pitch
var _input_time := 0.0
var _vy := 0.0
var _since_bore := 0.0
var _yaw_since_bore := 0.0
var _lift_since_clear := 0.0
var _path: Array[Vector3] = []
var _path_index := 0
var _auto_level_dist := 0.0
var _send_timer := 0.0
var _blocked_sound := 0.0
var _beep_timer := 0.0
var _start_pos := Vector3.ZERO
var _readout_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _ramp_shape: CollisionShape3D
var _visual_yaw := 0.0
var _teleport: Variant = null # [pos, yaw, pitch], toegepast in de volgende physics-tick

# Clients.
var _snapshots: Array = [] # [tijd ms, pos, yaw, pitch, speed]
var _clock_offset := INF

# Piloot (lokaal).
var _pilot_send := 0.0


func setup() -> void:
	var t: TerrainAPI = game.terrain
	_rng.seed = t.pit_seed * 7919 + 13
	var c := t.shaft_center_world()
	_start_pos = Vector3(c.x, t.surface_height_at(c.x, c.z) - TRACK_BOTTOM, c.z)
	body = AnimatableBody3D.new()
	body.name = "Body"
	body.sync_to_physics = true
	body.collision_layer = Layers.LIFT
	body.collision_mask = 0
	add_child(body)
	visual = MolVisual.new()
	visual.name = "Visual"
	body.add_child(visual)
	_build_collision()
	_build_buttons()
	# Terrein rond de Mol: hij boort en rijdt ook als niemand in de buurt is (autopiloot, extractie).
	t.add_viewer(body, Tuning.get_f("terrain", "view_m", 110.0), Tuning.get_f("terrain", "collision_m", 48.0))
	_place(_start_pos, 0.0, 0.0)
	_path = [_start_pos]


# --- Vragen ---------------------------------------------------------------------------

## Host: een melding voor iedereen (ook van FindField, bv. een opgeschepte vondst).
func announce(text: String) -> void:
	_rpc_message.rpc(text)


## Host: de Mol ergens neerzetten (tests, later respawn). In de volgende physics-tick, want het
## lichaam (sync_to_physics) neemt een verplaatsing van buiten die tick niet over.
func teleport(pos: Vector3, new_yaw: float, new_pitch: float) -> void:
	_teleport = [pos, new_yaw, new_pitch]


func forward() -> Vector3:
	return -body.global_basis.z


func depth() -> float:
	var p := body.global_position
	return maxf(0.0, game.terrain.surface_height_at(p.x, p.z) - (p.y + TRACK_BOTTOM))


## Staat een wereldpunt in de Mol (binnenruimte of op de open laadklep)?
func contains_point(world: Vector3) -> bool:
	var local := body.global_transform.affine_inverse() * world
	if INSIDE.has_point(local):
		return true
	if ramp_open: # op de klep, die schuin naar de vloer loopt
		return local.z > 4.0 and local.z < 7.2 and absf(local.x) < 2.1 and local.y > -3.4 and local.y < -0.5
	return false


## Mond van de ertstrechter (laadruim, linkerwand).
func chute_position() -> Vector3:
	return (visual.anchors["Ore_Chute"] as Node3D).global_position


## Staat een wereldpunt in de cabine (voor de woonruimte)? Daar zet E je aan het stuur.
func in_cockpit(world: Vector3) -> bool:
	var local := body.global_transform.affine_inverse() * world
	return INSIDE.has_point(local) and local.z < -1.2


func to_local_mol(world: Vector3) -> Vector3:
	return body.global_transform.affine_inverse() * world


func to_world_mol(local: Vector3) -> Vector3:
	return body.global_transform * local


func cargo_contents() -> Array:
	var items: Array = []
	for it: FindItem in game.finds.items:
		if it.freed and it.carriers.is_empty():
			var local := to_local_mol(it.global_position)
			if INSIDE.has_point(local):
				items.append(it)
	return items


# --- Bediening (lokaal → host) --------------------------------------------------------------

func press(button: Cmd, arg: float = 0.0) -> void:
	if button == Cmd.WORKBENCH:
		message.emit("Werkbank: upgrades voor de Mol komen later.")
		return
	if Net.is_host():
		_handle(Net.my_id(), button, arg)
	else:
		_rpc_press.rpc_id(1, button, arg)


func leave_seat() -> void:
	if Net.is_host():
		_handle_leave(Net.my_id())
	else:
		_rpc_leave.rpc_id(1)


## Piloot: invoer (gas, sturen, neus) naar de host, ±20×/s.
func send_input(throttle: float, steer: float, pitch_in: float, delta: float) -> void:
	_pilot_send += delta
	if _pilot_send < SEND_INTERVAL and Net.is_host() == false:
		return
	_pilot_send = 0.0
	if Net.is_host():
		_set_input(Net.my_id(), throttle, steer, pitch_in)
	else:
		_rpc_input.rpc_id(1, throttle, steer, pitch_in)


@rpc("any_peer", "reliable")
func _rpc_press(button: int, arg: float) -> void:
	if multiplayer.is_server():
		_handle(multiplayer.get_remote_sender_id(), button, arg)


@rpc("any_peer", "reliable")
func _rpc_leave() -> void:
	if multiplayer.is_server():
		_handle_leave(multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable_ordered")
func _rpc_input(throttle: float, steer: float, pitch_in: float) -> void:
	if multiplayer.is_server():
		_set_input(multiplayer.get_remote_sender_id(), throttle, steer, pitch_in)


func _set_input(sender: int, throttle: float, steer: float, pitch_in: float) -> void:
	if sender != pilot:
		return
	_input = Vector3(clampf(throttle, -1, 1), clampf(steer, -1, 1), clampf(pitch_in, -1, 1))
	_input_time = Time.get_ticks_msec() / 1000.0


func _handle(sender: int, button: int, arg: float) -> void:
	var p: Player = game.player_node(sender)
	if p == null:
		return
	var inside := contains_point(p.global_position)
	var near := p.global_position.distance_to(body.global_position) < 9.0
	match button:
		Cmd.SEAT:
			if inside and pilot == 0 and mode != Mode.EXTRACTING and mode != Mode.COUNTDOWN:
				_set_mode(Mode.DRIVING if mode == Mode.PARKED else mode, sender)
		Cmd.HORN:
			if inside:
				_rpc_event.rpc(Event.HORN)
		Cmd.LIGHTS:
			if inside:
				_rpc_flags.rpc(ramp_open, not lights_on)
		Cmd.RAMP:
			if (inside or near) and absf(speed) < 0.3 and mode != Mode.EXTRACTING:
				_rpc_flags.rpc(not ramp_open, lights_on)
		Cmd.AUTO:
			if inside and mode in [Mode.PARKED, Mode.DRIVING] and arg > depth() + 2.0:
				auto_depth = arg
				_auto_level_dist = 0.0
				_rpc_flags.rpc(false, lights_on)
				_set_mode(Mode.AUTO_DOWN, pilot)
				_rpc_message.rpc("Autopiloot: afdalen tot −%d m" % int(arg))
		Cmd.DEPART:
			if inside and mode in [Mode.PARKED, Mode.DRIVING, Mode.AUTO_DOWN] and _path.size() > 1:
				countdown = Tuning.get_f("mol", "countdown_s", 10.0)
				_beep_timer = 0.0
				_rpc_event.rpc(Event.HORN)
				_set_mode(Mode.COUNTDOWN, 0)


func _handle_leave(sender: int) -> void:
	if sender == pilot:
		_set_mode(Mode.PARKED if mode == Mode.DRIVING else mode, 0)


func _set_mode(new_mode: Mode, new_pilot: int) -> void:
	_rpc_mode.rpc(new_mode, new_pilot, countdown)


@rpc("authority", "call_local", "reliable")
func _rpc_mode(new_mode: int, new_pilot: int, cd: float) -> void:
	var pilot_was := pilot
	mode = new_mode
	pilot = new_pilot
	countdown = cd
	if pilot != pilot_was:
		pilot_changed.emit(pilot)
		_input = Vector3.ZERO
	mode_changed.emit(mode)


@rpc("authority", "call_local", "reliable")
func _rpc_flags(new_ramp: bool, new_lights: bool) -> void:
	ramp_open = new_ramp
	lights_on = new_lights


@rpc("authority", "call_local", "reliable")
func _rpc_event(event: int) -> void:
	match event:
		Event.HORN:
			visual.play("mol_horn", Vector3(0, 2.3, -3.0), 0.0)
		Event.BLOCKED:
			visual.play("mol_blocked", Vector3(0, 0, -7.0), -2.0)
		Event.DEPART:
			visual.play("mol_depart", Vector3(0, 2.0, 2.5), 0.0)
		Event.BEEP:
			visual.play("mol_beep", Vector3(0, 0.5, -2.5), -4.0)
		Event.ARRIVED:
			visual.play("mol_hydraulic", Vector3(0, -1.0, 4.0), -4.0)


@rpc("authority", "call_local", "reliable")
func _rpc_message(text: String) -> void:
	message.emit(text)


@rpc("authority", "call_local", "reliable")
func _rpc_summary(count: int, value: int, left_behind: int, ore_units: int, ore_value: int) -> void:
	last_ore_units = ore_units
	last_ore_value = ore_value
	summary.emit(count, value, left_behind)


## Late joiner: alles wat hij moet weten.
func send_state(peer: int) -> void:
	_rpc_full.rpc_id(peer, body.global_position, yaw, pitch, mode, pilot, ramp_open, lights_on, fuel)


@rpc("authority", "reliable")
func _rpc_full(pos: Vector3, y: float, p: float, m: int, pl: int, ramp: bool, lights: bool, f: float) -> void:
	_place(pos, y, p)
	mode = m
	pilot = pl
	ramp_open = ramp
	lights_on = lights
	fuel = f


# --- Simulatie (host) --------------------------------------------------------------------------

## Sonar: elke frame (vloeiende veeg), enkel als de lokale speler in de Mol is.
func _process(delta: float) -> void:
	if body == null or not visual.feed_active:
		return
	var noise := clampf(absf(speed) / 3.0, 0.0, 1.0) * Tuning.get_f("mol", "sonar_noise_driving", 0.35)
	if drilling:
		noise += Tuning.get_f("mol", "sonar_noise_drilling", 0.7)
	sonar.noise = clampf(noise, 0.0, 1.0)
	sonar.update(delta, body.global_transform, game.finds.items, contains_point)
	visual.sonar_screen.display(sonar, body.global_transform, delta)


func _physics_process(delta: float) -> void:
	if body == null:
		return
	if multiplayer.is_server():
		if _teleport != null:
			_place(_teleport[0], _teleport[1], _teleport[2])
			_path = [_teleport[0] as Vector3]
			_vy = 0.0
			speed = 0.0
			_teleport = null
			return
		if game.terrain.is_loaded:
			_simulate(delta)
		_send_state(delta)
	else:
		_interpolate()
	_update_visual()


func _simulate(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var inp := _input if now - _input_time < 0.5 else Vector3.ZERO
	match mode:
		Mode.AUTO_DOWN:
			inp = _autopilot_down(delta)
		Mode.COUNTDOWN:
			inp = Vector3.ZERO
			countdown -= delta
			_beep_timer -= delta
			if _beep_timer <= 0.0:
				_beep_timer = 1.0
				_rpc_event.rpc(Event.BEEP)
			if countdown <= 0.0:
				_rpc_event.rpc(Event.DEPART)
				_rpc_flags.rpc(false, lights_on)
				_path_index = _path.size() - 2
				_set_mode(Mode.EXTRACTING, 0)
		Mode.EXTRACTING:
			_extract(delta)
			return
		Mode.PARKED:
			inp = Vector3.ZERO
	_drive(inp, delta)


func _drive(inp: Vector3, delta: float) -> void:
	var throttle := inp.x
	var auto := mode == Mode.AUTO_DOWN
	# Neus en draaien.
	var max_pitch := deg_to_rad(Tuning.get_f("mol", "max_pitch_deg", 25.0))
	var pitch_was := pitch
	pitch = clampf(pitch + inp.z * deg_to_rad(Tuning.get_f("mol", "pitch_rate_deg", 12.0)) * delta, -max_pitch, max_pitch)
	var turn := -inp.y * deg_to_rad(Tuning.get_f("mol", "yaw_rate_deg", 22.0)) * delta * (0.7 if drilling and not auto else 1.0)
	var yaw_was := yaw
	var overlap_was := _edge_overlap(body.global_position, forward())
	yaw += turn
	_place(body.global_position, yaw, pitch)
	# Draaien of kantelen dat kop of staart in de buitenmuur zwaait: niet doen.
	if _edge_overlap(body.global_position, forward()) > overlap_was + 0.001:
		turn = 0.0
		yaw = yaw_was
		pitch = pitch_was
		_place(body.global_position, yaw, pitch)
	_yaw_since_bore += absf(turn) + absf(pitch - pitch_was)

	# Wat ligt er voor de kop?
	var fwd := forward()
	# Rots vooraan: een ring zo breed als de romp met de rupsen (anders rijdt hij door een grot
	# "zonder rots" terwijl de flanken en rupsen door de grotwand gaan). Te hard: de smalle kern.
	var ahead := body.global_position + fwd * (BORE_AHEAD + 1.9)
	var probe := _probe_ring(ahead, fwd)
	var rock: bool = probe[0]
	var hull_rock: bool = rock or _probe_ring(ahead, fwd, HULL_PROBE, 12)[0]
	var too_hard: bool = probe[1]
	var rear_rock: bool = _probe_ring(body.global_position - fwd * 5.4, fwd)[0]
	var bore_speed := Tuning.get_f("mol", "bore_speed", 3.0)
	var open_speed := Tuning.get_f("mol", "open_speed", 5.0)
	var auto_speed := Tuning.get_f("mol", "auto_speed", 6.0)
	var target := 0.0
	if throttle > 0.0:
		target = throttle * (auto_speed if auto else (bore_speed if rock else open_speed))
	elif throttle < 0.0:
		target = throttle * Tuning.get_f("mol", "reverse_speed", 2.0)
	var was_blocked := blocked
	# De buitenmuur van de put kan de boorkop niet aan: de volgende boorbol moet er helemaal in passen.
	at_edge = throttle > 0.0 and not game.terrain.sphere_fits(body.global_position + fwd * (BORE_AHEAD + BORE_STEP), BORE_RADIUS)
	blocked = throttle > 0.0 and (too_hard or at_edge)
	if blocked:
		target = minf(target, 0.0)
	if throttle < 0.0 and rear_rock:
		target = 0.0
	if fuel <= 0.0:
		target = 0.0
	var braking := absf(target) < absf(speed) or signf(target) != signf(speed)
	speed = move_toward(speed, target, Tuning.get_f("mol", "braking" if braking else "acceleration", 1.6) * delta)
	if blocked and speed > 0.0:
		speed = 0.0
	drilling = speed > 0.1 and rock

	# Bewegen, boren, brandstof.
	var step := fwd * speed * delta
	var pos := body.global_position + step
	_since_bore += step.length()
	if speed > 0.05 and (hull_rock or _since_bore >= BORE_STEP * 3.0) and _since_bore >= BORE_STEP:
		_since_bore = 0.0
		_bore(pos + fwd * BORE_AHEAD)
	if _yaw_since_bore > deg_to_rad(3.0):
		_yaw_since_bore = 0.0
		_shave_body(pos, fwd)
	fuel = maxf(0.0, fuel - step.length() * (1.0 / Tuning.get_f("mol", "fuel_m_boring", 400.0) if drilling else 1.0 / Tuning.get_f("mol", "fuel_m_driving", 1500.0)))
	if blocked and not was_blocked or blocked and _blocked_sound <= 0.0:
		_blocked_sound = 1.0
		_rpc_event.rpc(Event.BLOCKED)
	_blocked_sound -= delta

	# Steun: de rupsen rusten op de grond, anders zakt hij. Tilt de steun hem op (een grotvloer,
	# een bult), dan komt de romp hoger dan de geboorde tunnel: kopruimte vrijmaken.
	var before_y := pos.y
	pos = _support(pos, delta)
	if pos.y > before_y:
		_lift_since_clear += pos.y - before_y
		if _lift_since_clear > HEADROOM_EVERY:
			_lift_since_clear = 0.0
			_clear_headroom(pos, fwd)
	pos = _clamp_bounds(pos)
	_place(pos, yaw, pitch)
	if absf(speed) > 0.3 and ramp_open:
		_rpc_flags.rpc(false, lights_on)
	_record_path(pos)


## Hoe ver kop en staart buiten het graafbare deel zouden boren (0 = past).
func _edge_overlap(pos: Vector3, fwd: Vector3) -> float:
	var out := 0.0
	for off: float in [SHAVE_OFFSETS[0], SHAVE_OFFSETS[-1]]:
		var c: Vector3 = pos + fwd * off
		if not game.terrain.sphere_fits(c, BORE_RADIUS):
			out += _edge_distance(c)
	return out


## Afstand die een boorbol in de buitenmuur zou zitten (x, z en de bodem).
func _edge_distance(c: Vector3) -> float:
	var size: Vector3 = game.terrain.world_size()
	var m := EDGE_MARGIN + BORE_RADIUS
	return maxf(0.0, m - c.x) + maxf(0.0, c.x - (size.x - m)) + maxf(0.0, m - c.z) + maxf(0.0, c.z - (size.z - m)) + maxf(0.0, m - c.y)


## Ring van proefpunten loodrecht op de rijrichting: [rots?, te hard?].
func _probe_ring(center: Vector3, fwd: Vector3, radius := 2.4, count := 8) -> Array:
	var t: TerrainAPI = game.terrain
	var right := fwd.cross(Vector3.UP)
	if right.length() < 0.1:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(fwd).normalized()
	var rock := false
	var hard := false
	var points: Array[Vector3] = [center]
	for k in count:
		var a := k / float(count) * TAU
		points.append(center + (right * cos(a) + up * sin(a)) * radius)
	for p in points:
		if t.is_solid(p):
			rock = true
			if not Strata.can_dig(t.layer_at(p), TIER):
				hard = true
	return [rock, hard]


## Draaien of kantelen: voor- en achterkant zwaaien opzij. Over de hele lengte vrijmaken waar
## rots tegen de romp zit (bollen om de 1,6 m: daartussen blijft de tunnel breder dan de romp).
const SHAVE_OFFSETS := [6.4, 4.8, 3.2, 1.6, 0.0, -1.6, -3.2, -4.4] # meter vóór het midden (+ = richting de kop)


## Omtrek van de romp met de rupsen (lokaal x, y), iets ruimer genomen. Een ring van 8 punten
## miste rots tussen de punten: dan bleef er bij het draaien een hoek rots in de cabine.
const HULL_OUTLINE := [Vector2(0, 2.2), Vector2(-1.6, 2.2), Vector2(1.6, 2.2), Vector2(-2.5, 1.3), Vector2(2.5, 1.3),
		Vector2(-2.5, 0.0), Vector2(2.5, 0.0), Vector2(-2.5, -1.3), Vector2(2.5, -1.3), Vector2(-2.05, -2.5),
		Vector2(2.05, -2.5), Vector2(-1.2, -2.85), Vector2(1.2, -2.85), Vector2(0, -2.45)]
const HEAD_FROM := 4.0 # vanaf zoveel meter voor het midden: de ronde boorkop (straal 3,0)


func _shave_body(pos: Vector3, fwd: Vector3) -> void:
	var basis := body.global_basis
	for off: float in SHAVE_OFFSETS:
		var c: Vector3 = pos + fwd * off
		var touches: bool = _probe_ring(c, fwd, HULL_PROBE - 0.15, 16)[0] if off >= HEAD_FROM else _outline_touches(c, basis)
		if touches:
			_bore(c)


func _outline_touches(c: Vector3, basis: Basis) -> bool:
	for q: Vector2 in HULL_OUTLINE:
		if game.terrain.is_solid(c + basis.x * q.x + basis.y * q.y):
			return true
	return false


## Boorbol plus een paar happen uit wand en plafond (nooit uit de vloer: de rupsen rijden glad),
## zodat de tunnel ruw en brokkelig wordt in plaats van een gladde buis.
func _bore(center: Vector3) -> void:
	center -= body.global_basis.y * BORE_DROP
	_scoop_finds(center)
	var bites: Array = []
	var basis := body.global_basis
	for k in BORE_BITES:
		var d := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1.0, 1.0))
		if d.length() < 0.2:
			continue
		d = d.normalized()
		if d.y < -0.2: # niet in de vloer
			continue
		var r := _rng.randf_range(0.45, 0.95)
		bites.append([center + basis * d * (BORE_RADIUS - r * 0.4), r])
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, center, BORE_RADIUS, bites))


## De steun tilde de Mol op: rots boven de rupsen wegnemen over de hele lengte, nooit eronder
## (anders zakt hij meteen terug). Zonder dit reed hij in een grot met de cabine in de rots.
func _clear_headroom(pos: Vector3, fwd: Vector3) -> void:
	var up := body.global_basis.y
	for off: float in SHAVE_OFFSETS:
		var c: Vector3 = pos + fwd * off + up * HEADROOM_LIFT
		if _probe_ring(c, fwd, 2.6, 12)[0] or game.terrain.is_solid(c + up * 2.2):
			_scoop_finds(c)
			game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, c, HEADROOM_RADIUS))


## Vondsten die nog in de rots zitten en binnen het bereik van deze boorbol liggen, schept de
## boorkop op en legt hij in het laadruim, zwaar beschadigd (FindField.host_mol_scoop). Anders
## bleef de korst in de tunnel of in de Mol zweven. Zelf uitbikken blijft zo de moeite waard.
func _scoop_finds(center: Vector3) -> void:
	var reach := BORE_RADIUS + 0.6 # boorbol plus de happen uit de wand
	for it: FindItem in game.finds.items:
		if not it.freed and it.global_position.distance_to(center) < reach + it.half_extents.length():
			game.finds.host_mol_scoop(it, self)


## De rupsen rusten op de grond. Gemeten in de terreindata (SDF), niet met botsvormen:
## die zijn er pas als het blok gemesht is, en dan zou de Mol bij de start door de grond vallen.
func _support(pos: Vector3, delta: float) -> Vector3:
	var t: TerrainAPI = game.terrain
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var gap := INF # kleinste afstand tussen een rups en de grond (positief = zweeft)
	for p: Vector3 in TRACK_POINTS:
		var bottom: Vector3 = pos + basis * Vector3(p.x, TRACK_BOTTOM, p.z)
		gap = minf(gap, t.sdf_at(bottom))
	if CmdArgs.has("mol-debug") and Engine.get_physics_frames() % 15 == 0:
		print("[mol] y=%.2f depth=%.2f pitch=%.1f speed=%.2f gap=%.3f mode=%d blocked=%s" % [pos.y, depth(), rad_to_deg(pitch), speed, gap, mode, blocked])
	if gap > FALL_AT or _vy < 0.0 and gap > 0.06:
		_vy -= 9.8 * delta
		pos.y += maxf(_vy * delta, -(gap - 0.05))
	else:
		_vy = 0.0
		if gap < -LIFT_AT: # rupsen in de grond: optillen (bv. een bult opgereden)
			pos.y += minf(-gap - 0.04, 3.0 * delta)
	return pos


func _clamp_bounds(pos: Vector3) -> Vector3:
	var size: Vector3 = game.terrain.world_size()
	pos.x = clampf(pos.x, 4.5, size.x - 4.5)
	pos.z = clampf(pos.z, 4.5, size.z - 4.5)
	pos.y = clampf(pos.y, 3.6, size.y)
	return pos


func _record_path(pos: Vector3) -> void:
	if _path.is_empty() or _path[-1].distance_to(pos) < 1.0:
		return
	# Lussen eruit: komen we vlak bij een ouder punt, dan knippen we alles daarna weg.
	for i in range(0, _path.size() - 6):
		if _path[i].distance_to(pos) < 2.0:
			_path.resize(i + 1)
			break
	_path.append(pos)


func _autopilot_down(delta: float) -> Vector3:
	var d := depth()
	var radius := Tuning.get_f("mol", "spiral_radius", 11.0)
	var auto_speed := Tuning.get_f("mol", "auto_speed", 6.0)
	if blocked and d < auto_depth - 1.0:
		auto_depth = d
		_rpc_message.rpc(("Rand van de put" if at_edge else "Harde laag") + ": de autopiloot stopt op %d m" % int(d))
	if d < auto_depth - 1.0:
		var want := deg_to_rad(-Tuning.get_f("mol", "auto_pitch_deg", 22.0))
		var p_in := clampf((want - pitch) * 4.0, -1.0, 1.0)
		var yaw_rate := auto_speed / radius
		# De autopiloot mag scherper draaien dan een piloot (steer > 1).
		var steer := -rad_to_deg(yaw_rate) / Tuning.get_f("mol", "yaw_rate_deg", 22.0)
		return Vector3(1.0, steer, p_in)
	# Waterpas komen en nog een stukje rechtdoor.
	var p_in2 := clampf(-pitch * 4.0, -1.0, 1.0)
	_auto_level_dist += absf(speed) * delta
	if absf(pitch) < deg_to_rad(1.0) and _auto_level_dist > 6.0:
		speed = 0.0
		_place(body.global_position, yaw, 0.0)
		_rpc_flags.rpc(true, lights_on)
		_set_mode(Mode.DRIVING if pilot != 0 else Mode.PARKED, pilot)
		_rpc_event.rpc(Event.ARRIVED)
		return Vector3.ZERO
	return Vector3(0.6, 0.0, p_in2)


func _extract(delta: float) -> void:
	if _path_index < 0:
		speed = 0.0
		drilling = false
		var items := cargo_contents()
		var value := 0
		for it: FindItem in items:
			value += it.value()
		_path = [body.global_position]
		fuel = 1.0 # boven wordt bijgetankt: brandstof is per dienst
		_rpc_flags.rpc(true, lights_on)
		_set_mode(Mode.PARKED, 0)
		_rpc_event.rpc(Event.ARRIVED)
		# Wie niet aan boord was, klom te voet door de tunnel naar boven.
		var left := 0
		var left_peers: Array = []
		for pl: Player in game.players.get_children():
			if not pl.seated and not contains_point(pl.global_position):
				pl.host_teleport(game.spawn_pos_of(pl.peer_id))
				left += 1
				left_peers.append(pl.peer_id)
		var ores: OreField = game.ores
		_rpc_summary.rpc(items.size(), value, left, OreField.units(ores.hold), OreField.value(ores.hold))
		ores.host_after_extraction(left_peers)
		return
	var target := _path[_path_index]
	var pos := body.global_position
	var to := target - pos
	if to.length() < 0.6:
		_path_index -= 1
		return
	var v := Tuning.get_f("mol", "extract_speed", 6.0)
	speed = move_toward(speed, -v, Tuning.get_f("mol", "acceleration", 1.6) * 2.0 * delta)
	pos += to.normalized() * minf(absf(speed) * delta, to.length())
	# De Mol rijdt achteruit terug: de neus wijst weg van de rijrichting.
	var fwd := -to.normalized()
	var want_yaw := atan2(-fwd.x, -fwd.z)
	var want_pitch := clampf(asin(clampf(fwd.y, -1.0, 1.0)), deg_to_rad(-30.0), deg_to_rad(30.0))
	yaw = lerp_angle(yaw, want_yaw, minf(1.0, delta * 2.0))
	pitch = lerpf(pitch, want_pitch, minf(1.0, delta * 2.0))
	drilling = false
	blocked = false
	_place(pos, yaw, pitch)


func _place(pos: Vector3, y: float, p: float) -> void:
	yaw = y
	pitch = p
	body.global_transform = Transform3D(Basis.from_euler(Vector3(p, y, 0.0)), pos)


# --- Netwerk -------------------------------------------------------------------------------------

func _send_state(delta: float) -> void:
	_send_timer += delta
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0
	var flags := int(drilling) | (int(blocked) << 1) | (int(at_edge) << 2)
	for peer: int in game.ready_peers:
		if peer != multiplayer.get_unique_id():
			_rpc_state.rpc_id(peer, Time.get_ticks_msec(), body.global_position, yaw, pitch, speed, flags, fuel)


@rpc("authority", "unreliable_ordered")
func _rpc_state(sent_ms: int, pos: Vector3, y: float, p: float, spd: float, flags: int, f: float) -> void:
	var now := float(Time.get_ticks_msec())
	_clock_offset = minf(_clock_offset, now - sent_ms)
	_snapshots.append([float(sent_ms) + _clock_offset, pos, y, p, spd])
	if _snapshots.size() > 30:
		_snapshots.pop_front()
	drilling = flags & 1 != 0
	blocked = flags & 2 != 0
	at_edge = flags & 4 != 0
	fuel = f


func _interpolate() -> void:
	if _snapshots.is_empty():
		return
	var render_t := float(Time.get_ticks_msec()) - INTERP_DELAY_MS
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	speed = lerpf(a[4], b[4], k)
	_place((a[1] as Vector3).lerp(b[1], k), lerp_angle(a[2], b[2], k), lerp_angle(a[3], b[3], k))


func _update_visual() -> void:
	# Hendels uit wat de Mol doet (zo zien alle peers ze bewegen): gas en draaien als rupsverschil.
	var dt := get_physics_process_delta_time()
	var turn_rate := angle_difference(_visual_yaw, yaw) / maxf(dt, 0.001)
	_visual_yaw = yaw
	var gas := clampf(speed / 3.0, -1.0, 1.0)
	var steer := clampf(-turn_rate / deg_to_rad(22.0), -1.0, 1.0)
	visual.sticks = Vector2(clampf(gas + steer, -1.0, 1.0), clampf(gas - steer, -1.0, 1.0))
	_update_ramp_shape()
	visual.set_gauges([depth() / 60.0, absf(speed) / 6.0, fuel])
	visual.speed = speed
	visual.throttle = clampf(absf(speed) / 3.0, 0.0, 1.0)
	visual.drilling = drilling
	visual.blocked = blocked
	visual.ramp_open = ramp_open
	visual.lights_on = lights_on
	visual.beacons = mode in [Mode.AUTO_DOWN, Mode.COUNTDOWN, Mode.EXTRACTING]
	visual.lever_pulled = mode in [Mode.COUNTDOWN, Mode.EXTRACTING]
	if drilling:
		var layer: Strata.Layer = game.terrain.layer_at(body.global_position + forward() * (BORE_AHEAD + 2.0))
		visual.dust_color = Strata.DEBRIS_COLORS[layer]
	_readout_timer -= get_physics_process_delta_time()
	if _readout_timer <= 0.0:
		_readout_timer = 0.25
		var front: Strata.Layer = game.terrain.layer_at(body.global_position + forward() * (BORE_AHEAD + 2.0))
		var cargo := cargo_contents()
		var value := 0
		for it: FindItem in cargo:
			value += it.value()
		var states := ["GEPARKEERD", "RIJDEN", "AUTOPILOOT", "VERTREK %d" % int(ceil(countdown)), "NAAR BOVEN"]
		var state: String = ("! RAND PUT" if at_edge else "! TE HARD") if blocked else ("BOREN" if drilling and mode == Mode.DRIVING else states[mode])
		var ore: PackedInt32Array = game.ores.hold
		visual.set_readout("%s
DIEPTE   %4d M
HELLING  %+4d°
BRANDST. %4d%%
LAADRUIM %d · €%d
ERTS     %d · €%d" % [state, int(depth()), int(round(rad_to_deg(pitch))), int(fuel * 100.0), cargo.size(), value,
				OreField.units(ore), OreField.value(ore)])
		visual.feed_text = "%d M  ·  %s  ·  %.1f M/S" % [int(depth()), Strata.NAMES[front].to_upper(), absf(speed)]
	# Camerascherm enkel renderen als de lokale speler in de Mol is.
	var me: Player = game.player_node(Net.my_id())
	visual.feed_active = me != null and contains_point(me.global_position)


# --- Botsvormen en knoppen ---------------------------------------------------------------------

func _build_collision() -> void:
	# Vloer, wanden, plafond en voorschot van de binnenruimte; schild en kop; onderstel; dak.
	_box(Vector3(4.4, 0.2, 7.9), Vector3(0, -1.6, 0.3))
	_box(Vector3(0.35, 3.4, 8.0), Vector3(-2.27, 0.15, 0.2))
	_box(Vector3(0.35, 3.4, 8.0), Vector3(2.27, 0.15, 0.2))
	_box(Vector3(4.8, 0.32, 8.0), Vector3(0, 1.96, 0.2))
	_box(Vector3(4.8, 4.2, 0.4), Vector3(0, 0, -3.8))
	_box(Vector3(4.6, 1.2, 7.4), Vector3(0, -2.3, 0.2))
	_box(Vector3(2.1, 0.7, 2.6), Vector3(0, 2.45, 2.75))
	var head := CylinderShape3D.new()
	head.radius = 2.95
	head.height = 3.9
	var cs := CollisionShape3D.new()
	cs.shape = head
	cs.rotation = Vector3(PI / 2, 0, 0)
	cs.position = Vector3(0, 0, -5.9)
	body.add_child(cs)
	# Meubels binnen, zodat je er niet door loopt.
	_box(Vector3(4.2, 1.0, 0.9), Vector3(0, -1.0, -3.16)) # console
	_box(Vector3(0.75, 0.95, 0.95), Vector3(-1.72, -1.05, 1.05))
	_box(Vector3(0.45, 1.95, 0.9), Vector3(1.85, -0.52, 1.0))
	_box(Vector3(0.45, 0.6, 1.1), Vector3(-1.85, -1.2, 0.0))
	_box(Vector3(0.45, 0.6, 1.1), Vector3(1.85, -1.2, 0.0))
	_box(Vector3(0.75, 1.3, 0.75), Vector3(-1.57, -0.85, 1.97))
	_box(Vector3(0.6, 0.95, 0.6), Vector3(0, -1.03, -1.85))
	# Laadklep: een vorm van het Mol-lichaam zelf die elke tick de scharnierhoek volgt
	# (een apart lichaam onder de visuele klep belandde op een verkeerde plek).
	var rb := BoxShape3D.new()
	rb.size = Vector3(4.1, 3.3, 0.16)
	_ramp_shape = CollisionShape3D.new()
	_ramp_shape.name = "RampShape"
	_ramp_shape.shape = rb
	body.add_child(_ramp_shape)
	_update_ramp_shape()


func _update_ramp_shape() -> void:
	var xf: Transform3D = visual.ramp_hinge.transform * Transform3D(Basis(), Vector3(0, 1.65, 0))
	if not _ramp_shape.transform.is_equal_approx(xf):
		_ramp_shape.transform = xf


func _box(size: Vector3, pos: Vector3) -> void:
	var s := BoxShape3D.new()
	s.size = size
	var cs := CollisionShape3D.new()
	cs.shape = s
	cs.position = pos
	body.add_child(cs)


func _build_buttons() -> void:
	var a := visual.anchors
	var depths := [20.0, 40.0, 60.0]
	for i in 3:
		var d: float = depths[i]
		_button(a["Btn_Auto_%d" % i], "E: autopiloot · afdalen tot −%d m" % int(d), Cmd.AUTO, d, 0.16)
	_button(a["Btn_Horn"], "E: toeteren", Cmd.HORN, 0.0, 0.18)
	_button(a["Btn_Lights"], "E: lampen aan/uit", Cmd.LIGHTS, 0.0, 0.16)
	_button(a["Btn_Ramp_Cockpit"], "E: laadklep open/dicht", Cmd.RAMP, 0.0, 0.16)
	_button(a["Btn_Ramp_Back"], "E: laadklep open/dicht", Cmd.RAMP, 0.0, 0.3)
	_button(a["Lever"], "E: vertrekken naar boven (10 s)", Cmd.DEPART, 0.0, 0.3)
	_button(a["Workbench"], "Werkbank (upgrades komen later)", Cmd.WORKBENCH, 0.0, 0.6)
	# Ertstrechter: storten gaat rechtstreeks naar het ertsveld (host controleert de afstand).
	var chute_shape := BoxShape3D.new()
	chute_shape.size = Vector3(0.8, 0.7, 0.8)
	var chute := Interactable.make("E: erts storten", chute_shape)
	chute.set_meta("ore_chute", true)
	a["Ore_Chute"].add_child(chute)
	chute.used.connect(func(_p: Player) -> void: game.ores.deposit())
	# Stoel en stuurhendels samen: groot genoeg om niet te missen, laag genoeg om over te mikken
	# naar de knoppen op de console.
	var seat := Node3D.new()
	body.add_child(seat)
	seat.position = Vector3(0, -0.95, -2.05)
	_button(seat, "E: de Mol besturen", Cmd.SEAT, 0.0, Vector3(1.2, 1.1, 1.1))


func _button(anchor: Node3D, hint: String, button: Cmd, arg: float, size: Variant) -> void:
	var shape := BoxShape3D.new()
	shape.size = size if size is Vector3 else Vector3.ONE * float(size)
	var it := Interactable.make(hint, shape)
	it.set_meta("mol_cmd", button)
	anchor.add_child(it)
	it.used.connect(func(_p: Player) -> void: press(button, arg))
