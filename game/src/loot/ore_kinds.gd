class_name OreKinds
extends RefCounted
## Soorten erts (GDD v3 §4: vast inkomen, per laag een eigen soort) en hun clustermodellen.
## Een cluster is een handvol kristalnaalden die uit de rots steken; procedureel, enkele varianten
## per soort, gedeeld door alle clusters (willekeurige draaiing per cluster).

enum Kind { KOPER, IJZER, ZILVER, LICHTKRISTAL }

const NAMES: Array[String] = ["Copper", "Iron", "Silver", "Glow crystal"]
## Waarde per eenheid (€) bij verkoop aan boord: standaard, de echte waarden staan in ore.cfg
## (value_koper …, ontwerp-13: minder slagen per cluster, meer per slag). Gebruik value().
const VALUES: Array[int] = [8, 12, 20, 32]
const KEYS: Array[String] = ["koper", "ijzer", "zilver", "lichtkristal"]


## Waarde per eenheid (€), uit de tuning.
static func value(kind: int) -> int:
	return Tuning.get_i("ore", "value_" + KEYS[kind], VALUES[kind])
## Kleur van de kristallen (en van de glinsters, het stof en de schilfers bij het hakken). Koper is
## verweerd: turkoois malachiet, zodat het afsteekt tegen de rode klei (golf 3, binnen-03: "oranje op
## oranje"); het blanke metaal zit in klompjes in de knol (METAL).
const COLORS: Array[Color] = [
	Color(0.24, 0.82, 0.66), # koper: malachiet, turkoois
	Color(0.78, 0.2, 0.16), # ijzer: roestrood (hematiet)
	Color(0.82, 0.86, 0.92), # zilver
	Color(0.3, 0.9, 1.0), # lichtkristal: cyaan, gloeit
]
const GLOW: Array[float] = [0.45, 0.3, 0.45, 2.2]
## Blank metaal in de knol per soort (koper, ijzer, zilver; lichtkristal heeft geen).
const METAL: Array[Color] = [Color(0.97, 0.58, 0.32), Color(0.42, 0.4, 0.42), Color(0.92, 0.93, 0.96), Color(0, 0, 0)]
## De knol (de rots waarin het erts zit): donker, zodat de kristallen en het metaal afsteken.
const MATRIX: Array[Color] = [Color(0.16, 0.12, 0.1), Color(0.2, 0.08, 0.06), Color(0.14, 0.14, 0.16), Color(0.1, 0.12, 0.16)]
const VARIANTS := 5

static var _meshes: Dictionary = {} # "kind/variant" -> ArrayMesh
static var _materials: Dictionary = {} # kind -> Material


## Erts per laag (Strata.Layer: KRISTAL, GRANIET, ZANDSTEEN, KLEI) en planeet: op de Kristalmaan
## zit in het zandsteen lichtkristal in plaats van ijzer (planets.cfg glow_ore_in_sand).
static func for_layer(layer: Strata.Layer, planet := 0) -> Kind:
	match layer:
		Strata.Layer.KLEI:
			return Kind.KOPER
		Strata.Layer.ZANDSTEEN:
			return Kind.LICHTKRISTAL if PlanetLoot.value(planet, "glow_ore_in_sand", 0.0) > 0.5 else Kind.IJZER
		Strata.Layer.GRANIET:
			return Kind.ZILVER
	return Kind.LICHTKRISTAL


static func mesh(kind: Kind, variant: int) -> ArrayMesh:
	var key := "%d/%d" % [kind, variant % VARIANTS]
	if not _meshes.has(key):
		_meshes[key] = _build(kind, variant % VARIANTS)
	return _meshes[key]


## Materiaal van de kristallen (oppervlak 1 van de mesh). De knol (0) en het metaal (2) krijgen
## hun eigen materiaal in _build.
static func material(kind: Kind) -> Material:
	if not _materials.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[kind]
		m.metallic = [0.0, 0.75, 0.9, 0.1][kind]
		m.roughness = [0.3, 0.3, 0.2, 0.12][kind]
		m.emission_enabled = true
		m.emission = COLORS[kind]
		m.emission_energy_multiplier = GLOW[kind]
		m.rim_enabled = true
		m.rim = 0.6
		m.vertex_color_use_as_albedo = true
		_materials[kind] = m
	return _materials[kind]


static func _matrix_material(kind: Kind) -> Material:
	var key := 100 + kind
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = MATRIX[kind]
		m.roughness = 0.92
		m.vertex_color_use_as_albedo = true
		_materials[key] = m
	return _materials[key]


static func _metal_material(kind: Kind) -> Material:
	var key := 200 + kind
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = METAL[kind]
		m.metallic = 1.0
		m.roughness = 0.28
		m.emission_enabled = true
		m.emission = METAL[kind]
		m.emission_energy_multiplier = 0.12
		_materials[key] = m
	return _materials[key]


## Een ertsknol (golf 3, binnen-03): een donkere, gehakte knol van ±0,6 m met 10-13 zeskantige naalden
## in alle richtingen (een zee-egel: aan welke kant je hem ook vrijgraaft, er steken altijd naalden uit
## en de knol zelf komt bloot) en een paar klompjes blank metaal. Drie oppervlakken: 0 knol, 1
## kristallen (material()), 2 metaal. Oorsprong = midden van de knol.
static func _build(kind: Kind, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = kind * 101 + variant * 7 + 3
	var out := ArrayMesh.new()
	# 0. De knol: een icosaëder, één keer verdeeld, met verschoven hoekpunten (platte facetten).
	var lump := SurfaceTool.new()
	lump.begin(Mesh.PRIMITIVE_TRIANGLES)
	lump.set_smooth_group(-1)
	var r0 := 0.36
	for f in _ico_faces(1):
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		var pa := a * r0 * _bump(a, kind, variant)
		var pb := b * r0 * _bump(b, kind, variant)
		var pc := c * r0 * _bump(c, kind, variant)
		var shade := 0.8 + 0.35 * fposmod(sin((a + b + c).dot(Vector3(12.9, 78.2, 37.7)) + variant) * 43758.5, 1.0)
		_tri(lump, pa, pc, pb, Color(shade, shade, shade), Color(shade, shade, shade), Color(shade, shade, shade)) # met de klok mee
	lump.generate_normals()
	lump.commit(out)
	out.surface_set_material(0, _matrix_material(kind))
	# 1. Naalden in alle richtingen (gelijkmatig verdeeld: een gulden spiraal, wat geschud).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rng.randi_range(10, 13)
	for i in count:
		var yy := 1.0 - 2.0 * (i + 0.5) / count
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var ang := i * 2.39996 + variant
		var dir := (Vector3(cos(ang) * rr, yy, sin(ang) * rr) + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))).normalized()
		var length := rng.randf_range(0.34, 0.6) * (1.2 if i % 4 == 0 else 1.0)
		var radius := length * rng.randf_range(0.13, 0.2)
		_shard(st, dir * r0 * 0.6, dir, length, radius, rng.randf() * TAU, rng.randf_range(0.75, 1.0))
	st.generate_normals()
	st.commit(out)
	out.surface_set_material(1, material(kind))
	# 2. Klompjes blank metaal op de knol.
	if METAL[kind].a > 0.0 and METAL[kind].r + METAL[kind].g > 0.0:
		var mt := SurfaceTool.new()
		mt.begin(Mesh.PRIMITIVE_TRIANGLES)
		mt.set_smooth_group(-1)
		for k in rng.randi_range(4, 6):
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			var nr := rng.randf_range(0.06, 0.1)
			var cen := d * (r0 * 0.95)
			for f in _ico_faces(0):
				_tri(mt, cen + (f[0] as Vector3) * nr, cen + (f[2] as Vector3) * nr * 0.9, cen + (f[1] as Vector3) * nr * 1.15,
						Color.WHITE, Color.WHITE, Color.WHITE)
		mt.generate_normals()
		mt.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _metal_material(kind))
	return out


## Grillige straal van de knol in richting `d` (×r0).
static func _bump(d: Vector3, kind: int, variant: int) -> float:
	return 0.82 + 0.36 * fposmod(sin(d.dot(Vector3(5.3, 9.1, 7.7)) * 3.7 + kind * 1.3 + variant * 2.1) * 43758.5453, 1.0)


## Driehoeken van een icosaëder (eenheidsbol), `subdiv` keer verdeeld.
static func _ico_faces(subdiv: int) -> Array:
	var t := 1.618034
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var idx := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var faces: Array = []
	for f: Array in idx:
		faces.append([(v[f[0]] as Vector3).normalized(), (v[f[1]] as Vector3).normalized(), (v[f[2]] as Vector3).normalized()])
	for k in subdiv:
		var next: Array = []
		for f: Array in faces:
			var a: Vector3 = f[0]
			var b: Vector3 = f[1]
			var c: Vector3 = f[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			next.append([a, ab, ca])
			next.append([ab, b, bc])
			next.append([ca, bc, c])
			next.append([ab, bc, ca])
		faces = next
	return faces


static func _shard(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, radius: float, twist: float, shade: float) -> void:
	var up := dir
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	var ring_lo: Array[Vector3] = []
	var ring_hi: Array[Vector3] = []
	for k in 6:
		var a := twist + k * TAU / 6.0
		var off := (side * cos(a) + fwd * sin(a)) * radius
		ring_lo.append(base + off)
		ring_hi.append(base + up * length * 0.78 + off * 0.92)
	var tip := base + up * length
	var col_lo := Color(shade * 0.55, shade * 0.55, shade * 0.55)
	var col_hi := Color(shade, shade, shade)
	for k in 6:
		var n := (k + 1) % 6
		# Zijvlak (twee driehoeken) en de punt.
		_tri(st, ring_lo[k], ring_hi[k], ring_hi[n], col_lo, col_hi, col_hi)
		_tri(st, ring_lo[k], ring_hi[n], ring_lo[n], col_lo, col_hi, col_lo)
		_tri(st, ring_hi[k], tip, ring_hi[n], col_hi, Color.WHITE, col_hi)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)
