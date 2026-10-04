class_name SurfaceDressing
extends RefCounted
## Wat er op het verre landschap staat (blokmodel, docs/research/planeten.md §3–4): rotsblokken
## (dicht onder de kraterwand, verspreid op de bodem), een booreiland met een rood lampje op de
## terrassen van de verlaten mijnput, en een pijpleiding over de kraterbodem. Van boven geven ze
## schaal en schaduw, en ze tonen dat hier al eerder gegraven werd.
## Posities op de werkthread (`compute`, enkel uit de seed), meshes op de hoofdthread (`commit`).
## Binnen het speelgebied niets: daar staan de rotsblokken van de generator (voxels).

const ROCK_CELL := 24.0
const ROCK_REACH := 1150.0 # m van de landingsplek
const ROCK_HIDE_M := 1300.0
const CHUNK := 512.0 # m: rotsen per vak in een eigen MultiMesh (die valt als geheel weg)
const PIPE_LENGTH := 1700.0
const PIPE_STEP := 12.0
const ROCK_COLOR := Color("6a3a2b")
const RED_LIGHT := Color(1.0, 0.16, 0.08)


## Op de werkthread: waar alles staat.
static func compute(s: PlanetSurface) -> Dictionary:
	var lf := s.landform
	var rocks: Array[Transform3D] = []
	var tints := PackedColorArray()
	var c0x := int(floor((lf.landing.x - ROCK_REACH) / ROCK_CELL))
	var c1x := int(floor((lf.landing.x + ROCK_REACH) / ROCK_CELL))
	var c0z := int(floor((lf.landing.y - ROCK_REACH) / ROCK_CELL))
	var c1z := int(floor((lf.landing.y + ROCK_REACH) / ROCK_CELL))
	var inner := lf.crater_r - lf.wall_w
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var cell_c := Vector2((cx + 0.5) * ROCK_CELL, (cz + 0.5) * ROCK_CELL)
			var from_landing := cell_c.distance_to(lf.landing)
			if from_landing > ROCK_REACH:
				continue
			var rng := s._cell_rng(cx, cz, 7)
			var d := lf.crater_d(cell_c)
			# Puin onder de wand (afgebrokkeld), weinig in de put, matig op de bodem en het plateau.
			var talus := smoothstep(inner - 90.0, inner - 10.0, d) * (1.0 - smoothstep(inner + 25.0, inner + 60.0, d))
			var in_pit := cell_c.distance_to(lf.pit_c) < lf.pit_r
			var density := 0.42 + 3.2 * talus
			if in_pit:
				density = 0.15
			elif d > lf.crater_r:
				density = 0.3
			var count := int(density) + (1 if rng.randf() < fmod(density, 1.0) else 0)
			for k in count:
				var x := (cx + rng.randf()) * ROCK_CELL
				var z := (cz + rng.randf()) * ROCK_CELL
				var size := lerpf(0.7, 3.6, pow(rng.randf(), 2.4)) * lerpf(1.0, 2.4, talus)
				var rot := Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
				var sc := Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.45, 0.85), size * rng.randf_range(0.8, 1.3))
				if s.outside(x, z) < 6.0 + size:
					continue
				var y: float = s.far_height(x, z) - sc.y * 0.3
				rocks.append(Transform3D(Basis.from_euler(rot).scaled(sc), Vector3(x, y, z)))
				var t := lf.tint(x, z)
				var v := rng.randf_range(0.82, 1.12)
				tints.append(Color(ROCK_COLOR.r * v * lerpf(1.0, t.r, 0.35), ROCK_COLOR.g * v * lerpf(1.0, t.g, 0.35), ROCK_COLOR.b * v * lerpf(1.0, t.b, 0.35)))
	# Het booreiland op een terras van de put (half naar de rand), de pijpleiding de bodem over.
	var rig_xz := lf.pit_c + (lf.landing - lf.pit_c).normalized().rotated(1.9) * lf.pit_r * 0.5
	var rig := Vector3(rig_xz.x, s.far_height(rig_xz.x, rig_xz.y), rig_xz.y)
	var pipe := PackedVector3Array()
	for p in lf.pipe_points(PIPE_LENGTH, PIPE_STEP):
		pipe.append(Vector3(p.x, s.far_height(p.x, p.y) + 1.4, p.y))
	return {"rocks": rocks, "rock_tints": tints, "rig": rig, "pipe": pipe}


## Op de hoofdthread: de meshes in de scène.
static func commit(s: PlanetSurface, out: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	s.add_child(root)
	_commit_rocks(root, out.get("rocks", []), out.get("rock_tints", PackedColorArray()))
	if out.has("rig"):
		_commit_rig(root, out.rig)
	if out.has("pipe"):
		_commit_pipe(root, out.pipe)


static func _commit_rocks(root: Node3D, rocks: Array, tints: PackedColorArray) -> void:
	if rocks.is_empty():
		return
	var mesh := _rock_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.95
	mesh.surface_set_material(0, mat)
	var chunks := {}
	for i in rocks.size():
		var xf: Transform3D = rocks[i]
		var key := Vector2i(int(floor(xf.origin.x / CHUNK)), int(floor(xf.origin.z / CHUNK)))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(i)
	for key: Vector2i in chunks:
		var ids: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			mm.set_instance_transform(j, rocks[ids[j]])
			mm.set_instance_color(j, tints[ids[j]] if ids[j] < tints.size() else ROCK_COLOR)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rocks_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = ROCK_HIDE_M
		root.add_child(mmi)


## Een grof gehakte rots: een onderverdeelde icosaëder met verschoven hoekpunten, vlak belicht.
static func _rock_mesh() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var jitter := {}
	var jv := func(p: Vector3) -> Vector3:
		var k := Vector3i(roundi(p.x * 1000.0), roundi(p.y * 1000.0), roundi(p.z * 1000.0))
		if not jitter.has(k):
			jitter[k] = p.normalized() * rng.randf_range(0.6, 1.25)
		return jitter[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1) # vlak belicht: elk vlak een facet
	for tri in f:
		var a: Vector3 = v[tri[0]].normalized()
		var b: Vector3 = v[tri[1]].normalized()
		var c: Vector3 = v[tri[2]].normalized()
		# Geen onderverdeling: 20 grote, scheve vlakken lezen van ver als gehakte rots (onderverdeeld
		# werd het een rond brood). Onderkant platter: een rots ligt op de grond.
		for p: Vector3 in [a, c, b]:
			var w: Vector3 = jv.call(p)
			st.add_vertex(Vector3(w.x, maxf(w.y, -0.3), w.z))
	st.generate_normals()
	return st.commit()


## Booreiland (blokmodel): vier schuine poten, schoren, een platform met een cabine, een mast en een
## rood lampje bovenop. Roestig: dit staat hier al sinds een vorige concessie.
static func _commit_rig(root: Node3D, base: Vector3) -> void:
	var rig := Node3D.new()
	rig.name = "OldRig"
	root.add_child(rig)
	rig.global_position = base
	var rust := MolVisual.machine_material("RedOxide", false, 3.0)
	var steel := MolVisual.machine_material("DarkSteel", false, 3.0)
	var h := 30.0
	var foot := 5.0
	var top := 1.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_beam(rig, Vector3(sx * foot, 0.0, sz * foot), Vector3(sx * top, h, sz * top), 0.45, rust)
	for level in [0.25, 0.5, 0.75]:
		var w: float = lerpf(foot, top, level)
		var y: float = h * level
		for c in [[Vector3(-w, y, -w), Vector3(w, y, -w)], [Vector3(w, y, -w), Vector3(w, y, w)],
				[Vector3(w, y, w), Vector3(-w, y, w)], [Vector3(-w, y, w), Vector3(-w, y, -w)]]:
			_beam(rig, c[0], c[1], 0.25, rust)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(9.0, 0.6, 9.0)
	deck.mesh = dm
	deck.material_override = steel
	deck.position = Vector3(0.0, 8.0, 0.0)
	rig.add_child(deck)
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(3.5, 3.0, 3.0)
	cabin.mesh = cm
	cabin.material_override = MolVisual.machine_material("Yellow", false, 3.0)
	cabin.position = Vector3(2.4, 9.8, 2.2)
	rig.add_child(cabin)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.5
	lm.height = 1.0
	lamp.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = RED_LIGHT
	lmat.emission_enabled = true
	lmat.emission = RED_LIGHT
	lmat.emission_energy_multiplier = 6.0
	lamp.material_override = lmat
	lamp.position = Vector3(0.0, h + 0.6, 0.0)
	rig.add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = RED_LIGHT
	light.light_energy = 2.0
	light.omni_range = 25.0
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.position = lamp.position
	rig.add_child(light)


## Pijpleiding (blokmodel): stukken buis tussen de punten, met een steun onder elk punt.
static func _commit_pipe(root: Node3D, pts: PackedVector3Array) -> void:
	if pts.size() < 2:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = 0.55
	tube.bottom_radius = 0.55
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	var post := BoxMesh.new()
	post.size = Vector3(0.35, 1.0, 0.35)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tube
	mm.instance_count = pts.size() - 1
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.mesh = post
	pm.instance_count = pts.size()
	for i in pts.size():
		pm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1.0, 2.2, 1.0)), pts[i] - Vector3(0.0, 1.1, 0.0)))
		if i == pts.size() - 1:
			break
		var a := pts[i]
		var b := pts[i + 1]
		var dir := b - a
		var y := dir.normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		mm.set_instance_transform(i, Transform3D(Basis(x, y * dir.length(), z), (a + b) * 0.5))
	var steel := MolVisual.machine_material("DarkSteel", false, 3.0)
	for pair in [[mm, "Pipeline"], [pm, "PipelinePosts"]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pair[1]
		mmi.multimesh = pair[0]
		mmi.material_override = steel
		mmi.visibility_range_end = ROCK_HIDE_M + 500.0
		root.add_child(mmi)


static func _beam(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, a.distance_to(b), thick)
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
