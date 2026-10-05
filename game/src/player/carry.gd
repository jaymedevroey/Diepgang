class_name Carry
extends Node
## Grijphandschoen van de lokale speler (GDD §3, §9).
## E = oppakken / neerzetten, linkermuis = gooien. De host beslist wie iets draagt;
## zodra je drager bent, volgt de vondst op je eigen scherm meteen je handen (voorspelling).
## Loslaten: je stuurt je laatste positie en snelheid, de host neemt de fysica over.
##
## Gewicht (gevoel-06, binnen-10): twee robothanden in beeld houden de vondst vast. Hij volgt het
## houdpunt met een veer (hoe zwaarder, hoe trager hij naslingert) en kantelt mee met zijn
## naslepen. Gooien geeft hem die snelheid mee.

signal changed(item: FindItem)

## Stand van de handen (graden): onderarm naar onder (pitch) en naar buiten (yaw).
const HAND_PITCH := 38.0
const HAND_YAW := 22.0

var player: Player
var finds: FindField
var item: FindItem

var _vel := Vector3.ZERO # snelheid van de vondst in je handen (veer)
var _rel_basis := Basis() # draaiing t.o.v. je kijkrichting bij het oppakken
var _hands: Array[Node3D] = []


func _ready() -> void:
	finds.carriers_changed.connect(_on_carriers_changed)
	# Twee open handen (tools.glb: Glove_Open, rechterhand; links gespiegeld). Op de laag van het
	# gereedschap in beeld: het vullicht van het gereedschap raakt ze, de helmlamp niet.
	for side in [-1.0, 1.0]:
		var h := Node3D.new()
		h.name = "Hand%s" % ("L" if side < 0 else "R")
		h.top_level = true
		h.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		h.visible = false
		var mi := PickaxeModel.part("Glove_Open", 0.0, player.color, false)
		mi.layers = PickaxeModel.VIEWMODEL_LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3.ZERO
		h.add_child(mi)
		h.scale = Vector3(side, 1.0, 1.0)
		h.set_meta("side", side)
		player.add_child.call_deferred(h)
		_hands.append(h)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		return
	if event.is_action_pressed("interact") and player.seated:
		# In de stoel: een knop onder het vizier indrukken, anders uitstappen.
		var knob := player.aimed_interactable()
		if knob:
			knob.used.emit(player)
		else:
			player.game.mol.leave_seat()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var button := player.aimed_interactable()
		var mol: Mol = player.game.mol
		if button:
			button.used.emit(player)
		elif item == null and aimed_item() == null and mol.in_cockpit(player.global_position) and mol.pilot == 0:
			mol.press(Mol.Cmd.SEAT) # in de cabine: E = plaatsnemen, ook als je niet precies op de stoel mikt
		elif item:
			drop(false)
		else:
			try_grab()
		get_viewport().set_input_as_handled()
	elif item and event.is_action_pressed("dig") and not player.seated:
		drop(true)
		get_viewport().set_input_as_handled()


## Vondst onder het vizier (vrij, niet al door twee gedragen), of null.
func aimed_item() -> FindItem:
	var cam := player.camera
	var reach := Tuning.get_f("carry", "grab_reach", 3.0)
	var hit: Dictionary = player.game.terrain.raycast(cam.global_position, cam.global_position - cam.global_basis.z * reach,
			Layers.TERRAIN | Layers.LOOT | Layers.LIFT) # de Mol houdt de straal tegen
	if hit.is_empty() or not (hit.collider is FindItem):
		return null
	var it: FindItem = hit.collider
	return it if it.freed and it.carriers.size() < 2 else null


func try_grab() -> void:
	var it := aimed_item()
	if it:
		finds.request_grab(it.find_id)


func drop(throw: bool) -> void:
	if item == null:
		return
	var vel := player.velocity + _vel * 0.5
	if throw:
		vel += -player.camera.global_basis.z * Tuning.get_f("carry", "throw_speed", 6.5)
	finds.request_release(item.find_id, item.global_transform, vel)
	_set_item(null)


## Loopsnelheid met wat je draagt.
func move_multiplier() -> float:
	if item == null:
		return 1.0
	var n := maxi(1, item.carriers.size())
	var k := 1.0 - item.mass / (Tuning.get_f("carry", "strength", 30.0) * n)
	return maxf(Tuning.get_f("carry", "min_speed", 0.4), k)


func _physics_process(delta: float) -> void:
	if item == null:
		return
	if not is_instance_valid(item) or not item.carriers.has(player.peer_id):
		_set_item(null)
		return
	# Veer naar het houdpunt: zwaarder = slapper, dus meer naslepen en slingeren.
	var target := finds.carry_target(item)
	var heavy := 1.0 + item.mass / maxf(Tuning.get_f("carry", "follow_mass_ref", 6.0), 0.1)
	var k := Tuning.get_f("carry", "follow_stiffness", 260.0) / heavy
	var c := Tuning.get_f("carry", "follow_damping", 26.0) / sqrt(heavy)
	var pos := item.global_position
	if pos.distance_to(target) > 2.5: # te ver weg (een sprong, een teleport): meteen erbij
		pos = target
		_vel = Vector3.ZERO
		item.global_position = pos
		item.reset_physics_interpolation()
	_vel += ((target - pos) * k - _vel * c) * delta
	pos += _vel * delta
	# Kantelen met het naslepen: de onderkant blijft achter, als iets zwaars aan twee handen.
	var lag := player.head.global_basis.inverse() * (target - pos)
	var tilt := deg_to_rad(Tuning.get_f("carry", "sway_tilt_deg", 14.0))
	var sway := Basis.from_euler(Vector3(clampf(-lag.y * 6.0, -1.0, 1.0) * tilt, 0.0, clampf(lag.x * 6.0, -1.0, 1.0) * tilt))
	var yaw_basis := Basis(Vector3.UP, player.rotation.y)
	item.global_transform = Transform3D(yaw_basis * sway * _rel_basis, pos)


## De handen aan weerszijden van de vondst, zoals hij getekend wordt (elke frame).
func _process(_delta: float) -> void:
	var show := item != null and is_instance_valid(item) and player.camera != null
	for h in _hands:
		h.visible = show
	if not show:
		return
	var cam := player.camera.global_transform
	var at := item.get_global_transform_interpolated().origin
	var r := item.half_extents.length()
	var right := cam.basis.x
	var up := cam.basis.y
	for h in _hands:
		var side: float = h.get_meta("side")
		# Handpalm tegen de zijkant van de vondst, iets onder het midden. De hand kantelt zodat de
		# onderarm schuin naar onder en opzij uit beeld loopt (niet recht naar de camera).
		var p := at + right * side * (r * 0.78 + 0.02) - up * r * 0.3
		var tilt := cam.basis * Basis(Vector3.UP, deg_to_rad(HAND_YAW * side)) * Basis(Vector3.RIGHT, deg_to_rad(HAND_PITCH))
		h.global_transform = Transform3D(tilt.scaled_local(Vector3(side, 1.0, 1.0)), p)


func _on_carriers_changed(it: FindItem) -> void:
	var mine := it.carriers.has(player.peer_id)
	if mine and item != it:
		_set_item(it)
	elif not mine and item == it:
		_set_item(null)


func _set_item(it: FindItem) -> void:
	# De vondst mag de drager niet duwen (bv. als je naar beneden kijkt).
	if item and is_instance_valid(item):
		player.remove_collision_exception_with(item)
		item.set_held(false)
	item = it
	if item:
		item.set_held(true)
	_vel = Vector3.ZERO
	if item:
		player.add_collision_exception_with(item)
		# Zijn draaiing t.o.v. je kijkrichting houden (enkel de yaw, hij blijft rechtop).
		_rel_basis = Basis(Vector3.UP, -player.rotation.y) * item.global_basis
	changed.emit(it)
