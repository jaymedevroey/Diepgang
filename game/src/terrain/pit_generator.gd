class_name PitGenerator
extends VoxelGeneratorScript
## Genereert de put in voxelruimte (1 voxel = TerrainAPI.VOXEL_SIZE m).
## SDF-conventie van godot_voxel: negatief = rots, positief = lucht.
## Draait op werkthreads: na setup() wordt enkel nog gelezen.

const CHANNEL := VoxelBuffer.CHANNEL_SDF
const FAR := 10.0
const CAVERN_SQUASH := 1.6

var dims := Vector3i(128, 320, 128)
var surface_y := 300.0
var shaft_center := Vector2(64.0, 64.0)
var shaft_radius := 7.0
## Dikte van de ondoorgraafbare buitenmuur en bodem, in voxels.
var wall := 3.0

var _phase := Vector2.ZERO
var _caverns: Array[Vector4] = [] # xyz = centrum, w = horizontale straal (voxels)


func setup(pit_seed: int, size: Vector3i) -> void:
	dims = size
	surface_y = size.y - 20.0
	shaft_center = Vector2(size.x, size.z) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = pit_seed
	_phase = Vector2(rng.randf() * TAU, rng.randf() * TAU)
	_caverns.clear()
	for i in 10:
		var r := rng.randf_range(6.0, 13.0)
		var edge := r + wall + 2.0
		_caverns.append(Vector4(
				rng.randf_range(edge, size.x - edge),
				rng.randf_range(r + 8.0, surface_y - r - 12.0),
				rng.randf_range(edge, size.z - edge),
				r))


func surface_at(x: float, z: float) -> float:
	return surface_y + 1.5 * sin(x * 0.09 + _phase.x) + 1.5 * sin(z * 0.07 + _phase.y)


func sdf_at(p: Vector3) -> float:
	return _sdf(p, _caverns)


func _sdf(p: Vector3, caverns: Array[Vector4]) -> float:
	var s := p.y - surface_at(p.x, p.z)
	s = maxf(s, shaft_radius - Vector2(p.x, p.z).distance_to(shaft_center))
	for c in caverns:
		var d := Vector3(p.x - c.x, (p.y - c.y) * CAVERN_SQUASH, p.z - c.z).length()
		s = maxf(s, (c.w - d) / CAVERN_SQUASH)
	var edge := minf(minf(p.x, dims.x - 1 - p.x), minf(minf(p.z, dims.z - 1 - p.z), p.y))
	return minf(s, edge - wall)


func _get_used_channels_mask() -> int:
	return 1 << CHANNEL


func _generate_block(out_buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	var n := out_buffer.get_size()
	var step := 1 << lod
	var half := Vector3(n) * 0.5 * step
	var center := Vector3(origin) + half
	var reach := half.length() + 2.0

	var near: Array[Vector4] = []
	for c in _caverns:
		if Vector3(c.x, c.y, c.z).distance_to(center) < c.w + reach:
			near.append(c)

	# De SDF is ongeveer 1-Lipschitz: ver van elk oppervlak is het hele blok uniform.
	var c_sdf := _sdf(center, near)
	if c_sdf < -reach * 1.2:
		out_buffer.fill_f(-FAR, CHANNEL)
		return
	if c_sdf > reach * 1.2:
		out_buffer.fill_f(FAR, CHANNEL)
		return

	for z in n.z:
		for x in n.x:
			for y in n.y:
				var p := Vector3(origin.x + x * step, origin.y + y * step, origin.z + z * step)
				out_buffer.set_voxel_f(clampf(_sdf(p, near), -FAR, FAR), x, y, z, CHANNEL)
