extends Node
## Test van vondsten en korsten (M1 stap 5). Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=find_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		print("[find_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(p: Player) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	# De speler wordt naast vondsten in de rots gezet: geen zwaartekracht, anders valt hij weg.
	p.set_physics_process(false)
	await _frames(10)
	_expect(finds.items.size() >= 30, "vondsten geplaatst (%d)" % finds.items.size())
	var all_embedded := true
	for it in finds.items:
		all_embedded = all_embedded and t.generated_rock_depth(it.global_position) > 1.0 and it.freeze
	_expect(all_embedded, "alle vondsten zitten vast in de rots, in een korst")
	var closest := INF
	for i in finds.items.size():
		for j in range(i + 1, finds.items.size()):
			closest = minf(closest, finds.items[i].global_position.distance_to(finds.items[j].global_position))
	_expect(closest >= 2.0, "vondsten liggen minstens 2 m uit elkaar (%.2f m)" % closest)
	var near := finds.items[0].global_position.distance_to(t.spawn_point())
	_expect(near < 9.0, "eerste vondst ligt dicht bij de spawn (%.1f m)" % near)
	_expect(FindKinds.FAMILIES[finds.items[0].kind] == FindKinds.Family.SKELETON, "eerste vondst is een bot (%s)" % finds.items[0].display_name())
	# Niet altijd dezelfde klauw (ontwerp-16): de eerste soort volgt uit de seed (zoals FindField.generate).
	var firsts := {}
	for s in range(1, 10):
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919 + 11
		firsts[FindField.FIRST_BONES[rng.randi() % FindField.FIRST_BONES.size()]] = true
	_expect(firsts.size() >= 3, "eerste vondst wisselt per wereld (%d soorten in 9 seeds)" % firsts.size())

	# Houweel: zoveel slagen als de korst levens heeft (meer voor waardevollere vondsten), geen schade.
	var a := finds.items[0]
	var value_a := a.value()
	var hits_a := int(finds.crusts[a.find_id].max_hp)
	_expect(hits_a >= 7 and hits_a == int(FindField.crust_hp_of(a)), "korst heeft %d levens (waardeklasse %d)" % [hits_a, a.value_class])
	p.global_position = a.global_position + Vector3(0, 0.3, 1.2)
	for i in hits_a - 1:
		finds.hit_crust(a.find_id, Strata.Tool.HOUWEEL, a.global_position)
		await get_tree().create_timer(0.3).timeout
	_expect(not a.freed, "korst houdt tot de laatste slag")
	finds.hit_crust(a.find_id, Strata.Tool.HOUWEEL, a.global_position)
	await get_tree().create_timer(0.3).timeout
	_expect(a.freed, "korst breekt na %d houweelslagen" % hits_a)
	_expect(not finds.crusts.has(a.find_id), "korst is weg")
	_expect(is_equal_approx(a.condition, 1.0) and a.value() == value_a, "houweel: vondst gaaf (%d%%, €%d)" % [int(a.condition * 100), a.value()])
	await _frames(3)
	_expect(not t.is_solid(a.global_position), "ruimte rond de vondst is uitgegraven")
	_expect(not a.freeze, "vondst is een fysica-object")
	var start := a.global_position
	await get_tree().create_timer(1.5).timeout
	_expect(a.global_position.distance_to(start) > 0.05, "vondst bewoog na het vrijkomen (%.2f m)" % a.global_position.distance_to(start))

	# Boor: sneller, maar schade.
	var b := finds.items[1]
	var value_b := b.value()
	p.global_position = b.global_position + Vector3(0, 0.3, 1.2)
	var bites := 0
	var t0 := Time.get_ticks_msec()
	while not b.freed and bites < 30:
		finds.hit_crust(b.find_id, Strata.Tool.BOOR_T1, b.global_position)
		bites += 1
		await get_tree().create_timer(0.1).timeout
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var pick_secs := finds.crust_hp_of(b) * 0.55
	_expect(b.freed, "boor breekt de korst (%d happen, %.1f s)" % [bites, secs])
	_expect(secs < pick_secs * 0.5, "boor is veel sneller dan het houweel (%.1f s tegen ±%.1f s)" % [secs, pick_secs])
	# Koel geboord: ±10-18 % minder (ontwerp-11), niet een derde van de waarde.
	_expect(b.condition < 0.95 and b.condition > 0.75 and b.value() < value_b, "boor (koel): vondst beschadigd (%d%%, €%d → €%d)" % [int(b.condition * 100), value_b, b.value()])

	# Hete boor: dubbel zoveel schade per hap.
	var h := finds.items[3]
	p.global_position = h.global_position + Vector3(0, 0.3, 1.2)
	var hot_bites := 0
	while not h.freed and hot_bites < 30:
		finds.hit_crust(h.find_id, Strata.Tool.BOOR_T1, h.global_position, true)
		hot_bites += 1
		await get_tree().create_timer(0.1).timeout
	var cool_loss := (1.0 - b.condition) / finds.crust_hp_of(b)
	var hot_loss := (1.0 - h.condition) / finds.crust_hp_of(h)
	_expect(h.freed and hot_loss > cool_loss * 1.8, "hete boor: meer schade per hap (%.3f tegen %.3f)" % [hot_loss, cool_loss])

	# Te ver weg: host weigert.
	var c := finds.items[2]
	p.global_position = c.global_position + Vector3(0, 0, 10)
	finds.hit_crust(c.find_id, Strata.Tool.HOUWEEL, c.global_position)
	await _frames(3)
	_expect(is_equal_approx(finds.crusts[c.find_id].hp, finds.crusts[c.find_id].max_hp), "treffer van te ver weg geweigerd")

	var snap := finds.snapshot()
	_expect(snap.size() == finds.items.size() and snap[0][3] == true and snap[2][3] == false, "snapshot voor late joiners klopt")

	print("[find_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[find_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[find_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
