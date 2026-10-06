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
	# Tekstlint (ui2-07): de stijlregels en de woordenlijst over alle spelertekst in de bron. Met
	# --only=text enkel dit (snel, geen wereld): voor elk pakket dat nieuwe tekst schrijft.
	_text_lint()
	if str(CmdArgs.value("only", "")) == "text":
		_finish()
		return
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
	# ui-05: geen HUD-tekst kleiner dan 18 px op 1080p (hud-menu.md §4.9). Ook wat pas later in beeld
	# komt (rapport, aftelling, meldingen van elke soort) staat al in de boom.
	for kind: String in Hud.TOAST_KINDS:
		main.hud.toast("Test %s" % kind, kind)
	var small := PackedStringArray()
	var labels := 0
	for l: Label in main.hud.find_children("*", "Label", true, false):
		labels += 1
		var fs := l.get_theme_font_size("font_size")
		if fs < Hud.MIN_FONT:
			small.append("%s '%s' %d px" % [l.get_path().get_name(l.get_path().get_name_count() - 1), l.text.left(24), fs])
	_expect(labels > 40 and small.is_empty(), "alle %d labels in de HUD zijn minstens %d px%s" % [labels, Hud.MIN_FONT,
			"" if small.is_empty() else " (te klein: %s)" % ", ".join(small)])
	# ui2-09: toetsen komen uit de bindings, ook in een zin.
	_expect(Settings.fill_keys("{scan}: blips") == Settings.key_of("scan") + ": blips" and Settings.move_keys().length() >= 4,
			"toetsen in een zin uit de bindings ({scan} → %s, lopen %s)" % [Settings.key_of("scan"), Settings.move_keys()])
	var r_key := InputEventKey.new()
	r_key.physical_keycode = KEY_R
	Settings.rebind("scan", r_key)
	_expect(Settings.fill_keys("Press {scan} to scan") == "Press R to scan", "omgezette toets staat meteen in de zin (R)")
	Settings.reset_section("keys")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	Input.parse_input_event(pad)
	await _frames(2)
	_expect(Settings.device == Settings.DEVICE_PAD and Settings.key_of("interact") == "E", "controller in de hand: zonder knop voor de actie blijft de toets staan")
	_key(KEY_SHIFT)
	await _frames(2)
	_expect(Settings.device == Settings.DEVICE_KEYBOARD, "terug op het toetsenbord")
	_expect(Settings.event_label(pad) == "A", "controllerknop heet A")

	# ui2-10: de uitnodiging toont geen adres van een virtuele netwerkkaart (VirtualBox heet hier "Ethernet 3").
	var cases := {["192.168.56.1", "Ethernet 3"]: true, ["192.168.56.101", ""]: true, ["192.168.137.1", "Ethernet 2"]: true,
			["192.168.17.1", "Ethernet 4"]: true, ["172.20.48.1", ""]: true, ["10.0.0.1", ""]: true,
			["192.168.1.23", "Ethernet"]: false, ["192.168.0.104", "Wi-Fi"]: false, ["10.0.0.15", ""]: false,
			["100.101.2.3", "Tailscale"]: false, ["192.168.1.40", "VirtualBox Host-Only Network"]: true}
	var wrong := PackedStringArray()
	for c: Array in cases:
		if StartMenu.is_host_only(c[0], c[1]) != bool(cases[c]):
			wrong.append("%s (%s)" % [c[0], c[1]])
	var on_this_pc := PackedStringArray()
	for itf: Dictionary in IP.get_local_interfaces():
		for adr: String in itf.get("addresses", []):
			if not adr.contains(":"):
				on_this_pc.append("%s=%s%s" % [str(itf.get("friendly", "")), adr, " (weg)" if StartMenu.is_host_only(adr, str(itf.get("friendly", ""))) else ""])
	print("[ui_test] netwerkkaarten op deze pc: ", ", ".join(on_this_pc), " → uitnodiging: ", StartMenu.join_addresses())
	_expect(wrong.is_empty(), "uitnodiging: virtuele netwerkkaarten eruit, het thuisnet erin%s" % ("" if wrong.is_empty() else " (fout: %s)" % ", ".join(wrong)))

	# ui2-07: wat de speler ziet (labels, knoppen, Label3D) volgt de stijlregels, met het lettertype erbij.
	await _sweep_shown_text(p)
	# ui2-04: de pilootstrook en de sonar overlappen nooit, ook niet met een grotere interface.
	await _check_pilot_layout(p)

	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(main._pause.visible and get_tree().paused, "Esc opent het pauzemenu (solo: het spel staat stil)")
	_key(KEY_ESCAPE)
	await _frames(3)
	_expect(not main._pause.visible and not get_tree().paused, "Esc sluit het pauzemenu weer")
	_expect(p != null, "speler gespawnd")
	_finish()


func _finish() -> void:
	print("[ui_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[ui_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _text_lint() -> void:
	var found := TextLint.scan_sources(str(CmdArgs.value("lint-root", "res://")))
	for line in TextLint.report(found):
		print("[tekst] ", line)
	_expect(found.is_empty(), "tekstlint: alle spelertekst volgt de stijlregels en de woordenlijst (%d fouten%s)" % [
			found.size(), "" if found.is_empty() else ", zie [tekst] hierboven"])
	# De lint zelf: een paar gekende fouten moet hij zien, en de goede vorm niet.
	var bad := {"REP %+d": "signed", "SCAN T1 · %d M": "unit_caps", "%d shift(s) left": "plural", "WASD, Space: fly": "keys_wasd",
			"Press Q: blips": "keys_press", "BEACONS 3 [G]": "keys_bracket", "PAY X1.35": "mult", "REP -1": "minus",
			"Crew funds: €40": "funds", "At the terminal on the bridge": "terminal", "Appraised: Skull, 100%: €563": "two_colons",
			"Quota missed (€900): fine": "fine", "laughing in The Mole": "mole_case"}
	var missed := PackedStringArray()
	for s: String in bad:
		if not TextLint.check(s).any(func(h: Array) -> bool: return h[0] == bad[s]):
			missed.append("%s (%s)" % [s, bad[s]])
	var good := ["REP −1", "SCAN T1 · %d m", "E: choose a contract", "PAY ×1.35", "MAGMA 20 m below", "Quota missed: €550 fine",
			"Press %s to scan", "−€250", "3–5 pieces", "PRESS A KEY…"]
	for s: String in good:
		if not TextLint.check(s).is_empty():
			missed.append("vals alarm: %s %s" % [s, str(TextLint.check(s))])
	_expect(missed.is_empty(), "de tekstlint herkent de gekende fouten en laat de goede vorm door%s" % [
			"" if missed.is_empty() else " (%s)" % ", ".join(missed)])


## Alle tekst die nu in de boom staat, met de menu's open (de contractbalie met een reputatie van −1,
## de winkel, het pauzemenu met de uitnodiging), door TextLint.check_shown.
func _sweep_shown_text(p: Player) -> void:
	var c: Company = main.game.company
	var rep0 := c.reputation
	c.reputation = -1
	main._terminal.open(c)
	main._shop.open(c, Upgrades.SUPPLY_DESK)
	await _frames(3)
	var bad := PackedStringArray()
	var seen := 0
	for n: Node in get_tree().root.find_children("*", "", true, false):
		var text := ""
		var bungee := false
		if n is Label:
			text = (n as Label).text
			bungee = (n as Label).get_theme_font("font") == UiTheme.HEADING
		elif n is Button:
			text = (n as Button).text
			bungee = (n as Button).get_theme_font("font") == UiTheme.HEADING
		elif n is Label3D:
			text = (n as Label3D).text
			bungee = (n as Label3D).font == UiTheme.HEADING
		elif n is RichTextLabel:
			text = (n as RichTextLabel).get_parsed_text()
		if text.strip_edges() == "" or n.is_in_group("dev_only") or n is TuningMenu or n.get_parent() is TuningMenu:
			continue
		seen += 1
		for h: Array in TextLint.check_shown(text, bungee):
			bad.append("%s '%s' [%s %s]" % [n.name, text.left(40).replace("\n", " "), h[0], h[2]])
	_expect(seen > 60 and bad.is_empty(), "de %d teksten in beeld volgen de stijlregels%s" % [seen, "" if bad.is_empty() else " (%s)" % ", ".join(bad)])
	var rep_shown := false
	for l: Label in main._terminal.find_children("*", "Label", true, false):
		rep_shown = rep_shown or l.text.contains("REP −1")
	_expect(rep_shown, "de contractbalie toont de reputatie met een echt minteken (REP −1)")
	main._shop.close()
	main._terminal.close()
	c.reputation = rep0
	await _frames(2)


## In de stoel met buitenzicht, bij een interface van 100, 125 en 150 %: de pilootstrook ligt niet
## onder de sonar (ui2-04).
func _check_pilot_layout(p: Player) -> void:
	var mol: Mol = main.game.mol
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.0)))
	await _frames(5)
	mol.press(Mol.Cmd.SEAT)
	await _frames(20)
	_expect(p.seated, "in de stoel van de Mol")
	p.chase.activate()
	for scale in [1.0, 1.25, 1.5]:
		Settings.set_value("interface/ui_scale", scale, false)
		await _frames(4)
		var r: Dictionary = main.hud.layout_rects()
		var ok: bool = r.has("pilot") and r.has("sonar") and not (r.pilot as Rect2).intersects(r.sonar as Rect2)
		var inside: bool = r.has("pilot") and Rect2(Vector2.ZERO, main.hud.get_viewport_rect().size).encloses(r.pilot as Rect2)
		_expect(ok and inside, "interface %d%%: pilootstrook %s en sonar %s overlappen niet, strook in beeld" % [
				int(scale * 100), str(r.get("pilot")), str(r.get("sonar"))])
	Settings.reset_section("interface")
	p.camera.make_current()
	mol.leave_seat()
	await _frames(5)


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
