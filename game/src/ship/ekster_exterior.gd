class_name EksterExterior
extends Node3D
## De Ekster van buiten (tools/blender/ekster_exterior.py): het schip dat boven de landingsplek
## hangt. Enkel om te zien (geen botsvormen): de ruimte waar je rondloopt is een apart model
## (Ekster, de hub), elders in de wereld. De Mol stapt over tussen de baai van de hub en de baai
## van dit schip (zie Mol: drop en ophalen). De grijper hangt hier, aan een kabel, en zakt tot op
## de Mol bij het ophalen.

const MODEL := preload("res://assets/models/ekster_exterior.glb")
## Hoogte van de baai boven de landingsplek (m).
const ALTITUDE := 340.0
## Grijperklauwen: van de oorsprong van de grijper tot onder de klauwen (m).
const GRAPPLE_REACH := 3.0

var model: Node3D
## Grijper: meter onder zijn rustplek in de baai (gezet door de Mol).
var grapple_depth := 0.0

var _dock_local := Vector3.ZERO
var _grapple: Node3D
var _cable: Node3D # hangt aan zijn bovenkant; de schaal in y is de lengte
var _nav: Array[StandardMaterial3D] = []
var _time := 0.0


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
				cache[mat_name] = MolVisual.palette_material(mat_name, src, false)
				if mat_name in ["NavRed", "NavGreen"] and cache[mat_name] is StandardMaterial3D:
					_nav.append(cache[mat_name])
			if cache[mat_name]:
				mi.set_surface_override_material(i, cache[mat_name])
	_build_grapple()
	_build_lights()


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
	update_grapple()
	# Navigatielichten knipperen.
	var on := fmod(_time, 1.6) < 0.25
	for m in _nav:
		m.emission_energy_multiplier = 6.0 if on else 0.4


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
