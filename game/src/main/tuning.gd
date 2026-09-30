extends Node
## Autoload "Tuning": alle "gevoel"-waarden uit res://data/tuning/*.cfg (sectie [values]).
## Gebruik: Tuning.get_f("dig", "max_ops_per_second", 8.0)
##
## - Aanpassen tijdens het spel: set_value (tuning-menu, F1). Werkt meteen.
## - Bewaren: in de editor naar res://data/tuning/ (wordt de nieuwe standaard), in een
##   build naar user://tuning/ (overschrijft de standaard bij het laden).
## - Co-op: de host stuurt zijn waarden naar iedereen (apply_remote), anders zou een client
##   bv. sneller mogen graven dan de host toelaat en lopen de werelden uiteen.

signal changed(file: String, key: String)
signal remote_applied

const DIR := "res://data/tuning/"
const USER_DIR := "user://tuning/"

var _files: Dictionary = {} # naam -> ConfigFile
var _comments: Dictionary = {} # "naam/sleutel" -> uitleg uit het bestand
var _remote := false


func _ready() -> void:
	reload()


func reload() -> void:
	_files.clear()
	_comments.clear()
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".cfg"):
			continue
		var cfg := ConfigFile.new()
		var err := cfg.load(DIR + file)
		if err != OK:
			push_error("tuning: kan %s niet laden (%s)" % [file, error_string(err)])
			continue
		var base := file.get_basename()
		_files[base] = cfg
		_read_comments(base, DIR + file)
		# Eigen waarden van deze pc (build) over de standaard heen.
		var user := ConfigFile.new()
		if not OS.has_feature("editor") and user.load(USER_DIR + file) == OK:
			for key in user.get_section_keys("values"):
				cfg.set_value("values", key, user.get_value("values", key))


func value(file: String, key: String, fallback: Variant) -> Variant:
	var cfg: ConfigFile = _files.get(file)
	if cfg == null:
		return fallback
	return cfg.get_value("values", key, fallback)


func get_f(file: String, key: String, fallback: float) -> float:
	return float(value(file, key, fallback))


func get_i(file: String, key: String, fallback: int) -> int:
	return int(value(file, key, fallback))


# --- Menu en bewaren ------------------------------------------------------------

func files() -> PackedStringArray:
	var names := PackedStringArray(_files.keys())
	names.sort()
	return names


func keys(file: String) -> PackedStringArray:
	var cfg: ConfigFile = _files.get(file)
	return cfg.get_section_keys("values") if cfg else PackedStringArray()


func comment(file: String, key: String) -> String:
	return _comments.get(file + "/" + key, "")


func set_value(file: String, key: String, v: Variant) -> void:
	var cfg: ConfigFile = _files.get(file)
	if cfg == null:
		return
	cfg.set_value("values", key, v)
	changed.emit(file, key)


## Schrijft één bestand weg. Commentaar in het standaardbestand blijft behouden
## (enkel de waarden op de regels "sleutel=waarde" worden vervangen).
func save(file: String) -> String:
	var cfg: ConfigFile = _files.get(file)
	if cfg == null:
		return ""
	if OS.has_feature("editor"):
		var path := ProjectSettings.globalize_path(DIR + file + ".cfg")
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var line := lines[i]
			var eq := line.find("=")
			if eq > 0 and not line.begins_with(";") and not line.begins_with("["):
				var key := line.substr(0, eq).strip_edges()
				if cfg.has_section_key("values", key):
					lines[i] = "%s=%s" % [key, var_to_str(cfg.get_value("values", key))]
		FileAccess.open(path, FileAccess.WRITE).store_string("\n".join(lines))
		return path
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var user := ConfigFile.new()
	for key in cfg.get_section_keys("values"):
		user.set_value("values", key, cfg.get_value("values", key))
	user.save(USER_DIR + file + ".cfg")
	return ProjectSettings.globalize_path(USER_DIR + file + ".cfg")


## Alle waarden, om naar de clients te sturen.
func snapshot() -> Dictionary:
	var out := {}
	for file: String in _files:
		var values := {}
		for key in keys(file):
			values[key] = value(file, key, null)
		out[file] = values
	return out


## Client: waarden van de host overnemen (niet bewaren).
func apply_remote(snap: Dictionary) -> void:
	_remote = true
	for file: String in snap:
		var cfg: ConfigFile = _files.get(file)
		if cfg == null:
			continue
		for key: String in snap[file]:
			cfg.set_value("values", key, snap[file][key])
	remote_applied.emit()


## True als de waarden van de host komen (dan is aanpassen zinloos: de host beslist).
func is_remote() -> bool:
	return _remote


## Een commentaarblok geldt voor alle sleutels eronder, tot een lege regel.
func _read_comments(file: String, path: String) -> void:
	var block := PackedStringArray()
	var in_comment := false
	var current := ""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with(";"):
			if not in_comment:
				block.clear()
			in_comment = true
			block.append(line.trim_prefix(";").strip_edges())
			current = "\n".join(block)
		elif line.find("=") > 0:
			in_comment = false
			_comments[file + "/" + line.substr(0, line.find("=")).strip_edges()] = current
		else:
			in_comment = false
			current = ""
