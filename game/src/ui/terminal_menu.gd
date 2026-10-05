class_name TerminalMenu
extends Control
## De opdrachtterminal in de hub (E op de terminal): de contractbalie van DIG (ui-03). Bovenaan de
## stand van de firma (kas, reputatie, kwartaal, de quota met een streepje per dienst), daaronder drie
## werkorders om uit te kiezen: per kaart de planeet als draaiend bolletje met een speld op de
## claim, de naam groot met een bijnaam, een risicostempel, wat het oplevert en hoe snel het magma
## stijgt, en ruimte voor twee à drie voorwaarden (`modifiers` in de opdracht, pakket F1).
## Kiezen kan iedereen; de host beslist (Company). Na een keuze één bevestiging: een stempel SIGNED
## op de kaart en "COURSE SET" bovenaan, en het menu sluit vanzelf; de HUD zegt daarna wat er
## gebeurt (De Ekster vliegt erheen, dan naar de Mol). Het spel loopt door; Esc, E of CLOSE sluit.

## Zo lang blijft de bevestiging staan voor het menu vanzelf sluit (s).
const CONFIRM_S := 1.4
## Zo lang wachten we (client) op het antwoord van de host voor we zeggen dat er niets kwam (s).
const ANSWER_S := 6.0
const WIDTH := 1240.0
## Hoeveel voorwaarden een kaart kan tonen (de rest valt weg).
const MAX_MODIFIERS := 3
## Bijnamen per planeet (PlanetType.Id), vast per opdracht (uit de seed): smaak bij een kaal nummer.
const NICKNAMES := [
	["Dry Gulch", "Rust Flats", "Old Scar", "Red Hollow", "Dust Bowl", "Copper Rim", "Cracked Mesa", "Brick Basin"],
	["Bone Yard", "Shell Beach", "Chalk Cliffs", "Old Reef", "Grandpa's Pit", "Fossil Shelf", "Limestone Steps", "Ammonite Bay"],
	["Glass Garden", "Violet Hollow", "Shard Valley", "Moonglow Pit", "Prism Rim", "Quiet Geode", "Amethyst Flats", "Echo Crater"],
]
const RISK_INK := [Color("#7BC043"), Color("#F2B705"), Color("#FF5A1F")]

var company: Company
var _status: Label
var _quota_bar: Control
var _quota_label: Label
var _cards: HBoxContainer
var _note: Label
var _confirm: Label
var _time := 0.0
## Opdracht die we kozen en waar we op wachten (index), of −1.
var _pending := -1
var _pending_at := 0.0
## Seconden tot het menu na de bevestiging sluit (0 = niet aan het sluiten). Telt per frame met
## een plafond: kiezen bouwt de nieuwe wereld, en die eerste lange frame telt niet mee.
var _closing_left := 0.0


## Bijnaam van een opdracht ("Dry Gulch"), vast per opdracht.
static func nickname(o: Dictionary) -> String:
	var planet := clampi(int(o.get("planet", 0)), 0, NICKNAMES.size() - 1)
	var list: Array = NICKNAMES[planet]
	return list[absi(int(o.get("seed", 0))) % list.size()]


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
	# De console: donker, met een gele rand en een kopbalk van de firma.
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
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 26)
	body.add_theme_constant_override("margin_top", 18)
	body.add_theme_constant_override("margin_bottom", 22)
	outer.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	body.add_child(col)
	# De quota van het kwartaal.
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 16)
	col.add_child(qrow)
	var qh := Label.new()
	qh.text = "QUOTA"
	qh.add_theme_font_override("font", UiTheme.heading())
	qh.add_theme_font_size_override("font_size", 20)
	qh.add_theme_color_override("font_color", UiTheme.YELLOW)
	qh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(qh)
	_quota_bar = _QuotaBar.new()
	_quota_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quota_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(_quota_bar)
	_quota_label = Label.new()
	_quota_label.add_theme_font_override("font", UiTheme.body(800))
	_quota_label.add_theme_font_size_override("font_size", 20)
	_quota_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	qrow.add_child(_quota_label)
	# Drie werkorders.
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 18)
	col.add_child(_cards)
	# Bevestiging na een keuze (groot, geel), daaronder de uitleg en de knop om te sluiten.
	_confirm = Label.new()
	_confirm.add_theme_font_override("font", UiTheme.heading())
	_confirm.add_theme_font_size_override("font_size", 32)
	_confirm.add_theme_color_override("font_color", UiTheme.YELLOW)
	_confirm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm.visible = false
	col.add_child(_confirm)
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


## Kopbalk: het DIG-logo, de naam van de balie en de stand van de firma.
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
	var title := Label.new()
	title.text = "CONTRACT DESK"
	title.add_theme_font_override("font", UiTheme.heading())
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	_status = Label.new()
	_status.add_theme_font_override("font", UiTheme.body(900))
	_status.add_theme_font_size_override("font_size", 21)
	_status.add_theme_color_override("font_color", UiTheme.ANTHRACITE)
	_status.add_theme_constant_override("shadow_offset_y", 0)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_status)
	return bar


func open(c: Company) -> void:
	if company != c:
		if company:
			company.changed.disconnect(_on_company_changed)
			var old_mol: Mol = company.game.mol
			if old_mol and old_mol.mode_changed.is_connected(_on_mol_mode):
				old_mol.mode_changed.disconnect(_on_mol_mode)
		company = c
		company.changed.connect(_on_company_changed)
	var mol: Mol = company.game.mol
	if mol and not mol.mode_changed.is_connected(_on_mol_mode):
		mol.mode_changed.connect(_on_mol_mode)
	_pending = -1
	_closing_left = 0.0
	_confirm.visible = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.ui("open")
	_refresh()
	# Meteen met het toetsenbord of een controller kunnen kiezen.
	for b: Button in _cards.find_children("*", "Button", true, false):
		if not b.disabled:
			b.grab_focus()
			break


func close() -> void:
	if not visible:
		return
	visible = false
	_pending = -1
	_closing_left = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.ui("back")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Esc of nog eens E: sluiten (E is ook waarmee je het menu opende).
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	var now := Time.get_ticks_msec() / 1000.0
	if _closing_left > 0.0:
		_closing_left -= minf(delta, 0.05)
		if _closing_left <= 0.0:
			close()
	elif _pending >= 0 and now - _pending_at > ANSWER_S:
		# De host antwoordde niet met deze opdracht (de Mol vertrok, of iemand anders koos).
		_pending = -1
		_note.text = "No confirmation from the host: maybe the Mole just left, or someone else picked first. Try again."
		_note.add_theme_color_override("font_color", UiTheme.DANGER)


func _on_company_changed() -> void:
	if _pending >= 0 and company.contract_ready() and _pending < company.options.size() \
			and company.contract == company.options[_pending]:
		_pending = -1
		_confirm.text = "COURSE SET: %s · %s" % [str(company.contract.name), nickname(company.contract).to_upper()]
		_confirm.visible = true
		_closing_left = CONFIRM_S
		Sfx.ui("toast")
	_refresh()


func _on_mol_mode(_mode: int) -> void:
	_refresh()


func _choose(index: int) -> void:
	var mol: Mol = company.game.mol
	if mol == null or mol.mode != Mol.Mode.DOCKED:
		_note.text = "Not now: the Mole isn't in the bay."
		_note.add_theme_color_override("font_color", UiTheme.DANGER)
		Sfx.ui("back")
		return
	if company.contract == company.options[index]:
		return
	Sfx.ui("click")
	_pending = index
	_pending_at = Time.get_ticks_msec() / 1000.0
	_note.text = "Relayed to the bridge…"
	_note.remove_theme_color_override("font_color")
	company.choose(index)


func _refresh() -> void:
	if company == null or not visible:
		return
	var c := company
	var q := c.quota()
	var shifts := Tuning.get_i("company", "shifts", 3)
	_status.text = "FUNDS %s   ·   REP %+d   ·   Q%d · SHIFT %d/%d" % [UiTheme.euro(c.cash), c.reputation, c.quarter, c.shift, shifts]
	var robots := clampi(c.game.players.get_child_count(), 1, 4)
	_quota_label.text = "%s / %s  ·  %s" % [UiTheme.euro(c.earned), UiTheme.euro(q), UiTheme.count(robots, "robot")]
	(_quota_bar as _QuotaBar).set_state(clampf(float(c.earned) / maxf(1.0, q), 0.0, 1.0), shifts)
	var focus_index := -1
	for i in _cards.get_child_count():
		var b := _first_button(_cards.get_child(i))
		if b and b.has_focus():
			focus_index = i
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in c.options.size():
		_cards.add_child(_option_card(i, c.options[i], c.contract == c.options[i]))
	if focus_index >= 0 and focus_index < _cards.get_child_count():
		var fb := _first_button(_cards.get_child(focus_index))
		if fb and not fb.disabled:
			fb.grab_focus.call_deferred()
	if _pending >= 0:
		return # "Doorgegeven…" blijft staan tot de host antwoordt
	_note.remove_theme_color_override("font_color")
	var mol: Mol = c.game.mol
	var docked: bool = mol != null and mol.mode == Mol.Mode.DOCKED
	if not docked:
		_note.text = "The Mole is out. You can pick a contract once it's back in the bay."
	elif c.contract_ready():
		_note.text = "Board the Mole and pull the LAUNCH lever to drop."
	else:
		_note.text = "More risk pays more, but the magma rises faster. Miss the quota and head office fines you."


func _first_button(n: Node) -> Button:
	var found := n.find_children("*", "Button", true, false)
	return found[0] as Button if not found.is_empty() else null


## Eén werkorder: de planeet, de claim, de stempel met het risico, de cijfers, de voorwaarden en
## de knop. De eerste knop van de kaart is de keuzeknop (tests zoeken hem zo).
func _option_card(index: int, o: Dictionary, chosen: bool) -> Control:
	var risk := clampi(int(o.risk), 0, 2)
	var planet := clampi(int(o.get("planet", 0)), 0, PlanetType.NAMES.size() - 1)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#1E2126")
	box.border_color = UiTheme.YELLOW if chosen else Color("#3B4048")
	box.set_border_width_all(3 if chosen else 2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	# De knop eerst in de boom (tests en het toetsenbord vinden hem zo), onderaan in beeld.
	var b := Button.new()
	b.text = "CHOSEN" if chosen else "CHOOSE"
	# Niet uitgeschakeld als de Mol weg is: dan zegt het menu waarom het niet kan.
	b.disabled = chosen
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(_choose.bind(index))
	# Bovenaan: de planeet op een sterrenhemel, met de naam en de stempel.
	var art := _CardArt.new()
	art.menu = self
	art.planet = planet
	art.seed = int(o.get("seed", 0))
	art.custom_minimum_size = Vector2(0, 190)
	v.add_child(art)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	v.add_child(pad)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	pad.add_child(info)
	var h := Label.new()
	h.text = str(o.name)
	h.add_theme_font_override("font", UiTheme.heading())
	h.add_theme_font_size_override("font_size", 30)
	h.add_theme_color_override("font_color", UiTheme.CREAM)
	info.add_child(h)
	var nick := Label.new()
	nick.text = "\"%s\"" % nickname(o)
	nick.add_theme_font_override("font", UiTheme.body(800))
	nick.add_theme_font_size_override("font_size", 21)
	nick.add_theme_color_override("font_color", UiTheme.YELLOW)
	info.add_child(nick)
	info.add_child(_stat_row("Pay", "×%.2f" % Company.pay_factor(risk), UiTheme.CREAM))
	info.add_child(_stat_row("Magma rises", "×%.2f" % Company.magma_factor(risk), RISK_INK[risk]))
	# Voorwaarden van de opdracht (pakket F1 vult `modifiers`); altijd plaats voor drie regels.
	var cond := Label.new()
	cond.text = "CONDITIONS"
	cond.add_theme_font_override("font", UiTheme.heading())
	cond.add_theme_font_size_override("font_size", 18)
	cond.add_theme_color_override("font_color", Color("#8C9096"))
	info.add_child(cond)
	var mods_box := VBoxContainer.new()
	mods_box.add_theme_constant_override("separation", 2)
	mods_box.custom_minimum_size.y = 3 * 26
	info.add_child(mods_box)
	var mods: Array = o.get("modifiers", [])
	if mods.is_empty():
		mods_box.add_child(_mod_line("Standard terms. No surprises promised.", true))
	for m in mods.slice(0, MAX_MODIFIERS):
		mods_box.add_child(_mod_line(str(m), false))
	var bpad := MarginContainer.new()
	bpad.add_theme_constant_override("margin_left", 18)
	bpad.add_theme_constant_override("margin_right", 18)
	bpad.add_theme_constant_override("margin_top", 4)
	bpad.add_child(b)
	v.add_child(bpad)
	# Risicostempel schuin rechtsonder in het beeld, en SIGNED over de gekozen planeet. Kinderen van
	# het beeld (een gewone Control): een container zou ze uitrekken.
	var stamp := InkStamp.make("RISK %s" % Company.RISK_NAMES[risk], RISK_INK[risk], 22, -7.0)
	stamp.fill = Color(0.06, 0.05, 0.05, 0.75)
	art.add_child(stamp)
	var signed: InkStamp = null
	if chosen:
		signed = InkStamp.make("SIGNED", UiTheme.YELLOW, 34, -12.0)
		signed.fill = Color(0.06, 0.05, 0.05, 0.72)
		art.add_child(signed)
	art.resized.connect(func() -> void:
		stamp.refit()
		if signed:
			signed.refit()
		stamp.position = Vector2(art.size.x - stamp.size.x - 12.0, art.size.y - stamp.size.y - 12.0)
		if signed:
			signed.position = Vector2(art.size.x * 0.32 - signed.size.x / 2.0, art.size.y * 0.56 - signed.size.y / 2.0))
	return p


func _stat_row(label_text: String, value: String, col: Color) -> Control:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.add_theme_font_override("font", UiTheme.body(700))
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("#C9C1B2"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", UiTheme.body(900))
	v.add_theme_font_size_override("font_size", 22)
	v.add_theme_color_override("font_color", col)
	row.add_child(v)
	return row


func _mod_line(text: String, dim: bool) -> Label:
	var l := Label.new()
	l.text = "· " + text
	l.add_theme_font_override("font", UiTheme.body(700))
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("#8C9096") if dim else UiTheme.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


## Het beeld bovenaan een kaart: sterren, de planeet met een speld op de claim, en haar naam.
class _CardArt extends Control:
	var menu: TerminalMenu
	var planet := 0
	var seed := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _process(_delta: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("#0B0C10"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + planet
		for i in 40:
			var p := Vector2(rng.randf() * w, rng.randf() * h)
			draw_circle(p, rng.randf_range(0.6, 1.6), Color(1, 1, 1, rng.randf_range(0.2, 0.7)))
		var t := menu._time if menu else 0.0
		PlanetGlobe.draw(self, Vector2(w * 0.32, h * 0.56), h * 0.38, planet, t, seed)
		# De naam rechts van de planeet, één woord per regel, zo groot als past.
		var f := UiTheme.heading()
		var words := PlanetType.NAMES[planet].to_upper().split(" ")
		var nx := w * 0.58
		var room := w - nx - 12.0
		var fs := 26
		for word in words:
			while fs > 16 and f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
		for i in words.size():
			draw_string(f, Vector2(nx, 54 + i * (fs + 6)), words[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiTheme.CREAM)
		draw_rect(Rect2(0, h - 4, w, 4), Color("#2A2E35"))


## De quotabalk: gevuld tot waar we staan, met een streepje per dienst.
class _QuotaBar extends Control:
	var ratio := 0.0
	var parts := 3

	func _init() -> void:
		custom_minimum_size = Vector2(200, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(r: float, shifts: int) -> void:
		ratio = r
		parts = maxi(1, shifts)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, UiTheme.ANTHRACITE_HI)
		if ratio > 0.0:
			draw_rect(Rect2(r.position, Vector2(maxf(6.0, r.size.x * ratio), r.size.y)), UiTheme.GOOD if ratio >= 1.0 else UiTheme.YELLOW)
		for i in range(1, parts):
			var x := r.size.x * i / parts
			draw_line(Vector2(x, -3), Vector2(x, r.size.y + 3), Color("#14161A"), 3.0)
