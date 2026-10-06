class_name MolRideFeel
extends Node
## Het gewicht van de Mol, gevoeld van binnen (gevoel-04). Enkel lokaal en enkel beeld:
## - een lage, constante dreun als hij rijdt (meer op volle snelheid), veel meer als hij boort, en
##   een harde ratel tegen een laag die hij niet aankan (trauma op de CameraFx van de lokale speler);
## - de camera helt met de versnelling: achterover bij het optrekken, een ruk naar voren bij het
##   remmen en stoppen, en ze hangt over in de bocht. Een veer met weinig demping geeft de naschok;
## - de klauwen van de grijper klikken vast (schok), het optrekken duwt je in de vloer, en een
##   PING geeft een tikje.
## Draait na CameraFx (process_priority): die zet de rotatie van de camera elke frame opnieuw, dit
## telt er de helling bij. De gefilterde versnelling en draaisnelheid gaan ook naar het model
## (MolVisual: veren en hellen voor wie buiten kijkt) via Mol.ride_acc / ride_turn.

var mol: Mol

var _lean := Vector2.ZERO # graden: x = kantelen (+ = omhoog kijken), y = rollen
var _lean_v := Vector2.ZERO
var _speed_was := 0.0
var _yaw_was := 0.0
var _acc := 0.0
var _turn := 0.0
var _first := true
var _mode_was := -1


func _ready() -> void:
	process_priority = 100
	mol.drop_event.connect(_on_event)


func _process(delta: float) -> void:
	if mol == null or mol.body == null or delta <= 0.0:
		return
	# Versnelling en draaisnelheid, gefilterd: bij een client komt de snelheid in stapjes binnen.
	if _first:
		_first = false
		_speed_was = mol.speed
		_yaw_was = mol.yaw
	var ground := mol.mode in [Mol.Mode.PARKED, Mol.Mode.DRIVING, Mol.Mode.AUTO_DOWN, Mol.Mode.COUNTDOWN, Mol.Mode.EXTRACTING]
	var a := (mol.speed - _speed_was) / delta if ground else 0.0
	_speed_was = mol.speed
	_acc = lerpf(_acc, clampf(a, -8.0, 8.0), minf(1.0, delta * 9.0))
	var tr := angle_difference(_yaw_was, mol.yaw) / delta if ground else 0.0
	_yaw_was = mol.yaw
	_turn = lerpf(_turn, clampf(tr, -1.5, 1.5), minf(1.0, delta * 8.0))
	mol.ride_acc = _acc
	mol.ride_turn = _turn
	var mode_now := int(mol.mode)
	var lift_start := mode_now == Mol.Mode.LIFTING and _mode_was == Mol.Mode.GRAPPLE_DOWN
	_mode_was = mode_now

	var me := _local_inside()
	# Helling: een veer naar de versnelling (en de bocht). Ook bij wie niet binnen is bijwerken, zodat
	# er geen sprong is als hij instapt.
	var lean_k := Tuning.get_f("mol", "cabin_lean_deg", 1.6)
	var lean_max := Tuning.get_f("mol", "cabin_lean_max_deg", 3.0)
	var speed_k := clampf(absf(mol.speed) / maxf(0.1, Tuning.get_f("mol", "open_speed", 1.8)), 0.0, 1.0)
	var want := Vector2(clampf(_acc * lean_k, -lean_max, lean_max),
			clampf(-_turn * (0.35 + 0.65 * speed_k) * Tuning.get_f("mol", "cabin_roll_deg", 1.2) / 0.3, -lean_max, lean_max))
	var stiff := Tuning.get_f("mol", "cabin_spring", 60.0)
	var damp := Tuning.get_f("mol", "cabin_damping", 7.0)
	var left := minf(delta, 0.1) # veer in kleine stapjes (stabiel, ook bij een lang frame)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_lean_v += ((want - _lean) * stiff - _lean_v * damp) * h
		_lean += _lean_v * h
		left -= h
	if me == null:
		return
	if lift_start:
		# De kabel trekt strak: je wordt in de vloer geduwd.
		me.camera_fx.add_trauma(0.4)
		me.camera_fx.kick(-4.5, randf_range(-1.0, 1.0))
	# Dreun: de motor en de rupsen, het boren, en een laag die te hard is.
	var trauma := 0.0
	if ground and (absf(mol.speed) > 0.05 or absf(_turn) > 0.03):
		trauma = Tuning.get_f("mol", "cabin_trauma_drive", 0.26) * (0.6 + 0.4 * speed_k)
	if mol.drilling:
		trauma = maxf(trauma, Tuning.get_f("mol", "cabin_trauma_drill", 0.5))
	if mol.blocked and ground:
		trauma = maxf(trauma, Tuning.get_f("mol", "cabin_trauma_blocked", 0.62))
	if mol.mode == Mol.Mode.LIFTING:
		trauma = maxf(trauma, 0.16 + 0.12 * clampf(absf(mol.vertical_speed) / 30.0, 0.0, 1.0)) # de kabel ratelt
	if trauma > 0.0:
		me.camera_fx.hold_trauma(trauma)
	if ground and me.camera.current:
		var shake := Settings.get_f("interface/camera_shake")
		me.camera.rotation.x += deg_to_rad(_lean.x) * shake
		me.camera.rotation.z += deg_to_rad(_lean.y) * shake


## De worm raakt de romp (pakket G1, gevoel2-05): de cabine helt hard weg van de klap (een stoot op de
## veer: ±8°, met naschok) en de camera krijgt een ruk. `local_n`: de normaal van de romp waar hij
## raakt, t.o.v. de Mol.
func ram_hit(local_n: Vector3, strength: float) -> void:
	_lean_v += Vector2(local_n.z * 45.0, local_n.x * 65.0) * strength
	var me := _local_inside()
	if me:
		me.camera_fx.kick(-3.5 * strength, -local_n.x * 4.0 * strength)


## De lokale speler, als hij in de Mol is; anders null. (De schok telt ook in het buitenzicht: daar
## schokt MolChaseCam mee met dezelfde trauma.)
func _local_inside() -> Player:
	var me: Player = mol.game.player_node(Net.my_id()) if mol.game else null
	if me == null or me.camera == null or me.camera_fx == null:
		return null
	if not (me.seated or mol.contains_point(me.global_position)):
		return null
	return me


func _on_event(event: Mol.Event) -> void:
	var me := _local_inside()
	if me == null:
		return
	match event:
		Mol.Event.GRAPPLED:
			# De klauwen klikken vast: een harde klik door de romp.
			me.camera_fx.add_trauma(0.5)
			me.camera_fx.kick(-3.0, randf_range(-1.5, 1.5))
		Mol.Event.PING:
			me.camera_fx.kick(0.8, 0.0)
