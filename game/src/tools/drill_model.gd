class_name DrillModel
extends RefCounted
## De boor uit tools.glb (zie PickaxeModel). Oorsprong = de hand (greep).
## Het bit wijst naar -Z en heet "Bit" (draait rond Z); de handschoen volgt de schuine greep.

const GRIP_TILT := -15.0 # graden: de pistoolgreep helt naar voren
## Boor T2 (golf 3, binnen2-11): een andere kleur (carbide-oranje in plaats van DIG-geel) en een
## gouden carbidepunt op het bit, naast de cyane band en het label T2 uit het model.
const T2_COLOR := Color("#D9502A")


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
	# Boor T2 (F1): cyane band en het label T2 over de behuizing, enkel zichtbaar met de upgrade.
	if PickaxeModel.has_part("Drill_T2"):
		var t2 := PickaxeModel.part("Drill_T2", viewmodel_fov, color, viewmodel)
		t2.name = "T2"
		t2.visible = false
		root.add_child(t2)
	# Gouden carbidepunt (T2) op het bit: draait mee, enkel zichtbaar met de upgrade.
	var tip := MeshInstance3D.new()
	tip.name = "T2Tip"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.034
	cone.height = 0.085
	cone.radial_segments = 10
	tip.mesh = cone
	tip.material_override = PickaxeModel.material("Gold", viewmodel_fov if viewmodel else 0.0, color)
	tip.rotation = Vector3(-PI / 2.0, 0.0, 0.0) # de punt naar −z
	tip.position = Vector3(0.0, 0.0, -0.235)
	tip.visible = false
	if viewmodel:
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tip.layers = PickaxeModel.VIEWMODEL_LAYER
	bit.add_child(tip)
	if viewmodel:
		var glove := PickaxeModel.part("Glove", viewmodel_fov, color, viewmodel)
		glove.rotation_degrees = Vector3(GRIP_TILT, 0, 0)
		root.add_child(glove)
	return root


## T1 of T2 tonen: de band en het label T2, de carbidepunt, en de kleur van de behuizing.
static func set_tier(root: Node3D, t2: bool) -> void:
	var band := root.get_node_or_null("T2") as Node3D
	if band:
		band.visible = t2
	var tip := root.get_node_or_null("Bit/T2Tip") as Node3D
	if tip:
		tip.visible = t2
	var body := root.get_node_or_null("Drill") as MeshInstance3D
	if body == null:
		return
	for i in body.mesh.get_surface_count():
		var src := body.mesh.surface_get_material(i)
		if src == null or src.resource_name != "Yellow":
			continue
		if not body.has_meta("t1_mat_%d" % i):
			body.set_meta("t1_mat_%d" % i, body.get_surface_override_material(i))
		var t1: Material = body.get_meta("t1_mat_%d" % i)
		if not t2:
			body.set_surface_override_material(i, t1)
			continue
		var fov := 0.0
		if t1 is ShaderMaterial and (t1 as ShaderMaterial).get_shader_parameter("viewmodel") == true:
			fov = float((t1 as ShaderMaterial).get_shader_parameter("viewmodel_fov"))
		body.set_surface_override_material(i, MolVisual.machine_material("PlayerColor", false, PickaxeModel.DETAIL, fov, T2_COLOR, 0.35))
