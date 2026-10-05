extends Node
## Screenshot: een vondst dragen in een uitgegraven kuil.
## tools\godot.cmd --path game -- --scenario=carry_preview --no-steam

var main: Node
var _frame := -1


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _setup.call_deferred(p))


func _setup(p: Player) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var it := finds.items[int(CmdArgs.value("find", 1))]
	var here := it.global_position
	for dx in [-2.0, 0.0, 2.0]:
		t.debug_dig(here + Vector3(dx, 0.9, 1.6), 2.3)
	await get_tree().create_timer(0.5).timeout
	finds._free(it.find_id)
	await get_tree().create_timer(1.5).timeout
	p.global_position = it.global_position + Vector3(0, -0.2, 1.6)
	p.look_at(it.global_position + Vector3(0, -0.2, 0))
	p.rotation.x = 0.0
	p.head.rotation.x = deg_to_rad(-12)
	await get_tree().create_timer(0.3).timeout
	finds.request_grab(it.find_id)
	_frame = 0


func _process(_delta: float) -> void:
	if _frame < 0:
		return
	_frame += 1
	# Na 2,5 s: de speler is geland en de vondst hangt stil in zijn handen (hij volgt met een veer).
	if _frame == 150:
		var path := PerfLog.log_dir().path_join("carry.png")
		get_viewport().get_texture().get_image().save_png(path)
		print("[preview] ", path)
		get_tree().quit(0)
