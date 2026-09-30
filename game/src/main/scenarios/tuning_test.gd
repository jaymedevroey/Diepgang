extends Node
## Test van het tuning-systeem (M1 stap 8). Headless. Zet het bestand na afloop terug.
## tools\godot.cmd --headless --path game -- --scenario=tuning_test --no-steam

var main: Node
var _checks := 0
var _failures := PackedStringArray()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var path := ProjectSettings.globalize_path("res://data/tuning/carry.cfg")
	var original := FileAccess.get_file_as_string(path)
	var before := Tuning.get_f("carry", "throw_speed", 0.0)

	_expect(Tuning.files().has("pickaxe") and Tuning.files().has("lift"), "alle tuning-bestanden geladen (%d)" % Tuning.files().size())
	_expect(Tuning.comment("pickaxe", "strike_s").contains("Zwaai"), "uitleg geldt voor de hele groep eronder")

	Tuning.set_value("carry", "throw_speed", 9.5)
	_expect(is_equal_approx(Tuning.get_f("carry", "throw_speed", 0.0), 9.5), "waarde meteen aangepast")
	Tuning.save("carry")
	var saved := FileAccess.get_file_as_string(path)
	_expect(saved.contains("throw_speed=9.5"), "bewaard in het bestand")
	_expect(saved.contains("; Gooien: snelheid in m/s langs de kijkrichting."), "commentaar blijft staan")
	_expect(saved.count("\n") == original.count("\n"), "zelfde aantal regels")
	Tuning.reload()
	_expect(is_equal_approx(Tuning.get_f("carry", "throw_speed", 0.0), 9.5), "na herladen nog steeds 9.5")

	# Terugzetten.
	FileAccess.open(path, FileAccess.WRITE).store_string(original)
	Tuning.reload()
	_expect(is_equal_approx(Tuning.get_f("carry", "throw_speed", 0.0), before), "origineel teruggezet")

	var snap := Tuning.snapshot()
	_expect(snap.has("drill") and snap["drill"].has("heat_max"), "snapshot voor de clients bevat alles")

	print("[tuning_test] %d controles, %d mislukt → %s" % [_checks, _failures.size(), "GESLAAGD" if _failures.is_empty() else "GEFAALD"])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(cond: bool, what: String) -> void:
	_checks += 1
	print("[tuning_test] %s %s" % ["ok  " if cond else "FOUT", what])
	if not cond:
		_failures.append(what)
