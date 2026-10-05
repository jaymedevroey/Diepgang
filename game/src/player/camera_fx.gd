class_name CameraFx
extends Node
## Schermschok (trauma-model) en camera-kick (veer) op een Camera3D.
## De camera moet een eigen node zijn onder de node die de kijkrichting draagt:
## CameraFx zet enkel de lokale rotatie van de camera.

var camera: Camera3D
## Extra kanteling rond de kijkas (radialen), bv. zijwaarts lopen. Gezet door de speler.
var roll := 0.0

var _trauma := 0.0
## Traag rollen (bevingen, Unrest): graden, ebt zelf weg. Los van het trauma, dat snel trilt.
var _rumble_deg := 0.0
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
	_trauma = clampf(_trauma + amount * Settings.get_f("interface/camera_shake"), 0.0, 1.0)


## Minstens zoveel trauma (bevingen): een ondergrens vecht niet tegen het verval, zoals steeds
## trauma bijtellen dat zou doen (onderzoek magma-en-onrust, E).
func hold_trauma(amount: float) -> void:
	_trauma = maxf(_trauma, clampf(amount * Settings.get_f("interface/camera_shake"), 0.0, 1.0))


## Minstens zoveel traag rollen (graden, ±2-3 Hz): een beving rolt, ze zoemt niet (gevoel-08).
func hold_rumble(deg: float) -> void:
	_rumble_deg = maxf(_rumble_deg, deg * Settings.get_f("interface/camera_shake"))


## Stoot de camera weg (pitch omhoog = positief), veert daarna terug.
func kick(pitch_deg: float, yaw_deg: float) -> void:
	_kick_vel += Vector2(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg)) * 40.0 * Settings.get_f("interface/camera_shake")


func _process(delta: float) -> void:
	if camera == null:
		return
	_time += delta
	var stiffness := Tuning.get_f("camera", "kick_stiffness", 180.0)
	var damping := Tuning.get_f("camera", "kick_damping", 18.0)
	# De veer in kleine stapjes: in één lang frame (laden, een screenshot, een hapering) ontplofte hij
	# (stijfheid × delta > 2) en tolde de camera rond, tot NaN toe. Hooguit 0,1 s per frame meetellen.
	var left := minf(delta, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_kick_vel += (-_kick * stiffness - _kick_vel * damping) * h
		_kick += _kick_vel * h
		left -= h

	_trauma = maxf(0.0, _trauma - Tuning.get_f("camera", "trauma_decay", 1.6) * delta)
	var shake := _trauma * _trauma * Tuning.get_f("camera", "screen_shake_scale", 1.0)
	var max_rad := deg_to_rad(Tuning.get_f("camera", "shake_max_deg", 2.2)) * shake
	var f := _time * Tuning.get_f("camera", "shake_frequency", 22.0)
	_rumble_deg = maxf(0.0, _rumble_deg - 2.5 * delta)
	var rumble := deg_to_rad(_rumble_deg)
	var g := _time * 2.6
	camera.rotation = Vector3(
		_kick.x + max_rad * _noise.get_noise_2d(f, 0.0) + rumble * 0.6 * _noise.get_noise_2d(g, 50.0),
		_kick.y + max_rad * _noise.get_noise_2d(0.0, f) + rumble * 0.5 * _noise.get_noise_2d(50.0, g),
		roll + max_rad * 0.5 * _noise.get_noise_2d(f, f) + rumble * _noise.get_noise_2d(g, g + 90.0))
