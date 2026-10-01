extends Node3D
## Opstartscene. Start de netwerksessie en de Game, plus HUD en scenario's.
## Sessie (argumenten na `--`):
##   (niets)                 startmenu (solo, hosten, meedoen); met --solo meteen solo
##   --host [--port=N]       host op poort N (standaard 24565)
##   --join=ADRES [--port=N] verbinden met een host
## Scenario's (--scenario=…):
##   play (standaard)  speler op het oppervlak, graven met het houweel
##   dig_test          headless controle van graven en de TerrainAPI-laag
##   stress            4 gesimuleerde gravers + 30 fysica-objecten, frametijden naar logs/
##   render            vaste camera in een tunnel, screenshot naar logs/
##   net_test          host + client: beweging en terrein-sync (tools/net_test.py)
##   find_test         vondsten en korsten: uitbikken, boren, vrijkomen (headless)
##   carry_test        oppakken, dragen, gooien, botsschade (headless)
##   mol_test          de Mol: besturen, boren, autopiloot, meerijden, extractie (headless)
##   mol_preview       screenshots van de Mol (buiten, binnen, cabine, afdalen)
##   hud_preview       screenshots van de HUD in alle toestanden
##   ui_preview        thema en instellingenmenu
##   tool_preview      screenshots van het gereedschap (studio en first person)
##   ui_test           menu's met echte invoer: Esc, toetsen omzetten, bewaren, pauze (headless)
##   tuning_test       tuning-waarden aanpassen en bewaren (headless)
## Extra in play (voor controle door de agent):
##   --shot=naam --frames=90,140   screenshots N frames na het spawnen, dan afsluiten
##   --autodig                     gereedschap werkt vanzelf (houweel zwaait, boor boort)
##   --tool=drill                  met de boor beginnen
##   --pitch=-40 --yaw=45          kijkhoek en draai in graden bij het spawnen

const SCENARIOS := {
	"dig_test": preload("res://src/main/scenarios/dig_test.gd"),
	"stress": preload("res://src/main/scenarios/stress_test.gd"),
	"render": preload("res://src/main/scenarios/render_showcase.gd"),
	"net_test": preload("res://src/main/scenarios/net_test.gd"),
	"robot_preview": preload("res://src/main/scenarios/robot_preview.gd"),
	"find_test": preload("res://src/main/scenarios/find_test.gd"),
	"find_preview": preload("res://src/main/scenarios/find_preview.gd"),
	"carry_test": preload("res://src/main/scenarios/carry_test.gd"),
	"carry_preview": preload("res://src/main/scenarios/carry_preview.gd"),
	"mol_test": preload("res://src/main/scenarios/mol_test.gd"),
	"mol_preview": preload("res://src/main/scenarios/mol_preview.gd"),
	"tuning_test": preload("res://src/main/scenarios/tuning_test.gd"),
	"terrain_preview": preload("res://src/main/scenarios/terrain_preview.gd"),
	"ui_preview": preload("res://src/main/scenarios/ui_preview.gd"),
	"hud_preview": preload("res://src/main/scenarios/hud_preview.gd"),
	"ui_test": preload("res://src/main/scenarios/ui_test.gd"),
	"tool_preview": preload("res://src/main/scenarios/tool_preview.gd"),
}
## Scenario's waarin de host ook een eigen speler krijgt.
const SCENARIOS_WITH_PLAYER := ["play", "net_test", "find_test", "carry_test", "carry_preview", "mol_test", "mol_preview", "hud_preview", "ui_test", "tool_preview"]

var game: Game
var player: Player
var scenario := "play"
var scenario_node: Node
var terrain: TerrainAPI:
	get:
		return game.terrain if game else null

var hud: Hud
var _loading: LoadingScreen
var _pause: PauseMenu
var _tuning_menu: TuningMenu
var _start_menu: StartMenu
var _backdrop: MenuBackdrop
var _atmosphere: Atmosphere
var _mol_connected := false
var _frame_since_spawn := -1
var _shot_frames: PackedInt32Array = []


func _ready() -> void:
	InputSetup.ensure()
	get_tree().root.theme = UiTheme.get_theme() # huisstijl voor alle menu's en de HUD
	scenario = str(CmdArgs.value("scenario", "play"))
	var info := Engine.get_version_info()
	print("[diepgang] godot=%s physics=%s renderer=%s adapter=%s scenario=%s" % [
		info.string,
		ProjectSettings.get_setting("physics/3d/physics_engine"),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		scenario])
	print("[diepgang] voxel=%s" % VoxelEngine.get_version_v())

	_build_hud()
	if CmdArgs.has("shot"):
		for f in str(CmdArgs.value("frames", "90")).split(","):
			_shot_frames.append(int(f))

	game = Game.new()
	game.name = "Game"
	game.spawn_host_player = scenario in SCENARIOS_WITH_PLAYER
	add_child(game)
	game.world_loaded.connect(_on_world_loaded)
	game.player_spawned.connect(_on_player_spawned)

	if scenario != "play":
		if not SCENARIOS.has(scenario):
			push_error("onbekend scenario '%s'" % scenario)
			get_tree().quit(2)
			return
		scenario_node = SCENARIOS[scenario].new()
		scenario_node.name = "Scenario"
		scenario_node.set("main", self)
		add_child(scenario_node)

	Net.started.connect(_on_net_started)
	Net.failed.connect(func(reason: String) -> void:
		_loading.finish()
		if _start_menu:
			_start_menu.show_error("Netwerk: " + reason)
		else:
			hud.toast("Netwerk: " + reason, "warn", 8.0))
	Net.ended.connect(func(reason: String) -> void: hud.toast("Sessie voorbij: " + reason, "warn", 10.0))
	var port := int(CmdArgs.value("port", Net.DEFAULT_PORT))
	if CmdArgs.has("host"):
		Net.start_host(port)
	elif CmdArgs.has("join"):
		_join(str(CmdArgs.value("join")), port)
	elif scenario == "ui_test":
		pass # de test start zelf een solo-sessie
	elif scenario != "play" or CmdArgs.has("solo") or CmdArgs.has("shot"):
		Net.start_solo()
	else:
		_open_start_menu(port)


func _open_start_menu(port: int) -> void:
	_backdrop = MenuBackdrop.new()
	_backdrop.name = "MenuBackdrop"
	add_child(_backdrop)
	_start_menu = StartMenu.new()
	_start_menu.backdrop = _backdrop
	$HUD.add_child(_start_menu)
	_start_menu.solo_chosen.connect(func() -> void:
		_start_menu.visible = false
		Net.start_solo())
	_start_menu.host_chosen.connect(func() -> void:
		_start_menu.visible = false
		Net.start_host(port))
	_start_menu.join_chosen.connect(func(address: String) -> void:
		_start_menu.visible = false
		_join(address, port))


func _join(address: String, port: int) -> void:
	_loading.show_status("VERBINDEN MET %s" % ("DE HOST" if Settings.get_b("interface/hide_ip") else address))
	Net.join(address, port)


func _on_net_started() -> void:
	if Net.is_host():
		if scenario == "play":
			_loading.show_status("DE PUT WORDT KLAARGEMAAKT")
		game.start_host(int(CmdArgs.value("seed", 1)))
	else:
		_loading.show_status("WERELD OPHALEN BIJ DE HOST")
		game.start_client()


func _on_world_loaded(stats: Dictionary) -> void:
	if _atmosphere == null:
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "Atmosphere"
		add_child(_atmosphere)
		_atmosphere.setup(($WorldEnvironment as WorldEnvironment).environment, terrain)
	if not _mol_connected:
		_mol_connected = true
		game.mol.message.connect(func(t: String) -> void:
			hud.toast(t, "warn" if t.begins_with("Harde laag") else "mol"))
		game.mol.summary.connect(func(count: int, value: int, left_behind: int) -> void:
			hud.show_result(count, value, left_behind))
	print("[diepgang] terrein geladen in %.0f ms (time-out: %s), statisch geheugen %.1f MB, videogeheugen %.1f MB" % [
		stats.load_ms, stats.load_timed_out, stats.mem_static_mb, stats.video_mem_mb])
	print("[diepgang] terrein-statistieken: ", JSON.stringify(stats))
	var overview := $OverviewCamera as Camera3D
	overview.position = terrain.world_size() * Vector3(0.5, 1.0, 0.5) + Vector3(0, 25, 45)
	overview.look_at(terrain.shaft_center_world() + Vector3(0, terrain.world_size().y - 15, 0))
	if scenario_node and scenario_node.has_method("on_terrain_loaded"):
		scenario_node.on_terrain_loaded(stats)


func _on_player_spawned(p: Player) -> void:
	print("[diepgang] speler %d gespawnd%s" % [p.peer_id, " (lokaal)" if p.is_local else ""])
	if not p.is_local:
		return
	player = p
	if _backdrop:
		_backdrop.queue_free() # het menu-decor is niet meer nodig zodra je in de put staat
		_backdrop = null
	p.head.rotation.x = deg_to_rad(float(CmdArgs.value("pitch", 0.0)))
	p.rotate_y(deg_to_rad(float(CmdArgs.value("yaw", 0.0))))
	p.pickaxe.auto_swing = CmdArgs.has("autodig")
	p.drill.auto_use = CmdArgs.has("autodig")
	p.rescued.connect(func() -> void: hud.toast("Je viel door de wereld: teruggezet in de Mol", "warn"))
	if CmdArgs.value("tool", "") == "drill":
		p.select_tool(1)
	_loading.finish()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # meteen kunnen rondkijken, zonder eerst te klikken
	if Net.mode == Net.Mode.HOST:
		hud.toast("Je host. Vrienden doen mee via Esc > Vrienden uitnodigen.", "info", 7.0)
	_frame_since_spawn = 0
	if CmdArgs.has("tuning-open"):
		_tuning_menu.toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_tuning"):
		_tuning_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_stats"):
		Settings.set_value("hud/stats", Settings.HUD_OFF if int(Settings.get_value("hud/stats")) == Settings.HUD_ALWAYS else Settings.HUD_ALWAYS)
	elif event.is_action_pressed("ui_cancel") and player and not (_start_menu and _start_menu.visible) and not _tuning_menu.visible:
		_pause.open()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _frame_since_spawn >= 0:
		_frame_since_spawn += 1
		_take_shots()
	hud.update(player if not (_start_menu and _start_menu.visible) else null, game, terrain)


func _take_shots() -> void:
	if _shot_frames.is_empty():
		return
	var idx := _shot_frames.find(_frame_since_spawn)
	if idx == -1:
		return
	var shot_name := str(CmdArgs.value("shot"))
	if _shot_frames.size() > 1:
		shot_name += "_%d" % (idx + 1)
	var path := PerfLog.log_dir().path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[diepgang] screenshot: ", path)
	if _frame_since_spawn >= _shot_frames[_shot_frames.size() - 1]:
		get_tree().quit(0)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	layer.add_child(hud)
	_pause = PauseMenu.new()
	_pause.leave_requested.connect(_leave_to_menu)
	layer.add_child(_pause)
	_loading = LoadingScreen.new()
	layer.add_child(_loading)

	_tuning_menu = TuningMenu.new()
	_tuning_menu.theme = UiTheme.get_theme()
	layer.add_child(_tuning_menu)


## Terug naar het hoofdmenu: sessie verlaten en de hoofdscène opnieuw laden.
func _leave_to_menu() -> void:
	get_tree().paused = false
	Net.leave()
	get_tree().reload_current_scene()
