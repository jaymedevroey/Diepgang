class_name PauseMenu
extends Control
## Esc in het spel. In co-op loopt het spel door (zoals in DRG en PEAK); solo pauzeert het.
## Hervatten, vrienden uitnodigen (nu: je IP; Steam-uitnodigingen in M4), instellingen,
## de ploeg, terug naar het hoofdmenu, afsluiten.

signal leave_requested

var _buttons: VBoxContainer
var _invite: PanelContainer
var _invite_label: Label
var _players: VBoxContainer
var _settings: SettingsMenu
var _note: Label
var _was_captured := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_top", 90)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	margin.add_child(row)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 400
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var title := Label.new()
	title.text = "PAUZE"
	title.theme_type_variation = &"Title"
	col.add_child(title)
	col.add_child(HazardStrip.new(8.0))
	_note = Label.new()
	_note.theme_type_variation = &"Caption"
	var nm := MarginContainer.new()
	nm.add_theme_constant_override("margin_top", 8)
	nm.add_theme_constant_override("margin_bottom", 30)
	nm.add_child(_note)
	col.add_child(nm)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)
	_add("HERVATTEN", close)
	_add("VRIENDEN UITNODIGEN", _toggle_invite)
	_add("INSTELLINGEN", _open_settings, true)
	_add("TERUG NAAR HOOFDMENU", func() -> void: leave_requested.emit(), true)
	_add("AFSLUITEN", func() -> void: get_tree().quit(), true)

	# Rechts: uitnodigen en de ploeg.
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 420
	side.add_theme_constant_override("separation", 16)
	row.add_child(side)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 120
	side.add_child(spacer)
	_invite = PanelContainer.new()
	_invite.theme_type_variation = &"Card"
	_invite.visible = false
	side.add_child(_invite)
	var ic := VBoxContainer.new()
	ic.add_theme_constant_override("separation", 8)
	_invite.add_child(ic)
	var ih := Label.new()
	ih.text = "VRIENDEN UITNODIGEN"
	ih.theme_type_variation = &"SubHeading"
	ic.add_child(ih)
	_invite_label = Label.new()
	_invite_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ic.add_child(_invite_label)
	var players_card := PanelContainer.new()
	players_card.theme_type_variation = &"Card"
	side.add_child(players_card)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 6)
	players_card.add_child(pc)
	var ph := Label.new()
	ph.text = "PLOEG"
	ph.theme_type_variation = &"SubHeading"
	pc.add_child(ph)
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 4)
	pc.add_child(_players)

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void: _buttons.get_child(0).grab_focus())
	add_child(_settings)


func open() -> void:
	if visible:
		return
	_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var solo := Net.mode == Net.Mode.SOLO
	get_tree().paused = solo
	_note.text = "Het spel staat stil." if solo else "Het spel loopt door: je ploeg wacht niet."
	_invite.visible = false
	_refresh_players()
	Sfx.ui("open")
	_buttons.get_child(0).grab_focus()


func close() -> void:
	if not visible:
		return
	_settings.visible = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.ui("back")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _settings.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _add(text: String, action: Callable, ghost := false) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(400, 54 if not ghost else 48)
	b.add_theme_font_size_override("font_size", 22 if not ghost else 18)
	if ghost:
		b.theme_type_variation = &"GhostButton"
	b.pressed.connect(func() -> void:
		Sfx.ui("click")
		action.call())
	b.mouse_entered.connect(func() -> void: Sfx.ui("hover"))
	_buttons.add_child(b)


func _toggle_invite() -> void:
	_invite.visible = not _invite.visible
	if Net.mode == Net.Mode.SOLO:
		_invite_label.text = "Je speelt solo. Wil je met vrienden spelen? Ga terug naar het hoofdmenu en kies HOSTEN."
	elif Net.mode == Net.Mode.CLIENT:
		_invite_label.text = "Je bent te gast. Vrienden doen mee via het IP-adres van de host."
	elif Settings.get_b("interface/hide_ip"):
		_invite_label.text = "Je IP-adres is verborgen (Instellingen > Interface). Vrienden kiezen MEEDOEN en vullen jouw IP in. Steam-uitnodigingen komen in een volgende versie."
	else:
		_invite_label.text = "Vrienden kiezen MEEDOEN en vullen dit in:\n%s   (poort %d)\nSteam-uitnodigingen komen in een volgende versie." % [
			", ".join(StartMenu.local_ips()), int(CmdArgs.value("port", Net.DEFAULT_PORT))]


func _open_settings() -> void:
	_settings.open()


func _refresh_players() -> void:
	for c in _players.get_children():
		c.queue_free()
	var game := get_tree().root.find_child("Game", true, false)
	if game == null:
		return
	var i := 0
	for pl: Player in game.get_node("Players").get_children():
		i += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = pl.color
		row.add_child(dot)
		var l := Label.new()
		l.text = "Speler %d%s%s" % [i, "  (jij)" if pl.is_local else "", "  · host" if pl.peer_id == 1 and Net.mode != Net.Mode.SOLO else ""]
		row.add_child(l)
		_players.add_child(row)
