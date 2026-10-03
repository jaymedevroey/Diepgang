class_name HudHazard
extends HudFader
## Onder het kompas: hoe ver het magma onder je staat (vanaf 60 m, oranje → rood → knipperend
## onder 15 m), de onrust als een balk (vanaf 40% of als het beeft), en "BEVING!" tijdens een
## beving (onderzoek magma-en-onrust, G). Enkel in beeld als er iets te melden is.

const WIDTH := 300.0
const SHOW_MAGMA_M := 60.0
const SHOW_UNREST := 0.4

## Meter tot het magma onder je (INF = ver weg of geen magma).
var magma_m := INF
## Onrust 0..1 in de huidige trap.
var unrest := 0.0
var quake := Unrest.Phase.CALM
var _font: Font
var _head: Font


func _init() -> void:
	needs_content = true
	hold = 1.5
	custom_minimum_size = Vector2(WIDTH, 92)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.body(900)
	_head = UiTheme.heading()


func set_state(magma_dist: float, unrest_frac: float, phase: Unrest.Phase) -> void:
	magma_m = magma_dist
	unrest = clampf(unrest_frac, 0.0, 1.0)
	quake = phase
	active = magma_m < SHOW_MAGMA_M or unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM


func _process(delta: float) -> void:
	super(delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.38
	var y := 0.0
	if magma_m < SHOW_MAGMA_M:
		var col := UiTheme.AMBER if magma_m > 30.0 else UiTheme.DANGER
		if magma_m < 15.0 and not blink:
			col = Color(col, 0.45)
		var text := "MAGMA  %d m" % int(maxf(0.0, magma_m))
		var sz := _head.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var box := Rect2(WIDTH / 2.0 - sz.x / 2.0 - 12.0, y, sz.x + 24.0, 28.0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.25, 0.04, 0.0, 0.72)
		bg.border_color = col
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(6)
		draw_style_box(bg, box)
		draw_string(_head, Vector2(box.position.x + 12.0, y + 21.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		y += 36.0
	if unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM:
		var label := "ONRUST"
		draw_string_outline(_font, Vector2(0.0, y + 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
		draw_string(_font, Vector2(0.0, y + 13.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.CREAM)
		var bar := Rect2(70.0, y + 3.0, WIDTH - 70.0, 10.0)
		draw_rect(bar, Color(UiTheme.ANTHRACITE_LO, 0.75))
		var fill := unrest if quake == Unrest.Phase.CALM else 1.0
		var c := UiTheme.YELLOW.lerp(UiTheme.DANGER, smoothstep(0.6, 1.0, fill))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), c)
		# Streepje bij 80%: vanaf daar voorschokken.
		var x80 := bar.position.x + bar.size.x * 0.8
		draw_line(Vector2(x80, bar.position.y - 2.0), Vector2(x80, bar.end.y + 2.0), Color(UiTheme.CREAM, 0.6), 2.0)
		y += 22.0
	if quake != Unrest.Phase.CALM:
		var t := "BEVING!" if quake == Unrest.Phase.QUAKE else "BEVING KOMT"
		var sz2 := _head.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var col2 := Color(UiTheme.DANGER, 1.0 if blink else 0.55)
		draw_string_outline(_head, Vector2(WIDTH / 2.0 - sz2.x / 2.0, y + 24.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.8))
		draw_string(_head, Vector2(WIDTH / 2.0 - sz2.x / 2.0, y + 24.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col2)
