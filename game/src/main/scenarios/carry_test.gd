extends Node
## Test van dragen (M1 stap 6). Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=carry_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		print("[carry_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(p: Player) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	p.set_physics_process(false)
	await _frames(10)

	# Vondst vrijmaken en er een open ruimte rond graven om in te werken.
	var it := finds.items[0]
	var here := it.global_position
	for i in int(finds.crusts[it.find_id].max_hp):
		p.global_position = here + Vector3(0, 0.3, 1.2)
		finds.hit_crust(it.find_id, Strata.Tool.HOUWEEL, here)
		await get_tree().create_timer(0.3).timeout
	for dx in [-2.0, 0.0, 2.0, 4.0]:
		t.debug_dig(here + Vector3(dx, 0.8, 1.5), 2.2)
	await get_tree().create_timer(1.5).timeout
	_expect(it.freed, "vondst is vrij")

	# Oppakken.
	p.global_position = it.global_position + Vector3(0, -0.4, 1.5)
	p.look_at(it.global_position + Vector3(0, -0.4, 0))
	p.rotation.x = 0.0
	await _frames(2)
	finds.request_grab(it.find_id)
	await _frames(2)
	_expect(p.carry.item == it and it.carriers == PackedInt32Array([p.peer_id]), "speler draagt de vondst")
	_expect(not p.active_tool.visible, "gereedschap weg tijdens het dragen")
	var mult := p.carry.move_multiplier()
	var expect := maxf(0.4, 1.0 - it.mass / 30.0)
	_expect(is_equal_approx(mult, expect), "trager met gewicht (%.2f bij %.0f kg)" % [mult, it.mass])

	# Volgt de hand. Naar de oppervlakte erboven, zodat er ruimte is om te gooien.
	var t_api: TerrainAPI = main.terrain
	var up := p.global_position
	up.y = t_api.surface_height_at(up.x, up.z) + 1.2
	p.global_position = up
	await _frames(3)
	# De vondst volgt je handen met een veer (gevoel-06): eerst blijft hij achter, dan komt hij erbij.
	p.global_position += Vector3(1.0, 0, 0)
	await _frames(3)
	var target := p.hold_point(it.half_extents.length())
	var lag := it.global_position.distance_to(target)
	_expect(lag > 0.1, "vondst sleept na (%.2f m achter)" % lag)
	await get_tree().create_timer(1.0).timeout
	target = p.hold_point(it.half_extents.length())
	_expect(it.global_position.distance_to(target) < 0.05, "vondst volgt de hand (%.2f m)" % it.global_position.distance_to(target))

	# Gooien.
	var before := it.global_position
	p.carry.drop(true)
	await _frames(2)
	_expect(p.carry.item == null and it.carriers.is_empty(), "losgelaten")
	_expect(not it.freeze, "fysica neemt over")
	await get_tree().create_timer(0.4).timeout
	var fwd := -p.head.global_basis.z
	var moved := (it.global_position - before).dot(fwd)
	_expect(moved > 0.8, "gegooid in de kijkrichting (%.2f m)" % moved)
	_expect(p.active_tool.visible, "gereedschap terug na het loslaten")

	# Harde klap: gaafheid omlaag.
	var cond := it.condition
	it.linear_velocity = Vector3(0, -14, 0)
	it.sleeping = false
	await get_tree().create_timer(1.0).timeout
	_expect(it.condition < cond, "harde klap kost gaafheid (%d%% → %d%%)" % [int(cond * 100), int(it.condition * 100)])

	print("[carry_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[carry_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[carry_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
