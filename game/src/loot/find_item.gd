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
## Set (release-audit ontwerp-9): de stukken van één skelet hebben dezelfde set_id (uniek per wereld),
## set_size is het aantal stukken van dat skelet in de wereld. Leeg = geen set. Volgt uit de seed
## (FindField.generate), dus elke peer kent het. F1 rekent de setbonus uit bij de taxatie.
var set_id := ""
var set_size := 0
## Naam van het skelet ("Titan", "Sand strider"), voor schermen.
var set_name := ""
## Breekbaarheid (FindKinds.FRAGILITY): 0 = stevig. Breekbare vondsten gloeien vaak ook (GLOW).
var fragility := 0.0

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
var _light: OmniLight3D # lichtgevende vondsten (FindKinds.GLOW), aan zodra hij los is
var _drag_from := Vector3.INF # waar het laatste stofwolkje van het slepen kwam


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
	fragility = FindKinds.FRAGILITY[kind]
	if FindKinds.GLOW.has(kind):
		# Een klein lampje (geen schaduw, vervaagt op afstand): in het donker van de put zie je een
		# kristal liggen, en als het breekt, gaat het uit.
		_light = OmniLight3D.new()
		_light.light_color = FindKinds.GLOW[kind]
		_light.light_energy = Tuning.get_f("finds", "glow_energy", 0.9)
		_light.omni_range = Tuning.get_f("finds", "glow_range", 2.6)
		_light.omni_attenuation = 1.4
		_light.shadow_enabled = false
		_light.distance_fade_enabled = true
		_light.distance_fade_begin = 28.0
		_light.distance_fade_length = 8.0
		_light.visible = false
		add_child(_light)


## Het skelet waar dit stuk bij hoort, voor schermen: "Titan skeleton · 6 pieces" (leeg zonder set).
func set_label() -> String:
	if set_id == "":
		return ""
	return "%s skeleton · %d pieces" % [set_name, set_size]


## Gebroken (een breekbare vondst na een harde klap): bijna niets meer waard, het licht is uit.
func is_shattered() -> bool:
	return fragility > 0.0 and condition <= Tuning.get_f("finds", "shatter_condition", 0.08) + 0.001


## De gloed volgt de gaafheid; gebroken is ze uit en het kristal dof (op elk peer, na elke wijziging).
func update_glow() -> void:
	if _light:
		_light.visible = freed and not is_shattered()
		_light.light_energy = Tuning.get_f("finds", "glow_energy", 0.9) * clampf(condition, 0.3, 1.0)
	for i in _mesh.get_surface_override_material_count():
		var m := _mesh.get_surface_override_material(i)
		if m is StandardMaterial3D and m.has_meta("glow"):
			var sm := m as StandardMaterial3D
			sm.emission_energy_multiplier = 0.12 if is_shattered() else 1.6 * clampf(condition, 0.4, 1.0)
			sm.albedo_color.a = 1.0
			sm.roughness = 0.6 if is_shattered() else 0.08


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
	update_glow()


## Wordt hij nu gesleept (één drager, te zwaar om te tillen)? Op elk peer gelijk (dragers en massa).
func dragged() -> bool:
	return carriers.size() == 1 and not FindKinds.liftable_alone(mass)


## Laagste punt van het model onder de oorsprong, in deze draaiing (om hem op de grond te leggen).
func bottom_offset(b: Basis) -> float:
	var aabb := _mesh.mesh.get_aabb()
	var low := INF
	for i in 8:
		low = minf(low, (b * aabb.get_endpoint(i)).y)
	return -low


## In je eigen handen: belicht zoals je handen (het vullicht van het gereedschap, niet de helmlamp:
## op 0,8 m werd een bot een witte vlek), en minder randlicht.
## Te zware stukken (slepen, met twee dragen) blijven in de wereld belicht: ze hangen 1,5 m of verder
## voor je, daar brandt de helmlamp niets uit, en als gereedschap belicht waren ze een donkere vlek.
func set_held(on: bool) -> void:
	if freed:
		_glint.set_shader_parameter("rim", FindKinds.CLASS_RIM[value_class] * (0.25 if on else 1.0))
	_mesh.layers = PickaxeModel.VIEWMODEL_LAYER if on and FindKinds.liftable_alone(mass) else 1


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
	if freed and carriers.size() == 1:
		_drag_dust()
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


## Slepen (te zwaar om alleen te tillen): om de halve meter een stofwolkje en gruis waar hij over de
## grond schuurt, bij iedereen die het ziet (ook het geluid komt later hier, M6).
func _drag_dust() -> void:
	if not dragged():
		_drag_from = Vector3.INF
		return
	var p := global_position
	if _drag_from == Vector3.INF or p.distance_to(_drag_from) > 3.0:
		_drag_from = p
		return
	if p.distance_to(_drag_from) < 0.5:
		return
	_drag_from = p
	var game: Node = get_parent().game
	if game == null or game.terrain == null:
		return
	var floor_p := p - Vector3(0, bottom_offset(global_basis) - 0.04, 0)
	game.fx.grit_puff(floor_p, Vector3.UP, Strata.DEBRIS_COLORS[game.terrain.layer_at(floor_p)])


func _snap_world(s: Array) -> Transform3D:
	if s.size() > 2 and s[2]:
		# T.o.v. de Mol zoals hij getekend wordt (geïnterpoleerd), anders schuift de vondst in het
		# laadruim heen en weer terwijl de Mol rijdt.
		var mol: Mol = get_parent().game.mol
		return mol.body.get_global_transform_interpolated() * (s[1] as Transform3D)
	return s[1]
