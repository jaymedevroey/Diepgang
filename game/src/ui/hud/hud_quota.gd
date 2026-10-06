class_name HudQuota
extends HudFader
## De quota waar je ze voelt (golf 3, ui2-12 en ontwerp-3): linksboven, enkel in de hub en in de Mol
## (op de planeet te voet blijft de HUD rustig). Een dunne balk met wat dit kwartaal verdiend is
## tegenover de quota, en in de Mol erachter, lichter, wat de buit in het laadruim naar schatting
## oplevert (de echte prijs geeft de poort). Daaronder het laadruim in kg, rood als het te zwaar is.
## In de hub met een open buit: wat nog verkocht moet worden.
## Gebruik: in de HUD `hud_quota.update_from(player, game)` per frame.

const WIDTH := 330.0
const BAR_H := 10.0

var _title: Label
var _numbers: Label
var _bar: Control
var _line: Label
var _ratio := 0.0
var _lo := 0.0
var _hi := 0.0
var _over := false
var _met := false


func _init() -> void:
	mode_key = "hud/prompts"
	needs_content = true
	hold = 4.0
	custom_minimum_size = Vector2(WIDTH, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HudChip"
	chip.custom_minimum_size = Vector2(WIDTH, 0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(col)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_title = Label.new()
	_title.text = "QUOTA"
	_title.add_theme_font_override("font", UiTheme.heading())
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UiTheme.YELLOW)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	_numbers = Label.new()
	_numbers.add_theme_font_override("font", UiTheme.body(900))
	_numbers.add_theme_font_size_override("font_size", 19)
	_numbers.add_theme_color_override("font_color", UiTheme.CREAM)
	row.add_child(_numbers)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, BAR_H)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	col.add_child(_bar)
	_line = Label.new()
	_line.add_theme_font_override("font", UiTheme.body(800))
	_line.add_theme_font_size_override("font_size", 18)
	_line.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	col.add_child(_line)


## Elke frame: waar staat de speler, wat is verdiend, wat ligt in het laadruim.
func update_from(player: Player, game: Game) -> void:
	var c: Company = game.company if game else null
	var where := ""
	if c != null and player != null:
		if game.mol and game.mol.contains_point(player.global_position):
			where = "mol"
		elif game.ship and game.ship.contains(player.global_position):
			where = "hub"
	active = where != ""
	if not active:
		return
	var q := maxf(1.0, float(c.quota()))
	_ratio = clampf(float(c.earned) / q, 0.0, 1.0)
	_met = c.earned >= c.quota()
	_numbers.text = "%s / %s" % [UiTheme.euro(c.earned), UiTheme.euro(c.quota())]
	_title.text = "QUOTA MET" if _met else "QUOTA · Q%d" % c.quarter
	_title.add_theme_color_override("font_color", UiTheme.GOOD if _met else UiTheme.YELLOW)
	var est := Vector2i.ZERO
	var line := ""
	_over = false
	if where == "mol":
		var mol: Mol = game.mol
		var cargo := Appraisal.hold_items(game)
		est = Appraisal.estimate_haul(cargo, c.appraisal.field_contract(), not bool(c.haul.get("target_paid", false)))
		var kg := mol.cargo_mass()
		var cap := mol.cargo_capacity()
		_over = kg > cap + 0.01
		line = "Hold %d/%d kg" % [int(ceil(kg)), int(cap)]
		if not cargo.is_empty():
			line += " · haul %s" % Appraisal.range_text(est)
		if _over:
			line += " · too heavy"
	elif c.haul_open():
		var a := c.appraisal
		var waiting := a.unappraised_items()
		var ready := a.appraised_items()
		est = Appraisal.estimate_haul(waiting, c.haul.get("contract", {}), not bool(c.haul.get("target_paid", false)))
		var ready_v := 0
		for it: FindItem in ready:
			ready_v += a.value_of(it)
		est += Vector2i(ready_v, ready_v)
		line = "To sell: %s" % Appraisal.range_text(est) if not (waiting.is_empty() and ready.is_empty()) else ""
	else:
		line = "Shift %d of %d" % [c.shift, Tuning.get_i("company", "shifts", 3)]
	_lo = clampf(float(est.x) / q, 0.0, 1.0)
	_hi = clampf(float(est.y) / q, 0.0, 1.0)
	_line.text = line
	_line.add_theme_color_override("font_color", UiTheme.DANGER if _over else UiTheme.CREAM_DIM)
	_bar.queue_redraw()


## De balk: donker, verdiend in geel (groen als de quota gehaald is), de schatting van de buit erachter
## (vol tot de onderkant, gestreept tot de bovenkant), een streepje per dienst.
func _draw_bar() -> void:
	var w := _bar.size.x
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 0, w, h), UiTheme.ANTHRACITE_HI)
	var done := w * _ratio
	var col := UiTheme.GOOD if _met else UiTheme.YELLOW
	var lo := minf(w, done + w * _lo)
	var hi := minf(w, done + w * _hi)
	if hi > done:
		_bar.draw_rect(Rect2(done, 0, hi - done, h), Color(col, 0.22))
	if lo > done:
		_bar.draw_rect(Rect2(done, 0, lo - done, h), Color(col, 0.5))
	if done > 0.0:
		_bar.draw_rect(Rect2(0, 0, maxf(3.0, done), h), col)
	var parts := maxi(1, Tuning.get_i("company", "shifts", 3))
	for i in range(1, parts):
		var x := w * i / parts
		_bar.draw_line(Vector2(x, -2), Vector2(x, h + 2), UiTheme.ANTHRACITE_LO, 2.0)
