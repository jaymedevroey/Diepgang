extends Node
## Test van vondsten en korsten (M1 stap 5). Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=find_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(200.0).timeout.connect(func() -> void:
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

	await _planets(p)

	print("[find_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[find_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Per planeet een andere buit (release-audit ontwerp-5, -8, -9; PlanetLoot): drie planeten × twee seeds,
## tellen en vergelijken. Elke planeet moet anders spelen: Roestbol rommel en kleine skeletten, Fossielwereld
## grote skeletten met zware stukken, Kristalmaan breekbare, lichtgevende kristallen.
func _planets(p: Player) -> void:
	var game: Game = main.game
	var finds: FindField = game.finds
	var stats: Array[Dictionary] = []
	for planet in 3:
		var st := {"n": 0, "fam": [0, 0, 0, 0, 0], "heavy": 0, "fragile": 0, "glow": 0, "sets": 0, "titans": 0,
				"reach_sets": 0, "value": 0, "clustered": 0, "glow_ore_sand": 0, "ore": 0, "set_ok": true, "together": true}
		for s in [11, 12]:
			game.host_new_world(s, planet)
			await _frames(2)
			var t0 := Time.get_ticks_msec()
			while not game.world_ready() and Time.get_ticks_msec() - t0 < 20000:
				await _frames(5)
			st.n += finds.items.size()
			for it in finds.items:
				st.fam[FindKinds.FAMILIES[it.kind]] += 1
				st.heavy += 0 if FindKinds.liftable_alone(it.mass) else 1
				st.fragile += 1 if it.fragility > 0.0 else 0
				st.glow += 1 if FindKinds.GLOW.has(it.kind) else 0
				st.value += it.base_value
				var near := 0
				for o in finds.items:
					if o != it and o.global_position.distance_to(it.global_position) < 7.0:
						near += 1
				st.clustered += 1 if near >= 2 else 0
			var sets := finds.sets()
			st.sets += sets.size()
			for id: String in sets:
				var pieces: Array = sets[id]
				var c := Vector3.ZERO
				for it: FindItem in pieces:
					c += it.global_position
				c /= pieces.size()
				var first: FindItem = pieces[0]
				var half: float = PlanetLoot.SETS["titan" if first.set_name == "Titan" else "strider"].half_len
				for it: FindItem in pieces:
					st.set_ok = st.set_ok and it.set_size == pieces.size() and it.set_name == first.set_name \
							and pieces.size() >= 3 and pieces.size() <= 8 and FindKinds.FAMILIES[it.kind] == FindKinds.Family.SKELETON
					st.together = st.together and it.global_position.distance_to(c) < half + 3.0
				st.set_ok = st.set_ok and pieces.any(func(x: FindItem) -> bool: return x.kind in [FindKinds.Kind.SKULL, FindKinds.Kind.TITAN_SKULL])
				st.titans += 1 if first.set_name == "Titan" else 0
				st.reach_sets += 1 if c.y > Strata.TOPS_M[1] else 0
			for oc in game.ores.clusters:
				st.ore += 1
				st.glow_ore_sand += 1 if oc.kind == OreKinds.Kind.LICHTKRISTAL and game.terrain.layer_at(oc.global_position) == Strata.Layer.ZANDSTEEN else 0
		stats.append(st)
		var n := float(st.n)
		print("[find_test] %s (2 werelden): %d vondsten, skelet %d%%, relikwie %d%%, metaal %d%%, rommel %d%%, kristal %d%% · zwaar %d, breekbaar %d, gloeit %d · %d skeletten (%d Titan, %d bereikbaar met T1) · %d%% in groepjes · €%d · erts %d (lichtkristal in zandsteen %d)" % [
				PlanetType.NAMES[planet], st.n, 100 * st.fam[0] / n, 100 * st.fam[1] / n, 100 * st.fam[2] / n, 100 * st.fam[3] / n,
				100 * st.fam[4] / n, st.heavy, st.fragile, st.glow, st.sets, st.titans, st.reach_sets, 100 * st.clustered / n, st.value, st.ore, st.glow_ore_sand])
	var rb: Dictionary = stats[0]
	var fw: Dictionary = stats[1]
	var km: Dictionary = stats[2]
	for i in 3:
		var st: Dictionary = stats[i]
		_expect(st.set_ok, "%s: elk skelet heeft 3-8 stukken met een schedel, allemaal botten, met set_size = aantal stukken" % PlanetType.NAMES[i])
		_expect(st.together, "%s: de stukken van een skelet liggen samen in één bed" % PlanetType.NAMES[i])
		_expect(st.clustered > st.n * 0.5, "%s: buit geconcentreerd (%d%% met 2+ buren binnen 7 m)" % [PlanetType.NAMES[i], 100 * st.clustered / st.n])
	# Golf 3 (ontwerp-8): ook op Roestbol en de Kristalmaan een paar stukken om samen te dragen (een
	# loonzak in de kampen, een reuzengeode in de kristalgrotten), maar veel minder dan op Fossielwereld.
	_expect(rb.heavy >= 1 and rb.heavy <= 10 and rb.sets >= 8 and rb.fam[3] > fw.fam[3] * 2 and rb.fam[3] > km.fam[3],
			"Roestbol: rommel (%d tegen %d/%d), kleine skeletten (%d), een paar zware stukken (%d)" % [rb.fam[3], fw.fam[3], km.fam[3], rb.sets, rb.heavy])
	_expect(km.heavy >= 1 and km.heavy < fw.heavy / 3, "Kristalmaan: een paar zware stukken om samen te dragen (%d)" % km.heavy)
	_expect(fw.titans >= 12 and fw.heavy >= 30 and fw.fam[0] > fw.n * 0.6,
			"Fossielwereld: grote skeletten (%d Titan, %d stukken te zwaar voor één, %d%% botten)" % [fw.titans, fw.heavy, 100 * fw.fam[0] / fw.n])
	_expect(fw.reach_sets >= 12, "Fossielwereld: de meeste skeletten bereikbaar met de boor T1 (%d)" % fw.reach_sets)
	_expect(km.fragile > km.n * 0.3 and km.glow >= 40 and km.fam[4] > rb.fam[4] * 3,
			"Kristalmaan: breekbare, lichtgevende kristallen (%d breekbaar, %d gloeien, %d tegen %d op Roestbol)" % [km.fragile, km.glow, km.fam[4], rb.fam[4]])
	_expect(km.glow_ore_sand > 0 and rb.glow_ore_sand == 0, "Kristalmaan: lichtkristal-erts in het zandsteen (%d)" % km.glow_ore_sand)
	_expect(rb.ore > fw.ore, "Roestbol heeft meer erts dan Fossielwereld (%d tegen %d)" % [rb.ore, fw.ore])
	# Drie verschillende mixen: de verdeling over de families verschilt duidelijk per paar planeten.
	for pair in [[0, 1], [0, 2], [1, 2]]:
		var a: Dictionary = stats[pair[0]]
		var b: Dictionary = stats[pair[1]]
		var l1 := 0.0
		for f in 5:
			l1 += absf(a.fam[f] / float(a.n) - b.fam[f] / float(b.n))
		_expect(l1 > 0.4, "%s en %s: andere buit (verschil %.2f)" % [PlanetType.NAMES[pair[0]], PlanetType.NAMES[pair[1]], l1])
	# Gevaren per planeet voor F2 (gas, worm): de Kristalmaan is het onrustigst.
	var g := [PlanetType.params(0), PlanetType.params(1), PlanetType.params(2)]
	_expect(g[2].gas_mult > g[0].gas_mult and g[2].worm_mult > g[1].worm_mult and g[2].worm_mult > g[0].worm_mult,
			"PlanetType.params: meer gas (%.1f) en een actievere worm (%.1f) op de Kristalmaan" % [g[2].gas_mult, g[2].worm_mult])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[find_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
