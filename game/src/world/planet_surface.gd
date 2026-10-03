class_name PlanetSurface
extends Node3D
## Wat aan de oppervlakte rond het speelgebied hoort (GDD v3 §4):
## - Verre landschap: een ring tot ±475 m van het midden met dezelfde hoogtefunctie als het
##   voxelterrein, zodat de vlakte voorbij de rand doorloopt, met heuvels en mesa's die naar de
##   horizon toe groeien. Niet te graven, geen collision.
## - De concessiegrens van DIG: paaltjes met knipperlichten om de 16 m, en onzichtbare muren
##   zodat niemand het speelgebied uit loopt.
## - Het speelgebied zelf als grof raster, getekend waar het voxelterrein niet geladen is: verder
##   dan de laadafstand van de camera (van hoog in de lucht: alles). Dichterbij valt het weg in de
##   shader, zodat het nooit gaten of tunnels afsluit.

const RING := 360.0 # meter voorbij de rand van het speelgebied
const STEPS_INSIDE := 32 # rasterlijnen over de breedte van het speelgebied (de rand valt op een lijn)
const AREA_STEPS := 96 # raster van het speelgebied zelf (van ver)

var terrain: TerrainAPI
var _hills := FastNoiseLite.new()
var _area: MeshInstance3D


func build(t: TerrainAPI, planet_seed: int) -> void:
	terrain = t
	_hills.seed = planet_seed + 91
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.004
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_hills.fractal_octaves = 3
	_build_ring()
	_build_area()
	_build_boundary()



## Raster van het speelgebied (gegenereerd oppervlak, zonder gaten), een halve meter lager dan
## het echte oppervlak: waar het voxelterrein geladen is, ligt dat erover.
func _build_area() -> void:
	var size := terrain.world_size()
	var n := AREA_STEPS + 1
	var step := size.x / AREA_STEPS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := PackedFloat32Array()
	h.resize(n * n)
	for j in n:
		for i in n:
			h[j * n + i] = terrain.surface_height_at(i * step, j * step) - 0.5
	for j in n - 1:
		for i in n - 1:
			var a := Vector3(i * step, h[j * n + i], j * step)
			var b := Vector3((i + 1) * step, h[j * n + i + 1], j * step)
			var c := Vector3((i + 1) * step, h[(j + 1) * n + i + 1], (j + 1) * step)
			var d := Vector3(i * step, h[(j + 1) * n + i], (j + 1) * step)
			for v in [a, b, c, a, c, d]:
				st.add_vertex(v)
	st.generate_normals()
	_area = MeshInstance3D.new()
	_area.name = "AreaFromAbove"
	_area.mesh = st.commit()
	var area_mat := terrain.terrain_material().duplicate() as ShaderMaterial
	area_mat.set_shader_parameter("near_cutoff", Tuning.get_f("terrain", "view_m", 110.0) - 20.0)
	_area.material_override = area_mat
	_area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_area)


## Hoogte van het verre landschap: het oppervlak van de planeet plus heuvels die groeien met de
## afstand tot het speelgebied (aan de rand zelf exact het voxeloppervlak).
func far_height(x: float, z: float) -> float:
	var size := terrain.world_size()
	var dx := maxf(maxf(-x, x - size.x), 0.0)
	var dz := maxf(maxf(-z, z - size.z), 0.0)
	var out := Vector2(dx, dz).length()
	var grow := smoothstep(6.0, 160.0, out)
	return terrain.surface_height_at(x, z) + grow * (8.0 + 46.0 * (_hills.get_noise_2d(x, z) * 0.5 + 0.5))


func _build_ring() -> void:
	var size := terrain.world_size()
	var step := size.x / STEPS_INSIDE
	var k0 := -int(ceil(RING / step))
	var k1 := STEPS_INSIDE + int(ceil(RING / step))
	var n := k1 - k0 + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = far_height((k0 + i) * step, (k0 + j) * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n - 1:
		for i in n - 1:
			var ki := k0 + i
			var kj := k0 + j
			# Cellen binnen het speelgebied laat het voxelterrein over.
			if ki >= 0 and ki < STEPS_INSIDE and kj >= 0 and kj < STEPS_INSIDE:
				continue
			var a := Vector3(ki * step, heights[j * n + i], kj * step)
			var b := Vector3((ki + 1) * step, heights[j * n + i + 1], kj * step)
			var c := Vector3((ki + 1) * step, heights[(j + 1) * n + i + 1], (kj + 1) * step)
			var d := Vector3(ki * step, heights[(j + 1) * n + i], (kj + 1) * step)
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(d)
	# Rok langs de rand: hangt 30 m naar beneden, zodat er tussen ring en voxels geen kier is.
	for side in 4:
		for k in STEPS_INSIDE:
			var p0: Vector3
			var p1: Vector3
			match side:
				0:
					p0 = Vector3(k * step, 0, 0)
					p1 = Vector3((k + 1) * step, 0, 0)
				1:
					p0 = Vector3(size.x, 0, k * step)
					p1 = Vector3(size.x, 0, (k + 1) * step)
				2:
					p0 = Vector3((k + 1) * step, 0, size.z)
					p1 = Vector3(k * step, 0, size.z)
				_:
					p0 = Vector3(0, 0, (k + 1) * step)
					p1 = Vector3(0, 0, k * step)
			p0.y = far_height(p0.x, p0.z)
			p1.y = far_height(p1.x, p1.z)
			var q0 := p0 - Vector3(0, 30, 0)
			var q1 := p1 - Vector3(0, 30, 0)
			st.add_vertex(p0)
			st.add_vertex(q1)
			st.add_vertex(p1)
			st.add_vertex(p0)
			st.add_vertex(q0)
			st.add_vertex(q1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "FarTerrain"
	mi.mesh = st.commit()
	mi.material_override = terrain.terrain_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_boundary() -> void:
	var size := terrain.world_size()
	var posts: Array[Vector3] = []
	var spacing := 16.0
	for side in 4:
		var length := size.x if side % 2 == 0 else size.z
		var count := int(length / spacing)
		for k in count + 1:
			var s := k * length / count
			var p: Vector3
			match side:
				0:
					p = Vector3(s, 0, 1.0)
				1:
					p = Vector3(size.x - 1.0, 0, s)
				2:
					p = Vector3(s, 0, size.z - 1.0)
				_:
					p = Vector3(1.0, 0, s)
			p.y = terrain.surface_height_at(p.x, p.z)
			posts.append(p)
	# Paaltjes (geel-zwart) en lampjes erop (knipperen in de shader).
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 2.4, 0.16)
	var post_mat := MolVisual.machine_material("Hazard", false, 4.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	mm.instance_count = posts.size()
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.12
	lamp_mesh.height = 0.2
	var lmm := MultiMesh.new()
	lmm.transform_format = MultiMesh.TRANSFORM_3D
	lmm.mesh = lamp_mesh
	lmm.instance_count = posts.size()
	for i in posts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), posts[i] + Vector3(0, 1.0, 0)))
		lmm.set_instance_transform(i, Transform3D(Basis(), posts[i] + Vector3(0, 2.3, 0)))
	var pm := MultiMeshInstance3D.new()
	pm.name = "BoundaryPosts"
	pm.multimesh = mm
	pm.material_override = post_mat
	add_child(pm)
	var lamp_mat := ShaderMaterial.new()
	lamp_mat.shader = preload("res://src/world/beacon.gdshader")
	var lm := MultiMeshInstance3D.new()
	lm.name = "BoundaryLamps"
	lm.multimesh = lmm
	lm.material_override = lamp_mat
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lm)
	# Onzichtbare muren boven de grond (onder de grond is er de onbreekbare buitenmuur).
	var top := size.y + 80.0
	var walls := StaticBody3D.new()
	walls.name = "BoundaryWalls"
	walls.collision_layer = Layers.BOUNDS
	walls.collision_mask = 0
	add_child(walls)
	for w in [[Vector3(size.x * 0.5, 0, -0.5), Vector3(size.x + 2, 0, 1)],
			[Vector3(size.x * 0.5, 0, size.z + 0.5), Vector3(size.x + 2, 0, 1)],
			[Vector3(-0.5, 0, size.z * 0.5), Vector3(1, 0, size.z + 2)],
			[Vector3(size.x + 0.5, 0, size.z * 0.5), Vector3(1, 0, size.z + 2)]]:
		var shape := BoxShape3D.new()
		var c: Vector3 = w[0]
		var e: Vector3 = w[1]
		var bottom := size.y - 60.0
		shape.size = Vector3(e.x, top - bottom, e.z)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(c.x, (top + bottom) * 0.5, c.z)
		walls.add_child(cs)
