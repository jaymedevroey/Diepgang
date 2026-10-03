extends Node
## Ontwerpen van de binnenkant van De Ekster in de echte look van de game: het blokmodel uit
## res://assets/models/concepts/ (standaard interieur_v3.glb) komt op de plek van de hub, met de
## echte Mol in de baai, de planeet onder het schip, de hemel en het licht van het spel, en wordt
## vastgelegd op ooghoogte van een robot (1,2 m) en één keer van boven (zonder plafond).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=interior_preview --no-steam [--model=res://pad.glb] [--only=naam]
## Beelden: logs/interior/<naam>.png

const EYE := 1.2

var main: Node
## naam -> [van (lokaal), naar (lokaal)]
var shots := {
	"spawn": [Vector3(16.0, 2.4 + EYE, 13.0), Vector3(-3.0, 4.0, -20.0)],
	"opdrachttafel": [Vector3(19.5, 1.2 + EYE, -5.0), Vector3(-2.0, 3.0, -21.0)],
	"hangar": [Vector3(-1.0, EYE, 13.5), Vector3(0.5, 5.0, -14.0)],
	"raam": [Vector3(-2.5, EYE, -20.0), Vector3(2.0, 3.0, 8.0)],
	"terras": [Vector3(-14.5, 1.2 + EYE, 0.0), Vector3(-24.0, 2.4, -9.5)],
	"hoek": [Vector3(-17.0, -0.6 + EYE, 19.0), Vector3(-3.0, 3.0, 0.0)],
	"werkplaats": [Vector3(-4.0, EYE, -16.0), Vector3(-10.0, 2.0, -8.0)],
	"nis": [Vector3(-16.0, 1.2 + EYE, -9.5), Vector3(-26.0, 2.0, -9.5)],
	"glasvloer": [Vector3(-3.0, EYE, -16.0), Vector3(1.0, -6.0, -24.0)],
}


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
	# Kleuren van het spel (machine-shader, lampen, glas), zoals het buitenschip.
	var cache := {}
	var roof: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Roof"):
			roof.append(mi)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mi.name.begins_with("Glass") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var key := src.resource_name if src else ""
			if not cache.has(key):
				cache[key] = MolVisual.palette_material(key, src, true)
			if cache[key]:
				mi.set_surface_override_material(i, cache[key])
	# De oude hub weg; het blokmodel zo dat de Mol in zijn baai staat.
	game.ship.visible = false
	var dock := model.find_child("Mol_Dock", true, false) as Node3D
	model.global_position = game.mol.body.global_position - dock.position
	_add_lights(model)
	_add_signs(model)
	var cam := Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.1
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	for shot_name: String in shots:
		if not only.is_empty() and shot_name not in only:
			continue
		var s: Array = shots[shot_name]
		cam.global_position = model.to_global(s[0])
		cam.look_at(model.to_global(s[1]))
		await _settle(1.0)
		_save(out, shot_name)
	if only.is_empty() or "boven" in only:
		for r in roof:
			r.visible = false
		cam.fov = 50.0
		cam.global_position = model.to_global(Vector3(0.0, 70.0, 40.0))
		cam.look_at(model.to_global(Vector3(0.0, 0.0, 0.0)))
		await _settle(1.0)
		_save(out, "boven")
	get_tree().quit(0)


## Lampen bij de armaturen (warm), een eigen kleur per post (lege punten Glow_RRGGBB), een
## koel licht van het grote raam, en spots in de hangar.
func _add_lights(model: Node3D) -> void:
	var warm := Color(1.0, 0.8, 0.58)
	for p: Vector3 in [Vector3(17, 5.6, -17), Vector3(17, 5.6, -10), Vector3(17, 5.6, -3), Vector3(17, 5.6, 4),
			Vector3(-17, 5.6, -17), Vector3(-17, 5.6, -10), Vector3(-17, 5.6, -3), Vector3(-17, 5.6, 4),
			Vector3(17, 5.6, 19), Vector3(-17, 5.6, 18)]:
		var l := OmniLight3D.new()
		l.light_color = warm
		l.light_energy = 2.2
		l.omni_range = 11.0
		model.add_child(l)
		l.position = p
	for n: Node in model.find_children("Glow_*", "Node3D", true, false):
		var g := OmniLight3D.new()
		g.light_color = Color(String(n.name).substr(5))
		g.light_energy = 2.2
		g.omni_range = 7.0
		(n as Node3D).add_child(g)
	for p: Vector3 in [Vector3(-8, 7, -12), Vector3(8, 7, -12), Vector3(-8, 7, 2), Vector3(8, 7, 2), Vector3(0, 7, 13)]:
		var f := OmniLight3D.new() # vulling in de hangar (de echte verlichting komt bij het detail)
		f.light_color = warm
		f.light_energy = 1.2
		f.omni_range = 16.0
		model.add_child(f)
		f.position = p
	for z in [-12.0, -4.0, 4.0, 12.0]:
		var s := SpotLight3D.new()
		s.light_color = warm
		s.light_energy = 7.0
		s.spot_range = 20.0
		s.spot_angle = 42.0
		s.shadow_enabled = true
		model.add_child(s)
		s.position = Vector3(0, 14.8, z)
		s.rotation = Vector3(-PI / 2, 0, 0)
	# Het raam: koel licht van de planeet, schuin naar binnen.
	var win := SpotLight3D.new()
	win.light_color = Color(0.75, 0.85, 1.0)
	win.light_energy = 6.0
	win.spot_range = 70.0
	win.spot_angle = 55.0
	win.shadow_enabled = true
	model.add_child(win)
	win.position = Vector3(0, 14.0, -30.0)
	win.look_at(model.to_global(Vector3(0, 0, 4.0)))


## Bordjes: elk leeg punt "Sign_TEKST" in het model wordt een opschrift (laat zien wat waar is).
## De voorkant van het opschrift is de +z-kant van het punt. "_" wordt een spatie.
func _add_signs(model: Node3D) -> void:
	for n: Node in model.find_children("Sign_*", "Node3D", true, false):
		var l := Label3D.new()
		l.text = String(n.name).substr(5).replace("_", " ").replace("-", "-")
		l.font = UiTheme.heading()
		l.font_size = 96
		l.pixel_size = 0.004
		l.modulate = UiTheme.YELLOW
		l.outline_size = 12
		l.outline_modulate = Color(0.05, 0.04, 0.03)
		l.shaded = false
		l.double_sided = false
		(n as Node3D).add_child(l)


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await RenderingServer.frame_post_draw


func _save(out: String, shot_name: String) -> void:
	var file := out.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(file)
	print("[interior_preview] ", file)
