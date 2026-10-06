class_name LandingSite
extends Node3D
## Een gecomponeerde landingsplek (release-audit golf 3, buiten2-6 en voorstel 2 van "buiten"): op
## ±26 m van de landing, schuin vóór de Mol (de dropcamera kijkt bij de landing naar −z, en de cabine
## ook), een vaste groep die een verhaal vertelt. Zo heeft het eerste beeld na de drop een voorgrond,
## en hebben spelers een reden om eerst rond te kijken:
## - Roestbol: het kamp van een vorige ploeg (een zeil tussen twee palen, kisten, vaten, een
##   werklamp die nog brandt, een omgevallen meetmast met zijn kabelhaspel en een koude stookplaats);
## - Fossielwereld: een opgraving (een vak met rood-wit lint, een half vrijgelegd reuzenbot, een
##   hoop uitgegraven klei met een schep erin, een zeef op twee kisten en een werklamp);
## - Kristalmaan: een neergestorte sonde (half begraven, een gebroken zonnepaneel, een rood
##   knipperlicht, een sleepspoor erachter) waar cyane kristallen doorheen gegroeid zijn.
## Bouwstijl zoals de rest van het middenplan (MidgroundProps): eenvoudige vormen in het machinepalet.
## Ter goedkeuring van Jayme (golf 3).
##
## Enkel om te zien, met botsvormen voor spelers op Layers.BOUNDS (zoals de kisten van het
## middenplan: de Mol en het graven gaan erdoor). Alles hangt af van de seed. Graaf je eronder, dan
## verdwijnt dat stuk (TerrainAPI.dug).

## Afstand (m) van de landingsplek tot het midden van de groep, en hoe ver opzij van −z (graden).
const DIST := 26.0
const SIDE_DEG := Vector2(18.0, 34.0)
const HIDE_M := 420.0

var terrain: TerrainAPI
var focus := Vector3.ZERO # waar de camera naar kijkt (voor previews)
var _parts: Array[Node3D] = []
var _shapes: Array = [] # per stuk: CollisionShape3D of null
var _body: StaticBody3D
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _blink: StandardMaterial3D
var _halo: ShaderMaterial
var _t := 0.0
var _rng := RandomNumberGenerator.new()


## Plek van de groep (wereld x/z) voor deze seed (ook voor MidgroundProps: daar niets anders).
## `ramp` = de oude toegangsgang naar de startgrot (TerrainAPI.starter_ramp, pakket G5), met zijn
## monding ±27 m van de landingsplek, een werflamp en een bord. Op Roestbol staat het kamp van de
## vorige ploeg ernaast (zij groeven die gang): één plek, één verhaal. Elders blijft de groep minstens
## MOUTH_GAP van de monding en zijn eerste meters (de weg erin blijft vrij).
const MOUTH_GAP := 15.0

static func site_xz(landing: Vector2, planet_seed: int, planet_id := PlanetType.Id.ROESTBOL, ramp: Array[Vector3] = []) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 31 + 1201
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	var side := sgn * deg_to_rad(rng.randf_range(SIDE_DEG.x, SIDE_DEG.y))
	var c := landing + Vector2(0.0, -1.0).rotated(side) * DIST
	if ramp.size() < 2:
		return c
	var m := Vector2(ramp[0].x, ramp[0].z)
	var into := (Vector2(ramp[1].x, ramp[1].z) - m).normalized()
	if planet_id == PlanetType.Id.ROESTBOL:
		# Naast de monding, aan de kant die het dichtst bij −z ligt (in beeld van de dropcamera), iets
		# naar de Mol toe.
		var perp := into.orthogonal()
		if perp.dot(Vector2(0.0, -1.0)) < 0.0:
			perp = -perp
		return m + perp * 10.0 - into * 3.0
	# Weg van de monding: de andere kant op als hij te dichtbij staat.
	for k in 4:
		if _mouth_d(c, m, into) >= MOUTH_GAP:
			break
		side = -side if k == 0 else side + sgn * deg_to_rad(40.0)
		c = landing + Vector2(0.0, -1.0).rotated(side) * DIST
	return c


## Afstand van p tot de monding en de eerste 12 m van de gang (x/z).
static func _mouth_d(p: Vector2, m: Vector2, into: Vector2) -> float:
	var t := clampf((p - m).dot(into), 0.0, 12.0)
	return p.distance_to(m + into * t)


func build(t: TerrainAPI, planet_id: PlanetType.Id, landing: Vector2, planet_seed: int) -> void:
	terrain = t
	_rng.seed = planet_seed * 17 + 77
	var c := site_xz(landing, planet_seed, planet_id, t.starter_ramp())
	position = Vector3(c.x, t.surface_height_at(c.x, c.y), c.y)
	# De groep kijkt naar de landingsplek (+z lokaal = naar de Mol), iets schuin.
	var to := Vector2(landing.x - c.x, landing.y - c.y).normalized().rotated(_rng.randf_range(-0.3, 0.3))
	basis = Basis(Vector3.UP, atan2(to.x, to.y))
	match planet_id:
		PlanetType.Id.FOSSIELWERELD:
			_excavation()
		PlanetType.Id.KRISTALMAAN:
			_probe()
		_:
			_camp()
	focus = to_global(Vector3(0.0, 1.0, 0.0))
	set_meta("focus", focus)
	t.dug.connect(_on_dug)


func _process(delta: float) -> void:
	_t += delta
	if _lamp:
		# Een werklamp op een oude accu: brandt, hapert af en toe.
		var flick := 1.0 if fmod(_t * 0.37, 1.0) > 0.06 else 0.35 + 0.3 * sin(_t * 61.0)
		_lamp.light_energy = 1.6 * flick
		_lamp_mat.emission_energy_multiplier = 7.0 * flick
		if _halo:
			_halo.set_shader_parameter("blink", flick)
	if _blink:
		var on := fmod(_t, 1.3) < 0.18
		_blink.emission_energy_multiplier = 9.0 if on else 0.3
		if _halo:
			_halo.set_shader_parameter("blink", 1.0 if on else 0.05)


# --- Roestbol: het kamp van een vorige ploeg ----------------------------------------------------

func _camp() -> void:
	var red := MolVisual.machine_material("Red", false, 2.0)
	var wood := MolVisual.machine_material("Wood", false, 2.0)
	var dark := MolVisual.machine_material("Anthracite", false, 2.0)
	var yellow := MolVisual.machine_material("Yellow", false, 2.0)
	var steel := MolVisual.machine_material("Steel", false, 2.0)
	var canvas := _flat_mat(Color(0.62, 0.36, 0.22), 0.95) # verbleekt oranje zeil
	var meshes := MidgroundProps._meshes(null)
	# Zeil tussen twee palen (een afdak), schuin naar de grond, met scheerlijnen.
	var tent := _part("Tarp", Vector3(-2.2, 0.0, -1.2), 0.25, Vector3(3.4, 2.3, 2.6))
	_mesh(tent, _box(Vector3(0.1, 2.3, 0.1)), Vector3(-1.6, 1.15, 0.9), Vector3.ZERO, wood)
	_mesh(tent, _box(Vector3(0.1, 2.3, 0.1)), Vector3(1.6, 1.15, 0.9), Vector3.ZERO, wood)
	_mesh(tent, _box(Vector3(3.4, 0.08, 0.08)), Vector3(0.0, 2.28, 0.9), Vector3.ZERO, wood)
	_mesh(tent, _box(Vector3(3.6, 0.03, 2.9)), Vector3(0.0, 1.2, -0.22), Vector3(deg_to_rad(-52.0), 0.0, 0.0), canvas)
	_mesh(tent, _box(Vector3(0.03, 0.03, 1.9)), Vector3(-1.6, 1.35, 1.6), Vector3(deg_to_rad(38.0), 0.0, 0.0), dark)
	_mesh(tent, _box(Vector3(0.03, 0.03, 1.9)), Vector3(1.6, 1.35, 1.6), Vector3(deg_to_rad(38.0), 0.0, 0.0), dark)
	# Kisten (een gestapeld) en vaten (een omgevallen).
	_prop(meshes[MidgroundProps.Kind.CRATE], Vector3(-2.6, 0.0, -0.6), 0.2, Vector3(1.2, 0.9, 0.9))
	_prop(meshes[MidgroundProps.Kind.CRATE_DARK], Vector3(-1.3, 0.0, -0.9), -0.1, Vector3(1.2, 0.9, 0.9))
	_prop(meshes[MidgroundProps.Kind.CRATE], Vector3(-2.5, 0.9, -0.55), 0.45, Vector3.ZERO)
	_prop(meshes[MidgroundProps.Kind.BARREL], Vector3(0.4, 0.0, -1.7), 0.0, Vector3(0.64, 0.9, 0.64))
	var fallen := _part("Barrel", Vector3(1.3, 0.32, -0.9), 0.9, Vector3.ZERO)
	var bm := MeshInstance3D.new()
	bm.mesh = meshes[MidgroundProps.Kind.BARREL]
	bm.rotation = Vector3(0.0, 0.0, PI * 0.5)
	bm.position = Vector3(0.45, 0.0, 0.0)
	fallen.add_child(bm)
	# De werklamp op een driepoot: brandt nog (warm, hapert), met een halo.
	_work_lamp(Vector3(1.6, 0.0, 0.8), -0.6, dark, yellow)
	# Een omgevallen meetmast met zijn kabelhaspel.
	var mast := _part("FallenMast", Vector3(4.6, 0.0, -3.0), 0.5, Vector3.ZERO)
	var mm := MeshInstance3D.new()
	mm.mesh = meshes[MidgroundProps.Kind.MAST]
	mm.rotation = Vector3(0.0, 0.0, deg_to_rad(-84.0))
	mm.position = Vector3(0.0, 0.35, 0.0)
	mast.add_child(mm)
	var reel := _part("CableReel", Vector3(3.2, 0.0, -0.8), 1.1, Vector3(1.1, 1.1, 0.6))
	_mesh(reel, _cyl(0.55, 0.08), Vector3(0.0, 0.55, -0.24), Vector3(PI * 0.5, 0.0, 0.0), red)
	_mesh(reel, _cyl(0.55, 0.08), Vector3(0.0, 0.55, 0.24), Vector3(PI * 0.5, 0.0, 0.0), red)
	_mesh(reel, _cyl(0.36, 0.42), Vector3(0.0, 0.55, 0.0), Vector3(PI * 0.5, 0.0, 0.0), dark)
	_mesh(reel, _box(Vector3(1.2, 0.08, 0.6)), Vector3(0.0, 0.04, 0.0), Vector3.ZERO, steel)
	# Een koude stookplaats: een kring stenen rond as.
	var fire := _part("FirePit", Vector3(0.2, 0.0, 1.6), 0.0, Vector3.ZERO)
	_mesh(fire, _cyl(0.55, 0.03), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, _flat_mat(Color(0.12, 0.1, 0.09), 1.0))
	var stone := _flat_mat(Color(0.33, 0.22, 0.2), 0.95)
	var rm := SurfaceDressing.rock_mesh(311)
	for k in 8:
		var a := k * TAU / 8.0 + _rng.randf_range(-0.15, 0.15)
		var s := _rng.randf_range(0.15, 0.24)
		var mi := _mesh(fire, rm, Vector3(cos(a) * 0.7, 0.04, sin(a) * 0.7), Vector3(0.0, _rng.randf() * TAU, 0.0), stone)
		mi.scale = Vector3(s * 1.2, s * 0.8, s)


# --- Fossielwereld: een opgraving ----------------------------------------------------------------

func _excavation() -> void:
	var wood := MolVisual.machine_material("Wood", false, 2.0)
	var dark := MolVisual.machine_material("Anthracite", false, 2.0)
	var yellow := MolVisual.machine_material("Yellow", false, 2.0)
	var steel := MolVisual.machine_material("Steel", false, 2.0)
	var tape_red := _flat_mat(Color(0.85, 0.16, 0.1), 0.7)
	var tape_white := _flat_mat(Color(0.92, 0.9, 0.85), 0.7)
	var meshes := MidgroundProps._meshes(null)
	# Het vak: vier dikke paaltjes met een rood-wit lint, 7 × 4,5 m.
	var grid := _part("Trench", Vector3(0.0, 0.0, 0.0), 0.0, Vector3.ZERO)
	var corners := [Vector3(-3.5, 0, -2.25), Vector3(3.5, 0, -2.25), Vector3(3.5, 0, 2.25), Vector3(-3.5, 0, 2.25)]
	for c: Vector3 in corners:
		_mesh(grid, _box(Vector3(0.09, 1.0, 0.09)), c + Vector3(0.0, 0.45, 0.0), Vector3(0.0, 0.3, 0.0), wood)
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := int(a.distance_to(b) / 0.5)
		for j in n: # rood en wit om de 0,5 m (een gestreept lint, licht doorhangend)
			var t0 := float(j) / n
			var t1 := float(j + 1) / n
			var sag := 0.08 * sin(PI * (t0 + t1) * 0.5)
			_beam(grid, a.lerp(b, t0) + Vector3(0.0, 0.82 - sag, 0.0), a.lerp(b, t1) + Vector3(0.0, 0.82 - sag, 0.0), 0.035,
					tape_red if j % 2 == 0 else tape_white)
	# Uitgegraven bodem: een donkerdere vlek (klei van onder het krijt) over het vak.
	_dark_patch(grid, Vector3(0.0, 0.0, 0.0), Vector3(8.0, 3.0, 5.6), Color(0.42, 0.44, 0.44, 0.7))
	# Een half vrijgelegd reuzenbot in het vak (en een wervel), donker versteend zoals het skelet.
	var bone := _part("Bone", Vector3(-0.4, -0.25, 0.2), 0.35, Vector3(4.0, 0.8, 1.0))
	var bi := MeshInstance3D.new()
	bi.mesh = meshes[MidgroundProps.Kind.BONE]
	bi.scale = Vector3.ONE * 4.2
	bi.rotation = Vector3(0.0, 0.0, deg_to_rad(-6.0))
	bone.add_child(bi)
	var vert := _part("Vertebra", Vector3(2.2, -0.12, -1.1), 1.2, Vector3.ZERO)
	var vi := MeshInstance3D.new()
	vi.mesh = meshes[MidgroundProps.Kind.VERTEBRA]
	vi.scale = Vector3.ONE * 2.2
	vert.add_child(vi)
	# De hoop uitgegraven klei naast het vak, met een schep erin.
	var heap := _part("Spoil", Vector3(5.2, 0.0, 0.6), 0.4, Vector3(2.6, 0.9, 2.0))
	var hm := _mesh(heap, SurfaceDressing.rock_mesh(4411, 0.75, 1.1), Vector3(0.0, -0.1, 0.0), Vector3.ZERO, _flat_mat(Color(0.5, 0.53, 0.52), 1.0))
	hm.scale = Vector3(1.5, 0.55, 1.15)
	_beam(heap, Vector3(-0.2, 0.55, 0.1), Vector3(0.25, 1.75, 0.35), 0.06, wood)
	_mesh(heap, _box(Vector3(0.28, 0.36, 0.03)), Vector3(-0.3, 0.42, 0.04), Vector3(0.0, 0.2, deg_to_rad(-20.0)), steel)
	# Een zeef op twee kisten, en een gele kist met gereedschap.
	_prop(meshes[MidgroundProps.Kind.CRATE], Vector3(-5.0, 0.0, -1.2), 0.1, Vector3(1.2, 0.9, 0.9))
	_prop(meshes[MidgroundProps.Kind.CRATE_DARK], Vector3(-5.1, 0.0, 0.6), -0.2, Vector3(1.2, 0.9, 0.9))
	var sieve := _part("Sieve", Vector3(-5.05, 0.92, -0.3), 0.0, Vector3.ZERO)
	_mesh(sieve, _box(Vector3(1.0, 0.1, 1.6)), Vector3(0.0, 0.05, 0.0), Vector3.ZERO, wood)
	_mesh(sieve, _box(Vector3(0.9, 0.02, 1.5)), Vector3(0.0, 0.06, 0.0), Vector3.ZERO, MolVisual.machine_material("Grating", false, 2.0))
	# Werklamp.
	_work_lamp(Vector3(3.9, 0.0, 2.9), 2.4, dark, yellow)


# --- Kristalmaan: een neergestorte sonde ----------------------------------------------------------

func _probe() -> void:
	var hull := MolVisual.machine_material("HullLight", false, 2.0)
	var dark := MolVisual.machine_material("Anthracite", false, 2.0)
	var gold := MolVisual.machine_material("Gold", false, 2.0)
	var panel := _flat_mat(Color(0.12, 0.16, 0.3), 0.35)
	panel.metallic = 0.6
	# Het sleepspoor: een donkere voor van 14 m achter de sonde, met opgeworpen brokken.
	_dark_patch(self, Vector3(0.0, 0.0, -7.5), Vector3(3.2, 3.0, 15.0), Color(0.08, 0.06, 0.1, 0.8))
	var debris := _flat_mat(Color(0.2, 0.16, 0.26), 0.95)
	var rm := SurfaceDressing.rock_mesh(733)
	for k in 9:
		var side := -1.0 if k % 2 == 0 else 1.0
		var p := Vector3(side * _rng.randf_range(1.6, 2.6), 0.0, -_rng.randf_range(1.0, 13.0))
		var s := _rng.randf_range(0.25, 0.6)
		var mi := _mesh(self, rm, p, Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf()), debris)
		mi.scale = Vector3(s * 1.3, s * 0.7, s)
	# De sonde: een bol met een cilinder (de bus), schuin half in de grond.
	var probe := _part("Probe", Vector3(0.0, 0.0, 0.0), 0.0, Vector3(2.4, 1.6, 2.6))
	var body := Node3D.new()
	body.rotation = Vector3(deg_to_rad(-24.0), 0.0, deg_to_rad(14.0))
	body.position = Vector3(0.0, 0.55, 0.0)
	probe.add_child(body)
	_mesh(body, _sphere(1.05), Vector3.ZERO, Vector3.ZERO, hull)
	_mesh(body, _cyl(0.85, 1.7), Vector3(0.0, 0.0, -0.9), Vector3(PI * 0.5, 0.0, 0.0), gold)
	_mesh(body, _cyl(0.9, 0.12), Vector3(0.0, 0.0, -1.75), Vector3(PI * 0.5, 0.0, 0.0), dark)
	_mesh(body, _cyl(0.12, 0.9), Vector3(0.0, 1.2, 0.2), Vector3(0.0, 0.0, 0.0), dark) # antennemast (afgeknakt)
	_blink = _emit_mat(Color(1.0, 0.12, 0.06), 9.0)
	_mesh(body, _sphere(0.1), Vector3(0.0, 1.67, 0.2), Vector3.ZERO, _blink)
	_halo = _halo_at(body, Vector3(0.0, 1.7, 0.2), Color(1.0, 0.2, 0.1), 3.0, 1.4)
	# Het gebroken zonnepaneel ernaast, scheef in de grond.
	var wing := _part("Panel", Vector3(-2.6, 0.0, 1.2), 0.6, Vector3(3.2, 0.5, 1.3))
	_mesh(wing, _box(Vector3(3.2, 0.05, 1.25)), Vector3(0.0, 0.45, 0.0), Vector3(0.0, 0.0, deg_to_rad(16.0)), panel)
	_mesh(wing, _box(Vector3(3.3, 0.08, 0.08)), Vector3(0.0, 0.42, 0.0), Vector3(0.0, 0.0, deg_to_rad(16.0)), dark)
	# Cyane kristallen die door de sonde en rond de inslag gegroeid zijn (ze gloeien), met een licht.
	var shard := GroundScatter._shard()
	var cm := shard.surface_get_material(0) as ShaderMaterial
	cm.set_shader_parameter("glow_energy", 1.4)
	cm.set_shader_parameter("shadow_glow", 0.6)
	for k in 9:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.6, 2.4)
		var s := _rng.randf_range(0.6, 1.7)
		var mi := MeshInstance3D.new()
		mi.mesh = shard
		mi.position = Vector3(cos(a) * r, -0.1, sin(a) * r * 0.8 + 0.4)
		mi.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf() * TAU, _rng.randf_range(-0.6, 0.6))
		mi.scale = Vector3(s * 0.9, s * 1.6, s * 0.9)
		mi.visibility_range_end = HIDE_M
		probe.add_child(mi)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.35, 0.9, 1.0)
	glow.light_energy = 1.2
	glow.omni_range = 8.0
	glow.shadow_enabled = false
	glow.position = Vector3(0.0, 1.2, 0.6)
	probe.add_child(glow)


# --- Bouwstenen ------------------------------------------------------------------------------------

func _work_lamp(pos: Vector3, yaw: float, dark: Material, yellow: Material) -> void:
	var lamp := _part("WorkLamp", pos, yaw, Vector3(0.5, 1.9, 0.5))
	for k in 3:
		var a := k * TAU / 3.0
		_beam(lamp, Vector3(cos(a) * 0.55, 0.0, sin(a) * 0.55), Vector3(0.0, 1.75, 0.0), 0.05, dark)
	_mesh(lamp, _box(Vector3(0.42, 0.32, 0.22)), Vector3(0.0, 1.88, 0.0), Vector3(deg_to_rad(-20.0), 0.0, 0.0), yellow)
	_lamp_mat = _emit_mat(Color(1.0, 0.82, 0.55), 7.0)
	_mesh(lamp, _box(Vector3(0.34, 0.24, 0.03)), Vector3(0.0, 1.85, 0.12), Vector3(deg_to_rad(-20.0), 0.0, 0.0), _lamp_mat)
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.78, 0.5)
	_lamp.light_energy = 1.6
	_lamp.omni_range = 9.0
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, 1.7, 0.6)
	lamp.add_child(_lamp)
	_halo = _halo_at(lamp, Vector3(0.0, 1.85, 0.25), Color(1.0, 0.8, 0.5), 2.2, 1.6)


## Een stuk van de groep (verdwijnt als je eronder graaft), met een botsvorm als `solid` niet nul is.
func _part(part_name: String, pos: Vector3, yaw: float, solid: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = part_name
	n.position = pos
	n.rotation = Vector3(0.0, yaw, 0.0)
	add_child(n)
	# Op de grond eronder (de groep staat op een helling).
	if terrain:
		var w := to_global(pos)
		n.position.y = pos.y + terrain.surface_height_at(w.x, w.z) - global_position.y
	_parts.append(n)
	var cs: CollisionShape3D = null
	if solid != Vector3.ZERO:
		if _body == null:
			_body = StaticBody3D.new()
			_body.name = "Solid"
			_body.collision_layer = Layers.BOUNDS
			_body.collision_mask = 0
			add_child(_body)
		var box := BoxShape3D.new()
		box.size = solid
		cs = CollisionShape3D.new()
		cs.shape = box
		cs.transform = Transform3D(n.basis, n.position + Vector3(0.0, solid.y * 0.5, 0.0))
		_body.add_child(cs)
	_shapes.append(cs)
	return n


func _prop(mesh: Mesh, pos: Vector3, yaw: float, solid: Vector3) -> Node3D:
	var n := _part("Prop", pos, yaw, solid)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.visibility_range_end = HIDE_M
	n.add_child(mi)
	return n


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.visibility_range_end = HIDE_M
	parent.add_child(mi)
	return mi


func _beam(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := SurfaceDressing.beam(parent, a, b, thick, mat)
	mi.visibility_range_end = HIDE_M


## Een donkere vlek op de grond (een projectie: volgt het terrein), zacht aan de rand.
func _dark_patch(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var d := Decal.new()
	d.size = size
	d.texture_albedo = _patch_texture()
	d.modulate = col
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1 # enkel het terrein (laag 1), niet de stukken erop
	d.position = pos
	d.distance_fade_enabled = true
	d.distance_fade_begin = HIDE_M - 60.0
	d.distance_fade_length = 60.0
	parent.add_child(d)


static func _patch_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var u := absf((x + 0.5) / s - 0.5) * 2.0
			var v := absf((y + 0.5) / s - 0.5) * 2.0
			var d := maxf(u * u, v * v * 0.9) + 0.08 * sin(x * 0.9 + y * 0.4)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - smoothstep(0.55, 1.0, d), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _halo_at(parent: Node3D, pos: Vector3, col: Color, energy: float, size_m: float) -> ShaderMaterial:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/ship/ship_halo.gdshader")
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("size_m", size_m)
	mat.set_shader_parameter("min_angle", 0.004)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.visibility_range_end = HIDE_M
	parent.add_child(mi)
	return mat


static func _flat_mat(col: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


static func _emit_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	c.rings = 1
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


## Graaf je onder een stuk, dan verdwijnt het (anders zweeft het).
func _on_dug(center: Vector3, radius_m: float) -> void:
	for i in _parts.size():
		var n := _parts[i]
		if not n.visible:
			continue
		var p := n.global_position
		if Vector2(p.x - center.x, p.z - center.z).length() < radius_m + 0.8 and p.y > center.y - radius_m - 1.0:
			n.visible = false
			if _shapes[i]:
				(_shapes[i] as CollisionShape3D).set_deferred("disabled", true)
