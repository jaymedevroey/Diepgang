class_name DrillModel
extends RefCounted
## De boor uit tools.glb (zie PickaxeModel). Oorsprong = de hand (greep).
## Het bit wijst naar -Z en heet "Bit" (draait rond Z); de handschoen volgt de schuine greep.

const GRIP_TILT := -15.0 # graden: de pistoolgreep helt naar voren


static func build(viewmodel_fov: float, color: Color, viewmodel := true) -> Node3D:
	var root := Node3D.new()
	root.name = "DrillModel"
	root.add_child(PickaxeModel.part("Drill", viewmodel_fov, color, viewmodel))
	# Het bit draait rond zijn eigen draaipunt (de klauwplaat).
	var bit_mesh := PickaxeModel.part("Drill_Bit", viewmodel_fov, color, viewmodel)
	var bit := Node3D.new()
	bit.name = "Bit"
	bit.position = bit_mesh.position
	bit_mesh.position = Vector3.ZERO
	bit.add_child(bit_mesh)
	root.add_child(bit)
	if viewmodel:
		var glove := PickaxeModel.part("Glove", viewmodel_fov, color, viewmodel)
		glove.rotation_degrees = Vector3(GRIP_TILT, 0, 0)
		root.add_child(glove)
	return root
