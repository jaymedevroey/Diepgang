class_name RoestbolProps
extends RefCounted
## De eigen dingen van Roestbol (docs/research/planeten.md §4.1 en §4.4), rond het speelgebied:
## - DIG (hooguit vijf in het beeld van 300 m): een verlaten boortoren met een rood licht aan de put,
##   een pijpleiding op schragen met flenzen en afsluiters tot voorbij de kim, rijen meetpalen met
##   vlagjes en een geverfde stip (een stippellijn van boven), een reclamebord vlak buiten het
##   speelgebied, en een afgeschreven Mol die half in het zand steekt. Teksten in het Engels.
## - Rotsen in drie vormen (blokken, platen, de klompen van SurfaceDressing) in groepjes, en grote
##   blokken die uit de wand gevallen zijn (in de kleur van de lagen).
## - Twee stofduivels aan de kop van hun spoor, met een lange schaduw (RoestbolDustDevil).
## Alles uit de seed. `compute` op de werkthread (enkel rekenen en SurfaceTools vullen), `commit` op de
## hoofdthread (meshes, materialen, nodes). Elk model is één mesh met een surface per materiaal.

const HIDE_M := 1300.0 # verder dan dit niet getekend (de hub hangt 1,7 km hoog)
const PIPE_CHUNK := 32 # stukken buis per mesh (±380 m): elk stuk valt apart weg


## Driehoeken per materiaal, met vlakke normalen en een "slijtagekleur" per hoekpunt voor de
## machine-shader (r = randslijtage, g = vuil, b = variatie). Werkt op een werkthread.
class Kit:
	var tools := {} # materiaal -> SurfaceTool
	var wear := Color(0.8, 0.45, 0.5)

	func _st(mat: String) -> SurfaceTool:
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
		return tools[mat]

	## Driehoek die naar `out` kijkt (de volgorde wordt zo nodig omgedraaid: Godot = met de klok mee).
	func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
		var cr := (b - a).cross(c - a)
		if cr.dot(out) > 0.0:
			var t := b
			b = c
			c = t
			cr = -cr
		if cr.length_squared() < 1e-10:
			return
		var st := _st(mat)
		st.set_normal(-cr.normalized())
		st.set_color(wear)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)

	func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
		tri(mat, a, b, c, out)
		tri(mat, a, c, d, out)

	## Doos `size` met transform `xf` (midden van de doos).
	func box(mat: String, xf: Transform3D, size: Vector3) -> void:
		var h := size * 0.5
		var p: Array[Vector3] = []
		for i in 8:
			p.append(xf * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
		var c := xf.origin
		for f in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
			var q: Array = f
			var mid: Vector3 = (p[q[0]] + p[q[1]] + p[q[2]] + p[q[3]]) * 0.25
			quad(mat, p[q[0]], p[q[1]], p[q[2]], p[q[3]], mid - c)

	## Balk van a naar b, `thick` dik (vierkant), `wide` breed als die anders is.
	func beam(mat: String, a: Vector3, b: Vector3, thick: float, wide := -1.0) -> void:
		var y := b - a
		var len := y.length()
		if len < 1e-3:
			return
		y /= len
		var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		box(mat, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(wide if wide > 0.0 else thick, len, thick))

	## Cilinder van a naar b, straal r, `seg` zijden, met of zonder deksels.
	func cyl(mat: String, a: Vector3, b: Vector3, r: float, seg := 8, caps := true, r2 := -1.0) -> void:
		var y := b - a
		if y.length() < 1e-3:
			return
		var ay := y.normalized()
		var x := ay.cross(Vector3.UP if absf(ay.y) < 0.95 else Vector3.RIGHT).normalized()
		var z := x.cross(ay)
		var rb := r2 if r2 > 0.0 else r
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var d0 := x * cos(a0) + z * sin(a0)
			var d1 := x * cos(a1) + z * sin(a1)
			quad(mat, a + d0 * r, a + d1 * r, b + d1 * rb, b + d0 * rb, (d0 + d1))
			if caps:
				tri(mat, a, a + d0 * r, a + d1 * r, -ay)
				tri(mat, b, b + d0 * rb, b + d1 * rb, ay)

	## Prisma: een bolle veelhoek (x/z, lokaal) van y0 tot y1, bovenaan `taper` keer zo groot.
	func prism(mat: String, xf: Transform3D, poly: PackedVector2Array, y0: float, y1: float, taper := 1.0) -> void:
		var n := poly.size()
		var cen := Vector2.ZERO
		for q in poly:
			cen += q
		cen /= n
		var bot: Array[Vector3] = []
		var top: Array[Vector3] = []
		for q in poly:
			var t := cen + (q - cen) * taper
			bot.append(xf * Vector3(q.x, y0, q.y))
			top.append(xf * Vector3(t.x, y1, t.y))
		var mid := xf * Vector3(cen.x, (y0 + y1) * 0.5, cen.y)
		for i in n:
			var j := (i + 1) % n
			quad(mat, bot[i], bot[j], top[j], top[i], (bot[i] + bot[j]) * 0.5 - mid)
		var up := xf.basis * Vector3.UP
		for i in range(1, n - 1):
			tri(mat, top[0], top[i], top[i + 1], up)
			tri(mat, bot[0], bot[i], bot[i + 1], -up)

	## Arrays per materiaal (voor ArrayMesh.add_surface_from_arrays op de hoofdthread).
	func arrays() -> Dictionary:
		var out := {}
		for mat: String in tools:
			out[mat] = (tools[mat] as SurfaceTool).commit_to_arrays()
		return out


# --- Werkthread -----------------------------------------------------------------------------------

static func compute(lf: LandformRoestbol, s: PlanetSurface) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var out := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = lf._seed * 7919 + 5
	var rig_y := s.far_height(lf.rig_xz.x, lf.rig_xz.y)
	out["rb_rig"] = [Vector3(lf.rig_xz.x, rig_y, lf.rig_xz.y), lf.rig_yaw, _rig_arrays()]
	out["rb_pipe"] = _pipe_chunks(lf, s)
	out["rb_stakes"] = _stakes(lf, s)
	var by := s.far_height(lf.board_xz.x, lf.board_xz.y)
	out["rb_board"] = [Vector3(lf.board_xz.x, by, lf.board_xz.y), lf.board_yaw, _board_arrays(), lf.board_text]
	var wy := s.far_height(lf.wreck_xz.x, lf.wreck_xz.y)
	out["rb_wreck"] = [Vector3(lf.wreck_xz.x, wy, lf.wreck_xz.y), lf.wreck_yaw, _wreck_arrays()]
	out["rb_rocks"] = _rocks(lf, s, rng)
	var devils := []
	for dv: Array in lf.devils:
		devils.append(_devil_path(lf, s, dv))
	out["rb_devils"] = devils
	out["rb_compute_us"] = Time.get_ticks_usec() - t0
	return out


## Boortoren (35–40 m): een onderbouw op poten, een taps vakwerk met kruisschoren, de kroon met een
## rood licht, een platform halverwege, een takel aan een kabel, een loopbrug naar de grond, een
## lier in een geel huisje, tanks en een buizenrek. Lokaal: +x wijst naar de put.
static func _rig_arrays() -> Dictionary:
	var k := Kit.new()
	var rust := "RedOxide"
	var dark := "DarkSteel"
	var yel := "Yellow"
	k.wear = Color(0.9, 0.7, 0.5)
	# Onderbouw: vier dikke poten, schoren, een dek.
	var sub_h := 6.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(rust, Transform3D(Basis(), Vector3(sx * 4.6, sub_h * 0.5, sz * 4.6)), Vector3(0.7, sub_h, 0.7))
	for side in 4:
		var b := Basis(Vector3.UP, side * PI * 0.5)
		k.beam(rust, b * Vector3(-4.6, 0.3, 4.6), b * Vector3(4.6, sub_h - 0.4, 4.6), 0.28)
		k.beam(rust, b * Vector3(4.6, 0.3, 4.6), b * Vector3(-4.6, sub_h - 0.4, 4.6), 0.28)
	k.box(dark, Transform3D(Basis(), Vector3(0.0, sub_h + 0.25, 0.0)), Vector3(12.0, 0.5, 12.0))
	# Het vakwerk: vier poten van 3,6 m naar 1,0 m half breed, ringen en kruisschoren per vak.
	var y0 := sub_h + 0.5
	var y1 := 39.5
	var panels := 8
	var hw := func(y: float) -> float: return lerpf(3.6, 1.0, (y - y0) / (y1 - y0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.beam(rust, Vector3(sx * 3.6, y0, sz * 3.6), Vector3(sx * 1.0, y1, sz * 1.0), 0.5)
	for p in panels:
		var ya := lerpf(y0, y1, float(p) / panels)
		var yb := lerpf(y0, y1, float(p + 1) / panels)
		var wa: float = hw.call(ya)
		var wb: float = hw.call(yb)
		for side in 4:
			var b := Basis(Vector3.UP, side * PI * 0.5)
			k.beam(rust, b * Vector3(-wb, yb, wb), b * Vector3(wb, yb, wb), 0.24)
			# Eén zijde open (de "V-deur", waar de buizen binnenkomen), onderaan.
			if side == 2 and p < 2:
				continue
			k.beam(rust, b * Vector3(-wa, ya, wa), b * Vector3(wb, yb, wb), 0.16)
			k.beam(rust, b * Vector3(wa, ya, wa), b * Vector3(-wb, yb, wb), 0.16)
	# Kroon, katrol, mastje met het licht (dat hangt de hoofdthread eraan).
	k.box(dark, Transform3D(Basis(), Vector3(0.0, y1 + 0.6, 0.0)), Vector3(2.8, 1.2, 2.8))
	k.cyl(dark, Vector3(-0.9, y1 + 1.6, 0.0), Vector3(0.9, y1 + 1.6, 0.0), 0.9, 10)
	k.beam(rust, Vector3(0.0, y1 + 1.2, 0.0), Vector3(0.0, y1 + 3.6, 0.0), 0.2)
	# Platform halverwege (de "apenplank") met een leuning, aan de kant weg van de put.
	var ym := lerpf(y0, y1, 0.62)
	var wm: float = hw.call(ym)
	k.box(dark, Transform3D(Basis(), Vector3(-wm - 1.1, ym, 0.0)), Vector3(2.4, 0.18, 3.2))
	k.wear = Color(0.9, 0.5, 0.5)
	k.beam(yel, Vector3(-wm - 2.3, ym, -1.6), Vector3(-wm - 2.3, ym + 1.1, -1.6), 0.08)
	k.beam(yel, Vector3(-wm - 2.3, ym, 1.6), Vector3(-wm - 2.3, ym + 1.1, 1.6), 0.08)
	k.beam(yel, Vector3(-wm - 2.3, ym + 1.1, -1.6), Vector3(-wm - 2.3, ym + 1.1, 1.6), 0.08)
	# Takel aan de kabel (scheef: de kabel is aan één kant gebroken).
	k.wear = Color(0.6, 0.8, 0.5)
	k.beam(dark, Vector3(0.0, y1, 0.0), Vector3(0.4, 20.0, 0.3), 0.07)
	k.beam(dark, Vector3(0.3, y1, -0.2), Vector3(0.7, 20.0, 0.1), 0.07)
	k.box(yel, Transform3D(Basis(Vector3.FORWARD, 0.12), Vector3(0.55, 19.0, 0.2)), Vector3(1.0, 2.2, 0.9))
	k.beam(dark, Vector3(0.55, 17.9, 0.2), Vector3(0.6, 15.5, 0.2), 0.18)
	# Het lierhuis op het dek (geel, schuin dak), en de loopbrug naar de grond.
	k.wear = Color(0.95, 0.75, 0.5)
	var house := PackedVector2Array([Vector2(-2.6, -5.7), Vector2(2.4, -5.7), Vector2(2.9, -5.2), Vector2(2.9, -2.4), Vector2(-3.1, -2.4), Vector2(-3.1, -5.2)])
	k.prism(yel, Transform3D(), house, sub_h + 0.5, sub_h + 3.6)
	var roof := PackedVector2Array()
	for q in house:
		roof.append(Vector2(-0.1, -4.05) + (q - Vector2(-0.1, -4.05)) * 1.1)
	k.prism(dark, Transform3D(), roof, sub_h + 3.6, sub_h + 3.95)
	k.box(dark, Transform3D(Basis(), Vector3(-0.2, sub_h + 1.8, -2.35)), Vector3(1.6, 1.4, 0.12))
	k.wear = Color(0.8, 0.6, 0.5)
	var ramp_a := Vector3(-16.0, 0.3, 1.5)
	var ramp_b := Vector3(-6.0, sub_h + 0.5, 1.5)
	k.beam(dark, ramp_a, ramp_b, 0.3, 2.0)
	for t in [0.25, 0.6]:
		var pt: Vector3 = ramp_a.lerp(ramp_b, t)
		k.beam(rust, Vector3(pt.x, 0.0, 0.8), Vector3(pt.x, pt.y - 0.2, 0.8), 0.25)
		k.beam(rust, Vector3(pt.x, 0.0, 2.2), Vector3(pt.x, pt.y - 0.2, 2.2), 0.25)
	# Trap van de grond naar het dek.
	k.beam(yel, Vector3(7.5, 0.0, -4.0), Vector3(5.8, sub_h + 0.5, -4.0), 0.15, 1.1)
	# Buizenrek naast de loopbrug: lange buizen op drie bokjes, één is eraf gerold.
	for t in 3:
		var x := -12.0 - t * 4.5
		k.box(rust, Transform3D(Basis(), Vector3(x, 0.45, 5.0)), Vector3(0.3, 0.9, 4.0))
	for j in 5:
		var z := 3.4 + j * 0.62
		k.cyl(dark, Vector3(-22.5, 1.1, z), Vector3(-9.5, 1.1, z), 0.27, 6, true)
	k.cyl(dark, Vector3(-21.0, 0.27, 8.6), Vector3(-9.0, 0.27, 10.4), 0.27, 6, true)
	# Twee tanks op zadels, en een lange modderbak.
	k.wear = Color(0.85, 0.75, 0.5)
	for t in 2:
		var z := 9.5 + t * 3.4
		k.cyl(yel, Vector3(-3.5, 1.7, z), Vector3(4.5, 1.7, z), 1.4, 12, true)
		for x in [-2.0, 3.0]:
			k.box(dark, Transform3D(Basis(), Vector3(x, 0.4, z)), Vector3(0.5, 0.8, 2.4))
	k.box(dark, Transform3D(Basis(Vector3.UP, 0.05), Vector3(1.0, 1.3, -10.5)), Vector3(11.0, 2.6, 3.2))
	k.box(rust, Transform3D(Basis(), Vector3(1.0, 2.7, -10.5)), Vector3(11.2, 0.15, 0.15))
	return k.arrays()


## Pijpleiding: buis (Ø 1,2 m) op A-schragen om de 12 m, flenzen op de naden, om de ±200 m een
## afsluiter met een geel handwiel. In stukken van ±380 m (elk een eigen mesh).
static func _pipe_chunks(lf: LandformRoestbol, s: PlanetSurface) -> Array:
	var chunks := []
	var pts := PackedVector3Array()
	for p in lf.pipe:
		pts.append(Vector3(p.x, s.far_height(p.x, p.y) + 1.7, p.y))
	var i := 0
	while i < pts.size() - 1:
		var i1 := mini(i + PIPE_CHUNK, pts.size() - 1)
		var center := (pts[i] + pts[i1]) * 0.5
		var k := Kit.new()
		k.wear = Color(0.85, 0.65, 0.5)
		# Het laatste punt van een stuk is het eerste van het volgende: enkel de buis tot daar.
		var last := i1 if i1 == pts.size() - 1 else i1 - 1
		for j in range(i, last + 1):
			var a := pts[j] - center
			var dir := (pts[mini(j + 1, pts.size() - 1)] - pts[maxi(j - 1, 0)])
			dir.y = 0.0
			dir = dir.normalized()
			var side := dir.cross(Vector3.UP).normalized()
			# Schraag (A-vorm) onder elk punt; voet 1,7 m lager (de grond). Alles één materiaal (één
			# draw call per stuk): donker staal leest van boven als een lijn met een schaduwlijn.
			var foot := a - Vector3(0.0, 1.7, 0.0)
			k.beam("DarkSteel", foot + side * 1.15, a - Vector3(0.0, 0.55, 0.0) + side * 0.2, 0.16)
			k.beam("DarkSteel", foot - side * 1.15, a - Vector3(0.0, 0.55, 0.0) - side * 0.2, 0.16)
			# Flens op de naad.
			k.cyl("DarkSteel", a - dir * 0.16, a + dir * 0.16, 0.76, 6, false)
			if j < pts.size() - 1:
				k.cyl("DarkSteel", a, pts[j + 1] - center, 0.6, 6, false)
			# Afsluiter: een kast op de buis met een handwiel bovenop.
			if j % 17 == 8:
				k.cyl("DarkSteel", a, a + Vector3(0.0, 1.5, 0.0), 0.42, 6, true)
				var wc := a + Vector3(0.0, 1.62, 0.0)
				for w in 6:
					var a0 := TAU * w / 6
					var a1 := TAU * (w + 1) / 6
					k.beam("DarkSteel", wc + Vector3(cos(a0), 0.0, sin(a0)) * 0.6, wc + Vector3(cos(a1), 0.0, sin(a1)) * 0.6, 0.09)
				k.beam("DarkSteel", wc - side * 0.6, wc + side * 0.6, 0.06)
		chunks.append([center, k.arrays(), i == 0])
		i = i1
	return chunks


## Meetpalen: een paaltje van 2 m met een vlagje en een geverfde stip van 2,4 m op de grond (van
## 300 m zie je enkel de stippen: een stippellijn).
static func _stakes(lf: LandformRoestbol, s: PlanetSurface) -> Array:
	if lf.stakes.is_empty():
		return []
	var pts := PackedVector3Array()
	var center := Vector3.ZERO
	for p in lf.stakes:
		var v := Vector3(p.x, s.far_height(p.x, p.y), p.y)
		pts.append(v)
		center += v
	center /= pts.size()
	var k := Kit.new()
	k.wear = Color(0.5, 0.4, 0.5)
	for n in pts.size():
		var a := pts[n] - center
		var lean := Vector3(sin(n * 1.7) * 0.15, 0.0, cos(n * 2.3) * 0.15)
		k.beam("Hazard", a - Vector3(0.0, 0.3, 0.0), a + Vector3(0.0, 2.0, 0.0) + lean, 0.07)
		var top := a + Vector3(0.0, 1.95, 0.0) + lean
		var fdir := Vector3(cos(n * 0.9), 0.0, sin(n * 0.9))
		var f0 := top + fdir * 0.62
		var f1 := top - Vector3(0.0, 0.42, 0.0) + fdir * 0.62
		var f2 := top - Vector3(0.0, 0.42, 0.0)
		var nrm := fdir.cross(Vector3.UP)
		k.quad("Yellow", top, f0, f1, f2, nrm)
		k.quad("Yellow", top, f0, f1, f2, -nrm)
		# De verfstip: een platte schijf, net boven de grond (op de schuine grond iets dieper).
		var poly := PackedVector2Array()
		for q in 10:
			poly.append(Vector2(cos(TAU * q / 10), sin(TAU * q / 10)) * 0.95)
		k.prism("Yellow", Transform3D(Basis(), a), poly, -0.35, 0.07)
	return [center, k.arrays()]


## Reclamebord (8 × 4 m) op twee poten, een beetje scheef gezakt. De tekst hangt de hoofdthread
## eraan (Label3D). Lokaal: −z is de voorkant (naar de landingsplek).
static func _board_arrays() -> Dictionary:
	var k := Kit.new()
	k.wear = Color(0.9, 0.6, 0.5)
	for sx in [-2.6, 2.6]:
		k.box("DarkSteel", Transform3D(Basis(), Vector3(sx, 2.6, 0.25)), Vector3(0.36, 6.0, 0.3))
		k.beam("DarkSteel", Vector3(sx, 0.0, 2.4), Vector3(sx, 4.2, 0.4), 0.18)
		k.box("DarkSteel", Transform3D(Basis(), Vector3(sx, 0.1, 1.2)), Vector3(0.9, 0.25, 3.0))
	k.wear = Color(0.95, 0.75, 0.5)
	k.box("Yellow", Transform3D(Basis(), Vector3(0.0, 5.0, 0.0)), Vector3(8.0, 4.0, 0.22))
	k.box("DarkSteel", Transform3D(Basis(), Vector3(0.0, 3.0, 0.0)), Vector3(8.2, 0.14, 0.3))
	k.box("DarkSteel", Transform3D(Basis(), Vector3(0.0, 7.0, 0.0)), Vector3(8.2, 0.14, 0.3))
	# Een omgevallen schijnwerper aan de voet.
	k.cyl("DarkSteel", Vector3(3.6, 0.35, -1.4), Vector3(4.4, 0.6, -2.0), 0.35, 8, true)
	return k.arrays()


## Afgeschreven Mol (asset M-07): de achterkant van de romp (achthoekig, geel met strepen) steekt
## schuin uit het zand, de boorkop zit erin. Rupsen, de klep op een kier, een bordje ernaast.
static func _wreck_arrays() -> Dictionary:
	var k := Kit.new()
	var oct := PackedVector2Array()
	for q in 8:
		var a := TAU * (q + 0.5) / 8
		oct.append(Vector2(cos(a) * 3.0, sin(a) * 2.9))
	# De romp: van z = −5 (de neus, in het zand) tot z = +4,5 (de achterkant), schuin.
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-24.0)) * Basis(Vector3.FORWARD, deg_to_rad(9.0))
	var body := Transform3D(tilt, Vector3(0.0, 0.2, 0.0))
	k.wear = Color(1.0, 0.85, 0.5)
	var oct3 := PackedVector2Array()
	for q in oct:
		oct3.append(Vector2(q.x, q.y))
	# Prisma langs z: de veelhoek ligt in x/y, dus een rotatie die y naar z draait.
	var along := body * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	k.prism("Yellow", along, oct3, -5.0, 4.0)
	k.prism("Anthracite", along, oct3, 4.0, 4.5, 0.85)
	# Waarschuwingsstroken op de hoeken van de achterkant, en de klep op een kier.
	for sx in [-1.0, 1.0]:
		k.box("Hazard", body * Transform3D(Basis(), Vector3(sx * 2.55, 0.0, 4.35)), Vector3(0.5, 4.4, 0.4))
	k.box("Yellow", body * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-28.0)), Vector3(0.0, -1.6, 5.2)), Vector3(3.8, 0.2, 2.6))
	# Rupsen aan beide kanten (half begraven).
	k.wear = Color(0.6, 0.8, 0.5)
	for sx in [-1.0, 1.0]:
		k.box("Anthracite", body * Transform3D(Basis(), Vector3(sx * 3.15, -2.0, -0.2)), Vector3(0.9, 1.4, 7.6))
	# Bovenop: het kastje en een gebroken antenne.
	k.box("Anthracite", body * Transform3D(Basis(), Vector3(0.0, 2.95, 1.4)), Vector3(1.9, 0.6, 2.4))
	k.beam("Anthracite", body * Vector3(1.2, 2.9, -1.0), body * Vector3(2.4, 4.6, -2.2), 0.08)
	# Bordje op een paal naast het wrak.
	k.wear = Color(0.6, 0.4, 0.5)
	# (De paal staat achter het bordje, niet ervoor.)
	k.beam("Anthracite", Vector3(-5.53, -0.4, 5.53), Vector3(-5.53, 2.0, 5.53), 0.12)
	k.box("Yellow", Transform3D(Basis(Vector3.UP, 0.4), Vector3(-5.5, 1.75, 5.62)), Vector3(1.6, 0.8, 0.06))
	return k.arrays()


# --- Rotsen -----------------------------------------------------------------------------------------

## Rotsblok: een veelhoek die in drie ringen naar boven loopt (breed onderaan, een schuine, gebroken
## top). `flat` < 1 en twee ringen: een plaat. Enkel facetten (16–32 driehoeken), zonder onderkant
## (die zit in de grond).
static func rock_block(rock_seed: int, sides: int, flat: float, ring_count := 3) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rock_seed
	var rings: Array = []
	var hs := [-0.25, 0.25 * flat, 0.62 * flat] if ring_count == 3 else [-0.25, 0.5 * flat]
	var sc := [1.0, rng.randf_range(0.9, 1.05), rng.randf_range(0.55, 0.8)] if ring_count == 3 else [1.0, rng.randf_range(0.75, 0.9)]
	var tilt := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)) * flat
	var base: Array[float] = []
	for i in sides:
		base.append(rng.randf_range(0.7, 1.15))
	for r in ring_count:
		var ring: Array[Vector3] = []
		for i in sides:
			var a := TAU * (i + rng.randf_range(-0.2, 0.2)) / sides
			var rad: float = base[i] * sc[r] * rng.randf_range(0.9, 1.08)
			var p := Vector2(cos(a), sin(a)) * rad * Vector2(1.0, rng.randf_range(0.75, 0.95))
			var y: float = hs[r] + (tilt.dot(p) if r == ring_count - 1 else 0.0) + rng.randf_range(-0.05, 0.05)
			ring.append(Vector3(p.x, y, p.y))
		rings.append(ring)
	var k := Kit.new()
	k.wear = Color(1, 1, 1)
	var c := Vector3(0.0, 0.2 * flat, 0.0)
	for r in ring_count - 1:
		var lo: Array = rings[r]
		var hi: Array = rings[r + 1]
		for i in sides:
			var j := (i + 1) % sides
			var mid: Vector3 = (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25
			k.quad("rock", lo[i], lo[j], hi[j], hi[i], mid - c)
	var top: Array = rings[ring_count - 1]
	for i in range(1, sides - 1):
		k.tri("rock", top[0], top[i], top[i + 1], Vector3.UP)
	var arrays: Array = k.arrays()["rock"]
	arrays[Mesh.ARRAY_COLOR] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Rotsen in groepjes: onder de wand (veel, groot), op de waaiers, op de rand, en op de bodem in
## groepjes met lege stukken ertussen; plus 14–22 reuzenblokken die uit de wand gevallen zijn (in de
## kleur van de lagen). Drie vormen: 0 blok, 1 plaat, 2 klomp. [transforms per vorm, kleuren per vorm].
static func _rocks(lf: LandformRoestbol, s: PlanetSurface, rng: RandomNumberGenerator) -> Array:
	var xfs: Array = [[], [], []]
	var cols: Array = [[], [], []]
	var g := PlanetType.ground(PlanetType.Id.ROESTBOL)
	var rock: Color = g.rock
	var strata: Array = g.strata
	var talus_col := rock.lerp(strata[1] as Color, 0.3)
	var place := func(p: Vector2, size: float, kind: int, col: Color, sink: float) -> void:
		if lf._in_area(p, 8.0 + size) or p.distance_to(lf.pit_c) < lf.pit_r * 1.02:
			return
		var y := s.far_height(p.x, p.y)
		var flat := [rng.randf_range(0.6, 0.9), rng.randf_range(0.3, 0.45), rng.randf_range(0.55, 0.8)][kind] as float
		var sc := Vector3(size * rng.randf_range(0.85, 1.25), size * flat, size * rng.randf_range(0.8, 1.2))
		var rot := Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
		(xfs[kind] as Array).append(Transform3D(Basis.from_euler(rot).scaled(sc), Vector3(p.x, y - sc.y * sink, p.y)))
		var v := rng.randf_range(0.8, 1.12)
		(cols[kind] as Array).append(Color(col.r * v, col.g * v, col.b * v))
	var kind_of := func(slab_k: float) -> int:
		var r := rng.randf()
		return 1 if r < slab_k else (0 if r < slab_k + (1.0 - slab_k) * 0.55 else 2)
	# Langs de voet van de wand (het deel dat je ziet): groepjes om de 35–80 m.
	var arc := -1400.0
	while arc < 1400.0:
		arc += rng.randf_range(18.0, 45.0)
		var ang := lf._a0 + arc / lf._r0
		var i := lf._idx(ang)
		var dir := Vector2(cos(ang), sin(ang))
		var foot := lf.crater_r - lf._off[i] - lf._w[i]
		var toe := foot - lf._apron[i]
		var c := lf.crater_c + dir * rng.randf_range(toe - 10.0, foot + 15.0)
		for m in rng.randi_range(5, 14):
			var q := c + Vector2(rng.randfn(0.0, 16.0), rng.randfn(0.0, 16.0))
			place.call(q, lerpf(1.2, 6.5, pow(rng.randf(), 2.2)), kind_of.call(0.35), talus_col, 0.3)
	# Reuzenblokken uit de wand: op het puin en een eind de bodem op, in de kleur van de lagen.
	for m in rng.randi_range(12, 18):
		var ang := lf._a0 + rng.randf_range(-850.0, 850.0) / lf._r0
		var i := lf._idx(ang)
		var dir := Vector2(cos(ang), sin(ang))
		var foot := lf.crater_r - lf._off[i] - lf._w[i]
		var q := lf.crater_c + dir * (foot - lf._apron[i] * rng.randf_range(0.2, 1.6) - rng.randf_range(0.0, 30.0))
		var size := rng.randf_range(8.0, 20.0)
		var col: Color = rock.lerp(strata[1 + rng.randi() % 2] as Color, 0.45)
		place.call(q, size, 0, col, 0.35)
		for b in rng.randi_range(4, 9):
			place.call(q + Vector2(rng.randfn(0.0, size), rng.randfn(0.0, size)), size * rng.randf_range(0.12, 0.35), kind_of.call(0.5), col, 0.3)
	# Op de rand en het plateau erachter: lage groepjes (silhouet tegen de lucht).
	for m in 26:
		var ang := lf._a0 + rng.randf_range(-1300.0, 1300.0) / lf._r0
		var i := lf._idx(ang)
		var dir := Vector2(cos(ang), sin(ang))
		var c := lf.crater_c + dir * (lf.crater_r - lf._off[i] + rng.randf_range(15.0, 160.0))
		for b in rng.randi_range(3, 7):
			place.call(c + Vector2(rng.randfn(0.0, 10.0), rng.randfn(0.0, 10.0)), rng.randf_range(1.0, 4.5), kind_of.call(0.3), rock, 0.3)
	# Op de bodem: groepjes (één grote, wat kleine), met veel lege ruimte ertussen.
	for m in 130:
		var ang := rng.randf() * TAU
		var c := lf.landing + Vector2(cos(ang), sin(ang)) * lerpf(145.0, 950.0, sqrt(rng.randf()))
		if lf.crater_d(c) > lf._toe_at(c) - 15.0:
			continue
		var big := rng.randf_range(2.0, 4.8)
		place.call(c, big, kind_of.call(0.2), rock, 0.3)
		for b in rng.randi_range(3, 9):
			var q := c + Vector2(rng.randfn(0.0, 7.0), rng.randfn(0.0, 7.0))
			place.call(q, big * rng.randf_range(0.2, 0.55), kind_of.call(0.5), rock, 0.25)
	# En losse stenen, enkel waar de klonterruis het toelaat (zo blijven er lege stukken).
	for m in 800:
		var ang := rng.randf() * TAU
		var q := lf.landing + Vector2(cos(ang), sin(ang)) * lerpf(135.0, 1000.0, sqrt(rng.randf()))
		if lf._clump.get_noise_2d(q.x, q.y) < 0.05 or lf.crater_d(q) > lf._toe_at(q) - 5.0:
			continue
		place.call(q, lerpf(0.6, 2.4, pow(rng.randf(), 1.8)), kind_of.call(0.4), rock, 0.25)
	# Platen op de stortbergen en aan de rand van de put (afval van de mijn).
	for m in 30:
		var ang := rng.randf() * TAU
		var q := lf.pit_c + Vector2(cos(ang), sin(ang)) * lf.pit_r * rng.randf_range(1.05, 1.5)
		place.call(q, rng.randf_range(1.0, 3.0), 1, rock.lerp(Color(0.6, 0.55, 0.52), 0.4), 0.2)
	# MultiMesh-buffers hier al vullen (werkthread): per exemplaar 12 floats transform (rij per rij)
	# en 4 floats kleur. Op de hoofdthread is het dan één toewijzing in plaats van duizenden aanroepen.
	var bufs := []
	for kind in 3:
		var list: Array = xfs[kind]
		var cl: Array = cols[kind]
		var buf := PackedFloat32Array()
		buf.resize(list.size() * 16)
		for i in list.size():
			var xf: Transform3D = list[i]
			var c: Color = cl[i]
			var o := i * 16
			var b := xf.basis
			buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = xf.origin.x
			buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = xf.origin.y
			buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = xf.origin.z
			buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
		bufs.append([list.size(), buf])
	return bufs


# --- Stofduivels --------------------------------------------------------------------------------

## Waar een stofduivel heen loopt: verder in de richting van zijn spoor, in een flauwe bocht, met de
## hoogte van de grond (hij loopt heen en terug over dit stuk). [punten, hoogte van de kolom].
static func _devil_path(lf: LandformRoestbol, s: PlanetSurface, dv: Array) -> Array:
	var head: Vector2 = dv[0]
	var dir: Vector2 = dv[1]
	var pts := PackedVector3Array()
	var p := head - dir * 60.0
	for i in 30:
		pts.append(Vector3(p.x, s.far_height(p.x, p.y), p.y))
		dir = dir.rotated(0.035 * sin(i * 0.4))
		p += dir * 8.0
	return [pts, dv[2]]


# --- Hoofdthread --------------------------------------------------------------------------------

static func commit(lf: LandformRoestbol, root: Node3D, out: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var mats := {}
	var mat := func(name: String) -> Material:
		if not mats.has(name):
			mats[name] = MolVisual.machine_material(name, false, 2.0)
		return mats[name]
	if out.has("rb_rig"):
		var r: Array = out.rb_rig
		var rig := _mesh_node("OldRig", r[2], mat, r[0], r[1])
		root.add_child(rig)
		SurfaceDressing.red_light(rig, Vector3(0.0, 43.6, 0.0), Color(1.0, 0.16, 0.08), 3.0, 40.0)
		for c in rig.get_children():
			if c is GeometryInstance3D:
				(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_label(rig, "CLAIM 7A — DEPLETED.\nTHANK YOU FOR YOUR SACRIFICE.", Transform3D(Basis(), Vector3(-0.2, 8.6, -5.78)).rotated_local(Vector3.UP, PI), 0.006, Color(0.1, 0.1, 0.1), 5.4)
	if out.has("rb_pipe"):
		var n := 0
		for ch: Array in out.rb_pipe:
			var node := _mesh_node("Pipeline_%d" % n, ch[1], mat, ch[0], 0.0)
			root.add_child(node)
			n += 1
	if out.has("rb_stakes") and not (out.rb_stakes as Array).is_empty():
		var st: Array = out.rb_stakes
		var stakes := _mesh_node("SurveyStakes", st[1], mat, st[0], 0.0)
		stakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # dun: geen schaduw nodig
		root.add_child(stakes)
	if out.has("rb_board"):
		var b: Array = out.rb_board
		var board := _mesh_node("DigBoard", b[2], mat, b[0], b[1] + PI * 0.5)
		root.add_child(board)
		board.rotate_object_local(Vector3.RIGHT, deg_to_rad(-4.0))
		_label(board, b[3], Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 5.0, -0.13)), 0.0105, Color(0.09, 0.09, 0.1), 7.2)
	if out.has("rb_wreck"):
		var w: Array = out.rb_wreck
		var wreck := _mesh_node("WreckM07", w[2], mat, w[0] - Vector3(0.0, 0.6, 0.0), w[1])
		root.add_child(wreck)
		# Het nummer op de achterkant (zelfde stand als de romp in _wreck_arrays).
		var tilt := Basis(Vector3.RIGHT, deg_to_rad(-24.0)) * Basis(Vector3.FORWARD, deg_to_rad(9.0))
		_label(wreck, "M-07", Transform3D(tilt, Vector3(0.0, 0.2, 0.0) + tilt * Vector3(0.0, 0.6, 4.53)), 0.011, Color(0.08, 0.08, 0.08))
		var plate := Basis(Vector3.UP, 0.4)
		_label(wreck, "ASSET M-07\nWRITTEN OFF.\nCOST DEDUCTED FROM\nCREW WAGES.", Transform3D(plate, Vector3(-5.5, 1.75, 5.62) + plate * Vector3(0.0, 0.0, 0.045)), 0.0022, Color(0.1, 0.1, 0.1), 1.45)
	if out.has("rb_rocks"):
		_commit_rocks(root, out.rb_rocks, lf._seed)
	# Ontwikkelhulp: vaste camerabeelden (RoestbolShots), enkel met --rb-shots.
	if CmdArgs.has("rb-shots") and root.get_parent() is PlanetSurface:
		var shots := RoestbolShots.new()
		shots.lf = lf
		shots.surface = root.get_parent()
		root.add_child(shots)
	if out.has("rb_devils"):
		var sun := PlanetType.params(PlanetType.Id.ROESTBOL).sun_rotation_deg as Vector3
		var to_sun := Basis.from_euler(Vector3(deg_to_rad(sun.x), deg_to_rad(sun.y), deg_to_rad(sun.z))).z
		var k := 0
		for dv: Array in out.rb_devils:
			var devil := RoestbolDustDevil.new()
			devil.name = "DustDevil_%d" % k
			devil.setup(dv[0], dv[1], to_sun, lf._seed + k * 31)
			root.add_child(devil)
			k += 1
	var n_rocks := 0
	if out.has("rb_rocks"):
		for entry: Array in out.rb_rocks:
			n_rocks += int(entry[0])
	print("[roestbol] krater %.0f m, %d duinen, %d sporen, %d stofduivels, %d rotsen; werkthread %.0f ms, hoofdthread %.0f ms" % [
			lf.crater_r, lf.dunes.size(), lf.tracks.size(), lf.devils.size(), n_rocks,
			int(out.get("rb_compute_us", 0)) / 1000.0, (Time.get_ticks_usec() - t0) / 1000.0])


## Een model uit Kit-arrays: één mesh, een surface per materiaal, op `pos` gedraaid met `yaw`
## (rad, zodat lokaal +x naar die hoek in x/z wijst).
static func _mesh_node(name: String, arrays: Dictionary, mat: Callable, pos: Vector3, yaw: float) -> MeshInstance3D:
	var m := ArrayMesh.new()
	for k: String in arrays:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[k])
		m.surface_set_material(m.get_surface_count() - 1, mat.call(k))
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = m
	mi.position = pos
	mi.rotation.y = -yaw
	mi.visibility_range_end = HIDE_M
	return mi


## Geschilderde tekst (Engels, Bungee), enkel van dichtbij getekend. `max_w`: de langste regel past
## op zoveel meter (Bungee: ±0,64 em per teken).
static func _label(parent: Node3D, text: String, xf: Transform3D, pixel: float, color: Color, max_w := 0.0) -> void:
	if max_w > 0.0:
		var longest := 1
		for line in text.split("\n"):
			longest = maxi(longest, line.length())
		pixel = minf(pixel, max_w / (longest * 0.64 * 96.0))
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.heading()
	l.font_size = 96
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.transform = xf
	l.visibility_range_end = 220.0
	parent.add_child(l)


static func _commit_rocks(root: Node3D, rocks: Array, rock_seed: int) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	var chunk := SurfaceDressing.rock_mesh(rock_seed * 3 + 3, 0.62, 1.25)
	var meshes := [rock_block(rock_seed * 3 + 1, 6, 1.0), rock_block(rock_seed * 3 + 2, 5, 0.4, 2), chunk]
	for kind in 3:
		var count: int = rocks[kind][0]
		if count == 0:
			continue
		var mesh: ArrayMesh = meshes[kind]
		mesh.surface_set_material(0, mat)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = count
		mm.buffer = rocks[kind][1]
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["RockBlocks", "RockSlabs", "RockChunks"][kind]
		mmi.multimesh = mm
		mmi.visibility_range_end = HIDE_M
		# Platen liggen plat: hun schaduw zie je niet, die besparen we (de helft van de driehoeken).
		if kind == 1:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
