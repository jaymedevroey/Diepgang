class_name MolVisual
extends Node3D
## Alles wat je van de Mol ziet en hoort (docs/de-mol.md): model met machine-shader,
## draaiende boorkop en wielen, lopende rupsschakels, laadklep, hendel, lampen, rook,
## stof, geluid en het camerascherm in de cabine. Geen spellogica: Mol zet de toestand.

const MODEL := preload("res://assets/models/mol.glb")
const MACHINE := preload("res://src/mol/machine.gdshader")
const FEED_SHADER := preload("res://src/mol/feed.gdshader")

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
var _flames: Array[GPUParticles3D] = []
var _thrust_light: OmniLight3D
var _landing_dust: GPUParticles3D
var _feed_label: Label
var _feed_rec: ColorRect
## Tekst onderaan het camerascherm (diepte, laag).
var feed_text := ""
var _snd: Dictionary = {}
var _feed_viewport: SubViewport
var _feed_camera: Camera3D
var _rng := RandomNumberGenerator.new()
var _label_left: Label3D
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
	_label_left = _screen_label("Label_Depth")
	sonar_screen = SonarScreen.new()
	sonar_screen.name = "SonarScreen"
	add_child(sonar_screen)
	sonar_screen.setup(anchors["Sonar"], anchors["SonarLamp"])


## Meters op de console (0..1): diepte, snelheid, brandstof. De naalden lopen er traag naartoe.
func set_gauges(values: Array) -> void:
	for k in mini(values.size(), _needles.size()):
		_needles[k][3] = deg_to_rad(135.0 - 270.0 * clampf(values[k], 0.0, 1.0))


## Tekst op het statusscherm links van het camerascherm (amber, zoals een oud dotmatrixscherm).
func set_readout(text: String) -> void:
	_label_left.text = text


func _screen_label(anchor: String) -> Label3D:
	var l := Label3D.new()
	l.font = UiTheme.screen()
	l.font_size = 44
	l.line_spacing = -6.0
	l.pixel_size = 0.0016
	l.modulate = Color(1.0, 0.72, 0.3)
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.width = 360.0
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	anchors[anchor].add_child(l)
	l.position = Vector3(-0.28, 0.0, 0.03)
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
	for i in 3:
		var o := OmniLight3D.new()
		o.light_color = Color(1.0, 0.8, 0.55)
		o.light_energy = 1.1
		o.omni_range = 4.8
		o.shadow_enabled = false
		anchors["Cage_%d" % i].add_child(o)
		_lights.append(o)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.75, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 2.6
	anchors["Seat_Head"].add_child(glow)
	glow.position = Vector3(0, 0.55, -1.05)
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
	(_sparks.process_material as ParticleProcessMaterial).particle_flag_align_y = true
	(_sparks.process_material as ParticleProcessMaterial).color_ramp = _gradient_tex(Color(1, 0.9, 0.6, 1), Color(1, 0.35, 0.05, 0))


## Stuwraketten voor de landing na de drop: vier vlammen onder de romp, een gloed op de grond,
## en een stofring als hij neerkomt.
func _build_thrusters() -> void:
	var flame := QuadMesh.new()
	flame.size = Vector2(0.9, 0.9)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.vertex_color_use_as_albedo = true
	fm.albedo_texture = DigFx._puff_texture()
	flame.material = fm
	for x: float in [-1.7, 1.7]:
		for z: float in [-2.6, 2.6]:
			var p := GPUParticles3D.new()
			var m := ParticleProcessMaterial.new()
			m.direction = Vector3(0, -1, 0)
			m.spread = 7.0
			m.initial_velocity_min = 16.0
			m.initial_velocity_max = 22.0
			m.gravity = Vector3.ZERO
			m.scale_min = 0.8
			m.scale_max = 1.3
			m.scale_curve = _curve_tex([Vector2(0, 1.0), Vector2(1, 2.6)])
			var g := Gradient.new()
			g.set_color(0, Color(2.6, 2.2, 1.6, 1.0))
			g.add_point(0.25, Color(2.2, 0.9, 0.25, 0.9))
			g.set_color(g.get_point_count() - 1, Color(0.4, 0.3, 0.3, 0.0))
			var gt := GradientTexture1D.new()
			gt.gradient = g
			m.color_ramp = gt
			p.process_material = m
			p.draw_pass_1 = flame
			p.amount = 48
			p.lifetime = 0.28
			p.local_coords = false
			p.emitting = false
			model.add_child(p)
			p.position = Vector3(x, -2.5, z)
			_flames.append(p)
	_thrust_light = OmniLight3D.new()
	_thrust_light.light_color = Color(1.0, 0.55, 0.2)
	_thrust_light.light_energy = 0.0
	_thrust_light.omni_range = 26.0
	_thrust_light.shadow_enabled = false
	model.add_child(_thrust_light)
	_thrust_light.position = Vector3(0, -4.5, 0)
	# Stofring bij de landing: plat, naar buiten.
	_landing_dust = GPUParticles3D.new()
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	dm.emission_ring_axis = Vector3(0, 1, 0)
	dm.emission_ring_radius = 3.5
	dm.emission_ring_inner_radius = 2.5
	dm.emission_ring_height = 0.2
	dm.direction = Vector3(0, 0.15, 0)
	dm.spread = 10.0
	dm.radial_velocity_min = 7.0
	dm.radial_velocity_max = 13.0
	dm.damping_min = 3.0
	dm.damping_max = 5.0
	dm.gravity = Vector3(0, 0.25, 0)
	dm.scale_min = 2.2
	dm.scale_max = 4.0
	dm.scale_curve = _curve_tex([Vector2(0, 0.5), Vector2(1, 2.0)])
	dm.color_ramp = _gradient_tex(Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0))
	_landing_dust.process_material = dm
	_landing_dust.draw_pass_1 = _puff_quad()
	_landing_dust.amount = 90
	_landing_dust.lifetime = 3.2
	_landing_dust.one_shot = true
	_landing_dust.explosiveness = 0.9
	_landing_dust.local_coords = false
	_landing_dust.emitting = false
	model.add_child(_landing_dust)
	_landing_dust.position = Vector3(0, -2.6, 0)


## Stofwolk bij het neerkomen na de drop.
func landing_burst() -> void:
	(_landing_dust.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = Color(dust_color.lightened(0.2), 0.7)
	_landing_dust.restart()


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


func _loop(name: String, pos: Vector3, unit: float, max_d: float, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = load("res://assets/audio/sfx/%s.wav" % name)
	p.unit_size = unit
	p.max_distance = max_d
	p.volume_db = db
	add_child(p)
	p.position = pos
	p.play()
	return p


func play(name: String, pos := Vector3.ZERO, db := 0.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = load("res://assets/audio/sfx/%s.wav" % name)
	p.unit_size = 10.0
	p.max_distance = 80.0
	p.volume_db = db
	add_child(p)
	p.position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Camerascherm ----------------------------------------------------------------------------

func _build_feed() -> void:
	_feed_viewport = SubViewport.new()
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
	# Overlay zoals een bewakingscamera: naam, REC, vizier, diepte.
	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_viewport.add_child(hud)
	var font_col := Color(0.85, 1.0, 0.85, 0.9)
	var top := Label.new()
	top.text = "CAM 1  ·  BOORKOP"
	top.position = Vector2(18, 12)
	top.add_theme_font_size_override("font_size", 20)
	top.add_theme_color_override("font_color", font_col)
	hud.add_child(top)
	_feed_rec = ColorRect.new()
	_feed_rec.color = Color(1.0, 0.15, 0.1)
	_feed_rec.size = Vector2(12, 12)
	_feed_rec.position = Vector2(580, 20)
	hud.add_child(_feed_rec)
	var rec := Label.new()
	rec.text = "REC"
	rec.position = Vector2(538, 12)
	rec.add_theme_font_size_override("font_size", 20)
	rec.add_theme_color_override("font_color", font_col)
	hud.add_child(rec)
	for r in [Rect2(310, 175, 20, 2), Rect2(319, 166, 2, 20), Rect2(250, 175, 30, 2), Rect2(360, 175, 30, 2)]:
		var cr := ColorRect.new()
		cr.color = Color(0.85, 1.0, 0.85, 0.55)
		cr.position = r.position
		cr.size = r.size
		hud.add_child(cr)
	_feed_label = Label.new()
	_feed_label.position = Vector2(18, 312)
	_feed_label.add_theme_font_size_override("font_size", 20)
	_feed_label.add_theme_color_override("font_color", font_col)
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
	_lever.transform = _lever_rest * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(35.0) if lever_pulled else 0.0), Vector3.ZERO)

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

	# Licht en zwaailichten.
	for l in _lights:
		l.visible = lights_on
	for m in _lens_mats:
		m.emission_energy_multiplier = 3.0 if lights_on else 0.05
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
	_sparks.emitting = blocked
	for f in _flames:
		f.emitting = thrust > 0.02
		f.amount_ratio = clampf(thrust, 0.2, 1.0)
	_thrust_light.light_energy = move_toward(_thrust_light.light_energy, 5.0 * thrust, delta * 25.0)
	_thrust_light.visible = _thrust_light.light_energy > 0.01
	if drilling:
		var dm := _dust.draw_pass_1.surface_get_material(0) as StandardMaterial3D
		dm.albedo_color = Color(dust_color.lightened(0.1), 0.55)
		(_grit.process_material as ParticleProcessMaterial).color = dust_color.darkened(0.2)

	# Geluid.
	var eng: AudioStreamPlayer3D = _snd.engine
	eng.pitch_scale = lerpf(eng.pitch_scale, 0.85 + 0.45 * absf(throttle) + (0.15 if drilling else 0.0), delta * 3.0)
	_fade(_snd.cutter, -2.0 if drilling else -80.0, delta)
	_fade(_snd.tracks, -6.0 if absf(speed) > 0.15 else -80.0, delta)
	(_snd.tracks as AudioStreamPlayer3D).pitch_scale = clampf(0.5 + absf(speed) * 0.2, 0.5, 1.8)

	# Trillen bij boren gebeurt met de camera (vloeiend). Het model zelf elk frame willekeurig
	# verschuiven deed alles in de Mol zinderen.

	# Camerascherm.
	_feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if feed_active else SubViewport.UPDATE_DISABLED
	if sonar_screen.active != feed_active:
		sonar_screen.active = feed_active
	if feed_active:
		_feed_camera.global_transform = (anchors["Cam_Feed"] as Node3D).global_transform
		_feed_label.text = feed_text
		_feed_rec.visible = fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.7


func _fade(p: AudioStreamPlayer3D, target_db: float, delta: float) -> void:
	p.volume_db = move_toward(p.volume_db, target_db, delta * 60.0)
