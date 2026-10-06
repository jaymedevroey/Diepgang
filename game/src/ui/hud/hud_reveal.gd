class_name HudReveal
extends Control
## De onthulling aan de poort voor wie het podium niet ziet (golf 3, gevoel2-04): wie zijn vondst zelf
## door de poort draagt, staat onder het scherm, en wie aan de andere kant staat, ziet zijn achterkant.
## Dan komt de onthulling onder het vizier: de soort, een teller die oploopt tot de waarde (in de kleur
## van de waardeklasse) en een regel met de gaafheid en de bonus. Wie het podium wel ziet, krijgt niets
## (het scherm is het moment, niet de HUD).
## Gebruik: `hud_reveal.watch(game)` één keer; `hud_reveal.update_from(player, game)` per frame.

## Tot hoe ver van de poort de HUD de onthulling toont (m).
const NEAR_M := 9.0
const SHOW_S := 3.4
const WIDTH := 520.0

var _name: Label
var _value: Label
var _line: Label
var _info: Dictionary = {}
var _at := -100000
var _game: Game


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 100)
	visible = false


func _ready() -> void:
	var col := VBoxContainer.new()
	col.size = Vector2(WIDTH, 100)
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_name = _make(UiTheme.heading(), 22, UiTheme.CREAM)
	col.add_child(_name)
	_value = _make(UiTheme.heading(), 50, UiTheme.YELLOW)
	col.add_child(_value)
	_line = _make(UiTheme.body(900), 19, UiTheme.CREAM)
	col.add_child(_line)


func _make(font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Luisteren naar de poort (één keer, zodra de firma er is).
func watch(game: Game) -> void:
	if _game == game or game == null or game.company == null:
		return
	_game = game
	game.company.appraisal.revealed.connect(_on_revealed)


func _on_revealed(info: Dictionary) -> void:
	var game := _game
	var me: Player = game.player_node(Net.my_id()) if game else null
	if me == null or game.ship == null:
		return
	var it: FindItem = game.finds.item(int(info.get("find_id", -1)))
	var mine := it != null and it.carriers.has(Net.my_id())
	var near := me.global_position.distance_to(game.ship.anchor_position("Appraisal_Gate")) < NEAR_M
	var sees := game.ship.hub_screens != null and game.ship.hub_screens.is_rendering(HubScreens.APPRAISAL)
	if mine or (near and not sees):
		_info = info
		_at = Time.get_ticks_msec()


func update_from(_player: Player, hidden: bool) -> void:
	var since := (Time.get_ticks_msec() - _at) / 1000.0
	visible = not hidden and not _info.is_empty() and since < SHOW_S
	if not visible:
		return
	modulate.a = clampf((SHOW_S - since) / 0.5, 0.0, 1.0)
	var vc := clampi(int(_info.get("value_class", 1)), 0, 3)
	var k := clampf((since - HubScreens.ROLL_START) / HubScreens.ROLL_S, 0.0, 1.0)
	_name.text = str(_info.get("name", "")).to_upper()
	_value.text = UiTheme.euro(int(round(int(_info.get("value", 0)) * k * k * (3.0 - 2.0 * k))))
	_value.add_theme_color_override("font_color", HubScreens.STAGE_CLASS[vc] if k >= 1.0 else UiTheme.CREAM)
	var st: Array = HubScreens.condition_stamp(float(_info.get("condition", 1.0)))
	var line := "%s %d%%" % [str(st[0]), int(round(float(_info.get("condition", 1.0)) * 100.0))]
	if int(_info.get("bonus", 0)) > 0:
		line += " · target %s" % UiTheme.euro_signed(int(_info.bonus))
	var set_info: Array = _info.get("set", [])
	if set_info.size() >= 4:
		line += " · %s %d/%d" % [str(set_info[0]).to_lower(), int(set_info[1]), int(set_info[2])]
		if bool(_info.get("set_done", false)):
			line += " · complete!"
	_line.text = line
