extends Node3D
## Opstartscene. Bouwt het terrein en start een scenario:
##   play (standaard)  speler op het oppervlak, graven met het houweel
##   dig_test          headless controle van graven en de TerrainAPI-laag
##   stress            4 gesimuleerde gravers + 30 fysica-objecten, frametijden naar logs/
##   render            vaste camera in een tunnel, screenshot naar logs/
## Voorbeeld: tools\godot.cmd --path game -- --scenario=stress --duration=60
## Extra in play (voor controle door de agent):
##   --shot=naam --frames=90,140   screenshots N frames na het spawnen, dan afsluiten
##   --autodig                     houweel zwaait vanzelf
##   --pitch=-40                   kijkhoek in graden bij het spawnen

const SCENARIOS := {
	"dig_test": preload("res://src/main/scenarios/dig_test.gd"),
	"stress": preload("res://src/main/scenarios/stress_test.gd"),
	"render": preload("res://src/main/scenarios/render_showcase.gd"),
}
const AIM_COLORS := {
	Pickaxe.Aim.NONE: Color(1, 1, 1, 0.35),
	Pickaxe.Aim.DIGGABLE: Color(1, 1, 1, 0.95),
	Pickaxe.Aim.TOO_HARD: Color(1.0, 0.45, 0.3, 0.95),
}

var terrain: TerrainAPI
var fx: DigFx
var player: DebugPlayer
var scenario := "play"
var scenario_node: Node

var _hud_label: Label
var _crosshair: Label
var _hint: Label
var _stats_visible := true
var _frame_since_spawn := -1
var _shot_frames: PackedInt32Array = []


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

	fx = DigFx.new()
	fx.name = "DigFx"
	add_child(fx)

	_build_hud()
	var overview := $OverviewCamera as Camera3D
	overview.position = terrain.world_size() * Vector3(0.5, 1.0, 0.5) + Vector3(0, 25, 45)
	overview.look_at(terrain.shaft_center_world() + Vector3(0, terrain.world_size().y - 15, 0))

	if CmdArgs.has("shot"):
		for f in str(CmdArgs.value("frames", "90")).split(","):
			_shot_frames.append(int(f))

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
		_spawn_player()
	elif scenario_node and scenario_node.has_method("on_terrain_loaded"):
		scenario_node.on_terrain_loaded(stats)


func _spawn_player() -> void:
	player = DebugPlayer.new()
	player.terrain = terrain
	player.fx = fx
	add_child(player)
	player.global_position = terrain.spawn_point()
	var target := terrain.shaft_center_world()
	target.y = player.global_position.y
	player.look_at(target)
	player.rotation.x = 0.0
	player.head.rotation.x = deg_to_rad(float(CmdArgs.value("pitch", 0.0)))
	player.pickaxe.auto_swing = CmdArgs.has("autodig")
	player.pickaxe.aim_changed.connect(_on_aim_changed)
	_on_aim_changed(player.pickaxe.aim)
	_frame_since_spawn = 0


func _on_aim_changed(aim: Pickaxe.Aim) -> void:
	_crosshair.modulate = AIM_COLORS[aim]
	_hint.text = "Te hard voor het houweel: hier heb je een boor nodig" if aim == Pickaxe.Aim.TOO_HARD else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_stats"):
		_stats_visible = not _stats_visible
		_hud_label.visible = _stats_visible


func _process(_delta: float) -> void:
	if _frame_since_spawn >= 0:
		_frame_since_spawn += 1
		_take_shots()
	if not _stats_visible:
		return
	var lines := PackedStringArray()
	lines.append("DIEPGANG M1-proto  ·  %d fps" % Engine.get_frames_per_second())
	if not terrain.is_loaded:
		lines.append("Put laden…")
	if player:
		var p := player.global_position
		lines.append("Laag: %s  ·  diepte %.0f m%s" % [
			Strata.NAMES[terrain.layer_at(p)], maxf(0.0, terrain.surface_height_at(p.x, p.z) - p.y),
			"  ·  VLIEGEN" if player.flying else ""])
		lines.append("Linkermuis: houweel (vasthouden = doorhakken) · V vliegen · Esc muis los · F3 paneel")
	_hud_label.text = "\n".join(lines)


func _take_shots() -> void:
	if _shot_frames.is_empty():
		return
	var idx := _shot_frames.find(_frame_since_spawn)
	if idx == -1:
		return
	var name := str(CmdArgs.value("shot"))
	if _shot_frames.size() > 1:
		name += "_%d" % (idx + 1)
	var path := PerfLog.log_dir().path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("[diepgang] screenshot: ", path)
	if _frame_since_spawn >= _shot_frames[_shot_frames.size() - 1]:
		get_tree().quit(0)


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 12)
	_hud_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_hud_label)

	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override("font_size", 22)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(_crosshair)

	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hint.position.y += 36
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(1.0, 0.6, 0.45))
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_child(_hint)
