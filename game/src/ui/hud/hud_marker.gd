class_name HudMarker
extends Control
## Een merkteken op iets in de wereld (bv. de VERTREK-hendel in de Mol): een kloppende gele ring
## op die plek, met een kort label en de toets eronder. Hud.gd zet `target` en `shown`.

const RING := 15.0

var shown := false
## Wereldpositie van wat je aanwijst.
var target := Vector3.ZERO
var _label: Label
var _row: HBoxContainer
var _alpha := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1, 1)


func _ready() -> void:
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_row.add_child(KeyCap.make("interact", 14))
	_label = Label.new()
	_label.add_theme_font_override("font", UiTheme.heading())
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", UiTheme.YELLOW)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 6)
	_row.add_child(_label)


func set_text(text: String) -> void:
	_label.text = text


## Meteen weg (geen uitfaden).
func snap_out() -> void:
	shown = false
	_alpha = 0.0
	modulate.a = 0.0
	visible = false


## Elke frame: waar staat het doel op het scherm (of niet, als het achter de camera is).
func place(cam: Camera3D) -> void:
	var on := shown and cam != null and not cam.is_position_behind(target)
	_alpha = move_toward(_alpha, 1.0 if on else 0.0, get_process_delta_time() * (6.0 if on else 3.0))
	modulate.a = _alpha
	visible = _alpha > 0.01
	if not visible or cam == null or cam.is_position_behind(target):
		return
	# Het scherm van de camera is de viewport; de HUD rekt mee (canvas_items), dus omrekenen.
	var p := cam.unproject_position(target)
	var vp := get_viewport_rect().size
	var screen := cam.get_viewport().get_visible_rect().size
	p *= vp / screen
	position = p.clamp(Vector2(40, 40), vp - Vector2(40, 40))
	_row.position = Vector2(-_row.size.x / 2.0, RING + 8.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var k := 0.5 + 0.5 * sin(t * 5.0)
	draw_arc(Vector2.ZERO, RING + 6.0 * k, 0.0, TAU, 32, Color(UiTheme.YELLOW, 0.35 * (1.0 - k)), 3.0, true)
	draw_arc(Vector2.ZERO, RING, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 6.0, true)
	draw_arc(Vector2.ZERO, RING, 0.0, TAU, 32, UiTheme.YELLOW, 3.0, true)
	draw_circle(Vector2.ZERO, 3.0, UiTheme.YELLOW)
