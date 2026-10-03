extends Node
## Ontwerpen van De Ekster in de echte look van de game: elk model uit res://assets/models/concepts/
## krijgt de machine-shader, hangt boven de landingsplek onder de hemel van Roestbol, met de Mol
## eronder, en wordt vastgelegd uit de camera's die het spel gebruikt:
##   held_1/2/3  het heldenshot van de drop (vaste camera achter de vallende Mol, het schip erboven)
##   onder       schuin van onder, achter       van achter en onder, zij       van opzij
##   planeet     vanaf de landingsplek omhoog
## tools\godot.cmd --path game --resolution 1280x720 -- --scenario=concept_preview --no-steam [--only=naam] [--model=res://pad.glb]
## Beelden: logs/concepts/<model>_<camera>.png

const DIR := "res://assets/models/concepts/"
const HELD_BEHIND := 24.0 # heldenshot: zoveel meter achter de Mol, op dezelfde hoogte

var main: Node


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var out := PerfLog.log_dir().path_join("concepts")
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 4000.0
	cam.near = 0.3
	main.add_child(cam)
	cam.make_current()
	# De gewone Mol op de planeet uit beeld (de schetsen krijgen hun eigen Mol eronder).
	game.mol.body.visible = false
	var origin := Ekster.origin_above(game.terrain)
	var files: Array = Array(DirAccess.get_files_at(DIR)).map(func(f: String) -> String: return DIR + f)
	if CmdArgs.has("model"):
		files = [str(CmdArgs.value("model"))]
	for path: String in files:
		if not path.ends_with(".glb"):
			continue
		var file := path.get_file()
		var model_name := file.get_basename()
		if not only.is_empty() and not only.has(model_name):
			continue
		var holder := Node3D.new()
		main.add_child(holder)
		holder.global_position = origin
		var model: Node3D = (load(path) as PackedScene).instantiate()
		holder.add_child(model)
		_apply_materials(model)
		var dock := model.find_child("Mol_Dock", true, false) as Node3D
		var dock_pos := dock.global_position if dock else origin - Vector3(0, 8, 0)
		var mol := MolVisual.new()
		holder.add_child(mol)
		mol.feed_active = false
		mol.ramp_open = false
		mol.lights_on = true
		await get_tree().process_frame
		var shots := {
			"held_1": 18.0, "held_2": 90.0, "held_3": 230.0,
		}
		for shot: String in shots:
			var drop: float = shots[shot]
			var mol_pos := dock_pos - Vector3(0, drop, 0)
			mol.global_position = mol_pos
			mol.thrust = 0.0
			cam.global_position = mol_pos + Vector3(0.0, 2.0, HELD_BEHIND)
			cam.look_at(mol_pos + Vector3(0, 6.0 + drop * 0.12, 0), Vector3.UP)
			await _shot(cam, out.path_join("%s_%s.png" % [model_name, shot]))
		mol.global_position = dock_pos
		# Camera's op afstand naar de grootte van het model.
		var box := _bounds(model)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		var views := {"onder": Vector3(-0.55, -0.5, -0.65), "achter": Vector3(0.3, -0.4, 1.0), "zij": Vector3(-1.0, 0.06, 0.05)}
		for view: String in views:
			cam.global_position = c + (views[view] as Vector3).normalized() * r * (1.35 if view == "zij" else 1.15)
			cam.look_at(c, Vector3.UP)
			await _shot(cam, out.path_join("%s_%s.png" % [model_name, view]))
		# Close-ups (--close): boeg, motoren, rug, buik, van ±40–60 m (lokale coördinaten van het model).
		if CmdArgs.has("close"):
			var closes := {
				"close_boeg": [Vector3(-38, 6, -110), Vector3(0, 0, -62)],
				"close_motoren": [Vector3(30, 2, 128), Vector3(0, 0, 76)],
				"close_rug": [Vector3(-30, 32, 20), Vector3(0, 8, 24)],
				"close_buik": [Vector3(-26, -36, -44), Vector3(0, -6, -26)],
				"close_flank": [Vector3(-48, 0, -36), Vector3(0, 0, -36)],
			}
			for shot: String in closes:
				cam.global_position = origin + (closes[shot][0] as Vector3)
				cam.look_at(origin + (closes[shot][1] as Vector3), Vector3.UP)
				await _shot(cam, out.path_join("%s_%s.png" % [model_name, shot]))
		# Vanaf de landingsplek omhoog, ingezoomd (40° beeldhoek, zoals door een verrekijker).
		var ground := game.terrain.focus_world + Vector3(35, 1.8, 50)
		cam.global_position = ground
		cam.look_at(c, Vector3.UP)
		cam.fov = 40.0
		await _shot(cam, out.path_join("%s_planeet.png" % model_name))
		cam.fov = 75.0
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _apply_materials(model: Node3D) -> void:
	var cache := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat_name := src.resource_name if src else ""
			if not cache.has(mat_name):
				cache[mat_name] = MolVisual.palette_material(mat_name, src, false)
			if cache[mat_name]:
				mi.set_surface_override_material(i, cache[mat_name])


func _shot(cam: Camera3D, path: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	cam.get_viewport().get_texture().get_image().save_png(path)
	print("[concept_preview] ", path)
