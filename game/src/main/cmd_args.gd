class_name CmdArgs
extends RefCounted
## Gebruikersargumenten na `--`, bv. `godot --path game -- --scenario=stress --duration=60`.

static var _parsed: Dictionary = {}
static var _done := false


static func all() -> Dictionary:
	if not _done:
		_done = true
		for arg in OS.get_cmdline_user_args():
			if not arg.begins_with("--"):
				continue
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq == -1:
				_parsed[body] = true
			else:
				_parsed[body.substr(0, eq)] = body.substr(eq + 1)
	return _parsed


static func has(key: String) -> bool:
	return all().has(key)


static func value(key: String, fallback: Variant = null) -> Variant:
	return all().get(key, fallback)
