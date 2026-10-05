class_name DropCam
extends Camera3D
## Het heldenshot van de drop (keuze van Jayme, docs/research/drop-en-ophalen.md, ontwerp B): één
## camera achter de Mol, die enkel schuift en kantelt, nooit rond de Mol draait. Enkel lokaal; Player
## zet hem aan en uit. De val door de luiken van de hub zie je van binnen; bij de sprong naar buiten
## knipt Player hierheen ("knippen op de actie"):
## - SHIP (enkel de lange drop, ±1,2 s): een vaste camera onder het buitenschip, schuin achter de Mol,
##   omhoog kijkend: de buik van De Ekster boven in beeld, de Mol valt naar de camera toe en schiet
##   onderaan uit beeld. Nooit lager dan drop_cam_min_up_deg (geen horizon in beeld).
## - CHASE: achter en boven de staart, schuin omlaag langs de neus. Hoog in de lucht vlak genoeg dat
##   de kim, de hemel en de landmarken in beeld staan (buiten-1: niet recht omlaag op een egale
##   vlakte), lager steiler op de landingsplek. Met naijlen bij versnellen, een breder beeld met de
##   snelheid, traag rollen en inhalen, strepen en wind. Bij het remmen schuift hij naar beneden en
##   dichterbij, tot hij vooruit over het dak kijkt (zoals het eerste binnenbeeld). Na de klap blijft
##   hij nog even staan (stofring, schok), dan pas de knip naar binnen (gevoel-17).
## - LIFT (ophalen): een kraanshot opzij van de Mol, met de reus erachter, dat met hem mee stijgt tot
##   onder het schip; de Mol verdwijnt in de baai, en in het zwart knipt het naar binnen (buiten-5).
## Ook van hier: de balken boven en onder, de tip "overslaan", zwart bij overslaan, het stof bij de
## klap (een flits), het oorsuizen en de klank op het moment dat je de besturing terugkrijgt. De muis
## laat de blik een klein beetje opzij kijken (veert terug), nooit rond de Mol draaien.

enum Shot { NONE, SHIP, CHASE, LIFT }

const LIFT_SHOT := 24.0 # hooguit zoveel seconden buitenbeeld bij het ophalen (het loopt tot in de baai)
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
var _ship_cam := Vector3.ZERO
var _lag := 0.0 # naijlen in de hoogte (m), volgt de versnelling
var _lag_v := 0.0
var _vy_was := 0.0
var _acc := 0.0
var _noise := FastNoiseLite.new()
var _ignite := 0.0 # schok bij het ontsteken
var _land_t := -1.0 # seconden sinds de klap (−1 = niet geland in dit shot)
var _land_flash := false # de flits van de klap komt bij de knip naar binnen
var _look := Vector2.ZERO # kleine blik opzij met de muis (radialen: yaw, pitch), veert terug
var _look_idle := 0.0
var _lift_dir := Vector3.FORWARD # ophalen: horizontale kijkrichting (naar de reus)
var _lift_cam := Vector3.ZERO
var _black_until_docked := false
var _dust_col := Color(0.86, 0.74, 0.6)

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
	mol.landed.connect(_on_landed)


# --- Aan en uit ----------------------------------------------------------------------------------

func activate() -> void:
	_t = 0.0
	_brake_t = -1.0
	_chase_t = 0.0
	_lag = 0.0
	_lag_v = 0.0
	_ignite = 0.0
	_land_t = -1.0
	_land_flash = false
	_look = Vector2.ZERO
	_vy_was = mol.vertical_speed
	_acc = 0.0
	var params := PlanetType.params(mol.game.planet_type)
	var sky: Dictionary = params.get("sky", {})
	if params.get("fog") is Color and sky.get("haze_band") is Color:
		_dust_col = (params["fog"] as Color).lerp(sky["haze_band"], 0.5)
	if mol.mode == Mol.Mode.LIFTING:
		shot = Shot.LIFT
		_start_lift_shot()
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
	var was := shot
	_t = 0.0
	shot = Shot.NONE
	_wind.stop()
	_roar.stop()
	_streaks.emitting = false
	_hint.visible = false
	if was == Shot.LIFT:
		_bars_want = 0.0 # bij de drop gaan de balken pas weg bij de overdracht
		if _fade.color.a > 0.5:
			# In het zwart naar binnen: zwart blijven tot de Mol in de hub staat (de sprong).
			_black_until_docked = true
			_black_hold = 0.0
	if _land_t >= 0.0:
		_cut_in_jolt()
	_land_t = -1.0
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


## Buitenbeeld buiten de val zelf: het ophalen (tot de Mol in de baai verdwijnt, hooguit LIFT_SHOT
## seconden, één keer per ophaling), en na de klap van de landing nog drop_cam_land_hold_s.
func wants_lift_shot() -> bool:
	if mol == null:
		return false
	if current and shot == Shot.CHASE and _land_t >= 0.0:
		return _land_t < Tuning.get_f("ship", "drop_cam_land_hold_s", 0.22)
	if mol.mode != Mol.Mode.LIFTING:
		_lift_done = false
		return false
	if current and shot == Shot.LIFT and (_t > LIFT_SHOT or _lift_in_bay()):
		_lift_done = true
	return not _lift_done


## Ophalen: de Mol is (bijna) in de baai en het beeld is zwart: naar binnen.
func _lift_in_bay() -> bool:
	var ex: EksterExterior = mol.game.exterior
	return ex != null and _fade.color.a >= 0.99 and ex.dock_position().y - mol.placed.origin.y < 4.0


## De muis: de blik een beetje opzij (geen rondjes rond de Mol, zie het onderzoek); veert terug.
func look(relative: Vector2, sensitivity: float) -> void:
	_look.x = clampf(_look.x - relative.x * sensitivity * 0.5, -0.3, 0.3)
	_look.y = clampf(_look.y - relative.y * sensitivity * 0.5, -0.2, 0.2)
	_look_idle = 0.0


## De Mol sprong terwijl dit beeld liep (overslaan): even zwart, dan het volgshot opnieuw.
func on_mol_snapped() -> void:
	if shot == Shot.LIFT:
		_fade.color.a = 1.0 # in de baai: zwart tot het beeld binnen er staat
		return
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


## De klap van de landing: stof voor de ogen, oorsuizen, gedempt geluid. Staat het buitenbeeld nog
## (de stofring na de klap), dan komt de flits pas bij de knip naar binnen.
func impact() -> void:
	if current and _land_t >= 0.0:
		_land_flash = true
		return
	_flash_now()


func _flash_now() -> void:
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


## Geland terwijl dit beeld loopt: nog even buiten blijven, met een harde schok (de stofring).
func _on_landed() -> void:
	if current and shot == Shot.CHASE:
		_land_t = 0.0
		_ignite = 1.6


## De knip naar binnen na de klap: de flits, en de schok in de eigen camera van de speler.
func _cut_in_jolt() -> void:
	if _land_flash:
		_land_flash = false
		_flash_now()
	var p := get_parent() as Player
	if p and p.camera_fx:
		p.camera_fx.add_trauma(0.45)
		p.camera_fx.kick(-5.0, randf_range(-2.0, 2.0))


func _snap_atmosphere() -> void:
	var atm := get_tree().current_scene.find_child("Atmosphere", true, false) if get_tree().current_scene else null
	if atm and atm.has_method("snap"):
		atm.call("snap")


# --- Elke frame ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _black_hold >= 0.0:
		_black_hold += delta
		var docked := not _black_until_docked or mol == null or mol.mode == Mol.Mode.DOCKED
		if mol_synced() and not current and docked or _black_hold > (3.0 if _black_until_docked else 0.3):
			_black_hold = -1.0
			_black_until_docked = false
			_fade.color.a = 0.0
	if _land_t >= 0.0:
		_land_t += delta
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
	# De blik met de muis veert terug als je loslaat.
	_look_idle += delta
	if _look_idle > 0.5:
		_look = _look.lerp(Vector2.ZERO, minf(1.0, delta * 2.5))
	if shot == Shot.LIFT:
		_update_lift(m, delta)
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
	# Volgshot: achter en boven de staart, schuin omlaag langs de neus; bij het remmen lager, dichter
	# en vlakker, vooruit over het dak.
	var b := smoothstep(0.0, Tuning.get_f("ship", "drop_cam_brake_blend_s", 2.0), maxf(_brake_t, 0.0))
	# In het begin van het volgshot nog wat verder: de camera haalt de Mol langzaam in.
	_chase_t += delta
	var catch := lerpf(Tuning.get_f("ship", "drop_cam_catch", 1.45), 1.0,
			smoothstep(0.0, Tuning.get_f("ship", "drop_cam_catch_s", 5.0), _chase_t))
	# Hoog in de lucht kijkt hij vlakker (de kim en de reus in het bovenste deel, de landmarken en het
	# hele landschap eronder: buiten-1); dichter bij de grond steiler, op de landingsplek. De rand van
	# het verre landschap ligt achter de kim (de ring tot 6,5 km buigt mee met de planeet).
	var alt := m.y - (t.surface_height_at(m.x, m.z) if t else 0.0)
	var hi := smoothstep(60.0, 240.0, alt)
	var back_k := lerpf(Tuning.get_f("ship", "drop_cam_back", 12.0), Tuning.get_f("ship", "drop_cam_high_back", 17.0), hi)
	var up_k := lerpf(Tuning.get_f("ship", "drop_cam_up", 9.0), Tuning.get_f("ship", "drop_cam_high_up", 6.0), hi)
	var pitch := deg_to_rad(lerpf(Tuning.get_f("ship", "drop_cam_pitch_deg", 30.0), Tuning.get_f("ship", "drop_cam_high_pitch_deg", 17.0), hi))
	var dist := lerpf(back_k * catch, Tuning.get_f("ship", "drop_cam_brake_back", 13.0), b)
	var up := lerpf(up_k * catch, Tuning.get_f("ship", "drop_cam_brake_up", 6.0), b)
	# Naijlen: versnelt de Mol naar beneden, dan blijft de camera wat hoger hangen (en omgekeerd
	# bij het remmen en de klap), als een veer. Dat verkoopt de versnelling.
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
	var free_target := pos + (fwd * cos(pitch) + Vector3.DOWN * sin(pitch)) * 30.0
	var brake_target := m + fwd * 16.0 + Vector3.DOWN * 3.0
	var target := free_target.lerp(brake_target, b)
	# Schok: buffelen in de wind (met de snelheid), harder bij de stuwraketten, het ontsteken en de klap.
	var trauma := clampf(sk * sk * 0.45 + mol.thrust * 0.5 + _ignite * 0.6, 0.0, 1.0)
	var amp := deg_to_rad(Tuning.get_f("ship", "drop_cam_shake_deg", 1.4)) * trauma * trauma * shake_k
	var f := _t * 9.0
	global_position = pos
	look_at(target, Vector3.UP)
	# Traag rollen in de vrije val (het buitenbeeld leeft), weg bij het remmen.
	var roll := deg_to_rad(Tuning.get_f("ship", "drop_cam_roll_deg", 2.2)) * sk * (1.0 - b) \
			* (0.75 * sin(_chase_t * 0.6 + 0.4) + 0.25 * sin(_chase_t * 1.45))
	rotate_object_local(Vector3.FORWARD, roll)
	rotate_object_local(Vector3.UP, _look.x)
	rotate_object_local(Vector3.RIGHT, _look.y)
	rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 0.0))
	rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(0.0, f))
	rotate_object_local(Vector3.FORWARD, amp * 0.6 * _noise.get_noise_2d(f, f))
	var fov_want := lerpf(Tuning.get_f("ship", "drop_cam_fov", 70.0), Tuning.get_f("ship", "drop_cam_fov_fast", 80.0), sk)
	fov = lerpf(fov, lerpf(fov_want, 66.0, b), minf(1.0, delta * 3.0)) if delta > 0.0 else fov_want
	# Strepen en wind met de snelheid, gebrul met de stuwraketten.
	_update_streaks(sk * (1.0 - b))
	_wind.volume_db = linear_to_db(maxf(0.0005, sk * 0.55))
	_wind.pitch_scale = 0.75 + 0.5 * sk
	_roar.volume_db = linear_to_db(maxf(0.0005, mol.thrust * 0.6))
	_roar.pitch_scale = 0.85 + 0.25 * mol.thrust


## Ophalen: de camera staat opzij van de Mol, met de reus erachter (de Mol hangt tussen de kijker en
## de reus), eerst op ooghoogte op de grond.
func _start_lift_shot() -> void:
	fov = Tuning.get_f("ship", "lift_cam_fov", 62.0)
	var dir := Vector3.FORWARD
	var sky: Variant = PlanetType.params(mol.game.planet_type).get("sky", {})
	if sky is Dictionary and (sky as Dictionary).get("giant_dir") is Vector3:
		var g: Vector3 = (sky as Dictionary)["giant_dir"]
		dir = Vector3(g.x, 0.0, g.z)
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	# Iets schuin op de reus: de kabel en het schip staan dan niet recht voor zijn schijf.
	_lift_dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(20.0))
	var m := mol.placed.origin
	_lift_cam = m - _lift_dir * Tuning.get_f("ship", "lift_cam_side", 24.0)
	var t: TerrainAPI = mol.game.terrain
	var ground := t.surface_height_at(_lift_cam.x, _lift_cam.z) if t else m.y - 3.0
	_lift_cam.y = maxf(m.y - Tuning.get_f("ship", "lift_cam_below", 5.0), ground + 1.7)


## Kraanshot: de camera stijgt met de Mol mee (iets trager, zodat de ruk van de kabel in beeld komt),
## tot lift_cam_stop_m onder de baai. Daar blijft ze hangen: de Mol verdwijnt in het schip, dat groot
## boven in beeld hangt. Als hij in de baai is, wordt het zwart (de knip naar binnen).
func _update_lift(m: Vector3, delta: float) -> void:
	var ex: EksterExterior = mol.game.exterior
	var dock := ex.dock_position() if ex else m + Vector3(0.0, 300.0, 0.0)
	var t: TerrainAPI = mol.game.terrain
	var ground := t.surface_height_at(_lift_cam.x, _lift_cam.z) if t else -INF
	var want_y := minf(m.y - Tuning.get_f("ship", "lift_cam_below", 5.0), dock.y - Tuning.get_f("ship", "lift_cam_stop_m", 46.0))
	want_y = maxf(want_y, ground + 1.7)
	_lift_cam.y = lerpf(_lift_cam.y, want_y, minf(1.0, delta * 2.2)) if delta > 0.0 else want_y
	global_position = _lift_cam
	# Kijken naar de Mol; naarmate hij het schip nadert, schuift de blik naar de baai, zodat beide in
	# beeld staan.
	var near := clampf(1.0 - (dock.y - m.y) / 90.0, 0.0, 1.0)
	var target := m.lerp(dock, 0.45 * near) + Vector3(0.0, lerpf(-1.5, 2.5, near), 0.0)
	look_at(target, Vector3.UP)
	rotate_object_local(Vector3.UP, _look.x)
	rotate_object_local(Vector3.RIGHT, _look.y)
	# De kabel ratelt: een kleine schok, en een ruk bij het optrekken.
	var sk := clampf(absf(mol.vertical_speed) / 30.0, 0.0, 1.0)
	var amp := deg_to_rad(0.5) * (0.3 + 0.7 * sk) * Settings.get_f("interface/camera_shake") * (1.0 - smoothstep(0.0, 1.0, _t - 0.8) * 0.6)
	var f := _t * 7.0
	rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 3.0))
	rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(3.0, f))
	# In de baai: zwart (de Mol springt dan naar de hub).
	var in_bay := clampf(1.0 - (dock.y - m.y - 3.0) / 9.0, 0.0, 1.0)
	_fade.color.a = maxf(_fade.color.a if _black_hold >= 0.0 else 0.0, in_bay)


func _update_streaks(k: float) -> void:
	_streaks.emitting = k > 0.15
	_streaks.amount_ratio = clampf(k, 0.05, 1.0)
	var m := _streaks.process_material as ParticleProcessMaterial
	# De wind komt van onder (de Mol en de camera vallen): in cameraruimte.
	m.direction = global_basis.inverse() * Vector3.UP
	m.initial_velocity_min = 26.0 * k + 5.0
	m.initial_velocity_max = 38.0 * k + 8.0
	# Stof in de kleur van de lucht van de planeet (niet wit), en niet optellend: zachte vegen.
	var dust := _streak_color()
	_streak_mat.albedo_color = Color(dust.r, dust.g, dust.b, 0.22 * k)


## Kleur van de snelheidsstrepen: de stofwaas van deze planeet (mist en waasband van de hemel).
func _streak_color() -> Color:
	return _dust_col


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
		_hint.text = "%s  ·  SKIP" % key if mol.skip_votes == 0 else "%s  ·  SKIP  %d/%d" % [key, mol.skip_votes, mol.skip_needed]


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
	# Enkel aan de zijranden van het beeld (een brede ring rond de kijkrichting: boven en onder valt
	# hij buiten beeld), niet midden over de Mol en het landschap.
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0.0, 0.0, 1.0)
	m.emission_ring_radius = 12.0
	m.emission_ring_inner_radius = 8.0
	m.emission_ring_height = 6.0
	_streaks.process_material = m
	# Dikker en korter, met zachte uiteinden en randen (buiten-13: geen witte krassen op de lens).
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.9)
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streak_mat.albedo_color = Color(1, 1, 1, 0.0)
	_streak_mat.albedo_texture = _streak_texture()
	q.material = _streak_mat
	_streaks.draw_pass_1 = q
	_streaks.amount = 46
	_streaks.lifetime = 0.28
	_streaks.local_coords = true
	_streaks.emitting = false
	_streaks.visibility_aabb = AABB(Vector3(-20, -20, -30), Vector3(40, 40, 40))
	add_child(_streaks)
	_streaks.position = Vector3(0.0, 0.0, -8.0)


## Een zachte veeg: doorzichtig aan beide uiteinden en aan de zijkanten.
static func _streak_texture() -> ImageTexture:
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var along := float(y) / float(h - 1)
		var a_len := smoothstep(0.0, 0.35, along) * (1.0 - smoothstep(0.55, 1.0, along))
		for x in w:
			var across := absf((float(x) + 0.5) / float(w) - 0.5) * 2.0
			img.set_pixel(x, y, Color(1, 1, 1, a_len * (1.0 - across * across)))
	return ImageTexture.create_from_image(img)
