extends Node
## Ontwerpen van de binnenkant van De Ekster in de echte look van de game: het blokmodel uit
## res://assets/models/concepts/ (standaard interieur_v3.glb) komt op de plek van de hub, met de
## echte Mol in de baai, de planeet onder het schip en het licht van het spel. Beelden op ooghoogte
## van een robot uit de camera's in het model, en één keer van boven (zonder plafond).
## Lege punten in het model: Mol_Dock, Cam_NAAM + Look_NAAM, Lamp_/Glow_RRGGBB/Spot_RRGGBB (lampen, zie
## Ekster.add_lights), Sign_TEKST (bordje, voorkant = +z van het punt).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=interior_preview --no-steam [--model=res://pad.glb] [--only=naam]
## Beelden: logs/interior/<naam>.png

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var out := PerfLog.log_dir().path_join("interior")
	DirAccess.make_dir_recursive_absolute(out)
	var path := str(CmdArgs.value("model", "res://assets/models/concepts/interieur_v3.glb"))
	var model: Node3D = (load(path) as PackedScene).instantiate()
	add_child(model)
	# Kleuren en lampen zoals in het spel (Ekster: dezelfde code als de hub).
	Ekster.apply_materials(model)
	var roof: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Roof") or mi.name.contains("_Roof"):
			roof.append(mi)
		if mi.name.begins_with("Collision"):
			mi.visible = false # botsvorm: enkel voor het spel
	# De hub van het spel weg; het model op zijn plek, zodat de Mol in zijn baai staat.
	game.ship.visible = false
	var dock := model.find_child("Mol_Dock", true, false) as Node3D
	model.global_position = game.mol.body.global_position - dock.position
	Ekster.add_lights(model)
	_add_signs(model)
	var cam := Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.1
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	for c: Node in model.find_children("Cam_*", "Node3D", true, false):
		var shot_name := String(c.name).substr(4)
		if not only.is_empty() and shot_name not in only:
			continue
		var look := model.find_child("Look_" + shot_name, true, false) as Node3D
		cam.global_position = (c as Node3D).global_position
		cam.look_at(look.global_position)
		await _settle(1.0)
		_save(out, shot_name)
	if only.is_empty() or "boven" in only:
		for r in roof:
			r.visible = false
		cam.fov = 50.0
		var center := model.to_global(Vector3(3.0, 0.0, 13.0))
		cam.global_position = center + Vector3(0.0, 58.0, 30.0)
		cam.look_at(center)
		await _settle(1.0)
		_save(out, "boven")
	get_tree().quit(0)


## Bordjes: elk leeg punt "Sign_TEKST" wordt een opschrift dat naar de camera draait
## (achtervoegsels als _001 vallen weg).
func _add_signs(model: Node3D) -> void:
	var re := RegEx.new()
	re.compile("[._]\\d+$")
	for n: Node in model.find_children("Sign_*", "Node3D", true, false):
		var l := Label3D.new()
		l.text = re.sub(String(n.name).substr(5), "").replace("_", " ")
		l.font = UiTheme.heading()
		l.font_size = 72
		l.pixel_size = 0.004
		l.modulate = UiTheme.YELLOW
		l.outline_size = 12
		l.outline_modulate = Color(0.05, 0.04, 0.03)
		l.shaded = false
		l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # in een blokmodel: altijd leesbaar
		(n as Node3D).add_child(l)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _save(out: String, shot_name: String) -> void:
	var file := out.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(file)
	print("[interior_preview] ", file)
