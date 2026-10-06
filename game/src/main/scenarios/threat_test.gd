extends Node
## Test van de dreiging (pakket F2, GDD §6): de Graafworm, lichtbakens, gas, neergaan en redden,
## instortingen met de diepte, het magma als klok in de HUD en de climax. Solo, headless.
## - Worm: slaapt eerst; hoort een boor en zwemt erheen; valt enkel uit in een open ruimte (traag uit
##   de rots); slokt losse buit op en dumpt hem ver weg in een grot; een baken houdt hem tegen; hij
##   staat als grote stip op de sonar.
## - Grijpen (golf 3): wie hij raakt, grijpt hij en sleurt hij mee; spartelen, twee houweelslagen van
##   een ploegmaat (de host controleert de afstand) of een baken maken los; zonder hulp sleurt hij je
##   15-30 m weg en spuwt je uit. In een smalle gang breekt hij enkel door de wand na lang lawaai, en
##   wie lang boven hem staat, voelt hij (ontwerp2-2).
## - De Mol (golf 3): midden in de dienst hooguit een duw (de lading blijft heel, daarna laat hij de
##   Mol met rust), de kop stopt tegen de romp. In de climax jaagt hij op de Mol en bijt hij zich vast
##   (de lading lijdt zolang hij bijt, de Mol rijdt trager); een baken in de rijdende Mol telt niet,
##   de piloot schudt hem los, een baken uit de achterklep houdt hem af.
## - Gas: een boorhap in een open bel ontsteekt hem (het houweel niet, een net opengebroken bel ook
##   niet meteen); de ontploffing graaft een krater, raakt de speler en maakt lawaai.
## - Neergaan: een val doet pijn; solo neer → strompelen → in de Mol gerepareerd. Een ploegmaat neer →
##   dragen (traag) → in de Mol gerepareerd; te lang neer → kapot (spookdrone, telt als achtergebleven).
## - Instortingen: dieper meer zones, een grotere kans, en vanzelf een instorting bij een diepe zone
##   (niet bij een ondiepe); het puin houdt je tegen en je bikt het weg.
## tools\godot.cmd --headless --path game -- --scenario=threat_test --no-steam

const TAG := "[threat_test]"

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var game: Game
var t: TerrainAPI
var p: Player


func _ready() -> void:
	main.game.player_spawned.connect(func(pl: Player) -> void:
		if pl.is_local:
			_run.call_deferred(pl))
	get_tree().create_timer(480.0).timeout.connect(func() -> void:
		print(TAG, " GEFAALD: time-out")
		for f in _failures:
			print(TAG, " MISLUKT: ", f)
		get_tree().quit(1))


func _run(pl: Player) -> void:
	p = pl
	game = main.game
	t = main.terrain
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.0)
	var worm: Worm = game.worm
	var rescue: Rescue = game.rescue
	var magma: Magma = game.magma

	# 0. Een grot onder de grond om in te werken (30 m diep, 40 m van de landingsplek).
	var sc := t.shaft_center_world()
	var cave := Vector3(sc.x, t.surface_height_at(sc.x, sc.z - 40.0) - 30.0, sc.z - 40.0)
	p.set_physics_process(false)
	p.global_position = cave + Vector3.UP * 2.0
	await _until(func() -> bool: return t.is_area_ready(cave, 10.0), 20.0)
	t.debug_dig(cave, 6.0)
	await _wait(1.2)
	var floor_hit := t.raycast(cave, cave + Vector3.DOWN * 10.0)
	var ground: Vector3 = floor_hit.position if not floor_hit.is_empty() else cave + Vector3.DOWN * 5.8
	_expect(not floor_hit.is_empty(), "testgrot gegraven (vloer op %.1f m onder het midden)" % (cave.y - ground.y))
	p.global_position = ground + Vector3(2.5, 0.1, 0.0)
	p.reset_physics_interpolation()
	p.set_physics_process(true)
	await _wait(0.5)

	# 1. Het magma als klok: onder de grond altijd in de HUD, met wanneer het hier is (ontwerp-1).
	main.hud.update(p, game, t)
	var hz: HudHazard = main.hud.hazard
	_expect(hz.always_magma and hz.magma_m > 200.0 and hz._magma_shown(), "het magma staat in de HUD, ook op %d m (ontwerp-1)" % int(hz.magma_m))
	_expect(hz.magma_eta > 60.0 and hz.magma_eta < 3600.0, "met de tijd tot het hier is (%d s)" % int(hz.magma_eta))

	# 2. De worm slaapt de eerste minuten, dan wordt hij wakker.
	_expect(worm.mode == Worm.Mode.SLEEP, "de worm slaapt bij de start")
	magma.elapsed = game.worm.wake_after() + 1.0
	await _wait(0.3)
	_expect(worm.mode != Worm.Mode.SLEEP, "na wake_s wordt hij wakker (%s)" % Worm.Mode.keys()[worm.mode])

	# 3. Lawaai lokt hem: een boor in de grot, de worm 45 m verderop zwemt erheen.
	worm.pos = cave + Vector3(45.0, -8.0, 0.0)
	worm.vel = Vector3.ZERO
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm._cool = 999.0 # nog niet uitvallen
	var start_d := worm.pos.distance_to(cave)
	for i in 16:
		worm.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": ground + Vector3(0, 0.5, 0)})
		await _wait(0.12)
	await _wait(3.0)
	_expect(worm.mode == Worm.Mode.HUNT, "de boor lokt hem: hij jaagt (%s)" % Worm.Mode.keys()[worm.mode])
	_expect(worm.pos.distance_to(cave) < start_d - 8.0, "hij zwemt naar het lawaai (%.0f → %.0f m)" % [start_d, worm.pos.distance_to(cave)])
	# Het houweel is stil.
	worm._noises.clear()
	worm.host_player_op(1, {"op": TerrainAPI.Op.CHIP, "tool": Strata.Tool.HOUWEEL, "h": ground})
	_expect(worm._noises.is_empty(), "het houweel lokt hem niet")

	# 4. Op de sonar van de Mol: een grote stip (ook als hij verder is dan een PING reikt).
	var mol: Mol = game.mol
	worm.pos = mol.body.global_position + Vector3(30.0, -10.0, 0.0)
	await _wait(0.2)
	var echo := worm.sonar_echo(mol.body.global_position, 0.0, false)
	_expect(echo.get("on", false) and float(echo.strength) > 0.1, "de worm staat op de sonar (%.0f m)" % float(echo.get("dist", -1.0)))
	worm.pos = mol.body.global_position + Vector3(90.0, -10.0, 0.0)
	_expect(not worm.sonar_echo(mol.body.global_position, 0.0, false).get("on", false), "buiten sonar_m niet")

	# 5. Uitvallen enkel in een open ruimte.
	worm.pos = ground + Vector3(-12.0, -6.0, 0.0)
	worm._cool = 0.0
	var solid := ground + Vector3(0.0, -12.0, 0.0)
	_expect(not worm._try_lunge(solid), "niet in de rots (geen open ruimte)")
	# Losse buit in de grot (de speler opzij van de boog): hij valt uit en slokt de buit op.
	var it: FindItem = _a_find()
	game.finds._free(it.find_id)
	await _wait(0.6)
	it.global_position = ground + Vector3(0.0, 0.4, 0.0)
	it.linear_velocity = Vector3.ZERO
	it.reset_physics_interpolation()
	p.global_position = ground + Vector3(1.5, 0.1, -3.4)
	await _wait(0.4)
	var started := [false]
	var ate := [-1]
	worm.lunge_started.connect(func(_a: Vector3) -> void: started[0] = true, CONNECT_ONE_SHOT)
	worm.swallowed.connect(func(id: int) -> void: ate[0] = id, CONNECT_ONE_SHOT)
	var aim := ground + Vector3(0.0, 0.3, 0.0)
	_expect(worm._try_lunge(aim), "in de grot valt hij uit")
	_expect(started[0] and worm.mode == Worm.Mode.LUNGE, "eerst de waarschuwing, dan de boog (op elk peer)")
	# De waarschuwing duurt langer en de kop komt traag uit de rots (binnen2-02: niet in twee beelden).
	_expect(Tuning.get_f("worm", "telegraph_s", 0.0) >= 1.5 and Worm.lunge_param(0.2) < 0.12,
			"een waarschuwing van %.1f s, en het eerste vijfde van de boog legt maar %d%% af" % [Tuning.get_f("worm", "telegraph_s", 0.0), int(Worm.lunge_param(0.2) * 100)])
	await _until(func() -> bool: return worm.mode != Worm.Mode.LUNGE, Tuning.get_f("worm", "telegraph_s", 1.6) + Tuning.get_f("worm", "burst_s", 1.9) + 2.0)
	_expect(ate[0] == it.find_id and not it.visible and it.carriers.has(Worm.BELLY), "losse buit is opgeslokt")
	_expect(worm.mode == Worm.Mode.CARRY, "hij sleept de buit weg (%s)" % Worm.Mode.keys()[worm.mode])
	# Dumpen in een grot, ver weg.
	var spat := [false]
	worm.spat.connect(func(_ids: PackedInt32Array) -> void: spat[0] = true, CONNECT_ONE_SHOT)
	worm.pos = worm._lair
	await _wait(0.5)
	_expect(spat[0] and it.visible and it.carriers.is_empty(), "de buit ligt weer ergens (gedumpt)")
	_expect(it.global_position.distance_to(aim) > Tuning.get_f("worm", "lair_min_m", 50.0) * 0.7, "ver weg: %.0f m" % it.global_position.distance_to(aim))

	# 5b. Grijpen (golf 3, playtest "een worm die je opslokt"): wie hij raakt, grijpt hij en sleurt hij
	# mee; zelf spartelen (Spatie) maakt je los.
	var grabbed := [-1]
	var why := [""]
	worm.grabbed.connect(func(peer: int) -> void: grabbed[0] = peer)
	worm.released.connect(func(_peer: int, r: String) -> void: why[0] = r)
	await _grab_me(ground, grabbed)
	_expect(grabbed[0] == p.peer_id and rescue.is_held(p.peer_id) and worm.holds(p.peer_id) and worm.mode == Worm.Mode.GRAB,
			"wie hij raakt, grijpt hij (%s)" % Worm.Mode.keys()[worm.mode])
	_expect(p.ragdoll != null and rescue.life_of(p.peer_id) == Rescue.Life.KNOCKED, "als ragdoll in zijn muil")
	var at_grab := p.global_position
	var hb := rescue.health_of(p.peer_id)
	await _wait(1.2)
	var head := worm.head_world()
	_expect(head != Vector3.INF and p.ragdoll != null and p.ragdoll.torso.global_position.distance_to(head) < 2.0,
			"de romp hangt in de muil (%.1f m van de kop)" % (p.ragdoll.torso.global_position.distance_to(head) if p.ragdoll and head != Vector3.INF else -1.0))
	_expect(p.global_position.distance_to(at_grab) > 1.5 or float(worm._grab.len) < 2.0,
			"hij sleurt hem mee (%.1f m in 1,2 s; pad %.0f m)" % [p.global_position.distance_to(at_grab), float(worm._grab.get("len", 0.0))])
	_expect(rescue.health_of(p.peer_id) < hb and rescue.timer_of(p.peer_id) > 1.0, "zolang hij vasthoudt, kost het levens, en de klok van omver staat stil")
	# Het houweel raakt de kop echt: een straal op de lagen van het gereedschap vindt zijn doelwit.
	head = worm.head_world()
	var probe := t.tool_raycast(head + Vector3(0.0, 2.6, 0.0), head)
	_expect(not probe.is_empty() and (probe.collider as Node).has_meta("worm"), "het houweel kan de kop raken (laag CRUST)")
	for i in 14:
		if not rescue.is_held(p.peer_id):
			break
		rescue.request_flail()
		await _wait(0.15)
	_expect(why[0] == "struggle" and not rescue.is_held(p.peer_id) and worm.mode != Worm.Mode.GRAB, "spartelen (Spatie) maakt je los (%s)" % why[0])
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.OK and p.ragdoll == null, "na knock_s staat de robot weer op")

	# 5c. Een ploegmaat slaat hem los: twee slagen op de kop. De host controleert de afstand.
	game._spawn(2, 1, cave + Vector3(0.0, -4.0, 0.0))
	var buddy := game.player_node(2)
	await _wait(0.3)
	buddy.global_position = ground + Vector3(-2.0, 0.1, 2.5)
	_reset_player()
	await _wait(0.3)
	why[0] = ""
	grabbed[0] = -1
	await _grab_me(ground, grabbed)
	_expect(worm.holds(p.peer_id), "weer gegrepen")
	buddy.global_position = worm.head_world() + Vector3(0.0, -0.6, 14.0)
	worm.host_hit(2, worm.head_world())
	_expect(int(worm._grab.get("hp", 0)) == Tuning.get_i("worm", "grab_hits", 2), "een slag van 14 m ver telt niet (de host controleert de afstand)")
	for i in 2:
		buddy.global_position = worm.head_world() + Vector3(0.0, -0.6, 1.8)
		worm._hit_ms.clear()
		worm.host_hit(2, worm.head_world())
	_expect(why[0] == "hit" and not rescue.is_held(p.peer_id) and worm.mode == Worm.Mode.REPELLED, "twee slagen met het houweel: hij laat los en zwemt weg (%s)" % why[0])
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)

	# 5d. Een baken bij hem: hij laat los.
	why[0] = ""
	buddy.global_position = ground + Vector3(-3.0, 0.1, 3.8) # niet onder de boog
	await _grab_me(ground, grabbed)
	_expect(worm.holds(p.peer_id), "weer gegrepen")
	buddy.global_position = worm.head_world() + Vector3(0.0, -0.6, 3.0)
	await _wait(0.1)
	var bl := game.beacons.left
	game.beacons._host_throw(2, buddy.global_position + Vector3.UP * 1.0, Vector3.ZERO)
	await _until(func() -> bool: return why[0] != "", 1.5)
	_expect(game.beacons.left == bl - 1 and why[0] == "beacon" and not rescue.is_held(p.peer_id), "een baken bij hem: hij laat los (%s)" % why[0])
	game._despawn(2)
	rescue.host_peer_left(2)
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)
	_clear_beacons()

	# 5e. Een smalle, zelfgegraven gang: daar valt hij niet uit; enkel als het er lang luid was (de
	# boor), breekt hij door de wand (ontwerp2-2).
	var gang := cave + Vector3(0.0, -2.0, -12.0)
	for i in 7:
		t.debug_dig(gang + Vector3(0.0, 0.0, i * 0.6), 0.85)
	await _wait(1.2)
	var gfloor := t.raycast(gang, gang + Vector3.DOWN * 3.0)
	var gg: Vector3 = (gfloor.position as Vector3) if not gfloor.is_empty() else gang + Vector3.DOWN * 0.8
	_reset_player()
	p.global_position = gg + Vector3(0.0, 0.1, 1.8)
	await _wait(0.3)
	worm.mode = Worm.Mode.HUNT
	worm.pos = gg + Vector3(8.0, -5.0, 0.0)
	worm._cool = 0.0
	_expect(not worm._try_lunge(p.global_position), "in een smalle gang valt hij niet uit")
	_expect(not worm._try_breach(p.global_position, 1.0), "stil (houweel): hij breekt niet door de wand")
	_expect(worm._try_breach(p.global_position, 4.0) and worm.mode == Worm.Mode.LUNGE, "lang luid (de boor): hij breekt door de wand")
	_expect(float(worm._lunge.tel) >= Tuning.get_f("worm", "telegraph_s", 1.6), "met een langere waarschuwing (%.1f s)" % float(worm._lunge.tel))
	var touched := [false]
	var hit_once := func(_peer: int, _a: float, src: String) -> void:
		if src == "worm":
			touched[0] = true
	rescue.damaged.connect(hit_once)
	var g0 := _gt()
	while _gt() - g0 < 4.0 and not touched[0]:
		await get_tree().physics_frame
		if rescue.is_ok(p.peer_id):
			p.global_position = gg + Vector3(0.0, 0.1, 1.8)
	rescue.damaged.disconnect(hit_once)
	_expect(touched[0], "de doorbraak raakt wie in de gang staat")
	if worm.holds(p.peer_id):
		worm._end_grab("struggle")
	await _until(func() -> bool: return worm.mode != Worm.Mode.LUNGE and rescue.life_of(p.peer_id) == Rescue.Life.OK, 6.0)

	# 5f. Wie lang boven hem stilstaat, voelt hij (ontwerp2-2): hij sluipt onder je en valt dan aan.
	_reset_player()
	p.global_position = ground + Vector3(0.5, 0.1, 0.5)
	await _wait(0.3)
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm._sensed.clear()
	worm._prowl_peer = p.peer_id
	worm._wander_t = 30.0
	worm.pos = ground + Vector3(0.0, -7.0, 0.0)
	worm.vel = Vector3.ZERO
	await _until(func() -> bool: return worm.mode == Worm.Mode.HUNT, Tuning.get_f("worm", "sense_s", 5.0) + 3.0)
	_expect(worm.mode == Worm.Mode.HUNT and worm._target.distance_to(p.global_position) < 6.0, "wie boven hem blijft staan, voelt hij: hij komt (%s)" % Worm.Mode.keys()[worm.mode])
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm._grab_cool = 0.0

	# 5g. Niemand helpt: hij sleurt je 15-30 m weg van de ploeg en de Mol, bijt nog eens en spuwt je uit.
	var open := mol.body.global_position + mol.body.global_basis.x * 30.0
	open.y = t.surface_height_at(open.x, open.z)
	await _until(func() -> bool: return t.is_area_ready(open, 12.0), 10.0)
	why[0] = ""
	await _grab_me(open + Vector3(-0.6, 0.0, -0.6), grabbed)
	_expect(worm.holds(p.peer_id), "aan de oppervlakte gegrepen")
	var start := p.global_position
	var hs := rescue.health_of(p.peer_id)
	var drag_t := Tuning.get_f("worm", "grab_drag_m", 20.0) / Tuning.get_f("worm", "grab_speed", 2.6) + Tuning.get_f("worm", "grab_chew_s", 1.2) + 4.0
	await _until(func() -> bool: return why[0] != "", drag_t)
	var far := start.distance_to(p.global_position)
	_expect(why[0] == "done" and far >= 12.0 and far <= 32.0, "zonder hulp sleurt hij hem %.0f m weg en spuwt hem uit (%s)" % [far, why[0]])
	_expect(p.global_position.distance_to(mol.body.global_position) > start.distance_to(mol.body.global_position), "weg van de Mol")
	_expect(rescue.health_of(p.peer_id) < hs - 0.5 or rescue.life_of(p.peer_id) == Rescue.Life.DOWNED,
			"het kost veel levens (%d%% → %d%%)" % [int(hs * 100), int(rescue.health_of(p.peer_id) * 100)])
	await _wait(0.5)
	_reset_player()
	p.set_physics_process(false)
	p.global_position = ground + Vector3(2.5, 0.1, 0.0)
	p.reset_physics_interpolation()
	p.set_physics_process(true)
	await _wait(0.5)
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()

	# 6. Een lichtbaken houdt hem tegen.
	var left := game.beacons.left
	p.global_position = ground + Vector3(2.0, 0.1, 0.0)
	game.beacons._host_throw(1, ground + Vector3(1.0, 1.0, 0.0), Vector3.ZERO)
	await _wait(0.6)
	_expect(game.beacons.left == left - 1 and game.beacons.count_active() >= 1, "een baken gegooid (%d over)" % game.beacons.left)
	worm.mode = Worm.Mode.HUNT
	worm._cool = 0.0
	_expect(not worm._try_lunge(aim) and worm.mode == Worm.Mode.REPELLED, "bij een baken valt hij niet uit: hij zwemt weg")

	# 7. Gas: een bel in een tweede grot.
	var cave2 := cave + Vector3(0.0, 0.0, 22.0)
	t.debug_dig(cave2, 4.5)
	await _wait(1.0)
	var gas: Gas = game.gas
	var pk := Gas.Pocket.new()
	pk.id = gas.pockets.size()
	pk.center = cave2 + Vector3(0.0, -2.5, 0.0)
	pk.radius = 3.0
	gas.pockets.append(pk)
	gas._refresh_open(pk)
	pk.opened_at = -100.0
	_expect(pk.open, "de bel ligt open (een gele waas)")
	gas.host_player_op(1, {"op": TerrainAPI.Op.CHIP, "tool": Strata.Tool.HOUWEEL, "h": cave2})
	_expect(not pk.igniting, "het houweel ontsteekt niets")
	var boom := [false]
	gas.exploded.connect(func(_id: int, _at: Vector3) -> void: boom[0] = true, CONNECT_ONE_SHOT)
	var u0 := game.unrest.value
	var fresh := pk.center + Vector3(2.5, 0.0, 0.0)
	var below := t.raycast(pk.center, pk.center + Vector3.DOWN * 5.0)
	var rock_pt: Vector3 = (below.position as Vector3) + Vector3.DOWN * 0.8 if not below.is_empty() else pk.center + Vector3.DOWN * 3.0
	var sdf0 := t.sdf_at(rock_pt)
	p.global_position = pk.center + Vector3(0.0, -1.0, 2.0)
	var h_before := rescue.health_of(p.peer_id)
	gas.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": fresh})
	_expect(pk.igniting, "een boorhap in de waas ontsteekt hem")
	await _wait(Tuning.get_f("gas", "fuse_s", 0.6) + 0.6)
	_expect(boom[0] and pk.gone, "na fuse_s ontploft hij")
	_expect(t.sdf_at(rock_pt) > sdf0 + 0.3, "een krater in de vloer: de rots kan enkel weg (sdf %.1f → %.1f)" % [sdf0, t.sdf_at(rock_pt)])
	_expect(rescue.health_of(p.peer_id) < h_before or rescue.life_of(p.peer_id) != Rescue.Life.OK, "de speler is geraakt")
	_expect(game.unrest.value > u0 + 10.0, "een ontploffing is luid (onrust +%.0f)" % (game.unrest.value - u0))
	await _until(func() -> bool: return rescue.life_of(p.peer_id) in [Rescue.Life.OK, Rescue.Life.LIMPING], 8.0)
	# Een net opengebroken bel sist eerst (breach_grace_s).
	var pk2 := Gas.Pocket.new()
	pk2.id = gas.pockets.size()
	pk2.center = cave
	pk2.radius = 2.5
	gas.pockets.append(pk2)
	gas._refresh_open(pk2)
	gas.host_player_op(1, {"op": TerrainAPI.Op.SPHERE_REMOVE, "tool": Strata.Tool.BOOR_T1, "h": cave})
	_expect(pk2.open and not pk2.igniting, "net opengebroken: de boor ontsteekt hem nog niet")
	pk2.gone = true

	# 8. Neergaan solo: neer, dan zelf strompelen, en in de Mol gerepareerd.
	_reset_player()
	await _wait(0.3)
	rescue.host_damage(p.peer_id, 2.0, Vector3(2.0, 0.0, 0.0), true, "test")
	await _wait(0.2)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.DOWNED and p.ragdoll != null, "geen levens meer: neer, als ragdoll")
	_expect(p.ragdoll != null and p.global_position.distance_to(p.ragdoll.torso.global_position) < 0.1, "de speler staat op de plek van zijn romp")
	await _wait(Tuning.get_f("rescue", "limp_delay_s", 2.5) + 0.6)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.LIMPING and p.ragdoll == null, "solo: na even liggen strompel je zelf verder")
	_expect(not p.active_tool.visible, "strompelend: geen gereedschap")
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.0))
	await _wait(Tuning.get_f("rescue", "repair_s", 4.0) + 0.6)
	p.set_physics_process(true)
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.OK and absf(rescue.health_of(p.peer_id) - Tuning.get_f("rescue", "repair_health", 0.5)) < 0.15,
			"in de Mol gerepareerd (%d%%)" % int(rescue.health_of(p.peer_id) * 100))

	# 9. Een ploegmaat neer: dragen naar de Mol (een tweede robot, zonder eigen peer).
	_reset_player()
	game._spawn(2, 1, cave + Vector3(0.0, -4.0, 0.0))
	var mate := game.player_node(2)
	await _wait(0.3)
	mate.global_position = ground + Vector3(-1.5, 0.1, 0.0)
	await _wait(0.2)
	rescue.host_damage(2, 2.0, Vector3.ZERO, true, "test")
	await _wait(0.8)
	_expect(rescue.life_of(2) == Rescue.Life.DOWNED and rescue.ragdoll_of(2) != null, "ploegmaat neer: een ragdoll")
	await _wait(Tuning.get_f("rescue", "limp_delay_s", 2.5) + 0.5)
	_expect(rescue.life_of(2) == Rescue.Life.DOWNED, "met een gave ploegmaat strompelt hij niet: hij wacht op hulp")
	p.global_position = rescue.ragdoll_of(2).torso.global_position + Vector3(1.0, 0.2, 0.0)
	await _wait(0.2)
	rescue.request_carry(2)
	await _wait(0.2)
	_expect(rescue.carriers_of(2) == PackedInt32Array([1]) and p.carry.body_peer == 2, "de speler draagt zijn ploegmaat")
	_expect(p.carry.move_multiplier() < 0.5, "alleen dragen gaat traag (×%.2f)" % p.carry.move_multiplier())
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 1.6))
	p.rotation.y = mol.yaw
	var repaired := await _until(func() -> bool: return rescue.life_of(2) == Rescue.Life.OK, Tuning.get_f("rescue", "repair_s", 4.0) + 3.0)
	p.set_physics_process(true)
	_expect(repaired and rescue.ragdoll_of(2) == null, "in de Mol gerepareerd")
	_expect(p.carry.body_peer == -1 and mol.contains_point(mate.global_position), "losgelaten, en hij staat in de Mol")
	# Te lang neer: kapot, een spookdrone, telt als achtergebleven.
	mate.global_position = ground + Vector3(-1.5, 0.1, 0.0)
	await _wait(0.2)
	rescue.host_damage(2, 2.0, Vector3.ZERO, true, "test")
	await _wait(0.3)
	rescue.info(2).timer = 0.05
	await _wait(0.3)
	_expect(rescue.life_of(2) == Rescue.Life.BROKEN and mate._drone != null and mate.rig != null and not mate.rig.visible,
			"te lang neer: kapot, een spookdrone")
	_expect(rescue.left_behind_override(2) == 1, "een kapotte robot telt als achtergebleven")
	game._despawn(2)
	rescue.host_peer_left(2)
	await _wait(0.2)

	# 10. Vallen doet pijn (in de grot, niet uit De Ekster).
	_reset_player()
	p.global_position = ground + Vector3(2.0, 11.0, 0.0)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	var h0 := rescue.health_of(p.peer_id)
	await _until(func() -> bool: return rescue.health_of(p.peer_id) < h0 - 0.01, 4.0)
	_expect(rescue.health_of(p.peer_id) < h0, "een val van 11 m kost levens (%d%% → %d%%)" % [int(h0 * 100), int(rescue.health_of(p.peer_id) * 100)])
	await _until(func() -> bool: return rescue.life_of(p.peer_id) == Rescue.Life.OK, 4.0)

	# 11. Instortingen: dieper meer zones en een grotere kans.
	var shallow := 0
	var deep := 0
	for z: Vector4 in game.unrest.zones:
		var d := t.surface_height_at(z.x, z.z) - z.y
		if d >= 10.0 and d < 60.0:
			shallow += 1
		elif d >= 110.0 and d < 160.0:
			deep += 1
	_expect(deep > shallow, "dieper liggen meer onstabiele zones (%d op 110-160 m, %d op 10-60 m)" % [deep, shallow])
	_expect(Collapse.rate_at(30.0) < Collapse.rate_at(90.0) and Collapse.rate_at(90.0) < Collapse.rate_at(180.0),
			"de kans groeit met de diepte (%.3f / %.3f / %.3f per min)" % [Collapse.rate_at(30.0), Collapse.rate_at(90.0), Collapse.rate_at(180.0)])
	_expect(Collapse.rate_at(10.0) == 0.0, "aan de oppervlakte stort niets in")
	_expect(Collapse.rate_at(90.0, 1.0) > Collapse.rate_at(90.0, 0.0), "onrust maakt het erger")
	# Vanzelf: een diepe zone vlakbij stort in, een ondiepe niet.
	var col: Collapse = game.collapse
	game.unrest.zones = [Vector4(cave.x, cave.y + 5.0, cave.z, 4.0)] as Array[Vector4]
	Tuning.set_value("collapse", "quiet_s", 0.0)
	Tuning.set_value("collapse", "check_s", 0.2)
	Tuning.set_value("collapse", "rate_per_100m", 3000.0)
	Tuning.set_value("collapse", "max_rate", 1000.0)
	var n0 := col.count()
	await _until(func() -> bool: return col.count() > n0, 6.0)
	_expect(col.count() > n0, "een diepe zone stort vanzelf in (na een waarschuwing)")
	var surf_zone := Vector4(cave.x, t.surface_height_at(cave.x, cave.z) - 6.0, cave.z, 4.0)
	game.unrest.zones = [surf_zone] as Array[Vector4]
	var n1 := col.count()
	await _wait(2.0)
	_expect(col.count() == n1, "een ondiepe zone (6 m) niet")
	Tuning.set_value("collapse", "quiet_s", 90.0)
	Tuning.set_value("collapse", "check_s", 4.0)
	Tuning.set_value("collapse", "rate_per_100m", 0.035)
	Tuning.set_value("collapse", "max_rate", 0.12)
	# Puin: blijft liggen, houdt je tegen, en je bikt het weg.
	game.unrest.zones = [] as Array[Vector4]
	await _wait(Tuning.get_f("collapse", "warn_s", 1.6) + Tuning.get_f("collapse", "spread_s", 2.0) + 2.0)
	var rubble: Rubble = null
	for r: RigidBody3D in game.unrest._rocks:
		if r is Rubble and (r as Rubble).blocks and is_instance_valid(r):
			rubble = r
			break
	if rubble == null:
		game.unrest.spawn_rock(game.unrest.host_rock_entry(ground + Vector3(-2.0, 3.0, 0.0), 1.0, 0.0))
		await _wait(2.0)
		rubble = game.unrest.rock(game.unrest._next_rock - 1)
	_expect(rubble != null and rubble.collision_layer & Layers.RUBBLE and p.collision_mask & Layers.RUBBLE, "grote rotsen blijven liggen als puin dat je tegenhoudt")
	if rubble:
		var id := rubble.rock_id
		var hits := 0
		while game.unrest.rock(id) != null and hits < 20:
			p.global_position = rubble.global_position + Vector3(1.2, 0.0, 0.0)
			game.unrest.request_chip(id, false, rubble.global_position)
			hits += 1
			await _wait(0.2)
		_expect(game.unrest.rock(id) == null, "weggebikt in %d slagen" % hits)

	# 12. De Mol midden in de dienst: hooguit een duw, de lading blijft heel (ontwerp2-1).
	_reset_player()
	await _until(func() -> bool: return rescue.is_ok(p.peer_id), 4.0)
	var cargo: FindItem = _a_find()
	game.finds._free(cargo.find_id)
	await _wait(0.5)
	cargo.global_position = mol.to_world_mol(Vector3(0.6, -1.2, 2.6))
	cargo.linear_velocity = Vector3.ZERO
	cargo.reset_physics_interpolation()
	p.set_physics_process(false)
	p.global_position = mol.to_world_mol(Vector3(0.0, -1.45, 0.5))
	p.set_physics_process(true)
	await _wait(0.6)
	_expect(mol.cargo_contents().has(cargo), "een vondst in het laadruim")
	var cond0 := cargo.condition
	var mol_hits := [0]
	worm.rammed.connect(func(_a: Vector3) -> void: mol_hits[0] += 1)
	worm.mode = Worm.Mode.HUNT
	worm.pos = mol.body.global_position + Vector3(0.0, -7.0, 6.0)
	worm._target = mol.body.global_position
	worm._shove_cool = 0.0
	worm._ram_cool = 0.0
	worm._strike(worm._clock)
	await _wait(0.3)
	_expect(mol_hits[0] == 1 and is_equal_approx(cargo.condition, cond0), "midden in de dienst: een duw, de lading blijft heel (%d%%)" % int(cargo.condition * 100))
	_expect(rescue.life_of(p.peer_id) == Rescue.Life.KNOCKED, "wie in de Mol staat, gaat omver")
	_expect(worm._shove_cool > 30.0 and worm._mol_deaf_t > 20.0, "daarna laat hij de Mol een tijd met rust (%.0f s)" % worm._mol_deaf_t)
	worm.mode = Worm.Mode.HUNT
	worm._target = mol.body.global_position
	worm._strike(worm._clock)
	await _wait(0.2)
	_expect(mol_hits[0] == 1, "geen tweede duw meteen erna")
	worm._noises.clear()
	mol.speed = 1.8
	worm._mol_noise_t = 0.6
	worm._feed_mol(0.0)
	mol.speed = 0.0
	_expect(worm._noises.is_empty(), "na een duw voedt de rijdende Mol zijn geheugen niet")
	# De kop stopt tegen de romp, niet erdoor (binnen2-01).
	for side: Vector3 in [Vector3(9, -4, 0), Vector3(-9, -5, 2), Vector3(1, -6, 9), Vector3(0, -6, -9)]:
		worm.pos = mol.body.global_position + side
		var c: Dictionary = worm._hull_contact(mol)
		var hpos: Vector3 = (c.position as Vector3) + (c.normal as Vector3) * 0.9
		var to_c: Dictionary = t.raycast(hpos, mol.body.global_position, Layers.LIFT)
		_expect(not mol.contains_point(hpos) and not to_c.is_empty() and hpos.distance_to(to_c.position) > 0.6,
				"de kop stopt tegen de romp, niet erin (%s: %.1f m van de romp)" % [side, hpos.distance_to(to_c.position) if not to_c.is_empty() else -1.0])
	await _until(func() -> bool: return rescue.is_ok(p.peer_id), 4.0)

	# 13. De climax (ontwerp-7, ontwerp2-3): de hendel, de worm jaagt op de Mol en bijt zich vast; de
	# lading lijdt zolang hij bijt, de Mol rijdt trager. Een baken in de rijdende Mol telt niet; de
	# piloot schudt hem los; een baken uit de achterklep houdt hem af.
	_expect(worm.tension() < 0.2, "spanning bij het begin laag (%.2f)" % worm.tension())
	magma.debug_depth = 80.0
	await _wait(0.2)
	_expect(worm.tension() > 0.8, "het magma dichtbij: spanning hoog (%.2f)" % worm.tension())
	magma.debug_depth = -1.0
	worm.mode = Worm.Mode.ROAM
	worm._noises.clear()
	worm.pos = mol.body.global_position + Vector3(0.0, -10.0, 25.0)
	# Een spoor van 80 m terug over de grond.
	var home := mol.body.global_position
	var back := mol.body.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var path: Array[Vector3] = []
	for i in 9:
		var q := home + back * (80.0 * (1.0 - i / 8.0))
		q.y = t.surface_height_at(q.x, q.z) - Mol.TRACK_BOTTOM
		path.append(q)
	path[8] = home
	mol._path.assign(path)
	Tuning.set_value("mol", "countdown_s", 2.0)
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0.0, -1.45, -1.0)))
	await _wait(0.3)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.3)
	_expect(p.seated, "de piloot zit")
	mol.press(Mol.Cmd.DEPART)
	await _wait(0.4)
	_expect(mol.mode == Mol.Mode.COUNTDOWN and worm.tension() == 1.0, "de hendel: de climax (spanning 1)")
	await _wait(0.4)
	_expect(worm.mode == Worm.Mode.HUNT and worm._target.distance_to(mol.body.global_position) < 6.0, "de worm jaagt op de Mol zelf")
	worm.mode = Worm.Mode.REPELLED # even weg, voor de rest van de test
	worm._repel_t = 30.0
	game.beacons._rpc_spawn(77, mol.to_world_mol(Vector3(0.0, -1.0, 2.0)), Vector3.ZERO)
	await _until(func() -> bool: return mol.mode == Mol.Mode.EXTRACTING, 4.0)
	await _wait(1.0)
	var bn := game.beacons.nearest(mol.body.global_position)
	_expect(mol.mode == Mol.Mode.EXTRACTING and (bn == Vector3.INF or bn.distance_to(mol.body.global_position) > 14.0),
			"een baken in de rijdende Mol telt niet (het rijdt mee, de motor overstemt het)")
	var cond1 := cargo.condition
	var bite_end := [""]
	worm.bite_ended.connect(func(r: String) -> void: bite_end[0] = r)
	worm.pos = mol.body.global_position + mol.forward() * 9.0 + Vector3.DOWN * 3.0
	worm.mode = Worm.Mode.HUNT
	worm._ram_cool = 0.0
	mol_hits[0] = 0
	worm._start_bite(mol)
	_expect(worm.mode == Worm.Mode.BITE and worm.biting() and mol_hits[0] == 1, "hij bijt zich vast in de rijdende Mol")
	_expect(not mol.contains_point(worm._bite_head()), "de kop zit tegen de romp, niet erin")
	await _wait(2.2)
	_expect(absf(mol.speed) <= Tuning.get_f("mol", "extract_speed", 6.0) * Tuning.get_f("worm", "bite_slow", 0.45) + 0.4,
			"zolang hij bijt, rijdt de Mol trager (%.1f m/s)" % absf(mol.speed))
	_expect(cargo.condition < cond1 - 0.04 and cargo.condition > cond1 - 0.12, "zolang hij bijt, lijdt de lading (%d%% → %d%%)" % [int(cond1 * 100), int(cargo.condition * 100)])
	for s: float in [1.0, -1.0, 1.0, -1.0]:
		worm.host_shake(s)
	_expect(bite_end[0] == "shake" and worm.mode != Worm.Mode.BITE, "de piloot schudt hem los (links-rechts sturen)")
	var cond2 := cargo.condition
	await _wait(1.2)
	_expect(is_equal_approx(cargo.condition, cond2), "losgeschud: de lading lijdt niet meer")
	# Een baken uit de achterklep: het valt achter de Mol, buiten, en dan bijt hij niet.
	var left0 := game.beacons.left
	var out := [Vector3.INF]
	game.beacons.launched.connect(func(at: Vector3) -> void: out[0] = at, CONNECT_ONE_SHOT)
	_expect(game.beacons.host_launch(p.peer_id), "G in de rijdende Mol: een baken door de achterklep")
	await _wait(0.4)
	_expect(game.beacons.left == left0 - 1 and out[0] != Vector3.INF and not mol.contains_point(out[0]), "het baken valt buiten, achter de Mol")
	var trail: Vector3 = (out[0] as Vector3) - mol.body.global_position
	_expect(trail.dot(mol.forward()) > 3.0, "achter in de rijrichting (de Mol rijdt achteruit terug: aan de kant van de neus)")
	worm.pos = out[0] + Vector3.DOWN * 4.0
	worm.mode = Worm.Mode.HUNT
	worm._ram_cool = 0.0
	worm._start_bite(mol)
	_expect(worm.mode == Worm.Mode.REPELLED, "bij een baken buiten de Mol bijt hij niet: hij zwemt weg")
	p.set_physics_process(true)
	await _until(func() -> bool: return not mol.mode in [Mol.Mode.EXTRACTING, Mol.Mode.COUNTDOWN], 20.0)
	if p.seated:
		mol.leave_seat()
	Tuning.set_value("mol", "countdown_s", 10.0)
	_finish()




func _reset_player() -> void:
	var r: Rescue = game.rescue
	if r.life_of(p.peer_id) != Rescue.Life.OK or r.health_of(p.peer_id) < 1.0:
		r._rpc_reset.rpc(p.peer_id, p.global_position, false)
	p.set_physics_process(true)


## De worm valt uit naar de speler op `spot` (een open ruimte) en grijpt hem: wacht tot hij hem heeft.
func _grab_me(spot: Vector3, grabbed: Array) -> void:
	_reset_player()
	await _wait(0.2)
	var at := spot + Vector3(0.6, 0.1, 0.6)
	p.set_physics_process(false)
	p.global_position = at
	p.reset_physics_interpolation()
	p.set_physics_process(true)
	await _wait(0.4)
	var worm: Worm = game.worm
	worm.mode = Worm.Mode.HUNT
	worm.pos = spot + Vector3(-12.0, -6.0, 0.0)
	worm._cool = 0.0
	worm._grab_cool = 0.0
	grabbed[0] = -1
	worm._try_lunge(at)
	var t0 := _gt()
	while _gt() - t0 < 6.0 and grabbed[0] < 0:
		await get_tree().physics_frame
		if game.rescue.is_ok(p.peer_id):
			p.global_position = at


## Alle bakens weg (ze branden 2 min en zouden de volgende stappen tegenhouden).
func _clear_beacons() -> void:
	var bc: Beacons = game.beacons
	for b: RigidBody3D in bc._items.values():
		if is_instance_valid(b):
			b.queue_free()
	for r: Decal in bc._rings.values():
		if is_instance_valid(r):
			r.queue_free()
	bc._items.clear()
	bc._stowed.clear()
	bc._rings.clear()


## Een vondst ver van alles, om mee te testen.
func _a_find() -> FindItem:
	for it: FindItem in game.finds.items:
		if not it.freed and it.carriers.is_empty():
			return it
	return game.finds.items[0]


func _finish() -> void:
	print(TAG, " %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print(TAG, " MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print(TAG, " %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _gt() -> float:
	return Time.get_ticks_msec() / 1000.0


func _until(cond: Callable, timeout: float) -> bool:
	var t0 := _gt()
	while _gt() - t0 < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()
