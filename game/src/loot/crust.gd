class_name Crust
extends StaticBody3D
## Korst rond een vondst. Zelf geen terrein: een schil met eigen collider (laag CRUST),
## zodat gereedschap hem apart kan raken. De host houdt de levens bij (FindField).
##
## In beeld (binnen-04): een gebroken rotsknol met facetten in een eigen kleur per laag (een bleke
## knol in de klei, een roestige ijzersteen in het zandsteen, ...), met een hint van wat erin zit
## (ivoren plekken voor botten, goudschilfers voor metaal, paarse punten voor kristal). Lange
## vondsten steken met hun uiteinden uit de knol. Per slag brokkelt hij af: hij krimpt, de barsten
## groeien en de hint komt meer bloot.

const SHADER := preload("res://src/loot/crust.gdshader")
## Kleur van de knol per laag (Strata.Layer: KRISTAL, GRANIET, ZANDSTEEN, KLEI).
const LAYER_TINTS: Array[Color] = [
	Color(0.5, 0.56, 0.7),   # kristal: bleek blauwgrijs
	Color(0.36, 0.33, 0.31), # graniet: donker, gespikkeld
	Color(0.5, 0.31, 0.19),  # zandsteen: roestige ijzersteen
	Color(0.8, 0.69, 0.52),  # klei: bleke kalkknol
]
## Hint per familie (FindKinds.Family: SKELETON, RELIC, METAL, JUNK, CRYSTAL): kleur, glans.
const HINTS := [
	[Color(0.93, 0.88, 0.74), 0.0],
	[Color(0.78, 0.58, 0.28), 0.6],
	[Color(1.0, 0.8, 0.32), 1.0],
	[Color(0.35, 0.6, 0.4), 0.3],
	[Color(0.66, 0.42, 0.95), 0.9],
]

var find_id := -1
var hp := 4.0
var max_hp := 4.0
## Kleur van de knol (voor stof en brokjes bij een slag).
var tint := Color(0.72, 0.64, 0.5)

var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _radii := Vector3.ONE


## `half_extents`: halve afmetingen van de vondst. `layer` en `family` bepalen kleur en hint.
func setup(id: int, half_extents: Vector3, max_hp_value: float, seed_value: float,
		layer := Strata.Layer.KLEI, family := FindKinds.Family.JUNK) -> void:
	find_id = id
	max_hp = max_hp_value
	hp = max_hp
	collision_layer = Layers.CRUST
	collision_mask = 0
	tint = LAYER_TINTS[layer]
	var radii := (half_extents + Vector3.ONE * 0.12).max(Vector3.ONE * 0.18)
	# Lange vondsten (botten, de fles): de uiteinden steken uit de knol, als hint.
	var longest := half_extents.max_axis_index()
	var aspect := half_extents[longest] / maxf(0.01, (half_extents[(longest + 1) % 3] + half_extents[(longest + 2) % 3]) * 0.5)
	if aspect > 1.7:
		radii[longest] = half_extents[longest] * Tuning.get_f("finds", "crust_tip_out", 0.8)
	_radii = radii
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	_mesh = MeshInstance3D.new()
	# 158 vondsten op de planeet: enkel tekenen in de buurt (in de rots zie je ze toch niet).
	_mesh.visibility_range_end = Tuning.get_f("finds", "draw_distance", 70.0)
	_mesh.mesh = sphere
	_mesh.scale = radii
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", seed_value)
	_mat.set_shader_parameter("base_color", tint)
	var hint: Array = HINTS[family]
	_mat.set_shader_parameter("hint_color", hint[0])
	_mat.set_shader_parameter("hint_glint", hint[1])
	_mat.set_shader_parameter("speckle", 1.0 if layer == Strata.Layer.GRANIET else 0.4)
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
	var dmg := 1.0 - clampf(hp / max_hp, 0.0, 1.0)
	_mat.set_shader_parameter("damage", dmg)
	# Afbrokkelen: de knol krimpt naar de vondst toe.
	_mesh.scale = _radii * (1.0 - Tuning.get_f("finds", "crust_shrink", 0.2) * dmg)
	if hit:
		_mat.set_shader_parameter("glint", 1.0)
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("glint", v), 1.0, 0.0, 0.25)


func shatter() -> void:
	collision_layer = 0
	visible = false
	queue_free()
