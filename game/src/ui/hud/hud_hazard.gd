class_name HudHazard
extends HudFader
## Onder het kompas: de gevaren (onderzoek magma-en-onrust, G; ontwerp-1, ontwerp-12).
## - Het magma: onder de grond (en in de Mol) altijd in beeld, want het is de enige klok (ontwerp-1:
##   "de klok is het grootste deel van de dienst onzichtbaar"). Ver weg klein en rustig ("MAGMA 214 m
##   below · reaches you in 9:40"), vanaf 60 m groot en oranje, onder 30 m rood, onder 15 m knipperend. Een beving
##   die het magma opstuwt, toont even "+9 m".
## - Gerommel van de Graafworm: een seismograaf die uitslaat als hij dichtbij zwemt.
## - Gas: "GAS · NO DRILLING" zolang je in een gasbel staat.
## - De onrust als een balk (vanaf 40% of als het beeft), en "QUAKE!" tijdens een beving.
## Groot genoeg om te voelen (ui-04, ui-05): tekst ≥ 18 px. De rand rond het scherm (HudAlarm) doet de rest.

const WIDTH := 400.0
const SHOW_MAGMA_M := 60.0
const SHOW_UNREST := 0.4
const MAGMA_H := 36.0
const FAR_H := 30.0
const WORM_H := 30.0
const GAS_H := 32.0
const UNREST_H := 30.0
const QUAKE_H := 50.0

## Meter tot het magma onder je (INF = geen magma).
var magma_m := INF
## Seconden tot het magma hier is (INF = onbekend of nooit).
var magma_eta := INF
## Onder de grond of in de Mol: het magma altijd tonen.
var always_magma := false
## In de stoel van de Mol (eigen camera): het magma niet, want het statusscherm toont het al en de chip
## lag over de kop van het camerascherm (ui2-13).
var hide_magma := false
## De regel van ontwerp-1 (ver weg toch tonen). Uit = de oude regel (enkel binnen 60 m), voor een
## voor/na-beeld (threat_film --take=hud --legacy).
var far_rule := true
## Onrust 0..1 in de huidige trap.
var unrest := 0.0
var quake := Unrest.Phase.CALM
## Gerommel van de worm hier (0..1).
var worm := 0.0
## In een gasbel.
var gas := false
var _rise := 0.0
var _rise_t := 0.0
var _font: Font
var _head: Font
var _wave := PackedFloat32Array()


func _init() -> void:
	needs_content = true
	hold = 1.5
	custom_minimum_size = Vector2(WIDTH, MAGMA_H + WORM_H + GAS_H + UNREST_H + QUAKE_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.resize(64)


func _ready() -> void:
	_font = UiTheme.body(900)
	_head = UiTheme.heading()


func set_state(magma_dist: float, unrest_frac: float, phase: Unrest.Phase) -> void:
	magma_m = magma_dist
	unrest = clampf(unrest_frac, 0.0, 1.0)
	quake = phase
	active = _magma_shown() or unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM or worm > 0.05 or gas


## Een beving stuwde het magma zoveel meter op (even tonen).
func flash_rise(metres: float) -> void:
	_rise = metres
	_rise_t = 5.0


func _magma_shown() -> bool:
	return not hide_magma and (magma_m < SHOW_MAGMA_M or (always_magma and far_rule and magma_m < INF))


## Hoe hoog wat er nu getekend wordt (voor wat eronder komt, zoals de aftelling).
func content_height() -> float:
	var h := 0.0
	if hide_magma:
		pass
	elif magma_m < SHOW_MAGMA_M:
		h += MAGMA_H + 6.0
	elif always_magma and far_rule and magma_m < INF:
		h += FAR_H + 4.0
	if worm > 0.05:
		h += WORM_H
	if gas:
		h += GAS_H
	if unrest >= SHOW_UNREST or quake != Unrest.Phase.CALM:
		h += UNREST_H
	if quake != Unrest.Phase.CALM:
		h += QUAKE_H
	return h


func _process(delta: float) -> void:
	super(delta)
	_rise_t = maxf(0.0, _rise_t - delta)
	# Seismograaf: de naald slaat uit met het gerommel van de worm.
	for i in range(_wave.size() - 1):
		_wave[i] = _wave[i + 1]
	_wave[_wave.size() - 1] = randf_range(-1.0, 1.0) * worm * (0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 1000.0 * 7.0)))
	if visible:
		queue_redraw()


## Het teken van de worm (16 px): een open muil (een ring met tanden) en drie segmenten erachter.
func _worm_icon(c: Vector2, col: Color) -> void:
	var dark := Color(0, 0, 0, 0.75)
	for i in 3:
		var p := c + Vector2(-5.0 - i * 4.5, 3.0 + i * 1.5)
		draw_circle(p, 3.6 - i * 0.6, dark)
		draw_circle(p, 2.6 - i * 0.6, col)
	draw_circle(c, 7.0, dark)
	draw_arc(c, 5.0, 0.0, TAU, 20, col, 2.6)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		draw_line(c + Vector2(cos(a), sin(a)) * 4.6, c + Vector2(cos(a), sin(a)) * 1.6, col, 1.6)


static func _clock(s: float) -> String:
	var n := maxi(0, int(s))
	return "%d:%02d" % [n / 60, n % 60]


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var blink := fmod(t, 0.6) < 0.38
	var y := 0.0
	if hide_magma:
		pass
	elif magma_m < SHOW_MAGMA_M:
		var col := UiTheme.AMBER if magma_m > 30.0 else UiTheme.DANGER
		if magma_m < 15.0 and not blink:
			col = Color(col, 0.5)
		# "MAGMA" als label in de huisstijl, de afstand in gewone cijfers met "m" (ui-07), en wanneer het hier is.
		var word := "MAGMA"
		var dist := "%d m below" % int(maxf(0.0, magma_m))
		if magma_eta < 3600.0 and magma_m > 0.5:
			dist += "  ·  reaches you in %s" % _clock(magma_eta)
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
	elif always_magma and far_rule and magma_m < INF:
		# Ver weg: klein en rustig, maar altijd daar. Hoe dichter, hoe warmer de kleur.
		var k := clampf(1.0 - (magma_m - SHOW_MAGMA_M) / 200.0, 0.0, 1.0)
		var col := UiTheme.CREAM_DIM.lerp(UiTheme.AMBER, k)
		var word := "MAGMA"
		var dist := "%d m below" % int(magma_m)
		if magma_eta < 3600.0:
			dist += "  ·  reaches you in %s" % _clock(magma_eta)
		var wsz := _head.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var dsz := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		var bw := wsz.x + dsz.x + 34.0
		var box := Rect2(WIDTH / 2.0 - bw / 2.0, y, bw, FAR_H)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.05, 0.04, 0.6)
		bg.border_color = Color(col, 0.7)
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(6)
		draw_style_box(bg, box)
		draw_string(_head, Vector2(box.position.x + 12.0, y + 22.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		draw_string(_font, Vector2(box.position.x + 22.0 + wsz.x, y + 22.0), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM)
		y += FAR_H + 4.0
	if _rise_t > 0.0 and _rise >= 0.5:
		# Een beving stuwde het magma op: even "+9 m" rechts van de magmaregel.
		var txt := "+%d m" % roundi(_rise)
		var a := clampf(_rise_t, 0.0, 1.0)
		draw_string_outline(_head, Vector2(WIDTH - 6.0, y - 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.8 * a))
		draw_string(_head, Vector2(WIDTH - 6.0, y - 8.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UiTheme.DANGER, a))
	if worm > 0.05:
		# Gerommel: een seismograaf die uitslaat, met de naam van de worm en zijn teken (een muil met
		# een lijf erachter), in de kleur van gevaar (ui2-05: één naam overal, niet "TREMOR").
		var label := Worm.NAME.to_upper()
		var near := worm > 0.55
		var c := UiTheme.state_color(UiTheme.State.CRITICAL if near else UiTheme.State.DANGER)
		if near and not blink:
			c = Color(c, 0.7)
		# Een HUD-plaatje in de huisstijl (G6), de rand in de kleur van de toestand.
		UiTheme.draw_chip(self, Rect2(0.0, y, WIDTH, WORM_H - 4.0), UiTheme.state_color(UiTheme.State.CRITICAL if near else UiTheme.State.DANGER))
		_worm_icon(Vector2(22.0, y + 13.0), c)
		var lx := 34.0
		var lw := lx + _head.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(_head, Vector2(lx, y + 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, c)
		var box := Rect2(lw + 10.0, y + 4.0, WIDTH - lw - 18.0, 18.0)
		draw_rect(box, Color(0, 0, 0, 0.45))
		var pts := PackedVector2Array()
		for i in _wave.size():
			pts.append(Vector2(box.position.x + box.size.x * i / (_wave.size() - 1.0), box.get_center().y + _wave[i] * box.size.y * 0.48))
		draw_polyline(pts, c, 2.0)
		y += WORM_H
	if gas:
		var word := "GAS  ·  NO DRILLING"
		var gw := _head.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var gcol := Color("#E3D24A") if blink else Color("#E3D24A", 0.55)
		draw_string_outline(_head, Vector2(WIDTH / 2.0 - gw / 2.0, y + 24.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 7, Color(0.1, 0.08, 0.0, 0.9))
		draw_string(_head, Vector2(WIDTH / 2.0 - gw / 2.0, y + 24.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, gcol)
		y += GAS_H
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
