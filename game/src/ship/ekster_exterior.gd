class_name EksterExterior
extends Node3D
## De Ekster van buiten (tools/blender/ekster_exterior.py): het schip dat boven de landingsplek
## hangt. Enkel om te zien (geen botsvormen): de ruimte waar je rondloopt is een apart model
## (Ekster, de hub), elders in de wereld. De Mol stapt over tussen de baai van de hub en de baai
## van dit schip (zie Mol: drop en ophalen). De grijper hangt hier, aan een kabel, en zakt tot op
## de Mol bij het ophalen.

const MODEL := preload("res://assets/models/ekster_exterior.glb")
## De romp (release-audit buiten-10, ronde 2): platen, nagels, strepen, roet en krassen in de shader,
## op de grote rompmaterialen; ook antraciet krijgt strepen en roet, maar geen platen (kleine stukken).
const HULL_SHADER := preload("res://src/ship/ship_hull.gdshader")
const HULL_PLATING := {"HullGrey": 1.0, "HullDark": 1.0, "HullLight": 1.0, "GreyGreen": 1.0, "RedOxide": 1.0, "Anthracite": 0.0}
## Hoogte van de baai boven de landingsplek (m).
const ALTITUDE := 340.0
## Grijperklauwen: van de oorsprong van de grijper tot onder de klauwen (m).
const GRAPPLE_REACH := 3.0
## Motoren (tools/blender/ekster_exterior.py ENGINES): x, y, straal; de straalpijp eindigt op z 85,4.
const ENGINES: Array[Vector3] = [Vector3(-7.0, 4.5, 3.2), Vector3(0.0, 5.0, 3.4), Vector3(7.0, 4.5, 3.2),
		Vector3(-3.8, -2.6, 2.9), Vector3(3.8, -2.6, 2.9)]
## Hefstralen onder de buik (het schip hangt op stuwkracht, niet dood stil in de lucht).
const LIFT_JETS: Array[Vector3] = [Vector3(-8.5, -7.8, -36.0), Vector3(8.5, -7.8, -36.0), Vector3(-4.5, -7.3, 75.0),
		Vector3(4.5, -7.3, 75.0)]

var model: Node3D
## Grijper: meter onder zijn rustplek in de baai (gezet door de Mol).
var grapple_depth := 0.0

var _dock_local := Vector3.ZERO
var _grapple: Node3D
var _cable: Node3D # hangt aan zijn bovenkant; de schaal in y is de lengte
var _nav: Array[StandardMaterial3D] = []
var _nav_halos: Array[ShaderMaterial] = []
var _strobe_halo: ShaderMaterial
var _time := 0.0
var _hull_mats: Array[ShaderMaterial] = []
var _hull_xf := Transform3D()


func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	var dock := model.find_child("Mol_Dock", true, false) as Node3D
	_dock_local = dock.position if dock else Vector3.ZERO
	var cache := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat_name := src.resource_name if src else ""
			if not cache.has(mat_name):
				cache[mat_name] = _hull_material(mat_name) if HULL_PLATING.has(mat_name) else MolVisual.palette_material(mat_name, src, false)
				if mat_name in ["NavRed", "NavGreen"] and cache[mat_name] is StandardMaterial3D:
					_nav.append(cache[mat_name])
			if cache[mat_name]:
				mi.set_surface_override_material(i, cache[mat_name])
	_build_grapple()
	_build_lights()
	_build_glows()
	_sync_hull_space()


## Rompmateriaal: de instellingen van het machinemateriaal (MolVisual.MATS) in ship_hull.gdshader.
func _hull_material(mat_name: String) -> ShaderMaterial:
	var p: Dictionary = MolVisual.MATS[mat_name]
	var m := ShaderMaterial.new()
	m.shader = HULL_SHADER
	m.set_shader_parameter("albedo", p.albedo)
	m.set_shader_parameter("metallic", p.metallic)
	m.set_shader_parameter("roughness", p.roughness)
	m.set_shader_parameter("edge_wear", p.edge)
	m.set_shader_parameter("grime", p.grime)
	m.set_shader_parameter("bare_metal", p.get("bare", Color(0.62, 0.62, 0.6)))
	m.set_shader_parameter("plating", HULL_PLATING[mat_name])
	_hull_mats.append(m)
	return m


## De shader rekent in de ruimte van het schip (rijen platen, "onder", het motorblok achteraan).
func _sync_hull_space() -> void:
	if global_transform == _hull_xf and is_inside_tree():
		return
	_hull_xf = global_transform
	var inv := Projection(_hull_xf.affine_inverse())
	for m in _hull_mats:
		m.set_shader_parameter("ship_inv", inv)


## Plek voor de baai van een wereld: de Mol hangt ALTITUDE boven de landingsplek.
static func dock_above(terrain: TerrainAPI) -> Vector3:
	var c := terrain.shaft_center_world()
	return Vector3(c.x, terrain.surface_height_at(c.x, c.z) + ALTITUDE, c.z)


## Zet het schip zo dat de Mol in de baai op `dock` hangt.
func place_dock_at(dock: Vector3) -> void:
	global_position = dock - _dock_local


## Waar de Mol in de baai hangt (as van de Mol).
func dock_position() -> Vector3:
	return to_global(_dock_local)


## Grijper en kabel op `grapple_depth` zetten. Ook de Mol roept dit (in zijn _process), met de diepte
## van zijn getekende (geïnterpoleerde) dak, zodat de klauwen tijdens het optrekken op het dak
## blijven en niet een tick voor- of achterlopen (pakket C).
func update_grapple() -> void:
	var rest := grapple_rest_world() - global_position
	_grapple.position = rest - Vector3(0.0, grapple_depth, 0.0)
	_cable.position = rest + Vector3(0.0, 0.5, 0.0)
	_cable.scale = Vector3(1.0, maxf(0.05, grapple_depth + 0.5), 1.0)
	_cable.visible = grapple_depth > 0.5


## Rustplek van de grijper (wereld): net boven het dak van een Mol in de baai.
func grapple_rest_world() -> Vector3:
	return dock_position() + Vector3(0.0, Mol.HOOK.y + GRAPPLE_REACH, 0.0)


func _process(delta: float) -> void:
	_time += delta
	_sync_hull_space()
	update_grapple()
	# Navigatielichten knipperen.
	var on := fmod(_time, 1.6) < 0.25
	for m in _nav:
		m.emission_energy_multiplier = 6.0 if on else 0.4
	for h in _nav_halos:
		h.set_shader_parameter("blink", 1.0 if on else 0.12)
	# Flitser op de mast: twee korte flitsen om de 2,2 s.
	var st := fmod(_time + 0.7, 2.2)
	_strobe_halo.set_shader_parameter("blink", 1.0 if st < 0.07 or (st > 0.2 and st < 0.27) else 0.0)


func _build_grapple() -> void:
	# Grijper: een gele naaf met vier klauwen, en een stalen kabel die mee uitrekt.
	_grapple = Node3D.new()
	_grapple.name = "Grapple"
	add_child(_grapple)
	var yellow := MolVisual.machine_material("Yellow")
	var dark := MolVisual.machine_material("DarkSteel")
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 1.4
	hm.bottom_radius = 1.6
	hm.height = 1.2
	hub.mesh = hm
	hub.material_override = yellow
	hub.position = Vector3(0, -0.6, 0)
	_grapple.add_child(hub)
	for k in 4:
		var a := k * PI / 2 + PI / 4
		var claw := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.5, 2.6, 0.7)
		claw.mesh = cm
		claw.material_override = dark
		claw.position = Vector3(cos(a) * 1.7, -2.0, sin(a) * 1.7)
		claw.rotation = Vector3(0, -a, deg_to_rad(12.0))
		_grapple.add_child(claw)
	_cable = Node3D.new()
	_cable.name = "Cable"
	add_child(_cable)
	# Bewegen in _process (update_grapple): zonder fysica-interpolatie (gevoel-02).
	_grapple.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cable.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var wire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	# Dik genoeg om van ver te lezen als een kabel, geen draadje (buiten-5).
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 1.0
	cyl.radial_segments = 10
	wire.mesh = cyl
	wire.material_override = MolVisual.machine_material("Steel")
	wire.position = Vector3(0, -0.5, 0) # van 0 tot −1: de schaal van de node rekt hem uit
	_cable.add_child(wire)


## Leven van buiten (buiten-10: "het schip hangt dood stil"): stuwgloed uit de motoren en de
## hefstralen, en halo's rond de navigatielichten, de flitser en de buiklichten, die je van op de
## grond (340 m) nog ziet. Enkel om te zien, geen schaduw, geen mist (zie ship_glow/ship_halo).
func _build_glows() -> void:
	var glow := preload("res://src/ship/ship_glow.gdshader")
	var halo := preload("res://src/ship/ship_halo.gdshader")
	var k := 0
	var nozzles: Array[Vector4] = [] # x, y, z van de straalpijp, straal
	for e in ENGINES:
		nozzles.append(Vector4(e.x, e.y, 85.4, e.z))
	for s in [-1.0, 1.0]:
		for lx in [-3.6, 3.6]:
			var p := _arm_point(lx, 0.0, s)
			nozzles.append(Vector4(p.x, p.y, 89.4, 2.5))
	for nz in nozzles:
		var length := nz.w * 5.0
		_glow_cone(glow, Vector3(nz.x, nz.y, nz.z + length * 0.5), nz.w * 0.8, nz.w * 0.15, length,
				Vector3(-PI / 2.0, 0.0, 0.0), Color(0.55, 0.75, 1.0), 2.4, k)
		k += 1
	for j in LIFT_JETS:
		_glow_cone(glow, j - Vector3(0.0, 4.5, 0.0), 1.9, 0.7, 9.0, Vector3.ZERO, Color(0.5, 0.7, 1.0), 0.8, k)
		k += 1
	# Navigatielichten (rood bakboord, groen stuurboord) op de boeg en de uiteinden van de armen.
	for nav: Array in [[Vector3(-15.8, 6.0, -78.0), Color(1.0, 0.12, 0.08)], [Vector3(15.8, 6.0, -78.0), Color(0.2, 1.0, 0.4)],
			[_arm_point(-7.5, 0.0, -1.0) + Vector3(0.0, 0.0, 84.0), Color(1.0, 0.12, 0.08)],
			[_arm_point(7.5, 0.0, 1.0) + Vector3(0.0, 0.0, 84.0), Color(0.2, 1.0, 0.4)]]:
		_nav_halos.append(_halo(halo, nav[0], nav[1], 4.0, 2.4, 0.007))
	_strobe_halo = _halo(halo, Vector3(3.0, 25.8, -20.0), Color(0.95, 0.97, 1.0), 6.0, 3.0, 0.01)
	# Buiklichten (warm, rustig): van onder het schip een paar lichtjes in de waas.
	for b in [Vector3(0.0, -10.6, -40.0), Vector3(0.0, -10.6, -20.0), Vector3(0.0, -9.6, 20.0), Vector3(0.0, -9.6, 50.0)]:
		_halo(halo, b, Color(1.0, 0.72, 0.42), 2.2, 2.0, 0.005)


## Punt op een arm (doorsnede-coördinaten px, py) zoals _xf in het Blender-script: de armen hangen
## op ±19 m, 1 m hoog, en kantelen 32°.
static func _arm_point(px: float, py: float, s: float) -> Vector3:
	var r := deg_to_rad(-s * 32.0)
	return Vector3(px * cos(r) - py * sin(r) + s * 19.0, px * sin(r) + py * cos(r) + 1.0, 0.0)


func _glow_cone(shader: Shader, pos: Vector3, r_top: float, r_end: float, length: float, rot: Vector3, col: Color,
		energy: float, seed_i: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_end
	mesh.height = length
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("seed", float(seed_i))
	var mi := MeshInstance3D.new()
	mi.name = "Glow%d" % seed_i
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _halo(shader: Shader, pos: Vector3, col: Color, energy: float, size_m: float, min_angle: float) -> ShaderMaterial:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("size_m", size_m)
	mat.set_shader_parameter("min_angle", min_angle)
	var mi := MeshInstance3D.new()
	mi.name = "Halo"
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 64.0 # de shader maakt hem van ver groter dan zijn mesh
	mi.position = pos
	add_child(mi)
	return mat


func _build_lights() -> void:
	# Schijnwerpers onder de baai: je ziet de Mol vallen en terugkomen, ook in de schaduw van het schip.
	for x in [-6.0, 6.0]:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.86, 0.66)
		s.light_energy = 5.0
		s.spot_range = 120.0
		s.spot_angle = 16.0
		s.shadow_enabled = false
		add_child(s)
		s.position = _dock_local + Vector3(x, -2.0, 0)
		s.rotation = Vector3(-PI / 2, 0, 0)
