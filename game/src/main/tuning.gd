extends Node
## Autoload "Tuning": laadt alle "gevoel"-waarden uit res://data/tuning/*.cfg (sectie [values]).
## Gebruik: Tuning.get_f("dig", "max_ops_per_second", 8.0)

const DIR := "res://data/tuning/"

var _files: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_files.clear()
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".cfg"):
			continue
		var cfg := ConfigFile.new()
		var err := cfg.load(DIR + file)
		if err != OK:
			push_error("tuning: kan %s niet laden (%s)" % [file, error_string(err)])
			continue
		_files[file.get_basename()] = cfg


func value(file: String, key: String, fallback: Variant) -> Variant:
	var cfg: ConfigFile = _files.get(file)
	if cfg == null:
		return fallback
	return cfg.get_value("values", key, fallback)


func get_f(file: String, key: String, fallback: float) -> float:
	return float(value(file, key, fallback))


func get_i(file: String, key: String, fallback: int) -> int:
	return int(value(file, key, fallback))
