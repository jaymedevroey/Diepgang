class_name DebugPlayer
extends CharacterBody3D
## Tijdelijke first-person speler voor M0: lopen, springen, graven, vliegen (V).
## De echte robot komt in M1.

const LAYER_PLAYERS := 1 << 2
const MASK := 1 | (1 << 1) # terrein + buit

var terrain: TerrainAPI
var player_id := 1
var camera: Camera3D
var flying := false
var _pitch := 0.0


func _ready() -> void:
	collision_layer = LAYER_PLAYERS
	collision_mask = MASK

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)

	camera = Camera3D.new()
	camera.position.y = 1.2
	camera.fov = Tuning.get_f("player", "fov", 80.0)
	camera.near = 0.05
	add_child(camera)
	camera.make_current()

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 4.0
	lamp.spot_range = 18.0
	lamp.spot_angle = 38.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0.15, -0.1, 0.0)
	camera.add_child(lamp)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured:
		var sens := Tuning.get_f("player", "mouse_sensitivity", 0.0025)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -1.55, 1.55)
		camera.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fly"):
		flying = not flying


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if flying:
		var fly_speed := Tuning.get_f("player", "fly_speed", 12.0)
		var v := camera.global_basis * Vector3(input.x, 0.0, input.y) * fly_speed
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
		elif Input.is_action_just_pressed("jump"):
			velocity.y = Tuning.get_f("player", "jump_velocity", 4.5)
	move_and_slide()

	if Input.is_action_pressed("dig") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_try_dig()


func _try_dig() -> void:
	var forward := -camera.global_basis.z
	var from := camera.global_position
	var hit := terrain.raycast(from, from + forward * Tuning.get_f("player", "dig_reach", 3.5))
	if hit.is_empty():
		return
	var center: Vector3 = hit.position + forward * 0.2
	terrain.request_dig(player_id, center, Tuning.get_f("player", "dig_radius", 0.9))
