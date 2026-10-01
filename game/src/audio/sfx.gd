extends Node
## Autoload "Sfx": korte menu- en HUD-geluiden op de UI-bus (assets/audio/ui, tools/audio/synth_ui.py).
## Sfx.ui("click") · "hover" · "back" · "open" · "toast" · "warn" · "pickup"

const POOL := 6

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next := 0
var _last_hover := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"UI"
		add_child(p)
		_players.append(p)


func ui(name: String, volume_db := 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if name == "hover": # niet ratelen als de muis over een rij knoppen glijdt
		var now := Time.get_ticks_msec()
		if now - _last_hover < 45:
			return
		_last_hover = now
	if not _streams.has(name):
		var path := "res://assets/audio/ui/ui_%s.wav" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	if _streams[name] == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.96, 1.04)
	p.play()
