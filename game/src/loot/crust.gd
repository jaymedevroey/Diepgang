class_name Crust
extends StaticBody3D
## Korst rond een vondst. Zelf geen terrein: een schil met eigen collider (laag CRUST),
## zodat gereedschap hem apart kan raken. De host houdt de levens bij (FindField).
##
## In beeld (binnen-04, golf 3): een concretie zoals je ze echt vindt, per laag en per planeet een eigen
## gesteente dat afsteekt tegen de wand (PALETTE: op Roestbol een donkere ijzersteen met bleke
## kalkaders, op de Fossielwereld een zwarte vuursteenknol met een witte schors, op de Kristalmaan
## obsidiaan met roze aders), gehakt (een icosaëder met verschoven hoekpunten, platte vlakken). Een
## hint van wat erin zit: vlekken in de kleur van de familie (ivoor, goud, paars kristal), en een paar
## breuken in de schil waardoor je de vondst zelf ziet. Lange vondsten steken met hun uiteinden uit
## de knol. Per slag brokkelt hij af: hij krimpt, de barsten en de breuken groeien.

const SHADER := preload("res://src/loot/crust.gdshader")
## Gesteente van de knol per planeet (PlanetType.Id) en laag (Strata.Layer: KRISTAL, GRANIET, ZANDSTEEN,
## KLEI): [kleur, aders]. Donker op de lichte wand, en de aders licht: zo leest hij als "iets anders".
const PALETTE := [
	[[Color(0.3, 0.34, 0.46), Color(0.6, 0.9, 1.0)], [Color(0.22, 0.22, 0.24), Color(0.86, 0.85, 0.8)],
		[Color(0.4, 0.21, 0.12), Color(0.86, 0.66, 0.32)], [Color(0.2, 0.14, 0.13), Color(0.84, 0.8, 0.68)]],
	[[Color(0.3, 0.34, 0.46), Color(0.6, 0.95, 0.85)], [Color(0.24, 0.25, 0.24), Color(0.85, 0.86, 0.8)],
		[Color(0.38, 0.3, 0.18), Color(0.9, 0.85, 0.7)], [Color(0.16, 0.17, 0.2), Color(0.93, 0.91, 0.85)]],
	[[Color(0.26, 0.22, 0.4), Color(0.8, 0.6, 1.0)], [Color(0.18, 0.18, 0.22), Color(0.75, 0.62, 0.95)],
		[Color(0.34, 0.2, 0.28), Color(0.9, 0.75, 0.85)], [Color(0.16, 0.11, 0.2), Color(0.95, 0.5, 0.85)]],
]
const VARIANTS := 4
static var _meshes := {}
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
		layer := Strata.Layer.KLEI, family := FindKinds.Family.JUNK, planet := 0) -> void:
	find_id = id
	max_hp = max_hp_value
	hp = max_hp
	collision_layer = Layers.CRUST
	collision_mask = 0
	var pal: Array = PALETTE[clampi(planet, 0, 2)][layer]
	# De kleur van stof en brokjes bij een slag: tussen het gesteente en de aders.
	tint = (pal[0] as Color).lerp(pal[1], 0.35)
	var radii := (half_extents + Vector3.ONE * 0.12).max(Vector3.ONE * 0.18)
	# Lange vondsten (botten, de fles): de uiteinden steken uit de knol, als hint.
	var longest := half_extents.max_axis_index()
	var aspect := half_extents[longest] / maxf(0.01, (half_extents[(longest + 1) % 3] + half_extents[(longest + 2) % 3]) * 0.5)
	if aspect > 1.7:
		radii[longest] = half_extents[longest] * Tuning.get_f("finds", "crust_tip_out", 0.8)
	_radii = radii
	_mesh = MeshInstance3D.new()
	# 158 vondsten op de planeet: enkel tekenen in de buurt (in de rots zie je ze toch niet).
	_mesh.visibility_range_end = Tuning.get_f("finds", "draw_distance", 70.0)
	_mesh.mesh = _knol(id % VARIANTS)
	_mesh.scale = radii
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("seed", seed_value)
	_mat.set_shader_parameter("base_color", pal[0])
	_mat.set_shader_parameter("vein_color", pal[1])
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


## Een gehakte knol: een icosaëder, twee keer verdeeld, de hoekpunten wat verschoven (de shader
## kantelt de vlakken verder). Eenheidsbol, een paar varianten.
static func _knol(variant: int) -> ArrayMesh:
	if _meshes.has(variant):
		return _meshes[variant]
	var faces := OreKinds._ico_faces(2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		for v: Vector3 in [f[0], f[2], f[1]]: # Godot: met de klok mee is de voorkant
			var k := 0.9 + 0.2 * fposmod(sin(v.dot(Vector3(4.1, 7.3, 5.9)) * 2.3 + variant * 1.7) * 43758.5453, 1.0)
			st.set_normal(v)
			st.add_vertex(v * k)
	st.index()
	var m := st.commit()
	_meshes[variant] = m
	return m


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
