extends Node
## Nettest (M1 stap 1-2). Draait op host én client; start beide via tools/net_test.py.
## Client: verplaatst zijn speler, doet 6 houweelslagen via TerrainSync, meldt dan zijn
## positie en terrein-checksum aan de host. Host: vergelijkt met wat hij zelf ziet.
## Naam van deze node is "Scenario" op elke peer, zodat de RPC's aankomen.

const TIMEOUT_S := 90.0
const CHIPS := 6
const DRILL_BITES := 4

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(_on_player_spawned)
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		print("[net_test] GEFAALD: time-out na %.0f s" % TIMEOUT_S)
		get_tree().quit(1))


func _on_player_spawned(p: Player) -> void:
	if p.is_local and not Net.is_host():
		_run_client.call_deferred(p)
	elif p.is_local and Net.is_host():
		# Graven voor de client er is: moet via het op-logboek (wereld-init) aankomen.
		_host_chips.call_deferred(p, 4, Vector3(0, 0, 0))
	elif Net.is_host():
		# Graven terwijl de client nog laadt: moet bij de client gebufferd worden.
		_host_chips.call_deferred(main.game.local_player, 3, Vector3(0, 0, 1.2))
		# Tuning van de host moet bij de client aankomen.
		Tuning.set_value("carry", "throw_speed", 7.25)


func _host_chips(p: Player, count: int, offset: Vector3) -> void:
	var t: TerrainAPI = main.terrain
	for i in count:
		var probe := p.global_position + offset + Vector3(1.2, 1.5, -0.8 + i * 0.5)
		var hit := t.raycast(probe, probe - Vector3(0, 4, 0))
		if hit.is_empty():
			continue
		while not main.game.terrain_sync.submit_chip(hit.position, hit.normal, 0.75, 0.45, 0.14, Strata.Tool.HOUWEEL):
			await get_tree().physics_frame
	print("[net_test] host: %d slagen gedaan" % count)


func _run_client(p: Player) -> void:
	var t: TerrainAPI = main.terrain
	await _frames(30)
	var target := p.global_position + Vector3(0, 0, 2.0)
	target.y = t.surface_height_at(target.x, target.z) + 0.2
	p.global_position = target
	await get_tree().create_timer(1.0).timeout

	var done := 0
	for i in CHIPS:
		var probe := p.global_position + Vector3(-1.0 + i * 0.4, 1.5, -1.2)
		var hit := t.raycast(probe, probe - Vector3(0, 4, 0))
		if hit.is_empty():
			continue
		while not main.game.terrain_sync.submit_chip(hit.position, hit.normal, 0.75, 0.45, 0.14, Strata.Tool.HOUWEEL):
			await get_tree().physics_frame
		done += 1
	# Boor T1: 4 happen schuin in de vloer.
	var drilled := 0
	for i in 4:
		var probe := p.global_position + Vector3(1.0, 1.2, 0.2 * i)
		var hit := t.raycast(probe, probe - Vector3(0, 4, 0))
		if hit.is_empty():
			continue
		while not main.game.terrain_sync.submit_sphere(hit.position + Vector3(0, 0.65, 0), 0.8, Strata.Tool.BOOR_T1):
			await get_tree().physics_frame
		drilled += 1
	# Houweel in zandsteen: moet lokaal al geweigerd worden (geen voorspelling, geen desync).
	var sand := Vector3(p.global_position.x, 100.0, p.global_position.z)
	var refused: bool = not main.game.terrain_sync.submit_chip(sand, Vector3.UP, 0.75, 0.45, 0.14, Strata.Tool.HOUWEEL)
	print("[net_test] client: %d boorhappen, houweel in zandsteen geweigerd: %s" % [drilled, refused])
	done += drilled if refused else -100
	# Vondst 3 uitbikken (client meldt, host beslist, iedereen ziet hem vrijkomen).
	var finds: FindField = main.game.finds
	var it := finds.items[3]
	var back := p.global_position
	p.set_physics_process(false)
	p.global_position = it.global_position + Vector3(0, 0.3, 1.2)
	await get_tree().create_timer(0.6).timeout
	for i in 4:
		finds.hit_crust(it.find_id, Strata.Tool.HOUWEEL, it.global_position)
		await get_tree().create_timer(0.35).timeout
	# Oppakken, 2 m verder neerzetten.
	await get_tree().create_timer(1.0).timeout
	p.global_position = it.global_position + Vector3(0, -0.2, 1.3)
	p.look_at(it.global_position)
	await get_tree().create_timer(0.3).timeout
	finds.request_grab(it.find_id)
	await get_tree().create_timer(0.5).timeout
	var carried := p.carry.item == it
	p.global_position += Vector3(2.0, 0, 0)
	await get_tree().create_timer(0.6).timeout
	p.carry.drop(false)
	print("[net_test] client: vondst gedragen: %s" % carried)
	p.global_position = back
	p.set_physics_process(true)
	# Lift: 12 m omlaag sturen (de spawn ligt binnen roepafstand van de schacht).
	var lift: Lift = main.game.lift
	await get_tree().create_timer(0.5).timeout # host ziet ons pas 100 ms later terug bij de schacht
	lift.request(Lift.Command.DOWN, p)
	await get_tree().create_timer(6.0).timeout
	_rpc_lift_report.rpc_id(1, lift.y)
	_rpc_tuning_report.rpc_id(1, Tuning.get_f("carry", "throw_speed", 0.0))
	var sum := t.checksum()
	print("[net_test] client: %d slagen, vondst vrij: %s, checksum %s" % [done, it.freed, sum])
	_rpc_report.rpc_id(1, sum, p.global_position, done)
	_rpc_find_report.rpc_id(1, it.find_id, it.freed, it.global_position)


@rpc("any_peer", "reliable")
func _rpc_tuning_report(client_value: float) -> void:
	if multiplayer.is_server():
		_expect(is_equal_approx(client_value, 7.25), "tuning van de host kwam aan bij de client (%.2f)" % client_value)


@rpc("any_peer", "reliable")
func _rpc_lift_report(client_y: float) -> void:
	if not multiplayer.is_server():
		return
	var lift: Lift = main.game.lift
	var expect := lift.top_y - Tuning.get_f("lift", "step_down", 12.0)
	_expect(absf(lift.y - expect) < 0.01 and absf(client_y - lift.y) < 0.05,
			"lift 12 m omlaag, zelfde hoogte bij host en client (host %.2f, client %.2f)" % [lift.y, client_y])


@rpc("any_peer", "reliable")
func _rpc_find_report(id: int, freed: bool, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var it: FindItem = main.game.finds.items[id]
	_expect(freed and it.freed, "vondst %d vrij bij client en host" % id)
	var d := it.global_position.distance_to(pos)
	_expect(d < 0.3, "vondst ligt bij client en host op dezelfde plek (%.2f m verschil)" % d)


@rpc("any_peer", "reliable")
func _rpc_report(client_sum: String, client_pos: Vector3, chips: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	await _frames(10) # ops van dezelfde reliable-stroom zijn toegepast in de volgende ticks
	var t: TerrainAPI = main.terrain
	var host_sum := t.checksum()
	var remote: Player = main.game.player_node(sender)
	var from_sender := t.op_log().filter(func(op: Dictionary) -> bool: return op.p == sender).size()
	_expect(chips == CHIPS + DRILL_BITES, "client deed %d/%d slagen + boorhappen (en weigerde houweel in zandsteen)" % [chips, CHIPS + DRILL_BITES])
	_expect(from_sender == chips, "host paste %d ops van de client toe" % from_sender)
	_expect(main.game.terrain_sync.rejected_ops == 0, "geen geweigerde ops (%d)" % main.game.terrain_sync.rejected_ops)
	_expect(host_sum == client_sum, "terrein-checksum gelijk (host %s, client %s)" % [host_sum.left(8), client_sum.left(8)])
	_expect(remote != null, "host ziet de speler van de client")
	if remote:
		var d: float = remote.global_position.distance_to(client_pos)
		_expect(d < 0.3, "positie van de client klopt bij de host (%.2f m verschil)" % d)
	_expect(main.game.players.get_child_count() == 2, "2 spelers bij de host")
	_expect(t.op_log().size() == chips + 8, "host-logboek: 4 + 3 van de host, %d van de client, 1 om de vondst vrij te maken (%d)" % [chips, t.op_log().size()])
	var drill_ops := t.op_log().filter(func(op: Dictionary) -> bool: return op.get("tool", -1) == Strata.Tool.BOOR_T1).size()
	_expect(drill_ops == DRILL_BITES, "host paste %d boorhappen toe" % drill_ops)
	await _frames(20) # vondstrapport komt vlak na het terreinrapport
	var ok := _failures.is_empty()
	print("[net_test] host: %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if ok else "GEFAALD"])
	_rpc_finish.rpc(ok)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if ok else 1)


@rpc("authority", "reliable")
func _rpc_finish(ok: bool) -> void:
	print("[net_test] client: host meldt %s" % ("GESLAAGD" if ok else "GEFAALD"))
	get_tree().quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[net_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
