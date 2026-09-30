class_name Carry
extends Node
## Grijphandschoen van de lokale speler (GDD §3, §9).
## E = oppakken / neerzetten, linkermuis = gooien. De host beslist wie iets draagt;
## zodra je drager bent, volgt de vondst op je eigen scherm meteen je hand (voorspelling).
## Loslaten: je stuurt je laatste positie en snelheid, de host neemt de fysica over.

signal changed(item: FindItem)

var player: Player
var finds: FindField
var item: FindItem


func _ready() -> void:
	finds.carriers_changed.connect(_on_carriers_changed)


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("interact"):
		if item:
			drop(false)
		else:
			try_grab()
		get_viewport().set_input_as_handled()
	elif item and event.is_action_pressed("dig"):
		drop(true)
		get_viewport().set_input_as_handled()


## Vondst onder het vizier (vrij, niet al door twee gedragen), of null.
func aimed_item() -> FindItem:
	var cam := player.camera
	var reach := Tuning.get_f("carry", "grab_reach", 3.0)
	var hit: Dictionary = player.game.terrain.raycast(cam.global_position, cam.global_position - cam.global_basis.z * reach,
			Layers.TERRAIN | Layers.LOOT)
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
	var vel := player.velocity
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


func _physics_process(_delta: float) -> void:
	if item == null:
		return
	if not is_instance_valid(item) or not item.carriers.has(player.peer_id):
		_set_item(null)
		return
	item.global_position = finds.carry_target(item)


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
	item = it
	if item:
		player.add_collision_exception_with(item)
	changed.emit(it)
