class_name FindField
extends Node3D
## Alle vondsten van de put, met hun korst (GDD §3: uitbikken; §9: host simuleert buit).
## - Plaatsing volgt uit de seed: elke peer maakt dezelfde vondsten zonder netwerkverkeer.
## - Korsttreffers: de client meldt, de host beslist (levens, gaafheid) en verspreidt.
## - Korst kapot: de host graaft ruimte rond de vondst (terrein-op) en laat hem los.
## - Losse vondsten: de host simuleert, stuurt 20×/s posities; clients interpoleren.
## Staat op elk peer op Game/Finds zodat RPC's aankomen.

signal find_freed(item: FindItem)
signal crust_hit(item: FindItem, tool: Strata.Tool)

const SEND_INTERVAL := 0.05

var game: Node # Game
var items: Array[FindItem] = []
var crusts: Dictionary = {} # find_id -> Crust

var _last_hit: Dictionary = {} # host: peer_id -> tijd (s)
var _send_timer := 0.0


func generate(pit_seed: int) -> void:
	var t: TerrainAPI = game.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = pit_seed * 7919 + 11
	var count := Tuning.get_i("finds", "count", 36)
	var near := Tuning.get_i("finds", "near_spawn", 5)
	var spawn := t.spawn_point()
	var sc := t.shaft_center_world()
	var size := t.world_size()
	for i in count:
		var pos := Vector3.ZERO
		var ok := false
		for attempt in 60:
			if i < near:
				var ang := rng.randf() * TAU
				var d := rng.randf_range(2.5, 7.0)
				pos = spawn + Vector3(cos(ang), 0, sin(ang)) * d
				pos.y = t.surface_height_at(pos.x, pos.z) - rng.randf_range(1.3, 2.6)
			else:
				pos = Vector3(rng.randf_range(5.0, size.x - 5.0), 0, rng.randf_range(5.0, size.z - 5.0))
				pos.y = rng.randf_range(85.0, t.surface_height_at(pos.x, pos.z) - 2.0)
			var flat := Vector2(pos.x - sc.x, pos.z - sc.z).length()
			if flat > 6.0 and t.generated_rock_depth(pos) > 1.0 and _far_from_others(pos):
				ok = true
				break
		if not ok:
			continue
		var item := FindItem.new()
		item.setup(items.size(), FossilModel.pick_kind(rng))
		add_child(item)
		item.global_position = pos
		item.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		items.append(item)
		var crust := Crust.new()
		crust.name = "Crust%d" % item.find_id
		crust.setup(item.find_id, item.half_extents, Tuning.get_f("finds", "crust_hp", 4.0), float(item.find_id) * 3.7)
		add_child(crust)
		crust.global_transform = item.global_transform
		crusts[item.find_id] = crust
	print("[finds] %d vondsten geplaatst (seed %d)" % [items.size(), pit_seed])


func _far_from_others(pos: Vector3) -> bool:
	var min_gap := Tuning.get_f("finds", "min_spacing", 2.0)
	for other in items:
		if other.global_position.distance_to(pos) < min_gap:
			return false
	return true


func item(id: int) -> FindItem:
	return items[id] if id >= 0 and id < items.size() else null


# --- Korst raken --------------------------------------------------------------

## Lokaal gereedschap raakt een korst. Juice doet het gereedschap zelf meteen.
func hit_crust(find_id: int, tool: Strata.Tool, pos: Vector3) -> void:
	if Net.is_host():
		_apply_hit(Net.my_id(), find_id, tool, pos)
	else:
		_rpc_hit.rpc_id(1, find_id, tool, pos)


@rpc("any_peer", "reliable")
func _rpc_hit(find_id: int, tool: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_apply_hit(multiplayer.get_remote_sender_id(), find_id, tool, pos)


func _apply_hit(sender: int, find_id: int, tool: int, pos: Vector3) -> void:
	var it := item(find_id)
	var crust: Crust = crusts.get(find_id)
	if it == null or it.freed or crust == null:
		return
	var player: Node3D = game.player_node(sender)
	if player == null or player.global_position.distance_to(pos) > 4.5:
		return
	var drill := tool != Strata.Tool.HOUWEEL
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap := Tuning.get_f("finds", "drill_min_interval" if drill else "pickaxe_min_interval", 0.1)
	if now - float(_last_hit.get(sender, -100.0)) < min_gap:
		return
	_last_hit[sender] = now
	var hp := crust.hp - Tuning.get_f("finds", "drill_damage" if drill else "pickaxe_damage", 1.0)
	var cond := it.condition
	if drill:
		cond = maxf(Tuning.get_f("finds", "min_condition", 0.25), cond - Tuning.get_f("finds", "drill_condition_loss", 0.07))
	_rpc_state.rpc(find_id, hp, cond, tool)
	if hp <= 0.0:
		_free(find_id)


@rpc("authority", "call_local", "reliable")
func _rpc_state(find_id: int, hp: float, cond: float, tool: int) -> void:
	var it := item(find_id)
	if it == null:
		return
	it.condition = cond
	var crust: Crust = crusts.get(find_id)
	if crust:
		crust.set_hp(hp)
	crust_hit.emit(it, tool)


func _free(find_id: int) -> void:
	var it := item(find_id)
	var r := it.half_extents.length() + Tuning.get_f("finds", "free_margin", 0.35)
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, it.global_position, r))
	_rpc_freed.rpc(find_id)


@rpc("authority", "call_local", "reliable")
func _rpc_freed(find_id: int) -> void:
	var it := item(find_id)
	if it == null or it.freed:
		return
	it.freed = true
	var crust: Crust = crusts.get(find_id)
	if crust:
		game.fx.crust_break(crust.global_position, it.half_extents.length())
		crust.shatter()
		crusts.erase(find_id)
	it.celebrate()
	game.fx.play("ding", it.global_position, -2.0, 0.05)
	if multiplayer.is_server():
		it.freeze = false
		it.apply_central_impulse(Vector3.UP * Tuning.get_f("finds", "free_impulse", 1.2) * it.mass)
	find_freed.emit(it)


# --- Posities van losse vondsten ----------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or game == null:
		return
	_send_timer += delta
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0
	var ids := PackedInt32Array()
	var poses: Array = []
	for it in items:
		if it.freed and not it.sleeping:
			ids.append(it.find_id)
			poses.append(it.global_transform)
	if ids.is_empty():
		return
	for peer: int in game.ready_peers:
		if peer != multiplayer.get_unique_id():
			_rpc_poses.rpc_id(peer, ids, poses)


@rpc("authority", "unreliable_ordered")
func _rpc_poses(ids: PackedInt32Array, poses: Array) -> void:
	for i in ids.size():
		var it := item(ids[i])
		if it:
			it.push_snapshot(poses[i])


# --- Late joiners ------------------------------------------------------------

func snapshot() -> Array:
	var out: Array = []
	for it in items:
		var crust: Crust = crusts.get(it.find_id)
		out.append([it.find_id, crust.hp if crust else 0.0, it.condition, it.freed, it.global_transform])
	return out


func apply_snapshot(state: Array) -> void:
	for s in state:
		var it := item(s[0])
		if it == null:
			continue
		it.condition = s[2]
		var crust: Crust = crusts.get(it.find_id)
		if s[3]:
			it.freed = true
			it.global_transform = s[4]
			it.push_snapshot(s[4])
			if crust:
				crust.shatter()
				crusts.erase(it.find_id)
		elif crust:
			crust.set_hp(s[1])
