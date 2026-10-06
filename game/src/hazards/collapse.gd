class_name Collapse
extends Node
## Instortingen die met de diepte toenemen (GDD §6; playtest 2026-10-06: "hoe dieper, hoe meer kans
## dat het instort"). Staat op elk peer op Game/Collapse.
## - Tussen de bevingen door stort een onstabiele zone (Unrest.zones, gemarkeerd in de rotsshader)
##   in de buurt van een speler soms vanzelf in. De kans per zone groeit met de diepte, met de onrust
##   en naar het einde van de dienst (collapse.cfg; per planeet HazardParams "collapse").
## - Eerst een waarschuwing (stof dat uit het plafond spuit, warn_s), dan vallen er rotsen (Unrest):
##   wie eronder staat, wordt geraakt (Rescue). Grote rotsen blijven liggen als puin (Rubble) dat de
##   weg verspert en dat je wegbikt. De rots zelf groeit nooit aan.
## - Een opdracht met "Shaky ground" (pakket F1, Contracts.UNSTABLE): meer zones en een grotere kans.
## Netwerk: de host rolt de kans en kiest de rotsen (met id), elk peer laat ze zelf vallen.

## Een zone stort in (op elk peer; voor geluid en tests).
signal started(at: Vector3)

var game: Node # Game

var _check_t := 0.0
var _plans: Array = [] # [tijd sinds start (s), plan]
var _recent: Array = [] # host: [plek, tijd (s)] van rotsen die vielen (controle voor Rescue)
var _rng := RandomNumberGenerator.new()
var _count := 0


func _ready() -> void:
	_rng.randomize()


func attach_terrain(_terrain: TerrainAPI) -> void:
	_plans.clear()
	_recent.clear()
	_check_t = 0.0
	_count = 0


## Kans per zone per minuut op deze diepte (m onder het oppervlak), met onrust (0..1) en spanning (0..1).
static func rate_at(depth: float, unrest_frac := 0.0, tension := 0.0, planet := 1.0) -> float:
	var base := Tuning.get_f("collapse", "rate_per_100m", 0.035) * maxf(0.0, depth - Tuning.get_f("collapse", "start_m", 20.0)) / 100.0
	base = minf(base, Tuning.get_f("collapse", "max_rate", 0.12))
	return base * (1.0 + Tuning.get_f("collapse", "unrest_k", 1.5) * unrest_frac) \
			* (1.0 + Tuning.get_f("collapse", "tension_k", 1.0) * tension) * planet


## Factor voor de opdracht: "Shaky ground" (Contracts.UNSTABLE) maakt instortingen waarschijnlijker
## (`key`: unstable_rate of unstable_zones in collapse.cfg). Uit de voorwaarden van deze wereld, op
## elke peer gelijk (Company.world_mods).
static func contract_factor(game: Node, key: String) -> float:
	if game == null or game.company == null:
		return 1.0
	return Tuning.get_f("collapse", key, 1.0) if Contracts.has(game.company.world_mods, Contracts.UNSTABLE) else 1.0


## Hoeveel instortingen er deze dienst al waren (host).
func count() -> int:
	return _count


## Viel er de laatste seconden een rots vlakbij (Rescue: een gemelde treffer was echt)?
func recent_near(at: Vector3, r: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for e: Array in _recent:
		if now - float(e[1]) < 20.0 and (e[0] as Vector3).distance_to(at) < r:
			return true
	return false


func _process(delta: float) -> void:
	if game == null or game.terrain == null:
		return
	# Lopende instortingen (op elk peer): eerst stof, dan de rotsen op hun moment.
	for e: Array in _plans:
		e[0] = float(e[0]) + delta
		var t: float = e[0]
		var plan: Array = e[1]
		var done: Dictionary = e[2]
		var warn := Tuning.get_f("collapse", "warn_s", 1.6)
		if t < warn:
			_warn_tick(plan, t / warn, delta)
		for i in plan.size():
			var r: Array = plan[i]
			if not done.has(i) and t >= warn + float(r[2]):
				done[i] = true
				game.unrest.spawn_rock(r)
	_plans = _plans.filter(func(e: Array) -> bool: return (e[2] as Dictionary).size() < (e[1] as Array).size())
	if not multiplayer.is_server():
		return
	var magma: Magma = game.magma
	if magma == null or not magma.running or magma.elapsed < Tuning.get_f("collapse", "quiet_s", 90.0):
		return
	_check_t += delta
	var step := Tuning.get_f("collapse", "check_s", 4.0)
	if _check_t < step:
		return
	_check_t = 0.0
	_host_roll(step)


## Host: per zone in de buurt van een speler de kans rollen.
func _host_roll(step: float) -> void:
	var t: TerrainAPI = game.terrain
	var near := Tuning.get_f("collapse", "near_m", 28.0)
	var unrest_frac := clampf(game.unrest.value / maxf(1.0, Tuning.get_f("unrest", "stage", 100.0)), 0.0, 1.0)
	var tension: float = game.worm.tension() if game.worm else 0.0
	var planet := HazardParams.of(game, "collapse", 1.0) * contract_factor(game, "unstable_rate")
	var spots: Array[Vector3] = []
	for pl: Player in game.players.get_children():
		if game.rescue == null or game.rescue.life_of(pl.peer_id) != Rescue.Life.BROKEN:
			spots.append(pl.global_position)
	if spots.is_empty() or game.unrest.phase != Unrest.Phase.CALM:
		return
	for z: Vector4 in game.unrest.zones:
		var c := Vector3(z.x, z.y, z.z)
		var close := false
		for s in spots:
			if s.distance_to(c) < near:
				close = true
				break
		if not close:
			continue
		var depth := t.surface_height_at(c.x, c.z) - c.y
		var p := rate_at(depth, unrest_frac, tension, planet) * step / 60.0
		if _rng.randf() < p:
			host_collapse(z)
			return # hooguit één per keer


## Host: deze zone stort in (ook voor tests).
func host_collapse(z: Vector4) -> bool:
	var t: TerrainAPI = game.terrain
	var c := Vector3(z.x, z.y, z.z)
	var plan: Array = []
	var n := _rng.randi_range(Tuning.get_i("collapse", "rocks_min", 2), Tuning.get_i("collapse", "rocks_max", 5))
	var spread := Tuning.get_f("collapse", "spread_s", 2.0)
	for i in n:
		for attempt in 10:
			var p := c + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 1), _rng.randf_range(-1, 1)) * z.w * 0.8
			if not t.data_loaded(p) or t.sdf_at(p) < 0.6:
				continue
			var hit := t.raycast(p, p + Vector3.UP * 7.0)
			if hit.is_empty():
				continue
			var size := _rng.randf_range(Tuning.get_f("unrest", "rock_min", 0.4), Tuning.get_f("unrest", "rock_max", 1.4))
			var at: Vector3 = hit.position - Vector3(0.0, size * 0.6 + 0.1, 0.0)
			plan.append(game.unrest.host_rock_entry(at, size, _rng.randf_range(0.0, spread)))
			break
	if plan.is_empty():
		return false
	_count += 1
	var now := Time.get_ticks_msec() / 1000.0
	for r: Array in plan:
		_recent.append([r[0], now])
	_recent = _recent.filter(func(e: Array) -> bool: return now - float(e[1]) < 30.0)
	_rpc_collapse.rpc(c, plan)
	print("[collapse] zone op %.0f m diepte stort in (%d rotsen)" % [t.surface_height_at(c.x, c.z) - c.y, plan.size()])
	return true


## De waarschuwing zwelt aan (golf 3, gevoel2-01; zonder geluid, M6): wie dichtbij staat, voelt het
## beeld steeds harder rollen, ziet steentjes uit het plafond van de zone vallen en zijn lamp haperen.
## `k`: 0..1 door de waarschuwing heen. Enkel beeld, op elk peer zelf.
var _warn_pebble := 0.0


func _warn_tick(plan: Array, k: float, delta: float) -> void:
	var p: Player = game.local_player
	if p == null or plan.is_empty() or p.camera_fx == null:
		return
	var c: Vector3 = (plan[0] as Array)[0]
	var near := 1.0 - smoothstep(4.0, Tuning.get_f("collapse", "warn_near_m", 16.0), p.global_position.distance_to(c))
	if near <= 0.0:
		return
	p.camera_fx.hold_rumble(lerpf(0.4, Tuning.get_f("collapse", "warn_rumble_deg", 2.2), k * k) * near)
	p.camera_fx.hold_trauma(lerpf(0.05, 0.22, k) * near)
	_warn_pebble -= delta
	if _warn_pebble <= 0.0:
		_warn_pebble = lerpf(0.35, 0.12, k)
		var r: Array = plan[_rng.randi() % plan.size()]
		var at: Vector3 = (r[0] as Vector3) + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))
		game.unrest._spawn_pebble(at, _rng.randf_range(0.06, 0.16))
		if k > 0.4 and _rng.randf() < 0.5:
			game.unrest._start_flicker(0.12)


@rpc("authority", "call_local", "reliable")
func _rpc_collapse(at: Vector3, plan: Array) -> void:
	var warn := Tuning.get_f("collapse", "warn_s", 1.6)
	var col: Color = Strata.DEBRIS_COLORS[game.terrain.layer_at(at)]
	_warn_pebble = 0.0
	for r: Array in plan:
		game.unrest._dust_stream(r[0], warn + float(r[2]) + 0.4, col)
	_plans.append([0.0, plan, {}])
	# Kraken: een korte schok voor wie in de buurt is (geluid: M6).
	var p: Player = game.local_player
	if p and p.camera_fx:
		var k := 1.0 - smoothstep(6.0, 30.0, p.global_position.distance_to(at))
		if k > 0.0:
			p.camera_fx.add_trauma(0.25 * k)
			p.camera_fx.hold_rumble(1.5 * k)
		if k > 0.4:
			game.notice.emit("The ceiling is giving way! Get out from under it.", "warn")
	started.emit(at)
