class_name Drill
extends Node3D
## Boor T1/T2 (GDD §5). Vasthouden: korte aanloop, dan eet hij continu happen weg langs de
## kijkrichting (docs/research/graven.md: vloeiend, geen bolletjes). T1 graaft klei en zandsteen; op
## hardere rots slipt hij met vonken. T2 (upgrade van de ploeg, F1: Upgrades.drill_tier) graaft ook
## graniet en kristal; dan krijgt hij een cyane band en het label T2. Hitte: oververhit = even stil.
## Terreinbewerkingen gaan via TerrainSync (max-semantiek). De happen komen op een vast ritme in
## speltijd (drill.bites_per_s); de snelheidslimiet van het terrein is enkel nog een vangnet.
##
## Hardheid per laag (gevoel-11): in klei bijt hij diep (±3× sneller dan het houweel), in zandsteen
## half zo diep en hij wordt er sneller heet. Waarden in drill.cfg.
## Korst (ontwerp-11): de vondst verliest per hap gaafheid; met een hete boor (meer dan de helft van
## de hitte) dubbel zoveel. Tikjes geven is dus voorzichtiger dan vasthouden (FindField beslist).
## In beeld (gevoel-15): bit en kop gloeien met de hitte, oververhit = stoom en een hangende boor,
## en bij contact schuift de boor naar voren en schokt hij.
##
## Hang dit onder de camera. Verwacht: terrain, sync, camera, body, fx, camera_fx, color.

signal aim_changed(state: Pickaxe.Aim)
signal running_changed(running: bool)
## Oververhit aan/uit (een plek voor het gesis, M6).
signal overheated_changed(on: bool)

## Het niveau van deze boor (T1, of T2 als de ploeg de upgrade kocht). De host controleert hetzelfde
## (TerrainSync._validate: niet beter dan wat de ploeg bezit).
var tool := Strata.Tool.BOOR_T1
const VIEWMODEL_FOV := 68.0
# Rechtsonder, bit gericht op het vizier.
const POSE := [Vector3(0.3, -0.33, -0.55), Vector3(6, 16, 0)]
# Oververhit: de boor hangt (bit omlaag, lager in beeld).
const POSE_HANG := [Vector3(0.32, -0.45, -0.5), Vector3(-28, 22, 8)]
# Net gewisseld: van onder in beeld.
const POSE_LOW := [Vector3(0.34, -0.85, -0.42), Vector3(-45, 25, 0)]
const HEAT_COLOR := Color(1.0, 0.32, 0.06)
## Waar de punt van het bit in beeld lijkt te staan (camera-ruimte, ±1 m voor je).
const STEAM_AT := Vector3(0.17, -0.25, -1.0)

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
var _steam: GPUParticles3D
var _rng := RandomNumberGenerator.new()
var _crust_timer := 0.0
var _bite_timer := 0.0
var _heat_rate := 1.0
var _glow_mats: Array[ShaderMaterial] = []
var _equip := 1.0
var _hang := 0.0
var _push := 0.0


func _ready() -> void:
	_model = DrillModel.build(VIEWMODEL_FOV, color)
	add_child(_model)
	_bit = _model.get_node("Bit")
	# Eigen materialen voor het bit en de kop (de gloed mag niet op het houweel, dat deelt ze).
	for mi: MeshInstance3D in [_bit.get_child(0), _model.get_node("Drill")]:
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m == null:
				continue
			var mine := m.duplicate() as ShaderMaterial
			mi.set_surface_override_material(i, mine)
			# Enkel het staal vooraan gloeit (bit, klauwplaat), niet de gele behuizing of de greep.
			if mi == _bit.get_child(0) or (m.get_shader_parameter("metallic") as float) > 0.4:
				_glow_mats.append(mine)
	position = POSE[0]
	rotation_degrees = POSE[1]
	_motor = _loop("drill_motor", -8.0)
	_grind = _loop("drill_grind", -80.0)
	_screech = _loop("drill_screech", -80.0)
	_grit = fx.make_stream(DigFx.Stream.GRIT)
	_sparks = fx.make_stream(DigFx.Stream.SPARKS)
	_dust = fx.make_stream(DigFx.Stream.DUST)
	_steam = fx.make_stream(DigFx.Stream.STEAM)


func _exit_tree() -> void:
	for p in [_grit, _sparks, _dust, _steam]:
		if is_instance_valid(p):
			p.queue_free()


## Aan/uit bij het wisselen van gereedschap. Aan: van onder in beeld komen.
func set_active(on: bool) -> void:
	if on and not visible:
		_equip = 0.0
	visible = on
	set_process(on)
	set_physics_process(on)
	if not on:
		spin = 0.0
		_set_contact(false, false, Vector3.ZERO, Vector3.UP, Color.BLACK)
		_steam.emitting = false
		_motor.stop()
		_grind.stop()
		_screech.stop()
		_set_running(false)


func move_multiplier() -> float:
	return lerpf(1.0, Tuning.get_f("drill", "move_multiplier", 0.5), spin)


func _physics_process(delta: float) -> void:
	_update_tier()
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var held := auto_use or (captured and Input.is_action_pressed("dig"))
	var want := held and not overheated and _equip > 0.6
	var ramp := Tuning.get_f("drill", "spinup_s", 0.22) if want else Tuning.get_f("drill", "spindown_s", 0.35)
	spin = move_toward(spin, 1.0 if want else 0.0, delta / maxf(ramp, 0.01))
	_set_running(want and spin > 0.9)

	var hit := _aim_hit()
	_update_aim(hit)
	var touching := false
	_crust_timer -= delta
	_bite_timer -= delta
	_heat_rate = Tuning.get_f("drill", "heat_rate_idle", 0.6)
	var heat_max := Tuning.get_f("drill", "heat_max", 5.5)
	if running and not hit.is_empty() and hit.collider is Rubble and (hit.collider as Rubble).blocks:
		# Puin van een instorting wegboren (pakket F2): de host telt de levens.
		touching = true
		_heat_rate = Tuning.get_f("drill", "heat_rate_klei", 0.75)
		_set_contact(true, false, hit.position, hit.normal, Strata.DEBRIS_COLORS[terrain.layer_at(hit.position)])
		if _crust_timer <= 0.0:
			_crust_timer = 0.1
			(hit.collider as Rubble).chip(true, hit.position)
	elif running and not hit.is_empty() and hit.collider is Crust:
		# Door de korst boren: snel, maar de vondst lijdt eronder (host beslist), meer met een hete boor.
		var crust: Crust = hit.collider
		touching = true
		_heat_rate = Tuning.get_f("drill", "heat_rate_klei", 0.75)
		_set_contact(true, false, hit.position, hit.normal, crust.tint)
		if _crust_timer <= 0.0:
			_crust_timer = 0.1
			finds.hit_crust(crust.find_id, tool, hit.position, heat > heat_max * Tuning.get_f("finds", "drill_hot_from", 0.5))
			fx.crust_hit(hit.position, hit.normal, false, crust.tint)
	elif running and not hit.is_empty() and hit.collider is OreCluster:
		# Erts boren: trager per tik dan het houweel per slag, maar zonder pauze.
		var ore: OreCluster = hit.collider
		touching = true
		_heat_rate = Tuning.get_f("drill", "heat_rate_klei", 0.75)
		_set_contact(true, false, hit.position, hit.normal, OreKinds.COLORS[ore.kind])
		if _crust_timer <= 0.0:
			_crust_timer = 0.1
			ores.hit(ore.cluster_id, tool, hit.position)
			fx.ore_hit(hit.position, hit.normal, ore.kind, false)
	elif running and not hit.is_empty():
		var pos: Vector3 = hit.position
		var normal: Vector3 = hit.normal
		var layer := terrain.layer_at(pos - normal * 0.2)
		var col := Strata.DEBRIS_COLORS[layer]
		var lname := _layer_key(layer)
		touching = true
		_heat_rate = Tuning.get_f("drill", "heat_rate_" + lname, 1.0)
		if Strata.can_dig(layer, tool):
			if _bite_timer <= 0.0:
				_bite_timer += 1.0 / maxf(Tuning.get_f("drill", "bites_per_s", 8.0), 1.0)
				_bite_timer = maxf(_bite_timer, 0.0)
				var dir := -camera.global_basis.z
				var r := Tuning.get_f("drill", "bite_radius", 0.8)
				var bite := Tuning.get_f("drill", "bite_depth_" + lname, 0.15)
				# De bol steekt precies `bite` voorbij het raakpunt, langs de kijkrichting.
				sync.submit_sphere(pos + dir * (bite - r), r, tool)
			_set_contact(true, false, pos, normal, col)
		else:
			_set_contact(true, true, pos, normal, col)
	if not touching:
		_set_contact(false, false, Vector3.ZERO, Vector3.UP, Color.BLACK)

	# Hitte.
	if running:
		heat += delta * _heat_rate
		if heat >= heat_max:
			overheated = true
			_lockout = Tuning.get_f("drill", "lockout_s", 4.0)
			fx.play("clink", global_position, -10.0)
			overheated_changed.emit(true)
	else:
		heat = maxf(0.0, heat - delta * Tuning.get_f("drill", "cool_rate", 2.0))
	if overheated:
		_lockout -= delta
		if _lockout <= 0.0:
			overheated = false
			heat = minf(heat, heat_max * 0.5)
			overheated_changed.emit(false)


static func _layer_key(layer: Strata.Layer) -> String:
	return ["kristal", "graniet", "zandsteen", "klei"][layer]


func _process(delta: float) -> void:
	# Bit draait, behuizing trilt, geluid volgt toerental en belasting.
	_bit.rotate_object_local(Vector3.FORWARD, delta * spin * 55.0)
	_equip = minf(1.0, _equip + delta / maxf(Tuning.get_f("pickaxe", "equip_s", 0.28), 0.01))
	_hang = move_toward(_hang, 1.0 if overheated else 0.0, delta * (3.0 if overheated else 1.5))
	# Bij contact schuift de boor naar voren, de wand in (en terug bij loslaten).
	_push = move_toward(_push, 1.0 if contact and running else 0.0, delta * (6.0 if contact else 3.0))
	var jitter := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * 0.004 * spin
	if contact:
		jitter *= 3.0
	var hot := clampf(heat / Tuning.get_f("drill", "heat_max", 5.5), 0.0, 1.0)
	var pos: Vector3 = (POSE[0] as Vector3).lerp(POSE_HANG[0], _ease(_hang))
	var rot: Vector3 = (POSE[1] as Vector3).lerp(POSE_HANG[1], _ease(_hang))
	pos += jitter + Vector3(0, 0, 0.02 * spin) + Vector3(-0.03, 0.02, -Tuning.get_f("drill", "push_m", 0.14)) * _ease(_push)
	var e := 1.0 - pow(1.0 - _equip, 3.0)
	position = (POSE_LOW[0] as Vector3).lerp(pos, e)
	rotation_degrees = (POSE_LOW[1] as Vector3).lerp(rot, e)
	# Gloed: van dof rood naar oranjegeel (kwadratisch, pas boven de helft echt zichtbaar).
	var glow := hot * hot * Tuning.get_f("drill", "glow_energy", 3.0)
	var glow_col := HEAT_COLOR.lerp(Color(1.0, 0.7, 0.3), hot * hot)
	for m in _glow_mats:
		m.set_shader_parameter("flash", glow)
		m.set_shader_parameter("flash_color", glow_col)
	# Stoom zolang hij oververhit is (en nog even na).
	_steam.emitting = overheated or (hot > 0.85 and not running)
	if _steam.emitting:
		# Het bit staat in beeld met een eigen gezichtsveld (68°): de stoom komt in de wereld op de plek
		# waar het bit er uitziet, een meter voor je, niet vlak voor de camera (anders een wolk).
		_steam.global_position = camera.global_transform * (STEAM_AT + Vector3(0.0, -0.08, 0.0) * _hang)
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


static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _aim_hit() -> Dictionary:
	var from := camera.global_position
	return terrain.tool_raycast(from, from - camera.global_basis.z * Tuning.get_f("drill", "reach", 2.8))


func _update_aim(hit: Dictionary) -> void:
	var new_aim := Pickaxe.Aim.NONE
	if not hit.is_empty() and (hit.collider is Crust or hit.collider is Rubble):
		new_aim = Pickaxe.Aim.CRUST
	elif not hit.is_empty() and hit.collider is OreCluster:
		new_aim = Pickaxe.Aim.ORE
	elif not hit.is_empty():
		var layer := terrain.layer_at(hit.position - hit.normal * 0.2)
		new_aim = Pickaxe.Aim.DIGGABLE if Strata.can_dig(layer, tool) else Pickaxe.Aim.TOO_HARD
	if new_aim != aim:
		aim = new_aim
		aim_changed.emit(aim)


func hint_too_hard() -> String:
	if tool < Strata.Tool.BOOR_T2:
		return "Too hard for the T1 drill: a T2 drill digs this (tool rack, aboard)"
	return "Too hard for this drill: find a way around it"


## Het niveau volgt de upgrades van de ploeg (ook als ze gekocht worden terwijl je hem vasthoudt).
func _update_tier() -> void:
	var p := body as Player
	var want := Upgrades.drill_tier(p.game.company) if p and p.game and p.game.company else Strata.Tool.BOOR_T1
	if want != tool:
		tool = want
		# Golf 3: T2 zie je (andere kleur, carbidepunt, band en label).
		DrillModel.set_tier(_model, tool >= Strata.Tool.BOOR_T2)


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
		fx.tint_stream(_dust, col.lightened(0.2))
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
