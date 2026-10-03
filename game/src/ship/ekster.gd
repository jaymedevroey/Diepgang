class_name Ekster
extends Node3D
## De hub van De Ekster: de ruimte waar je tussen de diensten rondloopt (opdrachtterminal,
## taxatiepoort, museum, werkbank, de Mol in de dropbaai). Model uit tools/blender/ekster.py
## (tijdelijk: de binnenkant wordt opnieuw ontworpen). Het schip dat je van buiten ziet, is een
## apart model (EksterExterior) boven de landingsplek; de hub hangt HUB_ABOVE daarboven, als een
## aparte ruimte. De Mol stapt over tussen beide baaien (drop en ophalen), wie door de open baai
## valt, valt uit het buitenschip (Game.from_hub).
## Geen eigen spellogica: de luiken volgen wat de Mol (host) doet.

const MODEL := preload("res://assets/models/ekster.glb")
## De hub hangt zoveel boven de baai van het buitenschip (een aparte ruimte, ver uit beeld).
const HUB_ABOVE := 1400.0
## Binnenruimte (lokaal): hangar en museumzaal.
const HANGAR := AABB(Vector3(-11.0, -0.5, -22.0), Vector3(22.0, 9.5, 38.0))
const MUSEUM := AABB(Vector3(11.0, -0.5, 0.0), Vector3(14.0, 7.5, 16.0))
## Opening van de dropbaai in de vloer (lokaal x0, x1, z0, z1), gelijk aan BAY in ekster.py.
const BAY := [-3.8, 3.8, -10.5, 6.0]
const DOOR_OPEN_DEG := 100.0
## Grijperklauwen: van de oorsprong van de grijper tot onder de klauwen (m).
const GRAPPLE_REACH := 3.0

var game: Node # Game
var model: Node3D
var anchors: Dictionary = {}
var body: StaticBody3D
## Luiken: 0 = dicht, 1 = open. `doors_open` is het doel (gezet door de Mol op elk peer).
var doors_open := false
var door_amount := 0.0
## Grijper: meter onder zijn rustplek aan het plafond (gezet door de Mol).
var grapple_depth := 0.0
var grapple: Node3D
var terminal_screen: Label3D
var appraisal_screen: Label3D

var _doors: Array[Node3D] = []
var _door_shapes: Array[CollisionShape3D] = []
var _cable: Node3D
var _grapple_rest := Vector3.ZERO
var _bay_lights: Array[SpotLight3D] = []


func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	for n in model.find_children("*", "Node3D", true, false):
		anchors[n.name] = n
	_apply_materials()
	_build_collision()
	_build_lights()
	grapple = anchors["Grapple"]
	_cable = anchors["GrappleCable"]
	var dock: Node3D = anchors["Mol_Dock"]
	var top: Node3D = anchors["Grapple_Top"]
	_grapple_rest = Vector3(dock.position.x, top.position.y, dock.position.z)
	_doors = [anchors["BayDoor_L"], anchors["BayDoor_R"]]
	terminal_screen = _screen("TerminalScreen", 0.0032, Color(0.45, 0.95, 1.0), 900.0)
	appraisal_screen = _screen("AppraisalScreen", 0.0016, Color(1.0, 0.72, 0.3), 560.0)
	_build_buttons()
	_update_grapple()
	terminal_screen.text = "DIG · DIEPGANG INTERPLANETAIRE GRONDWERKEN

OPDRACHT: ROESTBOL
DOEL: ALLES WAT WAARDE HEEFT

> STAP IN DE MOL
> TREK AAN DE HENDEL
> NIET VERGETEN TERUG TE KOMEN"
	appraisal_screen.text = "TAXATIE

LEG VONDSTEN
OP DE BAND"


## Zet de hub zo dat de Mol in zijn baai op `dock` staat.
func place_dock_at(dock: Vector3) -> void:
	global_position = dock - (anchors["Mol_Dock"] as Node3D).position


## Onder de vloer van de hub (door de open baai gevallen)?
func below_floor(world: Vector3) -> bool:
	var l := global_transform.affine_inverse() * world
	return l.y < -6.0 and l.y > -80.0 and absf(l.x) < 40.0 and absf(l.z) < 60.0


## Staat een wereldpunt binnen in het schip (hangar of museum)?
func contains(world: Vector3) -> bool:
	var local := global_transform.affine_inverse() * world
	return HANGAR.has_point(local) or MUSEUM.has_point(local)


## Boven de open baai (wie hier staat als de luiken opengaan, valt).
func over_bay(world: Vector3) -> bool:
	var l := global_transform.affine_inverse() * world
	return l.x > BAY[0] and l.x < BAY[1] and l.z > BAY[2] and l.z < BAY[3] and l.y < 1.0 and l.y > -4.0


## Waar de Mol in de baai staat (as van de Mol, zoals Mol.body).
func dock_transform() -> Transform3D:
	return (anchors["Mol_Dock"] as Node3D).global_transform


## Spawnplek nummer `idx` (vooraan, bij de terminal, kijkend naar de Mol).
func spawn_point(idx: int) -> Vector3:
	return (anchors["Spawn_%d" % (idx % 4)] as Node3D).global_position


## Wereldpositie van de onderkant van de grijperklauwen.
func grapple_tip() -> Vector3:
	return grapple.global_position - global_basis.y * GRAPPLE_REACH


## Rustplek van de grijper (wereld), zonder kabel.
func grapple_rest_world() -> Vector3:
	return global_transform * _grapple_rest


func _process(delta: float) -> void:
	var target := 1.0 if doors_open else 0.0
	if not is_equal_approx(door_amount, target):
		door_amount = move_toward(door_amount, target, delta / 2.2)
		var a := deg_to_rad(DOOR_OPEN_DEG) * _ease(door_amount)
		_doors[0].rotation.z = -a
		_doors[1].rotation.z = a
		for cs in _door_shapes:
			cs.disabled = door_amount > 0.02
	_update_grapple()


func _update_grapple() -> void:
	grapple.position = _grapple_rest - Vector3(0.0, grapple_depth, 0.0)
	_cable.position = _grapple_rest + Vector3(0.0, 0.4, 0.0)
	_cable.scale = Vector3(1.0, maxf(0.05, grapple_depth + 0.4), 1.0)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# --- Opbouw ------------------------------------------------------------------------

func _apply_materials() -> void:
	var cache := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var inside := mi.name != "Hull"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat_name := src.resource_name if src else ""
			var key := mat_name + ("#in" if inside else "")
			if not cache.has(key):
				cache[key] = MolVisual.palette_material(mat_name, src, inside)
			if cache[key]:
				mi.set_surface_override_material(i, cache[key])
	# Het camerascherm-materiaal (zwart) blijft; de tekst komt er als Label3D op.


func _build_collision() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	# Zelfde laag als de Mol: spelers en buit botsen ertegen, gereedschap graaft er niet in.
	body.collision_layer = Layers.LIFT
	body.collision_mask = 0
	add_child(body)
	var interior: MeshInstance3D = anchors["Interior"]
	var cs := CollisionShape3D.new()
	cs.name = "Interior"
	cs.shape = interior.mesh.create_trimesh_shape()
	body.add_child(cs)
	cs.global_transform = interior.global_transform
	# Luiken (dicht): vlakke dozen; open = uitgeschakeld (wie erop staat, valt).
	var w: float = (BAY[1] - BAY[0]) * 0.5
	var l: float = BAY[3] - BAY[2]
	var zc: float = (BAY[2] + BAY[3]) * 0.5
	for x: float in [BAY[0] + w * 0.5, BAY[1] - w * 0.5]:
		var box := BoxShape3D.new()
		box.size = Vector3(w, 0.24, l)
		var ds := CollisionShape3D.new()
		ds.shape = box
		ds.position = Vector3(x, -0.13, zc)
		body.add_child(ds)
		_door_shapes.append(ds)
	# Boegvenster: glas, niet door te lopen.
	var glass := BoxShape3D.new()
	glass.size = Vector3(16.0, 4.4, 0.3)
	var gs := CollisionShape3D.new()
	gs.shape = glass
	gs.position = (anchors["Window_Glass"] as Node3D).position
	body.add_child(gs)


func _build_lights() -> void:
	for n: String in anchors:
		if n.begins_with("Lamp_"):
			var o := OmniLight3D.new()
			o.light_color = Color(1.0, 0.9, 0.76)
			o.light_energy = 1.5 if not n.begins_with("Lamp_m") else 1.2
			o.omni_range = 11.0
			o.omni_attenuation = 1.1
			o.shadow_enabled = false
			o.light_volumetric_fog_energy = 0.0
			(anchors[n] as Node3D).add_child(o)
	# Schijnwerpers onder het schip, rond de baai: je ziet de Mol vallen en terugkomen.
	for i in 4:
		var s := SpotLight3D.new()
		s.light_color = Color(1.0, 0.86, 0.66)
		s.light_energy = 6.0
		s.spot_range = 90.0
		s.spot_angle = 18.0
		s.spot_attenuation = 0.6
		s.shadow_enabled = false
		(anchors["BayLight_%d" % i] as Node3D).add_child(s)
		_bay_lights.append(s)
	# Opdrachtterminal: een koel schijnsel van het scherm.
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.85, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	glow.shadow_enabled = false
	add_child(glow)
	glow.position = (anchors["TerminalScreen"] as MeshInstance3D).get_aabb().get_center() + Vector3(0, 0, 1.2)


## Tekstlabel op een scherm (mesh met UV, zie quad() in ekster.py): midden van de mesh, iets ervoor.
func _screen(mesh_name: String, pixel: float, color: Color, width: float) -> Label3D:
	var mi: MeshInstance3D = anchors[mesh_name]
	var aabb := mi.get_aabb()
	var l := Label3D.new()
	l.name = mesh_name + "Text"
	l.font = UiTheme.screen()
	l.font_size = 48
	l.line_spacing = -8.0
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.width = width
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	# Normaal van het scherm: de dunste as van de AABB, weg van het midden van de hangar.
	var normal := Vector3(0, 0, 1)
	if aabb.size.x < aabb.size.z:
		normal = Vector3(1, 0, 0) if aabb.get_center().x < 0.0 else Vector3(-1, 0, 0)
	model.add_child(l)
	var c := aabb.get_center()
	var h := aabb.size.y
	l.position = c + normal * 0.03 + Vector3(0, h * 0.42, 0)
	l.basis = Basis.looking_at(-normal, Vector3.UP)
	return l


func _build_buttons() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.0, 1.2)
	var term := Interactable.make("E: opdrachtterminal", shape)
	term.name = "TerminalButton"
	(anchors["Terminal_Use"] as Node3D).add_child(term)
	term.position = Vector3(0, -0.2, -0.8)
	term.used.connect(func(p: Player) -> void: game.ship_terminal_used(p))
	var bench_shape := BoxShape3D.new()
	bench_shape.size = Vector3(1.4, 1.0, 3.0)
	var bench := Interactable.make("Werkbank (upgrades komen later)", bench_shape)
	(anchors["Workbench"] as Node3D).add_child(bench)
	bench.position = Vector3(-0.6, -0.4, 0)
