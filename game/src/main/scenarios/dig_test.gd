extends Node
## Headless controle van het graven (M0 stap 2 en 4). Eindigt met exitcode 0 als alles klopt.
## tools\godot.cmd --headless --path game -- --scenario=dig_test --no-steam

var main: Node
var _failures := PackedStringArray()
var _checks := 0


func on_terrain_loaded(stats: Dictionary) -> void:
	if stats.load_timed_out:
		_fail("terrein laadt binnen de time-out")
	_run.call_deferred()


func _run() -> void:
	var t: TerrainAPI = main.terrain
	_check_boundary()

	# Graven onder de spawn.
	var spawn := t.spawn_point()
	var p := spawn - Vector3(0, 4.0, 0)
	_expect(t.is_solid(p), "punt 4 m onder de spawn is rots")
	_expect(not t.raycast(spawn, spawn - Vector3(0, 20, 0)).is_empty(), "straal naar beneden raakt de grond")
	_expect(t.request_dig(1, p, 1.5), "eerste graafactie wordt aanvaard")
	await _ticks(2)
	_expect(not t.is_solid(p), "punt is lucht na het graven")

	# Collision volgt: schacht naar beneden graven en wachten tot de straal erdoor gaat.
	for i in 7:
		t.debug_dig(spawn - Vector3(0, 0.5 + i * 0.6, 0), 1.0)
	var through := -1
	for tick in 180:
		await get_tree().physics_frame
		var hit := t.raycast(spawn + Vector3.UP, spawn - Vector3(0, 20, 0))
		if not hit.is_empty() and hit.position.y < p.y - 1.0:
			through = tick
			break
	_expect(through >= 0, "collision volgt het gat (na %d ticks)" % through)

	# Houweelschilfer: ondiep. Net onder het raakpunt lucht, dieper nog rots.
	var wall := spawn + Vector3(3.0, 0, 0)
	var floor_hit := t.raycast(wall + Vector3.UP * 2.0, wall - Vector3.UP * 5.0)
	_expect(not floor_hit.is_empty(), "vloer gevonden voor schilfertest")
	if not floor_hit.is_empty():
		var fp: Vector3 = floor_hit.position
		_expect(t.request_chip(2, fp, floor_hit.normal, 0.75, 0.45, 0.0), "schilfer wordt aanvaard")
		var sunk := -1.0
		for tick in 60:
			await get_tree().physics_frame
			var after := t.raycast(fp + Vector3.UP * 2.0, fp - Vector3.UP * 5.0)
			if not after.is_empty() and after.position.y < fp.y - 0.3:
				sunk = fp.y - after.position.y
				break
		_expect(sunk >= 0.35 and sunk <= 0.7, "schilfer: vloer zakt 0,35-0,7 m (%.2f m)" % sunk)
		_expect(t.is_solid(fp - Vector3(0, 1.0, 0)), "schilfer: 1 m onder het oppervlak is nog rots")
		_expect(t.is_solid(fp + Vector3(0, -0.3, 1.6)), "schilfer: 1,6 m opzij is nog rots")

	# Gereedschapsregels per laag (GDD §4).
	_expect(Strata.can_dig(Strata.Layer.KLEI, Strata.Tool.HOUWEEL), "houweel graaft klei")
	_expect(not Strata.can_dig(Strata.Layer.ZANDSTEEN, Strata.Tool.HOUWEEL), "houweel graaft geen zandsteen")
	_expect(Strata.can_dig(Strata.Layer.ZANDSTEEN, Strata.Tool.BOOR_T1), "boor T1 graaft zandsteen")
	_expect(not Strata.can_dig(Strata.Layer.GRANIET, Strata.Tool.BOOR_T1), "boor T1 graaft geen graniet")

	# Snelheidslimiet.
	var accepted := 0
	for i in 20:
		accepted += int(t.request_dig(7, p - Vector3(0, 3, 0), 0.5))
	var burst := Tuning.get_i("dig", "burst", 3)
	_expect(accepted == burst, "snelheidslimiet: %d van 20 aanvaard (burst %d)" % [accepted, burst])

	# Buitenmuur blijft dicht, ook als je er vlak naast graaft.
	t.debug_dig(Vector3(0.3, 60.0, 0.3), 1.0)
	await _ticks(2)
	_expect(t.is_solid(Vector3(0.5, 60.0, 0.5)), "buitenmuur blijft dicht")

	_expect(t.op_log().size() >= 9, "op-logboek bevat de graafacties (%d)" % t.op_log().size())
	_expect(t.layer_at(Vector3(10, 10, 10)) == Strata.Layer.KRISTAL, "laag onderaan is kristal")
	_expect(t.layer_at(Vector3(10, 145, 10)) == Strata.Layer.KLEI, "laag bovenaan is klei")

	print("[dig_test] %d controles, %d mislukt" % [_checks, _failures.size()])
	for f in _failures:
		print("[dig_test] MISLUKT: ", f)
	print("[dig_test] ", "GESLAAGD" if _failures.is_empty() else "GEFAALD")
	get_tree().quit(0 if _failures.is_empty() else 1)


## Stap 4: buiten src/terrain/ roept geen enkel script de voxel-extensie rechtstreeks aan.
func _check_boundary() -> void:
	var forbidden := ["Voxel" + "Terrain", "Voxel" + "Tool", "do_" + "sphere", "get_voxel_" + "tool", "Voxel" + "Viewer"]
	var offenders := PackedStringArray()
	for path in _scripts_in("res://src"):
		if path.begins_with("res://src/terrain/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for word in forbidden:
			if text.contains(word):
				offenders.append("%s (%s)" % [path, word])
	_expect(offenders.is_empty(), "voxel-extensie enkel via TerrainAPI %s" % ", ".join(offenders))


func _scripts_in(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_in(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	return out


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[dig_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)


func _fail(what: String) -> void:
	_expect(false, what)
