class_name Rescue
extends Node3D
## Neergaan en redden (GDD §6 "Neergaan: je wordt zelf buit"; playtest 2026-10-06: robots als ragdoll).
## Staat op elk peer op Game/Rescue. De host beslist alles: levens, omver, neer, kapot, wie draagt.
## - Een robot heeft levens (rescue.cfg). Schade komt van vallen, rotsen, de worm, gas en de hitte
##   boven het magma. Een harde klap of val: even een ragdoll (KNOCKED), dan sta je weer op.
## - Geen levens meer: neer (DOWNED). Je robot is een ragdoll die je ploeg naar de Mol draagt (het
##   draagsysteem van de handschoen: E, alleen traag, met twee vlot). In de Mol wordt hij gerepareerd.
## - Niemand meer die je kan dragen (solo, of de rest ligt ook neer): je krabbelt recht en strompelt
##   zelf naar de Mol (LIMPING), zonder gereedschap. Solo blijft zo speelbaar.
## - Te lang neer, of gesmolten: kapot (BROKEN). Je vliegt als spookdrone mee tot de dienst voorbij
##   is. Ligt iedereen neer of is iedereen kapot, dan haalt DIG de Mol op.
## - Ragdolls: de host simuleert de pop, de clients volgen de romp en laten de ledematen zelf slingeren
##   (RobotRagdoll). De speler zelf staat op de plek van zijn romp (streaming, netwerk, magma, "aan boord").
## Netwerk: wat de client voorspelt (een val, een rots op zijn hoofd), meldt hij; de host past
## dezelfde controles toe (grenzen, een rots die echt gepland was) en beslist.

enum Life { OK, KNOCKED, DOWNED, LIMPING, BROKEN }

## De toestand van een robot veranderde (op elk peer).
signal life_changed(peer: int, life: int)
## Een robot kreeg een klap (op elk peer; voor HUD, camera en geluid).
signal damaged(peer: int, amount: float, source: String)

const SEND_INTERVAL := 0.05
const VITALS_INTERVAL := 0.25


class Info:
	var life := Life.OK
	var health := 1.0
	## Neer of strompelend: seconden tot kapot. Omver: seconden tot opstaan.
	var timer := 0.0
	## Seconden in de Mol (repareren).
	var repair := 0.0
	var carriers := PackedInt32Array()
	var melted := false
	var flail_cd := 0.0
	var limp_wait := 0.0
	var last_safe := Vector3.ZERO


var game: Node # Game
## peer -> RobotRagdoll (op elk peer).
var ragdolls := {}

var _info := {} # peer -> Info
var _send_t := 0.0
var _vitals_t := 0.0
var _wipe_t := 0.0
var _wipe_called := false
var _stowed := {} # host: peer -> Transform3D van de romp t.o.v. de Mol
var _rock_reports := {} # host: peer -> tijd van de laatste gemelde rots


func _ready() -> void:
	# Na de physics van de spelers: de romp staat al waar zijn dragers hem willen.
	process_physics_priority = 5


## Nieuwe dienst of einde van de dienst: alles terug op nul (host stuurt reset).
func attach(_terrain: TerrainAPI) -> void:
	pass


# --- Vragen (op elk peer) ------------------------------------------------------------------------

func info(peer: int) -> Info:
	if not _info.has(peer):
		_info[peer] = Info.new()
	return _info[peer]


func life_of(peer: int) -> int:
	return info(peer).life


func health_of(peer: int) -> float:
	return info(peer).health


func timer_of(peer: int) -> float:
	return info(peer).timer


func carriers_of(peer: int) -> PackedInt32Array:
	return info(peer).carriers


## Kan deze robot nog iets doen (rechtop, ook strompelend)?
func can_act(peer: int) -> bool:
	return info(peer).life in [Life.OK, Life.LIMPING]


## Volledig in orde (gereedschap, dragen, rijden)?
func is_ok(peer: int) -> bool:
	return info(peer).life == Life.OK


func ragdoll_of(peer: int) -> RobotRagdoll:
	var rd: Variant = ragdolls.get(peer)
	return rd if is_instance_valid(rd) else null


## Welke neergegane robot staat onder het vizier van deze speler (peer-id), of -1.
func aimed_body(p: Player) -> int:
	var cam := p.camera
	if cam == null:
		return -1
	var reach := Tuning.get_f("carry", "grab_reach", 3.0) + 0.5
	var hit: Dictionary = game.terrain.raycast(cam.global_position, cam.global_position - cam.global_basis.z * reach,
			Layers.TERRAIN | Layers.LOOT | Layers.LIFT)
	if hit.is_empty() or not (hit.collider is RigidBody3D) or not (hit.collider as Node).has_meta("rescue_peer"):
		return -1
	var peer: int = (hit.collider as Node).get_meta("rescue_peer")
	var i := info(peer)
	return peer if peer != p.peer_id and i.life == Life.DOWNED and i.carriers.size() < 2 else -1


## Waar een gedragen robot hoort: dwars in de armen van zijn dragers (de heup iets rechts, zodat de pop
## gecentreerd hangt), niet door een muur.
func carry_target(peer: int) -> Transform3D:
	var sum := Vector3.ZERO
	var yaw := 0.0
	var n := 0
	for c in info(peer).carriers:
		var p: Player = game.player_node(c)
		if p:
			sum += p.hold_point(0.55) + Vector3(0.0, -0.3, 0.0) + p.global_basis.x * 0.2
			yaw = p.rotation.y
			n += 1
	var rd := ragdoll_of(peer)
	if n == 0:
		return rd.torso.global_transform if rd else Transform3D()
	# Liggend op de armen: het lijf dwars (hoofd links), het gezicht naar boven. Alleen sleep je hem
	# laag over de grond (te zwaar om te tillen, zoals zware buit: FindKinds.liftable_alone).
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	var at := sum / n
	if n == 1 and not FindKinds.liftable_alone(Tuning.get_f("rescue", "body_mass", 24.0)):
		at.y -= Tuning.get_f("rescue", "drag_drop", 0.6)
	return Transform3D(b, at)


## Hoeveel deze robot telt bij het vertrek van de Mol (Mol._dock): 1 = achtergebleven (een wrak op de
## planeet), -1 = al aangerekend (gesmolten), 0 = gewoon nakijken of hij aan boord is.
func left_behind_override(peer: int) -> int:
	var i := info(peer)
	if i.life != Life.BROKEN:
		return 0
	return -1 if i.melted else 1


# --- Schade (host) -------------------------------------------------------------------------------

## Host: schade aan een robot. `push`: snelheid die de pop meekrijgt (m/s). `knock`: even omver.
## `quiet`: geen melding naar iedereen (doorlopende schade, zoals hitte).
func host_damage(peer: int, amount: float, push := Vector3.ZERO, knock := false, source := "", quiet := false) -> void:
	if not multiplayer.is_server():
		return
	var pl: Player = game.player_node(peer)
	if pl == null or amount <= 0.0:
		return
	var i := info(peer)
	if i.life == Life.BROKEN:
		return
	if i.life == Life.DOWNED:
		# Een neergegane robot die nog een klap krijgt: minder tijd over.
		i.timer -= amount * Tuning.get_f("rescue", "downed_s", 90.0) * 0.5
		var rd := ragdoll_of(peer)
		if rd and push.length() > 0.1:
			rd.push(push)
		_sync(peer)
		return
	if i.life == Life.LIMPING:
		host_break(peer, false)
		return
	i.health = maxf(0.0, i.health - amount)
	if not quiet:
		_rpc_damaged.rpc(peer, amount, source)
	if i.health <= 0.0:
		_host_down(peer, push)
	elif knock and i.life == Life.OK and not pl.seated:
		_host_knock(peer, push)
	elif knock and i.life == Life.KNOCKED:
		var rd := ragdoll_of(peer)
		if rd:
			rd.push(push)
		i.timer = maxf(i.timer, Tuning.get_f("rescue", "knock_s", 1.8))
		_sync(peer)
	else:
		_sync(peer)


func _host_knock(peer: int, push: Vector3) -> void:
	var pl: Player = game.player_node(peer)
	var i := info(peer)
	i.life = Life.KNOCKED
	i.timer = Tuning.get_f("rescue", "knock_s", 1.8)
	_rpc_ragdoll.rpc(peer, _feet_of(pl), push, i.life, i.health, i.timer)


func _host_down(peer: int, push: Vector3) -> void:
	var pl: Player = game.player_node(peer)
	var i := info(peer)
	if pl.seated:
		game.mol._handle_leave(peer) # uit de stoel: neer in de cabine
	i.life = Life.DOWNED
	i.timer = Tuning.get_f("rescue", "downed_s", 90.0)
	i.repair = 0.0
	i.carriers = PackedInt32Array()
	i.limp_wait = Tuning.get_f("rescue", "limp_delay_s", 2.5)
	game.finds.drop_all_of(peer)
	if ragdoll_of(peer):
		_sync(peer)
		ragdoll_of(peer).push(push)
	else:
		_rpc_ragdoll.rpc(peer, _feet_of(pl), push, i.life, i.health, i.timer)
	var solo: bool = game.players.get_child_count() <= 1
	if not solo:
		game.notice_all("%s is down! Carry them to the Mole." % _name_of(peer), "alarm")


## Host: kapot. Wat de robot droeg, valt (en zijn ertszak is weg). Gesmolten: al aangerekend (Magma).
func host_break(peer: int, melted: bool) -> void:
	if not multiplayer.is_server():
		return
	var pl: Player = game.player_node(peer)
	var i := info(peer)
	if pl == null or i.life == Life.BROKEN:
		return
	var rd := ragdoll_of(peer)
	var at := rd.torso.global_position if rd else pl.global_position
	var magma: Magma = game.magma
	if magma and magma.visible and at.y < magma.level + 2.5:
		at.y = magma.level + 2.5 # de drone komt boven het magma
	for other: int in _info:
		var o: Info = _info[other]
		if o.carriers.has(peer):
			_release(peer, other, Transform3D(), Vector3.ZERO)
	game.finds.drop_all_of(peer)
	if not melted:
		game.ores.host_lose_bag(peer)
	i.life = Life.BROKEN
	i.melted = melted
	i.health = 0.0
	i.timer = 0.0
	i.carriers = PackedInt32Array()
	_stowed.erase(peer)
	_rpc_broken.rpc(peer, at + Vector3.UP * 0.8, melted)


## Host: alles terug op nul (einde van de dienst, of een nieuwe dienst zonder schip).
func host_reset_all() -> void:
	if not multiplayer.is_server():
		return
	for peer: int in _info.keys():
		var i: Info = _info[peer]
		var pl: Player = game.player_node(peer)
		if pl == null:
			_info.erase(peer)
			continue
		if i.life == Life.OK and i.health >= 1.0:
			continue
		var to := pl.global_position
		var rd := ragdoll_of(peer)
		var mol: Mol = game.mol
		var aboard: bool = mol != null and mol.body != null and mol.contains_point(rd.torso.global_position if rd else pl.global_position)
		if i.life == Life.BROKEN or not aboard:
			to = game.spawn_pos_of(peer)
		elif rd:
			to = rd.stand_point(game.terrain)
		_rpc_reset.rpc(peer, to, i.life != Life.OK)
	_wipe_called = false
	_stowed.clear()


# --- Meldingen van de clients ---------------------------------------------------------------------

## Lokaal: de eigen robot landde hard (`speed` m/s neerwaarts). De host beslist over de schade.
func report_fall(speed: float) -> void:
	if speed < Tuning.get_f("rescue", "fall_safe", 9.0):
		return
	if Net.is_host():
		_host_fall(Net.my_id(), speed)
	else:
		_rpc_fall.rpc_id(1, speed)


@rpc("any_peer", "reliable")
func _rpc_fall(speed: float) -> void:
	if multiplayer.is_server():
		_host_fall(multiplayer.get_remote_sender_id(), speed)


func _host_fall(peer: int, speed: float) -> void:
	# Grens: hoger dan de valsnelheid die de speler kan halen, telt niet (een fout, geen val).
	speed = minf(speed, Tuning.get_f("player", "max_fall_speed", 40.0))
	var safe := Tuning.get_f("rescue", "fall_safe", 9.0)
	if speed < safe:
		return
	var amount := (speed - safe) * Tuning.get_f("rescue", "fall_damage", 0.12)
	host_damage(peer, amount, Vector3(0.0, -1.0, 0.0), speed >= Tuning.get_f("rescue", "fall_knock", 11.5), "fall")


## Lokaal: een vallende rots raakte de eigen robot (Unrest, Collapse: de rotsen vallen op elk peer zelf).
func report_rock(size: float, pos: Vector3) -> void:
	if Net.is_host():
		_host_rock(Net.my_id(), size, pos)
	else:
		_rpc_rock.rpc_id(1, size, pos)


@rpc("any_peer", "reliable")
func _rpc_rock(size: float, pos: Vector3) -> void:
	if multiplayer.is_server():
		_host_rock(multiplayer.get_remote_sender_id(), size, pos)


func _host_rock(peer: int, size: float, pos: Vector3) -> void:
	var pl: Player = game.player_node(peer)
	if pl == null:
		return
	# Dezelfde controle als bij de client: een rots die echt viel (gepland door de host), dicht bij de
	# speler zoals de host hem ziet. Hooguit één melding per 0,5 s.
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_rock_reports.get(peer, -10.0)) < 0.5:
		return
	if pl.global_position.distance_to(pos) > 4.0 or not _rock_was_planned(pos):
		print("[rescue] rots van %d geweigerd (%.1f m, gepland: %s)" % [peer, pl.global_position.distance_to(pos), _rock_was_planned(pos)])
		return
	_rock_reports[peer] = now
	var big := size >= Tuning.get_f("unrest", "big_rock", 0.8)
	var away := (pl.global_position - pos)
	away.y = 0.0
	var push := away.normalized() * 2.5 + Vector3.DOWN * 1.5 if away.length() > 0.05 else Vector3.DOWN * 2.0
	host_damage(peer, Tuning.get_f("rescue", "rock_big" if big else "rock_small", 0.4 if big else 0.15), push, big, "rock")


func _rock_was_planned(pos: Vector3) -> bool:
	for e: Array in game.unrest._plan:
		if (e[0] as Vector3).distance_to(pos) < 8.0:
			return true
	if game.collapse and game.collapse.recent_near(pos, 8.0):
		return true
	return false


## Lokaal: spartelen als je neerligt (Spatie). De host geeft de pop een duw.
func request_flail() -> void:
	if Net.is_host():
		_host_flail(Net.my_id())
	else:
		_rpc_flail.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_flail() -> void:
	if multiplayer.is_server():
		_host_flail(multiplayer.get_remote_sender_id())


func _host_flail(peer: int) -> void:
	var i := info(peer)
	var rd := ragdoll_of(peer)
	if rd == null or i.flail_cd > 0.0 or not i.carriers.is_empty():
		return
	i.flail_cd = Tuning.get_f("rescue", "flail_s", 1.0)
	var k := Tuning.get_f("rescue", "flail_impulse", 40.0)
	rd.torso.apply_central_impulse(Vector3(randf_range(-0.5, 0.5), 1.0, randf_range(-0.5, 0.5)).normalized() * k)
	for rb: RigidBody3D in rd.all_bodies():
		if rb != rd.torso:
			rb.apply_central_impulse(Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)) * k * 0.08)
	_rpc_flailed.rpc(peer)


@rpc("authority", "call_local", "reliable")
func _rpc_flailed(peer: int) -> void:
	var rd := ragdoll_of(peer)
	if rd == null:
		return
	game.fx.grit_puff(rd.torso.global_position, Vector3.UP, Color(0.6, 0.5, 0.4))
	if not multiplayer.is_server():
		# Ook bij de clients slingeren de ledematen mee.
		for rb: RigidBody3D in rd.all_bodies():
			if rb != rd.torso:
				rb.linear_velocity += Vector3(randf_range(-1, 1), randf_range(0.5, 2.0), randf_range(-1, 1)) * 1.5


# --- Dragen ----------------------------------------------------------------------------------------

## Lokaal: een neergegane ploegmaat oppakken.
func request_carry(peer: int) -> void:
	if Net.is_host():
		_carry(Net.my_id(), peer)
	else:
		_rpc_carry.rpc_id(1, peer)


## Lokaal: loslaten (of gooien) met de laatste plek en snelheid.
func request_release(peer: int, xf: Transform3D, velocity: Vector3) -> void:
	if Net.is_host():
		_release(Net.my_id(), peer, xf, velocity)
	else:
		_rpc_release.rpc_id(1, peer, xf, velocity)


@rpc("any_peer", "reliable")
func _rpc_carry(peer: int) -> void:
	if multiplayer.is_server():
		_carry(multiplayer.get_remote_sender_id(), peer)


@rpc("any_peer", "reliable")
func _rpc_release(peer: int, xf: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		_release(multiplayer.get_remote_sender_id(), peer, xf, velocity)


func _carry(sender: int, peer: int) -> void:
	var i := info(peer)
	var rd := ragdoll_of(peer)
	var p: Player = game.player_node(sender)
	if rd == null or p == null or sender == peer or i.life != Life.DOWNED or i.carriers.size() >= 2 or i.carriers.has(sender):
		return
	if not is_ok(sender):
		return
	if p.global_position.distance_to(rd.torso.global_position) > Tuning.get_f("carry", "grab_reach", 3.0) + 2.0:
		return
	# Wie al iets draagt, laat dat eerst los (een vondst, of een andere robot).
	game.finds.drop_all_of(sender)
	for other: int in _info:
		if (_info[other] as Info).carriers.has(sender):
			_release(sender, other, Transform3D(), Vector3.ZERO)
	var c := i.carriers.duplicate()
	c.append(sender)
	_stowed.erase(peer)
	_rpc_carriers.rpc(peer, c)


func _release(sender: int, peer: int, xf: Transform3D, velocity: Vector3) -> void:
	var i := info(peer)
	if not i.carriers.has(sender):
		return
	var c := i.carriers.duplicate()
	c.remove_at(c.find(sender))
	var rd := ragdoll_of(peer)
	if c.is_empty() and rd:
		# Fysica neemt over waar de laatste drager hem losliet (niet verder dan 3 m, niet in de rots).
		if xf != Transform3D() and xf.origin.distance_to(rd.torso.global_position) < 3.0 and game.terrain.sdf_at(xf.origin) > -0.2:
			rd.move_torso(xf)
		rd.set_pinned(false)
		rd.torso.linear_velocity = velocity.limit_length(10.0)
	_rpc_carriers.rpc(peer, c)


@rpc("authority", "call_local", "reliable")
func _rpc_carriers(peer: int, carriers: PackedInt32Array) -> void:
	info(peer).carriers = carriers
	var rd := ragdoll_of(peer)
	if rd and not multiplayer.is_server():
		rd.clear_snapshots()
	for c in carriers:
		var p: Player = game.player_node(c)
		if p and p.is_local and p.carry:
			p.carry.on_body_carried(peer)
	var me: Player = game.local_player
	if me and me.carry and me.carry.body_peer == peer and not carriers.has(me.peer_id):
		me.carry.on_body_released()
	life_changed.emit(peer, info(peer).life)


# --- Verloop -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if game == null or game.terrain == null:
		return
	if multiplayer.is_server():
		_host_tick(delta)
	else:
		var me := Net.my_id()
		for peer: int in ragdolls.keys():
			var rd := ragdoll_of(peer)
			if rd == null:
				continue
			if info(peer).carriers.has(me):
				continue # zelf drager: Carry zet de romp (voorspelling)
			rd.follow_snapshots(game.mol)


func _host_tick(delta: float) -> void:
	for peer: int in _info.keys():
		if game.player_node(peer) == null:
			_info.erase(peer)
			_remove_ragdoll(peer)
	for pl: Player in game.players.get_children():
		if pl.is_queued_for_deletion():
			continue
		var peer := pl.peer_id
		var i := info(peer)
		i.flail_cd = maxf(0.0, i.flail_cd - delta)
		match i.life:
			Life.OK:
				_host_ok(peer, i, pl, delta)
			Life.KNOCKED:
				i.timer -= delta
				if i.timer <= 0.0:
					_host_stand(peer, Life.OK, i.health)
			Life.DOWNED:
				_host_downed(peer, i, delta)
			Life.LIMPING:
				_host_limping(peer, i, pl, delta)
	_host_bodies(delta)
	_send_t += delta
	if _send_t >= SEND_INTERVAL:
		_send_t = 0.0
		_send_bodies()
	_vitals_t += delta
	if _vitals_t >= VITALS_INTERVAL:
		_vitals_t = 0.0
		_send_vitals()
	_wipe_t += delta
	if _wipe_t >= 1.0:
		_wipe_t = 0.0
		_check_wipe()


func _host_ok(peer: int, i: Info, pl: Player, delta: float) -> void:
	var mol: Mol = game.mol
	if i.health < 1.0 and mol and mol.body and (pl.seated or mol.contains_point(pl.global_position)):
		i.health = minf(1.0, i.health + Tuning.get_f("rescue", "mol_regen", 0.06) * delta)
	# De hittezone boven het magma doet pijn (onderzoek magma-en-onrust F: 20% per s).
	var magma: Magma = game.magma
	if magma and magma.running and magma.visible and not pl.seated:
		var feet := pl.global_position.y - magma.level
		var in_mol: bool = mol != null and mol.body != null and mol.contains_point(pl.global_position) and mol.body.global_position.y > magma.level
		if feet < Tuning.get_f("magma", "heat_m", 3.0) and feet > -0.3 and not in_mol:
			host_damage(peer, Tuning.get_f("rescue", "heat_dps", 0.2) * delta, Vector3.ZERO, false, "heat", true)


func _host_downed(peer: int, i: Info, delta: float) -> void:
	var rd := ragdoll_of(peer)
	var mol: Mol = game.mol
	if rd and mol and mol.body and mol.contains_point(rd.torso.global_position):
		i.repair += delta
		if i.repair >= Tuning.get_f("rescue", "repair_s", 4.0):
			_host_stand(peer, Life.OK, Tuning.get_f("rescue", "repair_health", 0.5))
			game.notice_all("%s is back on their feet." % _name_of(peer), "mol")
		return
	i.repair = maxf(0.0, i.repair - delta * 2.0)
	i.timer -= delta
	if i.timer <= 0.0:
		host_break(peer, false)
		return
	# Niemand meer die kan dragen: zelf recht krabbelen en strompelen.
	if i.carriers.is_empty() and not _anyone_else_ok(peer):
		i.limp_wait -= delta
		if i.limp_wait <= 0.0:
			_host_stand(peer, Life.LIMPING, 0.0)
	else:
		i.limp_wait = Tuning.get_f("rescue", "limp_delay_s", 2.5)


func _host_limping(peer: int, i: Info, pl: Player, delta: float) -> void:
	var mol: Mol = game.mol
	if mol and mol.body and (pl.seated or mol.contains_point(pl.global_position)):
		i.repair += delta
		if i.repair >= Tuning.get_f("rescue", "repair_s", 4.0):
			i.life = Life.OK
			i.health = Tuning.get_f("rescue", "repair_health", 0.5)
			i.repair = 0.0
			_sync(peer)
			game.notice_all("%s made it to the Mole: repaired." % _name_of(peer), "mol")
		return
	i.repair = 0.0
	i.timer -= delta
	if i.timer <= 0.0:
		host_break(peer, false)


func _anyone_else_ok(peer: int) -> bool:
	for pl: Player in game.players.get_children():
		if pl.peer_id != peer and is_ok(pl.peer_id):
			return true
	return false


## Host: opstaan op de plek van de romp (na omver, na reparatie, of strompelend).
func _host_stand(peer: int, life: int, health: float) -> void:
	var i := info(peer)
	var rd := ragdoll_of(peer)
	var pl: Player = game.player_node(peer)
	var to := rd.stand_point(game.terrain) if rd else pl.global_position
	var yaw := pl.rotation.y
	if rd:
		var fwd := -rd.torso.global_basis.z
		if Vector2(fwd.x, fwd.z).length() > 0.1:
			yaw = atan2(-fwd.x, -fwd.z)
	for c in i.carriers:
		_release(c, peer, Transform3D(), Vector3.ZERO)
	i.life = life
	i.health = health
	i.repair = 0.0
	if life == Life.OK:
		i.timer = 0.0
	_stowed.erase(peer)
	_rpc_stand.rpc(peer, to, yaw, life, health, i.timer)


## Host: ragdolls dragen, vastsjorren in een rijdende Mol, en een vangnet tegen de rots.
func _host_bodies(_delta: float) -> void:
	var mol: Mol = game.mol
	var moving: bool = mol != null and mol.body != null and (absf(mol.speed) > 0.05 or mol.mode in Mol.MOVING_MODES)
	var me := Net.my_id()
	for peer: int in ragdolls.keys():
		var rd := ragdoll_of(peer)
		if rd == null:
			continue
		var i := info(peer)
		var t := rd.torso
		if not i.carriers.is_empty():
			_stowed.erase(peer)
			if not rd.pinned:
				rd.set_pinned(true)
			if not i.carriers.has(me):
				rd.move_torso(carry_target(peer))
			continue
		if moving and (_stowed.has(peer) or mol.contains_point(t.global_position)):
			if not _stowed.has(peer):
				_stowed[peer] = mol.body.global_transform.affine_inverse() * t.global_transform
				rd.set_pinned(true)
			rd.move_torso(mol.body.global_transform * (_stowed[peer] as Transform3D))
			i.last_safe = t.global_position
			continue
		if _stowed.has(peer):
			rd.move_torso(mol.body.global_transform * (_stowed[peer] as Transform3D))
			_stowed.erase(peer)
			rd.set_pinned(false)
			continue
		if rd.pinned:
			rd.set_pinned(false)
		var p := t.global_position
		if game.terrain.sdf_at(p) < -0.4 or p.y < -5.0:
			var back := i.last_safe if i.last_safe != Vector3.ZERO else p + Vector3.UP
			rd.teleport(Transform3D(t.global_basis, back + Vector3.UP * 0.3))
		elif t.linear_velocity.length() < 3.0 and game.terrain.sdf_at(p) > 0.25:
			i.last_safe = p


func _send_bodies() -> void:
	if ragdolls.is_empty():
		return
	var mol: Mol = game.mol
	var peers := PackedInt32Array()
	var xfs: Array = []
	var in_mol := PackedByteArray()
	for peer: int in ragdolls.keys():
		var rd := ragdoll_of(peer)
		if rd == null:
			continue
		var xf := rd.torso.global_transform
		var inside: bool = mol != null and mol.body != null and mol.contains_point(xf.origin)
		peers.append(peer)
		xfs.append(mol.body.global_transform.affine_inverse() * xf if inside else xf)
		in_mol.append(1 if inside else 0)
	for peer: int in game.ready_peers:
		if peer != multiplayer.get_unique_id():
			_rpc_bodies.rpc_id(peer, peers, xfs, in_mol)


@rpc("authority", "unreliable_ordered")
func _rpc_bodies(peers: PackedInt32Array, xfs: Array, in_mol: PackedByteArray) -> void:
	for k in peers.size():
		var rd := ragdoll_of(peers[k])
		if rd:
			rd.push_snapshot(xfs[k], in_mol[k] == 1)


func _send_vitals() -> void:
	var peers := PackedInt32Array()
	var vals := PackedFloat32Array()
	for peer: int in _info:
		var i: Info = _info[peer]
		peers.append(peer)
		vals.append(i.health)
		vals.append(i.timer)
		vals.append(i.repair)
	if not peers.is_empty():
		_rpc_vitals.rpc(peers, vals)


@rpc("authority", "unreliable_ordered")
func _rpc_vitals(peers: PackedInt32Array, vals: PackedFloat32Array) -> void:
	for k in peers.size():
		var i := info(peers[k])
		i.health = vals[k * 3]
		i.timer = vals[k * 3 + 1]
		i.repair = vals[k * 3 + 2]


## Host: ligt iedereen neer of is iedereen kapot, dan haalt DIG de Mol op.
func _check_wipe() -> void:
	if _wipe_called or game.magma == null or not game.magma.running:
		return
	var n := 0
	for pl: Player in game.players.get_children():
		n += 1
		if can_act(pl.peer_id):
			return
	if n == 0:
		return
	var s := Tuning.get_f("rescue", "wipe_s", 12.0)
	if game.mol and game.mol.host_emergency(s, "Every robot is down. DIG is hauling the Mole up in %d s." % int(s)):
		_wipe_called = true


func _sync(peer: int) -> void:
	var i := info(peer)
	_rpc_life.rpc(peer, i.life, i.health, i.timer, i.melted)


# --- Toestand op elk peer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _rpc_life(peer: int, life: int, health: float, timer: float, melted: bool) -> void:
	var i := info(peer)
	var was := i.life
	i.life = life as Life
	i.health = health
	i.timer = timer
	i.melted = melted
	if was != life:
		var pl: Player = game.player_node(peer)
		if pl:
			pl.on_life(life)
		life_changed.emit(peer, life)


@rpc("authority", "call_local", "reliable")
func _rpc_damaged(peer: int, amount: float, source: String) -> void:
	damaged.emit(peer, amount, source)
	var pl: Player = game.player_node(peer)
	if pl and pl.is_local and pl.camera_fx:
		pl.camera_fx.add_trauma(clampf(amount * 1.2, 0.15, 0.6))
		pl.camera_fx.kick(-4.0 - amount * 10.0, randf_range(-4.0, 4.0))
	elif pl and pl.rig:
		pl.rig.grimace()


## Een robot gaat als ragdoll neer (omver of neer). `feet`: zijn plek en kijkrichting; `push`: snelheid.
@rpc("authority", "call_local", "reliable")
func _rpc_ragdoll(peer: int, feet: Transform3D, push: Vector3, life: int, health: float, timer: float) -> void:
	var pl: Player = game.player_node(peer)
	if pl == null:
		return
	var i := info(peer)
	i.life = life as Life
	i.health = health
	i.timer = timer
	i.carriers = PackedInt32Array()
	var rd := ragdoll_of(peer)
	if rd == null:
		rd = RobotRagdoll.new()
		rd.name = "Ragdoll%d" % peer
		rd.peer_id = peer
		add_child(rd)
		rd.build(feet, pl.color, multiplayer.is_server())
		ragdolls[peer] = rd
	if multiplayer.is_server():
		rd.push(push + Vector3.UP * 1.2)
	else:
		# De romp volgt de host; de ledematen krijgen zelf de klap mee.
		for rb: RigidBody3D in rd.all_bodies():
			if rb != rd.torso:
				rb.linear_velocity += push + Vector3.UP * 1.2
		rd.push_snapshot(rd.torso.global_transform, false)
	i.last_safe = rd.torso.global_position
	game.fx.grit_puff(feet.origin + Vector3.UP * 0.4, Vector3.UP, Color(0.6, 0.5, 0.4))
	pl.on_ragdoll(rd, life)
	life_changed.emit(peer, life)


## Opstaan: de ragdoll weg, de robot staat op `feet` (bij de eigenaar: daarheen springen).
@rpc("authority", "call_local", "reliable")
func _rpc_stand(peer: int, feet: Vector3, yaw: float, life: int, health: float, timer: float) -> void:
	var i := info(peer)
	i.life = life as Life
	i.health = health
	i.timer = timer
	i.carriers = PackedInt32Array()
	_remove_ragdoll(peer)
	var pl: Player = game.player_node(peer)
	if pl:
		pl.on_stand(feet, yaw, life)
	life_changed.emit(peer, life)


@rpc("authority", "call_local", "reliable")
func _rpc_broken(peer: int, at: Vector3, melted: bool) -> void:
	var i := info(peer)
	i.life = Life.BROKEN
	i.melted = melted
	i.health = 0.0
	i.carriers = PackedInt32Array()
	var rd := ragdoll_of(peer)
	if rd:
		game.fx.crust_break(rd.torso.global_position, 0.6, Color(0.3, 0.3, 0.32))
	_remove_ragdoll(peer)
	var pl: Player = game.player_node(peer)
	if pl:
		pl.on_broken(at)
		if pl.is_local:
			game.notice.emit("Your robot is broken. You're a ghost drone until the shift is over.", "alarm")
		else:
			game.notice.emit("%s's robot is broken." % _name_of(peer), "warn")
	life_changed.emit(peer, Life.BROKEN)


@rpc("authority", "call_local", "reliable")
func _rpc_reset(peer: int, feet: Vector3, move: bool) -> void:
	var i := info(peer)
	var was := i.life
	i.life = Life.OK
	i.health = 1.0
	i.timer = 0.0
	i.repair = 0.0
	i.melted = false
	i.carriers = PackedInt32Array()
	_remove_ragdoll(peer)
	var pl: Player = game.player_node(peer)
	if pl and (move or was != Life.OK):
		pl.on_stand(feet, pl.rotation.y, Life.OK)
	if was != Life.OK:
		life_changed.emit(peer, Life.OK)


func _remove_ragdoll(peer: int) -> void:
	var rd := ragdoll_of(peer)
	ragdolls.erase(peer)
	if rd:
		rd.queue_free()


## Late joiner: de toestand van iedereen (ragdolls opnieuw op de plek van de romp).
func send_state(peer: int) -> void:
	for p: int in _info:
		var i: Info = _info[p]
		var rd := ragdoll_of(p)
		if rd:
			var pl: Player = game.player_node(p)
			_rpc_ragdoll.rpc_id(peer, Transform3D(Basis(Vector3.UP, pl.rotation.y if pl else 0.0), rd.torso.global_position - Vector3.UP * RobotRagdoll.HIP),
					Vector3.ZERO, i.life, i.health, i.timer)
			_rpc_carriers.rpc_id(peer, p, i.carriers)
		elif i.life == Life.BROKEN:
			var pl: Player = game.player_node(p)
			_rpc_broken.rpc_id(peer, p, pl.global_position if pl else Vector3.ZERO, i.melted)
		else:
			_rpc_life.rpc_id(peer, p, i.life, i.health, i.timer, i.melted)


## Host: iemand verliet de sessie: zijn ragdoll weg, en wat hij droeg valt.
func host_peer_left(peer: int) -> void:
	for other: int in _info.keys():
		if (_info[other] as Info).carriers.has(peer):
			_release(peer, other, Transform3D(), Vector3.ZERO)
	_info.erase(peer)
	_remove_ragdoll(peer)


func _feet_of(pl: Player) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, pl.rotation.y), pl.global_position)


func _name_of(peer: int) -> String:
	var idx := 0
	for pl: Player in game.players.get_children():
		idx += 1
		if pl.peer_id == peer:
			return "Player %d" % idx
	return "A robot"
