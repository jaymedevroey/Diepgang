extends Node
## Autoload "Settings": instellingen van de speler (beeld, geluid, besturing, interface).
## Los van Tuning: Tuning is het spelgevoel (gedeeld met de host), Settings is per pc.
## Bewaard in user://settings.cfg, meteen toegepast bij het wijzigen.

signal changed(key: String)

const PATH := "user://settings.cfg"
const BUSES := ["SFX", "Music", "Voice", "UI"]
const FPS_CAPS := [0, 30, 60, 120, 144, 165, 240]
const MSAA := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]

## Standaardwaarden. Sleutel = "sectie/naam".
const DEFAULTS := {
	"video/window_mode": 1, # 0 venster · 1 volledig scherm (randloos) · 2 exclusief volledig scherm
	"video/vsync": true,
	"video/max_fps": 0, # index in FPS_CAPS (0 = onbeperkt)
	"video/msaa": 2, # index in MSAA (4x)
	"video/render_scale": 1.0, # < 1 met FSR 1.0 opgeschaald
	"video/fov": 80.0,
	"video/brightness": 1.0,
	"audio/master": 0.8,
	"audio/sfx": 1.0,
	"audio/music": 0.7,
	"audio/voice": 1.0,
	"audio/ui": 0.8,
	"audio/mute_unfocused": true,
	"controls/sensitivity": 1.0, # vermenigvuldiger op Tuning player.mouse_sensitivity
	"controls/invert_y": false,
	"interface/ui_scale": 1.0,
	"interface/camera_shake": 1.0,
	"interface/hide_ip": false, # voor streamers: IP-adres nergens tonen
	# HUD per onderdeel (zoals DRG): 0 uit · 1 dynamisch (verschijnt bij een verandering) · 2 altijd.
	"hud/crosshair": 2,
	"hud/prompts": 2,
	"hud/tools": 1,
	"hud/depth": 1,
	"hud/team": 1,
	"hud/sonar": 2, # klein sonarbeeld in buitenzicht
	"hud/stats": 0, # F3-infopaneel (0 uit, 2 aan)
}
const HUD_OFF := 0
const HUD_DYNAMIC := 1
const HUD_ALWAYS := 2

var _cfg := ConfigFile.new()
var _key_cache: Dictionary = {}
var _log_keys := "--log-keys" in OS.get_cmdline_user_args() # toetsen loggen (diagnose)
var _ready_done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	_cfg.load(PATH) # ontbreekt het bestand, dan gelden de standaardwaarden
	InputSetup.ensure() # eerst de standaardtoetsen, dan de eigen toetsen erover
	_load_bindings()
	_ready_done = true
	apply_all()


func get_value(key: String) -> Variant:
	var parts := key.split("/")
	return _cfg.get_value(parts[0], parts[1], DEFAULTS.get(key))


func get_f(key: String) -> float:
	return float(get_value(key))


func get_b(key: String) -> bool:
	return bool(get_value(key))


func set_value(key: String, value: Variant, save_now := true) -> void:
	var parts := key.split("/")
	_cfg.set_value(parts[0], parts[1], value)
	_apply(key)
	changed.emit(key)
	if save_now:
		save()


func reset_section(section: String) -> void:
	if _cfg.has_section(section):
		_cfg.erase_section(section)
	if section == "keys":
		InputMap.load_from_project_settings()
		InputSetup.ensure()
		_key_cache.clear()
	apply_all()
	for key: String in DEFAULTS:
		if key.begins_with(section + "/"):
			changed.emit(key)
	changed.emit(section)
	save()


func save() -> void:
	_cfg.save(PATH)


func apply_all() -> void:
	for key: String in DEFAULTS:
		_apply(key)


func _apply(key: String) -> void:
	if not _ready_done:
		return
	var root := get_tree().root
	match key:
		"video/window_mode":
			var args := OS.get_cmdline_args()
			if DisplayServer.get_name() == "headless" or "--windowed" in args or "--resolution" in args or OS.has_feature("editor"):
				return # tests, screenshots en de editor: venster laten zoals het is
			var mode := int(get_value(key))
			DisplayServer.window_set_mode([DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN,
					DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN][clampi(mode, 0, 2)])
		"video/vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_b(key) else DisplayServer.VSYNC_DISABLED)
		"video/max_fps":
			Engine.max_fps = FPS_CAPS[clampi(int(get_value(key)), 0, FPS_CAPS.size() - 1)]
		"video/msaa":
			root.msaa_3d = MSAA[clampi(int(get_value(key)), 0, MSAA.size() - 1)]
		"video/render_scale":
			var s := clampf(get_f(key), 0.5, 1.0)
			root.scaling_3d_scale = s
			root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
		"interface/ui_scale":
			root.content_scale_factor = clampf(get_f(key), 0.75, 2.0)
		"audio/master", "audio/sfx", "audio/music", "audio/voice", "audio/ui":
			var bus: String = "Master" if key == "audio/master" else BUSES[["audio/sfx", "audio/music", "audio/voice", "audio/ui"].find(key)]
			var i := AudioServer.get_bus_index(bus)
			var v := clampf(get_f(key), 0.0, 1.0)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(i, v <= 0.001)


func _input(event: InputEvent) -> void:
	if _log_keys and event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		var line := "[toets] keycode=%d physical=%d ui_cancel=%s" % [k.keycode, k.physical_keycode, event.is_action_pressed("ui_cancel")]
		print(line)
		var f := FileAccess.open(PerfLog.log_dir().path_join("toetsen.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(PerfLog.log_dir().path_join("toetsen.txt")) else FileAccess.WRITE)
		if f:
			f.seek_end()
			f.store_line(line)


func _notification(what: int) -> void:
	if not _ready_done:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and get_b("audio/mute_unfocused"):
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_apply("audio/master")


# --- Toetsen ------------------------------------------------------------------------------

## Acties die je kan omzetten, in de volgorde van het instellingenmenu, met hun naam.
const BINDABLE := [
	["move_forward", "Vooruit"], ["move_back", "Achteruit"], ["move_left", "Links"], ["move_right", "Rechts"],
	["jump", "Springen · neus omhoog"], ["crouch", "Bukken · neus omlaag"], ["interact", "Gebruiken · oppakken"],
	["dig", "Graven"], ["tool_1", "Houweel"], ["tool_2", "Boor"], ["horn", "Toeter"], ["mol_view", "Buitenzicht (Mol)"],
	["sonar_ping", "Sonar-PING (Mol)"],
]


## Eerste toets of muisknop van een actie, of null.
func binding(action: String) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return ev
	return null


func rebind(action: String, event: InputEvent) -> void:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(action, ev)
	InputMap.action_add_event(action, event)
	_key_cache.clear()
	if event is InputEventKey:
		_cfg.set_value("keys", action, "key:%d" % (event as InputEventKey).physical_keycode)
	elif event is InputEventMouseButton:
		_cfg.set_value("keys", action, "mouse:%d" % (event as InputEventMouseButton).button_index)
	changed.emit("keys/" + action)
	save()


func _load_bindings() -> void:
	if not _cfg.has_section("keys"):
		return
	for action: String in _cfg.get_section_keys("keys"):
		if not InputMap.has_action(action):
			continue
		var spec := str(_cfg.get_value("keys", action)).split(":")
		if spec.size() != 2:
			continue
		var ev: InputEvent
		if spec[0] == "key":
			ev = InputEventKey.new()
			(ev as InputEventKey).physical_keycode = int(spec[1]) as Key
		else:
			ev = InputEventMouseButton.new()
			(ev as InputEventMouseButton).button_index = int(spec[1]) as MouseButton
		for old in InputMap.action_get_events(action):
			if old is InputEventKey or old is InputEventMouseButton:
				InputMap.action_erase_event(action, old)
		InputMap.action_add_event(action, ev)


## Leesbare naam van een toets (volgens het toetsenbord van de speler, dus AZERTY toont Z).
static func event_label(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.keycode
		if k.physical_keycode:
			code = k.physical_keycode
			if DisplayServer.get_name() != "headless": # headless kent geen toetsenbordindeling
				code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		var names := {KEY_SPACE: "Spatie", KEY_CTRL: "Ctrl", KEY_SHIFT: "Shift", KEY_ALT: "Alt", KEY_TAB: "Tab",
				KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_BACKSPACE: "Backspace"}
		return names.get(code, OS.get_keycode_string(code))
	if ev is InputEventMouseButton:
		return {MOUSE_BUTTON_LEFT: "Linkermuis", MOUSE_BUTTON_RIGHT: "Rechtermuis", MOUSE_BUTTON_MIDDLE: "Middelste muis",
				MOUSE_BUTTON_WHEEL_UP: "Wieltje op", MOUSE_BUTTON_WHEEL_DOWN: "Wieltje neer"}.get(
				(ev as InputEventMouseButton).button_index, "Muis %d" % (ev as InputEventMouseButton).button_index)
	return "?"


## Toets van een actie als korte tekst voor in de HUD ("E", "Linkermuis"). Gecachet: de HUD vraagt
## dit elke frame, en de indeling van het toetsenbord opvragen is niet gratis.
func key_of(action: String) -> String:
	if not _key_cache.has(action):
		var ev := binding(action)
		_key_cache[action] = event_label(ev) if ev else "?"
	return _key_cache[action]
