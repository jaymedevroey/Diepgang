class_name HandScanner
extends Node3D
## Handscanner T1 (GDD §5 Scanner: "T1: blips. Nooit alles zichtbaar"; F1, rest van ontwerp-6):
## een gadget voor te voet, naast het gereedschap. Q tilt hem in je linkerhand in beeld en stuurt één
## stille puls tot scan_range_m (10 m): elke vondst in de rots of los (niet in de Mol, niet gedragen)
## geeft een vage blip op het schermpje, op de plek waar ze vandaan kwam met wat onzekerheid, en met
## een pijltje als ze duidelijk hoger of lager zit. Geen soort, geen waarde (dat is T2, later). De
## blips blijven scan_hold_s staan en draaien mee als je draait (vooruit = boven), daarna zakt hij weer
## weg en laadt hij scan_cooldown_s op. De Mol heeft de verre sonar met PING (24 m, luid).
## Enkel lokaal: de vondsten staan op elke peer (seed), er gaat niets over het netwerk.
## Model: tools.glb Scanner + Scanner_Screen (tools/blender/tools.py), ter goedkeuring van Jayme.
## Hang dit onder de camera van de lokale speler (Company doet dat bij het spawnen).

const VIEWMODEL_FOV := 68.0
## Links onder in beeld, het scherm schuin naar je toe.
const POSE := [Vector3(-0.2, -0.2, -0.46), Vector3(18, 14, 6)]
const POSE_LOW := [Vector3(-0.3, -0.8, -0.4), Vector3(-30, 20, 0)]
const SCREEN_PX := Vector2i(320, 240)
const PHOSPHOR := Color(0.42, 1.0, 0.52)
const MAX_BLIPS := 12

var player: Player
var game: Game
## Blips: [wereldplek met onzekerheid, grootte (Sonar.Size), seconden tot de puls hem raakt].
var blips: Array = []
## Seconden sinds de laatste puls (−1 = nog geen), en tot hij weer kan.
var since_pulse := -1.0
var cooldown := 0.0

var _model: Node3D
var _viewport: SubViewport
var _view: Control
var _up := 0.0
var _rng := RandomNumberGenerator.new()
var _denied := INF
var _hint_given := false


func _ready() -> void:
	_rng.randomize()
	_model = Node3D.new()
	_model.name = "ScannerModel"
	add_child(_model)
	if PickaxeModel.has_part("Scanner"):
		_model.add_child(PickaxeModel.part("Scanner", VIEWMODEL_FOV, player.color if player else PickaxeModel.GLOVE, true))
	# De linkerhand: dezelfde gesloten handschoen als bij de boor, gespiegeld (de scanner zelf niet:
	# dan stond zijn label in spiegelschrift).
	var glove := PickaxeModel.part("Glove", VIEWMODEL_FOV, player.color if player else PickaxeModel.GLOVE, true)
	glove.rotation_degrees = Vector3(DrillModel.GRIP_TILT + 3.0, 0, 0)
	glove.scale = Vector3(-1, 1, 1)
	_model.add_child(glove)
	_viewport = SubViewport.new()
	_viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_viewport.size = SCREEN_PX
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_view = _ScanView.new()
	_view.scanner = self
	_view.size = Vector2(SCREEN_PX)
	_viewport.add_child(_view)
	if PickaxeModel.has_part("Scanner_Screen"):
		var screen := PickaxeModel.part("Scanner_Screen", VIEWMODEL_FOV, Color.WHITE, true)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = _viewport.get_texture()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.use_z_clip_scale = true
		m.z_clip_scale = 0.3
		m.use_fov_override = true
		m.fov_override = VIEWMODEL_FOV
		screen.material_override = m
		_model.add_child(screen)
	visible = false
	position = POSE_LOW[0]
	rotation_degrees = POSE_LOW[1]


## Mag de scanner nu omhoog? (gekocht, niet in de stoel, geen filmpje, handen vrij)
func usable() -> bool:
	if player == null or game == null or game.company == null:
		return false
	return Upgrades.has_scanner(game.company) and not player.seated and not player.cinematic \
			and (player.carry == null or player.carry.item == null)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_local or not event.is_action_pressed("scan"):
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return
	if not Upgrades.has_scanner(game.company):
		if not _hint_given:
			_hint_given = true
			game.notice.emit("No hand scanner yet: the supply desk aboard sells one.", "info")
		return
	pulse()
	get_viewport().set_input_as_handled()


## Een puls (ook voor tests). False als het niet kan (opladen, handen vol).
func pulse() -> bool:
	if not usable():
		return false
	if cooldown > 0.0:
		_denied = 0.0
		return false
	var range_m := Tuning.get_f("economy", "scan_range_m", 10.0)
	var origin := player.camera.global_position if player.camera else player.global_position
	var found: Array = []
	var mol: Mol = game.mol
	for it: FindItem in game.finds.items:
		if not it.carriers.is_empty() or (it.freed and mol and mol.contains_point(it.global_position)):
			continue
		var d := it.global_position.distance_to(origin)
		if d > range_m:
			continue
		found.append([it, d])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1])
	blips.clear()
	var pulse_s := Tuning.get_f("economy", "scan_pulse_s", 0.5)
	for f: Array in found.slice(0, MAX_BLIPS):
		var it: FindItem = f[0]
		var d: float = f[1]
		var spread := Tuning.get_f("economy", "scan_jitter", 0.6) + Tuning.get_f("economy", "scan_jitter_per_m", 0.08) * d
		var j := Vector3(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 0.4), _rng.randfn(0.0, 1.0)) * spread * 0.5
		blips.append([it.global_position + j, Sonar.size_of(it), d / range_m * pulse_s])
	since_pulse = 0.0
	cooldown = Tuning.get_f("economy", "scan_cooldown_s", 4.0) + Tuning.get_f("economy", "scan_hold_s", 5.0)
	game.fx.play("tok", origin, -14.0, 0.0, 1.8) # (geluid: M6)
	return true


## Is de scanner nu in beeld (tests en screenshots)?
func raised() -> bool:
	return _up > 0.5


func _process(delta: float) -> void:
	if player == null:
		return
	cooldown = maxf(0.0, cooldown - delta)
	_denied += delta
	if since_pulse >= 0.0:
		since_pulse += delta
	var hold := Tuning.get_f("economy", "scan_hold_s", 5.0)
	var want_up := since_pulse >= 0.0 and since_pulse < hold and usable()
	_up = move_toward(_up, 1.0 if want_up else 0.0, delta / (0.22 if want_up else 0.35))
	visible = _up > 0.01
	if not visible:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var e := 1.0 - pow(1.0 - _up, 3.0)
	var bob := Vector3(0.0, sin(Time.get_ticks_msec() / 1000.0 * 1.7) * 0.004, 0.0)
	position = (POSE_LOW[0] as Vector3).lerp(POSE[0], e) + bob
	rotation_degrees = (POSE_LOW[1] as Vector3).lerp(POSE[1], e)
	_view.queue_redraw()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Het schermpje: een groene beeldbuis met afstandsringen, de puls die uitloopt, de blips t.o.v. waar
## je kijkt (vooruit = boven) en wat tekst.
class _ScanView extends Control:
	var scanner: HandScanner

	func _draw() -> void:
		var s := scanner
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.07, 0.03))
		var c := Vector2(w * 0.5, h * 0.56)
		var r := h * 0.44
		var range_m := Tuning.get_f("economy", "scan_range_m", 10.0)
		var ph := HandScanner.PHOSPHOR
		for k in [1.0, 0.5]:
			draw_arc(c, r * k, 0, TAU, 48, Color(ph, 0.35 if k == 1.0 else 0.2), 2.0)
		draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(ph, 0.12), 1.0)
		draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(ph, 0.12), 1.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5), c + Vector2(-5, 5)]), Color(ph, 0.8))
		var f := UiTheme.screen()
		var pulse_s := Tuning.get_f("economy", "scan_pulse_s", 0.5)
		var t := s.since_pulse
		if t >= 0.0 and t < pulse_s:
			draw_arc(c, r * t / pulse_s, 0, TAU, 48, Color(ph, 0.9), 3.0)
		var cam := s.player.camera if s.player else null
		var origin := Transform3D(Basis(Vector3.UP, s.player.global_rotation.y) if s.player else Basis(), cam.global_position if cam else Vector3.ZERO)
		var shown := 0
		var nearest := INF
		var nearest_dy := 0.0
		var hold := Tuning.get_f("economy", "scan_hold_s", 5.0)
		for b: Array in s.blips:
			var age: float = t - float(b[2])
			if age < 0.0:
				continue
			shown += 1
			var p: Vector3 = b[0]
			var rel := p - origin.origin
			var flat := Vector2(rel.x, rel.z)
			var bearing := Sonar.bearing(origin, p)
			var dist := clampf(flat.length() / range_m, 0.0, 1.0)
			var at := c + Vector2(sin(bearing), -cos(bearing)) * dist * r
			var fade := clampf(1.0 - age / hold, 0.0, 1.0)
			var rad: float = [6.0, 8.0, 11.0][int(b[1])]
			draw_circle(at, rad + 3.0, Color(ph, 0.18 * fade))
			draw_circle(at, rad, Color(ph, 0.85 * fade))
			if absf(rel.y) > 1.5:
				var dir := -1.0 if rel.y > 0.0 else 1.0
				draw_colored_polygon(PackedVector2Array([at + Vector2(rad + 4, 0), at + Vector2(rad + 12, 0), at + Vector2(rad + 8, dir * 7)]), Color(ph, fade))
			if rel.length() < nearest:
				nearest = rel.length()
				nearest_dy = rel.y
		draw_string(f, Vector2(10, 26), "SCAN T1 · %d m" % int(range_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(ph, 0.85))
		var line := "NOTHING" if shown == 0 and t > pulse_s else "%d BLIP%s" % [shown, "" if shown == 1 else "S"]
		if t < 0.0:
			line = "READY"
		draw_string(f, Vector2(10, h - 12), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, ph)
		if nearest < INF:
			var arrow := " UP" if nearest_dy > 1.5 else (" DOWN" if nearest_dy < -1.5 else "")
			draw_string(f, Vector2(w * 0.45, h - 12), "%d m%s" % [int(round(nearest)), arrow], HORIZONTAL_ALIGNMENT_RIGHT, w * 0.55 - 10, 28, ph)
		if s._denied < 0.5 or (s.cooldown > 0.0 and t >= hold):
			draw_string(f, Vector2(w - 120, 26), "CHARGING", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.6, 0.3, 0.9))
		# Beeldlijnen.
		for y in range(0, int(h), 3):
			draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.18))
