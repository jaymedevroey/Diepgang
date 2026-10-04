class_name SurfaceDressing
extends RefCounted
## Wat er op het verre landschap staat (docs/research/planeten.md §3–4): losse rotsblokken (waar
## en hoe groot zegt de Landform van de planeet), en de eigen dingen van de planeet
## (Landform.compute_props / commit_props: een booreiland, botten, kristallen ...). Van boven geven
## ze schaal en schaduw. Posities op de werkthread (`compute`, enkel uit de seed), meshes op de
## hoofdthread (`commit`). Binnen het speelgebied niets: daar staat het voxelterrein van de generator.
## Ook gedeelde bouwstenen voor de Landforms (beam, box, red_light, rock_mesh).

const ROCK_CELL := 24.0
const ROCK_REACH := 1150.0 # m van de landingsplek
const ROCK_HIDE_M := 1300.0
const CHUNK := 512.0 # m: rotsen per vak in een eigen MultiMesh (die valt als geheel weg)


## Op de werkthread: waar alles staat.
static func compute(s: PlanetSurface) -> Dictionary:
	var lf := s.landform
	var rocks: Array[Transform3D] = []
	var tints := PackedColorArray()
	var rock_color: Color = PlanetType.ground(s.planet).rock
	var c0x := int(floor((lf.landing.x - ROCK_REACH) / ROCK_CELL))
	var c1x := int(floor((lf.landing.x + ROCK_REACH) / ROCK_CELL))
	var c0z := int(floor((lf.landing.y - ROCK_REACH) / ROCK_CELL))
	var c1z := int(floor((lf.landing.y + ROCK_REACH) / ROCK_CELL))
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var cell_c := Vector2((cx + 0.5) * ROCK_CELL, (cz + 0.5) * ROCK_CELL)
			if cell_c.distance_to(lf.landing) > ROCK_REACH:
				continue
			var rng := s._cell_rng(cx, cz, 7)
			var density := lf.rock_density(cell_c)
			var count := int(density) + (1 if rng.randf() < fmod(density, 1.0) else 0)
			for k in count:
				var x := (cx + rng.randf()) * ROCK_CELL
				var z := (cz + rng.randf()) * ROCK_CELL
				var size := lerpf(0.7, 3.6, pow(rng.randf(), 2.4)) * lf.rock_scale(Vector2(x, z))
				var rot := Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
				var sc := Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.45, 0.85), size * rng.randf_range(0.8, 1.3))
				if s.outside(x, z) < 6.0 + size:
					continue
				var y: float = s.far_height(x, z) - sc.y * 0.3
				rocks.append(Transform3D(Basis.from_euler(rot).scaled(sc), Vector3(x, y, z)))
				var t := lf.tint(x, z)
				var v := rng.randf_range(0.82, 1.12)
				tints.append(Color(rock_color.r * v * lerpf(1.0, t.r, 0.35), rock_color.g * v * lerpf(1.0, t.g, 0.35), rock_color.b * v * lerpf(1.0, t.b, 0.35)))
	var out := {"rocks": rocks, "rock_tints": tints}
	out.merge(lf.compute_props(s))
	return out


## Op de hoofdthread: de meshes in de scène.
static func commit(s: PlanetSurface, out: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	s.add_child(root)
	_commit_rocks(root, out.get("rocks", []), out.get("rock_tints", PackedColorArray()), PlanetType.ground(s.planet).rock)
	s.landform.commit_props(root, out)


static func _commit_rocks(root: Node3D, rocks: Array, tints: PackedColorArray, fallback: Color) -> void:
	if rocks.is_empty():
		return
	var mesh := rock_mesh(4242)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true # de kleuren per rots zijn sRGB (anders roze-wit)
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
			mm.set_instance_color(j, tints[ids[j]] if ids[j] < tints.size() else fallback)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rocks_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.visibility_range_end = ROCK_HIDE_M
		root.add_child(mmi)


# --- Gedeelde bouwstenen voor de Landforms ------------------------------------------------------

## Een grof gehakte rots: een icosaëder met verschoven hoekpunten (20 grote, scheve vlakken lezen
## van ver als gehakte rots), vlak belicht, onderkant platter (een rots ligt op de grond).
static func rock_mesh(rock_seed: int, low := 0.6, high := 1.25) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	var jit: Array[Vector3] = []
	for p in v:
		jit.append(p.normalized() * rng.randf_range(low, high))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for tri in f:
		for i: int in [tri[0], tri[2], tri[1]]:
			var w := jit[i]
			st.add_vertex(Vector3(w.x, maxf(w.y, -0.3), w.z))
	st.generate_normals()
	return st.commit()


## Een balk van a naar b (vierkant, `thick` dik).
static func beam(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, a.distance_to(b), thick)
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	return mi


## Een doos van `size`, met het midden op `pos` (lokaal t.o.v. parent).
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Een gloeiend lampje met een klein licht (zonder schaduw), van ver een herkenningspunt.
static func red_light(parent: Node3D, pos: Vector3, color: Color, energy := 2.0, reach := 25.0) -> void:
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.5
	lm.height = 1.0
	lamp.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = color
	lmat.emission_enabled = true
	lmat.emission = color
	lmat.emission_energy_multiplier = 6.0
	lamp.material_override = lmat
	lamp.position = pos
	parent.add_child(lamp)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	light.position = pos
	parent.add_child(light)
