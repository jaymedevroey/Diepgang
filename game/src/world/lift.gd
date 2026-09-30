class_name Lift
extends Node3D
## De lift in de centrale schacht (GDD §3: "roep de lift naar die diepte").
## - Rails langs de schachtwand: E = lift naar jouw diepte roepen (werkt op elke diepte).
## - Op het platform: ▲ naar boven, ▼ zakt lift.step_down meter.
## - Spelers en vondsten op het platform rijden mee (AnimatableBody3D).
## - De host beslist; elk peer rijdt dezelfde beweging lokaal (vloeiend voor wie erop staat)
##   en de host stuurt elke halve seconde een correctie.
## Staat op elk peer op Game/Lift zodat RPC's aankomen.

signal arrived(y: float)

enum Command { CALL, UP, DOWN }

const RADIUS := 3.0
const DECK := 0.25
const SYNC_INTERVAL := 0.5

var game: Node # Game
var top_y := 150.0
var bottom_y := 5.0
## Hoogte van het dek (bovenkant van het platform).
var y := 150.0
var target_y := 150.0
var moving := false
var platform: AnimatableBody3D

var _center := Vector3.ZERO
var _cables: Array[MeshInstance3D] = []
var _display: Label3D
var _hum: AudioStreamPlayer3D
var _sync_timer := 0.0
var _vel := 0.0
var _wake_shape := BoxShape3D.new()


func setup() -> void:
	var t: TerrainAPI = game.terrain
	_center = t.shaft_center_world()
	top_y = t.surface_height_at(_center.x, _center.z)
	bottom_y = Tuning.get_f("lift", "bottom_margin", 3.0)
	y = top_y
	target_y = top_y
	_build_platform()
	_build_shaft()
	_build_gantry()
	_place()


# --- Bediening ------------------------------------------------------------------

func request(cmd: Command, player: Player) -> void:
	if Net.is_host():
		_handle(cmd, player.peer_id)
	else:
		_rpc_request.rpc_id(1, cmd)


@rpc("any_peer", "reliable")
func _rpc_request(cmd: int) -> void:
	if multiplayer.is_server():
		_handle(cmd, multiplayer.get_remote_sender_id())


func _handle(cmd: int, sender: int) -> void:
	var p: Player = game.player_node(sender)
	if p == null:
		return
	var flat := Vector2(p.global_position.x - _center.x, p.global_position.z - _center.z).length()
	if flat > RADIUS + Tuning.get_f("lift", "call_reach", 5.0):
		print("[lift] opdracht van %d geweigerd: te ver" % sender)
		return
	var to := y
	match cmd:
		Command.CALL:
			to = p.global_position.y
		Command.UP:
			to = top_y
		Command.DOWN:
			to = y - Tuning.get_f("lift", "step_down", 12.0)
	go_to(to)


## Host: lift naar een hoogte sturen (dek-hoogte).
func go_to(to: float) -> void:
	assert(multiplayer.is_server())
	to = clampf(to, bottom_y, top_y)
	_rpc_move.rpc(y, to)


@rpc("authority", "call_local", "reliable")
func _rpc_move(from_y: float, to_y: float) -> void:
	if absf(from_y - y) > 0.5:
		y = from_y
	target_y = to_y
	var was := moving
	moving = not is_equal_approx(y, target_y)
	if moving and not was:
		_clank()
		_hum.play()


## Late joiner: huidige toestand.
func send_state(peer: int) -> void:
	_rpc_move.rpc_id(peer, y, target_y)


@rpc("authority", "unreliable_ordered")
func _rpc_sync(host_y: float, host_target: float) -> void:
	target_y = host_target
	if absf(host_y - y) > 0.3:
		y = host_y


# --- Beweging ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if platform == null:
		return
	if moving:
		# Zachte aanloop en afremming: een bruuske stop lanceert vondsten van het platform.
		var remaining := target_y - y
		var accel := Tuning.get_f("lift", "acceleration", 3.0)
		var want := signf(remaining) * minf(Tuning.get_f("lift", "speed", 4.0), sqrt(2.0 * accel * absf(remaining)))
		_vel = move_toward(_vel, want, accel * delta)
		y += _vel * delta
		if absf(target_y - y) < 0.01 or signf(target_y - y) != signf(remaining):
			y = target_y
			_vel = 0.0
			moving = false
			_hum.stop()
			_clank()
			arrived.emit(y)
		if multiplayer.is_server():
			_wake_riders()
	_place()
	if multiplayer.is_server():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			for peer: int in game.ready_peers:
				if peer != multiplayer.get_unique_id():
					_rpc_sync.rpc_id(peer, y, target_y)


func _place() -> void:
	platform.global_position = Vector3(_center.x, y - DECK * 0.5, _center.z)
	var top := top_y + 4.2
	for c in _cables:
		var length := top - y - 1.0
		c.scale = Vector3(1, maxf(0.01, length), 1)
		c.position.y = 1.0 + length * 0.5
	_display.text = "%d m" % int(round(top_y - y))


## Host: vondsten op het platform wakker houden, anders blijven ze in de lucht hangen.
func _wake_riders() -> void:
	_wake_shape.size = Vector3(RADIUS * 2.0, 2.0, RADIUS * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _wake_shape
	q.transform = Transform3D(Basis(), Vector3(_center.x, y + 1.0, _center.z))
	q.collision_mask = Layers.LOOT
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var body := hit.collider as RigidBody3D
		if body and not body.freeze:
			body.sleeping = false


func _clank() -> void:
	game.fx.play("clink", platform.global_position, -6.0)


# --- Bouwen ---------------------------------------------------------------------

func _build_platform() -> void:
	platform = AnimatableBody3D.new()
	platform.name = "Platform"
	platform.sync_to_physics = true
	platform.collision_layer = Layers.LIFT
	platform.collision_mask = 0
	add_child(platform)

	var deck := CylinderShape3D.new()
	deck.radius = RADIUS
	deck.height = DECK
	var cs := CollisionShape3D.new()
	cs.shape = deck
	platform.add_child(cs)
	var deck_mesh := CylinderMesh.new()
	deck_mesh.top_radius = RADIUS
	deck_mesh.bottom_radius = RADIUS
	deck_mesh.height = DECK
	deck_mesh.radial_segments = 40
	_mesh(platform, deck_mesh, _metal(Color(0.2, 0.21, 0.23), 0.55), Vector3.ZERO)
	var ring := TorusMesh.new()
	ring.inner_radius = RADIUS - 0.2
	ring.outer_radius = RADIUS + 0.02
	ring.rings = 48
	_mesh(platform, ring, _hazard(), Vector3(0, DECK * 0.5, 0)).scale = Vector3(1, 0.12, 1)

	# Reling: 8 palen, 4 stukken leuning met 4 openingen om op en af te stappen.
	var metal := _metal(Color(0.5, 0.5, 0.52), 0.4)
	for i in 8:
		var a := deg_to_rad(22.5 + i * 45.0)
		var p := Vector3(cos(a), 0, sin(a)) * (RADIUS - 0.12)
		var post := CylinderMesh.new()
		post.top_radius = 0.035
		post.bottom_radius = 0.035
		post.height = 1.0
		_mesh(platform, post, metal, p + Vector3(0, 0.5 + DECK * 0.5, 0))
	for i in 4:
		var a0 := deg_to_rad(22.5 + i * 90.0)
		var a1 := a0 + deg_to_rad(45.0)
		var p0 := Vector3(cos(a0), 0, sin(a0)) * (RADIUS - 0.12)
		var p1 := Vector3(cos(a1), 0, sin(a1)) * (RADIUS - 0.12)
		for h in [0.5, 1.0]:
			var rail := BoxMesh.new()
			rail.size = Vector3(0.05, 0.05, p0.distance_to(p1))
			var mi := _mesh(platform, rail, _hazard() if h == 1.0 else metal, (p0 + p1) * 0.5 + Vector3(0, h + DECK * 0.5, 0))
			mi.look_at_from_position(mi.position, (p0 + p1) * 0.5 + (p1 - p0) + Vector3(0, h + DECK * 0.5, 0))
		# Botslichaam voor de leuning, zodat vondsten er niet af rollen.
		var fence := BoxShape3D.new()
		fence.size = Vector3(0.1, 1.0, p0.distance_to(p1))
		var fcs := CollisionShape3D.new()
		fcs.shape = fence
		platform.add_child(fcs)
		fcs.position = (p0 + p1) * 0.5 + Vector3(0, 0.5 + DECK * 0.5, 0)
		fcs.look_at_from_position(fcs.position, fcs.position + (p1 - p0))

	# Bedieningspaal met ▲ / ▼ en een dieptedisplay.
	var ca := deg_to_rad(45.0)
	var console_pos := Vector3(cos(ca), 0, sin(ca)) * (RADIUS - 0.9)
	var pole := BoxMesh.new()
	pole.size = Vector3(0.14, 1.05, 0.14)
	_mesh(platform, pole, metal, console_pos + Vector3(0, 0.55, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.42, 0.3, 0.16)
	var panel := _mesh(platform, head, _metal(Color(0.12, 0.12, 0.13), 0.6), console_pos + Vector3(0, 1.2, 0))
	panel.look_at_from_position(panel.position, Vector3(0, 1.2, 0))
	_display = Label3D.new()
	_display.font_size = 48
	_display.pixel_size = 0.0025
	_display.modulate = Color(1.0, 0.75, 0.3)
	_display.outline_size = 0
	panel.add_child(_display)
	_display.position = Vector3(0, 0.05, -0.085)
	_display.rotation_degrees = Vector3(0, 180, 0)
	for b in [[Command.UP, "E: lift naar boven", Color(0.3, 0.9, 0.4), -0.1], [Command.DOWN, "E: lift %d m omlaag" % int(Tuning.get_f("lift", "step_down", 12.0)), Color(1.0, 0.55, 0.15), 0.1]]:
		var box := BoxShape3D.new()
		box.size = Vector3(0.14, 0.12, 0.12)
		var btn := Interactable.make(b[1], box)
		panel.add_child(btn)
		btn.position = Vector3(b[3], -0.07, -0.09)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.045
		cap.bottom_radius = 0.05
		cap.height = 0.04
		var m := StandardMaterial3D.new()
		m.albedo_color = b[2]
		m.emission_enabled = true
		m.emission = b[2]
		m.emission_energy_multiplier = 1.5
		var mi := _mesh(btn, cap, m, Vector3.ZERO)
		mi.rotation_degrees = Vector3(90, 0, 0)
		var cmd: Command = b[0]
		btn.used.connect(func(p: Player) -> void: request(cmd, p))

	# Hangende werklamp.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.light_energy = 1.4
	lamp.omni_range = 7.0
	lamp.shadow_enabled = false
	platform.add_child(lamp)
	lamp.position = Vector3(0, 2.6, 0)
	var bulb := SphereMesh.new()
	bulb.radius = 0.08
	bulb.height = 0.16
	var bm := StandardMaterial3D.new()
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.8, 0.5)
	bm.emission_energy_multiplier = 4.0
	_mesh(platform, bulb, bm, Vector3(0, 2.6, 0))

	# Kabels van de reling naar het portaal (lengte volgt de hoogte).
	for i in 4:
		var a := deg_to_rad(22.5 + i * 90.0)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.height = 1.0
		var c := _mesh(platform, cyl, _metal(Color(0.15, 0.15, 0.16), 0.5), Vector3(cos(a), 0, sin(a)) * (RADIUS - 0.12))
		_cables.append(c)

	_hum = AudioStreamPlayer3D.new()
	_hum.stream = load("res://assets/audio/sfx/drill_motor.wav")
	_hum.pitch_scale = 0.32
	_hum.volume_db = -6.0
	_hum.unit_size = 6.0
	_hum.max_distance = 40.0
	platform.add_child(_hum)


## Vier roeprails langs de schachtwand, met een werklampje en dieptecijfer om de 12 m.
func _build_shaft() -> void:
	var height := top_y - bottom_y + 1.0
	var metal := _metal(Color(0.42, 0.43, 0.46), 0.4)
	for i in 4:
		var a := deg_to_rad(i * 90.0)
		var dir := Vector3(cos(a), 0, sin(a))
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, height, 0.22)
		var rail := Interactable.make("E: lift naar deze diepte roepen", box)
		add_child(rail)
		rail.global_position = _center + dir * 3.3 + Vector3(0, bottom_y + height * 0.5 - 0.5, 0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.12, height, 0.12)
		_mesh(rail, mesh, metal, Vector3.ZERO)
		var level := top_y - 12.0
		while level > bottom_y:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.7, 0.35)
			light.light_energy = 0.7
			light.omni_range = 4.5
			light.shadow_enabled = false
			add_child(light)
			light.global_position = _center + dir * 3.0 + Vector3(0, level + 1.6, 0)
			var tag := Label3D.new()
			tag.text = "-%d" % int(round(top_y - level))
			tag.font_size = 64
			tag.pixel_size = 0.004
			tag.modulate = Color(1.0, 0.75, 0.3)
			tag.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			add_child(tag)
			tag.global_position = _center + dir * 3.2 + Vector3(0, level + 2.0, 0)
			tag.look_at(_center + Vector3(0, level + 2.0, 0))
			tag.rotate_object_local(Vector3.UP, PI)
			level -= 12.0


## Portaal boven de schacht met de motor.
func _build_gantry() -> void:
	var steel := _metal(Color(0.32, 0.3, 0.28), 0.5)
	var top := top_y + 4.2
	for i in 2:
		var beam := BoxMesh.new()
		beam.size = Vector3(9.5, 0.3, 0.3)
		var mi := _mesh(self, beam, steel, _center + Vector3(0, top, 0))
		mi.rotation.y = PI * 0.5 * i + PI * 0.25
	for i in 4:
		var a := deg_to_rad(45.0 + i * 90.0)
		var leg := BoxMesh.new()
		leg.size = Vector3(0.25, 4.4, 0.25)
		var base := _center + Vector3(cos(a), 0, sin(a)) * 4.6
		base.y = game.terrain.surface_height_at(base.x, base.z)
		_mesh(self, leg, steel, base + Vector3(0, 2.2, 0))
	var motor := BoxMesh.new()
	motor.size = Vector3(1.2, 0.8, 1.2)
	_mesh(self, motor, _hazard(), _center + Vector3(0, top + 0.55, 0))


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


static func _metal(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.7
	m.roughness = rough
	return m


static var _hazard_mat: ShaderMaterial


## Geel-zwarte waarschuwingsstrepen.
static func _hazard() -> ShaderMaterial:
	if _hazard_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float s = step(0.5, fract((wpos.x + wpos.y + wpos.z) * 2.5));
	ALBEDO = mix(vec3(0.95, 0.7, 0.05), vec3(0.04), s);
	ROUGHNESS = 0.6;
}"""
		_hazard_mat = ShaderMaterial.new()
		_hazard_mat.shader = sh
	return _hazard_mat
