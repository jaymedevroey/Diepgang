class_name DrillModel
extends RefCounted
## Bouwt de boor uit primitieven (tijdelijk; later een Blender-model).
## Oorsprong = de hand (greep). Het bit wijst naar -Z en heet "Bit" (draait rond Z).

const METAL := Color(0.36, 0.37, 0.4)
const DARK := Color(0.08, 0.085, 0.1)


static func build(viewmodel_fov: float, color: Color, viewmodel := true) -> Node3D:
	PickaxeModel._viewmodel = viewmodel
	var root := Node3D.new()
	root.name = "DrillModel"
	var body := PickaxeModel._mat(color, 0.45, 0.1, viewmodel_fov)
	var dark := PickaxeModel._mat(DARK, 0.6, 0.2, viewmodel_fov)
	var metal := PickaxeModel._mat(METAL, 0.35, 0.85, viewmodel_fov)

	# Greep (schuin naar beneden) en behuizing erboven.
	var grip := BoxMesh.new()
	grip.size = Vector3(0.05, 0.14, 0.06)
	var g := PickaxeModel._add(root, grip, dark, Vector3(0, 0.02, 0.0))
	g.rotation_degrees = Vector3(-15, 0, 0)
	var housing := CylinderMesh.new()
	housing.top_radius = 0.065
	housing.bottom_radius = 0.075
	housing.height = 0.26
	housing.radial_segments = 16
	var h := PickaxeModel._add(root, housing, body, Vector3(0, 0.12, -0.04))
	h.rotation_degrees = Vector3(-90, 0, 0)
	var cap := SphereMesh.new()
	cap.radius = 0.075
	cap.height = 0.12
	PickaxeModel._add(root, cap, body, Vector3(0, 0.12, 0.09))
	# Koelribben en een batterij onderaan.
	for i in 3:
		var rib := TorusMesh.new()
		rib.inner_radius = 0.066
		rib.outer_radius = 0.078
		var r := PickaxeModel._add(root, rib, dark, Vector3(0, 0.12, 0.02 - i * 0.035))
		r.rotation_degrees = Vector3(90, 0, 0)
	var battery := BoxMesh.new()
	battery.size = Vector3(0.07, 0.05, 0.1)
	PickaxeModel._add(root, battery, dark, Vector3(0, -0.07, 0.01))

	# Kop: klauwplaat + bit (kegel met twee spiraalribben).
	var chuck := CylinderMesh.new()
	chuck.top_radius = 0.035
	chuck.bottom_radius = 0.045
	chuck.height = 0.06
	var c := PickaxeModel._add(root, chuck, metal, Vector3(0, 0.12, -0.2))
	c.rotation_degrees = Vector3(-90, 0, 0)
	var bit := Node3D.new()
	bit.name = "Bit"
	bit.position = Vector3(0, 0.12, -0.23)
	root.add_child(bit)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.032
	cone.height = 0.24
	cone.radial_segments = 12
	var k := PickaxeModel._add(bit, cone, metal, Vector3(0, 0, -0.12))
	k.rotation_degrees = Vector3(-90, 0, 0)
	for i in 2:
		var flute := BoxMesh.new()
		flute.size = Vector3(0.012, 0.05, 0.2)
		var f := PickaxeModel._add(bit, flute, metal, Vector3(0, 0, -0.11))
		f.rotation_degrees = Vector3(0, 0, i * 90 + 20)
		f.scale = Vector3(1, 1, 1)
	return root
