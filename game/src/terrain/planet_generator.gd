class_name PlanetGenerator
extends VoxelGeneratorScript
## Genereert een planeet (GDD v3 §4) in voxelruimte (1 voxel = TerrainAPI.VOXEL_SIZE m).
## SDF-conventie van godot_voxel: negatief = rots, positief = lucht.
## Draait op werkthreads: na setup() wordt enkel nog gelezen.
##
## Bovenaan een kale buitenaardse vlakte: golvende heuvels, kraters met een rand, losse
## rotsblokken, en in het midden een vlakke landingsplek voor de Mol. Daaronder grotten op elke
## diepte (een paar groot genoeg voor de Mol) en kronkelende gangen. Rondom een onbreekbare
## buitenmuur en bodem.

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
var _craters: Array[Vector4] = [] # x, z, straal, diepte (voxels)
var _boulders: Array[Vector4] = [] # x, y, z, straal
var _caverns: Array[Vector4] = [] # x, y, z, horizontale straal
var _tunnels: Array = [] # [a: Vector3, b: Vector3, straal]


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
	while _craters.size() < 22 and tries < 400:
		tries += 1
		var r := rng.randf_range(16.0, 62.0)
		var c := Vector2(rng.randf_range(r, size.x - r), rng.randf_range(r, size.z - r))
		if c.distance_to(shaft_center) < landing_radius + r * 0.9:
			continue
		_craters.append(Vector4(c.x, c.y, r, r * rng.randf_range(0.16, 0.26)))

	# Rotsblokken op het oppervlak, niet op de landingsplek.
	_boulders.clear()
	tries = 0
	while _boulders.size() < 70 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(12.0, size.x - 12.0), rng.randf_range(12.0, size.z - 12.0))
		if p.distance_to(shaft_center) < landing_radius + 8.0:
			continue
		var r := rng.randf_range(2.0, 6.5)
		_boulders.append(Vector4(p.x, surface_at(p.x, p.y) + r * 0.35, p.y, r))

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


## Hoogte van het oppervlak (voxels) op kolom x/z, zonder rotsblokken.
func surface_at(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(shaft_center)
	# Landingsplek: vlak in het midden, met een zachte overgang.
	var flat := clampf((d - landing_radius) / 40.0, 0.0, 1.0)
	flat = flat * flat * (3.0 - 2.0 * flat)
	var h := surface_y + flat * (10.0 * _hills.get_noise_2d(x, z) + 1.4 * _detail.get_noise_2d(x, z))
	for c in _craters:
		var dc := Vector2(x - c.x, z - c.y).length() / c.z
		if dc < 1.6:
			h += _crater_profile(dc) * c.w
	return h


func sdf_at(p: Vector3) -> float:
	return _sdf(p, surface_at(p.x, p.z), _boulders, _caverns, _tunnels)


## Kraterprofiel (×diepte): een kom tot de rand (d = 1), met een opstaande rand erbuiten.
static func _crater_profile(d: float) -> float:
	var bowl := -(1.0 - d * d) if d < 1.0 else 0.0
	var rim := 0.32 * exp(-pow((d - 1.0) / 0.22, 2.0))
	return bowl + rim


func _sdf(p: Vector3, h: float, boulders: Array[Vector4], caverns: Array[Vector4], tunnels: Array) -> float:
	var s := p.y - h
	var rough := NAN # 3D-ruis pas uitrekenen als een vorm in de buurt is (duur in GDScript)
	for b in boulders:
		var db := Vector3(p.x - b.x, (p.y - b.y) * 1.25, p.z - b.z).length() / 1.25 - b.w
		if db < 3.0:
			if is_nan(rough):
				rough = _rough.get_noise_3dv(p) * ROUGH_AMP
			db += rough * 0.5
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
			dt += rough * 0.7
		s = maxf(s, dt)
	# Buitenmuur en bodem: enkel onder het oppervlak (geen wand die boven de vlakte uitsteekt).
	if p.y < h + 2.0:
		var edge := minf(minf(p.x, dims.x - 1 - p.x), minf(minf(p.z, dims.z - 1 - p.z), p.y))
		s = minf(s, edge - wall)
	return s


func _get_used_channels_mask() -> int:
	return 1 << CHANNEL


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var n := out_buffer.get_size()
	var step := 1 << lod
	var half := Vector3(n) * 0.5 * step
	var center := Vector3(origin) + half
	var reach := half.length() + 2.0

	var boulders: Array[Vector4] = []
	for b in _boulders:
		if Vector3(b.x, b.y, b.z).distance_to(center) < b.w + reach:
			boulders.append(b)
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

	# Ver van elk oppervlak is het hele blok uniform (rots of lucht).
	var c_sdf := _sdf(center, surface_at(center.x, center.z), boulders, caverns, tunnels)
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
				out_buffer.set_voxel_f(clampf(_sdf(p, h, boulders, caverns, tunnels), -FAR, FAR), x, y, z, CHANNEL)
