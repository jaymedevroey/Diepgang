extends Node
## Test van de menu's met echte invoer (headless): Esc sluit de instellingen, toetsen omzetten,
## instellingen bewaren, het pauzemenu openen en sluiten, en de HUD in het spel.
## tools\godot.cmd --headless --path game -- --scenario=ui_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		print("[ui_test] GEFAALD: time-out")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	# 0. Ontwikkelaarstoetsen (gevoel-07, ui-06): zonder ontwikkelaarsmodus (de release-build) geen
	# F1 (tuning) en geen V (vliegen); in deze build enkel als de ontwikkelaarsmodus aan staat.
	var plain := InputSetup.keys_for(false)
	_expect(not plain.has("toggle_tuning") and not plain.has("toggle_fly") and InputSetup.keys_for(true).has("toggle_tuning"),
			"release-build: geen toets voor het tuningmenu of vliegen")
	var f1_bound := not InputMap.action_get_events("toggle_tuning").is_empty()
	_expect(f1_bound == CmdArgs.dev_mode(), "F1 opent het tuningmenu enkel in de ontwikkelaarsmodus (nu %s, F1 %s)" % [
			"aan" if CmdArgs.dev_mode() else "uit", "gebonden" if f1_bound else "vrij"])
	# 1. Instellingen: openen, Esc sluit.
	var settings := SettingsMenu.new()
	main.get_node("HUD").add_child(settings)
	await _frames(2)
	settings.open()
	await _frames(2)
	_expect(settings.visible, "instellingen open")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not settings.visible, "Esc sluit de instellingen (ook met de focus op een knop)")

	# 1b. Zoals in het hoofdmenu: instellingen via de knop van het startmenu, met de focus op een knop.
	var start := StartMenu.new()
	main.get_node("HUD").add_child(start)
	await _frames(3)
	start._open_settings()
	await _frames(2)
	_expect(start._settings.visible, "instellingen open vanuit het hoofdmenu")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not start._settings.visible, "Esc sluit de instellingen in het hoofdmenu")
	start.queue_free()
	await _frames(2)

	# 2. Toets omzetten: klik op de knop van de toeter, druk G.
	settings.open()
	settings._show("toetsen")
	await _frames(2)
	var horn_button: Button = null
	for b in settings.find_children("*", "Button", true, false):
		if (b as Button).text == Settings.key_of("horn").to_upper() and b.get_parent().get_child(0) is Label and (b.get_parent().get_child(0) as Label).text == "Horn":
			horn_button = b
	_expect(horn_button != null, "knop voor de toeter gevonden")
	var old_key := Settings.key_of("horn")
	if horn_button:
		horn_button.pressed.emit()
		await _frames(1)
		_key(KEY_G)
		await _frames(2)
		_expect(Settings.key_of("horn") == "G", "toeter omgezet naar G (was %s)" % old_key)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_G
		ev.pressed = true
		_expect(InputMap.event_is_action(ev, "horn"), "de G-toets doet nu de toeter in het spel")
	Settings.reset_section("keys")
	await _frames(1)
	_expect(Settings.key_of("horn") == "H", "standaardtoetsen terug (H)")
	settings.close()

	# 3. Een instelling bewaren en weer inlezen.
	Settings.set_value("video/fov", 95.0)
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	_expect(is_equal_approx(float(cfg.get_value("video", "fov", 0.0)), 95.0), "FOV bewaard in user://settings.cfg")
	Settings.reset_section("video")
	_expect(is_equal_approx(Settings.get_f("video/fov"), 80.0), "beeld terug naar standaard")

	# 4. Spel: HUD en pauzemenu.
	Net.start_solo()
	var p: Player = await main.game.player_spawned
	await _frames(30)
	_expect(main.hud.visible, "HUD zichtbaar in het spel")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(main._pause.visible and get_tree().paused, "Esc opent het pauzemenu (solo: het spel staat stil)")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not main._pause.visible and not get_tree().paused, "Esc sluit het pauzemenu weer")
	_expect(p != null, "speler gespawnd")

	print("[ui_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[ui_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[ui_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
