class_name Game
extends Node3D
## Een spelsessie: terrein, spelers en de sync ertussen.
## Staat op elk peer op hetzelfde pad (/root/Main/Game) zodat RPC's aankomen.
## Host (en solo): bouwt de wereld meteen. Client: vraagt de host om seed, op-logboek en
## de spelers die er al zijn; wie tijdens het laden graaft, komt via TerrainSync alsnog binnen.

signal world_loaded(stats: Dictionary)
signal player_spawned(player: Player)
signal player_removed(peer_id: int)
## Melding voor de HUD (bv. van het schip).
signal notice(text: String, kind: String)
## De lokale speler drukte E op de opdrachtterminal.
signal terminal_requested(player: Player)

## Eigen kleur per speler (GDD §8).
const COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.12), # amber
	Color(0.2, 0.75, 0.95), # cyaan
	Color(0.55, 0.88, 0.25), # limoen
	Color(0.9, 0.35, 0.72), # magenta
]

var terrain: TerrainAPI
var terrain_sync: TerrainSync
var finds: FindField
var ores: OreField
var surface: PlanetSurface
## Magma: de klok van een dienst (stijgt van onderen).
var magma: Magma
## Onrust (lawaai) en bevingen.
var unrest: Unrest
## Dreiging (pakket F2, GDD §6): neergaan en redden, de Graafworm met de lichtbakens, gasbellen en
## instortingen die met de diepte toenemen.
var rescue: Rescue
var worm: Worm
var beacons: Beacons
var gas: Gas
var collapse: Collapse
## De firma: kas, kwartaal, opdracht, rapport.
var company: Company
## Naam van de save van de firma (leeg = niet bewaren, bv. tests). Main zet dit.
var company_save := ""
## Type van de huidige planeet (hemel, zon, sfeer).
var planet_type := PlanetType.Id.ROESTBOL
var mol: Mol
## De Ekster: de hub (waar je rondloopt) en het schip boven de planeet, enkel als `start_on_ship`.
var ship: Ekster
var exterior: EksterExterior
## Het echte spel: spelers beginnen op De Ekster en de Mol staat in de dropbaai (GDD v3 §3).
## Uit voor scenario's die meteen op de planeet testen: dan staat de Mol aan de oppervlakte.
var start_on_ship := false
## Viewer boven de landingsplek: het terrein daar laadt al terwijl de ploeg op het schip is.
var landing_viewer: Node3D
var fx: DigFx
var players: Node3D
var local_player: Player
var pit_seed := 1
## Hoeveelste dienst (telt bij elke drop; wordt deel van de opdrachten, M3 stap 7).
var shift_number := 1
## Solo/host: ook een eigen speler spawnen. Uit voor scenario's zonder speler.
var spawn_host_player := true
var is_loaded := false
## Peers met een geladen wereld. Enkel die krijgen spelerstoestanden (anders "node not found").
var ready_peers: Array[int] = [1]

var _pending_spawns: Array = [] # client: spawns die binnenkomen voor het terrein geladen is
var _join_queue: Array[int] = [] # host: aanvragen voor de eigen wereld geladen is
var _world_seed_of := {} # host: peer -> seed van de wereld die bij die peer geladen is
var _color_of: Dictionary = {} # host: peer_id -> kleurindex
var _tuning_dirty := false
var _tuning_timer := 0.0


func _ready() -> void:
	fx = DigFx.new()
	fx.name = "DigFx"
	add_child(fx)
	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	terrain_sync = TerrainSync.new()
	terrain_sync.name = "TerrainSync"
	terrain_sync.game = self
	add_child(terrain_sync)
	terrain_sync.remote_op_applied.connect(_on_remote_op)
	finds = FindField.new()
	finds.name = "Finds"
	finds.game = self
	add_child(finds)
	ores = OreField.new()
	ores.name = "Ores"
	ores.game = self
	add_child(ores)
	magma = Magma.new()
	magma.name = "Magma"
	magma.game = self
	add_child(magma)
	unrest = Unrest.new()
	unrest.name = "Unrest"
	unrest.game = self
	add_child(unrest)
	terrain_sync.host_player_op.connect(unrest.host_player_op)
	rescue = Rescue.new()
	rescue.name = "Rescue"
	rescue.game = self
	add_child(rescue)
	worm = Worm.new()
	worm.name = "Worm"
	worm.game = self
	add_child(worm)
	beacons = Beacons.new()
	beacons.name = "Beacons"
	beacons.game = self
	add_child(beacons)
	gas = Gas.new()
	gas.name = "Gas"
	gas.game = self
	add_child(gas)
	collapse = Collapse.new()
	collapse.name = "Collapse"
	collapse.game = self
	add_child(collapse)
	terrain_sync.host_player_op.connect(worm.host_player_op)
	terrain_sync.host_player_op.connect(gas.host_player_op)
	company = Company.new()
	company.name = "Company"
	company.game = self
	add_child(company)
	Net.peer_left.connect(_on_peer_left)
	Tuning.changed.connect(func(_f: String, _k: String) -> void:
		if multiplayer.is_server():
			_tuning_dirty = true)


func start_host(seed_value: int) -> void:
	pit_seed = seed_value
	_build_terrain([])
	company.host_setup(company_save)


func start_client() -> void:
	_rpc_request_join.rpc_id(1)


func player_node(peer_id: int) -> Player:
	return players.get_node_or_null(str(peer_id)) as Player


# --- Wereld -------------------------------------------------------------------

func _build_terrain(ops: Array, finds_state: Array = [], ores_state: Array = []) -> void:
	is_loaded = false
	terrain = TerrainAPI.new()
	terrain.name = "Terrain"
	terrain.pit_seed = pit_seed
	terrain.planet = int(planet_type)
	add_child(terrain)
	# Het spel begint zodra het terrein rond de Mol (en de spawnplek erachter) er is.
	terrain.focus_world = terrain.shaft_center_world() + Vector3(0.0, terrain.surface_height_at(
			terrain.shaft_center_world().x, terrain.shaft_center_world().z), 4.0)
	surface = PlanetSurface.new()
	surface.name = "Surface"
	add_child(surface)
	surface.build(terrain, pit_seed, planet_type)
	finds.generate(pit_seed)
	finds.apply_snapshot(finds_state)
	ores.generate(pit_seed)
	ores.apply_snapshot(ores_state)
	magma.attach_terrain(terrain)
	unrest.attach_terrain(terrain)
	worm.attach_terrain(terrain)
	beacons.attach_terrain(terrain)
	gas.attach_terrain(terrain)
	collapse.attach_terrain(terrain)
	if start_on_ship and ship == null:
		exterior = EksterExterior.new()
		exterior.name = "EksterExterior"
		add_child(exterior)
		exterior.place_dock_at(EksterExterior.dock_above(terrain))
		ship = Ekster.new()
		ship.name = "Ekster"
		ship.game = self
		add_child(ship)
		ship.place_dock_at(exterior.dock_position() + Vector3(0.0, Ekster.HUB_ABOVE, 0.0))
	elif exterior:
		# Nieuwe wereld: het buitenschip hangt boven de nieuwe landingsplek. De hub blijft waar hij
		# is (een aparte ruimte; de sprong van de Mol gaat van baai naar baai).
		exterior.place_dock_at(EksterExterior.dock_above(terrain))
	if mol == null:
		mol = Mol.new()
		mol.name = "Mol"
		# Eerst de Mol, dan de spelers: wie meerijdt, volgt de Mol van deze tick (zie Player._ride_mol).
		mol.process_physics_priority = -10
		mol.game = self
		add_child(mol)
		mol.setup(ship != null)
		# De klok loopt vanaf de landing tot de Mol terug in de baai staat.
		mol.landed.connect(func() -> void:
			if multiplayer.is_server():
				magma.host_start(company.contract_magma())
				company.host_landed())
		mol.noise_made.connect(func(amount: float, _where: Vector3) -> void: unrest.host_add(amount))
		mol.noise_made.connect(worm.host_mol_noise)
		mol.landed.connect(func() -> void:
			if multiplayer.is_server():
				beacons.host_refill())
		# Einde van de dienst (aan boord, of zonder schip boven): iedereen weer heel.
		mol.summary.connect(func(_c: int, _v: int, _l: int) -> void:
			if multiplayer.is_server():
				rescue.host_reset_all())
	else:
		mol.attach_terrain()
	if ship:
		# Terrein rond de landingsplek laden zolang de ploeg boven is (en voor wie later springt).
		if landing_viewer == null:
			landing_viewer = Node3D.new()
			landing_viewer.name = "LandingViewer"
			add_child(landing_viewer)
		landing_viewer.global_position = terrain.focus_world
		terrain.add_viewer(landing_viewer, Tuning.get_f("terrain", "view_m", 110.0), Tuning.get_f("terrain", "collision_m", 48.0))
		for p: Player in players.get_children():
			_add_viewers(p)
	for op in ops:
		terrain.apply_op(op)
	terrain_sync.flush_pending()
	terrain.loaded.connect(_on_terrain_loaded)


## Nieuwe wereld (volgende dienst, nieuwe planeet): terrein, vondsten, erts en het landschap
## opnieuw uit een andere seed. De Mol, het schip en de spelers blijven.
func _rebuild_world(seed_value: int, planet := -1) -> void:
	pit_seed = seed_value
	if planet >= 0:
		planet_type = planet as PlanetType.Id
	# De oude wereld blijft tot het einde van dit beeld in de boom (verborgen, stil, met een andere
	# naam): godot_voxel werkt zijn terreinen pas later in het beeld bij en vroeg anders de plek op
	# van een terrein dat al uit de boom was ("!is_inside_tree", vooral in co-op).
	if surface:
		surface.abandon() # de werkthread leest het oude terrein nog
	for old: Node3D in [terrain, surface]:
		if old:
			old.name = String(old.name) + "_oud"
			old.process_mode = Node.PROCESS_MODE_DISABLED
			old.visible = false
			old.queue_free()
	finds.clear()
	ores.clear()
	if mol:
		mol.sonar.reset() # oude contacten wijzen naar vondsten die niet meer bestaan
	_build_terrain([])
	for p: Player in players.get_children():
		p.on_new_world()
	print("[game] nieuwe wereld: seed %d" % seed_value)


## Host: de volgende dienst gaat naar een nieuwe planeet (bij iedereen dezelfde seed).
func host_new_world(seed_value: int, planet := -1) -> void:
	_rebuild_world(seed_value, planet)
	for peer: int in multiplayer.get_peers():
		_rpc_new_world.rpc_id(peer, seed_value, int(planet_type))


@rpc("authority", "reliable")
func _rpc_new_world(seed_value: int, planet: int) -> void:
	_rebuild_world(seed_value, planet)


## Van de hub naar dezelfde plek t.o.v. de baai van het buitenschip (wie door de open baai van
## de hub valt, valt uit het schip boven de planeet).
func from_hub(world: Vector3) -> Vector3:
	return exterior.dock_position() + (world - ship.dock_transform().origin)


## Terminal op het schip (lokale speler drukte E).
func ship_terminal_used(p: Player) -> void:
	terminal_requested.emit(p)


## Host: een melding voor iedereen.
func notice_all(text: String, kind := "info") -> void:
	_rpc_notice.rpc(text, kind)


@rpc("authority", "call_local", "reliable")
func _rpc_notice(text: String, kind: String) -> void:
	notice.emit(text, kind)


func _on_terrain_loaded(stats: Dictionary) -> void:
	is_loaded = true
	world_loaded.emit(stats)
	if Net.is_host() and ship == null and not magma.running:
		magma.host_start() # zonder schip begint de dienst meteen
	if Net.is_host():
		if spawn_host_player:
			_color_of[1] = 0
			_spawn(1, 0, _spawn_pos(0))
		for id in _join_queue:
			_accept(id)
		_join_queue.clear()
	for s in _pending_spawns:
		_spawn(s[0], s[1], s[2])
	_pending_spawns.clear()
	if not Net.is_host():
		_rpc_peer_ready.rpc_id(1)
		_report_world_ready()


## Is deze wereld hier klaar om erin te droppen: het terrein geladen en het verre landschap
## gebouwd? (Anders val je in een vierkant zonder omgeving.)
func world_ready() -> bool:
	return terrain != null and terrain.is_loaded and (surface == null or surface.is_built)


## Client: de host laten weten dat deze wereld hier klaar is (pas als ook het verre landschap staat).
func _report_world_ready() -> void:
	if surface != null and not surface.is_built:
		if not surface.built.is_connected(_report_world_ready):
			surface.built.connect(_report_world_ready, CONNECT_ONE_SHOT)
		return
	_rpc_world_ready.rpc_id(1, pit_seed)


## Host: heeft iedereen die meespeelt de huidige wereld geladen? (Pas dan mag de Mol droppen,
## anders valt een client in een wereld die er bij hem nog niet is.)
func world_ready_everywhere() -> bool:
	if not is_loaded or not world_ready():
		return false
	for id in multiplayer.get_peers():
		if ready_peers.has(id) and int(_world_seed_of.get(id, -1)) != pit_seed:
			return false
	return true


@rpc("any_peer", "reliable")
func _rpc_world_ready(seed_value: int) -> void:
	if multiplayer.is_server():
		_world_seed_of[multiplayer.get_remote_sender_id()] = seed_value


@rpc("any_peer", "reliable")
func _rpc_peer_ready() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not ready_peers.has(id):
		ready_peers.append(id)
	for peer in multiplayer.get_peers():
		_rpc_set_ready_peers.rpc_id(peer, ready_peers)


@rpc("authority", "reliable")
func _rpc_set_ready_peers(peers: Array[int]) -> void:
	ready_peers = peers


# --- Binnenkomen en weggaan ---------------------------------------------------

@rpc("any_peer", "reliable")
func _rpc_request_join() -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if not is_loaded:
		_join_queue.append(id)
		return
	_accept(id)


func _accept(id: int) -> void:
	var existing: Array = []
	for p: Player in players.get_children():
		existing.append([p.peer_id, _color_of.get(p.peer_id, 0), p.global_position])
	_rpc_tuning.rpc_id(id, Tuning.snapshot())
	# De firma eerst: de voorwaarden van de opdracht bepalen mee hoe de wereld gegenereerd wordt
	# (extra fossielbedden en ertsaders, Company.world_mods).
	company.send_state(id)
	_rpc_world_init.rpc_id(id, pit_seed, int(planet_type), terrain.op_log(), existing, finds.snapshot(), ores.snapshot())
	mol.send_state(id)
	magma.send_state(id)
	unrest.send_state(id)
	rescue.send_state(id)
	worm.send_state(id)
	beacons.send_state(id)
	gas.send_state(id)
	var idx := _free_color()
	_color_of[id] = idx
	var pos := _spawn_pos(idx)
	for peer in multiplayer.get_peers():
		_rpc_spawn.rpc_id(peer, id, idx, pos)
	_spawn(id, idx, pos)
	print("[game] peer %d binnen (kleur %d, %d ops in het logboek)" % [id, idx, terrain.op_log().size()])


@rpc("authority", "reliable")
func _rpc_world_init(seed_value: int, planet: int, ops: Array, existing: Array, finds_state: Array, ores_state: Array) -> void:
	pit_seed = seed_value
	planet_type = planet as PlanetType.Id
	_pending_spawns.append_array(existing)
	_build_terrain(ops, finds_state, ores_state)
	print("[game] wereld ontvangen: seed %d, %d ops, %d spelers" % [seed_value, ops.size(), existing.size()])


@rpc("authority", "reliable")
func _rpc_spawn(peer_id: int, color_idx: int, pos: Vector3) -> void:
	if not is_loaded:
		_pending_spawns.append([peer_id, color_idx, pos])
		return
	_spawn(peer_id, color_idx, pos)


@rpc("authority", "reliable")
func _rpc_despawn(peer_id: int) -> void:
	_despawn(peer_id)


func _on_peer_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_color_of.erase(id)
	ready_peers.erase(id)
	_world_seed_of.erase(id)
	finds.drop_all_of(id)
	rescue.host_peer_left(id)
	_despawn(id)
	for peer in multiplayer.get_peers():
		_rpc_despawn.rpc_id(peer, id)


func _spawn(peer_id: int, color_idx: int, pos: Vector3) -> void:
	if player_node(peer_id) != null:
		return
	var p := Player.new()
	p.name = str(peer_id)
	p.peer_id = peer_id
	p.color = COLORS[color_idx % COLORS.size()]
	p.game = self
	players.add_child(p)
	p.global_position = pos
	var target := mol.body.global_position if ship else terrain.shaft_center_world()
	target.y = pos.y
	p.look_at(target) # naar de Mol (op het schip) of naar de open laadklep
	p.rotation.x = 0.0
	if p.is_local:
		local_player = p
	_add_viewers(p)
	player_spawned.emit(p)


## Terrein rond elke speler laden. Collision: de host simuleert buit bij iedereen, een client
## enkel bij zichzelf (andere spelers volgt hij via het netwerk).
func _add_viewers(p: Player) -> void:
	var view := Tuning.get_f("terrain", "view_m", 110.0)
	var coll := Tuning.get_f("terrain", "collision_m", 48.0)
	if p.is_local or Net.is_host():
		terrain.add_viewer(p, view, coll)
	else:
		terrain.add_viewer(p, coll)


func _despawn(peer_id: int) -> void:
	var p := player_node(peer_id)
	if p:
		p.queue_free()
		player_removed.emit(peer_id)


func _free_color() -> int:
	for i in COLORS.size():
		if not _color_of.values().has(i):
			return i
	return 0


## Host: vaste spawnplek van een speler: op het schip, of (zonder schip) achter de Mol aan de
## oppervlakte, bij de laadklep, naast elkaar.
func spawn_pos_of(peer_id: int) -> Vector3:
	return _spawn_pos(_color_of.get(peer_id, 0))


func _spawn_pos(idx: int) -> Vector3:
	if ship:
		return ship.spawn_point(idx)
	var sc := terrain.shaft_center_world()
	# Achter de Mol, in een rij die binnen de breedte van de laadklep (±2,1 m) blijft.
	var p := sc + Vector3(-1.8 + idx * 1.2, 0.0, 9.5)
	p.y = terrain.surface_height_at(p.x, p.z) + 1.0
	return p


# --- Tuning van de host --------------------------------------------------------

func _process(delta: float) -> void:
	if not _tuning_dirty:
		return
	# Gebundeld: slepen aan een waarde geeft tientallen wijzigingen per seconde.
	_tuning_timer += delta
	if _tuning_timer < 0.3:
		return
	_tuning_timer = 0.0
	_tuning_dirty = false
	var snap := Tuning.snapshot()
	for peer in multiplayer.get_peers():
		_rpc_tuning.rpc_id(peer, snap)


@rpc("authority", "reliable")
func _rpc_tuning(snap: Dictionary) -> void:
	Tuning.apply_remote(snap)


# --- Effecten van anderen -----------------------------------------------------

func _on_remote_op(op: Dictionary) -> void:
	if not op.has("h"):
		return
	var pos: Vector3 = op.h
	var normal: Vector3 = op.get("n", Vector3.UP)
	var layer := terrain.layer_at(pos - normal * 0.2)
	if op.op == TerrainAPI.Op.CHIP:
		fx.impact(pos, normal, Strata.DEBRIS_COLORS[layer], 2)
	else:
		fx.grit_puff(pos, normal, Strata.DEBRIS_COLORS[layer])
