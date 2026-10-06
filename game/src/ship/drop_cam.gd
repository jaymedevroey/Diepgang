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
## Golf 3 (gevoel2-11, buiten2-2, -3, -7, gevoel-17, gevoel2-12): per fase twee of drie plannen.
## - De val: het volgshot kijkt de eerste seconden hoger (de onthulling: de reus en zijn ring in het
##   bovenste derde, de Mol in het midden, het landschap onderaan) en kantelt dan naar de landingsplek;
##   onderweg val je door een stoflaag (±110-210 m, parallax: je ziet dat je valt); bij het ontsteken
##   van de stuwraketten een knip naar de flank (vlammen, de grond die op je afkomt); de laatste meters
##   een vaste camera op de grond (Plan.GROUND) die de Mol ziet neerkomen: de klap met een stofgolf naar
##   de camera toe, brokken, een stoot, en pas dan de knip naar binnen.
## - Het ophalen begint buiten al bij het zakken van de grijper (de klauwen op het dak, de klik): een
##   kraanshot op de grond met de reus naast de Mol (niet erachter), dat niet meestijgt (de Mol
##   verdwijnt omhoog); dan een knip naar een camera naast de Mol die omlaag kijkt (de landingsplek en
##   de ploeg vallen weg); de laatste tientallen meters het schip groot boven in beeld, de Mol de baai in.
## Ook van hier: de balken boven en onder, de tip "overslaan", zwart bij overslaan, het stof bij de
## klap (een flits), het oorsuizen en de klank op het moment dat je de besturing terugkrijgt. De muis
## laat de blik een klein beetje opzij kijken (veert terug), nooit rond de Mol draaien.

enum Shot { NONE, SHIP, CHASE, LIFT }
## Plannen binnen een shot (golf 3): de val CHASE → FLANK → GROUND, het ophalen CRANE → FALL → BAY.
enum Plan { CHASE, FLANK, GROUND, CRANE, FALL, BAY }

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
var plan := Plan.CHASE
var _plan_t := 0.0 # seconden in dit plan
var _ground_pos := Vector3.ZERO # Plan.GROUND: de vaste camera op de grond
var _ground_look := Vector3.ZERO
var _lift_t := -1.0 # seconden sinds de Mol van de grond loskwam (−1 = de grijper zakt nog)
var _handover_pending := false # de besturing kwam terug terwijl het buitenbeeld van de klap nog liep
var _clouds: MultiMeshInstance3D
var _wave: GPUParticles3D # stofgolf naar de grondcamera toe bij de klap
var _wave_mat: StandardMaterial3D


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
	_build_clouds()
	_build_wave()


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
	_plan_t = 0.0
	_handover_pending = false
	if mol.mode == Mol.Mode.LIFTING or mol.mode == Mol.Mode.GRAPPLE_DOWN:
		shot = Shot.LIFT
		_start_lift_shot()
	else:
		plan = Plan.CHASE
		_place_clouds()
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
	_clouds.visible = false
	if _handover_pending:
		_handover_pending = false
		_bars_want = 0.0
		_play2d("drop_ready", -9.0)
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
	# Het ophalen begint buiten al bij het zakken van de grijper: je ziet de klauwen op het dak komen.
	if mol.mode != Mol.Mode.LIFTING and mol.mode != Mol.Mode.GRAPPLE_DOWN:
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


## De besturing komt terug: balken weg, een belletje van de firma. Loopt het buitenbeeld van de klap
## nog, dan pas bij de knip naar binnen.
func handover() -> void:
	if current and _land_t >= 0.0:
		_handover_pending = true
		return
	_bars_want = 0.0
	_play2d("drop_ready", -9.0)


func _on_drop_event(event: Mol.Event) -> void:
	if event == Mol.Event.THRUST and current:
		_ignite = 1.0
		_play2d("drop_thrust_ignite", -4.0)


## Geland terwijl dit beeld loopt: nog even buiten blijven, met een harde schok (de stofring), en op
## de grondcamera een stofgolf naar de camera toe met brokken.
func _on_landed() -> void:
	if current and shot == Shot.CHASE:
		_land_t = 0.0
		_ignite = 1.6
		if plan == Plan.GROUND:
			_burst_wave()


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
	# Waar de Mol getekend wordt (fysica-interpolatie tussen twee ticks): anders trilt hij in beeld
	# boven 60 fps (hij valt tot 55 m/s). Na een sprong is de interpolatie gereset (Mol._place).
	var m := mol.body.get_global_transform_interpolated().origin
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
	_plan_t += delta
	if shot == Shot.CHASE and _update_plans(m, back, delta):
		_update_streaks(0.0)
		_wind.volume_db = linear_to_db(maxf(0.0005, sk * 0.3))
		_roar.volume_db = linear_to_db(maxf(0.0005, mol.thrust * 0.7))
		_roar.pitch_scale = 0.85 + 0.25 * mol.thrust
		return
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
	# De onthulling: de eerste seconden van het volgshot kijkt hij hoger en wat naar de reus toe (de reus
	# en zijn ring in het bovenste derde), dan kantelt hij naar de landingsplek (buiten2-2).
	var rv := 1.0 - smoothstep(Tuning.get_f("ship", "drop_cam_reveal_s", 1.6),
			Tuning.get_f("ship", "drop_cam_reveal_s", 1.6) + Tuning.get_f("ship", "drop_cam_reveal_blend_s", 1.8), _chase_t)
	pitch = lerpf(pitch, deg_to_rad(Tuning.get_f("ship", "drop_cam_reveal_pitch_deg", 0.0)), rv * hi)
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
	var look_dir := fwd.rotated(Vector3.UP, _giant_turn(fwd) * rv * hi)
	var free_target := pos + (look_dir * cos(pitch) + Vector3.DOWN * sin(pitch)) * 30.0
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
	var fov_want := lerpf(Tuning.get_f("ship", "drop_cam_fov", 70.0), Tuning.get_f("ship", "drop_cam_fov_fast", 80.0), sk * sk)
	fov = lerpf(fov, lerpf(fov_want, 66.0, b), minf(1.0, delta * 3.0)) if delta > 0.0 else fov_want
	# Strepen en wind met de snelheid, gebrul met de stuwraketten.
	_update_streaks(sk * (1.0 - b))
	_wind.volume_db = linear_to_db(maxf(0.0005, sk * 0.55))
	_wind.pitch_scale = 0.75 + 0.5 * sk
	_roar.volume_db = linear_to_db(maxf(0.0005, mol.thrust * 0.6))
	_roar.pitch_scale = 0.85 + 0.25 * mol.thrust


## Ophalen: eerst een kraanshot op de grond, met de reus NAAST de Mol (niet erachter, buiten2-3):
## de kijkrichting staat lift_cam_giant_deg van de reus af.
func _start_lift_shot() -> void:
	fov = Tuning.get_f("ship", "lift_cam_fov", 62.0)
	plan = Plan.CRANE
	_lift_t = 0.0 if mol.mode == Mol.Mode.LIFTING else -1.0
	var dir := Vector3.FORWARD
	var sky: Variant = PlanetType.params(mol.game.planet_type).get("sky", {})
	if sky is Dictionary and (sky as Dictionary).get("giant_dir") is Vector3:
		var g: Vector3 = (sky as Dictionary)["giant_dir"]
		dir = Vector3(g.x, 0.0, g.z)
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	_lift_dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(Tuning.get_f("ship", "lift_cam_giant_deg", 38.0)))
	var m := mol.placed.origin
	_lift_cam = m - _lift_dir * Tuning.get_f("ship", "lift_cam_side", 24.0)
	var t: TerrainAPI = mol.game.terrain
	var ground := t.surface_height_at(_lift_cam.x, _lift_cam.z) if t else m.y - 3.0
	_lift_cam.y = ground + 1.6


## Ophalen in drie plannen (gevoel2-11):
## - CRANE: de camera blijft op de grond en kantelt mee omhoog; de grijper zakt op het dak, de Mol
##   gaat los en verdwijnt omhoog (zo zie je dat hij stijgt);
## - FALL (na lift_cam_crane_s): naast en boven de Mol, omlaag kijkend: de landingsplek, het kamp en
##   wie achterblijft vallen onder je weg;
## - BAY (de laatste lift_cam_bay_m): onder het schip, dat groot boven in beeld hangt; de Mol verdwijnt
##   in de baai, en als hij erin is wordt het zwart (de knip naar binnen).
func _update_lift(m: Vector3, delta: float) -> void:
	var ex: EksterExterior = mol.game.exterior
	var dock := ex.dock_position() if ex else m + Vector3(0.0, 300.0, 0.0)
	var t: TerrainAPI = mol.game.terrain
	_plan_t += delta
	if mol.mode == Mol.Mode.LIFTING:
		_lift_t = maxf(_lift_t, 0.0) + delta
	if plan == Plan.CRANE and _lift_t > Tuning.get_f("ship", "lift_cam_crane_s", 2.8):
		plan = Plan.FALL
		_plan_t = 0.0
	if plan != Plan.BAY and dock.y - m.y < Tuning.get_f("ship", "lift_cam_bay_m", 90.0):
		plan = Plan.BAY
		_plan_t = 0.0
		_lift_cam = dock - _lift_dir * 22.0 + Vector3(0.0, -Tuning.get_f("ship", "lift_cam_stop_m", 46.0), 0.0)
	var target := m
	match plan:
		Plan.CRANE:
			# Een trage zijwaartse rijbeweging (het beeld leeft), op de grond.
			var side := _lift_dir.cross(Vector3.UP).normalized()
			var pos := _lift_cam + side * 0.7 * _plan_t
			if t:
				pos.y = maxf(pos.y, t.surface_height_at(pos.x, pos.z) + 1.6)
			global_position = pos
			target = m + Vector3(0.0, 1.8, 0.0)
			fov = lerpf(fov, Tuning.get_f("ship", "lift_cam_fov", 62.0), minf(1.0, delta * 2.0)) if delta > 0.0 else fov
		Plan.FALL:
			# Naast en boven de Mol, die traag omhoog uit beeld schuift (de camera stijgt iets trager) en
			# waar de camera langzaam omheen draait; onder hem valt de landingsplek weg.
			var side := _lift_dir.cross(Vector3.UP).normalized().rotated(Vector3.UP, deg_to_rad(9.0) * _plan_t)
			var behind := side.cross(Vector3.UP).normalized()
			var rise := minf(_plan_t * 0.8, 2.5)
			global_position = m - side * 11.0 - behind * 4.0 + Vector3.UP * (6.5 - rise)
			target = m + Vector3(0.0, -13.0, 0.0) + side * 3.0
			fov = 64.0
		_:
			global_position = _lift_cam
			var near := clampf(1.0 - (dock.y - m.y) / 90.0, 0.0, 1.0)
			target = m.lerp(dock, 0.45 * near) + Vector3(0.0, lerpf(-1.5, 2.5, near), 0.0)
			fov = Tuning.get_f("ship", "lift_cam_fov", 62.0)
	var up_v := Vector3.UP if absf((target - global_position).normalized().y) < 0.98 else -_lift_dir
	look_at(target, up_v)
	rotate_object_local(Vector3.UP, _look.x)
	rotate_object_local(Vector3.RIGHT, _look.y)
	# De kabel ratelt: een kleine schok, en een ruk bij het vastklikken en het optrekken.
	var sk := clampf(absf(mol.vertical_speed) / 30.0, 0.0, 1.0)
	var amp := deg_to_rad(0.5) * (0.3 + 0.7 * sk) * Settings.get_f("interface/camera_shake") * (1.0 - smoothstep(0.0, 1.0, _t - 0.8) * 0.6)
	if plan == Plan.FALL:
		amp *= 1.6 # vastgemaakt aan de Mol: elke ruk van de kabel voel je
	var f := _t * 7.0
	rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 3.0))
	rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(3.0, f))
	# In de baai: zwart (de Mol springt dan naar de hub).
	var in_bay := clampf(1.0 - (dock.y - m.y - 3.0) / 9.0, 0.0, 1.0)
	_fade.color.a = maxf(_fade.color.a if _black_hold >= 0.0 else 0.0, in_bay)


## De plannen van de val na het volgshot (true = dit frame afgehandeld):
## - FLANK (vanaf het ontsteken van de stuwraketten): naast de Mol, iets lager, schuin omlaag langs de
##   vlammen naar de grond die op je afkomt;
## - GROUND (de laatste drop_cam_ground_cut_m): een vaste camera op de grond, schuin achter de Mol, die
##   hem ziet neerkomen en de klap ziet.
func _update_plans(m: Vector3, back: Vector3, delta: float) -> bool:
	var t: TerrainAPI = mol.game.terrain
	if t == null:
		return false
	var ground := t.surface_height_at(m.x, m.z)
	var alt := m.y - ground
	if plan == Plan.CHASE and _brake_t >= Tuning.get_f("ship", "drop_cam_flank_after_s", 0.15) and alt > Tuning.get_f("ship", "drop_cam_ground_cut_m", 26.0) + 8.0:
		plan = Plan.FLANK
		_plan_t = 0.0
	if plan != Plan.GROUND and _land_t < 0.0 and alt < Tuning.get_f("ship", "drop_cam_ground_cut_m", 26.0) and mol.vertical_speed < -1.0:
		plan = Plan.GROUND
		_plan_t = 0.0
		_place_ground_cam(m, back, ground)
	var side := back.cross(Vector3.UP).normalized()
	var shake_k := Settings.get_f("interface/camera_shake")
	var trauma := clampf(mol.thrust * 0.55 + _ignite * 0.6, 0.0, 1.0)
	var f := _t * 9.0
	match plan:
		Plan.FLANK:
			# Vast aan de Mol (hij remt hard af: de grond schiet op je af), met de vlammen in beeld.
			global_position = m + side * 11.0 + back * 5.0 + Vector3.UP * 0.6
			look_at(m + Vector3.DOWN * 4.5 - back * 1.5, Vector3.UP)
			fov = lerpf(fov, 74.0, minf(1.0, delta * 4.0))
		Plan.GROUND:
			global_position = _ground_pos
			# Volgt de Mol naar beneden (eerst schuin omhoog, dan de klap op ooghoogte).
			var want := m + Vector3(0.0, 0.6, 0.0)
			_ground_look = want if _plan_t < 0.01 else _ground_look.lerp(want, minf(1.0, delta * 9.0))
			look_at(_ground_look, Vector3.UP)
			# Na de klap: een stoot (de grond trilt mee) en een korte zoom naar binnen.
			var hit := 0.0 if _land_t < 0.0 else exp(-_land_t * 5.0)
			trauma = maxf(trauma * 0.5, hit)
			fov = lerpf(64.0, 58.0, hit) if _land_t >= 0.0 else 64.0
		_:
			return false
	var amp := deg_to_rad(Tuning.get_f("ship", "drop_cam_shake_deg", 1.4)) * trauma * trauma * shake_k * (2.2 if plan == Plan.GROUND else 1.0)
	rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 0.0))
	rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(0.0, f))
	rotate_object_local(Vector3.FORWARD, amp * 0.6 * _noise.get_noise_2d(f, f))
	rotate_object_local(Vector3.UP, _look.x)
	rotate_object_local(Vector3.RIGHT, _look.y)
	return true


## De grondcamera: drop_cam_ground_dist m van de landingsplek, schuin achter de Mol (de Mol en wat
## voor hem ligt, zoals de landingsplek, in beeld), op ooghoogte.
func _place_ground_cam(m: Vector3, back: Vector3, ground: float) -> void:
	var t: TerrainAPI = mol.game.terrain
	var best := Vector3.ZERO
	var best_score := -INF
	for a: float in [-50.0, 50.0, -75.0, 75.0]:
		var d := back.rotated(Vector3.UP, deg_to_rad(a))
		var p := Vector3(m.x, ground, m.z) + d * Tuning.get_f("ship", "drop_cam_ground_dist", 17.0)
		var h := t.surface_height_at(p.x, p.z)
		# Liefst vlak (geen rug tussen de camera en de Mol) en zo laag mogelijk.
		var score := -absf(h - ground) - absf(a) * 0.01
		if score > best_score:
			best_score = score
			best = Vector3(p.x, h + 1.35, p.z)
	_ground_pos = best
	_ground_look = m


## Welke kant de reus op staat t.o.v. de kijkrichting (radialen, hooguit drop_cam_reveal_turn_deg).
func _giant_turn(fwd: Vector3) -> float:
	var sky: Variant = PlanetType.params(mol.game.planet_type).get("sky", {})
	if not (sky is Dictionary and (sky as Dictionary).get("giant_dir") is Vector3):
		return 0.0
	var g: Vector3 = (sky as Dictionary)["giant_dir"]
	var ang := Vector2(fwd.x, fwd.z).angle_to(Vector2(g.x, g.z))
	var lim := deg_to_rad(Tuning.get_f("ship", "drop_cam_reveal_turn_deg", 16.0))
	return clampf(-ang, -lim, lim)


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


## Een stoflaag om doorheen te vallen (buiten2-2: "iets om doorheen te vallen op ±150-250 m"): grote,
## zachte plukken in de stofkleur van de planeet, rond de kolom van de val tussen 110 en 210 m.
func _build_clouds() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _puff_texture()
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 6.0
	m.distance_fade_max_distance = 40.0
	m.disable_receive_shadows = true
	q.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = 70
	_clouds = MultiMeshInstance3D.new()
	_clouds.name = "DropClouds"
	_clouds.multimesh = mm
	_clouds.top_level = true
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds.visible = false
	add_child(_clouds)


## De stoflaag rond de landingsplek leggen (bij elke drop: een andere planeet, een andere stofkleur).
func _place_clouds() -> void:
	var t: TerrainAPI = mol.game.terrain
	if t == null or Tuning.get_f("ship", "drop_cloud_alpha", 0.3) <= 0.0:
		_clouds.visible = false
		return
	var m := mol.placed.origin
	var ground := t.surface_height_at(m.x, m.z)
	if m.y - ground < 160.0:
		_clouds.visible = false
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.x * 13.0 + m.z * 7.0) + mol.game.planet_type * 101
	var mm := _clouds.multimesh
	var a := Tuning.get_f("ship", "drop_cloud_alpha", 0.3)
	var col := _dust_col.lightened(0.12)
	for i in mm.instance_count:
		# De helft dicht bij de kolom van de val (daar val je doorheen), de rest verder (parallax).
		var r := rng.randf_range(4.0, 40.0) if i % 2 == 0 else rng.randf_range(40.0, 170.0)
		var p := Vector3(m.x, ground, m.z) + Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * r
		p.y += rng.randf_range(110.0, 210.0)
		var s := rng.randf_range(18.0, 46.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s * rng.randf_range(1.2, 1.8), s, s)), p))
		mm.set_instance_color(i, Color(col.r * rng.randf_range(0.92, 1.06), col.g * rng.randf_range(0.92, 1.06), col.b, a * rng.randf_range(0.5, 1.0)))
	_clouds.custom_aabb = AABB(Vector3(m.x - 220.0, ground + 80.0, m.z - 220.0), Vector3(440.0, 170.0, 440.0))
	_clouds.visible = true


static func _puff_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.09
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var k := clampf(1.0 - smoothstep(0.25, 1.0, d + 0.25 * noise.get_noise_2d(x, y)), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, k * k))
	return ImageTexture.create_from_image(img)


## Stofgolf bij de klap, op de grondcamera: grote, zachte wolken die van de Mol naar de camera rollen.
func _build_wave() -> void:
	_wave = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.15, 1)
	pm.spread = 38.0
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 17.0
	pm.damping_min = 4.0
	pm.damping_max = 7.0
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 1.6
	pm.scale_max = 3.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.0, 0.3, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.12, Color(1, 1, 1, 0.85))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_wave.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(3.0, 3.0)
	_wave_mat = StandardMaterial3D.new()
	_wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # stof in de zon (belicht was het roet)
	_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_wave_mat.vertex_color_use_as_albedo = true
	_wave_mat.albedo_texture = _puff_texture()
	_wave_mat.proximity_fade_enabled = true
	_wave_mat.proximity_fade_distance = 1.2
	q.material = _wave_mat
	_wave.draw_pass_1 = q
	_wave.amount = 46
	_wave.lifetime = 1.6
	_wave.one_shot = true
	_wave.explosiveness = 0.85
	_wave.local_coords = false
	_wave.emitting = false
	_wave.top_level = true
	_wave.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 20, 50))
	add_child(_wave)


func _burst_wave() -> void:
	var m := mol.placed.origin
	var t: TerrainAPI = mol.game.terrain
	var g := t.surface_height_at(m.x, m.z) if t else m.y
	var to_cam := Vector3(_ground_pos.x - m.x, 0.0, _ground_pos.z - m.z).normalized()
	var at := Vector3(m.x, g + 0.6, m.z) + to_cam * 4.5
	_wave.global_transform = Transform3D(Basis.looking_at(-to_cam, Vector3.UP), at)
	# Stof in de kleur van de grond van deze planeet (niet de laag onder de Mol: dat is altijd klei).
	var dust: Color = (PlanetType.ground(mol.game.planet_type).light as Color).lerp(_dust_col, 0.4)
	_wave_mat.albedo_color = Color(dust.lightened(0.15), 1.0)
	_wave.restart()


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
