class_name Player
extends CharacterBody3D
## Een robot. Op de peer die hem bestuurt (authority) is hij lokaal: invoer, camera,
## houweel, en hij stuurt zijn toestand ±20× per seconde. Op de andere peers is hij een
## kopie die geïnterpoleerd wordt (GDD §9: de client bepaalt de eigen beweging).
## Opbouw lokaal: Player (yaw) > Head (pitch) > Camera3D (CameraFx) > Pickaxe
## Naam van de node = peer-id, onder Game/Players, zodat RPC-paden overal gelijk zijn.

const LAYER_PLAYERS := 1 << 2
const MASK := 1 | (1 << 1) # terrein + buit
const SEND_INTERVAL := 0.05
const INTERP_DELAY_MS := 100.0

var peer_id := 1
var color := Color(0.95, 0.55, 0.12)
var game: Node # Game
var is_local := false

var head: Node3D
var camera: Camera3D
var camera_fx: CameraFx
var pickaxe: Pickaxe
var body_visual: Node3D
var flying := false

var _send_timer := 0.0
# Interpolatie (kopie): [lokale ontvangsttijd in ms, positie, yaw, pitch]
var _snapshots: Array = []
var _clock_offset := INF


func _ready() -> void:
	name = str(peer_id)
	set_multiplayer_authority(peer_id)
	is_local = peer_id == multiplayer.get_unique_id()
	collision_layer = LAYER_PLAYERS
	collision_mask = MASK

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.2
	add_child(head)

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	# Boven en naast het oog, zoals op een helm: zo werpen putjes en richels schaduw.
	lamp.position = Vector3(0.18, 0.22, 0.05)
	# Helmlampen van anderen zonder schaduw: GDD §9 budget van 4-8 schaduwlampen.
	lamp.shadow_enabled = is_local or Tuning.value("player", "remote_lamp_shadows", true)
	head.add_child(lamp)

	if is_local:
		_setup_local()
	else:
		_setup_remote()


func _setup_local() -> void:
	camera = Camera3D.new()
	camera.fov = Tuning.get_f("player", "fov", 80.0)
	camera.near = 0.05
	head.add_child(camera)
	camera.make_current()

	camera_fx = CameraFx.new()
	camera_fx.camera = camera
	add_child(camera_fx)

	pickaxe = Pickaxe.new()
	pickaxe.terrain = game.terrain
	pickaxe.sync = game.terrain_sync
	pickaxe.camera = camera
	pickaxe.body = self
	pickaxe.fx = game.fx
	pickaxe.camera_fx = camera_fx
	pickaxe.color = color
	camera.add_child(pickaxe)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_remote() -> void:
	# Tijdelijk lijf; de echte robot komt in stap 3.
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	mesh.mesh = capsule
	mesh.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mesh.material_override = mat
	body_visual = mesh
	add_child(mesh)
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.2, 0.1)
	visor.mesh = box
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.05, 0.08, 0.1)
	vmat.emission_enabled = true
	vmat.emission = Color(0.3, 0.9, 1.0)
	vmat.emission_energy_multiplier = 0.6
	visor.material_override = vmat
	visor.position = Vector3(0, 0, -0.33)
	head.add_child(visor)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var sens := Tuning.get_f("player", "mouse_sensitivity", 0.0025)
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.55, 1.55)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fly"):
		flying = not flying


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		input = Vector2.ZERO
	if flying:
		var fly_speed := Tuning.get_f("player", "fly_speed", 12.0)
		var v := head.global_basis * Vector3(input.x, 0.0, input.y) * fly_speed
		if Input.is_action_pressed("jump"):
			v.y += fly_speed
		if Input.is_action_pressed("crouch"):
			v.y -= fly_speed
		velocity = v
	else:
		var speed := Tuning.get_f("player", "move_speed", 4.5)
		var dir := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if not is_on_floor():
			velocity += get_gravity() * delta
		elif Input.is_action_just_pressed("jump") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			velocity.y = Tuning.get_f("player", "jump_velocity", 4.5)
	move_and_slide()


func _process(delta: float) -> void:
	if is_local:
		_send_timer += delta
		if _send_timer >= SEND_INTERVAL:
			_send_timer = 0.0
			var me := multiplayer.get_unique_id()
			for peer: int in game.ready_peers:
				if peer != me:
					_rpc_state.rpc_id(peer, Time.get_ticks_msec(), global_position, rotation.y, head.rotation.x)
	else:
		_interpolate()


## Toestand van de authority naar alle anderen. Onbetrouwbaar: een gemiste update
## wordt door de volgende vervangen.
@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_state(sent_ms: int, pos: Vector3, yaw: float, pitch: float) -> void:
	var now := float(Time.get_ticks_msec())
	# Klokverschil schatten: de kleinste (ontvangst - verzending) is de beste schatting.
	_clock_offset = minf(_clock_offset, now - sent_ms)
	_snapshots.append([float(sent_ms) + _clock_offset, pos, yaw, pitch])
	if _snapshots.size() > 30:
		_snapshots.pop_front()
	if _snapshots.size() == 1:
		global_position = pos
		rotation.y = yaw


func _interpolate() -> void:
	if _snapshots.is_empty():
		return
	var render_t := float(Time.get_ticks_msec()) - INTERP_DELAY_MS
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	global_position = (a[1] as Vector3).lerp(b[1], k)
	rotation.y = lerp_angle(a[2], b[2], k)
	head.rotation.x = lerpf(a[3], b[3], k)
