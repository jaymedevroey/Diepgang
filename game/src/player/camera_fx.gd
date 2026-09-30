class_name CameraFx
extends Node
## Schermschok (trauma-model) en camera-kick (veer) op een Camera3D.
## De camera moet een eigen node zijn onder de node die de kijkrichting draagt:
## CameraFx zet enkel de lokale rotatie van de camera.

var camera: Camera3D

var _trauma := 0.0
var _kick := Vector2.ZERO # x = pitch, y = yaw (radialen)
var _kick_vel := Vector2.ZERO
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = 7
	_noise.frequency = 1.0


func trauma() -> float:
	return _trauma


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Stoot de camera weg (pitch omhoog = positief), veert daarna terug.
func kick(pitch_deg: float, yaw_deg: float) -> void:
	_kick_vel += Vector2(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg)) * 40.0


func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	var stiffness := Tuning.get_f("camera", "kick_stiffness", 180.0)
	var damping := Tuning.get_f("camera", "kick_damping", 18.0)
	_kick_vel += (-_kick * stiffness - _kick_vel * damping) * delta
	_kick += _kick_vel * delta

	_trauma = maxf(0.0, _trauma - Tuning.get_f("camera", "trauma_decay", 1.6) * delta)
	var shake := _trauma * _trauma * Tuning.get_f("camera", "screen_shake_scale", 1.0)
	var max_rad := deg_to_rad(Tuning.get_f("camera", "shake_max_deg", 2.2)) * shake
	var f := _time * Tuning.get_f("camera", "shake_frequency", 22.0)
	camera.rotation = Vector3(
		_kick.x + max_rad * _noise.get_noise_2d(f, 0.0),
		_kick.y + max_rad * _noise.get_noise_2d(0.0, f),
		max_rad * 0.5 * _noise.get_noise_2d(f, f))
