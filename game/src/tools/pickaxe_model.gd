class_name PickaxeModel
extends RefCounted
## Gereedschapsmodellen uit Blender (tools/blender/tools.py → assets/models/tools.glb):
## houweel, boor, boorspiraal en de robothandschoen. Materialen = de machine-shader van de Mol
## (geel, antraciet, kaal staal met slijtage), in first person met een eigen gezichtsveld.
## Oorsprong van het houweel = de hand. De steel loopt langs +Y, de punt van de kop wijst naar -Z.

const GLOVE := Color(0.95, 0.55, 0.12) # robotkleur van speler 1
## Renderlaag voor gereedschap in beeld (laag 2), zodat een vullicht enkel dat raakt.
const VIEWMODEL_LAYER := 1 << 1
const SOURCE := preload("res://assets/models/tools.glb")
## Kleine voorwerpen: fijnere slijtvlekken en strepen dan op de Mol.
const DETAIL := 7.0
const EMISSIVE := {"Lens": [Color(1.0, 0.85, 0.6), 2.5], "Cyan": [Color(0.31, 0.89, 0.94), 2.5]}

static var _parts: Dictionary = {} # naam -> [mesh, transform]
static var _materials: Dictionary = {}


## `viewmodel` = in first-person voor de eigen camera (eigen FOV, z-clip, renderlaag 2) mét handschoen.
## Zonder: gewoon in de wereld, in de hand van een robot.
static func build(viewmodel_fov: float, glove_color := GLOVE, viewmodel := true) -> Node3D:
	var root := Node3D.new()
	root.name = "PickaxeModel"
	root.add_child(part("Pickaxe", viewmodel_fov, glove_color, viewmodel))
	if viewmodel:
		root.add_child(part("Glove", viewmodel_fov, glove_color, viewmodel))
	return root


## Kopie van een onderdeel uit tools.glb (zelfde plaats t.o.v. de oorsprong) met de juiste materialen.
static func part(name: String, viewmodel_fov: float, tint: Color, viewmodel: bool) -> MeshInstance3D:
	var src: Array = _source(name)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = src[0]
	mi.transform = src[1]
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		mi.set_surface_override_material(i, material(m.resource_name if m else "", viewmodel_fov if viewmodel else 0.0, tint))
	if viewmodel:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = VIEWMODEL_LAYER
	return mi


static func material(name: String, viewmodel_fov: float, tint: Color) -> Material:
	var key := "%s|%.1f|%s" % [name, viewmodel_fov, tint.to_html() if name == "PlayerColor" else ""]
	if _materials.has(key):
		return _materials[key]
	# Gereedschap is klein en dun: de slijtage van de Mol (randen, holtes) zou er overal zitten.
	var m: Material = MolVisual.machine_material(name, false, DETAIL, viewmodel_fov, tint, 0.35)
	if m == null:
		var sm := StandardMaterial3D.new()
		if EMISSIVE.has(name):
			sm.albedo_color = EMISSIVE[name][0]
			sm.emission_enabled = true
			sm.emission = EMISSIVE[name][0]
			sm.emission_energy_multiplier = EMISSIVE[name][1]
		else:
			sm.albedo_color = Color(0.5, 0.5, 0.5)
		if viewmodel_fov > 0.0:
			sm.use_z_clip_scale = true
			sm.z_clip_scale = 0.3
			sm.use_fov_override = true
			sm.fov_override = viewmodel_fov
		m = sm
	_materials[key] = m
	return m


## Zit dit onderdeel in tools.glb? (Nieuwe onderdelen, zoals de scanner en de T2-band, F1.)
static func has_part(name: String) -> bool:
	if _parts.is_empty():
		_source("Pickaxe")
	return _parts.has(name)


## Mesh en plaats van een onderdeel; de scène wordt één keer geopend en meteen weer vrijgegeven.
static func _source(name: String) -> Array:
	if _parts.is_empty():
		var root := SOURCE.instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			_parts[mi.name] = [mi.mesh, mi.transform]
		root.free()
	return _parts[name]
