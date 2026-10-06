class_name MolVisual
extends Node3D
## Alles wat je van de Mol ziet en hoort (docs/de-mol.md): model met machine-shader,
## draaiende boorkop en wielen, lopende rupsschakels, laadklep, hendel, lampen, rook,
## stof, geluid en het camerascherm in de cabine. Geen spellogica: Mol zet de toestand.

const MODEL := preload("res://assets/models/mol.glb")
const MACHINE := preload("res://src/mol/machine.gdshader")
const FEED_SHADER := preload("res://src/mol/feed.gdshader")
const FLAME_SHADER := preload("res://src/ship/drop_flame.gdshader")
const HAZE_SHADER := preload("res://src/mol/heat_haze.gdshader")

# Rupspad (lokaal rupsframe: x dwars, y omhoog, z langs) — gelijk aan tools/blender/mol.py.
const TRACK_ZF := -2.8
const TRACK_ZR := 3.2
const TRACK_R := 0.55 # straal van het pad (wiel 0,5 + halve schakel)
const TRACK_CENTER := Vector2(1.30, -2.25) # (x, y) voor de rechterkant; links gespiegeld
const TRACK_ROLL := 30.0
const LINK_SPACING := 0.19
const RAMP_OPEN_DEG := 118.0
## Normaal van het consolepaneel (tools/blender/mol.py, DESK_TILT = 35°).
const DESK_NORMAL := Vector3(0.0, 0.819152, 0.573576)

## Materiaal → instellingen voor de machine-shader.
const MATS := {
	"Yellow": {"albedo": Color(0.949, 0.718, 0.02), "metallic": 0.15, "roughness": 0.48, "edge": 0.9, "grime": 0.6},
	"Anthracite": {"albedo": Color(0.137, 0.149, 0.169), "metallic": 0.35, "roughness": 0.55, "edge": 0.55, "grime": 0.5, "bare": Color(0.5, 0.5, 0.5)},
	"Steel": {"albedo": Color(0.55, 0.56, 0.59), "metallic": 0.9, "roughness": 0.32, "edge": 0.0, "grime": 0.45},
	"DarkSteel": {"albedo": Color(0.2, 0.205, 0.215), "metallic": 0.85, "roughness": 0.45, "edge": 0.35, "grime": 0.5},
	"CutterSteel": {"albedo": Color(0.66, 0.66, 0.64), "metallic": 0.45, "roughness": 0.38, "edge": 0.25, "grime": 0.55},
	"Rubber": {"albedo": Color(0.06, 0.06, 0.065), "metallic": 0.0, "roughness": 0.85, "edge": 0.0, "grime": 0.5},
	"Hazard": {"albedo": Color(0.949, 0.718, 0.02), "metallic": 0.15, "roughness": 0.5, "edge": 0.7, "grime": 0.5, "hazard": true},
	"Panel": {"albedo": Color(0.78, 0.76, 0.72), "metallic": 0.1, "roughness": 0.55, "edge": 0.3, "grime": 0.45},
	"Cream": {"albedo": Color(0.913, 0.882, 0.827), "metallic": 0.05, "roughness": 0.6, "edge": 0.2, "grime": 0.3},
	"Floor": {"albedo": Color(0.36, 0.36, 0.35), "metallic": 0.35, "roughness": 0.62, "edge": 0.6, "grime": 0.6},
	"Wood": {"albedo": Color(0.55, 0.36, 0.2), "metallic": 0.0, "roughness": 0.75, "edge": 0.15, "grime": 0.4, "bare": Color(0.72, 0.56, 0.38)},
	"Leather": {"albedo": Color(0.42, 0.24, 0.13), "metallic": 0.0, "roughness": 0.6, "edge": 0.3, "grime": 0.3, "bare": Color(0.6, 0.4, 0.26)},
	"Red": {"albedo": Color(0.78, 0.1, 0.07), "metallic": 0.1, "roughness": 0.45, "edge": 0.6, "grime": 0.4},
	"Copper": {"albedo": Color(0.72, 0.42, 0.25), "metallic": 0.9, "roughness": 0.35, "edge": 0.0, "grime": 0.4},
	"Blue": {"albedo": Color(0.15, 0.35, 0.6), "metallic": 0.2, "roughness": 0.5, "edge": 0.5, "grime": 0.4},
	"DecalDark": {"albedo": Color(0.05, 0.05, 0.055), "metallic": 0.0, "roughness": 0.6, "edge": 0.0, "grime": 0.3},
	"DecalLight": {"albedo": Color(0.95, 0.93, 0.88), "metallic": 0.0, "roughness": 0.6, "edge": 0.0, "grime": 0.3},
	# Vondsten (tools/blender/finds.py).
	"Bone": {"albedo": Color(0.88, 0.82, 0.67), "metallic": 0.0, "roughness": 0.65, "edge": 0.5, "grime": 0.9, "bare": Color(0.97, 0.94, 0.86), "grime_col": Color(0.42, 0.28, 0.12)},
	"BoneDark": {"albedo": Color(0.3, 0.22, 0.14), "metallic": 0.0, "roughness": 0.85, "edge": 0.0, "grime": 0.3},
	"Gold": {"albedo": Color(1.0, 0.76, 0.26), "metallic": 1.0, "roughness": 0.28, "edge": 0.4, "grime": 0.5, "bare": Color(1.0, 0.9, 0.55)},
	"Brass": {"albedo": Color(0.74, 0.54, 0.26), "metallic": 0.85, "roughness": 0.4, "edge": 0.6, "grime": 0.85, "bare": Color(0.92, 0.78, 0.48), "grime_col": Color(0.22, 0.34, 0.24)},
	"Skin": {"albedo": Color(0.95, 0.72, 0.6), "metallic": 0.0, "roughness": 0.55, "edge": 0.5, "grime": 0.6, "bare": Color(0.92, 0.9, 0.85)},
	"Rock": {"albedo": Color(0.42, 0.37, 0.33), "metallic": 0.0, "roughness": 0.92, "edge": 0.3, "grime": 0.5, "bare": Color(0.6, 0.55, 0.5)},
	"Quartz": {"albedo": Color(0.92, 0.9, 0.86), "metallic": 0.0, "roughness": 0.35, "edge": 0.0, "grime": 0.3},
	"Green": {"albedo": Color(0.3, 0.55, 0.22), "metallic": 0.0, "roughness": 0.7, "edge": 0.5, "grime": 0.6, "bare": Color(0.92, 0.9, 0.85)},
	# De Ekster, Nostromo-stijl (docs/research/nostromo-stijl.md §3).
	"HullGrey": {"albedo": Color(0.42, 0.424, 0.408), "metallic": 0.45, "roughness": 0.6, "edge": 0.5, "grime": 0.7, "bare": Color(0.66, 0.66, 0.64)},
	"HullDark": {"albedo": Color(0.298, 0.306, 0.294), "metallic": 0.45, "roughness": 0.62, "edge": 0.5, "grime": 0.7, "bare": Color(0.6, 0.6, 0.58)},
	"HullLight": {"albedo": Color(0.541, 0.541, 0.514), "metallic": 0.4, "roughness": 0.58, "edge": 0.45, "grime": 0.65, "bare": Color(0.7, 0.7, 0.68)},
	"GreyGreen": {"albedo": Color(0.369, 0.4, 0.353), "metallic": 0.3, "roughness": 0.62, "edge": 0.55, "grime": 0.7, "bare": Color(0.62, 0.62, 0.6)},
	"RedOxide": {"albedo": Color(0.482, 0.247, 0.173), "metallic": 0.2, "roughness": 0.7, "edge": 0.5, "grime": 0.7, "bare": Color(0.55, 0.42, 0.36)},
	"Soot": {"albedo": Color(0.169, 0.153, 0.141), "metallic": 0.1, "roughness": 0.85, "edge": 0.0, "grime": 0.3},
	"Padded": {"albedo": Color(0.851, 0.827, 0.757), "metallic": 0.0, "roughness": 0.75, "edge": 0.2, "grime": 0.35},
	# De hub (tools/blender/interior).
	"DuctTape": {"albedo": Color(0.52, 0.53, 0.55), "metallic": 0.25, "roughness": 0.45, "edge": 0.0, "grime": 0.4},
	"Cardboard": {"albedo": Color(0.56, 0.42, 0.27), "metallic": 0.0, "roughness": 0.85, "edge": 0.2, "grime": 0.5},
	"Grating": {"albedo": Color(0.3, 0.31, 0.32), "metallic": 0.55, "roughness": 0.5, "edge": 0.6, "grime": 0.6},
	"FloorWorn": {"albedo": Color(0.46, 0.46, 0.45), "metallic": 0.6, "roughness": 0.38, "edge": 0.3, "grime": 0.3},
	"StainOil": {"albedo": Color(0.06, 0.055, 0.05), "metallic": 0.1, "roughness": 0.22, "edge": 0.0, "grime": 0.0},
	# Boorstof op de buitenkant van de Mol (tools/blender/mol.py, release-audit binnen-12 ronde 2).
	"Dust": {"albedo": Color(0.5, 0.42, 0.33), "metallic": 0.0, "roughness": 1.0, "edge": 0.0, "grime": 0.25},
}
const EMISSIVE := {
	"Lens": [Color(1.0, 0.85, 0.6), 3.0],
	"LensRed": [Color(1.0, 0.15, 0.06), 2.2],
	"LensOrange": [Color(1.0, 0.45, 0.05), 2.2],
	"Bulb": [Color(1.0, 0.86, 0.6), 4.0],
	"BellyLight": [Color(1.0, 0.72, 0.42), 8.0],
	"Cyan": [Color(0.31, 0.89, 0.94), 2.5],
	"EngineGlow": [Color(0.7, 0.85, 1.0), 7.0],
	"NavRed": [Color(1.0, 0.12, 0.08), 5.0],
	"NavGreen": [Color(0.2, 1.0, 0.4), 5.0],
	"RunLight": [Color(0.55, 0.8, 1.0), 4.0],
	"LedWhite": [Color(0.9, 0.95, 1.0), 1.4],
	"LedAmber": [Color(1.0, 0.62, 0.28), 2.2],
	"LedGreen": [Color(0.3, 1.0, 0.45), 2.0],
	"LedCyanSoft": [Color(0.35, 0.85, 0.95), 1.0],
	"ScreenAmber": [Color(1.0, 0.58, 0.18), 1.0],
	"ScreenCyan": [Color(0.3, 0.84, 0.95), 1.2],
	"ScreenGlow": [Color(0.5, 0.78, 0.28), 0.6],
	"ScreenGreen": [Color(0.32, 0.72, 0.04), 1.0],
	"ScreenBlue": [Color(0.02, 0.1, 0.8), 1.0],
	"HoloCyan": [Color(0.1, 0.6, 1.0), 2.0],
	"HoloCore": [Color(0.02, 0.18, 0.4), 1.0],
	# De hub: waarschuwingsstroken in de valschacht (Shaft_Lights).
	"ShaftLight": [Color(1.0, 0.45, 0.15), 2.0],
	"LedAmberSoft": [Color(1.0, 0.6, 0.26), 0.55],
	"LedRedSoft": [Color(1.0, 0.18, 0.1), 0.7],
}

## Toestand (gezet door Mol).
var speed := 0.0
var throttle := 0.0
var drilling := false
var blocked := false
var ramp_open := false
var lights_on := true
var beacons := false
var lever_pulled := false
var dust_color := Color(0.55, 0.38, 0.27)
## Stuwraketten onder de Mol bij de landing na de drop (0..1).
var thrust := 0.0
## True als de lokale speler in de cabine zit of ernaar kijkt: dan draait het camerascherm.
var feed_active := true
## Camerascherm: de boorkop, door de buik naar beneden (drop, optrekken), of op het dak naar boven
## (de grijper komt).
enum Feed { HEAD, BELLY, ROOF }
## Drop (gezet door Mol): binnenlicht 0 = gewoon, 1 = amber (aftellen), 2 = rood (laatste tellen,
## de val); valsnelheid (m/s); hoogte van de grond onder de Mol, en of hij boven de planeet hangt
## (niet in de hub).
var alert := 0
var feed_cam := Feed.HEAD
var fall_speed := 0.0
var ground_y := 0.0
var over_ground := false
var terrain: TerrainAPI
## Rijden (gezet door Mol): versnelling (m/s²) en draaisnelheid (rad/s), voor het veren en hellen van
## het model; enkel als de lokale speler van buiten kijkt (`outside_view`), anders zinderen de
## wanden rond wie binnen staat (daar doet MolRideFeel het met de camera).
var drive_acc := 0.0
var drive_turn := 0.0
var outside_view := true
## Aan de kabel van de grijper (zwaait wat).
var lifting := false

var model: Node3D
var ramp_hinge: Node3D
var anchors: Dictionary = {}

var _head: Node3D
var _wheels: Array = [] # [node, as, straal]
var _lever: Node3D
var _lever_rest: Transform3D
var _needles: Array = [] # [node, rust-transform, huidige hoek, doelhoek]
var _sticks: Array = [] # [node, rust-transform, huidige hoek]
## Stuurhendels: x = links, y = rechts, -1..1 (duwen = vooruit).
var sticks := Vector2.ZERO
var _links: Array[MultiMeshInstance3D] = []
var _track_scroll := 0.0
var _head_spin := 0.0
var _ramp_angle := 0.0
var _lens_mats: Array[StandardMaterial3D] = []
var _beacon_mats: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _beacon_lights: Array[SpotLight3D] = []
var _beacon_angle := 0.0
var _exhaust: Array[GPUParticles3D] = []
var _dust: GPUParticles3D
var _grit: GPUParticles3D
var _sparks: GPUParticles3D
var _trail: GPUParticles3D
var _spoil: GPUParticles3D # boorpuin dat achteraan onder de rupsen uitvalt
var _flames: Array[MeshInstance3D] = []
var _flame_mats: Array[ShaderMaterial] = []
var _smoke: Array[GPUParticles3D] = []
var _thrust_light: OmniLight3D
var _landing_dust: GPUParticles3D
var _debris: GPUParticles3D
var _downwash: GPUParticles3D
var _shadow: Decal
var _cage_lights: Array[OmniLight3D] = []
var _flicker := 0.0
var _flash := 0.0 # ontsteken: felle gloed die uitdooft
var _wobble_t := 0.0
var _sag := 0.0 # veren na de landing (m), enkel het model
var _sag_v := 0.0
var _lever_angle := 0.0
var _lever_v := 0.0
var _ping_light: OmniLight3D
var _ping_glow := 0.0
var _shake_t := 0.0
var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _rumble: AudioStreamPlayer3D
var _duck := 0.0
var _feed_top: Label
var _feed_label: Label
var _feed_rec: ColorRect
## Tekst onderaan het camerascherm (diepte, laag).
var feed_text := ""
var _snd: Dictionary = {}
var _feed_viewport: SubViewport
var _feed_camera: Camera3D
var _rng := RandomNumberGenerator.new()
## De schermen in de cabine spreken één taal (ui-13): dezelfde beeldbuis (feed.gdshader), hetzelfde
## schermlettertype, een kop linksboven in dezelfde vorm. Amber is de Mol zelf (status, camera),
## groen is de sonar (een apart instrument, zoals elke sonar).
const SCREEN_AMBER := Color(1.0, 0.72, 0.3)
var _status_viewport: SubViewport
var _status_body: Label
## Sonarscherm rechts in de cabine (Mol zet de toestand via sonar_screen.display).
var sonar_screen: SonarScreen


func _ready() -> void:
	model = MODEL.instantiate()
	add_child(model)
	for n in model.find_children("*", "Node3D", true, false):
		anchors[n.name] = n
	_apply_materials()
	_head = anchors["DrillHead"]
	_lever = anchors["Lever"]
	_lever_rest = _lever.transform
	for side in ["Stick_L", "Stick_R"]:
		var st: Node3D = anchors[side]
		_sticks.append([st, st.transform, 0.0])
	for k in 3:
		var n: Node3D = anchors["Needle_%d" % k]
		_needles.append([n, n.transform, 0.0, 0.0])
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var axis := Vector3(cos(deg_to_rad(TRACK_ROLL * s)), sin(deg_to_rad(TRACK_ROLL * s)), 0.0)
		for i in 7:
			var w: Node3D = anchors["Wheel_%s_%d" % [side, i]]
			var r := 0.44 if i == 0 else (0.42 if i == 1 else 0.33)
			_wheels.append([w, axis, r])
	_build_ramp_hinge()
	_build_tracks()
	_build_lights()
	_build_particles()
	_build_thrusters()
	_build_audio()
	_build_feed()
	_build_status()
	sonar_screen = SonarScreen.new()
	sonar_screen.name = "SonarScreen"
	add_child(sonar_screen)
	sonar_screen.setup(anchors["Sonar"], anchors["SonarLamp"], anchors["SonarPing"])


## Meters op de console (0..1): diepte, snelheid, brandstof. De naalden lopen er traag naartoe.
func set_gauges(values: Array) -> void:
	for k in mini(values.size(), _needles.size()):
		_needles[k][3] = deg_to_rad(135.0 - 270.0 * clampf(values[k], 0.0, 1.0))


# --- Upgrades die je ziet (golf 3, binnen2-11) ------------------------------------------------------

## Materialen van de boorkop T2: carbidetanden en -ring in goud, de kegel donker wolfraam.
const HEAD_T2_MATS := {"Steel": "Gold", "CutterSteel": "DarkSteel"}
## Bagagebakken van het grotere laadruim op de flanken (lokaal t.o.v. de Mol): achter het midden,
## boven de rupsen, net buiten de romp (x ±2,92).
const POD_POS := Vector3(3.14, -1.0, 2.0)

var _head_t2 := false
var _pods: Node3D


## De boorkop T2 en het grotere laadruim tonen (Upgrades.apply_visuals, op elke peer).
func set_upgrades(head_t2: bool, cargo_t2: bool) -> void:
	if head_t2 != _head_t2 and _head:
		_head_t2 = head_t2
		apply_head_tier(_head, head_t2)
	if cargo_t2 and _pods == null:
		_pods = Node3D.new()
		_pods.name = "CargoPods"
		model.add_child(_pods)
		for s in [-1.0, 1.0]:
			var pod := UpgradeShow.cargo_pod()
			_pods.add_child(pod)
			pod.position = Vector3(POD_POS.x * s, POD_POS.y, POD_POS.z)
			pod.scale = Vector3(1.0, 1.0, 2.0)
			if s < 0.0:
				pod.rotation = Vector3(0.0, PI, 0.0) # het bordje naar buiten
	if _pods:
		_pods.visible = cargo_t2


## Materialen van een boorkop (uit het model van de Mol) voor T1 of T2. Ook voor de bok op de Mol-werf
## en de kaart in de winkel (UpgradeShow).
static func apply_head_tier(head: Node3D, t2: bool) -> void:
	var meshes: Array = head.find_children("*", "MeshInstance3D", true, false)
	if head is MeshInstance3D:
		meshes.append(head)
	for mi: MeshInstance3D in meshes:
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var n := src.resource_name if src else ""
			if not HEAD_T2_MATS.has(n):
				if mi.get_surface_override_material(i) == null:
					mi.set_surface_override_material(i, palette_material(n, src))
				continue
			if not mi.has_meta("t1_%d" % i):
				var cur := mi.get_surface_override_material(i)
				mi.set_meta("t1_%d" % i, cur if cur else palette_material(n, src))
			mi.set_surface_override_material(i, machine_material(HEAD_T2_MATS[n]) if t2 else mi.get_meta("t1_%d" % i))


## Tekst op het statusscherm links van het camerascherm (amber, op dezelfde beeldbuis als de rest).
func set_readout(text: String) -> void:
	if _status_body.text != text:
		_status_body.text = text


## Statusscherm: een SubViewport met een kop en de toestand, op een vlak voor het scherm in het model
## (Label_Depth), met hetzelfde beeldbuiseffect als het camerascherm en de sonar.
func _build_status() -> void:
	_status_viewport = SubViewport.new()
	_status_viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF # tekent in _process (gevoel-02)
	_status_viewport.size = Vector2i(520, 320)
	_status_viewport.disable_3d = true
	_status_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_status_viewport)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.012)
	bg.size = Vector2(520, 320)
	_status_viewport.add_child(bg)
	var head := _screen_text("STATUS  ·  THE MOLE", Vector2(22, 8), 22, Color(SCREEN_AMBER, 0.7))
	_status_viewport.add_child(head)
	var rule := ColorRect.new()
	rule.color = Color(SCREEN_AMBER, 0.35)
	rule.position = Vector2(22, 38)
	rule.size = Vector2(476, 2)
	_status_viewport.add_child(rule)
	# Zo groot als het past: vanuit de stoel is een scherm klein (lessons: tekst ≥ 40 px op het scherm).
	_status_body = _screen_text("", Vector2(22, 44), 36, SCREEN_AMBER)
	_status_body.add_theme_constant_override("line_spacing", -8)
	_status_viewport.add_child(_status_body)
	var quad := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.62, 0.38)
	quad.mesh = q
	var m := ShaderMaterial.new()
	m.shader = FEED_SHADER
	m.set_shader_parameter("feed", _status_viewport.get_texture())
	m.set_shader_parameter("tint", Color(1, 1, 1))
	m.set_shader_parameter("desaturate", 0.0)
	m.set_shader_parameter("vignette", 0.3)
	m.set_shader_parameter("brightness", 1.6)
	m.set_shader_parameter("lines", 160.0)
	m.set_shader_parameter("flip_v", false)
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchors["Label_Depth"].add_child(quad)
	quad.position = Vector3(0.0, 0.0, 0.004)


## Tekst op een scherm in de cabine (schermlettertype, één kleur).
static func _screen_text(text: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", UiTheme.screen())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- Materialen -------------------------------------------------------------------

func _apply_materials() -> void:
	var cache := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var inside := mi.name in ["Interior", "Lever"]
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var name := src.resource_name if src else ""
			var key := name + ("#in" if inside else "")
			if not cache.has(key):
				cache[key] = _make_material(name, src, inside)
			if cache[key]:
				mi.set_surface_override_material(i, cache[key])
		if mi.name == "TrackLink":
			mi.visible = false


## Machine-materiaal uit de paletnaam van Blender (ook voor ander decor en gereedschap).
## `detail`: >1 voor kleine voorwerpen. `viewmodel_fov` > 0: gereedschap in beeld (first person).
## `tint`: kleur voor "PlayerColor" (de spelerskleur).
static func machine_material(name: String, inside := false, detail := 1.0, viewmodel_fov := 0.0,
		tint := Color(0.95, 0.55, 0.12), wear := 1.0) -> ShaderMaterial:
	var player := name == "PlayerColor"
	if not MATS.has(name) and not player:
		return null
	var p: Dictionary = MATS["Yellow" if player else name]
	var m := ShaderMaterial.new()
	m.shader = MACHINE
	m.set_shader_parameter("albedo", tint if player else p.albedo)
	m.set_shader_parameter("detail_scale", detail)
	m.set_shader_parameter("hazard_scale", 2.2 * detail)
	if viewmodel_fov > 0.0:
		m.set_shader_parameter("viewmodel", true)
		m.set_shader_parameter("viewmodel_fov", viewmodel_fov)
	m.set_shader_parameter("metallic", p.metallic)
	m.set_shader_parameter("roughness", p.roughness)
	m.set_shader_parameter("edge_wear", p.edge * (0.3 if inside else 1.0) * wear)
	m.set_shader_parameter("grime", p.grime * (0.45 if inside else 1.0) * wear)
	m.set_shader_parameter("low_grime", 0.0 if inside else 1.0)
	m.set_shader_parameter("bare_metal", p.get("bare", Color(0.62, 0.62, 0.6)))
	if p.has("grime_col"):
		m.set_shader_parameter("grime_color", p.grime_col)
	m.set_shader_parameter("hazard", p.get("hazard", false))
	return m


func _make_material(name: String, src: Material, inside := false) -> Material:
	var m := palette_material(name, src, inside)
	if EMISSIVE.has(name):
		if name == "LensOrange":
			_beacon_mats.append(m)
		else:
			_lens_mats.append(m)
	return m


## Materiaal voor een paletnaam uit Blender (kit.py): machine-shader, lampglas, glas of scherm.
## Ook voor andere modellen (De Ekster). Onbekende namen: het materiaal uit de glb.
static func palette_material(name: String, src: Material, inside := false) -> Material:
	if MATS.has(name):
		return machine_material(name, inside)
	if EMISSIVE.has(name):
		var e := StandardMaterial3D.new()
		e.albedo_color = EMISSIVE[name][0]
		e.emission_enabled = true
		e.emission = EMISSIVE[name][0]
		e.emission_energy_multiplier = EMISSIVE[name][1]
		e.roughness = 0.2
		return e
	if name == "Glass":
		var g := StandardMaterial3D.new()
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(0.6, 0.8, 0.85, 0.18)
		g.roughness = 0.05
		g.metallic = 0.2
		g.cull_mode = BaseMaterial3D.CULL_DISABLED
		return g
	if name == "HoloBeam":
		var hb := StandardMaterial3D.new()
		hb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hb.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hb.albedo_color = Color(0.1, 0.5, 1.0, 0.16)
		hb.cull_mode = BaseMaterial3D.CULL_DISABLED
		return hb
	if name == "Mirror":
		var mi := StandardMaterial3D.new()
		mi.albedo_color = Color(0.62, 0.64, 0.66)
		mi.metallic = 1.0
		mi.roughness = 0.1
		return mi
	if name == "Screen":
		var sc := StandardMaterial3D.new()
		sc.albedo_color = Color(0.02, 0.035, 0.045)
		sc.roughness = 0.45
		sc.metallic = 0.3
		return sc
	return src


# --- Laadklep, rupsen ----------------------------------------------------------------

func _build_ramp_hinge() -> void:
	var ramp: Node3D = anchors["Ramp"]
	ramp_hinge = Node3D.new()
	ramp_hinge.name = "RampHinge"
	model.add_child(ramp_hinge)
	ramp_hinge.position = ramp.position
	ramp.reparent(ramp_hinge, true)


func _build_tracks() -> void:
	var link: MeshInstance3D = anchors["TrackLink"]
	var count := int(_track_perimeter() / LINK_SPACING)
	for side in [-1.0, 1.0]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link.mesh
		mm.instance_count = count
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _make_material("DarkSteel", null)
		model.add_child(mmi)
		var ang := deg_to_rad(TRACK_ROLL * side)
		mmi.transform = Transform3D(Basis(Vector3.FORWARD, -ang), Vector3(TRACK_CENTER.x * side, TRACK_CENTER.y, 0.0))
		_links.append(mmi)
	_update_tracks()


func _track_perimeter() -> float:
	return 2.0 * (TRACK_ZR - TRACK_ZF) + TAU * TRACK_R


## Punt en richting op het rupspad (lokaal), s = afstand langs het pad.
func _track_at(s: float) -> Array:
	var straight := TRACK_ZR - TRACK_ZF
	var half := PI * TRACK_R
	s = fposmod(s, _track_perimeter())
	if s < straight: # onderkant, naar achteren
		return [Vector3(0, -TRACK_R, TRACK_ZF + s), Vector3(0, 0, 1), Vector3(0, -1, 0)]
	s -= straight
	if s < half: # achterwiel, omhoog
		var a := -PI / 2 + s / TRACK_R
		var n := Vector3(0, sin(a), cos(a))
		return [Vector3(0, 0, TRACK_ZR) + n * TRACK_R, Vector3(0, cos(a), -sin(a)), n]
	s -= half
	if s < straight: # bovenkant, naar voren
		return [Vector3(0, TRACK_R, TRACK_ZR - s), Vector3(0, 0, -1), Vector3(0, 1, 0)]
	s -= straight
	var a2 := PI / 2 + s / TRACK_R
	var n2 := Vector3(0, sin(a2), cos(a2))
	return [Vector3(0, 0, TRACK_ZF) + n2 * TRACK_R, Vector3(0, cos(a2), -sin(a2)), n2]


func _update_tracks() -> void:
	for mmi in _links:
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var t := _track_at(i * LINK_SPACING + _track_scroll)
			var pos: Vector3 = t[0]
			var tangent: Vector3 = t[1]
			var normal: Vector3 = t[2]
			var b := Basis(tangent.cross(normal).normalized(), normal, tangent)
			mm.set_instance_transform(i, Transform3D(b, pos))


# --- Licht ------------------------------------------------------------------------------

func _build_lights() -> void:
	# Iets vóór de naaf en zonder schaduw: in het voorvlak van de naaf blokkeerde zijn eigen
	# behuizing het licht, en bleef het camerascherm zwart.
	var hub := _spot("Light_Hub", Color(1.0, 0.9, 0.75), 3.5, 30.0, 50.0, false)
	hub.position = Vector3(0, 0, -0.3)
	hub.spot_angle_attenuation = 0.7
	_spot("Light_Bar", Color(1.0, 0.88, 0.7), 2.2, 16.0, 62.0, false)
	_spot("Light_Roof_L", Color(1.0, 0.85, 0.65), 1.4, 12.0, 50.0, false)
	_spot("Light_Roof_R", Color(1.0, 0.85, 0.65), 1.4, 12.0, 50.0, false)
	_spot("Light_Rear", Color(1.0, 0.8, 0.55), 2.4, 13.0, 65.0, false)
	# Binnen: geen egaal licht maar plassen warm licht (binnen-14). De kooilampen reiken minder ver
	# en vallen sneller af; daartussen een bureaulamp op de werkbank, de lampjesslinger aan het
	# plafond en een lampje boven de ertstrechter. Allemaal zonder schaduw (GDD §9: budget).
	for i in 3:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.78, 0.5)
		o.light_energy = 1.25
		o.omni_range = 3.6
		o.omni_attenuation = 1.5
		o.shadow_enabled = false
		anchors["Cage_%d" % i].add_child(o)
		_lights.append(o)
		_cage_lights.append(o)
	if anchors.has("Lamp_Bench"):
		var bench := _spot("Lamp_Bench", Color(1.0, 0.72, 0.42), 3.2, 2.6, 58.0, false)
		bench.spot_angle_attenuation = 1.4
	for a in ["Lamp_String_0", "Lamp_String_1"]:
		if anchors.has(a):
			var st := OmniLight3D.new()
			st.light_color = Color(1.0, 0.66, 0.36)
			st.light_energy = 0.45
			st.omni_range = 2.4
			st.omni_attenuation = 1.2
			st.shadow_enabled = false
			anchors[a].add_child(st)
			_lights.append(st)
	if anchors.has("Lamp_Hopper"):
		var hop := OmniLight3D.new()
		hop.light_color = Color(1.0, 0.6, 0.25)
		hop.light_energy = 0.7
		hop.omni_range = 1.8
		hop.shadow_enabled = false
		anchors["Lamp_Hopper"].add_child(hop)
		_lights.append(hop)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.75, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 2.6
	anchors["Seat_Head"].add_child(glow)
	glow.position = Vector3(0, 0.55, -1.05)
	_ping_light = OmniLight3D.new()
	_ping_light.light_color = SonarScreen.PHOSPHOR
	_ping_light.light_energy = 0.0
	_ping_light.omni_range = 5.5
	_ping_light.shadow_enabled = false
	_ping_light.visible = false
	add_child(_ping_light)
	_ping_light.position = Vector3(0.6, 0.6, -2.4)
	for side in ["Beacon_L", "Beacon_R"]:
		var b := SpotLight3D.new()
		b.light_color = Color(1.0, 0.45, 0.05)
		b.light_energy = 0.0
		b.spot_range = 11.0
		b.spot_angle = 28.0
		b.shadow_enabled = false
		anchors[side].add_child(b)
		_beacon_lights.append(b)


func _spot(anchor: String, color: Color, energy: float, rng: float, angle: float, shadow: bool) -> SpotLight3D:
	var s := SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_range = rng
	s.spot_angle = angle
	s.shadow_enabled = shadow
	anchors[anchor].add_child(s)
	_lights.append(s)
	return s


# --- Deeltjes -----------------------------------------------------------------------------

func _build_particles() -> void:
	for a in ["Exhaust_L", "Exhaust_R"]:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		m.direction = Vector3(0, 1, 0)
		m.spread = 12.0
		m.initial_velocity_min = 1.2
		m.initial_velocity_max = 2.2
		m.gravity = Vector3(0, 0.3, 0)
		m.damping_min = 0.6
		m.damping_max = 1.0
		m.scale_min = 0.25
		m.scale_max = 0.45
		m.scale_curve = _curve_tex([Vector2(0, 0.4), Vector2(1, 2.4)])
		m.color_ramp = _gradient_tex(Color(0.2, 0.19, 0.18, 0.55), Color(0.2, 0.19, 0.18, 0.0))
		p.process_material = m
		p.draw_pass_1 = _puff_quad()
		p.amount = 26
		p.lifetime = 2.6
		p.local_coords = false
		anchors[a].add_child(p)
		_exhaust.append(p)
	_trail = GPUParticles3D.new()
	var tm := ParticleProcessMaterial.new()
	tm.direction = Vector3(0, 1, 0)
	tm.spread = 60.0
	tm.initial_velocity_min = 0.3
	tm.initial_velocity_max = 0.9
	tm.gravity = Vector3(0, -0.15, 0)
	tm.damping_min = 0.5
	tm.damping_max = 1.0
	tm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	tm.emission_box_extents = Vector3(2.2, 0.15, 0.4)
	tm.scale_min = 0.8
	tm.scale_max = 1.6
	tm.scale_curve = _curve_tex([Vector2(0, 0.6), Vector2(1, 2.2)])
	tm.color_ramp = _gradient_tex(Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0))
	_trail.process_material = tm
	_trail.draw_pass_1 = _puff_quad()
	_trail.amount = 40
	_trail.lifetime = 3.0
	_trail.local_coords = false
	_trail.emitting = false
	model.add_child(_trail)
	_trail.position = Vector3(0, -2.55, 4.4)
	var head_front: Node3D = anchors["Light_Hub"]
	_dust = _burst_emitter(head_front, 70, 1.8, _puff_quad(), 2.0, 5.0, 85.0, Vector3(0, -0.8, 0))
	(_dust.process_material as ParticleProcessMaterial).scale_min = 1.4
	(_dust.process_material as ParticleProcessMaterial).scale_max = 3.0
	(_dust.process_material as ParticleProcessMaterial).scale_curve = _curve_tex([Vector2(0, 0.5), Vector2(1, 1.6)])
	var grit_mesh := DigFx._scaled(FindKinds.chunk(2), 0.09) # rotsbrokjes, geen kubusjes
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.roughness = 0.9
	grit_mesh.surface_set_material(0, gm)
	# Weinig zwaartekracht: anders valt gruis van de bovenkant van de ring voor de kopcamera.
	_grit = _burst_emitter(head_front, 140, 0.7, grit_mesh, 3.0, 7.0, 75.0, Vector3(0, -1.5, 0))
	var spark := QuadMesh.new()
	spark.size = Vector2(0.03, 0.18)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(4.0, 2.4, 1.0)
	spark.material = sm
	_sparks = _burst_emitter(head_front, 90, 0.45, spark, 5.0, 11.0, 80.0, Vector3(0, -3.0, 0))
	# Boorpuin: brokken die achteraan tussen de rupsen uitvallen terwijl hij boort (gevoel-04: je
	# ziet van buiten dat hij werkt, niet enkel een paar spikkels vooraan).
	_spoil = GPUParticles3D.new()
	var sm2 := ParticleProcessMaterial.new()
	sm2.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm2.emission_box_extents = Vector3(1.6, 0.2, 0.3)
	sm2.direction = Vector3(0, -0.3, 1)
	sm2.spread = 25.0
	sm2.initial_velocity_min = 0.6
	sm2.initial_velocity_max = 1.8
	sm2.gravity = Vector3(0, -9.8, 0)
	sm2.angular_velocity_min = -300.0
	sm2.angular_velocity_max = 300.0
	sm2.scale_min = 0.8
	sm2.scale_max = 2.2
	_spoil.process_material = sm2
	var spoil_mesh := DigFx._scaled(FindKinds.chunk(4), 0.12)
	var spm := StandardMaterial3D.new()
	spm.vertex_color_use_as_albedo = true
	spm.roughness = 0.95
	spoil_mesh.surface_set_material(0, spm)
	_spoil.draw_pass_1 = spoil_mesh
	_spoil.amount = 40
	_spoil.lifetime = 1.4
	_spoil.local_coords = false
	_spoil.emitting = false
	model.add_child(_spoil)
	_spoil.position = Vector3(0, -2.1, 3.9)
	(_sparks.process_material as ParticleProcessMaterial).particle_flag_align_y = true
	(_sparks.process_material as ParticleProcessMaterial).color_ramp = _gradient_tex(Color(1, 0.9, 0.6, 1), Color(1, 0.35, 0.05, 0))


## Stuwraketten voor de landing na de drop: vier vlammen onder de romp (kegels met een flakkerende
## shader, in de ruimte van de Mol: deeltjes in wereldruimte vielen trager dan de Mol en stegen dus
## boven hem uit), rook, een gloed op de grond, het stof dat de straal van de grond blaast, en bij
## het neerkomen een stofring buiten de romp met brokjes. In de val: een zachte schaduw op de grond
## (de echte schaduw reikt niet zo ver).
func _build_thrusters() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.42
	cone.bottom_radius = 0.06
	cone.height = 1.0
	cone.radial_segments = 16
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	var k := 0
	for x: float in [-1.7, 1.7]:
		for z: float in [-2.6, 2.6]:
			var mi := MeshInstance3D.new()
			mi.mesh = cone
			var sm := ShaderMaterial.new()
			sm.shader = FLAME_SHADER
			sm.set_shader_parameter("seed", float(k) * 1.7)
			sm.set_shader_parameter("intensity", 0.0)
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			model.add_child(mi)
			mi.position = Vector3(x, -2.55, z)
			_flames.append(mi)
			_flame_mats.append(sm)
			# Rook uit de straalpijp: in wereldruimte, blijft hangen boven de grond.
			var smoke := GPUParticles3D.new()
			var pm := ParticleProcessMaterial.new()
			pm.direction = Vector3(0, -1, 0)
			pm.spread = 18.0
			pm.initial_velocity_min = 9.0
			pm.initial_velocity_max = 14.0
			pm.damping_min = 6.0
			pm.damping_max = 9.0
			pm.gravity = Vector3(0, 0.6, 0)
			pm.scale_min = 0.8
			pm.scale_max = 1.4
			pm.scale_curve = _curve_tex([Vector2(0, 0.6), Vector2(1, 2.4)])
			pm.color_ramp = _gradient_tex(Color(0.45, 0.4, 0.36, 0.32), Color(0.5, 0.45, 0.4, 0.0))
			smoke.process_material = pm
			smoke.draw_pass_1 = _outside_dust_quad(true)
			smoke.amount = 24
			smoke.lifetime = 1.4
			smoke.local_coords = false
			smoke.emitting = false
			model.add_child(smoke)
			smoke.position = Vector3(x, -3.4, z)
			_smoke.append(smoke)
			k += 1
	# Warmtetrilling rond de vlammen (een kolom die het beeld erachter laat trillen).
	var col := CylinderMesh.new()
	col.top_radius = 3.0
	col.bottom_radius = 3.8
	col.height = 1.0
	col.radial_segments = 20
	col.rings = 4
	col.cap_top = false
	col.cap_bottom = false
	_haze = MeshInstance3D.new()
	_haze.mesh = col
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = HAZE_SHADER
	_haze.material_override = _haze_mat
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_haze.visible = false
	model.add_child(_haze)
	_thrust_light = OmniLight3D.new()
	_thrust_light.light_color = Color(1.0, 0.55, 0.2)
	_thrust_light.light_energy = 0.0
	_thrust_light.omni_range = 26.0
	_thrust_light.shadow_enabled = false
	model.add_child(_thrust_light)
	_thrust_light.position = Vector3(0, -4.5, 0)
	# Stof dat de straal van de grond blaast (onder de Mol, op de grond, naar buiten).
	_downwash = GPUParticles3D.new()
	var wm := ParticleProcessMaterial.new()
	wm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	wm.emission_ring_axis = Vector3(0, 1, 0)
	wm.emission_ring_radius = 6.0
	wm.emission_ring_inner_radius = 4.0
	wm.emission_ring_height = 0.6
	wm.direction = Vector3(0, 0.2, 0)
	wm.spread = 15.0
	wm.radial_velocity_min = 6.0
	wm.radial_velocity_max = 12.0
	wm.damping_min = 2.5
	wm.damping_max = 4.5
	wm.gravity = Vector3(0, 1.2, 0)
	wm.scale_min = 2.0
	wm.scale_max = 3.6
	wm.scale_curve = _curve_tex([Vector2(0, 0.3), Vector2(0.2, 1.0), Vector2(1, 2.2)])
	var wg := Gradient.new() # even invloeien (geen ploppende wolken), dan dik, dan weg
	wg.set_color(0, Color(1, 1, 1, 0.0))
	wg.add_point(0.1, Color(1, 1, 1, 0.9))
	wg.set_color(wg.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var wgt := GradientTexture1D.new()
	wgt.gradient = wg
	wm.color_ramp = wgt
	_downwash.process_material = wm
	_downwash.draw_pass_1 = _outside_dust_quad(false, 6.0) # grote, trage wolken (kleine leken op spikkels)
	_downwash.amount = 110
	_downwash.lifetime = 2.2
	_downwash.local_coords = false
	_downwash.emitting = false
	_downwash.top_level = true
	_downwash.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	add_child(_downwash)
	# Stofring bij de landing: een ovaal BUITEN de romp (de Mol is langer dan breed), anders
	# staken de wolken door de vloer de cabine in.
	_landing_dust = GPUParticles3D.new()
	var dm := ParticleProcessMaterial.new()
	_ellipse_emission(dm, 5.0, 7.4, 48)
	dm.direction = Vector3(0, 0, 1) # langs de normaal: naar buiten
	dm.spread = 12.0
	dm.initial_velocity_min = 9.0
	dm.initial_velocity_max = 17.0
	dm.damping_min = 3.0
	dm.damping_max = 5.0
	dm.gravity = Vector3(0, 1.4, 0) # de wolk kolkt op, hij blijft niet plat in de grond (proximity fade)
	dm.scale_min = 1.5
	dm.scale_max = 2.8
	# Klein bij de romp, groot verder weg (een grote wolk vlak naast de romp stak door de wand).
	dm.scale_curve = _curve_tex([Vector2(0, 0.3), Vector2(0.15, 0.9), Vector2(1, 2.4)])
	dm.color_ramp = _gradient_tex(Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0))
	_landing_dust.process_material = dm
	_landing_dust.draw_pass_1 = _outside_dust_quad(false, 3.5)
	_landing_dust.amount = 150
	_landing_dust.lifetime = 3.0
	_landing_dust.one_shot = true
	_landing_dust.explosiveness = 0.92
	_landing_dust.local_coords = false
	_landing_dust.emitting = false
	model.add_child(_landing_dust)
	_landing_dust.position = Vector3(0, -1.9, 0)
	# Brokjes die opspatten bij de klap.
	_debris = GPUParticles3D.new()
	var bm := ParticleProcessMaterial.new()
	_ellipse_emission(bm, 3.6, 5.8, 32)
	bm.direction = Vector3(0, 0.0, 1)
	bm.spread = 25.0
	bm.initial_velocity_min = 5.5
	bm.initial_velocity_max = 12.0
	bm.gravity = Vector3(0, -9.8, 0)
	bm.angular_velocity_min = -400.0
	bm.angular_velocity_max = 400.0
	bm.scale_min = 0.7
	bm.scale_max = 1.8
	_debris.process_material = bm
	var chunk := DigFx._scaled(FindKinds.chunk(3), 0.16)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.95
	chunk.surface_set_material(0, cm)
	_debris.draw_pass_1 = chunk
	_debris.amount = 40
	_debris.lifetime = 1.6
	_debris.one_shot = true
	_debris.explosiveness = 1.0
	_debris.local_coords = false
	_debris.emitting = false
	model.add_child(_debris)
	_debris.position = Vector3(0, -2.4, 0)
	# Zachte schaduw recht onder de Mol, op de grond (de echte reikt pas op ±60 m).
	_shadow = Decal.new()
	_shadow.top_level = true
	_shadow.size = Vector3(5.5, 24.0, 9.5)
	_shadow.texture_albedo = _blob_texture()
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.0)
	_shadow.upper_fade = 0.2
	_shadow.lower_fade = 0.2
	_shadow.cull_mask = ~(1 << 1) & 0xFFFFF
	_shadow.visible = false
	add_child(_shadow)
	_rumble = _loop("drop_rumble", Vector3(0, 0, 0), 9.0, 80.0, -80.0)


## Uitstootpunten op een ovaal rond de Mol (lokaal x/z), met de normaal naar buiten.
func _ellipse_emission(m: ParticleProcessMaterial, rx: float, rz: float, n: int) -> void:
	var pts := Image.create(n, 1, false, Image.FORMAT_RGBF)
	var nrm := Image.create(n, 1, false, Image.FORMAT_RGBF)
	for i in n:
		var a := TAU * i / float(n)
		pts.set_pixel(i, 0, Color(cos(a) * rx, 0.0, sin(a) * rz))
		var nv := Vector3(cos(a) / rx, 0.0, sin(a) / rz).normalized()
		nrm.set_pixel(i, 0, Color(nv.x, nv.y, nv.z))
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = ImageTexture.create_from_image(pts)
	m.emission_normal_texture = ImageTexture.create_from_image(nrm)
	m.emission_point_count = n


## Zachte ronde vlek (schaduw): donker in het midden, uitlopend naar de rand.
static func _blob_texture() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length() / (s * 0.5)
			var a := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	return ImageTexture.create_from_image(img)


## Stofwolk en brokjes bij het neerkomen na de drop; het model veert even in.
func landing_burst() -> void:
	(_landing_dust.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(dust_color.lightened(0.2), 0.75)
	_landing_dust.restart()
	# Rook en stof van de straal die nog rondhangen, zouden nu door de vloer de cabine in steken.
	_downwash.visible = false
	for s in _smoke:
		s.visible = false
	(_debris.process_material as ParticleProcessMaterial).color = dust_color.darkened(0.25)
	_debris.restart()
	_sag_v = -3.2 # de vering slaat door: de klap van 7 m/s
	_flicker = 0.15


## Een ruk door de romp (de grijper klikt vast): het model schiet even op en veert terug. Enkel
## van buiten (binnen schokt de camera, zie MolRideFeel).
func jolt(strength: float) -> void:
	if outside_view:
		_sag_v += 1.4 * strength
	_flicker = maxf(_flicker, 0.12)


## PING: een groene puls door de cabine en een ping met zijn echo ([plaatshouder]: het piepje van de
## Mol, hoger; het echte geluid komt met M6).
func ping_pulse() -> void:
	_ping_glow = 1.0
	var at := (anchors["SonarPing"] as Node3D).position if anchors.has("SonarPing") else Vector3(1.4, 0.0, -3.0)
	play("mol_beep", at, -2.0, 1.8)
	get_tree().create_timer(0.38).timeout.connect(func() -> void:
		if is_inside_tree():
			play("mol_beep", at, -14.0, 1.75))


## De klemmen laten los: de lichten haperen, de motor houdt even de adem in.
func release() -> void:
	_flicker = 0.3
	_duck = 0.45


## De stuwraketten ontsteken: een felle flits.
func ignite() -> void:
	_flash = 1.0


## De lichten haperen zoveel seconden.
func flicker(seconds: float) -> void:
	_flicker = maxf(_flicker, seconds)


func _burst_emitter(parent: Node3D, amount: int, lifetime: float, mesh: Mesh, vmin: float, vmax: float,
		spread: float, gravity: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0, 1) # terug langs de kop: −z is vooruit, dus +z = naar de Mol toe
	m.spread = minf(spread, 25.0)
	m.initial_velocity_min = vmin
	m.initial_velocity_max = vmax
	m.gravity = gravity
	m.damping_min = 1.0
	m.damping_max = 2.5
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0, 0, 1)
	m.emission_ring_radius = 3.0
	m.emission_ring_inner_radius = 2.3
	m.emission_ring_height = 0.3
	m.angular_velocity_min = -300.0
	m.angular_velocity_max = 300.0
	m.radial_velocity_min = vmin * 0.6
	m.radial_velocity_max = vmax * 0.8
	m.initial_velocity_min = vmin * 0.3
	m.initial_velocity_max = vmax * 0.4
	p.process_material = m
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = true
	p.emitting = false
	parent.add_child(p)
	p.position = Vector3(0, 0, 0.8)
	return p


func _puff_quad() -> QuadMesh:
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = DigFx._puff_texture()
	m.roughness = 1.0
	q.material = m
	return q


## Stof en rook die buiten rond de Mol hangen (landing, straal, stuwraketten). Een grote billboard naast
## de romp staat met zijn rand door de wand de cabine in: een witte vlek linksonder na de landing.
## Daarom vervagen ze vlak bij de camera (wie in de Mol zit, ziet ze niet binnen) en waar ze een
## oppervlak raken (geen harde snede door de vloer of de wand). unshaded: de rook van de
## stuwraketten (de gloed van de vlammen vlak ernaast blies hem anders wit op).
func _outside_dust_quad(unshaded := false, size := 1.0) -> QuadMesh:
	var q := _puff_quad()
	q.size = Vector2(size, size)
	var m := q.material as StandardMaterial3D
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 2.5
	m.distance_fade_max_distance = 5.0
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 1.2
	return q


static func _curve_tex(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _gradient_tex(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


# --- Geluid ---------------------------------------------------------------------------------

func _build_audio() -> void:
	_snd["engine"] = _loop("mol_engine", Vector3(0, 2.4, 2.75), 9.0, 70.0, -4.0)
	_snd["cutter"] = _loop("mol_cutter", Vector3(0, 0, -6.5), 10.0, 80.0, -80.0)
	_snd["tracks"] = _loop("mol_tracks", Vector3(0, -2.4, 0), 7.0, 50.0, -80.0)
	_snd["interior"] = _loop("mol_interior", Vector3(0, 0, 0), 2.2, 7.0, -6.0)


## Geluid uit assets/audio/sfx (de drop-geluiden via DropAudio: die zetten zelf hun loop-vlag).
static func _stream(name: String) -> AudioStream:
	if name.begins_with("drop_"):
		return DropAudio.stream(name)
	return load("res://assets/audio/sfx/%s.wav" % name)


func _loop(name: String, pos: Vector3, unit: float, max_d: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = _stream(name)
	p.unit_size = unit
	p.max_distance = max_d
	p.volume_db = db
	add_child(p)
	p.position = pos
	p.play()
	return p


func play(name: String, pos := Vector3.ZERO, db := 0.0, pitch := 1.0) -> void:
	var stream := _stream(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = stream
	p.unit_size = 10.0
	p.max_distance = 80.0
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Camerascherm ----------------------------------------------------------------------------

func _build_feed() -> void:
	_feed_viewport = SubViewport.new()
	# Een SubViewport erft de fysica-interpolatie niet: deze camera beweegt in _process (gevoel-02).
	_feed_viewport.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_feed_viewport.size = Vector2i(640, 352)
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_feed_viewport)
	_feed_viewport.world_3d = get_viewport().world_3d
	_feed_camera = Camera3D.new()
	_feed_camera.fov = 78.0
	_feed_camera.near = 0.1
	_feed_camera.far = 60.0
	_feed_viewport.add_child(_feed_camera)
	var screen: MeshInstance3D = anchors["Monitor"]
	var m := ShaderMaterial.new()
	m.shader = FEED_SHADER
	m.set_shader_parameter("feed", _feed_viewport.get_texture())
	screen.material_override = m
	# Beeld licht warm (niet groengrijs), zodat het naast het amberen statusscherm hoort.
	m.set_shader_parameter("tint", Color(1.0, 0.95, 0.86))
	# Overlay zoals een bewakingscamera: naam, REC, vizier, diepte. Amber in het schermlettertype,
	# de kop zoals op het statusscherm (ui-13).
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_viewport.add_child(hud)
	var font_col := Color(SCREEN_AMBER, 1.0)
	# Donkere banden achter de kop en de voetregel: leesbaar, ook tegen een lichte hemel.
	for band in [Rect2(0, 0, 640, 46), Rect2(0, 300, 640, 52)]:
		var b := ColorRect.new()
		b.color = Color(0.0, 0.0, 0.0, 0.55)
		b.position = band.position
		b.size = band.size
		hud.add_child(b)
	_feed_top = _screen_text("CAM 1  ·  DRILL HEAD", Vector2(18, 10), 24, Color(SCREEN_AMBER, 0.9))
	hud.add_child(_feed_top)
	_feed_rec = ColorRect.new()
	_feed_rec.color = Color(1.0, 0.15, 0.1)
	_feed_rec.size = Vector2(12, 12)
	_feed_rec.position = Vector2(580, 20)
	hud.add_child(_feed_rec)
	var rec := _screen_text("REC", Vector2(528, 10), 24, Color(SCREEN_AMBER, 0.9))
	hud.add_child(rec)
	for r in [Rect2(310, 175, 20, 2), Rect2(319, 166, 2, 20), Rect2(250, 175, 30, 2), Rect2(360, 175, 30, 2)]:
		var cr := ColorRect.new()
		cr.color = Color(SCREEN_AMBER, 0.5)
		cr.position = r.position
		cr.size = r.size
		hud.add_child(cr)
	_feed_label = _screen_text("", Vector2(18, 310), 26, font_col)
	hud.add_child(_feed_label)


# --- Elke frame -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Boorkop: snel bij boren, traag stationair.
	var spin_target := 2.4 if drilling else (0.9 if absf(speed) > 0.1 else 0.35)
	_head_spin = move_toward(_head_spin, spin_target, delta * 1.5)
	_head.rotate_object_local(Vector3.FORWARD, _head_spin * delta)

	# Wielen en rupsen.
	for w in _wheels:
		(w[0] as Node3D).rotate(w[1], -speed / w[2] * delta)
	if absf(speed) > 0.01:
		_track_scroll += speed * delta
		_update_tracks()

	# Laadklep en hendel.
	var target := deg_to_rad(RAMP_OPEN_DEG) if ramp_open else 0.0
	var was := _ramp_angle
	_ramp_angle = move_toward(_ramp_angle, target, delta * deg_to_rad(55.0))
	ramp_hinge.rotation.x = _ramp_angle
	if is_equal_approx(was, 0.0) and _ramp_angle > 0.0 or is_equal_approx(was, deg_to_rad(RAMP_OPEN_DEG)) and _ramp_angle < was:
		play("mol_hydraulic", Vector3(0, -1.0, 4.0), -2.0)
	# Hendel: zichtbaar overhalen (±0,3 s, een veer die even naveert), niet in één beeld.
	var lever_want := deg_to_rad(35.0) if lever_pulled else 0.0
	var lever_left := minf(delta, 0.1)
	while lever_left > 0.0:
		var h := minf(lever_left, 1.0 / 120.0)
		_lever_v += ((lever_want - _lever_angle) * 220.0 - _lever_v * 17.0) * h
		_lever_angle += _lever_v * h
		lever_left -= h
	_lever.transform = _lever_rest * Transform3D(Basis(Vector3.RIGHT, _lever_angle), Vector3.ZERO)

	# Meternaalden: draaien rond de normaal van het schuine paneel (35° naar de bestuurder).
	for nd in _needles:
		nd[2] = lerp_angle(nd[2], nd[3], minf(1.0, delta * 4.0))
		var rest: Transform3D = nd[1]
		(nd[0] as Node3D).transform = Transform3D(Basis(DESK_NORMAL, nd[2]) * rest.basis, rest.origin)

	# Stuurhendels: duwen = die rups vooruit.
	for i in _sticks.size():
		var st: Array = _sticks[i]
		var want := -deg_to_rad(22.0) * (sticks.x if i == 0 else sticks.y)
		st[2] = lerpf(st[2], want, minf(1.0, delta * 10.0))
		var rest: Transform3D = st[1]
		(st[0] as Node3D).transform = Transform3D(Basis(Vector3.RIGHT, st[2]) * rest.basis, rest.origin)

	# Licht en zwaailichten. Bij de drop: binnen amber tijdens het aftellen, rood en pulserend de
	# laatste tellen en in de val; de lichten haperen bij de luiken, het loslaten en de klap.
	_flicker = maxf(0.0, _flicker - delta)
	var off := _flicker > 0.0 and fmod(Time.get_ticks_msec() * 0.009, 1.0) < 0.45 # ±9 keer per seconde
	for l in _lights:
		l.visible = lights_on and not off
	for m in _lens_mats:
		m.emission_energy_multiplier = 3.0 if lights_on and not off else 0.05
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.3)
	var cage_col := Color(1.0, 0.8, 0.55)
	var cage_e := 1.25
	if alert == 1:
		cage_col = Color(1.0, 0.52, 0.14)
		cage_e = 1.0
	elif alert == 2:
		cage_col = Color(1.0, 0.12, 0.05)
		cage_e = 0.45 + 1.4 * pulse
	for o in _cage_lights:
		o.light_color = o.light_color.lerp(cage_col, minf(1.0, delta * 6.0))
		o.light_energy = lerpf(o.light_energy, cage_e, minf(1.0, delta * 10.0))
	_beacon_angle += delta * 6.0
	for i in _beacon_lights.size():
		var b := _beacon_lights[i]
		b.light_energy = 3.0 if beacons else 0.0
		b.rotation = Vector3(deg_to_rad(-15.0), _beacon_angle + i * PI, 0.0)
	for m in _beacon_mats:
		m.emission_energy_multiplier = (2.5 + 2.0 * sin(_beacon_angle * 2.0)) if beacons else 0.3

	# Rook, stof, vonken.
	for p in _exhaust:
		p.amount_ratio = 0.35 + 0.65 * clampf(absf(throttle) + (0.5 if drilling else 0.0), 0.0, 1.0)
		p.emitting = true
	_dust.emitting = drilling
	_trail.emitting = absf(speed) > 0.4
	if _trail.emitting:
		(_trail.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(dust_color.lightened(0.15), 1.0)
	_grit.emitting = drilling
	_spoil.emitting = drilling
	_sparks.emitting = blocked
	if drilling:
		var dm := _dust.draw_pass_1.surface_get_material(0) as StandardMaterial3D
		dm.albedo_color = Color(dust_color.lightened(0.1), 0.55)
		(_grit.process_material as ParticleProcessMaterial).color = dust_color.darkened(0.2)
		(_spoil.process_material as ParticleProcessMaterial).color = dust_color.darkened(0.3)
	_update_drop_fx(delta)

	# Geluid.
	# De motor brult meteen op als de piloot gas geeft (throttle volgt de invoer), en zakt trager weg.
	var eng: AudioStreamPlayer3D = _snd.engine
	var eng_want := 0.85 + 0.45 * absf(throttle) + (0.15 if drilling else 0.0) + (0.25 if alert > 0 else 0.0)
	eng.pitch_scale = lerpf(eng.pitch_scale, eng_want, minf(1.0, delta * (9.0 if eng_want > eng.pitch_scale else 2.5)))
	_duck = maxf(0.0, _duck - delta)
	eng.volume_db = -4.0 + 2.5 * absf(throttle) - 18.0 * clampf(_duck / 0.3, 0.0, 1.0)
	_fade(_snd.cutter, -2.0 if drilling else -80.0, delta)
	_fade(_snd.tracks, -6.0 if absf(speed) > 0.15 else -80.0, delta)
	(_snd.tracks as AudioStreamPlayer3D).pitch_scale = clampf(0.5 + absf(speed) * 0.2, 0.5, 1.8)

	# Trillen bij boren gebeurt met de camera (vloeiend). Het model zelf elk frame willekeurig
	# verschuiven deed alles in de Mol zinderen. (In de val wiebelt het model traag: zie _update_drop_fx.)

	# Camerascherm. Bij de drop kijkt het door de buik naar beneden (de luiken, dan de diepte).
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if feed_active else SubViewport.UPDATE_DISABLED
	_status_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if feed_active else SubViewport.UPDATE_DISABLED
	if sonar_screen.active != feed_active:
		sonar_screen.active = feed_active
	if feed_active:
		if feed_cam == Feed.BELLY:
			_feed_camera.global_transform = global_transform * Transform3D(
					Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(0.0, -2.55, -1.0))
			_feed_camera.near = 0.05
			_feed_camera.far = 3000.0
			_feed_top.text = "CAM 2  ·  BELLY"
		elif feed_cam == Feed.ROOF:
			# Op het dak, naar boven: de grijper die neerdaalt, De Ekster erboven.
			_feed_camera.global_transform = global_transform * Transform3D(
					Basis.looking_at(Vector3(0.0, 1.0, -0.12), Vector3.FORWARD), Vector3(0.0, 2.75, -1.6))
			_feed_camera.near = 0.1
			_feed_camera.far = 3000.0
			_feed_top.text = "CAM 3  ·  ROOF"
		else:
			_feed_camera.global_transform = (anchors["Cam_Feed"] as Node3D).global_transform
			_feed_camera.near = 0.1
			_feed_camera.far = 60.0
			_feed_top.text = "CAM 1  ·  DRILL HEAD"
		_feed_label.text = feed_text
		_feed_rec.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.7


## De drop van buiten: vlammen, rook, stof van de straal, de zachte schaduw, het
## wiebelen in de val en het inveren na de landing (enkel het model; de botsvorm blijft recht).
func _update_drop_fx(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 3.0)
	var on := thrust > 0.02
	var now := Time.get_ticks_msec() / 1000.0
	for i in _flames.size():
		var fl := _flames[i]
		fl.visible = on
		if on:
			var length := (2.6 + 4.6 * thrust) * (0.9 + 0.2 * sin(now * 47.0 + i * 1.7)) + _flash * 3.5
			var w := 1.35 + 0.45 * _flash
			fl.scale = Vector3(w, length, w)
			fl.position.y = -2.55 - length * 0.5
			_flame_mats[i].set_shader_parameter("intensity", clampf(0.6 + 0.4 * thrust + _flash * 0.6, 0.0, 1.6))
	_haze.visible = on
	if on:
		var hl := 3.0 + 6.0 * thrust
		_haze.scale = Vector3(1.0, hl, 1.0)
		_haze.position.y = -2.7 - hl * 0.5
		_haze_mat.set_shader_parameter("intensity", clampf(0.35 + 0.65 * thrust + _flash * 0.5, 0.0, 1.0))
	for s in _smoke:
		s.emitting = on
		if on:
			s.visible = true
		s.amount_ratio = clampf(thrust, 0.25, 1.0)
	_thrust_light.light_energy = move_toward(_thrust_light.light_energy, 5.0 * thrust + 14.0 * _flash, delta * 40.0)
	_thrust_light.visible = _thrust_light.light_energy > 0.01
	var gp := global_position
	var h := gp.y - 2.73 - ground_y # rupsen boven de grond
	# Stof dat de straal van de grond blaast.
	# Tot aan de klap (de stofwolk is het laatste wat je van buiten ziet); vlak bij de grond het dikst.
	var wash := over_ground and on and h < 28.0
	_downwash.emitting = wash
	if wash:
		_downwash.visible = true
		_downwash.global_position = Vector3(gp.x, ground_y + 0.3, gp.z)
		_downwash.amount_ratio = clampf((1.0 - h / 28.0) * 1.6, 0.2, 1.0)
		(_downwash.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(dust_color.lightened(0.4), 1.0)
	# Zachte schaduw: waar de zon hem zou werpen, tot de echte schaduw het overneemt (±60 m).
	var sh_a := 0.5 * smoothstep(35.0, 75.0, h) * (1.0 - smoothstep(180.0, 330.0, h)) if over_ground else 0.0
	_shadow.visible = sh_a > 0.01
	if _shadow.visible:
		var sun := _sun_dir()
		var p := Vector3(gp.x, ground_y, gp.z)
		if sun.y < -0.2:
			p = gp + sun * ((ground_y - gp.y) / sun.y)
			if terrain:
				p.y = terrain.surface_height_at(p.x, p.z)
		_shadow.global_position = p
		_shadow.global_basis = Basis(Vector3.UP, global_rotation.y)
		_shadow.modulate = Color(0.0, 0.0, 0.0, sh_a)
	# Rammelen van de romp in de val.
	var rk := clampf(fall_speed / 50.0, 0.0, 1.0)
	_fade(_rumble, linear_to_db(maxf(0.0005, rk * 0.7)) if fall_speed > 1.0 else -80.0, delta)
	_rumble.pitch_scale = 0.8 + 0.4 * rk
	# Wiebelen in de val (minder als de stuwraketten hem stabiel houden), inveren na de landing.
	_wobble_t += delta
	var wob := clampf(fall_speed / 55.0, 0.0, 1.0) * (1.0 - clampf(thrust * 1.5, 0.0, 1.0)) if over_ground else 0.0
	var amp := deg_to_rad(2.4) * wob
	var want := Vector3(amp * (0.8 * sin(_wobble_t * 2.3) + 0.35 * sin(_wobble_t * 5.3)), 0.0, amp * sin(_wobble_t * 1.7 + 0.6))
	var shake_off := Vector3.ZERO
	if outside_view and not over_ground:
		# Rijden, van buiten (gevoel-04): de neus komt op bij het optrekken en duikt bij het remmen,
		# de romp helt naar buiten in de bocht, en bij het boren trilt hij.
		var lean := deg_to_rad(Tuning.get_f("mol", "model_lean_deg", 1.4))
		var roll := deg_to_rad(Tuning.get_f("mol", "model_roll_deg", 1.6))
		want.x += clampf(drive_acc, -3.0, 3.0) * lean
		want.z += clampf(-drive_turn / 0.3, -1.0, 1.0) * roll * clampf(0.35 + absf(speed), 0.0, 1.0)
		if drilling or blocked:
			_shake_t += delta * 23.0
			var sa := Tuning.get_f("mol", "model_drill_shake", 0.025) * (1.6 if blocked else 1.0)
			shake_off = Vector3(sin(_shake_t * 1.3) * 0.6, sin(_shake_t * 1.9 + 1.0), 0.0) * sa
			want.x += sin(_shake_t * 1.7) * sa * 0.25
		if lifting:
			# Aan de kabel: een trage slinger.
			want.x += deg_to_rad(2.5) * sin(_wobble_t * 0.9)
			want.z += deg_to_rad(3.5) * sin(_wobble_t * 0.7 + 1.2)
	model.rotation = model.rotation.lerp(want, minf(1.0, delta * (9.0 if outside_view and not over_ground else 4.0)))
	var left := minf(delta, 0.1) # veer in kleine stapjes (stabiel, ook bij een lang frame)
	while left > 0.0:
		var step := minf(left, 1.0 / 120.0)
		_sag_v += (-_sag * 140.0 - _sag_v * 11.0) * step
		_sag += _sag_v * step
		left -= step
	if absf(_sag) < 0.0005 and absf(_sag_v) < 0.005:
		_sag = 0.0
		_sag_v = 0.0
	model.position = Vector3(shake_off.x, _sag + shake_off.y, 0.0)
	# PING: een groene puls door de cabine.
	_ping_glow = maxf(0.0, _ping_glow - delta * 1.8)
	_ping_light.light_energy = 3.0 * _ping_glow * _ping_glow
	_ping_light.visible = _ping_glow > 0.01


var _sun: DirectionalLight3D
var _sun_looked := false


## Richting van het zonlicht (van de zon weg), of recht omlaag als er geen zon is.
func _sun_dir() -> Vector3:
	if not _sun_looked:
		_sun_looked = true
		var root := get_tree().current_scene
		if root:
			for n in root.find_children("*", "DirectionalLight3D", true, false):
				_sun = n
				break
	if _sun and is_instance_valid(_sun) and _sun.visible:
		return -_sun.global_basis.z
	return Vector3.DOWN


func _fade(p: AudioStreamPlayer3D, target_db: float, delta: float) -> void:
	p.volume_db = move_toward(p.volume_db, target_db, delta * 60.0)
