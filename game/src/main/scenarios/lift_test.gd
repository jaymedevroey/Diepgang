extends Node
## Test van de lift (M1 stap 7). Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=lift_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		print("[lift_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(p: Player) -> void:
	var lift: Lift = main.game.lift
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	await _frames(10)
	_expect(is_equal_approx(lift.y, lift.top_y), "lift staat boven (%.1f m)" % lift.y)

	# Roepen vanaf een diepte: de speler hangt naast de schacht op 20 m diepte.
	p.set_physics_process(false)
	var sc := t.shaft_center_world()
	var depth_y := lift.top_y - 20.0
	p.global_position = sc + Vector3(4.2, depth_y, 0)
	lift.request(Lift.Command.CALL, p)
	var start := Time.get_ticks_msec()
	while lift.moving:
		await get_tree().physics_frame
	var secs := (Time.get_ticks_msec() - start) / 1000.0
	_expect(absf(lift.y - depth_y) < 0.01, "lift komt naar de roeper (%.2f m)" % lift.y)
	# 20 m met optrekken en afremmen: 20/v + v/a.
	var ideal := 20.0 / Tuning.get_f("lift", "speed", 4.0) + Tuning.get_f("lift", "speed", 4.0) / Tuning.get_f("lift", "acceleration", 3.0)
	_expect(absf(secs - ideal) < 0.8, "snelheid klopt (%.1f s voor 20 m, verwacht %.1f s)" % [secs, ideal])

	# Een vrijgemaakte vondst en de speler op het platform, dan naar boven.
	var it := finds.items[4]
	finds._free(it.find_id)
	await get_tree().create_timer(0.3).timeout
	it.global_position = sc + Vector3(1.0, depth_y + 0.4, 0.5)
	it.linear_velocity = Vector3.ZERO
	p.global_position = sc + Vector3(-1.0, depth_y + 0.05, 0)
	p.set_physics_process(true)
	await get_tree().create_timer(1.0).timeout
	var item_rel := it.global_position.y - lift.y
	_expect(item_rel > -0.05 and item_rel < 0.5, "vondst ligt op het platform (%.2f m boven het dek)" % item_rel)
	lift.request(Lift.Command.UP, p)
	await get_tree().physics_frame
	_expect(lift.moving, "▲ zet de lift in beweging")
	while lift.moving:
		await get_tree().physics_frame
	await get_tree().create_timer(0.5).timeout
	_expect(is_equal_approx(lift.y, lift.top_y), "lift is boven")
	var p_rel := p.global_position.y - lift.y
	_expect(p_rel > -0.1 and p_rel < 0.3, "speler reed mee (%.2f m boven het dek)" % p_rel)
	item_rel = it.global_position.y - lift.y
	_expect(item_rel > -0.05 and item_rel < 0.5, "vondst reed mee (%.2f m boven het dek)" % item_rel)

	# ▼ zakt een stap; te ver weg mag niet.
	lift.request(Lift.Command.DOWN, p)
	while lift.moving:
		await get_tree().physics_frame
	_expect(is_equal_approx(lift.y, lift.top_y - Tuning.get_f("lift", "step_down", 12.0)), "▼ zakt 12 m")
	p.set_physics_process(false)
	p.global_position = sc + Vector3(20.0, lift.top_y, 0)
	var y_before := lift.y
	lift.request(Lift.Command.UP, p)
	await _frames(3)
	_expect(lift.y == y_before and not lift.moving, "roepen van te ver weg geweigerd")

	print("[lift_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[lift_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[lift_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
