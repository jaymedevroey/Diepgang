class_name DebugPlayer
extends CharacterBody3D
## Tijdelijke first-person speler voor M0/M1: lopen, springen, vliegen (V), houweel.
## De echte robot komt in M1.
## Opbouw: DebugPlayer (yaw) > Head (pitch) > Camera3D (schok/kick via CameraFx) > Pickaxe

const LAYER_PLAYERS := 1 << 2
const MASK := 1 | (1 << 1) # terrein + buit

var terrain: TerrainAPI
var fx: DigFx
var player_id := 1
var head: Node3D
var camera: Camera3D
var camera_fx: CameraFx
var pickaxe: Pickaxe
var flying := false


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

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.2
	add_child(head)

	camera = Camera3D.new()
	camera.fov = Tuning.get_f("player", "fov", 80.0)
	camera.near = 0.05
	head.add_child(camera)
	camera.make_current()

	camera_fx = CameraFx.new()
	camera_fx.camera = camera
	add_child(camera_fx)

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	lamp.shadow_enabled = true
	# Boven en naast het oog, zoals op een helm: zo werpen putjes en richels schaduw.
	lamp.position = Vector3(0.18, 0.22, 0.05)
	head.add_child(lamp)

	pickaxe = Pickaxe.new()
	pickaxe.terrain = terrain
	pickaxe.camera = camera
	pickaxe.body = self
	pickaxe.fx = fx
	pickaxe.camera_fx = camera_fx
	pickaxe.player_id = player_id
	camera.add_child(pickaxe)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
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
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
		elif Input.is_action_just_pressed("jump"):
			velocity.y = Tuning.get_f("player", "jump_velocity", 4.5)
	move_and_slide()
