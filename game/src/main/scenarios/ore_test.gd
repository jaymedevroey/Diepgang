extends Node
## Test van erts (GDD v3 §4). Solo, headless.
## - Plaatsing: genoeg clusters, in de rots, soort volgt de laag, een korte ader bij de landing.
## - Delven: elke houweelslag = 1 eenheid in de ertszak; leeg = cluster weg. Boor: trager per tik.
## - Zak vol: geen erts meer, melding. Storten: enkel bij de trechter, dan in het laadruim.
## - De rots-shader krijgt de dichtstbijzijnde clusters (glinsteren).
## tools\godot.cmd --headless --path game -- --scenario=ore_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _full := 0


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(120.0).timeout.connect(func() -> void:
		print("[ore_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(p: Player) -> void:
	var t: TerrainAPI = main.terrain
	var ores: OreField = main.game.ores
	var mol: Mol = main.game.mol
	ores.bag_full.connect(func() -> void: _full += 1)
	await _wait(1.0)

	# 1. Plaatsing.
	_expect(ores.clusters.size() >= 200, "ertsclusters geplaatst (%d)" % ores.clusters.size())
	var in_rock := true
	var right_kind := true
	for c in ores.clusters:
		in_rock = in_rock and t.generated_rock_depth(c.global_position) >= 0.09
		right_kind = right_kind and c.kind == OreKinds.for_layer(t.layer_at(c.global_position), int(main.game.planet_type))
	_expect(in_rock, "alle clusters zitten in de rots")
	_expect(right_kind, "soort erts volgt de laag")
	var c0 := ores.clusters[0]
	_expect(c0.global_position.distance_to(t.spawn_point()) < 16.0 and c0.kind == OreKinds.Kind.KOPER,
			"korte ader koper bij de landing (%.1f m)" % c0.global_position.distance_to(t.spawn_point()))

	# 2. Blootleggen en delven met het houweel.
	var up := c0.global_basis.y
	var windowed := DisplayServer.get_name() != "headless"
	if windowed:
		# Glinsteren in de grond boven de ader, nog voor er gegraven is.
		p.set_physics_process(false)
		var above := c0.global_position
		above.y = t.surface_height_at(above.x, above.z) + 1.6
		p.global_position = above + Vector3(0, 0, 2.2)
		await _look(p, c0.global_position + Vector3(0, 1.0, 0))
		await _shot("erts_glinster")
	t.debug_dig(c0.global_position + up * 0.9, 1.3)
	p.set_physics_process(false)
	p.global_position = c0.global_position + up * 1.6
	await _wait(0.6)
	if windowed:
		p.global_position = c0.global_position + up * 1.2 + Vector3(0.6, 0, 0.6)
		await _look(p, c0.global_position + up * 0.25)
		await _shot("erts_bloot")
	var units := int(c0.max_hp)
	for i in units:
		ores.hit(c0.cluster_id, Strata.Tool.HOUWEEL, c0.global_position + up * 0.3)
		await _wait(0.35)
		if windowed and i == 2:
			await _shot("erts_delven")
	var bag := ores.bag_of(p.peer_id)
	_expect(bag[OreKinds.Kind.KOPER] == units, "%d houweelslagen = %d koper in de zak (%d)" % [units, units, bag[OreKinds.Kind.KOPER]])
	_expect(c0.depleted() and not c0.visible and c0.collision_layer == 0, "lege cluster is weg")
	ores.hit(c0.cluster_id, Strata.Tool.HOUWEEL, c0.global_position)
	await _wait(0.35)
	_expect(OreField.units(ores.bag_of(p.peer_id)) == units, "een lege cluster geeft niets meer")

	# 3. Boor: trager per tik, maar geen pauze.
	var c1 := ores.clusters[1]
	t.debug_dig(c1.global_position + c1.global_basis.y * 0.9, 1.3)
	p.global_position = c1.global_position + c1.global_basis.y * 1.6
	await _wait(0.6)
	for i in 6:
		ores.hit(c1.cluster_id, Strata.Tool.BOOR_T1, c1.global_position)
		await _wait(0.1)
	var drilled := OreField.units(ores.bag_of(p.peer_id)) - units
	_expect(drilled == 2, "6 boortikken = 2 eenheden (%d)" % drilled)

	# 4. Zak vol. Een verse cluster: met 2-3 eenheden per cluster (ontwerp-13) is c1 al bijna leeg.
	var c2 := ores.clusters[2]
	t.debug_dig(c2.global_position + c2.global_basis.y * 0.9, 1.3)
	p.global_position = c2.global_position + c2.global_basis.y * 1.6
	await _wait(0.6)
	Tuning.set_value("ore", "bag_capacity", float(OreField.units(ores.bag_of(p.peer_id)) + 1))
	for i in 6:
		ores.hit(c2.cluster_id, Strata.Tool.HOUWEEL, c2.global_position)
		await _wait(0.35)
	var have := OreField.units(ores.bag_of(p.peer_id))
	_expect(have == units + drilled + 1 and _full > 0, "zak vol: niet meer dan de capaciteit, met melding (%d, %d meldingen)" % [have, _full])
	Tuning.set_value("ore", "bag_capacity", 40.0)

	# 5. Storten: enkel bij de trechter.
	ores.deposit()
	await _wait(0.2)
	_expect(OreField.units(ores.bag_of(p.peer_id)) == have and OreField.units(ores.hold) == 0, "ver van de trechter: niet gestort")
	p.global_position = mol.chute_position() + mol.body.global_basis.x * 1.0
	await _wait(0.3)
	var value := OreField.value(ores.bag_of(p.peer_id))
	ores.deposit()
	await _wait(0.2)
	_expect(OreField.units(ores.bag_of(p.peer_id)) == 0 and OreField.units(ores.hold) == have,
			"gestort in de Mol: zak leeg, %d erts (€%d) in het laadruim" % [OreField.units(ores.hold), OreField.value(ores.hold)])
	_expect(OreField.value(ores.hold) == value, "waarde blijft gelijk na storten (€%d)" % value)
	p.set_physics_process(true)

	# 6. Glinsteren: de shader kent de clusters in de buurt.
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.global_position = ores.clusters[2].global_position + Vector3(0, 2, 0)
	cam.make_current()
	await _wait(0.6)
	var mat := t._terrain.material_override as ShaderMaterial
	_expect(int(mat.get_shader_parameter("ore_count")) > 0, "rots-shader krijgt %d clusters om te glinsteren" % int(mat.get_shader_parameter("ore_count")))

	print("[ore_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[ore_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Speler (en zijn camera) naar een punt laten kijken.
func _look(p: Player, at: Vector3) -> void:
	var d := at - p.camera.global_position
	p.rotation.y = atan2(-d.x, -d.z)
	await _wait(0.05)
	var local := p.global_basis.inverse() * (at - p.camera.global_position)
	p.head.rotation.x = atan2(local.y, Vector2(local.x, local.z).length())
	await _wait(0.5)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[ore_test] ", path)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[ore_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
