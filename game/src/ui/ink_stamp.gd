class_name InkStamp
extends Control
## Een rubberen stempel van de firma: een dubbele rand met ruwe inkt en een woord erin, schuin
## gezet. Voor het incidentrapport (APPROVED / QUOTA MISSED), de landing (planeet, claim) en een
## getekend contract (SIGNED). Met `fill` krijgt hij een donkere ondergrond, zodat hij ook op een
## lichte achtergrond leest (de crème cabine van de Mol, ui-18).

var text := ""
var sub := ""
var ink := UiTheme.DANGER
var fill := Color(0, 0, 0, 0)
var font_size := 30
var sub_size := 18
## Ruwheid van de rand (px): een stempel drukt nooit helemaal gelijk.
var rough := 1.6
var _seed := 0


static func make(word: String, color: Color, size := 30, angle_deg := -8.0) -> InkStamp:
	var s := InkStamp.new()
	s.text = word
	s.ink = color
	s.font_size = size
	s.rotation = deg_to_rad(angle_deg)
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed = randi()


func _ready() -> void:
	refit()


## Grootte volgens de tekst (na het wijzigen van text, sub of de lettergrootte).
func refit() -> void:
	var f := UiTheme.heading()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var h := f.get_height(font_size)
	if sub != "":
		var sf := UiTheme.body(800)
		w = maxf(w, sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_size).x)
		h += sf.get_height(sub_size) + 2.0
	custom_minimum_size = Vector2(w + font_size * 1.1, h + font_size * 0.55)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if fill.a > 0.0:
		draw_rect(r.grow(-2.0), fill)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	_rough_rect(r.grow(-2.0), 3.5, rng)
	_rough_rect(r.grow(-8.0), 1.8, rng)
	var f := UiTheme.heading()
	var th := f.get_height(font_size)
	var total := th
	var sf := UiTheme.body(800)
	if sub != "":
		total += sf.get_height(sub_size) + 2.0
	var y := (size.y - total) / 2.0 + f.get_ascent(font_size)
	draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
	if sub != "":
		draw_string(sf, Vector2(0, y + f.get_descent(font_size) + 2.0 + sf.get_ascent(sub_size)), sub, HORIZONTAL_ALIGNMENT_CENTER,
				size.x, sub_size, Color(ink, 0.92))
	# Inktvlekjes: kleine gaten in de rand, zoals een stempel die niet overal raakt (enkel zichtbaar
	# met een ondergrond).
	if fill.a > 0.0:
		for i in 7:
			var p := Vector2(rng.randf_range(0.0, size.x), rng.randf() * size.y)
			var on_edge := [Vector2(p.x, 3.0), Vector2(p.x, size.y - 3.0), Vector2(3.0, p.y), Vector2(size.x - 3.0, p.y)][i % 4] as Vector2
			draw_circle(on_edge, rng.randf_range(1.0, 2.4), fill)


func _rough_rect(r: Rect2, width: float, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var n := maxi(2, int(a.distance_to(b) / 14.0))
		for i in n:
			var q := a.lerp(b, float(i) / n)
			pts.append(q + Vector2(rng.randf_range(-rough, rough), rng.randf_range(-rough, rough)))
	pts.append(pts[0])
	draw_polyline(pts, ink, width, true)
