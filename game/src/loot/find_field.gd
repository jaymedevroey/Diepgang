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


func generate(pit_seed: int) -> void:
	var t: TerrainAPI = game.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = pit_seed * 7919 + 11
	var spawn := t.spawn_point()
	var size := t.world_size()
	# 1. Rond de landingsplek, ondiep, om meteen te vinden. De eerste is een bot (de haak van het spel).
	var near := Tuning.get_i("finds", "near_spawn", 5)
	for i in near:
		_place(rng, func() -> Array:
			var ang := rng.randf() * TAU
			var p := spawn + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(2.5, 7.0)
			p.y = t.surface_height_at(p.x, p.z) - rng.randf_range(1.3, 2.6)
			return [p, FindKinds.Kind.CLAW if i == 0 else -1])
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
	print("[finds] %d vondsten geplaatst (seed %d)" % [items.size(), pit_seed])


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
		item.setup(items.size(), kind)
		add_child(item)
		item.global_position = pos
		item.rotation = rot
		items.append(item)
		var crust := Crust.new()
		crust.name = "Crust%d" % item.find_id
		crust.setup(item.find_id, item.half_extents, Tuning.get_f("finds", "crust_hp", 4.0), float(item.find_id) * 3.7)
		add_child(crust)
		crust.global_transform = item.global_transform
		crusts[item.find_id] = crust
		return


func _far_from_others(pos: Vector3) -> bool:
	var min_gap := Tuning.get_f("finds", "min_spacing", 2.0)
	for other in items:
		if other.global_position.distance_to(pos) < min_gap:
			return false
	return true


func item(id: int) -> FindItem:
	return items[id] if id >= 0 and id < items.size() else null


# --- Korst raken --------------------------------------------------------------

## Lokaal gereedschap raakt een korst. Juice doet het gereedschap zelf meteen.
func hit_crust(find_id: int, tool: Strata.Tool, pos: Vector3) -> void:
	if Net.is_host():
		_apply_hit(Net.my_id(), find_id, tool, pos)
	else:
		_rpc_hit.rpc_id(1, find_id, tool, pos)


@rpc("any_peer", "reliable")
func _rpc_hit(find_id: int, tool: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_apply_hit(multiplayer.get_remote_sender_id(), find_id, tool, pos)


func _apply_hit(sender: int, find_id: int, tool: int, pos: Vector3) -> void:
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
		cond = maxf(Tuning.get_f("finds", "min_condition", 0.25), cond - Tuning.get_f("finds", "drill_condition_loss", 0.07))
	_rpc_state.rpc(find_id, hp, cond, tool)
	if hp <= 0.0:
		_free(find_id)


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


func _free(find_id: int) -> void:
	var it := item(find_id)
	var r := it.half_extents.length() + Tuning.get_f("finds", "free_margin", 0.35)
	game.terrain_sync.host_apply(game.terrain.make_sphere_op(0, it.global_position, r))
	_rpc_freed.rpc(find_id)


@rpc("authority", "call_local", "reliable")
func _rpc_freed(find_id: int) -> void:
	var it := item(find_id)
	if it == null or it.freed:
		return
	it.freed = true
	it.last_safe = it.global_position
	var crust: Crust = crusts.get(find_id)
	if crust:
		game.fx.crust_break(crust.global_position, it.half_extents.length())
		crust.shatter()
		crusts.erase(find_id)
	it.celebrate()
	game.fx.play("ding", it.global_position, -2.0, 0.05)
	if multiplayer.is_server():
		it.freeze = false
		it.apply_central_impulse(Vector3.UP * Tuning.get_f("finds", "free_impulse", 1.2) * it.mass)
	find_freed.emit(it)


# --- De Mol schept op ------------------------------------------------------

## Host: de boorkop van de Mol raakt een vondst die nog in de rots zit. Hij schept hem op en legt
## hem in het laadruim, zwaar beschadigd: zelf uitbikken loont (GDD §5A: de Mol is traag, luid
## en beperkt, met de hand graven blijft de kern).
func host_mol_scoop(it: FindItem, mol: Mol) -> void:
	if it.freed:
		return
	var cond := minf(it.condition, Tuning.get_f("finds", "mol_condition", 0.3))
	var local := Transform3D(Basis(Vector3.UP, randf() * TAU), _cargo_spot(it, mol))
	_rpc_scooped.rpc(it.find_id, cond, local)
	mol.announce("De boorkop schepte een %s op: in het laadruim, maar beschadigd (%d%%)" % [
			it.display_name().to_lower(), int(round(cond * 100.0))])


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
	it.freed = true
	var crust: Crust = crusts.get(find_id)
	if crust:
		game.fx.crust_break(crust.global_position, it.half_extents.length())
		crust.shatter()
		crusts.erase(find_id)
	it.global_transform = mol.body.global_transform * local
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
	it.carriers = carriers
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
	var threshold := Tuning.get_f("carry", "impact_threshold", 5.0)
	if dv <= threshold:
		return
	var loss := (dv - threshold) * Tuning.get_f("carry", "impact_damage", 0.05)
	var cond := maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss)
	_rpc_condition.rpc(it.find_id, cond)


@rpc("authority", "call_local", "reliable")
func _rpc_condition(find_id: int, cond: float) -> void:
	var it := item(find_id)
	if it == null:
		return
	var hard := cond < it.condition - 0.001
	it.condition = cond
	if hard:
		game.fx.crust_hit(it.global_position, Vector3.UP, false)
		game.fx.play("tok", it.global_position, 0.0)
	condition_changed.emit(it, hard)


# --- Late joiners ------------------------------------------------------------

func snapshot() -> Array:
	var out: Array = []
	for it in items:
		var crust: Crust = crusts.get(it.find_id)
		out.append([it.find_id, crust.hp if crust else 0.0, it.condition, it.freed, it.global_transform, it.carriers])
	return out


func apply_snapshot(state: Array) -> void:
	for s in state:
		var it := item(s[0])
		if it == null:
			continue
		it.condition = s[2]
		var crust: Crust = crusts.get(it.find_id)
		if s[3]:
			it.freed = true
			it.carriers = s[5]
			it.global_transform = s[4]
			it.push_snapshot(s[4])
			if crust:
				crust.shatter()
				crusts.erase(it.find_id)
		elif crust:
			crust.set_hp(s[1])
