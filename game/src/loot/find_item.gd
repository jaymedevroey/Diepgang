class_name FindItem
extends RigidBody3D
## Een vondst (buit). Zit eerst vast in de rots (bevroren) binnen een korst; na het breken
## van de korst simuleert de host hem (Jolt), clients volgen de host (GDD §9).

var find_id := -1
var kind: FindKinds.Kind
var base_value := 0
## 1 = gaaf. Boren door de korst verlaagt dit (GDD §3).
var condition := 1.0
var freed := false
var half_extents := Vector3.ONE * 0.1
## Peers die deze vondst dragen (0, 1 of 2). De host beslist.
var carriers := PackedInt32Array()
## Wie hem het laatst droeg (of gooide): die grimast als hij breekt.
var last_carriers := PackedInt32Array()
## Host: laatste plek buiten de rots, en hoe lang hij al in de rots zit (vangnet).
var last_safe := Vector3.ZERO
var stuck_time := 0.0

## Botsvorm per soort, gedeeld: een convexe vorm maken (met vereenvoudigen) kost ±45 ms, en een
## nieuwe wereld heeft ±160 vondsten (dat bevroor het spel 8–12 s na het kiezen van een opdracht).
static var _shapes := {}
const GLINT_SHADER := preload("res://src/loot/find_glint.gdshader")

## FindKinds.ValueClass: bepaalt glans, fonkels en het moment bij het vrijkomen.
var value_class := 0

# Clients: posities van de host, geïnterpoleerd (100 ms achter).
var _snapshots: Array = [] # [ontvangsttijd ms, Transform3D]
var _mesh: MeshInstance3D
var _glint: ShaderMaterial


func setup(id: int, kind_value: FindKinds.Kind) -> void:
	find_id = id
	kind = kind_value
	name = "Find%d" % id
	base_value = FindKinds.BASE_VALUES[kind]
	mass = FindKinds.MASSES[kind]
	# In de korst botst hij nergens mee (de korst heeft een eigen vorm): een bot dat uit de knol
	# steekt, houdt geen straal tegen en verraadt niets aan het vizier. Los: laag LOOT (set_freed).
	collision_layer = 0
	collision_mask = Layers.TERRAIN | Layers.LOOT | Layers.PLAYERS | Layers.LIFT
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var mesh := FindKinds.mesh(kind)
	_mesh = MeshInstance3D.new()
	# 158 vondsten op de planeet: enkel tekenen in de buurt (in de rots zie je ze toch niet).
	_mesh.visibility_range_end = Tuning.get_f("finds", "draw_distance", 70.0)
	_mesh.mesh = mesh
	var mats := FindKinds.materials(kind)
	for i in mats.size():
		_mesh.set_surface_override_material(i, mats[i])
	add_child(_mesh)
	# Glans van de waardeklasse over het hele model (randlicht, fonkels, de gloed bij het vrijkomen).
	value_class = FindKinds.value_class(base_value)
	_glint = ShaderMaterial.new()
	_glint.shader = GLINT_SHADER
	_glint.set_shader_parameter("glint_color", FindKinds.CLASS_GLINT[value_class])
	_glint.set_shader_parameter("rim", FindKinds.CLASS_RIM[value_class] * 0.4)
	_glint.set_shader_parameter("sparkle", 0.0)
	_glint.set_shader_parameter("seed", float(id) * 1.37)
	_mesh.material_overlay = _glint
	var cs := CollisionShape3D.new()
	if not _shapes.has(kind):
		_shapes[kind] = mesh.create_convex_shape(true, true)
	cs.shape = _shapes[kind]
	add_child(cs)
	half_extents = mesh.get_aabb().size * 0.5


## Tekenen tussen twee physics-ticks in: bij de host (Jolt simuleert per tick), en bij wie hem zelf
## draagt (Carry zet hem per tick). Bij een client die hem enkel volgt, beweegt hij in _process.
func _enter_tree() -> void:
	update_interpolation()


## Bij het afsluiten (headless) klaagde de dummy-renderer over een overlay die al weg was.
func _exit_tree() -> void:
	if _mesh:
		_mesh.material_overlay = null


func update_interpolation() -> void:
	var ticked := multiplayer.is_server() or carriers.has(multiplayer.get_unique_id())
	var mode := PHYSICS_INTERPOLATION_MODE_ON if ticked else PHYSICS_INTERPOLATION_MODE_OFF
	if mode != physics_interpolation_mode:
		physics_interpolation_mode = mode
		reset_physics_interpolation()


## Hoogte van de oorsprong boven de grond als hij rechtop ligt (onderkant van het model).
func rest_height() -> float:
	return -_mesh.mesh.get_aabb().position.y


func display_name() -> String:
	return FindKinds.NAMES[kind]


func value() -> int:
	return int(round(base_value * condition))


## Vrij: botst weer (laag LOOT) en de glans van zijn waardeklasse gaat volledig aan.
func set_freed() -> void:
	freed = true
	collision_layer = Layers.LOOT
	_glint.set_shader_parameter("rim", FindKinds.CLASS_RIM[value_class])
	_glint.set_shader_parameter("sparkle", FindKinds.CLASS_SPARKLE[value_class])


## In je eigen handen: belicht zoals je handen (het vullicht van het gereedschap, niet de helmlamp:
## op 0,8 m werd een bot een witte vlek), en minder randlicht.
func set_held(on: bool) -> void:
	if freed:
		_glint.set_shader_parameter("rim", FindKinds.CLASS_RIM[value_class] * (0.25 if on else 1.0))
	_mesh.layers = PickaxeModel.VIEWMODEL_LAYER if on else 1


## Gloed bij het vrijkomen (de "ding"-beloning, docs/research/graven.md, gevoel-03): fel, en pas
## uitdoven als het stof weg is (±2-3 s). Waardevoller = feller en langer.
func celebrate() -> void:
	var k := FindKinds.CLASS_STRENGTH[value_class]
	var peak := 1.0 * k
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.0, peak, 0.06)
	tw.tween_interval(Tuning.get_f("finds", "reveal_hold_s", 0.6) * k)
	tw.tween_method(_set_flash, peak, 0.0, Tuning.get_f("finds", "reveal_fade_s", 1.8) * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _set_flash(v: float) -> void:
	_glint.set_shader_parameter("flash", v)
	var col := FindKinds.CLASS_GLINT[value_class]
	for i in _mesh.mesh.get_surface_count():
		var m := _mesh.get_surface_override_material(i)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("flash", v * 0.3)
			(m as ShaderMaterial).set_shader_parameter("flash_color", col)
		elif m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled and (m as StandardMaterial3D).albedo_color.a < 1.0:
			(m as StandardMaterial3D).emission_energy_multiplier = v


## Client: toestand van de host binnen. `in_mol`: transform is relatief tot de Mol.
func push_snapshot(xf: Transform3D, in_mol := false) -> void:
	_snapshots.append([float(Time.get_ticks_msec()), xf, in_mol])
	if _snapshots.size() > 20:
		_snapshots.pop_front()


func _process(_delta: float) -> void:
	if not freed or multiplayer.is_server() or _snapshots.is_empty():
		return
	if carriers.has(multiplayer.get_unique_id()):
		return # zelf drager: Carry zet de positie (voorspelling)
	var render_t := float(Time.get_ticks_msec()) - 100.0
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	global_transform = _snap_world(a).interpolate_with(_snap_world(b), k)


func _snap_world(s: Array) -> Transform3D:
	if s.size() > 2 and s[2]:
		# T.o.v. de Mol zoals hij getekend wordt (geïnterpoleerd), anders schuift de vondst in het
		# laadruim heen en weer terwijl de Mol rijdt.
		var mol: Mol = get_parent().game.mol
		return mol.body.get_global_transform_interpolated() * (s[1] as Transform3D)
	return s[1]
