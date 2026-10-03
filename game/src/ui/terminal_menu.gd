class_name TerminalMenu
extends Control
## De opdrachtterminal in de hub (E op de terminal): de stand van de firma (kas, reputatie,
## kwartaal, quota) en drie opdrachten om uit te kiezen. Kiezen kan iedereen; de host beslist
## (Company). Na een keuze: een bevestiging ("KOERS GEZET NAAR …") en het menu sluit vanzelf; de
## HUD zegt daarna wat er gebeurt (De Ekster vliegt erheen, dan naar de Mol). Het spel loopt door;
## Esc, E of SLUITEN sluit.

## Zo lang blijft de bevestiging staan voor het menu vanzelf sluit (s).
const CONFIRM_S := 1.4
## Zo lang wachten we (client) op het antwoord van de host voor we zeggen dat er niets kwam (s).
const ANSWER_S := 6.0

var company: Company
var _status: Label
var _quota_bar: ProgressBar
var _quota_label: Label
var _cards: HBoxContainer
var _note: Label
var _confirm: Label
## Opdracht die we kozen en waar we op wachten (index), of −1.
var _pending := -1
var _pending_at := 0.0
## Seconden tot het menu na de bevestiging sluit (0 = niet aan het sluiten). Telt per frame met
## een plafond: kiezen bouwt de nieuwe wereld, en die eerste lange frame telt niet mee.
var _closing_left := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.NIGHT, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(1080, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	var title := Label.new()
	title.text = "DIG · OPDRACHTEN"
	title.theme_type_variation = &"Title"
	col.add_child(title)
	col.add_child(HazardStrip.new(8.0))
	# Stand van de firma.
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	col.add_child(card)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	card.add_child(sv)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	sv.add_child(_status)
	_quota_label = Label.new()
	_quota_label.theme_type_variation = &"Caption"
	sv.add_child(_quota_label)
	_quota_bar = ProgressBar.new()
	_quota_bar.custom_minimum_size = Vector2(0, 18)
	_quota_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = UiTheme.ANTHRACITE_LO
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.YELLOW
	fill.set_corner_radius_all(4)
	_quota_bar.add_theme_stylebox_override("background", bg)
	_quota_bar.add_theme_stylebox_override("fill", fill)
	sv.add_child(_quota_bar)
	# Drie opdrachten.
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	col.add_child(_cards)
	# Bevestiging na een keuze (groot, geel), daaronder de uitleg.
	_confirm = Label.new()
	_confirm.add_theme_font_override("font", UiTheme.heading())
	_confirm.add_theme_font_size_override("font_size", 30)
	_confirm.add_theme_color_override("font_color", UiTheme.YELLOW)
	_confirm.visible = false
	col.add_child(_confirm)
	_note = Label.new()
	_note.theme_type_variation = &"Caption"
	_note.add_theme_font_size_override("font_size", 18)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(_note)
	var close_b := Button.new()
	close_b.text = "SLUITEN"
	close_b.theme_type_variation = &"GhostButton"
	close_b.custom_minimum_size = Vector2(240, 48)
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close_b.pressed.connect(close)
	col.add_child(close_b)


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
	var now := Time.get_ticks_msec() / 1000.0
	if _closing_left > 0.0:
		_closing_left -= minf(delta, 0.05)
		if _closing_left <= 0.0:
			close()
	elif _pending >= 0 and now - _pending_at > ANSWER_S:
		# De host antwoordde niet met deze opdracht (de Mol vertrok, of iemand anders koos).
		_pending = -1
		_note.text = "Geen bevestiging van de host: misschien vertrok de Mol net, of koos iemand anders. Probeer opnieuw."
		_note.add_theme_color_override("font_color", UiTheme.DANGER)


func _on_company_changed() -> void:
	if _pending >= 0 and company.contract_ready() and _pending < company.options.size() \
			and company.contract == company.options[_pending]:
		_pending = -1
		_confirm.text = "KOERS GEZET NAAR %s" % str(company.contract.name)
		_confirm.visible = true
		_closing_left = CONFIRM_S
		Sfx.ui("toast")
	_refresh()


func _on_mol_mode(_mode: int) -> void:
	_refresh()


func _choose(index: int) -> void:
	var mol: Mol = company.game.mol
	if mol == null or mol.mode != Mol.Mode.DOCKED:
		_note.text = "Kan nu niet: de Mol staat niet in de baai."
		_note.add_theme_color_override("font_color", UiTheme.DANGER)
		Sfx.ui("back")
		return
	if company.contract == company.options[index]:
		return
	Sfx.ui("click")
	_pending = index
	_pending_at = Time.get_ticks_msec() / 1000.0
	_note.text = "Doorgegeven aan de brug…"
	_note.remove_theme_color_override("font_color")
	company.choose(index)


func _refresh() -> void:
	if company == null or not visible:
		return
	var c := company
	var q := c.quota()
	_status.text = "KAS  %s     ·     REPUTATIE  %+d     ·     KWARTAAL %d  ·  DIENST %d/%d" % [
			UiTheme.euro(c.cash), c.reputation, c.quarter, c.shift, Tuning.get_i("company", "shifts", 3)]
	_quota_label.text = "QUOTA DIT KWARTAAL: %s van %s (voor %d %s). Gemist = boete." % [
			UiTheme.euro(c.earned), UiTheme.euro(q), clampi(c.game.players.get_child_count(), 1, 4),
			"robot" if c.game.players.get_child_count() == 1 else "robots"]
	_quota_bar.max_value = maxf(1.0, q)
	_quota_bar.value = clampf(c.earned, 0.0, q)
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for i in c.options.size():
		_cards.add_child(_option_card(i, c.options[i], c.contract == c.options[i]))
	if _pending >= 0:
		return # "Doorgegeven…" blijft staan tot de host antwoordt
	_note.remove_theme_color_override("font_color")
	var mol: Mol = c.game.mol
	var docked: bool = mol != null and mol.mode == Mol.Mode.DOCKED
	if not docked:
		_note.text = "De Mol is op weg. Opdrachten kiezen kan als hij terug in de baai staat."
	elif c.contract_ready():
		_note.text = "Gekozen: %s. Stap in de Mol en trek aan de hendel (VERTREK) om te droppen." % c.contract.name
	else:
		_note.text = "Kies een opdracht. Meer risico = meer opbrengst, maar het magma stijgt sneller."


func _option_card(index: int, o: Dictionary, chosen: bool) -> Control:
	var risk := int(o.risk)
	var p := PanelContainer.new()
	p.theme_type_variation = &"Card"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if chosen:
		# De gekozen opdracht valt op: gele rand.
		var hl := StyleBoxFlat.new()
		hl.bg_color = UiTheme.ANTHRACITE_HI
		hl.border_color = UiTheme.YELLOW
		hl.set_border_width_all(3)
		hl.set_corner_radius_all(8)
		hl.content_margin_left = 12
		hl.content_margin_right = 12
		hl.content_margin_top = 12
		hl.content_margin_bottom = 12
		p.add_theme_stylebox_override("panel", hl)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var h := Label.new()
	h.text = str(o.name)
	h.theme_type_variation = &"SubHeading"
	v.add_child(h)
	var planet := Label.new()
	planet.text = PlanetType.NAMES[company.game.planet_type].to_upper()
	planet.theme_type_variation = &"Caption"
	v.add_child(planet)
	var r := Label.new()
	r.text = "RISICO  %s" % Company.RISK_NAMES[risk]
	r.add_theme_color_override("font_color", [UiTheme.GOOD, UiTheme.YELLOW, UiTheme.DANGER][risk])
	r.add_theme_font_size_override("font_size", 22)
	v.add_child(r)
	var d := Label.new()
	d.text = "Opbrengst ×%.2f\nMagma ×%.2f" % [Company.pay_factor(risk), Company.magma_factor(risk)]
	v.add_child(d)
	var b := Button.new()
	b.text = "GEKOZEN" if chosen else "KIEZEN"
	# Niet uitgeschakeld als de Mol weg is: dan zegt het menu waarom het niet kan.
	b.disabled = chosen
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(_choose.bind(index))
	v.add_child(b)
	return p
