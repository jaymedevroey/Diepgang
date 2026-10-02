extends Node
## Nettest (M1 stap 1-2). Draait op host én client; start beide via tools/net_test.py.
## Client: verplaatst zijn speler, doet 6 houweelslagen via TerrainSync, meldt dan zijn
## positie en terrein-checksum aan de host. Host: vergelijkt met wat hij zelf ziet.
## Naam van deze node is "Scenario" op elke peer, zodat de RPC's aankomen.

const TIMEOUT_S := 90.0
const CHIPS := 6
const DRILL_BITES := 4
## Deze vondst schept de boorkop van de Mol op (bij de host), de client moet het zien.
const SCOOP_ID := 10

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
	_rpc_please_scoop.rpc_id(1)
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
	# De Mol: instappen, plaatsnemen, klep dicht, 3 s vooruit rijden (de host simuleert).
	var mol: Mol = main.game.mol
	await get_tree().create_timer(0.5).timeout
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	await get_tree().create_timer(0.6).timeout # host moet ons eerst in de Mol zien
	mol.press(Mol.Cmd.SEAT)
	await get_tree().create_timer(0.6).timeout
	mol.press(Mol.Cmd.RAMP)
	await get_tree().create_timer(1.0).timeout
	var mol_start := mol.body.global_position
	Input.action_press("move_forward")
	await get_tree().create_timer(3.0).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(3.0).timeout
	_rpc_mol_report.rpc_id(1, mol.body.global_position, mol_start, p.global_position, p.seated, mol.ramp_open, mol.pilot)
	mol.leave_seat()
	await get_tree().create_timer(0.5).timeout
	p.global_position = back
	await get_tree().create_timer(0.8).timeout
	_rpc_tuning_report.rpc_id(1, Tuning.get_f("carry", "throw_speed", 0.0))
	var sum := t.checksum(t.focus_world, 40.0) # rond de start: daar graven host en client, en rijdt de Mol
	print("[net_test] client: %d slagen, vondst vrij: %s, checksum %s" % [done, it.freed, sum])
	_rpc_report.rpc_id(1, sum, p.global_position, done)
	_rpc_find_report.rpc_id(1, it.find_id, it.freed, it.global_position)
	var sc := finds.items[SCOOP_ID]
	_rpc_scoop_report.rpc_id(1, sc.freed, sc.condition, mol.contains_point(sc.global_position), finds.crusts.has(SCOOP_ID))


## Client is geladen: de host laat de boorkop een vondst opscheppen (zoals bij het boren).
@rpc("any_peer", "reliable")
func _rpc_please_scoop() -> void:
	if multiplayer.is_server():
		main.game.finds.host_mol_scoop(main.game.finds.items[SCOOP_ID], main.game.mol)


@rpc("any_peer", "reliable")
func _rpc_scoop_report(freed: bool, cond: float, in_mol: bool, has_crust: bool) -> void:
	if not multiplayer.is_server():
		return
	var it: FindItem = main.game.finds.items[SCOOP_ID]
	var mol: Mol = main.game.mol
	_expect(freed and it.freed and not has_crust and not main.game.finds.crusts.has(SCOOP_ID),
			"opgeschepte vondst %d: vrij en zonder korst bij client en host" % SCOOP_ID)
	_expect(is_equal_approx(cond, it.condition) and cond <= 0.31, "zelfde (lage) gaafheid bij client en host (%.2f)" % cond)
	_expect(in_mol and mol.contains_point(it.global_position), "opgeschepte vondst ligt in het laadruim, bij client en host")


@rpc("any_peer", "reliable")
func _rpc_tuning_report(client_value: float) -> void:
	if multiplayer.is_server():
		_expect(is_equal_approx(client_value, 7.25), "tuning van de host kwam aan bij de client (%.2f)" % client_value)


@rpc("any_peer", "reliable")
func _rpc_mol_report(client_mol: Vector3, client_start: Vector3, client_player: Vector3, seated: bool,
		client_ramp: bool, client_pilot: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var mol: Mol = main.game.mol
	var moved := (client_mol - client_start).length()
	_expect(client_pilot == sender and seated, "client zat aan het stuur (piloot %d)" % client_pilot)
	_expect(not mol.ramp_open and not client_ramp, "laadklep dicht op vraag van de client, bij host en client")
	_expect(moved > 4.0, "de client reed de Mol %.1f m vooruit" % moved)
	var d := mol.body.global_position.distance_to(client_mol)
	_expect(d < 0.3, "de Mol staat bij host en client op dezelfde plek (%.2f m verschil)" % d)
	var remote: Player = main.game.player_node(sender)
	_expect(remote != null and mol.contains_point(remote.global_position), "host ziet de piloot in de Mol zitten")
	if remote:
		var dp := remote.global_position.distance_to(client_player)
		_expect(dp < 0.4, "piloot bij host en client op dezelfde plek (%.2f m verschil)" % dp)


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
	var host_sum := t.checksum(t.focus_world, 40.0)
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
	var system_ops := t.op_log().filter(func(op: Dictionary) -> bool: return op.p == 0).size()
	_expect(t.op_log().size() - system_ops == chips + 7, "host-logboek: 4 + 3 van de host, %d van de client (%d)" % [chips, t.op_log().size() - system_ops])
	_expect(system_ops > 1, "systeem-ops: vondst vrijmaken en de boorkop van de Mol (%d)" % system_ops)
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
