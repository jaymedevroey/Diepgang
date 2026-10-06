class_name PlanetGenerator
extends VoxelGeneratorScript
## Genereert een planeet (GDD v3 §4) in voxelruimte (1 voxel = TerrainAPI.VOXEL_SIZE m).
## SDF-conventie van godot_voxel: negatief = rots, positief = lucht.
## Draait op werkthreads: na setup() wordt enkel nog gelezen.
##
## Bovenaan een kale buitenaardse vlakte: golvende heuvels, kraters met een rand, groepjes
## gehakte rotsblokken (per planeet een eigen vorm), en in het midden een vlakke landingsplek voor
## de Mol. Daaronder grotten op elke diepte (een paar groot genoeg voor de Mol) met druipsteen,
## pilaren en neergestorte blokken, en kronkelende gangen. Rondom een onbreekbare buitenmuur en bodem.

const CHANNEL := VoxelBuffer.CHANNEL_SDF
const FAR := 10.0
const CAVERN_SQUASH := 1.6
## De SDF is niet helemaal 1-Lipschitz (hellingen tot ±0,8): ruimere marge voor uniforme blokken.
const UNIFORM_MARGIN := 1.6

var dims := Vector3i(500, 600, 500)
## Gemiddelde hoogte van het oppervlak (voxels).
var surface_y := 570.0
## Midden van de planeet (landingsplek), x/z in voxels.
var shaft_center := Vector2(250.0, 250.0)
var shaft_radius := 7.0
## Dikte van de ondoorgraafbare buitenmuur en bodem, in voxels.
var wall := 3.0
## Straal (voxels) van de vlakke landingsplek in het midden.
var landing_radius := 44.0

var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
## Ruwheid van grotwanden, gangen en rotsblokken (3D, enkel in hun buurt).
var _rough := FastNoiseLite.new()
const ROUGH_AMP := 1.8
## Per planeet (TerrainAPI zet ze voor setup): Fossielwereld is een vlakke kalkbodem met weinig kraters.
var crater_count := 22
var boulder_count := 70
## Planeettype (PlanetType.Id): de vorm van de rotsblokken (release-audit buiten-8). Roestbol een
## grof gehakte rots (zoals SurfaceDressing.rock_mesh erbuiten), Fossielwereld afgeschuinde
## krijtblokken, Kristalmaan groepjes zeskantige basaltzuilen.
var planet := 0
## Vormen van de landvorm in het speelgebied (TerrainAPI: Landform.near_height op een raster, in
## voxels, vóór setup gezet). Leeg = geen.
var near := PackedFloat32Array()
var near_origin := Vector2.ZERO # voxels
var near_step := 1.0 # voxels
var near_nx := 0
var near_nz := 0
var _craters: Array[Vector4] = [] # x, z, straal, diepte (voxels)
var _boulders: Array[Vector4] = [] # x, y, z, straal (de omhullende bol van elke rots)
## Rotsen als veelvlak: per rots [0] = (midden, omhullende straal), daarna de vlakken (normaal, afstand),
## alles in voxels. Een rots is het snijpunt van zijn halfruimtes: platte vlakken met harde randen
## (de voxels schuinen ze een halve voxel af), geen brood meer.
var _rocks: Array[PackedVector4Array] = []
## In de grotten (na het uithollen): neergestorte blokken (veelvlakken) en druipsteen (kegels:
## punt, voet, straal van de voet, en de omhullende bol).
var _cave_rocks: Array[PackedVector4Array] = []
var _cones: Array[PackedFloat32Array] = []
var _caverns: Array[Vector4] = [] # x, y, z, horizontale straal
var _tunnels: Array = [] # [a: Vector3, b: Vector3, straal] (optioneel [3]: ruwheid, standaard 0,7)
## Startgrot (golf 3, binnen-01: "de eerste 15 minuten onder de grond hebben geen plek om naartoe
## te gaan"): een grot in de klei vlak bij de landingsplek, met een oude toegangsgang van de vorige
## ploeg vanaf het oppervlak. CaveSetPieces zet er het kamp in. TerrainAPI zet `starter_cave` voor
## setup (setpieces.cfg). Enkel weggenomen rots: de regel "terrein kan enkel weg" blijft.
var starter_cave := true
var starter := Vector4.ZERO # voxels: midden en horizontale straal (w = 0: geen)
var starter_ramp: Array[Vector3] = [] # voxels: de as van de gang, van de monding naar de grot
const STARTER_RAMP_R := 4.4 # voxels (2,2 m)


func setup(planet_seed: int, size: Vector3i) -> void:
	dims = size
	surface_y = size.y - 30.0
	shaft_center = Vector2(size.x, size.z) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed
	_hills.seed = planet_seed
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.006
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 3
	_detail.seed = planet_seed + 17
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.035
	_rough.seed = planet_seed + 31
	_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rough.frequency = 0.08
	_rough.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rough.fractal_octaves = 2

	# Kraters: niet op de landingsplek.
	_craters.clear()
	var tries := 0
	while _craters.size() < crater_count and tries < 400:
		tries += 1
		var r := rng.randf_range(16.0, 62.0)
		var c := Vector2(rng.randf_range(r, size.x - r), rng.randf_range(r, size.z - r))
		if c.distance_to(shaft_center) < landing_radius + r * 0.9:
			continue
		_craters.append(Vector4(c.x, c.y, r, r * rng.randf_range(0.16, 0.26)))
	# De startgrot en haar gang (een eigen rng: de rest van de wereld blijft zoals hij was).
	_plan_starter(planet_seed)

	# Rotsblokken op het oppervlak, niet op de landingsplek.
	_boulders.clear()
	tries = 0
	while _boulders.size() < boulder_count and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(12.0, size.x - 12.0), rng.randf_range(12.0, size.z - 12.0))
		if p.distance_to(shaft_center) < landing_radius + 8.0:
			continue
		var r := rng.randf_range(2.0, 6.5)
		_boulders.append(Vector4(p.x, surface_at(p.x, p.y) + r * 0.35, p.y, r))
	_make_rocks(planet_seed)

	# Grotten: veel kleine en middelgrote, een paar grote (voor de Mol), op elke diepte.
	_caverns.clear()
	for i in 46:
		var big := i < 5
		var r := rng.randf_range(30.0, 46.0) if big else rng.randf_range(8.0, 24.0)
		var edge := r + wall + 4.0
		_caverns.append(Vector4(
				rng.randf_range(edge, size.x - edge),
				rng.randf_range(r / CAVERN_SQUASH + 16.0, surface_y - r / CAVERN_SQUASH - 24.0),
				rng.randf_range(edge, size.z - edge),
				r))
	# Kronkelgangen: korte reeksen capsules.
	_tunnels.clear()
	for i in 26:
		var p := Vector3(rng.randf_range(20.0, size.x - 20.0), rng.randf_range(24.0, surface_y - 30.0),
				rng.randf_range(20.0, size.z - 20.0))
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.35, 0.35), rng.randf_range(-1, 1)).normalized()
		var r := rng.randf_range(2.6, 4.6)
		for k in rng.randi_range(3, 6):
			dir = (dir + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.6, 0.6))).normalized()
			var q := p + dir * rng.randf_range(14.0, 30.0)
			q = q.clamp(Vector3(wall + r + 6.0, 16.0, wall + r + 6.0),
					Vector3(size.x - wall - r - 6.0, surface_y - 24.0, size.z - wall - r - 6.0))
			_tunnels.append([p, q, r])
			p = q
	# Startgrot achteraan (geen trekkingen uit rng: de andere grotten en gangen blijven gelijk).
	if starter.w > 0.0:
		_caverns.append(starter)
		for i in starter_ramp.size() - 1:
			_tunnels.append([starter_ramp[i], starter_ramp[i + 1], STARTER_RAMP_R, 0.25])
	_make_cave_features(planet_seed)


## De startgrot: 8-9,5 m breed, ±14 m onder het oppervlak, 55-62 m van het midden, en een gang van
## ±30° vanaf de rand van de landingsplek (te belopen: CharacterBody3D tot 45°). In voxels.
func _plan_starter(planet_seed: int) -> void:
	starter = Vector4.ZERO
	starter_ramp.clear()
	if not starter_cave:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 97 + 41
	var ang := rng.randf() * TAU
	var r := rng.randf_range(16.0, 19.0)
	var depth := rng.randf_range(26.0, 30.0)
	var bend := rng.randf_range(-1.0, 1.0)
	var mouth_d := landing_radius + 10.0
	var cave_d := mouth_d + 62.0 + r
	var dir := Vector2(cos(ang), sin(ang))
	var c := shaft_center + dir * cave_d
	var cy := surface_at(c.x, c.y) - depth
	starter = Vector4(c.x, cy, c.y, r)
	var m := shaft_center + dir * mouth_d
	var start := Vector3(m.x, surface_at(m.x, m.y) + 1.5, m.y)
	var floor_y := cy - r / CAVERN_SQUASH
	var end := Vector3(c.x - dir.x * (r - 3.0), floor_y + STARTER_RAMP_R - 0.5, c.y - dir.y * (r - 3.0))
	# Licht gebogen (een gang die met de hand gegraven is), in vier stukken.
	var side := Vector3(-dir.y, 0.0, dir.x) * bend * 7.0
	starter_ramp = [start, start.lerp(end, 0.3) + side * 0.8, start.lerp(end, 0.65) + side, end]


## Hoogte van het oppervlak (voxels) op kolom x/z, zonder rotsblokken.
## Grotten in wereldmeters: xyz = midden, w = horizontale straal (de hoogte is w / CAVERN_SQUASH).
func caverns_world(voxel_size: float) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for c in _caverns:
		out.append(c * voxel_size)
	return out


func surface_at(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(shaft_center)
	# Landingsplek: vlak in het midden, met een zachte overgang.
	var flat := clampf((d - landing_radius) / 40.0, 0.0, 1.0)
	flat = flat * flat * (3.0 - 2.0 * flat)
	var nh := 0.0
	if near_nx > 0:
		# Bilineair, hier uitgeschreven (een functieaanroep kost op de voxeldraden meer dan dit).
		var fx := (x - near_origin.x) / near_step
		var fz := (z - near_origin.y) / near_step
		if fx >= 0.0 and fz >= 0.0 and fx < near_nx - 1 and fz < near_nz - 1:
			var i := int(fx)
			var k := int(fz) * near_nx + i
			var tx := fx - i
			var tz := fz - floorf(fz)
			nh = lerpf(lerpf(near[k], near[k + 1], tx), lerpf(near[k + near_nx], near[k + near_nx + 1], tx), tz)
	var h := surface_y + flat * (10.0 * _hills.get_noise_2d(x, z) + 1.4 * _detail.get_noise_2d(x, z) + nh)
	for c in _craters:
		var dc := Vector2(x - c.x, z - c.y).length() / c.z
		if dc < 1.6:
			h += _crater_profile(dc) * c.w
	return h


func sdf_at(p: Vector3) -> float:
	return _sdf(p, surface_at(p.x, p.z), _rocks, _caverns, _tunnels, _cave_rocks, _cones)


## De vormen binnen `reach` voxels van `center` (voor veel vragen in één gebied, zoals CaveDecor).
func local_shapes(center: Vector3, reach: float) -> Array:
	var rocks: Array[PackedVector4Array] = []
	for b in _rocks:
		if Vector3(b[0].x, b[0].y, b[0].z).distance_to(center) < b[0].w + reach:
			rocks.append(b)
	var caverns: Array[Vector4] = []
	for c in _caverns:
		if Vector3(c.x, c.y, c.z).distance_to(center) < c.w + reach:
			caverns.append(c)
	var tunnels: Array = []
	for t: Array in _tunnels:
		var a: Vector3 = t[0]
		var ab: Vector3 = (t[1] as Vector3) - a
		var k := clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if center.distance_to(a + ab * k) < float(t[2]) + reach:
			tunnels.append(t)
	var cave_rocks: Array[PackedVector4Array] = []
	for b in _cave_rocks:
		if Vector3(b[0].x, b[0].y, b[0].z).distance_to(center) < b[0].w + reach:
			cave_rocks.append(b)
	var cones: Array[PackedFloat32Array] = []
	for cn in _cones:
		if Vector3(cn[7], cn[8], cn[9]).distance_to(center) < cn[10] + reach:
			cones.append(cn)
	return [rocks, caverns, tunnels, cave_rocks, cones]


## Zoals sdf_at, maar enkel met de vormen uit local_shapes (voxels).
func sdf_local(p: Vector3, shapes: Array) -> float:
	return _sdf(p, surface_at(p.x, p.z), shapes[0], shapes[1], shapes[2], shapes[3], shapes[4])


## Kraterprofiel (×diepte): een kom tot de rand (d = 1), met een opstaande rand erbuiten.
static func _crater_profile(d: float) -> float:
	var bowl := -(1.0 - d * d) if d < 1.0 else 0.0
	var rim := 0.32 * exp(-pow((d - 1.0) / 0.22, 2.0))
	return bowl + rim


## Ruwheid op een veelvlak (voxels): klein, zodat de vlakken plat blijven en de randen hard.
const ROCK_ROUGH := 0.12

# --- Rotsblokken (release-audit buiten-8, buiten-12) ------------------------------------------
#
# Een rots is een veelvlak: het snijpunt van zijn halfruimtes (max van de afstanden tot de vlakken).
# Binnenin is dat de echte afstand, erbuiten een ondergrens: genoeg voor de voxels. Per planeet een
# eigen vorm, en in groepjes: om de ±60 m een groep van 2-5 met één grote, en losse ertussen. Zo
# staat er in het middenplan iets van 2-8 m, zoals de rotsen erbuiten (SurfaceDressing).


## Hoekpunten en vlakken van een icosaëder (zoals SurfaceDressing.rock_mesh).
const ICO_T := 1.618034
const ICO_V: Array[Vector3] = [Vector3(-1, ICO_T, 0), Vector3(1, ICO_T, 0), Vector3(-1, -ICO_T, 0), Vector3(1, -ICO_T, 0),
	Vector3(0, -1, ICO_T), Vector3(0, 1, ICO_T), Vector3(0, -1, -ICO_T), Vector3(0, 1, -ICO_T),
	Vector3(ICO_T, 0, -1), Vector3(ICO_T, 0, 1), Vector3(-ICO_T, 0, -1), Vector3(-ICO_T, 0, 1)]
const ICO_F := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
	[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
	[6, 2, 10], [8, 6, 7], [9, 8, 1]]


func _make_rocks(planet_seed: int) -> void:
	_rocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 31 + 5
	var centers := _boulders.duplicate()
	_boulders.clear()
	for i in centers.size():
		var c: Vector4 = centers[i]
		# Een op de drie wordt een groep, de rest blijft een losse (middelgrote) rots.
		var group := i % 3 == 0
		var main_r := rng.randf_range(4.0, 7.5) if group else rng.randf_range(2.2, 4.5)
		_add_rock(Vector2(c.x, c.z), main_r, rng)
		if group:
			for k in rng.randi_range(1, 4):
				var a := rng.randf() * TAU
				var r := main_r * rng.randf_range(0.3, 0.6)
				var d := (main_r + r) * rng.randf_range(0.7, 1.15)
				_add_rock(Vector2(c.x + cos(a) * d, c.z + sin(a) * d), r, rng)


## Eén rots op het oppervlak bij kolom `xz` (voxels), ±35% ingegraven.
func _add_rock(xz: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	# Altijd evenveel trekkingen, ook als de rots wegvalt (zelfde rotsen op elke peer).
	var shape := _rock_shape(rng, r, true)
	if xz.distance_to(shaft_center) < landing_radius + r + 4.0:
		return
	if xz.x < wall + r + 6.0 or xz.y < wall + r + 6.0 or xz.x > dims.x - wall - r - 6.0 or xz.y > dims.z - wall - r - 6.0:
		return
	if not starter_ramp.is_empty() and xz.distance_to(Vector2(starter_ramp[0].x, starter_ramp[0].z)) < r * 2.0 + 14.0:
		return # niet voor de monding van de oude gang
	var sink: float = shape[1]
	var c := Vector3(xz.x, surface_at(xz.x, xz.y) + sink, xz.y)
	var rock := _place(shape[0], c, shape[2])
	_rocks.append(rock)
	_boulders.append(rock[0])


## Een rotsvorm van `r` voxels in de stijl van de planeet: [vlakken (lokaal, rond 0), hoogte van het
## midden boven de grond]. `on_ground`: de onderkant mag ruw zijn (hij zit in de grond).
func _rock_shape(rng: RandomNumberGenerator, r: float, on_ground: bool) -> Array:
	var planes: Array[Vector4] = []
	var scale := Vector3.ONE
	var tilt := Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	var sink := 0.0
	# In grotten liggen op de Kristalmaan gewone brokken (een liggende zuil leek op een grafsteen).
	match planet if on_ground or planet != 2 else 0:
		1:
			# Krijtblok: een doos met afgeschuinde ribben en hoeken, plat en breed, wat verzakt.
			for ax: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
				planes.append(Vector4(ax.x, ax.y, ax.z, 1.0 + rng.randf_range(-0.06, 0.06)))
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var e1 := Vector3(sx, sy, 0.0).normalized()
					var e2 := Vector3(0.0, sy, sx).normalized()
					var e3 := Vector3(sx, 0.0, sy).normalized()
					for e: Vector3 in [e1, e2, e3]:
						planes.append(Vector4(e.x, e.y, e.z, rng.randf_range(1.12, 1.24)))
					for sz in [-1.0, 1.0]:
						var cn := Vector3(sx, sy, sz).normalized()
						planes.append(Vector4(cn.x, cn.y, cn.z, rng.randf_range(1.3, 1.45)))
			scale = Vector3(rng.randf_range(1.1, 1.5), rng.randf_range(0.45, 0.7), rng.randf_range(0.8, 1.2)) * r
			tilt.x *= 0.6
			tilt.z *= 0.6
			sink = scale.y * rng.randf_range(0.15, 0.4)
		2:
			# Basaltzuil: zeskantig, twee keer zo hoog als breed, met een schuin afgebroken top.
			var a0 := rng.randf() * TAU
			for k in 6:
				var a := a0 + k * TAU / 6.0
				planes.append(Vector4(cos(a), 0.0, sin(a), 1.0))
			var th := rng.randf_range(0.15, 0.5)
			var ph := rng.randf() * TAU
			var tn := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			planes.append(Vector4(tn.x, tn.y, tn.z, rng.randf_range(1.6, 2.4)))
			planes.append(Vector4(0.0, -1.0, 0.0, 2.0))
			scale = Vector3.ONE * r * 0.55
			tilt.x *= 0.5
			tilt.z *= 0.5
			sink = scale.y * rng.randf_range(0.4, 0.9)
		_:
			# Grof gehakte rots: een icosaëder met verschoven hoekpunten (20 grote, scheve vlakken).
			var v: Array[Vector3] = []
			for p in ICO_V:
				v.append(p.normalized() * rng.randf_range(0.78, 1.2))
			for f in ICO_F:
				var a: Vector3 = v[f[0]]
				var b: Vector3 = v[f[1]]
				var c: Vector3 = v[f[2]]
				var n := (b - a).cross(c - a).normalized()
				if n.dot(a + b + c) < 0.0:
					n = -n
				planes.append(Vector4(n.x, n.y, n.z, n.dot(a)))
			scale = Vector3(rng.randf_range(0.95, 1.3), rng.randf_range(0.6, 0.95), rng.randf_range(0.85, 1.2)) * r
			sink = scale.y * rng.randf_range(0.1, 0.35)
	if not on_ground:
		sink = scale.y * 0.5
	var basis := Basis.from_euler(tilt)
	var out := PackedVector4Array()
	for pl in planes:
		# Vlak in de geschaalde, gedraaide rots: n' = S⁻¹n / |S⁻¹n|, d' = d / |S⁻¹n|.
		var ns := Vector3(pl.x / scale.x, pl.y / scale.y, pl.z / scale.z)
		var l := ns.length()
		var nw := basis * (ns / l)
		out.append(Vector4(nw.x, nw.y, nw.z, pl.w / l))
	var ext := maxf(scale.x, maxf(scale.y, scale.z)) * (2.6 if planet == 2 else 1.8)
	return [out, sink, ext]


## De vlakken van een vorm rond `c`: [0] = (c, omhullende straal), daarna (normaal, afstand t.o.v. c).
func _place(shape: PackedVector4Array, c: Vector3, ext := -1.0) -> PackedVector4Array:
	var out := PackedVector4Array()
	var bound := ext
	if bound < 0.0:
		bound = 0.0
		for pl in shape:
			bound = maxf(bound, pl.w)
		bound *= 1.9
	out.append(Vector4(c.x, c.y, c.z, bound))
	out.append_array(shape)
	return out


static func _poly_sdf(p: Vector3, rock: PackedVector4Array) -> float:
	var c := rock[0]
	var q := p - Vector3(c.x, c.y, c.z)
	# Ver weg: de omhullende bol is genoeg (een ondergrens, en veel goedkoper).
	var far := q.length() - c.w
	if far > 2.5:
		return far
	var d := -INF
	for i in range(1, rock.size()):
		var pl := rock[i]
		d = maxf(d, q.x * pl.x + q.y * pl.y + q.z * pl.z - pl.w)
	return d


# --- Grotten: druipsteen, pilaren en neergestorte blokken (release-audit binnen-01) -------------
#
# Uit de seed, in de SDF: graafbaar terrein zoals de rest. Per grot een handvol druipstenen aan het
# plafond, wat stalagmieten op de vloer, in de grote grotten een pilaar, en een paar blokken.


func _make_cave_features(planet_seed: int) -> void:
	_cave_rocks.clear()
	_cones.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 53 + 11
	for c in _caverns:
		var r := c.w
		var half_h := r / CAVERN_SQUASH
		var camp := starter.w > 0.0 and c == starter # het kamp staat op de vloer: daar geen kegels of blokken
		# Druipsteen aan het plafond.
		for k in clampi(int(r / 4.0), 2, 10):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, 0.62) * r
			var ceil_y := c.y + sqrt(maxf(r * r - d * d, 0.0)) / CAVERN_SQUASH
			var length := rng.randf_range(0.22, 0.55) * half_h
			var base_r := maxf(1.6, length * rng.randf_range(0.2, 0.32))
			var top := Vector3(c.x + cos(a) * d, ceil_y + 2.5, c.z + sin(a) * d)
			_add_cone(top - Vector3(0.0, length + 2.5, 0.0), top, base_r)
		# Stalagmieten op de vloer.
		for k in (0 if camp else clampi(int(r / 7.0), 1, 6)):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.15, 0.7) * r
			var floor_y := c.y - sqrt(maxf(r * r - d * d, 0.0)) / CAVERN_SQUASH
			var length := rng.randf_range(0.15, 0.4) * half_h
			var base_r := maxf(1.8, length * rng.randf_range(0.3, 0.45))
			var foot := Vector3(c.x + cos(a) * d, floor_y - 2.0, c.z + sin(a) * d)
			_add_cone(foot + Vector3(0.0, length + 2.0, 0.0), foot, base_r)
		# Een pilaar in de grote grotten: een stalactiet en een stalagmiet die elkaar raken.
		if r > 28.0 and not camp:
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.3, 0.55) * r
			var p := Vector2(c.x + cos(a) * d, c.z + sin(a) * d)
			var span := sqrt(maxf(r * r - d * d, 0.0)) / CAVERN_SQUASH
			var pr := rng.randf_range(2.6, 4.2)
			var mid := c.y + rng.randf_range(-0.2, 0.2) * span
			# De punten schuiven voorbij elkaar: zo heeft de pilaar een taille, geen naald in het midden.
			_add_cone(Vector3(p.x, mid - span * 0.6, p.y), Vector3(p.x, c.y + span + 3.0, p.y), pr * 1.3)
			_add_cone(Vector3(p.x, mid + span * 0.6, p.y), Vector3(p.x, c.y - span - 3.0, p.y), pr * 1.5)
		# Neergestorte blokken op de vloer.
		if r > 11.0 and not camp:
			for k in 1 + int(r / 15.0):
				var shape := _rock_shape(rng, rng.randf_range(2.0, minf(5.0, r * 0.18)), false)
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.1, 0.6) * r
				var floor_y := c.y - sqrt(maxf(r * r - d * d, 0.0)) / CAVERN_SQUASH
				var sink: float = shape[1]
				_cave_rocks.append(_place(shape[0], Vector3(c.x + cos(a) * d, floor_y + sink * 0.5, c.z + sin(a) * d), shape[2]))


## Kegel van `tip` naar `base` met voetstraal `base_r` (voxels).
func _add_cone(tip: Vector3, base: Vector3, base_r: float) -> void:
	var mid := (tip + base) * 0.5
	var bound := tip.distance_to(base) * 0.5 + base_r
	_cones.append(PackedFloat32Array([tip.x, tip.y, tip.z, base.x, base.y, base.z, base_r, mid.x, mid.y, mid.z, bound]))


static func _cone_sdf(p: Vector3, cone: PackedFloat32Array) -> float:
	var far := p.distance_to(Vector3(cone[7], cone[8], cone[9])) - cone[10]
	if far > 2.5:
		return far
	var a := Vector3(cone[0], cone[1], cone[2])
	var ab := Vector3(cone[3], cone[4], cone[5]) - a
	var h := ab.length()
	var axis := ab / h
	var ap := p - a
	var t := ap.dot(axis)
	var radial := (ap - axis * t).length()
	var k := cone[6] / h
	# Druipsteen is niet glad: hij verdikt en versmalt in ringen.
	var wobble := 0.25 * sin(t * 0.9 + cone[0] * 0.37)
	var side := (radial - k * t - wobble) / sqrt(1.0 + k * k)
	return maxf(side, maxf(-t, t - h))


# --- De SDF ---------------------------------------------------------------------------------------

func _sdf(p: Vector3, h: float, rocks: Array[PackedVector4Array], caverns: Array[Vector4], tunnels: Array,
		cave_rocks: Array[PackedVector4Array], cones: Array[PackedFloat32Array]) -> float:
	var s := p.y - h
	var rough := NAN # 3D-ruis pas uitrekenen als een vorm in de buurt is (duur in GDScript)
	for b in rocks:
		var db := _poly_sdf(p, b)
		if db < 1.5:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			db += rough * ROCK_ROUGH
		s = minf(s, db)
	for c in caverns:
		var d := Vector3(p.x - c.x, (p.y - c.y) * CAVERN_SQUASH, p.z - c.z).length()
		var dc := (c.w - d) / CAVERN_SQUASH
		if dc > -4.0:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			dc += rough
		s = maxf(s, dc)
	for t: Array in tunnels:
		var a: Vector3 = t[0]
		var ab: Vector3 = (t[1] as Vector3) - a
		var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var dt := float(t[2]) - p.distance_to(a + ab * k)
		if dt > -3.0:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			dt += rough * (0.7 if t.size() < 4 else float(t[3]))
		s = maxf(s, dt)
	# In de grotten (na het uithollen): blokken en druipsteen.
	for b in cave_rocks:
		var db := _poly_sdf(p, b)
		if db < 1.5:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			db += rough * ROCK_ROUGH
		s = minf(s, db)
	for cn in cones:
		var dk := _cone_sdf(p, cn)
		if dk < 1.5:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			dk += rough * 0.25
		s = minf(s, dk)
	# Buitenmuur en bodem: enkel onder het oppervlak (geen wand die boven de vlakte uitsteekt). Als
	# afstand: muur ∩ "onder het oppervlak". Een harde afknip op h + 2 liet langs het hele speelgebied
	# een rand van ±1 m boven de vlakte staan (van op de grond een trede tegen het verre landschap).
	if p.y < h + 2.0:
		var edge := minf(minf(p.x, dims.x - 1 - p.x), minf(minf(p.z, dims.z - 1 - p.z), p.y))
		s = minf(s, maxf(edge - wall, p.y - h))
	return s


func _get_used_channels_mask() -> int:
	return 1 << CHANNEL


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var n := out_buffer.get_size()
	var step := 1 << lod
	var half := Vector3(n) * 0.5 * step
	var center := Vector3(origin) + half
	var reach := half.length() + 2.0

	var rocks: Array[PackedVector4Array] = []
	for b in _rocks:
		var c := b[0]
		if Vector3(c.x, c.y, c.z).distance_to(center) < c.w + reach:
			rocks.append(b)
	var caverns: Array[Vector4] = []
	for c in _caverns:
		if Vector3(c.x, c.y, c.z).distance_to(center) < c.w + reach:
			caverns.append(c)
	var tunnels: Array = []
	for t: Array in _tunnels:
		var a: Vector3 = t[0]
		var ab: Vector3 = (t[1] as Vector3) - a
		var k := clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if center.distance_to(a + ab * k) < float(t[2]) + reach:
			tunnels.append(t)
	var cave_rocks: Array[PackedVector4Array] = []
	for b in _cave_rocks:
		var c := b[0]
		if Vector3(c.x, c.y, c.z).distance_to(center) < c.w + reach:
			cave_rocks.append(b)
	var cones: Array[PackedFloat32Array] = []
	for cn in _cones:
		if Vector3(cn[7], cn[8], cn[9]).distance_to(center) < cn[10] + reach:
			cones.append(cn)

	# Ver van elk oppervlak is het hele blok uniform (rots of lucht).
	var c_sdf := _sdf(center, surface_at(center.x, center.z), rocks, caverns, tunnels, cave_rocks, cones)
	if c_sdf < -reach * UNIFORM_MARGIN:
		out_buffer.fill_f(-FAR, CHANNEL)
		return
	if c_sdf > reach * UNIFORM_MARGIN:
		out_buffer.fill_f(FAR, CHANNEL)
		return

	# Oppervlakte per kolom één keer.
	var heights := PackedFloat32Array()
	heights.resize(n.x * n.z)
	for z in n.z:
		for x in n.x:
			heights[z * n.x + x] = surface_at(origin.x + x * step, origin.z + z * step)
	for z in n.z:
		for x in n.x:
			var h := heights[z * n.x + x]
			for y in n.y:
				var p := Vector3(origin.x + x * step, origin.y + y * step, origin.z + z * step)
				out_buffer.set_voxel_f(clampf(_sdf(p, h, rocks, caverns, tunnels, cave_rocks, cones), -FAR, FAR), x, y, z, CHANNEL)
