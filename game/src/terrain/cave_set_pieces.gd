class_name CaveSetPieces
extends Node3D
## Set pieces in de grotten (golf 3, release-audit binnen-01 en binnen2-06; GDD §4: "rommel van
## vorige bezoekers", buit rond grotten). Een grot wordt zo een plek waar je naartoe wil:
##   kamp        een verlaten DIG-kamp: tent, werflamp die nog hapert, kisten, klaptafel met radio,
##               een A-bord "BACK IN 5 MIN" (de vorige ploeg kwam nooit terug)
##   oude Mol    een gestrande oude Mol, met de neus in de wand, half in de vloer, een knipperlicht
##   ribbenkast  een reusachtige ribbenkast die uit de vloer steekt (decor, geen buit)
##   geode       reuzenkristallen langs de wanden die de grot in de kleur van de planeet aanlichten
## Elke set piece ligt bij goede buit (FindField: vondsten in de wanden en de vloer errond).
##
## Welke grotten: de startgrot (PlanetGenerator._plan_starter: in de klei bij de landingsplek, met
## een oude toegangsgang vanaf het oppervlak, stutten en lampjes) krijgt altijd het kamp, met erbij
## per planeet nog iets (Roestbol: hun oude Mol, Fossielwereld: een ribbenkast, Kristalmaan:
## kristallen). Daarnaast altijd de twee dichtste grotten in de klei, en ±1 op 3 van de rest
## (setpieces.cfg). De soort hangt af van de planeet en de laag.
##
## Enkel props, op elke peer zelf uit de seed (geen netwerk; de buit plaatst FindField uit dezelfde
## plan_list). Het terrein verandert er niet door. Botsvormen op Layers.BOUNDS (enkel spelers botsen
## ertegen, het graven en de Mol niet). Graaf je onder een kampspullen, dan verdwijnt dat stuk (zoals
## MidgroundProps). Per grot pas gebouwd als de camera in de buurt komt (zoals CaveDecor).

const MODEL := preload("res://assets/models/setpieces.glb")
const MOL_MODEL := preload("res://assets/models/mol.glb")
const RUST_SHADER := preload("res://src/terrain/rust_overlay.gdshader")
const CHECK_S := 0.5
const DRAW_M := 90.0

enum Kind { CAMP, OLD_MOLE, RIBCAGE, GEODE }
const KIND_NAMES: Array[String] = ["camp", "old_mole", "ribcage", "geode"]
## Buit per soort (FindKinds.Kind): wat de vorige ploeg achterliet, of wat bij het tafereel hoort.
const LOOT := {
	Kind.CAMP: [FindKinds.Kind.COINS, FindKinds.Kind.COINS, FindKinds.Kind.BOTTLE, FindKinds.Kind.GNOME,
			FindKinds.Kind.TV, FindKinds.Kind.LAMP, FindKinds.Kind.GOLD],
	Kind.OLD_MOLE: [FindKinds.Kind.GOLD, FindKinds.Kind.COINS, FindKinds.Kind.LAMP, FindKinds.Kind.TV, FindKinds.Kind.GEODE],
	Kind.RIBCAGE: [FindKinds.Kind.SKULL, FindKinds.Kind.FEMUR, FindKinds.Kind.CLAW, FindKinds.Kind.VERTEBRA, FindKinds.Kind.TUSK],
	Kind.GEODE: [FindKinds.Kind.GEODE, FindKinds.Kind.GEODE, FindKinds.Kind.GLOWSHARD, FindKinds.Kind.BLOOM, FindKinds.Kind.GOLD],
}
## Botsvormen van de kampspullen: [maat, midden] per doos (lokaal, de voet op y = 0).
const SOLID := {
	"CampTent": [[Vector3(2.0, 1.35, 2.6), Vector3(0, 0.67, 0)]],
	"CampLamp": [[Vector3(0.5, 2.2, 0.5), Vector3(0, 1.1, 0)]],
	"CampCrate": [[Vector3(0.82, 0.7, 0.82), Vector3(0, 0.35, 0)]],
	"CampToolbox": [[Vector3(1.2, 0.48, 0.5), Vector3(0, 0.24, 0)]],
	"CampBarrel": [[Vector3(0.6, 0.9, 0.6), Vector3(0, 0.45, 0)]],
	"CampTable": [[Vector3(1.2, 0.78, 0.6), Vector3(0, 0.39, 0)]],
	"CampSign": [[Vector3(0.75, 1.0, 0.4), Vector3(0, 0.5, 0)]],
	"CampGenerator": [[Vector3(0.9, 0.62, 0.6), Vector3(0, 0.31, 0)]],
	"MineFrame": [[Vector3(0.2, 2.5, 0.2), Vector3(-1.15, 1.25, 0)], [Vector3(0.2, 2.5, 0.2), Vector3(1.15, 1.25, 0)]],
}
## Het kamp, lokaal (x opzij, z naar de ingang van de grot): [stuk, x, z, draaiing in graden].
const CAMP_LAYOUT := [
	["CampTent", 0.0, -1.6, 0.0],
	["CampLamp", 2.6, 1.2, -140.0],
	["CampTable", -2.3, 0.4, 75.0],
	["CampChair", -1.5, 1.1, -110.0],
	["CampCrate", 1.7, -2.9, 8.0],
	["CampCrate", 2.6, -2.3, -24.0],
	["CampToolbox", -0.9, 1.9, 12.0],
	["CampBarrel", -2.6, -2.1, 0.0],
	["CampGenerator", 3.1, -0.4, -80.0],
	["CampSign", 0.9, 3.0, 10.0],
]

var terrain: TerrainAPI
## De langste bouwtijd van één set piece (ms), voor de prestatiecontrole.
var build_ms_max := 0.0
var _plan: Array = [] # Dictionary per set piece (zie _make_plan)
var _built := {} # plan-index -> Node3D
var _parts := {} # plan-index -> Array[[Node3D, vloerpunt, Array[CollisionShape3D], Light3D of null]]
var _lights := {} # plan-index -> Array[[Light3D, basisenergie, soort: "lamp" | "blink" | "pulse"]]
var _timer := 0.0
var _flick := 0.0 # tijd tot de volgende hapering van de werflampen
var _mats := {}
var _rock_tint := Color(0.3, 0.25, 0.22) # de rotsvoet van de kristallen: de kleur van de laag
static var _meshes := {}
static var _trimesh := {}


func setup(t: TerrainAPI) -> void:
	terrain = t
	_make_plan()
	t.dug.connect(_on_dug)


## Alle set pieces van deze wereld: [{kind, cave (wereld), anchor (vloer), front (richting naar de
## ingang), starter, seed}], uit de seed. Voor FindField (de buit) en tests.
func plan_list() -> Array:
	return _plan


## Hoeveel set pieces er nu gebouwd zijn (tests).
func built_count() -> int:
	return _built.size()


# --- Plan (uit de seed) ---------------------------------------------------------------------------

func _make_plan() -> void:
	_plan.clear()
	var caves := terrain.caverns()
	var sc := terrain.shaft_center_world()
	var starter := terrain.starter_cave()
	var share := Tuning.get_f("setpieces", "share", 0.34)
	var min_r := Tuning.get_f("setpieces", "min_radius_m", 4.5)
	var planet := clampi(terrain.planet, 0, 2)
	# De twee dichtste grotten in de klei krijgen er altijd een (de eerste 15 minuten).
	var clay: Array = []
	for i in caves.size():
		var c := caves[i]
		if c.w < min_r or _is_starter(c, starter):
			continue
		if terrain.layer_at(Vector3(c.x, c.y, c.z)) == Strata.Layer.KLEI:
			clay.append([Vector2(c.x - sc.x, c.z - sc.z).length(), i])
	clay.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var forced := {}
	for k in mini(2, clay.size()):
		forced[int(clay[k][1])] = k
	for i in caves.size():
		var c := caves[i]
		var center := Vector3(c.x, c.y, c.z)
		var is_starter := _is_starter(c, starter)
		var rng := RandomNumberGenerator.new()
		rng.seed = terrain.pit_seed * 7919 + i * 104729 + 3
		var roll := rng.randf()
		var pick := rng.randf()
		var yaw := rng.randf() * TAU
		if not is_starter and not forced.has(i) and (c.w < min_r or roll > share):
			continue
		var layer := terrain.layer_at(center)
		var kind := Kind.CAMP if is_starter else _pick_kind(planet, layer, c.w, pick)
		if forced.get(i, -1) == 0 and not is_starter:
			kind = Kind.CAMP if planet == 0 else (Kind.RIBCAGE if planet == 1 else Kind.GEODE)
		var front := Vector3(sin(yaw), 0.0, cos(yaw))
		if is_starter:
			var ramp := terrain.starter_ramp()
			if not ramp.is_empty():
				var e: Vector3 = ramp[ramp.size() - 1]
				front = Vector3(e.x - c.x, 0.0, e.z - c.z).normalized()
		var anchor := _floor_below(center + front * (c.w * 0.18 if is_starter else 0.0), c.w / PlanetGenerator.CAVERN_SQUASH + 3.0)
		if anchor.is_finite() == false:
			continue
		_plan.append({"kind": kind, "cave": c, "anchor": anchor, "front": front, "starter": is_starter,
				"seed": terrain.pit_seed * 31 + i, "layer": layer, "index": i})


func _is_starter(c: Vector4, starter: Vector4) -> bool:
	return starter.w > 0.0 and c.is_equal_approx(starter)


## De soort per planeet en laag (Roestbol: kampen en oude Mollen; Fossielwereld: ribbenkasten;
## Kristalmaan: geodes). Een oude Mol enkel in grotten van minstens 7,5 m, een ribbenkast van 5,5 m.
static func _pick_kind(planet: int, layer: Strata.Layer, radius: float, r: float) -> Kind:
	var table: Array
	match layer:
		Strata.Layer.KLEI:
			table = [[Kind.CAMP, 0.45], [Kind.OLD_MOLE, 0.3], [Kind.GEODE, 0.25]] if planet == 0 else (
					[[Kind.RIBCAGE, 0.55], [Kind.CAMP, 0.35], [Kind.OLD_MOLE, 0.1]] if planet == 1 else
					[[Kind.GEODE, 0.55], [Kind.CAMP, 0.3], [Kind.OLD_MOLE, 0.15]])
		Strata.Layer.ZANDSTEEN:
			table = [[Kind.RIBCAGE, 0.4], [Kind.OLD_MOLE, 0.3], [Kind.CAMP, 0.3]] if planet == 0 else (
					[[Kind.RIBCAGE, 0.7], [Kind.CAMP, 0.3]] if planet == 1 else
					[[Kind.GEODE, 0.6], [Kind.OLD_MOLE, 0.2], [Kind.RIBCAGE, 0.2]])
		_:
			table = [[Kind.GEODE, 0.7], [Kind.OLD_MOLE, 0.3]]
	var acc := 0.0
	var kind: Kind = table[0][0]
	for row: Array in table:
		acc += float(row[1])
		if r <= acc:
			kind = row[0]
			break
	if kind == Kind.OLD_MOLE and radius < 7.5:
		kind = Kind.CAMP if layer != Strata.Layer.GRANIET and layer != Strata.Layer.KRISTAL else Kind.GEODE
	if kind == Kind.RIBCAGE and radius < 5.5:
		kind = Kind.CAMP
	return kind


# --- Vragen aan de seed (de SDF van de generator, niet de bewerkte voxels) ---------------------------

func _sdf(world: Vector3) -> float:
	return terrain._generator.sdf_at(world / TerrainAPI.VOXEL_SIZE) * TerrainAPI.VOXEL_SIZE


## Het eerste rotspunt onder `from` (wereld), tot `reach` m diep; Vector3.INF als er niets is.
func _floor_below(from: Vector3, reach: float) -> Vector3:
	if _sdf(from) < 0.0:
		return Vector3.INF
	var y := 0.0
	var prev := 0.0
	while y < reach:
		prev = y
		y += maxf(_sdf(from - Vector3(0, y, 0)) * 0.8, 0.15)
		if _sdf(from - Vector3(0, y, 0)) < 0.0:
			var lo := prev
			var hi := y
			for k in 6:
				var mid := (lo + hi) * 0.5
				if _sdf(from - Vector3(0, mid, 0)) < 0.0:
					hi = mid
				else:
					lo = mid
			return from - Vector3(0, hi, 0)
	return Vector3.INF


## De wand vanuit `from` in richting `dir` (wereld), tot `reach` m; Vector3.INF als er niets is.
func _wall_along(from: Vector3, dir: Vector3, reach: float) -> Vector3:
	var t := 0.0
	var prev := 0.0
	while t < reach:
		prev = t
		t += maxf(_sdf(from + dir * t) * 0.8, 0.2)
		if _sdf(from + dir * t) < 0.0:
			var lo := prev
			var hi := t
			for k in 6:
				var mid := (lo + hi) * 0.5
				if _sdf(from + dir * mid) < 0.0:
					hi = mid
				else:
					lo = mid
			return from + dir * hi
	return Vector3.INF


## Normaal van de rots op `p` (wereld, uit de seed).
func _normal(p: Vector3) -> Vector3:
	var e := 0.3
	var g := Vector3(_sdf(p + Vector3(e, 0, 0)) - _sdf(p - Vector3(e, 0, 0)),
			_sdf(p + Vector3(0, e, 0)) - _sdf(p - Vector3(0, e, 0)),
			_sdf(p + Vector3(0, 0, e)) - _sdf(p - Vector3(0, 0, e)))
	return g.normalized() if g.length() > 1e-5 else Vector3.UP


# --- Bouwen en afbreken (per grot, als de camera in de buurt komt) -------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	if _building:
		_step_build()
	_timer -= delta
	if _timer > 0.0 or terrain == null or not terrain.is_inside_tree():
		return
	_timer = CHECK_S
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var build_m := Tuning.get_f("setpieces", "build_m", 60.0)
	var free_m := Tuning.get_f("setpieces", "free_m", 100.0)
	var built_one := false
	for i in _plan.size():
		var sp: Dictionary = _plan[i]
		var c: Vector4 = sp.cave
		var d := p.distance_to(Vector3(c.x, c.y, c.z)) - c.w
		if sp.starter:
			for q in terrain.starter_ramp():
				d = minf(d, p.distance_to(q))
		if _built.has(i):
			if d > free_m:
				(_built[i] as Node3D).queue_free()
				_built.erase(i)
				_parts.erase(i)
				_lights.erase(i)
		elif d < build_m and not built_one and not _building and terrain.data_loaded(sp.anchor):
			_build(i)
			built_one = true # één per keer, en in stappen over een paar beelden: geen hapering


var _building := false
var _pending: Array[Callable] = []
var _pending_root: Node3D


## Bouwt een set piece in stappen (een beeld ertussen), zodat geen enkel beeld lang duurt.
func _build(i: int) -> void:
	var sp: Dictionary = _plan[i]
	var root := Node3D.new()
	root.name = "SetPiece%d_%s" % [i, KIND_NAMES[sp.kind]]
	add_child(root)
	_built[i] = root
	_parts[i] = []
	_lights[i] = []
	_building = true
	var body := StaticBody3D.new()
	body.name = "Solid"
	body.collision_layer = Layers.BOUNDS
	body.collision_mask = 0
	root.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(sp.seed)
	_rock_tint = Underground.color(terrain.planet, "dark", int(sp.layer)).lerp(Underground.color(terrain.planet, "base", int(sp.layer)), 0.5)
	var steps: Array[Callable] = []
	match int(sp.kind):
		Kind.CAMP:
			steps.append(_build_camp.bind(i, root, body, sp, rng))
			if sp.starter:
				steps.append(_build_ramp.bind(i, root, body))
				match clampi(terrain.planet, 0, 2):
					0:
						steps.append(_build_old_mole.bind(i, root, body, sp, rng, -sp.front))
					1:
						steps.append(_build_ribcage.bind(i, root, body, sp, rng, -sp.front * (sp.cave.w * 0.45)))
					_:
						steps.append(_build_geode.bind(i, root, body, sp, rng, 3))
		Kind.OLD_MOLE:
			steps.append(_build_old_mole.bind(i, root, body, sp, rng, Vector3.ZERO))
		Kind.RIBCAGE:
			steps.append(_build_ribcage.bind(i, root, body, sp, rng, Vector3.ZERO))
		Kind.GEODE:
			steps.append(_build_geode.bind(i, root, body, sp, rng, rng.randi_range(4, 6)))
	_pending = steps
	_pending_root = root


## De volgende stap van de set piece in opbouw (één per beeld).
func _step_build() -> void:
	if _pending.is_empty():
		_building = false
		return
	var step: Callable = _pending.pop_front()
	if not is_instance_valid(_pending_root) or _pending_root.is_queued_for_deletion():
		_pending.clear()
		_building = false
		return
	var t0 := Time.get_ticks_usec()
	step.call()
	build_ms_max = maxf(build_ms_max, (Time.get_ticks_usec() - t0) / 1000.0)


## Een stuk uit setpieces.glb op de vloer bij `world_xz` (de hoogte uit de seed), met zijn botsvorm.
func _place(i: int, root: Node3D, body: StaticBody3D, name: String, world: Vector3, yaw: float, from_y: float,
		scale := 1.0) -> MeshInstance3D:
	var fp := _floor_below(Vector3(world.x, from_y, world.z), 6.0)
	if not fp.is_finite():
		return null
	var mi := _mesh_instance(name)
	root.add_child(mi)
	var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), fp - Vector3(0, 0.03, 0))
	mi.global_transform = xf
	var shapes: Array[CollisionShape3D] = []
	for box: Array in SOLID.get(name, []):
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = (box[0] as Vector3) * scale
		cs.shape = bs
		body.add_child(cs)
		cs.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf * (box[1] as Vector3))
		shapes.append(cs)
	(_parts[i] as Array).append([mi, fp, shapes, null])
	return mi


func _mesh_instance(name: String, tint := Color(1, 1, 1)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(name)
	mi.visibility_range_end = DRAW_M
	for s in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(s)
		mi.set_surface_override_material(s, _material(src.resource_name if src else "", src, tint))
	return mi


func _light(i: int, root: Node3D, spot: bool, pos: Vector3, col: Color, energy: float, rng_m: float, mode: String,
		shadow := false) -> Light3D:
	var l: Light3D
	if spot:
		var s := SpotLight3D.new()
		s.spot_range = rng_m
		s.spot_angle = 48.0
		s.spot_attenuation = 0.9
		s.spot_angle_attenuation = 1.6
		l = s
	else:
		var o := OmniLight3D.new()
		o.omni_range = rng_m
		o.omni_attenuation = 1.4
		l = o
	l.light_color = col
	l.light_energy = energy
	l.shadow_enabled = shadow
	l.light_specular = 0.4
	l.light_volumetric_fog_energy = 0.5 if spot else 0.25
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 20.0
	if shadow:
		l.distance_fade_shadow = 30.0
	root.add_child(l)
	l.global_position = pos
	(_lights[i] as Array).append([l, energy, mode])
	return l


# --- Het kamp ------------------------------------------------------------------------------------

func _build_camp(i: int, root: Node3D, body: StaticBody3D, sp: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: Vector3 = sp.anchor
	var front: Vector3 = sp.front
	var side := Vector3.UP.cross(front).normalized()
	var base_yaw := atan2(front.x, front.z)
	var from_y := a.y + 2.5
	var lamp_xf := Transform3D()
	for row: Array in CAMP_LAYOUT:
		var name: String = row[0]
		var w := a + side * float(row[1]) + front * float(row[2])
		var yaw := base_yaw + deg_to_rad(float(row[3]) + rng.randf_range(-6.0, 6.0))
		var mi := _place(i, root, body, name, w, yaw, from_y)
		if mi and name == "CampLamp":
			lamp_xf = mi.global_transform
	# De werflamp: een spot uit de kop (2,17 m hoog, 30° omlaag naar zijn +z), met schaduw; hij hapert.
	if lamp_xf != Transform3D():
		var head := lamp_xf * Vector3(0.0, 2.17, 0.12)
		var dir := (lamp_xf.basis * Vector3(0.0, -sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))).normalized()
		var l := _light(i, root, true, head, Color(1.0, 0.8, 0.55), Tuning.get_f("setpieces", "lamp_energy", 5.0),
				Tuning.get_f("setpieces", "lamp_range", 18.0), "lamp", true)
		l.look_at(head + dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
		(_parts[i] as Array)[_lamp_part(i)][3] = l
	# Het lampjessnoer voor de tent en de lantaarn op de tafel: warm, zonder schaduw.
	var tent := a + front * -1.6
	_light(i, root, false, tent + front * 2.6 + Vector3.UP * 1.7 + side * 0.4, Color(1.0, 0.7, 0.4), 1.1, 6.5, "lamp")
	_light(i, root, false, a + side * -2.3 + front * 0.4 + Vector3.UP * 1.1, Color(1.0, 0.75, 0.45), 0.6, 3.5, "lamp")


func _lamp_part(i: int) -> int:
	var parts: Array = _parts[i]
	for k in parts.size():
		if (parts[k][0] as MeshInstance3D).mesh == _mesh("CampLamp"):
			return k
	return 0


## De oude toegangsgang van de vorige ploeg (enkel bij de startgrot): om de ±6 m een houten stut met
## een kooilamp (om de andere een echt lampje), en aan de monding een werflamp en het bord.
func _build_ramp(i: int, root: Node3D, body: StaticBody3D) -> void:
	var ramp := terrain.starter_ramp()
	if ramp.size() < 2:
		return
	var pts: Array[Vector3] = []
	for k in ramp.size() - 1:
		var a: Vector3 = ramp[k]
		var b: Vector3 = ramp[k + 1]
		var n := maxi(1, int(a.distance_to(b) / 6.0))
		for j in n:
			pts.append(a.lerp(b, float(j) / n))
	pts.append(ramp[ramp.size() - 1])
	var r := PlanetGenerator.STARTER_RAMP_R * TerrainAPI.VOXEL_SIZE
	for k in range(1, pts.size() - 1):
		var p := pts[k]
		var dir := pts[k + 1] - pts[k - 1]
		var yaw := atan2(dir.x, dir.z)
		var mi := _place(i, root, body, "MineFrame", p, yaw, p.y)
		if mi and k % 2 == 1:
			var lamp := mi.global_transform * Vector3(0.35, 2.15, 0.0)
			var l := _light(i, root, false, lamp, Color(1.0, 0.72, 0.42), 1.3, 7.0, "lamp")
			(_parts[i] as Array).back()[3] = l
	# De monding: een werflamp die de gang in schijnt, en het bord van het kamp.
	var m := ramp[0]
	var into := (ramp[1] - ramp[0])
	into.y = 0.0
	into = into.normalized()
	var side := Vector3.UP.cross(into).normalized()
	var top := m.y + r
	var lamp_at := m - into * 2.2 + side * 2.4
	var mi_l := _place(i, root, body, "CampLamp", lamp_at, atan2(into.x, into.z) - 0.35, top + 3.0)
	if mi_l:
		var head := mi_l.global_transform * Vector3(0.0, 2.17, 0.12)
		var dir := (mi_l.global_transform.basis * Vector3(0.0, -sin(deg_to_rad(30.0)), cos(deg_to_rad(30.0)))).normalized()
		var l := _light(i, root, true, head, Color(1.0, 0.8, 0.55), 4.0, 20.0, "lamp")
		l.look_at(head + dir, Vector3.UP)
		(_parts[i] as Array).back()[3] = l
	_place(i, root, body, "CampSign", m - into * 2.6 - side * 2.0, atan2(-into.x, -into.z) + 0.3, top + 3.0)
	_place(i, root, body, "CampCrate", m - into * 3.4 - side * 3.0, rng_yaw(i), top + 3.0)


func rng_yaw(i: int) -> float:
	return fmod(float(i) * 2.399, TAU)


# --- De oude Mol -----------------------------------------------------------------------------------

## Een oude Mol, met de neus ±3 m in de wand (in richting `toward`, of een richting uit de seed), half
## in de vloer, wat gekanteld. Verroest: de machine-shader met meer vuil en een verbleekte kleur.
func _build_old_mole(i: int, root: Node3D, body: StaticBody3D, sp: Dictionary, rng: RandomNumberGenerator, toward: Vector3) -> void:
	var c: Vector4 = sp.cave
	var a: Vector3 = sp.anchor
	var dir := toward.normalized() if toward.length() > 0.1 else Vector3(sin(rng.randf() * TAU), 0.0, cos(rng.randf() * TAU)).normalized()
	var from := a + Vector3.UP * 2.6
	var wall := _wall_along(from, dir, c.w * 1.6)
	if not wall.is_finite():
		return
	# Neus (−z van de Mol) in de wand: het midden ligt 5 m achter de neus, de neus 3 m in de rots.
	var yaw := atan2(-dir.x, -dir.z)
	var center := wall - dir * 2.0
	var floor_p := _floor_below(Vector3(center.x, a.y + 3.0, center.z), 8.0)
	var fy := floor_p.y if floor_p.is_finite() else a.y
	var mol := MOL_MODEL.instantiate() as Node3D
	mol.name = "OldMole"
	root.add_child(mol)
	_rust(mol, fy)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-10.0, -5.0))) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-9.0, 9.0)))
	mol.global_transform = Transform3D(basis, Vector3(center.x, fy + 2.73 - 1.1, center.z))
	# Botsvorm: de omhullende doos van het model (lokaal), iets kleiner.
	var aabb := _local_aabb(mol)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = aabb.size * Vector3(0.85, 0.85, 0.92)
	cs.shape = bs
	body.add_child(cs)
	cs.global_transform = Transform3D(mol.global_transform.basis, mol.global_transform * aabb.get_center())
	# Nog één lamp brandt: een oranje knipperlicht op het dak, en een flauwe gloed uit de cabine.
	var top := mol.global_transform * Vector3(0.0, aabb.end.y + 0.3, aabb.get_center().z + 1.0)
	_light(i, root, false, top, Color(1.0, 0.45, 0.08), 2.2, 9.0, "blink")
	_light(i, root, false, mol.global_transform * Vector3(0.0, 0.3, -1.5), Color(1.0, 0.68, 0.36), 0.7, 5.0, "lamp")


## De machine-materialen van de Mol, verweerd: kleuren naar roestbruin, meer vuil en kale randen.
## Glazen en lampen uit (behalve het knipperlicht), want de accu is bijna leeg.
func _rust(node: Node, floor_y: float) -> void:
	var overlay := ShaderMaterial.new()
	overlay.shader = RUST_SHADER
	overlay.set_shader_parameter("floor_y", floor_y)
	overlay.set_shader_parameter("dust", _rock_tint.lightened(0.25))
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = DRAW_M
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_overlay = overlay
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			var name := src.resource_name if src else ""
			mi.set_surface_override_material(s, _rust_material(name, src))


func _rust_material(name: String, src: Material) -> Material:
	var key := "rust/" + name
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if MolVisual.MATS.has(name):
		var sm := MolVisual.machine_material(name, false, 1.0, 0.0, Color(), 1.6)
		var p: Dictionary = MolVisual.MATS[name]
		var c: Color = p.albedo
		sm.set_shader_parameter("albedo", c.lerp(Color(0.36, 0.24, 0.16), 0.55).darkened(0.2))
		sm.set_shader_parameter("grime", 1.0)
		sm.set_shader_parameter("grime_color", Color(0.3, 0.17, 0.09))
		sm.set_shader_parameter("low_grime", 1.6)
		m = sm
	elif MolVisual.EMISSIVE.has(name):
		var e := StandardMaterial3D.new()
		var col: Color = MolVisual.EMISSIVE[name][0]
		e.albedo_color = col.darkened(0.6)
		e.roughness = 0.3
		if name == "LensOrange":
			e.emission_enabled = true
			e.emission = col
			e.emission_energy_multiplier = 1.5
		m = e
	else:
		m = MolVisual.palette_material(name, src)
	_mats[key] = m
	return m


func _local_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := node.global_transform.affine_inverse()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var bb := (inv * mi.global_transform) * mi.get_aabb()
		out = bb if first else out.merge(bb)
		first = false
	return out


# --- De ribbenkast ----------------------------------------------------------------------------------

func _build_ribcage(i: int, root: Node3D, body: StaticBody3D, sp: Dictionary, rng: RandomNumberGenerator, offset: Vector3) -> void:
	var a: Vector3 = sp.anchor
	var at := a + offset
	var fp := _floor_below(Vector3(at.x, a.y + 3.0, at.z), 8.0)
	if not fp.is_finite():
		return
	var yaw := rng.randf() * TAU
	if offset.length() > 0.1:
		var side := Vector3.UP.cross(offset.normalized())
		yaw = atan2(side.x, side.z) + PI * 0.5 # de rug evenwijdig met de wand
	var s := clampf(sp.cave.w / 9.0, 0.7, 1.15)
	var mi := _mesh_instance("Ribcage")
	root.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-6.0, 6.0))).scaled(Vector3.ONE * s),
			fp - Vector3(0, 0.45 * s, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _trimesh_of("Ribcage")
	body.add_child(cs)
	cs.global_transform = mi.global_transform
	# Een flauw koel licht erboven: van in de ingang zie je het silhouet.
	var glow := Underground.fungus(terrain.planet).lerp(Color(0.75, 0.85, 1.0), 0.6)
	_light(i, root, false, fp + Vector3.UP * 4.5, glow, 0.9, 11.0, "pulse")


# --- De geode ----------------------------------------------------------------------------------------

func _build_geode(i: int, root: Node3D, body: StaticBody3D, sp: Dictionary, rng: RandomNumberGenerator, count: int) -> void:
	var c: Vector4 = sp.cave
	var center := Vector3(c.x, c.y, c.z)
	var layer: int = sp.layer
	var col := Underground.color(terrain.planet, "accent", 0) if layer <= Strata.Layer.GRANIET else Underground.fungus(terrain.planet)
	if terrain.planet == 2:
		col = Underground.color(terrain.planet, "accent", 3)
	var placed := 0
	for k in count * 3:
		if placed >= count:
			break
		var y := rng.randf_range(-0.9, 0.35)
		var ang := rng.randf() * TAU
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var dir := Vector3(cos(ang) * r, y, sin(ang) * r)
		var hit := _wall_along(center, dir, c.w * 2.2)
		var s := rng.randf_range(0.8, 1.5) * clampf(c.w / 8.0, 0.6, 1.3)
		if not hit.is_finite():
			continue
		var n := _normal(hit)
		var up := (n + Vector3.UP * 0.35).normalized()
		var mi := _mesh_instance("CrystalCluster", col)
		root.add_child(mi)
		mi.global_transform = Transform3D(_basis_up(up) * Basis(Vector3.UP, rng.randf() * TAU) * Basis().scaled(Vector3.ONE * s), hit - n * 0.25)
		var cs := CollisionShape3D.new()
		cs.shape = _trimesh_of("CrystalCluster")
		body.add_child(cs)
		cs.global_transform = mi.global_transform
		(_parts[i] as Array).append([mi, hit - n * 0.2, [cs] as Array[CollisionShape3D], null])
		if placed < 2:
			var l := _light(i, root, false, hit + n * 1.6 + Vector3.UP * 0.6, col, 1.8, 7.0 + c.w * 0.4, "pulse")
			(_parts[i] as Array).back()[3] = l
		placed += 1


static func _basis_up(up: Vector3) -> Basis:
	if up.dot(Vector3.UP) < -0.999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, up.normalized()))


# --- Leven: werflampen die haperen, een knipperlicht, kristallen die traag kloppen -----------------

func _animate(delta: float) -> void:
	if _lights.is_empty():
		return
	var t := Time.get_ticks_msec() / 1000.0
	_flick -= delta
	var hiccup := 1.0
	if _flick < 0.0:
		if _flick < -0.35:
			_flick = 60.0 / maxf(0.1, Tuning.get_f("setpieces", "lamp_flicker_per_min", 5.0)) * randf_range(0.5, 1.5)
		else:
			hiccup = 0.15 if fmod(t * 23.0, 1.0) < 0.5 else 0.8 # even haperen
	for i: int in _lights:
		for row: Array in _lights[i]:
			var l: Light3D = row[0]
			if not is_instance_valid(l) or not l.visible:
				continue
			var e: float = row[1]
			match String(row[2]):
				"lamp":
					l.light_energy = e * hiccup * (0.96 + 0.04 * sin(t * 13.0 + i))
				"blink":
					l.light_energy = e * (1.0 if fmod(t, 1.6) < 0.25 else 0.05)
				_:
					l.light_energy = e * (0.8 + 0.2 * sin(t * 0.9 + i * 1.7))


# --- Weggegraven: kampspullen zonder vloer verdwijnen --------------------------------------------

func _on_dug(world_center: Vector3, radius_m: float) -> void:
	for i: int in _parts:
		for part: Array in _parts[i]:
			var fp: Vector3 = part[1]
			var node: Node3D = part[0]
			if not node.visible or fp.distance_to(world_center) > radius_m + 1.2:
				continue
			if terrain.sdf_at(fp - Vector3(0, 0.2, 0)) > 0.05:
				node.visible = false
				for cs: CollisionShape3D in part[2]:
					cs.set_deferred("disabled", true)
				if part[3] != null:
					(part[3] as Light3D).visible = false


# --- Meshes en materialen ------------------------------------------------------------------------------

static func _mesh(name: String) -> Mesh:
	if _meshes.is_empty():
		var root := MODEL.instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			_meshes[mi.name] = mi.mesh
		root.free()
	return _meshes[name]


static func _trimesh_of(name: String) -> Shape3D:
	if not _trimesh.has(name):
		_trimesh[name] = _mesh(name).create_trimesh_shape()
	return _trimesh[name]


func _material(name: String, src: Material, tint: Color) -> Material:
	var key := "%s/%s" % [name, (_rock_tint if name == "Rock" else tint).to_html()]
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match name:
		"Bone", "BoneDark":
			m = FindKinds.bone_material(name == "BoneDark")
		"Canvas", "Tarp", "Paper":
			var base := "Blue" if name == "Tarp" else "Cream"
			var sm := MolVisual.machine_material(base, false, 1.5)
			sm.set_shader_parameter("albedo", {"Canvas": Color(0.78, 0.6, 0.26), "Tarp": Color(0.2, 0.3, 0.4), "Paper": Color(0.92, 0.9, 0.82)}[name])
			sm.set_shader_parameter("grime", 0.8)
			sm.set_shader_parameter("metallic", 0.0)
			sm.set_shader_parameter("roughness", 0.85)
			m = sm
		"TentShadow":
			var d := StandardMaterial3D.new()
			d.albedo_color = Color(0.03, 0.025, 0.02)
			d.roughness = 1.0
			m = d
		"Crystal":
			var c := StandardMaterial3D.new()
			c.albedo_color = tint.darkened(0.35)
			c.roughness = 0.05
			c.metallic = 0.1
			c.rim_enabled = true
			c.rim = 0.6
			c.rim_tint = 0.8
			c.emission_enabled = true
			c.emission = tint
			c.emission_energy_multiplier = 0.9
			m = c
		"Rock":
			var rm := MolVisual.machine_material("Rock", false, 2.0)
			rm.set_shader_parameter("albedo", _rock_tint)
			rm.set_shader_parameter("bare_metal", _rock_tint.lightened(0.3))
			m = rm
		_:
			m = MolVisual.palette_material(name, src)
	_mats[key] = m
	return m
