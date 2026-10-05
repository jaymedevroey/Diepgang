class_name FindField
extends Node3D
## Alle vondsten van de put, met hun korst (GDD §3: uitbikken; §9: host simuleert buit).
## - Plaatsing volgt uit de seed: elke peer maakt dezelfde vondsten zonder netwerkverkeer.
## - Korsttreffers: de client meldt, de host beslist (levens, gaafheid) en verspreidt.
## - Korst kapot: de host graaft ruimte rond de vondst (terrein-op) en laat hem los.
## - Losse vondsten: de host simuleert, stuurt 20×/s posities; clients interpoleren.
## Staat op elk peer op Game/Finds zodat RPC's aankomen.

signal find_freed(item: FindItem)
signal crust_hit(item: FindItem, tool: Strata.Tool)
signal carriers_changed(item: FindItem)
signal condition_changed(item: FindItem, hard: bool)
## De boorkop van de Mol schepte een vondst op (in het laadruim, beschadigd).
signal find_scooped(item: FindItem)

const SEND_INTERVAL := 0.05
## De eerste vondst bij de landingsplek: een bot, wisselend per wereld (geen schedel: die is de
## grote vangst dieper). De klauw staat er twee keer in: hij blijft de vaakste.
const FIRST_BONES: Array[FindKinds.Kind] = [FindKinds.Kind.CLAW, FindKinds.Kind.CLAW, FindKinds.Kind.FEMUR,
		FindKinds.Kind.VERTEBRA, FindKinds.Kind.RIB]

var game: Node # Game
## Vloer van het laadruim (Mol-ruimte, y).
const CARGO_FLOOR := -1.47

var items: Array[FindItem] = []
var crusts: Dictionary = {} # find_id -> Crust

var _last_hit: Dictionary = {} # host: peer_id -> tijd (s)
var _prev_velocity: Dictionary = {} # host: find_id -> Vector3
var _stowed := {} # find_id -> Transform3D relatief tot de Mol (laadruim, zie _stow)
var _parked := {} # find_id -> true: bevroren omdat er geen collision onder ligt (streaming)
var _send_timer := 0.0
var _gone := PackedInt32Array() # opgeslokt door het magma (voor wie later binnenkomt)
var _by_id := {} # find_id -> FindItem (items blijft niet op volgorde: het magma haalt er weg)
var _next_id := 0


func generate(pit_seed: int) -> void:
	var t_start := Time.get_ticks_msec()
	var t: TerrainAPI = game.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = pit_seed * 7919 + 11
	var spawn := t.spawn_point()
	var size := t.world_size()
	# 1. Rond de landingsplek, ondiep, om meteen te vinden. De eerste is een bot (de haak van het spel),
	# maar niet altijd dezelfde klauw (ontwerp-16): een bot uit FIRST_BONES, gekozen met de seed.
	var first: FindKinds.Kind = FIRST_BONES[rng.randi() % FIRST_BONES.size()]
	var near := Tuning.get_i("finds", "near_spawn", 5)
	for i in near:
		_place(rng, func() -> Array:
			var ang := rng.randf() * TAU
			var p := spawn + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(2.5, 7.0)
			p.y = t.surface_height_at(p.x, p.z) - rng.randf_range(1.3, 2.6)
			return [p, first if i == 0 else -1])
	# 2. Fossielbedden: clusters skeletstukken in zandsteen en graniet.
	for b in Tuning.get_i("finds", "beds", 8):
		var center := Vector3(rng.randf_range(12.0, size.x - 12.0), rng.randf_range(Strata.TOPS_M[0] + 8.0, Strata.TOPS_M[2] - 4.0),
				rng.randf_range(12.0, size.z - 12.0))
		for k in rng.randi_range(4, 8):
			_place(rng, func() -> Array:
				return [center + Vector3(rng.randf_range(-7, 7), rng.randf_range(-2.5, 2.5), rng.randf_range(-7, 7)), -2])
	# 3. Rond grotten: net achter de wand, te vinden van in de grot.
	var caves := t.caves()
	for i in Tuning.get_i("finds", "near_caves", 45):
		var c: Vector4 = caves[rng.randi() % caves.size()]
		_place(rng, func() -> Array:
			var a := rng.randf() * TAU
			var r := c.w + rng.randf_range(0.8, 3.0)
			return [Vector3(c.x + cos(a) * r, c.y + rng.randf_range(-0.4, 0.4) * c.w / PlanetGenerator.CAVERN_SQUASH, c.z + sin(a) * r), -1])
	# 4. Verspreid, op elke diepte (opzij is evenveel te vinden als diep: geen "recht naar beneden").
	for i in Tuning.get_i("finds", "scattered", 60):
		_place(rng, func() -> Array:
			var p := Vector3(rng.randf_range(8.0, size.x - 8.0), 0, rng.randf_range(8.0, size.z - 8.0))
			p.y = rng.randf_range(6.0, t.surface_height_at(p.x, p.z) - 2.0)
			return [p, -1])
	print("[finds] %d vondsten geplaatst (seed %d) in %d ms" % [items.size(), pit_seed, Time.get_ticks_msec() - t_start])


## Eén vondst plaatsen. `where` geeft [positie, soort] terug (soort -1 = volgens de laag,
## -2 = fossielbed). Tot 40 pogingen voor een plek in de rots, weg van de landingsplek en van
## andere vondsten. Altijd evenveel getallen uit de rng per poging: elke peer plaatst hetzelfde.
## Nieuwe wereld: alle vondsten en korsten weg.
func clear() -> void:
	for it in items:
		it.queue_free()
	for c: Crust in crusts.values():
		c.queue_free()
	items.clear()
	crusts.clear()
	_gone.clear()
	_by_id.clear()
	_next_id = 0
	_stowed.clear()
	_parked.clear()
	_prev_velocity.clear()


func _place(rng: RandomNumberGenerator, where: Callable) -> void:
	var t: TerrainAPI = game.terrain
	var sc := t.shaft_center_world()
	for attempt in 40:
		var res: Array = where.call()
		var pos: Vector3 = res[0]
		var forced: int = res[1]
		var rot := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var flat := Vector2(pos.x - sc.x, pos.z - sc.z).length()
		if flat < 6.0 or pos.y < 4.0 or t.generated_rock_depth(pos) < 1.0 or not _far_from_others(pos):
			continue
		var kind: FindKinds.Kind = forced if forced >= 0 else FindKinds.pick_kind(rng, pos.y, t.layer_at(pos), forced == -2)
		var item := FindItem.new()
		item.setup(_next_id, kind)
		_next_id += 1
		add_child(item)
		item.global_position = pos
		item.rotation = rot
		item.reset_physics_interpolation()
		items.append(item)
		_by_id[item.find_id] = item
		var crust := Crust.new()
		crust.name = "Crust%d" % item.find_id
		crust.setup(item.find_id, item.half_extents, crust_hp_of(item), float(item.find_id) * 3.7,
				t.layer_at(pos), FindKinds.FAMILIES[kind])
		add_child(crust)
		crust.global_transform = item.global_transform
		crusts[item.find_id] = crust
		return


## Levens van de korst (ontwerp-11): hoe waardevoller de vondst, hoe meer geduld met het houweel
## (rommel ±4 s, kostbaar ±6,5 s bij 0,55 s per slag).
static func crust_hp_of(it: FindItem) -> float:
	return Tuning.get_f("finds", "crust_hp", 7.0) + Tuning.get_f("finds", "crust_hp_per_class", 2.0) * it.value_class


func _far_from_others(pos: Vector3) -> bool:
	var min_gap := Tuning.get_f("finds", "min_spacing", 2.0)
	for other in items:
		if other.global_position.distance_to(pos) < min_gap:
			return false
	return true


func item(id: int) -> FindItem:
	return _by_id.get(id)


# --- Korst raken --------------------------------------------------------------

## Lokaal gereedschap raakt een korst. Juice doet het gereedschap zelf meteen.
## `hot`: de boor is heet (meer dan de helft): de vondst lijdt meer (ontwerp-11, voorzichtig boren loont).
func hit_crust(find_id: int, tool: Strata.Tool, pos: Vector3, hot := false) -> void:
	if Net.is_host():
		_apply_hit(Net.my_id(), find_id, tool, pos, hot)
	else:
		_rpc_hit.rpc_id(1, find_id, tool, pos, hot)


@rpc("any_peer", "reliable")
func _rpc_hit(find_id: int, tool: int, pos: Vector3, hot: bool) -> void:
	if multiplayer.is_server():
		_apply_hit(multiplayer.get_remote_sender_id(), find_id, tool, pos, hot)


func _apply_hit(sender: int, find_id: int, tool: int, pos: Vector3, hot := false) -> void:
	var it := item(find_id)
	var crust: Crust = crusts.get(find_id)
	if it == null or it.freed or crust == null:
		return
	var player: Node3D = game.player_node(sender)
	if player == null or player.global_position.distance_to(pos) > 4.5:
		print("[finds] treffer op %d geweigerd: te ver of geen speler" % find_id)
		return
	var drill := tool != Strata.Tool.HOUWEEL
	var now := Time.get_ticks_msec() / 1000.0
	# Ruim (dig.host_slack): de client wacht al op zijn gereedschap, en echte tijd en speltijd
	# lopen onder zware belasting (streaming) uiteen.
	var min_gap := Tuning.get_f("finds", "drill_min_interval" if drill else "pickaxe_min_interval", 0.1) / Tuning.get_f("dig", "host_slack", 2.0)
	if now - float(_last_hit.get(sender, -100.0)) < min_gap:
		print("[finds] treffer op %d geweigerd: te snel (%.3f s)" % [find_id, now - float(_last_hit.get(sender, -100.0))])
		return
	_last_hit[sender] = now
	var hp := crust.hp - Tuning.get_f("finds", "drill_damage" if drill else "pickaxe_damage", 1.0)
	var cond := it.condition
	if drill:
		var loss := Tuning.get_f("finds", "drill_condition_loss", 0.014) * (Tuning.get_f("finds", "drill_hot_factor", 2.2) if hot else 1.0)
		cond = maxf(Tuning.get_f("finds", "min_condition", 0.25), cond - loss)
	_rpc_state.rpc(find_id, hp, cond, tool)
	if hp <= 0.0:
		_free(find_id, sender)


@rpc("authority", "call_local", "reliable")
func _rpc_state(find_id: int, hp: float, cond: float, tool: int) -> void:
	var it := item(find_id)
	if it == null:
		return
	it.condition = cond
	var crust: Crust = crusts.get(find_id)
	if crust:
		crust.set_hp(hp)
	crust_hit.emit(it, tool)


## `by`: wie de laatste slag gaf (0 = niemand): de vondst springt een beetje naar hem toe.
func _free(find_id: int, by := 0) -> void:
	var it := item(find_id)
	var r := it.half_extents.length() + Tuning.get_f("finds", "free_margin", 0.35)
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, it.global_position, r))
	_rpc_freed.rpc(find_id, by)


## Het moment (gevoel-03): eerst de vondst. Licht en sterretjes in de glans van zijn waardeklasse,
## de schelpen van de korst vliegen weg van wie hem vrijmaakte, het stof komt pas daarna en laag.
## De vondst springt omhoog en naar de speler toe, en zijn naam verschijnt erboven.
@rpc("authority", "call_local", "reliable")
func _rpc_freed(find_id: int, by := 0) -> void:
	var it := item(find_id)
	if it == null or it.freed:
		return
	it.set_freed()
	it.last_safe = it.global_position
	var striker: Node3D = game.player_node(by) if by != 0 else null
	var toward := Vector3.ZERO
	if striker:
		toward = striker.global_position + Vector3(0, 1.0, 0) - it.global_position
	var crust: Crust = crusts.get(find_id)
	var k: float = FindKinds.CLASS_STRENGTH[it.value_class]
	if crust:
		game.fx.crust_break(crust.global_position, it.half_extents.length(), crust.tint,
				FindKinds.CLASS_GLINT[it.value_class], k, toward, it)
		crust.shatter()
		crusts.erase(find_id)
	it.celebrate()
	game.fx.play("ding", it.global_position, -2.0 + 2.0 * (k - 1.0), 0.05, FindKinds.CLASS_PITCH[it.value_class])
	_reveal_text(it)
	if multiplayer.is_server():
		it.freeze = false
		var push := Vector3.UP * Tuning.get_f("finds", "free_impulse", 2.0)
		if toward.length() > 0.1:
			var flat := Vector3(toward.x, 0.0, toward.z)
			if flat.length() > 0.05:
				push += flat.normalized() * Tuning.get_f("finds", "free_toward", 1.0)
		it.apply_central_impulse(push * it.mass)
	find_freed.emit(it)


## Naam (en voorlopig de waarde) groot boven de vondst. Pakket F1 verhuist de onthulling van de
## waarde naar de taxatiepoort: dan blijft hier enkel de naam en de waardeklasse.
func _reveal_text(it: FindItem) -> void:
	var col: Color = FindKinds.CLASS_GLINT[it.value_class]
	var at := it.global_position + Vector3(0, it.half_extents.length() + 0.25, 0)
	game.fx.float_text(at, it.display_name().to_upper(), col.lerp(Color.WHITE, 0.2), 1.0 + 0.15 * it.value_class, 2.6)
	game.fx.float_text(at - Vector3(0, 0.13, 0), "€%d" % it.value(), Color(0.95, 0.92, 0.82), 0.6, 2.6)


# --- Het magma slokt op ----------------------------------------------------

## Host: een vondst ligt te lang in het magma (los of nog in de rots): weg, bij iedereen.
func host_swallow(find_id: int) -> void:
	_rpc_swallowed.rpc(find_id)


@rpc("authority", "call_local", "reliable")
func _rpc_swallowed(find_id: int) -> void:
	var it := item(find_id)
	if it == null:
		return
	# Enkel een sisser waar iemand het kan zien (het magma slokt soms tientallen tegelijk op).
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(it.global_position) < 30.0:
		game.fx.grit_puff(it.global_position, Vector3.UP, Color(1.0, 0.45, 0.1))
	_remove(it)
	game.magma.swallowed.emit(find_id)


## Host: een vondst is weg (verkocht), bij iedereen.
func host_remove(find_id: int) -> void:
	_rpc_removed.rpc(find_id)


@rpc("authority", "call_local", "reliable")
func _rpc_removed(find_id: int) -> void:
	var it := item(find_id)
	if it:
		_remove(it)


func _remove(it: FindItem) -> void:
	var crust: Crust = crusts.get(it.find_id)
	if crust:
		crust.queue_free()
		crusts.erase(it.find_id)
	items.erase(it)
	_by_id.erase(it.find_id)
	_stowed.erase(it.find_id)
	_parked.erase(it.find_id)
	_prev_velocity.erase(it.find_id)
	_gone.append(it.find_id)
	it.queue_free()


# --- De Mol schept op ------------------------------------------------------

## Host: de boorkop van de Mol raakt een vondst die nog in de rots zit. Hij schept hem op en legt
## hem in het laadruim, zwaar beschadigd: zelf uitbikken loont (GDD §5A: de Mol is traag, luid
## en beperkt, met de hand graven blijft de kern).
func host_mol_scoop(it: FindItem, mol: Mol, quiet := false) -> void:
	if it.freed:
		return
	var cond := minf(it.condition, Tuning.get_f("finds", "mol_condition", 0.05))
	var local := Transform3D(Basis(Vector3.UP, randf() * TAU), _cargo_spot(it, mol))
	_rpc_scooped.rpc(it.find_id, cond, local)
	if not quiet: # (de Mol meldt het zelf, samen met de andere van dezelfde boorbol)
		mol.announce("The drill head scooped up a find (%s): it's in the cargo hold, but damaged (%d%%)" % [
				it.display_name(), int(round(cond * 100.0))], "warn")


## Plek op de vloer van het laadruim, zo ver mogelijk van wat er al ligt (Mol-ruimte).
func _cargo_spot(it: FindItem, mol: Mol) -> Vector3:
	var taken: Array[Vector3] = []
	for other: FindItem in mol.cargo_contents():
		taken.append(mol.to_local_mol(other.global_position))
	var best := Vector3.ZERO
	var best_gap := -1.0
	for z in [2.3, 3.0, 3.7]:
		for x in [-0.9, -0.3, 0.3, 0.9]:
			var spot := Vector3(x, CARGO_FLOOR + it.rest_height() + 0.02, z)
			var gap := INF
			for q in taken:
				gap = minf(gap, q.distance_to(spot))
			if gap > best_gap + 0.01:
				best_gap = gap
				best = spot
	return best


@rpc("authority", "call_local", "reliable")
func _rpc_scooped(find_id: int, cond: float, local: Transform3D) -> void:
	var it := item(find_id)
	var mol: Mol = game.mol
	if it == null or it.freed or mol == null:
		return
	it.condition = cond
	it.set_freed()
	var crust: Crust = crusts.get(find_id)
	if crust:
		game.fx.crust_break(crust.global_position, it.half_extents.length())
		crust.shatter()
		crusts.erase(find_id)
	it.global_transform = mol.body.global_transform * local
	it.reset_physics_interpolation()
	it.last_safe = it.global_position
	it.push_snapshot(local, true)
	game.fx.play("tok", it.global_position, -2.0)
	if multiplayer.is_server():
		it.freeze = false
		it.linear_velocity = Vector3.ZERO
		it.angular_velocity = Vector3.ZERO
	find_scooped.emit(it)


# --- Dragen ------------------------------------------------------------------

func request_grab(find_id: int) -> void:
	if Net.is_host():
		_grab(Net.my_id(), find_id)
	else:
		_rpc_grab.rpc_id(1, find_id)


func request_release(find_id: int, xf: Transform3D, velocity: Vector3) -> void:
	if Net.is_host():
		_release(Net.my_id(), find_id, xf, velocity)
	else:
		_rpc_release.rpc_id(1, find_id, xf, velocity)


@rpc("any_peer", "reliable")
func _rpc_grab(find_id: int) -> void:
	if multiplayer.is_server():
		_grab(multiplayer.get_remote_sender_id(), find_id)


@rpc("any_peer", "reliable")
func _rpc_release(find_id: int, xf: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		_release(multiplayer.get_remote_sender_id(), find_id, xf, velocity)


func _grab(sender: int, find_id: int) -> void:
	var it := item(find_id)
	var player: Player = game.player_node(sender)
	if it == null or player == null or not it.freed or it.carriers.size() >= 2 or it.carriers.has(sender):
		return
	if player.global_position.distance_to(it.global_position) > Tuning.get_f("carry", "grab_reach", 3.0) + 1.5:
		return
	# Wie al iets draagt, laat dat eerst los.
	for other in items:
		if other.carriers.has(sender):
			_release(sender, other.find_id, other.global_transform, Vector3.ZERO)
	var carriers := it.carriers.duplicate()
	carriers.append(sender)
	it.freeze = true
	_rpc_carriers.rpc(find_id, carriers)


func _release(sender: int, find_id: int, xf: Transform3D, velocity: Vector3) -> void:
	var it := item(find_id)
	if it == null or not it.carriers.has(sender):
		return
	var carriers := it.carriers.duplicate()
	carriers.remove_at(carriers.find(sender))
	if carriers.is_empty():
		# Fysica neemt over waar de laatste drager hem losliet: niet verder dan 3 m van de
		# host-positie en niet in de rots.
		if xf.origin.distance_to(it.global_position) < 3.0 and not _inside_rock(xf.origin):
			it.global_transform = xf
		it.freeze = false
		it.linear_velocity = velocity.limit_length(12.0)
		it.sleeping = false
		_prev_velocity[find_id] = it.linear_velocity
	_rpc_carriers.rpc(find_id, carriers)


@rpc("authority", "call_local", "reliable")
func _rpc_carriers(find_id: int, carriers: PackedInt32Array) -> void:
	var it := item(find_id)
	if it == null:
		return
	if not it.carriers.is_empty():
		it.last_carriers = it.carriers
	it.carriers = carriers
	it.update_interpolation()
	carriers_changed.emit(it)


## Waar een gedragen vondst hoort: tussen de handen van zijn dragers, niet door een muur.
func carry_target(it: FindItem) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for peer in it.carriers:
		var p: Player = game.player_node(peer)
		if p:
			sum += p.hold_point(it.half_extents.length())
			n += 1
	return sum / n if n > 0 else it.global_position


## Host: iemand is weg; wat hij droeg, valt.
func drop_all_of(peer: int) -> void:
	for it in items:
		if it.carriers.has(peer):
			_release(peer, it.find_id, it.global_transform, Vector3.ZERO)


# --- Posities van losse vondsten ----------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or game == null:
		return
	var mol_now: Mol = game.mol
	var mol_moving := mol_now != null and mol_now.body != null and (absf(mol_now.speed) > 0.05 or mol_now.mode in Mol.MOVING_MODES)
	for it in items:
		if not it.freed:
			continue
		if it.carriers.size() > 0:
			_stowed.erase(it.find_id)
			# Draagt de host hem zelf, dan zet zijn Carry hem (met naslepen en wiegen).
			if not it.carriers.has(multiplayer.get_unique_id()):
				it.global_position = carry_target(it)
		elif _stow(it, mol_now, mol_moving):
			pass
		elif _park(it):
			pass
		else:
			_check_impact(it)
			_rescue_if_stuck(it, delta)
	_send_timer += delta
	if _send_timer < SEND_INTERVAL:
		return
	_send_timer = 0.0
	var ids := PackedInt32Array()
	var poses: Array = []
	var in_mol := PackedByteArray()
	var mol: Mol = game.mol
	for it in items:
		if not it.freed:
			continue
		var inside := mol != null and mol.contains_point(it.global_position)
		# In een rijdende Mol slaapt een vondst ook, maar hij beweegt wel mee.
		if it.sleeping and it.carriers.is_empty() and not (inside and absf(mol.speed) > 0.01):
			continue
		ids.append(it.find_id)
		if inside:
			poses.append(mol.body.global_transform.affine_inverse() * it.global_transform)
		else:
			poses.append(it.global_transform)
		in_mol.append(1 if inside else 0)
	if ids.is_empty():
		return
	for peer: int in game.ready_peers:
		if peer != multiplayer.get_unique_id():
			_rpc_poses.rpc_id(peer, ids, poses, in_mol)


@rpc("authority", "unreliable_ordered")
func _rpc_poses(ids: PackedInt32Array, poses: Array, in_mol: PackedByteArray) -> void:
	for i in ids.size():
		var it := item(ids[i])
		if it:
			it.push_snapshot(poses[i], in_mol[i] == 1)


## Host: laadruim. Rijdt de Mol, dan zitten losse vondsten in de Mol vastgesjord en volgen ze
## hem exact (wrijving alleen is bij 22° helling en 6 m/s niet betrouwbaar). Staat hij stil,
## dan neemt de fysica het weer over. Geeft true terug als de vondst vastzit.
func _stow(it: FindItem, mol: Mol, moving: bool) -> bool:
	var stowed: bool = _stowed.has(it.find_id)
	if moving and (stowed or mol.contains_point(it.global_position)):
		if not stowed:
			_stowed[it.find_id] = mol.body.global_transform.affine_inverse() * it.global_transform
			it.freeze = true
		it.global_transform = mol.body.global_transform * (_stowed[it.find_id] as Transform3D)
		it.last_safe = it.global_position
		_prev_velocity.erase(it.find_id)
		return true
	if stowed:
		# Nog één keer op zijn plek in de Mol (die kan net gesprongen zijn: hub ↔ buitenschip).
		it.global_transform = mol.body.global_transform * (_stowed[it.find_id] as Transform3D)
		_stowed.erase(it.find_id)
		it.freeze = false
		it.linear_velocity = Vector3.ZERO
		it.angular_velocity = Vector3.ZERO
		it.sleeping = false
	return false


## Host: ligt een losse vondst ver van elke speler en de Mol, dan is er geen collision meer onder
## hem (streaming) en zou hij door de wereld vallen. Dan bevriest hij tot er weer iemand in de
## buurt is. Geeft true terug zolang hij geparkeerd is.
func _park(it: FindItem) -> bool:
	var parked: bool = _parked.has(it.find_id)
	var ready: bool = game.terrain.collision_ready(it.global_position)
	if not ready:
		if not parked:
			_parked[it.find_id] = true
			it.freeze = true
		return true
	if parked:
		_parked.erase(it.find_id)
		it.freeze = false
		it.sleeping = false
	return false


## Minstens een halve meter diep in de rots (dichtstbijzijnde voxel, dus met marge).
func _inside_rock(pos: Vector3) -> bool:
	return game.terrain.debug_sdf(pos) < -1.0


## Host: vangnet. Zit een losse vondst in de rots of valt hij onder de put, dan terug naar
## zijn laatste veilige plek, en van daar omhoog tot er echt ruimte is. Een plek telt pas als
## veilig als hij in de lucht ligt: net onder het oppervlak (bv. losgelaten in de wand) zakt hij
## door de botsvorm en zat hij vroeger eindeloos vast (vangnet zette hem telkens terug in de grond).
func _rescue_if_stuck(it: FindItem, delta: float) -> void:
	var pos := it.global_position
	if _inside_rock(pos) or pos.y < -2.0:
		it.stuck_time += delta
		if it.stuck_time > 0.25:
			it.global_position = _free_spot_above(it.last_safe, it)
			it.reset_physics_interpolation()
			it.linear_velocity = Vector3.ZERO
			it.angular_velocity = Vector3.ZERO
			it.stuck_time = 0.0
			print("[finds] vondst %d zat vast in de rots: teruggezet naar %s" % [it.find_id, it.global_position])
	else:
		it.stuck_time = 0.0
		if it.linear_velocity.length() < 3.0 and game.terrain.debug_sdf(pos) > 0.0:
			it.last_safe = pos


## Vanaf `from` omhoog tot de vondst er helemaal in de lucht past (SDF in voxels groter dan zijn straal).
func _free_spot_above(from: Vector3, it: FindItem) -> Vector3:
	var need := it.half_extents.length() / TerrainAPI.VOXEL_SIZE + 0.5
	var p := from
	for i in 32:
		if game.terrain.debug_sdf(p) >= need:
			return p
		p.y += 0.25
	return from + Vector3(0, 0.3, 0)


## Host: harde klap (vallen, gooien, botsen) kost gaafheid (GDD §3: botst, breekt).
func _check_impact(it: FindItem) -> void:
	var v := it.linear_velocity
	var prev: Vector3 = _prev_velocity.get(it.find_id, v)
	_prev_velocity[it.find_id] = v
	var dv := (v - prev).length()
	var threshold := Tuning.get_f("carry", "impact_threshold", 3.0)
	if dv <= threshold:
		return
	var loss := minf((dv - threshold) * Tuning.get_f("carry", "impact_damage", 0.06), Tuning.get_f("carry", "impact_max_loss", 0.3))
	var cond := maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss)
	if cond < it.condition - 0.001:
		_rpc_condition.rpc(it.find_id, cond)


## Schade zie je meteen (gevoel-06, plezier-en-design §10): "−€X" boven de vondst, een krak (de
## bestaande tok, M6 brengt een eigen geluid) en schilfers. Het signaal condition_changed blijft
## voor de HUD en het robotgezicht.
@rpc("authority", "call_local", "reliable")
func _rpc_condition(find_id: int, cond: float) -> void:
	var it := item(find_id)
	if it == null:
		return
	var hard := cond < it.condition - 0.001
	var before := it.value()
	it.condition = cond
	if hard:
		var lost := before - it.value()
		if lost > 0:
			game.fx.float_text(it.global_position + Vector3(0, it.half_extents.length() + 0.15, 0), "−€%d" % lost,
					Color(1.0, 0.32, 0.22), 0.9, 1.6)
		game.fx.crust_hit(it.global_position, Vector3.UP, false)
		game.fx.play("tok", it.global_position, 0.0)
	condition_changed.emit(it, hard)


# --- Late joiners ------------------------------------------------------------

func snapshot() -> Array:
	var out: Array = []
	for it in items:
		var crust: Crust = crusts.get(it.find_id)
		out.append([it.find_id, crust.hp if crust else 0.0, it.condition, it.freed, it.global_transform, it.carriers])
	for id in _gone:
		out.append([id]) # weg (magma)
	return out


func apply_snapshot(state: Array) -> void:
	for s in state:
		var it := item(s[0])
		if it == null:
			continue
		if s.size() == 1:
			_remove(it)
			continue
		it.condition = s[2]
		var crust: Crust = crusts.get(it.find_id)
		if s[3]:
			it.set_freed()
			it.carriers = s[5]
			it.global_transform = s[4]
			it.reset_physics_interpolation()
			it.push_snapshot(s[4])
			if crust:
				crust.shatter()
				crusts.erase(it.find_id)
		elif crust:
			crust.set_hp(s[1])
