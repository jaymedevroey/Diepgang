class_name FossielBones
extends RefCounted
## Versteende botten uit code (Fossielwereld, docs/research/planeten.md §4.2): buizen langs een
## kromme met een gefacetteerde, licht scheve doorsnede (elke ring een halve stap gedraaid, zoals
## gehakt), afgeplat waar een bot plat is (ribben, doornen, kammen). Vlak belicht, zodat het van ver
## leest als een geschilderd low-poly bot en niet als een cilinder.
## Enkel arrays (hoekpunten, normalen, kleuren): veilig op een werkthread; de mesh komt op de
## hoofdthread (`mesh()`).
## Vertexkleur (voor fossiel_bone.gdshader): r = glans per vlak (0 = donker bot, 1 = glanzend),
## a = stof van de grond (1 = vlak bij de grond, bot dat uit het sediment komt).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var rng := RandomNumberGenerator.new()


func _init(bone_seed: int) -> void:
	rng.seed = bone_seed


## Driehoek met de voorkant naar `out` (Godot: met de klok mee gezien van voren, dus
## cross(b - a, c - a) wijst van de kijker weg). Vlakke normaal, één kleur per vlak.
func tri(a: Vector3, b: Vector3, c: Vector3, out: Vector3, gloss: float, dust: float) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var nn := -n.normalized()
	verts.append(a)
	verts.append(b)
	verts.append(c)
	normals.append(nn)
	normals.append(nn)
	normals.append(nn)
	var col := Color(clampf(gloss + rng.randf_range(-0.12, 0.12), 0.0, 1.0), 0.0, 0.0, clampf(dust, 0.0, 1.0))
	colors.append(col)
	colors.append(col)
	colors.append(col)


## Buis langs `pts`. `radii` per punt; `flat` < 1 maakt de doorsnede smal in de richting dwars op
## `up_ref` (een blad: ribben, doornen). `ground` (optioneel, per punt) = hoogte van de grond daar:
## dicht bij de grond komt er stof op (a). `jit` = hoe scheef de facetten zijn (deel van de straal).
func tube(pts: PackedVector3Array, radii: PackedFloat32Array, up_ref: Vector3, sides := 6, flat := 1.0,
		jit := 0.12, gloss := 0.35, ground := PackedFloat32Array(), cap_start := true, cap_end := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	var rings: Array[PackedVector3Array] = []
	var dusts := PackedFloat32Array()
	var up := up_ref.normalized()
	for i in n:
		var t: Vector3
		if i == 0:
			t = pts[1] - pts[0]
		elif i == n - 1:
			t = pts[n - 1] - pts[n - 2]
		else:
			t = pts[i + 1] - pts[i - 1]
		t = t.normalized()
		var side := t.cross(up)
		if side.length_squared() < 1e-6:
			side = t.cross(Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD)
		side = side.normalized()
		up = side.cross(t).normalized()
		var ring := PackedVector3Array()
		var r := radii[i]
		var twist := 0.5 * float(i % 2)
		for k in sides:
			var a := TAU * (float(k) + twist) / float(sides)
			var j := 1.0 + rng.randf_range(-jit, jit)
			ring.append(pts[i] + (side * (cos(a) * r * flat) + up * (sin(a) * r)) * j)
		rings.append(ring)
		var d := 0.0
		if ground.size() == n:
			d = 1.0 - smoothstep(-0.5, 1.4, pts[i].y - r - ground[i])
		dusts.append(d)
	for i in n - 1:
		var c := (pts[i] + pts[i + 1]) * 0.5
		var g := gloss + rng.randf_range(-0.1, 0.1)
		for k in sides:
			var a0 := rings[i][k]
			var a1 := rings[i][(k + 1) % sides]
			var b0 := rings[i + 1][k]
			var b1 := rings[i + 1][(k + 1) % sides]
			var mid := (a0 + a1 + b0 + b1) * 0.25
			tri(a0, a1, b1, mid - c, g, dusts[i])
			tri(a0, b1, b0, mid - c, g, dusts[i + 1])
	if cap_start and radii[0] > 0.02:
		_cap(rings[0], pts[0], (pts[0] - pts[1]).normalized() * radii[0] * 0.45, gloss, dusts[0])
	if cap_end and radii[n - 1] > 0.02:
		_cap(rings[n - 1], pts[n - 1], (pts[n - 1] - pts[n - 2]).normalized() * radii[n - 1] * rng.randf_range(0.2, 0.7), gloss, dusts[n - 1])


## Een kap als lage piramide (een afgebroken bot krijgt een scheve, gekartelde punt).
func _cap(ring: PackedVector3Array, center: Vector3, bulge: Vector3, gloss: float, dust: float) -> void:
	var tip := center + bulge
	var out := bulge.normalized()
	for k in ring.size():
		tri(tip, ring[k], ring[(k + 1) % ring.size()], out, gloss, dust)


## Kwadratische/kubieke Bézier als reeks punten (voor ribben en tanden).
static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, steps: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		out.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	return out


## Straal die lineair verloopt van a naar b over n punten (met een lichte golving).
func taper(n: int, a: float, b: float, wobble := 0.08) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		out.append(lerpf(a, b, t) * (1.0 + rng.randf_range(-wobble, wobble)))
	return out


## Wervel: een getailleerd lichaam langs de rug (`t`), een doorn omhoog en naar achteren, en twee
## korte uitsteeksels opzij. `r` = straal van het lichaam, `spike` = lengte van de doorn.
func vertebra(c: Vector3, t: Vector3, up: Vector3, r: float, spike: float, ground_y: float, gloss := 0.35) -> void:
	t = t.normalized()
	var side := t.cross(up).normalized()
	up = side.cross(t).normalized()
	var L := r * 1.5
	var body := PackedVector3Array([c - t * L * 0.5, c - t * L * 0.2, c + t * L * 0.2, c + t * L * 0.5])
	var g := PackedFloat32Array([ground_y, ground_y, ground_y, ground_y])
	tube(body, PackedFloat32Array([r * 1.05, r * 0.78, r * 0.78, r * 1.05]), up, 7, 1.0, 0.1, gloss, g)
	if spike > 0.3:
		var base := c + up * r * 0.6
		var tip := base + up * spike - t * spike * rng.randf_range(0.25, 0.45) + side * rng.randf_range(-0.1, 0.1) * spike
		var mid := base.lerp(tip, 0.5) + up * spike * 0.06
		tube(PackedVector3Array([base, mid, tip]), PackedFloat32Array([r * 0.62, r * 0.42, r * 0.1]), t, 5, 0.45, 0.12, gloss + 0.1,
				PackedFloat32Array([ground_y, ground_y, ground_y]))
	for sgn: float in [-1.0, 1.0]:
		var a := c + side * sgn * r * 0.5
		var b := a + side * sgn * r * rng.randf_range(1.2, 1.7) + up * r * 0.3 - t * r * 0.2
		tube(PackedVector3Array([a, b]), PackedFloat32Array([r * 0.42, r * 0.14]), t, 5, 0.6, 0.12, gloss,
				PackedFloat32Array([ground_y, ground_y]), false, true)


## Kegel (tand, hoorn, splinter) van `a` naar `b`.
func cone(a: Vector3, b: Vector3, r: float, up: Vector3, ground_y: float, gloss := 0.45) -> void:
	var mid := a.lerp(b, 0.55)
	tube(PackedVector3Array([a, mid, b]), PackedFloat32Array([r, r * 0.55, r * 0.06]), up, 5, 0.85, 0.1, gloss,
			PackedFloat32Array([ground_y, ground_y, ground_y]), true, false)


## Vorm met doorsneden (`secs`: Vector4(x, y, halve hoogte, halve breedte) in de lokale ruimte
## van `xf`, x = lengte, y = op, z = opzij). Voor de schedel: hersenpan en snuit.
func loft(xf: Transform3D, secs: Array[Vector4], sides: int, ground_y: float, gloss := 0.35) -> void:
	var pts := PackedVector3Array()
	var rings: Array[PackedVector3Array] = []
	for s in secs:
		var ring := PackedVector3Array()
		var twist := 0.5 * float(rings.size() % 2)
		for k in sides:
			var a := TAU * (float(k) + twist) / float(sides)
			var j := 1.0 + rng.randf_range(-0.09, 0.09)
			# Onderkant vlakker (een schedel ligt niet op een bol).
			var sy := sin(a)
			if sy < 0.0:
				sy *= 0.7
			ring.append(xf * Vector3(s.x, s.y + sy * s.z * j, cos(a) * s.w * j))
		rings.append(ring)
		pts.append(xf * Vector3(s.x, s.y, 0.0))
	for i in rings.size() - 1:
		var c := (pts[i] + pts[i + 1]) * 0.5
		for k in sides:
			var a0 := rings[i][k]
			var a1 := rings[i][(k + 1) % sides]
			var b0 := rings[i + 1][k]
			var b1 := rings[i + 1][(k + 1) % sides]
			var mid := (a0 + a1 + b0 + b1) * 0.25
			var dust := 1.0 - smoothstep(-0.5, 1.4, mid.y - ground_y)
			var g := gloss + rng.randf_range(-0.12, 0.12)
			tri(a0, a1, b1, mid - c, g, dust)
			tri(a0, b1, b0, mid - c, g, dust)
	var last := rings.size() - 1
	var d_end := (pts[last] - pts[last - 1]).normalized()
	var d_start := (pts[0] - pts[1]).normalized()
	_cap(rings[0], pts[0], d_start * secs[0].z * 0.35, gloss, 0.0)
	_cap(rings[last], pts[last], d_end * secs[last].z * 0.3, gloss, 0.0)


## Doos (kisten, borden, zeilen): `xf` = plek en richting, `size` = maten.
func box(xf: Transform3D, size: Vector3, gloss := 0.3) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for f: Array in [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]:
		var a := corners[f[0]]
		var b := corners[f[1]]
		var c := corners[f[2]]
		var d := corners[f[3]]
		var out := (a + b + c + d) * 0.25 - xf.origin
		tri(a, b, c, out, gloss, 0.0)
		tri(a, c, d, out, gloss, 0.0)


## Arrays voor een ArrayMesh (op de hoofdthread: `mesh()`).
func arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = normals
	a[Mesh.ARRAY_COLOR] = colors
	return a


func triangle_count() -> int:
	return verts.size() / 3


static func mesh(a: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	if (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 0:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m
