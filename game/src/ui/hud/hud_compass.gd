class_name HudCompass
extends HudFader
## Boven midden: diepte, laag en een kompasstrook met de richting naar de Mol (en de afstand).
## Dynamisch: verschijnt bij een andere laag, elke 10 m dieper, ver van de Mol, of als de Mol vertrekt.

const WIDTH := 520.0
const STRIP_H := 30.0
const SPAN_DEG := 180.0 # zichtbaar deel van het kompas
## Laagkleuren uit de stijlgids, met de tekstkleur die er het best op leest (contrast ≥ 4,5:1).
const LAYER_COLORS := [Color("#3A4260"), Color("#9A9EA3"), Color("#D1AD72"), Color("#6E4A35")]
const LAYER_TEXT_DARK := [false, true, true, false]

var heading_deg := 0.0 # waar de speler naar kijkt (0 = noord = −z)
var mol_bearing_deg := 0.0
var mol_distance := 0.0
var mol_visible := false
var depth := 0.0
var layer := 3
var _depth_label: Label
var _layer_label: Label
var _layer_chip: PanelContainer
var _mol_icon: Texture2D = preload("res://assets/ui/icons/mol.svg")
var _font: Font


func _init() -> void:
	mode_key = "hud/depth"
	hold = 4.0
	custom_minimum_size = Vector2(WIDTH, STRIP_H + 52)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.body(800)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(0, STRIP_H + 8)
	row.size = Vector2(WIDTH, 40)
	add_child(row)
	_depth_label = Label.new()
	_depth_label.add_theme_font_override("font", UiTheme.body(900))
	_depth_label.add_theme_font_size_override("font_size", 28)
	_depth_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_depth_label.add_theme_constant_override("outline_size", 6)
	row.add_child(_depth_label)
	_layer_chip = PanelContainer.new()
	_layer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_layer_chip)
	_layer_label = Label.new()
	_layer_label.add_theme_font_override("font", UiTheme.heading())
	_layer_label.add_theme_font_size_override("font_size", 15)
	_layer_label.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	_layer_label.add_theme_constant_override("shadow_offset_y", 0)
	_layer_chip.add_child(_layer_label)


func set_layer(index: int) -> void:
	if index != layer:
		layer = index
		poke(5.0)
	var box := StyleBoxFlat.new()
	box.bg_color = LAYER_COLORS[layer]
	box.set_corner_radius_all(5)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	_layer_chip.add_theme_stylebox_override("panel", box)
	_layer_label.text = Strata.NAMES[layer].to_upper()
	_layer_label.add_theme_color_override("font_color", UiTheme.ANTHRACITE if LAYER_TEXT_DARK[layer] else UiTheme.CREAM)


func set_depth(m: float) -> void:
	if floor(m / 10.0) != floor(depth / 10.0):
		poke()
	depth = m
	_depth_label.text = "%d m" % int(round(m)) if m < 0.5 else "−%d m" % int(round(m))


func _process(delta: float) -> void:
	super(delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var w := WIDTH
	var h := STRIP_H
	# Strook met zachte randen.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.62)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, Rect2(0, 0, w, h))
	var px_per_deg := w / SPAN_DEG
	# Streepjes om de 15°, letters voor de windrichtingen (N O Z W).
	var start := int(floor((heading_deg - SPAN_DEG / 2.0) / 15.0)) * 15
	var deg := start
	while deg <= heading_deg + SPAN_DEG / 2.0:
		var x := w / 2.0 + (deg - heading_deg) * px_per_deg
		var edge := 1.0 - clampf(absf(x - w / 2.0) / (w / 2.0), 0.0, 1.0)
		var a := smoothstep(0.0, 0.35, edge)
		var d := posmod(deg, 360)
		if d % 90 == 0:
			var letter: String = {0: "N", 90: "O", 180: "Z", 270: "W"}[d]
			var sz := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
			draw_string(_font, Vector2(x - sz.x / 2.0, h / 2.0 + 6.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 17,
					Color(UiTheme.YELLOW if d == 0 else UiTheme.CREAM, a))
		else:
			var th := 10.0 if d % 45 == 0 else 6.0
			draw_line(Vector2(x, h / 2.0 - th / 2.0), Vector2(x, h / 2.0 + th / 2.0), Color(UiTheme.CREAM, 0.55 * a), 2.0)
		deg += 15
	# Middenstreepje: jouw kijkrichting.
	draw_colored_polygon(PackedVector2Array([Vector2(w / 2 - 6, h + 1), Vector2(w / 2 + 6, h + 1), Vector2(w / 2, h - 6)]), UiTheme.CREAM)
	# De Mol: icoon op de strook, of een pijl aan de rand als hij achter je is.
	if mol_visible:
		var rel := wrapf(mol_bearing_deg - heading_deg, -180.0, 180.0)
		var x := w / 2.0 + rel * px_per_deg
		var off_left := x < 18.0
		var off_right := x > w - 18.0
		x = clampf(x, 18.0, w - 18.0)
		var col := UiTheme.YELLOW
		draw_circle(Vector2(x, h / 2.0), 14.0, Color(0, 0, 0, 0.55))
		draw_texture_rect(_mol_icon, Rect2(x - 11, h / 2.0 - 11, 22, 22), false, col)
		if off_left or off_right:
			var dir := -1.0 if off_left else 1.0
			var tip := Vector2(x + dir * 22.0, h / 2.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-dir * 8, -7), tip + Vector2(-dir * 8, 7)]), col)
		# Afstand naast het icoon, aan de kant waar plaats is.
		var dist := "%d m" % int(round(mol_distance))
		var dsz := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		var dx := x + 17.0 if x < w - 30.0 - dsz.x else x - 17.0 - dsz.x
		if off_right:
			dx = x - 34.0 - dsz.x
		elif off_left:
			dx = x + 34.0
		draw_string_outline(_font, Vector2(dx, h / 2.0 + 5.5), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
		draw_string(_font, Vector2(dx, h / 2.0 + 5.5), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiTheme.YELLOW)
