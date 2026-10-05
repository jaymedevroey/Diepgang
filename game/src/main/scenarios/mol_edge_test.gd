extends Node
## De playtest van 2026-10-01 nagespeeld: draaien, over het oppervlak rijden, achteruit, de neus
## 24° omlaag en schuin de grond in, tot tegen de buitenmuur van de put. Toen kwam er rots in de
## cabine (de boorbollen werden aan de rand naar binnen geschoven). Nu: de Mol stopt voor de muur,
## draait niet in de muur, kan achteruit weg, en er zit nooit rots in de romp. Solo, headless.
## tools\godot.cmd --headless --path game -- --scenario=mol_edge_test --no-steam

## Punten in de romp (lokaal x, y) die vrij moeten blijven: cabineplafond, hoeken, vloerhoeken.
const HULL := [Vector2(-2.0, 1.6), Vector2(2.0, 1.6), Vector2(0.0, 1.75), Vector2(-2.0, -1.3), Vector2(2.0, -1.3)]
const HULL_Z := [-3.5, -2.5, -1.5, 0.0, 2.0, 4.0]

var main: Node
var _checks := 0
var _failures := PackedStringArray()
var _worst := 0
var _saw_edge := false


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		print("[mol_edge_test] GEFAALD: time-out")
		get_tree().quit(1))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	var t: TerrainAPI = main.terrain
	while not t.is_loaded:
		await get_tree().physics_frame
	await _wait(1.0)
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
	await _wait(0.4)
	mol.press(Mol.Cmd.SEAT)
	await _wait(0.4)
	_expect(p.seated, "aan het stuur")
	# De planeet is groot: start 80 m van het midden, zodat dezelfde rit als in de playtest de
	# westrand haalt.
	var start := Vector3(t.world_size().x * 0.5 - 80.0, 0.0, t.world_size().z * 0.5)
	start.y = t.surface_height_at(start.x, start.z) - Mol.TRACK_BOTTOM
	mol.teleport(start, 0.0, 0.0)
	await _wait(2.5)

	# (De tijden passen bij de trage Mol van het GDD §5A: ±1,5 m/s, draaien met een aanloop. Dezelfde
	# rit als vroeger, in meter en graden.)
	await _hold("move_left", 6.8, mol, t)
	await _hold("move_forward", 12.0, mol, t)
	await _hold("move_back", 7.5, mol, t)
	await _hold("crouch", 3.0, mol, t)
	_expect(rad_to_deg(mol.pitch) < -20.0, "neus omlaag (%.0f°)" % rad_to_deg(mol.pitch))
	var dive_start := mol.body.global_position
	await _hold("move_forward", 35.0, mol, t)
	_expect(mol.depth() > 3.0, "schuin de grond in geboord (%.1f m diep)" % mol.depth())
	_expect(_saw_edge and absf(mol.speed) < 0.1, "gestopt voor de buitenmuur van de put (x %.1f, z %.1f)" % [mol.body.global_position.x, mol.body.global_position.z])
	var size := t.world_size()
	var pos := mol.body.global_position
	_expect(pos.x > 6.0 and pos.x < size.x - 6.0 and pos.z > 6.0 and pos.z < size.z - 6.0,
			"niet tegen de rand geschoven (x %.1f, z %.1f)" % [pos.x, pos.z])
	_expect(_worst == 0, "tijdens de hele rit geen rots in de romp (slechtste moment: %d punten)" % _worst)
	if DisplayServer.get_name() != "headless": # met venster: kijken hoe de cabine eruitziet
		p.camera.make_current()
		p.head.rotation.x = deg_to_rad(-4)
		await _wait(0.6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(PerfLog.log_dir().path_join("mol_rand.png"))
		p._look_yaw = deg_to_rad(-35)
		await _wait(0.4)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(PerfLog.log_dir().path_join("mol_rand_rechts.png"))
		p._look_yaw = 0.0

	# Draaien tegen de muur: kop en staart mogen er niet in zwaaien.
	var overlap := mol._edge_overlap(mol.body.global_position, mol.forward())
	var tunnel_yaw := mol.yaw
	await _hold("move_left", 2.5, mol, t)
	var after_left := mol._edge_overlap(mol.body.global_position, mol.forward())
	await _hold("move_right", 4.8, mol, t)
	var after_right := mol._edge_overlap(mol.body.global_position, mol.forward())
	# Terug in de richting van de eigen tunnel (draaien heeft een aanloop: sturen tot hij er staat).
	for i in 40:
		var off := angle_difference(mol.yaw, tunnel_yaw)
		if absf(off) < deg_to_rad(3.5):
			break
		await _hold("move_left" if off > 0.0 else "move_right", clampf(absf(rad_to_deg(off)) / 18.0, 0.25, 2.0), mol, t)
	_expect(after_left <= overlap + 0.01 and after_right <= overlap + 0.01,
			"draaien zwaait niet in de muur (%.2f → %.2f / %.2f m)" % [overlap, after_left, after_right])
	_expect(_worst == 0, "na het draaien geen rots in de romp")

	# Achteruit weg van de muur, door de eigen tunnel (enkel daar kan achteruit).
	var before := mol.body.global_position
	await _hold("move_back", 5.0, mol, t)
	_expect(mol.body.global_position.distance_to(before) > 2.0 and not mol.at_edge,
			"achteruit weg van de muur (%.1f m)" % mol.body.global_position.distance_to(before))
	_expect(_worst == 0, "ook achteruit geen rots in de romp")
	print("[mol_edge_test] rit: %.1f m schuin naar beneden" % dive_start.distance_to(mol.body.global_position))

	print("[mol_edge_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	for f in _failures:
		print("[mol_edge_test] MISLUKT: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)


## Een toets ingedrukt houden en intussen elke 0,25 s de romp controleren.
func _hold(action: String, seconds: float, mol: Mol, t: TerrainAPI) -> void:
	Input.action_press(action)
	var steps := int(seconds / 0.25)
	for i in steps:
		await _wait(0.25)
		_check_hull(mol, t)
		_saw_edge = _saw_edge or mol.at_edge
	Input.action_release(action)
	await _wait(0.8)
	_check_hull(mol, t)


func _check_hull(mol: Mol, t: TerrainAPI) -> void:
	var bad := 0
	var where := PackedStringArray()
	for z: float in HULL_Z:
		for c: Vector2 in HULL:
			var w := mol.to_world_mol(Vector3(c.x, c.y, z))
			if t.is_solid(w):
				bad += 1
				where.append("(%.1f, %.1f, %.1f) sdf %.2f" % [c.x, c.y, z, t.sdf_at(w)])
	if bad > _worst:
		print("[mol_edge_test] rots in de romp: %d punten (x %.1f, y %.1f, z %.1f, diepte %.1f, yaw %.0f°): %s" % [bad,
				mol.body.global_position.x, mol.body.global_position.y, mol.body.global_position.z, mol.depth(),
				rad_to_deg(mol.yaw), ", ".join(where)])
	_worst = maxi(_worst, bad)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _expect(ok: bool, what: String) -> void:
	_checks += 1
	print("[mol_edge_test] ", "ok   " if ok else "FOUT ", what)
	if not ok:
		_failures.append(what)
