class_name RobotRig
extends Node3D
## Het zichtbare robotlijf met procedurele animatie (GDD §8: wiebel, squash & stretch,
## veren). Model: assets/models/robot.glb (tools/blender/robot.py).
## Zet elke frame `velocity`, `on_floor` en `look_pitch`; roep swing() aan bij een slag.

const MODEL := preload("res://assets/models/robot.glb")
const FACE_SHADER := preload("res://src/player/robot_face.gdshader")

var velocity := Vector3.ZERO
var on_floor := true
var look_pitch := 0.0

var _torso: Node3D
var _head: Node3D
var _antenna: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _face: ShaderMaterial
var _rest := {} # node -> rust-transform

var _phase := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _was_on_floor := true
var _antenna_angle := Vector2.ZERO
var _antenna_vel := Vector2.ZERO
var _last_velocity := Vector3.ZERO
var _swing_t := -1.0
var _blink_timer := 2.0
var _blink := 0.0
var _rng := RandomNumberGenerator.new()


## Bouwt het lijf in de kleur `color`. Met `tool` hangt er een houweel in de rechterhand.
func setup(color: Color, with_pickaxe := true) -> void:
	var model := MODEL.instantiate()
	add_child(model)
	# Het model kijkt naar -Z, net als de speler.
	_torso = model.find_child("Torso") as Node3D
	_head = model.find_child("Head") as Node3D
	_antenna = model.find_child("Antenna") as Node3D
	_arm_l = model.find_child("Arm_L") as Node3D
	_arm_r = model.find_child("Arm_R") as Node3D
	_leg_l = model.find_child("Leg_L") as Node3D
	_leg_r = model.find_child("Leg_R") as Node3D
	for n in [_torso, _head, _antenna, _arm_l, _arm_r, _leg_l, _leg_r]:
		_rest[n] = n.transform
	_recolor(model, color)
	if with_pickaxe:
		var pick := PickaxeModel.build(0.0, color, false)
		pick.scale = Vector3.ONE * 1.1
		# In de hand: steel schuin omhoog-voor, punt naar voren.
		pick.position = Vector3(0.0, -0.3, -0.02)
		pick.rotation_degrees = Vector3(-22, 0, 0)
		_arm_r.add_child(pick)
	_rng.randomize()


func swing() -> void:
	_swing_t = 0.0


func _recolor(root: Node, color: Color) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			match mat.resource_name:
				"Body":
					var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = color
					mi.set_surface_override_material(i, m)
				"Screen":
					if _face == null:
						_face = ShaderMaterial.new()
						_face.shader = FACE_SHADER
					mi.set_surface_override_material(i, _face)


func _process(delta: float) -> void:
	if _torso == null:
		return
	var flat := Vector2(velocity.x, velocity.z)
	var speed := flat.length()
	var moving := clampf(speed / 4.5, 0.0, 1.0) * (1.0 if on_floor else 0.3)

	# Loopcyclus: benen en armen tegengesteld, lijf wipt en wiegt.
	_phase += delta * (4.0 + speed * 2.2) * (1.0 if moving > 0.05 else 0.0)
	var s := sin(_phase)
	var leg_swing := deg_to_rad(32.0) * moving
	_leg_l.transform = _rest[_leg_l] * Transform3D(Basis(Vector3.RIGHT, s * leg_swing), Vector3.ZERO)
	_leg_r.transform = _rest[_leg_r] * Transform3D(Basis(Vector3.RIGHT, -s * leg_swing), Vector3.ZERO)
	var bob := absf(cos(_phase)) * 0.045 * moving

	# Landen en springen: squash & stretch via een veer.
	if on_floor and not _was_on_floor:
		_squash_vel -= clampf(-_last_velocity.y * 0.35, 0.5, 3.0)
	if not on_floor and _was_on_floor and velocity.y > 1.0:
		_squash_vel += 1.5
	_was_on_floor = on_floor
	_squash_vel += (-_squash * 220.0 - _squash_vel * 14.0) * delta
	_squash += _squash_vel * delta
	var sq := clampf(_squash, -0.35, 0.35)
	var squash_scale := Vector3(1.0 - sq * 0.5, 1.0 + sq, 1.0 - sq * 0.5)

	var roll := s * deg_to_rad(4.0) * moving
	var lean := -deg_to_rad(8.0) * moving
	var torso_basis := Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, lean)
	_torso.transform = Transform3D(torso_basis.scaled(squash_scale), (_rest[_torso] as Transform3D).origin + Vector3(0, bob, 0))

	# Hoofd volgt de kijkhoek (begrensd).
	var pitch := clampf(look_pitch, deg_to_rad(-35), deg_to_rad(30))
	_head.transform = _rest[_head] * Transform3D(Basis(Vector3.RIGHT, pitch), Vector3.ZERO)

	# Armen: tegengesteld aan de benen, de rechter doet de slag.
	var arm_swing := deg_to_rad(28.0) * moving
	_arm_l.transform = _rest[_arm_l] * Transform3D(Basis(Vector3.RIGHT, -s * arm_swing), Vector3.ZERO)
	var right := -s * arm_swing * -1.0
	if _swing_t >= 0.0:
		_swing_t += delta
		var k := _swing_t / 0.55
		# Omhoog (aanzet), snel naar beneden (slag), terug.
		if k < 0.3:
			right = lerpf(0.0, deg_to_rad(160), _ease_out(k / 0.3))
		elif k < 0.45:
			right = lerpf(deg_to_rad(160), deg_to_rad(20), _ease_in((k - 0.3) / 0.15))
		else:
			right = lerpf(deg_to_rad(20), 0.0, _ease_out((k - 0.45) / 0.55))
		if k >= 1.0:
			_swing_t = -1.0
	_arm_r.transform = _rest[_arm_r] * Transform3D(Basis(Vector3.RIGHT, right), Vector3.ZERO)

	# Antenne: veer die reageert op versnelling.
	var accel := (velocity - _last_velocity) / maxf(delta, 0.0001)
	_last_velocity = velocity
	var local_accel := global_basis.inverse() * accel
	var target := Vector2(-local_accel.z, local_accel.x) * 0.004
	_antenna_vel += ((target - _antenna_angle) * 160.0 - _antenna_vel * 7.0) * delta
	_antenna_vel += Vector2(s, 0.0) * moving * 0.8 * delta * 60.0 * 0.02
	_antenna_angle += _antenna_vel * delta
	_antenna_angle = _antenna_angle.clamp(Vector2(-0.7, -0.7), Vector2(0.7, 0.7))
	_antenna.transform = _rest[_antenna] * Transform3D(
		Basis(Vector3.RIGHT, _antenna_angle.x) * Basis(Vector3.FORWARD, _antenna_angle.y), Vector3.ZERO)

	_update_face(delta, speed)


func _update_face(delta: float, speed: float) -> void:
	if _face == null:
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink = 1.0
		_blink_timer = _rng.randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta * 7.0)
	_face.set_shader_parameter("blink", 1.0 if _blink > 0.5 else 0.0)
	_face.set_shader_parameter("look", Vector2(0.0, clampf(look_pitch * 0.8, -1.0, 1.0)))
	_face.set_shader_parameter("squint", 1.0 if _swing_t >= 0.0 and _swing_t < 0.25 else 0.0)
	_face.set_shader_parameter("happy", 0.0)


static func _ease_in(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * k


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
