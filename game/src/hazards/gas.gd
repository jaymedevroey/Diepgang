class_name Gas
extends Node3D
## Gasbellen (GDD §6: "een zichtbare gele waas ... Ze ontploffen bij vonken, bijvoorbeeld van de
## boor"). Staat op elk peer op Game/Gas.
## - Plaatsing uit het zaad (elk peer dezelfde): in grotten (zichtbaar) en opgesloten in de rots (die
##   komen vrij als je erin graaft: eerst sissen, breach_grace_s). Dieper meer; niet bij de landingsplek.
## - De waas: zachte gele vlokken die traag draaien, belicht door je helmlamp, met een zwakke eigen
##   gloed zodat je hem in het donker van ver ziet. Enkel waar de bel open ligt (lucht in het midden).
## - Ontsteken (host): een boorhap in of vlak bij de waas, de boorkop van de Mol, een andere ontploffing
##   in de buurt, of het magma dat hem bereikt. Dan fuse_s sissen en oplichten, en de ontploffing: een
##   krater (TerrainAPI: de rots kan enkel weg), schade en een duw (Rescue: omver of neer), lawaai
##   (onrust, de worm), en een kettingreactie.
## Het houweel ontsteekt niets: gas is een reden om voorzichtig te werken.

## Een bel ontplofte (op elk peer; geluid, tests).
signal exploded(id: int, at: Vector3)

const MAX_HAZE := 6


class Pocket:
	var id := 0
	var center := Vector3.ZERO
	var radius := 3.0
	var gone := false
	var open := false
	var opened_at := -100.0 # lokale tijd (s) waarop hij openging
	var igniting := false


var game: Node # Game
var pockets: Array[Pocket] = []

var _scan_t := 0.0
var _haze: Array[GPUParticles3D] = []
var _haze_of := {} # pocket id -> GPUParticles3D
var _fuse := {} # host: pocket id -> seconden tot de ontploffing
var _dot: Texture2D


## Nieuwe wereld: de bellen uit het zaad.
func attach_terrain(terrain: TerrainAPI) -> void:
	pockets.clear()
	_fuse.clear()
	for h in _haze:
		h.emitting = false
		h.visible = false
	_haze_of.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.pit_seed * 6151 + 3
	var want := int(round(Tuning.get_i("gas", "pockets", 16) * HazardParams.of(game, "gas", 1.0)))
	var caves := terrain.caverns()
	var size := terrain.world_size()
	var sc := terrain.shaft_center_world()
	var min_d := Tuning.get_f("gas", "min_depth_m", 35.0)
	var full_d := maxf(min_d + 1.0, Tuning.get_f("gas", "full_depth_m", 150.0))
	var safe := Tuning.get_f("gas", "safe_landing_m", 30.0)
	var in_caves := Tuning.get_f("gas", "in_caves", 0.65)
	var attempts := 0
	while pockets.size() < want and attempts < want * 30:
		attempts += 1
		var p: Vector3
		var r := rng.randf_range(Tuning.get_f("gas", "radius_min", 2.5), Tuning.get_f("gas", "radius_max", 4.5))
		var roll := rng.randf()
		if roll < in_caves and not caves.is_empty():
			var c: Vector4 = caves[rng.randi() % caves.size()]
			var a := rng.randf() * TAU
			var d := rng.randf() * c.w * 0.55
			var h := c.w / PlanetGenerator.CAVERN_SQUASH
			p = Vector3(c.x + cos(a) * d, c.y - h * 0.35 + r * 0.4, c.z + sin(a) * d)
		else:
			p = Vector3(rng.randf_range(14.0, size.x - 14.0), rng.randf_range(12.0, size.y), rng.randf_range(14.0, size.z - 14.0))
		var accept := rng.randf()
		var depth := terrain.surface_height_at(p.x, p.z) - p.y
		if depth < min_d or Vector2(p.x - sc.x, p.z - sc.z).length() < safe:
			continue
		if accept > clampf(0.2 + 0.8 * (depth - min_d) / (full_d - min_d), 0.2, 1.0):
			continue
		var far := true
		for o in pockets:
			if o.center.distance_to(p) < o.radius + r + 6.0:
				far = false
				break
		if not far:
			continue
		var pk := Pocket.new()
		pk.id = pockets.size()
		pk.center = p
		pk.radius = r
		pockets.append(pk)
	print("[gas] %d gasbellen (seed %d)" % [pockets.size(), terrain.pit_seed])


func pocket(id: int) -> Pocket:
	return pockets[id] if id >= 0 and id < pockets.size() else null


## In een (open) gasbel?
func in_gas(at: Vector3) -> bool:
	for p in pockets:
		if not p.gone and p.open and p.center.distance_to(at) < p.radius:
			return true
	return false


# --- Ontsteken (host) ----------------------------------------------------------------------------

## Host: een speler groef. Een boorhap (vonken) in of vlak bij een open bel: ontsteken.
func host_player_op(_sender: int, op: Dictionary) -> void:
	if op.get("op", -1) != TerrainAPI.Op.SPHERE_REMOVE or int(op.get("tool", -1)) < Strata.Tool.BOOR_T1 or not op.has("h"):
		return
	var at: Vector3 = op.h
	var now := Time.get_ticks_msec() / 1000.0
	for p in pockets:
		if p.gone or p.igniting or p.center.distance_to(at) > p.radius + 0.8:
			continue
		_refresh_open(p)
		if not p.open:
			continue
		if now - p.opened_at < Tuning.get_f("gas", "breach_grace_s", 2.0):
			continue # net opengebroken: het sist nog, één keer weg met de boor
		host_ignite(p.id, at)


## Host: een bel ontsteken (na fuse_s ontploft hij).
func host_ignite(id: int, spark: Vector3) -> void:
	var p := pocket(id)
	if p == null or p.gone or p.igniting:
		return
	p.igniting = true
	_fuse[id] = Tuning.get_f("gas", "fuse_s", 0.6)
	_rpc_fuse.rpc(id, spark)


func _process(delta: float) -> void:
	if game == null or game.terrain == null:
		return
	if multiplayer.is_server():
		_host_tick(delta)
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_update_haze()


func _host_tick(delta: float) -> void:
	for id: int in _fuse.keys():
		_fuse[id] = float(_fuse[id]) - delta
		if float(_fuse[id]) <= 0.0:
			_fuse.erase(id)
			_host_explode(id)
	var magma: Magma = game.magma
	var mol: Mol = game.mol
	var bore := Vector3.INF
	if mol and mol.body and mol.drilling:
		bore = mol.body.global_position + mol.forward() * Mol.BORE_AHEAD
	for p in pockets:
		if p.gone or p.igniting:
			continue
		# De boorkop van de Mol: zijn bol raakt de bel (open of niet: hij breekt hem zelf open).
		if bore != Vector3.INF and bore.distance_to(p.center) < p.radius + Mol.BORE_RADIUS:
			host_ignite(p.id, bore)
		elif magma and magma.visible and magma.level > p.center.y - Tuning.get_f("gas", "magma_ignite_m", 2.0):
			host_ignite(p.id, Vector3(p.center.x, magma.level, p.center.z))


func _host_explode(id: int) -> void:
	var p := pocket(id)
	if p == null or p.gone:
		return
	p.gone = true
	var c := p.center
	var r := p.radius
	# De rots kan enkel weg: een krater in de vloer onder de bel (of waar de bel zelf in de rots zat).
	var crater_at := c
	var down: Dictionary = game.terrain.raycast(c, c + Vector3.DOWN * r * 1.6)
	if not down.is_empty():
		crater_at = down.position
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, crater_at, Tuning.get_f("gas", "crater_m", 2.4)))
	var blast := r * Tuning.get_f("gas", "blast_k", 2.2)
	var inner := r * Tuning.get_f("gas", "inner_k", 0.6)
	for pl: Player in game.players.get_children():
		var body := pl.global_position + Vector3.UP * 0.7
		var d := body.distance_to(c)
		if d > blast:
			continue
		var k := 1.0 - clampf((d - inner) / maxf(0.1, blast - inner), 0.0, 1.0)
		var dmg := 1.0 if d < inner else lerpf(0.1, Tuning.get_f("gas", "damage_max", 0.85), k)
		var away := (body - c)
		away = away.normalized() if away.length() > 0.05 else Vector3.UP
		var push := away * lerpf(3.0, Tuning.get_f("gas", "push", 9.0), k) + Vector3.UP * 3.0
		game.rescue.host_damage(pl.peer_id, dmg, push, true, "gas")
	# Losse buit vliegt weg (de botsing zelf kost gaafheid, FindField).
	for it: FindItem in game.finds.items:
		if not it.freed or not it.carriers.is_empty() or it.freeze:
			continue
		var d := it.global_position.distance_to(c)
		if d < blast:
			var away := (it.global_position - c).normalized()
			it.apply_central_impulse(away * it.mass * lerpf(8.0, 2.0, d / blast))
	game.unrest.host_add(Tuning.get_f("gas", "noise", 25.0))
	if game.worm:
		game.worm.hear(c, Tuning.get_f("worm", "loud_explosion", 5.0))
	_rpc_explode.rpc(id, c, r)
	# Kettingreactie.
	for o in pockets:
		if o.gone or o.igniting or o.id == id:
			continue
		if o.center.distance_to(c) < o.radius + r + Tuning.get_f("gas", "chain_m", 4.0):
			o.igniting = true
			_fuse[o.id] = 0.25 + randf() * 0.2
			_rpc_fuse.rpc(o.id, c)


# --- Op elk peer ---------------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _rpc_fuse(id: int, _spark: Vector3) -> void:
	var p := pocket(id)
	if p == null:
		return
	p.igniting = true
	var h: GPUParticles3D = _haze_of.get(id)
	if h:
		var m := h.draw_pass_1.surface_get_material(0) as StandardMaterial3D
		var tw := h.create_tween()
		tw.tween_method(func(e: float) -> void: m.emission_energy_multiplier = e, 0.2, 4.0, Tuning.get_f("gas", "fuse_s", 0.6))
	var me: Player = game.local_player
	if me and me.global_position.distance_to(p.center) < p.radius * 3.0:
		game.notice.emit("Gas! Get clear!", "alarm")


@rpc("authority", "call_local", "reliable")
func _rpc_explode(id: int, at: Vector3, radius: float) -> void:
	var p := pocket(id)
	if p:
		p.gone = true
		p.igniting = false
	var h: GPUParticles3D = _haze_of.get(id)
	if h:
		h.emitting = false
		h.visible = false
		_haze_of.erase(id)
	_explosion_fx(at, radius)
	exploded.emit(id, at)


## Late joiner: welke bellen al ontploft zijn.
func send_state(peer: int) -> void:
	for p in pockets:
		if p.gone:
			_rpc_gone.rpc_id(peer, p.id)


@rpc("authority", "call_remote", "reliable")
func _rpc_gone(id: int) -> void:
	var p := pocket(id)
	if p:
		p.gone = true


# --- Beeld ---------------------------------------------------------------------------------------

## Is de bel open (lucht in het midden, of op een paar plekken erin)? Onthoudt wanneer hij openging.
func _refresh_open(p: Pocket) -> void:
	var t: TerrainAPI = game.terrain
	if p.open or not t.data_loaded(p.center):
		return
	var open := t.sdf_at(p.center) > 0.3
	if not open:
		for o: Vector3 in [Vector3(p.radius * 0.6, 0, 0), Vector3(-p.radius * 0.6, 0, 0), Vector3(0, 0, p.radius * 0.6),
				Vector3(0, 0, -p.radius * 0.6), Vector3(0, p.radius * 0.5, 0)]:
			if t.sdf_at(p.center + o) > 0.3:
				open = true
				break
	if open:
		p.open = true
		p.opened_at = Time.get_ticks_msec() / 1000.0


## De waas rond de camera: de dichtstbijzijnde open bellen krijgen een wolk (hooguit MAX_HAZE).
func _update_haze() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var view := Tuning.get_f("gas", "view_m", 55.0)
	var near: Array = []
	for p in pockets:
		if p.gone:
			continue
		var d := cam.global_position.distance_to(p.center)
		if d > view:
			continue
		var was := p.open
		_refresh_open(p)
		if p.open and not was and d < 25.0 and Time.get_ticks_msec() > 5000:
			game.notice.emit("You broke into a gas pocket! Keep the drill away from it.", "warn")
		if p.open:
			near.append([d, p])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var keep := {}
	for i in mini(near.size(), MAX_HAZE):
		var p: Pocket = near[i][1]
		keep[p.id] = true
		if not _haze_of.has(p.id):
			var h := _free_haze()
			h.global_position = p.center
			var pm := h.process_material as ParticleProcessMaterial
			pm.emission_sphere_radius = p.radius * 0.75
			(h.draw_pass_1.surface_get_material(0) as StandardMaterial3D).emission_energy_multiplier = 0.2
			h.restart()
			h.visible = true
			h.emitting = true
			_haze_of[p.id] = h
	for id: int in _haze_of.keys():
		if not keep.has(id):
			var h: GPUParticles3D = _haze_of[id]
			h.emitting = false
			h.visible = false
			_haze_of.erase(id)


func _free_haze() -> GPUParticles3D:
	for h in _haze:
		if not h.visible:
			return h
	var h := _make_haze()
	_haze.append(h)
	return h


func _make_haze() -> GPUParticles3D:
	var d := GPUParticles3D.new()
	d.amount = 70
	d.lifetime = 7.0
	d.preprocess = 7.0
	d.visibility_aabb = AABB(Vector3(-8, -6, -8), Vector3(16, 12, 16))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 3.0
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 0.02
	m.initial_velocity_max = 0.15
	m.gravity = Vector3(0, 0.01, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.3
	m.turbulence_noise_scale = 6.0
	m.scale_min = 1.0
	m.scale_max = 2.2
	m.angle_min = 0.0
	m.angle_max = 360.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.8, 0.25, 0.0))
	g.add_point(0.25, Color(0.88, 0.82, 0.3, 0.22))
	g.add_point(0.75, Color(0.8, 0.78, 0.28, 0.18))
	g.set_color(g.get_point_count() - 1, Color(0.75, 0.72, 0.25, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	d.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 1.8)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot()
	qm.emission_enabled = true
	qm.emission = Color(0.75, 0.7, 0.2)
	qm.emission_energy_multiplier = 0.2
	qm.roughness = 1.0
	q.material = qm
	d.draw_pass_1 = q
	d.visible = false
	d.emitting = false
	add_child(d)
	return d


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
		g.add_point(0.5, Color(1, 1, 1, 0.45))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		t.gradient = g
		_dot = t
	return _dot


## Ontploffing: een felle flits, een vuurbal (additief), rook, stof en brokken, en schok naar afstand.
func _explosion_fx(at: Vector3, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.25)
	light.omni_range = radius * 5.0
	light.light_energy = 12.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(light.queue_free)
	var fire := _burst(at, radius * 0.7, 90, 0.9, [Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.55, 0.12, 0.9), Color(0.5, 0.12, 0.02, 0.0)], true, 6.0 + radius)
	var smoke := _burst(at, radius * 0.6, 50, 4.0, [Color(0.25, 0.22, 0.2, 0.0), Color(0.22, 0.2, 0.18, 0.55), Color(0.15, 0.14, 0.13, 0.0)], false, 2.5)
	for e in [fire, smoke]:
		get_tree().create_timer(6.0).timeout.connect(e.queue_free)
	var col := Strata.DEBRIS_COLORS[game.terrain.layer_at(at)]
	for i in 10:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		game.fx.grit_puff(at + dir * radius * 0.8, dir, col)
	var me: Player = game.local_player
	if me and me.camera_fx:
		var k := 1.0 - smoothstep(radius, radius * 9.0, me.global_position.distance_to(at))
		me.camera_fx.add_trauma(0.9 * k)
		me.camera_fx.hold_rumble(4.0 * k)
		me.camera_fx.kick(-6.0 * k, randf_range(-4.0, 4.0) * k)


func _burst(at: Vector3, r: float, amount: int, life: float, ramp: Array, additive: bool, speed: float) -> GPUParticles3D:
	var d := GPUParticles3D.new()
	d.amount = amount
	d.lifetime = life
	d.one_shot = true
	d.explosiveness = 0.95
	d.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = r * 0.4
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = speed * 0.3
	m.initial_velocity_max = speed
	m.damping_min = speed * 0.8
	m.damping_max = speed * 1.4
	m.gravity = Vector3(0, 0.6 if not additive else 0.0, 0)
	m.scale_min = 0.8
	m.scale_max = 2.0
	var g := Gradient.new()
	g.set_color(0, ramp[0])
	g.add_point(0.35, ramp[1])
	g.set_color(g.get_point_count() - 1, ramp[2])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	d.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4) * maxf(1.0, r * 0.45)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = _soft_dot()
	if additive:
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.albedo_color = Color(3.0, 2.0, 1.0)
	q.material = qm
	d.draw_pass_1 = q
	add_child(d)
	d.global_position = at
	d.emitting = true
	return d
