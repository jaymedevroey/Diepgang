class_name TerrainAPI
extends Node3D
## De enige toegang tot het terrein (GDD §9). Buiten src/terrain/ gebruikt niemand
## VoxelTerrain of VoxelTool rechtstreeks, zodat de voxel-extensie vervangbaar blijft.
##
## Terrein kan enkel weggenomen worden, dus de volgorde van graafacties maakt niet uit.
## Elke actie is een op (Dictionary) in voxelruimte. Ops gaan door een wachtrij die één
## keer per physics-tick wordt toegepast, en belanden daarna in het op-logboek (voor late
## joiners en replays).
##   SPHERE_REMOVE {c, r}            bol (boor, stresstest)
##   CHIP          {c, n, rt, rd, amp}  afgeplatte, ruwe schilfer langs normaal n (houweel)
## Elke op doet nieuw = max(huidig, -kwast): commutatief en idempotent (docs/research/graven.md).
## Ruis in de kwast zit in wereldruimte met een vaste seed, zodat elke peer hetzelfde uitkomt.

signal loaded(stats: Dictionary)
signal dug(world_center: Vector3, radius_m: float)
## Na het toepassen van elke op (lokaal of van het netwerk).
signal op_applied(op: Dictionary)

enum Op { SPHERE_REMOVE, CHIP }

const VOXEL_SIZE := 0.5
const COLLISION_LAYER := 1
const LOAD_TIMEOUT_MS := 120000.0
const SDF_BIT := 1 << VoxelBuffer.CHANNEL_SDF

@export var pit_seed := 1
@export var dims := Vector3i(128, 320, 128)

var is_loaded := false
var ops_applied_total := 0
var ops_applied_last_tick := 0

var _terrain: VoxelTerrain
var _tool: VoxelToolTerrain
var _generator: PitGenerator
var _queue: Array[Dictionary] = []
var _op_log: Array[Dictionary] = []
var _buckets: Dictionary = {} # player_id -> [tokens, laatste tijd in s]
var _tick := 0
var _load_start_us := 0
var _wake_shape := SphereShape3D.new()
var _brush_noise := FastNoiseLite.new()


func _ready() -> void:
	_brush_noise.seed = 1337
	_brush_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_brush_noise.frequency = 0.45 # per voxel: bulten van ±1 m
	_brush_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_brush_noise.fractal_octaves = 2

	_generator = PitGenerator.new()
	_generator.setup(pit_seed, dims)

	_terrain = VoxelTerrain.new()
	_terrain.name = "VoxelTerrain"
	_terrain.scale = Vector3.ONE * VOXEL_SIZE
	_terrain.generator = _generator
	_terrain.mesher = VoxelMesherTransvoxel.new()
	_terrain.bounds = AABB(Vector3.ZERO, Vector3(dims))
	_terrain.mesh_block_size = 16
	_terrain.max_view_distance = 512
	_terrain.generate_collisions = true
	_terrain.collision_layer = COLLISION_LAYER
	_terrain.collision_mask = 0
	_terrain.material_override = _make_material()
	add_child(_terrain)

	# De put is klein genoeg om volledig geladen te blijven: één viewer in het midden.
	var viewer := VoxelViewer.new()
	viewer.view_distance = 512
	viewer.position = world_size() * 0.5
	add_child(viewer)

	_tool = _terrain.get_voxel_tool() as VoxelToolTerrain
	_tool.channel = VoxelBuffer.CHANNEL_SDF
	_tool.mode = VoxelTool.MODE_REMOVE
	_load_start_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if is_loaded:
		return
	var elapsed_ms := (Time.get_ticks_usec() - _load_start_us) / 1000.0
	var meshed := _terrain.is_area_meshed(AABB(Vector3.ZERO, Vector3(dims)))
	if meshed or elapsed_ms > LOAD_TIMEOUT_MS:
		is_loaded = true
		var stats := get_stats()
		stats["load_ms"] = elapsed_ms
		stats["load_timed_out"] = not meshed
		loaded.emit(stats)


func _physics_process(_delta: float) -> void:
	_tick += 1
	ops_applied_last_tick = 0
	if _queue.is_empty():
		return
	var pending: Array[Dictionary] = []
	for op in _queue:
		var c: Vector3 = op.c
		var reach := _op_reach(op)
		if not _tool.is_area_editable(AABB(c - Vector3.ONE * (reach + 1.0), Vector3.ONE * (2.0 * reach + 2.0))):
			pending.append(op)
			continue
		match op.op:
			Op.SPHERE_REMOVE:
				_tool.do_sphere(c, op.r)
			Op.CHIP:
				_apply_chip(op)
		_op_log.append(op)
		ops_applied_last_tick += 1
		var world := _terrain.to_global(c)
		_wake_bodies(world, reach * VOXEL_SIZE)
		dug.emit(world, reach * VOXEL_SIZE)
		op_applied.emit(op)
	ops_applied_total += ops_applied_last_tick
	_queue = pending


# --- Graven -------------------------------------------------------------------

## Graafactie van een speler. Beperkt tot dig.max_ops_per_second per speler.
## Geeft false als de speler te snel graaft. (Lokaal; netwerkspel gaat via TerrainSync.)
func request_dig(player_id: int, world_center: Vector3, radius_m: float) -> bool:
	if not take_token(player_id):
		return false
	apply_op(make_sphere_op(player_id, world_center, radius_m))
	return true


## Houweelslag, lokaal. Zie make_chip_op.
func request_chip(player_id: int, world_hit: Vector3, world_normal: Vector3,
		radius_m: float, depth_m: float, rough_m: float) -> bool:
	if not take_token(player_id):
		return false
	apply_op(make_chip_op(player_id, world_hit, world_normal, radius_m, depth_m, rough_m))
	return true


## Bol wegnemen rond `world_center`. Maakt enkel de op; toepassen met apply_op.
func make_sphere_op(player_id: int, world_center: Vector3, radius_m: float) -> Dictionary:
	var r := radius_m / VOXEL_SIZE
	var c := _clamp_center(_terrain.to_local(world_center), r)
	return {"op": Op.SPHERE_REMOVE, "c": c, "r": r, "h": world_center, "tick": _tick, "p": player_id}


## Houweelslag: een afgeplatte, ruwe schilfer van `depth_m` diep en ±`radius_m` breed,
## ingebed in de wand op het raakpunt. `world_normal` wijst uit de rots naar buiten.
## Maakt enkel de op; toepassen met apply_op.
func make_chip_op(player_id: int, world_hit: Vector3, world_normal: Vector3,
		radius_m: float, depth_m: float, rough_m: float) -> Dictionary:
	var n := world_normal.normalized()
	var rt := radius_m / VOXEL_SIZE
	var rd := maxf(depth_m * 1.6, rt * 0.55) / VOXEL_SIZE
	var depth := depth_m / VOXEL_SIZE
	# De ellipsoïde steekt precies `depth` voorbij het raakpunt de rots in.
	var c := _terrain.to_local(world_hit) + n * (rd - depth)
	c = _clamp_center(c, maxf(rt, rd))
	return {"op": Op.CHIP, "c": c, "n": n, "rt": rt, "rd": rd, "amp": rough_m / VOXEL_SIZE,
			"h": world_hit, "tick": _tick, "p": player_id}


## Past een op toe (lokaal gemaakt of van het netwerk). Geen snelheidslimiet:
## wie een op van een ander aanvaardt, moet die eerst zelf valideren.
func apply_op(op: Dictionary) -> void:
	_queue.append(op)


## Wereldpositie van het centrum van een op, voor validatie (afstand tot de speler).
func op_world_center(op: Dictionary) -> Vector3:
	return _terrain.to_global(op.c)


## Graven zonder snelheidslimiet, voor tests en scenario's.
func debug_dig(world_center: Vector3, radius_m: float) -> void:
	apply_op(make_sphere_op(0, world_center, radius_m))


## Snelheidslimiet per speler (token bucket, dig.max_ops_per_second en dig.burst).
func take_token(player_id: int) -> bool:
	return _take_token(player_id)


## Checksum van het volledige SDF-kanaal. Twee peers met hetzelfde terrein geven dezelfde waarde.
func checksum() -> String:
	var buf := VoxelBuffer.new()
	buf.create(dims.x, dims.y, dims.z)
	_tool.copy(Vector3i.ZERO, buf, SDF_BIT, false)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(buf.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF))
	return ctx.finish().hex_encode()


func op_log() -> Array[Dictionary]:
	return _op_log


func queued_ops() -> int:
	return _queue.size()


# --- Vragen -------------------------------------------------------------------

func is_solid(world: Vector3) -> bool:
	var p := _terrain.to_local(world)
	return _tool.get_voxel_f(Vector3i(p.round())) < 0.0


## Afstand tot het rotsoppervlak in meter (trilineair; negatief = in de rots).
## Uit de voxeldata zelf, dus ook juist als de collision van dat blok nog niet gebouwd is.
func sdf_at(world: Vector3) -> float:
	var p := _terrain.to_local(world)
	var b := Vector3i(p.floor())
	var f := p - Vector3(b)
	var v := 0.0
	for dz in 2:
		for dy in 2:
			for dx in 2:
				var w := (f.x if dx else 1.0 - f.x) * (f.y if dy else 1.0 - f.y) * (f.z if dz else 1.0 - f.z)
				v += w * _tool.get_voxel_f(b + Vector3i(dx, dy, dz))
	return v * VOXEL_SIZE


## Ruwe SDF-waarde (voxels; negatief = rots) van de dichtstbijzijnde voxel. Voor tests.
func debug_sdf(world: Vector3) -> float:
	return _tool.get_voxel_f(Vector3i(_terrain.to_local(world).round()))


## Hoe diep een punt in de rots zat bij het genereren (meter; negatief = lucht).
## Puur uit de seed, dus op elke peer gelijk; bewerkingen tellen niet mee.
func generated_rock_depth(world: Vector3) -> float:
	return -_generator.sdf_at(world / VOXEL_SIZE) * VOXEL_SIZE


func layer_at(world: Vector3) -> Strata.Layer:
	return Strata.layer_at(world, pit_seed)


func surface_height_at(world_x: float, world_z: float) -> float:
	return _generator.surface_at(world_x / VOXEL_SIZE, world_z / VOXEL_SIZE) * VOXEL_SIZE


func world_size() -> Vector3:
	return Vector3(dims) * VOXEL_SIZE


func shaft_center_world() -> Vector3:
	return Vector3(_generator.shaft_center.x, 0.0, _generator.shaft_center.y) * VOXEL_SIZE


## Plek op het oppervlak naast de liftschacht.
func spawn_point() -> Vector3:
	var p := shaft_center_world() + Vector3(-(_generator.shaft_radius * VOXEL_SIZE + 4.0), 0.0, 0.0)
	p.y = surface_height_at(p.x, p.z) + 1.0
	return p


## Straal tegen het terrein (en optioneel andere lagen, zie Layers).
## Zelfde resultaat als PhysicsDirectSpaceState3D.intersect_ray.
func raycast(from: Vector3, to: Vector3, mask := COLLISION_LAYER) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(query)


func get_stats() -> Dictionary:
	return {
		"terrain": _terrain.get_statistics(),
		"engine": VoxelEngine.get_stats(),
		"ops_applied": ops_applied_total,
		"mem_static_mb": OS.get_static_memory_usage() / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}


# --- Intern -------------------------------------------------------------------

func _op_reach(op: Dictionary) -> float:
	match op.op:
		Op.CHIP:
			return maxf(op.rt, op.rd) + op.amp
	return op.r


## Schilfer: max(huidig, -kwast) met een eigen kwast via copy/paste van het SDF-kanaal.
func _apply_chip(op: Dictionary) -> void:
	var c: Vector3 = op.c
	var n: Vector3 = op.n
	var rt: float = op.rt
	var rd: float = op.rd
	var amp: float = op.amp
	var ext := maxf(rt, rd) + amp + 2.0
	var origin := Vector3i((c - Vector3.ONE * ext).floor())
	var size := int(ceil(ext * 2.0)) + 1
	var buf := VoxelBuffer.new()
	buf.create(size, size, size)
	_tool.copy(origin, buf, SDF_BIT, false)
	var t1 := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := n.cross(t1)
	var k := minf(rt, rd)
	var sdf := VoxelBuffer.CHANNEL_SDF
	for z in size:
		for y in size:
			for x in size:
				var p := Vector3(origin.x + x, origin.y + y, origin.z + z)
				var d := p - c
				var q := Vector3(d.dot(t1) / rt, d.dot(t2) / rt, d.dot(n) / rd)
				var brush := (q.length() - 1.0) * k + amp * _brush_noise.get_noise_3dv(p)
				var cur := buf.get_voxel_f(x, y, z, sdf)
				if -brush > cur:
					buf.set_voxel_f(-brush, x, y, z, sdf)
	_tool.paste(origin, buf, SDF_BIT)


## Houdt de bol weg van de buitenmuur en de bodem, zodat niemand uit de put graaft.
func _clamp_center(c: Vector3, r: float) -> Vector3:
	var m := _generator.wall + 0.5 + r
	c.x = clampf(c.x, m, dims.x - 1 - m)
	c.z = clampf(c.z, m, dims.z - 1 - m)
	c.y = maxf(c.y, m)
	return c


func _take_token(player_id: int) -> bool:
	var rate: float = Tuning.get_f("dig", "max_ops_per_second", 8.0)
	var burst: float = Tuning.get_f("dig", "burst", 3.0)
	var now := Time.get_ticks_usec() / 1000000.0
	# Array i.p.v. Vector2: Vector2 is 32-bit en de afronding van `now` kan een token doen verdwijnen.
	var bucket: Array = _buckets.get(player_id, [burst, now])
	var tokens := minf(burst, float(bucket[0]) + maxf(0.0, now - float(bucket[1])) * rate)
	if tokens < 1.0:
		_buckets[player_id] = [tokens, now]
		return false
	_buckets[player_id] = [tokens - 1.0, now]
	return true


## Buit in de buurt van een graafactie wakker maken, anders zweeft ze boven een gat.
func _wake_bodies(world_center: Vector3, radius_m: float) -> void:
	_wake_shape.radius = radius_m + Tuning.get_f("dig", "wake_radius_extra", 1.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _wake_shape
	query.transform = Transform3D(Basis(), world_center)
	query.collision_mask = ~COLLISION_LAYER
	var impulse := Tuning.get_f("dig", "wake_impulse", 0.15)
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body := hit.collider as RigidBody3D
		if body and body.sleeping:
			body.sleeping = false
			body.apply_central_impulse(Vector3.UP * impulse * body.mass)


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/terrain/terrain.gdshader")
	mat.set_shader_parameter("seed_f", float(pit_seed))
	mat.set_shader_parameter("top_kristal", Strata.TOPS_M[0])
	mat.set_shader_parameter("top_graniet", Strata.TOPS_M[1])
	mat.set_shader_parameter("top_zandsteen", Strata.TOPS_M[2])
	return mat
