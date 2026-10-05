extends Node
## Nettest van de drop, zoals de client hem beleeft (via tools/net_test.py --scenario=net_drop_flow_test):
## - de client opent de opdrachten aan de terminal (E), stapt in de Mol en kiest daar de opdracht
##   (Enter op de knop); beide laden de nieuwe wereld, maar de client hangt bij het begin van het
##   laden even vast (--stall-ms, standaard 12 s: een trage pc of een haperende schijf nabootsen);
## - de host trekt aan de hendel zodra zijn eigen wereld er is, en blijft trekken: zolang de client
##   laadt, weigert de hendel met een melding (QA-13); de client staat dan op de kade (8 s aftellen)
##   en springt halfweg in de Mol (het aftellen wordt korter);
## - tijdens de val: de client blijft in de Mol, zijn buitenbeeld toont nooit de hub (QA-14), en
##   overslaan is een stemming (de client alleen is niet genoeg, met de host erbij wel);
## - na de landing: de client kijkt weer door zijn eigen camera, stapt uit met echte invoer, en
##   host en client zien de Mol en de client op dezelfde plek. Geen fouten in de log, aan beide kanten.
## Wat nog niet in het spel zit (skip_cinematic, Player.cinematic), meldt de test als
## "NOG NIET BESCHIKBAAR". De naam van deze node is "Scenario" op elke peer (voor de RPC's).

const ErrorLog := preload("res://src/main/scenarios/qa_error_log.gd")
const TAG := "[net_drop_flow_test]"
const TIMEOUT_S := 260.0

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _missing := PackedStringArray()
var _gt := 0.0
var _log: Logger
var _slow := false # client: een trage pc nabootsen zolang de nieuwe wereld laadt
var _saw_unloaded := false
var _load_start := 0.0
var _load_s := -1.0
var _client_ready := false
var _client_voted := false
var _client_report: Dictionary = {}
var _client_voted_ack := false # client: de host heeft ook gestemd


func _ready() -> void:
	_log = ErrorLog.new()
	OS.add_logger(_log)
	main.game.player_spawned.connect(_on_player_spawned)
	get_tree().create_timer(TIMEOUT_S).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out na %.0f s" % TIMEOUT_S)
		for f in _failures:
			print(TAG, " MISLUKT: ", f)
		get_tree().quit(1))


func _process(delta: float) -> void:
	_gt += delta
	if _slow:
		var t: TerrainAPI = main.game.terrain
		if t and not t.is_loaded:
			if not _saw_unloaded:
				_saw_unloaded = true
				_load_start = _gt
				var stall := int(CmdArgs.value("stall-ms", 12000))
				print(TAG, " client: de nieuwe wereld begint te laden; %d ms vasthangen" % stall)
				OS.delay_msec(stall)
		elif _saw_unloaded:
			_slow = false
			_load_s = _gt - _load_start
			print(TAG, " client: nieuwe wereld geladen na %.1f s speltijd" % _load_s)


func _on_player_spawned(p: Player) -> void:
	if p.is_local and not Net.is_host():
		_run_client.call_deferred(p)
	elif p.is_local and Net.is_host():
		_run_host.call_deferred(p)


# --- Client --------------------------------------------------------------------------------------

func _run_client(p: Player) -> void:
	var game: Game = main.game
	var ship: Ekster = game.ship
	var mol: Mol = game.mol
	var cine_ready := InputMap.has_action("skip_cinematic")
	await _wait(2.0)
	var r := {"in_hub": ship.contains(p.global_position), "terminal": false, "chose": false, "cine_ready": cine_ready,
		"has_flag": "cinematic" in p}
	# 1. Aan de terminal: E opent de opdrachten; Esc sluit.
	p.global_position = ship.anchor_position("Terminal_Use") + Vector3(0.0, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	p.head.rotation.x = 0.0
	await _frames(4)
	_key(KEY_E)
	await _frames(3)
	r.terminal = main._terminal.visible
	_key(KEY_ESCAPE)
	await _frames(2)
	# 2. De Mol in, de host verwittigen (die stapt ook in), en dan kiezen (de opdrachten opnieuw
	# open, Enter op opdracht 1). Zo staat iedereen klaar voor de nieuwe wereld er is.
	p.global_position = mol.to_world_mol(Vector3(0.6, -1.45, 0.8))
	p.velocity = Vector3.ZERO
	await _wait(0.5)
	var in_mol := mol.contains_point(p.global_position)
	_rpc_client_ready.rpc_id(1, r.in_hub, r.terminal, in_mol)
	await _wait(1.0)
	var want: Dictionary = game.company.options[1]
	main._terminal.open(game.company)
	await _frames(2)
	var cards: Array = (main._terminal._cards as HBoxContainer).get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	if cards.size() > 1:
		var b := (cards[1] as Node).find_children("*", "Button", true, false)[0] as Button
		b.grab_focus()
		await _frames(1)
		_slow = true
		_key(KEY_ENTER)
	r.chose = await _until(func() -> bool: return game.company.contract == want, 30.0)
	main._terminal.close()
	# Even uitstappen naar de kade: bij de hendel zit niet iedereen in de Mol (dan 8 s aftellen).
	p.global_position = ship.global_transform * Vector3(0.75, 0.05, 8.8)
	p.velocity = Vector3.ZERO
	_rpc_client_chose.rpc_id(1, r.chose)
	# 3. Wachten op de drop; noteren of de wereld er al is. (Na het vasthangen kan de client meteen
	# in DROPPING of zelfs PARKED belanden: dan miste hij de val.)
	var falling := [Mol.Mode.DROP_COUNTDOWN, Mol.Mode.DROPPING, Mol.Mode.PARKED]
	await _until(func() -> bool: return mol.mode in falling, 150.0)
	r.loaded_at_countdown = game.world_ready()
	# Halfweg het aftellen alsnog in de Mol springen: dan wordt het aftellen korter (iedereen aan boord).
	await _wait(0.5)
	if mol.mode == Mol.Mode.DROP_COUNTDOWN:
		p.global_position = mol.to_world_mol(Vector3(0.6, -1.45, 0.8))
		p.velocity = Vector3.ZERO
	await _until(func() -> bool: return mol.mode == Mol.Mode.DROPPING or mol.mode == Mol.Mode.PARKED, 60.0)
	r.loaded_at_drop = mol.mode == Mol.Mode.DROPPING and game.world_ready() and game.pit_seed == int(want.seed)
	r.seed = game.pit_seed
	print(TAG, " client: de val begint (%s); nieuwe wereld geladen: %s (bij het aftellen: %s)" % [
		Mol.Mode.keys()[mol.mode], game.world_ready(), r.loaded_at_countdown])
	# 4. De val, zoals de client hem ziet.
	r.inside = true
	r.cine_cam = false
	r.cam_far = 0.0
	r.hub_frames = 0
	r.hub_s = 0.0
	r.voted = false
	r.jump_seen = false
	r.jump_before_host = false
	var last_h := _mol_h(mol)
	var start := _gt
	while mol.mode == Mol.Mode.DROPPING and _gt - start < 120.0:
		await get_tree().process_frame
		if not mol.contains_point(p.global_position):
			r.inside = false
		var c := get_viewport().get_camera_3d()
		# Wat er getekend wordt: dit buitenbeeld met de Mol waar zijn lichaam (en model) nu staat.
		var in_hub_still := mol.body.global_position.y > game.exterior.dock_position().y + 200.0
		if c != p.camera and c:
			r.cine_cam = true
			if in_hub_still:
				r.hub_frames += 1
				r.hub_s += get_process_delta_time()
			elif not (c.has_method("blacked_out") and c.call("blacked_out")):
				# Een volledig zwart beeld (de dip bij een sprong) telt niet: dat ziet niemand. (Let op:
				# process_frame komt vóór de _process van de camera; na een sprong is zijn plek hier
				# nog die van het vorige beeld, maar dan is het beeld ook zwart.)
				var far := c.global_position.distance_to(mol.body.global_position)
				if far > 150.0 and float(r.cam_far) <= 150.0:
					print(TAG, " client: buitenbeeld %.0f m van de Mol (%.1f s in de val): camera op %s, Mol op %s (gezet %s), stemmen %d/%d" % [
						far, _gt - start, c.global_position, mol.body.global_position, mol.placed.origin, mol.skip_votes, mol.skip_needed])
				r.cam_far = maxf(r.cam_far, far)
		var h := _mol_h(mol)
		if last_h < 1000.0 and absf(last_h - h) > 40.0:
			print(TAG, " client: de Mol sprong van %.0f naar %.0f m (%.1f s in de val)" % [last_h, h, _gt - start])
		if last_h < 1000.0 and last_h - h > 40.0:
			r.jump_seen = true
			if not _client_voted_ack:
				r.jump_before_host = true
		last_h = h
		if cine_ready and not r.voted and c != p.camera and not in_hub_still and h > 220.0:
			r.voted = true
			await _tap("skip_cinematic")
			_rpc_client_voted.rpc_id(1)
	r.drop_s = _gt - start
	# 5. Overdracht en uitstappen.
	var t_land := _gt
	r.cam_back = await _until(func() -> bool: return get_viewport().get_camera_3d() == p.camera and p.get("cinematic") != true, 3.0)
	r.handover = _gt - t_land
	await _wait(0.6)
	r.landed_inside = mol.contains_point(p.global_position)
	r.free = p._attached == null and p._hold_ticks <= 0 and p.is_on_floor()
	var from := p.global_position
	await _walk_to(p, mol.to_world_mol(Vector3(0.6, -1.5, 13.0)), 0.6, 12.0)
	var t: TerrainAPI = game.terrain
	var pos := p.global_position
	r.walked_out = not mol.contains_point(pos) and pos.distance_to(from) > 5.0
	r.on_ground = p.is_on_floor() and absf(pos.y - t.surface_height_at(pos.x, pos.z)) < 0.6
	r.player_pos = pos
	r.mol_pos = mol.body.global_position
	r.errors = _log.count()
	r.error_lines = " | ".join(_log.first(3))
	_rpc_client_report.rpc_id(1, r)


@rpc("authority", "reliable")
func _rpc_host_voted() -> void:
	_client_voted_ack = true


# --- Host ----------------------------------------------------------------------------------------

func _run_host(p: Player) -> void:
	var game: Game = main.game
	var mol: Mol = game.mol
	var cine_ready := InputMap.has_action("skip_cinematic")
	while not _client_ready:
		await get_tree().process_frame
	p.global_position = mol.to_world_mol(Vector3(-0.6, -1.45, 0.8))
	p.velocity = Vector3.ZERO
	var refused := [false]
	mol.message.connect(func(t: String) -> void:
		if t.begins_with("Not everyone has arrived"):
			refused[0] = true)
	# De hendel zodra de eigen wereld er is (zo snel als een host maar kan), en dan om de seconde
	# opnieuw, zoals een ongeduldige speler, tot het aftellen begint.
	await _until(func() -> bool: return game.company.contract_ready() and game.world_ready(), 120.0)
	await _frames(2)
	var pressed_at := _gt
	var started := false
	while _gt - pressed_at < 120.0:
		mol.press(Mol.Cmd.DEPART)
		started = await _until(func() -> bool: return mol.mode != Mol.Mode.DOCKED, 1.0)
		if started:
			break
	print(TAG, " host: aftellen begon %.1f s na de eerste keer aan de hendel" % (_gt - pressed_at))
	_expect(started and mol.mode == Mol.Mode.DROP_COUNTDOWN, "de hendel start het aftellen (eens iedereen de wereld heeft)")
	_expect(refused[0], "zolang de client nog laadt, weigert de hendel met een melding (QA-13)")
	var cd_start := _gt
	var cd_first := mol.countdown
	_expect(cd_first > 7.5, "niet iedereen in de Mol bij de hendel: 8 s aftellen (%.1f s)" % cd_first)
	while mol.mode == Mol.Mode.DROP_COUNTDOWN:
		await get_tree().process_frame
	var cd_total := _gt - cd_start
	_expect(cd_total > 4.5 and cd_total < 7.0, "de client springt erin: het aftellen wordt korter (%.1f s in totaal)" % cd_total)
	# Stemming: eerst enkel de client, dan de host erbij.
	var jump_after_client_only := false
	var jump_after_both := false
	if cine_ready:
		var ok := await _until(func() -> bool: return _client_voted or mol.mode != Mol.Mode.DROPPING, 60.0)
		if ok and mol.mode == Mol.Mode.DROPPING:
			var h0 := _mol_h(mol)
			await _wait(1.0)
			jump_after_client_only = h0 - _mol_h(mol) > 60.0
			var h1 := _mol_h(mol)
			_rpc_host_voted.rpc()
			await _tap("skip_cinematic")
			await _wait(1.0)
			jump_after_both = h1 - _mol_h(mol) > 60.0
			print(TAG, " host: na beide stemmen van %.0f naar %.0f m in 1 s (variant %s, stemmen %d/%d)" % [
				h1, _mol_h(mol), Mol.DropVariant.keys()[mol.drop_variant], mol.skip_votes, mol.skip_needed])
	while mol.mode != Mol.Mode.PARKED:
		await get_tree().process_frame
	while _client_report.is_empty():
		await get_tree().process_frame
	var r := _client_report
	_expect(bool(r.get("loaded_at_drop", false)), "de drop vertrekt pas als de client de nieuwe wereld heeft (QA-13)")
	_expect(int(r.get("seed", -1)) == game.pit_seed, "client en host in dezelfde wereld (%d)" % int(r.get("seed", -1)))
	_expect(bool(r.inside), "client bleef de hele val in de Mol")
	_expect(bool(r.cine_cam), "client zag een buitenbeeld tijdens de val")
	_expect(int(r.hub_frames) == 0, "het buitenbeeld van de client toont de Mol vanaf het eerste beeld (%d beelden, %.3f s waarin het lichaam van de Mol nog in de hub stond, QA-14)" % [
			r.hub_frames, float(r.hub_s)])
	_expect(float(r.cam_far) < 150.0, "het buitenbeeld van de client blijft bij de Mol (verst %.0f m)" % float(r.cam_far))
	if cine_ready:
		_expect(bool(r.voted) and not jump_after_client_only, "overslaan: de client alleen is niet genoeg (stemming)")
		_expect(jump_after_both and bool(r.jump_seen), "overslaan: met de host erbij springt de Mol, ook bij de client")
		_expect(not bool(r.jump_before_host), "de client zag geen sprong voor de host stemde")
	else:
		_na("overslaan als stemming (geen actie skip_cinematic)")
	_expect(bool(r.cam_back), "client kijkt na de landing weer door zijn eigen camera (na %.2f s)" % float(r.handover))
	if bool(r.has_flag):
		_expect(float(r.handover) < 1.5, "client: overdracht kort na de klap (%.2f s)" % float(r.handover))
	else:
		_na("Player.cinematic bij de client")
	_expect(bool(r.landed_inside) and bool(r.free), "client staat na de landing los in de Mol, op de vloer")
	_expect(bool(r.walked_out) and bool(r.on_ground), "client stapt met echte invoer uit, op de grond")
	var dm: float = (r.mol_pos as Vector3).distance_to(mol.body.global_position)
	_expect(dm < 0.5, "client en host zien de Mol op dezelfde plek (%.2f m)" % dm)
	await _wait(0.5)
	var remote := _remote_player()
	if remote:
		var dp := remote.global_position.distance_to(r.player_pos as Vector3)
		_expect(dp < 0.8, "host ziet de client waar die zelf is (%.2f m)" % dp)
	_expect(int(r.errors) == 0, "client: geen fouten in de log (%d) %s" % [int(r.errors), r.error_lines])
	_expect(_log.count() == 0, "host: geen fouten in de log (%d) %s" % [_log.count(), " | ".join(_log.first(3))])
	var ok := _failures.is_empty()
	print(TAG, " host: %d controles, %d mislukt, %d nog niet beschikbaar → %s" % [_checks, _failures.size(),
			_missing.size(), "GESLAAGD" if ok else "GEFAALD"])
	for f in _failures:
		print(TAG, " MISLUKT: ", f)
	_rpc_finish.rpc(ok)
	await _wait(0.5)
	get_tree().quit(0 if ok else 1)


func _remote_player() -> Player:
	for pl: Player in main.game.players.get_children():
		if not pl.is_local:
			return pl
	return null


@rpc("any_peer", "reliable")
func _rpc_client_ready(in_hub: bool, terminal: bool, in_mol: bool) -> void:
	_expect(in_hub, "client spawnt in de hub")
	_expect(terminal, "client: E aan de terminal opent de opdrachten")
	_expect(in_mol, "client staat in de Mol")
	_client_ready = true


@rpc("any_peer", "reliable")
func _rpc_client_chose(chose: bool) -> void:
	_expect(chose, "client kiest de opdracht (de host beslist, iedereen krijgt hem)")


@rpc("any_peer", "reliable")
func _rpc_client_voted() -> void:
	_client_voted = true


@rpc("any_peer", "reliable")
func _rpc_client_report(r: Dictionary) -> void:
	_client_report = r


@rpc("authority", "reliable")
func _rpc_finish(ok: bool) -> void:
	print(TAG, " client: host meldt %s" % ("GESLAAGD" if ok else "GEFAALD"))
	get_tree().quit(0 if ok else 1)


# --- Hulp ----------------------------------------------------------------------------------------

func _walk_to(p: Player, target: Vector3, reach: float, limit: float) -> bool:
	var start := _gt
	var arrived := false
	Input.action_press("move_forward")
	while _gt - start < limit:
		var to := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		if to.length() < reach:
			arrived = true
			break
		p.rotation.y = atan2(-to.x, -to.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	for i in 15:
		await get_tree().physics_frame
	return arrived


func _mol_h(mol: Mol) -> float:
	var t: TerrainAPI = main.game.terrain
	var mp := mol.body.global_position
	return mp.y - (t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _until(cond: Callable, timeout: float) -> bool:
	var start := _gt
	while not cond.call():
		if _gt - start > timeout:
			return false
		await get_tree().process_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print(TAG, " %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _na(what: String) -> void:
	_missing.append(what)
	print(TAG, " NOG NIET BESCHIKBAAR: ", what)
