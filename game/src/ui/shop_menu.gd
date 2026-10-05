class_name ShopMenu
extends Control
## Een toonbank in de hub (E aan het gereedschapsrek, de uitgiftebalie of de Mol-werf): de
## upgrades van die toonbank als werkorders, in dezelfde DIG-console als de contractbalie (ui-03).
## Per kaart: een beeld, de naam, wat je er NIEUW mee kan (GDD §5), een regel uitleg, de prijs voor
## deze ploeg en de knop (BUY, OWNED, of waarom niet: bevroren rekening, te weinig geld).
## Kopen kan iedereen; de host beslist (Company.buy). Na een koop een stempel PURCHASED op de kaart.
## Het spel loopt door; Esc, E of CLOSE sluit.

const WIDTH := 1000.0
const CARD_H := 470.0

var company: Company
var counter := ""
var _title: Label
var _status: Label
var _frozen: Control
var _frozen_label: Label
var _cards: HBoxContainer
var _note: Label
var _time := 0.0
## Wat we net kochten (stempel), tot de toestand het bevestigt.
var _pending := ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var console := PanelContainer.new()
	console.custom_minimum_size = Vector2(WIDTH, 0)
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color("#14161A")
	cb.border_color = UiTheme.YELLOW
	cb.set_border_width_all(3)
	cb.set_corner_radius_all(10)
	cb.shadow_color = Color(0, 0, 0, 0.6)
	cb.shadow_size = 24
	console.add_theme_stylebox_override("panel", cb)
	center.add_child(console)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	console.add_child(outer)
	outer.add_child(_header())
	outer.add_child(HazardStrip.new(10.0))
	# Bevroren rekening: een rode strook met de schuld (ontwerp-2: schuld heeft een gevolg).
	_frozen = PanelContainer.new()
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.34, 0.04, 0.0, 0.94)
	fb.content_margin_left = 26
	fb.content_margin_right = 26
	fb.content_margin_top = 10
	fb.content_margin_bottom = 10
	_frozen.add_theme_stylebox_override("panel", fb)
	_frozen_label = Label.new()
	_frozen_label.add_theme_font_override("font", UiTheme.body(900))
	_frozen_label.add_theme_font_size_override("font_size", 21)
	_frozen_label.add_theme_color_override("font_color", UiTheme.CREAM)
	_frozen_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_frozen.add_child(_frozen_label)
	outer.add_child(_frozen)
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 26)
	body.add_theme_constant_override("margin_top", 18)
	body.add_theme_constant_override("margin_bottom", 22)
	outer.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	body.add_child(col)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 18)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_cards)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	_note = Label.new()
	_note.add_theme_font_override("font", UiTheme.body(700))
	_note.add_theme_font_size_override("font_size", 20)
	_note.add_theme_color_override("font_color", Color("#C9C1B2"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_note)
	var close_b := Button.new()
	close_b.text = "CLOSE"
	close_b.theme_type_variation = &"GhostButton"
	close_b.custom_minimum_size = Vector2(200, 48)
	close_b.pressed.connect(close)
	foot.add_child(close_b)


func _header() -> Control:
	var bar := PanelContainer.new()
	var bb := StyleBoxFlat.new()
	bb.bg_color = UiTheme.YELLOW
	bb.corner_radius_top_left = 8
	bb.corner_radius_top_right = 8
	bb.content_margin_left = 22
	bb.content_margin_right = 22
	bb.content_margin_top = 10
	bb.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	var logo := PanelContainer.new()
	var lb := StyleBoxFlat.new()
	lb.bg_color = UiTheme.ANTHRACITE
	lb.set_corner_radius_all(4)
	lb.content_margin_left = 10
	lb.content_margin_right = 10
	lb.content_margin_top = 0
	lb.content_margin_bottom = 2
	logo.add_theme_stylebox_override("panel", lb)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var ll := Label.new()
	ll.text = "DIG"
	ll.add_theme_font_override("font", UiTheme.heading())
	ll.add_theme_font_size_override("font_size", 34)
	ll.add_theme_color_override("font_color", UiTheme.YELLOW)
	ll.add_theme_constant_override("shadow_offset_y", 0)
	logo.add_child(ll)
	_title = Label.new()
	_title.add_theme_font_override("font", UiTheme.heading())
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	_title.add_theme_constant_override("shadow_offset_y", 0)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_override("font", UiTheme.body(900))
	_status.add_theme_font_size_override("font_size", 21)
	_status.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	_status.add_theme_constant_override("shadow_offset_y", 0)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status)
	return bar


func open(c: Company, which: String) -> void:
	if company != c:
		if company:
			company.changed.disconnect(_on_changed)
			company.buy_denied.disconnect(_on_denied)
		company = c
		company.changed.connect(_on_changed)
		company.buy_denied.connect(_on_denied)
	counter = which
	_pending = ""
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.ui("open")
	_refresh()
	for b: Button in _cards.find_children("*", "Button", true, false):
		if not b.disabled:
			b.grab_focus()
			break


func close() -> void:
	if not visible:
		return
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.ui("back")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_time += delta


func _on_changed() -> void:
	if _pending != "" and company.has_upgrade(_pending):
		Sfx.ui("toast")
	_refresh()


func _on_denied(_id: String, reason: String) -> void:
	_pending = ""
	_note.text = reason
	_note.add_theme_color_override("font_color", UiTheme.DANGER)
	Sfx.ui("back")
	_refresh_cards()


## Ids van de upgrades aan deze toonbank, in de volgorde van de winkel.
func items() -> Array[String]:
	var out: Array[String] = []
	for id: String in Upgrades.ORDER:
		if str(Upgrades.info(id).counter) == counter:
			out.append(id)
	return out


func _buy(id: String) -> void:
	var why := Upgrades.blocker(company, id)
	if why != "":
		_note.text = why
		_note.add_theme_color_override("font_color", UiTheme.DANGER)
		Sfx.ui("back")
		return
	Sfx.ui("click")
	_pending = id
	_note.text = "Relayed to head office…"
	_note.remove_theme_color_override("font_color")
	company.buy(id, counter)


func _refresh() -> void:
	if company == null or not visible:
		return
	_title.text = str(Upgrades.COUNTER_NAMES.get(counter, "Supplies")).to_upper()
	var owned := 0
	for id in Upgrades.ORDER:
		if company.has_upgrade(id):
			owned += 1
	_status.text = "FUNDS %s   ·   %d/%d UPGRADES" % [UiTheme.euro(company.cash), owned, Upgrades.ORDER.size()]
	_frozen.visible = company.in_debt()
	_frozen_label.text = "ACCOUNT FROZEN: you owe head office %s. No purchases until your funds are back above €0. Debt costs %d%% interest per shift." % [
			UiTheme.euro(-company.cash), int(round(Tuning.get_f("company", "debt_interest", 0.1) * 100.0))]
	_refresh_cards()
	if _pending == "":
		_note.remove_theme_color_override("font_color")
		var others := PackedStringArray()
		for k: String in Upgrades.COUNTERS:
			if k != counter:
				others.append(str(Upgrades.COUNTER_IN_TEXT[k]))
		_note.text = "Upgrades are for the whole crew and you keep them, even after a missed quota. More at the %s." % " and the ".join(others)
	elif company.has_upgrade(_pending):
		_note.text = "Purchased: %s. %s." % [str(Upgrades.info(_pending).name), str(Upgrades.info(_pending).does)]
		_note.add_theme_color_override("font_color", UiTheme.GOOD)
		_pending = ""


func _refresh_cards() -> void:
	var focus_id := ""
	for card in _cards.get_children():
		var b := card.find_child("BuyButton", true, false) as Button
		if b and b.has_focus():
			focus_id = str(card.get_meta("id", ""))
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for id in items():
		var card := _card(id)
		_cards.add_child(card)
		if id == focus_id:
			var fb := card.find_child("BuyButton", true, false) as Button
			if fb and not fb.disabled:
				fb.grab_focus.call_deferred()


## Eén werkorder: beeld, naam, wat het opent, uitleg, prijs en de knop.
func _card(id: String) -> Control:
	var u := Upgrades.info(id)
	var owned := company.has_upgrade(id)
	var price := Upgrades.price(id, company.team_size())
	var why := Upgrades.blocker(company, id)
	var p := PanelContainer.new()
	p.set_meta("id", id)
	p.custom_minimum_size = Vector2(450, CARD_H)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#1E2126")
	box.border_color = UiTheme.GOOD if owned else Color("#3B4048")
	box.set_border_width_all(3 if owned else 2)
	box.set_corner_radius_all(8)
	box.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var b := Button.new()
	b.name = "BuyButton"
	b.custom_minimum_size = Vector2(0, 52)
	if owned:
		b.text = "OWNED"
		b.disabled = true
	elif why != "" and why != "Not enough funds":
		b.text = "FROZEN" if company.in_debt() else "LOCKED"
		b.disabled = true
	else:
		b.text = "BUY  %s" % UiTheme.euro(price)
		b.disabled = why != ""
	b.pressed.connect(_buy.bind(id))
	var art := _ItemArt.new()
	art.menu = self
	art.item = id
	art.custom_minimum_size = Vector2(0, 150)
	v.add_child(art)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(pad)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	pad.add_child(info)
	var h := Label.new()
	h.text = str(u.name).to_upper()
	h.add_theme_font_override("font", UiTheme.heading())
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", UiTheme.CREAM)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(h)
	var does := Label.new()
	does.text = str(u.does)
	does.add_theme_font_override("font", UiTheme.body(800))
	does.add_theme_font_size_override("font_size", 21)
	does.add_theme_color_override("font_color", UiTheme.YELLOW)
	does.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(does)
	var detail := Label.new()
	detail.text = str(u.detail)
	detail.add_theme_font_override("font", UiTheme.body(700))
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color("#A9A296"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(detail)
	var status := Label.new()
	status.add_theme_font_override("font", UiTheme.body(800))
	status.add_theme_font_size_override("font_size", 19)
	if owned:
		status.text = "In use by the whole crew"
		status.add_theme_color_override("font_color", UiTheme.GOOD)
	elif why != "":
		status.text = "%s · %s" % [why, UiTheme.euro(price)] if why == "Not enough funds" else why
		status.add_theme_color_override("font_color", UiTheme.DANGER)
	else:
		status.text = "%s for a crew of %d" % [UiTheme.euro(price), company.team_size()]
		status.add_theme_color_override("font_color", Color("#C9C1B2"))
	info.add_child(status)
	var bpad := MarginContainer.new()
	bpad.add_theme_constant_override("margin_left", 18)
	bpad.add_theme_constant_override("margin_right", 18)
	bpad.add_child(b)
	v.add_child(bpad)
	if owned:
		var stamp := InkStamp.make("PURCHASED", UiTheme.GOOD, 26, -9.0)
		stamp.fill = Color(0.06, 0.05, 0.05, 0.72)
		art.add_child(stamp)
		art.resized.connect(func() -> void:
			stamp.refit()
			stamp.position = Vector2(art.size.x - stamp.size.x - 14.0, art.size.y - stamp.size.y - 10.0))
	return p


## Het beeld bovenaan een kaart: een eenvoudige tekening van de upgrade op een donkere plaat.
class _ItemArt extends Control:
	var menu: ShopMenu
	var item := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var t := menu._time if menu else 0.0
		draw_rect(Rect2(0, 0, w, h), Color("#0B0C10"))
		for i in range(0, int(w), 24):
			draw_line(Vector2(i, 0), Vector2(i, h), Color(1, 1, 1, 0.025))
		for j in range(0, int(h), 24):
			draw_line(Vector2(0, j), Vector2(w, j), Color(1, 1, 1, 0.025))
		var c := Vector2(w * 0.5, h * 0.52)
		var y := UiTheme.YELLOW
		match item:
			Upgrades.DRILL_T2:
				var tex: Texture2D = load("res://assets/ui/icons/drill.svg")
				draw_texture_rect(tex, Rect2(c - Vector2(56, 56), Vector2(112, 112)), false, y)
				_badge(c + Vector2(70, -40), "T2")
			Upgrades.MOL_HEAD_T2:
				var tex2: Texture2D = load("res://assets/ui/icons/mol.svg")
				draw_texture_rect(tex2, Rect2(c - Vector2(60, 60), Vector2(120, 120)), false, y)
				_badge(c + Vector2(76, -42), "T2")
			Upgrades.SCANNER:
				var r := 56.0
				draw_circle(c, r, Color("#0E2A14"))
				draw_arc(c, r, 0, TAU, 48, Color(0.42, 1.0, 0.52, 0.8), 3.0)
				draw_arc(c, r * 0.55, 0, TAU, 40, Color(0.42, 1.0, 0.52, 0.35), 2.0)
				var a := fmod(t * 2.2, TAU)
				draw_line(c, c + Vector2(cos(a), sin(a)) * r, Color(0.42, 1.0, 0.52, 0.9), 3.0)
				for bp: Vector2 in [Vector2(20, -24), Vector2(-30, 12), Vector2(8, 34)]:
					draw_circle(c + bp, 5.0, Color(0.6, 1.0, 0.6, 0.6 + 0.4 * sin(t * 3.0 + bp.x)))
			Upgrades.LAMP:
				var o := c + Vector2(-70, 0)
				draw_colored_polygon(PackedVector2Array([o, o + Vector2(160, -56), o + Vector2(160, 56)]), Color(1.0, 0.86, 0.55, 0.22))
				draw_colored_polygon(PackedVector2Array([o, o + Vector2(110, -26), o + Vector2(110, 26)]), Color(1.0, 0.9, 0.65, 0.35))
				draw_circle(o, 22.0, y)
				draw_circle(o + Vector2(6, 0), 11.0, Color(1.0, 0.95, 0.8))
			Upgrades.CARGO:
				var r2 := Rect2(c - Vector2(70, 44), Vector2(140, 88))
				draw_rect(r2, Color("#3B2A12"))
				draw_rect(r2, y, false, 4.0)
				draw_line(r2.position, r2.end, Color(y, 0.6), 3.0)
				draw_line(Vector2(r2.position.x, r2.end.y), Vector2(r2.end.x, r2.position.y), Color(y, 0.6), 3.0)
				var f := UiTheme.heading()
				var kg := "%d KG" % int(Tuning.get_f("economy", "cargo_kg_t2", 140.0))
				draw_string(f, Vector2(r2.position.x, r2.end.y + 30), kg, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x, 24, UiTheme.CREAM)
		draw_rect(Rect2(0, h - 4, w, 4), Color("#2A2E35"))

	func _badge(at: Vector2, text: String) -> void:
		var f := UiTheme.heading()
		draw_rect(Rect2(at - Vector2(24, 20), Vector2(56, 36)), UiTheme.DANGER)
		draw_string(f, at + Vector2(-20, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiTheme.CREAM)
