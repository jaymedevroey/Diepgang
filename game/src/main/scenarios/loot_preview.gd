extends Node
## Beelden van pakket F3 (release-audit ontwerp-5, -8, -9): per planeet wat haar anders maakt.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=loot_preview --no-steam
##   [--planet=0|1|2] [--only=bed,camp,carry,crystal,scan]
## Beelden in logs/ (f3_<planeet>_*.png):
##   bed, bed_vrij       een skeletbed opgegraven (de korsten liggen zoals in het beest), en vrijgemaakt
##   kamp                Roestbol: een kamp van vorige bezoekers in de klei
##   slepen_fp           Fossielwereld: alleen een titanschedel slepen (eigen ogen)
##   samen_derde/_fp     Fossielwereld: met twee dragen (van opzij en door je eigen ogen)
##   kristal, _vrij, _breuk  Kristalmaan: een kristalgrot in de wand, de kristallen los en gloeiend, één gebroken
##   f3_zijscan          de zijscan in het laadruim (met een gevulde waterval), f3_pijltje: een pijltje in de wand

const KEYS := ["roestbol", "fossiel", "kristal"]

var main: Node
var _cam: Camera3D
var _lamp: SpotLight3D
var _only: PackedStringArray


func _ready() -> void:
	_only = str(CmdArgs.value("only", "")).split(",", false)
	main.game.player_spawned.connect(func(p: Player) -> void:
		if p.is_local:
			_run.call_deferred(p))


func _want(what: String) -> bool:
	return _only.is_empty() or what in _only


func _run(p: Player) -> void:
	p.set_physics_process(false)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	main.add_child(_cam)
	_lamp = SpotLight3D.new()
	_lamp.light_color = Color(1.0, 0.88, 0.72)
	_lamp.light_energy = 6.0
	_lamp.spot_range = 30.0
	_lamp.spot_angle = 55.0
	_lamp.shadow_enabled = true
	_cam.add_child(_lamp)
	_lamp.position = Vector3(0.4, 0.5, 0.0)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.8, 0.85, 1.0)
	fill.light_energy = 0.6
	fill.omni_range = 18.0
	fill.shadow_enabled = false
	_cam.add_child(fill)
	var planets: Array = [int(CmdArgs.value("planet", 0))] if CmdArgs.has("planet") else [0, 1, 2]
	for planet: int in planets:
		await _world(planet, 11)
		if _want("bed"):
			await _bed(p, planet)
		if planet == 0 and _want("camp"):
			await _camp(p)
		if planet == 1 and _want("carry"):
			await _carry(p)
		if planet == 2 and _want("crystal"):
			await _crystal(p)
		# De zijscan op de planeet met de grootste skeletten (of de enige gevraagde).
		if _want("scan") and (planet == 1 or planets.size() == 1):
			await _scan(p)
	get_tree().quit(0)


func _world(planet: int, seed_value: int) -> void:
	var game: Game = main.game
	if int(game.planet_type) != planet or game.pit_seed != seed_value:
		game.host_new_world(seed_value, planet)
		# Zonder schip krijgt de nieuwe wereld de spelers niet als kijker (enkel de Mol): dan laadt er geen
		# botsing rond de speler en blijven losse vondsten geparkeerd hangen.
		for pl: Player in game.players.get_children():
			game._add_viewers(pl)
		await _wait(0.5)
	var t0 := Time.get_ticks_msec()
	while not game.world_ready() and Time.get_ticks_msec() - t0 < 30000:
		await _wait(0.2)


## De speler (de kijker van het terrein) bij een plek zetten en wachten tot het terrein er staat.
func _go(p: Player, at: Vector3) -> void:
	p.global_position = at
	p.reset_physics_interpolation()
	var t: TerrainAPI = main.terrain
	var t0 := Time.get_ticks_msec()
	while (not t.collision_ready(at) or t.queued_ops() > 0) and Time.get_ticks_msec() - t0 < 15000:
		await _wait(0.2)
	await _wait(2.5)


func _settle() -> void:
	var t: TerrainAPI = main.terrain
	var t0 := Time.get_ticks_msec()
	while t.queued_ops() > 0 and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	await _wait(1.2)


func _center(items: Array) -> Vector3:
	var c := Vector3.ZERO
	for it: FindItem in items:
		c += it.global_position
	return c / maxf(1.0, items.size())


## Een skeletbed: het grootste bereikbare skelet (op Fossielwereld een Titan), de rots eromheen weg zodat de
## korsten bloot liggen (botten steken uit de knollen), van schuin boven met een lamp.
func _bed(p: Player, planet: int) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var sets := finds.sets()
	var best := ""
	for id: String in sets:
		var pieces: Array = sets[id]
		var c := _center(pieces)
		if c.y < Strata.TOPS_M[1] + 4.0:
			continue
		if best == "" or pieces.size() > (sets[best] as Array).size():
			best = id
	if best == "":
		print("[loot_preview] geen bereikbaar skelet op planeet %d" % planet)
		return
	var pieces: Array = sets[best]
	var c := _center(pieces)
	var far := 0.0
	for it: FindItem in pieces:
		far = maxf(far, Vector2(it.global_position.x - c.x, it.global_position.z - c.z).length())
	print("[loot_preview] %s: skelet %s (%s), %d stukken, %.0f m breed, op −%.0f m" % [KEYS[planet], best,
			(pieces[0] as FindItem).set_name, pieces.size(), far * 2.0, t.surface_height_at(c.x, c.z) - c.y])
	# De lengte van het bed: van het eerste stuk (de kop) naar het verste; de camera schuin opzij daarvan.
	var head: FindItem = pieces[0]
	var tail: FindItem = head
	for it: FindItem in pieces:
		if it.global_position.distance_to(head.global_position) > tail.global_position.distance_to(head.global_position):
			tail = it
	var axis := tail.global_position - head.global_position
	axis.y = 0.0
	var perp := axis.normalized().cross(Vector3.UP) if axis.length() > 0.5 else Vector3.RIGHT
	var cam_at := c + perp * (far * 0.75 + 2.5) + Vector3(0, far * 0.35 + 2.2, 0)
	await _go(p, cam_at)
	# Opgraving: rond elk stuk, tussen de stukken, en een gang naar de camera.
	for it: FindItem in pieces:
		t.debug_dig(it.global_position, FindKinds.radius(it.kind) + 1.3)
		for o: FindItem in pieces:
			if o != it and o.global_position.distance_to(it.global_position) < 6.0:
				t.debug_dig(it.global_position.lerp(o.global_position, 0.5), 1.6)
	for k in 6:
		t.debug_dig(c.lerp(cam_at, k / 5.0) + Vector3(0, 0.8, 0), 2.4 + far * 0.25)
	await _settle()
	_cam.fov = 70.0
	_cam.global_position = cam_at
	_cam.look_at(c - Vector3(0, 0.5, 0))
	_cam.make_current()
	await _shot("f3_%s_bed" % KEYS[planet])
	for it: FindItem in pieces:
		finds._free(it.find_id)
	await _wait(3.0)
	await _shot("f3_%s_bed_vrij" % KEYS[planet])


## Roestbol: een kamp van vorige bezoekers (rommel bijeen in de klei).
func _camp(p: Player) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var best: Array = []
	for it in finds.items:
		if FindKinds.FAMILIES[it.kind] != FindKinds.Family.JUNK or it.freed:
			continue
		var group: Array = [it]
		for o in finds.items:
			if o != it and not o.freed and FindKinds.FAMILIES[o.kind] in [FindKinds.Family.JUNK, FindKinds.Family.METAL, FindKinds.Family.RELIC] \
					and o.global_position.distance_to(it.global_position) < 5.5:
				group.append(o)
		if group.size() > best.size():
			best = group
	if best.size() < 3:
		print("[loot_preview] geen kamp gevonden")
		return
	var c := _center(best)
	var cam_at := c + Vector3(3.2, 1.8, 3.2)
	await _go(p, cam_at)
	for it: FindItem in best:
		t.debug_dig(it.global_position, FindKinds.radius(it.kind) + 0.9)
	t.debug_dig(c, 3.6)
	for k in 4:
		t.debug_dig(c.lerp(cam_at, k / 3.0), 2.4)
	await _settle()
	_cam.fov = 70.0
	_cam.global_position = cam_at
	_cam.look_at(c - Vector3(0, 0.6, 0))
	_cam.make_current()
	await _shot("f3_roestbol_kamp")
	for it: FindItem in best:
		finds._free(it.find_id)
	await _wait(3.0)
	await _shot("f3_roestbol_kamp_vrij")


## Fossielwereld: een titanschedel alleen slepen, dan met een tweede robot samen dragen.
func _carry(p: Player) -> void:
	var game: Game = main.game
	var finds: FindField = game.finds
	var t: TerrainAPI = main.terrain
	var skull: FindItem = null
	for it in finds.items:
		if it.kind == FindKinds.Kind.TITAN_SKULL and not it.freed and it.global_position.y > Strata.TOPS_M[1] + 4.0:
			if skull == null or it.global_position.y > skull.global_position.y:
				skull = it
	if skull == null:
		print("[loot_preview] geen titanschedel")
		return
	var at := skull.global_position
	await _go(p, at + Vector3(0, 2.0, 0))
	# Een kamer van ±12 × 9 m met een vlakke vloer, 2 m onder de schedel.
	var room := at + Vector3(0, 0.6, 0)
	for dx in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		for dz in [-2.5, 0.0, 2.5]:
			t.debug_dig(room + Vector3(dx, 0.0, dz), 2.8)
	await _settle()
	finds._free(skull.find_id)
	await _wait(2.5)
	var floor_y := _floor(skull.global_position)
	# Alleen: slepen, door je eigen ogen.
	p.global_position = Vector3(skull.global_position.x + 2.3, floor_y + 0.02, skull.global_position.z + 0.3)
	p.look_at(Vector3(skull.global_position.x, p.global_position.y, skull.global_position.z))
	p.rotation.x = 0.0
	p.head.rotation.x = deg_to_rad(-24)
	p.reset_physics_interpolation()
	await _wait(0.3)
	finds.request_grab(skull.find_id)
	await _wait(1.5)
	for i in 12: # een stukje achteruit trekken: stofwolkjes
		p.global_position += p.global_basis.z * 0.12
		await get_tree().physics_frame
		await get_tree().physics_frame
	await _wait(0.2)
	p.camera.make_current()
	await _shot("f3_fossiel_slepen_fp")
	# Een tweede robot pakt de andere kant: getild, tussen jullie in.
	game._spawn(2, 1, Vector3.ZERO)
	var buddy: Player = game.player_node(2)
	var mid := skull.global_position
	buddy.global_position = Vector3(mid.x - 2.1, floor_y + 0.02, mid.z - 0.2)
	buddy.look_at(Vector3(mid.x, buddy.global_position.y, mid.z))
	buddy.rotation.x = 0.0
	p.global_position = Vector3(mid.x + 2.1, floor_y + 0.02, mid.z + 0.2)
	p.look_at(Vector3(mid.x, p.global_position.y, mid.z))
	p.rotation.x = 0.0
	p.head.rotation.x = deg_to_rad(-6)
	finds._grab(2, skull.find_id)
	if buddy.rig:
		buddy.rig.set_carrying(true)
	await _wait(2.0)
	print("[loot_preview] samen: %d dragers, snelheid %.2f (alleen %.2f)" % [skull.carriers.size(), p.carry.move_multiplier(),
			Tuning.get_f("carry", "drag_speed", 0.33)])
	await _shot("f3_fossiel_samen_fp")
	# Van opzij: twee robots met de schedel tussen hen (de eigen speler heeft geen lijf in beeld, dus een
	# derde robot neemt zijn kant over).
	var side := (buddy.global_position - p.global_position).cross(Vector3.UP).normalized()
	var spot := p.global_position
	var view := p.rotation.y
	p.carry.drop(false)
	p.global_position = skull.global_position - side * 7.0 + Vector3(0, 1.5, 0)
	await _wait(0.3)
	game._spawn(3, 2, Vector3.ZERO)
	var other: Player = game.player_node(3)
	other.global_position = spot
	other.rotation.y = view
	finds._grab(3, skull.find_id)
	if other.rig:
		other.rig.set_carrying(true)
	await _wait(2.0)
	_cam.fov = 60.0
	_cam.global_position = skull.global_position + side * 4.6 + Vector3(0, 0.9, 0)
	_cam.look_at(skull.global_position - Vector3(0, 0.4, 0))
	_cam.make_current()
	_lamp.light_energy = 2.5
	await _shot("f3_fossiel_samen_derde")
	_lamp.light_energy = 6.0
	finds._release(2, skull.find_id, skull.global_transform, Vector3.ZERO)
	finds._release(3, skull.find_id, skull.global_transform, Vector3.ZERO)
	game._despawn(2)
	game._despawn(3)
	await _wait(0.5)


## Kristalmaan: een kristalgrot (kristallen net achter de wand van een grot), los op de vloer gloeiend, en
## één die breekt.
func _crystal(p: Player) -> void:
	var finds: FindField = main.game.finds
	var t: TerrainAPI = main.terrain
	var best: Array = []
	for it in finds.items:
		if it.fragility < 0.9 or it.freed or it.global_position.y < Strata.TOPS_M[1]:
			continue
		var group: Array = [it]
		for o in finds.items:
			if o != it and not o.freed and o.fragility > 0.0 and o.global_position.distance_to(it.global_position) < 5.0:
				group.append(o)
		if group.size() > best.size():
			best = group
	if best.size() < 2:
		print("[loot_preview] geen kristalgrot gevonden")
		return
	var c := _center(best)
	print("[loot_preview] kristalgrot: %d kristallen op −%.0f m" % [best.size(), t.surface_height_at(c.x, c.z) - c.y])
	var cam_at := c + Vector3(3.0, 1.6, 3.0)
	await _go(p, cam_at)
	# Eerst zoals je ze vindt: de korsten blootgelegd in de wand.
	for it: FindItem in best:
		t.debug_dig(it.global_position, FindKinds.radius(it.kind) + 0.6)
	for k in 4:
		t.debug_dig(c.lerp(cam_at, k / 3.0), 2.2)
	await _settle()
	_cam.fov = 70.0
	_cam.global_position = cam_at
	_cam.look_at(c)
	_cam.make_current()
	_lamp.light_energy = 3.0
	await _shot("f3_kristal_grot")
	# Dan een kamer eromheen: los vallen ze op de vloer en gloeien ze.
	t.debug_dig(c, 4.2)
	t.debug_dig(c + Vector3(0, -1.2, 0), 3.8)
	await _settle()
	for it: FindItem in best:
		finds._free(it.find_id)
	await _wait(4.0)
	var low := c
	low.y = _floor(c) + 0.3
	_cam.global_position = Vector3(c.x + 2.0, low.y + 2.2, c.z + 2.0) # binnen de kamer, schuin op de vloer
	_cam.look_at(low)
	_lamp.light_energy = 0.5 # de kristallen geven zelf licht
	for it: FindItem in best:
		print("[loot_preview] kristal %d: %s, vrij %s, bevroren %s, %.1f m van de camera, in beeld %s" % [it.find_id,
				it.display_name(), it.freed, it.freeze, it.global_position.distance_to(_cam.global_position),
				_cam.is_position_in_frustum(it.global_position)])
	await _shot("f3_kristal_vrij")
	var victim: FindItem = best[0]
	for it: FindItem in best: # de dichtstbijzijnde bij de camera breekt, zodat je het ziet
		if it.global_position.distance_to(_cam.global_position) < victim.global_position.distance_to(_cam.global_position):
			victim = it
	finds._rpc_condition.rpc(victim.find_id, Tuning.get_f("finds", "shatter_condition", 0.08))
	await _wait(0.3)
	await _shot("f3_kristal_breuk_klap")
	await _wait(2.5)
	await _shot("f3_kristal_breuk")
	_lamp.light_energy = 6.0


## De zijscan in het laadruim, met een waterval zoals na een rit langs een skeletbed, en een pijltje in een
## tunnelwand.
func _scan(p: Player) -> void:
	var game: Game = main.game
	var mol: Mol = game.mol
	var finds: FindField = game.finds
	var t: TerrainAPI = main.terrain
	var scan: SideScan = mol.side_scan
	# Een rit van 30 m langs het grootste skelet, 9 m ernaast, op dezelfde diepte.
	var sets := finds.sets()
	var c := mol.body.global_position
	var n := 0
	for id: String in sets:
		var whole := true
		for it: FindItem in sets[id]:
			whole = whole and not it.freed
		if whole and (sets[id] as Array).size() > n and _center(sets[id]).y > Strata.TOPS_M[1]:
			n = (sets[id] as Array).size()
			c = _center(sets[id])
	scan.rows.clear()
	var dir := Vector3(1, 0, 0)
	for i in SideScan.ROWS:
		var o := c + Vector3(0, 0, 9.0) + dir * (i * Tuning.get_f("mol", "side_scan_row_m", 0.6) - 18.0)
		scan.scan_row(Transform3D(Basis.looking_at(dir, Vector3.UP), o))
	scan.rows.reverse() # de nieuwste regel bovenaan
	var hits := 0
	for r: SideScan.Row in scan.rows:
		hits += 1 if r.best_id >= 0 else 0
	print("[loot_preview] zijscan: %d van %d regels met een echo (rit langs %s)" % [hits, scan.rows.size(), c])
	# In de Mol, voor het scherm.
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw - PI * 0.5), mol.to_world_mol(Vector3(0.75, -1.5, 2.55)))
	p.head.rotation.x = deg_to_rad(4)
	p.reset_physics_interpolation()
	p.camera.make_current()
	await _wait(1.5)
	await _shot("f3_zijscan")
	# Een pijltje in een tunnelwand, naar het skelet.
	var tunnel := c + Vector3(0, 0, 9.0)
	for dx in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		t.debug_dig(tunnel + Vector3(dx, 0, 0), 3.0)
	await _go(p, tunnel)
	await _settle()
	var hit: Dictionary = t.raycast(tunnel, c, Layers.TERRAIN)
	if not hit.is_empty():
		scan._rpc_dart(hit.position, c, "BONES %d m" % int(round((hit.position as Vector3).distance_to(c))), scan.darts - 1)
		_cam.global_position = tunnel + Vector3(-3.5, 0.6, -1.2)
		_cam.look_at(hit.position)
		_cam.make_current()
		_lamp.light_energy = 2.5
		await _wait(0.6)
		await _shot("f3_pijltje")


func _floor(at: Vector3) -> float:
	var hit: Dictionary = main.terrain.raycast(at + Vector3(0, 1.0, 0), at - Vector3(0, 10.0, 0))
	return hit.position.y if not hit.is_empty() else at.y - 1.0


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[loot_preview] ", path)
