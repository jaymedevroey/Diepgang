class_name HudObjective
extends HudFader
## In het schip, onder de strook bovenaan: wat je nu moet doen (opdracht kiezen, wachten tot De
## Ekster er is, naar de Mol, de hendel), met een kleinere regel eronder. Rood als het dringt
## (de drop telt af en je zit niet in de Mol). Volgt "Toetsprompts" in de HUD-instellingen.

const WIDTH := 640.0

enum Tone { NORMAL, URGENT }

var _chip: PanelContainer
var _title: Label
var _sub: Label
var _tone := Tone.NORMAL
var _last_title := ""


func _init() -> void:
	mode_key = "hud/prompts"
	needs_content = true
	hold = 6.0
	custom_minimum_size = Vector2(WIDTH, 70)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var col := VBoxContainer.new()
	col.size = Vector2(WIDTH, 70)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var line := CenterContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(_chip)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.heading())
	_title.add_theme_font_size_override("font_size", 17)
	_chip.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", UiTheme.body(700))
	_sub.add_theme_font_size_override("font_size", 16)
	_sub.add_theme_color_override("font_color", UiTheme.CREAM)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sub.add_theme_constant_override("outline_size", 5)
	col.add_child(_sub)
	_style()


## Wat er nu te doen is. Leeg = niets tonen. Een nieuwe titel houdt hem even langer in beeld.
func show_objective(title: String, sub := "", tone := Tone.NORMAL) -> void:
	active = title != ""
	if title == "":
		# Meteen weg (niet nog seconden de oude opdracht tonen, bv. "trek aan de hendel" na de hendel).
		_until = 0.0
		_last_title = ""
		return
	if title != _last_title:
		_last_title = title
		poke()
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	if tone != _tone:
		_tone = tone
		_style()


func _style() -> void:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	if _tone == Tone.URGENT:
		box.bg_color = Color(0.3, 0.04, 0.0, 0.85)
		box.border_color = UiTheme.DANGER
		box.set_border_width_all(2)
		_title.add_theme_color_override("font_color", UiTheme.CREAM)
	else:
		box.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.78)
		box.border_color = Color(UiTheme.YELLOW, 0.55)
		box.border_width_left = 4
		_title.add_theme_color_override("font_color", UiTheme.YELLOW)
	_chip.add_theme_stylebox_override("panel", box)


func _process(delta: float) -> void:
	super(delta)
	if _tone == Tone.URGENT and visible:
		_chip.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.55 else 0.7
	else:
		_chip.modulate.a = 1.0
