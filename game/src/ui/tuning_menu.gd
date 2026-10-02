class_name TuningMenu
extends PanelContainer
## Tuning-menu in het spel (F1, GDD §9: "alle gevoel-waarden in databestanden").
## Een tab per bestand in data/tuning/, een veld per waarde, uitleg als tooltip.
## Wijzigingen werken meteen; "Bewaar" schrijft ze weg (zie Tuning.save).

signal closed

const TITLES := {
	"camera": "Camera", "carry": "Dragen", "dig": "Graven", "drill": "Boor", "finds": "Vondsten",
	"mol": "De Mol", "pickaxe": "Houweel", "player": "Speler", "terrain": "Terrein",
}

var _tabs: TabContainer
var _status: Label
var _fields: Dictionary = {} # "bestand/sleutel" -> Control
var _was_captured := false


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 560)
	position -= custom_minimum_size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.055, 0.05, 0.94)
	style.border_color = Color(1.0, 0.65, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var title := Label.new()
	title.text = "Tuning  ·  F1 sluiten  ·  wijzigingen werken meteen"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	col.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	var save := Button.new()
	save.text = "Bewaar dit tabblad"
	save.pressed.connect(_save_current)
	buttons.add_child(save)
	var save_all := Button.new()
	save_all.text = "Bewaar alles"
	save_all.pressed.connect(_save_all)
	buttons.add_child(save_all)
	var reset := Button.new()
	reset.text = "Terug naar bewaarde waarden"
	reset.pressed.connect(func() -> void:
		Tuning.reload()
		_rebuild()
		_status.text = "Bewaarde waarden opnieuw geladen.")
	buttons.add_child(reset)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_status)

	Tuning.remote_applied.connect(_rebuild)
	_rebuild()


func toggle() -> void:
	visible = not visible
	if visible:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_values()
		if Tuning.is_remote():
			_status.text = "Je bent client: de host beslist over de waarden. Wijzigingen hier gelden enkel lokaal tot de host iets verandert."
	else:
		if _was_captured:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()


func _rebuild() -> void:
	var current := _tabs.current_tab
	for c in _tabs.get_children():
		c.queue_free()
	_fields.clear()
	for file in Tuning.files():
		var scroll := ScrollContainer.new()
		scroll.name = file
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_tabs.add_child(scroll)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, TITLES.get(file, file))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 16)
		scroll.add_child(grid)
		for key in Tuning.keys(file):
			var label := Label.new()
			label.text = key
			label.tooltip_text = Tuning.comment(file, key)
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(label)
			var field := _make_field(file, key, Tuning.value(file, key, 0.0))
			field.tooltip_text = label.tooltip_text
			grid.add_child(field)
			_fields[file + "/" + key] = field
	if current >= 0 and current < _tabs.get_tab_count():
		_tabs.current_tab = current


func _make_field(file: String, key: String, v: Variant) -> Control:
	if v is bool:
		var cb := CheckBox.new()
		cb.button_pressed = v
		cb.toggled.connect(func(on: bool) -> void: Tuning.set_value(file, key, on))
		return cb
	var sb := SpinBox.new()
	sb.custom_minimum_size.x = 160
	sb.allow_greater = true
	sb.allow_lesser = true
	sb.min_value = -1000000
	sb.max_value = 1000000
	if v is int:
		sb.step = 1
		sb.rounded = true
	else:
		sb.step = 0.0001
	sb.value = float(v)
	sb.value_changed.connect(func(nv: float) -> void:
		Tuning.set_value(file, key, int(nv) if v is int else nv))
	return sb


func _refresh_values() -> void:
	for id: String in _fields:
		var parts := id.split("/")
		var v: Variant = Tuning.value(parts[0], parts[1], 0.0)
		var field: Control = _fields[id]
		if field is SpinBox:
			(field as SpinBox).set_value_no_signal(float(v))
		elif field is CheckBox:
			(field as CheckBox).set_pressed_no_signal(bool(v))


func _save_current() -> void:
	var file := _tabs.get_child(_tabs.current_tab).name
	_status.text = "Bewaard: %s" % Tuning.save(file)


func _save_all() -> void:
	for file in Tuning.files():
		Tuning.save(file)
	_status.text = "Alles bewaard (%d bestanden)." % Tuning.files().size()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()
