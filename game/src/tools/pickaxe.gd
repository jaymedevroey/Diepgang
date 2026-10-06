class_name Pickaxe
extends Node3D
## Houweel voor in beeld (GDD §5). Vasthouden = doorhakken, een klik = één slag.
## Het terrein breekt af op het inslagmoment van de zwaai, niet bij de klik
## (docs/research/graven.md). Graaft enkel lagen waar het houweel volstaat (klei);
## op hardere rots ketst het af met vonken.
##
## De zwaai is een boog (gevoel-09): aanzet hoog rechts (de kop boven de schouder, uit beeld), dan
## draait de kop rond de hand naar het vizier en landt hij met de punt naar de wand. Houdingen zijn
## een plek van de hand plus de richting van de steel en van de punt (in camera-ruimte); daartussen
## slerpt de draaiing, en de hand volgt een kromme. Bij het wisselen komt het gereedschap van onder
## in beeld; tijdens het sprinten zakt het weg.
##
## Hang dit onder de camera. Verwacht: terrain, sync (TerrainSync), camera, body, fx, camera_fx, color.

signal aim_changed(state: Aim)
## Begin van een zwaai (voor de robot die anderen zien).
signal swung

enum State { IDLE, WINDUP, STRIKE, HITSTOP, RECOVER }
enum Aim { NONE, DIGGABLE, TOO_HARD, CRUST, ORE }

const TOOL := Strata.Tool.HOUWEEL
const VIEWMODEL_FOV := 68.0

# Houdingen: [plek van de hand, richting van de steel (+Y van het model), richting van de punt (-Z)],
# in camera-ruimte (x rechts, y omhoog, -z vooruit).
const POSE_REST := [Vector3(0.38, -0.36, -0.62), Vector3(0.04, 0.9, -0.42), Vector3(-0.6, 0.12, -1.0)]
const POSE_RAISED := [Vector3(0.36, -0.12, -0.58), Vector3(0.15, 0.85, 0.35), Vector3(-0.2, 0.6, -1.0)]
const POSE_STRUCK := [Vector3(0.16, -0.38, -0.6), Vector3(-0.3, 0.6, -0.74), Vector3(0.0, -0.45, -1.0)]
const POSE_LOWERED := [Vector3(0.36, -0.82, -0.42), Vector3(0.1, 0.5, -0.85), Vector3(-0.3, -0.6, -1.0)]
const POSE_SPRINT := [Vector3(0.32, -0.55, -0.48), Vector3(0.35, 0.75, -0.3), Vector3(-0.7, 0.3, -0.6)]

var terrain: TerrainAPI
var sync: TerrainSync
var finds: FindField
var ores: OreField
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
var _hitstop := 0.0
var _model: Node3D
var _from: Array
var _bob_time := 0.0
var _sway := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _equip := 1.0 # 0 = net gewisseld (onder in beeld), 1 = klaar
var _sprint := 0.0 # 0..1: hoe ver het houweel weggezakt is tijdens het sprinten
var _idle_t := 0.0


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
	_apply(POSE_REST)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_sway += event.relative * 0.0006


func _process(delta: float) -> void:
	_update_aim()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var sprinting: bool = body is Player and (body as Player).sprinting
	var held := (auto_swing or (captured and Input.is_action_pressed("dig"))) and _equip > 0.6 and not sprinting
	if captured and Input.is_action_just_pressed("dig") and _state == State.RECOVER \
			and Tuning.value("pickaxe", "buffer_click", true):
		_buffered = true
	_equip = minf(1.0, _equip + delta / maxf(Tuning.get_f("pickaxe", "equip_s", 0.28), 0.01))
	_sprint = move_toward(_sprint, 1.0 if sprinting and _state == State.IDLE else 0.0, delta * 5.0)

	_t += delta
	match _state:
		State.IDLE:
			if held or _buffered and not sprinting:
				_start_swing()
			else:
				_apply(POSE_REST)
		State.WINDUP:
			var d := Tuning.get_f("pickaxe", "windup_s", 0.17)
			_apply_blend(_from, POSE_RAISED, _ease_out(_t / d))
			if _t >= d:
				_enter(State.STRIKE, POSE_RAISED)
				fx.play("whoosh", camera.global_position, -12.0)
		State.STRIKE:
			var d := Tuning.get_f("pickaxe", "strike_s", 0.07)
			_apply_blend(POSE_RAISED, POSE_STRUCK, _ease_in(_t / d), 0.0, true)
			if _t >= d:
				_hitstop = Tuning.get_f("pickaxe", "hitstop_s", 0.055)
				_hit_something = _impact()
				if _hit_something:
					_enter(State.HITSTOP, POSE_STRUCK)
				else:
					_enter(State.RECOVER, POSE_STRUCK)
		State.HITSTOP:
			_apply(POSE_STRUCK)
			if _t >= _hitstop:
				_enter(State.RECOVER, POSE_STRUCK)
		State.RECOVER:
			var d := Tuning.get_f("pickaxe", "recover_s", 0.26)
			var k := _t / d
			# Bij een raak: eerst een kleine terugslag, dan rustig terug naar de rusthouding.
			var recoil := sin(clampf(k, 0.0, 1.0) * PI) * (0.35 if _hit_something else 0.0)
			_apply_blend(POSE_STRUCK, POSE_REST, _ease_out(k), recoil)
			if _t >= d:
				_state = State.IDLE
				if held or _buffered:
					_start_swing()

	_sway = _sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))


## Aan/uit bij het wisselen van gereedschap. Aan: van onder in beeld komen.
func set_active(on: bool) -> void:
	if on and not visible:
		_equip = 0.0
	visible = on
	set_process(on)
	if not on:
		_state = State.IDLE
		_buffered = false


func move_multiplier() -> float:
	return 1.0


func hint_too_hard() -> String:
	return "Too hard for the pickaxe: switch to the drill"


func _start_swing() -> void:
	_buffered = false
	swung.emit()
	_enter(State.WINDUP, _current_pose())


func _enter(state: State, from: Array) -> void:
	_state = state
	_t = 0.0
	_from = from


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
	if hit.collider is Rubble and (hit.collider as Rubble).blocks:
		# Puin van een instorting wegbikken (pakket F2): de host telt de levens.
		(hit.collider as Rubble).chip(false, pos)
		fx.impact(pos, normal, Strata.DEBRIS_COLORS[terrain.layer_at(pos)], 3)
		camera_fx.kick(Tuning.get_f("pickaxe", "kick_pitch_deg", 1.6), _rng.randf_range(-1, 1) * 0.6)
		camera_fx.add_trauma(Tuning.get_f("pickaxe", "shake_trauma", 0.28))
		return true
	if hit.collider is Crust:
		# Uitbikken: veilig voor de vondst, levens telt de host. De slag die de korst breekt (hier al
		# te voorspellen) krijgt een langere hit-stop en een grotere schok: dat is het moment.
		var crust: Crust = hit.collider
		var breaking := crust.hp <= Tuning.get_f("finds", "pickaxe_damage", 1.0) + 0.001
		finds.hit_crust(crust.find_id, TOOL, pos)
		fx.crust_hit(pos, normal, true, crust.tint)
		var k := 1.6 if breaking else 0.7
		camera_fx.kick(Tuning.get_f("pickaxe", "kick_pitch_deg", 1.6) * k, _rng.randf_range(-1, 1) * 0.4)
		camera_fx.add_trauma(Tuning.get_f("pickaxe", "shake_trauma", 0.28) * k)
		if breaking:
			_hitstop = Tuning.get_f("pickaxe", "break_hitstop_s", 0.11)
		return true
	if hit.collider is OreCluster:
		# Erts delven: één eenheid per slag (de host telt).
		var ore: OreCluster = hit.collider
		ores.hit(ore.cluster_id, TOOL, pos)
		fx.ore_hit(pos, normal, ore.kind)
		camera_fx.kick(Tuning.get_f("pickaxe", "kick_pitch_deg", 1.6) * 0.8, _rng.randf_range(-1, 1) * 0.5)
		camera_fx.add_trauma(Tuning.get_f("pickaxe", "shake_trauma", 0.28) * 0.8)
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
			fx.fresh_cut(pos, normal, Tuning.get_f("pickaxe", "chip_radius", 0.75), color)
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
	if not hit.is_empty() and (hit.collider is Crust or hit.collider is Rubble):
		new_aim = Aim.CRUST
	elif not hit.is_empty() and hit.collider is OreCluster:
		new_aim = Aim.ORE
	elif not hit.is_empty():
		var layer := terrain.layer_at(hit.position - hit.normal * 0.2)
		new_aim = Aim.DIGGABLE if Strata.can_dig(layer, TOOL) else Aim.TOO_HARD
	if new_aim != aim:
		aim = new_aim
		aim_changed.emit(aim)


# --- Houdingen ---------------------------------------------------------------

## Draaiing uit de richting van de steel en de punt (Gram-Schmidt).
static func _pose_quat(p: Array) -> Quaternion:
	var y := (p[1] as Vector3).normalized()
	var spike := (p[2] as Vector3)
	var z := -(spike - y * spike.dot(y)).normalized()
	var x := y.cross(z).normalized()
	return Quaternion(Basis(x, y, z).orthonormalized())


func _apply(p: Array) -> void:
	_apply_blend(p, p, 1.0)


## Tussen twee houdingen: draaiing slerpt (de kop zwaait in een boog rond de hand), de hand volgt
## een licht naar voren gebogen kromme. `arc`: tijdens de slag gaat de hand eerst naar voren.
func _apply_blend(a: Array, b: Array, k: float, recoil := 0.0, arc := false) -> void:
	k = clampf(k, 0.0, 1.0)
	var qa := _pose_quat(a) if a.size() == 3 else (a[1] as Quaternion)
	var pa: Vector3 = a[0]
	var pos: Vector3 = pa.lerp(b[0], k)
	if arc:
		pos += Vector3(0.0, 0.05, -0.08) * sin(k * PI)
	var q := qa.slerp(_pose_quat(b), k)
	# Terugslag na een raak: de kop veert even terug naar de camera.
	q = q * Quaternion(Vector3.RIGHT, recoil * deg_to_rad(25.0))
	pos.z += recoil * 0.05
	# Rust: lichte ademhaling. Wiegen bij het lopen en naslepen bij het rondkijken.
	var dt := get_process_delta_time()
	_idle_t += dt
	var breathe := Vector3(0.0, sin(_idle_t * 1.6) * 0.004, 0.0)
	var speed := Vector2(body.velocity.x, body.velocity.z).length()
	if body.is_on_floor() and speed > 0.5:
		_bob_time += dt * speed * 2.2
	var bob := Vector3(cos(_bob_time) * 0.012, absf(sin(_bob_time)) * 0.018, 0) * clampf(speed / 4.5, 0.0, 1.0)
	pos += bob + breathe + Vector3(-_sway.x, _sway.y, 0.0) * 0.6
	# Wisselen (van onder in beeld) en sprinten (weggezakt).
	var e := _ease_out(_equip)
	if e < 1.0 or _sprint > 0.0:
		var low: Array = POSE_LOWERED if e < 1.0 else POSE_SPRINT
		var w := maxf(1.0 - e, _sprint)
		pos = pos.lerp(low[0], w)
		q = q.slerp(_pose_quat(low), w)
	position = pos
	quaternion = q * Quaternion.from_euler(Vector3(_sway.y, _sway.x, 0.0) * 1.05)


func _current_pose() -> Array:
	return [position, quaternion]


static func _ease_in(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * k


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)
