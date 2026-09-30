class_name FossilModel
extends RefCounted
## Procedurele fossielstukken (GDD §4, vondstfamilie 1: skeletten). Eén mesh per stuk,
## samengevoegd met SurfaceTool. Oorsprong = midden van het stuk.

enum Kind { FEMUR, VERTEBRA, RIB, SKULL, CLAW }

const NAMES: Array[String] = ["Dijbeen", "Wervel", "Rib", "Schedel", "Klauw"]
const BASE_VALUES: Array[int] = [180, 60, 45, 350, 90]
const MASSES: Array[float] = [8.0, 3.0, 2.0, 14.0, 2.0]
## Kans per soort (som hoeft niet 1 te zijn).
const WEIGHTS: Array[float] = [25.0, 30.0, 25.0, 5.0, 15.0]
const BONE := Color(0.87, 0.81, 0.66)


static func pick_kind(rng: RandomNumberGenerator) -> Kind:
	var total := 0.0
	for w in WEIGHTS:
		total += w
	var r := rng.randf() * total
	for i in WEIGHTS.size():
		r -= WEIGHTS[i]
		if r <= 0.0:
			return i as Kind
	return Kind.VERTEBRA


static func build_mesh(kind: Kind) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		Kind.FEMUR:
			_add(st, _capsule(0.045, 0.62), Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3.ZERO))
			for side in [-1.0, 1.0]:
				_add(st, _sphere(0.075), Transform3D(Basis(), Vector3(side * 0.31, 0.02, 0.03)))
				_add(st, _sphere(0.06), Transform3D(Basis(), Vector3(side * 0.3, -0.03, -0.035)))
		Kind.VERTEBRA:
			_add(st, _cylinder(0.1, 0.1, 0.075), Transform3D())
			_add(st, _cylinder(0.0, 0.028, 0.17), Transform3D(Basis(), Vector3(0, 0.12, -0.02)))
			for side in [-1.0, 1.0]:
				_add(st, _capsule(0.022, 0.16), Transform3D(Basis(Vector3.FORWARD, side * 1.2), Vector3(side * 0.13, 0.03, 0)))
		Kind.RIB:
			var segments := 7
			for i in segments:
				var a := lerpf(-0.9, 0.9, float(i) / (segments - 1))
				var p := Vector3(sin(a) * 0.34, cos(a) * 0.34 - 0.28, 0)
				var r := lerpf(0.026, 0.017, float(i) / segments)
				_add(st, _capsule(r, 0.13), Transform3D(Basis(Vector3.FORWARD, -a), p))
		Kind.SKULL:
			_add(st, _sphere(0.16), Transform3D(Basis().scaled(Vector3(1.15, 0.85, 1.0)), Vector3.ZERO))
			_add(st, _capsule(0.075, 0.32), Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, -0.04, -0.2)))
			_add(st, _capsule(0.035, 0.34), Transform3D(Basis(Vector3.RIGHT, PI / 2.2), Vector3(0, -0.13, -0.16)))
			for side in [-1.0, 1.0]:
				_add(st, _sphere(0.05), Transform3D(Basis(), Vector3(side * 0.1, 0.05, -0.1)))
		Kind.CLAW:
			var pos := Vector3.ZERO
			var ang := 0.0
			for i in 5:
				var r := lerpf(0.045, 0.008, float(i) / 5.0)
				var r2 := lerpf(0.045, 0.008, float(i + 1) / 5.0)
				_add(st, _cylinder(r2, r, 0.07), Transform3D(Basis(Vector3.FORWARD, -ang), pos))
				pos += Vector3(sin(ang), cos(ang), 0) * 0.065
				ang += 0.28
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, bone_material())
	return mesh


static var _bone_material: StandardMaterial3D


static func bone_material() -> StandardMaterial3D:
	if _bone_material == null:
		_bone_material = StandardMaterial3D.new()
		_bone_material.albedo_color = BONE
		_bone_material.roughness = 0.65
		_bone_material.emission_enabled = true
		_bone_material.emission = Color(1.0, 0.9, 0.7)
		_bone_material.emission_energy_multiplier = 0.0
	return _bone_material


static func _add(st: SurfaceTool, mesh: Mesh, xf: Transform3D) -> void:
	st.append_from(mesh, 0, xf)


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


static func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	return m
