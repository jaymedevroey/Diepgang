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


## Ontwikkelaarsmodus: het tuningmenu (F1) en vliegen (V). Enkel in een debug-build (de editor, de
## tests en previews) of met `--dev`; in de release-build (de demo) staan ze uit (gevoel-07, ui-06).
static func dev_mode() -> bool:
	return OS.is_debug_build() or has("dev")
