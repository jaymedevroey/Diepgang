class_name Unrest
extends Node3D
## Onrust en bevingen (GDD §3, §6; onderzoek docs/research/magma-en-onrust.md B–E).
## - Onrust stijgt enkel door lawaai (host): de handboor, de Mol die rijdt of boort, een PING.
##   Het houweel is stil. Na een stille periode zakt ze traag terug.
## - Eén trap = `stage` (unrest.cfg). Vanaf 80% voorschokken, bij 100% een beving: 4 s
##   aankondiging, 6 s hoofdschok, rotsen vallen in de onstabiele zones in de buurt, en het magma
##   maakt een sprong (de klok gaat 40 s vooruit, zie Magma).
## - Onstabiele zones: uit het zaad (op elke peer hetzelfde), aan grotplafonds en verspreid in de
##   rots, ook in de klei (onder de bovenste meters). Altijd gemarkeerd in de rotsshader (barsten,
##   stof, krijtstrepen).
## - Rotsen: de host kiest de plekken en stuurt ze door; elke peer laat ze zelf vallen (fysica
##   enkel voor het beeld). Wie geraakt wordt, wankelt of gaat even neer (enkel lokaal) en laat
##   vallen wat hij draagt. Ze blijven liggen (rock_life_s): na een beving is de grot anders.
## - Zo voel je ze (release-audit binnen-05, gevoel-08, ontwerp-12): de aankondiging zwelt aan
##   (traag rollen, sijpelend gruis, de eerste steentjes), de hoofdschok komt in golven met pieken
##   (2-3°), de helmlamp flikkert, een stofwolk vult de ruimte, en rond elke speler vallen steentjes.
##   Geen geluid (M6), maar wel de haken ervoor: `rumble_level()`, `rock_landed`, `quake_*`.

enum Phase { CALM, WARNING, QUAKE }

## Voorschok (op elke peer).
signal pretremor
## Een beving komt eraan (T−warning_s) of begint (T0), op elke peer.
signal quake_warning(index: int)
signal quake_started(index: int)
## De lokale speler werd geraakt door een rots (grootte in m).
signal local_hit(size: float)
## Een grote rots gooide de lokale speler omver. Haak voor "neergaan" (F2, downed): nu enkel
## omvallen (Player.stun) en wat je draagt valt.
signal local_knockdown(size: float)
## Een rots kwam neer (op elke peer, voor geluid en effecten).
signal rock_landed(pos: Vector3, size: float)

const SYNC_INTERVAL := 0.25
const ZONE_UPDATE := 0.5

var game: Node # Game
## Onrust in de huidige trap (0..stage). Host bepaalt, clients krijgen ze 4× per seconde.
var value := 0.0
## Aantal bevingen deze dienst.
var stage := 0
var phase := Phase.CALM
## Seconden in de huidige fase.
var phase_t := 0.0
## Onstabiele zones (wereld): xyz = midden, w = straal.
var zones: Array[Vector4] = []

var _rng := RandomNumberGenerator.new()
var _quiet := 999.0
var _since_quake := 999.0
var _pretremor_timer := 10.0
var _sync_timer := 0.0
var _zone_timer := 0.0
var _drill_seen := {} # peer -> tijd (s) van zijn laatste boorhap
var _plan: Array = [] # [pos, grootte, vertraging na T0] van de lopende beving
var _plan_done := {} # index in _plan -> 0 = stof gestart, 1 = rots gevallen
var _rocks: Array[RigidBody3D] = []
var _dust: Array[GPUParticles3D] = []
var _rock_mesh: Array[Mesh] = []
var _rock_shape: Array[Shape3D] = []
var _trickles: Array[GPUParticles3D] = [] # fijne stofslierten uit het plafond van zones vlakbij
var _rumble := 0.0 # 0..1, voor geluid (rumble_level)
var _peak_seen := -1 # welke piek van de hoofdschok al flikkerde
var _pebbles_done := false
var _flicker_t := 0.0
var _flicker_lamps: Array = [] # [lamp, energie] van de lokale helmlamp tijdens het flikkeren


func _ready() -> void:
	_rng.randomize()
	# Gehakte brokken (zoals de rotsblokken en het puin), geen bollen: een icosaëder met verschoven
	# hoekpunten, vlak belicht, met een eigen botsvorm per variant (gedeeld door alle rotsen).
	for i in 4:
		var m := _chunk_mesh(911 + i * 37)
		_rock_mesh.append(m)
		_rock_shape.append(m.create_convex_shape(true, true))


## Nieuwe wereld: zones uit het zaad, alles terug op nul.
func attach_terrain(terrain: TerrainAPI) -> void:
	reset()
	_make_zones(terrain)


func reset() -> void:
	value = 0.0
	stage = 0
	phase = Phase.CALM
	phase_t = 0.0
	_rumble = 0.0
	_end_flicker()
	_quiet = 999.0
	_since_quake = 999.0
	_drill_seen.clear()
	_plan.clear()
	_plan_done.clear()
	for r in _rocks:
		if is_instance_valid(r):
			r.queue_free()
	_rocks.clear()


func _make_zones(terrain: TerrainAPI) -> void:
	zones.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.pit_seed * 92821 + 7
	var r := Tuning.get_f("unrest", "zone_radius", 4.0)
	var klei := Strata.TOPS_M[2] # boven deze hoogte: klei, met minder zones
	# Aan de plafonds van grotten (daar kom je zeker).
	for c: Vector4 in terrain.caverns():
		if rng.randf() > 0.65:
			continue
		var n := 2 if c.w > 20.0 else 1
		for k in n:
			var a := rng.randf() * TAU
			var d := rng.randf() * c.w * 0.5
			var top := c.y + c.w / PlanetGenerator.CAVERN_SQUASH
			var p := Vector3(c.x + cos(a) * d, top - 1.5, c.z + sin(a) * d)
			if p.y < klei or terrain.surface_height_at(p.x, p.z) - p.y > 8.0:
				zones.append(Vector4(p.x, p.y, p.z, r))
	# Verspreid in de rots, het meest in zandsteen.
	var size := terrain.world_size()
	for i in 70:
		var y := rng.randf_range(Strata.TOPS_M[1], klei - 3.0) if rng.randf() < 0.6 else rng.randf_range(8.0, Strata.TOPS_M[1])
		var p := Vector3(rng.randf_range(12.0, size.x - 12.0), y, rng.randf_range(12.0, size.z - 12.0))
		zones.append(Vector4(p.x, p.y, p.z, r))
	# Ook in de klei (ontwerp-12: bevingen raken je in elke laag), niet in de bovenste 8 m.
	for i in Tuning.get_i("unrest", "zones_klei", 24):
		var p := Vector3(rng.randf_range(12.0, size.x - 12.0), 0.0, rng.randf_range(12.0, size.z - 12.0))
		p.y = rng.randf_range(klei + 3.0, terrain.surface_height_at(p.x, p.z) - 8.0)
		zones.append(Vector4(p.x, p.y, p.z, r))


## In een onstabiele zone?
func in_zone(world: Vector3) -> bool:
	for z in zones:
		if world.distance_to(Vector3(z.x, z.y, z.z)) < z.w:
			return true
	return false


# --- Lawaai (host) -----------------------------------------------------------------------------

## Host: lawaai erbij (bv. een PING).
func host_add(amount: float) -> void:
	if not multiplayer.is_server() or not game.magma.running:
		return
	value += amount
	_quiet = 0.0


## Host: een speler groef. Enkel de boor maakt lawaai (het houweel is stil).
func host_player_op(sender: int, op: Dictionary) -> void:
	if op.get("op", -1) == TerrainAPI.Op.SPHERE_REMOVE and int(op.get("tool", -1)) >= Strata.Tool.BOOR_T1:
		_drill_seen[sender] = Time.get_ticks_msec() / 1000.0


func _host_noise(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var amount := 0.0
	for peer: int in _drill_seen:
		if now - float(_drill_seen[peer]) < 0.35:
			amount += Tuning.get_f("unrest", "drill", 0.3) * delta
	var mol: Mol = game.mol
	if mol and mol.body and mol.mode != Mol.Mode.DOCKED:
		if mol.drilling:
			amount += Tuning.get_f("unrest", "mol_drill", 0.6) * delta
		else:
			var top := maxf(0.1, Tuning.get_f("mol", "open_speed", 5.0))
			amount += Tuning.get_f("unrest", "mol_drive", 0.25) * clampf(absf(mol.speed) / top, 0.0, 1.0) * delta
	if amount > 0.0:
		value += amount
		_quiet = 0.0


# --- Verloop ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null or game.terrain == null:
		return
	var host := multiplayer.is_server()
	_update_flicker(delta)
	if host and game.magma.running:
		_since_quake += delta
		_quiet += delta
		_host_noise(delta)
		if phase == Phase.CALM:
			var full := Tuning.get_f("unrest", "stage", 100.0)
			if value >= full * Tuning.get_f("unrest", "pretremor_at", 80.0) / 100.0:
				_pretremor_timer -= delta
				if _pretremor_timer <= 0.0:
					_pretremor_timer = _rng.randf_range(Tuning.get_f("unrest", "pretremor_min_s", 8.0), Tuning.get_f("unrest", "pretremor_max_s", 15.0))
					_rpc_pretremor.rpc()
			if value >= full and _since_quake >= Tuning.get_f("unrest", "min_gap_s", 90.0):
				_host_begin_quake()
		# Verval pas na de controle: anders haalt een stille ploeg de volle trap net niet.
		if _quiet > Tuning.get_f("unrest", "quiet_s", 15.0) and phase == Phase.CALM:
			value = maxf(0.0, value - Tuning.get_f("unrest", "decay", 0.1) * delta)
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			_rpc_value.rpc(value, stage)
	_advance(delta)
	_zone_timer -= delta
	if _zone_timer <= 0.0:
		_zone_timer = ZONE_UPDATE
		_update_zone_marks()


## Fasen van een beving (op elke peer, vanaf het bericht van de host).
func _advance(delta: float) -> void:
	if phase == Phase.CALM:
		return
	phase_t += delta
	var warn := Tuning.get_f("unrest", "warning_s", 4.0)
	var quake := Tuning.get_f("unrest", "quake_s", 6.0)
	if phase == Phase.WARNING:
		var k := clampf(phase_t / warn, 0.0, 1.0)
		_shake(lerpf(Tuning.get_f("unrest", "trauma_warn_from", 0.2), Tuning.get_f("unrest", "trauma_warn_to", 0.45), k),
				lerpf(Tuning.get_f("unrest", "rumble_warn_from", 0.3), Tuning.get_f("unrest", "rumble_warn_to", 1.2), k * k))
		_rumble = 0.25 + 0.35 * k
		# Halfweg de aankondiging: de eerste steentjes rond de speler.
		if k > 0.5 and not _pebbles_done:
			_pebbles_done = true
			_pebbles_near_camera(Tuning.get_i("unrest", "pebbles", 10) / 3)
		_run_plan(phase_t - warn) # de eerste stofstralen al voor T0
		if phase_t >= warn:
			phase = Phase.QUAKE
			phase_t = 0.0
			_peak_seen = -1
			_start_flicker()
			_dust_cloud()
			_pebbles_near_camera(Tuning.get_i("unrest", "pebbles", 10))
			quake_started.emit(stage)
			if multiplayer.is_server():
				game.magma.host_quake()
	elif phase == Phase.QUAKE:
		if phase_t < quake:
			# In golven: pieken (2-3°, traag rollen) met rustiger stukken ertussen.
			var peaks := maxi(1, Tuning.get_i("unrest", "quake_peaks", 3))
			var u := phase_t / quake * peaks
			var wave := pow(sin(PI * fposmod(u, 1.0)), 2.0)
			var fade := 1.0 - smoothstep(0.75, 1.0, phase_t / quake)
			var peak := int(u)
			if wave > 0.85 and peak != _peak_seen:
				_peak_seen = peak
				if peak > 0:
					_start_flicker()
			_shake(Tuning.get_f("unrest", "trauma_quake", 0.85) * lerpf(0.55, 1.0, wave) * fade,
					Tuning.get_f("unrest", "rumble_quake", 3.5) * lerpf(0.35, 1.0, wave) * fade)
			_rumble = lerpf(0.6, 1.0, wave) * fade
		else:
			_rumble = 0.0
		_run_plan(phase_t)
		if phase_t >= quake and _plan_done.size() >= _plan.size() * 2:
			phase = Phase.CALM
			phase_t = 0.0


## Wandelen tijdens de hoofdschok (×), voor Player.
func walk_factor() -> float:
	if phase == Phase.QUAKE and phase_t < Tuning.get_f("unrest", "quake_s", 6.0):
		return Tuning.get_f("unrest", "walk_factor", 0.85)
	return 1.0


## Hoe hard het nu rommelt (0..1), voor geluid (M6): aanzwellend in de aankondiging, golvend in de
## hoofdschok, 0 als het stil is.
func rumble_level() -> float:
	return _rumble if phase != Phase.CALM else 0.0


func _shake(amount: float, rumble_deg := 0.0) -> void:
	var p: Player = game.local_player
	if p == null:
		return
	if game.mol and game.mol.contains_point(p.global_position):
		amount *= Tuning.get_f("unrest", "trauma_in_mol", 0.6)
		rumble_deg *= Tuning.get_f("unrest", "trauma_in_mol", 0.6)
	p.camera_fx.hold_trauma(amount)
	if rumble_deg > 0.0 and p.camera_fx.has_method("hold_rumble"):
		p.camera_fx.hold_rumble(rumble_deg)


@rpc("authority", "call_local", "reliable")
func _rpc_pretremor() -> void:
	_shake(Tuning.get_f("unrest", "trauma_pre", 0.3))
	_dust_near_camera(0.6)
	pretremor.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_value(v: float, s: int) -> void:
	value = v
	stage = s


## Late joiner.
func send_state(peer: int) -> void:
	_rpc_value.rpc_id(peer, value, stage)


func _host_begin_quake() -> void:
	value = 0.0
	_since_quake = 0.0
	_rpc_quake.rpc(stage + 1, _host_plan())


@rpc("authority", "call_local", "reliable")
func _rpc_quake(index: int, plan: Array) -> void:
	stage = index
	value = 0.0
	phase = Phase.WARNING
	phase_t = 0.0
	_plan = plan
	_plan_done.clear()
	_pebbles_done = false
	_dust_near_camera(1.0)
	quake_warning.emit(index)


# --- Rotsen ---------------------------------------------------------------------------------------

## Host: welke zones vallen en waar precies de rotsen loskomen (onder een plafond, in open lucht).
func _host_plan() -> Array:
	var t: TerrainAPI = game.terrain
	var near: Array[Vector3] = []
	for pl: Player in game.players.get_children():
		near.append(pl.global_position)
	if game.mol and game.mol.body:
		near.append(game.mol.body.global_position)
	var reach := Tuning.get_f("unrest", "zone_reach", 40.0)
	var picked: Array = []
	for z in zones:
		var c := Vector3(z.x, z.y, z.z)
		var best := INF
		for p in near:
			best = minf(best, c.distance_to(p))
		if best <= reach:
			picked.append([best, z])
	picked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	picked.resize(mini(picked.size(), Tuning.get_i("unrest", "max_zones", 6)))
	var plan: Array = []
	var spread := Tuning.get_f("unrest", "rock_spread_s", 5.0)
	for e: Array in picked:
		var z: Vector4 = e[1]
		var c := Vector3(z.x, z.y, z.z)
		var count := _rng.randi_range(Tuning.get_i("unrest", "rocks_min", 3), Tuning.get_i("unrest", "rocks_max", 6))
		for i in count:
			for attempt in 10:
				var p := c + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(-1, 1)) * z.w * 0.8
				if not t.data_loaded(p) or t.sdf_at(p) < 0.6:
					continue
				var hit := t.raycast(p, p + Vector3.UP * 7.0)
				if hit.is_empty():
					continue
				var size := _rng.randf_range(Tuning.get_f("unrest", "rock_min", 0.4), Tuning.get_f("unrest", "rock_max", 1.2))
				var at: Vector3 = hit.position - Vector3(0.0, size * 0.6 + 0.1, 0.0)
				plan.append([at, size, _rng.randf_range(0.0, spread)])
				break
	return plan


## Stofstraal en daarna de rots, op het juiste moment na T0 (`qt`: seconden sinds T0).
func _run_plan(qt: float) -> void:
	var lead := Tuning.get_f("unrest", "dust_lead_s", 1.2)
	for i in _plan.size():
		var e: Array = _plan[i]
		var at: float = e[2]
		var state: int = _plan_done.get(i, -1)
		if state < 0 and qt >= at - lead:
			_plan_done[i] = 0
			_dust_stream(e[0], lead + 0.6)
		if state < 1 and qt >= at and _plan_done.has(i):
			_plan_done[i] = 1
			_plan_done[i + _plan.size()] = 1 # telt mee voor "klaar"
			_spawn_rock(e[0], e[1])


func _spawn_rock(pos: Vector3, size: float) -> void:
	while _rocks.size() >= Tuning.get_i("unrest", "max_rocks", 30):
		var old: RigidBody3D = _rocks.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var rb := RigidBody3D.new()
	rb.collision_layer = Layers.DEBRIS
	rb.collision_mask = Layers.TERRAIN | Layers.DEBRIS
	rb.mass = 40.0 * size * size * size
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var variant := _rng.randi() % _rock_mesh.size()
	var squash := Vector3(1.0, _rng.randf_range(0.7, 0.95), _rng.randf_range(0.85, 1.1))
	var cs := CollisionShape3D.new()
	cs.shape = _rock_shape[variant]
	cs.scale = Vector3.ONE * size * 0.5 # botsvormen enkel gelijkmatig schalen
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh[variant]
	mi.scale = squash * size * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)].darkened(_rng.randf_range(0.15, 0.3))
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	rb.add_child(mi)
	# Een sliert stof achter de rots zolang hij valt.
	var trail := _make_dust(Vector3(0.15, 0.15, 0.15) * size, 18, Vector2(0.18, 0.18) * (0.6 + size), 1.4)
	trail.local_coords = false
	trail.name = "Trail"
	(trail.process_material as ParticleProcessMaterial).direction = Vector3.UP
	(trail.process_material as ParticleProcessMaterial).gravity = Vector3(0, -0.4, 0)
	_tint_dust(trail, Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)], 0.45)
	rb.add_child(trail)
	trail.emitting = true
	# Vloeiend tussen de physics-ticks (physics-interpolatie staat in het project aan, per node).
	rb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(rb)
	rb.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)
	rb.global_position = pos
	rb.reset_physics_interpolation() # niet van de oorsprong naar hier glijden
	rb.angular_velocity = Vector3(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2), _rng.randf_range(-2, 2))
	rb.set_meta("size", size)
	rb.set_meta("hit", false)
	rb.body_entered.connect(func(_b: Node) -> void: _on_rock_landed(rb), CONNECT_ONE_SHOT)
	_rocks.append(rb)
	# Na rock_life_s weg (een Timer in de rots zelf: geen lambda die een vrijgegeven rots vasthoudt).
	var life := Timer.new()
	life.wait_time = Tuning.get_f("unrest", "rock_life_s", 40.0)
	life.one_shot = true
	life.autostart = true
	life.timeout.connect(rb.queue_free)
	rb.add_child(life)


func _on_rock_landed(rb: RigidBody3D) -> void:
	if not is_instance_valid(rb):
		return
	var pos := rb.global_position
	var size: float = rb.get_meta("size", 0.8)
	var col: Color = Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)]
	game.fx.grit_puff(pos, Vector3.UP, col)
	var trail := rb.get_node_or_null("Trail") as GPUParticles3D
	if trail:
		trail.emitting = false
	# Een wolk stof waar hij neerkomt (groter bij een grote rots).
	var puff := _make_dust(Vector3(0.6, 0.1, 0.6) * size, int(24 + 30 * size), Vector2(0.35, 0.35) * (0.7 + size), 2.2)
	var pm := puff.process_material as ParticleProcessMaterial
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -0.3, 0)
	pm.damping_min = 1.5
	pm.damping_max = 2.5
	_tint_dust(puff, col, 0.5)
	add_child(puff)
	puff.global_position = pos
	puff.one_shot = true
	puff.explosiveness = 0.85
	puff.emitting = true
	get_tree().create_timer(4.0).timeout.connect(puff.queue_free)
	rock_landed.emit(pos, size)
	var p: Player = game.local_player
	if p:
		var d := p.global_position.distance_to(pos)
		var k := 1.0 - smoothstep(3.0, 12.0, d)
		if k > 0.0:
			p.camera_fx.add_trauma(Tuning.get_f("unrest", "trauma_rock", 0.35) * k)


func _physics_process(_delta: float) -> void:
	# Treffers op de lokale speler: een vallende rots dicht bij zijn lijf.
	_rocks = _rocks.filter(func(r: RigidBody3D) -> bool: return is_instance_valid(r))
	var p: Player = game.local_player if game else null
	if p == null or _rocks.is_empty():
		return
	var body := p.global_position + Vector3(0.0, 0.7, 0.0)
	for rb in _rocks:
		if not is_instance_valid(rb) or rb.get_meta("hit") or rb.linear_velocity.y > -2.0:
			continue
		var size: float = rb.get_meta("size")
		if rb.global_position.distance_to(body) < size * 0.5 + 0.55:
			rb.set_meta("hit", true)
			var big := size >= Tuning.get_f("unrest", "big_rock", 0.8)
			p.stun(Tuning.get_f("unrest", "knockdown_s" if big else "stagger_s", 1.2 if big else 0.3), big)
			local_hit.emit(size)
			if big:
				local_knockdown.emit(size) # F2: hier wordt neergaan (downed) aangesloten


# --- Stof en markering -------------------------------------------------------------------------

## Fijne stofstraal van het plafond: hier valt zo meteen een rots.
func _dust_stream(pos: Vector3, seconds: float) -> void:
	var d := _make_dust(Vector3(0.25, 0.05, 0.25), 60, Vector2(0.06, 0.06), 3.5)
	add_child(d)
	d.global_position = pos
	d.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(d):
			d.emitting = false
			get_tree().create_timer(4.0).timeout.connect(d.queue_free))


## Gruis dat uit het plafond rond de camera valt (voorschok, beving).
func _dust_near_camera(strength: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or game.terrain == null:
		return
	var p := cam.global_position
	if game.terrain.surface_height_at(p.x, p.z) - p.y < 2.0:
		return # aan de oppervlakte valt er niets
	var d := _make_dust(Vector3(6.0, 0.3, 6.0), int(160 * strength), Vector2(0.03, 0.03), 2.5)
	add_child(d)
	var hit: Dictionary = game.terrain.raycast(p, p + Vector3.UP * 8.0)
	d.global_position = (hit.position - Vector3(0, 0.3, 0)) if not hit.is_empty() else p + Vector3(0, 3.0, 0)
	d.one_shot = true
	d.explosiveness = 0.2
	d.emitting = true
	get_tree().create_timer(6.0).timeout.connect(d.queue_free)


## Hoofdschok: een stofwolk die van het plafond neerdaalt en de ruimte rond de camera vult.
func _dust_cloud() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or game.terrain == null:
		return
	var p := cam.global_position
	if game.terrain.surface_height_at(p.x, p.z) - p.y < 2.0:
		return # aan de oppervlakte niet
	var d := _make_dust(Vector3(7.0, 2.0, 7.0), Tuning.get_i("unrest", "dust_cloud", 160), Vector2(2.4, 2.4), 5.5)
	var pm := d.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 4.0
	_tint_dust(d, Strata.DEBRIS_COLORS[game.terrain.layer_at(p)].lightened(0.1), 0.11) # veel, zacht: een waas, geen bollen
	add_child(d)
	var hit: Dictionary = game.terrain.raycast(p, p + Vector3.UP * 7.0)
	d.global_position = (hit.position - Vector3(0, 1.2, 0)) if not hit.is_empty() else p + Vector3(0, 2.5, 0)
	d.one_shot = true
	d.explosiveness = 0.5
	d.emitting = true
	get_tree().create_timer(Tuning.get_f("unrest", "quake_s", 6.0) + 6.0).timeout.connect(d.queue_free)


## Steentjes die rond de camera uit het plafond vallen (enkel beeld, lokaal; ook buiten de zones).
func _pebbles_near_camera(count: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or game.terrain == null or count <= 0:
		return
	var p := cam.global_position
	if game.terrain.surface_height_at(p.x, p.z) - p.y < 2.0:
		return
	var t: TerrainAPI = game.terrain
	for i in count:
		var o := p + Vector3(_rng.randf_range(-5.0, 5.0), 0.0, _rng.randf_range(-5.0, 5.0))
		var hit := t.raycast(o, o + Vector3.UP * 6.0)
		if hit.is_empty():
			continue
		var at: Vector3 = hit.position - Vector3(0.0, 0.25, 0.0)
		var delay := _rng.randf_range(0.0, 1.6)
		var size := _rng.randf_range(0.08, 0.22)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_inside_tree():
				_spawn_pebble(at, size))


func _spawn_pebble(pos: Vector3, size: float) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = Layers.DEBRIS
	rb.collision_mask = Layers.TERRAIN
	rb.mass = 0.3
	var variant := _rng.randi() % _rock_mesh.size()
	var cs := CollisionShape3D.new()
	cs.shape = _rock_shape[variant]
	cs.scale = Vector3.ONE * size * 0.5
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh[variant]
	mi.scale = Vector3.ONE * size * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)].darkened(0.2)
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	rb.add_child(mi)
	rb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(rb)
	rb.global_position = pos
	rb.reset_physics_interpolation()
	rb.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
	var tw := rb.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(rb.queue_free)


## De helmlamp van de lokale speler flikkert even (bij T0 en in elke piek van de hoofdschok).
func _start_flicker() -> void:
	var p: Player = game.local_player
	if p == null or p.head == null:
		return
	if _flicker_lamps.is_empty():
		for n in p.head.get_children():
			if n is SpotLight3D:
				_flicker_lamps.append([n, (n as SpotLight3D).light_energy])
	_flicker_t = Tuning.get_f("unrest", "flicker_s", 0.6)


func _end_flicker() -> void:
	for e: Array in _flicker_lamps:
		if is_instance_valid(e[0]):
			(e[0] as SpotLight3D).light_energy = e[1]
	_flicker_lamps.clear()
	_flicker_t = 0.0


func _update_flicker(delta: float) -> void:
	if _flicker_lamps.is_empty():
		return
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_end_flicker()
		return
	# Haperen: een paar korte dips, niet rustig dimmen.
	var k := 1.0 if _rng.randf() > 0.35 else _rng.randf_range(0.05, 0.4)
	for e: Array in _flicker_lamps:
		if is_instance_valid(e[0]):
			(e[0] as SpotLight3D).light_energy = float(e[1]) * k


var _dot: Texture2D


func _soft_dot() -> Texture2D:
	if _dot == null:
		var t := GradientTexture2D.new()
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		t.gradient = g
		_dot = t
	return _dot


static func _tint_dust(d: GPUParticles3D, col: Color, alpha: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.15, Color(col, alpha))
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	(d.process_material as ParticleProcessMaterial).color_ramp = gt


## Een brok: icosaëder met verschoven hoekpunten (zoals de rotsen buiten), vlak belicht, ±1 groot.
## Elk vlak een eigen grijstint (vertexkleur), zodat de facetten lezen.
static func _chunk_mesh(chunk_seed: int) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var jit: Array[Vector3] = []
	for p in v:
		jit.append(p.normalized() * rng.randf_range(0.7, 1.25))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for tri in f:
		var shade := rng.randf_range(0.78, 1.0)
		st.set_color(Color(shade, shade, shade))
		for i: int in [tri[0], tri[2], tri[1]]:
			st.add_vertex(jit[i])
	st.generate_normals()
	return st.commit()


func _make_dust(extents: Vector3, amount: int, size: Vector2, lifetime: float) -> GPUParticles3D:
	var d := GPUParticles3D.new()
	d.amount = maxi(1, amount)
	d.lifetime = lifetime
	d.visibility_aabb = AABB(Vector3(-8, -10, -8), Vector3(16, 12, 16))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = extents
	m.direction = Vector3.DOWN
	m.spread = 6.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 1.0
	m.gravity = Vector3(0, -3.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.68, 0.58, 0.0))
	g.add_point(0.1, Color(0.75, 0.68, 0.58, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.75, 0.68, 0.58, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	d.process_material = m
	var q := QuadMesh.new()
	q.size = size
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot() # rond en zacht: grote vlokken zijn anders vierkanten
	qm.roughness = 1.0
	q.material = qm
	d.draw_pass_1 = q
	return d


## De dichtstbijzijnde zones in de rotsshader (de markering die je altijd ziet).
func _update_zone_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or zones.is_empty():
		return
	var p := cam.global_position
	var near: Array = []
	for z in zones:
		var d := p.distance_to(Vector3(z.x, z.y, z.z))
		if d < 80.0:
			near.append([d, z])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[Vector4] = []
	for e: Array in near:
		if out.size() >= 16:
			break
		out.append(e[1])
	game.terrain.set_hazard_zones(out)
	_update_trickles(near)


## Een fijne stofsliert uit het plafond van de dichtstbijzijnde zones (binnen 20 m, en enkel als
## de zone open ligt): zo zie je ook zonder lamp dat het daar niet pluis is.
func _update_trickles(near: Array) -> void:
	var t: TerrainAPI = game.terrain
	var used := 0
	for e: Array in near:
		if used >= 3 or float(e[0]) > 20.0:
			break
		var z: Vector4 = e[1]
		var c := Vector3(z.x, z.y, z.z)
		if not t.data_loaded(c) or t.sdf_at(c) < 0.3:
			continue
		var hit := t.raycast(c, c + Vector3.UP * (z.w + 3.0))
		if hit.is_empty():
			continue
		if _trickles.size() <= used:
			var d := _make_dust(Vector3(0.08, 0.02, 0.08), 24, Vector2(0.025, 0.025), 2.5)
			add_child(d)
			_trickles.append(d)
		var tr := _trickles[used]
		tr.global_position = hit.position - Vector3(0.0, 0.05, 0.0)
		tr.emitting = true
		used += 1
	for i in range(used, _trickles.size()):
		_trickles[i].emitting = false
