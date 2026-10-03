extends Node
## Test van magma en onrust (GDD §3, §6; onderzoek magma-en-onrust). Solo, headless.
## - Klok: 2 min stil, zonder bevingen na ±21 min aan het oppervlak; een beving zet de klok 40 s
##   vooruit als een golf.
## - Onrust: de boor en een PING maken lawaai, het houweel niet; na een stille periode zakt ze.
## - Beving: bij een volle trap aankondiging en hoofdschok, het magma maakt een sprong, rotsen
##   vallen in een zone in de buurt (en raken wie eronder staat), minstens min_gap_s ertussen.
## - Regels: losse buit in het magma is weg, een speler die erin zakt smelt (vervanger in de Mol),
##   de Mol krijgt alarmen, en bij recall_depth vertrekt hij vanzelf.
## tools\godot.cmd --headless --path game -- --scenario=magma_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _messages: Array[String] = []


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(150.0).timeout.connect(func() -> void:
		print("[magma_test] GEFAALD: time-out")
		for f in _failures:
			print("[magma_test] MISLUKT: ", f)
		get_tree().quit(1))


func _run(p: Player) -> void:
	var game: Game = main.game
	var magma: Magma = game.magma
	var unrest: Unrest = game.unrest
	var mol: Mol = game.mol
	var t: TerrainAPI = main.terrain
	mol.message.connect(func(text: String) -> void: _messages.append(text))
	await _wait(1.0)
	if CmdArgs.has("late"):
		await _late(p, game, magma, mol)
		return

	# 1. De curve.
	_expect(magma.running, "de klok loopt (zonder schip: vanaf het laden)")
	_expect(Magma.risen(110.0) == 0.0, "de eerste 2 min staat het magma stil")
	_expect(absf(Magma.depth_at(300.0) - (310.0 - 19.8)) < 0.1, "na 5 min 19,8 m gestegen (%.1f)" % (310.0 - Magma.depth_at(300.0)))
	var top := 0
	while Magma.depth_at(float(top)) > 0.0 and top < 4000:
		top += 1
	_expect(top > 1240 and top < 1290, "zonder bevingen na %d:%02d aan het oppervlak (±21 min)" % [top / 60, top % 60])
	_expect(Magma.risen(1200.0) - Magma.risen(1199.0) > Magma.risen(400.0) - Magma.risen(399.0), "het magma versnelt")

	# 2. Een beving zet de klok vooruit, als een golf.
	magma.elapsed = 500.0
	var before := magma.t_eff()
	magma.host_quake()
	_expect(absf(magma.t_eff() - before) < 0.01, "de golf begint op nul")
	magma.elapsed += 5.0
	_expect(absf(magma.t_eff() - magma.elapsed - 20.0) < 0.5, "halverwege de golf: 20 s voorsprong (%.1f)" % (magma.t_eff() - magma.elapsed))
	magma.elapsed += 10.0
	_expect(absf(magma.t_eff() - magma.elapsed - 40.0) < 0.01, "na de golf: 40 s voorsprong")
	magma.host_start()

	# 3. Lawaai.
	unrest.value = 0.0
	mol.noise_made.emit(5.0, mol.body.global_position)
	_expect(is_equal_approx(unrest.value, 5.0), "een PING telt 5 onrust")
	var v0 := unrest.value
	unrest.host_player_op(1, {"op": TerrainAPI.Op.CHIP, "tool": Strata.Tool.HOUWEEL})
	await _wait(0.3)
	_expect(absf(unrest.value - v0) < 0.001, "het houweel is stil")
	unrest.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1})
	await _wait(0.3)
	_expect(unrest.value - v0 > 0.04, "de boor maakt lawaai (+%.2f in 0,3 s)" % (unrest.value - v0))
	# Verval na een stille periode, nooit onder nul.
	Tuning.set_value("unrest", "quiet_s", 0.4)
	Tuning.set_value("unrest", "decay", 20.0)
	unrest.value = 8.0
	await _wait(1.2)
	_expect(unrest.value < 8.0 and unrest.value >= 0.0, "na een stille periode zakt de onrust (%.1f)" % unrest.value)
	Tuning.set_value("unrest", "quiet_s", 15.0)
	Tuning.set_value("unrest", "decay", 0.1)

	# 4. Een beving: een ruimte onder de grond met een zone aan het plafond, vlak bij de speler.
	var c := p.global_position + Vector3(0.0, -9.0, 0.0)
	t.debug_dig(c, 4.0)
	await _wait(1.0)
	unrest.zones = [Vector4(c.x, c.y + 1.5, c.z, 4.0)] as Array[Vector4]
	Tuning.set_value("unrest", "warning_s", 1.0)
	Tuning.set_value("unrest", "quake_s", 1.5)
	Tuning.set_value("unrest", "rock_spread_s", 0.5)
	Tuning.set_value("unrest", "dust_lead_s", 0.3)
	Tuning.set_value("unrest", "min_gap_s", 4.0)
	var quakes := magma.quakes.size()
	unrest.value = 100.0
	await _wait(0.1)
	_expect(unrest.phase == Unrest.Phase.WARNING, "een volle trap: de beving wordt aangekondigd")
	_expect(unrest.value < 1.0 and unrest.stage == 1, "de volgende trap begint (onrust %.1f, beving %d)" % [unrest.value, unrest.stage])
	_expect(unrest._plan.size() >= 3, "rotsen gepland in de zone (%d)" % unrest._plan.size())
	var in_zone := true
	for e: Array in unrest._plan:
		in_zone = in_zone and (e[0] as Vector3).distance_to(c) < 6.5
	_expect(in_zone, "elke rots komt uit de zone")
	await _wait(1.1)
	_expect(unrest.phase == Unrest.Phase.QUAKE, "dan de hoofdschok")
	_expect(magma.quakes.size() == quakes + 1, "het magma maakt een sprong")
	_expect(unrest.walk_factor() < 1.0, "tijdens de hoofdschok wandel je trager")
	await _wait(1.0)
	_expect(unrest._rocks.size() >= 3, "de rotsen vallen (%d)" % unrest._rocks.size())
	# Te snel weer vol: de volgende beving wacht op min_gap_s.
	unrest.value = 100.0
	await _wait(1.0)
	_expect(unrest.stage == 1, "geen tweede beving binnen min_gap_s")
	await _wait(3.0)
	_expect(unrest.stage == 2, "daarna wel")
	await _wait(3.0)
	# Een rots recht boven de speler: hij wankelt.
	p.velocity = Vector3.ZERO
	unrest._spawn_rock(p.global_position + Vector3(0.0, 4.0, 0.0), 1.0)
	var hit := false
	for i in 120:
		await get_tree().physics_frame
		if p._stun > 0.0:
			hit = true
			break
	_expect(hit, "een vallende rots raakt wie eronder staat")
	Tuning.set_value("unrest", "warning_s", 4.0)
	Tuning.set_value("unrest", "quake_s", 6.0)
	Tuning.set_value("unrest", "rock_spread_s", 5.0)
	Tuning.set_value("unrest", "dust_lead_s", 1.2)
	Tuning.set_value("unrest", "min_gap_s", 90.0)

	# 5. Losse buit (en vondsten nog in de rots) in het magma: weg.
	var victim: FindItem = null
	for it: FindItem in game.finds.items:
		if t.surface_height_at(it.global_position.x, it.global_position.z) - it.global_position.y > 40.0:
			victim = it
			break
	var gone := [false]
	var victim_id := victim.find_id if victim else -1
	magma.swallowed.connect(func(id: int) -> void:
		if id == victim_id:
			gone[0] = true)
	if victim:
		var surface_y := magma.level + magma.depth()
		magma.debug_depth = surface_y - victim.global_position.y - 1.0
		await _wait(2.2)
	_expect(gone[0] and game.finds.item(victim_id) == null, "een vondst onder het magma is na 1,5 s weg")

	await _late(p, game, magma, mol)


func _late(p: Player, game: Game, magma: Magma, mol: Mol) -> void:
	# 6. Een speler die erin zakt, smelt: een vervanger staat in de Mol.
	var melted := [0]
	magma.melted.connect(func(_id: int) -> void: melted[0] += 1)
	magma.debug_depth = 30.0
	await _wait(0.2)
	p.set_physics_process(false)
	p.global_position = Vector3(p.global_position.x, magma.level - 1.0, p.global_position.z)
	await _wait(0.6)
	p.set_physics_process(true)
	_expect(melted[0] == 1, "de speler smolt in het magma")
	_expect(mol.contains_point(p.global_position), "en staat als vervanger in de Mol")

	# 7. De Mol: alarm, en de noodophaling op recall_depth.
	_messages.clear()
	magma._reset_rules() # het smelten hierboven gaf al een alarm (magma 30 m onder de Mol)
	magma.debug_depth = 35.0
	await _wait(0.6)
	_expect(_messages.any(func(m: String) -> bool: return m.contains("MAGMA 40 M")), "alarm in de Mol: magma 40 m eronder")
	# Een spoor om terug te rijden (zonder schip kan de Mol enkel langs zijn eigen spoor naar boven).
	mol._path.assign([mol.body.global_position + Vector3(0.0, 0.0, -8.0), mol.body.global_position])
	magma.debug_depth = 55.0
	await _wait(0.6)
	_expect(mol.mode == Mol.Mode.COUNTDOWN, "noodophaling: de Mol vertrekt vanzelf")
	_expect(_messages.any(func(m: String) -> bool: return m.begins_with("Noodophaling")), "met een melding voor de ploeg")
	_finish()


func _finish() -> void:
	print("[magma_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[magma_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[magma_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
