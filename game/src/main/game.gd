class_name Game
extends Node3D
## Een spelsessie: terrein, spelers en de sync ertussen.
## Staat op elk peer op hetzelfde pad (/root/Main/Game) zodat RPC's aankomen.
## Host (en solo): bouwt de wereld meteen. Client: vraagt de host om seed, op-logboek en
## de spelers die er al zijn; wie tijdens het laden graaft, komt via TerrainSync alsnog binnen.

signal world_loaded(stats: Dictionary)
signal player_spawned(player: Player)
signal player_removed(peer_id: int)

## Eigen kleur per speler (GDD §8).
const COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.12), # amber
	Color(0.2, 0.75, 0.95), # cyaan
	Color(0.55, 0.88, 0.25), # limoen
	Color(0.9, 0.35, 0.72), # magenta
]

var terrain: TerrainAPI
var terrain_sync: TerrainSync
var finds: FindField
var lift: Lift
var fx: DigFx
var players: Node3D
var local_player: Player
var pit_seed := 1
## Solo/host: ook een eigen speler spawnen. Uit voor scenario's zonder speler.
var spawn_host_player := true
var is_loaded := false
## Peers met een geladen wereld. Enkel die krijgen spelerstoestanden (anders "node not found").
var ready_peers: Array[int] = [1]

var _pending_spawns: Array = [] # client: spawns die binnenkomen voor het terrein geladen is
var _join_queue: Array[int] = [] # host: aanvragen voor de eigen wereld geladen is
var _color_of: Dictionary = {} # host: peer_id -> kleurindex
var _tuning_dirty := false
var _tuning_timer := 0.0


func _ready() -> void:
	fx = DigFx.new()
	fx.name = "DigFx"
	add_child(fx)
	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	terrain_sync = TerrainSync.new()
	terrain_sync.name = "TerrainSync"
	terrain_sync.game = self
	add_child(terrain_sync)
	terrain_sync.remote_op_applied.connect(_on_remote_op)
	finds = FindField.new()
	finds.name = "Finds"
	finds.game = self
	add_child(finds)
	Net.peer_left.connect(_on_peer_left)
	Tuning.changed.connect(func(_f: String, _k: String) -> void:
		if multiplayer.is_server():
			_tuning_dirty = true)


func start_host(seed_value: int) -> void:
	pit_seed = seed_value
	_build_terrain([])


func start_client() -> void:
	_rpc_request_join.rpc_id(1)


func player_node(peer_id: int) -> Player:
	return players.get_node_or_null(str(peer_id)) as Player


# --- Wereld -------------------------------------------------------------------

func _build_terrain(ops: Array, finds_state: Array = []) -> void:
	terrain = TerrainAPI.new()
	terrain.name = "Terrain"
	terrain.pit_seed = pit_seed
	add_child(terrain)
	finds.generate(pit_seed)
	finds.apply_snapshot(finds_state)
	lift = Lift.new()
	lift.name = "Lift"
	lift.game = self
	add_child(lift)
	lift.setup()
	for op in ops:
		terrain.apply_op(op)
	terrain_sync.flush_pending()
	terrain.loaded.connect(_on_terrain_loaded)


func _on_terrain_loaded(stats: Dictionary) -> void:
	is_loaded = true
	world_loaded.emit(stats)
	if Net.is_host():
		if spawn_host_player:
			_color_of[1] = 0
			_spawn(1, 0, _spawn_pos(0))
		for id in _join_queue:
			_accept(id)
		_join_queue.clear()
	for s in _pending_spawns:
		_spawn(s[0], s[1], s[2])
	_pending_spawns.clear()
	if not Net.is_host():
		_rpc_peer_ready.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_peer_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not ready_peers.has(id):
		ready_peers.append(id)
	for peer in multiplayer.get_peers():
		_rpc_set_ready_peers.rpc_id(peer, ready_peers)


@rpc("authority", "reliable")
func _rpc_set_ready_peers(peers: Array[int]) -> void:
	ready_peers = peers


# --- Binnenkomen en weggaan ---------------------------------------------------

@rpc("any_peer", "reliable")
func _rpc_request_join() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not is_loaded:
		_join_queue.append(id)
		return
	_accept(id)


func _accept(id: int) -> void:
	var existing: Array = []
	for p: Player in players.get_children():
		existing.append([p.peer_id, _color_of.get(p.peer_id, 0), p.global_position])
	_rpc_tuning.rpc_id(id, Tuning.snapshot())
	_rpc_world_init.rpc_id(id, pit_seed, terrain.op_log(), existing, finds.snapshot())
	lift.send_state(id)
	var idx := _free_color()
	_color_of[id] = idx
	var pos := _spawn_pos(idx)
	for peer in multiplayer.get_peers():
		_rpc_spawn.rpc_id(peer, id, idx, pos)
	_spawn(id, idx, pos)
	print("[game] peer %d binnen (kleur %d, %d ops in het logboek)" % [id, idx, terrain.op_log().size()])


@rpc("authority", "reliable")
func _rpc_world_init(seed_value: int, ops: Array, existing: Array, finds_state: Array) -> void:
	pit_seed = seed_value
	_pending_spawns.append_array(existing)
	_build_terrain(ops, finds_state)
	print("[game] wereld ontvangen: seed %d, %d ops, %d spelers" % [seed_value, ops.size(), existing.size()])


@rpc("authority", "reliable")
func _rpc_spawn(peer_id: int, color_idx: int, pos: Vector3) -> void:
	if not is_loaded:
		_pending_spawns.append([peer_id, color_idx, pos])
		return
	_spawn(peer_id, color_idx, pos)


@rpc("authority", "reliable")
func _rpc_despawn(peer_id: int) -> void:
	_despawn(peer_id)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_color_of.erase(id)
	ready_peers.erase(id)
	finds.drop_all_of(id)
	_despawn(id)
	for peer in multiplayer.get_peers():
		_rpc_despawn.rpc_id(peer, id)


func _spawn(peer_id: int, color_idx: int, pos: Vector3) -> void:
	if player_node(peer_id) != null:
		return
	var p := Player.new()
	p.name = str(peer_id)
	p.peer_id = peer_id
	p.color = COLORS[color_idx % COLORS.size()]
	p.game = self
	players.add_child(p)
	p.global_position = pos
	var target := terrain.shaft_center_world()
	target.y = pos.y
	p.look_at(target)
	p.rotation.x = 0.0
	if p.is_local:
		local_player = p
	player_spawned.emit(p)


func _despawn(peer_id: int) -> void:
	var p := player_node(peer_id)
	if p:
		p.queue_free()
		player_removed.emit(peer_id)


func _free_color() -> int:
	for i in COLORS.size():
		if not _color_of.values().has(i):
			return i
	return 0


## Rond de liftschacht, elke kleur een eigen kant.
func _spawn_pos(idx: int) -> Vector3:
	var sc := terrain.shaft_center_world()
	var ang := PI + idx * TAU / COLORS.size()
	var p := sc + Vector3(cos(ang), 0.0, sin(ang)) * 7.5
	p.y = terrain.surface_height_at(p.x, p.z) + 1.0
	return p


# --- Tuning van de host --------------------------------------------------------

func _process(delta: float) -> void:
	if not _tuning_dirty:
		return
	# Gebundeld: slepen aan een waarde geeft tientallen wijzigingen per seconde.
	_tuning_timer += delta
	if _tuning_timer < 0.3:
		return
	_tuning_timer = 0.0
	_tuning_dirty = false
	var snap := Tuning.snapshot()
	for peer in multiplayer.get_peers():
		_rpc_tuning.rpc_id(peer, snap)


@rpc("authority", "reliable")
func _rpc_tuning(snap: Dictionary) -> void:
	Tuning.apply_remote(snap)


# --- Effecten van anderen -----------------------------------------------------

func _on_remote_op(op: Dictionary) -> void:
	if not op.has("h"):
		return
	var pos: Vector3 = op.h
	var normal: Vector3 = op.get("n", Vector3.UP)
	var layer := terrain.layer_at(pos - normal * 0.2)
	if op.op == TerrainAPI.Op.CHIP:
		fx.impact(pos, normal, Strata.DEBRIS_COLORS[layer], 2)
	else:
		fx.grit_puff(pos, normal, Strata.DEBRIS_COLORS[layer])
