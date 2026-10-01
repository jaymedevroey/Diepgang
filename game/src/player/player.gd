class_name Player
extends CharacterBody3D
## Een robot. Op de peer die hem bestuurt (authority) is hij lokaal: invoer, camera,
## houweel, en hij stuurt zijn toestand ±20× per seconde. Op de andere peers is hij een
## kopie die geïnterpoleerd wordt (GDD §9: de client bepaalt de eigen beweging).
## Opbouw lokaal: Player (yaw) > Head (pitch) > Camera3D (CameraFx) > Pickaxe, Drill
## Gereedschap: 1 = houweel, 2 = boor (of het muiswieltje).
## Naam van de node = peer-id, onder Game/Players, zodat RPC-paden overal gelijk zijn.

const LAYER_PLAYERS := 1 << 2
const MASK := Layers.TERRAIN | Layers.LOOT | Layers.LIFT
const SEND_INTERVAL := 0.05
const INTERP_DELAY_MS := 100.0

enum Action { SWING, TOOL_PICKAXE, TOOL_DRILL, DRILL_ON, DRILL_OFF, CARRY_ON, CARRY_OFF }

signal tool_changed(tool: Node3D)

var peer_id := 1
var color := Color(0.95, 0.55, 0.12)
var game: Node # Game
var is_local := false

var head: Node3D
var camera: Camera3D
var camera_fx: CameraFx
## Buitenzicht als piloot (C). Enkel bij de lokale speler.
var chase: MolChaseCam
var pickaxe: Pickaxe
var drill: Drill
var tools: Array[Node3D] = []
var active_tool: Node3D
var carry: Carry
var rig: RobotRig
var flying := false
## In de stoel van de Mol (piloot).
var seated := false

var _shape: CollisionShape3D
var _look_yaw := 0.0
const SEAT_FEET := Vector3(0.0, -1.12, -1.82)

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

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.4
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.7
	add_child(shape)
	_shape = shape

	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.2
	add_child(head)

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 20.0
	lamp.spot_angle = 52.0
	lamp.spot_angle_attenuation = 0.6
	# Boven en naast het oog, zoals op een helm: zo werpen putjes en richels schaduw.
	lamp.position = Vector3(0.18, 0.22, 0.05)
	# Helmlampen van anderen zonder schaduw: GDD §9 budget van 4-8 schaduwlampen.
	lamp.shadow_enabled = is_local or Tuning.value("player", "remote_lamp_shadows", true)
	# Gereedschap in beeld (laag 2) niet: van zo dichtbij brandt het uit. Het heeft een eigen vullicht.
	lamp.light_cull_mask = ~PickaxeModel.VIEWMODEL_LAYER
	head.add_child(lamp)

	if is_local:
		_setup_local()
	else:
		_setup_remote()


func _setup_local() -> void:
	camera = Camera3D.new()
	camera.fov = Tuning.get_f("player", "fov", 80.0)
	camera.near = 0.05
	head.add_child(camera)
	camera.make_current()

	camera_fx = CameraFx.new()
	camera_fx.camera = camera
	add_child(camera_fx)

	pickaxe = Pickaxe.new()
	pickaxe.terrain = game.terrain
	pickaxe.sync = game.terrain_sync
	pickaxe.finds = game.finds
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
		# Handen vol: gereedschap weg zolang je draagt.
		active_tool.set_active(it == null)
		_send_action(Action.CARRY_ON if it else Action.CARRY_OFF))
	game.mol.pilot_changed.connect(_on_pilot_changed)
	chase = MolChaseCam.new()
	chase.name = "ChaseCam"
	chase.mol = game.mol
	add_child(chase)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_pilot_changed(peer: int) -> void:
	if peer == peer_id and not seated:
		_sit()
	elif peer != peer_id and seated:
		_unseat()


func _sit() -> void:
	seated = true
	flying = false
	_shape.disabled = true
	_look_yaw = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO
	active_tool.set_active(false)


func _unseat() -> void:
	seated = false
	if chase.current:
		camera.make_current()
	_shape.disabled = false
	var mol: Mol = game.mol
	global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0.0, -1.45, -1.1)))
	head.rotation.x = 0.0
	if carry == null or carry.item == null:
		active_tool.set_active(true)


## Knop, hendel of rail onder het vizier (niet door een muur heen), of null.
func aimed_interactable() -> Interactable:
	var from := camera.global_position
	var hit: Dictionary = game.terrain.raycast(from, from - camera.global_basis.z * 3.0,
			Layers.TERRAIN | Layers.INTERACT)
	return hit.collider as Interactable if not hit.is_empty() else null


## Waar je iets vasthoudt: voor je, op ooghoogte, niet door een muur.
func hold_point(item_radius: float) -> Vector3:
	var fwd := -head.global_basis.z
	var from := head.global_position
	var dist := Tuning.get_f("carry", "hold_distance", 1.25)
	var hit: Dictionary = game.terrain.raycast(from, from + fwd * (dist + item_radius))
	if not hit.is_empty():
		dist = maxf(0.4, from.distance_to(hit.position) - item_radius)
	return from + fwd * dist + Vector3(0, -0.15, 0)


func select_tool(index: int) -> void:
	if carry and carry.item:
		return
	index = wrapi(index, 0, tools.size())
	if active_tool == tools[index]:
		return
	active_tool = tools[index]
	for t in tools:
		t.set_active(t == active_tool)
	_send_action(Action.TOOL_PICKAXE if active_tool == pickaxe else Action.TOOL_DRILL)
	tool_changed.emit(active_tool)


func _setup_remote() -> void:
	rig = RobotRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(color)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and captured and seated and chase.current:
		chase.look(event.relative, Tuning.get_f("player", "mouse_sensitivity", 0.0025))
	elif event.is_action_pressed("mol_view") and seated:
		if chase.current:
			camera.make_current()
		else:
			chase.activate()
	elif event is InputEventMouseMotion and captured and seated:
		# In de stoel: rondkijken binnen de cabine.
		var sens_s := Tuning.get_f("player", "mouse_sensitivity", 0.0025)
		_look_yaw = clampf(_look_yaw - event.relative.x * sens_s, -1.5, 1.5)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens_s, -0.9, 0.7)
	elif event is InputEventMouseMotion and captured:
		var sens := Tuning.get_f("player", "mouse_sensitivity", 0.0025)
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, -1.55, 1.55)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fly"):
		flying = not flying
	elif event.is_action_pressed("horn") and captured and (seated or game.mol.contains_point(global_position)):
		game.mol.press(Mol.Cmd.HORN)
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
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		input = Vector2.ZERO
	if flying:
		var fly_speed := Tuning.get_f("player", "fly_speed", 12.0)
		var v := head.global_basis * Vector3(input.x, 0.0, input.y) * fly_speed
		if Input.is_action_pressed("jump"):
			v.y += fly_speed
		if Input.is_action_pressed("crouch"):
			v.y -= fly_speed
		velocity = v
	else:
		var speed: float = Tuning.get_f("player", "move_speed", 4.5) * active_tool.move_multiplier() * (carry.move_multiplier() if carry else 1.0)
		var dir := (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		if not is_on_floor():
			velocity += get_gravity() * delta
		elif Input.is_action_just_pressed("jump") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			velocity.y = Tuning.get_f("player", "jump_velocity", 4.5)
	move_and_slide()


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
			_seat_to_mol() # ook tussen physics-ticks, zodat de camera vloeiend meebeweegt
		var mol: Mol = game.mol
		var in_mol := mol != null and (seated or mol.contains_point(global_position))
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


func _snap_pos(s: Array) -> Vector3:
	return game.mol.to_world_mol(s[1]) if s[4] else s[1]


func _snap_yaw(s: Array) -> float:
	return s[2] + game.mol.yaw if s[4] else s[2]


func _interpolate() -> void:
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
	if carry and carry.item:
		carry.drop(false)
	flying = false
	velocity = Vector3.ZERO
	global_position = pos


## Zichtbare acties (zwaai, gereedschap, boor) naar de anderen. Het terrein zelf komt via
## TerrainSync; dit is enkel wat je van de robot ziet en hoort.
## Wissel en boor aan/uit gaan betrouwbaar: die toestand moet kloppen.
@rpc("authority", "reliable", "call_remote")
func _rpc_action(action: int) -> void:
	if rig == null:
		return
	match action:
		Action.SWING:
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
