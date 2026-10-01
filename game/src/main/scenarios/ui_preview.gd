extends Node
## Toont de onderdelen van het UI-thema en de iconen, en neemt een screenshot (logs/ui_thema.png).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=ui_preview --no-steam

var main: Node


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UiTheme.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var margin := MarginContainer.new()
	margin.theme = UiTheme.get_theme()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	layer.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size.x = 520
	row.add_child(col)
	var title := Label.new()
	title.text = "DIEPGANG"
	title.theme_type_variation = &"Title"
	col.add_child(title)
	var h := Label.new()
	h.text = "INSTELLINGEN"
	h.theme_type_variation = &"Heading"
	col.add_child(h)
	var body := Label.new()
	body.text = "Lopende tekst in Nunito: leesbaar, rond en vriendelijk.\nTweede regel met cijfers 0123456789 €."
	col.add_child(body)
	var cap := Label.new()
	cap.text = "Kleine uitleg onder een instelling"
	cap.theme_type_variation = &"Caption"
	col.add_child(cap)
	for t in ["SOLO SPELEN", "HOSTEN"]:
		var b := Button.new()
		b.text = t
		col.add_child(b)
	var ghost := Button.new()
	ghost.text = "TERUG"
	ghost.theme_type_variation = &"GhostButton"
	col.add_child(ghost)
	var edit := LineEdit.new()
	edit.placeholder_text = "IP van de host, bv. 192.168.1.23"
	col.add_child(edit)
	var slider := HSlider.new()
	slider.value = 65
	col.add_child(slider)
	var check := CheckButton.new()
	check.text = "Verticale synchronisatie"
	check.button_pressed = true
	col.add_child(check)
	var check2 := CheckButton.new()
	check2.text = "Y omkeren"
	col.add_child(check2)
	var opt := OptionButton.new()
	for o in ["Volledig scherm", "Venster"]:
		opt.add_item(o)
	col.add_child(opt)
	var scr := Label.new()
	scr.text = "DIEPTE 34 M  LAAG ZANDSTEEN"
	scr.theme_type_variation = &"Screen"
	col.add_child(scr)

	var col2 := VBoxContainer.new()
	col2.add_theme_constant_override("separation", 20)
	row.add_child(col2)
	var panel := PanelContainer.new()
	col2.add_child(panel)
	var pl := Label.new()
	pl.text = "Paneel"
	panel.add_child(pl)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 18)
	col2.add_child(icons)
	for n in ["pickaxe", "drill", "hand", "bone", "mol", "warning", "depth"]:
		var tr := TextureRect.new()
		tr.texture = load("res://assets/ui/icons/%s.svg" % n)
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.modulate = UiTheme.CREAM if n != "warning" else UiTheme.DANGER
		icons.add_child(tr)
	var preview_extra: Callable = main.get("ui_preview_extra") if main.get("ui_preview_extra") is Callable else Callable()
	if preview_extra.is_valid():
		preview_extra.call(col2)

	for i in 20:
		await get_tree().process_frame
	_save("ui_thema")
	margin.queue_free()
	var settings := SettingsMenu.new()
	settings.theme = UiTheme.get_theme()
	layer.add_child(settings)
	for tab in ["beeld", "geluid", "toetsen", "interface"]:
		settings._show(tab)
		for i in 6:
			await get_tree().process_frame
		_save("ui_instellingen_" + tab)
	get_tree().quit(0)


func _save(shot: String) -> void:
	var path := PerfLog.log_dir().path_join(shot + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[ui_preview] ", path)
