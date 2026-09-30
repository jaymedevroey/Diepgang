extends Node
## M0 stap 7: vaste camera in een tunnel met helmlamp, kristallen en lavagloed.
## Maakt een screenshot in logs/ en sluit af. Draai met verschillende renderers:
##   tools\godot.cmd --path game -- --scenario=render --no-steam
##   tools\godot.cmd --path game --rendering-method gl_compatibility -- --scenario=render --no-steam
## Optioneel: --shot=naam (bestandsnaam zonder extensie), --frames=N (wachttijd na graven).

const TUNNEL_Y := 80.0

var main: Node
var _frames_left := -1


func on_terrain_loaded(_stats: Dictionary) -> void:
	var t: TerrainAPI = main.terrain
	var sc := t.shaft_center_world()
	# Tunnel vanaf de schacht naar buiten, op de grens zandsteen/graniet.
	for i in 44:
		t.debug_dig(Vector3(sc.x + 3.0 + i * 0.45, TUNNEL_Y + sin(i * 0.3) * 0.4, sc.z + sin(i * 0.17) * 0.8), 1.6)
	# Kamer aan het eind.
	var room := Vector3(sc.x + 25.0, TUNNEL_Y + 0.5, sc.z)
	for off in [Vector3.ZERO, Vector3(1.5, 0.8, 1.2), Vector3(-1.2, -0.6, -1.4), Vector3(2.5, -0.3, -1.0), Vector3(0.5, 1.5, 0.0)]:
		t.debug_dig(room + off, 2.8)

	var cam := Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.05
	main.add_child(cam)
	cam.global_position = Vector3(sc.x + 6.0, TUNNEL_Y + 0.4, sc.z)
	cam.look_at(room + Vector3(0, -0.5, 0))
	cam.make_current()

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 25.0
	lamp.spot_angle = 32.0
	lamp.shadow_enabled = true
	cam.add_child(lamp)
	lamp.position = Vector3(0.2, -0.15, 0.0)

	# Kristallen: emissief cyaan, met een kort lampje zonder schaduw (GDD §9).
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color(0.3, 0.9, 1.0)
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color(0.3, 0.9, 1.0)
	crystal_mat.emission_energy_multiplier = 3.0
	for i in 5:
		var prism := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.25, 0.9 + i * 0.15, 0.25)
		prism.mesh = pm
		prism.material_override = crystal_mat
		main.add_child(prism)
		prism.global_position = room + Vector3(1.8 - i * 0.35, -2.2 + i * 0.05, 1.6 - i * 0.5)
		prism.rotation = Vector3(0.3 - i * 0.12, i * 0.7, 0.2 * i - 0.3)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 0.9, 1.0)
	glow.light_energy = 2.0
	glow.omni_range = 5.0
	main.add_child(glow)
	glow.global_position = room + Vector3(1.0, -1.5, 0.6)

	# Lavagloed uit een spleet: oranje emissief vlak + lampje.
	var lava := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.5, 1.2)
	lava.mesh = plane
	var lava_mat := StandardMaterial3D.new()
	lava_mat.albedo_color = Color(1.0, 0.35, 0.05)
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.35, 0.05)
	lava_mat.emission_energy_multiplier = 4.0
	lava.material_override = lava_mat
	main.add_child(lava)
	lava.global_position = room + Vector3(-1.5, -2.6, -1.2)
	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.4, 0.1)
	heat.light_energy = 3.0
	heat.omni_range = 6.0
	main.add_child(heat)
	heat.global_position = room + Vector3(-1.5, -2.0, -1.2)

	_frames_left = int(CmdArgs.value("frames", 120))


func _process(_delta: float) -> void:
	if _frames_left < 0:
		return
	if main.terrain.queued_ops() > 0:
		return
	_frames_left -= 1
	if _frames_left > 0:
		return
	_frames_left = -1
	var method := RenderingServer.get_current_rendering_method()
	var shot_name := str(CmdArgs.value("shot", "render_" + method))
	var path := PerfLog.log_dir().path_join(shot_name + ".png")
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("[render] geen beeld (headless?)")
		get_tree().quit(1)
		return
	img.save_png(path)
	print("[render] screenshot: %s (%dx%d, %s, %d fps)" % [path, img.get_width(), img.get_height(), method, Engine.get_frames_per_second()])
	get_tree().quit(0)
