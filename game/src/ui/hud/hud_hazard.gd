class_name HudHazard
extends HudFader
## Onder het kompas: hoe ver het magma onder je staat (vanaf 60 m, oranje → rood → knipperend
## onder 15 m), de onrust als een balk (vanaf 40% of als het beeft), en "QUAKE!" tijdens een
## beving (onderzoek magma-en-onrust, G). Enkel in beeld als er iets te melden is.
## Groot genoeg om te voelen (ui-04, ui-05): tekst ≥ 18 px, een dikke balk met een duidelijk
## streepje bij 80% (vanaf daar voorschokken), en de beving als een groot, kloppend woord. De rand
## rond het scherm (HudAlarm) doet de rest.

const WIDTH := 400.0
const SHOW_MAGMA_M := 60.0
const SHOW_UNREST := 0.4
const MAGMA_H := 36.0
const UNREST_H := 30.0
const QUAKE_H := 50.0

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
	custom_minimum_size = Vector2(WIDTH, MAGMA_H + UNREST_H + QUAKE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.body(900)
	_head = UiTheme.heading()


func set_state(magma_dist: float, unrest_frac: float, phase: Unrest.Phase) -> void:
	magma_m = magma_dist
	unrest = clampf(unrest_frac, 0.0, 1.0)
	quake = phase
	active = magma_m < SHOW_MAGMA_M or unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM


## Hoe hoog wat er nu getekend wordt (voor wat eronder komt, zoals de aftelling).
func content_height() -> float:
	var h := 0.0
	if magma_m < SHOW_MAGMA_M:
		h += MAGMA_H + 6.0
	if unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM:
		h += UNREST_H
	if quake != Unrest.Phase.CALM:
		h += QUAKE_H
	return h


func _process(delta: float) -> void:
	super(delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var blink := fmod(t, 0.6) < 0.38
	var y := 0.0
	if magma_m < SHOW_MAGMA_M:
		var col := UiTheme.AMBER if magma_m > 30.0 else UiTheme.DANGER
		if magma_m < 15.0 and not blink:
			col = Color(col, 0.5)
		# "MAGMA" als label in de huisstijl, de afstand in gewone cijfers met "m" (ui-07).
		var word := "MAGMA"
		var dist := "%d m" % int(maxf(0.0, magma_m))
		var wsz := _head.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var dsz := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		var bw := wsz.x + dsz.x + 40.0
		var box := Rect2(WIDTH / 2.0 - bw / 2.0, y, bw, MAGMA_H)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.25, 0.04, 0.0, 0.8)
		bg.border_color = col
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(6)
		draw_style_box(bg, box)
		draw_string(_head, Vector2(box.position.x + 14.0, y + 26.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
		draw_string(_font, Vector2(box.position.x + 26.0 + wsz.x, y + 27.0), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiTheme.CREAM)
		y += MAGMA_H + 6.0
	if unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM:
		var label := "UNREST"
		var lw := _head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string_outline(_head, Vector2(0.0, y + 19.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.75))
		draw_string(_head, Vector2(0.0, y + 19.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiTheme.CREAM)
		var bar := Rect2(lw + 12.0, y + 4.0, WIDTH - lw - 12.0, 16.0)
		draw_rect(bar.grow(2.0), Color(0, 0, 0, 0.6))
		draw_rect(bar, Color(UiTheme.ANTHRACITE_LO, 0.85))
		var fill := unrest if quake == Unrest.Phase.CALM else 1.0
		var c := UiTheme.YELLOW.lerp(UiTheme.DANGER, smoothstep(0.6, 1.0, fill))
		if quake != Unrest.Phase.CALM and not blink:
			c = c.lightened(0.25)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), c)
		# Streepje bij 80%: vanaf daar voorschokken. Wit met een donkere rand, tot boven en onder de balk.
		var x80 := bar.position.x + bar.size.x * 0.8
		draw_line(Vector2(x80, bar.position.y - 5.0), Vector2(x80, bar.end.y + 5.0), Color(0, 0, 0, 0.8), 5.0)
		draw_line(Vector2(x80, bar.position.y - 5.0), Vector2(x80, bar.end.y + 5.0), UiTheme.CREAM, 2.5)
		y += UNREST_H
	if quake != Unrest.Phase.CALM:
		var is_quake := quake == Unrest.Phase.QUAKE
		var word := "QUAKE!" if is_quake else "QUAKE INCOMING"
		var size := 40 if is_quake else 30
		# Het woord klopt: groter en kleiner, en bij een beving schudt het een beetje mee.
		var beat := 0.5 + 0.5 * sin(t * TAU * (2.2 if is_quake else 1.2))
		var sz := _head.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var shake := Vector2(sin(t * 47.0), cos(t * 39.0)) * (3.0 if is_quake else 0.0)
		var pos := Vector2(WIDTH / 2.0 - sz.x / 2.0, y + size + 2.0) + shake
		var col2 := UiTheme.DANGER.lerp(Color("#FFC24A"), beat * 0.5)
		draw_string_outline(_head, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color(0.1, 0.0, 0.0, 0.9))
		draw_string(_head, pos, word, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col2)
