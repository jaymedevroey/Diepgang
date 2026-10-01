class_name Pickaxe
extends Node3D
## Houweel voor in beeld (GDD §5). Vasthouden = doorhakken, een klik = één slag.
## Het terrein breekt af op het inslagmoment van de zwaai, niet bij de klik
## (docs/research/graven.md). Graaft enkel lagen waar het houweel volstaat (klei);
## op hardere rots ketst het af met vonken.
##
## Hang dit onder de camera. Verwacht: terrain, sync (TerrainSync), camera, body, fx, camera_fx, color.

signal aim_changed(state: Aim)
## Begin van een zwaai (voor de robot die anderen zien).
signal swung

enum State { IDLE, WINDUP, STRIKE, HITSTOP, RECOVER }
enum Aim { NONE, DIGGABLE, TOO_HARD, CRUST }

const TOOL := Strata.Tool.HOUWEEL
const VIEWMODEL_FOV := 68.0

# Houdingen van de hand t.o.v. de camera: positie + rotatie in graden.
# Rotatie-X negatief = kop van de camera weg (naar voren), positief = naar achteren.
const POSE_REST := [Vector3(0.36, -0.37, -0.6), Vector3(-28, -18, -12)]
const POSE_RAISED := [Vector3(0.44, -0.18, -0.52), Vector3(40, -14, 20)]
const POSE_STRUCK := [Vector3(0.12, -0.34, -0.7), Vector3(-80, -4, 2)]

var terrain: TerrainAPI
var sync: TerrainSync
var finds: FindField
var camera: Camera3D
var body: CharacterBody3D
var fx: DigFx
var camera_fx: CameraFx
var color := PickaxeModel.GLOVE
var aim := Aim.NONE
## Voor tests en screenshots: zwaait alsof de knop ingedrukt is.
var auto_swing := false

var _state := State.IDLE
var _t := 0.0
var _buffered := false
var _hit_something := false
var _model: Node3D
var _from: Array
var _to: Array
var _bob_time := 0.0
var _sway := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_model = PickaxeModel.build(VIEWMODEL_FOV, color)
	add_child(_model)
	# Zacht vullicht dat enkel het gereedschap in beeld raakt (renderlaag 2),
	# anders valt het buiten de helmlamp en is het zwart.
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.65)
	fill.light_energy = 1.3
	fill.omni_range = 1.5
	fill.light_cull_mask = PickaxeModel.VIEWMODEL_LAYER
	fill.shadow_enabled = false
	fill.position = Vector3(0.1, 0.25, 0.1)
	camera.add_child.call_deferred(fill)
	_apply_pose(POSE_REST, POSE_REST, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sway += event.relative * 0.0006


func _process(delta: float) -> void:
	_update_aim()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := auto_swing or (captured and Input.is_action_pressed("dig"))
	if captured and Input.is_action_just_pressed("dig") and _state == State.RECOVER \
			and Tuning.value("pickaxe", "buffer_click", true):
		_buffered = true

	_t += delta
	match _state:
		State.IDLE:
			if held or _buffered:
				_start_swing()
			else:
				_apply_pose(POSE_REST, POSE_REST, 0.0)
		State.WINDUP:
			var d := Tuning.get_f("pickaxe", "windup_s", 0.17)
			_apply_pose(_from, POSE_RAISED, _ease_out(_t / d))
			if _t >= d:
				_enter(State.STRIKE, POSE_RAISED, POSE_STRUCK)
				fx.play("whoosh", camera.global_position, -12.0)
		State.STRIKE:
			var d := Tuning.get_f("pickaxe", "strike_s", 0.07)
			_apply_pose(POSE_RAISED, POSE_STRUCK, _ease_in(_t / d))
			if _t >= d:
				_hit_something = _impact()
				if _hit_something:
					_enter(State.HITSTOP, POSE_STRUCK, POSE_STRUCK)
				else:
					_enter(State.RECOVER, POSE_STRUCK, POSE_REST)
		State.HITSTOP:
			if _t >= Tuning.get_f("pickaxe", "hitstop_s", 0.055):
				_enter(State.RECOVER, POSE_STRUCK, POSE_REST)
		State.RECOVER:
			var d := Tuning.get_f("pickaxe", "recover_s", 0.26)
			var k := _t / d
			# Bij een raak: eerst een kleine terugslag, dan rustig terug naar de rusthouding.
			var recoil := sin(clampf(k, 0.0, 1.0) * PI) * (0.35 if _hit_something else 0.0)
			_apply_pose(POSE_STRUCK, POSE_REST, _ease_out(k), recoil)
			if _t >= d:
				_state = State.IDLE
				if held or _buffered:
					_start_swing()

	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))


## Aan/uit bij het wisselen van gereedschap.
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	if not on:
		_state = State.IDLE
		_buffered = false


func move_multiplier() -> float:
	return 1.0


func hint_too_hard() -> String:
	return "Te hard voor het houweel: hier heb je een boor nodig"


func _start_swing() -> void:
	_buffered = false
	swung.emit()
	_enter(State.WINDUP, _current_pose(), POSE_RAISED)


func _enter(state: State, from: Array, to: Array) -> void:
	_state = state
	_t = 0.0
	_from = from
	_to = to


## Inslag: straal langs het vizier. Geeft true als er iets geraakt is.
func _impact() -> bool:
	var reach := Tuning.get_f("pickaxe", "reach", 2.6)
	var from := camera.global_position
	var dir := -camera.global_basis.z
	var hit := terrain.tool_raycast(from, from + dir * reach)
	if hit.is_empty():
		return false
	var pos: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	if hit.collider is Crust:
		# Uitbikken: veilig voor de vondst, levens telt de host.
		finds.hit_crust(hit.collider.find_id, TOOL, pos)
		fx.crust_hit(pos, normal)
		camera_fx.kick(Tuning.get_f("pickaxe", "kick_pitch_deg", 1.6) * 0.7, _rng.randf_range(-1, 1) * 0.4)
		camera_fx.add_trauma(Tuning.get_f("pickaxe", "shake_trauma", 0.28) * 0.7)
		return true
	var layer := terrain.layer_at(pos - normal * 0.2)
	var color := Strata.DEBRIS_COLORS[layer]
	if Strata.can_dig(layer, TOOL):
		var ok := sync.submit_chip(pos, normal,
				Tuning.get_f("pickaxe", "chip_radius", 0.75),
				Tuning.get_f("pickaxe", "chip_depth", 0.45),
				Tuning.get_f("pickaxe", "chip_roughness", 0.14), TOOL)
		if ok:
			var pebbles := _rng.randi_range(Tuning.get_i("pickaxe", "pebbles_min", 3), Tuning.get_i("pickaxe", "pebbles_max", 5))
			fx.impact(pos, normal, color, pebbles)
			camera_fx.kick(Tuning.get_f("pickaxe", "kick_pitch_deg", 1.6), _rng.randf_range(-1, 1) * Tuning.get_f("pickaxe", "kick_yaw_deg", 0.6))
			camera_fx.add_trauma(Tuning.get_f("pickaxe", "shake_trauma", 0.28))
	else:
		fx.clink(pos, normal, color)
		camera_fx.kick(Tuning.get_f("pickaxe", "clink_kick_pitch_deg", 2.6), _rng.randf_range(-1, 1) * 1.2)
		camera_fx.add_trauma(Tuning.get_f("pickaxe", "clink_shake_trauma", 0.42))
	return true


func _update_aim() -> void:
	var reach := Tuning.get_f("pickaxe", "reach", 2.6)
	var from := camera.global_position
	var hit := terrain.tool_raycast(from, from - camera.global_basis.z * reach)
	var new_aim := Aim.NONE
	if not hit.is_empty() and hit.collider is Crust:
		new_aim = Aim.CRUST
	elif not hit.is_empty():
		var layer := terrain.layer_at(hit.position - hit.normal * 0.2)
		new_aim = Aim.DIGGABLE if Strata.can_dig(layer, TOOL) else Aim.TOO_HARD
	if new_aim != aim:
		aim = new_aim
		aim_changed.emit(aim)


# --- Houdingen ---------------------------------------------------------------

func _apply_pose(a: Array, b: Array, k: float, recoil := 0.0) -> void:
	var pos: Vector3 = (a[0] as Vector3).lerp(b[0], k)
	var rot: Vector3 = (a[1] as Vector3).lerp(b[1], k)
	rot.x += recoil * 25.0
	pos.z += recoil * 0.05
	# Wiegen bij het lopen en naslepen bij het rondkijken.
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if body.is_on_floor() and speed > 0.5:
		_bob_time += get_process_delta_time() * speed * 2.2
	var bob := Vector3(cos(_bob_time) * 0.012, absf(sin(_bob_time)) * 0.018, 0) * clampf(speed / 4.5, 0.0, 1.0)
	pos += bob + Vector3(-_sway.x, _sway.y, 0.0) * 0.6
	position = pos
	rotation_degrees = rot + Vector3(_sway.y * 60.0, _sway.x * 60.0, 0.0)


func _current_pose() -> Array:
	return [position, rotation_degrees]


static func _ease_in(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * k


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
