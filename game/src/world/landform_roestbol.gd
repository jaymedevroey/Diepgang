class_name LandformRoestbol
extends Landform
## Roestbol (docs/research/planeten.md §4.1): een oude reuzenkrater (de wand schuin vóór de
## landingsplek, met lagen en geulen), een verlaten DIG-mijnput met terrassen op de kraterbodem,
## een roestig booreiland en een pijpleiding, en donkere duinsikkels die met de wind meekruipen.

const DUNE_CELL := 128.0
const PIPE_LENGTH := 1700.0
const PIPE_STEP := 12.0
const RED_LIGHT := Color(1.0, 0.16, 0.08)

# Krater: midden, straal, breedte van de wand, hoogte van de rand, hoogte van het plateau erbuiten.
var crater_c := Vector2.ZERO
var crater_r := 1400.0
var wall_w := 95.0
var rim_h := 95.0
var plateau_h := 70.0
# Mijnput: midden, straal, diepte, aantal terrassen.
var pit_c := Vector2.ZERO
var pit_r := 120.0
var pit_depth := 40.0
var pit_steps := 5
# Duinen: x, z, straal, hoogte; de wind blaast langs `wind` (de open kant van de sikkel wijst mee).
var dunes: Array[Vector4] = []
var _dune_grid := {} # Vector2i -> Array[int]
# De kraterrand is geen cirkel: hij golft (±55 m) en geulen snijden in de wand.
var _wall_noise := FastNoiseLite.new()
# Richting van de pijpleiding (van de put weg, de kraterbodem over).
var pipe_dir := Vector2.UP


func setup(planet_seed: int, landing_xz: Vector2, size: Vector2) -> void:
	super(planet_seed, landing_xz, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 2654435761 + 17
	# De wand ligt schuin vóór de landingsplek (−z is waar de dropcamera naar kijkt bij het remmen):
	# links- of rechtsvoor, zodat hij het beeld kadert en de horizon vrij blijft.
	var a_rim := deg_to_rad(-90.0 + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(38.0, 55.0))
	var rim_dir := Vector2(cos(a_rim), sin(a_rim))
	var rim_dist := rng.randf_range(380.0, 440.0)
	crater_r = rng.randf_range(1300.0, 1600.0)
	crater_c = landing - rim_dir * (crater_r - rim_dist)
	_wall_noise.seed = planet_seed + 311
	_wall_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wall_noise.frequency = 0.006
	_wall_noise.fractal_octaves = 3
	rim_h = rng.randf_range(115.0, 145.0)
	plateau_h = rim_h * rng.randf_range(0.65, 0.8)
	# De put: opzij (links of rechts), zodat hij van boven en bij het remmen in beeld komt.
	var a_pit := a_rim + deg_to_rad((90.0 if rng.randf() < 0.5 else -90.0) + rng.randf_range(-20.0, 20.0))
	var pit_dir := Vector2(cos(a_pit), sin(a_pit))
	pit_r = rng.randf_range(105.0, 130.0)
	pit_c = landing + pit_dir * (play_size.x * 0.5 + 70.0 + pit_r)
	pipe_dir = pit_dir.rotated(deg_to_rad(rng.randf_range(-35.0, 35.0)))
	# Wind schuin langs de wand: de duinen kruipen over de kraterbodem.
	wind = rim_dir.rotated(deg_to_rad(90.0 + rng.randf_range(-30.0, 30.0)))
	dunes.clear()
	var tries := 0
	while dunes.size() < 46 and tries < 600:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := lerpf(190.0, 950.0, sqrt(rng.randf()))
		var p := landing + Vector2(cos(ang), sin(ang)) * dist
		var r := rng.randf_range(22.0, 58.0)
		# Niet in het speelgebied (plus de overgang), niet in de put, niet tegen of op de wand.
		var half := play_size * 0.5 + Vector2(FADE_IN.y + r, FADE_IN.y + r)
		if absf(p.x - landing.x) < half.x and absf(p.y - landing.y) < half.y:
			continue
		if p.distance_to(pit_c) < pit_r * 1.5 + r:
			continue
		if p.distance_to(crater_c) > crater_r - wall_w - r * 1.4:
			continue
		var ok := true
		for d in dunes:
			if p.distance_to(Vector2(d.x, d.y)) < (d.z + r) * 0.9:
				ok = false
				break
		if not ok:
			continue
		dunes.append(Vector4(p.x, p.y, r, r * rng.randf_range(0.09, 0.14)))
	_dune_grid.clear()
	for i in dunes.size():
		var d := dunes[i]
		var reach := d.z * 1.6
		for gz in range(int(floor((d.y - reach) / DUNE_CELL)), int(floor((d.y + reach) / DUNE_CELL)) + 1):
			for gx in range(int(floor((d.x - reach) / DUNE_CELL)), int(floor((d.x + reach) / DUNE_CELL)) + 1):
				var key := Vector2i(gx, gz)
				if not _dune_grid.has(key):
					_dune_grid[key] = []
				_dune_grid[key].append(i)


## Hoogte (m) boven of onder de basis van het verre landschap; `o` = afstand buiten het speelgebied.
func height(x: float, z: float, o: float) -> float:
	var k := Landform.fade_in(o)
	if k <= 0.0:
		return 0.0
	var p := Vector2(x, z)
	return k * (_crater(p) + _pit(p) + _dunes(p))


## 0 op de kraterbodem, 1 op en voorbij de wand: daar mogen de gewone heuvels volop (op de bodem
## blijft het rustig, zodat de duinen en de put leesbaar zijn).
func hills_factor(x: float, z: float) -> float:
	var d := crater_d(Vector2(x, z))
	return lerpf(0.25, 1.0, smoothstep(crater_r - wall_w - 150.0, crater_r, d))


## Kleur van het landschap hier: rgb vermenigvuldigt de rotskleur, a = hoeveel lagen (strata) er
## in de wand te zien zijn (de shader tekent ze op hoogte).
func tint(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var c := Color(1.18, 1.08, 0.95, 0.0) # perzikkleurig stof op de kraterbodem
	var d := crater_d(p)
	var t := clampf((d - (crater_r - wall_w)) / wall_w, 0.0, 1.0)
	var wall := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.92, 1.0, t))
	c.a = wall
	# Bovenop de rand en het plateau: lichter, stoffiger.
	var top := smoothstep(crater_r - 10.0, crater_r + 60.0, d)
	c = Color(c.r * lerpf(1.0, 1.12, top), c.g * lerpf(1.0, 1.1, top), c.b * lerpf(1.0, 1.05, top), c.a)
	# Donker basaltzand in de duinen.
	var dune := _dune_mask(p)
	c = Color(lerpf(c.r, 0.42, dune), lerpf(c.g, 0.34, dune), lerpf(c.b, 0.34, dune), c.a)
	# De put: grijziger, het gesteente dat eruit kwam ligt als lichte hopen op de rand.
	var dp := p.distance_to(pit_c) / pit_r
	if dp < 1.5:
		var inside := 1.0 - smoothstep(0.92, 1.0, dp)
		var spoil := smoothstep(1.0, 1.12, dp) * (1.0 - smoothstep(1.28, 1.5, dp))
		c = Color(lerpf(c.r, 0.86, inside), lerpf(c.g, 0.8, inside), lerpf(c.b, 0.78, inside), maxf(c.a, inside * 0.3))
		c = Color(lerpf(c.r, 1.3, spoil), lerpf(c.g, 1.2, spoil), lerpf(c.b, 1.08, spoil), c.a)
	return c


## Punten van de pijpleiding (wereld x/z), van de rand van de put tot `length` m verder.
func pipe_points(length: float, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var start := pit_c + pipe_dir * (pit_r * 1.45)
	var n := int(length / step)
	var side := pipe_dir.orthogonal()
	for i in n + 1:
		var s := i * step
		# Een lichte bocht, zodat het geen liniaal is.
		out.append(start + pipe_dir * s + side * (sin(s * 0.0021) * 60.0))
	return out


# --- Vormen ------------------------------------------------------------------------------------

## Afstand tot het kratermidden, met een golvende rand (zodat de wand geen cirkel is).
func crater_d(p: Vector2) -> float:
	var rel := p - crater_c
	var arc := atan2(rel.y, rel.x) * crater_r
	return rel.length() + _wall_noise.get_noise_1d(arc) * 55.0


## Hoe diep een geul hier in de wand snijdt (0..1).
func _gully(p: Vector2) -> float:
	var rel := p - crater_c
	var arc := atan2(rel.y, rel.x) * crater_r
	return smoothstep(0.15, 0.6, _wall_noise.get_noise_1d(arc * 5.3 + 911.0))


## Reuzenkrater: vlakke bodem, een steile wand met terrassen (de lagen), een rand, en daarbuiten een
## plateau dat langzaam afloopt. Geulen snijden in de wand en de rand.
func _crater(p: Vector2) -> float:
	var d := crater_d(p)
	var inner := crater_r - wall_w
	if d <= inner:
		return 0.0
	var g := _gully(p)
	if d <= crater_r:
		var t := (d - inner) / wall_w
		# Vier treden: steile wanden, smalle richels (zoals gelaagd gesteente afbrokkelt).
		var s := t * 4.0
		var stepped := (floorf(s) + smoothstep(0.2, 0.75, s - floorf(s))) / 4.0
		var h := rim_h * lerpf(t, stepped, 0.8)
		return h * (1.0 - 0.45 * g * (1.0 - t * 0.3))
	var top := plateau_h + (rim_h - plateau_h) * exp(-(d - crater_r) / 140.0)
	return top * (1.0 - 0.3 * g * exp(-(d - crater_r) / 120.0))


## Open mijnput: terrassen naar beneden, een wal van afval eromheen.
func _pit(p: Vector2) -> float:
	var dn := p.distance_to(pit_c) / pit_r
	if dn >= 1.5:
		return 0.0
	if dn >= 1.0:
		var b := (dn - 1.0) / 0.5
		return 7.0 * sin(b * PI) * (1.0 - b * 0.4)
	var s := (1.0 - dn) * pit_steps
	var level := floorf(s) + smoothstep(0.7, 1.0, s - floorf(s))
	return -pit_depth * level / pit_steps


## Barchans: een heuvel met een uitgehold hart aan de kant van de wind (de sikkel wijst mee).
func _dunes(p: Vector2) -> float:
	var key := Vector2i(int(floor(p.x / DUNE_CELL)), int(floor(p.y / DUNE_CELL)))
	var ids: Variant = _dune_grid.get(key)
	if ids == null:
		return 0.0
	var h := 0.0
	for i: int in ids:
		var d := dunes[i]
		var c := Vector2(d.x, d.y)
		var body := 1.0 - (p.distance_squared_to(c) / (d.z * d.z))
		if body <= 0.0:
			continue
		var hollow := 1.0 - (p.distance_squared_to(c + wind * d.z * 0.55) / pow(d.z * 0.78, 2.0))
		h += d.w * clampf(body - maxf(hollow, 0.0) * 1.25, 0.0, 1.0)
	return h


func _dune_mask(p: Vector2) -> float:
	var key := Vector2i(int(floor(p.x / DUNE_CELL)), int(floor(p.y / DUNE_CELL)))
	var ids: Variant = _dune_grid.get(key)
	if ids == null:
		return 0.0
	var m := 0.0
	for i: int in ids:
		var d := dunes[i]
		var c := Vector2(d.x, d.y)
		var body := 1.0 - (p.distance_squared_to(c) / pow(d.z * 1.15, 2.0))
		if body <= 0.0:
			continue
		var hollow := 1.0 - (p.distance_squared_to(c + wind * d.z * 0.55) / pow(d.z * 0.75, 2.0))
		m = maxf(m, clampf((body - maxf(hollow, 0.0) * 1.3) * 3.0, 0.0, 1.0))
	return m


# --- Rotsblokken en eigen dingen ----------------------------------------------------------------

## Puin onder de wand (afgebrokkeld), weinig in de put, matig op de bodem en het plateau.
func rock_density(p: Vector2) -> float:
	var d := crater_d(p)
	var inner := crater_r - wall_w
	var talus := smoothstep(inner - 90.0, inner - 10.0, d) * (1.0 - smoothstep(inner + 25.0, inner + 60.0, d))
	if p.distance_to(pit_c) < pit_r:
		return 0.15
	if d > crater_r:
		return 0.3
	return 0.42 + 3.2 * talus


func rock_scale(p: Vector2) -> float:
	var d := crater_d(p)
	var inner := crater_r - wall_w
	var talus := smoothstep(inner - 90.0, inner - 10.0, d) * (1.0 - smoothstep(inner + 25.0, inner + 60.0, d))
	return lerpf(1.0, 2.4, talus)


func compute_props(s: PlanetSurface) -> Dictionary:
	# Het booreiland op een terras van de put (half naar de rand), de pijpleiding de bodem over.
	var rig_xz := pit_c + (landing - pit_c).normalized().rotated(1.9) * pit_r * 0.5
	var rig := Vector3(rig_xz.x, s.far_height(rig_xz.x, rig_xz.y), rig_xz.y)
	var pipe := PackedVector3Array()
	for p in pipe_points(PIPE_LENGTH, PIPE_STEP):
		pipe.append(Vector3(p.x, s.far_height(p.x, p.y) + 1.4, p.y))
	return {"rig": rig, "pipe": pipe}


func commit_props(root: Node3D, out: Dictionary) -> void:
	if out.has("rig"):
		_commit_rig(root, out.rig)
	if out.has("pipe"):
		_commit_pipe(root, out.pipe)


## Booreiland (blokmodel): vier schuine poten, schoren, een platform met een cabine, een mast en een
## rood lampje bovenop. Roestig: dit staat hier al sinds een vorige concessie.
func _commit_rig(root: Node3D, base: Vector3) -> void:
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
			SurfaceDressing.beam(rig, Vector3(sx * foot, 0.0, sz * foot), Vector3(sx * top, h, sz * top), 0.45, rust)
	for level: float in [0.25, 0.5, 0.75]:
		var w: float = lerpf(foot, top, level)
		var y: float = h * level
		for c in [[Vector3(-w, y, -w), Vector3(w, y, -w)], [Vector3(w, y, -w), Vector3(w, y, w)],
				[Vector3(w, y, w), Vector3(-w, y, w)], [Vector3(-w, y, w), Vector3(-w, y, -w)]]:
			SurfaceDressing.beam(rig, c[0], c[1], 0.25, rust)
	SurfaceDressing.box(rig, Vector3(9.0, 0.6, 9.0), Vector3(0.0, 8.0, 0.0), steel)
	SurfaceDressing.box(rig, Vector3(3.5, 3.0, 3.0), Vector3(2.4, 9.8, 2.2), MolVisual.machine_material("Yellow", false, 3.0))
	SurfaceDressing.red_light(rig, Vector3(0.0, h + 0.6, 0.0), RED_LIGHT)


## Pijpleiding (blokmodel): stukken buis tussen de punten, met een steun onder elk punt.
func _commit_pipe(root: Node3D, pts: PackedVector3Array) -> void:
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
		mmi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M + 500.0
		root.add_child(mmi)
