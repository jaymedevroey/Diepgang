extends Node3D
## Opstartscene. Start de netwerksessie en de Game, plus HUD en scenario's.
## Sessie (argumenten na `--`):
##   (niets)                 startmenu (solo, hosten, meedoen); met --solo meteen solo
##   --host [--port=N]       host op poort N (standaard 24565)
##   --join=ADRES [--port=N] verbinden met een host
## Scenario's (--scenario=…):
##   play (standaard)  het spel: op De Ekster beginnen, droppen met de Mol
##   ship_preview      screenshots van De Ekster (de hub langs de route, van buiten, de drop)
##   ship_test         De Ekster en de drop: spawnen op het schip, droppen, landen, ophalen (headless)
##   net_ship_test     host + client droppen samen en komen samen terug (tools/net_test.py --scenario=net_ship_test)
##   drop_sequence     opname van de hele drop (beelden, tijdlijn), zie het bestand voor de opties
##   drop_flow_test    de hele drop als speler met echte invoer (headless; --variant=main|skip|left_behind|on_doors)
##   net_drop_flow_test de drop zoals de client hem beleeft (tools/net_test.py --scenario=net_drop_flow_test)
##   concept_preview   ontwerpen van De Ekster (assets/models/concepts/) in de look van de game
##   sky_preview       de zes controlebeelden van de hemel (--sky=a|b|c), logs/sky/
##   dig_test          headless controle van graven en de TerrainAPI-laag
##   stress            4 gesimuleerde gravers + 30 fysica-objecten, frametijden naar logs/
##   render            vaste camera in een tunnel, screenshot naar logs/
##   net_test          host + client: beweging en terrein-sync (tools/net_test.py)
##   find_test         vondsten en korsten: uitbikken, boren, vrijkomen (headless)
##   carry_test        oppakken, dragen, gooien, botsschade (headless)
##   mol_test          de Mol: besturen, boren, autopiloot, meerijden, extractie (headless)
##   sonar_test        sonar in de Mol (richting, echo's, bereik) en opscheppen door de boorkop (headless)
##   mol_edge_test     de Mol schuin de grond in tot tegen de buitenmuur: geen rots in de romp (headless)
##   stream_test       grote planeet: laden rond de spelers, gaten blijven na ontladen, ops wachten (headless)
##   ore_test          erts: plaatsing, delven, zak vol, storten in de Mol, glinsteren (headless)
##   mol_preview       screenshots van de Mol (buiten, binnen, cabine, afdalen)
##   hud_preview       screenshots van de HUD in alle toestanden
##   ui_preview        thema en instellingenmenu
##   finds_gallery     alle vondsten en het puin naast elkaar (screenshots)
##   tool_preview      screenshots van het gereedschap (studio en first person)
##   ui_test           menu's met echte invoer: Esc, toetsen omzetten, bewaren, pauze (headless)
##   tuning_test       tuning-waarden aanpassen en bewaren (headless)
##   hub_screens_test  de schermen in de hub (tv, firmabord, terminal, taxatie) volgen de firma (headless)
##   economy_test      taxatie en verkoop, sets, upgrades, laadruim, schuld, voorwaarden, bewaren (headless)
##   economy_preview   screenshots van de winkel, de taxatie en de contractkaarten (--only=shop,gate,cards)
##   net_economy_test  host + client: kopen, taxeren en verkopen via de host (tools/net_test.py --scenario=net_economy_test)
##   surface_bench     bouwtijd van het verre landschap per planeet (--contended: terwijl het terrein laadt)
##   feel_bench        metingen en filmpjes van lopen, gereedschap, dragen en vondsten (--part=…)
##   threat_test       dreiging (F2): worm, bakens, gas, neergaan en redden, instortingen, climax (headless)
##   net_threat_test   neergaan, dragen en redden, en de worm in co-op (tools/net_test.py --scenario=net_threat_test)
##   threat_film       films en beelden van de dreiging (--take=model|worm|lunge|gas|rescue|collapse|hud)
## Extra in play (voor controle door de agent):
##   --shot=naam --frames=90,140   screenshots N frames na het spawnen, dan afsluiten
##   --autodig                     gereedschap werkt vanzelf (houweel zwaait, boor boort)
##   --tool=drill                  met de boor beginnen
##   --pitch=-40 --yaw=45          kijkhoek en draai in graden bij het spawnen

const SCENARIOS := {
	"dig_test": preload("res://src/main/scenarios/dig_test.gd"),
	"drop_sequence": preload("res://src/main/scenarios/drop_sequence.gd"),
	"drop_flow_test": preload("res://src/main/scenarios/drop_flow_test.gd"),
	"net_drop_flow_test": preload("res://src/main/scenarios/net_drop_flow_test.gd"),
	"stress": preload("res://src/main/scenarios/stress_test.gd"),
	"render": preload("res://src/main/scenarios/render_showcase.gd"),
	"net_test": preload("res://src/main/scenarios/net_test.gd"),
	"robot_preview": preload("res://src/main/scenarios/robot_preview.gd"),
	"find_test": preload("res://src/main/scenarios/find_test.gd"),
	"find_preview": preload("res://src/main/scenarios/find_preview.gd"),
	"carry_test": preload("res://src/main/scenarios/carry_test.gd"),
	"carry_preview": preload("res://src/main/scenarios/carry_preview.gd"),
	"mol_test": preload("res://src/main/scenarios/mol_test.gd"),
	"sonar_test": preload("res://src/main/scenarios/sonar_test.gd"),
	"stream_test": preload("res://src/main/scenarios/stream_test.gd"),
	"ore_test": preload("res://src/main/scenarios/ore_test.gd"),
	"planet_preview": preload("res://src/main/scenarios/planet_preview.gd"),
	"drive_perf": preload("res://src/main/scenarios/drive_perf.gd"),
	"mol_edge_test": preload("res://src/main/scenarios/mol_edge_test.gd"),
	"mol_preview": preload("res://src/main/scenarios/mol_preview.gd"),
	"tuning_test": preload("res://src/main/scenarios/tuning_test.gd"),
	"terrain_preview": preload("res://src/main/scenarios/terrain_preview.gd"),
	"ui_preview": preload("res://src/main/scenarios/ui_preview.gd"),
	"hud_preview": preload("res://src/main/scenarios/hud_preview.gd"),
	"ui_test": preload("res://src/main/scenarios/ui_test.gd"),
	"tool_preview": preload("res://src/main/scenarios/tool_preview.gd"),
	"finds_gallery": preload("res://src/main/scenarios/finds_gallery.gd"),
	"ship_preview": preload("res://src/main/scenarios/ship_preview.gd"),
	"ship_test": preload("res://src/main/scenarios/ship_test.gd"),
	"concept_preview": preload("res://src/main/scenarios/concept_preview.gd"),
	"sky_preview": preload("res://src/main/scenarios/sky_preview.gd"),
	"net_ship_test": preload("res://src/main/scenarios/net_ship_test.gd"),
	"magma_preview": preload("res://src/main/scenarios/magma_preview.gd"),
	"magma_test": preload("res://src/main/scenarios/magma_test.gd"),
	"company_test": preload("res://src/main/scenarios/company_test.gd"),
	"interior_preview": preload("res://src/main/scenarios/interior_preview.gd"),
	"hub_screens_test": preload("res://src/main/scenarios/hub_screens_test.gd"),
	"surface_bench": preload("res://src/main/scenarios/surface_bench.gd"),
	"feel_bench": preload("res://src/main/scenarios/feel_bench.gd"),
	"economy_test": preload("res://src/main/scenarios/economy_test.gd"),
	"economy_preview": preload("res://src/main/scenarios/economy_preview.gd"),
	"net_economy_test": preload("res://src/main/scenarios/net_economy_test.gd"),
	"threat_test": preload("res://src/main/scenarios/threat_test.gd"),
	"net_threat_test": preload("res://src/main/scenarios/net_threat_test.gd"),
	"threat_film": preload("res://src/main/scenarios/threat_film.gd"),
}
## Scenario's die op De Ekster beginnen (de Mol in de dropbaai). De rest begint op de planeet.
const SCENARIOS_ON_SHIP := ["play", "ship_preview", "drop_sequence", "drop_flow_test", "net_drop_flow_test", "ship_test", "net_ship_test", "company_test", "interior_preview", "surface_bench", "economy_test", "economy_preview", "net_economy_test"]
## Scenario's waarin de host ook een eigen speler krijgt.
const SCENARIOS_WITH_PLAYER := ["play", "ship_preview", "drop_sequence", "drop_flow_test", "net_drop_flow_test", "ship_test", "net_ship_test", "net_test", "find_test", "carry_test", "carry_preview", "mol_test", "sonar_test", "mol_edge_test", "stream_test", "ore_test", "drive_perf", "mol_preview", "hud_preview", "ui_test", "tool_preview", "magma_test", "company_test", "surface_bench", "feel_bench", "economy_test", "economy_preview", "net_economy_test", "threat_test", "net_threat_test", "threat_film"]

var game: Game
var player: Player
var scenario := "play"
var scenario_node: Node
var terrain: TerrainAPI:
	get:
		return game.terrain if game else null

var hud: Hud
## Tijd tot het gebied rond de start geladen was (ms), voor tests.
var load_ms := 0.0
var _loading: LoadingScreen
var _pause: PauseMenu
var _terminal: TerminalMenu
var _shop: ShopMenu
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
	game.start_on_ship = scenario in SCENARIOS_ON_SHIP and not CmdArgs.has("on-planet")
	# De firma bewaren: in het echte spel altijd, in tests enkel met --save=naam.
	game.company_save = "firma" if scenario == "play" else str(CmdArgs.value("save", ""))
	add_child(game)
	game.notice.connect(func(t: String, kind: String) -> void: hud.toast(t, kind))
	game.terminal_requested.connect(func(_p: Player) -> void: _terminal.open(game.company))
	game.company.shop_requested.connect(func(counter: String) -> void: _shop.open(game.company, counter))
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
			_start_menu.show_error("Network: " + reason)
		else:
			hud.toast("Network: " + reason, "warn", 8.0))
	Net.ended.connect(func(reason: String) -> void: hud.toast("Session over: " + reason, "warn", 10.0))
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
	_loading.show_status("CONNECTING TO %s" % ("THE HOST" if Settings.get_b("interface/hide_ip") else address))
	Net.join(address, port)


func _on_net_started() -> void:
	if Net.is_host():
		if scenario == "play":
			_loading.show_status("PREPARING THE MAGPIE")
		game.start_host(int(CmdArgs.value("seed", 1)))
	else:
		_loading.show_status("FETCHING THE WORLD FROM THE HOST")
		game.start_client()


func _on_world_loaded(stats: Dictionary) -> void:
	load_ms = stats.load_ms
	if _atmosphere == null:
		_atmosphere = Atmosphere.new()
		_atmosphere.name = "Atmosphere"
		add_child(_atmosphere)
		_atmosphere.setup(($WorldEnvironment as WorldEnvironment).environment, terrain, game.planet_type)
	_atmosphere.terrain = terrain # nieuwe wereld per dienst
	_atmosphere.set_planet(game.planet_type) # andere planeet: andere hemel, zon en sfeer
	_atmosphere.ship = game.ship
	if not _mol_connected:
		_mol_connected = true
		# De Mol zegt zelf hoe dringend een melding is (mol, warn, alarm): niet op de zin matchen.
		game.mol.notice.connect(func(t: String, kind: String) -> void: hud.toast(t, kind))
		# De stempel landt op het moment dat je de besturing terugkrijgt, niet in de klap zelf.
		game.mol.landed.connect(func() -> void:
			if player and game.mol.contains_point(player.global_position):
				await get_tree().create_timer(Tuning.get_f("ship", "drop_handover_s", 0.7)).timeout
				if player == null:
					return
				var c: Company = game.company
				var where: String = str(c.contract.get("name", "CLAIM %d" % (game.pit_seed % 97 + 1)))
				hud.stamp(PlanetType.NAMES[game.planet_type].to_upper(), "%s · QUARTER %d · SHIFT %d" % [where, c.quarter, c.shift]))
		game.mol.summary.connect(func(count: int, value: int, left_behind: int) -> void:
			if game.ship == null: # met het schip komt het incidentrapport van de firma
				hud.show_result(count, value, left_behind, game.mol.last_ore_units, game.mol.last_ore_value))
		game.company.report_ready.connect(hud.show_report)
	print("[diepgang] terrein geladen in %.0f ms (time-out: %s), statisch geheugen %.1f MB, videogeheugen %.1f MB" % [
		stats.load_ms, stats.load_timed_out, stats.mem_static_mb, stats.video_mem_mb])
	print("[diepgang] terrein-statistieken: ", JSON.stringify(stats))
	var overview := $OverviewCamera as Camera3D
	overview.position = terrain.world_size() * Vector3(0.5, 1.0, 0.5) + Vector3(0, 25, 45)
	overview.look_at(terrain.shaft_center_world() + Vector3(0, terrain.world_size().y - 15, 0))
	if not game.spawn_host_player and Net.is_host():
		_loading.finish() # scenario's zonder speler (previews): anders blijft het laadscherm staan
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
	p.rescued.connect(func() -> void: hud.toast("You fell through the world: put back in the Mole", "warn"))
	if CmdArgs.value("tool", "") == "drill":
		p.select_tool(1)
	_loading.finish()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # meteen kunnen rondkijken, zonder eerst te klikken
	if Net.mode == Net.Mode.HOST:
		hud.toast("You're hosting. Friends join via Esc > Invite friends.", "info", 7.0)
	_frame_since_spawn = 0
	if CmdArgs.has("tuning-open") and CmdArgs.dev_mode():
		_tuning_menu.toggle()


func _unhandled_input(event: InputEvent) -> void:
	# Het tuningmenu is gereedschap voor ons, niet voor spelers: enkel in de ontwikkelaarsmodus.
	if event.is_action_pressed("toggle_tuning") and CmdArgs.dev_mode():
		_tuning_menu.toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_stats"):
		Settings.set_value("hud/stats", Settings.HUD_OFF if int(Settings.get_value("hud/stats")) == Settings.HUD_ALWAYS else Settings.HUD_ALWAYS)
	elif event.is_action_pressed("ui_cancel") and player and not (_start_menu and _start_menu.visible) and not _tuning_menu.visible and not _terminal.visible and not _shop.visible:
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
	# Met het pauzemenu open geen HUD erachter: de kaarten van het menu en de banner van de HUD
	# vielen over elkaar (ui-14).
	_pause.visibility_changed.connect(func() -> void: hud.modulate.a = 0.0 if _pause.visible else 1.0)
	layer.add_child(_pause)
	_terminal = TerminalMenu.new()
	layer.add_child(_terminal)
	_shop = ShopMenu.new()
	layer.add_child(_shop)
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
