class_name HudCompass
extends HudFader
## Boven midden: diepte, laag en een kompasstrook met de richting naar de Mol (en de afstand).
## Dynamisch: verschijnt bij een andere laag, elke 10 m dieper, ver van de Mol, of als de Mol vertrekt.
## In het schip (`place` niet leeg): geen windrichtingen en geen diepte, maar waar je bent ("THE
## MAGPIE · BRIDGE") en een doel op de strook (de terminal of de Mol), met de afstand.
## De laagchip is donker met de kleur van de laag als rand en stip, zodat hij niet wegvalt tegen
## de laag waar je in staat; de bovenste laag heeft per planeet een eigen naam en kleur (ui-10).

const WIDTH := 560.0
const STRIP_H := 32.0
const SPAN_DEG := 180.0 # zichtbaar deel van het kompas
## Laagkleuren uit de stijlgids (kristal, graniet, zandsteen, klei).
const LAYER_COLORS := [Color("#3A4260"), Color("#9A9EA3"), Color("#D1AD72"), Color("#9A6B4C")]
## De bovenste laag per planeet (PlanetType.Id): naam. De kleur komt uit PlanetType.ground.
const TOP_LAYER_NAMES := ["CLAY", "LIMESTONE", "BASALT"]
const MOL_ICON := preload("res://assets/ui/icons/mol.svg")
const TERMINAL_ICON := preload("res://assets/ui/icons/terminal.svg")

var heading_deg := 0.0 # waar de speler naar kijkt (0 = noord = −z)
## Het doel op de strook (de Mol, of in het schip de terminal).
var mol_bearing_deg := 0.0
var mol_distance := 0.0
var mol_visible := false
var target_icon: Texture2D = MOL_ICON
## Rood knipperend doel (bv. de Mol als de drop aftelt en je er niet in zit).
var urgent := false
var depth := 0.0
var layer := 3
## De planeet (PlanetType.Id): de naam en kleur van de bovenste laag.
var planet := 0:
	set(v):
		if v != planet:
			planet = v
			_layer_dirty = true
## In het schip: de plek ("THE MAGPIE · BRIDGE"); leeg = op de planeet (diepte en laag).
var place := ""
var _depth_label: Label
var _layer_label: Label
var _layer_chip: PanelContainer
var _font: Font
var _layer_dirty := true


func _init() -> void:
	mode_key = "hud/depth"
	hold = 4.0
	custom_minimum_size = Vector2(WIDTH, STRIP_H + 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = UiTheme.body(800)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(0, STRIP_H + 8)
	row.size = Vector2(WIDTH, 44)
	add_child(row)
	_depth_label = Label.new()
	_depth_label.add_theme_font_override("font", UiTheme.body(900))
	_depth_label.add_theme_font_size_override("font_size", 30)
	_depth_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_depth_label.add_theme_constant_override("outline_size", 6)
	row.add_child(_depth_label)
	_layer_chip = PanelContainer.new()
	_layer_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_layer_chip)
	_layer_label = Label.new()
	_layer_label.add_theme_font_override("font", UiTheme.heading())
	_layer_label.add_theme_font_size_override("font_size", 18)
	_layer_label.add_theme_color_override("font_color", UiTheme.CREAM)
	_layer_label.add_theme_constant_override("shadow_offset_y", 0)
	_layer_chip.add_child(_layer_label)


## Naam van een laag op deze planeet (de bovenste laag heet per planeet anders).
static func layer_name(index: int, planet_id: int) -> String:
	if index == Strata.NAMES.size() - 1:
		return TOP_LAYER_NAMES[clampi(planet_id, 0, TOP_LAYER_NAMES.size() - 1)]
	return Strata.NAMES[index].to_upper()


## Kleur van een laag op deze planeet.
static func layer_color(index: int, planet_id: int) -> Color:
	if index == LAYER_COLORS.size() - 1:
		var g: Dictionary = PlanetType.ground(planet_id as PlanetType.Id)
		return (g.get("light", LAYER_COLORS[index]) as Color)
	return LAYER_COLORS[index]


func set_layer(index: int) -> void:
	if index != layer:
		layer = index
		_layer_dirty = true
		if place == "":
			poke(5.0)
	if place != "" or not _layer_dirty:
		return
	_layer_dirty = false
	var col := layer_color(layer, planet)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.85)
	box.border_color = col
	box.set_border_width_all(2)
	box.border_width_left = 10 # de kleur van de laag als een vlak links
	box.set_corner_radius_all(5)
	box.content_margin_left = 16
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	_layer_chip.add_theme_stylebox_override("panel", box)
	_layer_label.text = layer_name(layer, planet)
	_layer_label.add_theme_color_override("font_color", UiTheme.CREAM)


func set_depth(m: float) -> void:
	if place == "" and floor(m / 10.0) != floor(depth / 10.0):
		poke()
	depth = m
	if place == "":
		_depth_label.text = "%d m" % int(round(m)) if m < 0.5 else "−%d m" % int(round(m))


## In het schip: de naam van de plek (leeg = op de planeet). Een nieuwe plek toont de strook even.
func set_place(where: String) -> void:
	if where == place:
		return
	place = where
	if place == "":
		_depth_label.visible = true
		_layer_dirty = true
		set_layer(layer)
		set_depth(depth)
		return
	poke(3.0)
	_depth_label.visible = false
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.85)
	box.border_color = Color(UiTheme.YELLOW, 0.8)
	box.set_border_width_all(2)
	box.set_corner_radius_all(5)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 3
	_layer_chip.add_theme_stylebox_override("panel", box)
	_layer_label.text = place
	_layer_label.add_theme_color_override("font_color", UiTheme.CREAM)


func _process(delta: float) -> void:
	super(delta)
	if visible:
		queue_redraw()


func _draw() -> void:
	var w := WIDTH
	var h := STRIP_H
	var in_ship := place != ""
	# Strook met zachte randen.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.66)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, Rect2(0, 0, w, h))
	var px_per_deg := w / SPAN_DEG
	# Streepjes om de 15°, letters voor de windrichtingen (N O Z W); in het schip enkel streepjes.
	var start := int(floor((heading_deg - SPAN_DEG / 2.0) / 15.0)) * 15
	var deg := start
	while deg <= heading_deg + SPAN_DEG / 2.0:
		var x := w / 2.0 + (deg - heading_deg) * px_per_deg
		var edge := 1.0 - clampf(absf(x - w / 2.0) / (w / 2.0), 0.0, 1.0)
		var a := smoothstep(0.0, 0.35, edge)
		var d := posmod(deg, 360)
		if d % 90 == 0 and not in_ship:
			var letter: String = {0: "N", 90: "E", 180: "S", 270: "W"}[d]
			var sz := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
			draw_string(_font, Vector2(x - sz.x / 2.0, h / 2.0 + 7.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(UiTheme.YELLOW if d == 0 else UiTheme.CREAM, a))
		else:
			var th := 10.0 if d % 45 == 0 else 6.0
			draw_line(Vector2(x, h / 2.0 - th / 2.0), Vector2(x, h / 2.0 + th / 2.0), Color(UiTheme.CREAM, 0.55 * a), 2.0)
		deg += 15
	# Middenstreepje: jouw kijkrichting.
	draw_colored_polygon(PackedVector2Array([Vector2(w / 2 - 6, h + 1), Vector2(w / 2 + 6, h + 1), Vector2(w / 2, h - 6)]), UiTheme.CREAM)
	# Het doel: icoon op de strook, of een pijl aan de rand (binnen de strook) als het achter je is.
	if mol_visible:
		var rel := wrapf(mol_bearing_deg - heading_deg, -180.0, 180.0)
		var x := w / 2.0 + rel * px_per_deg
		var off_left := x < 40.0
		var off_right := x > w - 40.0
		x = clampf(x, 40.0, w - 40.0)
		var col := UiTheme.YELLOW
		if urgent:
			col = UiTheme.DANGER if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.4 else UiTheme.YELLOW
		if off_left or off_right:
			var dir := -1.0 if off_left else 1.0
			var tip := Vector2(x + dir * 28.0, h / 2.0)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-dir * 10, -8), tip + Vector2(-dir * 10, 8)]), col)
		draw_circle(Vector2(x, h / 2.0), 15.0, Color(0, 0, 0, 0.6))
		draw_texture_rect(target_icon, Rect2(x - 12, h / 2.0 - 12, 24, 24), false, col)
		# Afstand naast het icoon, op een donker plaatje (niet door de streepjes heen), aan de kant
		# waar plaats is en niet aan de kant van de pijl.
		var dist := "%d m" % int(round(mol_distance))
		var dsz := _font.get_string_size(dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var pill := Rect2(0.0, h / 2.0 - 12.0, dsz.x + 14.0, 24.0)
		var right := x < w - 30.0 - pill.size.x and not off_right
		pill.position.x = x + 18.0 if right or off_left else x - 18.0 - pill.size.x
		if off_left:
			pill.position.x = x + 40.0
		elif off_right:
			pill.position.x = x - 40.0 - pill.size.x
		var pb := StyleBoxFlat.new()
		pb.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.92)
		pb.set_corner_radius_all(5)
		draw_style_box(pb, pill)
		draw_string(_font, Vector2(pill.position.x + 7.0, pill.position.y + 18.0), dist, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
