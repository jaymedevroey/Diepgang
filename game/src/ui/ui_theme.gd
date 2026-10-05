class_name UiTheme
extends RefCounted
## Huisstijl van Diepgang BV voor alle menu's en de HUD (docs/stijlgids.md, docs/research/hud-menu.md).
## "Goedkope bedrijfshuisstijl": bedrijfsgeel en antraciet, Bungee voor koppen en knoppen,
## Nunito voor tekst, VT323 voor schermen. Eén thema voor het hele spel (op het hoofdvenster).

# Palet (stijlgids).
const YELLOW := Color("#F2B705")
const YELLOW_HI := Color("#FFC92E")
const YELLOW_LO := Color("#B98A00")
const ANTHRACITE := Color("#23262B")
const ANTHRACITE_HI := Color("#30343B")
const ANTHRACITE_LO := Color("#16181C")
const STEEL := Color("#8C9096")
const CREAM := Color("#E9E1D3")
const CREAM_DIM := Color("#A9A296")
const AMBER := Color("#FFB45A")
const DANGER := Color("#FF5A1F")
const CYAN := Color("#4FE3F0")
const NIGHT := Color("#120D0A")
const GOOD := Color("#8CE040")

const HEADING := preload("res://assets/fonts/Bungee-Regular.ttf")
const BODY := preload("res://assets/fonts/Nunito-Variable.ttf")
const SCREEN := preload("res://assets/fonts/VT323-Regular.ttf")


## Een bedrag zoals op een factuur: €1,250 of −€47 (met het echte minteken).
static func euro(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("−€" if v < 0 else "€") + s + out


## Een bedrag met teken, voor een rij die iets bijtelt of aftrekt: +€266 of −€240.
static func euro_signed(v: int) -> String:
	return ("+" if v > 0 else "") + euro(v)


## Een geheel getal met het echte minteken (−19, niet -19).
static func num(v: int) -> String:
	return ("−" if v < 0 else "") + str(absi(v))


## "1 shift", "3 shifts": enkelvoud of meervoud (met een eigen meervoud als het niet op -s eindigt).
static func count(n: int, word: String, plural := "") -> String:
	return "%d %s" % [n, word if n == 1 else (plural if plural != "" else word + "s")]


## Eerste letter een hoofdletter: elke prompt, doelregel en melding begint zo, ook als de bron
## (een knop, een melding) met een kleine letter begint (ui-07).
static func cap(s: String) -> String:
	return s if s.is_empty() else s.substr(0, 1).to_upper() + s.substr(1)

static var _theme: Theme
static var _fonts: Dictionary = {}


## Nunito in een gewicht (400 gewoon, 700 vet, 900 zwart).
static func body(weight := 600) -> Font:
	var key := "body%d" % weight
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = BODY
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[key] = f
	return _fonts[key]


static func heading() -> Font:
	return HEADING


static func screen() -> Font:
	return SCREEN


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body(600)
	t.default_font_size = 18

	# Tekst.
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	# Varianten: koppen in Bungee, kleine kopjes, schermtekst.
	_variation(t, "Title", "Label", HEADING, 64, YELLOW)
	_variation(t, "Heading", "Label", HEADING, 30, YELLOW)
	_variation(t, "SubHeading", "Label", HEADING, 18, CREAM)
	_variation(t, "Caption", "Label", body(700), 18, Color("#BDB5A7"))
	_variation(t, "Screen", "Label", SCREEN, 26, AMBER)

	# Panelen.
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", _box(ANTHRACITE_HI, 8, 0, Color.TRANSPARENT, 12))
	# HUD: donker plaatje met een gele rand links, het kenmerk van de firma op elk HUD-element (ui-09).
	t.set_type_variation("HudChip", "PanelContainer")
	var chip := _box(Color(ANTHRACITE_LO, 0.8), 5, 0, YELLOW, 10, 6)
	chip.border_width_left = 4
	chip.content_margin_left = 12
	t.set_stylebox("panel", "HudChip", chip)

	# Knoppen: geel, dikke donkere onderrand ("lip"), ingedrukt zakt hij in.
	t.set_stylebox("normal", "Button", _button_box(YELLOW, YELLOW_LO, 5))
	t.set_stylebox("hover", "Button", _button_box(YELLOW_HI, YELLOW_LO, 5))
	t.set_stylebox("pressed", "Button", _button_box(YELLOW_LO, YELLOW_LO, 1, 4))
	t.set_stylebox("hover_pressed", "Button", _button_box(YELLOW_LO, YELLOW_LO, 1, 4))
	t.set_stylebox("disabled", "Button", _button_box(Color(STEEL, 0.5), Color(STEEL, 0.3), 5))
	t.set_stylebox("focus", "Button", _focus_box())
	t.set_font("font", "Button", HEADING)
	t.set_font_size("font_size", "Button", 20)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", ANTHRACITE)
	t.set_color("font_disabled_color", "Button", Color(ANTHRACITE, 0.6))
	# Tweede soort knop: antraciet met gele rand (minder belangrijk, terug, annuleren).
	t.set_type_variation("GhostButton", "Button")
	t.set_stylebox("normal", "GhostButton", _button_box(ANTHRACITE_HI, ANTHRACITE_LO, 4, 0, STEEL))
	t.set_stylebox("hover", "GhostButton", _button_box(Color("#3B4048"), ANTHRACITE_LO, 4, 0, YELLOW))
	t.set_stylebox("pressed", "GhostButton", _button_box(ANTHRACITE_LO, ANTHRACITE_LO, 1, 3, YELLOW))
	t.set_stylebox("hover_pressed", "GhostButton", _button_box(ANTHRACITE_LO, ANTHRACITE_LO, 1, 3, YELLOW))
	t.set_font_size("font_size", "GhostButton", 17)
	for c in ["font_color", "font_focus_color"]:
		t.set_color(c, "GhostButton", CREAM)
	for c in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "GhostButton", YELLOW)
	# Tabknop in de instellingen (links in een lijst).
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", _box(Color.TRANSPARENT, 6, 0, Color.TRANSPARENT, 14, 10))
	t.set_stylebox("hover", "TabButton", _box(Color(1, 1, 1, 0.06), 6, 0, Color.TRANSPARENT, 14, 10))
	t.set_stylebox("pressed", "TabButton", _box(YELLOW, 6, 0, Color.TRANSPARENT, 14, 10))
	t.set_stylebox("hover_pressed", "TabButton", _box(YELLOW_HI, 6, 0, Color.TRANSPARENT, 14, 10))
	t.set_font_size("font_size", "TabButton", 17)
	t.set_color("font_color", "TabButton", CREAM_DIM)
	t.set_color("font_hover_color", "TabButton", CREAM)
	t.set_color("font_focus_color", "TabButton", CREAM)
	t.set_color("font_pressed_color", "TabButton", ANTHRACITE)
	t.set_color("font_hover_pressed_color", "TabButton", ANTHRACITE)

	# Invoervelden.
	var edit := _box(ANTHRACITE_LO, 6, 2, Color("#3B4048"), 12, 9)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _box(ANTHRACITE_LO, 6, 2, YELLOW, 12, 9))
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", Color(CREAM_DIM, 0.6))
	t.set_color("caret_color", "LineEdit", YELLOW)
	t.set_color("selection_color", "LineEdit", Color(YELLOW, 0.35))
	t.set_font_size("font_size", "LineEdit", 18)

	# Schuifregelaars: dikke groef, gele vulling, ronde knop.
	var groove := _box(ANTHRACITE_LO, 5, 0, Color.TRANSPARENT, 0, 0)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	var fill := _box(YELLOW, 5, 0, Color.TRANSPARENT, 0, 0)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", groove)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(YELLOW_HI, 5, 0, Color.TRANSPARENT, 0, 0))
	t.set_icon("grabber", "HSlider", _circle_icon(22, CREAM, ANTHRACITE))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(22, Color.WHITE, YELLOW_LO))
	t.set_constant("center_grabber", "HSlider", 1)

	# Vinkjes en schakelaars.
	t.set_icon("checked", "CheckButton", _toggle_icon(true))
	t.set_icon("unchecked", "CheckButton", _toggle_icon(false))
	t.set_icon("checked", "CheckBox", _toggle_icon(true))
	t.set_icon("unchecked", "CheckBox", _toggle_icon(false))
	for ty in ["CheckButton", "CheckBox"]:
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			t.set_stylebox(st, ty, empty if st != "focus" else _focus_box())
		t.set_color("font_color", ty, CREAM)
		t.set_color("font_hover_color", ty, YELLOW)
		t.set_color("font_pressed_color", ty, CREAM)
		t.set_color("font_hover_pressed_color", ty, YELLOW)

	# Keuzelijst.
	t.set_stylebox("normal", "OptionButton", _button_box(ANTHRACITE_HI, ANTHRACITE_LO, 3, 0, Color("#3B4048")))
	t.set_stylebox("hover", "OptionButton", _button_box(Color("#3B4048"), ANTHRACITE_LO, 3, 0, YELLOW))
	t.set_stylebox("pressed", "OptionButton", _button_box(ANTHRACITE_LO, ANTHRACITE_LO, 1, 2, YELLOW))
	t.set_stylebox("focus", "OptionButton", _focus_box())
	t.set_font("font", "OptionButton", body(700))
	t.set_font_size("font_size", "OptionButton", 17)
	for c in ["font_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(c, "OptionButton", CREAM)
	t.set_color("font_hover_color", "OptionButton", YELLOW)
	t.set_stylebox("panel", "PopupMenu", _box(ANTHRACITE_LO, 8, 2, STEEL, 6, 6))
	t.set_stylebox("hover", "PopupMenu", _box(YELLOW, 5, 0, Color.TRANSPARENT, 8, 4))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", ANTHRACITE)
	t.set_font("font", "PopupMenu", body(700))
	t.set_font_size("font_size", "PopupMenu", 17)

	# Schuifbalken (goed zichtbaar: een lijst die niet past, moet je zien, ui-15), tooltips,
	# scheidingslijnen, tabbladen (tuning-menu).
	var sb := _box(Color(1, 1, 1, 0.12), 5, 0, Color.TRANSPARENT, 5, 0)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", _box(Color(STEEL, 0.95), 5, 0, Color.TRANSPARENT, 5, 5))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(YELLOW, 4, 0, Color.TRANSPARENT, 4, 4))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(YELLOW_HI, 4, 0, Color.TRANSPARENT, 4, 4))
	t.set_stylebox("panel", "TooltipPanel", _box(ANTHRACITE_LO, 6, 2, YELLOW, 10, 8))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 18)
	var sep := StyleBoxLine.new()
	sep.color = Color(STEEL, 0.3)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 18)
	t.set_stylebox("panel", "TabContainer", _box(ANTHRACITE_LO, 8, 0, Color.TRANSPARENT, 12, 12))
	t.set_stylebox("tab_selected", "TabContainer", _box(YELLOW, 6, 0, Color.TRANSPARENT, 12, 6))
	t.set_stylebox("tab_unselected", "TabContainer", _box(ANTHRACITE_HI, 6, 0, Color.TRANSPARENT, 12, 6))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("#3B4048"), 6, 0, Color.TRANSPARENT, 12, 6))
	t.set_color("font_selected_color", "TabContainer", ANTHRACITE)
	t.set_color("font_unselected_color", "TabContainer", CREAM_DIM)
	t.set_color("font_hovered_color", "TabContainer", CREAM)
	t.set_font("font", "TabContainer", body(800))
	t.set_stylebox("normal", "SpinBox", edit)
	return t


static func _variation(t: Theme, name: String, base: String, font: Font, size: int, color: Color) -> void:
	t.set_type_variation(name, base)
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)


## Paneel: antraciet met een dunne lichte rand en een zachte schaduw.
static func panel_box() -> StyleBoxFlat:
	var b := _box(Color(ANTHRACITE, 0.96), 12, 2, Color("#3B4048"), 24, 20)
	b.shadow_color = Color(0, 0, 0, 0.45)
	b.shadow_size = 18
	b.shadow_offset = Vector2(0, 6)
	return b


static func _box(bg: Color, radius: int, border: int, border_color: Color, margin_h := 12, margin_v := -1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.set_corner_radius_all(radius)
	b.set_border_width_all(border)
	b.border_color = border_color
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v if margin_v >= 0 else margin_h
	b.content_margin_bottom = margin_v if margin_v >= 0 else margin_h
	b.anti_aliasing = true
	return b


## Knop met een "lip" onderaan: de dikke onderrand is de zijkant van een fysieke knop.
static func _button_box(bg: Color, lip: Color, lip_px: int, sink := 0, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var b := _box(bg, 7, 0, lip, 18, 10)
	b.border_width_bottom = lip_px
	if border.a > 0.0:
		b.border_width_left = 2
		b.border_width_right = 2
		b.border_width_top = 2
		b.border_color = border
		b.border_blend = false
	b.expand_margin_top = -sink # ingedrukt: de knop zakt in
	b.content_margin_top = 10 + sink
	b.content_margin_bottom = 10 + lip_px - sink
	return b


static func _focus_box() -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.draw_center = false
	b.set_border_width_all(3)
	b.border_color = Color(CREAM, 0.9)
	b.set_corner_radius_all(9)
	b.expand_margin_left = 3
	b.expand_margin_right = 3
	b.expand_margin_top = 3
	b.expand_margin_bottom = 3
	return b


static func _circle_icon(size: int, fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= c - 0.5:
				col = ring if d > c - 3.5 else fill
			elif d <= c + 0.5:
				col = Color(ring, c + 0.5 - d)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Schakelaar: een pilvorm met een bolletje, geel als hij aan staat.
static func _toggle_icon(on: bool) -> ImageTexture:
	var w := 52
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h / 2.0
	var track := YELLOW if on else Color("#3B4048")
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			var col := Color(0, 0, 0, 0)
			if d <= r:
				col = Color(track, clampf(r - d, 0.0, 1.0))
			var dk := px.distance_to(Vector2(knob_x, r))
			if dk <= r - 4.0:
				var k := CREAM if not on else ANTHRACITE
				col = col.blend(Color(k, clampf(r - 4.0 - dk, 0.0, 1.0)))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)
