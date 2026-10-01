class_name HazardStrip
extends Control
## Geel-zwarte waarschuwingsstrook (huisstijl van Diepgang BV), schuin gestreept.
## Kan langzaam schuiven (bv. tijdens het aftellen van de Mol).

@export var stripe := 14.0
@export var speed := 0.0 # pixels per seconde
var color_a := UiTheme.YELLOW
var color_b := UiTheme.ANTHRACITE_LO
var _offset := 0.0


func _init(height := 8.0) -> void:
	custom_minimum_size.y = height
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(delta: float) -> void:
	if speed != 0.0:
		_offset = fposmod(_offset + speed * delta, stripe * 2.0)
		queue_redraw()


func _draw() -> void:
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), color_b)
	var x := -h - stripe * 2.0 + _offset
	while x < size.x + h:
		draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h, 0), Vector2(x + h + stripe, 0), Vector2(x + stripe, h)]), color_a)
		x += stripe * 2.0
