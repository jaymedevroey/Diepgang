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
const COLORS: Array[Color] = [
	Color(0.95, 0.5, 0.22), # koper: oranjebruin
	Color(0.78, 0.2, 0.16), # ijzer: roestrood (hematiet)
	Color(0.82, 0.86, 0.92), # zilver
	Color(0.3, 0.9, 1.0), # lichtkristal: cyaan, gloeit
]
const GLOW: Array[float] = [0.35, 0.3, 0.45, 2.2]
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


static func material(kind: Kind) -> Material:
	if not _materials.has(kind):
		var m := StandardMaterial3D.new()
		m.albedo_color = COLORS[kind]
		m.metallic = 0.55 if kind != Kind.LICHTKRISTAL else 0.1
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = COLORS[kind]
		m.emission_energy_multiplier = GLOW[kind]
		m.rim_enabled = true
		m.rim = 0.6
		m.vertex_color_use_as_albedo = true
		_materials[kind] = m
	return _materials[kind]


## 6–9 zeshoekige naalden met een punt, uit een gemeenschappelijke voet, in alle richtingen (een ster):
## zo steken er altijd naalden uit de wand, aan welke kant je de cluster ook vrijgraaft (binnen-03).
## Oorsprong = voet (in de rots); de punten steken ±0,35–0,6 m uit.
static func _build(kind: Kind, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = kind * 101 + variant * 7 + 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rng.randi_range(6, 9)
	for i in count:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.8, 1.0), rng.randf_range(-1, 1)).normalized()
		var length := rng.randf_range(0.28, 0.6) * (1.25 if i == 0 else 1.0)
		var radius := length * rng.randf_range(0.14, 0.22)
		var base := Vector3(rng.randf_range(-0.08, 0.08), -0.05, rng.randf_range(-0.08, 0.08))
		_shard(st, base, dir, length, radius, rng.randf() * TAU, rng.randf_range(0.75, 1.0))
	st.generate_normals()
	return st.commit()


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
