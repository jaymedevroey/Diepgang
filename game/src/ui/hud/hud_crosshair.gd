class_name HudCrosshair
extends HudFader
## Vizier: een kleine stip met een ring die vertelt wat je bekijkt (vorm én kleur, niet enkel kleur):
##   NONE     enkel de stip
##   DIG      dunne ring: hier kan je graven
##   HARD     rode ring met een schuine streep: te hard voor dit gereedschap
##   CRUST    amberen ring in stukken: elk stuk is een slag die de korst nog verdraagt
##   USE      dikke gele ring: E doet hier iets
## Rond de ring een boog voor de hitte van de boor. Een slag laat de ring even opveren.

enum State { NONE, DIG, HARD, CRUST, USE }

var state := State.NONE
var crust_hp := 0.0
var crust_max := 4.0
var heat := 0.0 # 0..1
var overheated := false
var _pulse := 0.0
var _shown := State.NONE
var _blend := 1.0


func _init() -> void:
	mode_key = "hud/crosshair"
	custom_minimum_size = Vector2(96, 96)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pulse(strength := 1.0) -> void:
	_pulse = maxf(_pulse, strength)


func _process(delta: float) -> void:
	super(delta)
	_pulse = move_toward(_pulse, 0.0, delta * 5.0)
	if state != _shown:
		_shown = state
		_blend = 0.0
	_blend = minf(1.0, _blend + delta * 9.0)
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var shadow := Color(0, 0, 0, 0.55)
	var grow := 1.0 + _pulse * 0.35 + (1.0 - _blend) * 0.25
	# Stip met een donkere rand: leesbaar op licht en op donker.
	draw_circle(c, 3.6, shadow)
	draw_circle(c, 2.3, UiTheme.CREAM)
	var r := 11.0 * grow
	match state:
		State.DIG:
			_ring(c, r, 2.0, Color(UiTheme.CREAM, 0.85))
		State.HARD:
			_ring(c, r, 2.6, UiTheme.DANGER)
			draw_line(c + Vector2(-r, r) * 0.62, c + Vector2(r, -r) * 0.62, shadow, 5.0, true)
			draw_line(c + Vector2(-r, r) * 0.62, c + Vector2(r, -r) * 0.62, UiTheme.DANGER, 2.6, true)
		State.CRUST:
			# Grotere ring in stukken: elk stuk is een slag die de korst nog verdraagt.
			var n := maxi(1, int(round(crust_max)))
			var gap := 0.32
			var cr := 19.0 * grow
			for i in n:
				var a0 := -PI / 2.0 + TAU * i / n + gap / 2.0
				var a1 := a0 + TAU / n - gap
				var filled := i < int(ceil(crust_hp))
				draw_arc(c, cr, a0, a1, 12, shadow, 7.5, true)
				draw_arc(c, cr, a0, a1, 12, UiTheme.AMBER if filled else Color(UiTheme.CREAM, 0.22), 4.5, true)
		State.USE:
			_ring(c, r + 1.0, 3.2, UiTheme.YELLOW)
	# Hitte van de boor: een boog die van onder naar boven vol loopt, rood als hij oververhit is.
	if heat > 0.01:
		var hr := 24.0
		var a_start := PI * 0.75
		var span := PI * 1.5
		draw_arc(c, hr, a_start, a_start + span, 32, Color(0, 0, 0, 0.45), 6.0, true)
		var col := UiTheme.DANGER if overheated or heat > 0.85 else UiTheme.AMBER.lerp(UiTheme.DANGER, heat)
		draw_arc(c, hr, a_start, a_start + span * heat, 32, col, 3.5, true)


func _ring(c: Vector2, r: float, w: float, col: Color) -> void:
	draw_arc(c, r, 0.0, TAU, 40, Color(0, 0, 0, 0.5), w + 2.5, true)
	draw_arc(c, r, 0.0, TAU, 40, col, w, true)
