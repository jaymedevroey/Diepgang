class_name Player
extends CharacterBody3D
## Een robot. Op de peer die hem bestuurt (authority) is hij lokaal: invoer, camera,
## houweel, en hij stuurt zijn toestand ±20× per seconde. Op de andere peers is hij een
## kopie die geïnterpoleerd wordt (GDD §9: de client bepaalt de eigen beweging).
## Opbouw lokaal: Player (yaw) > Head (pitch, logica) en CamRig (top_level) > Camera3D (CameraFx) > Pickaxe, Drill
## Gereedschap: 1 = houweel, 2 = boor (of het muiswieltje).
## Naam van de node = peer-id, onder Game/Players, zodat RPC-paden overal gelijk zijn.
##
## Fysica-interpolatie (gevoel-02): het lijf beweegt per physics-tick (60 Hz) en wordt getekend
## tussen twee ticks in. De camera hangt NIET aan het lijf: CamRig staat los (top_level, zonder
## interpolatie) en wordt elke frame gezet op de geïnterpoleerde plek van het lijf (of van de Mol als
## je zit of vastzit), met de kijkrichting van nu. Zo volgt het beeld de muis meteen en loopt het
## vloeiend op 144 Hz. Na een sprong of teleport: reset_physics_interpolation() (zie _check_jump).
##
## Bewegen (gevoel-01, waarden in player.cfg): versnellen en remmen in ±0,1 s, minder controle in
## de lucht, sprint (Shift) en hurken (Ctrl), coyote-tijd en sprongbuffer, een landingsdip met stof,
## en een lichte loopbeweging van de camera (uit te zetten: Settings interface/head_bob).

const LAYER_PLAYERS := 1 << 2
## RUBBLE: puin van een instorting houdt je tegen (wegbikken of erover springen).
const MASK := Layers.TERRAIN | Layers.LOOT | Layers.LIFT | Layers.BOUNDS | Layers.RUBBLE
const SEND_INTERVAL := 0.05
const INTERP_DELAY_MS := 100.0

enum Action { SWING, TOOL_PICKAXE, TOOL_DRILL, DRILL_ON, DRILL_OFF, CARRY_ON, CARRY_OFF }

## Na een val onder de wereld teruggezet (HUD toont een melding).
signal rescued
signal tool_changed(tool: Node3D)
## Na de drop: de speler heeft de besturing terug (einde van het filmpje).
signal control_returned

var peer_id := 1
var color := Color(0.95, 0.55, 0.12)
var game: Node # Game
var is_local := false

var head: Node3D
## Lokaal: het oog, los van het lijf (top_level), elke frame gezet (zie _update_rig).
var cam_rig: Node3D
var camera: Camera3D
var camera_fx: CameraFx
## Bewegen (lokaal).
var sprinting := false
var crouching := false
## Buitenzicht als piloot (C). Enkel bij de lokale speler.
var chase: MolChaseCam
## Buitenbeeld tijdens de drop en het ophalen (enkel lokaal, zie DropCam).
var drop_cam: DropCam
## Filmpje: van het loslaten in de hub tot de overdracht na de landing (en het buitenbeeld bij het
## ophalen). Geen eigen beweging, geen gereedschap; de HUD verbergt dan vizier en meldingen.
var cinematic := false
var _drop_cine := false # deze drop meegemaakt vanuit de Mol (van het loslaten tot de overdracht)
var _handover := 0.0 # seconden tot de besturing terugkomt na de landing
# Meerijden in de Mol: zijn transform bij de vorige tick (zie _ride_mol).
var _mol_ref := Transform3D()
var _stun := 0.0 # seconden geen controle (geraakt door een rots)
var _riding := false
# Vast in de Mol tijdens de drop en het ophalen: [positie lokaal t.o.v. de Mol, draaiing t.o.v. de Mol].
var _attached: Variant = null
# Na een sprong van de Mol: zoveel ticks vast blijven (zijn botsvorm komt pas een tick later aan).
var _hold_ticks := 0
var pickaxe: Pickaxe
var drill: Drill
var tools: Array[Node3D] = []
var active_tool: Node3D
var carry: Carry
var rig: RobotRig
var flying := false
## In de stoel van de Mol (piloot).
var seated := false
## Neergaan (Rescue, GDD §6): de toestand van deze robot (Rescue.Life) en zijn ragdoll zolang hij
## omver of neer ligt. Dan staat de speler op de plek van zijn romp (streaming, netwerk, magma, "aan
## boord") en kijkt de eigen camera van achter naar de pop. Kapot: een spookdrone.
var life := 0
var ragdoll: RobotRagdoll
var _drone: SpectatorDrone
## Hoogste punt van de huidige sprong of val (valschade: enkel wie van een richel of in een put valt,
## niet wie uit De Ekster springt).
var _air_top := -INF
var _phys_last := Vector3.ZERO # plek na de vorige tick (een sprong van buitenaf is geen val)

var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _look_yaw := 0.0
## Kleur waarin de flits van een klap uitdooft, per bron (Rescue.damaged): een rots of val warm wit,
## gas oranje, de worm rood.
const IMPACT_TINTS := {"rock": Color(1.0, 0.86, 0.7), "fall": Color(1.0, 0.92, 0.82), "gas": Color(1.0, 0.55, 0.15),
		"worm": Color(0.95, 0.18, 0.1), "": Color(1.0, 0.9, 0.85)}
## Vaste camerapunten in de Mol (Mol-ruimte) voor wie er neerligt of binnengedragen wordt: hoog in
## de hoeken van cabine en laadruim en in het midden, zodat de camera nooit in een lijf of wand zit.
const CABIN_CAMS: Array[Vector3] = [Vector3(1.5, 1.05, -2.8), Vector3(-1.5, 1.05, -2.8), Vector3(1.5, 1.05, 3.6),
		Vector3(-1.5, 1.05, 3.6), Vector3(0.0, 1.3, 0.4)]
const SEAT_FEET := Vector3(0.0, -1.12, -1.82)
const STAND_HEIGHT := 1.4
const EYE_STAND := 1.2

# Bewegen en camera (lokaal).
var _coyote := 0.0
var _jump_buffer := 0.0
var _ride_yaw := 0.0 # draaiing die de Mol in de laatste tick gaf (de camera mengt hem in, zie _update_rig)
var _land_impulse := 0.0 # m/s neerwaarts bij de laatste landing, nog toe te passen op de dip
var _dip := 0.0 # landingsdip van het oog (m, veer)
var _dip_vel := 0.0
var _bob_phase := 0.0
var _bob_amount := 0.0
var _tilt := 0.0
var _last_pos := Vector3.ZERO
var _was_attached := false

## Het klapmoment (golf 3, gevoel2-02): flits en FOV-stoot. Lokaal.
var impact_fx: ImpactFx
## Gehurkt en geen plaats om recht te staan (gevoel2-13): de HUD legt het uit.
var crouch_blocked := false
var _fov_base := 80.0
var _sprint_fov := 0.0
var _turn_roll := 0.0
var _last_yaw := 0.0
# Hit-stop en overgang naar de volgcamera: het beeld blijft even staan, dan glijdt het naar achter de pop.
var _impact_hold := 0.0
var _view_from := Transform3D()
var _view_blend := 1.0
var _orbit_pos := Vector3.INF # de volgcamera, afgevlakt
var _cabin_pick := -1 # vast camerapunt in de Mol (index in CABIN_CAMS)
var _unstick := Vector3.ZERO # gehurkt vast: richting naar een plek waar je recht kan staan
var _unstick_t := 0.0

var _send_timer := 0.0
# Interpolatie (kopie): [lokale ontvangsttijd in ms, positie, yaw, pitch]
var _snapshots: Array = []
var _clock_offset := INF


func _ready() -> void:
	name = str(peer_id)
	set_multiplayer_authority(peer_id)
	is_local = peer_id == multiplayer.get_unique_id()
	collision_layer = LAYER_PLAYERS
	collision_mask = MASK
	# Geen platformsnelheid van de Mol erbij: meerijden doet _ride_mol, anders telt het dubbel.
	platform_floor_layers = 0
	platform_wall_layers = 0

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = STAND_HEIGHT
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = STAND_HEIGHT * 0.5
	add_child(shape)
	_shape = shape
	_capsule = capsule

	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE_STAND
	add_child(head)
	# Lokaal bewegt het lijf in de physics-tick: tekenen met interpolatie. Een kopie van een andere
	# speler beweegt in _process (snapshots): zonder (Main staat standaard uit, zie main.tscn).
	physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_ON if is_local else PHYSICS_INTERPOLATION_MODE_OFF
	if is_local:
		process_priority = -100 # het oog vóór de HUD en de rest zetten (die lezen de camera)
		cam_rig = Node3D.new()
		cam_rig.name = "CamRig"
		cam_rig.top_level = true
		cam_rig.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
		add_child(cam_rig)
	var lamp_parent: Node3D = cam_rig if is_local else head

	var lamp := SpotLight3D.new()
	lamp.name = "HelmetLamp" # F1: Upgrades.apply_lamp (helmlamp T2) zoekt hem op naam
	# Warm wit, niet amber (release-audit binnen-01/02): een amber bundel kleurde elke laag oranje,
	# ook het koele graniet. De lamp blijft warm; de kleur van de rots leest nu zelf.
	lamp.light_color = Color(1.0, 0.86, 0.68)
	# Minder fel vlak voor je, iets meer in de verte (gevoel-19: op 1 m was de kern een egale vlek).
	lamp.light_energy = Tuning.get_f("player", "lamp_energy", 5.0)
	lamp.spot_attenuation = Tuning.get_f("player", "lamp_decay", 1.0)
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	lamp.light_volumetric_fog_energy = 1.6 # de bundel leest in het stof
	# Boven en naast het oog, zoals op een helm: zo werpen putjes en richels schaduw.
	lamp.position = Vector3(0.18, 0.22, 0.05)
	# Helmlampen van anderen zonder schaduw: GDD §9 budget van 4-8 schaduwlampen.
	lamp.shadow_enabled = is_local or Tuning.value("player", "remote_lamp_shadows", true)
	# Gereedschap in beeld (laag 2) niet: van zo dichtbij brandt het uit. Het heeft een eigen vullicht.
	lamp.light_cull_mask = ~PickaxeModel.VIEWMODEL_LAYER
	lamp_parent.add_child(lamp)
	# Brede, zwakke gloed rond de bundel: geen harde lichtcirkel (zaklamp-in-een-kelder-gevoel),
	# zoals een echte helmlamp met een hete kern en een zachte rand.
	var fill := SpotLight3D.new()
	fill.name = "LampFill"
	fill.light_color = Color(1.0, 0.87, 0.72)
	fill.light_energy = Tuning.get_f("player", "lamp_fill_energy", 0.9)
	fill.spot_range = 13.0
	fill.spot_angle = 80.0
	fill.spot_angle_attenuation = 1.6
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.3
	fill.light_cull_mask = ~PickaxeModel.VIEWMODEL_LAYER
	fill.position = lamp.position
	lamp_parent.add_child(fill)

	if is_local:
		_setup_local()
	else:
		_setup_remote()


func _setup_local() -> void:
	camera = Camera3D.new()
	_fov_base = Settings.get_f("video/fov")
	camera.fov = _fov_base
	Settings.changed.connect(func(key: String) -> void:
		if key == "video/fov":
			_fov_base = Settings.get_f("video/fov")
			camera.fov = _fov_base)
	camera.near = 0.05
	cam_rig.add_child(camera)
	camera.make_current()

	camera_fx = CameraFx.new()
	camera_fx.camera = camera
	add_child(camera_fx)
	impact_fx = ImpactFx.new()
	impact_fx.name = "ImpactFx"
	add_child(impact_fx)

	pickaxe = Pickaxe.new()
	pickaxe.terrain = game.terrain
	pickaxe.sync = game.terrain_sync
	pickaxe.finds = game.finds
	pickaxe.ores = game.ores
	pickaxe.camera = camera
	pickaxe.body = self
	pickaxe.fx = game.fx
	pickaxe.camera_fx = camera_fx
	pickaxe.color = color
	pickaxe.swung.connect(_send_action.bind(Action.SWING))
	camera.add_child(pickaxe)

	drill = Drill.new()
	drill.terrain = game.terrain
	drill.sync = game.terrain_sync
	drill.finds = game.finds
	drill.ores = game.ores
	drill.camera = camera
	drill.body = self
	drill.fx = game.fx
	drill.camera_fx = camera_fx
	drill.color = color
	drill.running_changed.connect(func(on: bool) -> void:
		_send_action(Action.DRILL_ON if on else Action.DRILL_OFF))
	camera.add_child(drill)

	tools = [pickaxe, drill]
	select_tool(0)

	carry = Carry.new()
	carry.name = "Carry"
	carry.player = self
	carry.finds = game.finds
	add_child(carry)
	carry.changed.connect(func(it: FindItem) -> void:
		# Handen vol: gereedschap weg zolang je draagt (en in het schip sowieso weg).
		active_tool.set_active(it == null and carry.body_peer < 0 and not _holstered and _tools_allowed())
		_send_action(Action.CARRY_ON if it or carry.body_peer >= 0 else Action.CARRY_OFF))
	game.mol.pilot_changed.connect(_on_pilot_changed)
	chase = MolChaseCam.new()
	chase.name = "ChaseCam"
	chase.mol = game.mol
	# Deze camera's zetten zichzelf elke frame (in _process): geen interpolatie van het lijf erbij.
	chase.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	add_child(chase)
	drop_cam = DropCam.new()
	drop_cam.name = "DropCam"
	drop_cam.physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
	add_child(drop_cam)
	drop_cam.setup(game.mol)
	game.mol.landed.connect(_on_mol_landed)
	game.mol.drop_event.connect(_on_drop_event)
	game.mol.snapped.connect(_on_mol_snapped)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## De Mol sprong (hub ↔ buitenschip, of overslaan): wie erin zat, springt mee naar dezelfde plek
## in de Mol. Wie al vastzit (drop, ophalen), houdt zijn plek; anders telt de plek van vóór de sprong.
func _on_mol_snapped(old_xf: Transform3D, new_xf: Transform3D) -> void:
	if drop_cam.current:
		drop_cam.on_mol_snapped() # overslaan: even zwart, het buitenbeeld begint opnieuw
	elif _attached != null:
		drop_cam.hold_black() # binnen meegesprongen: zwart tot de Mol er ook staat
	var local := old_xf.affine_inverse() * global_position
	if _attached != null:
		local = _attached[0]
	elif not seated and not Mol.INSIDE.has_point(local):
		return
	global_position = new_xf * local
	reset_physics_interpolation()
	_mol_ref = new_xf
	_attached = [local, rotation.y - game.mol.yaw if _attached == null else float(_attached[1])]
	_hold_ticks = 4


## Momenten van de drop, voor wie in de Mol zit: de luiken, het loslaten (val in de hub).
func _on_drop_event(event: Mol.Event) -> void:
	var mol: Mol = game.mol
	if not (seated or mol.contains_point(global_position)):
		return
	match event:
		Mol.Event.DOORS:
			camera_fx.add_trauma(0.2)
			camera_fx.kick(-1.5, 0.0)
		Mol.Event.RELEASE:
			# De vloer valt weg: even gewichtloos, een ruk omhoog, en vanaf nu het filmpje.
			_drop_cine = true
			_handover = 0.0
			camera_fx.add_trauma(0.35)
			camera_fx.kick(3.5, randf_range(-2.0, 2.0))
			if active_tool:
				active_tool.set_active(false)


## Geland: knippen naar binnen in de klap (DropCam), schok, en even later de besturing terug.
func _on_mol_landed() -> void:
	var mol: Mol = game.mol
	if not mol.contains_point(global_position):
		return
	camera_fx.add_trauma(0.6)
	camera_fx.kick(-6.0, randf_range(-2.0, 2.0))
	if _drop_cine:
		# Het laatste buitenbeeld keek vooruit over het dak: het eerste binnenbeeld ook. (Nog vast in
		# de Mol tot de volgende tick: ook de vaste draaiing, anders zet _follow_attached hem terug.)
		rotation.y = mol.yaw
		if _attached != null:
			_attached[1] = 0.0
		head.rotation.x = deg_to_rad(-4.0)
		drop_cam.impact()
		if _handover <= 0.0:
			_handover = Tuning.get_f("ship", "drop_handover_s", 0.7)


## Geraakt door een vallende rots (Unrest): even geen controle. `knock`: omver (langer, harder).
func stun(seconds: float, knock: bool) -> void:
	_stun = maxf(_stun, seconds)
	camera_fx.add_trauma(0.6 if knock else 0.35)
	camera_fx.kick(-14.0 if knock else -5.0, randf_range(-6.0, 6.0))
	if impact_fx:
		impact_fx.punch(0.85 if knock else 0.35, IMPACT_TINTS["rock"], "rock")
	if knock and carry and carry.item:
		carry.drop(false)


## Nieuwe wereld (nieuwe dienst): het gereedschap graaft in het nieuwe terrein.
func on_new_world() -> void:
	if pickaxe:
		pickaxe.terrain = game.terrain
		drill.terrain = game.terrain


func _on_pilot_changed(peer: int) -> void:
	if peer == peer_id and not seated:
		_sit()
	elif peer != peer_id and seated:
		_unseat()


func _sit() -> void:
	seated = true
	_riding = false # meerijden opnieuw beginnen na het uitstappen (anders een oude Mol-positie)
	flying = false
	_shape.disabled = true
	# Dezelfde kijkrichting houden (binnen wat de stoel toelaat) en de camera naar de stoel laten
	# glijden: geen harde knip (gevoel-20).
	var cam_was := camera.global_position if camera else global_position
	_look_yaw = clampf(angle_difference(game.mol.yaw, rotation.y), -1.5, 1.5)
	head.rotation.x = clampf(head.rotation.x, -0.9, 0.7)
	velocity = Vector3.ZERO
	active_tool.set_active(false)
	_seat_to_mol()
	ViewGlide.start(self, camera, cam_was, 0.32, 0.3) # met een boogje over de rugleuning


func _unseat() -> void:
	seated = false
	_riding = false # zie _ride_mol: de Mol-positie van vóór het zitten is ongeldig
	var cam_was := camera.global_position if camera else global_position
	var was_chase := chase.current
	if chase.current:
		camera.make_current()
	_shape.disabled = false
	var mol: Mol = game.mol
	# Opstaan met dezelfde kijkrichting, en de camera glijdt uit de stoel (gevoel-14, gevoel-20). Het
	# lijf zelf springt (geen interpolatie ertussen); het oog glijdt (ViewGlide).
	global_transform = Transform3D(Basis(Vector3.UP, mol.yaw + _look_yaw), mol.to_world_mol(Vector3(0.0, -1.45, -0.65)))
	reset_physics_interpolation()
	head.rotation.x = clampf(head.rotation.x, -1.2, 1.2)
	if not was_chase:
		ViewGlide.start(self, camera, cam_was, 0.32, 0.3)
	if (carry == null or carry.item == null) and not _holstered and _tools_allowed():
		active_tool.set_active(true)


## Gereedschap mag enkel met een gave robot (niet strompelend, neer of als drone).
func _tools_allowed() -> bool:
	return life == Rescue.Life.OK


## Knop, hendel of rail onder het vizier (niet door een muur heen), of null.
## In de stoel telt de stoel zelf niet (E is daar uitstappen).
## Het schip en de Mol (laag LIFT) zitten niet in de straal (dan raakte hij de meubels waar de
## knoppen op staan); daarom een tweede straal: staat er een wand van het schip of de Mol
## duidelijk vóór de knop, dan telt hij niet (geen prompt door een deurstijl of een toonbank).
const SIGHT_MARGIN := 0.12

func aimed_interactable() -> Interactable:
	var from := camera.global_position
	var hit: Dictionary = game.terrain.raycast(from, from - camera.global_basis.z * 3.0,
			Layers.TERRAIN | Layers.INTERACT)
	var it := hit.collider as Interactable if not hit.is_empty() else null
	if it and seated and it.get_meta("mol_cmd", -1) == Mol.Cmd.SEAT:
		return null
	if it:
		var at: Vector3 = hit.position
		var wall: Dictionary = game.terrain.raycast(from, at, Layers.LIFT)
		if not wall.is_empty() and from.distance_to(wall.position) < from.distance_to(at) - SIGHT_MARGIN:
			return null
	return it


## Waar je iets vasthoudt: voor je, op ooghoogte, niet door een muur.
func hold_point(item_radius: float) -> Vector3:
	var fwd := -head.global_basis.z
	var from := head.global_position
	# Tussen je handen, vlak voor je: kleine dingen dichtbij, grote verder (gevoel-06).
	var dist := Tuning.get_f("carry", "hold_near", 0.62) + item_radius * Tuning.get_f("carry", "hold_per_radius", 1.1)
	var hit: Dictionary = game.terrain.raycast(from, from + fwd * (dist + item_radius))
	if not hit.is_empty():
		dist = maxf(0.4, from.distance_to(hit.position) - item_radius)
	return from + fwd * dist + Vector3(0, -Tuning.get_f("carry", "hold_drop", 0.24), 0)


func select_tool(index: int) -> void:
	if carry and (carry.item or carry.body_peer >= 0):
		return
	index = wrapi(index, 0, tools.size())
	if active_tool == tools[index]:
		return
	active_tool = tools[index]
	for t in tools:
		t.set_active(t == active_tool and not _holstered and _tools_allowed())
	_send_action(Action.TOOL_PICKAXE if active_tool == pickaxe else Action.TOOL_DRILL)
	tool_changed.emit(active_tool)


func _setup_remote() -> void:
	rig = RobotRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(color)
	# Breekt er iets in zijn handen, dan zie je hem grimassen.
	game.finds.condition_changed.connect(func(it: FindItem, hard: bool) -> void:
		if hard and (it.carriers.has(peer_id) or it.last_carriers.has(peer_id)):
			rig.grimace())


## Muisgevoeligheid: spelgevoel (Tuning) × eigen voorkeur (Settings).
func _sensitivity() -> float:
	return Tuning.get_f("player", "mouse_sensitivity", 0.0025) * Settings.get_f("controls/sensitivity")


## Muisbeweging met de eigen voorkeur (verticaal omgekeerd of niet).
func _mouse(relative: Vector2) -> Vector2:
	return Vector2(relative.x, -relative.y if Settings.get_b("controls/invert_y") else relative.y)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("skip_cinematic") and cinematic and game.mol.drop_skippable():
		game.mol.vote_skip()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and captured and drop_cam.current:
		drop_cam.look(_mouse(event.relative), _sensitivity())
	elif event is InputEventMouseMotion and captured and seated and chase.current:
		chase.look(_mouse(event.relative), _sensitivity())
	elif event.is_action_pressed("mol_view") and seated:
		if chase.current:
			camera.make_current()
		else:
			chase.activate()
	elif event is InputEventMouseMotion and captured and seated:
		# In de stoel: rondkijken binnen de cabine.
		var sens_s := _sensitivity()
		var rel_s := _mouse(event.relative)
		_look_yaw = clampf(_look_yaw - rel_s.x * sens_s, -1.5, 1.5)
		head.rotation.x = clampf(head.rotation.x - rel_s.y * sens_s, -0.9, 0.7)
	elif event is InputEventMouseMotion and captured:
		var sens := _sensitivity()
		var rel := _mouse(event.relative)
		rotate_y(-rel.x * sens)
		if _attached != null: # vast in de Mol (ophalen): rondkijken mag wel (gevoel-05)
			_attached[1] = float(_attached[1]) - rel.x * sens
		head.rotation.x = clampf(head.rotation.x - rel.y * sens, -1.55, 1.55)
	elif event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fly") and life == Rescue.Life.OK:
		flying = not flying
	elif life != Rescue.Life.OK:
		# Neer, strompelend of als drone: geen knoppen, geen gereedschap. De drone kan piepen (E), wie
		# strompelt kan nog een baken gooien (de worm op afstand houden op de weg naar de Mol).
		if life == Rescue.Life.BROKEN and event.is_action_pressed("interact"):
			_send_action(Action.SWING) # bij de anderen: de drone piept en knippert
			camera_fx.kick(-1.0, 0.0)
			game.fx.play("clink", global_position, -14.0, 0.0, 2.2) # plaatshouder (geluid: M6)
		elif life == Rescue.Life.LIMPING and event.is_action_pressed("beacon") and captured and game.beacons:
			game.beacons.request_throw(self)
		return
	elif event.is_action_pressed("horn") and captured and (seated or game.mol.contains_point(global_position)):
		game.mol.press(Mol.Cmd.HORN)
	elif event.is_action_pressed("sonar_ping") and captured and (seated or game.mol.contains_point(global_position)):
		game.mol.press(Mol.Cmd.PING)
	elif event.is_action_pressed("beacon") and captured and not seated and game.beacons:
		game.beacons.request_throw(self)
	elif seated:
		return # geen gereedschap in de stoel
	elif event.is_action_pressed("tool_1"):
		select_tool(0)
	elif event.is_action_pressed("tool_2"):
		select_tool(1)
	elif event.is_action_pressed("tool_next") and captured:
		select_tool(tools.find(active_tool) + 1)
	elif event.is_action_pressed("tool_prev") and captured:
		select_tool(tools.find(active_tool) - 1)


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	if seated:
		_drive_mol(delta)
		return
	if ragdoll != null:
		# Omver of neer: de host (of de fysica hier) beweegt de pop; wij staan op de plek van de romp.
		if is_instance_valid(ragdoll):
			global_position = ragdoll.torso.global_position
		velocity = Vector3.ZERO
		_air_top = global_position.y
		var awake := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
		if awake and life == Rescue.Life.DOWNED and Input.is_action_just_pressed("jump"):
			game.rescue.request_flail()
		return
	if life == Rescue.Life.BROKEN:
		_drone_fly(delta)
		return
	_ride_mol()
	_rescue_if_fallen()
	# Door de open baai van de hub gevallen: je valt uit het schip boven de planeet. (Niet wie vast in
	# de Mol zit: die valt bij de drop eerst met de Mol door de luiken, de Mol neemt hem mee naar buiten.)
	if _attached == null and game.ship and game.exterior and game.ship.below_floor(global_position):
		global_position = game.from_hub(global_position)
		reset_physics_interpolation()
		_riding = false
	# Drop en ophalen: de Mol beweegt snel verticaal, en meerijden met zijn verplaatsing per tick
	# liep telkens een tick achter (de speler zakte steeds verder door de vloer). Dan zit je vast op
	# je plek in de Mol: geen zwaartekracht, geen eigen beweging.
	var mol: Mol = game.mol
	# (Terwijl de grijper zakt, staat de Mol stil: dan loop je vrij rond.)
	if mol.mode in [Mol.Mode.DROPPING, Mol.Mode.LIFTING] and (_attached != null or _riding) or _hold_ticks > 0:
		if _attached == null:
			_attached = [mol.to_local_mol(global_position), rotation.y - mol.yaw]
		_follow_attached(mol)
		_hold_ticks -= 1
		velocity = Vector3.ZERO
		return
	if _attached != null:
		reset_physics_interpolation() # los van de Mol: niet tekenen vanaf de vaste plek van vorige tick
	_attached = null
	var can_move := not (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless" or drop_cam.current or cinematic)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if can_move else Vector2.ZERO
	if _stun > 0.0:
		_stun -= delta
		input = Vector2.ZERO
		can_move = false
	if flying:
		var fly_speed := Tuning.get_f("player", "fly_speed", 12.0)
		var v := head.global_basis * Vector3(input.x, 0.0, input.y) * fly_speed
		if Input.is_action_pressed("jump"):
			v.y += fly_speed
		if Input.is_action_pressed("crouch"):
			v.y -= fly_speed
		velocity = v
		move_and_slide()
		return
	var on_floor := is_on_floor()
	_set_crouch(can_move and Input.is_action_pressed("crouch"))
	# Sprint: enkel vooruit, niet gehurkt, niet met de boor aan of iets zwaars in je handen. Geen
	# uithouding (zoals DRG): het gereedschap zakt weg terwijl je sprint, dat is de prijs.
	var heavy: bool = carry != null and carry.item != null and carry.item.mass > Tuning.get_f("carry", "sprint_max_mass", 6.0)
	var limping := life == Rescue.Life.LIMPING
	var want_sprint: bool = can_move and InputMap.has_action("sprint") and Input.is_action_pressed("sprint") and input.y < -0.3 \
			and not crouching and not heavy and active_tool.move_multiplier() > 0.99 and not limping
	sprinting = want_sprint and (on_floor or sprinting)
	var speed := Tuning.get_f("player", "move_speed", 4.5)
	if crouching:
		speed = Tuning.get_f("player", "crouch_speed", 2.2)
	elif sprinting:
		speed = Tuning.get_f("player", "sprint_speed", 6.8)
	speed *= active_tool.move_multiplier() * (carry.move_multiplier() if carry else 1.0) * (game.unrest.walk_factor() if game.unrest else 1.0)
	if limping:
		# Strompelen: traag, en een hapering in de pas.
		speed *= Tuning.get_f("rescue", "limp_speed", 0.45) * (0.75 + 0.25 * absf(sin(Time.get_ticks_msec() / 1000.0 * 3.1)))
	var dir := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
	var target := Vector3(dir.x, 0.0, dir.z) * speed
	# Gehurkt vast onder een overhang (gevoel2-13): zachtjes naar een plek waar je recht kan staan.
	if crouch_blocked and input.length() < 0.1 and on_floor:
		_unstick_t -= delta
		if _unstick_t <= 0.0:
			_unstick_t = 0.25
			_unstick = _find_unstick()
		if _unstick != Vector3.ZERO:
			target = _unstick.normalized() * Tuning.get_f("player", "unstick_speed", 1.2)
	else:
		_unstick = Vector3.ZERO
		_unstick_t = 0.0
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var accel: float
	if not on_floor:
		accel = Tuning.get_f("player", "air_accel", 9.0)
	elif target.length_squared() > 0.01:
		accel = Tuning.get_f("player", "ground_accel", 40.0)
	else:
		accel = Tuning.get_f("player", "ground_decel", 48.0)
	hv = hv.move_toward(target, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	# Springen: even na het afstappen kan het nog (coyote-tijd), en te vroeg indrukken telt nog even.
	_coyote = Tuning.get_f("player", "coyote_s", 0.1) if on_floor else _coyote - delta
	if can_move and Input.is_action_just_pressed("jump") and not cinematic:
		_jump_buffer = Tuning.get_f("player", "jump_buffer_s", 0.12)
	else:
		_jump_buffer -= delta
	if not on_floor:
		velocity += get_gravity() * delta
		# Wie uit De Ekster springt, valt niet sneller dan dit (geen tunneling door de grond).
		velocity.y = maxf(velocity.y, -Tuning.get_f("player", "max_fall_speed", 40.0))
	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouching and not limping:
		velocity.y = Tuning.get_f("player", "jump_velocity", 4.5)
		_jump_buffer = 0.0
		_coyote = 0.0
	_step_up(delta)
	var fall := -velocity.y
	# Neergezet van buitenaf (een scenario, de host, het schip): de val begint hier opnieuw.
	if global_position.distance_to(_phys_last) > velocity.length() * delta + 1.0:
		_air_top = global_position.y
	_air_top = global_position.y if on_floor else maxf(_air_top, global_position.y)
	move_and_slide()
	_phys_last = global_position
	if not on_floor and is_on_floor():
		_on_landed(fall)
		_air_top = global_position.y


## Hurken: lagere botsvorm en een lager oog. Opstaan kan enkel als er boven je ruimte is.
func _set_crouch(want: bool) -> void:
	if want == crouching:
		crouch_blocked = false
		return
	var low := Tuning.get_f("player", "crouch_height", 0.95)
	if not want:
		# Past de hele capsule weer? (anders blijf je gehurkt, bv. onder een overhang in je tunnel). Dan
		# zegt de HUD waarom, en schuif je vanzelf naar een plek waar het wel kan (_find_unstick).
		if test_move(global_transform, Vector3(0.0, STAND_HEIGHT - low, 0.0)):
			crouch_blocked = true
			return
	crouch_blocked = false
	crouching = want
	var h := low if crouching else STAND_HEIGHT
	_capsule.height = h
	_shape.position.y = h * 0.5


## Gehurkt vast: de dichtstbijzijnde plek (tot 0,5 m opzij, zonder muur ertussen) waar de hele capsule
## weer past, als verschuiving; ZERO als er geen is.
func _find_unstick() -> Vector3:
	var up := Vector3(0.0, STAND_HEIGHT - Tuning.get_f("player", "crouch_height", 0.95), 0.0)
	for r: float in [0.2, 0.35, 0.5]:
		for i in 8:
			var a := TAU * i / 8.0
			var off := Vector3(cos(a), 0.0, sin(a)) * r
			if test_move(global_transform, off):
				continue
			if not test_move(global_transform.translated(off), up):
				return off
	return Vector3.ZERO


## Geland met `speed` m/s naar beneden: het oog zakt even door (meer bij een hogere val), een
## kleine schok, en bij een harde landing stof aan je voeten.
func _on_landed(speed: float) -> void:
	# Valschade (GDD §6, playtest 2026-10-06): wie van een richel of in een put valt. Niet wie uit De
	# Ekster springt (dan begon de val hoog boven het oppervlak) en niet in het schip.
	# De snelheid moet passen bij de hoogte van de val (anders telt de opgebouwde snelheid van een robot
	# die een test of de host door de rots verzette).
	var dropped := sqrt(2.0 * 9.8 * maxf(0.0, _air_top - global_position.y)) + 1.0
	if game.rescue and game.terrain and minf(speed, dropped) >= Tuning.get_f("rescue", "fall_safe", 9.0):
		var top_ok: bool = _air_top < game.terrain.surface_height_at(global_position.x, global_position.z) + 6.0
		if top_ok and not (game.ship and game.ship.contains(global_position)):
			game.rescue.report_fall(minf(speed, dropped))
	if speed < Tuning.get_f("player", "land_min_speed", 2.5):
		return
	_land_impulse = speed
	var hard := speed > Tuning.get_f("player", "land_dust_speed", 6.0)
	camera_fx.kick(-clampf(speed * 0.35, 0.0, 6.0), randf_range(-0.6, 0.6))
	if hard:
		camera_fx.add_trauma(clampf((speed - 6.0) * 0.04, 0.0, 0.35))
		var at := global_position + Vector3(0, 0.05, 0)
		var col := Strata.DEBRIS_COLORS[game.terrain.layer_at(at - Vector3(0, 0.5, 0))] if game.terrain else Color(0.55, 0.4, 0.3)
		if game.ship == null or not game.ship.contains(at):
			game.fx.land_dust(at, col, clampf(speed / 12.0, 0.4, 1.2))
		game.fx.play("crumble", at, -14.0 + minf(speed, 12.0))


## Lage treden in De Ekster (de ringtreden van de verhoging, drempels): een CharacterBody loopt
## hellingen op, maar geen treden. Botst de stap van deze tick tegen een lage rand van het schip,
## dan eerst op de rand gaan staan. Enkel tegen de hub: op de planeet en in de Mol verandert niets.
func _step_up(delta: float) -> void:
	var ship: Ekster = game.ship
	if ship == null or ship.body == null or not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length_squared() < 1e-8:
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit) or hit.get_collider() != ship.body:
		return
	if hit.get_normal().angle_to(Vector3.UP) <= floor_max_angle:
		return # een helling (trap): daar loopt move_and_slide zelf op
	var up := Vector3(0.0, Tuning.get_f("player", "step_height", 0.25), 0.0)
	if up.y <= 0.0 or test_move(global_transform, up):
		return # uit, of geen plaats boven het hoofd
	var raised := global_transform.translated(up)
	if test_move(raised, motion):
		return # ook hoger nog een muur: geen trede
	var down := KinematicCollision3D.new()
	if not test_move(raised.translated(motion), -up, down) or down.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return # geen vloer op de rand
	global_position.y += up.y + down.get_travel().y


## Wie in de Mol staat, beweegt mee met de Mol: positie en kijkrichting volgen exact zijn
## verplaatsing en draaiing sinds de vorige tick. Je eigen stappen komen daarbovenop.
## (De vloer alleen neemt je niet mee: dan glijd je weg en draait je blik rond als hij bijdraait.)
func _ride_mol() -> void:
	var mol: Mol = game.mol
	_ride_yaw = 0.0
	if mol == null or mol.body == null or flying or not mol.contains_point(global_position):
		_riding = false
		return
	var now := mol.body.global_transform
	if _riding and now.origin.distance_to(_mol_ref.origin) < 3.0: # meer in één tick kan niet: oude waarde
		var d := now * _mol_ref.affine_inverse()
		global_position = d * global_position
		var fwd := d.basis * -global_basis.z
		if Vector2(fwd.x, fwd.z).length() > 0.01:
			var was := rotation.y
			rotation.y = atan2(-fwd.x, -fwd.z)
			_ride_yaw = wrapf(rotation.y - was, -PI, PI)
		# Verticale snelheid relatief tot de Mol: niet "vallen" als hij daalt, niet gelanceerd worden als hij stijgt.
		if is_on_floor():
			velocity.y = minf(velocity.y, 0.0)
	_mol_ref = now
	_riding = true


func _follow_attached(mol: Mol) -> void:
	global_position = mol.to_world_mol(_attached[0])
	rotation.y = mol.yaw + float(_attached[1])
	_mol_ref = mol.body.global_transform


## Vangnet: wie onder de wereld valt (door een fout of door het terrein), komt terug in de Mol.
func _rescue_if_fallen() -> void:
	if global_position.y > -10.0:
		return
	var mol: Mol = game.mol
	print("[player] onder de wereld gevallen: terug in de Mol")
	_teleport(mol.to_world_mol(Vector3(0.0, -1.2, 0.8)) if mol and mol.body else game.terrain.spawn_point())
	rescued.emit()


## Piloot: zit vast in de stoel en stuurt de Mol (W/S gas, A/D draaien, spatie/Ctrl neus).
func _drive_mol(delta: float) -> void:
	var mol: Mol = game.mol
	# Headless (tests): geen muis om te vangen, toetsen tellen toch.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	var throttle := Input.get_axis("move_back", "move_forward") if captured else 0.0
	var steer := Input.get_axis("move_left", "move_right") if captured else 0.0
	var nose := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
	mol.send_input(throttle, steer, nose if captured else 0.0, delta)
	velocity = Vector3.ZERO
	_seat_to_mol()


func _seat_to_mol() -> void:
	var mol: Mol = game.mol
	global_transform = mol.body.global_transform * Transform3D(Basis(Vector3.UP, _look_yaw), SEAT_FEET)


func _process(delta: float) -> void:
	if is_local:
		if seated:
			_seat_to_mol()
		var mol: Mol = game.mol
		if _attached != null:
			_follow_attached(mol)
		_update_rig(delta)
		var in_mol := mol != null and (seated or mol.contains_point(global_position))
		_update_drop_cam(mol, in_mol)
		_update_cinematic(mol, in_mol, delta)
		_update_holster()
		if in_mol and mol.drilling and camera_fx.trauma() < 0.22:
			camera_fx.add_trauma(delta * 0.6) # de hele Mol trilt als hij boort
		_send_timer += delta
		if _send_timer >= SEND_INTERVAL:
			_send_timer = 0.0
			# In de Mol: positie en draaiing relatief tot de Mol, zodat je op elk scherm netjes
			# binnen staat, ook als de Mol rijdt (iedereen ziet de Mol iets anders vertraagd).
			var pos := global_position
			var yaw := rotation.y
			if in_mol:
				pos = mol.to_local_mol(global_position)
				yaw = rotation.y - mol.yaw
			var me := multiplayer.get_unique_id()
			for peer: int in game.ready_peers:
				if peer != me:
					_rpc_state.rpc_id(peer, Time.get_ticks_msec(), pos, yaw, head.rotation.x, in_mol)
	else:
		_interpolate()


## Het oog (CamRig) op de plek waar het lijf nu getekend wordt (geïnterpoleerd tussen twee ticks),
## met de kijkrichting van nu, plus de loopbeweging, de landingsdip en het hurken.
## Zit je in de stoel of vast in de Mol, dan volgt het oog de getekende Mol (die is ook
## geïnterpoleerd), anders schuift de cabine onder je door.
func _update_rig(delta: float) -> void:
	var mol: Mol = game.mol
	_check_jump()
	_update_fov(delta)
	if ragdoll != null and is_instance_valid(ragdoll):
		_orbit_ragdoll(delta)
		return
	var frac := Engine.get_physics_interpolation_fraction()
	var anchor: Transform3D
	if seated and mol and mol.body:
		anchor = mol.body.get_global_transform_interpolated() * Transform3D(Basis(Vector3.UP, _look_yaw), SEAT_FEET)
	elif _attached != null and mol and mol.body:
		anchor = Transform3D(Basis(Vector3.UP, rotation.y), mol.body.get_global_transform_interpolated() * (_attached[0] as Vector3))
	else:
		anchor = Transform3D(Basis(Vector3.UP, rotation.y - _ride_yaw * (1.0 - frac)), get_global_transform_interpolated().origin)
	# Hurken: het oog zakt vloeiend (de botsvorm wisselt meteen).
	var eye_target := Tuning.get_f("player", "crouch_eye", 0.78) if crouching else EYE_STAND
	head.position.y = move_toward(head.position.y, eye_target, delta * Tuning.get_f("player", "crouch_eye_speed", 3.5))
	# Landingsdip: een veer die door de klap omlaag geduwd wordt.
	if _land_impulse > 0.0:
		var k := clampf((_land_impulse - 2.0) / 10.0, 0.0, 1.0)
		_dip_vel += lerpf(0.4, Tuning.get_f("player", "land_dip_max", 2.2), k) * Settings.get_f("interface/camera_shake")
		_land_impulse = 0.0
	var left := minf(delta, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_dip_vel += (-_dip * Tuning.get_f("player", "land_dip_stiffness", 160.0) - _dip_vel * Tuning.get_f("player", "land_dip_damping", 15.0)) * h
		_dip += _dip_vel * h
		left -= h
	# Loopbeweging en zijwaartse kanteling (uit te zetten in de instellingen). Sprinten (gevoel2-16):
	# hogere, langere passen met een zwaai van links naar rechts, en kantelen in een bocht.
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hv.length()
	var grounded := is_on_floor() and not seated and _attached == null and not flying
	var bob_on := _head_bob_on()
	var walk := Tuning.get_f("player", "move_speed", 4.5)
	var run := clampf((speed - walk) / maxf(Tuning.get_f("player", "sprint_speed", 6.8) - walk, 0.1), 0.0, 1.0) if sprinting else 0.0
	var want_bob := clampf(speed / walk, 0.0, 1.6) if grounded and bob_on else 0.0
	_bob_amount = move_toward(_bob_amount, want_bob, delta * 4.0)
	if grounded:
		var stride := lerpf(Tuning.get_f("player", "step_length", 1.6), Tuning.get_f("player", "sprint_step_length", 2.1), run)
		_bob_phase += delta * speed / maxf(stride, 0.1) * PI
	var amp := Tuning.get_f("player", "bob_height", 0.022) * _bob_amount * lerpf(1.0, Tuning.get_f("player", "sprint_bob", 1.7), run)
	var bob := Vector3(cos(_bob_phase) * amp * lerpf(0.55, 0.9, run), -absf(sin(_bob_phase)) * amp, 0.0)
	var side := (anchor.basis.inverse() * hv).x
	var want_tilt := -side / maxf(walk, 0.1) * deg_to_rad(Tuning.get_f("player", "strafe_tilt_deg", 1.2)) if bob_on and grounded else 0.0
	_tilt = lerpf(_tilt, want_tilt, minf(1.0, delta * 8.0))
	# Kantelen in een bocht (met de muis draaien terwijl je loopt; sprintend het sterkst) en de zwaai van de pas.
	var yaw_rate := wrapf(rotation.y - _last_yaw, -PI, PI) / maxf(delta, 0.001)
	_last_yaw = rotation.y
	var lean := 0.0
	if bob_on and grounded and speed > 0.5:
		lean = clampf(-yaw_rate * Tuning.get_f("player", "turn_tilt", 0.012), -1.0, 1.0) \
				* deg_to_rad(Tuning.get_f("player", "turn_tilt_max_deg", 2.5)) * lerpf(0.4, 1.0, run)
	_turn_roll = lerpf(_turn_roll, lean, minf(1.0, delta * 6.0))
	var sway := sin(_bob_phase) * deg_to_rad(Tuning.get_f("player", "sprint_sway_deg", 0.7)) * run * _bob_amount
	camera_fx.roll = _tilt + _turn_roll + sway
	var eye := head.position + bob + Vector3(0.0, -_dip, 0.0)
	cam_rig.global_transform = Transform3D(anchor.basis * Basis(Vector3.RIGHT, head.rotation.x), anchor * eye)


func _head_bob_on() -> bool:
	return Settings.get_b("interface/head_bob") if Settings.DEFAULTS.has("interface/head_bob") else true


## FOV: de eigen instelling, plus sprinten (een paar graden breder, gevoel2-16; uit met "head bob") en
## de stoot van een klap (ImpactFx).
func _update_fov(delta: float) -> void:
	var want := 0.0
	if sprinting and _head_bob_on() and ragdoll == null \
			and Vector2(velocity.x, velocity.z).length() > Tuning.get_f("player", "move_speed", 4.5) + 0.3:
		want = Tuning.get_f("player", "sprint_fov_deg", 7.0)
	_sprint_fov = move_toward(_sprint_fov, want, delta * Tuning.get_f("player", "sprint_fov_speed", 28.0))
	camera.fov = clampf(_fov_base + _sprint_fov + (impact_fx.fov_kick if impact_fx else 0.0), 30.0, 130.0)


## Het klapmoment (gevoel2-02): het beeld blijft impact_hold_s staan waar het was (hit-stop, met flits
## en schok), dan glijdt het in impact_blend_s naar de volgcamera. Bij elke nieuwe ragdoll.
func _impact_begin() -> void:
	_view_from = cam_rig.global_transform
	_impact_hold = Tuning.get_f("camera", "impact_hold_s", 0.14)
	_view_blend = 0.0
	_orbit_pos = Vector3.INF
	_cabin_pick = -1


## Omver of neer: de volgcamera hangt achter en boven de pop en kijkt ernaar (rondkijken met de muis;
## R.E.P.O.: je ziet je eigen robot vallen). Ze komt nooit in je eigen robot, een ploegmaat of de Mol:
## een bol die de rots, de Mol, spelers en andere poppen voelt, minstens follow_min ver, en anders
## eerst hoger en dan opzij. Gedragen draait ze mee met je drager (je ziet waar je heen gaat). In de
## Mol een vast camerapunt in de cabine. Eerst het klapmoment (_impact_begin).
func _orbit_ragdoll(delta: float) -> void:
	var target := _follow_cam(delta)
	camera_fx.roll = 0.0
	if _impact_hold > 0.0:
		_impact_hold -= delta
		cam_rig.global_transform = _view_from
	elif _view_blend < 1.0:
		_view_blend = minf(1.0, _view_blend + delta / maxf(0.05, Tuning.get_f("camera", "impact_blend_s", 0.32)))
		cam_rig.global_transform = _view_from.interpolate_with(target, smoothstep(0.0, 1.0, _view_blend))
	else:
		cam_rig.global_transform = target
	# Zit de camera (nog) in of vlak bij je eigen robot (het klapmoment, een nauwe gang): niet tonen.
	var torso := ragdoll.torso.get_global_transform_interpolated().origin + Vector3.UP * 0.35
	ragdoll.visible = cam_rig.global_position.distance_to(torso) > Tuning.get_f("camera", "follow_hide_self", 0.7)


func _follow_cam(delta: float) -> Transform3D:
	var focus := ragdoll.torso.get_global_transform_interpolated().origin + Vector3.UP * 0.35
	var mol: Mol = game.mol
	var carriers: PackedInt32Array = game.rescue.carriers_of(peer_id) if game.rescue else PackedInt32Array()
	var carrier: Player = game.player_node(carriers[0]) if not carriers.is_empty() else null
	if carrier:
		# Gedragen: de camera draait met de drager mee (de muis kan er nog bij).
		rotation.y = lerp_angle(rotation.y, carrier.rotation.y, 1.0 - exp(-delta * Tuning.get_f("camera", "follow_carried_turn", 2.5)))
	if mol and mol.body and mol.contains_point(focus):
		return _cabin_cam(mol, focus, delta)
	_cabin_pick = -1
	var want := Tuning.get_f("camera", "follow_dist", 3.2)
	var pitch := clampf(head.rotation.x - 0.35, -1.25, 0.6)
	var yaw0 := rotation.y
	if carrier:
		# Schuin van achter en opzij, van boven: je ziet jezelf in de armen van je drager, en de weg.
		pitch = minf(pitch, -0.6)
		yaw0 += Tuning.get_f("camera", "follow_carried_side", 0.8)
	var best_dir := Vector3.BACK
	var best_d := -1.0
	# Achter de kijkrichting, dan hoger, dan opzij: de eerste die de hele afstand vrij heeft.
	for c: Vector2 in [Vector2(0.0, 0.0), Vector2(0.0, -0.35), Vector2(0.0, -0.7), Vector2(0.7, -0.35), Vector2(-0.7, -0.35),
			Vector2(1.4, -0.5), Vector2(-1.4, -0.5), Vector2(0.0, -1.15)]:
		var b := Basis(Vector3.UP, yaw0 + c.x) * Basis(Vector3.RIGHT, clampf(pitch + c.y, -1.35, 0.6))
		var dir := b * Vector3.BACK
		var d := _clear_dist(focus, dir, want)
		if d >= want - 0.05:
			best_dir = dir
			best_d = d
			break
		if d > best_d + 0.1:
			best_dir = dir
			best_d = d
	var pos := focus + best_dir * maxf(best_d, 0.3)
	# Afvlakken: naar buiten traag, naar binnen (een wand) meteen.
	if _orbit_pos == Vector3.INF or _orbit_pos.distance_to(pos) > 4.0:
		_orbit_pos = pos
	else:
		var smoothed := _orbit_pos.lerp(pos, 1.0 - exp(-delta * 8.0))
		var sd := focus.distance_to(smoothed)
		if sd > 0.05 and _clear_dist(focus, (smoothed - focus) / sd, sd) < sd - 0.05:
			smoothed = pos
		_orbit_pos = smoothed
	var look := focus
	if carrier:
		var fwd := -carrier.global_basis.z
		fwd.y = 0.0
		look = focus + fwd.normalized() * 1.2
	return Transform3D(_look_basis(look - _orbit_pos), _orbit_pos)


## In de Mol: het vaste camerapunt (CABIN_CAMS) dat de pop het best ziet, minstens follow_min ver en
## zonder iets ertussen. Je houdt hetzelfde punt zolang het goed blijft (geen gespring).
func _cabin_cam(mol: Mol, focus: Vector3, delta: float) -> Transform3D:
	var xf := mol.body.get_global_transform_interpolated()
	if _cabin_pick < 0 or not _cabin_ok(xf * CABIN_CAMS[_cabin_pick], focus):
		var best := -1
		var best_d := -1.0
		for i in CABIN_CAMS.size():
			var d := (xf * CABIN_CAMS[i]).distance_to(focus)
			if _cabin_ok(xf * CABIN_CAMS[i], focus) and d > best_d:
				best = i
				best_d = d
		_cabin_pick = best if best >= 0 else CABIN_CAMS.size() - 1
	var pos: Vector3 = xf * CABIN_CAMS[_cabin_pick]
	if _orbit_pos == Vector3.INF or _orbit_pos.distance_to(pos) > 12.0:
		_orbit_pos = pos
	else:
		_orbit_pos = _orbit_pos.lerp(pos, 1.0 - exp(-delta * 5.0))
	return Transform3D(_look_basis(focus - _orbit_pos), _orbit_pos)


func _cabin_ok(at: Vector3, focus: Vector3) -> bool:
	if at.distance_to(focus) < Tuning.get_f("camera", "follow_min", 1.2):
		return false
	var hit: Dictionary = game.terrain.raycast(at, focus, Layers.LIFT | Layers.PLAYERS)
	return hit.is_empty() or (hit.position as Vector3).distance_to(focus) < 0.6


## Hoe ver de camera vanaf `from` langs `dir` kan (hooguit `want`), als bol van follow_radius: rots, de
## Mol, spelers en poppen (behalve de eigen pop) houden haar tegen.
func _clear_dist(from: Vector3, dir: Vector3, want: float) -> float:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.get_f("camera", "follow_radius", 0.22)
	q.shape = sphere
	q.transform = Transform3D(Basis(), from)
	q.motion = dir * want
	q.collision_mask = Layers.TERRAIN | Layers.LIFT | Layers.PLAYERS | Layers.LOOT | Layers.RUBBLE
	var ex: Array[RID] = [get_rid()]
	for rb: RigidBody3D in ragdoll.all_bodies():
		ex.append(rb.get_rid())
	q.exclude = ex
	var res := get_world_3d().direct_space_state.cast_motion(q)
	if res.is_empty() or (float(res[0]) <= 0.0 and float(res[1]) <= 0.0):
		# De bol begint al in iets (de romp ligt tegen een wand): dan een gewone straal.
		var hit: Dictionary = game.terrain.raycast(from, from + dir * want, Layers.TERRAIN | Layers.LIFT)
		return want if hit.is_empty() else maxf(0.0, from.distance_to(hit.position) - 0.25)
	return want * float(res[0])


static func _look_basis(dir: Vector3) -> Basis:
	if dir.length() < 0.01:
		return Basis()
	var up := Vector3.UP if absf(dir.normalized().y) < 0.98 else Vector3.BACK
	return Basis.looking_at(dir, up)


## Grote sprong van het lijf zonder reset (een scenario, een test, de host die je verzet): niet
## tekenen alsof je in één tick door de wereld vloog.
func _check_jump() -> void:
	if global_position.distance_to(_last_pos) > 3.0:
		reset_physics_interpolation()
	_last_pos = global_position


## In de Mol tijdens de drop of het ophalen: het heldenshot (DropCam). Bij de drop vanaf de sprong
## naar buiten (de val door de luiken van de hub zie je van binnen) tot de landing; bij het ophalen
## enkel de eerste seconden (de Mol vertrekt van de grond), daarna terug naar binnen tot in de hub.
## Op de plek van de Mol, niet op zijn toestand: bij een client komt de sprong een tick na de toestand.
func _update_drop_cam(mol: Mol, in_mol: bool) -> void:
	# Pas naar buiten knippen als het lichaam van de Mol er ook staat (anders een beeld zonder Mol).
	var drop_shot := in_mol and mol.mode == Mol.Mode.DROPPING and not mol.in_hub() and (drop_cam.current or drop_cam.mol_synced())
	var want := drop_shot or in_mol and drop_cam.wants_lift_shot()
	if want and not drop_cam.current:
		drop_cam.activate()
	elif not want and drop_cam.current:
		drop_cam.deactivate()
		camera.make_current()
		if not _drop_cine:
			camera_fx.add_trauma(0.3) # knippen in de klap


## Filmpje (drop): brommen en trillen tijdens het aftellen, de val door de luiken, en na de landing
## na drop_handover_s de besturing terug (gereedschap, HUD, beweging).
func _update_cinematic(mol: Mol, in_mol: bool, delta: float) -> void:
	if mol == null:
		return
	if in_mol and mol.mode == Mol.Mode.DROP_COUNTDOWN:
		var k := 1.0 - clampf(mol.countdown / Tuning.get_f("ship", "drop_countdown_s", 8.0), 0.0, 1.0)
		camera_fx.hold_trauma(lerpf(0.12, 0.3, k))
	elif _drop_cine and mol.mode == Mol.Mode.DROPPING and mol.in_hub():
		camera_fx.hold_trauma(0.4) # door de luiken: de cabine rammelt
	if _drop_cine and _handover <= 0.0 and mol.mode != Mol.Mode.DROPPING:
		if mol.mode == Mol.Mode.PARKED:
			_handover = Tuning.get_f("ship", "drop_handover_s", 0.7) # geland (het bericht kan later komen)
		else:
			_end_cinematic() # de drop liep anders af: meteen terug
	elif _handover > 0.0:
		_handover -= delta
		if _handover <= 0.0:
			_end_cinematic()
	cinematic = _drop_cine or drop_cam.current


## In De Ekster valt er niets te graven: het gereedschap zit weg zolang je in het schip bent (ook in
## de Mol in de baai). Buiten het schip komt het terug, maar enkel als het hier weggestoken werd en
## niets anders het weghoudt (de stoel, iets dragen, het filmpje van de drop: dat geeft het zelf terug).
var _holstered := false

func _update_holster() -> void:
	if active_tool == null:
		return
	var in_ship: bool = game.ship != null and game.ship.contains(global_position)
	if in_ship and not _holstered:
		_holstered = true
		active_tool.set_active(false)
	elif not in_ship and _holstered:
		_holstered = false
		if not seated and (carry == null or carry.item == null) and not _drop_cine and not drop_cam.current and _tools_allowed():
			active_tool.set_active(true)


func _end_cinematic() -> void:
	_drop_cine = false
	_handover = 0.0
	if not seated and (carry == null or carry.item == null) and active_tool and not _holstered and _tools_allowed():
		active_tool.set_active(true)
	drop_cam.handover()
	control_returned.emit()


## Toestand van de authority naar alle anderen. Onbetrouwbaar: een gemiste update
## wordt door de volgende vervangen. `in_mol`: positie en draaiing zijn relatief tot de Mol.
@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_state(sent_ms: int, pos: Vector3, yaw: float, pitch: float, in_mol: bool) -> void:
	var now := float(Time.get_ticks_msec())
	# Klokverschil schatten: de kleinste (ontvangst - verzending) is de beste schatting.
	_clock_offset = minf(_clock_offset, now - sent_ms)
	_snapshots.append([float(sent_ms) + _clock_offset, pos, yaw, pitch, in_mol])
	if _snapshots.size() > 30:
		_snapshots.pop_front()
	if _snapshots.size() == 1:
		global_position = _snap_pos(_snapshots[0])
		rotation.y = _snap_yaw(_snapshots[0])


## In de Mol: t.o.v. de Mol zoals hij nu getekend wordt (geïnterpoleerd), anders schuift de robot
## bij een rijdende Mol heen en weer in de cabine.
func _snap_pos(s: Array) -> Vector3:
	return game.mol.body.get_global_transform_interpolated() * (s[1] as Vector3) if s[4] else s[1]


func _snap_yaw(s: Array) -> float:
	return s[2] + game.mol.yaw if s[4] else s[2]


func _interpolate() -> void:
	if rig:
		rig.reach = _carry_reach()
	if ragdoll != null and is_instance_valid(ragdoll):
		global_position = ragdoll.torso.global_position # omver of neer: op de plek van de romp
		return
	if _snapshots.is_empty():
		return
	var render_t := float(Time.get_ticks_msec()) - INTERP_DELAY_MS
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	var prev := global_position
	# Beide punten nu naar de wereld omrekenen (met de Mol zoals hij nu staat), dan mengen.
	global_position = _snap_pos(a).lerp(_snap_pos(b), k)
	rotation.y = lerp_angle(_snap_yaw(a), _snap_yaw(b), k)
	head.rotation.x = lerpf(a[3], b[3], k)
	if rig:
		var dt := get_process_delta_time()
		var v := (global_position - prev) / maxf(dt, 0.0001)
		rig.velocity = rig.velocity.lerp(v, minf(1.0, dt * 12.0))
		rig.on_floor = absf(rig.velocity.y) < 0.8
		rig.look_pitch = head.rotation.x


## Waar de armen van deze (andere) robot naartoe reiken: zijn greep op een zwaar stuk of op een robot
## die hij draagt (golf 3, gevoel2-03), of INF.
func _carry_reach() -> Vector3:
	if game.finds:
		var it: FindItem = game.finds.carried_by(peer_id)
		if it:
			return game.finds.grip_world(it, peer_id)
	if game.rescue:
		return game.rescue.grip_of_carrier(peer_id)
	return Vector3.INF


func _send_action(action: Action) -> void:
	var me := multiplayer.get_unique_id()
	for peer: int in game.ready_peers:
		if peer != me:
			_rpc_action.rpc_id(peer, action)


## Host: deze speler ergens neerzetten (bv. achtergebleven bij de extractie). De eigenaar
## beweegt zijn eigen robot, dus de host vraagt het hem.
func host_teleport(pos: Vector3) -> void:
	if is_local:
		_teleport(pos)
	else:
		_rpc_teleport.rpc_id(peer_id, pos)


@rpc("any_peer", "reliable")
func _rpc_teleport(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1 and is_local:
		_teleport(pos)


func _teleport(pos: Vector3) -> void:
	if carry and (carry.item or carry.body_peer >= 0):
		carry.drop(false)
	flying = false
	velocity = Vector3.ZERO
	global_position = pos
	reset_physics_interpolation()
	_riding = false
	_air_top = pos.y


# --- Neergaan (Rescue) -----------------------------------------------------------------------------

## Omver of neer: de pop ligt er, wij volgen hem (Rescue._rpc_ragdoll, op elk peer).
func on_ragdoll(rd: RobotRagdoll, new_life: int) -> void:
	ragdoll = rd
	life = new_life
	if is_local:
		if carry and (carry.item or carry.body_peer >= 0):
			carry.drop(false)
		_shape.disabled = true
		velocity = Vector3.ZERO
		flying = false
		_attached = null
		if active_tool:
			active_tool.set_active(false)
		_impact_begin()
	else:
		_snapshots.clear()
		if rig:
			rig.visible = false
	_update_drone()


## Weer recht (na omver, na reparatie, of strompelend): op `feet`, met kijkrichting `yaw`. Wie zelf
## opstaat, kijkt verder waar de volgcamera keek, en het beeld glijdt terug in de ogen (gevoel2-02).
func on_stand(feet: Vector3, yaw: float, new_life: int) -> void:
	var was_down := ragdoll != null
	ragdoll = null
	life = new_life
	if is_local:
		var cam_was := camera.global_position if camera else global_position
		var look := -cam_rig.global_basis.z if cam_rig else Vector3.ZERO
		_shape.disabled = false
		collision_mask = MASK
		_teleport(feet)
		rotation.y = yaw
		_impact_hold = 0.0
		_view_blend = 1.0
		if was_down and look.length() > 0.5 and Vector2(look.x, look.z).length() > 0.05:
			rotation.y = atan2(-look.x, -look.z)
			head.rotation.x = clampf(asin(clampf(look.y, -1.0, 1.0)), -0.6, 0.5)
			ViewGlide.start(self, camera, cam_was, Tuning.get_f("camera", "stand_glide_s", 0.35), 0.0)
		if active_tool and not seated and (carry == null or (carry.item == null and carry.body_peer < 0)) and not _holstered:
			active_tool.set_active(_tools_allowed())
	else:
		_snapshots.clear()
		global_position = feet
		rotation.y = yaw
		if rig:
			rig.visible = true
	_update_drone()


## Kapot: een spookdrone op `at` (Rescue._rpc_broken, op elk peer). Hij botst enkel met de rots.
func on_broken(at: Vector3) -> void:
	ragdoll = null
	life = Rescue.Life.BROKEN
	if is_local:
		if carry and (carry.item or carry.body_peer >= 0):
			carry.drop(false)
		var cam_was := camera.global_position if camera else global_position
		_shape.disabled = false
		collision_mask = Layers.TERRAIN | Layers.BOUNDS
		flying = false
		_attached = null
		_teleport(at)
		_impact_hold = 0.0
		_view_blend = 1.0
		ViewGlide.start(self, camera, cam_was, 0.5, 0.0) # van de volgcamera naar de drone, geen knip
		if active_tool:
			active_tool.set_active(false)
	else:
		_snapshots.clear()
		global_position = at
		if rig:
			rig.visible = false
	_update_drone()


## Een andere toestand zonder ragdoll (strompelend → gerepareerd, of terug op nul).
func on_life(new_life: int) -> void:
	life = new_life
	if is_local:
		if life != Rescue.Life.BROKEN:
			collision_mask = MASK
		if active_tool:
			active_tool.set_active(_tools_allowed() and not seated and not _holstered and (carry == null or (carry.item == null and carry.body_peer < 0)))
	elif rig:
		rig.visible = ragdoll == null and life != Rescue.Life.BROKEN
	_update_drone()


## De spookdrone bij de anderen tonen (of weghalen).
func _update_drone() -> void:
	var want := life == Rescue.Life.BROKEN and not is_local
	if want and _drone == null:
		_drone = SpectatorDrone.new()
		_drone.name = "Drone"
		add_child(_drone)
		_drone.setup(color)
	elif not want and _drone != null:
		_drone.queue_free()
		_drone = null


## Spookdrone: vrij vliegen (WASD, Spatie omhoog, Ctrl omlaag), botst enkel met de rots.
func _drone_fly(delta: float) -> void:
	var can_move := not (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless")
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if can_move else Vector2.ZERO
	var speed := Tuning.get_f("rescue", "drone_speed", 6.0)
	var want := head.global_basis * Vector3(input.x, 0.0, input.y) * speed
	if can_move and Input.is_action_pressed("jump"):
		want.y += speed * 0.8
	if can_move and Input.is_action_pressed("crouch"):
		want.y -= speed * 0.8
	velocity = velocity.lerp(want, minf(1.0, delta * 5.0))
	move_and_slide()
	_rescue_if_fallen()


## Zichtbare acties (zwaai, gereedschap, boor) naar de anderen. Het terrein zelf komt via
## TerrainSync; dit is enkel wat je van de robot ziet en hoort.
## Wissel en boor aan/uit gaan betrouwbaar: die toestand moet kloppen.
@rpc("authority", "reliable", "call_remote")
func _rpc_action(action: int) -> void:
	if rig == null:
		return
	match action:
		Action.SWING:
			if life == Rescue.Life.BROKEN and _drone:
				_drone.beep()
			else:
				rig.swing()
		Action.TOOL_PICKAXE:
			rig.set_tool(RobotRig.HeldTool.PICKAXE)
		Action.TOOL_DRILL:
			rig.set_tool(RobotRig.HeldTool.DRILL)
		Action.DRILL_ON:
			rig.set_drilling(true)
		Action.DRILL_OFF:
			rig.set_drilling(false)
		Action.CARRY_ON:
			rig.set_carrying(true)
		Action.CARRY_OFF:
			rig.set_carrying(false)
