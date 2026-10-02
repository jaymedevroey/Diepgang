class_name Crust
extends StaticBody3D
## Korst rond een vondst. Zelf geen terrein: een schil met eigen collider (laag CRUST),
## zodat gereedschap hem apart kan raken. De host houdt de levens bij (FindField).

const SHADER := preload("res://src/loot/crust.gdshader")

var find_id := -1
var hp := 4.0
var max_hp := 4.0

var _mat: ShaderMaterial
var _mesh: MeshInstance3D


## `half_extents`: halve afmetingen van de vondst. De korst is een knobbelige ellipsoïde erom.
func setup(id: int, half_extents: Vector3, max_hp_value: float, seed_value: float) -> void:
	find_id = id
	max_hp = max_hp_value
	hp = max_hp
	collision_layer = Layers.CRUST
	collision_mask = 0
	var radii := (half_extents + Vector3.ONE * 0.12).max(Vector3.ONE * 0.18)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 28
	sphere.rings = 14
	_mesh = MeshInstance3D.new()
	# 158 vondsten op de planeet: enkel tekenen in de buurt (in de rots zie je ze toch niet).
	_mesh.visibility_range_end = Tuning.get_f("finds", "draw_distance", 70.0)
	_mesh.mesh = sphere
	_mesh.scale = radii
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", seed_value)
	_mesh.material_override = _mat
	add_child(_mesh)
	# Collider: lage-poly ellipsoïde als convexe vorm.
	var low := SphereMesh.new()
	low.radius = 1.0
	low.height = 2.0
	low.radial_segments = 10
	low.rings = 5
	var pts := PackedVector3Array()
	for v in low.get_mesh_arrays()[Mesh.ARRAY_VERTEX]:
		pts.append(v * radii)
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)


func set_hp(value: float) -> void:
	var hit := value < hp
	hp = value
	_mat.set_shader_parameter("damage", 1.0 - clampf(hp / max_hp, 0.0, 1.0))
	if hit:
		_mat.set_shader_parameter("glint", 1.0)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("glint", v), 1.0, 0.0, 0.25)


func shatter() -> void:
	collision_layer = 0
	visible = false
	queue_free()
