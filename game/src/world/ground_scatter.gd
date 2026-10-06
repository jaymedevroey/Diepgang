class_name GroundScatter
extends Node3D
## Klein detail op de grond tot aan je voeten (release-audit golf 3, buiten2-1: "binnen 15 m ligt er
## niets, geen kiezels, scherven of botsplinters"). Per planeet een eigen familie losse stukjes:
## - Roestbol: donker basaltgrind en roodbruine stenen, lichte zandsteenscherven;
## - Fossielwereld: vuursteenknollen, witte krijtplaatjes en ivoren botsplinters;
## - Kristalmaan: donkere basaltsplinters en kristalscherven die van binnen gloeien.
## De grote (vanaf ±20 cm) werpen schaduw: dat geeft de donkere accenten die de grond op ooghoogte
## miste (planeten.md §3.5, de concepten). De shader legt er nog fijner gruis onder (terrain.gdshader
## g4_ground).
##
## Enkel om te zien: geen botsvormen, geen netwerk. Alles hangt af van de seed en de plek, dus elke
## peer ziet hetzelfde. In vakken van CHUNK m over het speelgebied; een vak wordt pas gebouwd als de
## camera binnen BUILD_M komt (een paar vakken per frame, op de hoofdthread: ±40-80 hoogtes per vak),
## en is te zien tot HIDE_M. Graaf je eronder, dan verdwijnen ze (TerrainAPI.dug), ook in vakken die
## later gebouwd worden.

const CHUNK := 12.0
const BUILD_M := 46.0
const HIDE_M := 34.0
const HIDE_SMALL_M := 18.0
## Niet onder de Mol op de landingsplek (daar landt hij en staat de ploeg).
const PAD_CLEAR := 6.5
const PER_FRAME := 2

var terrain: TerrainAPI
var planet := PlanetType.Id.ROESTBOL
var _seed := 0
var _size := Vector3.ZERO
var _landing := Vector2.ZERO
var _kinds: Array[Dictionary] = [] # {mesh, colors: Array[Color], size: Vector2, flat: float, weight, shadows}
var _density := 0.3
var _built: Dictionary = {} # Vector2i -> Array (per soort: [MultiMeshInstance3D, PackedVector3Array])
var _digs: Array[Vector4] = [] # graafacties aan de oppervlakte: x, y, z, straal
var _check := 0.0


func setup(t: TerrainAPI, planet_seed: int, planet_id: PlanetType.Id, landing: Vector2) -> void:
	terrain = t
	_seed = planet_seed
	planet = planet_id
	_size = t.world_size()
	_landing = landing
	_kinds = _families(planet_id)
	_density = [0.42, 0.34, 0.32][clampi(int(planet_id), 0, 2)]
	t.dug.connect(_on_dug)


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0 or terrain == null:
		return
	_check = 0.2
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	if c.x < -BUILD_M or c.z < -BUILD_M or c.x > _size.x + BUILD_M or c.z > _size.z + BUILD_M:
		return
	if absf(c.y - terrain.surface_height_at(clampf(c.x, 0.0, _size.x), clampf(c.z, 0.0, _size.z))) > BUILD_M:
		return # hoog in de lucht (de drop) of diep onder de grond
	var n := 0
	var r := int(ceil(BUILD_M / CHUNK))
	var ci := Vector2i(int(floor(c.x / CHUNK)), int(floor(c.z / CHUNK)))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var k := ci + Vector2i(dx, dz)
			if _built.has(k) or k.x < 0 or k.y < 0 or k.x * CHUNK >= _size.x or k.y * CHUNK >= _size.z:
				continue
			var mid := Vector2((k.x + 0.5) * CHUNK, (k.y + 0.5) * CHUNK)
			if mid.distance_to(Vector2(c.x, c.z)) > BUILD_M + CHUNK * 0.7:
				continue
			_build_chunk(k)
			n += 1
			if n >= PER_FRAME:
				_check = 0.0 # volgende frame verder
				return


## Hoeveel vakken er gebouwd zijn (voor tests en de log).
func built_count() -> int:
	return _built.size()


func _build_chunk(k: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(k.x, k.y, _seed + 7717))
	var per_kind: Array = []
	for i in _kinds.size():
		per_kind.append({"xf": [], "col": [], "pos": PackedVector3Array()})
	# Plekkerig, niet overal even dicht: per vak een paar groepjes rond een kern, plus losse.
	var count := int(CHUNK * CHUNK * _density * rng.randf_range(0.5, 1.5))
	var cores: Array[Vector2] = []
	for i in rng.randi_range(1, 3):
		cores.append(Vector2((k.x + rng.randf()) * CHUNK, (k.y + rng.randf()) * CHUNK))
	for i in count:
		var p: Vector2
		if rng.randf() < 0.65:
			var core: Vector2 = cores[rng.randi() % cores.size()]
			p = core + Vector2.from_angle(rng.randf() * TAU) * (rng.randf() ** 1.6) * 4.5
		else:
			p = Vector2((k.x + rng.randf()) * CHUNK, (k.y + rng.randf()) * CHUNK)
		if p.x < 0.5 or p.y < 0.5 or p.x > _size.x - 0.5 or p.y > _size.z - 0.5:
			continue
		if p.distance_to(_landing) < PAD_CLEAR:
			continue
		var kind := _pick_kind(rng)
		var kd: Dictionary = _kinds[kind]
		var sz: Vector2 = kd.sz
		var s := lerpf(sz.x, sz.y, pow(rng.randf(), 2.6))
		var y := terrain.surface_height_at(p.x, p.y)
		var pos := Vector3(p.x, y, p.y)
		if _dug_at(pos, s):
			continue
		var flat: float = kd.flat
		var sc := Vector3(s * rng.randf_range(0.8, 1.3), s * flat * rng.randf_range(0.7, 1.2), s * rng.randf_range(0.7, 1.1))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35)))
		if kd.get("lean", false):
			b = Basis.from_euler(Vector3(rng.randf_range(-1.1, 1.1), rng.randf() * TAU, rng.randf_range(-0.6, 0.6)))
		var cols: Array = kd.colors
		var col: Color = cols[rng.randi() % cols.size()] * rng.randf_range(0.82, 1.12)
		col.a = 1.0
		(per_kind[kind].xf as Array).append(Transform3D(b.scaled(sc), pos - Vector3(0.0, sc.y * float(kd.sink), 0.0)))
		(per_kind[kind].col as Array).append(col)
		(per_kind[kind].pos as PackedVector3Array).append(pos)
	var out: Array = []
	for i in _kinds.size():
		var xfs: Array = per_kind[i].xf
		if xfs.is_empty():
			out.append(null)
			continue
		var kd: Dictionary = _kinds[i]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kd.mesh
		mm.instance_count = xfs.size()
		for j in xfs.size():
			mm.set_instance_transform(j, xfs[j])
			mm.set_instance_color(j, per_kind[i].col[j])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Scatter_%d_%d_%d" % [k.x, k.y, i]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kd.shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = HIDE_M if kd.shadows else HIDE_SMALL_M
		mmi.visibility_range_end_margin = 4.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		out.append([mmi, per_kind[i].pos])
	_built[k] = out


func _pick_kind(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for kd in _kinds:
		total += float(kd.weight)
	var r := rng.randf() * total
	for i in _kinds.size():
		r -= float(_kinds[i].weight)
		if r <= 0.0:
			return i
	return 0


## Een graafactie aan de oppervlakte: wat erop lag, verdwijnt (ook in vakken die nog komen).
func _on_dug(center: Vector3, radius_m: float) -> void:
	if terrain == null or center.y + radius_m < terrain.surface_height_at(center.x, center.z) - 0.6:
		return # onder de grond: raakt het oppervlak niet
	_digs.append(Vector4(center.x, center.y, center.z, radius_m))
	var k0 := Vector2i(int(floor((center.x - radius_m - 1.0) / CHUNK)), int(floor((center.z - radius_m - 1.0) / CHUNK)))
	var k1 := Vector2i(int(floor((center.x + radius_m + 1.0) / CHUNK)), int(floor((center.z + radius_m + 1.0) / CHUNK)))
	for kz in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var key := Vector2i(kx, kz)
			if not _built.has(key):
				continue
			for entry: Variant in _built[key]:
				if entry == null:
					continue
				var mmi: MultiMeshInstance3D = entry[0]
				var pos: PackedVector3Array = entry[1]
				for j in pos.size():
					if _in_dig(pos[j], 0.3, Vector4(center.x, center.y, center.z, radius_m)):
						mmi.multimesh.set_instance_transform(j, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), pos[j] + Vector3.DOWN * 40.0))


func _dug_at(p: Vector3, s: float) -> bool:
	for d in _digs:
		if _in_dig(p, s, d):
			return true
	return false


static func _in_dig(p: Vector3, s: float, d: Vector4) -> bool:
	return Vector2(p.x - d.x, p.z - d.z).length() < d.w + s + 0.3 and p.y > d.y - d.w - 1.0


## De familie per planeet: meshes, kleuren (sRGB, uit PlanetType.ground), maten (m), hoe plat, hoe
## vaak, en of ze schaduw werpen.
static func _families(id: PlanetType.Id) -> Array[Dictionary]:
	var g := PlanetType.ground(id)
	var a: Color = g.get("g4_peb_a", Color(0.3, 0.25, 0.2))
	var b: Color = g.get("g4_peb_b", Color(0.6, 0.5, 0.4))
	var rock: Color = g.get("g4_rock", g.rock)
	var stone := _material()
	var out: Array[Dictionary] = []
	match id:
		PlanetType.Id.FOSSIELWERELD:
			out.append({"mesh": _rock(5101, 0.7, 1.2, stone), "colors": [a, a.darkened(0.15)], "sz": Vector2(0.05, 0.22),
					"flat": 0.75, "weight": 3.0, "shadows": false, "sink": 0.3})
			out.append({"mesh": _rock(5102, 0.8, 1.1, stone), "colors": [b, rock], "sz": Vector2(0.08, 0.5),
					"flat": 0.32, "weight": 2.0, "shadows": true, "sink": 0.25})
			out.append({"mesh": _splinter(stone), "colors": [Color.html("E8DCC0"), Color.html("D9C9A6")], "sz": Vector2(0.12, 0.55),
					"flat": 1.0, "weight": 1.0, "shadows": true, "sink": 0.35, "lean": true})
		PlanetType.Id.KRISTALMAAN:
			out.append({"mesh": _rock(5201, 0.6, 1.3, stone), "colors": [a, rock], "sz": Vector2(0.05, 0.4),
					"flat": 0.6, "weight": 3.0, "shadows": true, "sink": 0.3})
			out.append({"mesh": _shard(), "colors": [Color(1, 1, 1), Color(0.85, 0.9, 1.0)], "sz": Vector2(0.08, 0.32),
					"flat": 1.0, "weight": 1.2, "shadows": false, "sink": 0.2, "lean": true})
		_:
			out.append({"mesh": _rock(5001, 0.6, 1.25, stone), "colors": [a, a.lightened(0.08), rock], "sz": Vector2(0.05, 0.55),
					"flat": 0.62, "weight": 3.0, "shadows": true, "sink": 0.3})
			out.append({"mesh": _rock(5002, 0.85, 1.1, stone), "colors": [b, b.darkened(0.1)], "sz": Vector2(0.06, 0.3),
					"flat": 0.3, "weight": 1.6, "shadows": false, "sink": 0.2})
	return out


static func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true # de kleuren per stuk zijn sRGB (anders roze-wit)
	m.roughness = 0.9
	return m


static func _rock(rock_seed: int, low: float, high: float, mat: Material) -> ArrayMesh:
	var mesh := SurfaceDressing.rock_mesh(rock_seed, low, high)
	mesh.surface_set_material(0, mat)
	return mesh


## Een botsplinter: een langwerpige, iets gebogen staaf (ivoor), schuin in de grond.
static func _splinter(mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var ring := 5
	var rows := [Vector3(0.0, -0.5, 0.0), Vector3(0.03, -0.15, 0.0), Vector3(0.05, 0.2, 0.0), Vector3(0.02, 0.5, 0.0)]
	var radii := [0.09, 0.12, 0.1, 0.05]
	var pts: Array = []
	for r in rows.size():
		var row: Array = []
		for i in ring:
			var a := TAU * i / ring
			row.append(rows[r] + Vector3(cos(a), 0.0, sin(a)) * radii[r] * (0.85 + 0.3 * float((i * 7 + r * 3) % 5) / 4.0))
		pts.append(row)
	for r in rows.size() - 1:
		for i in ring:
			var a: Vector3 = pts[r][i]
			var b: Vector3 = pts[r][(i + 1) % ring]
			var c: Vector3 = pts[r + 1][(i + 1) % ring]
			var d: Vector3 = pts[r + 1][i]
			for v in [a, c, b, a, d, c]:
				st.add_vertex(v)
	for i in range(1, ring - 1): # dop bovenaan
		for v in [pts[rows.size() - 1][0], pts[rows.size() - 1][i], pts[rows.size() - 1][i + 1]]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Een kristalscherf: een zeskantige staaf met een punt, in het kristalmateriaal (gloeit van binnen).
static func _shard() -> ArrayMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.22
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.append_from(cm, 0, Transform3D(Basis(), Vector3(0.0, 0.4, 0.0)))
	st.generate_normals()
	var mesh := st.commit()
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/world/kristal_crystal.gdshader")
	var sr: Vector3 = PlanetType.params(PlanetType.Id.KRISTALMAAN).sun_rotation_deg
	m.set_shader_parameter("to_sun", Basis.from_euler(Vector3(deg_to_rad(sr.x), deg_to_rad(sr.y), deg_to_rad(sr.z))).z)
	mesh.surface_set_material(0, m)
	return mesh
