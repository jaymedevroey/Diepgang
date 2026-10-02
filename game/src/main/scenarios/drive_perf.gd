extends Node
## Performance van streaming terwijl de Mol over en door de planeet rijdt (met venster).
## Piloot rijdt: 15 s rechtdoor over het oppervlak, dan neus omlaag en 25 s schuin de grond in,
## dan 15 s draaien en rijden onder de grond. Frametijden per seconde naar logs/drive_perf_*.csv.
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=drive_perf --no-steam

var main: Node
var _log := PerfLog.new(PackedStringArray(["fase", "geladen_blokken", "wachtend", "hersteld"]))
var _phase := 0
var _t0 := 0


func _ready() -> void:
	main.game.player_spawned.connect(func(p: Player) -> void: _run.call_deferred(p))


func _process(delta: float) -> void:
	if _t0 == 0:
		return
	var t: TerrainAPI = main.terrain
	var stats: Dictionary = t.get_stats().terrain
	_log.add(PackedFloat32Array([(Time.get_ticks_msec() - _t0) / 1000.0, delta * 1000.0, _phase,
			float(stats.get("updated_blocks", 0)), t.waiting_ops(), t.ops_repaired]))


func _run(p: Player) -> void:
	var mol: Mol = main.game.mol
	await _wait(2.0)
	p.global_transform = Transform3D(Basis(Vector3.UP, mol.yaw), mol.to_world_mol(Vector3(0, -1.45, -1.3)))
	await _wait(0.4)
	mol.press(Mol.Cmd.SEAT)
	await _wait(1.0)
	_t0 = Time.get_ticks_msec()
	_phase = 1
	Input.action_press("move_forward")
	await _wait(15.0)
	_phase = 2
	Input.action_press("crouch")
	await _wait(2.0)
	Input.action_release("crouch")
	await _wait(23.0)
	_phase = 3
	Input.action_press("move_left")
	await _wait(15.0)
	Input.action_release("move_left")
	Input.action_release("move_forward")
	_phase = 4
	await _wait(2.0)
	var s := _summarize()
	print("[drive_perf] %s" % s)
	print("[drive_perf] Mol op %s, diepte %.0f m, ops hersteld %d" % [mol.body.global_position, mol.depth(), main.terrain.ops_repaired])
	get_tree().quit(0)


func _summarize() -> String:
	var out := PackedStringArray()
	for ph in [1, 2, 3]:
		var frames := PackedFloat32Array()
		for r in _log.rows:
			if int(r[2]) == ph:
				frames.append(r[1])
		if frames.is_empty():
			continue
		var sorted := frames.duplicate()
		sorted.sort()
		var sum := 0.0
		for f in frames:
			sum += f
		var over := 0
		for f in frames:
			if f > 33.3:
				over += 1
		out.append("fase %d: gem %.1f ms, p99 %.1f ms, max %.1f ms, %d frames > 33 ms (van %d)" % [
				ph, sum / frames.size(), sorted[int(sorted.size() * 0.99)], sorted[-1], over, frames.size()])
	return " | ".join(out)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
