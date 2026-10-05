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
## - De naad: langs elke zijde een strook (BAND_ROWS) met om de ±1 m een hoekpunt op exact de hoogte
##   van het voxelterrein (de ring heeft er één om de 7,8 m, en een halve meter lager gaf van op de
##   grond een trede langs de paaltjes). Het raster, de strook en de ring sluiten op de rand aan, met
##   een rok die naar binnen kijkt voor de kieren tussen de rechte randen en het voxelterrein.
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
## Naadstrook langs de rand: rijen op deze afstand buiten het speelgebied (m), en zoveel hoekpunten
## langs de rand per cel van de ring (7,8 m / 8 ≈ 1 m, zo fijn als het reliëf van de generator).
const BAND_ROWS: Array[float] = [0.0, 1.2, 3.0, 5.2]
const BAND_PER_CELL := 8
## Het voxelterrein sluit op de grens van zijn volume af tegen lucht: zijn laatste cel ligt op de
## goede hoogte, maar met naar buiten geknikte normalen (van op de grond een donkere lijn langs de
## paaltjes). De strook begint daarom binnen het speelgebied: rijen op (m binnen de rand, m boven het
## oppervlak). De binnenste ligt eronder, de volgende er net boven: over die laatste halve meter
## tekent de strook, verder het voxelterrein. Ook de rij op de rand ligt BAND_LIFT hoger.
const BAND_INSIDE: Array[Vector2] = [Vector2(1.2, -0.05), Vector2(0.55, 0.05)]
const BAND_LIFT := 0.05
## Landingsplek in de rotsshader: straal van de aangestampte kern en waar ze helemaal terrein is (m).
const LANDING_PAD := Vector2(11.0, 30.0)
## De tint van de landvorm over het speelgebied, als textuur voor het voxelterrein (m per texel).
const NEAR_TINT_STEP := 2.0
## Kaarten van de planeet rond de landingsplek voor het planeetdek onder de hub (Atmosphere): een
## scherpe op het raster van de ring (±496 m, 7,8 m per texel) en een grove tot ±4 km (62,5 m).
## Rgb = kleur van de grond (sRGB, met reliëf, lagen en landmarks), a = hoogte.
const MAP_FAR_N := 128
const MAP_FAR_HALF := 4000.0
## Hoogte in de kaart: a = (hoogte - oppervlak - MAP_H.x) / MAP_H.y.
const MAP_H := Vector2(-60.0, 240.0)

var terrain: TerrainAPI
## Planeettype van deze wereld, en zijn grote landvormen rond het speelgebied (Landform.create).
var planet := PlanetType.Id.ROESTBOL
var landform: Landform = Landform.new()
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
var _phase_ms: Dictionary = {} # ms per stap op de werkthread (voor de log)
## Reliëf (planeten.md §3.5: de kleur volgt de vorm): hoogte min het gemiddelde in een venster van
## ±RELIEF_CELLS cellen van de ring, op het raster van de ring (ook over het speelgebied). Laagtes
## worden donkerder, hoogtes en randen lichter (PlanetType.ground relief_*), in het verre landschap
## én in de tint van het voxelterrein: drie waardegroepen die aan de vormen hangen, niet aan ruis.
const RELIEF_CELLS := 5
## De kaarten (na _commit): texturen en rechthoeken (x/z van de hoek, breedte), voor Atmosphere.
var land_map: ImageTexture
var land_map_rect := Vector4.ZERO
var land_map_near: ImageTexture
var land_map_near_rect := Vector4.ZERO
var _rel_field := PackedFloat32Array()
var _rel_n := 0
var _rel_o := 0.0
var _rel_step := 1.0
var _relief_m := 0.0 # m hoogteverschil voor het volle effect (0 = uit)
var _relief_dark := Color(1, 1, 1)
var _relief_light := Color(1, 1, 1)


func build(t: TerrainAPI, planet_seed: int, planet_id := PlanetType.Id.ROESTBOL) -> void:
	_t0 = Time.get_ticks_usec()
	terrain = t
	_seed = planet_seed
	planet = planet_id
	landform = t.landform if t.landform != null else Landform.create(planet_id)
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
	# De kleuren van de bovenste laag en de lagen in de wanden: per planeet (ook het voxelterrein).
	var g := PlanetType.ground(planet_id)
	var mat := t.terrain_material()
	for k: String in ["base", "light", "dark"]:
		var col: Color = g[k]
		mat.set_shader_parameter("surf_" + k, Vector3(col.r, col.g, col.b))
	var strata: Array = g.strata
	for i in 3:
		var col: Color = strata[i]
		mat.set_shader_parameter(["strata_light", "strata_mid", "strata_dark"][i], Vector3(col.r, col.g, col.b))
	if t.landform == null:
		landform.setup(planet_seed, Vector2(c.x, c.z), Vector2(_size.x, _size.z))
	_relief_m = float(g.get("relief_m", 0.0))
	_relief_dark = g.get("relief_dark", Color(1, 1, 1))
	_relief_light = g.get("relief_light", Color(1, 1, 1))
	var pd: Color = g.patch_dark
	var pl: Color = g.patch_light
	mat.set_shader_parameter("patch_dark", Vector4(pd.r, pd.g, pd.b, pd.a))
	mat.set_shader_parameter("patch_light", Vector4(pl.r, pl.g, pl.b, pl.a))
	mat.set_shader_parameter("patch_scale", float(g.patch_scale))
	mat.set_shader_parameter("surface_world_y", _surface_y)
	var sp := landform.shader_params(_surface_y)
	for k: String in sp:
		mat.set_shader_parameter(k, sp[k])
	_place_craters()
	_build_boundary()
	# Het zware werk (±50k hoogtes) op een werkthread; de scène enkel op de hoofdthread.
	_task = WorkerThreadPool.add_task(_compute, true, "PlanetSurface") # voorrang: het voxelterrein streamt intussen ook
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


## Hoogte van het verre landschap. Op de rand exact het oppervlak van het voxelterrein (zelfde
## generator, zelfde hoogte: geen trede); verder heuvels en laagtes die groeien met de afstand,
## kraters, ruggen en mesa's, en de kromming van de planeet.
func far_height(x: float, z: float) -> float:
	var o := outside(x, z)
	var h := _surface_y
	if o < 420.0:
		# Het oppervlak van de generator loopt door (kleine heuvels); verder vervaagt het naar zijn
		# gemiddelde (de generator is duur, en van ver valt dat reliëf weg tegen het grote).
		h = lerpf(terrain.surface_height_at(x, z), _surface_y, smoothstep(250.0, 420.0, o))
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
	var tp := ts
	_out = {}
	for step: String in ["area", "far", "skirt", "tint", "map", "dressing"]:
		match step:
			"tint":
				_out.near_tint = _near_tint_data()
			"map":
				var cell := _size.x / STEPS_INSIDE
				var near_n := 2 * int(ceil(RING / cell)) + STEPS_INSIDE + 1
				_out.land_map_near_n = near_n
				_out.land_map_near_half = near_n * cell * 0.5
				_out.land_map_near = _land_map_data(_out.far, near_n, near_n * cell * 0.5)
				_out.land_map = _land_map_data(_out.far, MAP_FAR_N, MAP_FAR_HALF)
			"area":
				_out.area = _area_arrays()
			"far":
				_out.far = _far_arrays()
			"skirt":
				_out.skirt = _skirt_arrays()
			"dressing":
				_out.merge(SurfaceDressing.compute(self))
		var now := Time.get_ticks_usec()
		_phase_ms[step] = (now - tp) / 1000
		tp = now
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
## van voren; dan wijst cross(b - a, c - a) naar beneden). Gesplitst langs de diagonaal waarvan de
## hoeken het minst in hoogte verschillen: die volgt de hoogtelijn, zodat een klifrand of rug die
## schuin door het raster loopt een rechte rand blijft in plaats van een zaagtand (buiten-7).
static func _quad(idx: PackedInt32Array, at: int, verts: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	if absf(verts[a].y - verts[c].y) > absf(verts[b].y - verts[d].y):
		var t := a
		a = b
		b = c
		c = d
		d = t
	var up := (verts[b] - verts[a]).cross(verts[c] - verts[a]).y < 0.0
	if up:
		idx[at] = a; idx[at + 1] = b; idx[at + 2] = c
		idx[at + 3] = a; idx[at + 4] = c; idx[at + 5] = d
	else:
		idx[at] = a; idx[at + 1] = c; idx[at + 2] = b
		idx[at + 3] = a; idx[at + 4] = d; idx[at + 5] = c


## Raster van het speelgebied (gegenereerd oppervlak, zonder gaten), een halve meter lager dan
## het echte oppervlak: waar het voxelterrein geladen is, ligt dat erover. Op de rand zelf exact het
## oppervlak, zodat het aansluit op de naadstrook van het verre landschap.
func _area_arrays() -> Array:
	var n := AREA_STEPS + 1
	var step := _size.x / AREA_STEPS
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			var x := i * step
			var z := j * step
			var d := minf(minf(x, z), minf(_size.x - x, _size.z - z))
			verts[j * n + i] = Vector3(x, terrain.surface_height_at(x, z) - 0.5 * smoothstep(0.0, 3.0, d), z)
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
	_build_relief(verts, n, k0 * step, step)
	var quads: Array[PackedInt32Array] = []
	var ring_idx := PackedInt32Array()
	ring_idx.resize((n - 1) * (n - 1) * 6)
	var at := 0
	for j in n - 1:
		for i in n - 1:
			var ki := k0 + i
			var kj := k0 + j
			# Cellen binnen het speelgebied laat het voxelterrein (en het raster) over; de rij cellen er
			# vlak rond vult de naadstrook (hieronder).
			if ki >= -1 and ki <= STEPS_INSIDE and kj >= -1 and kj <= STEPS_INSIDE:
				continue
			_quad(ring_idx, at, verts, j * n + i, j * n + i + 1, (j + 1) * n + i + 1, (j + 1) * n + i)
			at += 6
	ring_idx.resize(at)
	quads.append(ring_idx)
	quads.append(_band(verts, n, k0))
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
		# Hoekpuntkleuren zijn 8-bit (0..1): de tint (1 = neutraal, tot 2 = lichter) gaat er gehalveerd in.
		var tc := _relief_tint(landform.tint(verts[i].x, verts[i].z), verts[i].x, verts[i].z)
		colors[i] = Color(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, tc.a)
	return _with_normals(verts, idx, colors)


## Het reliëfveld uit de hoogtes van het raster van de ring (n × n, vanaf origin, om de step m), met
## een sommentabel (een vak van ±RELIEF_CELLS cellen kost zo vier opzoekingen).
func _build_relief(verts: PackedVector3Array, n: int, origin: float, step: float) -> void:
	_rel_n = n
	_rel_o = origin
	_rel_step = step
	_rel_field = PackedFloat32Array()
	if _relief_m <= 0.0:
		_rel_n = 0
		return
	var w := n + 1
	var sat := PackedFloat64Array()
	sat.resize(w * w)
	for j in n:
		var row := 0.0
		for i in n:
			row += verts[j * n + i].y
			sat[(j + 1) * w + i + 1] = sat[j * w + i + 1] + row
	_rel_field.resize(n * n)
	var r := RELIEF_CELLS
	for j in n:
		var j0 := maxi(j - r, 0)
		var j1 := mini(j + r + 1, n)
		for i in n:
			var i0 := maxi(i - r, 0)
			var i1 := mini(i + r + 1, n)
			var sum := sat[j1 * w + i1] - sat[j0 * w + i1] - sat[j1 * w + i0] + sat[j0 * w + i0]
			_rel_field[j * n + i] = verts[j * n + i].y - sum / float((j1 - j0) * (i1 - i0))


## Reliëf hier (m boven het gemiddelde van de omgeving), bilineair; 0 buiten de fijne ring (en naar
## haar buitenrand toe uitdovend, zodat de grove schijf aansluit).
func relief_at(x: float, z: float) -> float:
	if _rel_n == 0:
		return 0.0
	var fx := (x - _rel_o) / _rel_step
	var fz := (z - _rel_o) / _rel_step
	if fx < 0.0 or fz < 0.0 or fx >= _rel_n - 1 or fz >= _rel_n - 1:
		return 0.0
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * _rel_n + i
	var v := lerpf(lerpf(_rel_field[k], _rel_field[k + 1], tx), lerpf(_rel_field[k + _rel_n], _rel_field[k + _rel_n + 1], tx), tz)
	return v * (1.0 - smoothstep(RING - 110.0, RING - 30.0, outside(x, z)))


## De tint van de landvorm, met het reliëf erbij (laagtes donker, hoogtes licht).
func _relief_tint(tc: Color, x: float, z: float) -> Color:
	if _rel_n == 0:
		return tc
	var k := clampf(relief_at(x, z) / _relief_m, -1.0, 1.0)
	var m := Color(1, 1, 1).lerp(_relief_dark, -k) if k < 0.0 else Color(1, 1, 1).lerp(_relief_light, k)
	return Color(minf(tc.r * m.r, 2.0), minf(tc.g * m.g, 2.0), minf(tc.b * m.b, 2.0), tc.a)


## Naadstrook rond het speelgebied, in de cellen tussen de rand en de eerste rasterlijn van de ring
## (die laat _far_arrays open). Voegt de hoekpunten toe aan `verts` en geeft de driehoeken:
## - per zijde rijen op BAND_ROWS buiten de rand, met BAND_PER_CELL hoekpunten per cel van de ring;
##   rij 0 ligt op de rand zelf, op de hoogte van het voxelterrein, en BAND_INSIDE rijen erbinnen
##   (over de laatste cel van het voxelterrein, die op de grens van zijn volume donker kleurt);
## - de buitenste rij geritst aan de rasterlijn van de ring (waaiers, geen T-knopen: geen kieren);
## - op elke hoek een waaier vanuit het hoekpunt van de ring.
func _band(verts: PackedVector3Array, n: int, k0: int) -> PackedInt32Array:
	var s_in := STEPS_INSIDE
	var m := s_in * BAND_PER_CELL
	var rows := BAND_ROWS.size()
	# Zijden: oorsprong, richting langs de rand, richting naar buiten (x/z). W, O, Z, N.
	var sides: Array[Array] = [
		[Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)],
		[Vector2(_size.x, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 0.0)],
		[Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)],
		[Vector2(0.0, _size.z), Vector2(1.0, 0.0), Vector2(0.0, 1.0)],
	]
	# De rasterlijn van de ring net buiten elke zijde, als (ki, kj) per k = 0..s_in.
	var coarse := func(side: int, k: int) -> int:
		var c := [Vector2i(-1, k), Vector2i(s_in + 1, k), Vector2i(k, -1), Vector2i(k, s_in + 1)][side] as Vector2i
		return (c.y - k0) * n + (c.x - k0)
	var first: Array[int] = []
	for sd: Array in sides:
		var o0: Vector2 = sd[0]
		var along: Vector2 = sd[1]
		var out: Vector2 = sd[2]
		first.append(verts.size())
		for r in rows:
			for i in m + 1:
				var q := o0 + along * (_size.x * i / m) + out * BAND_ROWS[r]
				verts.append(Vector3(q.x, far_height(q.x, q.y) + (BAND_LIFT if r == 0 else 0.0), q.y))
		# Rijen binnen de rand (na de andere), van binnen naar buiten.
		for bi: Vector2 in BAND_INSIDE:
			for i in m + 1:
				var q := o0 + along * (_size.x * i / m) - out * bi.x
				verts.append(Vector3(q.x, terrain.surface_height_at(q.x, q.y) + bi.y, q.y))
	var idx := PackedInt32Array()
	for side in 4:
		var b := first[side]
		for r in rows - 1:
			for i in m:
				var a := b + r * (m + 1) + i
				_tri(idx, verts, a, a + 1, a + m + 2)
				_tri(idx, verts, a, a + m + 2, a + m + 1)
		for k in BAND_INSIDE.size():
			var r0 := b + (rows + k) * (m + 1)
			var r1 := b + (rows + k + 1) * (m + 1) if k + 1 < BAND_INSIDE.size() else b
			for i in m:
				_tri(idx, verts, r0 + i, r0 + i + 1, r1 + i + 1)
				_tri(idx, verts, r0 + i, r1 + i + 1, r1 + i)
		# Ritsen: elke cel van de ring (k .. k+1) tegen BAND_PER_CELL stukjes van de buitenste rij.
		var outer := b + (rows - 1) * (m + 1)
		var half := BAND_PER_CELL >> 1
		for k in s_in:
			var c0: int = coarse.call(side, k)
			var c1: int = coarse.call(side, k + 1)
			var f := outer + k * BAND_PER_CELL
			for i in half:
				_tri(idx, verts, c0, f + i, f + i + 1)
			_tri(idx, verts, c0, f + half, c1)
			for i in range(half, BAND_PER_CELL):
				_tri(idx, verts, c1, f + i, f + i + 1)
	# Hoeken: [zijde langs z/x die op dit hoekpunt eindigt (i = 0 of m), idem voor de andere, ring-hoek].
	var corners := [[2, 0, 0, 0, Vector2i(-1, -1)], [2, m, 1, 0, Vector2i(s_in + 1, -1)],
			[3, 0, 0, m, Vector2i(-1, s_in + 1)], [3, m, 1, m, Vector2i(s_in + 1, s_in + 1)]]
	for cr: Array in corners:
		var sa: int = cr[0]
		var ia: int = cr[1]
		var sb: int = cr[2]
		var ib: int = cr[3]
		var rc: Vector2i = cr[4]
		var apex := (rc.y - k0) * n + (rc.x - k0)
		var poly := PackedInt32Array()
		poly.append(coarse.call(sa, 0 if ia == 0 else s_in))
		for r in range(rows - 1, -1, -1):
			poly.append(first[sa] + r * (m + 1) + ia)
		for r in range(1, rows):
			poly.append(first[sb] + r * (m + 1) + ib)
		poly.append(coarse.call(sb, 0 if ib == 0 else s_in))
		for i in poly.size() - 1:
			_tri(idx, verts, apex, poly[i], poly[i + 1])
	return idx


## Eén driehoek met de voorkant naar boven (zie _quad).
static func _tri(idx: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int) -> void:
	if (verts[b] - verts[a]).cross(verts[c] - verts[a]).y < 0.0:
		idx.append_array([a, b, c])
	else:
		idx.append_array([a, c, b])


## De tint van de landvorm over het speelgebied (rgb gehalveerd zoals de hoekpuntkleuren, a = naden
## van de korst), voor het voxelterrein: zo loopt de kleur van het landschap door tot onder je
## voeten. Op de landingsplek neutraal. Ruwe bytes (een Image per pixel aanspreken is op de
## werkthread traag); de hoofdthread maakt er een textuur van.
func _near_tint_data() -> PackedByteArray:
	var n := int(ceil(_size.x / NEAR_TINT_STEP)) + 1
	var c := landform.landing
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for j in n:
		for i in n:
			var x := i * NEAR_TINT_STEP
			var z := j * NEAR_TINT_STEP
			var tc := _relief_tint(landform.tint(x, z), x, z)
			var seams := landform.crust_seams(x, z)
			var pad := smoothstep(LANDING_PAD.x, LANDING_PAD.y, Vector2(x - c.x, z - c.y).length())
			var at := (j * n + i) * 4
			data[at] = int(clampf(lerpf(1.0, tc.r, pad) * 0.5, 0.0, 1.0) * 255.0 + 0.5)
			data[at + 1] = int(clampf(lerpf(1.0, tc.g, pad) * 0.5, 0.0, 1.0) * 255.0 + 0.5)
			data[at + 2] = int(clampf(lerpf(1.0, tc.b, pad) * 0.5, 0.0, 1.0) * 255.0 + 0.5)
			data[at + 3] = int(clampf(seams * pad, 0.0, 1.0) * 255.0 + 0.5)
	return data


## De kaart voor het planeetdek (buiten-11: door de baai zag je voor elke planeet dezelfde grijze
## kratermaan). Uit de hoekpunten van het verre landschap die er al zijn (geen extra hoogtes: die
## kosten op Fossielwereld ±30 µs per stuk): elk hoekpunt in zijn texel, gemiddeld, gaten opgevuld
## vanuit de buren. Daarbovenop de landmarks (Landform.map_marks: de kristalader, het skelet).
func _land_map_data(far: Array, n: int, half: float) -> PackedByteArray:
	var verts: PackedVector3Array = far[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = far[Mesh.ARRAY_COLOR]
	var g := PlanetType.ground(planet)
	var base := (g.base as Color).srgb_to_linear()
	var strata := ((g.strata as Array)[1] as Color).srgb_to_linear()
	var x0 := landform.landing.x - half
	var z0 := landform.landing.y - half
	var texel := half * 2.0 / n
	var acc := PackedFloat32Array()
	acc.resize(n * n * 5) # r, g, b, hoogte, aantal
	for i in verts.size():
		var v := verts[i]
		var ti := int((v.x - x0) / texel)
		var tj := int((v.z - z0) / texel)
		if ti < 0 or tj < 0 or ti >= n or tj >= n:
			continue
		var c := cols[i]
		var lin := Color(base.r * c.r * 2.0, base.g * c.g * 2.0, base.b * c.b * 2.0)
		lin = lin.lerp(strata, clampf(c.a, 0.0, 1.0) * 0.55)
		var o := outside(v.x, v.z)
		var at := (tj * n + ti) * 5
		acc[at] += lin.r
		acc[at + 1] += lin.g
		acc[at + 2] += lin.b
		acc[at + 3] += v.y + o * o / (2.0 * _radius) - _surface_y
		acc[at + 4] += 1.0
	for t in n * n:
		var k := acc[t * 5 + 4]
		if k > 0.0:
			for ch in 4:
				acc[t * 5 + ch] /= k
			acc[t * 5 + 4] = 1.0
	# Gaten (verder dan ±1,5 km liggen de ringen van de schijf verder uit elkaar dan een texel).
	for pass_i in 8:
		var filled := acc.duplicate()
		var left := 0
		for tj in n:
			for ti in n:
				var at := (tj * n + ti) * 5
				if acc[at + 4] > 0.0:
					continue
				var sum := [0.0, 0.0, 0.0, 0.0]
				var k := 0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						var ii := ti + di
						var jj := tj + dj
						if ii < 0 or jj < 0 or ii >= n or jj >= n:
							continue
						var b := (jj * n + ii) * 5
						if acc[b + 4] > 0.0:
							for ch in 4:
								sum[ch] += acc[b + ch]
							k += 1
				if k == 0:
					left += 1
					continue
				for ch in 4:
					filled[at + ch] = sum[ch] / k
				filled[at + 4] = 1.0
		acc = filled
		if left == 0:
			break
	# Wat dan nog leeg is: het gemiddelde.
	var mean := [0.0, 0.0, 0.0, 0.0]
	var cnt := 0
	for t in n * n:
		if acc[t * 5 + 4] > 0.0:
			for ch in 4:
				mean[ch] += acc[t * 5 + ch]
			cnt += 1
	for t in n * n:
		if acc[t * 5 + 4] <= 0.0:
			for ch in 4:
				acc[t * 5 + ch] = mean[ch] / maxi(cnt, 1)
	for mark: Array in landform.map_marks():
		var mp: Vector2 = mark[0]
		var mr: float = mark[1]
		var mc: Color = (mark[2] as Color).srgb_to_linear()
		var reach := int(ceil(mr / texel)) + 1
		var ci := int((mp.x - x0) / texel)
		var cj := int((mp.y - z0) / texel)
		for tj in range(cj - reach, cj + reach + 1):
			for ti in range(ci - reach, ci + reach + 1):
				if ti < 0 or tj < 0 or ti >= n or tj >= n:
					continue
				var d := Vector2(x0 + (ti + 0.5) * texel, z0 + (tj + 0.5) * texel).distance_to(mp)
				var k := (1.0 - smoothstep(mr * 0.5, mr + texel * 0.5, d)) * mc.a
				if k <= 0.0:
					continue
				var at := (tj * n + ti) * 5
				acc[at] = lerpf(acc[at], mc.r, k)
				acc[at + 1] = lerpf(acc[at + 1], mc.g, k)
				acc[at + 2] = lerpf(acc[at + 2], mc.b, k)
	var data := PackedByteArray()
	data.resize(n * n * 4)
	for t in n * n:
		var lin := Color(acc[t * 5], acc[t * 5 + 1], acc[t * 5 + 2]).linear_to_srgb()
		data[t * 4] = int(clampf(lin.r, 0.0, 1.0) * 255.0 + 0.5)
		data[t * 4 + 1] = int(clampf(lin.g, 0.0, 1.0) * 255.0 + 0.5)
		data[t * 4 + 2] = int(clampf(lin.b, 0.0, 1.0) * 255.0 + 0.5)
		data[t * 4 + 3] = int(clampf((acc[t * 5 + 3] - MAP_H.x) / MAP_H.y, 0.0, 1.0) * 255.0 + 0.5)
	return data


## Rok langs de rand van het speelgebied: hangt 30 m naar beneden en kijkt naar binnen, zodat je
## vanuit het speelgebied nooit door een kier tussen de rechte randen van de ring, het raster en
## het voxelterrein de lucht ziet (die kier tekende een witte lijn rond het vierkant). Even fijn als
## de naadstrook en met haar bovenrand op de rand van de strook (anders steekt de rok tussen twee
## hoekpunten boven de grond uit, of blijft er een spleet onder de strook).
func _skirt_arrays() -> Array:
	var segs := STEPS_INSIDE * BAND_PER_CELL
	var step := _size.x / segs
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	for side in 4:
		for k in segs:
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
			# Exact de rand van de naadstrook (zelfde punten, zelfde hoogte): geen spleet waar een
			# scherende straal tussen de strook en het raster onder de strook door naar de lucht kan.
			p0.y = far_height(p0.x, p0.z) + BAND_LIFT
			p1.y = far_height(p1.x, p1.z) + BAND_LIFT
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
	# Neutrale tint en geen lagen (zonder kleuren leest de rotsshader wit: dubbel zo licht).
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color(0.5, 0.5, 0.5, 0.0))
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays


# --- In de scène (hoofdthread) -------------------------------------------------------------

func _commit() -> void:
	var commit_t0 := Time.get_ticks_usec()
	# Eerst de tint van het speelgebied op het materiaal van het terrein (de kopieën hieronder erven ze).
	var tn := int(ceil(_size.x / NEAR_TINT_STEP)) + 1
	var tint_img := Image.create_from_data(tn, tn, false, Image.FORMAT_RGBA8, _out.near_tint)
	var tmat := terrain.terrain_material()
	tmat.set_shader_parameter("near_tint", ImageTexture.create_from_image(tint_img))
	tmat.set_shader_parameter("near_tint_rect", Vector4(0.0, 0.0, NEAR_TINT_STEP, float(tn)))
	tmat.set_shader_parameter("near_tint_on", true)
	land_map = ImageTexture.create_from_image(Image.create_from_data(MAP_FAR_N, MAP_FAR_N, false, Image.FORMAT_RGBA8, _out.land_map))
	land_map_rect = Vector4(landform.landing.x - MAP_FAR_HALF, landform.landing.y - MAP_FAR_HALF, MAP_FAR_HALF * 2.0, 0.0)
	var nn: int = _out.land_map_near_n
	var nh: float = _out.land_map_near_half
	land_map_near = ImageTexture.create_from_image(Image.create_from_data(nn, nn, false, Image.FORMAT_RGBA8, _out.land_map_near))
	land_map_near_rect = Vector4(landform.landing.x - nh, landform.landing.y - nh, nh * 2.0, 0.0)
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
	# Werpt schaduw (buiten-3/-7, ronde 2): kliffen, buttes en ruggen leggen van op de drop een schaduw
	# over het landschap ervoor; zonder hingen ze er belicht maar "plat" bij.
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	far.visibility_range_end = FAR_HIDE_M
	add_child(far)
	SurfaceDressing.commit(self, _out)
	_out.clear()
	is_built = true
	_main_us += Time.get_ticks_usec() - commit_t0
	print("[surface] verre landschap (%s): werkthread %.0f ms %s, hoofdthread %.0f ms, %s" % [
			PlanetType.Id.keys()[planet], _compute_us / 1000.0, _phase_ms, _main_us / 1000.0, triangle_counts()])
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
