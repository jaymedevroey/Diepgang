class_name CaveDecor
extends Node3D
## Wat er in de grotten uit de seed groeit (release-audit binnen-01/02/08): gloeiende zwammen (of
## kristalscherven op de Kristalmaan) in de klei en het zandsteen, kwartsgeodes in het graniet, grote
## kristallen in de kristallaag, en dunne druipsteentjes aan elk plafond. Met een paar echte lampjes
## (zonder schaduw, kort bereik): zo heeft een grot een eigen lichtbron, en zie je hem als grot.
##
## Enkel beeld, op elke peer zelf uit de seed (geen netwerk). Per grot pas gebouwd als de camera in
## de buurt komt, en weer weg als ze ver weg is. Wat op een plek staat die weggegraven is, valt weg
## (TerrainAPI.dug): terrein kan enkel weggenomen worden, dus wat weg is, komt niet terug.
##
## Referenties (ter goedkeuring van Jayme): Deep Rock Galactic (Fungus Bogs: lichtgevende zwammen
## als enige licht; Crystalline Caverns: kristallen die uit de wand groeien en de rots aanlichten),
## Astroneer (kleine gloeiende planten in grotten, low-poly, verzadigd), echte druipsteen (dunne
## rietjes en kegels aan het plafond), de kristallen van Naica.

const BUILD_M := 55.0 # grot bouwen als de camera zo dicht bij haar rand komt
const FREE_M := 95.0
const CHECK_S := 0.4
const DRAW_M := 70.0
const MAX_LIGHTS := 2 # per grot
const DECOR_SHADER := preload("res://src/terrain/cave_decor.gdshader")

enum Kind { FUNGUS, CRYSTAL, STRAW }

var terrain: TerrainAPI
var _caverns: Array[Vector4] = [] # wereld: midden, horizontale straal
var _built := {} # index -> Node3D
var _items := {} # index -> Array[[kind, multimesh, instance, anchor, normal, light]]
var _timer := 0.0
var _meshes := {}
var _mats := {}


func setup(t: TerrainAPI) -> void:
	terrain = t
	_caverns = t.caverns()
	t.dug.connect(_on_dug)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or terrain == null or not terrain.is_inside_tree():
		return
	_timer = CHECK_S
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var built_one := false
	for i in _caverns.size():
		var c := _caverns[i]
		var d := p.distance_to(Vector3(c.x, c.y, c.z)) - c.w
		if _built.has(i):
			if d > FREE_M:
				(_built[i] as Node3D).queue_free()
				_built.erase(i)
				_items.erase(i)
		elif d < BUILD_M and not built_one and terrain.data_loaded(Vector3(c.x, c.y, c.z)):
			_build(i)
			built_one = true # één grot per keer: geen hapering


# --- Bouwen -------------------------------------------------------------------------------------

func _build(index: int) -> void:
	var c := _caverns[index]
	var center := Vector3(c.x, c.y, c.z)
	var gen := terrain._generator
	var vs := TerrainAPI.VOXEL_SIZE
	var shapes := gen.local_shapes(center / vs, c.w / vs + 6.0)
	var layer := terrain.layer_at(center)
	var planet := terrain.planet
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain.pit_seed * 7349 + index * 131 + 17
	var root := Node3D.new()
	root.name = "Cave%d" % index
	add_child(root)
	_built[index] = root
	var items: Array = []
	_items[index] = items

	var glow_kind := Kind.FUNGUS
	var glow_col := Underground.fungus(planet)
	var clusters := 0
	var crystal_size := 0.0
	match layer:
		Strata.Layer.KLEI, Strata.Layer.ZANDSTEEN:
			clusters = rng.randi_range(2, 3) + int(c.w / 6.0)
			if planet == 2:
				glow_kind = Kind.CRYSTAL # Kristalmaan: kristalscherven in plaats van zwammen
				crystal_size = 0.45
		Strata.Layer.GRANIET:
			glow_kind = Kind.CRYSTAL
			glow_col = Underground.color(planet, "accent", 0).lerp(Color.WHITE, 0.55) # bleke kwarts met een zweem
			clusters = rng.randi_range(1, 3)
			crystal_size = 0.35
		_:
			glow_kind = Kind.CRYSTAL
			glow_col = Underground.color(planet, "accent", 0)
			clusters = rng.randi_range(4, 6) + int(c.w / 6.0)
			crystal_size = 0.9

	var glow_xf: Array[Transform3D] = []
	var glow_cols := PackedColorArray()
	var straw_xf: Array[Transform3D] = []
	var lights := 0
	# Gloeiende groepjes: vooral onderaan de wanden en in de hoeken van de vloer, wat aan het plafond.
	for k in clusters:
		var dir := _rand_dir(rng, rng.randf_range(-0.75, 0.55))
		var hit := _surface(gen, shapes, center / vs, dir, c.w / vs * 2.2)
		var size := rng.randf_range(0.7, 1.3)
		var count := rng.randi_range(5, 10)
		var spread := rng.randf_range(0.5, 1.0) * (1.2 if glow_kind == Kind.CRYSTAL else 1.6) * maxf(crystal_size, 0.6)
		var parts: Array = []
		for j in count:
			parts.append([rng.randf(), rng.randf(), rng.randf(), rng.randf()])
		if hit.is_empty() or not _still_rock(hit[0], hit[1]):
			continue
		var a: Vector3 = hit[0]
		var n: Vector3 = hit[1]
		var light := -1
		if lights < MAX_LIGHTS:
			light = _add_light(root, a + n * 0.6, glow_col, glow_kind == Kind.CRYSTAL and crystal_size > 0.5)
			lights += 1
		var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2 := n.cross(t1)
		for part: Array in parts:
			var ang := float(part[0]) * TAU
			var rad := sqrt(float(part[1])) * spread
			var pos := a + (t1 * cos(ang) + t2 * sin(ang)) * rad - n * 0.04
			var s := size * lerpf(0.5, 1.2, float(part[2]))
			var up := n
			if glow_kind == Kind.CRYSTAL:
				# Kristallen staan schuin uit de wand, in een waaier.
				up = (n * 1.2 + (t1 * cos(ang) + t2 * sin(ang)) * lerpf(0.2, 0.9, float(part[3]))).normalized()
				s *= crystal_size * (1.6 if part == parts[0] else 1.0)
			else:
				s *= 0.5 # zwammen: hoed van 15-75 cm (gestileerd groot, zoals in DRG)
			var basis := _basis_up(up) * Basis(Vector3.UP, float(part[3]) * TAU)
			glow_xf.append(Transform3D(basis.scaled_local(Vector3.ONE * s), pos))
			glow_cols.append(glow_col.lightened(float(part[2]) * 0.25))
			items.append([glow_kind, glow_xf.size() - 1, a, n, light])
	# Druipsteentjes aan het plafond (dunne kegels die de voxels niet kunnen tonen).
	for k in rng.randi_range(4, 6) + int(c.w / 3.0):
		var dir := _rand_dir(rng, rng.randf_range(0.55, 1.0))
		var hit := _surface(gen, shapes, center / vs, dir, c.w / vs * 2.2)
		var length := rng.randf_range(0.35, 1.4)
		var spin := rng.randf() * TAU
		if hit.is_empty() or (hit[1] as Vector3).y > -0.45 or not _still_rock(hit[0], hit[1]):
			continue
		var a: Vector3 = hit[0]
		var basis := Basis(Vector3.UP, spin).scaled(Vector3(length * 0.16, length, length * 0.16))
		straw_xf.append(Transform3D(basis, a + Vector3.UP * 0.1))
		items.append([Kind.STRAW, straw_xf.size() - 1, a, hit[1], -1])

	var glow_mm := _multimesh(root, glow_kind, glow_xf, glow_cols, glow_col)
	var straw_mm := _multimesh(root, Kind.STRAW, straw_xf, PackedColorArray(), Underground.color(planet, "base", layer).lerp(Underground.color(planet, "light", layer), 0.3))
	for it: Array in items:
		it.append(glow_mm if it[0] != Kind.STRAW else straw_mm)


## Een richting met een gegeven y (-1 = recht naar beneden .. 1 = recht naar boven).
static func _rand_dir(rng: RandomNumberGenerator, y: float) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(maxf(0.0, 1.0 - y * y))
	return Vector3(cos(a) * r, y, sin(a) * r)


## De wand van de grot in richting `dir` vanuit `from` (voxels), uit de SDF van de generator
## (sphere tracing, dan halveren). [plek (wereld), normaal (wereld)] of [] als er niets is.
func _surface(gen: PlanetGenerator, shapes: Array, from: Vector3, dir: Vector3, max_t: float) -> Array:
	var t := 0.0
	var prev := 0.0
	var s := gen.sdf_local(from, shapes)
	if s < 0.0:
		return []
	var found := false
	for i in 48:
		prev = t
		t += maxf(s * 0.8, 0.4)
		if t > max_t:
			return []
		s = gen.sdf_local(from + dir * t, shapes)
		if s < 0.0:
			found = true
			break
	if not found:
		return []
	var lo := prev
	var hi := t
	for i in 6:
		var mid := (lo + hi) * 0.5
		if gen.sdf_local(from + dir * mid, shapes) < 0.0:
			hi = mid
		else:
			lo = mid
	var p := from + dir * hi
	var e := 0.5
	var grad := Vector3(
		gen.sdf_local(p + Vector3(e, 0, 0), shapes) - gen.sdf_local(p - Vector3(e, 0, 0), shapes),
		gen.sdf_local(p + Vector3(0, e, 0), shapes) - gen.sdf_local(p - Vector3(0, e, 0), shapes),
		gen.sdf_local(p + Vector3(0, 0, e), shapes) - gen.sdf_local(p - Vector3(0, 0, e), shapes))
	if grad.length() < 1e-4:
		return []
	return [p * TerrainAPI.VOXEL_SIZE, grad.normalized()]


## Is de plek nog rots (niet weggegraven)? Zolang de data er niet is, gaan we uit van de seed.
func _still_rock(anchor: Vector3, normal: Vector3) -> bool:
	var q := anchor - normal * 0.2
	if not terrain.data_loaded(q):
		return true
	return terrain.sdf_at(q) < 0.05


func _add_light(root: Node3D, pos: Vector3, col: Color, big: bool) -> int:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.6 if big else 0.9
	l.omni_range = 7.0 if big else 4.5
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	l.light_specular = 0.3
	l.light_volumetric_fog_energy = 0.4
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 15.0
	root.add_child(l)
	l.global_position = pos
	return l.get_index()


func _multimesh(root: Node3D, kind: Kind, xfs: Array[Transform3D], cols: PackedColorArray, col: Color) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = _mesh(kind)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _material(kind, col)
	mmi.visibility_range_end = DRAW_M
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind != Kind.STRAW else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mmi)
	return mm


## Plekken van gloeiende groepjes in de gebouwde grotten, dichtste eerst: [[plek, normaal], ...].
## Voor previews en tests.
func glow_anchors(near: Vector3) -> Array:
	var out: Array = []
	for i: int in _items:
		for it: Array in _items[i]:
			if it[0] != Kind.STRAW and it[5] != null:
				out.append([it[2], it[3]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return near.distance_to(a[0]) < near.distance_to(b[0]))
	return out


# --- Weggegraven -----------------------------------------------------------------------------

func _on_dug(world_center: Vector3, radius_m: float) -> void:
	for i: int in _items:
		var c := _caverns[i]
		if world_center.distance_to(Vector3(c.x, c.y, c.z)) > c.w * 1.4 + radius_m + 3.0:
			continue
		var root: Node3D = _built.get(i)
		for it: Array in _items[i]:
			var a: Vector3 = it[2]
			if a.distance_to(world_center) > radius_m + 0.8 or it[5] == null:
				continue
			if terrain.sdf_at(a - (it[3] as Vector3) * 0.15) > 0.05:
				var mm: MultiMesh = it[5]
				mm.set_instance_transform(int(it[1]), Transform3D(Basis().scaled(Vector3.ZERO), a))
				it[5] = null
				var li: int = it[4]
				if li >= 0 and root and li < root.get_child_count():
					(root.get_child(li) as Node3D).visible = false


# --- Meshes en materialen -----------------------------------------------------------------------

func _mesh(kind: Kind) -> ArrayMesh:
	if not _meshes.has(kind):
		match kind:
			Kind.FUNGUS:
				_meshes[kind] = _fungus_mesh()
			Kind.CRYSTAL:
				_meshes[kind] = _crystal_mesh()
			_:
				_meshes[kind] = _straw_mesh()
	return _meshes[kind]


func _material(kind: Kind, col: Color) -> Material:
	var key := "%d/%s" % [kind, col.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if kind == Kind.STRAW:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = col
		sm.roughness = 0.85
		m = sm
	else:
		var sh := ShaderMaterial.new()
		sh.shader = DECOR_SHADER
		sh.set_shader_parameter("glow", col)
		sh.set_shader_parameter("energy", 2.6 if kind == Kind.FUNGUS else 1.9)
		sh.set_shader_parameter("rough", 0.55 if kind == Kind.FUNGUS else 0.08)
		sh.set_shader_parameter("rim_k", 0.0 if kind == Kind.FUNGUS else 1.0)
		m = sh
	_mats[key] = m
	return m


## Een basis waarvan de y-as naar `up` wijst (ook recht naar beneden).
static func _basis_up(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up.normalized()))


## Zwam: een steeltje en een bolle hoed (6 kanten), oorsprong aan de voet, 1 = hoed van ±1 breed.
static func _fungus_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var stem := Color(0.35, 0.33, 0.3, 0.0)
	var cap := Color(0.55, 0.55, 0.55, 0.3) # bovenop: kleur, wat gloed
	var gill := Color(1.0, 1.0, 1.0, 1.0) # onderkant en rand: de felle gloed
	var sides := 8
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.12
		var b1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.12
		var t0 := b0 * 0.8 + Vector3(0, 0.75, 0)
		var t1 := b1 * 0.8 + Vector3(0, 0.75, 0)
		_tri(st, b0, t0, t1, stem)
		_tri(st, b0, t1, b1, stem)
		# Hoed: onderkant (gloeiend), rand, bolle top.
		var r0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.5 + Vector3(0, 0.68, 0)
		var r1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.5 + Vector3(0, 0.68, 0)
		var m0 := Vector3(cos(a0), 0.0, sin(a0)) * 0.36 + Vector3(0, 0.95, 0)
		var m1 := Vector3(cos(a1), 0.0, sin(a1)) * 0.36 + Vector3(0, 0.95, 0)
		var top := Vector3(0, 1.05, 0)
		var under := Vector3(0, 0.74, 0)
		_tri(st, under, r1, r0, gill)
		_tri(st, r0, m1, m0, gill)
		_tri(st, r0, r1, m1, cap)
		_tri(st, m0, m1, top, cap)
	st.generate_normals()
	return st.commit()


## Kristal: een zeskantige staaf met een punt, oorsprong aan de voet (een stukje in de wand), 1 hoog.
static func _crystal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var r := 0.16
	var sides := 6
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var b0 := Vector3(cos(a0) * r, -0.15, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -0.15, sin(a1) * r)
		var t0 := Vector3(cos(a0) * r, 0.72, sin(a0) * r)
		var t1 := Vector3(cos(a1) * r, 0.72, sin(a1) * r)
		var tip := Vector3(0.0, 1.0, 0.0)
		var shade := Color.WHITE.darkened(0.25 * float(k % 3))
		_tri(st, b0, t0, t1, shade.darkened(0.35))
		_tri(st, b0, t1, b1, shade.darkened(0.35))
		_tri(st, t0, tip, t1, shade)
	st.generate_normals()
	return st.commit()


## Druipsteentje: een dunne, licht gebogen kegel naar beneden, oorsprong bovenaan, 1 lang.
static func _straw_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var sides := 5
	var rings := [[0.0, 1.0], [-0.45, 0.6], [-0.8, 0.28], [-1.0, 0.0]]
	for i in rings.size() - 1:
		var y0: float = rings[i][0]
		var y1: float = rings[i + 1][0]
		var w0: float = rings[i][1]
		var w1: float = rings[i + 1][1]
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var p00 := Vector3(cos(a0) * w0, y0, sin(a0) * w0)
			var p01 := Vector3(cos(a1) * w0, y0, sin(a1) * w0)
			var p10 := Vector3(cos(a0) * w1, y1, sin(a0) * w1)
			var p11 := Vector3(cos(a1) * w1, y1, sin(a1) * w1)
			_tri(st, p00, p01, p11, Color.WHITE)
			_tri(st, p00, p11, p10, Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
