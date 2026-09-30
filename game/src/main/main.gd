extends Node3D
## Opstartscene. Bouwt het terrein en start een scenario:
##   play (standaard)  speler op het oppervlak, graven met de muis
##   dig_test          headless controle van graven en de TerrainAPI-laag
##   stress            4 gesimuleerde gravers + 30 fysica-objecten, frametijden naar logs/
##   render            vaste camera in een tunnel, screenshot naar logs/
## Voorbeeld: tools\godot.cmd --path game -- --scenario=stress --duration=60
## In play: --shot=naam neemt na het spawnen (--frames=N, standaard 90) een screenshot en sluit af.

const SCENARIOS := {
	"dig_test": preload("res://src/main/scenarios/dig_test.gd"),
	"stress": preload("res://src/main/scenarios/stress_test.gd"),
	"render": preload("res://src/main/scenarios/render_showcase.gd"),
}

var terrain: TerrainAPI
var player: DebugPlayer
var scenario := "play"
var scenario_node: Node

var _hud_label: Label
var _stats_visible := true
var _shot_frames_left := -1


func _ready() -> void:
	InputSetup.ensure()
	scenario = str(CmdArgs.value("scenario", "play"))
	var info := Engine.get_version_info()
	print("[diepgang] godot=%s physics=%s renderer=%s adapter=%s scenario=%s" % [
		info.string,
		ProjectSettings.get_setting("physics/3d/physics_engine"),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		scenario])
	print("[diepgang] voxel=%s" % VoxelEngine.get_version_v())

	terrain = TerrainAPI.new()
	terrain.name = "Terrain"
	terrain.pit_seed = int(CmdArgs.value("seed", 1))
	add_child(terrain)
	terrain.loaded.connect(_on_terrain_loaded)

	_build_hud()
	var overview := $OverviewCamera as Camera3D
	overview.position = terrain.world_size() * Vector3(0.5, 1.0, 0.5) + Vector3(0, 25, 45)
	overview.look_at(terrain.shaft_center_world() + Vector3(0, terrain.world_size().y - 15, 0))

	if scenario != "play":
		if not SCENARIOS.has(scenario):
			push_error("onbekend scenario '%s'" % scenario)
			get_tree().quit(2)
			return
		scenario_node = SCENARIOS[scenario].new()
		scenario_node.set("main", self)
		add_child(scenario_node)


func _on_terrain_loaded(stats: Dictionary) -> void:
	print("[diepgang] terrein geladen in %.0f ms (time-out: %s), statisch geheugen %.1f MB, videogeheugen %.1f MB" % [
		stats.load_ms, stats.load_timed_out, stats.mem_static_mb, stats.video_mem_mb])
	print("[diepgang] terrein-statistieken: ", JSON.stringify(stats))
	if scenario == "play":
		player = DebugPlayer.new()
		player.terrain = terrain
		add_child(player)
		player.global_position = terrain.spawn_point()
		player.look_at(terrain.shaft_center_world() + Vector3(0, player.global_position.y, 0))
		player.rotation.x = 0.0
		if CmdArgs.has("shot"):
			_shot_frames_left = int(CmdArgs.value("frames", 90))
	elif scenario_node and scenario_node.has_method("on_terrain_loaded"):
		scenario_node.on_terrain_loaded(stats)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		_stats_visible = not _stats_visible
		_hud_label.visible = _stats_visible


func _process(_delta: float) -> void:
	if _shot_frames_left > 0:
		_shot_frames_left -= 1
		if _shot_frames_left == 0:
			var path := PerfLog.log_dir().path_join(str(CmdArgs.value("shot")) + ".png")
			get_viewport().get_texture().get_image().save_png(path)
			print("[diepgang] screenshot: ", path)
			get_tree().quit(0)
	if not _stats_visible:
		return
	var lines := PackedStringArray()
	lines.append("DIEPGANG M0  ·  %d fps  ·  %.2f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(1.0, Engine.get_frames_per_second())])
	if not terrain.is_loaded:
		lines.append("Put laden…")
	else:
		lines.append("Graafacties: %d" % terrain.ops_applied_total)
	if player:
		var p := player.global_position
		lines.append("Positie: %.1f, %.1f, %.1f  ·  Laag: %s%s" % [
			p.x, p.y, p.z, Strata.NAMES[terrain.layer_at(p)], "  ·  VLIEGEN" if player.flying else ""])
		lines.append("Linkermuis graven · V vliegen · Esc muis los · F3 dit paneel")
	_hud_label.text = "\n".join(lines)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 12)
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_hud_label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(cross)
