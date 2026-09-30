class_name TerrainSync
extends Node
## Graafacties over het netwerk (GDD §9, docs/research/graven.md).
## - Elke op is max-semantiek (commutatief, idempotent): volgorde en dubbels maken niet uit.
## - Client: past zijn eigen op meteen toe (voorspelling) en stuurt ze naar de host.
## - Host: valideert (snelheid, afstand, gereedschap tegenover laag), past toe en stuurt door.
## - Ops die binnenkomen voor het terrein bestaat (tijdens het laden), worden gebufferd.
## Staat op elk peer op hetzelfde pad (Game/TerrainSync) zodat RPC's aankomen.

signal remote_op_applied(op: Dictionary)

const MAX_OP_DISTANCE := 6.0 # meter tussen speler en op-centrum (bereik + marge voor vertraging)

var game: Node # Game
var rejected_ops := 0
var _pending: Array[Dictionary] = []


func terrain() -> TerrainAPI:
	return game.terrain


## Houweelslag van de lokale speler. False als het gereedschap te zwak is of de
## snelheidslimiet weigert (dan wordt er ook niets voorspeld).
func submit_chip(world_hit: Vector3, normal: Vector3, radius_m: float, depth_m: float,
		rough_m: float, tool: Strata.Tool) -> bool:
	var t := terrain()
	var op := t.make_chip_op(Net.my_id(), world_hit, normal, radius_m, depth_m, rough_m)
	op["tool"] = tool
	if not tool_allows(op) or not t.take_token(Net.my_id()):
		return false
	t.apply_op(op)
	if Net.is_host():
		_broadcast(op, Net.my_id())
	else:
		_rpc_submit.rpc_id(1, op)
	return true


## Boorstreep of andere bol-op van de lokale speler.
func submit_sphere(world_center: Vector3, radius_m: float, tool: Strata.Tool) -> bool:
	var t := terrain()
	var op := t.make_sphere_op(Net.my_id(), world_center, radius_m)
	op["tool"] = tool
	if not tool_allows(op) or not t.take_token(Net.my_id()):
		return false
	t.apply_op(op)
	if Net.is_host():
		_broadcast(op, Net.my_id())
	else:
		_rpc_submit.rpc_id(1, op)
	return true


## Host: een op van het spel zelf (geen speler), bv. ruimte rond een vrijgekomen vondst.
func host_apply(op: Dictionary) -> void:
	assert(multiplayer.is_server())
	op["tool"] = -1
	terrain().apply_op(op)
	_broadcast(op, multiplayer.get_unique_id())


## Zelfde controle op client (voor de voorspelling) en host (validatie). Verschillen ze,
## dan lopen de werelden uiteen: terrein wegnemen kan niet teruggedraaid worden.
func tool_allows(op: Dictionary) -> bool:
	var t := terrain()
	var probe: Vector3 = op.get("h", t.op_world_center(op))
	if op.op == TerrainAPI.Op.CHIP:
		probe -= (op.n as Vector3) * 0.2
	return Strata.can_dig(t.layer_at(probe), op.tool)


## Wordt door Game aangeroepen zodra het terrein bestaat.
func flush_pending() -> void:
	for op in _pending:
		terrain().apply_op(op)
	_pending.clear()


@rpc("any_peer", "reliable")
func _rpc_submit(op: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	op["p"] = sender
	var reason := _validate(sender, op)
	if reason != "":
		rejected_ops += 1
		print("[terrain_sync] op van peer %d geweigerd: %s" % [sender, reason])
		return
	terrain().apply_op(op)
	remote_op_applied.emit(op)
	_broadcast(op, sender)


@rpc("authority", "reliable")
func _rpc_apply(op: Dictionary) -> void:
	if game.terrain == null:
		_pending.append(op)
		return
	terrain().apply_op(op)
	remote_op_applied.emit(op)


func _broadcast(op: Dictionary, except_peer: int) -> void:
	for id in multiplayer.get_peers():
		if id != except_peer:
			_rpc_apply.rpc_id(id, op)


## Lege string = goed. De client doet dezelfde controles lokaal, dus weigeren is zeldzaam
## (en kan niet teruggedraaid worden: terrein wegnemen is definitief).
func _validate(sender: int, op: Dictionary) -> String:
	var t := terrain()
	if not op.has_all(["op", "c", "tool"]):
		return "onvolledige op"
	if not t.take_token(sender):
		return "te snel"
	var player: Node3D = game.player_node(sender)
	if player == null:
		return "geen speler"
	var center := t.op_world_center(op)
	if center.distance_to(player.global_position) > MAX_OP_DISTANCE:
		return "te ver (%.1f m)" % center.distance_to(player.global_position)
	if not tool_allows(op):
		return "gereedschap te zwak"
	return ""
