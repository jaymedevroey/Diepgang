class_name FindItem
extends RigidBody3D
## Een vondst (buit). Zit eerst vast in de rots (bevroren) binnen een korst; na het breken
## van de korst simuleert de host hem (Jolt), clients volgen de host (GDD §9).

var find_id := -1
var kind: FossilModel.Kind
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


func setup(id: int, kind_value: FossilModel.Kind) -> void:
	find_id = id
	kind = kind_value
	name = "Find%d" % id
	base_value = FossilModel.BASE_VALUES[kind]
	mass = FossilModel.MASSES[kind]
	collision_layer = Layers.LOOT
	collision_mask = Layers.TERRAIN | Layers.LOOT | Layers.PLAYERS
	continuous_cd = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var mesh := FossilModel.build_mesh(kind)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.material_override = FossilModel.bone_material().duplicate()
	add_child(_mesh)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape(true, true)
	add_child(cs)
	half_extents = mesh.get_aabb().size * 0.5


func display_name() -> String:
	return FossilModel.NAMES[kind]


func value() -> int:
	return int(round(base_value * condition))


## Korte gloed bij het vrijkomen (de "ding"-beloning, docs/research/graven.md).
func celebrate() -> void:
	var mat := _mesh.material_override as StandardMaterial3D
	var tw := create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 1.2, 0.08)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.9)


## Client: toestand van de host binnen.
func push_snapshot(xf: Transform3D) -> void:
	_snapshots.append([float(Time.get_ticks_msec()), xf])
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
	global_transform = (a[1] as Transform3D).interpolate_with(b[1], k)
