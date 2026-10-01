class_name StartMenu
extends Control
## Hoofdmenu: links een kolom in de huisstijl, rechts de levende achtergrond (MenuBackdrop).
## Solo, hosten, meedoen via IP (Steam-uitnodigingen komen in M4), instellingen, afsluiten.

signal solo_chosen
signal host_chosen
signal join_chosen(address: String)

const LAST_IP_FILE := "user://last_ip.txt"
const VERSION := "Playtest 0.3 · oktober 2026"

var backdrop: MenuBackdrop
var _ip: LineEdit
var _status: Label
var _join_card: Control
var _buttons: VBoxContainer
var _settings: SettingsMenu
var _fade: ColorRect


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Leesbaarheid: links donker verloop over de 3D-scène, onderaan een dunne vignet.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.NIGHT, 0.92))
	g.add_point(0.45, Color(UiTheme.NIGHT, 0.55))
	g.set_color(g.get_point_count() - 1, Color(UiTheme.NIGHT, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 900
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 88)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 48)
	margin.add_theme_constant_override("margin_right", 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.custom_minimum_size.x = 440
	margin.add_child(col)

	# Logo: DIEPGANG met een gele waarschuwingsstrook en een knipoog van de firma eronder.
	var logo := Label.new()
	logo.text = "DIEPGANG"
	logo.theme_type_variation = &"Title"
	logo.add_theme_font_size_override("font_size", 92)
	logo.add_theme_color_override("font_outline_color", UiTheme.ANTHRACITE_LO)
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	logo.add_theme_constant_override("shadow_offset_y", 7)
	logo.add_theme_constant_override("shadow_offset_x", 0)
	col.add_child(logo)
	var strip := HazardStrip.new(10.0)
	strip.speed = 10.0
	strip.custom_minimum_size.x = 440
	col.add_child(strip)
	var tag := Label.new()
	tag.text = "DIEPGANG BV  ·  BOORPLOEG GEZOCHT  ·  ERVARING NIET VEREIST"
	tag.theme_type_variation = &"Caption"
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_constant_override("line_spacing", 0)
	col.add_child(_spaced(tag, 10, 44))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)
	_menu_button("SOLO SPELEN", "Alleen de put in. Ideaal om de knoppen te leren.", func() -> void: _choose(solo_chosen.emit))
	_menu_button("HOSTEN", "Start een ploeg; vrienden doen mee met jouw IP-adres.", func() -> void: _choose(host_chosen.emit))
	_menu_button("MEEDOEN", "Bij een vriend die host. Steam-uitnodigingen komen later.", _toggle_join)

	# Meedoen: een kaartje met het IP-veld, klapt open onder de knop.
	_join_card = PanelContainer.new()
	_join_card.theme_type_variation = &"Card"
	_join_card.visible = false
	_buttons.add_child(_join_card)
	var jc := VBoxContainer.new()
	jc.add_theme_constant_override("separation", 10)
	_join_card.add_child(jc)
	var jl := Label.new()
	jl.text = "IP-adres van de host"
	jl.theme_type_variation = &"Caption"
	jc.add_child(jl)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	jc.add_child(jrow)
	_ip = LineEdit.new()
	_ip.placeholder_text = "bv. 192.168.1.23"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip.text = _load_last_ip()
	_ip.text_submitted.connect(func(_t: String) -> void: _join())
	jrow.add_child(_ip)
	var go := Button.new()
	go.text = "VERBINDEN"
	go.pressed.connect(_join)
	jrow.add_child(go)

	_menu_button("INSTELLINGEN", "Beeld, geluid, besturing, toetsen.", _open_settings, true)
	_menu_button("AFSLUITEN", "", func() -> void: get_tree().quit(), true)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_color_override("font_color", UiTheme.DANGER)
	_status.custom_minimum_size.x = 440
	col.add_child(_spaced(_status, 14, 0))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var foot := Label.new()
	foot.text = VERSION
	foot.theme_type_variation = &"Caption"
	col.add_child(foot)

	_settings = SettingsMenu.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		if backdrop:
			backdrop.go_to("main")
		_buttons.get_child(0).grab_focus())
	add_child(_settings)

	_fade = ColorRect.new()
	_fade.color = Color(UiTheme.NIGHT, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.2).set_ease(Tween.EASE_OUT)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_buttons.get_child(0).grab_focus()
	if CmdArgs.has("menu-shot"):
		await get_tree().create_timer(2.5).timeout
		await _shot("menu")
		if CmdArgs.has("menu-join"):
			_toggle_join()
			await get_tree().create_timer(2.6).timeout
			await _shot("menu_meedoen")
		if CmdArgs.has("menu-settings"):
			_open_settings()
			await get_tree().create_timer(2.6).timeout
			await _shot("menu_instellingen")
		get_tree().quit(0)


func show_error(text: String) -> void:
	visible = true
	_fade.color.a = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = text


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _join_card.visible and not _settings.visible:
		_toggle_join()
		get_viewport().set_input_as_handled()


func _menu_button(text: String, tip: String, action: Callable, ghost := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 58 if not ghost else 50)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 24 if not ghost else 19)
	if ghost:
		b.theme_type_variation = &"GhostButton"
	b.tooltip_text = tip
	b.pressed.connect(func() -> void:
		Sfx.ui("click")
		action.call())
	# Bij hover schuift de knop een tikje naar rechts (een kleine beloning, zoals in DRG).
	b.mouse_entered.connect(func() -> void:
		Sfx.ui("hover")
		create_tween().tween_property(b, "position:x", 10.0, 0.12).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		create_tween().tween_property(b, "position:x", 0.0, 0.15).set_ease(Tween.EASE_OUT))
	b.focus_entered.connect(func() -> void: b.position.x = 10.0)
	b.focus_exited.connect(func() -> void: b.position.x = 0.0)
	_buttons.add_child(b)
	return b


func _spaced(c: Control, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(c)
	return m


func _toggle_join() -> void:
	_join_card.visible = not _join_card.visible
	if backdrop:
		backdrop.go_to("join" if _join_card.visible else "main")
	if _join_card.visible:
		_ip.grab_focus()
		_ip.caret_column = _ip.text.length()


func _open_settings() -> void:
	if backdrop:
		backdrop.go_to("settings")
	_settings.open()


## Keuze gemaakt: kort naar zwart, dan start de sessie (het laadscherm neemt over).
func _choose(emit: Callable) -> void:
	_status.text = ""
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		visible = false
		_buttons.mouse_filter = Control.MOUSE_FILTER_PASS
		emit.call())


func _join() -> void:
	var address := _ip.text.strip_edges()
	if address == "":
		_status.text = "Vul eerst het IP-adres van de host in."
		return
	var f := FileAccess.open(LAST_IP_FILE, FileAccess.WRITE)
	if f:
		f.store_string(address)
	_choose(func() -> void: join_chosen.emit(address))


func _load_last_ip() -> String:
	return FileAccess.get_file_as_string(LAST_IP_FILE).strip_edges() if FileAccess.file_exists(LAST_IP_FILE) else ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[menu] screenshot: ", path)


## Privé-IPv4-adressen van deze pc (om aan vrienden in het LAN door te geven).
static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) in range(16, 32)) or a.begins_with("100."):
			out.append(a)
	return out
