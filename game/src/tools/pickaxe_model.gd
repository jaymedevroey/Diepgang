class_name PickaxeModel
extends RefCounted
## Bouwt het houweel voor in beeld uit primitieven (tijdelijk; later een Blender-model).
## Oorsprong = de hand. De steel loopt langs +Y, de punt van de kop wijst naar -Z.

const WOOD := Color(0.42, 0.27, 0.15)
const METAL := Color(0.36, 0.37, 0.4)
const GLOVE := Color(0.95, 0.55, 0.12) # robotkleur van speler 1
## Renderlaag voor gereedschap in beeld (laag 2), zodat een vullicht enkel dat raakt.
const VIEWMODEL_LAYER := 1 << 1


static func build(viewmodel_fov: float) -> Node3D:
	var root := Node3D.new()
	root.name = "PickaxeModel"

	var handle := CylinderMesh.new()
	handle.top_radius = 0.018
	handle.bottom_radius = 0.022
	handle.height = 0.62
	handle.radial_segments = 10
	_add(root, handle, _mat(WOOD, 0.85, 0.0, viewmodel_fov), Vector3(0, 0.22, 0))

	# Kop: blok + punt naar voren (licht gebogen) + platte beitel naar achteren.
	var head := Node3D.new()
	head.position = Vector3(0, 0.5, 0)
	root.add_child(head)
	var block := BoxMesh.new()
	block.size = Vector3(0.05, 0.065, 0.075)
	var metal := _mat(METAL, 0.45, 0.8, viewmodel_fov)
	_add(head, block, metal, Vector3.ZERO)

	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.026
	spike.height = 0.24
	spike.radial_segments = 8
	var s := _add(head, spike, metal, Vector3(0, -0.02, -0.14))
	s.rotation = Vector3(deg_to_rad(-100), 0, 0)

	var adze := CylinderMesh.new()
	adze.top_radius = 0.004
	adze.bottom_radius = 0.028
	adze.height = 0.15
	adze.radial_segments = 8
	var a := _add(head, adze, metal, Vector3(0, -0.01, 0.1))
	a.rotation = Vector3(deg_to_rad(95), 0, 0)
	a.scale = Vector3(1.7, 1.0, 0.45)

	var ring := CylinderMesh.new()
	ring.top_radius = 0.026
	ring.bottom_radius = 0.026
	ring.height = 0.03
	_add(head, ring, metal, Vector3(0, -0.045, 0))

	# Robothandschoen rond de greep.
	var glove := CapsuleMesh.new()
	glove.radius = 0.045
	glove.height = 0.13
	_add(root, glove, _mat(GLOVE, 0.55, 0.1, viewmodel_fov), Vector3(0.0, 0.0, 0.0))
	var knuckle := BoxMesh.new()
	knuckle.size = Vector3(0.07, 0.05, 0.06)
	_add(root, knuckle, _mat(GLOVE.darkened(0.3), 0.6, 0.1, viewmodel_fov), Vector3(0.0, 0.0, -0.03))
	return root


static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 1 | VIEWMODEL_LAYER
	parent.add_child(mi)
	return mi


## Viewmodel-materiaal: eigen FOV en z-clip-schaal, zodat het niet door muren steekt.
static func _mat(color: Color, roughness: float, metallic: float, fov: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.use_z_clip_scale = true
	m.z_clip_scale = 0.3
	m.use_fov_override = true
	m.fov_override = fov
	return m
