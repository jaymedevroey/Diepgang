extends Logger
## Telt de fouten die Godot logt (script-fouten, push_error, motorfouten) tijdens een scenario, zodat
## een test kan falen op een foutenstroom die verder niets breekt (zoals de sonar na een nieuwe
## wereld). Gebruik: var log := preload("res://src/main/scenarios/qa_error_log.gd").new();
## OS.add_logger(log) … log.count(), log.first(3).
## Thread-veilig: Godot logt ook vanuit andere threads.

## Bekende ruis die niets zegt over het spel (enkel bij het afsluiten, zie lessons.md).
const IGNORE := ["Parameter \"material\" is null"]

var _mutex := Mutex.new()
var _count := 0
var _messages: PackedStringArray = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, _error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
	var text := rationale if rationale != "" else code
	for skip: String in IGNORE:
		if text.contains(skip):
			return
	# Waar in de scripts (de bovenste drie stappen), want een motorfout zegt enkel "node_3d.cpp".
	var trail: PackedStringArray = []
	for bt in script_backtrace:
		for i in mini(3, bt.get_frame_count()):
			trail.append("%s:%d %s" % [bt.get_frame_file(i).get_file(), bt.get_frame_line(i), bt.get_frame_function(i)])
	_mutex.lock()
	_count += 1
	if _messages.size() < 20:
		_messages.append("%s (%s:%d, %s)%s" % [text, file.get_file(), line, function,
				"" if trail.is_empty() else " ← " + " ← ".join(trail)])
	_mutex.unlock()


func count() -> int:
	_mutex.lock()
	var n := _count
	_mutex.unlock()
	return n


## De eerste `n` verschillende meldingen.
func first(n: int) -> PackedStringArray:
	_mutex.lock()
	var out: PackedStringArray = []
	for m in _messages:
		if not out.has(m):
			out.append(m)
		if out.size() >= n:
			break
	_mutex.unlock()
	return out
