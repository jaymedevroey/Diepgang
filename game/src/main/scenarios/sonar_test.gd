extends Node
## Test van de sonar in de Mol en van het opscheppen door de boorkop. Solo, headless.
## - Richting: 12 uur = vooruit, 3 uur = rechts, ook als de Mol gedraaid staat.
## - Echo's: binnen het stille bereik (12 m) verschijnen ze na één veeg, dicht bij de echte plek
##   (vaag, niet exact); buiten bereik, gedragen of in het laadruim niet.
## - PING: na de ring staat alles tot 24 m op de sonar, scherp; maakt lawaai (onrust); tijdens het
##   opladen doet een tweede PING niets.
## - Opscheppen: rijdt de boorkop in een vondst die nog in de rots zit, dan ligt hij daarna
##   beschadigd in het laadruim (geen korst meer in de tunnel), met een melding.
## tools\godot.cmd --headless --path game -- --scenario=sonar_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _messages: Array[String] = []


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("[sonar_test] GEFAALD: time-out")
		for f in _failures:
			print("[sonar_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	var t: TerrainAPI = main.terrain
	var finds: FindField = main.game.finds
	mol.message.connect(func(text: String) -> void: _messages.append(text))
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.0)

	# 1. Richting en wijzerplaat.
	var o := Transform3D(Basis(), Vector3(10, 5, 10))
	_expect(Sonar.clock(Sonar.bearing(o, o.origin + Vector3(0, 0, -5))) == 12, "recht vooruit = 12 uur")
	_expect(Sonar.clock(Sonar.bearing(o, o.origin + Vector3(5, 0, 0))) == 3, "rechts = 3 uur")
	_expect(Sonar.clock(Sonar.bearing(o, o.origin + Vector3(-5, -3, 0))) == 9, "links (en lager) = 9 uur")
	_expect(Sonar.clock(Sonar.bearing(o, o.origin + Vector3(0, 0, 5))) == 6, "achter = 6 uur")
	var turned := Transform3D(Basis(Vector3.UP, PI / 2.0), o.origin) # neus naar −x
	_expect(Sonar.clock(Sonar.bearing(turned, o.origin + Vector3(0, 0, -5))) == 3, "gedraaide Mol: −z ligt nu rechts (3 uur)")

	# 2. In de Mol, aan het stuur: na één veeg staan de vondsten binnen bereik op het scherm.
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
	await _wait(0.4)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.4)
	_expect(mol.visual.feed_active, "sonarscherm aan (speler in de Mol)")
	await _wait(Tuning.get_f("mol", "sonar_period", 2.4) * 1.3)
	var sonar := mol.sonar
	var origin := mol.body.global_transform
	var in_range := 0
	for it: FindItem in finds.items:
		if it.global_position.distance_to(origin.origin) < sonar.range_m - 0.5 and it.carriers.is_empty() \
				and not mol.contains_point(it.global_position):
			in_range += 1
	var seen := 0
	for c: Sonar.Contact in sonar.contacts.values():
		if c.item.global_position.distance_to(origin.origin) < sonar.range_m - 0.5:
			seen += 1
	_expect(in_range > 0 and seen == in_range, "%d van %d vondsten binnen %d m staan op de sonar" % [seen, in_range, int(sonar.range_m)])
	var worst := 0.0
	var outside := 0
	for c: Sonar.Contact in sonar.contacts.values():
		worst = maxf(worst, c.echo.distance_to(c.item.global_position))
		if c.item.global_position.distance_to(origin.origin) > sonar.range_m + 0.01:
			outside += 1
	_expect(outside == 0, "geen echo's van buiten het bereik")
	_expect(worst > 0.0 and worst < 4.0, "echo's zijn vaag maar dichtbij (grootste afwijking %.2f m)" % worst)
	var target := sonar.nearest(origin)
	_expect(target != null, "er is een doel (dichtstbijzijnde echo)")
	if target:
		var real := target.item.global_position
		var right := (real - origin.origin).dot(origin.basis.x) > 0.0
		var h := Sonar.clock(Sonar.bearing(origin, target.echo))
		_expect((h > 0 and h <= 6) == right or absf((real - origin.origin).dot(origin.basis.x)) < 2.0,
				"doel op %d uur ligt echt %s" % [h, "rechts" if right else "links"])
		# Gedragen = niet op de sonar (die echo is de speler zelf).
		var id := target.item.find_id
		target.item.carriers = PackedInt32Array([99])
		await _wait(0.1)
		_expect(not sonar.contacts.has(id), "een gedragen vondst verdwijnt van de sonar")
		target.item.carriers = PackedInt32Array()

	# 2b. PING: alles tot 24 m, scherp, luid, en daarna opladen.
	var noise := [0]
	mol.noise_made.connect(func(_a: float, _w: Vector3) -> void: noise[0] += 1)
	var ping_n := 0
	var quiet_n := 0
	for it: FindItem in finds.items:
		var dd := it.global_position.distance_to(origin.origin)
		if it.carriers.is_empty() and not mol.contains_point(it.global_position):
			if dd < sonar.ping_range - 0.5:
				ping_n += 1
			if dd < sonar.range_m - 0.5:
				quiet_n += 1
	# (Headless kan de muis niet vangen, dus de toets zelf gaat niet door Player; enkel de koppeling.)
	_expect(InputMap.has_action("sonar_ping") and Settings.key_of("sonar_ping") == "F", "PING op de F-toets")
	mol.press(Mol.Cmd.PING)
	await get_tree().process_frame
	_expect(sonar.pinging(), "de PING-knop start een PING (de ring loopt)")
	await _wait(sonar.ping_range / Tuning.get_f("mol", "sonar_ping_speed", 40.0) + 0.2)
	var sharp := 0
	var far := 0
	var worst_ping := 0.0
	for c: Sonar.Contact in sonar.contacts.values():
		if c.sharp:
			sharp += 1
			worst_ping = maxf(worst_ping, c.echo.distance_to(c.item.global_position))
			if c.item.global_position.distance_to(origin.origin) > sonar.range_m:
				far += 1
	_expect(ping_n > quiet_n, "er liggen vondsten tussen 12 en 24 m (%d tegen %d)" % [ping_n, quiet_n])
	_expect(sharp >= ping_n, "na de PING: %d van %d vondsten binnen %d m scherp op de sonar" % [sharp, ping_n, int(sonar.ping_range)])
	_expect(far > 0, "ook vondsten voorbij het stille bereik (%d)" % far)
	_expect(worst_ping < 1.0, "PING-echo's zijn scherp (grootste afwijking %.2f m)" % worst_ping)
	_expect(noise[0] == 1, "de PING maakte lawaai (voor de onrust)")
	var cool := sonar.ping_cool
	_expect(cool > 0.0, "de PING laadt op (%.1f s)" % cool)
	mol.press(Mol.Cmd.PING)
	await _wait(0.3)
	_expect(noise[0] == 1 and sonar.ping_cool < cool, "tijdens het opladen doet een tweede PING niets")

	# 3. Opscheppen: een vondst diep in de rots, de Mol 12 m ervoor in een uitgegraven stuk tunnel.
	var size := t.world_size()
	var sc := t.shaft_center_world()
	var victim: FindItem = null
	for it: FindItem in finds.items:
		var pos := it.global_position
		if it.freed or pos.x < 16.0 or pos.x > size.x - 16.0 or pos.z < 18.0 or pos.y > Strata.TOPS_M[2] - 10.0:
			continue
		# De boorkop T1 komt enkel door klei en zandsteen.
		if not Strata.can_dig(t.layer_at(pos), Mol.TIER) or not Strata.can_dig(t.layer_at(pos + Vector3(0, 0, 12)), Mol.TIER):
			continue
		if Vector2(pos.x - sc.x, pos.z - sc.z).length() < 12.0:
			continue
		victim = it
		break
	_expect(victim != null, "vondst gevonden voor de opschep-test")
	if victim == null:
		_finish()
		return
	var goal := victim.global_position
	var dir := Vector3(0, 0, -1) # de Mol rijdt naar −z (yaw 0)
	var start := goal - dir * 12.0
	mol.leave_seat()
	p.set_physics_process(false)
	p.global_position = start
	await _wait(3.0)
	for back in [16.0, 12.0, 8.0]:
		t.debug_dig(goal - dir * back, 3.6)
	await _wait(1.0)
	_expect(finds.crusts.has(victim.find_id), "korst zit nog rond de vondst voor de Mol eraan komt")
	mol.teleport(start, 0.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	p.set_physics_process(true)
	await _wait(1.0)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.3)
	var cond_before := victim.condition
	Input.action_press("move_forward")
	var t0 := Time.get_ticks_msec()
	while not victim.freed and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _wait(1.5)
	_expect(victim.freed, "de boorkop raakte de vondst en schepte hem op")
	_expect(not finds.crusts.has(victim.find_id), "geen korst meer in de tunnel")
	_expect(victim in mol.cargo_contents(), "de vondst ligt in het laadruim")
	var local := mol.to_local_mol(victim.global_position)
	_expect(local.y > -1.6 and local.y < -0.6, "en ligt op de vloer van het laadruim (lokaal y %.2f)" % local.y)
	var max_cond := Tuning.get_f("finds", "mol_condition", 0.3)
	_expect(victim.condition <= max_cond + 0.001 and victim.condition < cond_before,
			"zwaar beschadigd: gaafheid %d%% (max %d%%)" % [int(victim.condition * 100), int(max_cond * 100)])
	_expect(_messages.any(func(m: String) -> bool: return m.begins_with("The drill head scooped up")), "melding voor de ploeg")
	_expect(not sonar.contacts.has(victim.find_id), "vondsten in het laadruim staan niet op de sonar")
	_finish()


func _finish() -> void:
	print("[sonar_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[sonar_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[sonar_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
