extends Node
## Co-op test van de dreiging (pakket F2). Draait op host én client; start via
## `py -3.11 tools/net_test.py --scenario=net_threat_test`.
## - Neergaan en redden: de host beslist dat de client neergaat; bij beiden een ragdoll, de client
##   staat op de plek van zijn romp. De host draagt hem naar de Mol (de client ziet wie hem draagt),
##   in de Mol wordt hij gerepareerd: bij beiden recht, op dezelfde plek in de Mol.
## - De worm: bij beiden op dezelfde plek; een uitval (zelfde plan) bij de client in een grot gooit de
##   client omver (de host beslist, de client ziet het).
## - Lichtbakens: de voorraad is bij beiden gelijk.
## Naam van deze node is "Scenario" op elk peer, zodat de RPC's aankomen.

const TAG := "[net_threat_test]"
const TIMEOUT_S := 240.0

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _reports := {} # host: sleutel -> gegevens van de client
var _lunge_seen := false # client
var _client := 0


func _ready() -> void:
	main.game.player_spawned.connect(_on_player_spawned)
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out na %.0f s" % TIMEOUT_S)
		for f in _failures:
			print(TAG, " MISLUKT: ", f)
		get_tree().quit(1))


func _on_player_spawned(p: Player) -> void:
	if p.is_local and not Net.is_host():
		_client_start.call_deferred(p)


func _client_start(p: Player) -> void:
	var game: Game = main.game
	while not game.world_ready():
		await get_tree().physics_frame
	await _frames(30)
	game.worm.lunge_started.connect(func(_a: Vector3) -> void: _lunge_seen = true)
	_rpc_ready.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_ready() -> void:
	if multiplayer.is_server():
		_client = multiplayer.get_remote_sender_id()
		_host_flow.call_deferred()


## Host: de stappen, telkens met een vraag aan de client.
func _host_flow() -> void:
	var game: Game = main.game
	var rescue: Rescue = game.rescue
	var mol: Mol = game.mol
	var me: Player = game.local_player
	var cid := _client
	await _wait(1.0)
	var remote: Player = game.player_node(cid)
	_expect(remote != null, "host ziet de client")

	# A. Neer, gedragen, gerepareerd.
	rescue.host_damage(cid, 2.0, Vector3(1.0, 0.0, 0.0), true, "test")
	await _wait(1.2)
	_expect(rescue.life_of(cid) == Rescue.Life.DOWNED and rescue.ragdoll_of(cid) != null, "host: de client is neer, als ragdoll")
	var downed: Dictionary = await _ask("downed")
	_expect(int(downed.life) == Rescue.Life.DOWNED and downed.ragdoll, "client: zelf neer, met een ragdoll")
	_expect(float(downed.on_torso) < 0.2, "client: de speler staat op de plek van zijn romp (%.2f m)" % float(downed.on_torso))
	var rd := rescue.ragdoll_of(cid)
	var d_torso := (downed.torso as Vector3).distance_to(rd.torso.global_position)
	_expect(d_torso < 1.0, "de romp ligt bij beiden op dezelfde plek (%.2f m verschil)" % d_torso)
	me.set_physics_process(false)
	me.global_position = rd.torso.global_position + Vector3(1.0, 0.2, 0.0)
	await _wait(0.3)
	rescue.request_carry(cid)
	await _wait(0.4)
	_expect(rescue.carriers_of(cid) == PackedInt32Array([1]), "de host draagt de client")
	var carried: Dictionary = await _ask("carried")
	_expect(carried.carriers == PackedInt32Array([1]), "client: ziet dat de host hem draagt")
	me.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.6))
	me.rotation.y = mol.yaw
	var t0 := _now()
	while _now() - t0 < Tuning.get_f("rescue", "repair_s", 4.0) + 4.0 and rescue.life_of(cid) != Rescue.Life.OK:
		await get_tree().physics_frame
	_expect(rescue.life_of(cid) == Rescue.Life.OK, "host: in de Mol gerepareerd")
	await _wait(1.0)
	var fixed: Dictionary = await _ask("repaired")
	_expect(int(fixed.life) == Rescue.Life.OK and not fixed.ragdoll, "client: zelf weer recht, geen ragdoll meer")
	_expect(fixed.in_mol, "client: staat in de Mol")
	var dp := (fixed.pos as Vector3).distance_to(remote.global_position)
	_expect(dp < 0.6, "client staat bij beiden op dezelfde plek (%.2f m verschil)" % dp)
	me.set_physics_process(true)
	me.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 2.4))

	# B. De worm: zelfde plek, en een uitval die de client omver gooit.
	var t: TerrainAPI = game.terrain
	var sc := t.shaft_center_world()
	var cave := Vector3(sc.x + 30.0, t.surface_height_at(sc.x + 30.0, sc.z) - 26.0, sc.z)
	game.terrain_sync.host_apply(t.make_sphere_op(0, cave, 6.0))
	await _wait(2.0)
	var hit := t.raycast(cave, cave + Vector3.DOWN * 10.0)
	var ground: Vector3 = hit.position if not hit.is_empty() else cave + Vector3.DOWN * 5.8
	var moved: Dictionary = await _ask("move", {"to": ground + Vector3(0.0, 0.1, 0.0)})
	_expect(moved.ok, "client staat in de grot")
	await _wait(0.6)
	var worm: Worm = game.worm
	game.magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(0.3)
	worm.pos = cave + Vector3(10.0, -6.0, 0.0)
	worm.mode = Worm.Mode.HUNT
	worm._cool = 0.0
	await _wait(1.2)
	var wr: Dictionary = await _ask("worm")
	var dw := (wr.pos as Vector3).distance_to(worm.pos)
	_expect(dw < 3.0, "de worm zit bij beiden op dezelfde plek (%.1f m verschil)" % dw)
	_expect(wr.awake, "client: de worm is wakker")
	worm._cool = 0.0
	var h0 := rescue.health_of(cid)
	var started := worm._try_lunge(remote.global_position)
	_expect(started, "host: de worm valt uit bij de client")
	await _wait(Tuning.get_f("worm", "telegraph_s", 1.3) + Tuning.get_f("worm", "burst_s", 1.6) + 0.4)
	_expect(rescue.health_of(cid) < h0, "host: de client is geraakt (%d%% → %d%%)" % [int(h0 * 100), int(rescue.health_of(cid) * 100)])
	var lunge: Dictionary = await _ask("lunge")
	_expect(lunge.seen, "client: zag dezelfde uitval")
	_expect(float(lunge.health) < 0.99 and (int(lunge.life) == Rescue.Life.KNOCKED or lunge.was_knocked), "client: zelf omver en minder levens (%d%%)" % int(float(lunge.health) * 100))

	# C. Lichtbakens.
	game.beacons.add(2)
	await _wait(0.4)
	var bc: Dictionary = await _ask("beacons")
	_expect(int(bc.left) == game.beacons.left, "zelfde voorraad bakens (%d / %d)" % [int(bc.left), game.beacons.left])

	var ok := _failures.is_empty()
	print(TAG, " host: %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if ok else "GEFAALD"])
	for f in _failures:
		print(TAG, " MISLUKT: ", f)
	_rpc_finish.rpc(ok)
	await _wait(0.5)
	get_tree().quit(0 if ok else 1)


## Host: de client iets vragen en op het antwoord wachten.
func _ask(key: String, args := {}) -> Dictionary:
	_reports.erase(key)
	_rpc_question.rpc_id(_client, key, args)
	var t0 := _now()
	while not _reports.has(key) and _now() - t0 < 15.0:
		await get_tree().physics_frame
	if not _reports.has(key):
		_expect(false, "antwoord van de client op '%s'" % key)
		return {"life": -1, "ragdoll": false, "on_torso": 99.0, "torso": Vector3.ZERO, "carriers": PackedInt32Array(),
				"in_mol": false, "pos": Vector3.ZERO, "ok": false, "awake": false, "seen": false, "health": 1.0,
				"was_knocked": false, "left": -1}
	return _reports[key]


var _was_knocked := false


@rpc("authority", "reliable")
func _rpc_question(key: String, args: Dictionary) -> void:
	var game: Game = main.game
	var p: Player = game.local_player
	var rescue: Rescue = game.rescue
	var me := p.peer_id
	var rd := rescue.ragdoll_of(me)
	var out := {}
	match key:
		"downed":
			out = {"life": rescue.life_of(me), "ragdoll": rd != null,
					"on_torso": p.global_position.distance_to(rd.torso.global_position) if rd else 99.0,
					"torso": rd.torso.global_position if rd else Vector3.ZERO}
		"carried":
			out = {"carriers": rescue.carriers_of(me)}
		"repaired":
			out = {"life": rescue.life_of(me), "ragdoll": rd != null, "in_mol": game.mol.contains_point(p.global_position),
					"pos": p.global_position}
		"move":
			p.set_physics_process(false)
			p.global_position = args.to
			p.reset_physics_interpolation()
			rescue.life_changed.connect(func(peer: int, life: int) -> void:
				if peer == me and life == Rescue.Life.KNOCKED:
					_was_knocked = true)
			out = {"ok": true}
			# Physics weer aan na een tel: de grot moet eerst ook hier botsvormen hebben.
			get_tree().create_timer(1.0).timeout.connect(func() -> void: p.set_physics_process(true))
		"worm":
			out = {"pos": game.worm.pos, "awake": game.worm.is_awake()}
		"lunge":
			out = {"seen": _lunge_seen, "life": rescue.life_of(me), "health": rescue.health_of(me), "was_knocked": _was_knocked}
		"beacons":
			out = {"left": game.beacons.left}
	_rpc_answer.rpc_id(1, key, out)


@rpc("any_peer", "reliable")
func _rpc_answer(key: String, data: Dictionary) -> void:
	if multiplayer.is_server():
		_reports[key] = data


@rpc("authority", "reliable")
func _rpc_finish(ok: bool) -> void:
	print(TAG, " client: host meldt %s" % ("GESLAAGD" if ok else "GEFAALD"))
	get_tree().quit(0 if ok else 1)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print(TAG, " %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
