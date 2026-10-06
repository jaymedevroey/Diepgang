class_name Beacons
extends Node3D
## Lichtbakens (GDD §5, verbruik; §6: "Lichtbakens en lokaas houden hem op afstand. Er zijn geen
## wapens."). De ploeg deelt er een paar per dienst (beacon.cfg per_shift; pakket F1 kan er meer
## verkopen: `add`). G gooit er een met de linkerhand: een geel staafje met een fel amberen
## flikkerlicht (een fakkel, gevoel2-07) dat life_s blijft branden en op het einde sputtert. Een zachte
## ring van licht op de vloer toont de veilige zone: daarbinnen valt de worm niet uit (worm.repel_m).
## In een rijdende (of vertrekkende) Mol gaat G door de achterklep: het baken valt achter de Mol in de
## tunnel, waar de worm vandaan komt (ontwerp2-3). Een baken dat in een rijdende Mol ligt, telt niet:
## de motor overstemt het.
## Netwerk: de host telt en beslist; elk peer laat het baken zelf vallen (zelfde begin), en de host
## zet het daarna op zijn rustplek (de worm rekent met de plek van de host).

const MODEL_PATH := "res://assets/models/worm.glb"

## Hoeveel bakens de ploeg nog heeft (op elk peer gekend).
signal count_changed(left: int)
## Een baken ging uit de achterklep van de Mol (op elk peer; voor geluid). `at`: waar het valt.
signal launched(at: Vector3)
## Een baken ontsteekt (op elk peer; voor geluid).
signal lit(at: Vector3)

var game: Node # Game
## Bakens die de ploeg deze dienst nog heeft.
var left := 3

var _next_id := 1
var _items := {} # id -> RigidBody3D
var _stowed := {} # id -> Transform3D t.o.v. de Mol (lokaal)
var _rings := {} # id -> Decal: de veilige zone op de vloer
var _mesh: Mesh
static var _ring_tex: ImageTexture
static var _ring_glow_tex: ImageTexture


func _ready() -> void:
	left = Tuning.get_i("beacon", "per_shift", 3)


## Nieuwe wereld: alle bakens weg, de voorraad weer vol (host).
func attach_terrain(_terrain: TerrainAPI) -> void:
	for b: RigidBody3D in _items.values():
		if is_instance_valid(b):
			b.queue_free()
	for r: Decal in _rings.values():
		if is_instance_valid(r):
			r.queue_free()
	_items.clear()
	_stowed.clear()
	_rings.clear()
	if multiplayer.is_server():
		host_refill()


## Host: de voorraad voor een nieuwe dienst.
func host_refill() -> void:
	_rpc_left.rpc(Tuning.get_i("beacon", "per_shift", 3))


## Host: er komen bakens bij (bv. gekocht, pakket F1).
func add(n: int) -> void:
	if multiplayer.is_server():
		_rpc_left.rpc(left + n)


@rpc("authority", "call_local", "reliable")
func _rpc_left(n: int) -> void:
	left = maxi(0, n)
	count_changed.emit(left)


## Lokaal: een baken gooien, voor de speler uit, met de linkerhand. In een rijdende Mol: door de
## achterklep naar buiten.
func request_throw(p: Player) -> void:
	if p.camera == null:
		return
	if left <= 0:
		game.notice.emit("No beacons left this shift.", "warn")
		return
	if game.ship and game.ship.contains(p.global_position):
		return
	var mol: Mol = game.mol
	if mol and mol.body and (p.seated or mol.contains_point(p.global_position)) and launch_ready(mol):
		if Net.is_host():
			host_launch(Net.my_id())
		else:
			_rpc_launch.rpc_id(1)
		if not p.seated:
			_throw_hand(p)
		return
	var cb := p.camera.global_basis
	var fwd := -cb.z
	# Uit de linkerhand: links onder in beeld.
	var origin := p.camera.global_position + fwd * 0.45 + Vector3.DOWN * 0.15 - cb.x * 0.2
	var hit: Dictionary = game.terrain.raycast(p.camera.global_position, origin, Layers.TERRAIN | Layers.LIFT)
	if not hit.is_empty():
		origin = p.camera.global_position
	var vel := fwd * Tuning.get_f("beacon", "throw_speed", 9.0) + p.velocity + Vector3.UP * 1.8 + cb.x * 0.6
	if Net.is_host():
		_host_throw(Net.my_id(), origin, vel)
	else:
		_rpc_throw.rpc_id(1, origin, vel)
	_throw_hand(p)


## Kan een baken nu door de achterklep (de Mol rijdt, of vertrekt)?
func launch_ready(mol: Mol) -> bool:
	return absf(mol.speed) > 0.3 or mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING, Mol.Mode.AUTO_DOWN]


@rpc("any_peer", "reliable")
func _rpc_launch() -> void:
	if multiplayer.is_server():
		host_launch(multiplayer.get_remote_sender_id())


## Host: een baken door de achterklep van de Mol: het valt achter de Mol (achter in de rijrichting) in
## de tunnel. Dezelfde controles als bij de client: in de Mol, de Mol rijdt, er zijn er nog.
func host_launch(sender: int) -> bool:
	var p: Player = game.player_node(sender)
	var mol: Mol = game.mol
	if p == null or left <= 0 or mol == null or mol.body == null:
		return false
	if game.rescue and not game.rescue.can_act(sender):
		return false
	if not (p.seated or mol.contains_point(p.global_position)) or not launch_ready(mol):
		return false
	var travel := _travel(mol)
	var at := launch_point(mol)
	var id := _next_id
	_next_id += 1
	_rpc_left.rpc(left - 1)
	_rpc_spawn.rpc(id, at, -travel * 3.0 + Vector3.UP * 1.5)
	_rpc_launched.rpc(at)
	return true


## De rijrichting van de Mol (de terugrit is achteruit).
func _travel(mol: Mol) -> Vector3:
	var travel := mol.forward()
	if absf(mol.speed) > 0.1:
		travel *= signf(mol.speed)
	elif mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING]:
		travel = -travel
	return travel


## Waar een baken uit de achterklep valt: achter de Mol in de rijrichting, op de vloer.
func launch_point(mol: Mol) -> Vector3:
	var at := mol.body.global_position - _travel(mol) * Tuning.get_f("beacon", "launch_back_m", 8.5)
	var down: Dictionary = game.terrain.raycast(at + Vector3.UP * 2.0, at + Vector3.DOWN * 6.0)
	if not down.is_empty():
		at = (down.position as Vector3) + Vector3.UP * 0.4
	return at


@rpc("authority", "call_local", "reliable")
func _rpc_launched(at: Vector3) -> void:
	launched.emit(at)
	var me: Player = game.local_player
	var mol: Mol = game.mol
	if me and mol and mol.body and (me.seated or mol.contains_point(me.global_position)):
		game.notice.emit("Beacon out behind the Mole.", "mol")


## De worp met de linkerhand (enkel beeld, lokaal): de handschoen komt links onder in beeld omhoog
## en zwiept naar voren (0,25 s).
func _throw_hand(p: Player) -> void:
	if p.camera == null or not PickaxeModel.has_part("Glove"):
		return
	var hand := Node3D.new()
	hand.name = "BeaconThrow"
	var glove := PickaxeModel.part("Glove", 68.0, p.color, true)
	glove.scale = Vector3(-1, 1, 1)
	hand.add_child(glove)
	p.camera.add_child(hand)
	hand.position = Vector3(-0.32, -0.62, -0.42)
	hand.rotation_degrees = Vector3(-40, 15, 10)
	var tw := hand.create_tween()
	tw.tween_property(hand, "position", Vector3(-0.2, -0.2, -0.55), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(hand, "rotation_degrees", Vector3(10, 10, 0), 0.1)
	tw.tween_property(hand, "position", Vector3(-0.08, -0.5, -0.75), 0.15).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(hand, "rotation_degrees", Vector3(-55, 0, -10), 0.15)
	tw.tween_callback(hand.queue_free)
	if p.camera_fx:
		p.camera_fx.kick(0.8, -0.6)


@rpc("any_peer", "reliable")
func _rpc_throw(origin: Vector3, vel: Vector3) -> void:
	if multiplayer.is_server():
		_host_throw(multiplayer.get_remote_sender_id(), origin, vel)


func _host_throw(sender: int, origin: Vector3, vel: Vector3) -> void:
	var p: Player = game.player_node(sender)
	if p == null or left <= 0 or (game.rescue and not game.rescue.can_act(sender)):
		return
	if p.global_position.distance_to(origin) > 3.0:
		return
	var id := _next_id
	_next_id += 1
	_rpc_left.rpc(left - 1)
	_rpc_spawn.rpc(id, origin, vel.limit_length(14.0))


@rpc("authority", "call_local", "reliable")
func _rpc_spawn(id: int, origin: Vector3, vel: Vector3) -> void:
	var b := _make(id)
	add_child(b)
	b.global_position = origin
	b.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	b.reset_physics_interpolation()
	b.linear_velocity = vel
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	_items[id] = b
	var life := Tuning.get_f("beacon", "life_s", 120.0)
	var flick := b.get_node_or_null("Flicker") as BeaconFlicker
	if flick:
		flick.life = life
	var ring := _make_ring()
	add_child(ring)
	ring.global_position = origin
	_rings[id] = ring
	var tw := b.create_tween()
	tw.tween_interval(maxf(0.1, life - 3.0))
	tw.tween_method(func(k: float) -> void: _dim(b, k), 1.0, 0.0, 3.0)
	tw.tween_callback(func() -> void:
		_items.erase(id)
		_stowed.erase(id)
		var r: Decal = _rings.get(id)
		_rings.erase(id)
		if r and is_instance_valid(r):
			r.queue_free()
		b.queue_free())
	lit.emit(origin)
	if multiplayer.is_server():
		# Na het vallen: de rustplek van de host voor iedereen.
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if is_instance_valid(b) and _items.has(id):
				_rpc_rest.rpc(id, b.global_transform))


@rpc("authority", "call_remote", "reliable")
func _rpc_rest(id: int, xf: Transform3D) -> void:
	var b: RigidBody3D = _items.get(id)
	if b and is_instance_valid(b):
		b.global_transform = xf
		b.linear_velocity = Vector3.ZERO
		b.angular_velocity = Vector3.ZERO
		b.reset_physics_interpolation()


## Het dichtstbijzijnde brandende baken (wereld), of Vector3.INF. Een baken dat in een rijdende Mol
## meerijdt, telt niet (de worm hoort enkel de motor; ontwerp2-3), tenzij `include_stowed`.
func nearest(at: Vector3, include_stowed := false) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for id: int in _items:
		var b: RigidBody3D = _items[id]
		if not is_instance_valid(b) or (_stowed.has(id) and not include_stowed):
			continue
		var d := b.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = b.global_position
	return best


func count_active() -> int:
	return _items.size()


## Late joiner: de voorraad (de bakens zelf branden maar kort).
func send_state(peer: int) -> void:
	_rpc_left.rpc_id(peer, left)


## Een baken in een rijdende Mol rijdt mee (zoals de lading). De ring van de veilige zone ligt op de
## vloer onder het baken (niet als het in een rijdende Mol ligt: daar is het geen veilige zone).
func _physics_process(_delta: float) -> void:
	for id: int in _rings:
		var r: Decal = _rings[id]
		var bb: RigidBody3D = _items.get(id)
		if r == null or not is_instance_valid(r) or bb == null or not is_instance_valid(bb):
			continue
		r.global_position = bb.global_position + Vector3.UP * 0.5
		var l := bb.get_node_or_null("Light") as OmniLight3D
		var level := float(l.get_meta("level", 1.0)) if l else 1.0
		r.visible = not _stowed.has(id)
		r.modulate.a = 0.55 * level * (0.85 + 0.15 * sin(Time.get_ticks_msec() / 1000.0 * 2.0))
	var mol: Mol = game.mol if game else null
	if mol == null or mol.body == null or _items.is_empty():
		return
	var moving := absf(mol.speed) > 0.05 or mol.mode in Mol.MOVING_MODES
	for id: int in _items.keys():
		var b: RigidBody3D = _items[id]
		if not is_instance_valid(b):
			continue
		if moving and (_stowed.has(id) or mol.contains_point(b.global_position)):
			if not _stowed.has(id):
				_stowed[id] = mol.body.global_transform.affine_inverse() * b.global_transform
				b.freeze = true
			b.global_transform = mol.body.global_transform * (_stowed[id] as Transform3D)
		elif _stowed.has(id):
			_stowed.erase(id)
			b.freeze = false


func _dim(b: RigidBody3D, k: float) -> void:
	var l := b.get_node_or_null("Light") as OmniLight3D
	if l:
		l.set_meta("level", k)


func _make(id: int) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.name = "Beacon%d" % id
	b.mass = 1.2
	b.collision_layer = 0
	b.collision_mask = Layers.TERRAIN | Layers.LIFT | Layers.DEBRIS
	b.continuous_cd = true
	b.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var cs := CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = 0.06
	c.height = 0.42
	cs.shape = c
	b.add_child(cs)
	b.add_child(_model())
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = Color("#FFA04A")
	light.omni_range = Tuning.get_f("beacon", "light_range", 18.0)
	light.omni_attenuation = 0.8
	light.light_energy = Tuning.get_f("beacon", "light_energy", 7.0)
	light.shadow_enabled = false
	light.position = Vector3(0, 0.22, 0)
	b.add_child(light)
	# Een fakkel spuwt vonken.
	b.add_child(_sparks())
	var flick := BeaconFlicker.new()
	flick.name = "Flicker"
	flick.light = light
	b.add_child(flick)
	return b


## De veilige zone: een zachte ring van licht op de vloer, zo groot als worm.repel_m.
func _make_ring() -> Decal:
	var d := Decal.new()
	d.name = "SafeZone"
	d.top_level = true
	var r := Tuning.get_f("worm", "repel_m", 14.0)
	d.size = Vector3(r * 2.0, 10.0, r * 2.0)
	d.texture_albedo = _ring_texture()
	d.texture_emission = _ring_texture(true)
	d.emission_energy = 1.6
	d.albedo_mix = 0.6
	d.modulate = Color(1.0, 0.62, 0.25, 0.5)
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 0xFFFFF & ~PickaxeModel.VIEWMODEL_LAYER
	return d


## De ring: wit met de vorm in de alfa (albedo), of de vorm in de kleur zelf (`glow`: emissie telt de
## alfa niet, anders gloeit het hele vierkant).
static func _ring_texture(glow := false) -> ImageTexture:
	if glow and _ring_glow_tex:
		return _ring_glow_tex
	if not glow and _ring_tex:
		return _ring_tex
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x - n * 0.5 + 0.5, y - n * 0.5 + 0.5).length() / (n * 0.5)
			# Een smalle rand op de grens, met een zachte gloed naar binnen; streepjes om de 10°.
			var edge := exp(-pow((r - 0.96) / 0.018, 2.0))
			var inner := clampf((r - 0.55) / 0.41, 0.0, 1.0)
			inner = inner * inner * 0.22 * (1.0 if r < 0.97 else 0.0)
			var ang := atan2(y - n * 0.5, x - n * 0.5)
			var dash := 1.0 if fmod(ang + PI, TAU / 36.0) < TAU / 36.0 * 0.6 else 0.35
			var a := clampf(edge * dash + inner, 0.0, 1.0)
			img.set_pixel(x, y, Color(a, a, a, 1.0) if glow else Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	if glow:
		_ring_glow_tex = tex
	else:
		_ring_tex = tex
	return tex


## Vonken van de fakkel (enkel beeld).
func _sparks() -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.name = "Sparks"
	g.amount = 14
	g.lifetime = 0.6
	g.position = Vector3(0, 0.26, 0)
	g.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 50.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.8
	m.gravity = Vector3(0, -4.0, 0)
	m.scale_min = 0.5
	m.scale_max = 1.0
	m.color = Color(1.0, 0.7, 0.3)
	g.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	g.draw_pass_1 = q
	return g


## Het model: uit worm.glb (Beacon), anders een eenvoudig geel staafje met een gloeiende kop.
func _model() -> Node3D:
	if ResourceLoader.exists(MODEL_PATH):
		var model := (load(MODEL_PATH) as PackedScene).instantiate()
		var n := model.find_child("Beacon", true, false) as Node3D
		if n:
			n.get_parent().remove_child(n)
			n.owner = null
			for c in n.find_children("*", "", true, false):
				c.owner = null
			n.transform = Transform3D(Basis(), Vector3(0, -0.21, 0))
			model.queue_free()
			return n
		model.queue_free()
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.06
	cyl.height = 0.34
	body.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#F2B705")
	m.roughness = 0.5
	body.material_override = m
	body.position.y = -0.04
	root.add_child(body)
	var cap := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.11
	cap.mesh = s
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(1.0, 0.75, 0.4)
	cm.emission_enabled = true
	cm.emission = Color("#FFB45A")
	cm.emission_energy_multiplier = 6.0
	cap.material_override = cm
	cap.position.y = 0.16
	root.add_child(cap)
	return root


## Flikkerlicht van een baken: een fakkel, geen gloeilamp. `level` (meta op de lamp) dooft hem uit;
## de laatste sputter_s sputtert hij (valt even weg, komt terug, steeds vaker).
class BeaconFlicker:
	extends Node
	var light: OmniLight3D
	var life := 120.0
	var _t := randf() * 10.0
	var _age := 0.0

	func _process(delta: float) -> void:
		if light == null:
			return
		_t += delta
		_age += delta
		var k := 0.82 + 0.12 * sin(_t * 11.0) + 0.06 * sin(_t * 37.0 + 1.0)
		var left := life - _age
		var sputter := Tuning.get_f("beacon", "sputter_s", 8.0)
		if left < sputter and fmod(_t * 7.3, 1.0) < 0.45 * (1.0 - left / sputter):
			k *= 0.12
		light.light_energy = Tuning.get_f("beacon", "light_energy", 7.0) * float(light.get_meta("level", 1.0)) * k
