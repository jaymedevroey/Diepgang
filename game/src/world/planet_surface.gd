class_name PlanetSurface
extends Node3D
## Wat aan de oppervlakte rond het speelgebied hoort (GDD v3 §4, docs/research/hemel.md §4):
## - Verre landschap tot voorbij de horizon (sky.cfg horizon_m, ±6,5 km), in één mesh: een fijne
##   ring tot 360 m voorbij de rand (cellen van 7,8 m, heuvels en kraters die doorlopen) en
##   daarbuiten een grove schijf met grote kraters, ruggen en mesa's. Alles buigt weg met de
##   kromming van de planeet (zakt o²/2R, o = afstand tot het speelgebied), net als de kim in de
##   hemel: van elke hoogte valt het landschap zelf achter de horizon, er is nergens een rand.
##   Zelfde rotsshader als het voxelterrein (altijd klei). Niet te graven, geen collision.
##   Van ver weg (de hub, 1,7 km hoog) verborgen: daar tekenen de hemel en het planeetdek de planeet.
## - De concessiegrens van DIG: paaltjes met knipperlichten om de 16 m (enkel van dichtbij
##   zichtbaar, van boven verraden ze het vierkant), en onzichtbare muren.
## - Het speelgebied zelf als grof raster, een halve meter onder het oppervlak, getekend waar het
##   voxelterrein niet geladen is. Dichterbij dan de laadafstand valt het weg in de shader.
##   De ring sluit er naadloos op aan (zelfde hoogte op de rand), met een rok die naar binnen kijkt
##   voor de kieren tussen de rechte randen en het voxelterrein.
## De meshes worden op een werkthread berekend (`built` zodra ze in de scène hangen). Alles hangt
## enkel af van de seed, dus elke peer ziet hetzelfde; de werkthread raakt de scène niet aan.

signal built

const RING := 360.0 # meter voorbij de rand van het speelgebied (fijne ring)
const STEPS_INSIDE := 32 # rasterlijnen over de breedte van het speelgebied (de rand valt op een lijn)
const AREA_STEPS := 96 # raster van het speelgebied zelf (van ver)
const APRON_FIRST := 9.0 # m: eerste stap van de grove schijf
const APRON_GROW := 1.085 # elke volgende ring zoveel breder (past bij het perspectief)
## Verder van de camera dan dit (de hub hangt 1,7 km hoog): verborgen. De drop komt niet hoger dan 360 m.
const FAR_HIDE_M := 1100.0
## Paaltjes: verder dan dit niet meer getekend (van boven verraden ze de rand van het vierkant).
const POST_HIDE_M := 170.0
const POST_CHUNKS := 4 # stukken per zijde (elk een eigen zichtafstand)
const POST_SPACING := 16.0
const SMALL_CRATER_CELL := 56.0
const BIG_CRATER_CELL := 520.0
const SKIRT := 30.0
## Landingsplek in de rotsshader: straal van de aangestampte kern en waar ze helemaal terrein is (m).
const LANDING_PAD := Vector2(11.0, 30.0)

var terrain: TerrainAPI
## Grote landvormen rond het speelgebied (krater, put, duinen), per planeettype.
var landform := Landform.new()
var is_built := false
var _seed := 0
var _size := Vector3.ZERO
var _surface_y := 0.0
var _radius := 30000.0
var _horizon := 6500.0
var _hills := FastNoiseLite.new()
var _relief := FastNoiseLite.new()
var _mesa := FastNoiseLite.new()
var _small: Dictionary = {} # Vector2i (cel) -> Vector4 (x, z, straal, diepte)
var _big: Dictionary = {}
var _task := -1
var _out: Dictionary = {} # door de werkthread gevuld: naam -> arrays
var _t0 := 0 # µs: start van build()
var _main_us := 0 # µs op de hoofdthread (build + in de scène hangen)
var _compute_us := 0 # µs op de werkthread


func build(t: TerrainAPI, planet_seed: int) -> void:
	_t0 = Time.get_ticks_usec()
	terrain = t
	_seed = planet_seed
	_size = t.world_size()
	var c := t.shaft_center_world()
	_surface_y = t.surface_height_at(c.x, c.z)
	_radius = Tuning.get_f("sky", "planet_radius_m", 30000.0)
	_horizon = Tuning.get_f("sky", "horizon_m", 6500.0)
	_hills.seed = planet_seed + 91
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.004
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_hills.fractal_octaves = 3
	_relief.seed = planet_seed + 92
	_relief.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_relief.frequency = 0.0007
	_relief.fractal_type = FastNoiseLite.FRACTAL_FBM
	_relief.fractal_octaves = 4
	_mesa.seed = planet_seed + 93
	_mesa.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mesa.frequency = 0.00035
	_mesa.fractal_type = FastNoiseLite.FRACTAL_FBM
	_mesa.fractal_octaves = 2
	# De landingsplek in de rotsshader: aangestampt in het midden, tot 30 m overgaand in het terrein
	# (de vlakke plek van de generator is 22 m breed, met 20 m overgang).
	t.terrain_material().set_shader_parameter("landing_pad", Vector4(c.x, c.z, LANDING_PAD.x, LANDING_PAD.y))
	landform.setup(planet_seed, Vector2(c.x, c.z), Vector2(_size.x, _size.z))
	_place_craters()
	_build_boundary()
	# Het zware werk (±50k hoogtes) op een werkthread; de scène enkel op de hoofdthread.
	_task = WorkerThreadPool.add_task(_compute, false, "PlanetSurface")
	_main_us = Time.get_ticks_usec() - _t0


## Nieuwe wereld: wacht tot de werkthread klaar is, zodat hij het oude terrein niet meer leest als
## dat vrijgegeven wordt (anders een crash bij snel na elkaar kiezen).
func abandon() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Wacht op de werkthread en hang de meshes in de scène (ook voor tests die er meteen op rekenen).
func finish() -> void:
	if _task < 0:
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_commit()


func _exit_tree() -> void:
	# Nooit vrijgeven terwijl de werkthread nog rekent (hij leest het terrein en deze node).
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Afstand (m) buiten het speelgebied (0 erbinnen).
func outside(x: float, z: float) -> float:
	var dx := maxf(maxf(-x, x - _size.x), 0.0)
	var dz := maxf(maxf(-z, z - _size.z), 0.0)
	return Vector2(dx, dz).length()


## Hoogte van het verre landschap. Op de rand exact het raster van het speelgebied (het oppervlak
## min 0,5 m); verder heuvels en laagtes die groeien met de afstand, kraters, ruggen en mesa's,
## en de kromming van de planeet.
func far_height(x: float, z: float) -> float:
	var o := outside(x, z)
	var h := _surface_y
	if o < 420.0:
		# Het oppervlak van de generator loopt door (kleine heuvels); verder vervaagt het naar zijn
		# gemiddelde (de generator is duur, en van ver valt dat reliëf weg tegen het grote).
		h = lerpf(terrain.surface_height_at(x, z), _surface_y, smoothstep(250.0, 420.0, o))
	h -= 0.5
	if o <= 0.0:
		return h
	# Heuvels en laagtes (geen rand rond het speelgebied: anders ligt het vierkant in een kom).
	var amp := (5.0 * smoothstep(0.0, 80.0, o) + 40.0 * smoothstep(80.0, 600.0, o)) * landform.hills_factor(x, z)
	h += amp * (_hills.get_noise_2d(x, z) * 0.5 + 0.5 - 0.35)
	h += landform.height(x, z, o)
	# Grote vormen; naar de buitenrand toe weer vlak, zodat die rand zeker achter de kim valt.
	var fade := 1.0 - smoothstep(_horizon - 2600.0, _horizon - 1100.0, o)
	var big := smoothstep(300.0, 2500.0, o) * fade
	if big > 0.0:
		h += big * 55.0 * _relief.get_noise_2d(x, z)
		# Mesa's: vlakke toppen met steile flanken, van ver een silhouet op de horizon.
		var mesa := smoothstep(0.22, 0.3, _mesa.get_noise_2d(x, z)) * smoothstep(700.0, 2200.0, o) * fade
		if mesa > 0.0:
			h += mesa * (80.0 + 45.0 * _relief.get_noise_2d(z * 0.7 + 913.0, x * 0.7))
	h += _crater_height(x, z)
	return h - o * o / (2.0 * _radius)


# --- Kraters --------------------------------------------------------------------------------

func _cell_rng(cx: int, cz: int, k: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (_seed * 73856093) ^ (cx * 19349663) ^ (cz * 83492791) ^ (k * 2654435761)
	return rng


## Kraters buiten het speelgebied, zoals die erin (zelfde profiel): kleine in de fijne ring
## (één per cel van 56 m, niet in elke cel), grote verder weg (cel van 520 m). Nooit tot tegen het
## speelgebied (daar sluit de ring aan op het voxelterrein) en nooit over de rand van de fijne ring.
func _place_craters() -> void:
	_small.clear()
	_big.clear()
	var c0 := int(floor(-RING / SMALL_CRATER_CELL)) - 1
	var c1 := int(ceil((_size.x + RING) / SMALL_CRATER_CELL)) + 1
	for cz in range(c0, c1 + 1):
		for cx in range(c0, c1 + 1):
			var rng := _cell_rng(cx, cz, 1)
			if rng.randf() > 0.6:
				continue
			var r := lerpf(7.0, 26.0, pow(rng.randf(), 2.0))
			var p := Vector2((cx + rng.randf_range(0.15, 0.85)) * SMALL_CRATER_CELL, (cz + rng.randf_range(0.15, 0.85)) * SMALL_CRATER_CELL)
			var o := outside(p.x, p.y)
			if o < 1.6 * r + 8.0 or o > RING - 1.6 * r - 8.0:
				continue
			_small[Vector2i(cx, cz)] = Vector4(p.x, p.y, r, r * rng.randf_range(0.16, 0.26))
	var reach := _horizon + _size.x
	var b0 := int(floor(-reach / BIG_CRATER_CELL))
	var b1 := int(ceil(reach / BIG_CRATER_CELL))
	for cz in range(b0, b1 + 1):
		for cx in range(b0, b1 + 1):
			var rng := _cell_rng(cx, cz, 2)
			if rng.randf() > 0.55:
				continue
			var r := lerpf(55.0, 210.0, pow(rng.randf(), 1.6))
			var p := Vector2((cx + rng.randf_range(0.3, 0.7)) * BIG_CRATER_CELL, (cz + rng.randf_range(0.3, 0.7)) * BIG_CRATER_CELL)
			if outside(p.x, p.y) < RING + 1.6 * r:
				continue
			_big[Vector2i(cx, cz)] = Vector4(p.x, p.y, r, r * rng.randf_range(0.14, 0.22))


func _crater_height(x: float, z: float) -> float:
	return _craters_in(_small, SMALL_CRATER_CELL, x, z) + _craters_in(_big, BIG_CRATER_CELL, x, z)


## Elke cel heeft hoogstens één krater en die past in de 3×3 cellen rond het punt.
static func _craters_in(cells: Dictionary, size: float, x: float, z: float) -> float:
	var h := 0.0
	var cx := int(floor(x / size))
	var cz := int(floor(z / size))
	for j in range(-1, 2):
		for i in range(-1, 2):
			var k: Variant = cells.get(Vector2i(cx + i, cz + j))
			if k == null:
				continue
			var cr: Vector4 = k
			var d := Vector2(x - cr.x, z - cr.y).length() / cr.z
			if d < 1.6:
				h += PlanetGenerator._crater_profile(d) * cr.w
	return h


# --- Meshes (werkthread) ----------------------------------------------------------------------

func _compute() -> void:
	var ts := Time.get_ticks_usec()
	_out = {"area": _area_arrays(), "far": _far_arrays(), "skirt": _skirt_arrays()}
	_out.merge(SurfaceDressing.compute(self))
	_compute_us = Time.get_ticks_usec() - ts
	# Klaar: op de hoofdthread in de scène hangen (call_deferred is veilig vanaf een werkthread).
	finish.call_deferred()


## Normalen uit de driehoeken (vloeiend: hoekpunten op dezelfde plek delen hun normaal).
## `colors`: per hoekpunt de tint van de landvorm (de rotsshader leest ze in het verre landschap).
static func _with_normals(verts: PackedVector3Array, idx: PackedInt32Array, colors := PackedColorArray()) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	if colors.size() == verts.size():
		arrays[Mesh.ARRAY_COLOR] = colors
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays)
	st.generate_normals()
	return st.commit_to_arrays()


## Twee driehoeken per vierhoek a-b-c-d, met de voorkant naar boven (Godot: met de klok mee gezien
## van voren; dan wijst cross(b - a, c - a) naar beneden).
static func _quad(idx: PackedInt32Array, at: int, verts: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	var up := (verts[b] - verts[a]).cross(verts[c] - verts[a]).y < 0.0
	if up:
		idx[at] = a; idx[at + 1] = b; idx[at + 2] = c
		idx[at + 3] = a; idx[at + 4] = c; idx[at + 5] = d
	else:
		idx[at] = a; idx[at + 1] = c; idx[at + 2] = b
		idx[at + 3] = a; idx[at + 4] = d; idx[at + 5] = c


## Raster van het speelgebied (gegenereerd oppervlak, zonder gaten), een halve meter lager dan
## het echte oppervlak: waar het voxelterrein geladen is, ligt dat erover.
func _area_arrays() -> Array:
	var n := AREA_STEPS + 1
	var step := _size.x / AREA_STEPS
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			verts[j * n + i] = Vector3(i * step, terrain.surface_height_at(i * step, j * step) - 0.5, j * step)
	var idx := PackedInt32Array()
	idx.resize(AREA_STEPS * AREA_STEPS * 6)
	var at := 0
	for j in AREA_STEPS:
		for i in AREA_STEPS:
			_quad(idx, at, verts, j * n + i, j * n + i + 1, (j + 1) * n + i + 1, (j + 1) * n + i)
			at += 6
	return _with_normals(verts, idx)


## De fijne ring (vierkant raster rond het speelgebied) en de grove schijf erbuiten, in één mesh:
## de buitenrand van de ring is de eerste ring van de schijf (zelfde hoekpunten, geen naad).
func _far_arrays() -> Array:
	var step := _size.x / STEPS_INSIDE
	var k0 := -int(ceil(RING / step))
	var k1 := STEPS_INSIDE + int(ceil(RING / step))
	var n := k1 - k0 + 1
	var verts := PackedVector3Array()
	# Fijne ring: alle rasterpunten (die binnen het speelgebied worden niet gebruikt).
	verts.resize(n * n)
	for j in n:
		for i in n:
			var x := (k0 + i) * step
			var z := (k0 + j) * step
			verts[j * n + i] = Vector3(x, far_height(x, z), z)
	var quads: Array[PackedInt32Array] = []
	var ring_idx := PackedInt32Array()
	ring_idx.resize((n - 1) * (n - 1) * 6)
	var at := 0
	for j in n - 1:
		for i in n - 1:
			var ki := k0 + i
			var kj := k0 + j
			# Cellen binnen het speelgebied laat het voxelterrein (en het raster) over.
			if ki >= 0 and ki < STEPS_INSIDE and kj >= 0 and kj < STEPS_INSIDE:
				continue
			_quad(ring_idx, at, verts, j * n + i, j * n + i + 1, (j + 1) * n + i + 1, (j + 1) * n + i)
			at += 6
	ring_idx.resize(at)
	quads.append(ring_idx)
	# Buitenrand van de ring, rondom (504 punten), als eerste ring van de schijf.
	var rim := PackedInt32Array()
	for i in n - 1:
		rim.append(i) # j = 0
	for j in n - 1:
		rim.append(j * n + n - 1) # i = n-1
	for i in range(n - 1, 0, -1):
		rim.append((n - 1) * n + i) # j = n-1
	for j in range(n - 1, 0, -1):
		rim.append(j * n) # i = 0
	var m := rim.size()
	var center := Vector3(_size.x * 0.5, 0.0, _size.z * 0.5)
	var dirs: Array[Vector3] = []
	var base_r := PackedFloat32Array()
	for v in rim:
		var flat := Vector3(verts[v].x, 0.0, verts[v].z) - center
		base_r.append(flat.length())
		dirs.append(flat.normalized())
	var prev := rim
	var o := 0.0
	var dstep := APRON_FIRST
	var reach := _horizon - base_r[0] # vanaf de ring (as) tot horizon_m van het midden
	while o < reach:
		o += dstep
		dstep *= APRON_GROW
		var cur := PackedInt32Array()
		cur.resize(m)
		var first := verts.size()
		verts.resize(first + m)
		for a in m:
			var p := center + dirs[a] * (base_r[a] + o)
			verts[first + a] = Vector3(p.x, far_height(p.x, p.z), p.z)
			cur[a] = first + a
		var ring_q := PackedInt32Array()
		ring_q.resize(m * 6)
		for a in m:
			var b := (a + 1) % m
			_quad(ring_q, a * 6, verts, prev[a], prev[b], cur[b], cur[a])
		quads.append(ring_q)
		prev = cur
	var idx := PackedInt32Array()
	for q in quads:
		idx.append_array(q)
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		colors[i] = landform.tint(verts[i].x, verts[i].z)
	return _with_normals(verts, idx, colors)


## Rok langs de rand van het speelgebied: hangt 30 m naar beneden en kijkt naar binnen, zodat je
## vanuit het speelgebied nooit door een kier tussen de rechte randen van de ring, het raster en
## het voxelterrein de lucht ziet (die kier tekende een witte lijn rond het vierkant).
func _skirt_arrays() -> Array:
	var step := _size.x / STEPS_INSIDE
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for side in 4:
		for k in STEPS_INSIDE:
			var p0: Vector3
			var p1: Vector3
			var inward: Vector3
			match side:
				0:
					p0 = Vector3(k * step, 0, 0)
					p1 = Vector3((k + 1) * step, 0, 0)
					inward = Vector3(0, 0, 1)
				1:
					p0 = Vector3(_size.x, 0, k * step)
					p1 = Vector3(_size.x, 0, (k + 1) * step)
					inward = Vector3(-1, 0, 0)
				2:
					p0 = Vector3(k * step, 0, _size.z)
					p1 = Vector3((k + 1) * step, 0, _size.z)
					inward = Vector3(0, 0, -1)
				_:
					p0 = Vector3(0, 0, k * step)
					p1 = Vector3(0, 0, (k + 1) * step)
					inward = Vector3(1, 0, 0)
			p0.y = far_height(p0.x, p0.z)
			p1.y = far_height(p1.x, p1.z)
			var q0 := p0 - Vector3(0, SKIRT, 0)
			var q1 := p1 - Vector3(0, SKIRT, 0)
			var a := verts.size()
			verts.append_array([p0, p1, q1, q0])
			normals.append_array([inward, inward, inward, inward])
			# Voorkant naar binnen: cross(b - a, c - a) wijst van de kijker weg (zie _quad).
			if (p1 - p0).cross(q1 - p0).dot(inward) < 0.0:
				idx.append_array([a, a + 1, a + 2, a, a + 2, a + 3])
			else:
				idx.append_array([a, a + 2, a + 1, a, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


# --- In de scène (hoofdthread) -------------------------------------------------------------

func _commit() -> void:
	var commit_t0 := Time.get_ticks_usec()
	var area_mesh := ArrayMesh.new()
	area_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _out.area)
	var area := MeshInstance3D.new()
	area.name = "AreaFromAbove"
	area.mesh = area_mesh
	var area_mat := terrain.terrain_material().duplicate() as ShaderMaterial
	area_mat.set_shader_parameter("near_cutoff", Tuning.get_f("terrain", "view_m", 110.0) - 20.0)
	area.material_override = area_mat
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	area.visibility_range_end = FAR_HIDE_M
	add_child(area)

	var far_mat := terrain.terrain_material().duplicate() as ShaderMaterial
	far_mat.set_shader_parameter("far_terrain", true)
	far_mat.set_shader_parameter("near_cutoff", 0.0)
	var far_mesh := ArrayMesh.new()
	far_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _out.far)
	far_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _out.skirt)
	var far := MeshInstance3D.new()
	far.name = "FarTerrain"
	far.mesh = far_mesh
	far.material_override = far_mat
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.visibility_range_end = FAR_HIDE_M
	add_child(far)
	SurfaceDressing.commit(self, _out)
	_out.clear()
	is_built = true
	_main_us += Time.get_ticks_usec() - commit_t0
	print("[surface] verre landschap: werkthread %.0f ms, hoofdthread %.0f ms, %s" % [_compute_us / 1000.0, _main_us / 1000.0, triangle_counts()])
	built.emit()


## Aantal driehoeken van het verre landschap en het raster (voor de performancecontrole).
func triangle_counts() -> Dictionary:
	var out := {}
	for n in ["FarTerrain", "AreaFromAbove"]:
		var mi := get_node_or_null(n) as MeshInstance3D
		if mi:
			var tris := 0
			for s in mi.mesh.get_surface_count():
				tris += (mi.mesh.surface_get_array_index_len(s)) / 3
			out[n] = tris
	return out


func _build_boundary() -> void:
	var size := _size
	# Paaltjes per stuk van een zijde, zodat elk stuk zijn eigen zichtafstand heeft.
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.16, 2.4, 0.16)
	var post_mat := MolVisual.machine_material("Hazard", false, 4.0)
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.12
	lamp_mesh.height = 0.2
	var lamp_mat := ShaderMaterial.new()
	lamp_mat.shader = preload("res://src/world/beacon.gdshader")
	var posts := Node3D.new()
	posts.name = "BoundaryPosts"
	add_child(posts)
	for side in 4:
		var length := size.x if side % 2 == 0 else size.z
		var count := int(length / POST_SPACING)
		var chunks: Array = []
		for c in POST_CHUNKS:
			chunks.append([])
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
			chunks[mini(int(float(k) / (count + 1) * POST_CHUNKS), POST_CHUNKS - 1)].append(p)
		for c in POST_CHUNKS:
			var pts: Array = chunks[c]
			if pts.is_empty():
				continue
			var mid := Vector3.ZERO
			for p: Vector3 in pts:
				mid += p
			mid /= pts.size()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = post_mesh
			mm.instance_count = pts.size()
			var lmm := MultiMesh.new()
			lmm.transform_format = MultiMesh.TRANSFORM_3D
			lmm.mesh = lamp_mesh
			lmm.instance_count = pts.size()
			for i in pts.size():
				var local: Vector3 = pts[i] - mid
				mm.set_instance_transform(i, Transform3D(Basis(), local + Vector3(0, 1.0, 0)))
				lmm.set_instance_transform(i, Transform3D(Basis(), local + Vector3(0, 2.3, 0)))
			var pm := MultiMeshInstance3D.new()
			pm.name = "Posts_%d_%d" % [side, c]
			pm.multimesh = mm
			pm.material_override = post_mat
			pm.position = mid
			pm.visibility_range_end = POST_HIDE_M
			posts.add_child(pm)
			var lm := MultiMeshInstance3D.new()
			lm.name = "Lamps_%d_%d" % [side, c]
			lm.multimesh = lmm
			lm.material_override = lamp_mat
			lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lm.position = mid
			lm.visibility_range_end = POST_HIDE_M
			posts.add_child(lm)
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
