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
## Host: laatste plek buiten de rots, en hoe lang hij al in de rots zit (vangnet).
var last_safe := Vector3.ZERO
var stuck_time := 0.0

# Clients: posities van de host, geïnterpoleerd (100 ms achter).
var _snapshots: Array = [] # [ontvangsttijd ms, Transform3D]
var _mesh: MeshInstance3D


func setup(id: int, kind_value: FindKinds.Kind) -> void:
	find_id = id
	kind = kind_value
	name = "Find%d" % id
	base_value = FindKinds.BASE_VALUES[kind]
	mass = FindKinds.MASSES[kind]
	collision_layer = Layers.LOOT
	collision_mask = Layers.TERRAIN | Layers.LOOT | Layers.PLAYERS | Layers.LIFT
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var mesh := FindKinds.mesh(kind)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	var mats := FindKinds.materials(kind)
	for i in mats.size():
		_mesh.set_surface_override_material(i, mats[i])
	add_child(_mesh)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape(true, true)
	add_child(cs)
	half_extents = mesh.get_aabb().size * 0.5


## Hoogte van de oorsprong boven de grond als hij rechtop ligt (onderkant van het model).
func rest_height() -> float:
	return -_mesh.mesh.get_aabb().position.y


func display_name() -> String:
	return FindKinds.NAMES[kind]


func value() -> int:
	return int(round(base_value * condition))


## Korte gloed bij het vrijkomen (de "ding"-beloning, docs/research/graven.md).
## Kostbare vondsten gloeien goud en langer.
func celebrate() -> void:
	var precious := base_value >= FindKinds.PRECIOUS
	var peak := 2.2 if precious else 1.0
	var tw := create_tween()
	tw.tween_method(_set_flash, 0.0, peak, 0.08)
	tw.tween_method(_set_flash, peak, 0.0, 1.6 if precious else 0.9)


func _set_flash(v: float) -> void:
	for i in _mesh.mesh.get_surface_count():
		var m := _mesh.get_surface_override_material(i)
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("flash", v)
			(m as ShaderMaterial).set_shader_parameter("flash_color", Color(1.0, 0.78, 0.3) if base_value >= FindKinds.PRECIOUS else Color(1.0, 0.9, 0.7))
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
		var mol: Mol = get_parent().game.mol
		return mol.body.global_transform * (s[1] as Transform3D)
	return s[1]
