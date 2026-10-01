class_name SettingsMenu
extends Control
## Instellingen (hoofdmenu en pauzemenu): tabbladen links, rijen rechts. Alles werkt meteen en
## wordt meteen bewaard (Settings). Toetsen omzetten: klik, druk een toets of muisknop, Esc annuleert.

signal closed

const TABS := [["beeld", "BEELD"], ["geluid", "GELUID"], ["besturing", "BESTURING"], ["toetsen", "TOETSEN"], ["interface", "INTERFACE"]]

var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _current := ""
var _waiting_for: Button = null
var _waiting_action := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 640)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "INSTELLINGEN"
	title.theme_type_variation = &"Heading"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var hint := Label.new()
	hint.text = "Alles werkt meteen en wordt bewaard"
	hint.theme_type_variation = &"Caption"
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hint)
	outer.add_child(HazardStrip.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	outer.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size.x = 200
	tabs.add_theme_constant_override("separation", 6)
	body.add_child(tabs)
	var group := ButtonGroup.new()
	for t: Array in TABS:
		var b := Button.new()
		b.text = t[1]
		b.theme_type_variation = &"TabButton"
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show.bind(t[0]))
		tabs.add_child(b)
		_tab_buttons[t[0]] = b
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var reset := Button.new()
	reset.text = "STANDAARD"
	reset.theme_type_variation = &"GhostButton"
	reset.tooltip_text = "Zet dit tabblad terug op de standaardwaarden"
	reset.pressed.connect(func() -> void:
		Settings.reset_section(_section_of(_current))
		_rebuild(_current))
	tabs.add_child(reset)
	var back := Button.new()
	back.text = "TERUG"
	back.pressed.connect(close)
	tabs.add_child(back)

	var pages := PanelContainer.new()
	pages.theme_type_variation = &"Card"
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	for t: Array in TABS:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 4)
		page.visible = false
		stack.add_child(page)
		_pages[t[0]] = page
		_rebuild(t[0])
	_tab_buttons["beeld"].button_pressed = true
	_show("beeld")


func open() -> void:
	visible = true
	_show(_current if _current != "" else "beeld")
	_tab_buttons[_current].grab_focus()


func close() -> void:
	_cancel_rebind()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_for != null:
		return # _input vangt de toets op
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _waiting_for == null or not visible:
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		if key.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		var ev := InputEventKey.new()
		ev.physical_keycode = key.physical_keycode
		_finish_rebind(ev)
	elif mouse and mouse.pressed and mouse.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()
		var ev := InputEventMouseButton.new()
		ev.button_index = mouse.button_index
		_finish_rebind(ev)


func _show(tab: String) -> void:
	_current = tab
	for k: String in _pages:
		_pages[k].visible = k == tab
	_tab_buttons[tab].button_pressed = true


func _section_of(tab: String) -> String:
	return {"beeld": "video", "geluid": "audio", "besturing": "controls", "toetsen": "keys", "interface": "interface"}[tab]


# --- Pagina's --------------------------------------------------------------------------------

func _rebuild(tab: String) -> void:
	var page: VBoxContainer = _pages[tab]
	for c in page.get_children():
		c.queue_free()
	match tab:
		"beeld":
			_option(page, "video/window_mode", "Weergave", ["Venster", "Volledig scherm (randloos)", "Volledig scherm (exclusief)"])
			_toggle(page, "video/vsync", "Verticale synchronisatie", "Geen scheuren in het beeld; kan wat vertraging geven.")
			_option(page, "video/max_fps", "Beeldsnelheid maximum", Settings.FPS_CAPS.map(func(v: int) -> String: return "Onbeperkt" if v == 0 else "%d fps" % v))
			_option(page, "video/msaa", "Anti-aliasing (randen)", ["Uit", "2× MSAA", "4× MSAA", "8× MSAA"])
			_slider(page, "video/render_scale", "Renderschaal", 0.5, 1.0, 0.05, "%d%%", 100.0, "Lager = sneller. Opgeschaald met FSR.")
			_slider(page, "video/fov", "Gezichtsveld (FOV)", 60.0, 110.0, 1.0, "%d°", 1.0)
			_slider(page, "video/brightness", "Helderheid", 0.6, 1.6, 0.05, "%d%%", 100.0, "De put hoort donker te zijn; je helmlamp is je beste vriend.")
		"geluid":
			_slider(page, "audio/master", "Hoofdvolume", 0.0, 1.0, 0.01, "%d%%", 100.0)
			_slider(page, "audio/sfx", "Effecten", 0.0, 1.0, 0.01, "%d%%", 100.0)
			_slider(page, "audio/music", "Muziek", 0.0, 1.0, 0.01, "%d%%", 100.0)
			_slider(page, "audio/voice", "Stemmen (spraak)", 0.0, 1.0, 0.01, "%d%%", 100.0, "Voor de voice-chat (komt in M4).")
			_slider(page, "audio/ui", "Menu's", 0.0, 1.0, 0.01, "%d%%", 100.0)
			_toggle(page, "audio/mute_unfocused", "Stil als het spel niet actief is")
		"besturing":
			_slider(page, "controls/sensitivity", "Muisgevoeligheid", 0.1, 3.0, 0.05, "%d%%", 100.0)
			_toggle(page, "controls/invert_y", "Verticaal omkeren (Y)")
		"toetsen":
			var note := Label.new()
			note.text = "Klik op een toets en druk de nieuwe toets of muisknop. Esc annuleert."
			note.theme_type_variation = &"Caption"
			page.add_child(note)
			for pair: Array in Settings.BINDABLE:
				_key_row(page, pair[0], pair[1])
		"interface":
			_slider(page, "interface/ui_scale", "Grootte van de interface", 0.75, 1.5, 0.05, "%d%%", 100.0)
			_slider(page, "interface/camera_shake", "Schudden van de camera", 0.0, 1.0, 0.05, "%d%%", 100.0, "Minder schudden helpt tegen misselijkheid.")
			_toggle(page, "interface/show_hints", "Hulpteksten (welke toets doet wat)")
			_toggle(page, "interface/crosshair", "Vizier")
			_toggle(page, "interface/stats", "Infopaneel (fps, netwerk) · F3")


func _row(page: Control, label_text: String, help := "") -> HBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	page.add_child(wrap)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 50
	row.add_theme_constant_override("separation", 16)
	wrap.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = 1.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if help != "":
		var h := Label.new()
		h.text = help
		h.theme_type_variation = &"Caption"
		h.autowrap_mode = TextServer.AUTOWRAP_WORD
		wrap.add_child(h)
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 10)
	wrap.add_child(line)
	return row


func _toggle(page: Control, key: String, label_text: String, help := "") -> void:
	var row := _row(page, label_text, help)
	var c := CheckButton.new()
	c.button_pressed = Settings.get_b(key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	row.add_child(c)


func _option(page: Control, key: String, label_text: String, items: Array) -> void:
	var row := _row(page, label_text)
	var o := OptionButton.new()
	o.custom_minimum_size.x = 300
	for it: String in items:
		o.add_item(it)
	o.selected = clampi(int(Settings.get_value(key)), 0, items.size() - 1)
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(key, i))
	row.add_child(o)


func _slider(page: Control, key: String, label_text: String, lo: float, hi: float, step: float,
		fmt: String, shown_scale: float, help := "") -> void:
	var row := _row(page, label_text, help)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Settings.get_f(key)
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", UiTheme.body(800))
	v.text = fmt % roundi(s.value * shown_scale)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt % roundi(x * shown_scale)
		Settings.set_value(key, x, false))
	s.drag_ended.connect(func(_c: bool) -> void: Settings.save())


func _key_row(page: Control, action: String, label_text: String) -> void:
	var row := _row(page, label_text)
	var b := Button.new()
	b.theme_type_variation = &"GhostButton"
	b.custom_minimum_size.x = 220
	b.text = Settings.key_of(action).to_upper()
	b.pressed.connect(func() -> void:
		_cancel_rebind()
		_waiting_for = b
		_waiting_action = action
		b.text = "DRUK EEN TOETS…")
	row.add_child(b)


func _finish_rebind(ev: InputEvent) -> void:
	Settings.rebind(_waiting_action, ev)
	_waiting_for.text = Settings.key_of(_waiting_action).to_upper()
	_waiting_for = null
	_waiting_action = ""


func _cancel_rebind() -> void:
	if _waiting_for:
		_waiting_for.text = Settings.key_of(_waiting_action).to_upper()
	_waiting_for = null
	_waiting_action = ""
