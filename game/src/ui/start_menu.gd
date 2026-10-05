class_name StartMenu
extends Control
## Hoofdmenu: links een kolom in de huisstijl, rechts de levende achtergrond (MenuBackdrop).
## Eén hoofdkeuze (PLAY SOLO, geel), daaronder samen spelen (hosten, meedoen via IP), instellingen en
## afsluiten. Wat een knop doet, staat in een vaste regel onder de knop met de focus (geen tooltip),
## ui-12.

signal solo_chosen
signal host_chosen
signal join_chosen(address: String)

const LAST_IP_FILE := "user://last_ip.txt"
const VERSION := "v" + Net.GAME_VERSION

var backdrop: MenuBackdrop
var _ip: LineEdit
var _status: Label
var _join_card: Control
var _buttons: VBoxContainer
var _settings: SettingsMenu
var _fade: ColorRect
## De kolom met het logo en de knoppen (weg zolang de instellingen open staan, ui-15).
var _col: VBoxContainer
## Uitleg bij de knop met de focus, net onder die knop.
var _desc: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Leesbaarheid: links donker verloop over de 3D-scène, onderaan een dunne vignet.
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(UiTheme.NIGHT, 0.96))
	g.add_point(0.45, Color(UiTheme.NIGHT, 0.88))
	g.add_point(0.75, Color(UiTheme.NIGHT, 0.3))
	g.set_color(g.get_point_count() - 1, Color(UiTheme.NIGHT, 0.0))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 1050
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
	_col = col

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
	tag.text = "DRILL CREW WANTED  ·  NO EXPERIENCE REQUIRED"
	tag.theme_type_variation = &"Caption"
	tag.add_theme_constant_override("line_spacing", 0)
	col.add_child(_spaced(tag, 10, 40))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	col.add_child(_buttons)
	_desc = Label.new()
	_desc.theme_type_variation = &"Caption"
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc.custom_minimum_size.x = 440
	_menu_button("PLAY SOLO", "Down the pit alone. The best way to learn the ropes.", func() -> void: _choose(solo_chosen.emit), false)
	var coop := Label.new()
	coop.text = "WITH FRIENDS"
	coop.add_theme_font_override("font", UiTheme.heading())
	coop.add_theme_font_size_override("font_size", 18)
	coop.add_theme_color_override("font_color", UiTheme.STEEL)
	_buttons.add_child(_spaced(coop, 10, 0))
	_menu_button("HOST", "Start a crew. Friends join with your IP address.", func() -> void: _choose(host_chosen.emit), true)
	_menu_button("JOIN", "Join a friend who hosts, with their IP address.", _toggle_join, true)

	# Meedoen: een kaartje met het IP-veld, klapt open onder de knop.
	_join_card = PanelContainer.new()
	_join_card.theme_type_variation = &"Card"
	_join_card.visible = false
	_buttons.add_child(_join_card)
	var jc := VBoxContainer.new()
	jc.add_theme_constant_override("separation", 10)
	_join_card.add_child(jc)
	var jl := Label.new()
	jl.text = "Host IP address"
	jl.theme_type_variation = &"Caption"
	jc.add_child(jl)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	jc.add_child(jrow)
	_ip = LineEdit.new()
	_ip.placeholder_text = "e.g. 192.168.1.23"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip.text = _load_last_ip()
	_ip.text_submitted.connect(func(_t: String) -> void: _join())
	jrow.add_child(_ip)
	var go := Button.new()
	go.text = "CONNECT"
	go.pressed.connect(_join)
	jrow.add_child(go)

	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	_buttons.add_child(gap)
	_menu_button("SETTINGS", "Video, audio, controls, keys.", _open_settings, true)
	_menu_button("QUIT", "Back to the real world.", func() -> void: get_tree().quit(), true)
	_buttons.add_child(_desc)

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
		_col.visible = true
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


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and _join_card.visible and not _settings.visible:
		_toggle_join()
		get_viewport().set_input_as_handled()


func _menu_button(text: String, tip: String, action: Callable, ghost := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(440, 68 if not ghost else 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 30 if not ghost else 20)
	if ghost:
		b.theme_type_variation = &"GhostButton"
	b.set_meta("tip", tip)
	b.pressed.connect(func() -> void:
		Sfx.ui("click")
		action.call())
	# Bij hover schuift de knop een tikje naar rechts (een kleine beloning, zoals in DRG).
	b.mouse_entered.connect(func() -> void:
		Sfx.ui("hover")
		_show_desc(b)
		create_tween().tween_property(b, "position:x", 10.0, 0.12).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func() -> void:
		create_tween().tween_property(b, "position:x", 0.0, 0.15).set_ease(Tween.EASE_OUT))
	b.focus_entered.connect(func() -> void:
		b.position.x = 10.0
		_show_desc(b))
	b.focus_exited.connect(func() -> void: b.position.x = 0.0)
	_buttons.add_child(b)
	return b


## De uitleg van een knop, net onder die knop (niet als het IP-kaartje openstaat).
func _show_desc(b: Button) -> void:
	if _desc == null or b.get_parent() != _buttons:
		return
	_desc.text = str(b.get_meta("tip", ""))
	_desc.visible = _desc.text != "" and not _join_card.visible
	_buttons.move_child(_desc, b.get_index() + 1)


func _spaced(c: Control, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(c)
	return m


func _toggle_join() -> void:
	_join_card.visible = not _join_card.visible
	_desc.visible = not _join_card.visible and _desc.text != ""
	if backdrop:
		backdrop.go_to("join" if _join_card.visible else "main")
	if _join_card.visible:
		_ip.grab_focus()
		_ip.caret_column = _ip.text.length()


func _open_settings() -> void:
	if backdrop:
		backdrop.go_to("settings")
	# Het hoofdmenu niet half door het paneel laten schemeren (ui-15).
	_col.visible = false
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
		_status.text = "Enter the host's IP address first."
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
	for e: Array in join_addresses():
		out.append(e[1])
	return out


## [soort, adres] waarmee vrienden kunnen meedoen: eerst een virtueel LAN (Tailscale, Radmin VPN),
## dan het eigen netwerk. Virtuele netwerkkaarten van VMware, VirtualBox en Hyper-V/WSL laten we
## weg: die adressen (192.168.x.1) bereikt niemand anders.
static func join_addresses() -> Array:
	var vpn: Array = []
	var lan: Array = []
	for itf: Dictionary in IP.get_local_interfaces():
		var name := (str(itf.get("friendly", "")) + " " + str(itf.get("name", ""))).to_lower()
		if ["vmware", "virtualbox", "vethernet", "hyper-v", "wsl", "loopback", "bluetooth"].any(func(w: String) -> bool: return name.contains(w)):
			continue
		for a: String in itf.get("addresses", []):
			if a.contains(":"):
				continue # IPv6: niet nodig
			var parts := a.split(".")
			if parts.size() != 4:
				continue
			var p0 := int(parts[0])
			var p1 := int(parts[1])
			if name.contains("tailscale") or (p0 == 100 and p1 >= 64 and p1 < 128):
				vpn.append(["Tailscale", a])
			elif name.contains("radmin") or p0 == 26:
				vpn.append(["Radmin VPN", a])
			elif p0 == 192 and p1 == 168 or p0 == 10 or (p0 == 172 and p1 >= 16 and p1 < 32):
				lan.append(["Same network", a])
	return vpn + lan


## De uitleg in het pauzemenu: welk adres vrienden intypen, en dat iedereen dezelfde versie nodig heeft.
static func invite_text(port: int) -> String:
	var lines := PackedStringArray(["Friends choose JOIN and enter one of these:"])
	var any_vpn := false
	for e: Array in join_addresses():
		lines.append("%s: %s" % [e[0], e[1]])
		any_vpn = any_vpn or e[0] != "Same network"
	if not any_vpn:
		lines.append("Over the internet: Tailscale, or your public IP with UDP port %d forwarded." % port)
	lines.append("Everyone needs version %s." % Net.GAME_VERSION)
	return "\n".join(lines)
