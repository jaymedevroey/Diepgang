class_name DropCam
extends Camera3D
## Het heldenshot van de drop (keuze van Jayme, docs/research/drop-en-ophalen.md, ontwerp B): één
## camera achter de Mol, die enkel schuift en kantelt, nooit rond de Mol draait. Enkel lokaal; Player
## zet hem aan en uit. De val door de luiken van de hub zie je van binnen; bij de sprong naar buiten
## knipt Player hierheen ("knippen op de actie"):
## - SHIP (enkel de lange drop, ±1,2 s): een vaste camera onder het buitenschip, schuin achter de Mol,
##   omhoog kijkend: de buik van De Ekster boven in beeld, de Mol valt naar de camera toe en schiet
##   onderaan uit beeld. Nooit lager dan drop_cam_min_up_deg (geen horizon in beeld).
## - CHASE: achter en boven de staart, steil omlaag langs de neus (horizon boven het beeld), met
##   naijlen bij versnellen, een breder beeld met de snelheid, strepen en wind. Bij het remmen schuift
##   hij naar beneden en dichterbij, tot hij vooruit over het dak kijkt (zoals het eerste binnenbeeld).
## - LIFT (ophalen): een vaste plek op de grond die de Mol nakijkt (de eerste LIFT_SHOT seconden).
## Ook van hier: de balken boven en onder, de tip "overslaan", zwart bij overslaan, het stof bij de
## klap (een flits), het oorsuizen en de klank op het moment dat je de besturing terugkrijgt.

enum Shot { NONE, SHIP, CHASE, LIFT }

const LIFT_SHOT := 6.0 # seconden van het buitenbeeld bij het ophalen
const SHIP_SHOT_MAX := 1.6 # het shot onder het schip duurt hooguit zo lang
const BAR := 0.075 # hoogte van een balk (deel van het beeld)

var mol: Mol
## Waar deze camera stond in zijn eerste beeld (voor de nettest: niet in de hub).
var first_frame_pos := Vector3.ZERO
var shot := Shot.NONE

var _t := 0.0
var _brake_t := -1.0 # seconden sinds de stuwraketten begonnen (−1 = nog niet)
var _chase_t := 0.0 # seconden in het volgshot (de camera haalt de Mol eerst nog in)
var _lift_done := false
var _ground_pos := Vector3.ZERO
var _ship_cam := Vector3.ZERO
var _lag := 0.0 # naijlen in de hoogte (m), volgt de versnelling
var _lag_v := 0.0
var _vy_was := 0.0
var _acc := 0.0
var _noise := FastNoiseLite.new()
var _ignite := 0.0 # schok bij het ontsteken

var _overlay: CanvasLayer
var _bars: Array[ColorRect] = []
var _fade: ColorRect
var _flash: ColorRect
var _hint: Label
var _bars_k := 0.0
var _bars_want := 0.0
var _wind: AudioStreamPlayer
var _roar: AudioStreamPlayer
var _streaks: GPUParticles3D
var _streak_mat: StandardMaterial3D
var _lowpass: AudioEffectLowPassFilter
var _lowpass_t := -1.0
var _black_hold := -1.0 # seconden zwart na een sprong, tot de Mol er ook in beeld staat (−1 = uit)


func _ready() -> void:
	fov = 72.0
	near = 0.2
	far = 4000.0
	top_level = true
	# Het gereedschap in de hand van de lokale speler hoort niet in het buitenbeeld (door de patrijspoort).
	cull_mask = 0xFFFFF & ~PickaxeModel.VIEWMODEL_LAYER
	_noise.seed = 31
	_noise.frequency = 1.0
	_build_overlay()
	_build_audio()
	_build_streaks()


func setup(m: Mol) -> void:
	mol = m
	mol.drop_event.connect(_on_drop_event)


# --- Aan en uit ----------------------------------------------------------------------------------

func activate() -> void:
	_t = 0.0
	_brake_t = -1.0
	_chase_t = 0.0
	_lag = 0.0
	_lag_v = 0.0
	_ignite = 0.0
	_vy_was = mol.vertical_speed
	_acc = 0.0
	if mol.mode == Mol.Mode.LIFTING:
		shot = Shot.LIFT
		var p := mol.body.global_position + Vector3(14.0, 0.0, 26.0)
		if mol.game.terrain:
			p.y = mol.game.terrain.surface_height_at(p.x, p.z) + 1.7
		_ground_pos = p
	else:
		var ex: EksterExterior = mol.game.exterior
		var below := ex.dock_position().y - mol.placed.origin.y if ex else INF
		shot = Shot.SHIP if mol.drop_variant == Mol.DropVariant.FULL and below < 30.0 else Shot.CHASE
		if shot == Shot.SHIP:
			var back := _back()
			fov = 66.0
			_ship_cam = ex.dock_position() + back * Tuning.get_f("ship", "drop_cam_ship_back", 16.0) \
					+ Vector3.DOWN * Tuning.get_f("ship", "drop_cam_ship_below", 34.0)
		_wind.play()
		_roar.play()
		_wind.volume_db = -60.0
		_roar.volume_db = -60.0
	_bars_want = 1.0
	if _black_hold >= 0.0:
		_black_hold = -1.0
		_fade.color.a = 0.0 # de sprong is voorbij: meteen het buitenbeeld
	_update(0.0)
	first_frame_pos = global_position
	make_current()
	_snap_atmosphere()


func deactivate() -> void:
	_t = 0.0
	shot = Shot.NONE
	_wind.stop()
	_roar.stop()
	_streaks.emitting = false
	_hint.visible = false
	if mol.mode == Mol.Mode.LIFTING:
		_bars_want = 0.0 # bij de drop gaan de balken pas weg bij de overdracht
	_snap_atmosphere()


## Staat het lichaam van de Mol (en dus wat je ervan ziet) al waar hij gezet is? Na een sprong loopt
## het een tick achter (sync_to_physics): dan zou het eerste beeld de Mol niet tonen.
func mol_synced() -> bool:
	return mol != null and mol.body != null and mol.body.global_position.distance_to(mol.placed.origin) < 3.0 # (een sprong is honderden m; vallen ±1 m per tick)


## Is het beeld nu volledig zwart (de dip bij een sprong)? Voor tests: wat dan getekend wordt, ziet niemand.
func blacked_out() -> bool:
	return _fade != null and _fade.color.a >= 0.99


## Sprong terwijl de speler binnen meerijdt (naar buiten, terug naar de hub): even zwart tot de Mol
## er ook staat, anders zie je een beeld lang de lucht of de hangar zonder de Mol rond je.
func hold_black() -> void:
	_black_hold = 0.0
	_fade.color.a = 1.0


## Ophalen: het buitenbeeld enkel de eerste LIFT_SHOT seconden, één keer per ophaling.
func wants_lift_shot() -> bool:
	if mol == null or mol.mode != Mol.Mode.LIFTING:
		_lift_done = false
		return false
	if current and shot == Shot.LIFT and _t > LIFT_SHOT:
		_lift_done = true
	return not _lift_done


func look(_relative: Vector2, _sensitivity: float) -> void:
	pass # vaste camera: de muis doet niets (geen rondjes, zie het onderzoek)


## De Mol sprong terwijl dit beeld liep (overslaan): even zwart, dan het volgshot opnieuw.
func on_mol_snapped() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(_fade, "color:a", 0.0, 0.3)
	shot = Shot.CHASE
	_chase_t = 0.0
	_lag = 0.0
	_lag_v = 0.0
	_vy_was = -Tuning.get_f("ship", "drop_max_speed", 55.0)
	_snap_atmosphere()


## De klap van de landing (Player knipt dan naar binnen): stof voor de ogen, oorsuizen, gedempt geluid.
func impact() -> void:
	var dust := Color(0.78, 0.6, 0.45)
	if mol and mol.visual:
		dust = mol.visual.dust_color.lightened(0.35)
	_flash.color = Color(dust, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	_play2d("drop_ring", -16.0)
	_lowpass_t = 0.0


## De besturing komt terug: balken weg, een belletje van de firma.
func handover() -> void:
	_bars_want = 0.0
	_play2d("drop_ready", -9.0)


func _on_drop_event(event: Mol.Event) -> void:
	if event == Mol.Event.THRUST and current:
		_ignite = 1.0
		_play2d("drop_thrust_ignite", -4.0)


func _snap_atmosphere() -> void:
	var atm := get_tree().current_scene.find_child("Atmosphere", true, false) if get_tree().current_scene else null
	if atm and atm.has_method("snap"):
		atm.call("snap")


# --- Elke frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _black_hold >= 0.0:
		_black_hold += delta
		if mol_synced() and not current or _black_hold > 0.3:
			_black_hold = -1.0
			_fade.color.a = 0.0
	_update_overlay(delta)
	_update_lowpass(delta)
	if mol == null or mol.body == null or not current:
		return
	_t += delta
	_update(delta)


func _back() -> Vector3:
	var back := mol.placed.basis.z
	back.y = 0.0
	return back.normalized() if back.length() > 0.1 else Vector3.BACK


func _update(delta: float) -> void:
	# Waar de Mol gezet is (Mol.placed), niet waar zijn lichaam nu staat: na een sprong staat dat
	# lichaam nog een frame op de oude plek (sync_to_physics), en dan zat het eerste beeld in de hub.
	var m := mol.placed.origin
	# Net na een sprong (overslaan: ±150 m) staat het model van de Mol nog een tick op de oude plek:
	# dan volgt de camera wat er getekend wordt, anders is er een beeld zonder de Mol.
	if not mol_synced():
		m = mol.body.global_position
	if shot == Shot.LIFT:
		global_position = _ground_pos
		look_at(m + Vector3(0, 2.0, 0), Vector3.UP)
		return
	var shake_k := Settings.get_f("interface/camera_shake")
	var speed := absf(mol.vertical_speed)
	var vmax := Tuning.get_f("ship", "drop_max_speed", 55.0)
	var sk := clampf(speed / vmax, 0.0, 1.0)
	if mol.thrust > 0.02 and _brake_t < 0.0:
		_brake_t = 0.0
	if _brake_t >= 0.0:
		_brake_t += delta
	_ignite = maxf(0.0, _ignite - delta * 2.5)
	var t: TerrainAPI = mol.game.terrain
	var back := _back()
	var fwd := -back
	if shot == Shot.SHIP:
		# Vaste camera onder het schip: kijkt naar de Mol, maar nooit lager dan min_up (geen horizon).
		global_position = _ship_cam
		var to := m + Vector3(0, 1.0, 0) - _ship_cam
		var flat := Vector2(to.x, to.z).length()
		var min_up := deg_to_rad(Tuning.get_f("ship", "drop_cam_min_up_deg", 42.0))
		var elev := maxf(atan2(to.y, flat), min_up)
		var dir := (Vector3(to.x, 0.0, to.z).normalized() * cos(elev) + Vector3.UP * sin(elev))
		look_at(global_position + dir, Vector3.UP)
		fov = lerpf(fov, 66.0, minf(1.0, delta * 2.0))
		# Uit beeld onderaan (of te lang): knippen naar het volgshot.
		var mol_elev := atan2(to.y - 2.5, flat)
		if mol_elev < elev - deg_to_rad(fov * 0.5) or _t > SHIP_SHOT_MAX:
			shot = Shot.CHASE
			_chase_t = 0.0
			_lag = 0.0
			_lag_v = 0.0
		else:
			return
	# Volgshot: achter en boven de staart, steil omlaag; bij het remmen lager, dichter, vlakker.
	var b := smoothstep(0.0, Tuning.get_f("ship", "drop_cam_brake_blend_s", 2.0), maxf(_brake_t, 0.0))
	# In het begin van het volgshot nog wat verder: de camera haalt de Mol langzaam in.
	_chase_t += delta
	var catch := lerpf(1.35, 1.0, smoothstep(0.0, 3.5, _chase_t))
	# Hoog in de lucht bijna recht boven de Mol, steil omlaag: de Mol valt naar de landingsplek, de rand
	# van het landschap blijft ver boven het beeld. Lager schuift hij naar achter en boven de staart en
	# kijkt hij verder vooruit; bij het remmen bijna vlak, vooruit over het dak.
	var alt := m.y - (t.surface_height_at(m.x, m.z) if t else 0.0)
	var hi := smoothstep(90.0, 220.0, alt)
	var back_k := lerpf(Tuning.get_f("ship", "drop_cam_back", 12.0), Tuning.get_f("ship", "drop_cam_high_back", 7.0), hi)
	var up_k := lerpf(Tuning.get_f("ship", "drop_cam_up", 12.0), Tuning.get_f("ship", "drop_cam_high_up", 18.0), hi)
	var dist := lerpf(back_k * catch, Tuning.get_f("ship", "drop_cam_brake_back", 13.0), b)
	var up := lerpf(up_k * catch, Tuning.get_f("ship", "drop_cam_brake_up", 6.0), b)
	var look_ahead := lerpf(3.0, 16.0, b)
	var look_down := lerpf(lerpf(5.0, Tuning.get_f("ship", "drop_cam_high_down", 26.0), hi), 3.0, b)
	# Naijlen: versnelt de Mol naar beneden, dan blijft de camera wat hoger hangen (en omgekeerd
	# bij het remmen), als een veer. Dat verkoopt de versnelling.
	if delta > 0.0:
		var a := (mol.vertical_speed - _vy_was) / delta
		_vy_was = mol.vertical_speed
		_acc = lerpf(_acc, clampf(a, -40.0, 40.0), minf(1.0, delta * 6.0))
	var lag_want := clampf(-_acc * Tuning.get_f("ship", "drop_cam_lag", 0.22), -1.5, 3.0)
	var left := minf(delta, 0.1) # veer in kleine stapjes (stabiel, ook bij een lang frame)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_lag_v += ((lag_want - _lag) * 18.0 - _lag_v * 7.0) * h
		_lag += _lag_v * h
		left -= h
	var pos := m + back * dist + Vector3.UP * (up + _lag)
	if t:
		pos.y = maxf(pos.y, t.surface_height_at(pos.x, pos.z) + 2.0)
	var target := m + fwd * look_ahead + Vector3.DOWN * look_down
	# Schok: buffelen in de wind (met de snelheid), harder bij de stuwraketten en het ontsteken.
	var trauma := clampf(sk * sk * 0.45 + mol.thrust * 0.5 + _ignite * 0.6, 0.0, 1.0)
	var amp := deg_to_rad(Tuning.get_f("ship", "drop_cam_shake_deg", 1.4)) * trauma * trauma * shake_k
	var f := _t * 9.0
	global_position = pos
	look_at(target, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 0.0))
	rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(0.0, f))
	rotate_object_local(Vector3.FORWARD, amp * 0.6 * _noise.get_noise_2d(f, f))
	var fov_want := lerpf(Tuning.get_f("ship", "drop_cam_fov", 70.0), Tuning.get_f("ship", "drop_cam_fov_fast", 82.0), sk)
	fov = lerpf(fov, lerpf(fov_want, 66.0, b), minf(1.0, delta * 3.0)) if delta > 0.0 else fov_want
	# Strepen en wind met de snelheid, gebrul met de stuwraketten.
	_update_streaks(sk * (1.0 - b))
	_wind.volume_db = linear_to_db(maxf(0.0005, sk * 0.55))
	_wind.pitch_scale = 0.75 + 0.5 * sk
	_roar.volume_db = linear_to_db(maxf(0.0005, mol.thrust * 0.6))
	_roar.pitch_scale = 0.85 + 0.25 * mol.thrust


func _update_streaks(k: float) -> void:
	_streaks.emitting = k > 0.15
	_streaks.amount_ratio = clampf(k, 0.05, 1.0)
	var m := _streaks.process_material as ParticleProcessMaterial
	# De wind komt van onder (de Mol en de camera vallen): in cameraruimte.
	m.direction = global_basis.inverse() * Vector3.UP
	m.initial_velocity_min = 30.0 * k + 5.0
	m.initial_velocity_max = 45.0 * k + 8.0
	_streak_mat.albedo_color = Color(1.0, 0.97, 0.9, 0.16 * k)


# --- Opbouw --------------------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 60 # boven de HUD, onder het pauzemenu
	add_child(_overlay)
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0.0, 0.0, 0.0, 1.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.anchor_left = 0.0
		r.anchor_right = 1.0
		r.anchor_top = 0.0 if top else 1.0
		r.anchor_bottom = 0.0 if top else 1.0
		_overlay.add_child(r)
		_bars.append(r)
	_flash = _full_rect(Color(1, 1, 1, 0))
	_fade = _full_rect(Color(0, 0, 0, 0))
	_hint = Label.new()
	_hint.add_theme_font_override("font", UiTheme.body(800))
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", UiTheme.CREAM)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -520.0
	_hint.offset_right = -36.0
	_hint.offset_top = -64.0
	_hint.offset_bottom = -20.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_overlay.add_child(_hint)


func _full_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(r)
	return r


func _update_overlay(delta: float) -> void:
	_bars_k = move_toward(_bars_k, _bars_want, delta / 0.35)
	var h := get_viewport().get_visible_rect().size.y * BAR * smoothstep(0.0, 1.0, _bars_k)
	_bars[0].offset_top = 0.0
	_bars[0].offset_bottom = h
	_bars[1].offset_top = -h
	_bars[1].offset_bottom = 0.0
	for r in _bars:
		r.visible = h > 0.5
	var show := current and mol != null and mol.drop_skippable()
	_hint.visible = show
	if show:
		var key := Settings.key_of("skip_cinematic").to_upper()
		_hint.text = "%s  ·  OVERSLAAN" % key if mol.skip_votes == 0 else "%s  ·  OVERSLAAN  %d/%d" % [key, mol.skip_votes, mol.skip_needed]


## Na de klap: alles even gedempt (laagdoorlaat op de SFX-bus die weer opengaat).
func _update_lowpass(delta: float) -> void:
	if _lowpass_t < 0.0:
		return
	var bus := AudioServer.get_bus_index(&"SFX")
	if bus < 0:
		_lowpass_t = -1.0
		return
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bus, _lowpass)
	var idx := -1
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _lowpass:
			idx = i
	if idx < 0:
		_lowpass_t = -1.0
		return
	_lowpass_t += delta
	var dur := Tuning.get_f("ship", "drop_muffle_s", 0.9)
	var k := clampf(_lowpass_t / dur, 0.0, 1.0)
	_lowpass.cutoff_hz = lerpf(450.0, 20000.0, k * k)
	AudioServer.set_bus_effect_enabled(bus, idx, k < 1.0)
	if k >= 1.0:
		_lowpass_t = -1.0


func _build_audio() -> void:
	_wind = _player2d("drop_wind")
	_roar = _player2d("drop_thrust")


func _player2d(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = DropAudio.stream(sound)
	p.volume_db = -60.0
	add_child(p)
	return p


func _play2d(sound: String, db: float) -> void:
	var stream := DropAudio.stream(sound)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"SFX"
	p.stream = stream
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Strepen vlak voor de camera: de lucht die langs raast (cameraruimte, met de snelheid).
func _build_streaks() -> void:
	_streaks = GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(7.0, 5.0, 6.0)
	m.direction = Vector3.UP
	m.spread = 2.0
	m.gravity = Vector3.ZERO
	m.particle_flag_align_y = true
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 30.0
	_streaks.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 1.8)
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streak_mat.albedo_color = Color(1, 1, 1, 0.0)
	q.material = _streak_mat
	_streaks.draw_pass_1 = q
	_streaks.amount = 60
	_streaks.lifetime = 0.35
	_streaks.local_coords = true
	_streaks.emitting = false
	_streaks.visibility_aabb = AABB(Vector3(-20, -20, -30), Vector3(40, 40, 40))
	add_child(_streaks)
	_streaks.position = Vector3(0.0, 0.0, -11.0)
