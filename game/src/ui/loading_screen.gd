class_name LoadingScreen
extends Control
## Laadscherm tussen het menu en de put: de boorkop van de Mol van voren (hij draait om zijn as,
## met rukjes, zoals een motor die slaat), wat er gebeurt, en een "veiligheidsbriefing" van de
## firma met een tip (ui-16). De tip staat in een brede kolom, met de regels gelijk verdeeld.

const TIPS := [
	"The pickaxe is slow but safe. The drill is fast, but finds lose condition.",
	"Crust gets chipped away: keep swinging until it cracks. The crosshair shows how many hits are left.",
	"Heavy pieces are better carried in pairs. The company calls that \"teamwork\".",
	"Whatever is in the Mole's cargo hold rides up with it. Whatever is next to it does not.",
	"Granite stops the Mole's drill head. Nose up, or steer away.",
	"Launch lever pulled? Ten seconds. Anyone not on board climbs back up on foot.",
	"Lost? The compass at the top of the screen points the way to the Mole.",
	"Diepgang Ltd. accepts no liability for lost robots, fingers or good spirits.",
	"Press C in the Mole's seat to watch from outside while you drive.",
	"Settings > Keys: put every key wherever you want it.",
]

var _status: Label
var _kicker: Label
var _tip: Label
var _drill: _DrillHead


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = UiTheme.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var strip := HazardStrip.new(12.0)
	strip.speed = 26.0
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -12
	add_child(strip)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	col.custom_minimum_size.x = 980
	center.add_child(col)
	var spin_box := CenterContainer.new()
	spin_box.custom_minimum_size = Vector2(0, 170)
	col.add_child(spin_box)
	_drill = _DrillHead.new()
	_drill.custom_minimum_size = Vector2(160, 160)
	spin_box.add_child(_drill)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.theme_type_variation = &"Heading"
	_status.add_theme_font_size_override("font_size", 30)
	col.add_child(_status)
	var line := HazardStrip.new(6.0)
	line.custom_minimum_size.x = 260
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(line)
	_kicker = Label.new()
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kicker.add_theme_font_override("font", UiTheme.heading())
	_kicker.add_theme_font_size_override("font_size", 20)
	_kicker.add_theme_color_override("font_color", UiTheme.YELLOW)
	col.add_child(_kicker)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tip.add_theme_font_size_override("font_size", 22)
	_tip.add_theme_color_override("font_color", Color("#CFC7B8"))
	_tip.custom_minimum_size.x = 980
	col.add_child(_tip)
	visible = false


func show_status(text: String) -> void:
	if not visible:
		var i := randi() % TIPS.size()
		_kicker.text = "DIG SAFETY BRIEFING  ·  No. %02d" % (i + 1)
		_tip.text = TIPS[i]
		modulate.a = 1.0
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = true
	_status.text = text


func finish() -> void:
	if not visible:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE # vervagen mag geen klikken opvangen
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: visible = false)


## De boorkop van voren: een stalen schijf met snijtanden en drie spiraalarmen, die draait.
class _DrillHead extends Control:
	var _angle := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		# Een boor draait niet gelijkmatig: korte rukjes, zoals een motor die slaat.
		_angle += delta * (4.0 + 2.5 * sin(Time.get_ticks_msec() / 90.0))
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.42
		# Geel huis van de Mol rond de kop.
		draw_circle(c, r * 1.16, UiTheme.YELLOW_LO)
		draw_circle(c, r * 1.1, UiTheme.YELLOW)
		draw_arc(c, r * 1.1, 0.0, TAU, 64, UiTheme.ANTHRACITE_LO, 4.0, true)
		# Snijtanden rond de rand.
		var teeth := 14
		for i in teeth:
			var a := _angle + TAU * i / teeth
			var d := Vector2.from_angle(a)
			var n := Vector2.from_angle(a + 0.22)
			draw_colored_polygon(PackedVector2Array([c + d * r * 0.86, c + n * r * 1.04, c + d * r * 1.02]), Color("#B9BEC4"))
		draw_circle(c, r * 0.88, Color("#7E848B"))
		# Drie spiraalarmen.
		for k in 3:
			var pts := PackedVector2Array()
			for j in 12:
				var t := j / 11.0
				var a := _angle + TAU * k / 3.0 + t * 1.6
				pts.append(c + Vector2.from_angle(a) * r * (0.18 + 0.68 * t))
			draw_polyline(pts, Color("#3A3E44"), r * 0.16, true)
			draw_polyline(pts, Color("#C9CED3"), r * 0.06, true)
		# Naaf in het midden.
		draw_circle(c, r * 0.22, UiTheme.ANTHRACITE)
		draw_circle(c, r * 0.12, UiTheme.YELLOW)
		# Glans linksboven (staat stil terwijl de kop draait: zo zie je de draaiing).
		draw_arc(c, r * 0.8, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.35), r * 0.08, true)
