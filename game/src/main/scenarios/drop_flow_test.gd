extends Node
## De hele drop als speler, headless en zoveel mogelijk met echte invoer (toetsen, het vizier):
## opdracht kiezen aan de terminal, in de Mol, de hendel, het aftellen, de val, de landing, de
## overdracht van de camera en de besturing, uitstappen en terug, ophalen tot in de hub, en een
## tweede opdracht met een tweede drop. Varianten (--variant=…):
##   main         (standaard) de volledige rondgang met twee drops (de eerste lang, de tweede kort)
##   skip         de eerste drop overslaan met SPATIE (skip_cinematic) zodra het buitenbeeld er is
##   left_behind  de speler blijft in de hub als de Mol dropt, en springt later zelf door de baai
##   on_doors     de speler staat op de luiken naast de Mol als die opengaan
## Wat nog niet in het spel zit (de actie skip_cinematic, Player.cinematic, de korte drop), meldt
## de test als "NOG NIET BESCHIKBAAR" in plaats van te falen. Gekende fouten (QA-3, QA-4, QA-5,
## QA-14, QA-15, QA-16 uit docs/review/qa_drop.md) falen tot ze opgelost zijn. Elke duur is speltijd.
## tools\godot.cmd --headless --path game -- --scenario=drop_flow_test [--variant=skip] --no-steam

const ErrorLog := preload("res://src/main/scenarios/qa_error_log.gd")
const TAG := "[drop_flow_test]"

var main: Node
var game: Game
var ship: Ekster
var mol: Mol
var p: Player
var _variant := "main"
var _checks := 0
var _failures := PackedStringArray()
var _missing := PackedStringArray()
var _gt := 0.0
var _log: Logger
var _cine_ready := false # de nieuwe drop van cine is er (actie skip_cinematic)
var _landed_signal := false
var _summary := Vector3i(-1, -1, -1)


func _ready() -> void:
	_log = ErrorLog.new()
	OS.add_logger(_log)
	_variant = str(CmdArgs.value("variant", "main"))
	main.game.player_spawned.connect(func(pl: Player) -> void:
		if pl.is_local:
			_run.call_deferred(pl))
	get_tree().create_timer(900.0).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out")
		_finish())


func _process(delta: float) -> void:
	_gt += delta


func _run(pl: Player) -> void:
	p = pl
	game = main.game
	ship = game.ship
	mol = game.mol
	_cine_ready = InputMap.has_action("skip_cinematic")
	mol.landed.connect(func() -> void: _landed_signal = true)
	mol.summary.connect(func(count: int, value: int, left: int) -> void: _summary = Vector3i(count, value, left))
	Tuning.set_value("mol", "countdown_s", 2.0) # het aftellen voor het ophalen (niet de drop)
	print(TAG, " variant %s, nieuwe drop van cine: %s, Player.cinematic: %s" % [_variant, _cine_ready, _has_flag()])
	await _wait(1.0)
	_expect(ship != null and ship.contains(p.global_position), "speler spawnt in de hub")
	_expect(_cam() == p.camera, "in de hub kijkt de speler door zijn eigen camera")
	_expect(mol.mode == Mol.Mode.DOCKED, "de Mol staat in de baai")
	match _variant:
		"skip":
			await _run_skip()
		"left_behind":
			await _run_left_behind()
		"on_doors":
			await _run_on_doors()
		_:
			await _run_main()
	_expect(_log.count() == 0, "geen fouten in de log (%d)%s" % [_log.count(),
			"" if _log.count() == 0 else ": " + " | ".join(_log.first(3))])
	_finish()


# --- Varianten ---------------------------------------------------------------------------------

func _run_main() -> void:
	# 1. Terminal met echte invoer: E aan de tafel, twee keer kort na elkaar kiezen, Esc.
	var opts: Array = game.company.options.duplicate(true)
	_expect(await _open_terminal_by_key(), "aan de terminal: E opent de opdrachten")
	await _press_card(0)
	await _frames(2)
	await _press_card(2)
	await _frames(2)
	_expect(game.company.contract == opts[2], "twee keer kort na elkaar kiezen: de laatste keuze telt")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not main._terminal.visible, "Esc sluit de opdrachten")
	await _until(func() -> bool: return game.terrain.is_loaded, 60.0)
	_expect(game.pit_seed == int(opts[2].seed), "de nieuwe wereld komt uit de laatst gekozen opdracht (%d)" % game.pit_seed)

	# 2. Van de kade de klep op, de Mol in (echte invoer), de hendel (vizier + E).
	await _walk_into_mol_from_quay()
	var cd_start := await _pull_lever(Mol.Mode.DROP_COUNTDOWN)
	await _check_countdown(cd_start, true)

	# 3. De lange drop (eerste van de sessie), met de controles tijdens het buitenbeeld.
	var d1 := await _observe_drop(false, true)
	await _after_landing("drop 1", d1)
	var t_long: float = d1.duration

	# 4. Uitstappen met echte invoer, en terug.
	await _walk_out_and_back()

	# 5. Kiezen terwijl de Mol weg is: gebeurt niet. De knop mag aan staan (ontwerp level): het menu
	# zegt dan waarom het niet kan.
	var seed_before := game.pit_seed
	var contract_before: Dictionary = game.company.contract
	game.company.choose(1 if game.company.contract != game.company.options[1] else 0)
	await _wait(0.5)
	_expect(game.pit_seed == seed_before and game.company.contract == contract_before, "een opdracht kiezen terwijl de Mol weg is: gebeurt niet")
	main._terminal.open(game.company)
	await _frames(2)
	await _expect_choose_refused("de terminal terwijl de Mol weg is")
	main._terminal.close()

	# 6. Sonar: echo's opvangen in deze wereld (zo test de volgende wereld QA-4).
	await _sonar_contacts()

	# 7. Ophalen met de hendel, tot in de hub.
	await _extract_to_hub()

	# 8. De klep af naar de kade (echte invoer).
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 4.5)), 0.5, 8.0)
	await _walk_to(ship.global_transform * Vector3(0.75, 0.0, 8.8), 0.5, 8.0)
	var ql := ship.global_transform.affine_inverse() * p.global_position
	_expect(not mol.contains_point(p.global_position) and ship.contains(p.global_position) and p.is_on_floor()
			and absf(ql.y) < 0.15, "terug in de hub: met echte invoer de klep af tot op de kade (y %.2f)" % ql.y)

	# 9. Tweede opdracht en tweede drop (de korte versie).
	var opts2: Array = game.company.options.duplicate(true)
	game.company.choose(1)
	await _frames(2)
	await _until(func() -> bool: return game.terrain.is_loaded, 60.0)
	_expect(game.pit_seed == int(opts2[1].seed), "tweede opdracht: nieuwe wereld (%d)" % game.pit_seed)
	await _walk_into_mol_from_quay()
	# QA-16: de opdrachten staan open als de Mol vertrekt (zoals bij een speler aan de terminal terwijl
	# een ander aan de hendel trekt; E zou het menu sluiten, dus de hendel hier via de Mol zelf).
	# QA-5: het rapport staat nog open (een snelle ploeg).
	if not game.company.last_report.is_empty():
		main.hud.show_report(game.company.last_report)
	main._terminal.open(game.company)
	await _frames(2)
	mol.press(Mol.Cmd.DEPART)
	var started := await _until(func() -> bool: return mol.mode == Mol.Mode.DROP_COUNTDOWN, 2.0)
	_expect(started, "de hendel (andere speler) start DROP_COUNTDOWN")
	var cd2 := _gt
	await _frames(3)
	var note_text: String = (main._terminal._note as Label).text
	_expect(note_text.contains("op weg"), "de open terminal ververst zodra de Mol vertrekt (QA-16): \"%s\"" % note_text)
	await _expect_choose_refused("de open terminal na het vertrek")
	main._terminal.close()
	await _wait(0.5)
	var hud: Hud = main.hud
	var overlap := hud._result.visible and hud._banner.visible \
			and hud._result.get_global_rect().intersects(hud._banner.get_global_rect())
	_expect(not overlap, "het incidentrapport bedekt de aftelbanner niet (QA-5)")
	await _check_countdown(cd2, false)
	var d2 := await _observe_drop(false, false)
	await _after_landing("drop 2", d2)
	if _cine_ready:
		_expect(d2.duration < t_long - 1.0, "de tweede drop is de korte versie (%.1f s, de eerste %.1f s)" % [d2.duration, t_long])
	else:
		_na("korte versie van de tweede drop (%.1f s, de eerste %.1f s)" % [d2.duration, t_long])
	var sc := game.terrain.shaft_center_world()
	var mp := mol.body.global_position
	_expect(Vector2(mp.x - sc.x, mp.z - sc.z).length() < 1.5, "tweede drop: geland op de landingsplek van de nieuwe wereld")
	await _walk_out_and_back()


func _run_skip() -> void:
	game.company.choose(1)
	await _frames(2)
	await _until(func() -> bool: return game.terrain.is_loaded, 60.0)
	await _walk_into_mol_from_quay()
	var cd := await _pull_lever(Mol.Mode.DROP_COUNTDOWN)
	await _check_countdown(cd, true)
	var d := await _observe_drop(true, false)
	if _cine_ready:
		_expect(float(d.first_press) >= 0.0, "SPATIE gedrukt in het buitenbeeld (%.0f m boven de grond)" % d.h_press)
		_expect(float(d.short_at) >= 0.0 and float(d.short_at) - float(d.first_press) < 0.3,
				"solo: de drop wordt meteen de korte (%.2f s)" % (float(d.short_at) - float(d.first_press)))
		_expect(float(d.skip_at) >= 0.0 and float(d.skip_at) - float(d.first_press) < 0.5 and float(d.jump) > 40.0,
				"de Mol springt naar het korte stuk (%.0f m lager, na %.2f s)" % [d.jump, float(d.skip_at) - float(d.first_press)])
		_expect(float(d.h_after) > 120.0 and float(d.h_after) < 230.0, "na het overslaan zo'n 150 m boven de grond (%.0f m)" % d.h_after)
		_expect(bool(d.dipped), "even zwart bij de sprong (het overslaan is te zien)")
		print(TAG, " val met overslaan: %.1f s speltijd (SPATIE na %.1f s)" % [d.duration, float(d.first_press) - float(d.start)])
	else:
		_na("overslaan met skip_cinematic")
	await _after_landing("drop met overslaan", d)
	await _walk_out_and_back()


func _run_left_behind() -> void:
	game.company.choose(1)
	await _frames(2)
	await _until(func() -> bool: return game.terrain.is_loaded, 60.0)
	await _walk_into_mol_from_quay()
	var cd := await _pull_lever(Mol.Mode.DROP_COUNTDOWN)
	# Uitstappen: naar het laadrek, ver van de baai.
	p.global_position = ship.spawn_point(0)
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return mol.mode != Mol.Mode.DROP_COUNTDOWN, 20.0)
	var countdown := _gt - cd
	if _cine_ready:
		# Ontwerp: iedereen aan boord bij de hendel = 5 s; dat wordt niet langer als iemand uitstapt.
		# (8 s als niet iedereen aan boord is: net_drop_flow_test, met de client buiten de Mol.)
		_expect(countdown > 4.5 and countdown < 5.6, "de enige speler zat bij de hendel in de Mol: 5 s, ook na uitstappen (%.1f s)" % countdown)
	else:
		_na("aftellen na uitstappen (gemeten %.1f s)" % countdown)
	var stayed := true
	var own_cam := true
	var flag_off := true
	while mol.mode == Mol.Mode.DROPPING and _gt - cd < 120.0:
		await get_tree().process_frame
		stayed = stayed and ship.contains(p.global_position)
		own_cam = own_cam and _cam() == p.camera
		flag_off = flag_off and _flag() != true
	_expect(mol.mode == Mol.Mode.PARKED, "de Mol landt zonder de speler")
	_expect(stayed, "wie niet in de Mol zat, blijft in de hub")
	_expect(own_cam, "wie in de hub bleef, ziet geen buitenbeeld (eigen camera)")
	if _has_flag():
		_expect(flag_off, "Player.cinematic blijft uit voor wie in de hub bleef")
	else:
		_na("Player.cinematic voor wie in de hub bleef")
	await _wait(1.0)
	_expect(ship.doors_open, "de luiken blijven open terwijl de Mol weg is (springen kan)")
	_expect(main.hud.visible, "HUD zichtbaar in de hub")
	# Zelf springen: van de kade de open baai op.
	p.global_position = ship.global_transform * Vector3(0.75, 0.05, 8.8)
	p.velocity = Vector3.ZERO
	await _wait(0.3)
	var t0 := _gt
	Input.action_press("move_forward")
	var target := ship.global_transform * Vector3(0.75, 0.0, 2.0)
	while _gt - t0 < 6.0 and ship.contains(p.global_position):
		var to := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		p.rotation.y = atan2(-to.x, -to.y)
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_expect(not ship.contains(p.global_position), "van de kade door de open baai gestapt")
	var landed := await _until(func() -> bool:
		return p.is_on_floor() and not ship.contains(p.global_position) \
				and p.global_position.y < game.exterior.dock_position().y - 100.0, 60.0)
	_expect(landed, "na de sprong op de planeet geland (%.1f s)" % (_gt - t0))
	await _wait(0.5)
	var ll := mol.to_local_mol(p.global_position)
	var where := _place_name(ll)
	print(TAG, " na de sprong door de baai geland: %s (lokaal %s)" % [where, ll])
	if where == "grond":
		_ground_checks("na de sprong door de baai")
	else:
		_expect(p.is_on_floor(), "na de sprong door de baai: staat op de %s van de Mol" % where)
	# Naast de Mol, op de klep of op het dak mag; onder de buik of door het dak in de cabine niet.
	_expect(where in ["grond", "klep", "dak"], "na de sprong niet onder de Mol en niet door het dak in de cabine (%s)" % where)
	_expect(_cam() == p.camera, "na de sprong de eigen camera")
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 13.0)), 0.8, 25.0)
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 2.0)), 0.5, 10.0)
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, -0.6)), 0.5, 6.0)
	_expect(mol.contains_point(p.global_position), "te voet de Mol in")
	await _extract_to_hub()


func _run_on_doors() -> void:
	game.company.choose(1)
	await _frames(2)
	await _until(func() -> bool: return game.terrain.is_loaded, 60.0)
	await _walk_into_mol_from_quay()
	await _pull_lever(Mol.Mode.DROP_COUNTDOWN)
	var doors := ship.global_transform * Vector3(2.0, 0.2, 5.0)
	p.global_position = doors
	p.velocity = Vector3.ZERO
	await _frames(2)
	_expect(ship.over_bay(p.global_position) and not mol.contains_point(p.global_position), "speler staat op de luiken naast de Mol")
	var lost_at_deg := -1.0
	var start := _gt
	var airborne := 0
	while _gt - start < 90.0:
		await get_tree().physics_frame
		# Het moment waarop de speler boven de baai zijn steun verliest: drie ticks na elkaar niet meer
		# op een vloer. (Meezakken op een kantelend luik is nog steun: de botsvorm draait mee.)
		airborne = airborne + 1 if not p.is_on_floor() else 0
		if lost_at_deg < 0.0 and airborne >= 3:
			var hl := ship.global_transform.affine_inverse() * p.global_position
			lost_at_deg = ship.door_angle_deg() if ship.has_method("door_angle_deg") else ship.door_amount * 100.0
			print(TAG, " steun kwijt boven de baai: luiken %.0f graden open (lokaal y %.2f)" % [lost_at_deg, hl.y])
		if lost_at_deg >= 0.0 and mol.mode == Mol.Mode.PARKED and p.is_on_floor() \
				and p.global_position.y < game.exterior.dock_position().y - 100.0:
			break
	# Ontwerp (level): de botsvorm draait mee met de luiken en valt pas weg voorbij 60 graden. Een luik
	# dat sneller wegzwaait dan je valt, laat je los (gemeten 16-48 graden, naargelang de belasting):
	# dat is echt vallen, niet door een dicht luik zakken (vóór: 0-2 %).
	_expect(lost_at_deg >= 10.0, "geen val door dichte luiken: steun pas kwijt als ze zichtbaar draaien (%.0f graden, QA-15)" % lost_at_deg)
	await _wait(0.5)
	_ground_checks("van de luiken gevallen")
	var lp := mol.to_local_mol(p.global_position)
	_expect(mol.mode == Mol.Mode.PARKED, "de Mol landde normaal")
	_expect(_place_name(lp) == "grond", "naast de Mol terechtgekomen, niet eronder, erop of erin (%s, lokaal %s)" % [_place_name(lp), lp])
	# Kan hij weg? Opzij lopen met echte invoer.
	var from := p.global_position
	await _walk_to(mol.to_world_mol(Vector3(signf(lp.x if absf(lp.x) > 0.1 else 1.0) * 8.0, -2.5, lp.z)), 0.6, 6.0)
	_expect(p.global_position.distance_to(from) > 2.0 and _place_name(mol.to_local_mol(p.global_position)) == "grond",
			"van daar weg kunnen lopen (%.1f m)" % p.global_position.distance_to(from))


# --- Stappen -----------------------------------------------------------------------------------

## Aftellen: niet over te slaan; 5 s als iedereen in de Mol zit (nieuwe drop), anders 8 s.
func _check_countdown(cd_start: float, try_skip: bool) -> void:
	await _frames(2) # de HUD werkt zich bij in main._process
	_expect(main.hud._banner.visible, "aftelbanner zichtbaar")
	if try_skip and _cine_ready:
		await _wait(1.0)
		var before := mol.countdown
		var t := _gt
		await _tap("skip_cinematic")
		await _wait(0.5)
		_expect(mol.mode == Mol.Mode.DROP_COUNTDOWN and mol.countdown > before - (_gt - t) - 0.3,
				"het aftellen is niet over te slaan")
	elif try_skip:
		_na("SPATIE tijdens het aftellen (geen actie skip_cinematic)")
	await _until(func() -> bool: return mol.mode != Mol.Mode.DROP_COUNTDOWN, 20.0)
	var cd := _gt - cd_start
	if _cine_ready:
		_expect(cd < 5.8, "iedereen in de Mol: aftellen 5 s (%.1f s)" % cd)
	else:
		_na("aftellen 5 s als iedereen in de Mol zit (gemeten %.1f s)" % cd)
	_expect(mol.mode == Mol.Mode.DROPPING, "na het aftellen valt de Mol")
	_expect(ship.doors_open, "de luiken staan open")


## Volgt een drop van DROPPING tot de landing. `skip`: SPATIE zodra het buitenbeeld er is.
## `extra`: invoer en pauze testen tijdens het buitenbeeld.
func _observe_drop(skip: bool, extra: bool) -> Dictionary:
	var d := {"start": _gt, "duration": 0.0, "inside": true, "cine_cam": false, "flag_seen": false,
		"flag_flicker": false, "skip_at": -1.0, "first_press": -1.0, "jump": 0.0, "h_after": INF,
		"input_moved": -1.0, "cam_far": 0.0, "mismatch_s": 0.0, "mismatch_frames": 0, "short_at": -1.0,
		"h_press": 0.0, "dipped": false}
	_landed_signal = false
	var last_h := _mol_h()
	var flag_was := false
	var tries := 0
	var next_try := 0.0
	var tested := not extra
	var frame := 0
	var outside_since := -1.0
	while mol.mode == Mol.Mode.DROPPING and _gt - float(d.start) < 120.0:
		await get_tree().process_frame
		if not mol.contains_point(p.global_position):
			d.inside = false
		var c := _cam()
		frame += 1
		if c != p.camera and c:
			d.cine_cam = true
			# Wat er getekend wordt: dit beeld van de buitencamera, met de Mol (het lichaam en zijn model)
			# waar hij nu staat. Staat dat lichaam nog in de hub, dan toont het buitenbeeld geen Mol.
			var body_pos := mol.body.global_position
			if body_pos.y > game.exterior.dock_position().y + 200.0:
				if int(d.mismatch_frames) == 0:
					print(TAG, " buitenbeeld zonder de Mol: frame %d van de val, %s op %s, het lichaam van de Mol nog op %s (gezet: %s)" % [
						frame, c.name, c.global_position, body_pos, mol.placed.origin])
				d.mismatch_frames = int(d.mismatch_frames) + 1
				d.mismatch_s = float(d.mismatch_s) + get_process_delta_time()
			else:
				d.cam_far = maxf(d.cam_far, c.global_position.distance_to(body_pos))
		var f: Variant = _flag()
		if f == true:
			d.flag_seen = true
			flag_was = true
		elif f == false and flag_was:
			d.flag_flicker = true
		var h := _mol_h()
		if last_h < 1000.0 and last_h - h > 40.0 and float(d.skip_at) < 0.0:
			d.skip_at = _gt
			d.jump = last_h - h
			d.h_after = h
		last_h = h
		var outside_cam := c != p.camera and _exterior()
		if outside_cam and outside_since < 0.0:
			outside_since = _gt
		if float(d.first_press) >= 0.0 and float(d.short_at) < 0.0 and mol.drop_variant == Mol.DropVariant.SHORT:
			d.short_at = _gt
		if float(d.first_press) >= 0.0 and c is DropCam and (c as DropCam)._fade.color.a > 0.5:
			d.dipped = true
		# Overslaan: pas als het buitenbeeld er een tijdje is (het shot onder het schip loopt), hoog genoeg.
		if skip and _cine_ready and float(d.short_at) < 0.0 and tries < 6 and outside_cam \
				and _gt - outside_since > 0.3 and h > 200.0 and _gt >= next_try:
			tries += 1
			if float(d.first_press) < 0.0:
				d.first_press = _gt
				d.h_press = h
			next_try = _gt + 0.3
			await _tap("skip_cinematic")
		if not tested and outside_cam and h > 120.0:
			tested = true
			var l0 := mol.to_local_mol(p.global_position)
			Input.action_press("move_forward")
			await _wait(0.5)
			Input.action_release("move_forward")
			d.input_moved = mol.to_local_mol(p.global_position).distance_to(l0)
			_key(KEY_ESCAPE)
			await _frames(3)
			var paused: bool = main._pause.visible
			_key(KEY_ESCAPE)
			await _frames(3)
			_expect(paused and not main._pause.visible and not get_tree().paused, "Esc tijdens de val: pauzemenu open en weer dicht")
	d.duration = _gt - float(d.start)
	_expect(mol.mode == Mol.Mode.PARKED, "de Mol is geland (%.1f s speltijd)" % d.duration)
	_expect(d.inside, "de speler bleef de hele val in de Mol (ook door de baai van de hub)")
	_expect(d.cine_cam, "buitenbeeld tijdens de val")
	_expect(int(d.mismatch_frames) == 0, "het buitenbeeld toont de Mol vanaf het eerste beeld (%d beelden, %.3f s speltijd waarin het lichaam van de Mol nog in de hub stond, QA-14)" % [
			d.mismatch_frames, d.mismatch_s])
	_expect(float(d.cam_far) < 150.0, "het buitenbeeld blijft bij de Mol (verst %.0f m)" % d.cam_far)
	if extra:
		_expect(float(d.input_moved) >= 0.0 and float(d.input_moved) < 0.05,
				"tijdens het buitenbeeld verplaatsen de toetsen de speler niet (%.3f m)" % d.input_moved)
	if _has_flag():
		_expect(d.flag_seen, "Player.cinematic staat aan tijdens de val")
		_expect(not d.flag_flicker, "Player.cinematic blijft aan tot de landing")
	else:
		_na("Player.cinematic tijdens de val")
	return d


## Overdracht na de landing en alles wat daarna moet kloppen.
func _after_landing(label: String, _d: Dictionary) -> void:
	var t_land := _gt
	var back := await _until(func() -> bool: return _cam() == p.camera and _flag() != true, 3.0)
	var handover := _gt - t_land
	_expect(back, "%s: na de landing de eigen camera terug (na %.2f s)" % [label, handover])
	if _has_flag():
		_expect(handover > 0.3 and handover < 1.5, "%s: overdracht kort na de klap (%.2f s, gepland 0,6-0,8 s)" % [label, handover])
	else:
		_na("%s: overdracht 0,6-0,8 s na de klap (gemeten %.2f s)" % [label, handover])
	await _wait(0.6)
	var t: TerrainAPI = game.terrain
	var mp := mol.body.global_position
	var ground := t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM
	_expect(absf(mp.y - ground) < 0.6, "%s: de Mol staat op de grond (%.2f m)" % [label, mp.y - ground])
	_expect(mol.contains_point(p.global_position), "%s: de speler staat in de Mol" % label)
	_expect(p._attached == null and p._hold_ticks <= 0, "%s: de speler zit niet meer vast" % label)
	_expect(p.is_on_floor(), "%s: de speler staat op de vloer" % label)
	_expect(p.camera.current and absf(p.camera.fov - Settings.get_f("video/fov")) < 0.5, "%s: eigen camera met de eigen FOV" % label)
	_expect(main.hud.visible and _crosshair_visible(), "%s: HUD en vizier terug" % label)
	_expect(_landed_signal, "%s: de landing is gemeld (stempel)" % label)
	var calm := await _until(func() -> bool: return p.camera_fx.trauma() < 0.05, 3.0)
	_expect(calm, "%s: de schok van de landing dooft uit" % label)


func _walk_out_and_back() -> void:
	var start := p.global_position
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 13.0)), 0.6, 12.0)
	_expect(not mol.contains_point(p.global_position) and p.global_position.distance_to(start) > 5.0,
			"met echte invoer uit de Mol gestapt (%.1f m)" % p.global_position.distance_to(start))
	_ground_checks("buiten de Mol")
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 2.0)), 0.5, 10.0)
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, -0.6)), 0.5, 6.0)
	_expect(mol.contains_point(p.global_position), "met echte invoer terug de Mol in")


## Op de grond, op het oppervlak, niet in de rots, in het speelgebied.
func _ground_checks(label: String) -> void:
	var t: TerrainAPI = game.terrain
	var pos := p.global_position
	var surf := t.surface_height_at(pos.x, pos.z)
	var size := t.world_size()
	_expect(p.is_on_floor(), "%s: staat op de grond" % label)
	_expect(absf(pos.y - surf) < 0.6, "%s: op het oppervlak (%.2f m)" % [label, pos.y - surf])
	_expect(t.sdf_at(pos + Vector3(0.0, 1.0, 0.0)) > 0.2, "%s: het hoofd zit niet in de rots" % label)
	_expect(pos.x > 0.0 and pos.z > 0.0 and pos.x < size.x and pos.z < size.z, "%s: binnen het speelgebied" % label)


func _sonar_contacts() -> void:
	mol.press(Mol.Cmd.PING)
	await _wait(2.0)
	if mol.sonar.contacts.is_empty():
		# Een vondst dichter bij de Mol leggen, zodat de sonar zeker iets ziet.
		for it: FindItem in game.finds.items:
			if is_instance_valid(it) and it.carriers.is_empty():
				it.global_position = mol.to_world_mol(Vector3(4.0, -2.0, -8.0))
				break
		await _wait(3.0)
	print(TAG, " sonar: %d echo's in deze wereld" % mol.sonar.contacts.size())


## De hendel trekken, ophalen, en alles wat bij de aankomst in de hub moet kloppen.
func _extract_to_hub() -> void:
	_summary = Vector3i(-1, -1, -1)
	await _pull_lever(Mol.Mode.COUNTDOWN)
	var start := _gt
	var lift_start := -1.0
	var cam_on := -1.0
	var cam_off := -1.0
	var inside := true
	var saw_grapple := false
	while mol.mode != Mol.Mode.DOCKED and _gt - start < 150.0:
		await get_tree().process_frame
		if mol.mode == Mol.Mode.GRAPPLE_DOWN:
			saw_grapple = true
		if mol.mode == Mol.Mode.LIFTING:
			if lift_start < 0.0:
				lift_start = _gt
			if not mol.contains_point(p.global_position):
				inside = false
			if cam_on < 0.0 and _cam() != p.camera:
				cam_on = _gt
			if cam_on >= 0.0 and cam_off < 0.0 and _cam() == p.camera:
				cam_off = _gt
	_expect(saw_grapple and lift_start >= 0.0, "de grijper zakte en trok de Mol omhoog")
	_expect(mol.mode == Mol.Mode.DOCKED, "terug in de baai (%.0f s speltijd)" % (_gt - start))
	_expect(inside, "de speler bleef in de Mol tijdens het ophalen")
	_expect(cam_on >= 0.0 and cam_on - lift_start < 0.5, "buitenbeeld bij het vertrek van de planeet (QA-3)")
	_expect(cam_on < 0.0 or (cam_off >= 0.0 and cam_off - lift_start < DropCam.LIFT_SHOT + 1.5),
			"na het buitenbeeld weer de eigen camera tijdens het ophalen")
	await _wait(3.0)
	_expect(ship.contains(p.global_position) and mol.contains_point(p.global_position), "aangekomen in de hub, in de Mol")
	_expect(not ship.doors_open and ship.door_amount < 0.05, "de luiken zijn weer dicht")
	_expect(_cam() == p.camera and _flag() != true, "in de hub de eigen camera")
	_expect(main.hud._result.visible, "het incidentrapport staat in beeld")
	_expect(_summary.z == 0, "niemand achtergebleven (%d)" % _summary.z)


func _walk_into_mol_from_quay() -> void:
	p.global_position = ship.global_transform * Vector3(0.75, 0.05, 8.8)
	p.velocity = Vector3.ZERO
	await _wait(0.4)
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, 2.0)), 0.5, 10.0)
	await _walk_to(mol.to_world_mol(Vector3(0.0, -1.5, -0.6)), 0.5, 6.0)
	_expect(mol.contains_point(p.global_position), "met echte invoer van de kade de Mol in")


## De hendel in het vizier nemen en E drukken. Geeft de speltijd terug waarop de Mol `want` werd.
func _pull_lever(want: Mol.Mode) -> float:
	var lever: Interactable = mol.get("_lever_button")
	var aimed := false
	for c: Vector3 in [Vector3(0.7, -1.45, -1.3), Vector3(0.4, -1.45, -1.5), Vector3(1.0, -1.45, -1.0),
			Vector3(0.0, -1.45, -1.2), Vector3(1.2, -1.45, -1.6)]:
		p.global_position = mol.to_world_mol(c)
		p.velocity = Vector3.ZERO
		await _frames(3)
		_aim_at(lever.global_position)
		await get_tree().physics_frame
		if p.aimed_interactable() == lever:
			aimed = true
			break
	if aimed:
		_key(KEY_E)
	else:
		print(TAG, " let op: de hendel kwam niet in het vizier, dus via mol.press")
		mol.press(Mol.Cmd.DEPART)
	var ok := await _until(func() -> bool: return mol.mode == want, 2.0)
	_expect(ok, "de hendel (%s) start %s" % ["vizier + E" if aimed else "mol.press", Mol.Mode.keys()[want]])
	p.head.rotation.x = 0.0
	return _gt


func _open_terminal_by_key() -> bool:
	p.global_position = ship.anchor_position("Terminal_Use") + Vector3(0.0, 0.05, 0.0)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	p.head.rotation.x = 0.0
	await _frames(4)
	var knob := p.aimed_interactable()
	if knob == null or not knob.hint.begins_with("E: opdracht"):
		print(TAG, " let op: de terminal staat niet in het vizier (%s)" % (knob.hint if knob else "niets"))
	_key(KEY_E)
	await _frames(3)
	return main._terminal.visible


## Op de knop van opdracht `index` drukken: focus en Enter (zoals met het toetsenbord).
func _press_card(index: int) -> void:
	var cards: Array = (main._terminal._cards as HBoxContainer).get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	if index >= cards.size():
		_expect(false, "opdrachtkaart %d bestaat" % index)
		return
	var b := (cards[index] as Node).find_children("*", "Button", true, false)[0] as Button
	var before: Dictionary = game.company.contract
	b.grab_focus()
	await _frames(1)
	_key(KEY_ENTER)
	await _frames(2)
	if game.company.contract == before and not b.disabled:
		print(TAG, " let op: Enter drukte de knop niet in, dus via het signaal")
		b.pressed.emit()
		await _frames(2)


# --- Hulp ----------------------------------------------------------------------------------------

## Te voet naar `target` met echte invoer (vooruit, naar het doel kijken). True als hij er raakt.
func _walk_to(target: Vector3, reach := 0.4, limit := 10.0) -> bool:
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


func _aim_at(world: Vector3) -> void:
	var from := p.camera.global_position
	var d := world - from
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


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


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()


func _has_flag() -> bool:
	return p != null and "cinematic" in p


func _flag() -> Variant:
	return p.get("cinematic") if _has_flag() else null


func _crosshair_visible() -> bool:
	var c: Control = main.hud.crosshair
	return c.is_visible_in_tree() and c.modulate.a > 0.05


## Waar staat iemand t.o.v. de Mol (lokaal)? "cabine" (binnen), "klep" (de open laadklep), "dak",
## "onder" (tussen de rupsen, onder de buik) of "grond" (ernaast). De rupsen liggen op ±3,1 m, de
## neus tot z ≈ −7,5, de klep begint op z ≈ +4,3, de vloer van de cabine op y ≈ −1,8.
func _place_name(local: Vector3) -> String:
	if Mol.INSIDE.has_point(local):
		return "cabine"
	if absf(local.x) < 2.6 and local.z >= 4.3 and local.z < 10.0 and local.y > -3.0 and local.y < -0.3:
		return "klep"
	var over := absf(local.x) < 3.4 and local.z > -7.5 and local.z < 4.3
	if over and local.y >= 1.9:
		return "dak"
	if over and local.y > -3.2:
		return "onder"
	return "grond"


## Een opdracht kiezen (Enter op de eerste vrije KIEZEN-knop) terwijl de Mol niet in de baai staat:
## er verandert niets, en het menu zegt waarom.
func _expect_choose_refused(label: String) -> void:
	var before: Dictionary = game.company.contract
	var seed_before := game.pit_seed
	var b: Button = null
	for n: Button in main._terminal.find_children("*", "Button", true, false):
		if not n.is_queued_for_deletion() and n.text == "KIEZEN" and not n.disabled:
			b = n
			break
	if b == null:
		_expect(true, "%s: geen actieve KIEZEN-knop (kiezen kan niet)" % label)
		return
	b.grab_focus()
	await _frames(1)
	_key(KEY_ENTER)
	await _wait(0.5)
	var note_text: String = (main._terminal._note as Label).text
	_expect(game.company.contract == before and game.pit_seed == seed_before and note_text.contains("Kan nu niet"),
			"%s: KIEZEN verandert niets en zegt waarom (\"%s\")" % [label, note_text])


## Buiten de hub (het buitenschip of lager).
func _exterior() -> bool:
	return game.exterior != null and mol.body.global_position.y < game.exterior.dock_position().y + 50.0


func _mol_h() -> float:
	var t: TerrainAPI = game.terrain
	var mp := mol.body.global_position
	return mp.y - (t.surface_height_at(mp.x, mp.z) - Mol.TRACK_BOTTOM)


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


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print(TAG, " ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)


func _na(what: String) -> void:
	_missing.append(what)
	print(TAG, " NOG NIET BESCHIKBAAR: ", what)


func _finish() -> void:
	print(TAG, " %s: %d controles, %d mislukt, %d nog niet beschikbaar → %s" % [_variant, _checks, _failures.size(),
			_missing.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print(TAG, " MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)
