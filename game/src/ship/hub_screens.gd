class_name HubScreens
extends Node
## De schermen in de hub van De Ekster (ekster_hub.glb; contract: tools/blender/interior/layout.py).
## Elk scherm is een SubViewport (enkel 2D, lage resolutie) als textuur op het vlak met UV 0..1:
## - TV_Screen (werkdek): DIG-nieuws, een goedkope bedrijfszender. Segmenten van 8 tot 12 s
##   (nieuws, reclame, quota, weer, beurs, werknemer van het kwartaal, veiligheid), een lopende
##   balk onderaan, het DIG-logo in de hoek en een beeldbuis (feed.gdshader). Teksten in
##   res://data/hub_tv.gd. Na een dienst komt er een EXTRA-uitzending met het rapport.
## - Company_Board (gang): kas, reputatie, kwartaal en dienst, de quota, de opdracht, de vorige dienst.
## - Terminal_Screen (brug): hologram boven de opdrachttafel: de gekozen opdracht, of "kies er een".
## - Appraisal_Screen (kade): de taxatie van de vorige dienst (tot de echte taxatiepoort er is).
## Alles leest de toestand van de firma (Company) op deze peer, dus ook clients zien het juiste.
## Performance: een scherm rendert enkel als de camera binnen VIEW_RANGE × zijn breedte is, het in
## beeld staat en naar de camera kijkt, en dan nog op zijn eigen tempo (UPDATE_ONCE, `fps`);
## anders blijft het laatste beeld staan en kost het niets.
## Gebruik in de hub:  var screens := HubScreens.new(); add_child(screens); screens.setup(game, anchors)

const FEED_SHADER := preload("res://src/mol/feed.gdshader")
const HOLO_SHADER := preload("res://src/ship/hub_hologram.gdshader")
const TEXTS := preload("res://data/hub_tv.gd")

const TV := "TV_Screen"
const BOARD := "Company_Board"
const TERMINAL := "Terminal_Screen"
const APPRAISAL := "Appraisal_Screen"
## Breedte van elke viewport in pixels; de hoogte volgt uit de verhouding van het scherm.
const WIDTH := 640
## Een scherm rendert enkel binnen zoveel keer zijn breedte (verder weg is het een paar pixels).
const VIEW_RANGE := 10.0
## Tv: de volgorde van de segmenten (de inhoud kiest hij willekeurig).
const PLAYLIST: Array[String] = ["news", "ad", "quota", "news", "safety", "weather", "news", "employee", "ad", "shares", "news", "quota", "safety", "news", "weather"]
## Duur van een segment: van x (korte tekst) tot y seconden (lange tekst).
const SEGMENT_S := Vector2(8.0, 12.0)
const IDENT_EVERY := 9
const TICKER_SPEED := 64.0
const TICKER_H := 40.0
const KICKER := {
	"news": ["NEWS", UiTheme.YELLOW, UiTheme.ANTHRACITE],
	"ad": ["ADVERTISING", UiTheme.ANTHRACITE, UiTheme.YELLOW],
	"quota": ["QUARTERLY FIGURES", UiTheme.CYAN, UiTheme.ANTHRACITE],
	"employee": ["EMPLOYEE OF THE QUARTER", UiTheme.YELLOW, UiTheme.ANTHRACITE],
	"weather": ["WEATHER", UiTheme.GOOD, UiTheme.ANTHRACITE],
	"shares": ["MARKETS", UiTheme.GOOD, UiTheme.ANTHRACITE],
	"safety": ["SAFETY", UiTheme.DANGER, UiTheme.CREAM],
	"report": ["BREAKING", UiTheme.DANGER, UiTheme.CREAM],
}
const SMALL_PRINT: Array[String] = [
	"Prices excl. tax, arms and warranty.",
	"Offer valid until the magma arrives.",
	"Not suitable for robots.",
	"Costs are deducted from your funds.",
]


## Eén scherm: het vlak, zijn viewport en wat erop staat.
class Screen:
	var key := ""
	var mesh: MeshInstance3D
	var viewport: SubViewport
	var root: Control
	var art: Control
	var size := Vector2.ZERO
	## Beelden per seconde zolang het zichtbaar is.
	var fps := 4.0
	var timer := 0.0
	var dirty := true
	var seen := false
	var two_sided := false
	var local_center := Vector3.ZERO
	var local_normal := Vector3.BACK
	var local_corners := PackedVector3Array()
	var width := 1.0
	var height := 1.0
	var labels := {}


## Tekent wat geen label is (achtergrond, balken, grafiek, het robotje) met een functie van HubScreens.
class Art extends Control:
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


var game: Node # Game
var _screens := {} # naam -> Screen
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _box := StyleBoxFlat.new()
# Tv.
var _seg := ""
var _seg_time := 0.0
var _seg_left := 0.0
var _seg_index := -1
var _since_ident := 0
var _hold := false
var _report_pending := false
var _line: PackedStringArray = [] # gekozen regel van dit segment (ingevuld, in delen)
var _last_pick := {} # soort -> laatste index
var _ticker_x := 0.0
var _ticker_w := 0.0
var _share := 412.0
var _share_up := 3.2
var _share_down := 1.4
var _share_curve := PackedFloat32Array()
var _tv_light: OmniLight3D
# Taxatie: lopende tekst.
var _marquee_x := 0.0
var _marquee_w := 0.0


func _init() -> void:
	name = "HubScreens"
	_box.anti_aliasing = true


## `anchors`: naam -> node van het hubmodel (enkel de schermen worden gebruikt).
func setup(game_node: Node, anchors: Dictionary) -> void:
	game = game_node
	_rng.randomize()
	if anchors.get(TV) is MeshInstance3D:
		_build_tv(_make(TV, anchors[TV], 24.0))
	if anchors.get(BOARD) is MeshInstance3D:
		_build_board(_make(BOARD, anchors[BOARD], 2.0))
	if anchors.get(TERMINAL) is MeshInstance3D:
		_build_terminal(_make(TERMINAL, anchors[TERMINAL], 4.0, true))
	if anchors.get(APPRAISAL) is MeshInstance3D:
		_build_appraisal(_make(APPRAISAL, anchors[APPRAISAL], 4.0))
	var c: Company = game.company
	c.changed.connect(_on_changed)
	c.report_ready.connect(_on_report)
	_tv_enter("ident")
	for s: Screen in _screens.values():
		_paint(s)
		s.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE # meteen een eerste beeld


## Namen van de schermen die gevonden werden.
func screen_names() -> PackedStringArray:
	return PackedStringArray(_screens.keys())


## Voor tests: alle tekst die nu op een scherm staat (bijgewerkt naar de huidige toestand).
func screen_text(key: String) -> String:
	var s: Screen = _screens.get(key)
	if s == null:
		return ""
	_paint(s)
	var parts := PackedStringArray()
	for l: Label in s.root.find_children("*", "Label", true, false):
		if l.is_visible_in_tree() and l.text != "":
			parts.append(l.text)
	return " | ".join(parts)


## Waar een scherm hangt (wereldruimte): midden, normaal (naar de kijker), breedte en hoogte (m).
## Handig voor camera's in previews of een prompt bij het scherm.
func screen_info(key: String) -> Dictionary:
	var s: Screen = _screens.get(key)
	if s == null or not s.mesh.is_inside_tree():
		return {}
	var xf := s.mesh.global_transform
	return {"center": xf * s.local_center, "normal": (xf.basis * s.local_normal).normalized(), "width": s.width, "height": s.height}


## Voor tests: rendert dit scherm nu (zichtbaar voor de camera)?
func is_rendering(key: String) -> bool:
	var s: Screen = _screens.get(key)
	return s != null and s.seen


## Previews en tests: de tv toont dit segment en blijft erop staan (tot `tv_resume`).
func tv_show(kind: String) -> void:
	_tv_enter(kind)
	_hold = true
	_seg_time = 1.0 # geen overgang
	if _screens.has(TV):
		(_screens[TV] as Screen).dirty = true


func tv_resume() -> void:
	_hold = false


## De soort van het huidige tv-segment (news, ad, quota, ...).
func tv_segment() -> String:
	return _seg


## Een tekstregel uit hub_tv.gd met de plaatshouders ingevuld (ook voor tests).
func fill(line: String) -> String:
	return line.format(_vars())


func _process(delta: float) -> void:
	_time += delta
	_tv_tick(delta)
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	for s: Screen in _screens.values():
		s.seen = _can_see(s, cam)
		if not s.seen:
			continue
		s.timer -= delta
		if s.timer > 0.0 and not s.dirty:
			continue
		s.timer = 1.0 / s.fps
		s.dirty = false
		_paint(s)
		s.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _tv_light:
		_tv_light.visible = (_screens[TV] as Screen).seen


func _on_changed() -> void:
	for s: Screen in _screens.values():
		s.dirty = true
	if _seg in ["quota", "weather"] and not _line.is_empty():
		_tv_layout() # nieuwe cijfers in hetzelfde segment


func _on_report(_report: Dictionary) -> void:
	_report_pending = true
	if not _hold:
		_seg_left = minf(_seg_left, 1.5)
	_on_changed()


# --- Opbouw --------------------------------------------------------------------------------------

func _make(key: String, mesh: MeshInstance3D, fps: float, holo := false) -> Screen:
	var s := Screen.new()
	s.key = key
	s.mesh = mesh
	s.fps = fps
	s.two_sided = holo
	_measure(s)
	var h := int(round(WIDTH * s.height / maxf(s.width, 0.01) / 2.0)) * 2
	s.size = Vector2(WIDTH, clampi(h, 96, 720))
	s.viewport = SubViewport.new()
	s.viewport.name = key
	s.viewport.size = Vector2i(s.size)
	s.viewport.disable_3d = true
	s.viewport.transparent_bg = holo
	s.viewport.gui_disable_input = true
	s.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(s.viewport)
	s.root = Control.new()
	s.root.size = s.size
	s.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.viewport.add_child(s.root)
	var art := Art.new()
	art.size = s.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(art)
	s.art = art
	var m := ShaderMaterial.new()
	if holo:
		m.shader = HOLO_SHADER
		m.set_shader_parameter("lines", s.size.y / 2.0)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		m.shader = FEED_SHADER
		m.set_shader_parameter("tint", Color(1.0, 0.97, 0.92))
		m.set_shader_parameter("desaturate", 0.05)
		m.set_shader_parameter("vignette", 0.35)
		m.set_shader_parameter("brightness", 1.1)
		m.set_shader_parameter("lines", s.size.y / 2.0)
	m.set_shader_parameter("feed", s.viewport.get_texture())
	mesh.material_override = m
	_screens[key] = s
	return s


## Maat en richting van het vlak uit de mesh: de hoeken via de UV's (u naar rechts, v langs de
## hoogte), de normaal uit de mesh.
func _measure(s: Screen) -> void:
	var mesh := s.mesh.mesh
	var aabb := mesh.get_aabb()
	s.local_center = aabb.get_center()
	s.width = maxf(Vector2(aabb.size.x, aabb.size.z).length(), 0.1)
	s.height = maxf(aabb.size.y, 0.1)
	s.local_corners = PackedVector3Array([aabb.position, aabb.end, aabb.position + Vector3(aabb.size.x, 0, 0), aabb.position + Vector3(0, aabb.size.y, aabb.size.z)])
	if mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var normals: Variant = arrays[Mesh.ARRAY_NORMAL]
	if normals is PackedVector3Array and not (normals as PackedVector3Array).is_empty():
		s.local_normal = (normals as PackedVector3Array)[0].normalized()
	if not uvs is PackedVector2Array or (uvs as PackedVector2Array).size() != verts.size():
		return
	var corner := {}
	for i in verts.size():
		var uv: Vector2 = (uvs as PackedVector2Array)[i]
		corner[Vector2i(int(uv.x > 0.5), int(uv.y > 0.5))] = verts[i]
	if corner.size() < 4:
		return
	var basis := s.mesh.global_basis if s.mesh.is_inside_tree() else s.mesh.basis
	var p00: Vector3 = corner[Vector2i(0, 0)]
	s.width = (basis * (corner[Vector2i(1, 0)] - p00)).length()
	s.height = (basis * (corner[Vector2i(0, 1)] - p00)).length()
	s.local_corners = PackedVector3Array([p00, corner[Vector2i(1, 0)], corner[Vector2i(1, 1)], corner[Vector2i(0, 1)]])
	s.local_center = (p00 + corner[Vector2i(1, 0)] + corner[Vector2i(1, 1)] + corner[Vector2i(0, 1)]) / 4.0


## Kan de camera dit scherm zien (dichtbij genoeg, in beeld, van voren)?
func _can_see(s: Screen, cam: Camera3D) -> bool:
	if cam == null or not s.mesh.is_inside_tree() or not s.mesh.is_visible_in_tree():
		return false
	var xf := s.mesh.global_transform
	var center := xf * s.local_center
	var to_cam := cam.global_position - center
	var dist := to_cam.length()
	if dist > s.width * VIEW_RANGE:
		return false
	if not s.two_sided and (xf.basis * s.local_normal).dot(to_cam) <= 0.0:
		return false
	if dist < s.width or cam.is_position_in_frustum(center):
		return true
	for p in s.local_corners:
		if cam.is_position_in_frustum(xf * p):
			return true
	return false


func _paint(s: Screen) -> void:
	match s.key:
		TV:
			_paint_tv(s)
		BOARD:
			_paint_board(s)
		TERMINAL:
			_paint_terminal(s)
		APPRAISAL:
			_paint_appraisal(s)
	s.art.queue_redraw()


func _label(s: Screen, key: String, font: Font, size: int, color: Color, pos: Vector2, box := Vector2.ZERO,
		align := HORIZONTAL_ALIGNMENT_LEFT, wrap := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -int(size * 0.12) if font == UiTheme.screen() else -int(size * 0.3))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else s.root).add_child(l)
	l.position = pos
	if box != Vector2.ZERO:
		l.size = box
	s.labels[key] = l
	return l


func _text(s: Screen, key: String, text: String) -> void:
	var l: Label = s.labels[key]
	if l.text != text:
		l.text = text


## Afgeronde rechthoek.
func _rrect(c: CanvasItem, r: Rect2, col: Color, radius := 6) -> void:
	_box.bg_color = col
	_box.set_corner_radius_all(radius)
	c.draw_style_box(_box, r)


## Geel-zwarte schuine strepen (huisstijl), binnen `r`.
func _stripes(c: CanvasItem, r: Rect2, a: Color, b: Color, stripe := 12.0, offset := 0.0) -> void:
	c.draw_rect(r, b)
	var h := r.size.y
	var x := r.position.x - h - stripe * 2.0 + fposmod(offset, stripe * 2.0)
	while x < r.end.x:
		var pts := _clip_x(PackedVector2Array([Vector2(x, r.end.y), Vector2(x + h, r.position.y), Vector2(x + h + stripe, r.position.y), Vector2(x + stripe, r.end.y)]), r.position.x, r.end.x)
		if pts.size() >= 3 and absf(_area(pts)) > 1.0:
			c.draw_colored_polygon(pts, a)
		x += stripe * 2.0


## Een bolle veelhoek afsnijden tussen x0 en x1 (Sutherland-Hodgman).
static func _clip_x(poly: PackedVector2Array, x0: float, x1: float) -> PackedVector2Array:
	var out := poly
	for side in 2:
		var src := out
		out = PackedVector2Array()
		var edge := x0 if side == 0 else x1
		for i in src.size():
			var p := src[i]
			var q := src[(i + 1) % src.size()]
			var p_in := p.x >= edge if side == 0 else p.x <= edge
			var q_in := q.x >= edge if side == 0 else q.x <= edge
			if p_in:
				out.append(p)
			if p_in != q_in:
				out.append(p.lerp(q, (edge - p.x) / (q.x - p.x)))
		if out.size() < 3:
			return PackedVector2Array()
	return out


static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0


func _gradient(c: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))


func _blink(period := 1.0, on := 0.6) -> bool:
	return fmod(_time, period) < period * on


# --- Toestand en tekst ---------------------------------------------------------------------------

func _company() -> Company:
	return game.company


func _shifts() -> int:
	return Tuning.get_i("company", "shifts", 3)


## Getal met een decimale punt: 1.20.
static func _num(v: float, decimals := 2) -> String:
	return ("%." + str(decimals) + "f") % v


func _planet_name() -> String:
	return PlanetType.NAMES[clampi(int(game.planet_type), 0, PlanetType.NAMES.size() - 1)]


func _surface_temp() -> int:
	return -18 - int(game.pit_seed) % 37


## Plaatshouders voor de teksten van de tv (zie hub_tv.gd).
func _vars() -> Dictionary:
	var c := _company()
	var chosen := c.contract_ready()
	return {
		"planet": _planet_name(),
		"cash": UiTheme.euro(c.cash),
		"earned": UiTheme.euro(c.earned),
		"quota": UiTheme.euro(c.quota()),
		"quarter": c.quarter,
		"shift": c.shift,
		"shifts": _shifts(),
		"left": maxi(1, _shifts() - c.shift + 1),
		"rep": "%+d" % c.reputation,
		"contract": str(c.contract.name) if chosen else "not chosen yet",
		"risk": Company.RISK_NAMES[int(c.contract.risk)].to_lower() if chosen else "unknown",
		"magma": _num(c.contract_magma()),
		"replacement": UiTheme.euro(Tuning.get_i("company", "replacement_cost", 120)),
		"robots": clampi(game.players.get_child_count(), 1, 4) if game.players else 1,
		"temp": "%d°C" % _surface_temp(),
		"share": UiTheme.euro(int(_share)),
		"up": _num(_share_up, 1),
		"down": _num(_share_down, 1),
	}


## Willekeurige regel uit een lijst, nooit twee keer na elkaar dezelfde; ingevuld en in delen ("|").
func _pick(kind: String, list: Array[String]) -> PackedStringArray:
	var i := _rng.randi_range(0, list.size() - 1)
	if list.size() > 1 and i == int(_last_pick.get(kind, -1)):
		i = (i + 1) % list.size()
	_last_pick[kind] = i
	return fill(list[i]).split("|")


# --- Tv: DIG-nieuws ------------------------------------------------------------------------------

func _build_tv(s: Screen) -> void:
	var w := s.size.x
	var h := s.size.y
	(s.art as Art).painter = _draw_tv
	var kicker := PanelContainer.new()
	var kb := StyleBoxFlat.new()
	kb.set_corner_radius_all(4)
	kb.content_margin_left = 10
	kb.content_margin_right = 10
	kb.content_margin_top = 2
	kb.content_margin_bottom = 2
	kicker.add_theme_stylebox_override("panel", kb)
	kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(kicker)
	s.labels["kicker_box"] = kicker
	_label(s, "kicker", UiTheme.heading(), 17, UiTheme.ANTHRACITE, Vector2.ZERO, Vector2.ZERO, HORIZONTAL_ALIGNMENT_LEFT, false, kicker)
	_label(s, "big", UiTheme.heading(), 40, UiTheme.YELLOW, Vector2.ZERO, Vector2(w, 50), HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(s, "head", UiTheme.screen(), 40, UiTheme.CREAM, Vector2.ZERO, Vector2(w, 50), HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(s, "sub", UiTheme.screen(), 28, UiTheme.CREAM_DIM, Vector2.ZERO, Vector2(w, 30), HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(s, "small", UiTheme.screen(), 24, UiTheme.AMBER, Vector2.ZERO, Vector2(w, 30), HORIZONTAL_ALIGNMENT_LEFT, true)
	_label(s, "price", UiTheme.heading(), 22, UiTheme.CREAM, Vector2.ZERO, Vector2(150, 70), HORIZONTAL_ALIGNMENT_CENTER, true)
	# Bovenaan: LIVE en de klok; rechts het logo van de zender (de "bug").
	_label(s, "live", UiTheme.heading(), 15, UiTheme.CREAM, Vector2(34, 12))
	_label(s, "clock", UiTheme.screen(), 26, UiTheme.CREAM, Vector2(84, 6))
	_label(s, "bug", UiTheme.heading(), 22, UiTheme.ANTHRACITE, Vector2(w - 86, 10), Vector2(70, 30), HORIZONTAL_ALIGNMENT_CENTER)
	_label(s, "bug2", UiTheme.screen(), 18, UiTheme.ANTHRACITE, Vector2(w - 86, 36), Vector2(70, 18), HORIZONTAL_ALIGNMENT_CENTER)
	(s.labels["live"] as Label).text = "LIVE"
	(s.labels["bug"] as Label).text = "DIG"
	(s.labels["bug2"] as Label).text = "NEWS"
	# Lopende balk onderaan.
	_label(s, "tag", UiTheme.heading(), 16, UiTheme.ANTHRACITE, Vector2(0, h - TICKER_H + 9), Vector2(108, 24), HORIZONTAL_ALIGNMENT_CENTER)
	(s.labels["tag"] as Label).text = "DIG 24"
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(108, h - TICKER_H)
	clip.size = Vector2(w - 108, TICKER_H)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(clip)
	_label(s, "ticker", UiTheme.screen(), 30, UiTheme.CREAM, Vector2(0, 3), Vector2.ZERO, HORIZONTAL_ALIGNMENT_LEFT, false, clip)
	_ticker_x = clip.size.x
	_ticker_text()
	# Overgang tussen segmenten: een gele veeg (bovenop alles).
	var over := Art.new()
	over.size = s.size
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.painter = _draw_tv_over
	s.root.add_child(over)
	s.labels["over"] = over
	# Wat licht van de tv in de kamer.
	_tv_light = OmniLight3D.new()
	_tv_light.name = "TvLight"
	_tv_light.light_energy = 0.5
	_tv_light.omni_range = 5.0
	_tv_light.shadow_enabled = false
	_tv_light.light_volumetric_fog_energy = 0.0
	s.mesh.add_child(_tv_light)
	_tv_light.position = s.local_center + s.local_normal * 0.9


func _ticker_text() -> void:
	var lines: Array[String] = TEXTS.TICKER.duplicate()
	var order: Array = range(lines.size())
	order.shuffle()
	var parts := PackedStringArray()
	for i: int in order.slice(0, 8):
		parts.append(fill(lines[i]).to_upper())
	var text := "      ·      ".join(parts) + "      ·      "
	if _screens.has(TV):
		var l: Label = (_screens[TV] as Screen).labels["ticker"]
		l.text = text
		_ticker_w = UiTheme.screen().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		l.size = Vector2(_ticker_w + 8.0, TICKER_H)


func _tv_tick(delta: float) -> void:
	if not _screens.has(TV):
		return
	_seg_time += delta
	_ticker_x -= TICKER_SPEED * delta
	if _ticker_x < -_ticker_w:
		_ticker_text()
		_ticker_x = (_screens[TV] as Screen).size.x - 108.0
	if _hold:
		return
	_seg_left -= delta
	if _seg_left <= 0.0:
		_tv_next()


func _tv_next() -> void:
	if _report_pending and not _company().last_report.is_empty():
		_report_pending = false
		_tv_enter("report")
	elif _since_ident >= IDENT_EVERY:
		_tv_enter("ident")
	else:
		_seg_index = (_seg_index + 1) % PLAYLIST.size()
		_tv_enter(PLAYLIST[_seg_index])


## Een nieuw segment: een regel kiezen en de labels schikken.
func _tv_enter(kind: String) -> void:
	_seg = kind
	_seg_time = 0.0
	_since_ident = 0 if kind == "ident" else _since_ident + 1
	match kind:
		"news":
			_line = _pick(kind, TEXTS.NEWS)
		"ad":
			_line = _pick(kind, TEXTS.ADS)
		"safety":
			_line = _pick(kind, TEXTS.SAFETY)
		"weather":
			_line = _pick(kind, TEXTS.WEATHER)
		"employee":
			_line = _pick(kind, TEXTS.EMPLOYEE)
		"shares":
			_share_up = _rng.randf_range(0.4, 9.9)
			_share_down = _rng.randf_range(0.5, 6.0)
			_share *= 1.0 + _share_up / 100.0
			_share_curve = PackedFloat32Array()
			var v := 0.5
			for i in 48:
				v = clampf(v + _rng.randf_range(-0.11, 0.09) + (0.03 if i > 34 else 0.0), 0.05, 0.98)
				_share_curve.append(v)
			_share_curve[_share_curve.size() - 1] = 0.97 # het eindigt altijd hoog
			_line = _pick(kind, TEXTS.SHARES)
		_:
			_line = PackedStringArray([kind])
	var chars := 0
	for p in _line:
		chars += p.length()
	_seg_left = 5.0 if kind == "ident" else clampf(SEGMENT_S.x + (chars - 40) / 15.0, SEGMENT_S.x, SEGMENT_S.y)
	if kind == "report":
		_seg_left = 13.0
	_tv_layout()


## Labels schikken voor het huidige segment (ook opnieuw als de cijfers veranderen).
func _tv_layout() -> void:
	if not _screens.has(TV):
		return
	var s: Screen = _screens[TV]
	var w := s.size.x
	var h := s.size.y
	var bottom := h - TICKER_H
	var c := _company()
	for k in ["big", "head", "sub", "small", "price"]:
		var l: Label = s.labels[k]
		l.text = ""
		l.rotation = 0.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var kicker: PanelContainer = s.labels["kicker_box"]
	kicker.visible = KICKER.has(_seg)
	if kicker.visible:
		var kk: Array = KICKER[_seg]
		(s.labels["kicker"] as Label).text = kk[0]
		(s.labels["kicker"] as Label).add_theme_color_override("font_color", kk[2])
		(kicker.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = kk[1]
		kicker.reset_size()
		kicker.position = Vector2(20, 50)
	var head: Label = s.labels["head"]
	var sub: Label = s.labels["sub"]
	var big: Label = s.labels["big"]
	var small: Label = s.labels["small"]
	_style(head, UiTheme.screen(), 40, UiTheme.CREAM)
	_style(sub, UiTheme.screen(), 28, UiTheme.CREAM_DIM)
	_style(big, UiTheme.heading(), 40, UiTheme.YELLOW)
	_style(small, UiTheme.screen(), 24, UiTheme.AMBER)
	match _seg:
		"ident":
			_place(big, "DIG", Rect2(0, 108, w, 90), HORIZONTAL_ALIGNMENT_CENTER)
			_style(big, UiTheme.heading(), 72, UiTheme.YELLOW)
			_place(sub, "DIEPGANG INTERPLANETARY GROUNDWORKS", Rect2(0, 250, w, 28), HORIZONTAL_ALIGNMENT_CENTER)
			_style(sub, UiTheme.screen(), 28, UiTheme.CREAM)
			_place(small, "We dig, you pay.", Rect2(0, 276, w, 26), HORIZONTAL_ALIGNMENT_CENTER)
		"news", "report":
			kicker.position = Vector2(20, 176)
			if _seg == "report":
				var r := c.last_report
				var replaced := int(r.get("left_behind", 0)) + int(r.get("melted", 0))
				_line = PackedStringArray(["Shift %d complete: net %s" % [int(r.get("shift_total", 0)), UiTheme.euro(int(r.get("net", 0)))],
						("%d %s replaced. Disappointing, not surprising." % [replaced, "robot" if replaced == 1 else "robots"]) if replaced > 0
						else "Nobody replaced. Head office suspects fraud."])
				var result := str(r.get("quarter_result", ""))
				var verdict := "QUOTA MET\nREPUTATION +1" if result == "gehaald" else (
						"QUOTA MISSED\nFINE %s" % UiTheme.euro(int(r.get("fine", 0))) if result == "gemist" else
						"QUARTER %d\nSHIFT %d/%d" % [c.quarter, c.shift, _shifts()])
				_place(small, verdict, Rect2(40, 74, 270, 80), HORIZONTAL_ALIGNMENT_CENTER)
				_style(small, UiTheme.screen(), 34, UiTheme.CREAM)
			_style(head, UiTheme.screen(), 38, UiTheme.CREAM)
			_place(head, _line[0], Rect2(24, 0, w - 48, 40))
			_style(sub, UiTheme.screen(), 26, UiTheme.CREAM_DIM)
			_place(sub, _line[1] if _line.size() > 1 else "", Rect2(24, 0, w - 48, 28))
			_stack([head, sub], 202, bottom - 4, 2)
		"ad":
			_style(big, UiTheme.heading(), 40 if _line[0].length() <= 14 else 32, UiTheme.ANTHRACITE)
			_place(big, _line[0], Rect2(20, 86, w - 40, 50))
			_style(head, UiTheme.screen(), 36, UiTheme.ANTHRACITE)
			_place(head, _line[1] if _line.size() > 1 else "", Rect2(20, _below(big, 10.0), 380, 80))
			_place(small, SMALL_PRINT[_rng.randi_range(0, SMALL_PRINT.size() - 1)], Rect2(20, bottom - 30, 400, 24))
			_style(small, UiTheme.screen(), 20, UiTheme.ANTHRACITE_HI)
			var price: Label = s.labels["price"]
			price.text = _line[2] if _line.size() > 2 else ""
			price.add_theme_font_size_override("font_size", 22 if price.text.length() <= 8 else 15)
			price.size = Vector2(130, 70)
			price.position = Vector2(w - 120 - 65, bottom - 104 - 35)
			price.pivot_offset = price.size / 2.0
			price.rotation = -0.15
			price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		"quota":
			var q := c.quota()
			_place(head, "Quarter %d: %s of %s" % [c.quarter, UiTheme.euro(c.earned), UiTheme.euro(q)], Rect2(24, 88, w - 48, 44))
			_style(head, UiTheme.screen(), 46, UiTheme.CREAM)
			_place(sub, "Head office is watching.", Rect2(24, 136, w - 48, 30))
			_style(sub, UiTheme.screen(), 30, UiTheme.AMBER)
			var ratio := float(c.earned) / maxf(1.0, q)
			_place(big, "%d%%" % int(clampf(ratio, 0.0, 9.99) * 100.0), Rect2(w - 224, 150, 200, 40), HORIZONTAL_ALIGNMENT_RIGHT)
			_style(big, UiTheme.heading(), 28, UiTheme.GOOD if ratio >= 1.0 else UiTheme.YELLOW)
			var remark: String = TEXTS.QUOTA_REMARKS[3 if ratio >= 1.0 else clampi(int(ratio * 3.0), 0, 2)]
			if c.cash < 0:
				remark = "Debt: %s. Head office has noticed." % UiTheme.euro(c.cash)
			_place(small, "SHIFT %d/%d  ·  %s" % [c.shift, _shifts(), remark], Rect2(24, 244, w - 48, 56))
			_style(small, UiTheme.screen(), 26, UiTheme.CREAM)
		"employee":
			var f := _employee_frame(w)
			_place(big, "VACANT", Rect2(f.get_center().x - 120, f.get_center().y - 25, 240, 50), HORIZONTAL_ALIGNMENT_CENTER)
			_style(big, UiTheme.heading(), 34, UiTheme.DANGER)
			big.pivot_offset = Vector2(120, 25)
			big.rotation = -0.22
			_style(head, UiTheme.screen(), 42, UiTheme.CREAM)
			_place(head, "Quarter %d: the spot remains empty." % c.quarter, Rect2(24, 100, f.position.x - 48, 90))
			_style(sub, UiTheme.screen(), 30, UiTheme.AMBER)
			_place(sub, _line[0], Rect2(24, _below(head, 14.0), f.position.x - 48, 90))
		"weather":
			_place(big, _planet_name().to_upper(), Rect2(286, 88, w - 300, 40))
			_style(big, UiTheme.heading(), 30, UiTheme.CREAM)
			_place(head, _line[0], Rect2(286, 128, w - 306, 70))
			_style(head, UiTheme.screen(), 32, UiTheme.CREAM)
			_place(sub, _line[1] if _line.size() > 1 else "", Rect2(286, 196, w - 306, 50))
			_style(sub, UiTheme.screen(), 24, UiTheme.CREAM_DIM)
			var risk := ("  (RISK %s)" % Company.RISK_NAMES[int(c.contract.risk)]) if c.contract_ready() else ""
			_place(small, "SURFACE %d°C\nMAGMA ×%s%s" % [_surface_temp(), _num(c.contract_magma()), risk], Rect2(286, 246, w - 300, 56))
			_style(small, UiTheme.screen(), 28, UiTheme.AMBER)
		"shares":
			_style(big, UiTheme.heading(), 24, UiTheme.GOOD)
			_place(big, "DIG +%s%%" % _num(_share_up, 1), Rect2(20 + kicker.size.x + 14, 52, 260, 34))
			_style(head, UiTheme.screen(), 36, UiTheme.CREAM)
			_place(head, _line[0], Rect2(24, 96, w - 48, 40))
			_style(sub, UiTheme.screen(), 26, UiTheme.CREAM_DIM)
			_place(sub, _line[1] if _line.size() > 1 else "", Rect2(24, _below(head, 4.0), w - 48, 30))
		"safety":
			_style(head, UiTheme.screen(), 40, UiTheme.CREAM)
			_place(head, _line[0], Rect2(208, 0, w - 228, 40))
			_style(sub, UiTheme.screen(), 30, UiTheme.AMBER)
			_place(sub, _line[1] if _line.size() > 1 else "", Rect2(208, 0, w - 228, 40))
			_stack([head, sub], 80, bottom - 24, 16)
	s.dirty = true


## Onderkant van de tekst van een label (+ marge): om het volgende label eronder te zetten.
func _below(l: Label, gap: float) -> float:
	return l.position.y + _text_h(l) + gap


func _text_h(l: Label) -> float:
	if l.text == "":
		return 0.0
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	return maxi(1, l.get_line_count()) * (f.get_height(fs) + l.get_theme_constant("line_spacing"))


## Labels onder elkaar, als blok verticaal in het midden tussen `top` en `bottom`.
func _stack(labels: Array[Label], top: float, bottom: float, gap: float) -> void:
	var total := -gap
	for l in labels:
		total += _text_h(l) + gap
	var y := top + maxf(0.0, (bottom - top - total) / 2.0)
	for l in labels:
		l.position.y = y
		y += _text_h(l) + gap


## Het fotolijstje van de werknemer van het kwartaal (rechts op de tv).
func _employee_frame(w: float) -> Rect2:
	return Rect2(w - 236, 58, 168, 196)


func _style(l: Label, font: Font, size: int, color: Color) -> void:
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", -int(size * 0.12) if font == UiTheme.screen() else -int(size * 0.3))


func _place(l: Label, text: String, r: Rect2, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	l.text = text
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align


func _paint_tv(s: Screen) -> void:
	var t := Time.get_time_dict_from_system()
	var c := _company()
	_text(s, "clock", "%02d:%02d  ·  Q%d  ·  SHIFT %d/%d" % [t.hour, t.minute, c.quarter, c.shift, _shifts()])
	(s.labels["ticker"] as Label).position.x = roundf(_ticker_x)
	var kicker: PanelContainer = s.labels["kicker_box"]
	if _seg == "report":
		kicker.modulate.a = 1.0 if _blink(0.8) else 0.25
	else:
		kicker.modulate.a = 1.0
	(s.labels["over"] as Control).queue_redraw()
	if _tv_light:
		_tv_light.light_color = _tv_tone()


## Kleur van het licht dat de tv in de kamer werpt (ongeveer de achtergrond van het segment).
func _tv_tone() -> Color:
	match _seg:
		"ad", "ident", "employee":
			return Color(1.0, 0.75, 0.3)
		"safety", "report":
			return Color(1.0, 0.4, 0.25)
		"shares", "weather":
			return Color(0.6, 0.9, 0.7)
		_:
			return Color(0.55, 0.7, 1.0)


func _draw_tv(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var bottom := h - TICKER_H
	match _seg:
		"ident":
			c.draw_rect(Rect2(0, 0, w, h), UiTheme.YELLOW_LO)
			var center := Vector2(w / 2.0, 150)
			var n := 18
			for i in n:
				var a0 := _time * 0.25 + TAU * i / n
				var a1 := a0 + TAU / n / 2.0
				c.draw_colored_polygon(PackedVector2Array([center, center + Vector2.from_angle(a0) * 900.0, center + Vector2.from_angle(a1) * 900.0]), UiTheme.YELLOW)
			c.draw_circle(center, 96, UiTheme.ANTHRACITE_LO)
			c.draw_arc(center, 96, 0, TAU, 64, UiTheme.YELLOW_HI, 6, true)
			c.draw_rect(Rect2(0, 246, w, 60), Color(UiTheme.ANTHRACITE_LO, 0.92))
		"news", "report":
			var alarm := _seg == "report"
			_gradient(c, Rect2(0, 0, w, bottom), Color("#3b1712") if alarm else Color("#24324a"), Color("#120807") if alarm else Color("#0d1118"))
			# Scherm achter de presentator: het logo van het programma, of de uitslag.
			_rrect(c, Rect2(24, 56, 304, 112), Color("#08121c") if not alarm else Color("#1c0806"), 6)
			for i in 9:
				c.draw_line(Vector2(24 + 34 * i, 56), Vector2(24 + 34 * i, 168), Color(1, 1, 1, 0.04), 1)
			if not alarm:
				c.draw_string(UiTheme.heading(), Vector2(62, 124), "DIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 46, UiTheme.YELLOW)
				c.draw_string(UiTheme.screen(), Vector2(190, 108), "NEWS", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UiTheme.CREAM)
				c.draw_string(UiTheme.screen(), Vector2(190, 132), "hourly, even if", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM_DIM)
				c.draw_string(UiTheme.screen(), Vector2(190, 150), "nobody watches", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.CREAM_DIM)
			_draw_anchor(c, Vector2(w - 128, 44), alarm)
			# Desk en de onderste band.
			c.draw_rect(Rect2(w - 262, 148, 262, 30), UiTheme.ANTHRACITE)
			c.draw_rect(Rect2(w - 262, 148, 262, 4), UiTheme.DANGER if alarm else UiTheme.YELLOW)
			c.draw_string(UiTheme.heading(), Vector2(w - 152, 172), "DIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiTheme.YELLOW, 0.8))
			c.draw_rect(Rect2(0, 190, w, bottom - 190), Color(0.05, 0.055, 0.07, 0.96))
			c.draw_rect(Rect2(0, 190, 8, bottom - 190), UiTheme.DANGER if alarm else UiTheme.YELLOW)
		"ad":
			c.draw_rect(Rect2(0, 0, w, bottom), UiTheme.YELLOW)
			var x := -bottom + fposmod(_time * 20.0, 48.0)
			while x < w:
				c.draw_colored_polygon(PackedVector2Array([Vector2(x, bottom), Vector2(x + bottom, 0), Vector2(x + bottom + 20, 0), Vector2(x + 20, bottom)]), Color(UiTheme.YELLOW_HI, 0.55))
				x += 48.0
			var star := Vector2(w - 120, bottom - 104)
			var pts := PackedVector2Array()
			for i in 32:
				var a := _time * 0.4 + TAU * i / 32.0
				pts.append(star + Vector2.from_angle(a) * (82.0 if i % 2 == 0 else 64.0))
			c.draw_colored_polygon(pts, UiTheme.DANGER)
			c.draw_circle(star, 58, Color(UiTheme.DANGER.darkened(0.15)))
		"quota":
			c.draw_rect(Rect2(0, 0, w, bottom), Color("#11161c"))
			for gx in range(0, int(w), 32):
				c.draw_line(Vector2(gx, 0), Vector2(gx, bottom), Color(1, 1, 1, 0.035))
			for gy in range(0, int(bottom), 32):
				c.draw_line(Vector2(0, gy), Vector2(w, gy), Color(1, 1, 1, 0.035))
			var co := _company()
			var ratio := clampf(float(co.earned) / maxf(1.0, co.quota()), 0.0, 1.0)
			_bar(c, Rect2(24, 194, w - 48, 38), ratio, UiTheme.GOOD if ratio >= 1.0 else UiTheme.YELLOW, _shifts())
		"employee":
			_gradient(c, Rect2(0, 0, w, bottom), Color("#33230f"), Color("#100a05"))
			var f := _employee_frame(w)
			var sx := f.get_center().x
			c.draw_colored_polygon(PackedVector2Array([Vector2(sx - 30, 0), Vector2(sx + 30, 0), Vector2(sx + 130, bottom), Vector2(sx - 130, bottom)]), Color(1.0, 0.9, 0.6, 0.07))
			_rrect(c, f, Color("#c9a227"), 4)
			_rrect(c, f.grow(-12), Color("#1a1410"), 2)
			var mid := f.get_center()
			c.draw_rect(Rect2(mid.x - 34, mid.y - 62, 68, 52), Color(UiTheme.CREAM_DIM, 0.25), false, 2.0)
			c.draw_rect(Rect2(mid.x - 48, mid.y - 2, 96, 70), Color(UiTheme.CREAM_DIM, 0.25), false, 2.0)
			c.draw_string(UiTheme.heading(), Vector2(mid.x - 10, mid.y - 26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(UiTheme.CREAM_DIM, 0.35))
			_rrect(c, Rect2(mid.x - 60, f.end.y + 2, 120, 16), Color("#c9a227"), 2)
			c.draw_string(UiTheme.screen(), Vector2(mid.x - 60, f.end.y + 15), "QUARTER %d" % _company().quarter, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, UiTheme.ANTHRACITE_LO)
		"weather":
			var sky: Dictionary = PlanetType.params(game.planet_type).get("sky", {})
			_gradient(c, Rect2(0, 0, w, bottom), sky.get("zenith", Color("#a0705f")), sky.get("horizon", Color("#e8c49a")))
			var pc := Vector2(146, 190)
			var ground: Color = sky.get("ground_lit", Color("#b5532e"))
			c.draw_circle(pc, 96, Color(sky.get("ground_shadow", Color("#5a2e35"))))
			c.draw_circle(pc + Vector2(-10, -8), 86, ground)
			c.draw_arc(pc, 96, deg_to_rad(25), deg_to_rad(155), 32, UiTheme.DANGER, 7, true)
			for i in 3:
				var y := 150 + i * 34 + sin(_time * 0.8 + i) * 6
				c.draw_arc(pc + Vector2(-20 + i * 14, y - 190), 70 + i * 12, deg_to_rad(200), deg_to_rad(250), 12, Color(1, 1, 1, 0.25), 3, true)
			_rrect(c, Rect2(270, 80, w - 284, bottom - 90), Color(0.04, 0.03, 0.03, 0.62), 8)
		"shares":
			c.draw_rect(Rect2(0, 0, w, bottom), Color("#0d1411"))
			var r := Rect2(24, 186, w - 48, bottom - 196)
			for i in 5:
				var gy := r.position.y + r.size.y * i / 4.0
				c.draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), Color(1, 1, 1, 0.06))
			if _share_curve.size() > 1:
				var pts := PackedVector2Array()
				for i in _share_curve.size():
					pts.append(Vector2(r.position.x + r.size.x * i / (_share_curve.size() - 1.0), r.end.y - r.size.y * _share_curve[i]))
				var fill_pts := pts.duplicate()
				fill_pts.append(r.end)
				fill_pts.append(Vector2(r.position.x, r.end.y))
				c.draw_colored_polygon(fill_pts, Color(UiTheme.GOOD, 0.14))
				c.draw_polyline(pts, UiTheme.GOOD, 3.0, true)
				c.draw_circle(pts[pts.size() - 1], 6.0 if _blink(0.6) else 4.0, UiTheme.CREAM)
		"safety":
			c.draw_rect(Rect2(0, 0, w, bottom), UiTheme.ANTHRACITE)
			_stripes(c, Rect2(0, bottom - 14, w, 14), UiTheme.DANGER, UiTheme.ANTHRACITE_LO, 12.0, _time * 18.0)
			var tc := Vector2(108, 170)
			c.draw_colored_polygon(PackedVector2Array([tc + Vector2(0, -80), tc + Vector2(82, 64), tc + Vector2(-82, 64)]), UiTheme.YELLOW)
			c.draw_colored_polygon(PackedVector2Array([tc + Vector2(0, -56), tc + Vector2(60, 50), tc + Vector2(-60, 50)]), UiTheme.ANTHRACITE_LO)
			c.draw_rect(Rect2(tc.x - 6, tc.y - 28, 12, 46), UiTheme.YELLOW)
			c.draw_circle(tc + Vector2(0, 34), 7, UiTheme.YELLOW)
	# Bovenaan: LIVE (knipperend rood bolletje), de klok en het logo van de zender.
	_rrect(c, Rect2(8, 6, 392, 32), Color(0.03, 0.03, 0.04, 0.72), 5)
	c.draw_circle(Vector2(23, 22), 6, UiTheme.DANGER if _blink(1.2) else UiTheme.DANGER.darkened(0.7))
	_rrect(c, Rect2(w - 88, 6, 74, 54), UiTheme.ANTHRACITE_LO, 8)
	_rrect(c, Rect2(w - 86, 8, 70, 50), UiTheme.YELLOW, 6)
	# Lopende balk.
	c.draw_rect(Rect2(0, bottom, w, TICKER_H), UiTheme.ANTHRACITE_LO)
	c.draw_rect(Rect2(0, bottom, w, 2), UiTheme.STEEL)
	c.draw_rect(Rect2(0, bottom, 108, TICKER_H), UiTheme.YELLOW)


## Overgang tussen segmenten: een gele veeg met strepen, een halve seconde.
func _draw_tv_over(c: Control) -> void:
	var k := _seg_time / 0.45
	if k >= 1.0:
		return
	var w := c.size.x
	var x := lerpf(-w * 0.6, w * 1.1, k)
	c.draw_rect(Rect2(x, 0, w * 0.5, c.size.y), UiTheme.YELLOW)
	_stripes(c, Rect2(x + w * 0.5, 0, 26, c.size.y), UiTheme.YELLOW, UiTheme.ANTHRACITE_LO, 10.0)
	c.draw_string(UiTheme.heading(), Vector2(x + 20, c.size.y / 2.0 + 18), "DIG", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UiTheme.ANTHRACITE)


## Het robotje dat het nieuws leest (vanaf de bovenkant van zijn hoofd `p`).
func _draw_anchor(c: Control, p: Vector2, alarm: bool) -> void:
	var x := p.x
	var y := p.y
	c.draw_line(Vector2(x, y + 2), Vector2(x, y - 14), UiTheme.STEEL, 3.0)
	c.draw_circle(Vector2(x, y - 17), 5.0, UiTheme.DANGER if _blink(0.9) else UiTheme.DANGER.darkened(0.6))
	_rrect(c, Rect2(x - 54, y + 64, 108, 70), UiTheme.ANTHRACITE_HI, 12)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x - 8, y + 66), Vector2(x + 8, y + 66), Vector2(x + 5, y + 92), Vector2(x, y + 98), Vector2(x - 5, y + 92)]), UiTheme.DANGER if alarm else UiTheme.YELLOW)
	_rrect(c, Rect2(x - 50, y, 100, 68), UiTheme.YELLOW, 12)
	c.draw_circle(Vector2(x - 50, y + 34), 7.0, UiTheme.STEEL)
	c.draw_circle(Vector2(x + 50, y + 34), 7.0, UiTheme.STEEL)
	_rrect(c, Rect2(x - 40, y + 12, 80, 42), UiTheme.ANTHRACITE_LO, 9)
	var blink := fmod(_time, 3.7) < 0.13
	var eye := UiTheme.DANGER if alarm else UiTheme.CYAN
	var eh := 3.0 if blink else (20.0 if alarm else 16.0)
	for ex: float in [-17.0, 17.0]:
		_rrect(c, Rect2(x + ex - 7, y + 28 - eh / 2.0, 14, eh), eye, 3)
	var talk := absf(sin(_time * 11.0) * sin(_time * 3.7))
	c.draw_rect(Rect2(x - 9, y + 45 - 3.0 * talk, 18, 2.0 + 5.0 * talk), eye)


## Voortgangsbalk met streepjes per dienst.
func _bar(c: CanvasItem, r: Rect2, ratio: float, col: Color, parts: int) -> void:
	_rrect(c, r, UiTheme.ANTHRACITE_HI, 5)
	if ratio > 0.0:
		_rrect(c, Rect2(r.position, Vector2(maxf(10.0, r.size.x * ratio), r.size.y)), col, 5)
		var gx := r.position.x + fposmod(_time * 120.0, r.size.x * ratio + 60.0) - 30.0
		if gx > r.position.x and gx < r.position.x + r.size.x * ratio - 8.0:
			c.draw_rect(Rect2(gx, r.position.y + 3, 8, r.size.y - 6), Color(1, 1, 1, 0.25))
	for i in range(1, parts):
		var px := r.position.x + r.size.x * i / parts
		c.draw_line(Vector2(px, r.position.y - 4), Vector2(px, r.end.y + 4), UiTheme.ANTHRACITE_LO, 3.0)


# --- Firmabord -----------------------------------------------------------------------------------

const BOARD_TILES := [["cash", "FUNDS"], ["rep", "REPUTATION"], ["quarter", "QUARTER · SHIFT"]]


func _build_board(s: Screen) -> void:
	var w := s.size.x
	(s.art as Art).painter = _draw_board
	_label(s, "title", UiTheme.heading(), 26, UiTheme.ANTHRACITE, Vector2(18, 8)).text = "DIG · COMPANY BOARD"
	_label(s, "status", UiTheme.screen(), 26, UiTheme.ANTHRACITE, Vector2(w - 236, 12), Vector2(218, 28), HORIZONTAL_ALIGNMENT_RIGHT)
	var tw := (w - 32 - 24) / 3.0
	for i in BOARD_TILES.size():
		var x := 16 + i * (tw + 12)
		_label(s, "cap_" + BOARD_TILES[i][0], UiTheme.screen(), 22, UiTheme.CREAM_DIM, Vector2(x + 14, 70)).text = BOARD_TILES[i][1]
		_label(s, BOARD_TILES[i][0], UiTheme.heading(), 30, UiTheme.YELLOW, Vector2(x + 14, 94), Vector2(tw - 20, 44))
	_label(s, "cap_quota", UiTheme.screen(), 24, UiTheme.CREAM_DIM, Vector2(16, 156)).text = "QUOTA THIS QUARTER"
	_label(s, "quota", UiTheme.screen(), 30, UiTheme.CREAM, Vector2(w - 336, 152), Vector2(320, 32), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(s, "remark", UiTheme.screen(), 24, UiTheme.AMBER, Vector2(16, 222), Vector2(w - 32, 26))
	_label(s, "cap_contract", UiTheme.screen(), 24, UiTheme.CREAM_DIM, Vector2(16, 264)).text = "CONTRACT"
	_label(s, "contract", UiTheme.screen(), 30, UiTheme.CREAM, Vector2(150, 260), Vector2(w - 166, 32))
	_label(s, "cap_last", UiTheme.screen(), 24, UiTheme.CREAM_DIM, Vector2(16, 302)).text = "LAST SHIFT"
	_label(s, "last", UiTheme.screen(), 30, UiTheme.CREAM, Vector2(150, 298), Vector2(w - 166, 32))


func _paint_board(s: Screen) -> void:
	var c := _company()
	var q := c.quota()
	_text(s, "status", "Q%d  ·  SHIFT %d/%d" % [c.quarter, c.shift, _shifts()])
	_text(s, "cash", UiTheme.euro(c.cash))
	(s.labels["cash"] as Label).add_theme_color_override("font_color", UiTheme.DANGER if c.cash < 0 else UiTheme.YELLOW)
	_text(s, "rep", "%+d" % c.reputation)
	(s.labels["rep"] as Label).add_theme_color_override("font_color", UiTheme.GOOD if c.reputation > 0 else (UiTheme.DANGER if c.reputation < 0 else UiTheme.CREAM))
	_text(s, "quarter", "%d · %d/%d" % [c.quarter, c.shift, _shifts()])
	(s.labels["quarter"] as Label).add_theme_color_override("font_color", UiTheme.CREAM)
	_text(s, "quota", "%s / %s" % [UiTheme.euro(c.earned), UiTheme.euro(q)])
	var ratio := float(c.earned) / maxf(1.0, q)
	_text(s, "remark", TEXTS.QUOTA_REMARKS[3 if ratio >= 1.0 else clampi(int(ratio * 3.0), 0, 2)])
	var contract: Label = s.labels["contract"]
	if c.contract_ready():
		var risk := int(c.contract.risk)
		_text(s, "contract", "%s  ·  RISK %s" % [str(c.contract.name), Company.RISK_NAMES[risk]])
		contract.add_theme_color_override("font_color", [UiTheme.GOOD, UiTheme.YELLOW, UiTheme.DANGER][risk])
		contract.modulate.a = 1.0
	else:
		_text(s, "contract", "NOT CHOSEN YET  ·  SEE THE BRIDGE")
		contract.add_theme_color_override("font_color", UiTheme.AMBER)
		contract.modulate.a = 1.0 if _blink(1.0, 0.7) else 0.45
	var r := c.last_report
	if r.is_empty():
		_text(s, "last", "NONE YET  ·  HEAD OFFICE IS WAITING")
		(s.labels["last"] as Label).add_theme_color_override("font_color", UiTheme.CREAM_DIM)
	else:
		var net := int(r.get("net", 0))
		var replaced := int(r.get("left_behind", 0)) + int(r.get("melted", 0))
		_text(s, "last", "NET %s%s  ·  %d %s REPLACED" % ["+" if net > 0 else "", UiTheme.euro(net), replaced, "ROBOT" if replaced == 1 else "ROBOTS"])
		(s.labels["last"] as Label).add_theme_color_override("font_color", UiTheme.GOOD if net > 0 else UiTheme.DANGER)


func _draw_board(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var co := _company()
	c.draw_rect(Rect2(0, 0, w, h), Color("#121418"))
	c.draw_rect(Rect2(0, 0, w, 48), UiTheme.YELLOW)
	_stripes(c, Rect2(0, 48, w, 8), UiTheme.YELLOW, UiTheme.ANTHRACITE_LO, 10.0)
	var tw := (w - 32 - 24) / 3.0
	for i in 3:
		var x := 16 + i * (tw + 12)
		_rrect(c, Rect2(x, 66, tw, 76), UiTheme.ANTHRACITE, 6)
		c.draw_rect(Rect2(x, 66, 4, 76), UiTheme.YELLOW)
	var ratio := clampf(float(co.earned) / maxf(1.0, co.quota()), 0.0, 1.0)
	_bar(c, Rect2(16, 188, w - 32, 28), ratio, UiTheme.GOOD if ratio >= 1.0 else UiTheme.YELLOW, _shifts())
	c.draw_line(Vector2(16, 254), Vector2(w - 16, 254), Color(UiTheme.STEEL, 0.35), 2.0)
	if _blink(1.6, 0.5):
		c.draw_circle(Vector2(w - 12, h - 12), 4.0, UiTheme.GOOD)


# --- Opdrachtterminal (hologram) -----------------------------------------------------------------

const HOLO := Color("#4FE3F0")
const HOLO_DIM := Color(0.31, 0.89, 0.94, 0.75)


func _build_terminal(s: Screen) -> void:
	var w := s.size.x
	(s.art as Art).painter = _draw_terminal
	_label(s, "title", UiTheme.heading(), 28, HOLO, Vector2(0, 12), Vector2(w, 36), HORIZONTAL_ALIGNMENT_CENTER).text = "DIG · CONTRACTS"
	_label(s, "name", UiTheme.screen(), 64, HOLO, Vector2(0, 58), Vector2(w, 60), HORIZONTAL_ALIGNMENT_CENTER)
	_label(s, "where", UiTheme.screen(), 28, HOLO_DIM, Vector2(0, 118), Vector2(w, 30), HORIZONTAL_ALIGNMENT_CENTER)
	var cw := (w - 48) / 3.0
	for i in 3:
		_label(s, "cap%d" % i, UiTheme.screen(), 24, HOLO_DIM, Vector2(24 + i * cw, 156), Vector2(cw, 26), HORIZONTAL_ALIGNMENT_CENTER)
		_label(s, "val%d" % i, UiTheme.heading(), 24, HOLO, Vector2(24 + i * cw, 182), Vector2(cw, 34), HORIZONTAL_ALIGNMENT_CENTER)
	_label(s, "prompt", UiTheme.screen(), 28, HOLO, Vector2(28, s.size.y - 48), Vector2(w - 56, 30))


func _paint_terminal(s: Screen) -> void:
	var c := _company()
	var cursor := "_" if _blink(0.9, 0.5) else " "
	_text(s, "where", "%s  ·  QUARTER %d  ·  SHIFT %d/%d" % [_planet_name().to_upper(), c.quarter, c.shift, _shifts()])
	var name_l: Label = s.labels["name"]
	var docked: bool = game.mol == null or game.mol.mode == Mol.Mode.DOCKED
	if c.contract_ready():
		var risk := int(c.contract.risk)
		_text(s, "name", str(c.contract.name))
		name_l.modulate.a = 1.0
		_text(s, "cap0", "RISK")
		_text(s, "val0", Company.RISK_NAMES[risk])
		_text(s, "cap1", "PAYOUT")
		_text(s, "val1", "×" + _num(Company.pay_factor(risk)))
		_text(s, "cap2", "MAGMA")
		_text(s, "val2", "×" + _num(Company.magma_factor(risk)))
		# Na het kiezen laadt de nieuwe wereld: De Ekster vliegt erheen (de hendel wacht daarop).
		var loading: bool = not game.world_ready()
		var dots := ".".repeat(1 + int(_time * 2.5) % 3)
		if not docked:
			_text(s, "prompt", "> THE MOLE IS AWAY" + cursor)
		elif loading:
			_text(s, "prompt", "> EN ROUTE TO THE CLAIM" + dots)
		else:
			_text(s, "prompt", "> BOARD THE MOLE AND PULL THE LEVER" + cursor)
	else:
		_text(s, "name", "CHOOSE A CONTRACT")
		name_l.modulate.a = 1.0 if _blink(1.2, 0.7) else 0.6
		for i in 3:
			if i < c.options.size():
				var o: Dictionary = c.options[i]
				_text(s, "cap%d" % i, str(o.name))
				_text(s, "val%d" % i, Company.RISK_NAMES[int(o.risk)])
			else:
				_text(s, "cap%d" % i, "")
				_text(s, "val%d" % i, "")
		_text(s, "prompt", ("> E AT THE TABLE: CHOOSE A CONTRACT" if docked else "> WAIT FOR THE MOLE TO RETURN") + cursor)


func _draw_terminal(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var co := _company()
	# Hoeken, een lijn onder de titel, kolommen.
	var k := 26.0
	for corner: Vector2 in [Vector2(6, 6), Vector2(w - 6, 6), Vector2(w - 6, h - 6), Vector2(6, h - 6)]:
		var sx := 1.0 if corner.x < w / 2.0 else -1.0
		var sy := 1.0 if corner.y < h / 2.0 else -1.0
		c.draw_polyline(PackedVector2Array([corner + Vector2(0, sy * k), corner, corner + Vector2(sx * k, 0)]), HOLO, 3.0)
	c.draw_line(Vector2(60, 52), Vector2(w - 60, 52), HOLO_DIM, 2.0)
	var cw := (w - 48) / 3.0
	for i in range(1, 3):
		c.draw_line(Vector2(24 + i * cw, 158), Vector2(24 + i * cw, 214), Color(HOLO, 0.3), 1.0)
	c.draw_line(Vector2(60, h - 58), Vector2(w - 60, h - 58), Color(HOLO, 0.3), 1.0)
	# Risico in streepjes (1 tot 3) onder elke kolom.
	var risks: Array[int] = []
	if co.contract_ready():
		risks = [int(co.contract.risk)]
	else:
		for o: Dictionary in co.options:
			risks.append(int(o.risk))
	for i in risks.size():
		var cx := 24 + (i + 0.5) * cw if risks.size() > 1 else 24 + 0.5 * cw
		for b in 3:
			var on := b <= risks[i]
			c.draw_rect(Rect2(cx - 27 + b * 20, 220, 14, 6), HOLO if on else Color(HOLO, 0.18))


# --- Taxatie -------------------------------------------------------------------------------------

## Breedte van het linker- en rechterblok van het taxatiescherm (px).
const APPRAISAL_LEFT := 136.0
const APPRAISAL_RIGHT := 150.0


func _build_appraisal(s: Screen) -> void:
	var w := s.size.x
	var h := s.size.y
	(s.art as Art).painter = _draw_appraisal
	_label(s, "title", UiTheme.heading(), 17, UiTheme.YELLOW, Vector2(10, 14), Vector2(APPRAISAL_LEFT - 16, 28)).text = "APPRAISAL"
	_label(s, "when", UiTheme.screen(), 24, UiTheme.CREAM_DIM, Vector2(10, 44), Vector2(APPRAISAL_LEFT - 16, 60), HORIZONTAL_ALIGNMENT_LEFT, true)
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(APPRAISAL_LEFT + 8, 0)
	clip.size = Vector2(w - APPRAISAL_LEFT - APPRAISAL_RIGHT - 16, h)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(clip)
	s.labels["clip"] = clip
	_label(s, "marquee", UiTheme.screen(), 44, UiTheme.AMBER, Vector2(0, 14), Vector2(clip.size.x, 50), HORIZONTAL_ALIGNMENT_LEFT, false, clip)
	_label(s, "detail", UiTheme.screen(), 24, UiTheme.CREAM_DIM, Vector2(0, h - 54), Vector2(clip.size.x, 50), HORIZONTAL_ALIGNMENT_CENTER, true, clip)
	var rx := w - APPRAISAL_RIGHT + 8
	_label(s, "cap_total", UiTheme.screen(), 22, UiTheme.CREAM_DIM, Vector2(rx, 10), Vector2(APPRAISAL_RIGHT - 18, 24), HORIZONTAL_ALIGNMENT_RIGHT).text = "SOLD"
	_label(s, "total", UiTheme.heading(), 24, UiTheme.YELLOW, Vector2(rx - 4, 34), Vector2(APPRAISAL_RIGHT - 14, 34), HORIZONTAL_ALIGNMENT_RIGHT)
	_label(s, "net", UiTheme.screen(), 22, UiTheme.CREAM, Vector2(rx, 80), Vector2(APPRAISAL_RIGHT - 18, 60), HORIZONTAL_ALIGNMENT_RIGHT, true)


func _paint_appraisal(s: Screen) -> void:
	var c := _company()
	var r := c.last_report
	var marquee: Label = s.labels["marquee"]
	var clip: Control = s.labels["clip"]
	if r.is_empty():
		# Nog niets verkocht: een stilstaande, knipperende oproep. Geen belofte ("binnenkort"): de
		# taxatie gebeurt echt, na elke dienst, met wat in de Mol ligt (ui-02, binnen-13).
		_text(s, "when", "NO SHIFT\nYET")
		_style(marquee, UiTheme.screen(), 40, UiTheme.AMBER)
		_place(marquee, "AWAITING\nYOUR HAUL", Rect2(0, 8, clip.size.x, 80), HORIZONTAL_ALIGNMENT_CENTER)
		marquee.modulate.a = 1.0 if _blink(1.4, 0.75) else 0.5
		_text(s, "detail", "FINDS IN THE MOLE ARE APPRAISED AFTER THE SHIFT")
		_text(s, "total", UiTheme.euro(0))
		_text(s, "net", "")
		s.fps = 4.0
		return
	marquee.modulate.a = 1.0
	_text(s, "when", "SHIFT %d\nQ%d · %d/%d" % [int(r.get("shift_total", 0)), int(r.get("quarter", 1)), int(r.get("shift", 1)), _shifts()])
	var parts := PackedStringArray()
	for it: Array in r.get("sold", []):
		parts.append("%s %s (%d%%)" % [str(it[0]).to_upper(), UiTheme.euro(int(it[1])), int(it[2])])
	if int(r.get("ore_units", 0)) > 0:
		parts.append("ORE ×%d %s" % [int(r.get("ore_units", 0)), UiTheme.euro(int(r.get("ore_value", 0)))])
	if int(r.get("bonus", 0)) != 0:
		parts.append("RISK BONUS %s" % UiTheme.euro(int(r.get("bonus", 0))))
	if parts.is_empty():
		parts.append("NOTHING SOLD. HEAD OFFICE SIGHS.")
	var text := "    ·    ".join(parts) + "    ·    "
	if marquee.text != text:
		# Nieuwe lijst: meteen leesbaar vanaf links, daarna lopend van rechts.
		_style(marquee, UiTheme.screen(), 44, UiTheme.AMBER)
		marquee.text = text
		marquee.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_marquee_w = UiTheme.screen().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		marquee.size = Vector2(_marquee_w + 8.0, 50)
		marquee.position.y = 18
		_marquee_x = 0.0
	# Lopende tekst: 20 beelden per seconde zolang er iets loopt.
	s.fps = 20.0
	_marquee_x -= 60.0 / s.fps
	if _marquee_x < -_marquee_w:
		_marquee_x = clip.size.x
	marquee.position.x = roundf(_marquee_x)
	var sold := (r.get("sold", []) as Array).size()
	_text(s, "detail", "%d %s  ·  DAMAGE %s" % [sold, "FIND" if sold == 1 else "FINDS", UiTheme.euro(int(r.get("damage", 0)))])
	var gross := int(r.get("finds_value", 0)) + int(r.get("ore_value", 0)) + int(r.get("bonus", 0))
	_text(s, "total", UiTheme.euro(gross))
	var costs := int(r.get("costs", 0))
	_text(s, "net", ("COSTS %s\n" % UiTheme.euro(-costs) if costs > 0 else "") + "NET %s" % UiTheme.euro(int(r.get("net", 0))))


func _draw_appraisal(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(0, 0, w, h), Color("#0c0a08"))
	for y in range(2, int(h), 4):
		c.draw_line(Vector2(APPRAISAL_LEFT, y), Vector2(w - APPRAISAL_RIGHT, y), Color(1.0, 0.7, 0.3, 0.035))
	c.draw_rect(Rect2(0, 0, APPRAISAL_LEFT, h), UiTheme.ANTHRACITE)
	c.draw_rect(Rect2(APPRAISAL_LEFT - 4, 0, 4, h), UiTheme.YELLOW)
	c.draw_rect(Rect2(w - APPRAISAL_RIGHT, 0, APPRAISAL_RIGHT, h), UiTheme.ANTHRACITE)
	c.draw_rect(Rect2(w - APPRAISAL_RIGHT, 0, 4, h), UiTheme.YELLOW)
	_stripes(c, Rect2(0, h - 10, APPRAISAL_LEFT - 4, 10), UiTheme.YELLOW, UiTheme.ANTHRACITE_LO, 8.0, _time * 12.0)
