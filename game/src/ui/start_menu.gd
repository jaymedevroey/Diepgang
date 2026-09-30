class_name StartMenu
extends Control
## Startmenu: solo, hosten of meedoen via IP (M1: ENet in het LAN; Steam-uitnodigingen in M2).

signal solo_chosen
signal host_chosen
signal join_chosen(address: String)

const LAST_IP_FILE := "user://last_ip.txt"

var _ip: LineEdit
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.025, 0.02, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(460, 0)
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := Label.new()
	title.text = "DIEPGANG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	col.add_child(title)
	var sub := Label.new()
	sub.text = "M1-playtest · graven, uitbikken, dragen, lift"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.7, 0.62))
	col.add_child(sub)
	col.add_child(HSeparator.new())

	var solo := _button("Solo spelen")
	solo.pressed.connect(func() -> void: solo_chosen.emit())
	col.add_child(solo)
	var host := _button("Hosten (anderen verbinden met jouw IP)")
	host.pressed.connect(func() -> void: host_chosen.emit())
	col.add_child(host)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_ip = LineEdit.new()
	_ip.placeholder_text = "IP van de host, bv. 192.168.1.23"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip.text = _load_last_ip()
	_ip.text_submitted.connect(func(_t: String) -> void: _join())
	row.add_child(_ip)
	var join := _button("Meedoen")
	join.pressed.connect(_join)
	row.add_child(join)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	col.add_child(_status)

	col.add_child(HSeparator.new())
	var help := Label.new()
	help.text = "ZQSD lopen · spatie springen · muis kijken\nlinkermuis graven (vasthouden) · 1 houweel · 2 boor · wieltje wisselen\nE oppakken / neerzetten / knop · linkermuis gooien (als je draagt)\nV vliegen · F1 tuning · F3 infopaneel · Esc muis los"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62))
	col.add_child(help)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if CmdArgs.has("menu-shot"):
		for i in 30:
			await get_tree().process_frame
		var path := PerfLog.log_dir().path_join("menu.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("[menu] screenshot: ", path)
		get_tree().quit(0)


func show_error(text: String) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = text


func _join() -> void:
	var address := _ip.text.strip_edges()
	if address == "":
		_status.text = "Vul eerst het IP-adres van de host in."
		return
	var f := FileAccess.open(LAST_IP_FILE, FileAccess.WRITE)
	if f:
		f.store_string(address)
	join_chosen.emit(address)


func _load_last_ip() -> String:
	return FileAccess.get_file_as_string(LAST_IP_FILE).strip_edges() if FileAccess.file_exists(LAST_IP_FILE) else ""


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	return b


## Privé-IPv4-adressen van deze pc (om aan vrienden in het LAN door te geven).
static func local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and int(a.split(".")[1]) in range(16, 32)) or a.begins_with("100."):
			out.append(a)
	return out
