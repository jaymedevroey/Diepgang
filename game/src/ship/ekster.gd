class_name Ekster
extends Node3D
## De hub van De Ekster: de ruimte waar je tussen de diensten rondloopt. Model:
## assets/models/ekster_hub.glb, gebouwd door tools/blender/interior/build.py uit de zones; de
## namen van de lege punten en meshes zijn het contract in tools/blender/interior/layout.py. Deze
## code kent enkel dat contract en de zones uit layout.py, geen details van de zones.
## Eén dek met kleine trappen: hangar 0 (plafond 9 m), uitkijkput −0,6, laadrek +0,6, werkdek,
## gang, brug en galerij +1,2, verhoging van de terminal +1,8. De route: laadrek → werkdek → gang
## → brug (terminal) → trap naar de kade → de Mol in de dropbaai.
## Het schip dat je van buiten ziet, is een apart model (EksterExterior) boven de landingsplek; de
## hub hangt HUB_ABOVE daarboven, als een aparte ruimte. De Mol stapt over tussen beide baaien
## (drop en ophalen), wie door de open baai valt, valt uit het buitenschip (Game.from_hub).
## Geen eigen spellogica: de luiken volgen wat de Mol (host) doet.

const MODEL := preload("res://assets/models/ekster_hub.glb")
## De hub hangt zoveel boven de baai van het buitenschip (een aparte ruimte, ver uit beeld).
const HUB_ABOVE := 1400.0
## Midden van de Mol in het plan van layout.py (MOL): plan (x, y, z) = hub (x + 7, y, z + 9).
const PLAN_ORIGIN := Vector3(7.0, 0.0, 9.0)
## Binnenruimte in plancoördinaten (zones uit layout.py): x0, x1, y0, y1, z0, z1.
const ROOMS := [
	[0.0, 20.0, -1.0, 9.4, 0.0, 26.3], # hangar, uitkijkput, galerij en brug
	[7.0, 13.0, 0.9, 3.9, 26.0, 30.0], # gang
	[0.0, 20.0, 0.9, 4.8, 30.0, 40.0], # werkdek met de vier nissen
	[6.0, 14.0, 0.3, 3.0, 40.0, 44.3], # trap en laadrek
]
## Alle namen uit het contract (layout.py). Zonder de Mol-plek, de spawnplekken, de luiken en de
## botsvorm werkt de hub niet; de rest is optioneel (ontbreekt iets, dan een waarschuwing).
const CONTRACT := ["Mol_Dock", "Spawn_0", "Spawn_1", "Spawn_2", "Spawn_3", "BayDoor_L", "BayDoor_R", "Collision",
		"Terminal_Use", "Terminal_Screen", "Appraisal_Gate", "Appraisal_Screen", "Sell_Hatch", "Vending",
		"Company_Board", "TV_Screen", "Locker", "Niche_Tools", "Niche_Supply", "Niche_Free_A", "Niche_Free_B",
		"Mol_Werf", "Window_Glass"]
const DOOR_OPEN_DEG := 100.0
## Dikte van de botsvorm van een dicht luik (bovenkant gelijk met de hangarvloer, y = 0).
const DOOR_THICKNESS := 0.3
## Lege punten die enkel voor de previews in het model zitten.
const PREVIEW_ONLY := ["Sign_", "Cam_", "Look_"]
## Wat je ziet als je mikt op iets dat er nog niet is (geen ": " erin: de HUD knipt daar).
const HINTS := {
	"Appraisal_Gate": "Taxatie komt binnenkort · alles wordt na de dienst vanzelf verkocht",
	"Sell_Hatch": "Verkoopluik komt later · verkopen gaat nu vanzelf na de dienst",
	"Vending": "Automaat (komt later)",
	"Locker": "Kast en spuitcabine (komt later)",
	"Niche_Tools": "Gereedschap (upgrades komen later)",
	"Niche_Supply": "Uitgifte (upgrades komen later)",
	"Niche_Free_A": "Lege nis",
	"Niche_Free_B": "Lege nis",
	"Mol_Werf": "Mol-werf (upgrades voor de Mol komen later)",
}

var game: Node # Game
var model: Node3D
var anchors: Dictionary = {}
var body: StaticBody3D
## Luiken: 0 = dicht, 1 = open. `doors_open` is het doel (gezet door de Mol op elk peer).
var doors_open := false
var door_amount := 0.0
## Schermen uit het contract (MeshInstance3D met UV 0..1): Terminal_Screen, Appraisal_Screen,
## Company_Board, TV_Screen. HubScreens tekent erop.
var screens: Dictionary = {}
var hub_screens: HubScreens
## De opening van de dropbaai in de vloer (lokaal, x en z), uit de dichte luiken.
var bay := AABB()

var _doors: Array[Node3D] = []
var _door_shapes: Array[CollisionShape3D] = []
var _rooms: Array[AABB] = []
var _dock_local := Vector3.ZERO


func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	for n in model.find_children("*", "Node3D", true, false):
		anchors[n.name] = n
	for r: Array in ROOMS:
		_rooms.append(AABB(Vector3(r[0], r[2], r[4]) - PLAN_ORIGIN, Vector3(r[1] - r[0], r[3] - r[2], r[5] - r[4])))
	if not missing_anchors().is_empty():
		push_warning("De hub mist punten uit het contract (layout.py): %s" % ", ".join(missing_anchors()))
	_drop_preview_nodes()
	apply_materials(model)
	_dock_local = _local(anchors["Mol_Dock"]).origin
	_doors = [anchors["BayDoor_L"], anchors["BayDoor_R"]]
	_build_collision()
	add_lights(model)
	_build_screens()
	_build_buttons()
	add_child(HubDropFx.new(self))


## Zet de hub zo dat de Mol in zijn baai op `dock` staat.
func place_dock_at(dock: Vector3) -> void:
	global_position = dock - _dock_local


## Onder de vloer van de hub (door de open baai gevallen)?
func below_floor(world: Vector3) -> bool:
	var l := global_transform.affine_inverse() * world
	return l.y < -6.0 and l.y > -80.0 and absf(l.x) < 40.0 and absf(l.z) < 60.0


## Staat een wereldpunt binnen in het schip (een van de ruimtes)?
func contains(world: Vector3) -> bool:
	var local := global_transform.affine_inverse() * world
	for r in _rooms:
		if r.has_point(local):
			return true
	return false


## Boven de open baai (wie hier staat als de luiken opengaan, valt).
func over_bay(world: Vector3) -> bool:
	var l := global_transform.affine_inverse() * world
	return l.x > bay.position.x and l.x < bay.end.x and l.z > bay.position.z and l.z < bay.end.z \
			and l.y < 1.0 and l.y > -4.0


## Waar de Mol in de baai staat (as van de Mol, zoals Mol.body).
func dock_transform() -> Transform3D:
	return (anchors["Mol_Dock"] as Node3D).global_transform


## Spawnplek nummer `idx` (in het laadrek, kijkend naar voren).
func spawn_point(idx: int) -> Vector3:
	return (anchors["Spawn_%d" % (idx % 4)] as Node3D).global_position


## Namen uit het contract die niet in het model zitten (leeg = alles in orde).
func missing_anchors() -> PackedStringArray:
	var missing := PackedStringArray()
	for n: String in CONTRACT:
		if not anchors.has(n):
			missing.append(n)
	return missing


## Wereldplek van een leeg punt uit het contract (bv. "Terminal_Use"), voor tests en previews.
func anchor_position(anchor_name: String) -> Vector3:
	return (anchors[anchor_name] as Node3D).global_position


func _process(delta: float) -> void:
	var target := 1.0 if doors_open else 0.0
	if not is_equal_approx(door_amount, target):
		door_amount = move_toward(door_amount, target, delta / 2.2)
		var a := deg_to_rad(DOOR_OPEN_DEG) * _ease(door_amount)
		_doors[0].rotation.z = -a
		_doors[1].rotation.z = a
		for cs in _door_shapes:
			cs.disabled = door_amount > 0.02


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Transform van een node uit het model t.o.v. de hub.
func _local(n: Node3D) -> Transform3D:
	return global_transform.affine_inverse() * n.global_transform


# --- Opbouw ------------------------------------------------------------------------

## Namen, camera's en kijkpunten voor de previews horen niet in het spel; de botsvorm is onzichtbaar.
func _drop_preview_nodes() -> void:
	for n: String in anchors.keys():
		for prefix: String in PREVIEW_ONLY:
			if n.begins_with(prefix):
				var node: Node = anchors[n]
				node.get_parent().remove_child(node)
				node.queue_free()
				anchors.erase(n)
				break
	(anchors["Collision"] as MeshInstance3D).visible = false


## Kleuren van het spel (machine-shader, ledstroken, glas, schermen) op elke mesh van de hub.
## Ook voor interior_preview, zodat de zones daar ogen zoals in het spel.
static func apply_materials(root: Node3D) -> void:
	var cache := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var glass := false
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat_name := src.resource_name if src else ""
			glass = glass or mat_name == "Glass"
			if not cache.has(mat_name):
				cache[mat_name] = MolVisual.palette_material(mat_name, src, true)
			if cache[mat_name]:
				mi.set_surface_override_material(i, cache[mat_name])
		# Glas werpt geen schaduw (anders geen licht door het raam).
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if glass else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _build_collision() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	# Zelfde laag als de Mol: spelers en buit botsen ertegen, gereedschap graaft er niet in.
	body.collision_layer = Layers.LIFT
	body.collision_mask = 0
	add_child(body)
	# De vereenvoudigde botsvorm uit het model (trappen zijn hellingen, zie layout.py).
	var col: MeshInstance3D = anchors["Collision"]
	var cs := CollisionShape3D.new()
	cs.name = "Hull"
	cs.shape = col.mesh.create_trimesh_shape()
	body.add_child(cs)
	cs.transform = _local(col)
	# Luiken (dicht): een doos per helft, met de bovenkant gelijk met de hangarvloer; open =
	# uitgeschakeld (wie erop staat, valt). De opening van de baai volgt uit de luiken zelf.
	bay = AABB()
	for i in _doors.size():
		var door: MeshInstance3D = _doors[i]
		var box := _local(door) * door.get_aabb()
		bay = box if i == 0 else bay.merge(box)
		var shape := BoxShape3D.new()
		shape.size = Vector3(box.size.x, DOOR_THICKNESS, box.size.z)
		var ds := CollisionShape3D.new()
		ds.name = "Door_%d" % i
		ds.shape = shape
		ds.position = Vector3(box.get_center().x, -DOOR_THICKNESS * 0.5, box.get_center().z)
		body.add_child(ds)
		_door_shapes.append(ds)


## Lampen uit de lege punten van het model, met een klein budget: geen schaduw, op één na (het
## licht door het grote raam). Lamp_ = warm, rondom; Glow_RRGGBB_ = rondom in die kleur;
## Spot_RRGGBB_ = recht naar beneden. Lamp_ en Spot_ hangen aan het plafond: hoe hoger (y t.o.v.
## de hangarvloer), hoe verder en sterker (het licht valt af met 1/afstand). Ook voor interior_preview.
static func add_lights(root: Node3D) -> void:
	for n: Node3D in root.find_children("Lamp_*", "Node3D", true, false):
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.86, 0.68)
		o.omni_range = clampf(n.position.y * 1.6, 6.0, 15.0)
		o.light_energy = 0.55 * maxf(n.position.y, 2.0)
		_quiet(o)
		n.add_child(o)
	for n: Node3D in root.find_children("Glow_*", "Node3D", true, false):
		var g := OmniLight3D.new()
		g.light_color = _hex_of(n.name, Color(1.0, 0.7, 0.4))
		g.light_energy = 1.4
		g.omni_range = 7.0
		_quiet(g)
		n.add_child(g)
	for n: Node3D in root.find_children("Spot_*", "Node3D", true, false):
		var s := SpotLight3D.new()
		s.light_color = _hex_of(n.name, Color(0.8, 0.9, 1.0))
		s.light_energy = 0.35 * maxf(n.position.y, 2.0)
		s.spot_range = maxf(n.position.y * 1.5, 5.0)
		s.spot_angle = 35.0
		s.spot_angle_attenuation = 0.8
		_quiet(s)
		n.add_child(s)
		s.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	# Het grote raam: koel licht van buiten, schuin naar binnen, met de schaduw van de stijlen.
	var glass := root.find_child("Window_Glass", true, false) as Node3D
	if glass:
		var win := SpotLight3D.new()
		win.name = "WindowLight"
		win.light_color = Color(0.72, 0.83, 1.0)
		win.light_energy = 7.0
		win.spot_range = 48.0
		win.spot_angle = 55.0
		win.spot_angle_attenuation = 0.9
		win.shadow_enabled = true
		win.light_volumetric_fog_energy = 0.4
		glass.get_parent().add_child(win)
		var from := glass.position + Vector3(0.0, 3.5, -9.0)
		var to := glass.position + Vector3(0.0, -4.6, 19.0)
		win.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), from)


## Kleine lampen: geen schaduw, niet in de mist (dat kost per lamp, en de hub hoort niet te walmen).
static func _quiet(l: Light3D) -> void:
	l.shadow_enabled = false
	l.light_volumetric_fog_energy = 0.0


## Kleur uit een naam als "Glow_ffb060_18".
static func _hex_of(node_name: String, fallback: Color) -> Color:
	var parts := node_name.split("_")
	if parts.size() > 1 and parts[1].length() == 6 and parts[1].is_valid_hex_number():
		return Color(parts[1])
	return fallback


## De schermen (tv met DIG-nieuws, firmabord, opdrachthologram, taxatie): HubScreens tekent ze
## en volgt zelf de firma (ook bij clients).
func _build_screens() -> void:
	for n: String in [HubScreens.TERMINAL, HubScreens.APPRAISAL, HubScreens.BOARD, HubScreens.TV]:
		if anchors.has(n):
			screens[n] = anchors[n]
	hub_screens = HubScreens.new()
	add_child(hub_screens)
	hub_screens.setup(game, screens)


## E-knop op de terminal; op de rest een korte uitleg (dat komt later). Een leeg punt kijkt met
## −z naar het ding (zoals de spawnplekken naar voren kijken), de knop staat daar voor je.
func _build_buttons() -> void:
	if anchors.has("Terminal_Use"):
		var term_shape := BoxShape3D.new()
		term_shape.size = Vector3(2.4, 1.6, 1.0)
		var term := Interactable.make("E: opdrachtterminal", term_shape)
		term.name = "TerminalButton"
		(anchors["Terminal_Use"] as Node3D).add_child(term)
		term.position = Vector3(0.0, 1.2, -0.9)
		term.used.connect(func(p: Player) -> void: game.ship_terminal_used(p))
	for n: String in HINTS:
		if not anchors.has(n):
			continue
		var shape := BoxShape3D.new()
		# De taxatiepoort: het midden van de poort, van alle kanten.
		shape.size = Vector3(1.6, 2.4, 1.6) if n == "Appraisal_Gate" else Vector3(1.4, 1.8, 1.0)
		var it := Interactable.make(HINTS[n], shape)
		it.name = n + "Hint"
		(anchors[n] as Node3D).add_child(it)
		it.position = Vector3(0.0, 1.3, 0.0) if n == "Appraisal_Gate" else Vector3(0.0, 1.1, -0.75)
