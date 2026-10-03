class_name Hud
extends Control
## De HUD (docs/research/hud-menu.md §4): weinig vast in beeld, alles dynamisch waar het kan.
##   midden        vizier (stip + ring) met de prompt eronder
##   boven midden  diepte, laag en kompas met de richting naar de Mol
##   onder midden  gereedschap (verschijnt bij wisselen), daarboven de meldingen
##   linksonder    wat je draagt
##   links         de ploeg (bij meerdere spelers)
##   in de Mol     besturing voor de piloot; bij vertrek een grote banner met aftelling
##   rechtsonder   in buitenzicht: het sonarbeeld uit de cabine
## main.gd roept elke frame update() aan.

const TOOLS := [["pickaxe", "HOUWEEL", "tool_1"], ["drill", "BOOR T1", "tool_2"]]

var main: Node
var crosshair: HudCrosshair
var compass: HudCompass
var hazard: HudHazard
var _prompt: HudFader
var _prompt_caps: HBoxContainer
var _prompt_text: Label
var _prompt_sub: Label
var _prompt_box: PanelContainer
var _hotbar: HudFader
var _slots: Array[PanelContainer] = []
var _tool_name: Label
var _tool_hint: HBoxContainer
var _carry: HudFader
var _ore: HudFader
var _ore_label: Label
var _ore_value: Label
var _ore_shown := -1
var _ore_connected := false
var _carry_name: Label
var _carry_value: Label
var _carry_bar: ColorRect
var _carry_bar_bg: ColorRect
var _carry_note: Label
var _toasts: VBoxContainer
var _banner: PanelContainer
var _banner_title: Label
var _banner_count: Label
var _banner_strip: HazardStrip
var _result: PanelContainer
var _result_title: Label
var _result_rows: VBoxContainer
var _team: HudFader
var _team_rows: VBoxContainer
var _pilot: HudFader
var _sonar: HudFader
var _sonar_view: TextureRect
var _stats: Label
var _host_chip: HudFader
var _host_label: Label
var _last_tool := -1
var _last_team := -1
var _was_seated := false
var _last_carry: Object = null
var _started := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_center()
	_build_top()
	_build_bottom()
	_build_left()
	_build_overlays()


# --- Opbouw -----------------------------------------------------------------------------------

func _build_center() -> void:
	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	crosshair = HudCrosshair.new()
	crosshair.position = -crosshair.custom_minimum_size / 2.0
	center.add_child(crosshair)

	_prompt = HudFader.new()
	_prompt.mode_key = "hud/prompts"
	_prompt.needs_content = true
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.position = Vector2(-300, 46)
	_prompt.size = Vector2(600, 90)
	center.add_child(_prompt)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)
	col.size = Vector2(600, 90)
	_prompt.add_child(col)
	var line := CenterContainer.new()
	col.add_child(line)
	_prompt_box = PanelContainer.new()
	_prompt_box.theme_type_variation = &"HudChip"
	line.add_child(_prompt_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_prompt_box.add_child(row)
	_prompt_caps = HBoxContainer.new()
	_prompt_caps.add_theme_constant_override("separation", 4)
	row.add_child(_prompt_caps)
	_prompt_text = Label.new()
	_prompt_text.add_theme_font_override("font", UiTheme.body(800))
	_prompt_text.add_theme_font_size_override("font_size", 19)
	row.add_child(_prompt_text)
	_prompt_sub = Label.new()
	_prompt_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_sub.add_theme_font_override("font", UiTheme.body(700))
	_prompt_sub.add_theme_font_size_override("font_size", 16)
	_prompt_sub.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	_prompt_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_prompt_sub.add_theme_constant_override("outline_size", 5)
	col.add_child(_prompt_sub)


func _build_top() -> void:
	compass = HudCompass.new()
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-HudCompass.WIDTH / 2.0, 18)
	add_child(compass)
	hazard = HudHazard.new()
	hazard.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hazard.position = Vector2(-HudHazard.WIDTH / 2.0, 108)
	add_child(hazard)

	_host_chip = HudFader.new()
	_host_chip.hold = 8.0
	_host_chip.needs_content = true
	_host_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_host_chip.position = Vector2(-330, 18)
	_host_chip.size = Vector2(312, 40)
	add_child(_host_chip)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HudChip"
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_host_chip.add_child(chip)
	_host_label = Label.new()
	_host_label.add_theme_font_size_override("font_size", 16)
	chip.add_child(_host_label)


func _build_bottom() -> void:
	# Gereedschap: twee vakjes onderaan in het midden, met de naam erboven bij het wisselen.
	_hotbar = HudFader.new()
	_hotbar.mode_key = "hud/tools"
	_hotbar.hold = 2.5
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.position = Vector2(-160, -150)
	_hotbar.size = Vector2(320, 132)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	var col := VBoxContainer.new()
	col.size = Vector2(320, 132)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	_hotbar.add_child(col)
	_tool_name = Label.new()
	_tool_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_name.add_theme_font_override("font", UiTheme.heading())
	_tool_name.add_theme_font_size_override("font_size", 20)
	_tool_name.add_theme_color_override("font_color", UiTheme.YELLOW)
	_tool_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_tool_name.add_theme_constant_override("outline_size", 6)
	col.add_child(_tool_name)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 10)
	col.add_child(slots)
	for t: Array in TOOLS:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(72, 72)
		slots.add_child(slot)
		var inner := Control.new()
		inner.custom_minimum_size = Vector2(52, 52)
		slot.add_child(inner)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/icons/%s.svg" % t[0])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_child(icon)
		var cap := KeyCap.make(t[2], 13)
		cap.position = Vector2(-20, -20) # linksboven over de rand van het vakje
		inner.add_child(cap)
		_slots.append(slot)
	_tool_hint = HBoxContainer.new()
	_tool_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_tool_hint.add_theme_constant_override("separation", 6)
	col.add_child(_tool_hint)
	_tool_hint.add_child(KeyCap.make("dig", 14))
	var hl := Label.new()
	hl.text = "graven (vasthouden)"
	hl.add_theme_font_size_override("font_size", 16)
	_tool_hint.add_child(hl)

	# Meldingen: boven het gereedschap, nieuwste onderaan.
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.position = Vector2(-300, -330)
	_toasts.size = Vector2(600, 170)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# Wat je draagt: linksonder.
	_carry = HudFader.new()
	_carry.mode_key = "hud/prompts"
	_carry.needs_content = true
	_carry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_carry.position = Vector2(28, -170)
	_carry.size = Vector2(380, 150)
	add_child(_carry)
	var card := PanelContainer.new()
	card.theme_type_variation = &"HudChip"
	card.custom_minimum_size = Vector2(360, 0)
	_carry.add_child(card)
	var cc := VBoxContainer.new()
	cc.add_theme_constant_override("separation", 6)
	card.add_child(cc)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	cc.add_child(top)
	var bone := TextureRect.new()
	bone.texture = preload("res://assets/ui/icons/bone.svg")
	bone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bone.custom_minimum_size = Vector2(34, 34)
	bone.modulate = Color("#E8DCC0")
	top.add_child(bone)
	var tc := VBoxContainer.new()
	tc.add_theme_constant_override("separation", -2)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tc)
	_carry_name = Label.new()
	_carry_name.add_theme_font_override("font", UiTheme.body(900))
	_carry_name.add_theme_font_size_override("font_size", 19)
	tc.add_child(_carry_name)
	_carry_note = Label.new()
	_carry_note.add_theme_font_size_override("font_size", 15)
	_carry_note.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	tc.add_child(_carry_note)
	_carry_value = Label.new()
	_carry_value.add_theme_font_override("font", UiTheme.body(900))
	_carry_value.add_theme_font_size_override("font_size", 22)
	_carry_value.add_theme_color_override("font_color", UiTheme.YELLOW)
	top.add_child(_carry_value)
	# Gaafheid als balk (met het percentage erin).
	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 10)
	cc.add_child(bar_wrap)
	_carry_bar_bg = ColorRect.new()
	_carry_bar_bg.color = Color(0, 0, 0, 0.5)
	_carry_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(_carry_bar_bg)
	_carry_bar = ColorRect.new()
	_carry_bar.color = UiTheme.GOOD
	_carry_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar_wrap.add_child(_carry_bar)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	cc.add_child(keys)
	keys.add_child(KeyCap.make("interact", 14))
	keys.add_child(_small("neerzetten"))
	var gap := Control.new()
	gap.custom_minimum_size.x = 10
	keys.add_child(gap)
	keys.add_child(KeyCap.make("dig", 14))
	keys.add_child(_small("gooien"))

	# Besturing van de Mol (piloot): onderaan, verschijnt bij het instappen.
	_pilot = HudFader.new()
	_pilot.mode_key = "hud/prompts"
	_pilot.hold = 9.0
	_pilot.needs_content = true
	_pilot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pilot.position = Vector2(-470, -96)
	_pilot.size = Vector2(940, 70)
	add_child(_pilot)
	var pc := CenterContainer.new()
	pc.size = Vector2(940, 70)
	_pilot.add_child(pc)
	var pchip := PanelContainer.new()
	pchip.theme_type_variation = &"HudChip"
	pc.add_child(pchip)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	pchip.add_child(prow)
	var ph := Label.new()
	ph.text = "DE MOL"
	ph.add_theme_font_override("font", UiTheme.heading())
	ph.add_theme_font_size_override("font_size", 17)
	ph.add_theme_color_override("font_color", UiTheme.YELLOW)
	prow.add_child(ph)
	for part: Array in [[["move_forward", "move_back"], "gas"], [["move_left", "move_right"], "sturen"],
			[["jump", "crouch"], "neus"], [["mol_view"], "buitenzicht"], [["sonar_ping"], "ping"], [["horn"], "toeter"],
			[["interact"], "uitstappen"]]:
		var sep := Control.new()
		sep.custom_minimum_size.x = 10
		prow.add_child(sep)
		for a: String in part[0]:
			prow.add_child(KeyCap.make(a, 14))
		prow.add_child(_small(part[1]))


	# Sonar in buitenzicht: hetzelfde beeld als op de kast in de cabine, rechtsonder.
	_sonar = HudFader.new()
	_sonar.mode_key = "hud/sonar"
	_sonar.needs_content = true
	_sonar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_sonar.position = Vector2(-440, -338)
	_sonar.size = Vector2(416, 314)
	add_child(_sonar)
	var schip := PanelContainer.new()
	schip.theme_type_variation = &"HudChip"
	_sonar.add_child(schip)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 4)
	schip.add_child(scol)
	var sh := Label.new()
	sh.text = "SONAR"
	sh.add_theme_font_override("font", UiTheme.heading())
	sh.add_theme_font_size_override("font_size", 15)
	sh.add_theme_color_override("font_color", UiTheme.YELLOW)
	scol.add_child(sh)
	_sonar_view = TextureRect.new()
	_sonar_view.custom_minimum_size = Vector2(394, 257)
	_sonar_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sonar_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scol.add_child(_sonar_view)


	# Ertszak: klein kaartje linksonder, boven het draagkaartje; verschijnt bij elke verandering.
	_ore = HudFader.new()
	_ore.mode_key = "hud/prompts"
	_ore.hold = 3.0
	_ore.needs_content = true
	_ore.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ore.position = Vector2(28, -228)
	_ore.size = Vector2(300, 48)
	add_child(_ore)
	var ochip := PanelContainer.new()
	ochip.theme_type_variation = &"HudChip"
	_ore.add_child(ochip)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 10)
	ochip.add_child(orow)
	var oh := Label.new()
	oh.text = "ERTSZAK"
	oh.add_theme_font_override("font", UiTheme.heading())
	oh.add_theme_font_size_override("font_size", 15)
	oh.add_theme_color_override("font_color", UiTheme.YELLOW)
	orow.add_child(oh)
	_ore_label = Label.new()
	_ore_label.add_theme_font_override("font", UiTheme.body(800))
	_ore_label.add_theme_font_size_override("font_size", 18)
	orow.add_child(_ore_label)
	_ore_value = Label.new()
	_ore_value.add_theme_font_size_override("font_size", 16)
	_ore_value.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	orow.add_child(_ore_value)


func _build_left() -> void:
	_team = HudFader.new()
	_team.mode_key = "hud/team"
	_team.hold = 5.0
	_team.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_team.position = Vector2(24, -120)
	_team.size = Vector2(280, 240)
	add_child(_team)
	_team_rows = VBoxContainer.new()
	_team_rows.add_theme_constant_override("separation", 6)
	_team.add_child(_team_rows)

	_stats = Label.new()
	_stats.position = Vector2(16, 12)
	_stats.add_theme_font_size_override("font_size", 14)
	_stats.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.8))
	_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_stats.add_theme_constant_override("outline_size", 4)
	add_child(_stats)


func _build_overlays() -> void:
	# Vertrek van de Mol: groot, boven in beeld, met een schuivende waarschuwingsstrook.
	_banner = PanelContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-280, 128)
	_banner.custom_minimum_size = Vector2(560, 0)
	_banner.visible = false
	var bb := UiTheme.panel_box()
	bb.content_margin_top = 12
	bb.content_margin_bottom = 14
	_banner.add_theme_stylebox_override("panel", bb)
	add_child(_banner)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 8)
	_banner.add_child(bc)
	_banner_strip = HazardStrip.new(8.0)
	_banner_strip.speed = 40.0
	bc.add_child(_banner_strip)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	brow.add_theme_constant_override("separation", 18)
	bc.add_child(brow)
	_banner_title = Label.new()
	_banner_title.add_theme_font_override("font", UiTheme.heading())
	_banner_title.add_theme_font_size_override("font_size", 26)
	_banner_title.add_theme_color_override("font_color", UiTheme.YELLOW)
	brow.add_child(_banner_title)
	_banner_count = Label.new()
	_banner_count.add_theme_font_override("font", UiTheme.body(900))
	_banner_count.add_theme_font_size_override("font_size", 40)
	brow.add_child(_banner_count)

	# Eindoverzicht van een dienst.
	_result = PanelContainer.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_result.position = Vector2(-240, 150)
	_result.custom_minimum_size = Vector2(480, 0)
	_result.visible = false
	add_child(_result)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 10)
	_result.add_child(rc)
	var rt := Label.new()
	_result_title = rt
	rt.text = "DIENST AFGELOPEN"
	rt.theme_type_variation = &"Heading"
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(rt)
	rc.add_child(HazardStrip.new(6.0))
	_result_rows = VBoxContainer.new()
	_result_rows.add_theme_constant_override("separation", 6)
	rc.add_child(_result_rows)


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4)
	return l


# --- Meldingen ------------------------------------------------------------------------------

## Korte melding middenonder. kind: "info", "mol", "warn", "find".
func toast(text: String, kind := "info", seconds := 4.5) -> void:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HudChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icons/%s.svg" % {"info": "depth", "mol": "mol", "warn": "warning", "find": "bone"}.get(kind, "depth"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(26, 26)
	icon.modulate = {"warn": UiTheme.DANGER, "mol": UiTheme.YELLOW, "find": Color("#E8DCC0")}.get(kind, UiTheme.CREAM)
	row.add_child(icon)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.body(800))
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	_toasts.add_child(chip)
	# Hooguit 3 tegelijk. Meteen weghalen: queue_free alleen laat het kind nog staan, en dan liep
	# deze lus eindeloos (en het geheugen vol) bij de vierde melding kort na elkaar.
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	Sfx.ui("warn" if kind == "warn" else "toast", -4.0)
	chip.modulate.a = 0.0
	var tw := chip.create_tween() # sterft mee met de melding
	tw.tween_property(chip, "modulate:a", 1.0, 0.18)
	tw.tween_interval(seconds)
	tw.tween_property(chip, "modulate:a", 0.0, 0.6)
	tw.tween_callback(chip.queue_free)


## Stempel bij de landing (in plaats van een melding): groot, schuin, met een klap, en dan weg.
## Zoals een stempel op een vrachtbrief: de planeet, de concessie en de dienst.
func stamp(title: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-360, 150)
	box.custom_minimum_size = Vector2(720, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for pair in [[title, 64, UiTheme.YELLOW], [sub, 22, UiTheme.CREAM]]:
		var l := Label.new()
		l.text = pair[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", UiTheme.heading())
		l.add_theme_font_size_override("font_size", pair[1])
		l.add_theme_color_override("font_color", pair[2])
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
		l.add_theme_constant_override("outline_size", 10)
		box.add_child(l)
	box.pivot_offset = Vector2(360, 50)
	box.rotation = deg_to_rad(-4.0)
	box.scale = Vector2(1.8, 1.8)
	box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)


## Incidentrapport van de firma na een dienst (Company): wat verkocht werd, de bonus van de
## opdracht, de kosten (vervangrobots), de schade, bevingen, en de stand van het kwartaal.
func show_report(r: Dictionary) -> void:
	for c in _result_rows.get_children():
		c.queue_free()
	_result_title.text = "INCIDENTRAPPORT · DIENST %d" % int(r.get("shift_total", 0))
	var sold: Array = r.get("sold", [])
	var shown := 0
	for e: Array in sold:
		if shown >= 6:
			_result_row("… en nog %d" % (sold.size() - shown), "")
			break
		_result_row("%s (%d%%)" % [e[0], int(e[2])], UiTheme.euro(int(e[1])), UiTheme.CREAM)
		shown += 1
	if sold.is_empty():
		_result_row("Geen vondsten in het laadruim", UiTheme.euro(0), UiTheme.CREAM_DIM)
	if int(r.get("ore_units", 0)) > 0:
		_result_row("Erts (%d)" % int(r.ore_units), UiTheme.euro(int(r.ore_value)), UiTheme.CREAM)
	if int(r.get("bonus", 0)) != 0:
		_result_row("Opdracht %s (×%.2f)" % [r.get("contract", ""), float(r.get("factor", 1.0))], "+" + UiTheme.euro(int(r.bonus)), UiTheme.YELLOW)
	var robots := int(r.get("left_behind", 0)) + int(r.get("melted", 0))
	if robots > 0:
		_result_row("Vervangrobots (%d achter, %d gesmolten)" % [int(r.left_behind), int(r.melted)], UiTheme.euro(-int(r.costs)), UiTheme.DANGER)
	if int(r.get("damage", 0)) > 0:
		_result_row("Schade aan vondsten (verloren waarde)", UiTheme.euro(int(r.damage)), UiTheme.CREAM_DIM)
	if int(r.get("quakes", 0)) > 0:
		_result_row("Bevingen", str(int(r.quakes)), UiTheme.CREAM_DIM)
	_result_row("NETTO", UiTheme.euro(int(r.get("net", 0))), UiTheme.YELLOW if int(r.get("net", 0)) >= 0 else UiTheme.DANGER)
	var result: String = r.get("quarter_result", "")
	if result == "gehaald":
		_result_row("KWARTAAL %d GEHAALD" % int(r.quarter), UiTheme.euro(int(r.earned)) + " / " + UiTheme.euro(int(r.quota)), UiTheme.GOOD)
	elif result == "gemist":
		_result_row("KWARTAAL %d GEMIST (%s / %s) · boete" % [int(r.quarter), UiTheme.euro(int(r.earned)), UiTheme.euro(int(r.quota))],
				UiTheme.euro(-int(r.get("fine", 0))), UiTheme.DANGER)
	else:
		_result_row("Kwartaal %d · dienst %d/%d" % [int(r.quarter), int(r.shift), Tuning.get_i("company", "shifts", 3)], UiTheme.euro(int(r.earned)) + " / " + UiTheme.euro(int(r.quota)), UiTheme.CREAM)
	_result_row("Kas", UiTheme.euro(int(r.get("cash", 0))), UiTheme.YELLOW if int(r.get("cash", 0)) >= 0 else UiTheme.DANGER)
	_open_result(12.0)


## Eindoverzicht na de extractie (zonder schip; met het schip komt het incidentrapport).
func show_result(count: int, value: int, left_behind: int, ore_units := 0, ore_value := 0) -> void:
	for c in _result_rows.get_children():
		c.queue_free()
	_result_title.text = "DIENST AFGELOPEN"
	_result_row("Vondsten in het laadruim", str(count))
	_result_row("Waarde vondsten", "€%d" % value, UiTheme.YELLOW)
	if ore_units > 0:
		_result_row("Erts (%d)" % ore_units, "€%d" % ore_value, UiTheme.YELLOW)
	if left_behind > 0:
		_result_row("Achterblijvers (te voet boven)", str(left_behind), UiTheme.DANGER)
	_result_row("Brandstof", "bijgetankt")
	_open_result(7.0)


func _open_result(seconds: float) -> void:
	_result.visible = true
	_result.modulate.a = 0.0
	Sfx.ui("open")
	var tw := create_tween()
	tw.tween_property(_result, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_result, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void: _result.visible = false)


func _result_row(label_text: String, value_text: String, col := UiTheme.CREAM) -> void:
	var row := HBoxContainer.new()
	_result_rows.add_child(row)
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var v := Label.new()
	v.text = value_text
	v.add_theme_font_override("font", UiTheme.body(900))
	v.add_theme_font_size_override("font_size", 22)
	v.add_theme_color_override("font_color", col)
	row.add_child(v)


# --- Elke frame ----------------------------------------------------------------------------------

func update(player: Player, game: Game, terrain: TerrainAPI) -> void:
	visible = player != null
	if player == null or game == null or terrain == null:
		return
	var mol := game.mol
	if not _started:
		_started = true
		compass.poke(6.0) # bij de start: waar ben ik, waar staat de Mol
	_update_compass(player, mol, terrain)
	_update_hazard(player, game)
	_update_tools(player)
	_update_carry(player)
	_update_ore(player, game)
	_update_prompt(player, game, terrain)
	_update_pilot(player)
	_update_sonar(player, mol)
	_update_banner(mol, game)
	_update_team(player, game)
	_update_host()
	_update_stats(player, game, terrain)


func _update_hazard(player: Player, game: Game) -> void:
	var dist := INF
	if game.magma and game.magma.visible and not (game.ship and game.ship.contains(player.global_position)):
		dist = player.global_position.y - game.magma.level
	var frac := 0.0
	var phase := Unrest.Phase.CALM
	if game.unrest:
		frac = game.unrest.value / maxf(1.0, Tuning.get_f("unrest", "stage", 100.0))
		phase = game.unrest.phase
	hazard.set_state(dist, frac, phase)


func _update_compass(player: Player, mol: Mol, terrain: TerrainAPI) -> void:
	var p := player.global_position
	var fwd := -player.camera.global_basis.z
	compass.heading_deg = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	var depth := maxf(0.0, terrain.surface_height_at(p.x, p.z) - p.y)
	compass.set_depth(depth)
	compass.set_layer(terrain.layer_at(p))
	compass.mol_visible = mol != null and mol.body != null
	if compass.mol_visible:
		var to := mol.body.global_position - p
		compass.mol_bearing_deg = fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
		compass.mol_distance = Vector2(to.x, to.z).length()
		# De richting blijft in beeld zolang je de Mol niet ziet: buiten de Mol en ofwel ver weg,
		# ofwel niet voor je (meer dan 50° opzij), of als de Mol vertrekt.
		var rel := absf(wrapf(compass.mol_bearing_deg - compass.heading_deg, -180.0, 180.0))
		compass.active = not mol.contains_point(p) and (compass.mol_distance > 25.0 or rel > 50.0
				or mol.mode == Mol.Mode.COUNTDOWN)


func _update_tools(player: Player) -> void:
	var idx := player.tools.find(player.active_tool)
	if idx != _last_tool:
		_last_tool = idx
		_hotbar.poke()
	_hotbar.blocked = player.seated or player.carry.item != null
	for i in _slots.size():
		var on := i == idx
		var box := StyleBoxFlat.new()
		box.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.78) if not on else Color(UiTheme.ANTHRACITE, 0.92)
		box.set_corner_radius_all(10)
		box.set_border_width_all(3 if on else 2)
		box.border_color = UiTheme.YELLOW if on else Color(UiTheme.STEEL, 0.35)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		_slots[i].add_theme_stylebox_override("panel", box)
		(_slots[i].get_child(0).get_child(0) as TextureRect).modulate = UiTheme.YELLOW if on else Color(UiTheme.CREAM, 0.55)
	_tool_name.text = TOOLS[idx][1] if idx >= 0 else ""


func _update_carry(player: Player) -> void:
	var it: FindItem = player.carry.item
	_carry.active = it != null
	if it != _last_carry:
		_last_carry = it
		if it:
			Sfx.ui("pickup", -2.0)
	if it == null:
		return
	_carry_name.text = it.display_name()
	_carry_value.text = "€%d" % it.value()
	var others := it.carriers.size() - 1
	_carry_note.text = "samen gedragen" if others > 0 else ("zwaar: samen dragen gaat sneller" if it.mass >= 10.0 else "%d kg" % int(round(it.mass)))
	_carry_bar.anchor_right = clampf(it.condition, 0.0, 1.0)
	_carry_bar.offset_right = 0
	_carry_bar.color = UiTheme.GOOD if it.condition > 0.66 else (UiTheme.AMBER if it.condition > 0.4 else UiTheme.DANGER)


func _update_prompt(player: Player, game: Game, terrain: TerrainAPI) -> void:
	var action := ""
	var text := ""
	var sub := ""
	var state := HudCrosshair.State.NONE
	var aim: Pickaxe.Aim = player.active_tool.aim
	crosshair.heat = 0.0
	if player.active_tool == player.drill and not player.seated:
		var d := player.drill
		crosshair.heat = clampf(d.heat / Tuning.get_f("drill", "heat_max", 5.5), 0.0, 1.0)
		crosshair.overheated = d.overheated
		if d.overheated:
			sub = "Oververhit: even laten afkoelen"
	var knob := player.aimed_interactable()
	if knob:
		state = HudCrosshair.State.USE
		var parts := knob.hint.split(": ", true, 1)
		action = "interact"
		text = parts[1] if parts.size() == 2 else knob.hint
		if not knob.hint.begins_with("E:"):
			action = ""
	elif player.seated:
		pass
	elif player.carry.item:
		pass # het draagkaartje linksonder toont de toetsen
	elif game.mol and game.mol.in_cockpit(player.global_position) and game.mol.pilot == 0:
		action = "interact"
		text = "De Mol besturen"
		state = HudCrosshair.State.USE
	else:
		var cam := player.camera
		var hit := terrain.raycast(cam.global_position, cam.global_position - cam.global_basis.z * 3.5,
				Layers.TERRAIN | Layers.CRUST | Layers.LOOT | Layers.LIFT)
		if not hit.is_empty() and hit.collider is Crust:
			var c: Crust = hit.collider
			state = HudCrosshair.State.CRUST
			crosshair.crust_hp = c.hp
			crosshair.crust_max = c.max_hp
			text = "Korst: uitbikken"
			sub = "houweel is veilig · boor is sneller, maar schaadt de vondst"
		elif not hit.is_empty() and hit.collider is OreCluster:
			var o: OreCluster = hit.collider
			state = HudCrosshair.State.CRUST
			crosshair.crust_hp = o.hp
			crosshair.crust_max = o.max_hp
			text = "Erts: %s" % OreKinds.NAMES[o.kind]
			sub = "€%d per stuk · %d over · houweel of boor" % [OreKinds.VALUES[o.kind], int(ceil(o.hp))]
		elif not hit.is_empty() and hit.collider is FindItem:
			var f: FindItem = hit.collider
			state = HudCrosshair.State.USE if f.freed else HudCrosshair.State.NONE
			if f.freed and f.carriers.size() < 2:
				action = "interact"
				text = "Oppakken: %s" % f.display_name()
			else:
				text = f.display_name()
			sub = "€%d · gaaf %d%%" % [f.value(), int(round(f.condition * 100))]
		elif aim == Pickaxe.Aim.TOO_HARD:
			state = HudCrosshair.State.HARD
			text = player.active_tool.hint_too_hard()
		elif aim == Pickaxe.Aim.DIGGABLE:
			state = HudCrosshair.State.DIG
	crosshair.state = state
	_set_prompt(action, text, sub)


func _set_prompt(action: String, text: String, sub: String) -> void:
	var has := text != "" or sub != ""
	_prompt.active = has
	if not has:
		return
	_prompt_box.visible = text != ""
	_prompt_text.text = text
	_prompt_sub.text = sub
	_prompt_sub.visible = sub != ""
	# Eén toetsblokje per actie, hergebruikt.
	for c in _prompt_caps.get_children():
		c.visible = (c as KeyCap).action == action
	if action != "" and not _prompt_caps.get_children().any(func(c: Node) -> bool: return (c as KeyCap).action == action):
		_prompt_caps.add_child(KeyCap.make(action, 16))
	_prompt_caps.visible = action != ""


func _update_ore(player: Player, game: Game) -> void:
	var ores: OreField = game.ores
	if ores == null:
		return
	if not _ore_connected:
		_ore_connected = true
		ores.bag_full.connect(func() -> void:
			toast("Ertszak vol: stort hem in de trechter van de Mol", "warn"))
	var bag := ores.bag_of(player.peer_id)
	var n := OreField.units(bag)
	_ore.active = n > 0 and int(Settings.get_value("hud/prompts")) == Settings.HUD_ALWAYS
	if n == _ore_shown:
		return
	_ore_shown = n
	var cap := Tuning.get_i("ore", "bag_capacity", 40)
	_ore_label.text = "%d/%d" % [n, cap]
	_ore_label.add_theme_color_override("font_color", UiTheme.DANGER if n >= cap else UiTheme.CREAM)
	_ore_value.text = "€%d" % OreField.value(bag)
	if n > 0:
		_ore.poke()


func _update_pilot(player: Player) -> void:
	if player.seated and not _was_seated:
		_pilot.poke()
	_was_seated = player.seated
	_pilot.blocked = not player.seated
	_pilot.active = player.seated and int(Settings.get_value("hud/prompts")) == Settings.HUD_ALWAYS


func _update_sonar(player: Player, mol: Mol) -> void:
	var show := mol != null and player.seated and player.chase.current
	_sonar.active = show
	_sonar.blocked = not show
	if show and _sonar_view.texture == null:
		_sonar_view.texture = mol.visual.sonar_screen.texture()


func _update_banner(mol: Mol, game: Game) -> void:
	if mol == null:
		return
	if mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.DROP_COUNTDOWN]:
		# Wie zit er al in? Zo weet de ploeg op wie ze wacht (onderzoek drop-en-ophalen: "je zit erin").
		var total := 0
		var inside := 0
		for pl: Player in game.players.get_children():
			total += 1
			if pl.seated or mol.contains_point(pl.global_position):
				inside += 1
		_banner.visible = true
		_banner_title.text = "%s · IN DE MOL %d/%d" % ["DE MOL VERTREKT" if mol.mode == Mol.Mode.COUNTDOWN else "DROP", inside, total]
		_banner_count.text = "%d" % int(ceil(mol.countdown))
		_banner_count.visible = true
	elif mol.mode == Mol.Mode.EXTRACTING:
		_banner.visible = true
		_banner_title.text = "DE MOL RIJDT NAAR BOVEN"
		_banner_count.visible = false
	else:
		_banner.visible = false


func _update_team(player: Player, game: Game) -> void:
	var others: Array = []
	for pl: Player in game.players.get_children():
		if pl != player and not pl.is_queued_for_deletion():
			others.append(pl)
	if others.size() != _last_team:
		_last_team = others.size()
		_team.poke()
		for c in _team_rows.get_children():
			c.queue_free()
		for pl: Player in others:
			var chip := PanelContainer.new()
			chip.theme_type_variation = &"HudChip"
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			chip.add_child(row)
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(14, 14)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.color = pl.color
			row.add_child(dot)
			var name := Label.new()
			name.text = "Speler %d" % (game.players.get_children().find(pl) + 1)
			name.add_theme_font_override("font", UiTheme.body(800))
			name.add_theme_font_size_override("font_size", 16)
			row.add_child(name)
			var where := Label.new()
			where.name = "Where"
			where.add_theme_font_size_override("font_size", 15)
			where.add_theme_color_override("font_color", UiTheme.CREAM_DIM)
			row.add_child(where)
			chip.set_meta("player", pl)
			_team_rows.add_child(chip)
	for chip in _team_rows.get_children():
		var obj: Variant = chip.get_meta("player")
		if not is_instance_valid(obj):
			_last_team = -1 # speler weg: de lijst wordt de volgende frame opnieuw opgebouwd
			continue
		var pl := obj as Player
		var where: Label = chip.find_child("Where", true, false)
		where.text = "in de Mol" if game.mol and game.mol.contains_point(pl.global_position) else "%d m" % int(player.global_position.distance_to(pl.global_position))


func _update_host() -> void:
	if Net.mode != Net.Mode.HOST:
		_host_chip.active = false
		return
	if Settings.get_b("interface/hide_ip"):
		_host_label.text = "HOST  ·  IP verborgen"
	else:
		_host_label.text = "HOST  ·  IP %s" % ", ".join(StartMenu.local_ips())
	if _last_team == 0:
		_host_chip.active = true # tot er iemand meedoet, blijft je IP in beeld
	else:
		_host_chip.active = false


func _update_stats(player: Player, game: Game, terrain: TerrainAPI) -> void:
	_stats.visible = int(Settings.get_value("hud/stats")) == Settings.HUD_ALWAYS
	if not _stats.visible:
		return
	var net: String = ["solo", "host", "client"][Net.mode]
	var p := player.global_position
	_stats.text = "%d fps  ·  %s  ·  %d speler(s)\npos %.1f, %.1f, %.1f%s" % [
		Engine.get_frames_per_second(), net, game.players.get_child_count(), p.x, p.y, p.z,
		"  ·  VLIEGEN" if player.flying else ""]
