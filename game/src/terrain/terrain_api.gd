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
##
## Streaming (GDD v3): de planeet is te groot om helemaal geladen te zijn. Viewers op de spelers en
## de Mol (add_viewer) laden het terrein rond hen. Bewerkte blokken die ontladen worden, gaan naar een
## VoxelStreamMemory en komen zo terug. Een op voor gebied dat (nog) niet geladen is, wacht per
## datablok tot dat blok laadt (block_loaded) en wordt dan alsnog toegepast: zo ziet elke peer
## uiteindelijk hetzelfde, ook voor graafwerk ver van hem vandaan.

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
## Planeettype (PlanetType.Id): hoeveel kraters en rotsblokken de generator legt.
var planet := 0
## De grote landvorm rond het speelgebied (ook PlanetSurface gebruikt deze). Zijn vormen die het
## speelgebied binnenlopen, liggen ook in het voxelterrein (Landform.near_height).
var landform: Landform
## Raster (m) waarop near_height gebakken wordt: vormen van 10 m en meer, bilineair.
const NEAR_STEP := 3.0
@export var dims := Vector3i(500, 600, 500)
## Het spel kan beginnen zodra het gebied rond dit punt gemesht is (wereld, meter).
var focus_world := Vector3.ZERO
var focus_radius := 24.0

var is_loaded := false
var ops_applied_total := 0
var ops_applied_last_tick := 0

var _terrain: VoxelTerrain
var _tool: VoxelToolTerrain
var _generator: PlanetGenerator
var _queue: Array[Dictionary] = []
## Ops voor gebied dat nog niet geladen is: datablok van het centrum -> [op, ...].
var _waiting: Dictionary = {}
var _waiting_count := 0
var _sweep_timer := 0.0
## Toegepaste ops per datablok dat ze raken (om ze na een herlaadbeurt na te kijken).
var _op_blocks: Dictionary = {}
## Na te kijken: [op, blok, tijd tot wanneer]. Zie _verify.
var _verify_queue: Array = []
var _verify_timer := 0.0
## Hoe vaak een op opnieuw moest (voor tests en het infopaneel).
var ops_repaired := 0
var _block_size := 16
## [viewer, doel, afstand_m, collisions] van elke viewer (voor collision_ready).
var _viewers: Array = []
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

	var size_m := Vector2(dims.x, dims.z) * VOXEL_SIZE
	landform = Landform.create(clampi(planet, 0, 2) as PlanetType.Id)
	landform.setup(pit_seed, size_m * 0.5, size_m)
	_generator = PlanetGenerator.new()
	_generator.crater_count = [22, 6, 16][clampi(planet, 0, 2)]
	_generator.boulder_count = [70, 40, 60][clampi(planet, 0, 2)]
	_generator.planet = clampi(planet, 0, 2)
	_bake_near(_generator, size_m)
	_generator.setup(pit_seed, dims)

	_terrain = VoxelTerrain.new()
	_terrain.name = "VoxelTerrain"
	_terrain.scale = Vector3.ONE * VOXEL_SIZE
	_terrain.generator = _generator
	_terrain.mesher = VoxelMesherTransvoxel.new()
	_terrain.stream = VoxelStreamMemory.new()
	_terrain.bounds = AABB(Vector3.ZERO, Vector3(dims))
	_terrain.mesh_block_size = 16
	_terrain.max_view_distance = int(Tuning.get_f("terrain", "max_view_m", 160.0) / VOXEL_SIZE) # in voxels (gemeten), viewers in meter
	_terrain.generate_collisions = true
	_terrain.collision_layer = COLLISION_LAYER
	_terrain.collision_mask = 0
	_terrain.material_override = _make_material()
	add_child(_terrain)
	_block_size = _terrain.get_data_block_size()
	_terrain.block_loaded.connect(_on_block_loaded)

	_tool = _terrain.get_voxel_tool() as VoxelToolTerrain
	_tool.channel = VoxelBuffer.CHANNEL_SDF
	_tool.mode = VoxelTool.MODE_REMOVE
	_load_start_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	if is_loaded:
		return
	var elapsed_ms := (Time.get_ticks_usec() - _load_start_us) / 1000.0
	var meshed := is_area_ready(focus_world, focus_radius)
	if meshed or elapsed_ms > LOAD_TIMEOUT_MS:
		is_loaded = true
		var stats := get_stats()
		stats["load_ms"] = elapsed_ms
		stats["load_timed_out"] = not meshed
		loaded.emit(stats)


func _physics_process(delta: float) -> void:
	_tick += 1
	ops_applied_last_tick = 0
	# Vangnet: block_loaded komt soms net voor het blok bruikbaar is. Om de 0,5 s nakijken of de
	# blokken van wachtende ops er intussen zijn.
	_sweep_timer += delta
	if _sweep_timer > 0.5 and _waiting_count > 0:
		_sweep_timer = 0.0
		for key: Vector3i in _waiting.keys():
			if _terrain.has_data_block(key):
				_requeue(key)
	_verify_timer += delta
	if _verify_timer > 0.2 and not _verify_queue.is_empty():
		_verify_timer = 0.0
		_verify(Time.get_ticks_msec() / 1000.0)
	if _queue.is_empty():
		return
	for op in _queue:
		var c: Vector3 = op.c
		var reach := _op_reach(op)
		if not _editable(op):
			_wait_for_blocks(op)
			continue
		_write(op)
		_index_and_verify(op)
		ops_applied_last_tick += 1
		var world := _terrain.to_global(c)
		_wake_bodies(world, reach * VOXEL_SIZE)
		dug.emit(world, reach * VOXEL_SIZE)
		op_applied.emit(op)
	ops_applied_total += ops_applied_last_tick
	_queue.clear()


func _editable(op: Dictionary) -> bool:
	var c: Vector3 = op.c
	var reach := _op_reach(op)
	return _tool.is_area_editable(AABB(c - Vector3.ONE * (reach + 1.0), Vector3.ONE * (2.0 * reach + 2.0)))


func _write(op: Dictionary) -> void:
	var c: Vector3 = op.c
	match op.op:
		Op.SPHERE_REMOVE:
			_tool.do_sphere(c, op.r)
			if op.has("b"):
				var b: PackedFloat32Array = op.b
				for i in range(0, b.size() - 3, 4):
					_tool.do_sphere(Vector3(b[i], b[i + 1], b[i + 2]), b[i + 3])
		Op.CHIP:
			_apply_chip(op)


# --- Nakijken (godot_voxel kan bewerkingen vlak na het laden overschrijven) --------------------
#
# Een laadantwoord dat binnenkomt voor een blok dat al bestaat, overschrijft het blok volledig
# (VoxelTerrain::apply_data_block_response, try_set_block). Met viewers die overlappen (speler in
# de Mol) gebeurt dat af en toe vlak na het laden, en dan is een gat weg (gemeten: 1 op 4-6 keer).
# Ops zijn idempotent, dus: na het toepassen en na elk geladen blok enkele seconden nakijken of
# het gat er nog is (één voxel per op en blok), en zo niet, de op opnieuw toepassen.

const VERIFY_SECONDS := 4.0


func _index_and_verify(op: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() / 1000.0 + VERIFY_SECONDS
	for block: Vector3i in _blocks_of(op):
		if not _op_blocks.has(block):
			_op_blocks[block] = []
		(_op_blocks[block] as Array).append(op)
		_verify_queue.append([op, block, deadline])


func _blocks_of(op: Dictionary) -> Array[Vector3i]:
	var c: Vector3 = op.c
	var r := _op_core(op)
	var lo := _terrain.voxel_to_data_block(c - Vector3.ONE * r)
	var hi := _terrain.voxel_to_data_block(c + Vector3.ONE * r)
	var out: Array[Vector3i] = []
	for z in range(lo.z, hi.z + 1):
		for y in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				out.append(Vector3i(x, y, z))
	return out


## Straal (voxels) waarbinnen een op gegarandeerd lucht maakt.
func _op_core(op: Dictionary) -> float:
	if op.op == Op.CHIP:
		return minf(op.rt, op.rd) * 0.6
	return float(op.r) - 0.6


## Een voxel in `block` die na de op lucht moet zijn (zo dicht mogelijk bij het blok), of null.
func _sample_in(op: Dictionary, block: Vector3i) -> Variant:
	var c: Vector3 = op.c
	var r := _op_core(op)
	if r < 0.5:
		return null
	var lo := Vector3(block * _block_size)
	var nearest := c.clamp(lo, lo + Vector3.ONE * (_block_size - 1))
	var d := nearest - c
	if d.length() > r:
		nearest = c + d.normalized() * r
	var v := Vector3i(nearest.round())
	if v.x < block.x * _block_size or v.y < block.y * _block_size or v.z < block.z * _block_size:
		return null
	if v.x >= (block.x + 1) * _block_size or v.y >= (block.y + 1) * _block_size or v.z >= (block.z + 1) * _block_size:
		return null
	if Vector3(v).distance_to(c) > r:
		return null
	return v


func _verify(now: float) -> void:
	var keep: Array = []
	for e: Array in _verify_queue:
		if now > float(e[2]):
			continue
		var op: Dictionary = e[0]
		var block: Vector3i = e[1]
		if not _terrain.has_data_block(block):
			keep.append(e)
			continue
		var v: Variant = _sample_in(op, block)
		if v != null and _tool.get_voxel_f(v) < 0.0 and _editable(op):
			_write(op)
			ops_repaired += 1
		keep.append(e)
	_verify_queue = keep


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


## Past een bol helemaal in het graafbare deel (binnen de buitenmuur, boven de bodem)?
## Zo niet, dan schuift make_sphere_op hem naar binnen en blijft er rots staan aan de rand.
func sphere_fits(world_center: Vector3, radius_m: float) -> bool:
	var c := _terrain.to_local(world_center)
	return c.is_equal_approx(_clamp_center(c, radius_m / VOXEL_SIZE))


## Bol wegnemen rond `world_center`. Maakt enkel de op; toepassen met apply_op.
## Bol, optioneel met kleinere happen uit de wand (`bites`: [[wereldcentrum, straal_m], ...]) voor een
## ruwe, brokkelige tunnelwand. De happen zitten in de op zelf, zodat elke peer exact hetzelfde toepast.
func make_sphere_op(player_id: int, world_center: Vector3, radius_m: float, bites: Array = []) -> Dictionary:
	var r := radius_m / VOXEL_SIZE
	var c := _clamp_center(_terrain.to_local(world_center), r)
	var op := {"op": Op.SPHERE_REMOVE, "c": c, "r": r, "h": world_center, "tick": _tick, "p": player_id}
	if not bites.is_empty():
		var b := PackedFloat32Array()
		for bite: Array in bites:
			var br: float = float(bite[1]) / VOXEL_SIZE
			var bc := _clamp_center(_terrain.to_local(bite[0]), br)
			b.append_array([bc.x, bc.y, bc.z, br])
		op["b"] = b
	return op


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
	# In het logboek bij ontvangst, niet pas bij toepassen: een op die wacht op een blok dat
	# deze peer nooit laadt, moet toch mee naar wie later binnenkomt.
	_op_log.append(op)
	_queue.append(op)


## Wereldpositie van het centrum van een op, voor validatie (afstand tot de speler).
func op_world_center(op: Dictionary) -> Vector3:
	return _terrain.to_global(op.c)


## Graven zonder snelheidslimiet, voor tests en scenario's.
func debug_dig(world_center: Vector3, radius_m: float) -> void:
	apply_op(make_sphere_op(0, world_center, radius_m))


## Snelheidslimiet per speler (token bucket, dig.max_ops_per_second en dig.burst).
## `lenient`: voor de host die ops van een client valideert. De client houdt zich al aan de
## gewone limiet en heeft zijn op al voorspeld (niet terug te draaien); door schommelingen in het
## netwerk komen ops soms gebundeld binnen. De host kijkt dus ruimer (dig.host_slack ×).
func take_token(player_id: int, lenient := false) -> bool:
	return _take_token(player_id, Tuning.get_f("dig", "host_slack", 2.0) if lenient else 1.0)


## Checksum van het SDF-kanaal in een kubus rond `world_center` (half = halve zijde in meter).
## Twee peers met hetzelfde terrein in dat (geladen) gebied geven dezelfde waarde.
func checksum(world_center: Vector3, half_m := 32.0) -> String:
	var lo := Vector3i(_terrain.to_local(world_center - Vector3.ONE * half_m).floor()).clamp(Vector3i.ZERO, dims - Vector3i.ONE)
	var hi := Vector3i(_terrain.to_local(world_center + Vector3.ONE * half_m).ceil()).clamp(Vector3i.ZERO, dims)
	var size := (hi - lo).max(Vector3i.ONE)
	var buf := VoxelBuffer.new()
	buf.create(size.x, size.y, size.z)
	_tool.copy(lo, buf, SDF_BIT, false)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(buf.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF))
	return ctx.finish().hex_encode()


func op_log() -> Array[Dictionary]:
	return _op_log


func queued_ops() -> int:
	return _queue.size()


## Ops die wachten tot hun gebied geladen is (ver van elke viewer).
func waiting_ops() -> int:
	return _waiting_count


# --- Streaming ------------------------------------------------------------------

## Laadt het terrein rond `target` zolang die bestaat. `distance_m`: straal voor beeld (en data);
## `collision_m`: straal waarbinnen ook collision gebouwd wordt (0 = geen). Twee viewers, omdat
## collision bouwen het duurste is (hoofdthread) en enkel dichtbij nodig is.
func add_viewer(target: Node3D, distance_m: float, collision_m := 0.0) -> void:
	# Een nieuwe wereld (nieuwe dienst) houdt de doelen: oude viewers eerst weg.
	for n in ["TerrainViewer", "TerrainCollisionViewer"]:
		var old := target.get_node_or_null(n)
		if old:
			target.remove_child(old)
			old.queue_free()
	var visual := VoxelViewer.new()
	visual.name = "TerrainViewer"
	visual.view_distance = int(distance_m) # wereldeenheden (meter), niet voxels: gemeten
	visual.view_distance_vertical_ratio = Tuning.get_f("terrain", "vertical_ratio", 0.75)
	visual.requires_collisions = false
	target.add_child(visual)
	_viewers.append([visual, target, distance_m, false])
	if collision_m > 0.0:
		var coll := VoxelViewer.new()
		coll.name = "TerrainCollisionViewer"
		coll.view_distance = int(collision_m)
		coll.requires_visuals = false
		coll.requires_collisions = true
		target.add_child(coll)
		_viewers.append([coll, target, collision_m, true])


## Is het gebied rond een punt geladen en gemesht (te zien, en met collision als een
## collision-viewer in de buurt is)?
func is_area_ready(world_center: Vector3, radius_m: float) -> bool:
	var c := _terrain.to_local(world_center)
	var r := radius_m / VOXEL_SIZE
	var box := AABB(c - Vector3.ONE * r, Vector3.ONE * r * 2.0).intersection(AABB(Vector3.ZERO, Vector3(dims)))
	return box.size != Vector3.ZERO and _terrain.is_area_meshed(box)


## Het materiaal van het terrein (ook voor het verre landschap, zodat het naadloos aansluit).
func terrain_material() -> ShaderMaterial:
	return _terrain.material_override as ShaderMaterial


## Erts vlak achter de wand laten glinsteren (OreField geeft de dichtstbijzijnde clusters).
func set_ore_glints(points: Array[Vector4]) -> void:
	var mat := _terrain.material_override as ShaderMaterial
	var arr := PackedVector4Array(points)
	arr.resize(16)
	mat.set_shader_parameter("ore_points", arr)
	mat.set_shader_parameter("ore_count", mini(points.size(), 16))


## Onstabiele zones (Unrest) in de rotsshader tekenen: barsten en stof waar ze de wand raken.
func set_hazard_zones(zones: Array[Vector4]) -> void:
	var mat := _terrain.material_override as ShaderMaterial
	var arr := PackedVector4Array(zones)
	arr.resize(16)
	mat.set_shader_parameter("hazard_zones", arr)
	mat.set_shader_parameter("hazard_count", mini(zones.size(), 16))


## Grotten (wereld): xyz = midden, w = horizontale straal; hoogte = w / PlanetGenerator.CAVERN_SQUASH.
func caverns() -> Array[Vector4]:
	return _generator.caverns_world(VOXEL_SIZE)


## Is de voxeldata rond dit punt geladen (los van meshes en collision)?
func data_loaded(world: Vector3) -> bool:
	return _terrain.has_data_block(_terrain.voxel_to_data_block(_terrain.to_local(world)))


## Staat er collision onder dit punt? (Binnen het bereik van een collision-viewer en gemesht.)
## Losse buit ver van iedereen bevriest de host, anders valt hij door de wereld.
func collision_ready(world: Vector3) -> bool:
	# Boven de rots (De Ekster, in de lucht) is er geen terrein om op te wachten.
	if world.y > float(dims.y) * VOXEL_SIZE + 2.0:
		return true
	for v: Array in _viewers:
		if not v[3] or not is_instance_valid(v[1]):
			continue
		if (v[1] as Node3D).global_position.distance_to(world) < float(v[2]) - 6.0:
			return is_area_ready(world, 2.0)
	return false


func _wait_for_blocks(op: Dictionary) -> void:
	var key := _terrain.voxel_to_data_block(op.c)
	if not _waiting.has(key):
		_waiting[key] = []
	(_waiting[key] as Array).append(op)
	_waiting_count += 1


## Een datablok is geladen: ops die erop wachtten (centrum in dit blok of ernaast) opnieuw proberen.
func _on_block_loaded(block: Vector3i) -> void:
	# Een (opnieuw) geladen blok: ops die erin gegraven hebben nakijken (stream of overschreven).
	if _op_blocks.has(block):
		var deadline := Time.get_ticks_msec() / 1000.0 + VERIFY_SECONDS
		for op: Dictionary in _op_blocks[block]:
			_verify_queue.append([op, block, deadline])
	if _waiting_count == 0:
		return
	for dz in range(-1, 2):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var key := block + Vector3i(dx, dy, dz)
				if _waiting.has(key):
					_requeue(key)


func _requeue(key: Vector3i) -> void:
	var ops: Array = _waiting[key]
	_waiting.erase(key)
	_waiting_count -= ops.size()
	for op: Dictionary in ops:
		_queue.append(op)


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


## Grotten van de generator in wereldruimte: x, y, z = midden, w = horizontale straal (meter).
## Verticaal is een grot CAVERN_SQUASH keer platter.
func caves() -> Array[Vector4]:
	var out: Array[Vector4] = []
	for c in _generator._caverns:
		out.append(c * VOXEL_SIZE)
	return out


func layer_at(world: Vector3) -> Strata.Layer:
	return Strata.layer_at(world, pit_seed)


## De vormen van de landvorm die het speelgebied binnenlopen, op een raster voor de generator (in
## voxels). Tot FADE_IN.y buiten de rand: daar neemt Landform.height het over (PlanetSurface).
func _bake_near(g: PlanetGenerator, size_m: Vector2) -> void:
	if not landform.has_near():
		return
	var t0 := Time.get_ticks_usec()
	var margin := Landform.FADE_IN.y + NEAR_STEP
	var nx := int(ceil((size_m.x + margin * 2.0) / NEAR_STEP)) + 1
	var nz := int(ceil((size_m.y + margin * 2.0) / NEAR_STEP)) + 1
	var vals := PackedFloat32Array()
	vals.resize(nx * nz)
	for j in nz:
		var z := -margin + j * NEAR_STEP
		var dz := maxf(maxf(-z, z - size_m.y), 0.0)
		for i in nx:
			var x := -margin + i * NEAR_STEP
			var dx := maxf(maxf(-x, x - size_m.x), 0.0)
			var k := 1.0 - Landform.fade_in(sqrt(dx * dx + dz * dz))
			vals[j * nx + i] = landform.near_height(x, z) * k / VOXEL_SIZE if k > 0.0 else 0.0
	g.near = vals
	g.near_origin = Vector2(-margin, -margin) / VOXEL_SIZE
	g.near_step = NEAR_STEP / VOXEL_SIZE
	g.near_nx = nx
	g.near_nz = nz
	print("[terrain] vormen van de landvorm in het speelgebied: %d×%d punten in %d ms" % [nx, nz, (Time.get_ticks_usec() - t0) / 1000])


func surface_height_at(world_x: float, world_z: float) -> float:
	return _generator.surface_at(world_x / VOXEL_SIZE, world_z / VOXEL_SIZE) * VOXEL_SIZE


func world_size() -> Vector3:
	return Vector3(dims) * VOXEL_SIZE


func shaft_center_world() -> Vector3:
	return Vector3(_generator.shaft_center.x, 0.0, _generator.shaft_center.y) * VOXEL_SIZE


## Plek op het oppervlak naast het midden van de put.
func spawn_point() -> Vector3:
	var p := shaft_center_world() + Vector3(-(_generator.shaft_radius * VOXEL_SIZE + 4.0), 0.0, 0.0)
	p.y = surface_height_at(p.x, p.z) + 1.0
	return p


## Straal tegen het terrein (en optioneel andere lagen, zie Layers).
## Zelfde resultaat als PhysicsDirectSpaceState3D.intersect_ray.
## Straal voor gereedschap: rots en korsten, maar de Mol houdt hem tegen (niet door zijn wand
## heen graven). Raakt hij eerst de Mol, dan is het resultaat leeg.
func tool_raycast(from: Vector3, to: Vector3) -> Dictionary:
	var hit := raycast(from, to, Layers.TERRAIN | Layers.CRUST | Layers.LIFT)
	if not hit.is_empty() and hit.collider is CollisionObject3D and (hit.collider as CollisionObject3D).collision_layer & Layers.LIFT:
		return {}
	return hit


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
	if op.has("b"):
		return op.r + 2.5 # happen op de wand steken tot ±1 m (2 voxels) verder
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


func _take_token(player_id: int, slack := 1.0) -> bool:
	var rate: float = Tuning.get_f("dig", "max_ops_per_second", 8.0) * slack
	var burst: float = Tuning.get_f("dig", "burst", 3.0) * slack + (slack - 1.0) * 2.0
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
	var ore_cols := PackedVector4Array()
	for c: Color in OreKinds.COLORS:
		var l := c.srgb_to_linear()
		ore_cols.append(Vector4(l.r, l.g, l.b, 1.0))
	mat.set_shader_parameter("ore_colors", ore_cols)
	# De ondergrond van deze planeet (kleuren, merklagen, gloed), en stof en puin in die kleuren.
	Underground.apply(mat, clampi(planet, 0, 2))
	Strata.DEBRIS_COLORS = Underground.debris_colors(clampi(planet, 0, 2))
	_set_surface_height(mat)
	return mat


## Hoogte van het oppervlak op een raster (SURF_TEX_STEP m) als textuur voor de rotsshader: zo
## weet hij hoe diep een punt onder zijn eigen oppervlak ligt (de korst is enkel de bovenste meter,
## daaronder de ondergrond). Puur uit de seed, zonder bewerkingen.
const SURF_TEX_STEP := 2.0


func _set_surface_height(mat: ShaderMaterial) -> void:
	var t0 := Time.get_ticks_usec()
	var size := world_size()
	var nx := int(ceil(size.x / SURF_TEX_STEP)) + 1
	var nz := int(ceil(size.z / SURF_TEX_STEP)) + 1
	var vals := PackedFloat32Array()
	vals.resize(nx * nz)
	for j in nz:
		for i in nx:
			vals[j * nx + i] = surface_height_at(i * SURF_TEX_STEP, j * SURF_TEX_STEP)
	var img := Image.create_from_data(nx, nz, false, Image.FORMAT_RF, vals.to_byte_array())
	mat.set_shader_parameter("surf_height", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("surf_height_rect", Vector4(SURF_TEX_STEP, nx, nz, 1.0))
	print("[terrain] hoogte van het oppervlak voor de shader: %d×%d in %d ms" % [nx, nz, (Time.get_ticks_usec() - t0) / 1000])
