class_name LandformFossiel
extends Landform
## Fossielwereld (docs/research/planeten.md §4.2), hemel B: een wit badland onder een teal lucht,
## waar donkere, versteende reuzenskeletten uit de lagen eroderen (archeologie die je van boven al
## ziet), een gestreepte klif met een roestige ijzerband, en warme mist in de geulen.
##
## Opbouw (vanaf de landingsplek; de dropcamera kijkt bij het remmen naar −z):
## - Een escarpment links vóór (in de zon van hemel B): de rand van een hoogvlakte van ±100 m, met
##   drie treden, baaien en uitlopers, een puinhelling eronder, en een kloof waar de droge bedding
##   uit het plateau komt. Losse buttes (resten van het plateau) aan de kim, één per kwadrant.
## - Een vlakke kalkbodem rond het speelgebied (onregelmatig, groter dan het vierkant), daarbuiten
##   badlands: ruggen en V-geulen (ruis met domain warp), hoger naar de klif toe.
## - Een droge bedding schuin door de concessie, van de kloof in de klif tot voorbij de kim.
## - Het reuzenskelet (het grote landmark) op de bodem tussen het speelgebied en de klif: een
##   gewelfde ribbenkast met de rug als kam, een nek naar een schedel met kam, hoorns en tanden, en
##   een staart die in de grond verdwijnt. Een tweede, half begraven ribbenkast linksachter, en
##   botfragmenten in groepjes. Donker versteend bot (Jayme): leesbaar tegen de kalk.
## - Een verlaten DIG-meetkamp bij de schedel (zeil, kisten, palen, een bord in het Engels, afgedekte
##   putten, een mast met een amber lampje), en warme mist in de geulen en de bedding.

const BONE_SHADER := preload("res://src/world/fossiel_bone.gdshader")
const MIST_SHADER := preload("res://src/world/fossiel_mist.gdshader")
const BEACON := Color(1.0, 0.71, 0.35) # baken-amber (#FFB45A)

# Escarpment: de rand van een ronde hoogvlakte (midden, straal), hoogte, breedte van de wand
# (voet → bovenrand) en van de puinhelling ervoor.
var cliff_c := Vector2.ZERO
var cliff_r := 1500.0
var cliff_h := 100.0
var wall_w := 68.0
const TALUS_W := 55.0
# Vlakke kalkbodem rond de landingsplek (gemiddelde straal, m).
var floor_r := 185.0
# Droge bedding: punten (wereld x/z), halve breedte en diepte.
var wash := PackedVector2Array()
const WASH_HALF := 22.0
const WASH_DEPTH := 3.5
const WASH_CELL := 64.0
const WASH_REACH := 70.0 # verder dan dit van de bedding telt ze niet (alles daarbuiten = WASH_REACH)
var _wash_grid := {} # Vector2i -> PackedInt32Array (stukken van de bedding in de buurt)
# Buttes (aan de kim) en kleine restmesa's in de badlands: x, z, straal, hoogte.
var buttes: Array[Vector4] = []
var _butte_grid := {} # Vector2i (cel van BUTTE_CELL) -> Array[int]
const BUTTE_CELL := 160.0
# Badlands: hoe hoog de ruggen worden (m), en vanaf waar ze uitdoven.
const BAD_AMP := 21.0
const BAD_FADE := Vector2(900.0, 1700.0)
# Het reuzenskelet: midden van de ribbenkast, richting van de kop, en de maten langs de rug.
var giant_c := Vector2.ZERO
var giant_dir := Vector2.LEFT
const RIB_HALF := 46.0
const NECK_L := 38.0
const TAIL_L := 66.0
## Schaal van de schedel (1 = ±31 m lang).
const SKULL_S := 1.5
# Tweede ribbenkast (half begraven) en de meetkamp.
var ribs2_c := Vector2.ZERO
var ribs2_dir := Vector2.RIGHT
var camp_c := Vector2.ZERO
var camp_face := Vector2.DOWN
# Hoodoos (krijtpaddenstoelen) in groepjes: x, z, aantal.
var hoodoo_sites: Array[Vector3] = []

var _edge := FastNoiseLite.new() # langs de rand van de klif: baaien, uitlopers, kloven
var _bad := FastNoiseLite.new() # badlands: de nullijnen zijn de geulen
var _warp := FastNoiseLite.new()
var _shape := FastNoiseLite.new() # omtrek van de kalkbodem
var _macro := FastNoiseLite.new() # waar de badlands hoog zijn en waar rustige vlaktes liggen
var _seed := 0
# Velden per punt (zie _fields): het resultaat, en een vaste tabel als geheugen (x, z | 5 velden).
var _f_u := 0.0
var _f_wd := 0.0
var _f_amp := 0.0
var _f_v := 0.0
var _f_bh := 0.0
const CACHE_N := 65536
var _ck := PackedFloat32Array()
var _cv := PackedFloat32Array()
# Ruis als tabellen en rasters. Op de werkthread is tijdens het laden van een wereld een oproep naar
# een object (FastNoiseLite) 10–40× trager dan rekenen in GDScript (gemeten: 1–6 µs per oproep; de
# voxelthreads werken dan volop), dus de ruis wordt één keer in bulk gemaakt (get_image, of een
# tabel in setup) en daarna enkel nog uit arrays gelezen.
const EDGE_STEP := 4.0 # m boog langs de rand van de klif
var _edge_a := PackedFloat32Array() # baaien en uitlopers
var _edge_b := PackedFloat32Array() # kloven
var _edge_x0 := 0.0
const FLOOR_STEPS := 720 # omtrek van de kalkbodem, per halve graad
var _floor_t := PackedFloat32Array()
const RAS_REACH := 1800.0 # m rond de landingsplek
const BAD_STEP := 6.0
const WARP_STEP := 12.0
const MACRO_STEP := 16.0
var _ras_ready := false
var _r_origin := Vector2.ZERO
var _ras_all := PackedByteArray() # alle rasters na elkaar
var _bad_o := 0 # begin van elk raster in _ras_all
var _wx_o := 0
var _wz_o := 0
var _macro_o := 0
var _bad_n := 0
var _warp_n := 0
var _macro_n := 0


func setup(planet_seed: int, landing_xz: Vector2, size: Vector2) -> void:
	super(planet_seed, landing_xz, size)
	_seed = planet_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 2654435761 + 23
	for n: FastNoiseLite in [_edge, _bad, _warp, _shape, _macro]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_edge.seed = planet_seed + 401
	_edge.frequency = 0.0035
	_edge.fractal_octaves = 2
	_bad.seed = planet_seed + 402
	_bad.frequency = 0.0058
	_bad.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_bad.fractal_octaves = 2
	_bad.fractal_gain = 0.45
	_warp.seed = planet_seed + 403
	_warp.frequency = 0.006
	_warp.fractal_octaves = 1
	_shape.seed = planet_seed + 404
	_shape.frequency = 0.01
	_shape.fractal_octaves = 2
	_macro.seed = planet_seed + 405
	_macro.frequency = 0.0024
	_macro.fractal_octaves = 2

	# De klif links vóór: daar valt de zon van hemel B (van rechtsachter) vol op de wand.
	var bear := rng.randf_range(-38.0, -30.0)
	var dist := rng.randf_range(318.0, 335.0)
	cliff_r = rng.randf_range(1300.0, 1600.0)
	cliff_c = landing + _dir(bear) * (dist + cliff_r)
	cliff_h = rng.randf_range(96.0, 110.0)
	wall_w = rng.randf_range(62.0, 72.0)
	# Tabellen voor de rand van de klif (boog −πR..πR) en de omtrek van de bodem (hoek −π..π).
	_edge_x0 = -PI * cliff_r - EDGE_STEP
	var ne := int(TAU * cliff_r / EDGE_STEP) + 4
	_edge_a.resize(ne)
	_edge_b.resize(ne)
	for i in ne:
		var arc := _edge_x0 + i * EDGE_STEP
		_edge_a[i] = _edge.get_noise_1d(arc)
		_edge_b[i] = _edge.get_noise_1d(arc * 2.4 + 1234.0)
	_floor_t.resize(FLOOR_STEPS + 2)
	for i in FLOOR_STEPS + 2:
		_floor_t[i] = _shape.get_noise_1d((-PI + TAU * i / FLOOR_STEPS) * 180.0)
	_ras_ready = false

	# Het skelet ligt dwars voor de camera (van opzij te zien), de kop naar de klif.
	giant_c = landing + Vector2(rng.randf_range(-70.0, -55.0), -rng.randf_range(222.0, 232.0))
	giant_dir = Vector2.LEFT.rotated(deg_to_rad(rng.randf_range(-6.0, 6.0)))
	# Tweede ribbenkast linksachter, de kamp vóór de nek (naar de landingsplek toe).
	ribs2_c = landing + _dir(rng.randf_range(-118.0, -106.0)) * rng.randf_range(265.0, 290.0)
	ribs2_dir = _dir(rng.randf_range(10.0, 40.0))
	var neck := giant_c + giant_dir * (RIB_HALF + NECK_L * 0.6)
	camp_c = neck + (landing - neck).normalized() * 30.0 + giant_dir.orthogonal() * rng.randf_range(-4.0, 4.0)
	camp_face = (landing - camp_c).normalized()

	# Droge bedding: uit een kloof in de klif (linksvoor), schuin door de concessie, naar rechtsachter.
	wash.clear()
	var rel_pts := [Vector2(-470.0, -330.0), Vector2(-370.0, -255.0), Vector2(-280.0, -175.0), Vector2(-190.0, -95.0),
			Vector2(-80.0, -10.0), Vector2(60.0, 70.0), Vector2(220.0, 150.0), Vector2(400.0, 215.0),
			Vector2(640.0, 250.0), Vector2(900.0, 230.0), Vector2(1200.0, 260.0)]
	for i in rel_pts.size():
		var q: Vector2 = rel_pts[i]
		wash.append(landing + q + Vector2(rng.randf_range(-18.0, 18.0), rng.randf_range(-18.0, 18.0)))
	_wash_grid.clear()
	var wr := WASH_HALF + WASH_REACH + WASH_CELL
	for i in wash.size() - 1:
		var lo := Vector2(minf(wash[i].x, wash[i + 1].x), minf(wash[i].y, wash[i + 1].y)) - Vector2(wr, wr)
		var hi := Vector2(maxf(wash[i].x, wash[i + 1].x), maxf(wash[i].y, wash[i + 1].y)) + Vector2(wr, wr)
		for gz in range(int(floor(lo.y / WASH_CELL)), int(floor(hi.y / WASH_CELL)) + 1):
			for gx in range(int(floor(lo.x / WASH_CELL)), int(floor(hi.x / WASH_CELL)) + 1):
				var cc := Vector2((gx + 0.5) * WASH_CELL, (gz + 0.5) * WASH_CELL)
				var ab := wash[i + 1] - wash[i]
				var t := clampf((cc - wash[i]).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if cc.distance_to(wash[i] + ab * t) > wr:
					continue
				var key := Vector2i(gx, gz)
				var ids: PackedInt32Array = _wash_grid.get(key, PackedInt32Array())
				ids.append(i)
				_wash_grid[key] = ids

	# Buttes: één restheuvel vlak voor de klif, en één per kwadrant aan de kim.
	buttes.clear()
	var spots := [[-80.0, 395.0, 42.0, 0.78], [14.0, 1150.0, 120.0, 0.68], [96.0, 720.0, 80.0, 0.62],
			[148.0, 830.0, 95.0, 0.55], [-168.0, 650.0, 70.0, 0.58], [-128.0, 930.0, 110.0, 0.66]]
	for sp: Array in spots:
		var b_bear: float = sp[0]
		var b_dist: float = sp[1]
		var b_r: float = sp[2]
		var b_h: float = sp[3]
		var c := landing + _dir(b_bear + rng.randf_range(-6.0, 6.0)) * (b_dist * rng.randf_range(0.92, 1.08))
		buttes.append(Vector4(c.x, c.y, b_r * rng.randf_range(0.85, 1.15), cliff_h * b_h * rng.randf_range(0.9, 1.1)))
	# Kleine restmesa's in de badlands (meso-landmarks, platte toppen met lagen), niet tussen de
	# camera en het skelet, niet op de bodem, de bedding of tegen de klif.
	var tries := 0
	var placed := 0
	while placed < 11 and tries < 400:
		tries += 1
		var bear2 := rng.randf_range(-180.0, 180.0)
		var d2 := lerpf(240.0, 880.0, sqrt(rng.randf()))
		var c2 := landing + _dir(bear2) * d2
		var r2 := rng.randf_range(26.0, 44.0)
		if bear2 > -55.0 and bear2 < 35.0 and d2 < 340.0:
			continue
		if _floor_d(c2) < r2 + 25.0 or _wash_d(c2) < r2 + 30.0 or _cliff_u(c2) > -TALUS_W - r2 - 20.0:
			continue
		var ok := true
		for b in buttes:
			if c2.distance_to(Vector2(b.x, b.y)) < (b.z + r2) * 1.8:
				ok = false
				break
		if not ok:
			continue
		buttes.append(Vector4(c2.x, c2.y, r2, rng.randf_range(12.0, 22.0) + r2 * 0.2))
		placed += 1
	_butte_grid.clear()
	for i in buttes.size():
		var b := buttes[i]
		var reach := b.z * 1.75
		for gz in range(int(floor((b.y - reach) / BUTTE_CELL)), int(floor((b.y + reach) / BUTTE_CELL)) + 1):
			for gx in range(int(floor((b.x - reach) / BUTTE_CELL)), int(floor((b.x + reach) / BUTTE_CELL)) + 1):
				var key := Vector2i(gx, gz)
				if not _butte_grid.has(key):
					_butte_grid[key] = []
				_butte_grid[key].append(i)
	wind = _dir(rng.randf_range(100.0, 125.0))
	# Hoodoos: op de rand van de kalkbodem en op rustige plekken in de badlands, in groepjes.
	hoodoo_sites.clear()
	tries = 0
	while hoodoo_sites.size() < 9 and tries < 500:
		tries += 1
		var bear3 := rng.randf_range(-180.0, 180.0)
		var d3 := lerpf(175.0, 620.0, sqrt(rng.randf()))
		var c3 := landing + _dir(bear3) * d3
		if bear3 > -50.0 and bear3 < 30.0 and d3 < 330.0:
			continue # niet tussen de camera en het skelet
		var fd := _floor_d(c3)
		if fd < -15.0 or fd > 90.0 or _wash_d(c3) < 18.0 or _cliff_u(c3) > -TALUS_W - 25.0 or _buttes(c3) > 0.5:
			continue
		if c3.distance_to(camp_c) < 60.0 or c3.distance_to(ribs2_c) < 45.0:
			continue
		var near := false
		for h in hoodoo_sites:
			if c3.distance_to(Vector2(h.x, h.y)) < 110.0:
				near = true
				break
		if not near:
			hoodoo_sites.append(Vector3(c3.x, c3.y, rng.randi_range(3, 7)))


## Eenheidsvector vanaf de landingsplek: 0° = vooruit (−z), positief = naar rechts (+x).
static func _dir(bearing_deg: float) -> Vector2:
	var a := deg_to_rad(bearing_deg)
	return Vector2(sin(a), -cos(a))


# --- Hoogte ----------------------------------------------------------------------------------

func height(x: float, z: float, o: float) -> float:
	var k := Landform.fade_in(o)
	if k <= 0.0:
		return 0.0
	var p := Vector2(x, z)
	_fields(x, z)
	var u := _f_u
	var wd := _f_wd
	var h := _cliff_height(u, p)
	# De bedding snijdt een kloof in het plateau en een geul door de badlands.
	var canyon := 1.0 - smoothstep(0.0, 34.0, wd)
	if h > 0.0 and canyon > 0.0:
		h *= 1.0 - 0.9 * canyon * smoothstep(-TALUS_W, 20.0, u)
	h = maxf(h, _f_bh)
	h += _f_amp * _f_v
	h -= WASH_DEPTH * (1.0 - smoothstep(0.0, 16.0, wd)) * (1.0 - smoothstep(0.0, 30.0, u))
	return k * h


## De droge bedding loopt schuin door het speelgebied (zelfde profiel als in height).
func near_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	return -WASH_DEPTH * (1.0 - smoothstep(0.0, 16.0, _wash_d(p))) * (1.0 - smoothstep(0.0, 30.0, _cliff_u(p)))


func has_near() -> bool:
	return true


## Wat height en tint allebei nodig hebben, één keer per punt, in _f_*: u (klif), afstand tot de
## bedding, hoogte van de badlands hier, de badlandruis, en de hoogte van een butte of restmesa.
## Zonder iets aan te maken: een nieuw object of array kost op de werkthread tijdens het laden van een
## wereld 100+ µs (gemeten; de voxelthreads vragen tegelijk geheugen). Daarom een vaste tabel als
## geheugen (height en tint vragen dezelfde hoekpunten, in dezelfde volgorde).
## Let op: de tabel en _f_* zijn gedeelde toestand. Eén thread tegelijk (de werkthread van
## PlanetSurface tijdens het bouwen, daarna mag de hoofdthread), nooit twee tegelijk.
func _fields(x: float, z: float) -> void:
	if not _ras_ready:
		_build_rasters()
	var q := Vector2(x, z) # 32 bit, zoals de hoekpunten die tint krijgt
	var slot := ((int(q.x * 4.0) * 73856093) ^ (int(q.y * 4.0) * 19349663)) & (CACHE_N - 1)
	if _ck[slot * 2] == q.x and _ck[slot * 2 + 1] == q.y:
		var c := slot * 5
		_f_u = _cv[c]
		_f_wd = _cv[c + 1]
		_f_amp = _cv[c + 2]
		_f_v = _cv[c + 3]
		_f_bh = _cv[c + 4]
		return
	_f_u = _cliff_u(q)
	if q.distance_to(landing) > BAD_FADE.y + 50.0:
		_f_wd = 1e6 # ver weg: enkel het plateau
		_f_amp = 0.0
		_f_v = 0.0
		_f_bh = 0.0
	else:
		_f_wd = _wash_d(q)
		_f_amp = _bad_amp(q, _f_u, _f_wd)
		_f_v = _bad_v(q) if _f_amp > 0.05 else 0.0
		_f_bh = _buttes(q)
	_ck[slot * 2] = q.x
	_ck[slot * 2 + 1] = q.y
	var c := slot * 5
	_cv[c] = _f_u
	_cv[c + 1] = _f_wd
	_cv[c + 2] = _f_amp
	_cv[c + 3] = _f_v
	_cv[c + 4] = _f_bh


## De gewone heuvels: rustig op de bodem (het skelet en de kamp moeten leesbaar blijven), iets
## meer in de badlands, ver weg weer volop (silhouetten aan de kim).
func hills_factor(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.distance_to(landing)
	return lerpf(0.3, 1.0, smoothstep(700.0, 1500.0, d))


## m binnen de rand van het plateau (0 = voet van de wand, negatief = ervoor).
func _cliff_u(p: Vector2) -> float:
	var rel := p - cliff_c
	var f := (atan2(rel.y, rel.x) * cliff_r - _edge_x0) / EDGE_STEP
	var i := clampi(int(f), 0, _edge_a.size() - 2)
	var t := f - i
	var off := 42.0 * lerpf(_edge_a[i], _edge_a[i + 1], t)
	off -= 80.0 * smoothstep(0.38, 0.72, lerpf(_edge_b[i], _edge_b[i + 1], t)) # kloven in de wand
	return cliff_r + minf(off, 18.0) - rel.length()


## Profiel van de klif: puinhelling, drie treden (harde lagen steil, zachte lagen schuin; de
## bovenste, de kaprots, het steilst), en een licht golvend plateau.
func _cliff_height(u: float, p: Vector2) -> float:
	if u <= -TALUS_W:
		return 0.0
	var foot := cliff_h * 0.12
	if u <= 0.0:
		var t := (u + TALUS_W) / TALUS_W
		return foot * t * t
	if u <= wall_w:
		var t := u / wall_w
		var s := t * 3.0
		var f := s - floorf(s)
		var stepped := (floorf(s) + smoothstep(0.2, 0.7 if s < 2.0 else 0.5, f)) / 3.0
		return lerpf(foot, cliff_h, lerpf(t, stepped, 0.75))
	return cliff_h + 2.5 * (sin(p.x * 0.011 + 1.3) * sin(p.y * 0.0137 + 0.4) + sin(p.x * 0.0041 - p.y * 0.0053)) - 6.0 * smoothstep(wall_w, wall_w + 400.0, u)


func _buttes(p: Vector2) -> float:
	var ids: Variant = _butte_grid.get(Vector2i(int(floor(p.x / BUTTE_CELL)), int(floor(p.y / BUTTE_CELL))))
	if ids == null:
		return 0.0
	var h := 0.0
	for i: int in ids:
		var b := buttes[i]
		var rel := Vector2(p.x - b.x, p.y - b.y)
		var dd := rel.length()
		if dd > b.z * 1.7:
			continue
		var ang := atan2(rel.y, rel.x)
		var rr := b.z * (1.0 + 0.12 * sin(3.0 * ang + b.x) + 0.08 * sin(5.0 * ang + b.y) + 0.05 * sin(9.0 * ang + b.w))
		var t := dd / rr
		var hb: float
		if t < 0.8:
			hb = b.w
		elif t < 1.0:
			# Twee treden in de wand.
			var s := (1.0 - t) / 0.2
			hb = b.w * lerpf(0.16, 1.0, lerpf(s, (floorf(s * 2.0) + smoothstep(0.3, 0.8, fmod(s * 2.0, 1.0))) / 2.0, 0.7))
		else:
			hb = b.w * 0.16 * (1.0 - smoothstep(1.0, 1.6, t))
		h = maxf(h, hb)
	return h


## Signed afstand tot de droge bedding (negatief = op de bodem van de bedding).
func _wash_d(p: Vector2) -> float:
	var ids: Variant = _wash_grid.get(Vector2i(int(floor(p.x / WASH_CELL)), int(floor(p.y / WASH_CELL))))
	if ids == null:
		return WASH_REACH
	var best := INF
	for i: int in ids:
		var a := wash[i]
		var ab := wash[i + 1] - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_squared_to(a + ab * t))
	return minf(sqrt(best) - WASH_HALF, WASH_REACH)


## Signed afstand tot de vlakke kalkbodem (rond de landingsplek, onder het skelet en de tweede
## ribbenkast): negatief = op de bodem.
func _floor_d(p: Vector2) -> float:
	var rel := p - landing
	var fa := (atan2(rel.y, rel.x) + PI) / TAU * FLOOR_STEPS
	var ia := clampi(int(fa), 0, FLOOR_STEPS)
	var r := floor_r + 40.0 * lerpf(_floor_t[ia], _floor_t[ia + 1], fa - ia)
	var d := rel.length() - r
	# Het skelet ligt op een vlakte die tot tegen de puinhelling loopt.
	var a := giant_c + giant_dir * (RIB_HALF + NECK_L + 34.0)
	var b := giant_c - giant_dir * (RIB_HALF + TAIL_L * 0.7)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	d = minf(d, p.distance_to(a + ab * t) - 42.0)
	d = minf(d, p.distance_to(ribs2_c) - 26.0)
	return d


## Hoe hoog de badlands hier mogen (m): niets op de bodem en in de bedding, hoger naar de klif toe,
## niets op het plateau, uitdovend naar de kim.
func _bad_amp(p: Vector2, u: float, wd: float) -> float:
	if u > 0.0:
		return 0.0
	var fd := _floor_d(p)
	if fd <= 0.0:
		return 0.0
	var a := BAD_AMP * smoothstep(0.0, 75.0, fd) * smoothstep(-6.0, 26.0, wd)
	a *= 1.0 + 0.4 * smoothstep(-320.0, -110.0, u) # hoger naar de voet van de klif
	a *= 1.0 - smoothstep(-TALUS_W - 10.0, -8.0, u) # op de puinhelling geen ruggen meer
	a *= 1.0 - smoothstep(BAD_FADE.x, BAD_FADE.y, p.distance_to(landing))
	# Rustige vlaktes tussen de badlands (30–40% van het beeld), niet overal hetzelfde behangpapier.
	a *= lerpf(0.12, 1.15, smoothstep(-0.3, 0.25, _ras(_macro_o, _macro_n, MACRO_STEP, p.x, p.y)))
	return a


## 0 op de bodem van de geulen, 1 op de scherpe kammen (ridged ruis: scherpe ruggen, brede
## geulen waar de mist in blijft hangen).
func _bad_v(p: Vector2) -> float:
	var wx := _ras(_wx_o, _warp_n, WARP_STEP, p.x, p.y) * 34.0
	var wz := _ras(_wz_o, _warp_n, WARP_STEP, p.x, p.y) * 34.0
	var r := clampf(_ras(_bad_o, _bad_n, BAD_STEP, p.x + wx, p.y + wz) * 0.6 + 0.45, 0.0, 1.0)
	return r * r * sqrt(r) # scherpe kammen, brede geulen


## De 2D-ruis in bulk (één oproep per raster, in C++), rond de landingsplek. Op de werkthread, bij
## de eerste vraag naar de badlands.
func _build_rasters() -> void:
	_r_origin = landing - Vector2(RAS_REACH, RAS_REACH)
	_ras_all = PackedByteArray()
	var a := _raster(_bad, BAD_STEP, Vector2.ZERO)
	_bad_o = _ras_all.size()
	_bad_n = a[1]
	_ras_all.append_array(a[0])
	a = _raster(_warp, WARP_STEP, Vector2.ZERO)
	_wx_o = _ras_all.size()
	_warp_n = a[1]
	_ras_all.append_array(a[0])
	a = _raster(_warp, WARP_STEP, Vector2(731.0, -419.0))
	_wz_o = _ras_all.size()
	_ras_all.append_array(a[0])
	a = _raster(_macro, MACRO_STEP, Vector2.ZERO)
	_macro_o = _ras_all.size()
	_macro_n = a[1]
	_ras_all.append_array(a[0])
	_ck = PackedFloat32Array()
	_ck.resize(CACHE_N * 2)
	_ck.fill(INF)
	_cv = PackedFloat32Array()
	_cv.resize(CACHE_N * 5)
	_ras_ready = true


## Raster van een ruis met een pixel per `step` m, vanaf _r_origin (+ shift): [PackedByteArray, n].
## Waarde −1..1 als 0..255 (get_image zonder normaliseren).
func _raster(noise: FastNoiseLite, step: float, shift: Vector2) -> Array:
	var n := int(ceil(RAS_REACH * 2.0 / step)) + 2
	var dup := noise.duplicate() as FastNoiseLite
	dup.frequency = noise.frequency * step
	dup.offset = Vector3((_r_origin.x + shift.x) / step, (_r_origin.y + shift.y) / step, 0.0)
	var img := dup.get_image(n, n, false, false, false)
	if img.get_format() != Image.FORMAT_L8:
		img.convert(Image.FORMAT_L8)
	return [img.get_data(), n]


## Bilineair uit een raster (enkel rekenen en array-toegang: snel op de werkthread). −1..1.
func _ras(base: int, n: int, step: float, x: float, z: float) -> float:
	var fx := (x - _r_origin.x) / step
	var fz := (z - _r_origin.y) / step
	var ix := clampi(int(fx), 0, n - 2)
	var iz := clampi(int(fz), 0, n - 2)
	var tx := clampf(fx - ix, 0.0, 1.0)
	var tz := clampf(fz - iz, 0.0, 1.0)
	var i := base + iz * n + ix
	var top := lerpf(_ras_all[i], _ras_all[i + 1], tx)
	var bottom := lerpf(_ras_all[i + n], _ras_all[i + n + 1], tx)
	return lerpf(top, bottom, tz) * (2.0 / 255.0) - 1.0


# --- Kleur -----------------------------------------------------------------------------------

## rgb maal de rotskleur (1 = neutraal, tot 2), a = lagen in steile wanden. Ook in het speelgebied
## (PlanetSurface bakt ze voor het voxelterrein): de bedding loopt erdoor.
func tint(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	_fields(x, z)
	var u := _f_u
	var wd := _f_wd
	var c := Color(1.0, 1.0, 1.0, 0.0) # kalkbodem: rustig, zoals het speelgebied
	# Badlands: warm okerstof in de geulen, witte kalk op de kammen, lagen op de hellingen.
	var amp := _f_amp
	if amp > 0.05:
		var v := clampf(_f_v / 0.6, 0.0, 1.0)
		var w := smoothstep(0.5, 8.0, amp)
		# Lagen op hoogte (zoals in de Painted Hills): van boven lees je elke rug als gestreepte
		# heuvel. Zacht (sinus), want de vertexkleur ligt maar om de 7,8 m.
		var hb := amp * _f_v
		var band := 0.5 + 0.5 * sin(hb * TAU / 8.5 + float(_seed % 5))
		var clay := smoothstep(0.82, 0.95, fposmod(hb / 23.0 + 0.3, 1.0)) # af en toe een grijsblauwe kleilaag
		var lit := Color(lerpf(1.15, 0.95, band), lerpf(1.12, 0.84, band), lerpf(1.05, 0.66, band))
		lit = Color(lerpf(lit.r, 0.86, clay), lerpf(lit.g, 0.9, clay), lerpf(lit.b, 0.94, clay))
		var low := Color(0.8, 0.68, 0.55) # okerstof op de bodem van de geulen
		var cc := Color(lerpf(low.r, lit.r, smoothstep(0.0, 0.25, v)), lerpf(low.g, lit.g, smoothstep(0.0, 0.25, v)), lerpf(low.b, lit.b, smoothstep(0.0, 0.25, v)))
		c = Color(lerpf(1.0, cc.r, w), lerpf(1.0, cc.g, w), lerpf(1.0, cc.b, w), 0.8 * w)
	# De bedding: grijsblauwe klei (koeler, donkerder): van boven een lijn door het beeld.
	var bed := (1.0 - smoothstep(-4.0, 12.0, wd)) * (1.0 - smoothstep(0.0, 30.0, u))
	c = Color(lerpf(c.r, 0.74, bed), lerpf(c.g, 0.77, bed), lerpf(c.b, 0.8, bed), c.a * (1.0 - bed))
	# Klif: puin (warmer, donkerder), de wand vol lagen, het plateau licht.
	if u > -TALUS_W - 20.0:
		var talus := smoothstep(-TALUS_W - 20.0, -TALUS_W + 15.0, u) * (1.0 - smoothstep(0.0, 8.0, u))
		c = Color(lerpf(c.r, 0.92, talus), lerpf(c.g, 0.86, talus), lerpf(c.b, 0.8, talus), maxf(c.a, talus * 0.35))
		var wall := smoothstep(-4.0, 6.0, u) * (1.0 - smoothstep(wall_w - 4.0, wall_w + 8.0, u))
		c = Color(lerpf(c.r, 1.06, wall), lerpf(c.g, 1.04, wall), lerpf(c.b, 1.0, wall), maxf(c.a, wall))
		var top := smoothstep(wall_w - 4.0, wall_w + 30.0, u)
		c = Color(lerpf(c.r, 1.1, top), lerpf(c.g, 1.07, top), lerpf(c.b, 1.02, top), c.a * (1.0 - top))
	# Buttes en restmesa's: wanden met lagen.
	if _f_bh > 1.0:
		c.a = 1.0
	# Rond het skelet: donkerder, losgewoeld sediment (de opgraving).
	var gd := _giant_d(p)
	if gd < 34.0:
		var e := (1.0 - smoothstep(8.0, 34.0, gd)) * 0.7
		c = Color(lerpf(c.r, 0.86, e), lerpf(c.g, 0.79, e), lerpf(c.b, 0.72, e), c.a)
	return c


## Lagen in de klif en de badlands (rotsshader van het verre landschap; werkt zodra de lead
## Landform.shader_params aansluit, zie het rapport van 2026-10-04): dunnere lagen, vooral kalk, wat
## oker, dunne grijsblauwe kleilijnen, ook op de minder steile hellingen van de badlands, en één
## roestige ijzerband op ±60% van de klif.
func shader_params(surface_y: float) -> Dictionary:
	return {"strata_scale": 9.0, "strata_cuts": Vector2(0.58, 0.9), "strata_strength": 0.75,
			"strata_steep": Vector2(0.72, 0.94), "strata_key": Vector3(surface_y + cliff_h * 0.6, 5.5, 0.9)}


## Afstand tot de rug van het reuzenskelet (benaderd als lijnstuk).
func _giant_d(p: Vector2) -> float:
	var a := giant_c + giant_dir * (RIB_HALF + NECK_L + 30.0)
	var b := giant_c - giant_dir * (RIB_HALF + TAIL_L * 0.6)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Rotsblokken -----------------------------------------------------------------------------

## Veel groot puin onder de klif, weinig op de bodem (een opgraving wordt opgeruimd), wat in de
## badlands en op het plateau.
func rock_density(p: Vector2) -> float:
	var u := _cliff_u(p)
	var talus := smoothstep(-TALUS_W - 45.0, -TALUS_W + 5.0, u) * (1.0 - smoothstep(4.0, 22.0, u))
	if talus > 0.01:
		return 0.15 + 0.9 * talus
	if u > 0.0:
		return 0.12
	if _floor_d(p) < 0.0:
		return 0.06
	return 0.2


func rock_scale(p: Vector2) -> float:
	var u := _cliff_u(p)
	var talus := smoothstep(-TALUS_W - 45.0, -TALUS_W + 5.0, u) * (1.0 - smoothstep(4.0, 22.0, u))
	return lerpf(1.0, 2.4, talus)


# --- Eigen dingen (werkthread) ---------------------------------------------------------------

func compute_props(s: PlanetSurface) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var bones := FossielBones.new(_seed + 11)
	_build_giant(bones, s)
	_build_ribs2(bones, s)
	var frags := _build_fragments(s)
	var hoodoos := _build_hoodoos(s)
	var camp := _build_camp(s)
	var mist := _build_mist(s)
	var out := {"fossil_bones": bones.arrays(), "fossil_frags": frags, "fossil_camp": camp, "fossil_mist": mist,
			"fossil_hoodoos": hoodoos.arrays()}
	var frag_tris := 0
	for k: Dictionary in frags.kinds:
		frag_tris += (k.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3 * (k.xf as Array).size()
	var camp_tris := 0
	for key: String in ["yellow", "wood", "dark"]:
		camp_tris += (camp[key][Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	print("[fossiel] driehoeken: skelet %d, fragmenten %d (%d stuks), hoodoos %d, kamp %d, mist %d; %.0f ms" % [
		bones.triangle_count(), frag_tris, frags.get("count", 0), hoodoos.triangle_count(), camp_tris,
		(mist.idx as PackedInt32Array).size() / 3, (Time.get_ticks_usec() - t0) / 1000.0])
	return out


## Hoogte van de rug boven de grond langs het skelet (u = m langs de rug, + = naar de kop).
func _giant_h(u: float) -> float:
	if absf(u) <= RIB_HALF:
		var q := u / (RIB_HALF * 1.08)
		return 5.0 + 21.0 * sqrt(maxf(1.0 - q * q, 0.0))
	if u > RIB_HALF:
		var t := (u - RIB_HALF) / NECK_L
		return lerpf(_giant_h(RIB_HALF), 4.2, smoothstep(0.0, 1.0, t))
	var t := (-u - RIB_HALF) / TAIL_L
	return lerpf(_giant_h(-RIB_HALF), -2.2, smoothstep(0.0, 0.75, t))


## Zijwaartse slinger van de rug (m).
func _giant_lat(u: float) -> float:
	var tail := smoothstep(-RIB_HALF, -RIB_HALF - TAIL_L, u)
	return 4.0 * sin(u * 0.03 + float(_seed % 7)) + 14.0 * tail * tail


func _giant_r(u: float) -> float:
	if absf(u) <= RIB_HALF:
		return 2.4
	if u > RIB_HALF:
		return lerpf(2.2, 1.75, (u - RIB_HALF) / NECK_L)
	return lerpf(2.2, 0.5, clampf((-u - RIB_HALF) / TAIL_L, 0.0, 1.0))


func _giant_spike(u: float) -> float:
	if absf(u) <= RIB_HALF:
		return 5.0 + 4.0 * (1.0 - absf(u) / RIB_HALF)
	if u > RIB_HALF:
		return 2.2
	return lerpf(3.4, 0.4, clampf((-u - RIB_HALF) / TAIL_L, 0.0, 1.0))


func _giant_at(u: float, s: PlanetSurface) -> Vector3:
	var side := giant_dir.orthogonal()
	var q := giant_c + giant_dir * u + side * _giant_lat(u)
	var g := s.far_height(q.x, q.y)
	return Vector3(q.x, g + _giant_h(u), q.y)


func _build_giant(b: FossielBones, s: PlanetSurface) -> void:
	var side2 := giant_dir.orthogonal()
	var side := Vector3(side2.x, 0.0, side2.y)
	var u_neck := RIB_HALF + NECK_L
	var u_tail := -(RIB_HALF + TAIL_L)
	# Wervels van de nek naar de staart.
	var us := PackedFloat32Array()
	var u := u_neck
	while u > u_tail:
		us.append(u)
		u -= 4.2 if u > -RIB_HALF else lerpf(3.4, 1.7, clampf((-u - RIB_HALF) / TAIL_L, 0.0, 1.0))
	var pos := PackedVector3Array()
	var grounds := PackedFloat32Array()
	for uu in us:
		var p := _giant_at(uu, s)
		pos.append(p)
		grounds.append(p.y - _giant_h(uu))
	var rib_i := 0
	for i in us.size():
		var uu := us[i]
		var r := _giant_r(uu)
		var p := pos[i]
		if p.y + r + _giant_spike(uu) < grounds[i] - 0.2:
			continue # helemaal begraven
		var t := (pos[maxi(i - 1, 0)] - pos[mini(i + 1, us.size() - 1)]).normalized()
		b.vertebra(p, t, Vector3.UP, r, _giant_spike(uu), grounds[i], 0.35)
		# Ribben op elke tweede wervel in de ribbenkast.
		if absf(uu) > RIB_HALF * 0.97:
			continue
		rib_i += 1
		if rib_i % 2 == 0:
			continue
		var hgt := p.y - grounds[i]
		var reach := 0.68 * hgt + 11.0
		for sgn: float in [-1.0, 1.0]:
			if b.rng.randf() < 0.08:
				continue
			var p0 := p + side * sgn * r * 0.55
			var g2 := Vector2(p.x, p.z) + side2 * sgn * reach - giant_dir * 4.5
			var gy := s.far_height(g2.x, g2.y)
			var p3 := Vector3(g2.x, gy - 1.6, g2.y)
			var p1 := p0 + side * sgn * reach * 0.5 + Vector3.UP * 3.4
			var p2 := p3 + side * sgn * reach * 0.1 + Vector3.UP * (hgt * 0.62)
			var pts := FossielBones.bezier(p0, p1, p2, p3, 9)
			var gr := PackedFloat32Array()
			for k in pts.size():
				gr.append(lerpf(grounds[i], gy, float(k) / (pts.size() - 1)))
			var keep := pts.size()
			if b.rng.randf() < 0.22:
				keep = b.rng.randi_range(5, 8) # afgebroken
			pts.resize(keep)
			gr.resize(keep)
			b.tube(pts, b.taper(keep, 2.0, lerpf(2.0, 0.9, float(keep - 1) / 9.0)), t, 6, 0.5, 0.12, 0.4, gr)
	# De schedel, aan het eind van de nek, op de grond.
	var n_end := pos[0]
	var hd2 := giant_dir.rotated(deg_to_rad(-18.0)) # kop iets naar de landingsplek gedraaid
	var fwd := Vector3(hd2.x, 0.0, hd2.y).rotated(Vector3(hd2.y, 0.0, -hd2.x).normalized(), deg_to_rad(-3.0))
	var basis := Basis(fwd, Vector3.UP.rotated(fwd, deg_to_rad(14.0)), Vector3.ZERO)
	basis.z = basis.x.cross(basis.y).normalized()
	basis.y = basis.z.cross(basis.x).normalized()
	basis = basis.scaled(Vector3.ONE * SKULL_S)
	var origin := n_end - basis * Vector3(-1.5, 5.0, 0.0)
	_build_skull(b, Transform3D(basis, origin), grounds[0])


## Schedel (lokaal: x = naar de snuit, y = op, z = opzij; 0 = achterkant), ±31 m lang maal de schaal
## van `xf`.
func _build_skull(b: FossielBones, xf: Transform3D, gy: float) -> void:
	var k := xf.basis.x.length()
	var cranium: Array[Vector4] = [Vector4(-1.5, 5.0, 3.0, 3.4), Vector4(1.5, 5.8, 4.4, 5.0), Vector4(5.0, 6.2, 4.4, 5.3),
			Vector4(8.5, 6.1, 3.7, 4.7), Vector4(10.5, 5.8, 3.0, 4.0)]
	b.loft(xf, cranium, 8, gy, 0.3)
	var snout: Array[Vector4] = [Vector4(16.8, 5.4, 2.9, 3.6), Vector4(20.5, 5.0, 2.6, 3.0), Vector4(24.5, 4.3, 2.1, 2.3),
			Vector4(28.0, 3.6, 1.6, 1.5), Vector4(30.8, 3.0, 1.0, 0.8)]
	b.loft(xf, snout, 7, gy, 0.35)
	var lat := xf.basis.z
	var upl := xf.basis.y
	for sgn: float in [-1.0, 1.0]:
		var z := sgn
		_bar(b, xf, [Vector3(9.0, 8.4, 3.0 * z), Vector3(13.5, 9.3, 3.4 * z), Vector3(17.5, 7.6, 2.7 * z)], 1.05 * k, upl, gy)
		_bar(b, xf, [Vector3(9.0, 2.8, 4.2 * z), Vector3(13.5, 2.3, 4.4 * z), Vector3(18.0, 3.0, 3.5 * z)], 1.15 * k, upl, gy)
		_bar(b, xf, [Vector3(10.4, 8.6, 3.5 * z), Vector3(11.1, 5.6, 4.1 * z), Vector3(10.4, 2.8, 4.3 * z)], 0.85 * k, lat, gy)
		_bar(b, xf, [Vector3(17.4, 7.5, 2.8 * z), Vector3(17.1, 5.2, 3.4 * z), Vector3(17.5, 3.1, 3.5 * z)], 0.8 * k, lat, gy)
		# Hoorns boven de oogkas.
		b.cone(xf * Vector3(12.0, 9.0, 3.0 * z), xf * Vector3(15.8, 13.8, 5.8 * z), 1.05 * k, xf.basis.x, gy, 0.5)
		# Onderkaak (open, half begraven): scharnier achteraan, kin vooraan.
		var hinge := Vector3(1.0, 1.8, 4.2 * z)
		var jaw := [hinge, Vector3(9.0, 0.9, 4.3 * z), Vector3(18.0, 0.1, 3.4 * z), Vector3(26.0, -0.4, 1.9 * z), Vector3(29.0, -0.5, 0.9 * z)]
		var open := Basis(Vector3(0, 0, 1), deg_to_rad(-12.0))
		var jaw_pts: Array = []
		for jp: Vector3 in jaw:
			jaw_pts.append(hinge + open * (jp - hinge))
		_bar(b, xf, jaw_pts, 1.25 * k, upl, gy, 0.55)
		# Tanden: boven naar beneden, onder naar boven.
		for i in 7:
			var tx := lerpf(18.5, 29.5, float(i) / 6.0)
			var sec := _sec_at(snout, tx)
			var base := Vector3(tx, sec.y - sec.z * 0.62, sec.w * 0.78 * z)
			var ln := b.rng.randf_range(1.4, 2.5)
			b.cone(xf * (base + Vector3(0.0, 0.4, 0.0)), xf * (base + Vector3(0.35, -ln, 0.0)), 0.45 * k, xf.basis.x, gy, 0.55)
		for i in 6:
			var f := float(i) / 5.0
			var jp := (hinge + open * (Vector3(lerpf(15.0, 27.0, f), lerpf(0.3, -0.45, f), lerpf(3.7, 1.7, f) * z) - hinge))
			var ln := b.rng.randf_range(1.2, 2.1)
			b.cone(xf * (jp + Vector3(0.0, 0.6, 0.0)), xf * (jp + Vector3(-0.3, 0.6 + ln, 0.0)), 0.42 * k, xf.basis.x, gy, 0.55)
	# Kam naar achteren (alien), plat als een blad.
	var crest: Array = [Vector3(4.0, 9.4, 0.0), Vector3(-2.0, 12.0, 0.0), Vector3(-8.0, 14.4, 0.0), Vector3(-13.5, 15.4, 0.0)]
	var pts := PackedVector3Array()
	for c: Vector3 in crest:
		pts.append(xf * c)
	b.tube(pts, PackedFloat32Array([2.0 * k, 1.6 * k, 1.0 * k, 0.25 * k]), upl, 6, 0.4, 0.1, 0.4, PackedFloat32Array([gy, gy, gy, gy]))


## Doorsnede van een loft op lengte x (lineair tussen de doorsneden).
static func _sec_at(secs: Array[Vector4], x: float) -> Vector4:
	for i in secs.size() - 1:
		if x <= secs[i + 1].x:
			var t := clampf((x - secs[i].x) / (secs[i + 1].x - secs[i].x), 0.0, 1.0)
			return secs[i].lerp(secs[i + 1], t)
	return secs[secs.size() - 1]


## Staaf door lokale punten (in de ruimte van `xf`), plat dwars op `up`.
func _bar(b: FossielBones, xf: Transform3D, local_pts: Array, r: float, up: Vector3, gy: float, flat := 0.7) -> void:
	var pts := PackedVector3Array()
	var g := PackedFloat32Array()
	for lp: Vector3 in local_pts:
		pts.append(xf * lp)
		g.append(gy)
	b.tube(pts, b.taper(pts.size(), r, r * 0.8), up, 6, flat, 0.1, 0.35, g)


## Tweede ribbenkast: half begraven, enkel ribben die als slagtanden uit de grond komen, en een
## paar wervelbulten. Van op de grond een silhouet linksachter.
func _build_ribs2(b: FossielBones, s: PlanetSurface) -> void:
	var side2 := ribs2_dir.orthogonal()
	var side := Vector3(side2.x, 0.0, side2.y)
	var axis := Vector3(ribs2_dir.x, 0.0, ribs2_dir.y)
	for i in 8:
		var along := (float(i) - 3.5) * 7.5
		var q := ribs2_c + ribs2_dir * along
		var gy := s.far_height(q.x, q.y)
		var lnf := 1.0 - absf(float(i) - 3.5) / 5.0
		var ln := (17.0 + 9.0 * lnf) * b.rng.randf_range(0.8, 1.12)
		var p0 := Vector3(q.x, gy - 1.5, q.y)
		var p3 := p0 + side * ln * 0.7 + Vector3.UP * ln * 0.55 + axis * b.rng.randf_range(-1.5, 1.5)
		var p1 := p0 + Vector3.UP * ln * 0.55
		var p2 := p3 - side * ln * 0.12 + Vector3.UP * ln * 0.2
		var pts := FossielBones.bezier(p0, p1, p2, p3, 8)
		var keep := pts.size() if b.rng.randf() > 0.3 else b.rng.randi_range(5, 7)
		pts.resize(keep)
		var gr := PackedFloat32Array()
		gr.resize(keep)
		gr.fill(gy)
		b.tube(pts, b.taper(keep, 1.6, 0.6), axis, 6, 0.55, 0.12, 0.4, gr)
		if i % 2 == 0:
			b.vertebra(Vector3(q.x, gy - 0.5, q.y) - side * 2.0, axis, Vector3.UP, 1.7, 2.2, gy)


## Botfragmenten in groepjes (MultiMesh per soort): een stuk rib, een wervel, een pijpbeen, een
## splinter. Meer langs het skelet en de bedding, nooit in het speelgebied.
func _build_fragments(s: PlanetSurface) -> Dictionary:
	var kinds: Array = []
	for k in 4:
		var fb := FossielBones.new(_seed + 100 + k)
		match k:
			0: # gebogen stuk rib, lengte ±1
				var pts := FossielBones.bezier(Vector3(0, -0.15, 0), Vector3(0.05, 0.35, 0), Vector3(0.3, 0.75, 0), Vector3(0.62, 0.85, 0), 6)
				fb.tube(pts, fb.taper(7, 0.11, 0.06), Vector3(0, 0, 1), 6, 0.55, 0.12, 0.4, _flat_ground(7))
			1: # wervel met doorn
				fb.vertebra(Vector3(0, 0.15, 0), Vector3(1, 0, 0), Vector3.UP, 0.22, 0.45, 0.0)
			2: # pijpbeen met knobbels
				var pts := PackedVector3Array([Vector3(-0.5, 0.05, 0), Vector3(-0.42, 0.08, 0), Vector3(0.0, 0.1, 0), Vector3(0.42, 0.12, 0), Vector3(0.5, 0.1, 0)])
				fb.tube(pts, PackedFloat32Array([0.13, 0.15, 0.08, 0.15, 0.12]), Vector3.UP, 6, 1.0, 0.14, 0.35, _flat_ground(5))
			_: # splinter / hoorn
				fb.cone(Vector3(0, -0.1, 0), Vector3(0.25, 0.9, 0.1), 0.14, Vector3(0, 0, 1), 0.0, 0.45)
		kinds.append({"arrays": fb.arrays(), "xf": []})
	var rng := RandomNumberGenerator.new()
	var count := 0
	var cell := 90.0
	var reach := 720.0
	var c0x := int(floor((landing.x - reach) / cell))
	var c1x := int(floor((landing.x + reach) / cell))
	var c0z := int(floor((landing.y - reach) / cell))
	var c1z := int(floor((landing.y + reach) / cell))
	var centers: Array[Vector3] = [] # x, z, aantal
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var crng := s._cell_rng(cx, cz, 41)
			var p := Vector2((cx + crng.randf()) * cell, (cz + crng.randf()) * cell)
			if p.distance_to(landing) > reach or _cliff_u(p) > -10.0:
				continue
			if crng.randf() > 0.4:
				continue
			centers.append(Vector3(p.x, p.y, crng.randi_range(2, 5)))
	# Rond het reuzenskelet: afgebroken stukken.
	rng.seed = _seed + 77
	for i in 7:
		var u := rng.randf_range(-RIB_HALF - TAIL_L * 0.5, RIB_HALF + NECK_L)
		var q := giant_c + giant_dir * u + giant_dir.orthogonal() * rng.randf_range(-30.0, 30.0)
		centers.append(Vector3(q.x, q.y, rng.randi_range(2, 4)))
	for ci in centers.size():
		var cc := centers[ci]
		rng.seed = _seed * 31 + ci * 7919
		for j in int(cc.z):
			var x := cc.x + rng.randf_range(-12.0, 12.0)
			var z := cc.y + rng.randf_range(-12.0, 12.0)
			var size := lerpf(2.0, 7.0, pow(rng.randf(), 1.8))
			if s.outside(x, z) < 8.0 + size:
				continue
			var kind := rng.randi_range(0, 3)
			var y := s.far_height(x, z) - size * rng.randf_range(0.15, 0.35)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))).scaled(Vector3.ONE * size)
			(kinds[kind].xf as Array).append(Transform3D(basis, Vector3(x, y, z)))
			count += 1
	return {"kinds": kinds, "count": count}


## Hoodoos: een slanke kalkzuil met banden en een donkere, bredere kaprots erop (Witte Woestijn,
## Dinosaur Provincial Park). r (vertexkleur) = 1 voor kalk, 0 voor de kaprots.
func _build_hoodoos(s: PlanetSurface) -> FossielBones:
	var b := FossielBones.new(_seed + 300)
	for site in hoodoo_sites:
		for k in int(site.z):
			var a := b.rng.randf() * TAU
			var q := Vector2(site.x, site.y) + Vector2(cos(a), sin(a)) * b.rng.randf_range(2.0, 16.0)
			if s.outside(q.x, q.y) < 12.0:
				continue
			var gy := s.far_height(q.x, q.y)
			var h := lerpf(4.0, 15.0, pow(b.rng.randf(), 1.3))
			var r0 := h * b.rng.randf_range(0.14, 0.2)
			var lean := Vector3(b.rng.randf_range(-0.06, 0.06), 0.0, b.rng.randf_range(-0.06, 0.06)) * h
			var base := Vector3(q.x, gy - 1.0, q.y)
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			var g := PackedFloat32Array()
			for i in 6:
				var t := float(i) / 5.0
				pts.append(base + Vector3.UP * (h * t + 1.0 * (1.0 - t)) + lean * t * t)
				# Breed aan de voet, een hals onder de kap (daar schuurt de wind het meest).
				radii.append(r0 * lerpf(1.25, 0.55, smoothstep(0.0, 0.85, t)) * (1.0 + b.rng.randf_range(-0.08, 0.08)))
				g.append(gy)
			b.tube(pts, radii, Vector3.RIGHT, 7, 1.0, 0.14, 1.0, g, false, false)
			var top := pts[5]
			var cap_r := r0 * b.rng.randf_range(1.3, 1.9)
			var th := cap_r * b.rng.randf_range(0.35, 0.55)
			var tilt := Basis.from_euler(Vector3(b.rng.randf_range(-0.12, 0.12), b.rng.randf() * TAU, b.rng.randf_range(-0.12, 0.12)))
			var cap: Array[Vector4] = [Vector4(-th * 0.5, 0.0, cap_r * 0.25, cap_r * 0.25), Vector4(-th * 0.35, 0.0, cap_r * 0.9, cap_r * 0.95),
					Vector4(th * 0.3, 0.0, cap_r, cap_r), Vector4(th * 0.55, 0.0, cap_r * 0.55, cap_r * 0.6)]
			# loft: x = de as van de kap (hier omhoog), y/z = doorsnede.
			var xf := Transform3D(tilt * Basis(Vector3.UP, Vector3.RIGHT, Vector3.FORWARD).orthonormalized(), top)
			b.loft(xf, cap, 7, gy, 0.0)
	return b


static func _flat_ground(n: int) -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(n)
	g.fill(0.0)
	return g


## De meetkamp: arrays per materiaal en de plek van het bord en het lampje.
func _build_camp(s: PlanetSurface) -> Dictionary:
	var yellow := FossielBones.new(_seed + 201)
	var wood := FossielBones.new(_seed + 202)
	var dark := FossielBones.new(_seed + 203)
	var fwd := camp_face
	var right := fwd.orthogonal() # zo is (right, op, fwd) rechtshandig: de tekst staat niet gespiegeld
	var at := func(f: float, r: float, up: float) -> Vector3:
		var q: Vector2 = camp_c + fwd * f + right * r
		return Vector3(q.x, s.far_height(q.x, q.y) + up, q.y)
	var basis := Basis(Vector3(right.x, 0, right.y), Vector3.UP, Vector3(fwd.x, 0, fwd.y))
	# Zeil op vier palen (geel: DIG), licht doorgezakt.
	var corners := [[-3.5, -2.5], [3.5, -2.5], [3.5, 2.5], [-3.5, 2.5]]
	var tops: Array[Vector3] = []
	for cr: Array in corners:
		var foot: Vector3 = at.call(cr[1], cr[0], 0.0)
		var top := foot + Vector3.UP * (2.8 if cr[1] > 0.0 else 2.3)
		wood.tube(PackedVector3Array([foot - Vector3.UP * 0.3, top]), PackedFloat32Array([0.07, 0.06]), Vector3(1, 0, 0), 4, 1.0, 0.0, 0.2)
		tops.append(top)
	var grid := 4
	var pts: Array = []
	for j in grid + 1:
		var row: Array = []
		for i in grid + 1:
			var fi := float(i) / grid
			var fj := float(j) / grid
			var a: Vector3 = tops[0].lerp(tops[1], fi)
			var b: Vector3 = tops[3].lerp(tops[2], fi)
			var p: Vector3 = a.lerp(b, fj)
			p.y -= 0.45 * sin(fi * PI) * sin(fj * PI)
			row.append(p)
		pts.append(row)
	for j in grid:
		for i in grid:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][i + 1]
			var c: Vector3 = pts[j + 1][i + 1]
			var d: Vector3 = pts[j + 1][i]
			for up_dir: Vector3 in [Vector3.UP, Vector3.DOWN]: # twee kanten
				yellow.tri(a, b, c, up_dir, 0.3, 0.0)
				yellow.tri(a, c, d, up_dir, 0.3, 0.0)
	# Kisten (geel en donker) in een groepje onder en naast het zeil.
	var crates := [[0.5, -1.5, 0.0, 0], [0.5, -0.2, 0.0, 1], [0.6, -0.8, 0.9, 0], [-1.2, 4.6, 0.0, 1], [-0.4, 5.6, 0.0, 0]]
	for cr: Array in crates:
		var c: Vector3 = at.call(cr[0], cr[1], 0.45 + cr[2])
		var bb := basis.rotated(Vector3.UP, b_rand(cr[0] * 3.1 + cr[1]) * 0.6)
		(yellow if cr[3] == 0 else dark).box(Transform3D(bb, c), Vector3(1.2, 0.9, 0.9))
	# Bord voor het zeil, naar de landingsplek gekeerd.
	var sign_c: Vector3 = at.call(5.5, 2.0, 0.0)
	for sx: float in [-1.6, 1.6]:
		var foot := sign_c + basis.x * sx
		wood.tube(PackedVector3Array([foot - Vector3.UP * 0.4, foot + Vector3.UP * 3.1]), PackedFloat32Array([0.09, 0.08]), Vector3(1, 0, 0), 4, 1.0, 0.0, 0.2)
	var board := Transform3D(basis, sign_c + Vector3.UP * 2.25)
	yellow.box(board, Vector3(3.8, 1.7, 0.1))
	# Afgedekte putten bij het skelet (gele zeilen plat op de grond), en de meetmast met een lampje.
	var cover_u := PackedFloat32Array([RIB_HALF + NECK_L + 6.0, RIB_HALF + 10.0, -RIB_HALF - 18.0])
	var cover_side := PackedFloat32Array([16.0, -24.0, 14.0])
	var cover_turn := PackedFloat32Array([0.2, -0.3, 0.5])
	var cover_size: Array[Vector3] = [Vector3(7.0, 0.12, 5.0), Vector3(6.0, 0.12, 4.0), Vector3(5.0, 0.12, 4.0)]
	for i in 3:
		var q := giant_c + giant_dir * cover_u[i] + giant_dir.orthogonal() * cover_side[i]
		var y := s.far_height(q.x, q.y) + 0.15
		var bb := Basis(Vector3.UP, atan2(giant_dir.x, giant_dir.y) + cover_turn[i])
		yellow.box(Transform3D(bb, Vector3(q.x, y, q.y)), cover_size[i])
	var mast: Vector3 = at.call(-3.0, -6.0, 0.0)
	dark.tube(PackedVector3Array([mast - Vector3.UP * 0.5, mast + Vector3.UP * 8.0]), PackedFloat32Array([0.12, 0.08]), Vector3(1, 0, 0), 5, 1.0, 0.0, 0.2)
	yellow.box(Transform3D(basis, mast + Vector3.UP * 7.2 + basis.x * 0.7), Vector3(1.3, 0.8, 0.04)) # vlag
	# Meetpalen met vlagjes in een lijn van de kamp naar de rand van het speelgebied.
	var to_land := (landing - camp_c).normalized()
	var k := 1
	while true:
		var q := camp_c + to_land * (14.0 + 13.0 * k)
		if s.outside(q.x, q.y) < 6.0 or k > 12:
			break
		var foot := Vector3(q.x, s.far_height(q.x, q.y), q.y)
		wood.tube(PackedVector3Array([foot - Vector3.UP * 0.3, foot + Vector3.UP * 2.0]), PackedFloat32Array([0.05, 0.04]), Vector3(1, 0, 0), 4, 1.0, 0.0, 0.2)
		yellow.box(Transform3D(basis, foot + Vector3.UP * 1.8 + basis.x * 0.25), Vector3(0.45, 0.3, 0.03))
		k += 1
	return {"yellow": yellow.arrays(), "wood": wood.arrays(), "dark": dark.arrays(), "sign": board,
			"lamp": mast + Vector3.UP * 8.3}


static func b_rand(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0


## Mist: een raster (24 m) een paar meter boven de geulbodem, enkel waar badlands of de bedding
## zijn. Waar geen mist hoort, ligt het onder de grond (de dieptetest verbergt het).
func _build_mist(s: PlanetSurface) -> Dictionary:
	var cell := 30.0
	var reach := 720.0
	var n := int(reach * 2.0 / cell) + 1
	var x0 := landing.x - reach
	var z0 := landing.y - reach
	# Eerst waar mist hoort (enkel de velden, goedkoop), dan de hoogte enkel daar en ernaast.
	var lvl := PackedFloat32Array()
	lvl.resize(n * n)
	var live := PackedByteArray()
	live.resize(n * n)
	for j in n:
		for i in n:
			var p := Vector2(x0 + i * cell, z0 + j * cell)
			lvl[j * n + i] = -3.0
			if p.distance_to(landing) > reach:
				continue
			var k := Landform.fade_in(s.outside(p.x, p.y))
			if k <= 0.0:
				continue
			_fields(p.x, p.y)
			var bed := (1.0 - smoothstep(0.0, 16.0, _f_wd)) * (1.0 - smoothstep(0.0, 30.0, _f_u))
			if _f_amp > 1.0 or bed > 0.5:
				# Aan de voet van de klif blijft meer mist hangen (warme stofzee onder de wand).
				var foot := smoothstep(-240.0, -130.0, _f_u) * (1.0 - smoothstep(-TALUS_W - 10.0, -TALUS_W + 20.0, _f_u))
				lvl[j * n + i] = maxf(_f_amp * 0.42 - 0.3 + 5.0 * foot, -WASH_DEPTH + 3.8 if bed > 0.5 else -3.0) * k
				live[j * n + i] = 1
	var need := PackedByteArray()
	need.resize(n * n)
	for j in n:
		for i in n:
			if live[j * n + i] == 0:
				continue
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var jj := j + dj
					var ii := i + di
					if jj >= 0 and jj < n and ii >= 0 and ii < n:
						need[jj * n + ii] = 1
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in n:
		for i in n:
			if need[j * n + i] == 0:
				continue
			var x := x0 + i * cell
			var z := z0 + j * cell
			var o := s.outside(x, z)
			# Basis = het landschap zonder de badlands (de mist volgt de geulbodem).
			var base := s.far_height(x, z) - height(x, z, o)
			verts[j * n + i] = Vector3(x, base - 0.6 + lvl[j * n + i], z)
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n + 1
			var d := a + n
			if live[a] + live[b] + live[c] + live[d] == 0:
				continue
			if (verts[b] - verts[a]).cross(verts[c] - verts[a]).y < 0.0:
				idx.append_array([a, b, c, a, c, d])
			else:
				idx.append_array([a, c, b, a, d, c])
	return {"verts": verts, "idx": idx}


# --- In de scène (hoofdthread) ---------------------------------------------------------------

func commit_props(root: Node3D, out: Dictionary) -> void:
	var bone_mat := ShaderMaterial.new()
	bone_mat.shader = BONE_SHADER
	if out.has("fossil_bones"):
		var mi := MeshInstance3D.new()
		mi.name = "GiantSkeleton"
		mi.mesh = FossielBones.mesh(out.fossil_bones)
		mi.material_override = bone_mat
		mi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M + 500.0
		root.add_child(mi)
	if out.has("fossil_frags"):
		var kinds: Array = out.fossil_frags.kinds
		for k in kinds.size():
			var xfs: Array = kinds[k].xf
			if xfs.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = FossielBones.mesh(kinds[k].arrays)
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "BoneFragments_%d" % k
			mmi.multimesh = mm
			mmi.material_override = bone_mat
			mmi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M
			root.add_child(mmi)
	if out.has("fossil_hoodoos"):
		var lime := ShaderMaterial.new()
		lime.shader = BONE_SHADER
		lime.set_shader_parameter("bone_dark", Color("8A7660")) # kaprots
		lime.set_shader_parameter("bone_gloss", Color("E2CFA8")) # kalk
		lime.set_shader_parameter("dust", Color("C9B48C"))
		lime.set_shader_parameter("top_dust", 0.1)
		var mi := MeshInstance3D.new()
		mi.name = "Hoodoos"
		mi.mesh = FossielBones.mesh(out.fossil_hoodoos)
		mi.material_override = lime
		mi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M
		root.add_child(mi)
	if out.has("fossil_camp"):
		_commit_camp(root, out.fossil_camp)
	if out.has("fossil_mist"):
		var verts: PackedVector3Array = out.fossil_mist.verts
		var idx: PackedInt32Array = out.fossil_mist.idx
		if idx.size() > 0:
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_INDEX] = idx
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mat := ShaderMaterial.new()
			mat.shader = MIST_SHADER
			var mi := MeshInstance3D.new()
			mi.name = "GullyMist"
			mi.mesh = m
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M
			root.add_child(mi)


func _commit_camp(root: Node3D, camp: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "SurveyCamp"
	root.add_child(node)
	for pair in [["yellow", "Yellow"], ["wood", "Wood"], ["dark", "Anthracite"]]:
		var mi := MeshInstance3D.new()
		mi.name = "Camp" + pair[1]
		mi.mesh = FossielBones.mesh(camp[pair[0]])
		mi.material_override = MolVisual.machine_material(pair[1], false, 3.0)
		mi.visibility_range_end = SurfaceDressing.ROCK_HIDE_M
		node.add_child(mi)
	var board: Transform3D = camp.sign
	var label := Label3D.new()
	label.name = "CampSign"
	label.text = "DIG SURVEY CAMP F-4\nFOSSILS ARE NOT SOUVENIRS.\nFOSSILS ARE INVENTORY."
	label.font = UiTheme.heading()
	label.font_size = 64
	label.pixel_size = 0.0042
	label.line_spacing = -4.0
	label.modulate = Color(0.08, 0.07, 0.06)
	label.outline_size = 0
	label.double_sided = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visibility_range_end = 400.0
	node.add_child(label)
	# Label3D kijkt naar +z: het bord kijkt naar de landingsplek (basis.z = camp_face).
	label.global_transform = Transform3D(board.basis, board.origin + board.basis.z * 0.07)
	SurfaceDressing.red_light(node, node.to_local(camp.lamp), BEACON, 1.6, 22.0)
