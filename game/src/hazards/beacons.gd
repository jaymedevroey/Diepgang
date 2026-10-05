class_name Beacons
extends Node3D
## Lichtbakens (GDD §5, verbruik; §6: "Lichtbakens en lokaas houden hem op afstand. Er zijn geen
## wapens."). De ploeg deelt er een paar per dienst (beacon.cfg per_shift; pakket F1 kan er meer
## verkopen: `add`). G gooit er een: een geel staafje met een fel amberen flikkerlicht dat
## life_s blijft branden. Waar een baken brandt, valt de worm niet uit (Worm, worm.repel_m), en een
## baken in de Mol houdt hem op de terugweg van het rammen af.
## Netwerk: de host telt en beslist; elk peer laat het baken zelf vallen (zelfde begin), en de host
## zet het daarna op zijn rustplek (de worm rekent met de plek van de host).

const MODEL_PATH := "res://assets/models/worm.glb"

## Hoeveel bakens de ploeg nog heeft (op elk peer gekend).
signal count_changed(left: int)

var game: Node # Game
## Bakens die de ploeg deze dienst nog heeft.
var left := 3

var _next_id := 1
var _items := {} # id -> RigidBody3D
var _stowed := {} # id -> Transform3D t.o.v. de Mol (lokaal)
var _mesh: Mesh


func _ready() -> void:
	left = Tuning.get_i("beacon", "per_shift", 3)


## Nieuwe wereld: alle bakens weg, de voorraad weer vol (host).
func attach_terrain(_terrain: TerrainAPI) -> void:
	for b: RigidBody3D in _items.values():
		if is_instance_valid(b):
			b.queue_free()
	_items.clear()
	_stowed.clear()
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


## Lokaal: een baken gooien, voor de speler uit.
func request_throw(p: Player) -> void:
	if p.camera == null:
		return
	if left <= 0:
		game.notice.emit("No beacons left this shift.", "warn")
		return
	if game.ship and game.ship.contains(p.global_position):
		return
	var fwd := -p.camera.global_basis.z
	var origin := p.camera.global_position + fwd * 0.45 + Vector3.DOWN * 0.15
	var hit: Dictionary = game.terrain.raycast(p.camera.global_position, origin, Layers.TERRAIN | Layers.LIFT)
	if not hit.is_empty():
		origin = p.camera.global_position
	var vel := fwd * Tuning.get_f("beacon", "throw_speed", 7.0) + p.velocity + Vector3.UP * 1.5
	if Net.is_host():
		_host_throw(Net.my_id(), origin, vel)
	else:
		_rpc_throw.rpc_id(1, origin, vel)


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
	var tw := b.create_tween()
	tw.tween_interval(maxf(0.1, life - 3.0))
	tw.tween_method(func(k: float) -> void: _dim(b, k), 1.0, 0.0, 3.0)
	tw.tween_callback(func() -> void:
		_items.erase(id)
		_stowed.erase(id)
		b.queue_free())
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


## Het dichtstbijzijnde brandende baken (wereld), of Vector3.INF.
func nearest(at: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for b: RigidBody3D in _items.values():
		if not is_instance_valid(b):
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


## Een baken in een rijdende Mol rijdt mee (zoals de lading).
func _physics_process(_delta: float) -> void:
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
	light.light_color = Color("#FFB45A")
	light.omni_range = Tuning.get_f("beacon", "light_range", 10.0)
	light.light_energy = Tuning.get_f("beacon", "light_energy", 3.0)
	light.shadow_enabled = false
	light.position = Vector3(0, 0.22, 0)
	b.add_child(light)
	var flick := BeaconFlicker.new()
	flick.light = light
	b.add_child(flick)
	return b


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


## Flikkerlicht van een baken: een fakkel, geen gloeilamp. `level` (meta op de lamp) dooft hem uit.
class BeaconFlicker:
	extends Node
	var light: OmniLight3D
	var _t := randf() * 10.0

	func _process(delta: float) -> void:
		if light == null:
			return
		_t += delta
		var k := 0.85 + 0.1 * sin(_t * 11.0) + 0.05 * sin(_t * 37.0 + 1.0)
		light.light_energy = Tuning.get_f("beacon", "light_energy", 3.0) * float(light.get_meta("level", 1.0)) * k
