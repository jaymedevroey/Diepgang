class_name KristalMesh
extends RefCounted
## Geometrie voor Kristalmaan, uit code: kristallen (gefacetteerde prisma's met een afgeschuinde
## punt), zeshoekige korstplaten en basaltzuilen. Alles komt in gewone arrays (veilig op een
## werkthread); per stuk wereld en per materiaal wordt dat één mesh (één draw call), zoals een
## rotsveld van ver als één mesh (docs/research/planeten.md §5, HLOD).
## Vlakke normalen per driehoek: low-poly facetten. Vertexkleur: rgb = tint, a = binnengloed
## (enkel gebruikt door de kristalshader).

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
## Waar de mesh in de wereld hangt (na `center_on_self`): de hoekpunten liggen er rond.
var origin := Vector3.ZERO
# Omhullende van de geplaatste kopieën (add_instance): goedkoper dan achteraf alle hoekpunten.
var _lo := Vector3.INF
var _hi := -Vector3.INF


func is_empty() -> bool:
	return verts.is_empty()


func triangle_count() -> int:
	return verts.size() / 3


## Arrays voor ArrayMesh.add_surface_from_arrays (op de hoofdthread).
func arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = normals
	a[Mesh.ARRAY_COLOR] = colors
	return a


## De hoekpunten rond het midden van hun omhullende leggen (nauwkeuriger dan wereldcoördinaten van
## kilometers ver) en dat midden onthouden in `origin`. Op de werkthread: de lus over alle
## hoekpunten kost op de hoofdthread anders een hapering.
## Met kopieën: het midden van hun plaatsen (de enkele los gebouwde vormen liggen ertussen).
func center_on_self() -> void:
	if verts.is_empty():
		return
	if _lo.x <= _hi.x:
		origin = (_lo + _hi) * 0.5
	else:
		var lo := verts[0]
		var hi := verts[0]
		for v in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		origin = (lo + hi) * 0.5
	verts = Transform3D(Basis(), -origin) * verts


## Een kopie van `src` (gebouwd rond de oorsprong) met transformatie `xf` erbij, in native code
## (Transform3D * PackedVector3Array): duizenden kristallen kosten zo bijna niets op de werkthread.
## Enkel draaien, uniform schalen, of schalen langs de eigen assen van een rechtopstaand prisma
## (dan blijven de vlakke normalen juist; Godot normaliseert ze bij het opslaan).
func add_instance(src: KristalMesh, xf: Transform3D) -> void:
	verts.append_array(xf * src.verts)
	normals.append_array(Transform3D(xf.basis, Vector3.ZERO) * src.normals)
	colors.append_array(src.colors)
	_lo = _lo.min(xf.origin)
	_hi = _hi.max(xf.origin)


## Driehoek a-b-c, tegen de klok in gezien van buiten (wiskundig). Godot tekent met de klok mee als
## voorkant, dus de volgorde wordt omgedraaid; de normaal wijst naar buiten.
func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n := (b - a).cross(c - a)
	var l := n.length()
	if l < 1e-9:
		return
	n /= l
	verts.append(a)
	verts.append(c)
	verts.append(b)
	for k in 3:
		normals.append(n)
	colors.append(ca)
	colors.append(cc)
	colors.append(cb)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	tri(a, b, c, ca, cb, cc)
	tri(a, c, d, ca, cc, cd)


# --- Kristallen --------------------------------------------------------------------------------

## Eén kristal: een prisma met `sides` zijden langs `axis`, van `base` (iets onder de grond) tot
## een afgeschuinde rand en een (scheve) punt. Licht onregelmatig, zodat geen twee gelijk zijn.
## `col` = tint (rgb), de gloed loopt van `glow` onderaan naar ±20 % in de punt.
func crystal(base: Vector3, axis: Vector3, length: float, radius: float, rng: RandomNumberGenerator,
		col: Color, glow := 1.0, sides := 6) -> void:
	var y := axis.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := y.cross(x) # de ring loopt tegen de klok in gezien vanaf de punt (normalen naar buiten)
	var twist := rng.randf() * TAU
	var taper := rng.randf_range(0.78, 0.95)
	var body := length * rng.randf_range(0.68, 0.8)
	var bevel := radius * rng.randf_range(0.25, 0.45)
	var tip_h := maxf(length - body - bevel, radius * 0.6)
	# Scheve punt: de top ligt niet altijd op de as (zoals echte kristallen afbreken of groeien).
	var tip_off := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * radius
	var r_jit := PackedFloat32Array()
	for i in sides:
		r_jit.append(rng.randf_range(0.85, 1.12))
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var ring2: Array[Vector3] = []
	for i in sides:
		var a := twist + TAU * i / sides
		var dir := x * cos(a) + z * sin(a)
		ring0.append(base - y * radius * 0.6 + dir * radius * r_jit[i])
		ring1.append(base + y * body + dir * radius * taper * r_jit[i])
		ring2.append(base + y * (body + bevel) + dir * radius * taper * 0.62 * r_jit[i])
	var apex := base + y * (body + bevel + tip_h) + x * tip_off.x + z * tip_off.y
	var c0 := Color(col.r, col.g, col.b, glow)
	var c1 := Color(col.r * 1.04, col.g * 1.04, col.b * 1.02, glow * 0.6)
	var c2 := Color(col.r * 1.08, col.g * 1.06, col.b * 1.03, glow * 0.35)
	var c3 := Color(col.r * 1.12, col.g * 1.1, col.b * 1.05, glow * 0.15)
	for i in sides:
		var j := (i + 1) % sides
		# Elk vlak een eigen waarde (zoals geslepen): van ver blijft het een kristal, geen ijsklont.
		var f := rng.randf_range(0.72, 1.08)
		var d0 := Color(c0.r * f, c0.g * f, c0.b * f, c0.a)
		var d1 := Color(c1.r * f, c1.g * f, c1.b * f, c1.a)
		var d2 := Color(c2.r * f, c2.g * f, c2.b * f, c2.a)
		var d3 := Color(c3.r * f, c3.g * f, c3.b * f, c3.a)
		quad(ring0[i], ring0[j], ring1[j], ring1[i], d0, d0, d1, d1)
		quad(ring1[i], ring1[j], ring2[j], ring2[i], d1, d1, d2, d2)
		tri(ring2[i], ring2[j], apex, d2, d2, d3)


## Een groep kristallen uit één punt: een hoofdkristal (licht schuin) en `n` kleinere die naar
## buiten wijzen, zoals een druse. `size` = lengte van het hoofdkristal (m).
func cluster(base: Vector3, up: Vector3, size: float, rng: RandomNumberGenerator, col: Color, n := 4,
		glow := 1.0) -> void:
	var y := up.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var lean := rng.randf_range(0.0, 0.25)
	var la := rng.randf() * TAU
	var main_axis := (y + (x * cos(la) + z * sin(la)) * lean).normalized()
	var r_main := size * rng.randf_range(0.11, 0.16)
	crystal(base, main_axis, size, r_main, rng, col, glow, 6 if rng.randf() < 0.7 else 5)
	for k in n:
		var a := rng.randf() * TAU
		var out := x * cos(a) + z * sin(a)
		var tilt := rng.randf_range(0.35, 1.05)
		var axis := (y + out * tilt).normalized()
		var s := size * rng.randf_range(0.3, 0.72)
		var r := s * rng.randf_range(0.12, 0.18)
		var shade := rng.randf_range(0.9, 1.06)
		var c := Color(col.r * shade, col.g * shade, col.b * shade)
		crystal(base + out * r_main * rng.randf_range(0.6, 1.4), axis, s, r, rng, c, glow,
				6 if rng.randf() < 0.6 else 5)


# --- Korst en basalt ---------------------------------------------------------------------------

## Een zeshoekige korstplaat: zes hoekpunten op hun eigen hoogte (`corner_y`) en het midden op
## `center.y`, `thick` boven de grond, met een rand die tot `skirt` onder de grond zakt.
## `bevel` (0..1): zoveel van de straal is een afschuining van de bovenrand (kleur `bevel_col`), die
## van thick tot 45 % van thick zakt: de plaat leest als een opgeheven, afgesleten schol.
func hex_plate(center: Vector3, radius: float, rot: float, corner_y: PackedFloat32Array, thick: float,
		skirt: float, col: Color, edge_col: Color, bevel := 0.0, bevel_col := Color()) -> void:
	var top: Array[Vector3] = []
	var rim: Array[Vector3] = []
	var low: Array[Vector3] = []
	for i in 6:
		var a := rot + TAU * i / 6.0
		var r_top := radius * (1.0 - bevel)
		var y_rim := corner_y[i] + (thick * 0.45 if bevel > 0.0 else thick)
		top.append(Vector3(center.x + cos(a) * r_top, corner_y[i] + thick, center.z + sin(a) * r_top))
		var p := Vector3(center.x + cos(a) * radius, y_rim, center.z + sin(a) * radius)
		rim.append(p)
		low.append(Vector3(p.x, corner_y[i] - skirt, p.z))
	var mid := Vector3(center.x, center.y + thick, center.z)
	for i in 6:
		var j := (i + 1) % 6
		# Bovenvlak: een waaier vanuit het midden (volgt de grond).
		tri(mid, top[j], top[i], col, col, col)
		if bevel > 0.0:
			quad(top[i], top[j], rim[j], rim[i], bevel_col, bevel_col, bevel_col, bevel_col)
		# De rand: een zichtbare dikte, iets donkerder.
		quad(rim[i], rim[j], low[j], low[i], edge_col, edge_col, edge_col, edge_col)


## Een basaltzuil: zeshoekig prisma van `bottom` (onder de grond) tot `top_y`, met een vlakke top.
func column(center: Vector3, radius: float, rot: float, bottom: float, top_y: float, col: Color,
		top_col: Color) -> void:
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in 6:
		var a := rot + TAU * i / 6.0
		var d := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		lo.append(Vector3(center.x + d.x, bottom, center.z + d.z))
		hi.append(Vector3(center.x + d.x, top_y, center.z + d.z))
	var mid := Vector3(center.x, top_y, center.z)
	for i in 6:
		var j := (i + 1) % 6
		var shade := 0.88 + 0.12 * float((i * 5) % 3) / 2.0
		var c := Color(col.r * shade, col.g * shade, col.b * shade)
		quad(lo[j], lo[i], hi[i], hi[j], c, c, c, c)
		tri(mid, hi[j], hi[i], top_col, top_col, top_col)


# --- Machines (booreiland) ---------------------------------------------------------------------

## Een balk van a naar b met een vierkante doorsnede `thick` (zonder kopse vlakken).
func beam(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized() * thick * 0.5
	var z := x.cross(y).normalized() * thick * 0.5
	var c: Array[Vector3] = [x + z, -x + z, -x - z, x - z]
	for i in 4:
		var j := (i + 1) % 4
		quad(a + c[j], a + c[i], b + c[i], b + c[j], col, col, col, col)


## Een doos (assen `basis`, halve maten `half`) rond `pos`.
func box(pos: Vector3, basis: Basis, half: Vector3, col: Color) -> void:
	var p: Array[Vector3] = []
	for k in 8:
		var s := Vector3(1.0 if k & 1 else -1.0, 1.0 if k & 2 else -1.0, 1.0 if k & 4 else -1.0)
		p.append(pos + basis * (s * half))
	# Zijden: -x, +x, -y, +y, -z, +z (tegen de klok in gezien van buiten).
	quad(p[0], p[4], p[6], p[2], col, col, col, col)
	quad(p[1], p[3], p[7], p[5], col, col, col, col)
	quad(p[0], p[1], p[5], p[4], col, col, col, col)
	quad(p[2], p[6], p[7], p[3], col, col, col, col)
	quad(p[0], p[2], p[3], p[1], col, col, col, col)
	quad(p[4], p[5], p[7], p[6], col, col, col, col)
