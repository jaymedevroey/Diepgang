class_name PerfLog
extends RefCounted
## Verzamelt per frame meetwaarden en schrijft een CSV plus een samenvatting.
## Kolom 0 is de tijd in s, kolom 1 de frametijd in ms.

var columns := PackedStringArray(["t_s", "frame_ms"])
var rows: Array[PackedFloat32Array] = []


func _init(extra_columns: PackedStringArray = PackedStringArray()) -> void:
	columns.append_array(extra_columns)


func add(values: PackedFloat32Array) -> void:
	rows.append(values)


## logs/ naast het project (editor) of naast de .exe (export).
static func log_dir() -> String:
	var dir: String
	if OS.has_feature("editor"):
		dir = ProjectSettings.globalize_path("res://").path_join("../logs").simplify_path()
	else:
		dir = OS.get_executable_path().get_base_dir().path_join("logs")
	DirAccess.make_dir_recursive_absolute(dir)
	return dir


static func timestamp() -> String:
	return Time.get_datetime_string_from_system().replace(":", "").replace("T", "_")


func summary() -> Dictionary:
	var frames := PackedFloat32Array()
	for r in rows:
		frames.append(r[1])
	var n := frames.size()
	if n == 0:
		return {}
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	var over_16 := 0
	var over_33 := 0
	for v in sorted:
		total += v
		over_16 += int(v > 16.7)
		over_33 += int(v > 33.3)
	var spikes: Array = []
	var idx := range(n)
	idx.sort_custom(func(a: int, b: int) -> bool: return frames[a] > frames[b])
	for i in mini(10, n):
		spikes.append({"t_s": snappedf(rows[idx[i]][0], 0.01), "frame_ms": snappedf(frames[idx[i]], 0.01)})
	return {
		"frames": n,
		"avg_ms": total / n,
		"p50_ms": _pct(sorted, 0.50),
		"p95_ms": _pct(sorted, 0.95),
		"p99_ms": _pct(sorted, 0.99),
		"max_ms": sorted[n - 1],
		"frames_over_16_7ms": over_16,
		"frames_over_33_3ms": over_33,
		"top_spikes": spikes,
	}


func write_csv(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line(",".join(columns))
	for r in rows:
		var cells := PackedStringArray()
		for v in r:
			cells.append("%.3f" % v)
		f.store_line(",".join(cells))


static func _pct(sorted: PackedFloat32Array, p: float) -> float:
	return sorted[clampi(int(ceil(p * sorted.size())) - 1, 0, sorted.size() - 1)]
