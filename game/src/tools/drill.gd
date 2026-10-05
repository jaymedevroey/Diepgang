class_name Drill
extends Node3D
## Boor T1 (GDD §5). Vasthouden: korte aanloop, dan eet hij continu dunne happen weg
## langs de kijkrichting (docs/research/graven.md: vloeiend, geen bolletjes). Graaft klei en
## zandsteen; op hardere rots slipt hij met vonken. Hitte: oververhit = even stil.
## Terreinbewerkingen gaan via TerrainSync (max-semantiek, 8 happen/s).
##
## Hang dit onder de camera. Verwacht: terrain, sync, camera, body, fx, camera_fx, color.

signal aim_changed(state: Pickaxe.Aim)
signal running_changed(running: bool)

const TOOL := Strata.Tool.BOOR_T1
const VIEWMODEL_FOV := 68.0
# Rechtsonder, bit gericht op het vizier.
const POSE := [Vector3(0.3, -0.33, -0.55), Vector3(6, 16, 0)]

var terrain: TerrainAPI
var sync: TerrainSync
var finds: FindField
var ores: OreField
var camera: Camera3D
var body: CharacterBody3D
var fx: DigFx
var camera_fx: CameraFx
var color := PickaxeModel.GLOVE
var aim := Pickaxe.Aim.NONE
## Voor tests en screenshots: boort alsof de knop ingedrukt is.
var auto_use := false

var heat := 0.0
var overheated := false
## 0..1: hoe snel het bit draait.
var spin := 0.0
var contact := false
var running := false

var _model: Node3D
var _bit: Node3D
var _lockout := 0.0
var _motor: AudioStreamPlayer
var _grind: AudioStreamPlayer
var _screech: AudioStreamPlayer
var _grit: GPUParticles3D
var _sparks: GPUParticles3D
var _dust: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _crust_timer := 0.0


func _ready() -> void:
	_model = DrillModel.build(VIEWMODEL_FOV, color)
	add_child(_model)
	_bit = _model.get_node("Bit")
	position = POSE[0]
	rotation_degrees = POSE[1]
	_motor = _loop("drill_motor", -8.0)
	_grind = _loop("drill_grind", -80.0)
	_screech = _loop("drill_screech", -80.0)
	_grit = fx.make_stream(DigFx.Stream.GRIT)
	_sparks = fx.make_stream(DigFx.Stream.SPARKS)
	_dust = fx.make_stream(DigFx.Stream.DUST)


func _exit_tree() -> void:
	for p in [_grit, _sparks, _dust]:
		if is_instance_valid(p):
			p.queue_free()


## Aan/uit bij het wisselen van gereedschap.
func set_active(on: bool) -> void:
	visible = on
	set_process(on)
	set_physics_process(on)
	if not on:
		spin = 0.0
		_set_contact(false, false, Vector3.ZERO, Vector3.UP, Color.BLACK)
		_motor.stop()
		_grind.stop()
		_screech.stop()
		_set_running(false)


func move_multiplier() -> float:
	return lerpf(1.0, Tuning.get_f("drill", "move_multiplier", 0.5), spin)


func _physics_process(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := auto_use or (captured and Input.is_action_pressed("dig"))
	var want := held and not overheated
	var ramp := Tuning.get_f("drill", "spinup_s", 0.22) if want else Tuning.get_f("drill", "spindown_s", 0.35)
	spin = move_toward(spin, 1.0 if want else 0.0, delta / maxf(ramp, 0.01))
	_set_running(want and spin > 0.9)

	var hit := _aim_hit()
	_update_aim(hit)
	var touching := false
	_crust_timer -= delta
	if running and not hit.is_empty() and hit.collider is Crust:
		# Door de korst boren: snel, maar de vondst lijdt eronder (host beslist).
		touching = true
		_set_contact(true, false, hit.position, hit.normal, DigFx.CRUST_COLOR)
		if _crust_timer <= 0.0:
			_crust_timer = 0.1
			finds.hit_crust(hit.collider.find_id, TOOL, hit.position)
			fx.crust_hit(hit.position, hit.normal, false)
	elif running and not hit.is_empty() and hit.collider is OreCluster:
		# Erts boren: trager per tik dan het houweel per slag, maar zonder pauze.
		var ore: OreCluster = hit.collider
		touching = true
		_set_contact(true, false, hit.position, hit.normal, OreKinds.COLORS[ore.kind])
		if _crust_timer <= 0.0:
			_crust_timer = 0.1
			ores.hit(ore.cluster_id, TOOL, hit.position)
	elif running and not hit.is_empty():
		var pos: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		var layer := terrain.layer_at(pos - normal * 0.2)
		var col := Strata.DEBRIS_COLORS[layer]
		touching = true
		if Strata.can_dig(layer, TOOL):
			var dir := -camera.global_basis.z
			var r := Tuning.get_f("drill", "bite_radius", 0.8)
			var bite := Tuning.get_f("drill", "bite_depth", 0.15)
			# De bol steekt precies `bite` voorbij het raakpunt, langs de kijkrichting.
			sync.submit_sphere(pos + dir * (bite - r), r, TOOL)
			_set_contact(true, false, pos, normal, col)
		else:
			_set_contact(true, true, pos, normal, col)
	if not touching:
		_set_contact(false, false, Vector3.ZERO, Vector3.UP, Color.BLACK)

	# Hitte.
	if running:
		heat += delta * Tuning.get_f("drill", "heat_rate", 1.0)
		if heat >= Tuning.get_f("drill", "heat_max", 5.5):
			overheated = true
			_lockout = Tuning.get_f("drill", "lockout_s", 4.0)
			fx.play("clink", global_position, -10.0)
	else:
		heat = maxf(0.0, heat - delta * Tuning.get_f("drill", "cool_rate", 2.0))
	if overheated:
		_lockout -= delta
		if _lockout <= 0.0:
			overheated = false
			heat = 0.0


func _process(delta: float) -> void:
	# Bit draait, behuizing trilt, geluid volgt toerental en belasting.
	_bit.rotate_object_local(Vector3.FORWARD, delta * spin * 55.0)
	var jitter := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * 0.004 * spin
	if contact:
		jitter *= 2.5
	position = POSE[0] + jitter + Vector3(0, 0, 0.02 * spin)
	if spin > 0.01:
		if not _motor.playing:
			_motor.play()
		_motor.pitch_scale = lerpf(0.45, 1.0, spin) * (0.86 if contact else 1.0)
		_motor.volume_db = lerpf(-30.0, -8.0, minf(1.0, spin * 1.5))
	elif _motor.playing:
		_motor.stop()
	if running:
		var shake := Tuning.get_f("drill", "shake_per_s", 1.2) * delta * (1.6 if contact else 0.5)
		if camera_fx.trauma() < Tuning.get_f("drill", "shake_cap", 0.32):
			camera_fx.add_trauma(shake)


func _aim_hit() -> Dictionary:
	var from := camera.global_position
	return terrain.tool_raycast(from, from - camera.global_basis.z * Tuning.get_f("drill", "reach", 2.8))


func _update_aim(hit: Dictionary) -> void:
	var new_aim := Pickaxe.Aim.NONE
	if not hit.is_empty() and hit.collider is Crust:
		new_aim = Pickaxe.Aim.CRUST
	elif not hit.is_empty() and hit.collider is OreCluster:
		new_aim = Pickaxe.Aim.ORE
	elif not hit.is_empty():
		var layer := terrain.layer_at(hit.position - hit.normal * 0.2)
		new_aim = Pickaxe.Aim.DIGGABLE if Strata.can_dig(layer, TOOL) else Pickaxe.Aim.TOO_HARD
	if new_aim != aim:
		aim = new_aim
		aim_changed.emit(aim)


func hint_too_hard() -> String:
	return "Too hard for the T1 drill: you need a T2 drill here"


func _set_running(on: bool) -> void:
	if on != running:
		running = on
		running_changed.emit(on)


func _set_contact(on: bool, skid: bool, pos: Vector3, normal: Vector3, col: Color) -> void:
	contact = on
	var biting := on and not skid
	for p: GPUParticles3D in [_grit, _dust]:
		p.emitting = biting
	_sparks.emitting = on and skid
	if on:
		for p: GPUParticles3D in [_grit, _dust, _sparks]:
			p.global_position = pos + normal * 0.05
			p.global_basis = DigFx._basis_x_to(normal)
		fx.tint_stream(_grit, col.darkened(0.2))
		fx.tint_stream(_dust, col)
	_grind.volume_db = move_toward(_grind.volume_db, -6.0 if biting else -80.0, 20.0)
	_screech.volume_db = move_toward(_screech.volume_db, -10.0 if (on and skid) else -80.0, 20.0)
	for p in [_grind, _screech]:
		if p.volume_db > -70.0 and not p.playing:
			p.play()
		elif p.volume_db <= -70.0 and p.playing:
			p.stop()


func _loop(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = load("res://assets/audio/sfx/%s.wav" % name)
	p.volume_db = db
	add_child(p)
	return p
