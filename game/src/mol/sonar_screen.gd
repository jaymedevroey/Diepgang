class_name SonarScreen
extends Node
## Het sonarscherm in de cabine: een SubViewport met het sonarbeeld (sonar.gdshader) en de tekst,
## op het scherm achter de frontplaat van de sonarkast (tools/blender/mol.py, build_sonar), met
## hetzelfde beeldbuiseffect als het camerascherm. Het echolampje flitst bij elke echo; de
## PING-knop brandt als hij klaar is en flitst als hij vertrekt.
## De rand van de scoop is het PING-bereik (24 m), de binnenste felle cirkel het stille bereik.
## Indeling in pixels = millimeters op de kast: scoop links (rond), rechts dieptestrook en tekst.

const SHADER := preload("res://src/mol/sonar.gdshader")
const FEED_SHADER := preload("res://src/mol/feed.gdshader")
const SIZE := Vector2i(860, 560)
const SCOPE_C := Vector2(260, 280)
const SCOPE_R := 245.0
const STRIP := Rect2(548, 60, 22, 440)
const STRIP_RANGE := 20.0
const TEXT_X := 618.0
const MAX_BLIPS := 24
const PHOSPHOR := Color(0.42, 1.0, 0.52)

## Rendert enkel als iemand kijkt (de lokale speler in de Mol).
var active := true:
	set(v):
		active = v
		if _viewport:
			_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED

var _viewport: SubViewport
var _scope: ShaderMaterial
var _labels: Dictionary = {}
var _lamp: StandardMaterial3D
var _lamp_glow := 0.0
var _ping_mat: StandardMaterial3D
var _ping_glow := 0.0
var _was_pinging := false
var _last_echoes := 0
var _text_timer := 0.0


func setup(screen: MeshInstance3D, lamp: MeshInstance3D, ping_button: MeshInstance3D) -> void:
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE)
	_scope = ShaderMaterial.new()
	_scope.shader = SHADER
	_scope.set_shader_parameter("size", Vector2(SIZE))
	_scope.set_shader_parameter("scope_c", SCOPE_C)
	_scope.set_shader_parameter("scope_r", SCOPE_R)
	_scope.set_shader_parameter("strip", Vector4(STRIP.position.x, STRIP.position.y, STRIP.end.x, STRIP.end.y))
	_scope.set_shader_parameter("strip_range", STRIP_RANGE)
	_scope.set_shader_parameter("phosphor", PHOSPHOR)
	rect.material = _scope
	_viewport.add_child(rect)
	# Dieptestrook: meters naast de streepjes.
	for m: int in [20, 10, 0, -10, -20]:
		var y := STRIP.get_center().y - m * STRIP.size.y * 0.5 / STRIP_RANGE
		_label("tick%d" % m, ("+%d" % m) if m > 0 else str(m), Vector2(STRIP.end.x + 6.0, y - 13.0), 24, 0.55)
	_label("head", "TARGET", Vector2(TEXT_X, 22), 32, 0.55)
	_label("dist", "", Vector2(TEXT_X, 50), 76, 1.0)
	_label("clock", "", Vector2(TEXT_X, 128), 48, 0.9)
	_label("height", "", Vector2(TEXT_X, 176), 48, 0.9)
	_label("size", "", Vector2(TEXT_X, 224), 48, 0.75)
	_label("warn", "", Vector2(TEXT_X, 300), 40, 1.0)
	_label("ping", "", Vector2(TEXT_X, 400), 36, 0.9)
	_label("range", "", Vector2(TEXT_X, 448), 30, 0.55)
	_label("status", "", Vector2(TEXT_X, 482), 36, 0.8)
	# Beeldbuis: zelfde effect als het camerascherm, zonder ontzadigen (het beeld is al groen).
	var m := ShaderMaterial.new()
	m.shader = FEED_SHADER
	m.set_shader_parameter("feed", _viewport.get_texture())
	m.set_shader_parameter("tint", Color(1, 1, 1))
	m.set_shader_parameter("desaturate", 0.0)
	m.set_shader_parameter("vignette", 0.3)
	m.set_shader_parameter("brightness", 1.6)
	m.set_shader_parameter("lines", 200.0)
	screen.material_override = m
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color(0.2, 0.45, 0.25)
	_lamp.emission_enabled = true
	_lamp.emission = PHOSPHOR
	_lamp.roughness = 0.2
	lamp.material_override = _lamp
	_ping_mat = StandardMaterial3D.new()
	_ping_mat.albedo_color = Color(0.55, 0.22, 0.05)
	_ping_mat.emission_enabled = true
	_ping_mat.emission = Color(1.0, 0.42, 0.06)
	_ping_mat.roughness = 0.25
	ping_button.material_override = _ping_mat


func texture() -> ViewportTexture:
	return _viewport.get_texture()


## Elke frame (als `active`): de toestand van de sonar op het scherm zetten.
func display(sonar: Sonar, origin: Transform3D, delta: float) -> void:
	var fwd := -origin.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var shown := sonar.visible_contacts()
	var target := sonar.nearest(origin)
	var blips := PackedVector4Array()
	var heights := PackedFloat32Array()
	var target_index := -1
	for c: Sonar.Contact in shown:
		if blips.size() >= MAX_BLIPS:
			break
		var rel := c.echo - origin.origin
		var flat := Vector2(rel.dot(right), rel.dot(fwd)) / sonar.ping_range
		if flat.length() > 0.96:
			flat = flat.normalized() * 0.96
		if c == target:
			target_index = blips.size()
		blips.append(Vector4(flat.x, flat.y, sonar.brightness(c), float(c.size) + (3.0 if c.sharp else 0.0)))
		heights.append(rel.y)
	blips.resize(MAX_BLIPS)
	heights.resize(MAX_BLIPS)
	_scope.set_shader_parameter("sweep", sonar.sweep)
	_scope.set_shader_parameter("noise", sonar.noise)
	_scope.set_shader_parameter("quiet", sonar.range_m / sonar.ping_range)
	_scope.set_shader_parameter("ping_r", sonar.ping_r / sonar.ping_range if sonar.ping_r >= 0.0 else -1.0)
	_scope.set_shader_parameter("count", mini(shown.size(), MAX_BLIPS))
	_scope.set_shader_parameter("blips", blips)
	_scope.set_shader_parameter("heights", heights)
	_scope.set_shader_parameter("target", target_index)

	# Echolampje.
	if sonar.echo_count != _last_echoes:
		_last_echoes = sonar.echo_count
		_lamp_glow = 1.0
	_lamp_glow = maxf(0.0, _lamp_glow - delta * 5.0)
	_lamp.emission_energy_multiplier = 0.15 + 3.5 * _lamp_glow

	# PING-knop: flits bij vertrek, donker tijdens het opladen, rustig ademend als hij klaar is.
	var pinging := sonar.pinging()
	if pinging and not _was_pinging:
		_ping_glow = 1.0
	_was_pinging = pinging
	_ping_glow = maxf(0.0, _ping_glow - delta * 2.5)
	var ready := sonar.ping_ready()
	var idle := (1.1 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)) if ready else 0.12
	# Geweigerd (te vroeg of op): de knop knippert kort.
	var denied := sonar.denied_age < 0.6
	if denied:
		idle = 2.5 if fmod(sonar.denied_age, 0.2) < 0.1 else 0.1
	_ping_mat.emission_energy_multiplier = idle + 6.0 * _ping_glow
	_ping_mat.albedo_color = Color(0.55, 0.22, 0.05) if ready or _ping_glow > 0.0 or denied else Color(0.16, 0.07, 0.03)

	_text_timer -= delta
	if _text_timer > 0.0 and sonar.denied_age > 1.0:
		return
	_text_timer = 0.1
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.5
	if target == null:
		_text("head", "")
		_text("dist", "")
		_text("clock", "NO")
		_text("height", "ECHO")
		_text("size", "")
		_text("warn", "")
	else:
		var rel := target.echo - origin.origin
		var dist := rel.length()
		_text("head", "TARGET")
		_text("dist", "%d M" % int(round(dist)))
		_text("clock", "%d O'CLOCK" % Sonar.clock(Sonar.bearing(origin, target.echo)))
		var level := Tuning.get_f("mol", "sonar_level", 2.5)
		_text("height", "LEVEL" if absf(rel.y) <= level else "%d M %s" % [int(round(absf(rel.y))), "ABOVE" if rel.y > 0.0 else "BELOW"])
		_text("size", Sonar.SIZE_NAMES[target.size])
		var close := dist < Tuning.get_f("mol", "sonar_warn", 8.0)
		_text("warn", "! CLOSE\nSTOP HERE" if close else "")
		(_labels["warn"] as Label).modulate.a = 1.0 if blink else 0.35
	# PING: hoeveel er deze dienst nog over zijn, en of hij opgeladen is. Te vroeg gedrukt: het getal
	# licht op en knippert (gevoel-13: een toets zonder antwoord voelt kapot).
	var max_pings := Tuning.get_i("mol", "sonar_pings", 4)
	if sonar.pinging():
		_text("ping", "PING!")
	elif sonar.pings_left <= 0:
		_text("ping", "NO PINGS")
	elif sonar.ping_cool > 0.0:
		_text("ping", "PING %d S" % int(ceil(sonar.ping_cool)))
	else:
		_text("ping", "PING %d/%d" % [sonar.pings_left, max_pings])
	var pl: Label = _labels["ping"]
	if sonar.denied_age < 0.9:
		pl.modulate = Color(1.6, 1.6, 1.6, 1.0) if fmod(sonar.denied_age, 0.3) < 0.15 else Color(1, 1, 1, 0.3)
	else:
		pl.modulate = Color(1, 1, 1, 1.0 if sonar.ping_ready() or sonar.pinging() else 0.45)
	_text("range", "RANGE %d M" % int(sonar.range_m))
	var noisy := sonar.noise > 0.3
	_text("status", "NOISY" if noisy else "QUIET")
	(_labels["status"] as Label).modulate.a = (1.0 if blink else 0.4) if noisy else 0.8


func _label(key: String, text: String, pos: Vector2, size: int, alpha: float) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", UiTheme.screen())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(PHOSPHOR, alpha))
	l.add_theme_constant_override("line_spacing", -8)
	_viewport.add_child(l)
	_labels[key] = l


func _text(key: String, text: String) -> void:
	var l: Label = _labels[key]
	if l.text != text:
		l.text = text
