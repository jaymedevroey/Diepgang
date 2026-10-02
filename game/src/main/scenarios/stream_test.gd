extends Node
## Test van het streamen van de grote planeet (GDD v3 §4, §9). Solo, headless.
## - Laden: het spel begint als het gebied rond de Mol klaar is, niet de hele planeet.
## - Ver weg is niets geladen; dichtbij wel.
## - Een gat ver van de Mol blijft bestaan als zijn blok ontladen en later opnieuw geladen wordt.
## - Een op voor gebied dat nog niet geladen is, wacht en wordt toegepast zodra iemand erheen gaat.
## tools\godot.cmd --headless --path game -- --scenario=stream_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	# Kleinere laadafstand in deze test, zodat "ver weg" ondubbelzinnig is (laden gebeurt in een
	# kubus en rondt af op blokken van 8 m).
	if not CmdArgs.has("probe"):
		Tuning.set_value("terrain", "view_m", 60.0)
		Tuning.set_value("terrain", "collision_m", 32.0)
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(180.0).timeout.connect(func() -> void:
		print("[stream_test] GEFAALD: time-out")
		for f in _failures:
			print("[stream_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var t: TerrainAPI = main.terrain
	var mol: Mol = main.game.mol
	var size := t.world_size()
	print("[stream_test] planeet %.0f × %.0f × %.0f m, geladen in %.0f ms" % [size.x, size.z, size.y, main.load_ms])
	_expect(size.x >= 240.0 and size.y >= 290.0, "planeet is groot (%.0f × %.0f m)" % [size.x, size.y])
	if CmdArgs.has("probe"):
		await _wait(10.0)
		var c := mol.body.global_position
		var reach := 0.0
		for d in range(0, 200, 4):
			var q := c + Vector3(d, 0, 0)
			if q.x < size.x and t.data_loaded(q):
				reach = d
		var reach_y := 0.0
		for d in range(0, 200, 4):
			var q := c - Vector3(0, d, 0)
			if q.y > 0.0 and t.data_loaded(q):
				reach_y = d
		print("[stream_test] geladen tot %.0f m opzij en %.0f m omlaag (viewer: view_m %.0f, collision_m %.0f)" % [
				reach, reach_y, Tuning.get_f("terrain", "view_m", 0), Tuning.get_f("terrain", "collision_m", 0)])
		get_tree().quit(0)
		return
	var far_corner := Vector3(12.0, t.surface_height_at(12.0, 12.0) - 5.0, 12.0)
	_expect(not t.data_loaded(far_corner), "ver weg (hoek van de planeet) is niets geladen")
	_expect(t.data_loaded(mol.body.global_position), "rond de Mol is alles geladen")
	# Echte collision (fysicastraal), niet enkel data: rond de Mol, en 15–30 m ervandaan.
	for off: Vector3 in [Vector3(0, 0, 12), Vector3(-13, 0, 0), Vector3(15, 0, 15), Vector3(-30, 0, 5)]:
		var q := mol.body.global_position + off
		q.y = t.surface_height_at(q.x, q.z) + 3.0
		var hit := t.raycast(q, q - Vector3(0, 12, 0))
		_expect(not hit.is_empty(), "collision op %s van de Mol (straal raakt de grond)" % off)

	# 1. Ver van de Mol graven, weglopen, terugkomen.
	# Geladen wordt een kubus rond elke viewer: verder dan view_m langs één as = buiten bereik.
	var spot := Vector3(30.0, 0.0, 125.0)
	spot.y = t.surface_height_at(spot.x, spot.z) - 3.0
	await _go(p, spot + Vector3(0, 6.0, 0))
	_expect(t.is_solid(spot), "graafplek ver van de Mol is rots")
	t.debug_dig(spot, 1.5)
	await _wait(0.5)
	_expect(not t.is_solid(spot), "gat gegraven")
	var sum_before := t.checksum(spot, 6.0)
	await _go(p, mol.body.global_position + Vector3(0, 3.0, 9.0))
	var t0 := Time.get_ticks_msec()
	while t.data_loaded(spot) and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	_expect(not t.data_loaded(spot), "graafplek ontladen na het weglopen")
	await _go(p, spot + Vector3(0, 6.0, 0))
	_expect(not t.is_solid(spot), "gat is er nog na opnieuw laden")
	_expect(t.checksum(spot, 6.0) == sum_before, "terrein rond het gat identiek na ontladen en laden")

	# 2. Een op voor gebied dat niet geladen is (bv. van een andere speler ver weg).
	var far := Vector3(size.x - 30.0, 0.0, 140.0)
	far.y = t.surface_height_at(far.x, far.z) - 4.0
	_expect(not t.data_loaded(far), "andere hoek is niet geladen")
	t.debug_dig(far, 1.5)
	await _wait(0.3)
	_expect(t.waiting_ops() >= 1, "op voor niet-geladen gebied wacht (%d)" % t.waiting_ops())
	await _go(p, far + Vector3(0, 7.0, 0))
	await _wait(0.5)
	# De op past pas toe als al zijn blokken geladen zijn (ook die onder de graafplek).
	var t1 := Time.get_ticks_msec()
	while t.is_solid(far) and Time.get_ticks_msec() - t1 < 8000:
		await get_tree().process_frame
	_expect(not t.is_solid(far), "op toegepast zodra het gebied geladen is (na %d ms)" % (Time.get_ticks_msec() - t1))
	_expect(t.waiting_ops() == 0, "geen ops meer die wachten (%d)" % t.waiting_ops())

	print("[stream_test] ops opnieuw toegepast (overschreven na laden): %d" % t.ops_repaired)
	print("[stream_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[stream_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Speler ergens neerzetten en wachten tot het terrein daar klaar is (met collision).
func _go(p: Player, pos: Vector3) -> void:
	p.set_physics_process(false)
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var t: TerrainAPI = main.terrain
	var t0 := Time.get_ticks_msec()
	while not (t.is_area_ready(pos, 8.0) and t.collision_ready(pos)) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().process_frame
	print("[stream_test] naar (%.0f, %.0f, %.0f): klaar na %d ms" % [pos.x, pos.y, pos.z, Time.get_ticks_msec() - t0])
	p.set_physics_process(true)
	await _wait(0.2)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[stream_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
