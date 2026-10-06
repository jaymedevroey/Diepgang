class_name Hud
extends Control
## De HUD (docs/research/hud-menu.md §4): weinig vast in beeld, alles dynamisch waar het kan.
##   midden        vizier (stip + ring) met de prompt eronder
##   boven midden  diepte, laag en kompas met de richting naar de Mol; de gevaren eronder
##   onder midden  gereedschap (verschijnt bij wisselen), daarboven de meldingen
##   linksonder    wat je draagt
##   links         de ploeg (bij meerdere spelers)
##   rechts        het incidentrapport na een dienst (een formulier van de firma)
##   in de Mol     besturing voor de piloot; bij vertrek een grote aftelling bovenaan
##   rechtsonder   in buitenzicht: het sonarbeeld uit de cabine
##   hele scherm   een rode rand bij gevaar (HudAlarm): beving, alarm, de laatste tellen
## In het schip (De Ekster): geen diepte, laag of gereedschap, maar waar je bent, wat je nu moet
## doen (opdracht kiezen, wachten, naar de Mol, de hendel) en een doel op de strook; in de Mol een
## merkteken op de VERTREK-hendel. Tijdens een filmbeeld (Player.cinematic, of een andere camera
## dan die van de speler) geen vizier, prompt, strook of gereedschap.
## Tekst: minstens 18 px op 1080p (hud-menu.md §4.9, ui-05); ui_test controleert elke Label.
## main.gd roept elke frame update() aan.

const TOOLS := [["pickaxe", "PICKAXE", "tool_1"], ["drill", "DRILL", "tool_2"]]
## Kleinste lettergrootte in de HUD (1080p).
const MIN_FONT := 18
## Toetsblokjes in de HUD.
const KEY_FONT := 20
## Icoon en kleur per familie van vondsten (FindKinds.Family: skelet, reliek, metaal, rommel, kristal).
const FAMILY_ICONS := ["bone", "relic", "coin", "junk", "crystal"]
const FAMILY_TINTS := [Color("#E8DCC0"), Color("#C98A4B"), Color("#F0C24B"), Color("#C9C2B4"), Color("#4FE3F0")]
## Soorten meldingen: [icoon, kleur van het icoon en de rand]. De bron kiest de soort (ui-04):
##   info      gewone melding            contract  een opdracht gekozen (niet voor wie hem net koos)
##   mol       iets van de Mol           find      een vondst
##   warn      waarschuwing (rood)       alarm     gevaar nu: groot, rood, met een rand rond het scherm
const TOAST_KINDS := {
	"info": ["info", UiTheme.CREAM],
	"contract": ["terminal", UiTheme.YELLOW],
	"mol": ["mol", UiTheme.YELLOW],
	"find": ["bone", Color("#E8DCC0")],
	"warn": ["warning", UiTheme.DANGER],
	"alarm": ["warning", UiTheme.CREAM],
}
## Inkt op het papier van het rapport.
const INK := Color("#23262B")
const INK_DIM := Color("#5C5A55")
const INK_RED := Color("#B3260B")
const INK_GREEN := Color("#2E6B1F")
const PAPER := Color("#EDE5D6")

var main: Node
var crosshair: HudCrosshair
var compass: HudCompass
var hazard: HudHazard
var alarm: HudAlarm
## Neergaan en redden (F2): de staat van je robot, neer/strompelend/drone, ploegmaten die neerliggen.
var rescue_hud: HudRescue
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
var _carry_icon: TextureRect
var _carry_name: Label
var _carry_value: Label
var _carry_bar: ColorRect
var _carry_bar_bg: ColorRect
var _carry_pct: Label
var _carry_note: Label
var _carry_cond_label: Label # "CONDITION", of "TIME LEFT" bij een neergegane ploegmaat
var _toasts: VBoxContainer
var _banner: PanelContainer
var _banner_title: Label
var _banner_count: Label
var _banner_sub: Label
var _banner_strip: HazardStrip
var _banner_strip2: HazardStrip
var _banner_shown := -1
var _result: Control
var _result_title: Label
var _result_meta: Label
var _result_rows: VBoxContainer
var _result_stamp: InkStamp
var _team: HudFader
var _team_rows: VBoxContainer
var _pilot: HudFader
var _pilot_box: CenterContainer
var _pilot_chip: PanelContainer
var _sonar: HudFader
var _sonar_chip: PanelContainer
var _sonar_view: TextureRect
var _stats: Label
var _host_chip: HudFader
var _host_label: Label
var _last_tool := -1
var _last_team := -1
var _was_seated := false
var _last_carry: Object = null
var _started := false
var objective: HudObjective
var _marker: HudMarker
var _result_tween: Tween
var _result_closing := false
var _was_loading := false
## Waar de speler deze frame op mikt (knop, hendel), of null.
var _aimed: Interactable
## Deze frame: staat de speler in het schip, in de Mol, en is de wereld-HUD weg (filmbeeld)?
var _in_hub := false
var _in_mol := false
var _world_hidden := false
var _own_cam := true
## Vorige toestand van de Mol (voor overgangen, zoals het begin van het aftellen).
var _last_mode := -1
## Tijdens het drop-aftellen voor wie in de Mol zit: enkel de aftelling (en waarschuwingen).
var _countdown_focus := false
## Dit vertrek van de Mol is een noodophaling (er kwam een alarm bij het begin van het aftellen).
var _emergency := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alarm = HudAlarm.new()
	add_child(alarm)
	_build_center()
	_build_top()
	_build_bottom()
	_build_left()
	_build_overlays()
	rescue_hud = HudRescue.new()
	rescue_hud.name = "Rescue"
	add_child(rescue_hud)


# --- Opbouw -----------------------------------------------------------------------------------

## Een HUD-label met een omlijning (leesbaar op licht en op donker).
static func _hud_label(size: int, font: Font = null, color := UiTheme.CREAM) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", maxi(size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _build_center() -> void:
	var center := Control.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	crosshair = HudCrosshair.new()
	crosshair.position = -crosshair.custom_minimum_size / 2.0
	center.add_child(crosshair)

	# De prompt staat een eind onder het vizier, zodat hij het ding waar je op mikt (een vondst op
	# armlengte is ±150 px hoog) niet bedekt (ui-19).
	_prompt = HudFader.new()
	_prompt.mode_key = "hud/prompts"
	_prompt.needs_content = true
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.position = Vector2(-340, PROMPT_Y)
	_prompt.size = Vector2(680, 100)
	center.add_child(_prompt)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 4)
	col.size = Vector2(680, 100)
	_prompt.add_child(col)
	var line := CenterContainer.new()
	col.add_child(line)
	_prompt_box = PanelContainer.new()
	_prompt_box.theme_type_variation = &"HudChip"
	line.add_child(_prompt_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_prompt_box.add_child(row)
	_prompt_caps = HBoxContainer.new()
	_prompt_caps.add_theme_constant_override("separation", 4)
	row.add_child(_prompt_caps)
	_prompt_text = Label.new()
	_prompt_text.add_theme_font_override("font", UiTheme.body(800))
	_prompt_text.add_theme_font_size_override("font_size", 21)
	row.add_child(_prompt_text)
	_prompt_sub = _hud_label(MIN_FONT, UiTheme.body(700), Color("#D2CABB"))
	_prompt_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_prompt_sub)


## Hoe ver de prompt onder het vizier staat (px op 1080p).
const PROMPT_Y := 128.0


func _build_top() -> void:
	compass = HudCompass.new()
	compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-HudCompass.WIDTH / 2.0, 18)
	add_child(compass)
	hazard = HudHazard.new()
	hazard.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hazard.position = Vector2(-HudHazard.WIDTH / 2.0, 112)
	add_child(hazard)
	# Enkel in het schip (waar de onrust- en magmameter niet staat): wat je nu moet doen.
	objective = HudObjective.new()
	objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	objective.position = Vector2(-HudObjective.WIDTH / 2.0, 108)
	add_child(objective)
	_marker = HudMarker.new()
	add_child(_marker)

	_host_chip = HudFader.new()
	_host_chip.hold = 8.0
	_host_chip.needs_content = true
	_host_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_host_chip.position = Vector2(-380, 18)
	_host_chip.size = Vector2(362, 44)
	add_child(_host_chip)
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"HudChip"
	chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_host_chip.add_child(chip)
	_host_label = Label.new()
	_host_label.add_theme_font_size_override("font_size", MIN_FONT)
	chip.add_child(_host_label)


func _build_bottom() -> void:
	# Gereedschap: twee vakjes onderaan in het midden, met de naam erboven bij het wisselen.
	_hotbar = HudFader.new()
	_hotbar.mode_key = "hud/tools"
	_hotbar.hold = 2.5
	_hotbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.position = Vector2(-170, -158)
	_hotbar.size = Vector2(340, 140)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	var col := VBoxContainer.new()
	col.size = Vector2(340, 140)
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 6)
	_hotbar.add_child(col)
	_tool_name = _hud_label(22, UiTheme.heading(), UiTheme.YELLOW)
	_tool_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		var cap := KeyCap.make(t[2], MIN_FONT)
		cap.position = Vector2(-22, -22) # linksboven over de rand van het vakje
		inner.add_child(cap)
		_slots.append(slot)
	_tool_hint = HBoxContainer.new()
	_tool_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_tool_hint.add_theme_constant_override("separation", 6)
	col.add_child(_tool_hint)
	_tool_hint.add_child(KeyCap.make("dig", MIN_FONT))
	_tool_hint.add_child(_small("Dig (hold)"))

	# Meldingen: boven het gereedschap, nieuwste onderaan.
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.position = Vector2(-380, -360)
	_toasts.size = Vector2(760, 196)
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)

	# Wat je draagt: linksonder.
	_carry = HudFader.new()
	_carry.mode_key = "hud/prompts"
	_carry.needs_content = true
	_carry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_carry.position = Vector2(28, -196)
	_carry.size = Vector2(420, 176)
	add_child(_carry)
	var card := PanelContainer.new()
	card.theme_type_variation = &"HudChip"
	card.custom_minimum_size = Vector2(400, 0)
	_carry.add_child(card)
	var cc := VBoxContainer.new()
	cc.add_theme_constant_override("separation", 6)
	card.add_child(cc)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	cc.add_child(top)
	# Een icoon per soort vondst (bot, reliek, munt, rommel, kristal), niet altijd een bot (ui-09).
	_carry_icon = TextureRect.new()
	_carry_icon.texture = preload("res://assets/ui/icons/bone.svg")
	_carry_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carry_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_carry_icon.custom_minimum_size = Vector2(40, 40)
	_carry_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_carry_icon)
	var tc := VBoxContainer.new()
	tc.add_theme_constant_override("separation", -2)
	tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tc)
	_carry_name = Label.new()
	_carry_name.add_theme_font_override("font", UiTheme.body(900))
	_carry_name.add_theme_font_size_override("font_size", 21)
	tc.add_child(_carry_name)
	_carry_note = Label.new()
	_carry_note.add_theme_font_size_override("font_size", MIN_FONT)
	_carry_note.add_theme_color_override("font_color", Color("#C2BAAC"))
	tc.add_child(_carry_note)
	_carry_value = Label.new()
	_carry_value.add_theme_font_override("font", UiTheme.body(900))
	_carry_value.add_theme_font_size_override("font_size", 26)
	_carry_value.add_theme_color_override("font_color", UiTheme.YELLOW)
	top.add_child(_carry_value)
	# Gaafheid: een label, een balk in de kleuren van de huisstijl, en het percentage.
	var cond := HBoxContainer.new()
	cond.add_theme_constant_override("separation", 10)
	cc.add_child(cond)
	var cl := Label.new()
	_carry_cond_label = cl
	cl.text = "CONDITION"
	cl.add_theme_font_override("font", UiTheme.heading())
	cl.add_theme_font_size_override("font_size", MIN_FONT)
	cl.add_theme_color_override("font_color", Color("#C2BAAC"))
	cond.add_child(cl)
	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 12)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cond.add_child(bar_wrap)
	_carry_bar_bg = ColorRect.new()
	_carry_bar_bg.color = Color(0, 0, 0, 0.5)
	_carry_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(_carry_bar_bg)
	_carry_bar = ColorRect.new()
	_carry_bar.color = UiTheme.YELLOW
	_carry_bar.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	bar_wrap.add_child(_carry_bar)
	_carry_pct = Label.new()
	_carry_pct.add_theme_font_override("font", UiTheme.body(900))
	_carry_pct.add_theme_font_size_override("font_size", 20)
	_carry_pct.custom_minimum_size.x = 56
	_carry_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cond.add_child(_carry_pct)
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	cc.add_child(keys)
	keys.add_child(KeyCap.make("interact", MIN_FONT))
	keys.add_child(_small("Put down"))
	var gap := Control.new()
	gap.custom_minimum_size.x = 12
	keys.add_child(gap)
	keys.add_child(KeyCap.make("dig", MIN_FONT))
	keys.add_child(_small("Throw"))

	# Besturing van de Mol (piloot): onderaan, verschijnt bij het instappen.
	_pilot = HudFader.new()
	_pilot.mode_key = "hud/prompts"
	_pilot.hold = 9.0
	_pilot.needs_content = true
	_pilot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_pilot.position = Vector2(-760, -98)
	_pilot.size = Vector2(1520, 72)
	add_child(_pilot)
	var pc := CenterContainer.new()
	pc.size = Vector2(1520, 72)
	_pilot.add_child(pc)
	_pilot_box = pc
	var pchip := PanelContainer.new()
	pchip.theme_type_variation = &"HudChip"
	pc.add_child(pchip)
	_pilot_chip = pchip
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	pchip.add_child(prow)
	var ph := Label.new()
	ph.text = "THE MOLE"
	ph.add_theme_font_override("font", UiTheme.heading())
	ph.add_theme_font_size_override("font_size", 20)
	ph.add_theme_color_override("font_color", UiTheme.YELLOW)
	prow.add_child(ph)
	for part: Array in [[["move_forward", "move_back"], "Throttle"], [["move_left", "move_right"], "Steer"],
			[["jump", "crouch"], "Nose"], [["mol_view"], "Outside view"], [["sonar_ping"], "Ping"], [["horn"], "Horn"],
			[["interact"], "Get out"]]:
		var sep := Control.new()
		sep.custom_minimum_size.x = 12
		prow.add_child(sep)
		for a: String in part[0]:
			prow.add_child(KeyCap.make(a, MIN_FONT))
		prow.add_child(_small(part[1]))

	# Sonar in buitenzicht: hetzelfde beeld als op de kast in de cabine, rechtsonder. Groot genoeg om
	# ook op 720p de blips en het bereik te lezen (ui-05).
	_sonar = HudFader.new()
	_sonar.mode_key = "hud/sonar"
	_sonar.needs_content = true
	_sonar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_sonar.position = Vector2(-624, -458)
	_sonar.size = Vector2(600, 434)
	add_child(_sonar)
	var schip := PanelContainer.new()
	schip.theme_type_variation = &"HudChip"
	_sonar.add_child(schip)
	_sonar_chip = schip
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 4)
	schip.add_child(scol)
	var sh := Label.new()
	sh.text = "SONAR"
	sh.add_theme_font_override("font", UiTheme.heading())
	sh.add_theme_font_size_override("font_size", MIN_FONT)
	sh.add_theme_color_override("font_color", UiTheme.YELLOW)
	scol.add_child(sh)
	_sonar_view = TextureRect.new()
	_sonar_view.custom_minimum_size = Vector2(576, 376)
	_sonar_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sonar_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scol.add_child(_sonar_view)

	# Ertszak: klein kaartje linksonder, boven het draagkaartje; verschijnt bij elke verandering.
	_ore = HudFader.new()
	_ore.mode_key = "hud/prompts"
	_ore.hold = 3.0
	_ore.needs_content = true
	_ore.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ore.position = Vector2(28, -258)
	_ore.size = Vector2(340, 52)
	add_child(_ore)
	var ochip := PanelContainer.new()
	ochip.theme_type_variation = &"HudChip"
	_ore.add_child(ochip)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 10)
	ochip.add_child(orow)
	var oh := Label.new()
	oh.text = "ORE BAG"
	oh.add_theme_font_override("font", UiTheme.heading())
	oh.add_theme_font_size_override("font_size", MIN_FONT)
	oh.add_theme_color_override("font_color", UiTheme.YELLOW)
	orow.add_child(oh)
	_ore_label = Label.new()
	_ore_label.add_theme_font_override("font", UiTheme.body(800))
	_ore_label.add_theme_font_size_override("font_size", 20)
	orow.add_child(_ore_label)
	_ore_value = Label.new()
	_ore_value.add_theme_font_size_override("font_size", MIN_FONT)
	_ore_value.add_theme_color_override("font_color", Color("#C2BAAC"))
	orow.add_child(_ore_value)


func _build_left() -> void:
	_team = HudFader.new()
	_team.mode_key = "hud/team"
	_team.hold = 5.0
	_team.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_team.position = Vector2(24, -120)
	_team.size = Vector2(320, 240)
	add_child(_team)
	_team_rows = VBoxContainer.new()
	_team_rows.add_theme_constant_override("separation", 6)
	_team.add_child(_team_rows)

	_stats = _hud_label(MIN_FONT, null, Color(UiTheme.CREAM, 0.85))
	_stats.position = Vector2(16, 12)
	add_child(_stats)


func _build_overlays() -> void:
	# Vertrek van de Mol: een grote aftelling bovenaan, het hoogtepunt van de lus (ui-11). Het getal
	# is het grootste ding op het scherm en klopt bij elke tel; de laatste drie tellen rood, met een
	# rand rond het scherm.
	_banner = PanelContainer.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-BANNER_W / 2.0, 112)
	_banner.custom_minimum_size = Vector2(BANNER_W, 0)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 0)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(bc)
	_banner_strip = HazardStrip.new(8.0)
	_banner_strip.speed = 40.0
	bc.add_child(_banner_strip)
	_banner_title = _hud_label(28, UiTheme.heading(), UiTheme.CREAM)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_top", 10)
	tm.add_child(_banner_title)
	bc.add_child(tm)
	_banner_count = _hud_label(124, UiTheme.heading(), UiTheme.YELLOW)
	_banner_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_count.add_theme_constant_override("outline_size", 18)
	_banner_count.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))
	# Bungee heeft veel lucht onder de cijfers: die halen we weg, het getal staat zo tussen de strepen.
	var cm := MarginContainer.new()
	cm.add_theme_constant_override("margin_top", -10)
	cm.add_theme_constant_override("margin_bottom", -26)
	cm.add_child(_banner_count)
	bc.add_child(cm)
	_banner_sub = _hud_label(22, UiTheme.body(800), UiTheme.CREAM)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_bottom", 10)
	sm.add_child(_banner_sub)
	bc.add_child(sm)
	_banner_strip2 = HazardStrip.new(8.0)
	_banner_strip2.speed = -40.0
	bc.add_child(_banner_strip2)

	# Incidentrapport na een dienst: een formulier van de firma op papier, rechts in beeld (niet
	# midden voor je neus, en het doel blijft staan) (ui-08).
	# `_result` is de houder (papier en stempel), zo groot als het papier.
	_result = Control.new()
	_result.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_result.position = Vector2(-REPORT_W - 48, 176)
	_result.visible = false
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.rotation = deg_to_rad(-1.2)
	add_child(_result)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(REPORT_W, 0)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.resized.connect(func() -> void: _result.size = sheet.size)
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.set_corner_radius_all(3)
	paper.content_margin_left = 26
	paper.content_margin_right = 26
	paper.content_margin_top = 20
	paper.content_margin_bottom = 20
	paper.shadow_color = Color(0, 0, 0, 0.5)
	paper.shadow_size = 16
	paper.shadow_offset = Vector2(4, 8)
	sheet.add_theme_stylebox_override("panel", paper)
	_result.add_child(sheet)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 8)
	sheet.add_child(rc)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	rc.add_child(head)
	var logo := PanelContainer.new()
	var lb := StyleBoxFlat.new()
	lb.bg_color = UiTheme.YELLOW
	lb.set_corner_radius_all(3)
	lb.content_margin_left = 8
	lb.content_margin_right = 8
	lb.content_margin_top = 0
	lb.content_margin_bottom = 2
	logo.add_theme_stylebox_override("panel", lb)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(logo)
	var ll := Label.new()
	ll.text = "DIG"
	ll.add_theme_font_override("font", UiTheme.heading())
	ll.add_theme_font_size_override("font_size", 26)
	ll.add_theme_color_override("font_color", INK)
	ll.add_theme_constant_override("shadow_offset_y", 0)
	logo.add_child(ll)
	_result_title = Label.new()
	_result_title.text = "INCIDENT REPORT"
	_result_title.add_theme_font_override("font", UiTheme.heading())
	_result_title.add_theme_font_size_override("font_size", 26)
	_result_title.add_theme_color_override("font_color", INK)
	_result_title.add_theme_constant_override("shadow_offset_y", 0)
	_result_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_result_title)
	_result_meta = _paper_label("", MIN_FONT, INK_DIM, 700)
	rc.add_child(_result_meta)
	var strip := HazardStrip.new(6.0)
	strip.color_b = INK
	rc.add_child(strip)
	_result_rows = VBoxContainer.new()
	_result_rows.add_theme_constant_override("separation", 4)
	rc.add_child(_result_rows)
	var sign := _paper_label("Signed: head office (automated)", MIN_FONT, INK_DIM, 600)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rc.add_child(sign)
	# Onderaan plaats voor de stempel (die ligt dan over niets dat je moet lezen).
	var stamp_room := Control.new()
	stamp_room.custom_minimum_size = Vector2(0, 50)
	rc.add_child(stamp_room)
	# De stempel ligt schuin onderaan het papier.
	_result_stamp = InkStamp.make("APPROVED", INK_GREEN, 30, -11.0)
	_result.add_child(_result_stamp)


const BANNER_W := 560.0
const REPORT_W := 520.0


func _small(text: String) -> Label:
	var l := _hud_label(MIN_FONT, null, UiTheme.CREAM)
	l.text = text
	return l


## Tekst op het papier van het rapport (donkere inkt, geen schaduw of omlijning).
func _paper_label(text: String, size: int, color: Color, weight := 700) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.body(weight))
	l.add_theme_font_size_override("font_size", maxi(size, MIN_FONT))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


# --- Meldingen ------------------------------------------------------------------------------

## Korte melding middenonder. `kind`: zie TOAST_KINDS (info, contract, mol, find, warn, alarm). De
## bron van de melding kiest de soort; de HUD kijkt nooit naar de zin zelf (ui-04).
func toast(text: String, kind := "info", seconds := 4.5) -> void:
	if not TOAST_KINDS.has(kind):
		kind = "info"
	# Toetsen in een melding staan als {actie} en worden hier ingevuld, met de toetsen van wie het leest
	# (een melding van de host kan zo ook "{scan}" bevatten, ui2-09).
	text = Settings.fill_keys(text)
	var urgent := kind in ["warn", "alarm"]
	# Tijdens het drop-aftellen in de Mol zegt de aftelling alles: enkel waarschuwingen komen erdoor.
	if _countdown_focus and not urgent:
		return
	# Wie net zelf een opdracht koos, zag dat al aan de terminal: geen derde bevestiging (ui-03).
	if kind == "contract" and main and main.get("_terminal") and (main._terminal as Control).visible:
		return
	if kind == "alarm":
		_on_alarm()
	# Dezelfde melding staat er al: niet nog eens (de oude blijft gewoon staan).
	for c in _toasts.get_children():
		if c.get_meta("text", "") == text and not c.is_queued_for_deletion():
			return
	var chip := PanelContainer.new()
	chip.set_meta("text", text)
	chip.set_meta("kind", kind)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", _toast_box(kind))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	chip.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/ui/icons/%s.svg" % TOAST_KINDS[kind][0])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(34, 34) if kind == "alarm" else Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = TOAST_KINDS[kind][1]
	row.add_child(icon)
	if kind == "alarm":
		var tag := Label.new()
		tag.text = "ALERT"
		tag.add_theme_font_override("font", UiTheme.heading())
		tag.add_theme_font_size_override("font_size", 24)
		tag.add_theme_color_override("font_color", UiTheme.YELLOW)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)
	var l := Label.new()
	l.text = UiTheme.cap(text)
	l.add_theme_font_override("font", UiTheme.body(900 if kind == "alarm" else 800))
	l.add_theme_font_size_override("font_size", 25 if kind == "alarm" else (20 if kind == "warn" else 19))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	_toasts.add_child(chip)
	# Hooguit 3 tegelijk. Meteen weghalen: queue_free alleen laat het kind nog staan, en dan liep
	# deze lus eindeloos (en het geheugen vol) bij de vierde melding kort na elkaar.
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	Sfx.ui("warn" if urgent else "toast", -4.0)
	chip.modulate.a = 0.0
	var tw := chip.create_tween() # sterft mee met de melding
	if kind == "alarm":
		# Groot binnenkomen en drie keer oplichten, en langer blijven staan.
		seconds = maxf(seconds, 7.0)
		chip.scale = Vector2(1.3, 1.3)
		tw.tween_property(chip, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(chip, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in 3:
			tw.tween_property(chip, "modulate", Color(1.5, 1.35, 1.3, 1.0), 0.09)
			tw.tween_property(chip, "modulate", Color(1, 1, 1, 1), 0.16)
		chip.resized.connect(func() -> void: chip.pivot_offset = chip.size / 2.0)
	else:
		tw.tween_property(chip, "modulate:a", 1.0, 0.18)
	tw.tween_interval(seconds)
	tw.tween_property(chip, "modulate:a", 0.0, 0.6)
	tw.tween_callback(chip.queue_free)


## Achtergrond van een melding: donker met een gekleurde rand links (de huisstijl, ui-09); een alarm
## donkerrood met een rode rand rondom.
func _toast_box(kind: String) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(5)
	b.content_margin_left = 14
	b.content_margin_right = 16
	b.content_margin_top = 7
	b.content_margin_bottom = 8
	if kind == "alarm":
		b.bg_color = Color(0.34, 0.04, 0.0, 0.94)
		b.border_color = UiTheme.DANGER
		b.set_border_width_all(3)
		b.content_margin_top = 10
		b.content_margin_bottom = 11
		b.shadow_color = Color(UiTheme.DANGER, 0.35)
		b.shadow_size = 14
	else:
		b.bg_color = Color(UiTheme.ANTHRACITE_LO, 0.84)
		b.border_color = UiTheme.DANGER if kind == "warn" else UiTheme.YELLOW
		b.border_width_left = 5
	return b


## Er kwam een alarm binnen: de rand rond het scherm licht op, en als de Mol nu aftelt, is dat een
## noodophaling (de banner wordt rood).
func _on_alarm() -> void:
	alarm.flash(1.0, UiTheme.DANGER)
	var mol: Mol = main.game.mol if main and main.game else null
	if mol and mol.mode == Mol.Mode.COUNTDOWN:
		_emergency = true


## Stempel bij de landing (in plaats van een melding): groot, schuin, met een klap, en dan weg.
## Zoals een stempel op een vrachtbrief: de planeet, de claim en de dienst. Een donkere stempel met
## een ruwe rand, zodat hij ook in de crème cabine leest (ui-18).
func stamp(title: String, sub: String) -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	holder.position = Vector2(0, 260) # onder de magmachip, die er na de landing altijd staat (ui2-13)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var s := InkStamp.make(title, UiTheme.YELLOW, 60, -4.0)
	s.sub = sub
	s.sub_size = 24
	s.fill = Color(UiTheme.ANTHRACITE_LO, 0.88)
	holder.add_child(s)
	s.refit()
	s.position = -s.size / 2.0
	s.scale = Vector2(1.8, 1.8)
	s.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(s, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(s, "modulate:a", 0.0, 0.8)
	tw.tween_callback(holder.queue_free)


## Incidentrapport van de firma na een dienst (Company): wat verkocht werd, de bonus van de
## opdracht, de kosten (vervangrobots), de schade, bevingen, en de stand van het kwartaal. Een
## formulier: wat geld kost, staat in het rood met een minteken; bovenaan een stempel.
func show_report(r: Dictionary) -> void:
	if str(r.get("type", "")) == "quarter":
		_show_quarter(r)
		return
	_clear_rows()
	var shift_total := int(r.get("shift_total", 0))
	_result_title.text = "INCIDENT REPORT"
	var claim := str(r.get("contract", ""))
	_result_meta.text = "No. %04d  ·  %s  ·  Quarter %d, shift %d/%d" % [shift_total, claim.capitalize() if claim != "" else "No contract",
			int(r.get("quarter", 1)), int(r.get("shift", 1)), Tuning.get_i("company", "shifts", 3)]
	var sold: Array = r.get("sold", [])
	var shown := 0
	for e: Array in sold:
		if shown >= 6:
			_result_row("… and %s" % UiTheme.count(sold.size() - shown, "more find"), "", INK_DIM)
			break
		_result_row("%s (%d%%)" % [e[0], int(e[2])], UiTheme.euro(int(e[1])), INK)
		shown += 1
	var haul := int(r.get("haul_count", -1))
	if haul > 0:
		_result_row("Finds to appraise at the gate (%d)" % haul, "€ ?", INK)
	elif sold.is_empty():
		_result_row("No finds in the cargo hold", UiTheme.euro(0), INK_DIM)
	if int(r.get("ore_units", 0)) > 0:
		_result_row("Ore (%d)" % int(r.ore_units), UiTheme.euro(int(r.ore_value)), INK)
	if int(r.get("bonus", 0)) != 0:
		_result_row("Risk bonus (×%.2f)" % float(r.get("factor", 1.0)), UiTheme.euro_signed(int(r.bonus)), INK_GREEN)
	var robots := int(r.get("left_behind", 0)) + int(r.get("melted", 0))
	if robots > 0:
		_result_row("Replacement robots (%d left behind, %d melted)" % [int(r.left_behind), int(r.melted)], UiTheme.euro(-int(r.costs)), INK_RED)
	if int(r.get("interest", 0)) > 0:
		_result_row("Interest on debt", UiTheme.euro(-int(r.interest)), INK_RED)
	if int(r.get("damage", 0)) > 0 and haul <= 0:
		_result_row("Damage to finds (value lost)", UiTheme.euro(-int(r.damage)), INK_RED)
	if int(r.get("quakes", 0)) > 0:
		_result_row("Quakes survived", str(int(r.quakes)), INK_DIM)
	_result_line()
	var net := int(r.get("net", 0))
	_result_row("Net", UiTheme.euro_signed(net), INK if net >= 0 else INK_RED, true)
	var result: String = r.get("quarter_result", "")
	var quota := "%s / %s" % [UiTheme.euro(int(r.get("earned", 0))), UiTheme.euro(int(r.get("quota", 0)))]
	if result == "gehaald":
		_result_row("Quota met (%s)" % quota, "", INK_GREEN)
		_set_report_stamp("QUOTA MET", INK_GREEN)
	elif result == "gemist":
		_result_row("Fine: quota missed (%s)" % quota, UiTheme.euro(-int(r.get("fine", 0))), INK_RED)
		_set_report_stamp("QUOTA MISSED", INK_RED)
	else:
		_result_row("Quota so far (sell your finds!)" if haul > 0 else "Quota so far", quota, INK)
		_set_report_stamp("APPROVED" if net >= 0 else "NOTED", INK_GREEN if net >= 0 else INK_RED)
	var cash := int(r.get("cash", 0))
	_result_row("Team funds", UiTheme.euro(cash), INK if cash >= 0 else INK_RED, true)
	_open_result(12.0)


## Afsluiting van een kwartaal (F1): na de verkoop van de laatste dienst, of bij het tekenen van de
## volgende opdracht. Wat verkocht werd, de bonussen, de stand tegenover de quota, het oordeel en
## de gevolgen (boete, proeftijd, bevroren rekening).
func _show_quarter(r: Dictionary) -> void:
	_clear_rows()
	_result_title.text = "QUARTER REPORT"
	_result_meta.text = "Quarter %d closed  ·  Head office, accounts department" % int(r.get("quarter", 1))
	var sold: Array = r.get("sold", [])
	if not sold.is_empty():
		_result_row("Last haul sold (%d)" % sold.size(), UiTheme.euro(int(r.get("finds_value", 0))), INK)
	if int(r.get("set_bonus", 0)) > 0:
		_result_row("Complete sets", UiTheme.euro_signed(int(r.set_bonus)), INK_GREEN)
	if int(r.get("target_bonus", 0)) > 0:
		_result_row("Target bonus", UiTheme.euro_signed(int(r.target_bonus)), INK_GREEN)
	if int(r.get("leftover_value", 0)) > 0:
		_result_row("Unsold, bought by head office (%d)" % int(r.get("leftover_count", 0)), UiTheme.euro_signed(int(r.leftover_value)), INK)
	_result_line()
	var quota := "%s / %s" % [UiTheme.euro(int(r.get("earned", 0))), UiTheme.euro(int(r.get("quota", 0)))]
	if str(r.get("quarter_result", "")) == "gehaald":
		_result_row("Quota met (%s)" % quota, "REP +1", INK_GREEN, true)
		_set_report_stamp("QUOTA MET", INK_GREEN)
	else:
		_result_row("Fine: quota missed (%s)" % quota, UiTheme.euro(-int(r.get("fine", 0))), INK_RED, true)
		_result_row("Reputation", UiTheme.signed(int(r.get("reputation", 0))), INK_RED)
		_set_report_stamp("QUOTA MISSED", INK_RED)
	if bool(r.get("probation", false)):
		_result_row("Probation: no HIGH-risk contracts", "", INK_RED)
	if bool(r.get("frozen", false)):
		_result_row("Account frozen until funds are positive", "", INK_RED)
	var cash := int(r.get("cash", 0))
	_result_row("Team funds", UiTheme.euro(cash), INK if cash >= 0 else INK_RED, true)
	_open_result(14.0)


## De getaxeerde waarde van een vondst (Appraisal), of −1 zolang ze niet getaxeerd is.
func _appraised_value(it: FindItem) -> int:
	var game: Game = main.game if main else null
	if game == null or game.company == null:
		return -1
	return game.company.appraisal.appraised_value(it.find_id)


## Eindoverzicht na de extractie (zonder schip; met het schip komt het incidentrapport).
func show_result(count: int, value: int, left_behind: int, ore_units := 0, ore_value := 0) -> void:
	_clear_rows()
	_result_title.text = "SHIFT OVER"
	_result_meta.text = "Extraction complete"
	_result_row("Finds in the cargo hold", str(count), INK)
	_result_row("Value of finds", UiTheme.euro(value), INK)
	if ore_units > 0:
		_result_row("Ore (%d)" % ore_units, UiTheme.euro(ore_value), INK)
	if left_behind > 0:
		_result_row("Left behind (walking up)", str(left_behind), INK_RED)
	_result_row("Fuel", "Refueled", INK_DIM)
	_set_report_stamp("RECEIVED", INK_GREEN)
	_open_result(7.0)


func _clear_rows() -> void:
	for c in _result_rows.get_children():
		_result_rows.remove_child(c)
		c.queue_free()


func _set_report_stamp(word: String, ink: Color) -> void:
	_result_stamp.text = word
	_result_stamp.ink = ink
	_result_stamp.refit()


func _open_result(seconds: float) -> void:
	_result.visible = true
	_result_closing = false
	_result.modulate.a = 0.0
	Sfx.ui("open")
	if _result_tween:
		_result_tween.kill()
	# De stempel komt een tel later, met een klap.
	_result_stamp.modulate.a = 0.0
	var tw := create_tween()
	_result_tween = tw
	tw.tween_property(_result, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void:
		var ps := _result.size
		_result_stamp.position = Vector2(30.0, ps.y - _result_stamp.size.y - 10.0)
		_result_stamp.scale = Vector2(1.7, 1.7))
	tw.tween_property(_result_stamp, "modulate:a", 0.9, 0.05)
	tw.parallel().tween_property(_result_stamp, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(seconds)
	tw.tween_callback(func() -> void: _result_closing = true)
	tw.tween_property(_result, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func() -> void:
		_result.visible = false
		_result_closing = false)


func _result_row(label_text: String, value_text: String, col := INK, strong := false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_result_rows.add_child(row)
	var l := _paper_label(label_text, 20 if strong else 19, INK if not strong else INK, 800 if strong else 600)
	if strong:
		l.add_theme_font_override("font", UiTheme.heading())
		l.text = label_text.to_upper()
	row.add_child(l)
	# Stippellijn tussen de omschrijving en het bedrag, zoals op een formulier.
	var dots := _Leader.new()
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dots)
	var v := _paper_label(value_text, 23 if strong else 20, col, 900)
	row.add_child(v)


func _result_line() -> void:
	var line := ColorRect.new()
	line.color = Color(INK, 0.55)
	line.custom_minimum_size = Vector2(0, 2)
	_result_rows.add_child(line)


## Stippellijn op het papier.
class _Leader extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(16, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.72
		var x := 4.0
		while x < size.x - 4.0:
			draw_circle(Vector2(x, y), 1.3, Color(0.14, 0.15, 0.17, 0.45))
			x += 7.0


# --- Elke frame ----------------------------------------------------------------------------------

func update(player: Player, game: Game, terrain: TerrainAPI) -> void:
	visible = player != null
	if player == null or game == null or terrain == null:
		alarm.level = 0.0
		return
	var mol := game.mol
	if not _started:
		_started = true
		compass.poke(6.0) # bij de start: waar ben ik, waar staat de Mol
	# Filmbeeld (drop, landing): de speler kijkt niet door zijn eigen ogen. Player.cinematic komt van
	# de drop; ook elke andere camera dan die van de speler (of zijn buitenzicht) telt.
	var cam := get_viewport().get_camera_3d()
	_own_cam = cam == player.camera
	var chase_cam := player.chase != null and cam == player.chase
	_world_hidden = player.get("cinematic") == true or not (_own_cam or chase_cam)
	_in_hub = game.ship != null and game.ship.contains(player.global_position)
	_in_mol = mol != null and mol.body != null and (player.seated or mol.contains_point(player.global_position))
	_update_focus(mol)
	_update_compass(player, game, mol, terrain)
	_update_hazard(player, game)
	_update_tools(player)
	_update_carry(player)
	_update_ore(player, game)
	_update_prompt(player, game, terrain)
	_update_pilot(player)
	_update_sonar(player, mol)
	_update_banner(mol, game)
	_update_objective(player, game, mol, cam)
	_update_team(player, game)
	_update_host()
	_update_stats(player, game, terrain)
	_update_alarm(player, game, mol)
	rescue_hud.update(player, game, _world_hidden or not (_own_cam or chase_cam))


func _update_hazard(player: Player, game: Game) -> void:
	hazard.blocked = _in_hub or _world_hidden # in het schip geen magma of onrust
	var dist := INF
	var eta := INF
	var p := player.global_position
	var underground := game.terrain != null and game.terrain.surface_height_at(p.x, p.z) - p.y > 2.5
	var in_mol := game.mol != null and game.mol.body != null and (player.seated or game.mol.contains_point(p))
	if game.magma and game.magma.visible and not (game.ship and game.ship.contains(p)):
		dist = p.y - game.magma.level
		eta = game.magma.seconds_until(p.y)
	var frac := 0.0
	var phase := Unrest.Phase.CALM
	if game.unrest:
		frac = game.unrest.value / maxf(1.0, Tuning.get_f("unrest", "stage", 100.0))
		phase = game.unrest.phase
	hazard.always_magma = underground or in_mol
	hazard.hide_magma = player.seated and _own_cam # het statusscherm in de cabine toont het al (ui2-13)
	if game.magma and not game.magma.quake_rise.is_connected(hazard.flash_rise):
		game.magma.quake_rise.connect(hazard.flash_rise)
	hazard.magma_eta = eta
	# De worm: hoe hard het rommelt waar jij staat (0..1).
	var worm := 0.0
	if game.worm and game.worm.is_awake():
		var cam := get_viewport().get_camera_3d()
		var at := cam.global_position if cam else p
		worm = (1.0 - smoothstep(6.0, Tuning.get_f("worm", "rumble_m", 30.0), at.distance_to(game.worm.pos))) * game.worm.activity
	hazard.worm = worm
	hazard.gas = game.gas != null and game.gas.in_gas(p + Vector3.UP * 1.0)
	hazard.set_state(dist, frac, phase)


## De rand rond het scherm: een voorschok pulseert traag, een beving snel en fel, en wie bij een
## drop niet in de Mol zit, ziet rood tot hij erin zit. Uit de toestand, nooit uit een zin.
func _update_alarm(player: Player, game: Game, mol: Mol) -> void:
	var lvl := 0.0
	var hz := 1.0
	if not _in_hub and not _world_hidden and game.unrest:
		match game.unrest.phase:
			Unrest.Phase.WARNING:
				lvl = 0.45
				hz = 1.2
			Unrest.Phase.QUAKE:
				lvl = 0.85
				hz = 2.2
	if mol and mol.mode == Mol.Mode.DROP_COUNTDOWN and _in_hub and not _in_mol and not _world_hidden:
		lvl = maxf(lvl, 0.55)
		hz = 1.6
	if not _in_hub and not _world_hidden and hazard.magma_m < 15.0:
		lvl = maxf(lvl, 0.3)
	# De worm (pakket G1, ui2-05): een zwakke rode gloed als hij dichtbij rommelt, fel als hij je vasthoudt
	# of in de Mol bijt waar je in zit.
	if not _in_hub and not _world_hidden and game.worm:
		if hazard.worm > 0.5:
			lvl = maxf(lvl, 0.2 + 0.35 * smoothstep(0.5, 0.9, hazard.worm))
			hz = maxf(hz, 1.3)
		if game.worm.holds(player.peer_id) or (game.worm.biting() and mol and mol.body and (player.seated or mol.contains_point(player.global_position))):
			lvl = maxf(lvl, 0.75)
			hz = maxf(hz, 2.2)
	alarm.level = lvl
	alarm.pulse_hz = hz


func _update_compass(player: Player, game: Game, mol: Mol, terrain: TerrainAPI) -> void:
	var p := player.global_position
	var fwd := -player.camera.global_basis.z
	compass.heading_deg = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	# In de stoel van de Mol staat de diepte op de schermen van de cabine; de strook zou dan over
	# het camerabeeld liggen (ui-13).
	compass.blocked = _world_hidden or player.seated
	if _in_hub:
		# In het schip: waar je bent, en het doel (terminal of Mol) uit _hub_state.
		var ship: Ekster = game.ship
		compass.set_place("THE MOLE · IN THE BAY" if _in_mol else "THE MAGPIE · " + ship.zone_at(p))
		var s := _hub_state(player, game, mol)
		compass.mol_visible = s.has_target
		compass.target_icon = s.icon
		compass.urgent = s.tone == HudObjective.Tone.URGENT
		if compass.mol_visible:
			var to: Vector3 = (s.target as Vector3) - p
			compass.mol_bearing_deg = fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
			compass.mol_distance = Vector2(to.x, to.z).length()
			var rel := absf(wrapf(compass.mol_bearing_deg - compass.heading_deg, -180.0, 180.0))
			# In beeld zolang het doel niet vlak voor je staat.
			compass.active = compass.urgent or compass.mol_distance > 6.0 or rel > 40.0
		else:
			compass.active = false
		return
	compass.set_place("")
	compass.planet = int(game.planet_type)
	compass.target_icon = HudCompass.MOL_ICON
	compass.urgent = false
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
				or mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.DROP_COUNTDOWN])


func _update_tools(player: Player) -> void:
	var idx := player.tools.find(player.active_tool)
	if idx != _last_tool:
		_last_tool = idx
		_hotbar.poke()
	# In het schip valt er niets te graven: geen gereedschapsbalk (ook niet bij wisselen).
	_hotbar.blocked = player.seated or player.carry.item != null or _in_hub or _world_hidden
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
	if player.carry.body_peer >= 0:
		_carry.active = true
		if _last_carry != player.carry:
			_last_carry = player.carry
			Sfx.ui("pickup", -2.0)
			_carry_icon.texture = load("res://assets/ui/icons/warning.svg")
			_carry_icon.modulate = UiTheme.DANGER
		var g: Game = player.game
		_carry_name.text = _player_name(g, player.carry.body_peer)
		_carry_value.text = "DOWN"
		var others := g.rescue.carriers_of(player.carry.body_peer).size() - 1
		_carry_note.text = "Carried together: get to the Mole" if others > 0 else "To the Mole for repairs · faster with a buddy"
		var left := clampf(g.rescue.timer_of(player.carry.body_peer) / maxf(1.0, Tuning.get_f("rescue", "downed_s", 90.0)), 0.0, 1.0)
		_carry_bar.anchor_right = left
		_carry_bar.offset_right = 0
		_carry_bar.color = UiTheme.DANGER if left < 0.25 else UiTheme.AMBER
		_carry_pct.text = HudRescue._clock(g.rescue.timer_of(player.carry.body_peer))
		_carry_cond_label.text = "TIME LEFT"
		_carry_pct.add_theme_color_override("font_color", _carry_bar.color)
		return
	_carry.active = it != null
	_carry_cond_label.text = "CONDITION"
	if it != _last_carry:
		_last_carry = it
		if it:
			Sfx.ui("pickup", -2.0)
			var fam := int(FindKinds.FAMILIES[it.kind])
			_carry_icon.texture = load("res://assets/ui/icons/%s.svg" % FAMILY_ICONS[fam])
			_carry_icon.modulate = FAMILY_TINTS[fam]
	if it == null:
		return
	_carry_name.text = it.display_name()
	# De waarde is pas aan boord bekend (F1, taxatiepoort); tot dan de waardeklasse.
	var known := _appraised_value(it)
	_carry_value.text = UiTheme.euro(known) if known >= 0 else "€ ?"
	_carry_note.text = player.carry.note() # slepen, samen, breekbaar, skelet, gewicht (F3: Carry.note)
	var cond := clampf(it.condition, 0.0, 1.0)
	_carry_bar.anchor_right = cond
	_carry_bar.offset_right = 0
	var col := UiTheme.YELLOW if cond > 0.66 else (UiTheme.AMBER if cond > 0.4 else UiTheme.DANGER)
	_carry_bar.color = col
	_carry_pct.text = "%d%%" % int(round(cond * 100.0))
	_carry_pct.add_theme_color_override("font_color", col)


func _update_prompt(player: Player, game: Game, terrain: TerrainAPI) -> void:
	var action := ""
	var text := ""
	var sub := ""
	var state := HudCrosshair.State.NONE
	var aim: Pickaxe.Aim = player.active_tool.aim
	# Vizier en prompt enkel door je eigen ogen (niet in buitenzicht of een filmbeeld).
	crosshair.blocked = _world_hidden or not _own_cam or player.ragdoll != null or player.life == Rescue.Life.BROKEN
	_prompt.blocked = crosshair.blocked
	_prompt.position.y = PROMPT_Y
	crosshair.heat = 0.0
	if player.active_tool == player.drill and not player.seated:
		var d := player.drill
		crosshair.heat = clampf(d.heat / Tuning.get_f("drill", "heat_max", 5.5), 0.0, 1.0)
		crosshair.overheated = d.overheated
		if d.overheated:
			sub = "Overheated: let it cool down"
	var knob := player.aimed_interactable()
	_aimed = knob
	if knob:
		state = HudCrosshair.State.USE
		var parts := knob.hint.split(": ", true, 1)
		action = "interact"
		text = parts[1] if parts.size() == 2 else knob.hint
		sub = knob.sub
		if not knob.hint.begins_with("E:"):
			action = ""
			state = HudCrosshair.State.NONE # enkel uitleg: E doet hier niets
		# Aan de terminal staat de tekst van het hologram rond het vizier: de prompt eronder.
		if game.ship and knob == game.ship.terminal_button():
			_prompt.position.y = 220.0
	elif player.seated:
		pass
	elif player.carry.item or player.carry.body_peer >= 0:
		pass # het draagkaartje linksonder toont de toetsen
	elif game.rescue and game.rescue.is_ok(player.peer_id) and game.rescue.aimed_body(player) >= 0:
		action = "interact"
		text = "Carry %s to the Mole" % _player_name(game, game.rescue.aimed_body(player))
		sub = "Heavy: faster with a buddy"
		state = HudCrosshair.State.USE
	elif game.mol and game.mol.in_cockpit(player.global_position) and game.mol.pilot == 0:
		action = "interact"
		text = "Drive the Mole"
		state = HudCrosshair.State.USE
	else:
		var cam := player.camera
		var hit := terrain.raycast(cam.global_position, cam.global_position - cam.global_basis.z * 3.5,
				Layers.TERRAIN | Layers.CRUST | Layers.LOOT | Layers.LIFT)
		if not hit.is_empty() and (hit.collider as Node).has_meta("worm"):
			# De kop van de worm (pakket G1): slaan doet hem loslaten.
			state = HudCrosshair.State.CRUST
			text = "The %s: hit it!" % Worm.NAME
			sub = "Pickaxe: it lets go"
		elif not hit.is_empty() and hit.collider is Rubble and (hit.collider as Rubble).blocks:
			var rb: Rubble = hit.collider
			state = HudCrosshair.State.CRUST
			crosshair.crust_hp = rb.hp
			crosshair.crust_max = rb.max_hp
			text = "Rubble: chip it away"
			sub = "Pickaxe or drill"
		elif not hit.is_empty() and hit.collider is Crust:
			var c: Crust = hit.collider
			state = HudCrosshair.State.CRUST
			crosshair.crust_hp = c.hp
			crosshair.crust_max = c.max_hp
			text = "Crust: chip it away"
			sub = "Pickaxe is safe · the drill is faster, but damages the find"
		elif not hit.is_empty() and hit.collider is OreCluster:
			var o: OreCluster = hit.collider
			state = HudCrosshair.State.CRUST
			crosshair.crust_hp = o.hp
			crosshair.crust_max = o.max_hp
			text = "Ore: %s" % OreKinds.NAMES[o.kind]
			sub = "%s each · %d left · pickaxe or drill" % [UiTheme.euro(OreKinds.value(o.kind)), int(ceil(o.hp))]
		elif not hit.is_empty() and hit.collider is FindItem:
			var f: FindItem = hit.collider
			state = HudCrosshair.State.USE if f.freed else HudCrosshair.State.NONE
			if f.freed and f.carriers.size() < 2:
				action = "interact"
				text = "%s: %s" % [Carry.verb(f), f.display_name()] # oppakken, slepen of helpen dragen (F3)
			else:
				text = f.display_name()
			var known := _appraised_value(f)
			sub = ("%s · condition %d%%" % [UiTheme.euro(known), int(round(f.condition * 100))]) if known >= 0 else 					("%s · condition %d%% · value: appraised aboard" % [FindKinds.CLASS_NAMES[f.value_class], int(round(f.condition * 100))])
		elif aim == Pickaxe.Aim.TOO_HARD:
			state = HudCrosshair.State.HARD
			text = player.active_tool.hint_too_hard()
		elif aim == Pickaxe.Aim.DIGGABLE:
			state = HudCrosshair.State.DIG
	crosshair.state = state
	_set_prompt(action, UiTheme.cap(text), UiTheme.cap(sub))


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
		_prompt_caps.add_child(KeyCap.make(action, KEY_FONT))
	_prompt_caps.visible = action != ""


func _update_ore(player: Player, game: Game) -> void:
	var ores: OreField = game.ores
	if ores == null:
		return
	if not _ore_connected:
		_ore_connected = true
		ores.bag_full.connect(func() -> void:
			toast("Ore bag full: empty it into the Mole's hopper", "warn"))
	var bag := ores.bag_of(player.peer_id)
	var n := OreField.units(bag)
	_ore.active = n > 0 and int(Settings.get_value("hud/prompts")) == Settings.HUD_ALWAYS
	if n == _ore_shown:
		return
	_ore_shown = n
	var cap := Tuning.get_i("ore", "bag_capacity", 40)
	_ore_label.text = "%d/%d" % [n, cap]
	_ore_label.add_theme_color_override("font_color", UiTheme.DANGER if n >= cap else UiTheme.CREAM)
	_ore_value.text = UiTheme.euro(OreField.value(bag))
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
	_place_pilot(show)
	if show and _sonar_view.texture == null:
		_sonar_view.texture = mol.visual.sonar_screen.texture()


## De pilootstrook: onderaan in het midden. In buitenzicht staat rechtsonder de sonar: dan gecentreerd
## in de ruimte links ervan, en als ze daar niet past (een grote interface, een smal scherm) boven de
## sonar. Nooit eronder, want "Get out" stond er net onder (ui2-04).
func _place_pilot(sonar_shown: bool) -> void:
	var vp := get_viewport_rect().size
	var chip_w := _pilot_chip.get_combined_minimum_size().x
	var h := 72.0
	var x0 := 24.0
	var x1 := vp.x - 24.0
	var y := vp.y - 98.0
	if sonar_shown:
		var sonar_left := _sonar.get_rect().position.x
		if chip_w <= sonar_left - 16.0 - x0:
			x1 = sonar_left - 16.0
		else:
			y = _sonar.get_rect().position.y - 12.0 - h
	_pilot.position = Vector2(x0, y)
	_pilot.size = Vector2(x1 - x0, h)
	_pilot_box.size = _pilot.size


## Waar de grote HUD-onderdelen nu staan (schermrechthoeken van wat zichtbaar is), voor de test op
## overlap (ui_test): pilootstrook en sonar.
func layout_rects() -> Dictionary:
	var out := {}
	if not _pilot.blocked:
		out["pilot"] = _pilot_chip.get_global_rect()
	if not _sonar.blocked:
		out["sonar"] = _sonar_chip.get_global_rect()
	return out


## De aftelling van de Mol (ui-11): de titel ("DROP IN", "THE MOLE LEAVES IN"), een groot getal dat
## bij elke tel klopt, en in co-op wie er al in zit. Rood bij een noodophaling, of als jij bij een
## drop niet in de Mol zit; de laatste drie tellen altijd rood, met een flits aan de rand.
func _update_banner(mol: Mol, game: Game) -> void:
	if mol == null:
		return
	if not mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING]:
		_emergency = false
	var counting: bool = mol.mode in [Mol.Mode.COUNTDOWN, Mol.Mode.DROP_COUNTDOWN]
	if counting:
		# Wie zit er al in? Zo weet de ploeg op wie ze wacht (onderzoek drop-en-ophalen: "je zit erin").
		var total := 0
		var inside := 0
		for pl: Player in game.players.get_children():
			total += 1
			if pl.seated or mol.contains_point(pl.global_position):
				inside += 1
		var left_out: bool = mol.mode == Mol.Mode.DROP_COUNTDOWN and _in_hub and not _in_mol
		var n := int(ceil(mol.countdown))
		var red := left_out or _emergency or n <= 3
		_banner.visible = true
		if mol.mode == Mol.Mode.DROP_COUNTDOWN:
			_banner_title.text = "NOT IN THE MOLE · DROP IN" if left_out else "DROP IN"
		else:
			_banner_title.text = "EMERGENCY EXTRACTION IN" if _emergency else "THE MOLE LEAVES IN"
		_banner_count.text = str(n)
		_banner_count.visible = true
		_banner_sub.text = "ABOARD %d/%d" % [inside, total]
		_banner_sub.visible = total > 1 # solo zegt "aan boord 1/1" niets
		_style_banner(red, left_out or _emergency)
		if n != _banner_shown:
			_banner_shown = n
			_tick_banner(n, red)
	elif mol.mode == Mol.Mode.EXTRACTING:
		_banner.visible = true
		_banner_title.text = "THE MOLE IS HEADING UP"
		_banner_count.visible = false
		_banner_sub.visible = false
		_banner_shown = -1
		_style_banner(_emergency, _emergency)
	else:
		_banner.visible = false
		_banner_shown = -1
	# Zo klein als de inhoud (een Control krimpt niet vanzelf als er een regel verdwijnt), onder de
	# gevaren (magma, onrust) als die er staan, anders onder de strook.
	if _banner.visible:
		_banner.reset_size()
	_banner.position.y = 112.0 + (hazard.content_height() + 6.0 if hazard.visible else 0.0)


## Kleur van de aftelling: geel (gewoon) of rood (dringend: de rand, de strepen, het getal).
func _style_banner(red: bool, urgent_frame: bool) -> void:
	var b := StyleBoxFlat.new()
	b.set_corner_radius_all(10)
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 0
	b.content_margin_bottom = 0
	b.bg_color = Color(0.3, 0.03, 0.0, 0.82) if urgent_frame else Color(UiTheme.ANTHRACITE_LO, 0.72)
	b.border_color = UiTheme.DANGER if urgent_frame else Color(UiTheme.YELLOW, 0.55)
	b.set_border_width_all(3 if urgent_frame else 2)
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 16
	_banner.add_theme_stylebox_override("panel", b)
	var stripe := UiTheme.DANGER if urgent_frame else UiTheme.YELLOW
	_banner_strip.color_a = stripe
	_banner_strip2.color_a = stripe
	_banner_count.add_theme_color_override("font_color", UiTheme.DANGER if red else UiTheme.YELLOW)
	_banner_title.add_theme_color_override("font_color", UiTheme.CREAM)


## Een nieuwe tel: het getal springt groot in beeld en licht op; de laatste tellen ook de rand.
func _tick_banner(n: int, red: bool) -> void:
	var lbl := _banner_count
	lbl.pivot_offset = lbl.size / 2.0
	lbl.scale = Vector2(1.45, 1.45)
	lbl.modulate = Color(1.8, 1.8, 1.8, 1.0)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate", Color.WHITE, 0.4)
	if n <= 3 and n > 0:
		alarm.flash(0.75 if red else 0.5, UiTheme.DANGER)
	elif n > 3:
		alarm.flash(0.18, UiTheme.YELLOW)


## Wat er in het schip te doen is: titel en regel eronder, de toon, het doel voor de strook (de
## terminal of de Mol) en of de hendel een merkteken krijgt.
func _hub_state(player: Player, game: Game, mol: Mol) -> Dictionary:
	var s := {"title": "", "sub": "", "tone": HudObjective.Tone.NORMAL, "has_target": false, "target": Vector3.ZERO,
			"icon": HudCompass.MOL_ICON, "lever": false}
	var ship: Ekster = game.ship
	if mol == null or mol.body == null or ship == null:
		return s
	var c: Company = game.company
	var p := player.global_position
	var mol_pos := mol.body.global_position
	match mol.mode:
		Mol.Mode.DOCKED:
			if c and c.haul_open() and not c.contract_ready() and not c.appraisal.unappraised_items().is_empty():
				s.title = "Appraise your haul"
				s.sub = "Carry the finds from the Mole through the appraisal gate (%d left)" % c.appraisal.unappraised_items().size()
				s.has_target = true
				s.target = ship.anchor_position("Appraisal_Gate") + Vector3(0, 1.2, 0)
				s.icon = HudCompass.TERMINAL_ICON
			elif c and c.haul_open() and not c.contract_ready() and not c.appraisal.appraised_items().is_empty():
				s.title = "Sell your haul"
				s.sub = "At the sell hatch, next to the gate"
				s.has_target = true
				s.target = ship.anchor_position("Sell_Hatch") + Vector3(0, 1.2, 0)
				s.icon = HudCompass.TERMINAL_ICON
			elif c == null or not c.contract_ready():
				s.title = "Choose a contract"
				s.sub = "At the contract table on the bridge"
				s.has_target = true
				s.target = ship.terminal_target()
				s.icon = HudCompass.TERMINAL_ICON
			elif not game.world_ready():
				var dots := ".".repeat(1 + int(Time.get_ticks_msec() / 400) % 3)
				s.title = "The Magpie is flying to %s%s" % [str(c.contract.get("name", "the claim")), dots]
				s.sub = "Hang on, then pull the lever" if _in_mol else "Head over to the Mole"
				s.has_target = not _in_mol
				s.target = mol_pos
			elif not _in_mol:
				s.title = "Board the Mole"
				s.sub = "In the hangar, up the ramp at the back"
				s.has_target = true
				s.target = mol_pos
			else:
				s.title = "Pull the lever"
				s.sub = "The LAUNCH lever, on the right of the console"
				s.lever = true
		Mol.Mode.DROP_COUNTDOWN:
			if not _in_mol:
				# De aftelling zelf staat groot in de banner: hier enkel wat je moet doen (ui-11).
				s.title = "Get to the Mole"
				s.sub = "The hatches are opening: stand on them and you fall" if ship.over_bay(p, 0.5) else "Get in fast, or you'll be left behind"
				s.tone = HudObjective.Tone.URGENT
				s.has_target = true
				s.target = mol_pos
		Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING, Mol.Mode.GRAPPLE_DOWN, Mol.Mode.LIFTING:
			if not _in_mol:
				s.title = "The Mole is coming back"
				s.sub = "Wait until it's back in the bay"
		_:
			if not _in_mol:
				s.title = "The crew is on the planet"
				s.sub = "The Mole returns after the shift"
	# Open luiken zonder Mol: een gat van 8 × 14 m in de vloer.
	if ship.doors_open and not _in_mol and mol.mode != Mol.Mode.DROP_COUNTDOWN and ship.over_bay(p, 1.5):
		s.title = "OPEN HATCH · %d m FREE FALL" % int(round(EksterExterior.ALTITUDE))
		s.sub = "Jump = go down to the planet on foot"
		s.tone = HudObjective.Tone.URGENT
	elif ship.doors_open and not _in_mol and mol.mode != Mol.Mode.DROP_COUNTDOWN and s.title == "The crew is on the planet":
		s.sub = "To follow, jump through the open hatch in the hangar"
	return s


## In het schip: de doelregel onder de strook en het merkteken op de hendel.
func _update_objective(player: Player, game: Game, mol: Mol, cam: Camera3D) -> void:
	var s := _hub_state(player, game, mol) if _in_hub else {}
	# Het incidentrapport staat rechts: het doel blijft gewoon in beeld (ui-08).
	objective.blocked = not _in_hub or _world_hidden
	# Aangekomen boven de concessie (de nieuwe wereld is geladen): één melding, met geluid.
	var loading: bool = not game.world_ready()
	if _was_loading and not loading and _in_hub and game.company and game.company.contract_ready() \
			and mol and mol.mode == Mol.Mode.DOCKED:
		toast("Arrived above %s." % str(game.company.contract.get("name", "")), "mol", 5.0)
	_was_loading = loading
	objective.show_objective(s.get("title", ""), s.get("sub", ""), s.get("tone", HudObjective.Tone.NORMAL))
	# Onder de aftelling als die er staat (drop-aftelling), anders onder de strook.
	objective.position.y = _banner.position.y + _banner.size.y + 10.0 if _banner.visible else 108.0
	# Het merkteken op de hendel in de Mol (niet als je er al op mikt: dan staat de prompt er).
	var lever := _find_lever(mol)
	_marker.shown = s.get("lever", false) and lever != null and _aimed != lever and not _world_hidden and _own_cam \
			and not _countdown_focus
	if lever:
		_marker.target = lever.global_position
		_marker.set_text("LAUNCH LEVER")
	_marker.place(cam)
	# QA-5: het incidentrapport meteen weg als een nieuwe aftelling begint (niet over de banner).
	if mol and mol.mode in [Mol.Mode.DROP_COUNTDOWN, Mol.Mode.COUNTDOWN] and _result.visible:
		if _result_tween:
			_result_tween.kill()
		_result.visible = false
		_result_closing = false


var _lever: Interactable

## De VERTREK-hendel van de Mol (de knop met het commando DEPART).
func _find_lever(mol: Mol) -> Interactable:
	if _lever and is_instance_valid(_lever):
		return _lever
	if mol == null:
		return null
	for it: Interactable in mol.find_children("*", "Interactable", true, false):
		if it.get_meta("mol_cmd", -1) == Mol.Cmd.DEPART:
			_lever = it
			return it
	return null


## Voorrang tijdens het drop-aftellen, voor wie in de Mol zit: de aftelling, verder niets. Bij het
## begin: de doelregel, het merkteken, het rapport en de oude meldingen meteen weg.
func _update_focus(mol: Mol) -> void:
	var mode := mol.mode if mol else -1
	var focus := mode == Mol.Mode.DROP_COUNTDOWN and _in_mol
	if focus and not _countdown_focus:
		objective.snap_out()
		_marker.snap_out()
		for c in _toasts.get_children():
			_toasts.remove_child(c)
			c.queue_free()
	_countdown_focus = focus
	_last_mode = mode


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
			name.text = "Player %d" % (game.players.get_children().find(pl) + 1)
			name.add_theme_font_override("font", UiTheme.body(800))
			name.add_theme_font_size_override("font_size", MIN_FONT)
			row.add_child(name)
			var where := Label.new()
			where.name = "Where"
			where.add_theme_font_size_override("font_size", MIN_FONT)
			where.add_theme_color_override("font_color", Color("#C2BAAC"))
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
		var life: int = game.rescue.life_of(pl.peer_id) if game.rescue else Rescue.Life.OK
		if life == Rescue.Life.DOWNED:
			where.text = "DOWN %s" % HudRescue._clock(game.rescue.timer_of(pl.peer_id))
			where.add_theme_color_override("font_color", UiTheme.DANGER)
		elif life == Rescue.Life.LIMPING:
			where.text = "Limping %s" % HudRescue._clock(game.rescue.timer_of(pl.peer_id))
			where.add_theme_color_override("font_color", UiTheme.AMBER)
		elif life == Rescue.Life.BROKEN:
			where.text = "Ghost drone"
			where.add_theme_color_override("font_color", UiTheme.CYAN)
		else:
			where.add_theme_color_override("font_color", Color("#C2BAAC"))
			where.text = "In the Mole" if game.mol and game.mol.contains_point(pl.global_position) else "%d m" % int(player.global_position.distance_to(pl.global_position))


## "Player 2": zoals in de ploeglijst (volgorde van binnenkomen).
static func _player_name(game: Game, peer: int) -> String:
	var idx := 0
	for pl: Player in game.players.get_children():
		idx += 1
		if pl.peer_id == peer:
			return "Player %d" % idx
	return "a robot"


func _update_host() -> void:
	if Net.mode != Net.Mode.HOST:
		_host_chip.active = false
		return
	if Settings.get_b("interface/hide_ip"):
		_host_label.text = "HOST  ·  IP hidden"
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
	_stats.text = "%d fps  ·  %s  ·  %s\npos %.1f, %.1f, %.1f%s" % [
		Engine.get_frames_per_second(), net, UiTheme.count(game.players.get_child_count(), "player"), p.x, p.y, p.z,
		"  ·  FLYING" if player.flying else ""]
