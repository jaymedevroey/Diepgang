extends Node
## Test van dragen (M1 stap 6). Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=carry_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
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

	await _heavy_and_fragile(p, here)

	print("[carry_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[carry_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Samen dragen en slepen (ontwerp-8) en breekbare kristallen (ontwerp-5), in een kamer onder de eerste
## vondst. Een titanschedel (28 kg) en twee glowshards worden er met de regels van FindField geplaatst.
func _heavy_and_fragile(p: Player, here: Vector3) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var drag := Tuning.get_f("carry", "drag_speed", 0.33)
	# Snelheden (dezelfde regel als in het spel): alleen slepen, met twee sneller dan slepen, maar trager dan leeg.
	var skull_kg: float = FindKinds.MASSES[FindKinds.Kind.TITAN_SKULL]
	var femur_kg: float = FindKinds.MASSES[FindKinds.Kind.TITAN_FEMUR]
	_expect(is_equal_approx(Carry.speed_for(skull_kg, 1), drag), "titanschedel alleen: slepen (%.2f)" % Carry.speed_for(skull_kg, 1))
	_expect(Carry.speed_for(skull_kg, 2) > 0.5 and Carry.speed_for(skull_kg, 2) < 0.75, "titanschedel (%d kg) met twee: %.2f (trager dan leeg)" % [int(skull_kg), Carry.speed_for(skull_kg, 2)])
	_expect(Carry.speed_for(femur_kg, 2) > Carry.speed_for(femur_kg, 1) * 2.0 and not FindKinds.liftable_alone(femur_kg), "reuzendijbeen (%d kg) met twee >2× zo snel als slepen (%.2f tegen %.2f)" % [int(femur_kg), Carry.speed_for(femur_kg, 2), Carry.speed_for(femur_kg, 1)])
	_expect(Carry.speed_for(14.0, 1) > drag and FindKinds.liftable_alone(14.0), "een schedel (14 kg) til je nog alleen (%.2f)" % Carry.speed_for(14.0, 1))
	# Een kamer van ±12 × 8 m onder de eerste vondst, met een vrij vlakke vloer.
	var room := here + Vector3(0, -6.0, 0)
	for dx in [-3.0, -1.0, 1.0, 3.0, 5.0]:
		for dz in [-2.0, 0.0, 2.0]:
			t.debug_dig(room + Vector3(dx, 0.0, dz), 2.6)
	await get_tree().create_timer(1.0).timeout
	# Plaatsen zoals FindField het doet (in de rots onder de kamer), dan naar de kamer en vrijmaken.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var big := finds._place(rng, func() -> Array: return [room + Vector3(rng.randf_range(-3, 3), -6.0, 0.0), FindKinds.Kind.TITAN_SKULL], 10)
	var shard_a := finds._place(rng, func() -> Array: return [room + Vector3(rng.randf_range(-3, 3), -6.0, -3.0), FindKinds.Kind.GLOWSHARD], 10)
	var shard_b := finds._place(rng, func() -> Array: return [room + Vector3(rng.randf_range(-3, 3), -6.0, 3.0), FindKinds.Kind.GLOWSHARD], 10)
	_expect(big != null and shard_a != null and shard_b != null, "titanschedel en twee glowshards geplaatst")
	if big == null or shard_a == null or shard_b == null:
		return
	var spots := [room + Vector3(-2.5, -1.0, 0.0), room + Vector3(2.0, -1.6, -2.2), room + Vector3(4.0, -1.6, 2.2)]
	for i in 3:
		var f: FindItem = [big, shard_a, shard_b][i]
		f.global_position = spots[i]
		f.reset_physics_interpolation()
		finds._free(f.find_id)
	await get_tree().create_timer(2.0).timeout
	_expect(big.freed and not big.freeze, "titanschedel vrij in de kamer")

	# Alleen: slepen.
	p.global_position = big.global_position + Vector3(1.6, -0.4, 0.0)
	p.look_at(big.global_position)
	p.rotation.x = 0.0
	await _frames(2)
	_expect(Carry.verb(big) == "Drag", "prompt: slepen (%s)" % Carry.verb(big))
	finds.request_grab(big.find_id)
	await _frames(3)
	_expect(p.carry.item == big and big.dragged(), "alleen: de titanschedel wordt gesleept")
	_expect(is_equal_approx(p.carry.move_multiplier(), drag), "slepen aan %.2f van de loopsnelheid" % p.carry.move_multiplier())
	_expect(p.carry.note().begins_with("Too heavy"), "kaartje: %s" % p.carry.note())
	await get_tree().create_timer(1.2).timeout
	var floor_hit: Dictionary = t.raycast(big.global_position + Vector3(0, 1.0, 0), big.global_position - Vector3(0, 3.0, 0))
	var bottom := big.global_position.y - big.bottom_offset(big.global_basis)
	_expect(not floor_hit.is_empty() and absf(bottom - floor_hit.position.y) < 0.25,
			"gesleept: hij ligt op de grond (%.2f m erboven)" % (bottom - (floor_hit.position.y if not floor_hit.is_empty() else 0.0)))
	var c0 := big.condition
	var from := big.global_position
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for i in 25:
		p.global_position -= fwd * 0.22 # achteruit trekken, door de kamer
		await _frames(3)
	await get_tree().create_timer(0.8).timeout
	var moved := big.global_position.distance_to(from)
	_expect(moved > 3.5, "de gesleepte schedel volgt (%.1f m)" % moved)
	_expect(big.condition < c0 and big.condition > c0 - 0.1, "slepen schuurt een beetje (%d%% → %d%%)" % [int(c0 * 100), int(big.condition * 100)])
	# Een tweede drager (hier nagebootst; de nettest doet het echt): getild, en veel sneller.
	big.carriers = PackedInt32Array([p.peer_id, 9999])
	_expect(not big.dragged() and p.carry.move_multiplier() > drag * 1.6, "met twee: getild, %.2f van de loopsnelheid" % p.carry.move_multiplier())
	_expect(p.carry.note() == "Carried together", "kaartje met twee: %s" % p.carry.note())
	big.carriers = PackedInt32Array([p.peer_id])
	p.carry.drop(false)
	await _frames(3)

	# Breekbaar: de regel voor een klap, en echt laten vallen tegenover neerzetten.
	var shard_rule := shard_a.condition
	_expect(is_equal_approx(FindField.impact_condition(shard_a, 1.0), shard_rule), "glowshard: een tikje (1 m/s) doet niets")
	var dented := FindField.impact_condition(shard_a, 2.6)
	_expect(dented < shard_rule - 0.1 and dented > 0.5, "glowshard: een klap van 2,6 m/s kost al %d%%" % int((shard_rule - dented) * 100))
	_expect(FindField.impact_condition(shard_a, 5.0) <= 0.081, "glowshard: een klap van 5 m/s breekt hem")
	_expect(FindField.impact_condition(big, 5.0) > 0.5 and big.fragility == 0.0, "een bot breekt niet van 5 m/s (%d%%)" % int(FindField.impact_condition(big, 5.0) * 100))
	# Neerzetten met E: geen val, geen schade.
	p.global_position = shard_a.global_position + Vector3(0, -0.3, 1.4)
	p.look_at(shard_a.global_position)
	p.rotation.x = 0.0
	await _frames(2)
	finds.request_grab(shard_a.find_id)
	await get_tree().create_timer(1.0).timeout
	_expect(p.carry.item == shard_a and p.carry.note().begins_with("Fragile"), "glowshard in de handen: %s" % p.carry.note())
	p.carry.drop(false)
	await get_tree().create_timer(1.5).timeout
	_expect(shard_a.condition > 0.99 and not shard_a.is_shattered() and shard_a._light.visible,
			"neergezet met E: heel en hij gloeit (%d%%)" % int(shard_a.condition * 100))
	# Laten vallen van op draaghoogte (1,4 m, zoals bij omvallen): hij breekt.
	shard_b.freeze = false
	shard_b.global_position += Vector3(0, 1.4, 0)
	shard_b.linear_velocity = Vector3.ZERO
	shard_b.sleeping = false
	shard_b.reset_physics_interpolation()
	await get_tree().create_timer(2.0).timeout
	_expect(shard_b.is_shattered() and not shard_b._light.visible and shard_b.value() < 25,
			"gevallen van 1,4 m: gebroken, licht uit (%d%%, €%d)" % [int(shard_b.condition * 100), shard_b.value()])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[carry_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
