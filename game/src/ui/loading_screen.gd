class_name LoadingScreen
extends Control
## Laadscherm tussen het menu en de put: draaiende boorkop, wat er gebeurt, en een tip van de firma.

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
var _tip: Label
var _spinner: TextureRect


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
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size.x = 720
	center.add_child(col)
	var spin_box := CenterContainer.new()
	spin_box.custom_minimum_size = Vector2(0, 110)
	col.add_child(spin_box)
	_spinner = TextureRect.new()
	_spinner.texture = preload("res://assets/ui/icons/drill.svg")
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.custom_minimum_size = Vector2(96, 96)
	_spinner.pivot_offset = Vector2(48, 48)
	_spinner.modulate = UiTheme.YELLOW
	spin_box.add_child(_spinner)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.theme_type_variation = &"Heading"
	_status.add_theme_font_size_override("font_size", 28)
	col.add_child(_status)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tip.add_theme_font_size_override("font_size", 19)
	_tip.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	col.add_child(_tip)
	visible = false


func show_status(text: String) -> void:
	if not visible:
		_tip.text = "Tip: " + TIPS[randi() % TIPS.size()]
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


func _process(delta: float) -> void:
	if visible:
		# Een boor draait niet gelijkmatig: korte rukjes, zoals een motor die slaat.
		_spinner.rotation += delta * (5.0 + 3.0 * sin(Time.get_ticks_msec() / 90.0))
