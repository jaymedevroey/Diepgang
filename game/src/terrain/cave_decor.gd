class_name CaveDecor
extends Node3D
## Wat er in de grotten uit de seed groeit (release-audit binnen-01/02/08, golf 3 binnen2-06: "één
## recept, overal hetzelfde"). Per planeet en per laag een eigen set, met een eigen silhouet:
##   Roestbol      klei: paddenstoelen met gloeiende lamellen op de vloer, gloeidraden aan het plafond
##                 zandsteen: hoge parasolzwammen
##   Fossielwereld klei (krijt): konzoolzwammen tegen de wanden en witte zoutkorsten
##                 zandsteen: parasolzwammen en zoutkorsten
##   Kristalmaan   klei en zandsteen: roze kristalscherven en roze gloeidraden
##   graniet       (overal) halve kwartsgeodes in de wand, met een zweem van het accent
##   kristallaag   (overal) grote kristallen die de rots aanlichten
## Plus aan elk plafond druipsteentjes in de kleur van de laag (geen zwarte punten meer), en een paar
## echte lampjes (zonder schaduw, kort bereik) bij wat gloeit. De modellen komen uit setpieces.glb
## (tools/blender/setpieces.py: Decor_*); kristal en druipsteen zijn hier procedureel.
##
## Enkel beeld, op elke peer zelf uit de seed (geen netwerk). Per grot pas gebouwd als de camera in
## de buurt komt, en weer weg als ze ver weg is. Wat op een plek staat die weggegraven is, valt weg
## (TerrainAPI.dug): terrein kan enkel weggenomen worden, dus wat weg is, komt niet terug.
##
## Referenties (ter goedkeuring van Jayme): Deep Rock Galactic (Fungus Bogs: lichtgevende zwammen
## als enige licht; Crystalline Caverns: kristallen die uit de wand groeien en de rots aanlichten),
## Astroneer (kleine gloeiende planten in grotten, low-poly, verzadigd), de gloeiwormgrotten van
## Waitomo (draden met lichtjes aan het plafond), konzoolzwammen op dood hout, seleniet en zoutkorsten
## in kalksteengrotten, en echte druipsteen (dunne rietjes en kegels aan het plafond).

const BUILD_M := 55.0 # grot bouwen als de camera zo dicht bij haar rand komt
const FREE_M := 95.0
const CHECK_S := 0.4
const DRAW_M := 70.0
const MAX_LIGHTS := 2 # per grot
const DECOR_SHADER := preload("res://src/terrain/cave_decor.gdshader")
const MESH_SHADER := preload("res://src/terrain/cave_decor_mesh.gdshader")
const MODEL := preload("res://assets/models/setpieces.glb")

enum Kind { FUNGUS, CRYSTAL, STRAW, PARASOL, BRACKET, THREADS, GEODE, SALT }
## Model in setpieces.glb per soort ("" = procedureel).
const MESH_NAMES := {Kind.FUNGUS: "Decor_Mushroom", Kind.PARASOL: "Decor_Parasol", Kind.BRACKET: "Decor_Bracket",
		Kind.THREADS: "Decor_Threads", Kind.GEODE: "Decor_Geode", Kind.SALT: "Decor_Salt"}
## Wat gloeit (en dus een lampje mag krijgen).
const GLOWS := [Kind.FUNGUS, Kind.CRYSTAL, Kind.PARASOL, Kind.BRACKET, Kind.THREADS, Kind.GEODE]

var terrain: TerrainAPI
## De langste bouwtijd van één grot (ms), voor de prestatiecontrole.
var build_ms_max := 0.0
var _caverns: Array[Vector4] = [] # wereld: midden, horizontale straal
var _built := {} # index -> Node3D
var _items := {} # index -> Array[[kind, instance, anchor, normal, light, multimesh]]
var _timer := 0.0
var _meshes := {}
var _mats := {}
static var _glb := {}


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
			var t0 := Time.get_ticks_usec()
			_build(i)
			build_ms_max = maxf(build_ms_max, (Time.get_ticks_usec() - t0) / 1000.0)
			built_one = true # één grot per keer: geen hapering


# --- Recepten ------------------------------------------------------------------------------------

## De set van een grot: groepen {kind, where (floor/wall/ceil), clusters, per (stuks per groepje),
## size (m), spread (m), color}. Per planeet en laag een eigen recept (zie de uitleg bovenaan).
func _recipe(planet: int, layer: Strata.Layer, radius: float, rng: RandomNumberGenerator) -> Array:
	var glow := Underground.fungus(planet)
	var extra := int(radius / 6.0)
	var out: Array = []
	match layer:
		Strata.Layer.KLEI, Strata.Layer.ZANDSTEEN:
			var sand := layer == Strata.Layer.ZANDSTEEN
			match planet:
				1:
					out.append({"kind": Kind.BRACKET if not sand else Kind.PARASOL, "where": "wall" if not sand else "floor",
							"clusters": rng.randi_range(2, 3) + extra, "per": [3, 6], "size": [0.35, 0.8] if not sand else [0.5, 1.0], "spread": 1.2, "color": glow})
					out.append({"kind": Kind.SALT, "where": "wall", "clusters": rng.randi_range(2, 4) + extra, "per": [2, 4],
							"size": [0.5, 1.1], "spread": 0.9, "color": Color(0.95, 0.95, 0.92)})
				2:
					out.append({"kind": Kind.CRYSTAL, "where": "floor", "clusters": rng.randi_range(2, 3) + extra, "per": [5, 9],
							"size": [0.3, 0.6], "spread": 0.8, "color": glow})
					out.append({"kind": Kind.THREADS, "where": "ceil", "clusters": rng.randi_range(2, 3) + extra, "per": [3, 6],
							"size": [0.7, 1.5], "spread": 1.0, "color": glow})
				_:
					if sand:
						out.append({"kind": Kind.PARASOL, "where": "floor", "clusters": rng.randi_range(2, 3) + extra, "per": [3, 5],
								"size": [0.5, 1.1], "spread": 1.3, "color": glow})
						out.append({"kind": Kind.FUNGUS, "where": "floor", "clusters": rng.randi_range(1, 2), "per": [3, 6],
								"size": [0.2, 0.45], "spread": 1.0, "color": glow})
					else:
						out.append({"kind": Kind.FUNGUS, "where": "floor", "clusters": rng.randi_range(2, 3) + extra, "per": [4, 8],
								"size": [0.2, 0.6], "spread": 1.3, "color": glow})
						out.append({"kind": Kind.THREADS, "where": "ceil", "clusters": rng.randi_range(2, 3) + extra, "per": [4, 7],
								"size": [0.7, 1.6], "spread": 1.1, "color": glow.lerp(Color(0.5, 0.9, 1.0), 0.4)})
		Strata.Layer.GRANIET:
			out.append({"kind": Kind.GEODE, "where": "wall", "clusters": rng.randi_range(2, 3) + extra, "per": [1, 3],
					"size": [0.5, 1.1], "spread": 1.2, "color": Underground.color(planet, "accent", 0).lerp(Color.WHITE, 0.45)})
		_:
			out.append({"kind": Kind.CRYSTAL, "where": "any", "clusters": rng.randi_range(4, 6) + extra, "per": [5, 10],
					"size": [0.7, 1.3], "spread": 1.1, "color": Underground.color(planet, "accent", 0), "big": true})
	return out


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
	var lights := 0
	var mms := {} # kind -> [xfs, cols]
	for grp: Dictionary in _recipe(planet, layer, c.w, rng):
		var kind: Kind = grp.kind
		if not mms.has(kind):
			mms[kind] = [[] as Array[Transform3D], []]
		var xfs: Array[Transform3D] = mms[kind][0]
		var col: Color = grp.color
		for k in int(grp.clusters):
			var y := 0.0
			match String(grp.where):
				"floor":
					y = rng.randf_range(-0.95, -0.45)
				"wall":
					y = rng.randf_range(-0.4, 0.35)
				"ceil":
					y = rng.randf_range(0.6, 1.0)
				_:
					y = rng.randf_range(-0.75, 0.55)
			var dir := _rand_dir(rng, y)
			var hit := _surface(gen, shapes, center / vs, dir, c.w / vs * 2.2)
			var count := rng.randi_range(int(grp.per[0]), int(grp.per[1]))
			var parts: Array = []
			for j in count:
				parts.append([rng.randf(), rng.randf(), rng.randf(), rng.randf()])
			if hit.is_empty() or not _still_rock(hit[0], hit[1]):
				continue
			var a: Vector3 = hit[0]
			var n: Vector3 = hit[1]
			if String(grp.where) == "ceil" and n.y > -0.3:
				continue # gloeidraden hangen enkel aan een plafond
			var light := -1
			if lights < MAX_LIGHTS and kind in GLOWS:
				light = _add_light(root, a + n * 0.7, col, grp.has("big"))
				lights += 1
			var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
			var t2 := n.cross(t1)
			var spread: float = grp.spread
			for part: Array in parts:
				var ang := float(part[0]) * TAU
				var rad := sqrt(float(part[1])) * spread
				var off := (t1 * cos(ang) + t2 * sin(ang)) * rad
				var s := lerpf(float(grp.size[0]), float(grp.size[1]), float(part[2]))
				var pos := a + off - n * 0.05
				var basis := _orient(kind, n, off, float(part[3]))
				if kind == Kind.CRYSTAL:
					s *= 1.5 if part == parts[0] else 1.0
				if kind == Kind.THREADS:
					pos = a + off + n * 0.02
				xfs.append(Transform3D(basis.scaled_local(Vector3.ONE * s), pos))
				(mms[kind][1] as Array).append(col.lightened(float(part[2]) * 0.2))
				items.append([kind, xfs.size() - 1, a, n, light])
	# Druipsteentjes aan het plafond (dunne kegels die de voxels niet kunnen tonen).
	var straw_xf: Array[Transform3D] = []
	for k in rng.randi_range(4, 6) + int(c.w / 3.0):
		var dir := _rand_dir(rng, rng.randf_range(0.55, 1.0))
		var hit := _surface(gen, shapes, center / vs, dir, c.w / vs * 2.2)
		var length := rng.randf_range(0.35, 1.4)
		var spin := rng.randf() * TAU
		if hit.is_empty() or (hit[1] as Vector3).y > -0.45 or not _still_rock(hit[0], hit[1]):
			continue
		var a: Vector3 = hit[0]
		var basis := Basis(Vector3.UP, spin).scaled(Vector3(length * 0.2, length, length * 0.2))
		straw_xf.append(Transform3D(basis, a + Vector3.UP * 0.1))
		items.append([Kind.STRAW, straw_xf.size() - 1, a, hit[1], -1])
	var by_kind := {}
	for kind: Kind in mms:
		by_kind[kind] = _multimesh(root, kind, mms[kind][0], PackedColorArray(mms[kind][1] as Array), layer)
	by_kind[Kind.STRAW] = _multimesh(root, Kind.STRAW, straw_xf, PackedColorArray(), layer)
	for it: Array in items:
		it.append(by_kind[it[0]])


## Hoe een stuk staat: zwammen groeien omhoog (wat naar de normaal), gloeidraden hangen recht naar
## beneden, konzoolzwammen liggen als planken tegen de wand, de rest volgt de normaal.
static func _orient(kind: Kind, n: Vector3, off: Vector3, r: float) -> Basis:
	match kind:
		Kind.FUNGUS, Kind.PARASOL:
			return _basis_up((n + Vector3.UP * 1.6).normalized()) * Basis(Vector3.UP, r * TAU)
		Kind.THREADS:
			return Basis(Vector3.RIGHT, PI) * Basis(Vector3.UP, r * TAU)
		Kind.BRACKET:
			# y = uit de wand, z = omhoog langs de wand: de planken liggen horizontaal.
			var yv := Vector3(n.x, 0.0, n.z).normalized() if Vector2(n.x, n.z).length() > 0.2 else Vector3.FORWARD
			var zv := Vector3.UP
			return Basis(yv.cross(zv).normalized(), yv, zv)
		Kind.CRYSTAL:
			# Kristallen staan schuin uit de wand, in een waaier.
			var up := (n * 1.2 + off.normalized() * lerpf(0.2, 0.9, r)).normalized() if off.length() > 0.01 else n
			return _basis_up(up) * Basis(Vector3.UP, r * TAU)
	return _basis_up(n) * Basis(Vector3.UP, r * TAU)


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
	l.light_energy = 1.6 if big else 1.0
	l.omni_range = 7.0 if big else 5.0
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


func _multimesh(root: Node3D, kind: Kind, xfs: Array[Transform3D], cols: PackedColorArray, layer: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = _mesh(kind, layer)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not MESH_NAMES.has(kind):
		mmi.material_override = _material(kind, layer)
	mmi.visibility_range_end = DRAW_M
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind in [Kind.STRAW, Kind.FUNGUS, Kind.PARASOL] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	return mm


## Plekken van gloeiende groepjes in de gebouwde grotten, dichtste eerst: [[plek, normaal], ...].
## Voor previews en tests.
func glow_anchors(near: Vector3) -> Array:
	var out: Array = []
	for i: int in _items:
		for it: Array in _items[i]:
			if it[0] in GLOWS and it[5] != null:
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

## De mesh per soort; die uit setpieces.glb krijgen hun materialen per oppervlak (per laag: de
## schil van een geode in de donkere kleur van de laag).
func _mesh(kind: Kind, layer: int) -> Mesh:
	var key := "%d/%d" % [kind, layer]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match kind:
		Kind.CRYSTAL:
			m = _crystal_mesh()
		Kind.STRAW:
			m = _straw_mesh()
		_:
			var src: Mesh = _glb_mesh(MESH_NAMES[kind])
			var copy := src.duplicate() as ArrayMesh
			for s in copy.get_surface_count():
				var sm := copy.surface_get_material(s)
				copy.surface_set_material(s, _surface_material(sm.resource_name if sm else "", layer))
			m = copy
	_meshes[key] = m
	return m


static func _glb_mesh(name: String) -> Mesh:
	if _glb.is_empty():
		var root := MODEL.instantiate()
		for mi: MeshInstance3D in root.find_children("Decor_*", "MeshInstance3D", true, false):
			_glb[mi.name] = mi.mesh
		root.free()
	return _glb[name]


## Materiaal per oppervlak van het decor uit setpieces.glb (cave_decor_mesh.gdshader).
func _surface_material(name: String, layer: int) -> Material:
	var key := "s/%s/%d" % [name, layer]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = MESH_SHADER
	match name:
		"FungusCap":
			# Mat en gekleurd, nauwelijks gloed: de hoed leest als zwam.
			m.set_shader_parameter("base", Color(0.24, 0.2, 0.18))
			m.set_shader_parameter("tint_albedo", 0.3)
			m.set_shader_parameter("glow", 0.03)
			m.set_shader_parameter("rough", 0.75)
		"FungusGlow":
			m.set_shader_parameter("base", Color(0.5, 0.5, 0.5))
			m.set_shader_parameter("tint_albedo", 1.0)
			m.set_shader_parameter("glow", 1.7)
			m.set_shader_parameter("rough", 0.5)
		"FungusStem":
			m.set_shader_parameter("base", Color(0.72, 0.67, 0.58))
			m.set_shader_parameter("tint_albedo", 0.15)
			m.set_shader_parameter("glow", 0.06)
			m.set_shader_parameter("rough", 0.85)
		"Quartz":
			m.set_shader_parameter("base", Color(0.88, 0.87, 0.84))
			m.set_shader_parameter("tint_albedo", 0.2)
			m.set_shader_parameter("glow", 0.35)
			m.set_shader_parameter("rough", 0.12)
			m.set_shader_parameter("rim_k", 1.0)
		"GeodeRind":
			var d := Underground.color(terrain.planet, "dark", layer)
			m.set_shader_parameter("base", d)
			m.set_shader_parameter("rough", 0.95)
		"Salt":
			m.set_shader_parameter("base", Color(0.93, 0.92, 0.88))
			m.set_shader_parameter("rough", 0.55)
			m.set_shader_parameter("rim_k", 0.3)
		_:
			m.set_shader_parameter("base", Color(0.6, 0.6, 0.6))
	_mats[key] = m
	return m


func _material(kind: Kind, layer: int) -> Material:
	var key := "%d/%d" % [kind, layer]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if kind == Kind.STRAW:
		# Druipsteen in de kleur van de laag (lichter dan de wand: kalk), van beide kanten getekend:
		# zwarte punten op een licht plafond lazen als gaten (binnen2-06, binnen2-12).
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Underground.color(terrain.planet, "base", layer).lerp(Underground.color(terrain.planet, "light", layer), 0.55)
		sm.roughness = 0.75
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		m = sm
	else:
		var sh := ShaderMaterial.new()
		sh.shader = DECOR_SHADER
		sh.set_shader_parameter("glow", Color(0, 0, 0))
		sh.set_shader_parameter("energy", 2.6)
		sh.set_shader_parameter("rough", 0.08)
		sh.set_shader_parameter("rim_k", 1.0)
		m = sh
	_mats[key] = m
	return m


## Een basis waarvan de y-as naar `up` wijst (ook recht naar beneden).
static func _basis_up(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up.normalized()))


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
			_tri(st, p00, p11, p01, Color.WHITE)
			_tri(st, p00, p10, p11, Color.WHITE)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
