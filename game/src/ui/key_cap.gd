class_name KeyCap
extends PanelContainer
## Toets als klein blokje ("E", "Linkermuis"), voor prompts in de HUD.
## Volgt de toetsen van de speler: na omzetten in de instellingen toont hij de nieuwe toets.

var action := ""
var _label: Label
var _icon: TextureRect


static func make(action_name: String, size := 18) -> KeyCap:
	var k := KeyCap.new()
	k.action = action_name
	k._build(size)
	return k


func _build(font_size: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.CREAM
	box.set_corner_radius_all(5)
	box.border_width_bottom = 3
	box.border_color = UiTheme.CREAM_DIM
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 1
	box.content_margin_bottom = 2
	add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.add_theme_font_override("font", UiTheme.heading())
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(font_size + 6, font_size + 6)
	_icon.modulate = UiTheme.ANTHRACITE
	add_child(_icon)
	custom_minimum_size.x = font_size + 12
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_refresh()
	Settings.changed.connect(func(key: String) -> void:
		if key.begins_with("keys"):
			_refresh())


func _refresh() -> void:
	# Muisknoppen als icoontje, toetsen als letters.
	var ev := Settings.binding(action) if action != "" else null
	var icon := ""
	if ev is InputEventMouseButton:
		icon = {MOUSE_BUTTON_LEFT: "mouse_left", MOUSE_BUTTON_RIGHT: "mouse_right"}.get((ev as InputEventMouseButton).button_index, "mouse_wheel")
	elif action in ["tool_prev", "tool_next"]:
		icon = "mouse_wheel"
	_icon.visible = icon != ""
	_label.visible = icon == ""
	if icon != "":
		_icon.texture = load("res://assets/ui/icons/%s.svg" % icon)
	else:
		_label.text = Settings.key_of(action).to_upper()
