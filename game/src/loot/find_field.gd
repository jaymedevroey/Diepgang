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
## Een breekbare vondst brak (harde klap): op elk peer. Haak voor het geluid (M6).
signal shattered(item: FindItem)

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
var _drag_last := {} # host: find_id -> plek bij de vorige tick (slepen schuurt)
var _drag_worn := {} # host: find_id -> geschuurde gaafheid die nog niet gemeld is
var _freed_at := {} # host: find_id -> tijd (ms) van het vrijkomen (zie _check_impact)
var _by_id := {} # find_id -> FindItem (items blijft niet op volgorde: het magma haalt er weg)
var _next_id := 0


## Alle vondsten van deze wereld, per planeet anders (PlanetLoot, planets.cfg; release-audit ontwerp-5):
## de buit ligt geconcentreerd in fossielbedden (één skelet per bed, een set), kampen, kristalgrotten
## en rond grotten, en minder verspreid (GDD §4).
func generate(pit_seed: int) -> void:
	var t_start := Time.get_ticks_msec()
	var t: TerrainAPI = game.terrain
	var planet := int(game.planet_type)
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
	var caves := t.caves()
	# 2. Fossielbedden: één skelet per bed, de stukken liggen zoals in het beest (PlanetLoot.SLOTS). Plus
	# extra bedden als de opdracht "rijke fossielbedden" heeft (Contracts, F1), bovenop die van de planeet.
	var beds := PlanetLoot.count(planet, "beds", 8) + Contracts.extra_beds(game.company.world_mods if game.company else [])
	var deep := PlanetLoot.count(planet, "deep_beds", 2)
	var surface_y := t.surface_height_at(spawn.x, spawn.z)
	for b in beds + deep:
		var titan := rng.randf() < PlanetLoot.value(planet, "titan_share", 0.0)
		var lo := Strata.TOPS_M[1] + 6.0
		var hi := surface_y - PlanetLoot.value(planet, "bed_top_m", 74.0)
		if b >= beds: # diep, in het graniet (boor T2)
			lo = Strata.TOPS_M[0] + 8.0
			hi = Strata.TOPS_M[1] - 4.0
		var near_cave := rng.randf() < PlanetLoot.value(planet, "bed_cave_share", 0.5)
		var center := _bed_center(rng, caves, lo, maxf(hi, lo + 4.0), near_cave)
		_place_set(rng, center, "titan" if titan else "strider", "%d-%d" % [pit_seed, b])
	# 3. Kampen van vorige bezoekers (rommel in de klei) en kristalgrotten (kristallen rond een grot).
	for i in PlanetLoot.count(planet, "camps", 0):
		var c := Vector3(rng.randf_range(14.0, size.x - 14.0), 0.0, rng.randf_range(14.0, size.z - 14.0))
		c.y = t.surface_height_at(c.x, c.z) - rng.randf_range(5.0, 38.0)
		_place_heap(rng, c, PlanetLoot.CAMP_POOL, 2.4)
	for i in PlanetLoot.count(planet, "pockets", 0):
		var cv := _cave_between(rng, caves, Strata.TOPS_M[1] + 4.0, surface_y - 12.0)
		var a0 := rng.randf() * TAU
		_place_pocket(rng, cv, a0)
	# 4. Rond grotten: een handvol rijke grotten, elk met een groepje vondsten net achter één stuk wand
	# (te vinden van in de grot; GDD §4: rijke zakken rond grotten, niet uniform).
	var rich: Array[Vector4] = []
	var arcs: Array[float] = []
	for i in maxi(1, PlanetLoot.count(planet, "rich_caves", 10)):
		rich.append(caves[rng.randi() % caves.size()])
		arcs.append(rng.randf() * TAU)
	for i in PlanetLoot.count(planet, "near_caves", 45):
		var c: Vector4 = rich[i % rich.size()]
		var a0: float = arcs[i % rich.size()]
		_place(rng, func() -> Array:
			var a := a0 + rng.randf_range(-0.55, 0.55)
			var r := c.w + rng.randf_range(0.8, 3.0)
			return [Vector3(c.x + cos(a) * r, c.y + rng.randf_range(-0.4, 0.4) * c.w / PlanetGenerator.CAVERN_SQUASH, c.z + sin(a) * r), -1])
	# 5. Verspreid, op elke diepte (opzij is evenveel te vinden als diep: geen "recht naar beneden").
	for i in PlanetLoot.count(planet, "scattered", 60):
		_place(rng, func() -> Array:
			var p := Vector3(rng.randf_range(8.0, size.x - 8.0), 0, rng.randf_range(8.0, size.z - 8.0))
			p.y = rng.randf_range(6.0, t.surface_height_at(p.x, p.z) - 2.0)
			return [p, -1])
	# 6. Bij de set pieces in de grotten (golf 3, CaveSetPieces): goede buit in de wanden en de vloer
	# errond. Achteraan, zodat alles hierboven op dezelfde plek blijft.
	for sp: Dictionary in t.set_pieces():
		_place_setpiece_loot(rng, sp)
	print("[finds] %d vondsten geplaatst op %s (seed %d, %d skeletten) in %d ms" % [items.size(),
			PlanetType.NAMES[clampi(planet, 0, 2)], pit_seed, sets().size(), Time.get_ticks_msec() - t_start])


## Midden van een bed tussen hoogte lo en hi: naast een grot (als die er in die band is), anders ergens
## in de rots, weg van de rand.
func _bed_center(rng: RandomNumberGenerator, caves: Array[Vector4], lo: float, hi: float, near_cave: bool) -> Vector3:
	var size: Vector3 = game.terrain.world_size()
	var c := Vector3(rng.randf_range(16.0, size.x - 16.0), rng.randf_range(lo, hi), rng.randf_range(16.0, size.z - 16.0))
	if near_cave:
		var cv := _cave_between(rng, caves, lo, hi)
		if cv.w > 0.0:
			var a := rng.randf() * TAU
			var r := cv.w + rng.randf_range(3.0, 5.5)
			c = Vector3(clampf(cv.x + cos(a) * r, 16.0, size.x - 16.0), clampf(cv.y, lo, hi), clampf(cv.z + sin(a) * r, 16.0, size.z - 16.0))
	return c


## Een willekeurige grot met zijn midden tussen lo en hi (w = 0 als er geen is). Altijd één getal uit de rng.
func _cave_between(rng: RandomNumberGenerator, caves: Array[Vector4], lo: float, hi: float) -> Vector4:
	var pick := rng.randi()
	var ok: Array[Vector4] = []
	for cv in caves:
		if cv.y >= lo and cv.y <= hi:
			ok.append(cv)
	return ok[pick % ok.size()] if not ok.is_empty() else Vector4.ZERO


## Eén skelet in een bed: de stukken langs een rug in een willekeurige richting, kop vooraan en
## paren links en rechts (PlanetLoot.SLOTS). Pas als er minstens 3 stukken in de rots passen, is het
## een set (set_size = wat er echt ligt: anders kan je hem nooit compleet maken).
func _place_set(rng: RandomNumberGenerator, center: Vector3, set_key: String, id: String) -> void:
	var spec: Dictionary = PlanetLoot.SETS[set_key]
	var kinds := PlanetLoot.set_pieces(rng, set_key)
	var a := rng.randf() * TAU
	var axis := Vector3(cos(a), rng.randf_range(-0.12, 0.12), sin(a)).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var half: float = spec.half_len
	var placed: Array[FindItem] = []
	var seen := {}
	var core_missing := false
	for k in kinds:
		var slot: Array = PlanetLoot.SLOTS.get(k, [0.0, false])
		var n: int = seen.get(k, 0)
		seen[k] = n + 1
		# Herhaalde soorten (twee dijbenen, drie ruggenstukken) schuiven op langs de rug of wisselen van kant.
		var along: float = float(slot[0]) * half + (n * 1.9 if not slot[1] else (n / 2) * 1.6)
		var lateral := (1.6 if n % 2 == 0 else -1.6) if slot[1] else 0.0
		var it := _place(rng, func() -> Array:
			var p := center + axis * along + side * lateral
			p += Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
			return [p, k], 14)
		if it:
			placed.append(it)
		elif k in spec.core:
			core_missing = true
	if placed.size() < 3 or core_missing:
		return # te weinig plaats (een grot, de rand) of zonder schedel: losse botten, geen set
	for it in placed:
		it.set_id = id
		it.set_size = placed.size()
		it.set_name = str(spec.name)


## Een hoopje (kamp van vorige bezoekers): 3-5 stukken uit `pool` in een kring van `radius` m.
func _place_heap(rng: RandomNumberGenerator, center: Vector3, pool: Array, radius: float) -> void:
	var n := rng.randi_range(3, 5)
	for i in n:
		var k: int = pool[rng.randi() % pool.size()]
		var a := float(i) / n * TAU + rng.randf_range(-0.3, 0.3)
		_place(rng, func() -> Array:
			return [center + Vector3(cos(a) * radius, rng.randf_range(-0.6, 0.6), sin(a) * radius), k], 10)


## Buit bij een set piece (CaveSetPieces.plan_list): loot_min..loot_max vondsten uit de pot van die
## soort (het kamp: munten, rommel, een lamp en een goudklomp), de helft in de wand rond het tafereel
## en de helft net onder de vloer ernaast. Uit de seed, zoals al de rest.
func _place_setpiece_loot(rng: RandomNumberGenerator, sp: Dictionary) -> void:
	var pool: Array = CaveSetPieces.LOOT[int(sp.kind)]
	var c: Vector4 = sp.cave
	var a: Vector3 = sp.anchor
	var n := rng.randi_range(Tuning.get_i("setpieces", "loot_min", 4), Tuning.get_i("setpieces", "loot_max", 6))
	if sp.starter:
		n = Tuning.get_i("setpieces", "starter_loot", 7)
	for k in n:
		var kind: int = pool[k % pool.size()] if k < pool.size() else pool[rng.randi() % pool.size()]
		var in_wall := k % 2 == 0
		_place(rng, func() -> Array:
			var ang := rng.randf() * TAU
			if in_wall:
				# Net achter de wand op die hoogte (een grot is een platgedrukte bol).
				var y := a.y + rng.randf_range(0.6, 2.4)
				var e := clampf((y - c.y) * PlanetGenerator.CAVERN_SQUASH / c.w, -1.0, 1.0)
				var r := c.w * sqrt(1.0 - e * e) + rng.randf_range(0.7, 1.8)
				return [Vector3(c.x + cos(ang) * r, y, c.z + sin(ang) * r), kind]
			var d := rng.randf_range(1.5, minf(c.w * 0.8, 6.0))
			return [Vector3(a.x + cos(ang) * d, a.y - rng.randf_range(1.2, 2.0), a.z + sin(ang) * d), kind], 14)


## Kristalgrot: 3-5 kristallen net achter de wand van grot `cv`, samen in een boog van ±70°.
func _place_pocket(rng: RandomNumberGenerator, cv: Vector4, a0: float) -> void:
	if cv.w <= 0.0:
		return
	for i in rng.randi_range(3, 5):
		var k: int = PlanetLoot.POCKET_POOL[rng.randi() % PlanetLoot.POCKET_POOL.size()]
		_place(rng, func() -> Array:
			var a := a0 + rng.randf_range(-0.6, 0.6)
			var r := cv.w + rng.randf_range(0.7, 1.8)
			return [Vector3(cv.x + cos(a) * r, cv.y + rng.randf_range(-0.5, 0.3) * cv.w / PlanetGenerator.CAVERN_SQUASH,
					cv.z + sin(a) * r), k], 12)


## Skeletten in deze wereld: set_id -> [stukken]. Voor tests, schermen en de taxatie (F1).
func sets() -> Dictionary:
	var out := {}
	for it in items:
		if it.set_id != "":
			if not out.has(it.set_id):
				out[it.set_id] = []
			(out[it.set_id] as Array).append(it)
	return out


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
	_drag_last.clear()
	_drag_worn.clear()
	_freed_at.clear()


## Eén vondst plaatsen. `where` geeft [positie, soort] terug (soort -1 = volgens de laag en de
## planeet). Tot `attempts` pogingen voor een plek in de rots, weg van de landingsplek en van andere
## vondsten (grote stukken houden meer afstand: hun korsten mogen niet overlappen). Altijd evenveel
## getallen uit de rng per poging: elke peer plaatst hetzelfde. Geeft de vondst terug, of null.
func _place(rng: RandomNumberGenerator, where: Callable, attempts := 40) -> FindItem:
	var t: TerrainAPI = game.terrain
	var sc := t.shaft_center_world()
	for attempt in attempts:
		var res: Array = where.call()
		var pos: Vector3 = res[0]
		var forced: int = res[1]
		var rot := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var kind: FindKinds.Kind = forced if forced >= 0 else FindKinds.pick_kind(rng, pos.y, t.layer_at(pos), int(game.planet_type))
		var flat := Vector2(pos.x - sc.x, pos.z - sc.z).length()
		if flat < 6.0 or pos.y < 4.0 or t.generated_rock_depth(pos) < 1.0 or not _far_from_others(pos, FindKinds.radius(kind)):
			continue
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
		return item
	return null


## Levens van de korst (ontwerp-11): hoe waardevoller de vondst, hoe meer geduld met het houweel
## (rommel ±4 s, kostbaar ±6,5 s bij 0,55 s per slag).
static func crust_hp_of(it: FindItem) -> float:
	return Tuning.get_f("finds", "crust_hp", 7.0) + Tuning.get_f("finds", "crust_hp_per_class", 2.0) * it.value_class


## `radius`: straal van de korst van de nieuwe vondst (FindKinds.radius). Twee korsten houden minstens
## min_spacing uit elkaar, en grote (Titan) zoveel als hun stralen samen plus een marge.
func _far_from_others(pos: Vector3, radius := 0.0) -> bool:
	var min_gap := Tuning.get_f("finds", "min_spacing", 2.0)
	for other in items:
		var gap := maxf(min_gap, radius + FindKinds.radius(other.kind) + 0.3)
		if other.global_position.distance_to(pos) < gap:
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
		# Breekbaar (kristallen, Kristalmaan): het trillen van de boor kost meer (houweel blijft veilig).
		var loss := Tuning.get_f("finds", "drill_condition_loss", 0.014) * (Tuning.get_f("finds", "drill_hot_factor", 2.2) if hot else 1.0) \
				* (1.0 + it.fragility * Tuning.get_f("finds", "drill_fragile_factor", 1.2))
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
	it.update_glow()
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
		_freed_at[find_id] = Time.get_ticks_msec()
		var push := Vector3.UP * Tuning.get_f("finds", "free_impulse", 2.0)
		if toward.length() > 0.1:
			var flat := Vector3(toward.x, 0.0, toward.z)
			if flat.length() > 0.05:
				push += flat.normalized() * Tuning.get_f("finds", "free_toward", 1.0)
		it.apply_central_impulse(push * it.mass)
	find_freed.emit(it)


## Naam en waardeklasse groot boven de vondst. De waarde zelf blijft verborgen tot de taxatiepoort
## aan boord (F1, ontwerp-9: Appraisal); de glans en deze regel verraden enkel de klasse.
func _reveal_text(it: FindItem) -> void:
	var col: Color = FindKinds.CLASS_GLINT[it.value_class]
	var at := it.global_position + Vector3(0, it.half_extents.length() + 0.25, 0)
	game.fx.float_text(at, it.display_name().to_upper(), col.lerp(Color.WHITE, 0.2), 1.0 + 0.15 * it.value_class, 2.6)
	game.fx.float_text(at - Vector3(0, 0.13, 0), FindKinds.CLASS_NAMES[it.value_class].to_upper(), Color(0.95, 0.92, 0.82), 0.6, 2.6)


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


## Host: een vondst uit het laadruim op de grond zetten (te zwaar voor de grijper, F1): los van
## wie hem droeg, niet meer vastgesjord in de Mol, stil op `world`.
func host_eject(find_id: int, world: Vector3) -> void:
	var it := item(find_id)
	if it == null:
		return
	for peer in it.carriers.duplicate():
		_release(peer, find_id, it.global_transform, Vector3.ZERO)
	_stowed.erase(find_id)
	_prev_velocity.erase(find_id)
	it.global_position = world
	it.reset_physics_interpolation()
	it.last_safe = world
	it.freeze = false
	it.linear_velocity = Vector3.ZERO
	it.angular_velocity = Vector3.ZERO
	it.sleeping = false


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


## Waar een gedragen vondst hoort: tussen de handen van zijn dragers, niet door een muur. Te zwaar om
## alleen te tillen (ontwerp-8): dan sleept de enige drager hem over de grond (drag_point).
func carry_target(it: FindItem) -> Vector3:
	if it.dragged():
		var dragger: Player = game.player_node(it.carriers[0])
		if dragger:
			return drag_point(dragger, it)
	var sum := Vector3.ZERO
	var n := 0
	for peer in it.carriers:
		var p: Player = game.player_node(peer)
		if p:
			sum += p.hold_point(it.half_extents.length())
			n += 1
	return sum / n if n > 0 else it.global_position


## Waar een gesleepte vondst ligt: vlak voor de voeten van wie sleept, met zijn onderkant op de grond
## (de rots, of de vloer van de Mol en de hub). Op elk peer dezelfde regel (host, drager, kijkers).
func drag_point(p: Player, it: FindItem) -> Vector3:
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var at := p.global_position + fwd * (Tuning.get_f("carry", "drag_near", 0.45) + it.half_extents.length())
	var hit: Dictionary = game.terrain.raycast(at + Vector3(0, 1.2, 0), at - Vector3(0, 2.0, 0), Layers.TERRAIN | Layers.LIFT)
	var ground: float = hit.position.y if not hit.is_empty() else p.global_position.y
	at.y = ground + it.bottom_offset(it.global_basis) + 0.03
	return at


## Host: slepen schuurt (ontwerp-8: alleen kan, maar het kost). Per meter carry.drag_wear gaafheid,
## gemeld per stapje van 2 % (anders een melding per tick).
func _drag_wear(it: FindItem) -> void:
	var last: Variant = _drag_last.get(it.find_id)
	var here := it.global_position
	_drag_last[it.find_id] = here
	if last == null:
		return
	var moved := here.distance_to(last as Vector3)
	if moved > 1.5: # een sprong (de Mol, een teleport): niet geschuurd
		return
	var worn: float = _drag_worn.get(it.find_id, 0.0) + moved * Tuning.get_f("carry", "drag_wear", 0.004)
	if worn >= 0.02 and it.condition > Tuning.get_f("finds", "min_condition", 0.25):
		_rpc_condition.rpc(it.find_id, maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - worn))
		worn = 0.0
	_drag_worn[it.find_id] = worn


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
			if it.dragged():
				_drag_wear(it)
			else:
				_drag_last.erase(it.find_id)
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


## Host: harde klap (vallen, gooien, botsen) kost gaafheid (GDD §3: botst, breekt). Breekbare vondsten
## (FindItem.fragility, Kristalmaan) voelen al een kleinere klap, verliezen per klap meer, en boven
## finds.shatter_dv / breekbaarheid breken ze: bijna niets meer waard, het licht gaat uit.
func _check_impact(it: FindItem) -> void:
	var v := it.linear_velocity
	var prev: Vector3 = _prev_velocity.get(it.find_id, v)
	_prev_velocity[it.find_id] = v
	var dv := (v - prev).length()
	# Het sprongetje bij het vrijkomen (gevoel-03) mag een kristal niet kraken: even geen klappen tellen.
	if Time.get_ticks_msec() < int(_freed_at.get(it.find_id, -100000)) + int(Tuning.get_f("finds", "free_grace_s", 1.5) * 1000.0):
		return
	var cond := impact_condition(it, dv)
	if cond < it.condition - 0.001:
		_rpc_condition.rpc(it.find_id, cond)


## Gaafheid na een klap met snelheidsverandering `dv` (m/s). Dezelfde regel voor tests en de host.
static func impact_condition(it: FindItem, dv: float) -> float:
	var frag := it.fragility
	var threshold := Tuning.get_f("carry", "impact_threshold", 3.0) / (1.0 + frag * Tuning.get_f("finds", "fragile_threshold_factor", 1.2))
	if dv <= threshold or it.is_shattered():
		return it.condition
	if frag > 0.0 and dv >= Tuning.get_f("finds", "shatter_dv", 4.5) / frag:
		return minf(it.condition, Tuning.get_f("finds", "shatter_condition", 0.08))
	var rate := Tuning.get_f("carry", "impact_damage", 0.06) * (1.0 + frag * Tuning.get_f("finds", "fragile_damage_factor", 2.0))
	var cap := Tuning.get_f("carry", "impact_max_loss", 0.3) * (1.0 + frag * 0.5)
	var loss := minf((dv - threshold) * rate, cap)
	return minf(it.condition, maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss))


## Schade zie je meteen (gevoel-06, plezier-en-design §10): "−X%" boven de vondst, een krak (de
## bestaande tok, M6 brengt een eigen geluid) en schilfers. Het signaal condition_changed blijft
## voor de HUD en het robotgezicht.
@rpc("authority", "call_local", "reliable")
func _rpc_condition(find_id: int, cond: float) -> void:
	var it := item(find_id)
	if it == null:
		return
	var hard := cond < it.condition - 0.001
	var before := it.value()
	var before_cond := it.condition
	var was_whole := not it.is_shattered()
	it.condition = cond
	it.update_glow()
	if hard and was_whole and it.is_shattered():
		# Gebroken (breekbaar kristal na een harde klap): scherven in zijn kleur, het licht gaat uit.
		var col: Color = FindKinds.GLOW.get(it.kind, Color(0.75, 0.6, 0.95))
		game.fx.crust_break(it.global_position, it.half_extents.length(), col.darkened(0.2), col, 0.8)
		game.fx.float_text(it.global_position + Vector3(0, it.half_extents.length() + 0.2, 0), "SHATTERED",
				Color(1.0, 0.32, 0.22), 1.0, 2.0)
		shattered.emit(it)
	elif hard:
		# De gaafheid die verloren ging, niet het bedrag: de waarde is pas aan boord bekend (F1).
		var lost := int(round((before_cond - cond) * 100.0))
		if lost > 0 and before > 0:
			game.fx.float_text(it.global_position + Vector3(0, it.half_extents.length() + 0.15, 0), "−%d%%" % lost,
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
