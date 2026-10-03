class_name Unrest
extends Node3D
## Onrust en bevingen (GDD §3, §6; onderzoek docs/research/magma-en-onrust.md B–E).
## - Onrust stijgt enkel door lawaai (host): de handboor, de Mol die rijdt of boort, een PING.
##   Het houweel is stil. Na een stille periode zakt ze traag terug.
## - Eén trap = `stage` (unrest.cfg). Vanaf 80% voorschokken, bij 100% een beving: 4 s
##   aankondiging, 6 s hoofdschok, rotsen vallen in de onstabiele zones in de buurt, en het magma
##   maakt een sprong (de klok gaat 40 s vooruit, zie Magma).
## - Onstabiele zones: uit het zaad (op elke peer hetzelfde), aan grotplafonds en verspreid in de
##   rots (niet in klei). Altijd gemarkeerd in de rotsshader (barsten, stof, krijtstrepen).
## - Rotsen: de host kiest de plekken en stuurt ze door; elke peer laat ze zelf vallen (fysica
##   enkel voor het beeld). Wie geraakt wordt, wankelt of gaat even neer (enkel lokaal).

enum Phase { CALM, WARNING, QUAKE }

## Voorschok (op elke peer).
signal pretremor
## Een beving komt eraan (T−warning_s) of begint (T0), op elke peer.
signal quake_warning(index: int)
signal quake_started(index: int)
## De lokale speler werd geraakt door een rots (grootte in m).
signal local_hit(size: float)

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
var _trickles: Array[GPUParticles3D] = [] # fijne stofslierten uit het plafond van zones vlakbij


func _ready() -> void:
	_rng.randomize()
	for i in 3:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 5 + i
		m.rings = 3 + (i % 2)
		_rock_mesh.append(m)


## Nieuwe wereld: zones uit het zaad, alles terug op nul.
func attach_terrain(terrain: TerrainAPI) -> void:
	reset()
	_make_zones(terrain)


func reset() -> void:
	value = 0.0
	stage = 0
	phase = Phase.CALM
	phase_t = 0.0
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
	var klei := Strata.TOPS_M[2] # boven deze hoogte: klei, geen zones
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
			if p.y < klei:
				zones.append(Vector4(p.x, p.y, p.z, r))
	# Verspreid in de rots, het meest in zandsteen.
	var size := terrain.world_size()
	for i in 70:
		var y := rng.randf_range(Strata.TOPS_M[1], klei - 3.0) if rng.randf() < 0.6 else rng.randf_range(8.0, Strata.TOPS_M[1])
		var p := Vector3(rng.randf_range(12.0, size.x - 12.0), y, rng.randf_range(12.0, size.z - 12.0))
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
		_shake(lerpf(Tuning.get_f("unrest", "trauma_warn_from", 0.2), Tuning.get_f("unrest", "trauma_warn_to", 0.45), clampf(phase_t / warn, 0.0, 1.0)))
		_run_plan(phase_t - warn) # de eerste stofstralen al voor T0
		if phase_t >= warn:
			phase = Phase.QUAKE
			phase_t = 0.0
			quake_started.emit(stage)
			if multiplayer.is_server():
				game.magma.host_quake()
	elif phase == Phase.QUAKE:
		if phase_t < quake:
			_shake(Tuning.get_f("unrest", "trauma_quake", 0.7))
		_run_plan(phase_t)
		if phase_t >= quake and _plan_done.size() >= _plan.size() * 2:
			phase = Phase.CALM
			phase_t = 0.0


## Wandelen tijdens de hoofdschok (×), voor Player.
func walk_factor() -> float:
	if phase == Phase.QUAKE and phase_t < Tuning.get_f("unrest", "quake_s", 6.0):
		return Tuning.get_f("unrest", "walk_factor", 0.85)
	return 1.0


func _shake(amount: float) -> void:
	var p: Player = game.local_player
	if p == null:
		return
	if game.mol and game.mol.contains_point(p.global_position):
		amount *= Tuning.get_f("unrest", "trauma_in_mol", 0.6)
	p.camera_fx.hold_trauma(amount)


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
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = size * 0.45
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = _rock_mesh[_rng.randi() % _rock_mesh.size()]
	mi.scale = Vector3(size, size * _rng.randf_range(0.7, 1.0), size * _rng.randf_range(0.8, 1.1))
	mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)] * 0.8
	mat.roughness = 0.95
	mi.material_override = mat
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = pos
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
	var col: Color = Strata.DEBRIS_COLORS[game.terrain.layer_at(pos)]
	game.fx.grit_puff(pos, Vector3.UP, col)
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
