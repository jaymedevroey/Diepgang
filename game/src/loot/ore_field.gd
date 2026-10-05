class_name OreField
extends Node3D
## Erts op de planeet (GDD v3 §4: vast inkomen). Aders van clusters in de rots, per laag een
## eigen soort, plus clusters die uit grotwanden steken en een korte ader bij de landingsplek.
## - Plaatsing volgt uit de seed: elke peer maakt dezelfde clusters zonder netwerkverkeer.
## - Delven: de client meldt een treffer, de host beslist (levens, ertszak) en verspreidt.
## - Ertszak per speler (max ore.bag_capacity). Storten in de trechter van de Mol (host).
## - Wat in de Mol zit, telt bij de extractie. Wie achterblijft, verliest zijn zak.
## Staat op elk peer op Game/Ores zodat RPC's aankomen.

signal bag_changed(peer_id: int)
signal hold_changed
signal cluster_hit(cluster: OreCluster, peer_id: int)
## Enkel bij wie het overkomt: zak vol.
signal bag_full

var game: Node # Game
var clusters: Array[OreCluster] = []
## peer_id -> PackedInt32Array (eenheden per OreKinds.Kind)
var bags: Dictionary = {}
## Eenheden per soort in de Mol.
var hold := PackedInt32Array([0, 0, 0, 0])

var _last_hit: Dictionary = {} # host: peer_id -> tijd (s)
var _glint_timer := 0.0
var _last_hit_pos := Vector3.ZERO # lokaal: waar je laatst erts raakte (voor de "+1")


## Rots laten glinsteren rond de clusters die het dichtst bij de camera liggen.
func _process(delta: float) -> void:
	_glint_timer -= delta
	if _glint_timer > 0.0 or game == null or game.terrain == null:
		return
	_glint_timer = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam:
		game.terrain.set_ore_glints(nearest(cam.global_position, 16, 40.0))


func generate(planet_seed: int) -> void:
	var t: TerrainAPI = game.terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 7919 + 23
	var size := t.world_size()
	# 1. Een korte ader koper vlak bij de landingsplek (eerste minuut: meteen iets te delven).
	var spawn := t.spawn_point()
	var a := rng.randf() * TAU
	var start := spawn + Vector3(cos(a), 0, sin(a)) * rng.randf_range(6.0, 10.0)
	start.y = t.surface_height_at(start.x, start.z) - 1.4
	_vein(rng, start, Vector3(sin(a), -0.1, -cos(a)).normalized(), 5)
	# 2. Aders per laag: meer in de bovenste lagen, waar je het eerst komt.
	var per_layer := [Tuning.get_i("ore", "veins_kristal", 8), Tuning.get_i("ore", "veins_graniet", 10),
			Tuning.get_i("ore", "veins_zandsteen", 12), Tuning.get_i("ore", "veins_klei", 10)]
	var bottoms := [4.0, Strata.TOPS_M[0], Strata.TOPS_M[1], Strata.TOPS_M[2]]
	for layer in 4:
		for v in per_layer[layer]:
			var top: float = Strata.TOPS_M[layer] if layer < 3 else size.y - 30.0
			var p := Vector3(rng.randf_range(10.0, size.x - 10.0), rng.randf_range(bottoms[layer] + 3.0, top - 3.0),
					rng.randf_range(10.0, size.z - 10.0))
			if layer == 3:
				p.y = minf(p.y, t.surface_height_at(p.x, p.z) - 3.0)
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.25, 0.25), rng.randf_range(-1, 1)).normalized()
			_vein(rng, p, dir, rng.randi_range(5, 9))
	# 3. Uit grotwanden: meteen te zien van in de grot.
	var caves := t.caves()
	for i in Tuning.get_i("ore", "cave_clusters", 36):
		var c: Vector4 = caves[rng.randi() % caves.size()]
		var ang := rng.randf() * TAU
		var dir := Vector3(cos(ang), rng.randf_range(-0.3, 0.2), sin(ang)).normalized()
		# Vanuit het midden naar buiten tot net in de rots.
		var p := Vector3(c.x, c.y, c.z)
		for k in 80:
			p += dir * 0.35
			if t.generated_rock_depth(p) > 0.15:
				break
		_add(rng, p, -dir)
	# 4. Extra aders als de opdracht "ertsaders" heeft (Contracts, F1): in klei en zandsteen.
	for v in Contracts.extra_veins(game.company.world_mods if game.company else []):
		var layer := 2 + (v % 2) # zandsteen, klei
		var top: float = Strata.TOPS_M[layer] if layer < 3 else size.y - 30.0
		var p := Vector3(rng.randf_range(10.0, size.x - 10.0), rng.randf_range(bottoms[layer] + 3.0, top - 3.0),
				rng.randf_range(10.0, size.z - 10.0))
		if layer == 3:
			p.y = minf(p.y, t.surface_height_at(p.x, p.z) - 3.0)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.25, 0.25), rng.randf_range(-1, 1)).normalized()
		_vein(rng, p, dir, rng.randi_range(5, 9))
	print("[ore] %d ertsclusters geplaatst (seed %d)" % [clusters.size(), planet_seed])


## Nieuwe wereld: alle clusters weg (zakken en laadruim blijven: dat is buit van de ploeg).
func clear() -> void:
	for c in clusters:
		c.queue_free()
	clusters.clear()


## Een ader: `count` clusters langs een licht kronkelende lijn.
func _vein(rng: RandomNumberGenerator, start: Vector3, dir: Vector3, count: int) -> void:
	var p := start
	for i in count:
		_add(rng, p, Vector3.ZERO)
		dir = (dir + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.15, 0.15), rng.randf_range(-0.4, 0.4))).normalized()
		p += dir * rng.randf_range(1.8, 3.0)


## Eén cluster, als hij in de rots zit en binnen de planeet. `out`: richting waarin hij uitsteekt
## (nul = willekeurig). Altijd evenveel getallen uit de rng: elke peer plaatst hetzelfde.
func _add(rng: RandomNumberGenerator, pos: Vector3, out: Vector3) -> void:
	var t: TerrainAPI = game.terrain
	var size := t.world_size()
	var units := rng.randi_range(Tuning.get_i("ore", "units_min", 4), Tuning.get_i("ore", "units_max", 6))
	var variant := rng.randi() % OreKinds.VARIANTS
	var up := out if out.length() > 0.1 else Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	var spin := rng.randf() * TAU
	if pos.x < 4.0 or pos.z < 4.0 or pos.x > size.x - 4.0 or pos.z > size.z - 4.0 or pos.y < 4.0:
		return
	if t.generated_rock_depth(pos) < 0.1:
		return
	var c := OreCluster.new()
	c.setup(clusters.size(), OreKinds.for_layer(t.layer_at(pos)), units, variant)
	add_child(c)
	var basis := Basis(Quaternion(Vector3.UP, up.normalized())) * Basis(Vector3.UP, spin)
	c.global_transform = Transform3D(basis, pos)
	clusters.append(c)


func cluster(id: int) -> OreCluster:
	return clusters[id] if id >= 0 and id < clusters.size() else null


func bag_of(peer_id: int) -> PackedInt32Array:
	return bags.get(peer_id, PackedInt32Array([0, 0, 0, 0]))


static func units(counts: PackedInt32Array) -> int:
	var n := 0
	for c in counts:
		n += c
	return n


static func value(counts: PackedInt32Array) -> int:
	var v := 0
	for k in counts.size():
		v += counts[k] * OreKinds.value(k)
	return v


## Dichtstbijzijnde clusters met erts (voor het glinsteren in de rots-shader): [Vector4(x, y, z, soort)].
func nearest(world: Vector3, count: int, max_dist: float) -> Array[Vector4]:
	var found: Array = []
	for c in clusters:
		if c.depleted():
			continue
		var d := c.global_position.distance_squared_to(world)
		if d < max_dist * max_dist:
			found.append([d, c])
	found.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var out: Array[Vector4] = []
	for i in mini(count, found.size()):
		var c: OreCluster = found[i][1]
		var p := c.global_position + c.global_basis.y * 0.2
		out.append(Vector4(p.x, p.y, p.z, float(c.kind)))
	return out


# --- Delven ---------------------------------------------------------------------

## Lokaal gereedschap raakt een cluster. Juice doet het gereedschap zelf meteen.
func hit(cluster_id: int, tool: Strata.Tool, pos: Vector3) -> void:
	_last_hit_pos = pos
	if Net.is_host():
		_apply_hit(Net.my_id(), cluster_id, tool, pos)
	else:
		_rpc_hit.rpc_id(1, cluster_id, tool, pos)


@rpc("any_peer", "reliable")
func _rpc_hit(cluster_id: int, tool: int, pos: Vector3) -> void:
	if multiplayer.is_server():
		_apply_hit(multiplayer.get_remote_sender_id(), cluster_id, tool, pos)


func _apply_hit(sender: int, cluster_id: int, tool: int, pos: Vector3) -> void:
	var c := cluster(cluster_id)
	if c == null or c.depleted():
		return
	var player: Node3D = game.player_node(sender)
	if player == null or player.global_position.distance_to(pos) > 4.5 or c.global_position.distance_to(pos) > 1.5:
		print("[ore] treffer op %d geweigerd: te ver of geen speler" % cluster_id)
		return
	var drill := tool != Strata.Tool.HOUWEEL
	var now := Time.get_ticks_msec() / 1000.0
	var min_gap := Tuning.get_f("finds", "drill_min_interval" if drill else "pickaxe_min_interval", 0.1) / Tuning.get_f("dig", "host_slack", 2.0)
	if now - float(_last_hit.get(sender, -100.0)) < min_gap:
		return
	_last_hit[sender] = now
	var bag := bag_of(sender)
	if units(bag) >= Tuning.get_i("ore", "bag_capacity", 40):
		if sender == multiplayer.get_unique_id():
			bag_full.emit()
		else:
			_rpc_full.rpc_id(sender)
		return
	var hp := c.hp - (Tuning.get_f("ore", "drill_per_tick", 0.34) if drill else 1.0)
	var gained := int(ceil(c.hp - 0.001)) - int(ceil(maxf(hp, 0.0) - 0.001))
	if gained > 0:
		bag[c.kind] += gained
		_rpc_bag.rpc(sender, bag)
	_rpc_cluster.rpc(cluster_id, maxf(hp, 0.0), sender)


@rpc("authority", "call_local", "reliable")
func _rpc_cluster(cluster_id: int, hp: float, by: int) -> void:
	var c := cluster(cluster_id)
	if c == null:
		return
	c.set_hp(hp)
	cluster_hit.emit(c, by)
	if c.depleted():
		var col: Color = OreKinds.COLORS[c.kind]
		game.fx.crust_break(c.global_position + c.global_basis.y * 0.2, 0.3, col, col.lightened(0.3), 0.55)


@rpc("authority", "call_local", "reliable")
func _rpc_bag(peer_id: int, counts: PackedInt32Array) -> void:
	var before := bag_of(peer_id)
	bags[peer_id] = counts
	# Erin: "+1 Copper" waar je hakte (gevoel-16), enkel bij wie het overkomt.
	if peer_id == multiplayer.get_unique_id() and game and game.fx:
		for k in counts.size():
			var gained := counts[k] - (before[k] if k < before.size() else 0)
			if gained > 0:
				game.fx.float_text(_last_hit_pos + Vector3(0, 0.25, 0), "+%d %s" % [gained, OreKinds.NAMES[k]],
						OreKinds.COLORS[k].lightened(0.35), 0.6, 1.1)
	bag_changed.emit(peer_id)


@rpc("authority", "reliable")
func _rpc_full() -> void:
	bag_full.emit()


# --- Storten in de Mol --------------------------------------------------------

## De lokale speler stort zijn ertszak in de trechter van de Mol.
func deposit() -> void:
	if Net.is_host():
		_deposit(Net.my_id())
	else:
		_rpc_deposit.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_deposit() -> void:
	if multiplayer.is_server():
		_deposit(multiplayer.get_remote_sender_id())


func _deposit(sender: int) -> void:
	var player: Node3D = game.player_node(sender)
	var mol: Mol = game.mol
	var bag := bag_of(sender)
	if player == null or mol == null or units(bag) == 0:
		return
	if player.global_position.distance_to(mol.chute_position()) > 3.5:
		print("[ore] storten door %d geweigerd: te ver van de trechter" % sender)
		return
	var new_hold := hold.duplicate()
	for k in bag.size():
		new_hold[k] += bag[k]
	_rpc_hold.rpc(new_hold)
	_rpc_bag.rpc(sender, PackedInt32Array([0, 0, 0, 0]))


@rpc("authority", "call_local", "reliable")
func _rpc_hold(counts: PackedInt32Array) -> void:
	var before := value(hold)
	var poured := PackedInt32Array([0, 0, 0, 0])
	for k in counts.size():
		poured[k] = maxi(0, counts[k] - (hold[k] if k < hold.size() else 0))
	hold = counts
	# Gestort (gevoel-16): een stroom brokjes in de trechter, gerammel en "+€X" erboven.
	var gain := value(counts) - before
	var mol: Mol = game.mol if game else null
	if gain > 0 and mol and mol.body and game.fx:
		game.fx.ore_pour(mol.chute_position(), poured, gain)
	hold_changed.emit()


## Host: na de extractie. Het laadruim is verkocht; wie achterbleef, is zijn zak kwijt.
## Host: de ertszak van een speler is weg (zijn robot smolt).
func host_lose_bag(peer: int) -> void:
	_rpc_bag.rpc(peer, PackedInt32Array([0, 0, 0, 0]))


func host_after_extraction(left_behind: Array) -> void:
	_rpc_hold.rpc(PackedInt32Array([0, 0, 0, 0]))
	for peer: int in left_behind:
		_rpc_bag.rpc(peer, PackedInt32Array([0, 0, 0, 0]))


# --- Late joiners ------------------------------------------------------------

func snapshot() -> Array:
	var changed: Array = []
	for c in clusters:
		if c.hp < c.max_hp:
			changed.append([c.cluster_id, c.hp])
	return [changed, bags.duplicate(true), hold]


func apply_snapshot(state: Array) -> void:
	if state.size() < 3:
		return
	for e: Array in state[0]:
		var c := cluster(e[0])
		if c:
			c.set_hp(e[1])
	bags = (state[1] as Dictionary).duplicate(true)
	hold = state[2]
