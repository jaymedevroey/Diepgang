extends Node
## Nettest (M1 stap 1-2). Draait op host én client; start beide via tools/net_test.py.
## Client: verplaatst zijn speler, doet 6 houweelslagen via TerrainSync, meldt dan zijn
## positie en terrein-checksum aan de host. Host: vergelijkt met wat hij zelf ziet.
## Naam van deze node is "Scenario" op elke peer, zodat de RPC's aankomen.

const TIMEOUT_S := 240.0
const CHIPS := 6
const DRILL_BITES := 4
## Deze vondst schept de boorkop van de Mol op (bij de host), de client moet het zien.
const SCOOP_ID := 10
## Ertscluster (ader bij de landing) dat de client delft.
const ORE_ID := 2

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
	for i in 20: # tot hij vrij is (de korst heeft 7-13 levens, zie FindField.crust_hp_of)
		if it.freed:
			break
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
	# Erts: twee slagen op de ader bij de landing, dan storten in de trechter van de Mol.
	var ores: OreField = main.game.ores
	var oc := ores.clusters[ORE_ID]
	p.set_physics_process(false)
	p.global_position = oc.global_position + Vector3(0, 1.5, 0)
	await get_tree().create_timer(0.4).timeout
	for i in 2:
		ores.hit(ORE_ID, Strata.Tool.HOUWEEL, oc.global_position)
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(0.3).timeout
	var bag_after := OreField.units(ores.bag_of(p.peer_id))
	var mol_ore: Mol = main.game.mol
	p.global_position = mol_ore.chute_position() + mol_ore.body.global_basis.x * 1.0
	await get_tree().create_timer(0.6).timeout # de host moet ons eerst bij de trechter zien
	ores.deposit()
	# Met pakketverlies kan "zak leeg" na "laadruim" opnieuw verstuurd moeten worden: tot 2 s wachten.
	var deposit_deadline := Time.get_ticks_msec() + 2000
	await get_tree().create_timer(0.5).timeout
	while (OreField.units(ores.bag_of(p.peer_id)) != 0 or OreField.units(ores.hold) != 2) and Time.get_ticks_msec() < deposit_deadline:
		await get_tree().create_timer(0.1).timeout
	_rpc_ore_report.rpc_id(1, bag_after, OreField.units(ores.bag_of(p.peer_id)), OreField.units(ores.hold), oc.hp)
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
	await _team_carry(p)
	p.global_position = back
	await get_tree().create_timer(0.5).timeout
	_rpc_tuning_report.rpc_id(1, Tuning.get_f("carry", "throw_speed", 0.0))
	# Magma en een beving: de host beslist, de client ziet dezelfde klok en hetzelfde rotsplan.
	_rpc_please_quake.rpc_id(1)
	await get_tree().create_timer(1.5).timeout
	var u: Unrest = main.game.unrest
	var m: Magma = main.game.magma
	_rpc_quake_report.rpc_id(1, u.phase, u.stage, u._plan.size(), m.elapsed, m.quakes.size(), m.level)
	var sum := t.checksum(t.focus_world, 40.0) # rond de start: daar graven host en client, en rijdt de Mol
	print("[net_test] client: %d slagen, vondst vrij: %s, checksum %s" % [done, it.freed, sum])
	_rpc_report.rpc_id(1, sum, p.global_position, done)
	_rpc_find_report.rpc_id(1, it.find_id, it.freed, it.global_position)
	var sc := finds.items[SCOOP_ID]
	_rpc_scoop_report.rpc_id(1, sc.freed, sc.condition, mol.contains_point(sc.global_position), finds.crusts.has(SCOOP_ID))


# --- Samen dragen (F3, ontwerp-8) ----------------------------------------------------------

## Client: een titanschedel (28 kg) alleen slepen, dan draagt de host mee (twee dragers, getild en
## sneller), je kan niet ver van elkaar, en als de host loslaat, sleep je weer. Elke stap vergelijken host
## en client wat ze zien (zelfde regel aan beide kanten).
func _team_carry(p: Player) -> void:
	var finds: FindField = main.game.finds
	_rpc_please_heavy.rpc_id(1)
	await get_tree().create_timer(3.0).timeout
	var it := finds.item(_heavy_id)
	_expect(it != null and it.freed, "client: titanschedel %d vrij" % _heavy_id)
	if it == null:
		return
	p.set_physics_process(false)
	p.global_position = it.global_position + Vector3(2.0, -0.2, 0.0)
	p.look_at(it.global_position)
	p.rotation.x = 0.0
	await get_tree().create_timer(0.6).timeout # de host moet ons eerst daar zien
	finds.request_grab(it.find_id)
	await get_tree().create_timer(0.8).timeout
	var drag := Tuning.get_f("carry", "drag_speed", 0.33)
	var solo_ok: bool = p.carry.item == it and it.dragged() and is_equal_approx(p.carry.move_multiplier(), drag)
	print("[net_test] client: alleen sleept hij (%s, %.2f)" % [solo_ok, p.carry.move_multiplier()])
	_rpc_please_help.rpc_id(1, it.find_id)
	await get_tree().create_timer(1.5).timeout
	var team_mult: float = p.carry.move_multiplier()
	var team_ok: bool = it.carriers.size() == 2 and not it.dragged() and is_equal_approx(team_mult, Carry.speed_for(it.mass, 2))
	_rpc_team_report.rpc_id(1, solo_ok, team_ok, team_mult, it.global_position)
	await get_tree().create_timer(0.4).timeout
	# Weglopen: de vondst houdt je bij je maat.
	var host_p: Player = main.game.player_node(1)
	var away := p.global_position - host_p.global_position
	away.y = 0.0
	p.global_position += away.normalized() * 4.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Met vertraging schuift de host op ons scherm nog na (zijn eigen touw trekt hem naar ons toe, en
	# dat zien we pas 60+ ms later); pas meten als beide kanten stilstaan. Was 2 frames: 3,3 m bij 60 ms.
	await get_tree().create_timer(0.5).timeout
	# Golf 3 (gevoel2-03): het touw is de afstand tussen de twee handgrepen plus de armen (Carry.team_limit).
	var limit := Carry.team_limit(it)
	var span := Vector2(p.global_position.x - host_p.global_position.x, p.global_position.z - host_p.global_position.z).length()
	_rpc_leash_report.rpc_id(1, span, limit)
	await get_tree().create_timer(1.0).timeout # de host laat los
	var alone_again: bool = it.carriers.size() == 1 and it.dragged() and is_equal_approx(p.carry.move_multiplier(), drag)
	var carriers_now := it.carriers.size()
	p.carry.drop(false)
	await get_tree().create_timer(0.6).timeout
	_rpc_alone_report.rpc_id(1, alone_again, carriers_now)
	p.set_physics_process(true)


var _heavy_id := -1


## Host: een titanschedel naast de landingsplek, bij iedereen dezelfde (FindField._place met een vaste
## seed), dan een kamer eromheen en vrijmaken.
@rpc("any_peer", "reliable")
func _rpc_please_heavy() -> void:
	if not multiplayer.is_server():
		return
	var t: TerrainAPI = main.terrain
	var sp := t.spawn_point()
	var at := sp + Vector3(-9.0, 0.0, 6.0)
	at.y = t.surface_height_at(at.x, at.z) - 3.5
	_rpc_spawn_heavy.rpc(at)
	await get_tree().physics_frame
	var game: Game = main.game
	for dx in [-2.0, 0.0, 2.0, 4.0]:
		game.terrain_sync.host_apply(t.make_sphere_op(0, at + Vector3(dx, 0.4, 0.0), 2.4))
	await get_tree().create_timer(0.3).timeout
	game.finds._free(_heavy_id)


@rpc("authority", "call_local", "reliable")
func _rpc_spawn_heavy(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var it: FindItem = main.game.finds._place(rng, func() -> Array: return [at + Vector3(rng.randf_range(-0.5, 0.5), 0.0, 0.0), FindKinds.Kind.TITAN_SKULL], 20)
	_heavy_id = it.find_id if it else -1
	print("[net_test] titanschedel %d geplaatst" % _heavy_id)


## Host: de lokale speler van de host pakt de andere kant vast.
@rpc("any_peer", "reliable")
func _rpc_please_help(find_id: int) -> void:
	if not multiplayer.is_server():
		return
	var finds: FindField = main.game.finds
	var it := finds.item(find_id)
	var me: Player = main.game.local_player
	me.global_position = it.global_position + Vector3(-2.0, -0.2, 0.0)
	me.look_at(it.global_position)
	me.rotation.x = 0.0
	await get_tree().physics_frame
	finds.request_grab(find_id)


@rpc("any_peer", "reliable")
func _rpc_team_report(solo_ok: bool, team_ok: bool, team_mult: float, client_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var it: FindItem = main.game.finds.item(_heavy_id)
	var me: Player = main.game.local_player
	_expect(solo_ok, "samen dragen: alleen sleept de client de titanschedel (%d kg, aan %.2f)" % [int(FindKinds.MASSES[FindKinds.Kind.TITAN_SKULL]), Tuning.get_f("carry", "drag_speed", 0.33)])
	_expect(team_ok and it.carriers.size() == 2, "samen dragen: met twee getild, bij client en host (%d dragers)" % it.carriers.size())
	_expect(is_equal_approx(me.carry.move_multiplier(), team_mult), "samen dragen: host en client even snel (%.2f / %.2f)" % [me.carry.move_multiplier(), team_mult])
	_expect(it.global_position.distance_to(client_pos) < 0.6, "samen dragen: de schedel hangt bij host en client op dezelfde plek (%.2f m)" % it.global_position.distance_to(client_pos))


@rpc("any_peer", "reliable")
func _rpc_leash_report(span: float, limit: float) -> void:
	if not multiplayer.is_server():
		return
	_expect(span <= limit + 0.15, "samen dragen: de client kan niet weglopen van de host (%.1f m, max %.1f)" % [span, limit])
	main.game.local_player.carry.drop(false)


@rpc("any_peer", "reliable")
func _rpc_alone_report(alone_again: bool, carriers: int) -> void:
	if multiplayer.is_server():
		_expect(alone_again and carriers == 1, "samen dragen: host laat los, de client sleept weer alleen")


@rpc("any_peer", "reliable")
func _rpc_ore_report(bag_after_hits: int, bag_now: int, hold: int, cluster_hp: float) -> void:
	if not multiplayer.is_server():
		return
	var ores: OreField = main.game.ores
	var oc := ores.clusters[ORE_ID]
	_expect(bag_after_hits == 2, "client delfde 2 erts (zak %d)" % bag_after_hits)
	_expect(bag_now == 0 and OreField.units(ores.bag_of(multiplayer.get_remote_sender_id())) == 0, "client stortte zijn zak (bij client en host leeg)")
	_expect(hold == 2 and OreField.units(ores.hold) == 2, "2 erts in de Mol, bij client en host (%d / %d)" % [hold, OreField.units(ores.hold)])
	_expect(is_equal_approx(cluster_hp, oc.hp) and oc.hp == oc.max_hp - 2, "cluster heeft bij client en host dezelfde levens (%.0f)" % oc.hp)


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
func _rpc_please_quake() -> void:
	if multiplayer.is_server():
		Tuning.set_value("unrest", "min_gap_s", 0.0)
		main.game.unrest.value = 100.0


@rpc("any_peer", "reliable")
func _rpc_quake_report(phase: int, stage: int, plan_n: int, elapsed: float, quakes_n: int, level: float) -> void:
	if not multiplayer.is_server():
		return
	var u: Unrest = main.game.unrest
	var m: Magma = main.game.magma
	_expect(phase != Unrest.Phase.CALM and stage == u.stage and stage >= 1, "client beleeft dezelfde beving (%d / %d)" % [stage, u.stage])
	_expect(plan_n == u._plan.size(), "zelfde rotsplan bij client en host (%d / %d)" % [plan_n, u._plan.size()])
	_expect(absf(elapsed - m.elapsed) < 1.0, "magmaklok gelijk (%.2f s verschil)" % absf(elapsed - m.elapsed))
	_expect(quakes_n == m.quakes.size() and absf(level - m.level) < 0.1, "magma op dezelfde hoogte (%.2f m verschil)" % absf(level - m.level))


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
