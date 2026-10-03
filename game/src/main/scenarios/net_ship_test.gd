extends Node
## Nettest van De Ekster (host + client, via tools/net_test.py --scenario=net_ship_test):
## beide spawnen in de hub, stappen in de Mol, de host dropt; de client blijft in de Mol (ook bij
## de sprong naar het buitenschip), landt mee, en komt met de grijper mee terug in de hub. De host
## vergelijkt wat de client meldt met wat hij zelf ziet.
## Naam van deze node is "Scenario" op elke peer, zodat de RPC's aankomen.

const TIMEOUT_S := 200.0

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _client_ready := false
var _client_report: Array = []
var _client_drop: Array = []


func _ready() -> void:
	main.game.player_spawned.connect(_on_player_spawned)
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		print("[net_ship_test] GEFAALD: time-out na %.0f s" % TIMEOUT_S)
		for f in _failures:
			print("[net_ship_test] MISLUKT: ", f)
		get_tree().quit(1))


func _on_player_spawned(p: Player) -> void:
	if p.is_local and not Net.is_host():
		_run_client.call_deferred(p)
	elif p.is_local and Net.is_host():
		_run_host.call_deferred(p)


# --- Client ------------------------------------------------------------------------------------

func _run_client(p: Player) -> void:
	var game: Game = main.game
	var mol: Mol = game.mol
	await _wait(2.0)
	var in_hub := game.ship.contains(p.global_position)
	p.global_position = mol.to_world_mol(Vector3(0.6, -1.45, 0.8))
	await _wait(1.0)
	_rpc_client_ready.rpc_id(1, in_hub, mol.contains_point(p.global_position))
	# Wachten op de drop en de landing. Onderweg: het buitenbeeld (pas na de sprong naar buiten, dus
	# niet in de hub), het filmpje, en overslaan: de host stemt eerst, de client 1 s later.
	while mol.mode != Mol.Mode.DROPPING:
		await get_tree().process_frame
	var inside_fall := true
	var saw_cam := false
	var first_in_hub := false
	var cine := true
	var voted := false
	var host_vote_ms := -1
	var frames := 0
	while mol.mode == Mol.Mode.DROPPING:
		await get_tree().process_frame
		frames += 1
		if not mol.contains_point(p.global_position):
			inside_fall = false
		if mol.mode != Mol.Mode.DROPPING:
			break
		if frames >= 3: # het moment van loslaten komt net na de toestand
			cine = cine and p.cinematic
		if p.drop_cam.current and not saw_cam:
			saw_cam = true
			first_in_hub = p.drop_cam.first_frame_pos.y > game.exterior.dock_position().y + 200.0
		if mol.skip_votes >= 1 and host_vote_ms < 0:
			host_vote_ms = Time.get_ticks_msec()
		if not voted and host_vote_ms > 0 and Time.get_ticks_msec() - host_vote_ms > 1000 and mol.drop_skippable():
			voted = true
			mol.vote_skip()
	var short := mol.drop_variant == Mol.DropVariant.SHORT
	await _wait(1.0)
	var landed_inside := mol.contains_point(p.global_position)
	var cam_back := p.camera.current
	_rpc_client_drop.rpc_id(1, saw_cam, first_in_hub, cine, voted, short)
	# Ophalen: wachten tot de Mol weer in de hub staat.
	while mol.mode != Mol.Mode.DOCKED:
		await get_tree().process_frame
	await _wait(1.5)
	_rpc_client_report.rpc_id(1, inside_fall, landed_inside, cam_back, game.ship.contains(p.global_position),
			mol.contains_point(p.global_position), p.global_position, mol.body.global_position,
			game.company.cash, int(game.company.last_report.get("shift_total", 0)))


# --- Host --------------------------------------------------------------------------------------

func _run_host(p: Player) -> void:
	var game: Game = main.game
	var mol: Mol = game.mol
	Tuning.set_value("ship", "drop_countdown_s", 3.0)
	Tuning.set_value("mol", "countdown_s", 2.0)
	while not _client_ready:
		await get_tree().process_frame
	p.global_position = mol.to_world_mol(Vector3(-0.6, -1.45, 0.8))
	await _wait(1.0)
	var remote := _remote_player()
	_expect(remote != null and mol.contains_point(remote.global_position), "host ziet de client in de Mol (in de hub)")
	game.company.contract = game.company.options[0] # opdracht zonder nieuwe wereld (die test ship_test)
	mol.press(Mol.Cmd.DEPART)
	# Overslaan samen: de host stemt in het buitenbeeld; alleen is niet genoeg (1/2), met de stem
	# van de client wordt het de korte drop.
	var voted := false
	var alone_ok := false
	var cam_ms := -1
	while mol.mode != Mol.Mode.PARKED:
		await get_tree().process_frame
		if p.drop_cam.current and cam_ms < 0:
			cam_ms = Time.get_ticks_msec()
		if not voted and cam_ms > 0 and Time.get_ticks_msec() - cam_ms > 500 and mol.drop_skippable():
			voted = true
			mol.vote_skip()
			await _wait(0.4)
			alone_ok = mol.skip_votes == 1 and mol.skip_needed == 2 and mol.drop_variant == Mol.DropVariant.FULL
	_expect(voted and alone_ok, "overslaan samen: één stem van de twee is niet genoeg")
	_expect(mol.drop_variant == Mol.DropVariant.SHORT, "overslaan samen: met beide stemmen werd de drop kort")
	while _client_drop.is_empty():
		await get_tree().process_frame
	_expect(_client_drop[0] and not _client_drop[1], "client: buitenbeeld pas na de sprong naar buiten (niet in de hub)")
	_expect(_client_drop[2], "client: de hele val een filmpje (geen besturing)")
	_expect(_client_drop[3] and _client_drop[4], "client: stemde mee en zag de korte drop")
	await _wait(1.5)
	remote = _remote_player()
	_expect(remote != null and mol.contains_point(remote.global_position), "na de landing: host ziet de client in de Mol")
	mol.press(Mol.Cmd.DEPART)
	while mol.mode != Mol.Mode.DOCKED:
		await get_tree().process_frame
	while _client_report.is_empty():
		await get_tree().process_frame
	var r := _client_report
	_expect(r[0], "client bleef de hele val in de Mol")
	_expect(r[1], "client zit na de landing nog in de Mol")
	_expect(r[2], "client ziet na de landing weer door zijn eigen camera")
	_expect(r[3] and r[4], "client is mee terug in de hub, in de Mol")
	var d: float = (r[6] as Vector3).distance_to(mol.body.global_position)
	_expect(d < 0.5, "client en host zien de Mol op dezelfde plek (%.2f m)" % d)
	remote = _remote_player()
	if remote:
		var dp: float = remote.global_position.distance_to(r[5])
		_expect(dp < 0.6, "host ziet de client waar die zelf is (%.2f m)" % dp)
	_expect(int(r[7]) == game.company.cash and int(r[8]) == 1, "client kreeg het incidentrapport en dezelfde kas (%s)" % UiTheme.euro(int(r[7])))
	var ok := _failures.is_empty()
	print("[net_ship_test] host: %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if ok else "GEFAALD"])
	_rpc_finish.rpc(ok)
	await _wait(0.5)
	get_tree().quit(0 if ok else 1)


func _remote_player() -> Player:
	for pl: Player in main.game.players.get_children():
		if not pl.is_local:
			return pl
	return null


@rpc("any_peer", "reliable")
func _rpc_client_ready(in_hub: bool, in_mol: bool) -> void:
	_expect(in_hub, "client spawnt in de hub")
	_expect(in_mol, "client staat in de Mol")
	_client_ready = true


@rpc("any_peer", "reliable")
func _rpc_client_report(inside_fall: bool, landed_inside: bool, cam_back: bool, in_hub: bool, in_mol: bool,
		player_pos: Vector3, mol_pos: Vector3, cash: int, report_shift: int) -> void:
	_client_report = [inside_fall, landed_inside, cam_back, in_hub, in_mol, player_pos, mol_pos, cash, report_shift]


@rpc("any_peer", "reliable")
func _rpc_client_drop(saw_cam: bool, first_in_hub: bool, cine: bool, voted: bool, short: bool) -> void:
	_client_drop = [saw_cam, first_in_hub, cine, voted, short]


@rpc("authority", "reliable")
func _rpc_finish(ok: bool) -> void:
	print("[net_ship_test] client: host meldt %s" % ("GESLAAGD" if ok else "GEFAALD"))
	get_tree().quit(0 if ok else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[net_ship_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
