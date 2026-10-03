extends Node
## Ontwerpen van de binnenkant van De Ekster in de echte look van de game: het blokmodel uit
## res://assets/models/concepts/ (standaard interieur_v3.glb) komt op de plek van de hub, met de
## echte Mol in de baai, de planeet onder het schip en het licht van het spel. Beelden op ooghoogte
## van een robot uit de camera's in het model, en één keer van boven (zonder plafond).
## Lege punten in het model: Mol_Dock, Cam_NAAM + Look_NAAM, Glow_RRGGBB (lamp), Spot_RRGGBB (lamp
## naar beneden), Sign_TEKST (bordje, voorkant = +z van het punt).
## tools\godot.cmd --path game --resolution 1600x900 -- --scenario=interior_preview --no-steam [--model=res://pad.glb] [--only=naam]
## Met --screens: de schermen van de hub (HubScreens) aan, en beelden van elk scherm (dichtbij en
## vanuit de ruimte), van elk segment van de tv, en van alles na een (nagebootste) dienst. Zonder
## --model dan het hubmodel. Met --screens zonder --only enkel de schermbeelden.
## Beelden: logs/interior/<naam>.png (headless: geen beelden, wel de schermen en hun teksten).

const HUB_MODEL := "res://assets/models/ekster_hub.glb"
## Schermbeelden vanuit de ruimte: [scherm, afstand (m), hoe ver het oog onder het midden van het
## scherm zit (vloer + 1,2 m), zijwaarts (m)] (plan: tools/blender/interior/layout.py).
## Negatieve afstand = van achteren (het hologram is van twee kanten leesbaar).
const SCREEN_VIEWS := {
	"tv": [HubScreens.TV, 6.0, 0.75, 1.6],
	"firmabord": [HubScreens.BOARD, 3.6, 0.1, 1.4],
	"terminal": [HubScreens.TERMINAL, 1.9, 0.3, 0.4], # op de verhoging (+1,8), bij de tafel
	"terminal_achter": [HubScreens.TERMINAL, -2.8, 0.9, -1.0], # vanaf de brug (+1,2), vooraan
	"taxatie": [HubScreens.APPRAISAL, 5.0, 2.05, -1.2],
}
const SCREEN_SHOTS := {
	HubScreens.TV: "tv", HubScreens.BOARD: "firmabord", HubScreens.TERMINAL: "terminal", HubScreens.APPRAISAL: "taxatie",
}
const TV_SEGMENTS: Array[String] = ["ident", "news", "ad", "quota", "weather", "shares", "employee", "safety"]

var main: Node
var _headless := DisplayServer.get_name() == "headless"
var _signs: Array[Label3D] = []


func on_terrain_loaded(_stats: Dictionary) -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Game = main.game
	var only := str(CmdArgs.value("only", "")).split(",", false)
	var with_screens := CmdArgs.has("screens")
	var out := PerfLog.log_dir().path_join("interior")
	DirAccess.make_dir_recursive_absolute(out)
	var path := str(CmdArgs.value("model", HUB_MODEL if with_screens else "res://assets/models/concepts/interieur_v3.glb"))
	var model: Node3D = (load(path) as PackedScene).instantiate()
	add_child(model)
	# Kleuren van het spel (machine-shader, lampen, glas), zoals het buitenschip.
	var cache := {}
	var roof: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name.begins_with("Roof") or mi.name.contains("_Roof"):
			roof.append(mi)
		if mi.name.begins_with("Collision"):
			mi.visible = false # botsvorm: enkel voor het spel
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
	cam.fov = 80.0
	cam.near = 0.1
	cam.far = 5000.0
	add_child(cam)
	cam.make_current()
	var screens: HubScreens = null
	if with_screens:
		var anchors := {}
		for n: Node in model.find_children("*", "Node3D", true, false):
			anchors[n.name] = n
		screens = HubScreens.new()
		add_child(screens)
		screens.setup(game, anchors)
		print("[interior_preview] schermen: ", ", ".join(screens.screen_names()))
	for c: Node in model.find_children("Cam_*", "Node3D", true, false):
		var shot_name := String(c.name).substr(4)
		if (with_screens and only.is_empty()) or (not only.is_empty() and shot_name not in only):
			continue
		var look := model.find_child("Look_" + shot_name, true, false) as Node3D
		cam.global_position = (c as Node3D).global_position
		cam.look_at(look.global_position)
		await _settle(1.0)
		_save(out, shot_name)
	if screens:
		await _screen_shots(screens, cam, out, only)
	if (not with_screens and only.is_empty()) or "boven" in only:
		for r in roof:
			r.visible = false
		cam.fov = 50.0
		var center := model.to_global(Vector3(3.0, 0.0, 13.0))
		cam.global_position = center + Vector3(0.0, 58.0, 30.0)
		cam.look_at(center)
		await _settle(1.0)
		_save(out, "boven")
	get_tree().quit(0)


## Lampen uit het model (Glow_ = rondom, Spot_ = naar beneden) en koel licht van het grote raam.
func _add_lights(model: Node3D) -> void:
	for n: Node in model.find_children("Glow_*", "Node3D", true, false):
		var g := OmniLight3D.new()
		g.light_color = Color(String(n.name).substr(5, 6))
		g.light_energy = 1.6
		g.omni_range = 7.0
		(n as Node3D).add_child(g)
	for n: Node in model.find_children("Spot_*", "Node3D", true, false):
		var s := SpotLight3D.new()
		s.light_color = Color(String(n.name).substr(5, 6))
		s.light_energy = 6.0
		s.spot_range = 12.0
		s.spot_angle = 35.0
		s.shadow_enabled = true
		(n as Node3D).add_child(s)
		s.rotation = Vector3(-PI / 2, 0, 0)
	# Het raam: koel licht van de planeet, schuin naar binnen.
	var win := SpotLight3D.new()
	win.light_color = Color(0.75, 0.85, 1.0)
	win.light_energy = 5.0
	win.spot_range = 50.0
	win.spot_angle = 55.0
	win.shadow_enabled = true
	model.add_child(win)
	win.position = Vector3(3.0, 8.0, -18.0)
	win.look_at(model.to_global(Vector3(3.0, 0.0, 10.0)))


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
		_signs.append(l)


## Beelden van de schermen: elk scherm dichtbij en vanuit de ruimte, elk segment van de tv, en
## daarna alles na een nagebootste dienst (opdracht gekozen, rapport binnen).
## Namen: <scherm>_dicht, <scherm>_ruimte, tv_<segment>, en _na voor na de dienst.
func _screen_shots(screens: HubScreens, cam: Camera3D, out: String, only: PackedStringArray) -> void:
	var want := func(shot: String) -> bool: return only.is_empty() or shot in only or shot.get_slice("_", 0) in only
	for key: String in screens.screen_names():
		var shot: String = SCREEN_SHOTS.get(key, key)
		if want.call(shot + "_dicht"):
			_close_up(screens, cam, key)
			await _settle(0.8)
			_save(out, shot + "_dicht")
	for view: String in SCREEN_VIEWS:
		if screens.screen_names().has(SCREEN_VIEWS[view][0]) and want.call(view + "_ruimte"):
			_room_view(screens, cam, SCREEN_VIEWS[view])
			await _settle(0.8)
			_save(out, view + "_ruimte")
	if screens.screen_names().has(HubScreens.TV):
		_close_up(screens, cam, HubScreens.TV)
		for seg in TV_SEGMENTS:
			if want.call("tv_" + seg):
				screens.tv_show(seg)
				await _settle(0.6)
				_save(out, "tv_" + seg)
		screens.tv_resume()
	# Na een dienst: een opdracht met hoog risico, wat verdiend, en een rapport (zonder de HUD).
	var c: Company = main.game.company
	c.contract = c.options[2]
	c.cash = 1840
	c.earned = 520
	c.reputation = 1
	c.shift = 2
	c.last_report = {"shift_total": 1, "quarter": 1, "shift": 1, "contract": c.contract.name, "risk": 2, "factor": 1.35,
			"sold": [["Schedel", 340, 87], ["Rib", 120, 100], ["Tuinkabouter", 12, 64]], "finds_value": 472, "ore_units": 6,
			"ore_value": 40, "bonus": 179, "left_behind": 1, "melted": 1, "costs": 240, "damage": 61, "quakes": 2, "net": 451,
			"earned": 451, "quota": 800}
	c.changed.emit()
	for key: String in screens.screen_names():
		var shot: String = SCREEN_SHOTS.get(key, key)
		if key == HubScreens.TV:
			continue
		if want.call(shot + "_na"):
			_close_up(screens, cam, key)
			await _settle(1.2)
			_save(out, shot + "_na")
	if screens.screen_names().has(HubScreens.TV):
		_close_up(screens, cam, HubScreens.TV)
		for seg in ["report", "quota"]:
			if want.call("tv_%s_na" % seg):
				screens.tv_show(seg)
				await _settle(0.6)
				_save(out, "tv_%s_na" % seg)
	for key: String in screens.screen_names():
		print("[interior_preview] %s: %s" % [key, screens.screen_text(key)])


## Camera recht voor een scherm, zodat het ±85% van het beeld vult (zonder de bordjes van de
## preview, die er soms voor hangen).
func _close_up(screens: HubScreens, cam: Camera3D, key: String) -> void:
	_show_signs(false)
	var info := screens.screen_info(key)
	cam.fov = 50.0
	var aspect := float(get_viewport().get_visible_rect().size.x) / float(get_viewport().get_visible_rect().size.y)
	var half_v := tan(deg_to_rad(cam.fov) / 2.0)
	var dist := maxf(float(info.height) / 2.0 / half_v, float(info.width) / 2.0 / (half_v * aspect)) / 0.85
	cam.global_position = info.center + info.normal * dist
	cam.look_at(info.center)


## Camera op ooghoogte van een robot, een paar meter voor het scherm en wat opzij.
## `v`: [scherm, afstand, oog onder het midden, zijwaarts] (SCREEN_VIEWS).
func _room_view(screens: HubScreens, cam: Camera3D, v: Array) -> void:
	_show_signs(true)
	var info := screens.screen_info(v[0])
	var normal: Vector3 = info.normal
	var side := normal.cross(Vector3.UP).normalized()
	cam.fov = 75.0
	cam.global_position = info.center + normal * float(v[1]) + side * float(v[3]) - Vector3(0, float(v[2]), 0)
	cam.look_at(info.center)


func _show_signs(on: bool) -> void:
	for l in _signs:
		l.visible = on


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if not _headless:
		await RenderingServer.frame_post_draw


func _save(out: String, shot_name: String) -> void:
	if _headless:
		print("[interior_preview] (headless, geen beeld) ", shot_name)
		return
	var file := out.path_join(shot_name + ".png")
	get_viewport().get_texture().get_image().save_png(file)
	print("[interior_preview] ", file)
