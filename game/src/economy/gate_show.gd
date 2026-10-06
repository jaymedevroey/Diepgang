class_name GateShow
extends Node3D
## De taxatiepoort en het verkoopluik als ceremonie (golf 3: ui2-01, gevoel2-04, binnen2-10,
## ontwerp2-9). Enkel beeld, op elke peer; de host beslist in Appraisal. Alles hangt aan de lege
## punten Appraisal_Gate en Sell_Hatch van het hubmodel (layout.py), en wordt in code gebouwd zodat
## het hubmodel (een gedeelde .glb) niet opnieuw gebouwd moet worden:
## - De band loopt zichtbaar (latten die meelopen) en is verlengd tot de voet van de klep van de Mol:
##   wat je daar neerlegt, rijdt de poort in.
## - De poort doet zelf iets: een scanstraal zakt over het stuk, de lichtstroken in de palen worden
##   wit, dan de kleur van de waardeklasse (wit, goud, fel goud), en regenboog als een skelet compleet
##   is; een lamp in de poort kleurt het stuk en de vloer mee.
## - Het podium: een groot scherm boven de poort (HubScreens tekent het, sleutel APPRAISAL); het
##   kleine scherm uit het model gaat uit.
## - Het luik: bij een verkoop gaan de stukken één voor één het luik in (kopieën van het model; de
##   echte vondsten haalt de host weg), en het scherm op de toonbank (HubScreens, PAYOUT) telt op.
## Geluid: Appraisal.cue (haken), geen klank uit code.

const BELT_SHADER := preload("res://src/economy/gate_belt.gdshader")
## Kleur van de poort per waardeklasse (FindKinds.ValueClass): rommel, gewoon, waardevol, kostbaar.
const CLASS_LIGHT: Array[Color] = [Color(0.72, 0.7, 0.66), Color(1.0, 0.95, 0.86), Color(1.0, 0.76, 0.28), Color(1.0, 0.62, 0.1)]
const IDLE := Color(0.31, 0.89, 0.94)
## Het verlengde van de band, lokaal t.o.v. Appraisal_Gate (de band uit het model: x −1,65..1,65).
const FEED_X := Vector2(-3.45, -1.65)
const BELT_Z := 0.9
## Het podium boven de poort (lokaal t.o.v. Appraisal_Gate, naar −x: de kade): breed en hoger dan
## het oude scherm, maar onder de kroon (4,45 m) en boven de opening (2,92 m).
const STAGE_SIZE := Vector2(2.4, 0.98)
const STAGE_POS := Vector3(-0.262, 3.445, 0.0)
## Het scherm op de toonbank van het luik (lokaal t.o.v. Appraisal_Gate; het luik ligt op dezelfde z).
const PAYOUT_SIZE := Vector2(0.72, 0.4)
const PAYOUT_POS := Vector3(2.97, 1.215, -0.66)
## Waar de stukken het luik in gaan (lokaal t.o.v. Appraisal_Gate).
const HATCH_MOUTH := Vector3(3.62, 1.55, 0.35)

var ship: Node3D # Ekster
var appraisal: Appraisal
## Het podium en het scherm aan het luik (HubScreens tekent erop).
var stage: MeshInstance3D
var payout: MeshInstance3D

var _gate: Node3D
var _belts: Array[ShaderMaterial] = []
var _belt_offset := 0.0
var _strips: Array[StandardMaterial3D] = []
var _lenses: StandardMaterial3D
var _light: OmniLight3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
## Het gordijn onder de scanstraal (van de straal tot de vloer, zwak): zo leest het als een scanner.
var _fan: MeshInstance3D
var _fan_mat: StandardMaterial3D
var _class_col := IDLE
var _rainbow := false


func _init(hub: Node3D) -> void:
	ship = hub
	name = "GateShow"


func _ready() -> void:
	var anchors: Dictionary = ship.get("anchors")
	if not anchors.has("Appraisal_Gate"):
		return
	_gate = Node3D.new()
	_gate.name = "Gate"
	add_child(_gate)
	_gate.global_transform = (anchors["Appraisal_Gate"] as Node3D).global_transform
	_build_belts()
	_build_gate_lights()
	_build_stage()
	_build_payout()
	if anchors.has("Appraisal_Screen"):
		(anchors["Appraisal_Screen"] as Node3D).visible = false # het podium vervangt het kleine scherm


## Verbinden met de firma (na het opzetten van het spel).
func connect_company(c: Company) -> void:
	appraisal = c.appraisal
	appraisal.revealed.connect(_on_revealed)
	appraisal.sold.connect(_on_sold)


func _process(delta: float) -> void:
	if _gate == null or appraisal == null:
		return
	var now := Time.get_ticks_msec()
	# De band: de latten lopen mee zolang er iets op ligt dat nog rijdt.
	if _belt_moving():
		_belt_offset += Tuning.get_f("economy", "belt_speed", 0.6) * delta
		for m in _belts:
			m.set_shader_parameter("offset", _belt_offset)
	# De scanstraal: van boven naar onder over het stuk, de lenzen fel, de stroken wit.
	var scan_s := Tuning.get_f("economy", "scan_s", 0.9)
	var since_scan := (now - appraisal.scan_at) / 1000.0
	var scanning := appraisal.scanning_id >= 0 and since_scan < scan_s + 0.6
	if scanning:
		var k := clampf(since_scan / scan_s, 0.0, 1.0)
		_beam.visible = true
		_fan.visible = true
		var y := lerpf(2.75, 0.06, k)
		_beam.position.y = y
		_beam_mat.albedo_color = Color(0.75, 0.95, 1.0, 0.7 * (1.0 - 0.3 * k))
		_fan.scale.y = maxf(0.01, y)
		_fan.position.y = y / 2.0
		var flick := 0.75 + 0.25 * sin(now * 0.05)
		_set_strips(Color(0.9, 1.0, 1.0) * flick, 5.0)
		_lenses.emission_energy_multiplier = 6.0 * flick
		_light.light_color = Color(0.8, 0.95, 1.0)
		_light.light_energy = 1.2
		return
	_beam.visible = false
	_fan.visible = false
	_lenses.emission_energy_multiplier = 1.5
	# Na de onthulling: de kleur van de waardeklasse, uitdovend naar het gewone cyaan.
	var since := (now - appraisal.reveal_at) / 1000.0
	var hold := Tuning.get_f("economy", "reveal_hold_s", 1.8) + 1.4
	if since < hold:
		var col := _class_col
		if _rainbow:
			col = Color.from_hsv(fmod(since * 0.8, 1.0), 0.75, 1.0)
		var fade := clampf((hold - since) / 1.0, 0.0, 1.0)
		var pulse := 1.0 + 0.35 * sin(since * 14.0) * fade if _class_col == CLASS_LIGHT[3] or _rainbow else 1.0
		_set_strips(IDLE.lerp(col, fade), lerpf(2.5, 6.0, fade) * pulse)
		_light.light_color = col
		_light.light_energy = 2.6 * fade * pulse
	else:
		_set_strips(IDLE, 2.5)
		_light.light_energy = 0.0


func _belt_moving() -> bool:
	if not appraisal.belt_running():
		return false
	for it: FindItem in appraisal.company.game.finds.items:
		if appraisal.on_belt(it) and appraisal._gate_local(it.global_position).x < Appraisal.BELT_END - 0.03:
			return true
	return false


func _on_revealed(info: Dictionary) -> void:
	_class_col = CLASS_LIGHT[clampi(int(info.get("value_class", 1)), 0, CLASS_LIGHT.size() - 1)]
	_rainbow = bool(info.get("set_done", false))


## De verkoop: elk stuk (een kopie van zijn model) gaat na het vorige het luik in.
func _on_sold(info: Dictionary) -> void:
	var gap := Tuning.get_f("economy", "sell_gap_s", 0.35)
	var lines: Array = info.get("items", [])
	var game: Game = appraisal.company.game
	for i in lines.size():
		var it: FindItem = game.finds.item(int(lines[i][2]))
		if it == null:
			continue
		var ghost := Node3D.new()
		ghost.name = "SoldGhost"
		add_child(ghost)
		ghost.global_transform = it.global_transform
		for mi: MeshInstance3D in it.find_children("*", "MeshInstance3D", true, false):
			var copy := mi.duplicate() as MeshInstance3D
			ghost.add_child(copy)
			copy.global_transform = mi.global_transform
		it.visible = false
		var from := ghost.global_position
		var mouth := _gate.global_transform * HATCH_MOUTH
		var over := _gate.global_transform * Vector3(HATCH_MOUTH.x - 0.9, 2.0, HATCH_MOUTH.z * 0.5)
		var inside := _gate.global_transform * (HATCH_MOUTH + Vector3(0.7, -0.1, 0.0))
		var tw := ghost.create_tween()
		tw.tween_interval(i * gap)
		tw.tween_callback(func() -> void: appraisal.cue.emit("hatch_item", mouth, -1))
		tw.tween_method(func(k: float) -> void:
			# Een boog: omhoog van de band, over de toonbank, het luik in.
			var a := from.lerp(over, k)
			var b := over.lerp(mouth, k)
			ghost.global_position = a.lerp(b, k), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(ghost, "scale", Vector3.ONE * 0.7, 0.45)
		tw.tween_property(ghost, "global_position", inside, 0.18)
		tw.parallel().tween_property(ghost, "scale", Vector3.ONE * 0.2, 0.18)
		tw.tween_callback(ghost.queue_free)


func _set_strips(col: Color, energy: float) -> void:
	for m in _strips:
		m.albedo_color = col
		m.emission = col
		m.emission_energy_multiplier = energy


# --- Opbouw --------------------------------------------------------------------------------------

## De band uit het model krijgt een lopend oppervlak, en een verlengde tot de voet van de klep (vlak
## in de vloer, met een frame en een rol aan het begin: je loopt eroverheen, zoals over de band).
func _build_belts() -> void:
	_belts.append(_belt_surface(Vector2(-1.65, 1.65), 0.0215))
	_belts.append(_belt_surface(FEED_X, 0.0215))
	var steel := _mat(Color(0.2, 0.205, 0.215), 0.85, 0.45)
	var yellow := _mat(Color(0.949, 0.718, 0.02), 0.15, 0.5)
	var len := FEED_X.y - FEED_X.x
	var cx := (FEED_X.x + FEED_X.y) / 2.0
	# Frame (twee langsbalken en een kopse kant) en een rol aan het begin.
	for z in [-BELT_Z - 0.05, BELT_Z + 0.05]:
		_box(Vector3(cx, 0.012, z), Vector3(len, 0.03, 0.1), steel)
	_box(Vector3(FEED_X.x - 0.05, 0.012, 0.0), Vector3(0.1, 0.03, BELT_Z * 2.0 + 0.2), yellow)
	var roller := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = BELT_Z * 2.0
	roller.mesh = cyl
	roller.material_override = _mat(Color(0.55, 0.56, 0.59), 0.9, 0.32)
	_gate.add_child(roller)
	roller.position = Vector3(FEED_X.x + 0.03, 0.005, 0.0)
	roller.rotation = Vector3(PI / 2.0, 0.0, 0.0)


func _belt_surface(xs: Vector2, y: float) -> ShaderMaterial:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(xs.y - xs.x, BELT_Z * 2.0)
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = BELT_SHADER
	m.set_shader_parameter("belt_len", xs.y - xs.x)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate.add_child(mi)
	mi.position = Vector3((xs.x + xs.y) / 2.0, y, 0.0)
	return m


## Lichtstroken over de cyaan stroken van het model (binnenkant van de palen en onder de balk), de
## drie scannerlenzen, een lamp in de poort en de scanstraal.
func _build_gate_lights() -> void:
	for zs in [-0.977, 0.977]:
		for x in [-0.12, 0.12]:
			_strips.append(_emissive_box(Vector3(x, 1.47, zs), Vector3(0.03, 2.28, 0.006)))
	for x in [-0.02, 0.16]:
		_strips.append(_emissive_box(Vector3(x, 2.862, 0.0), Vector3(0.034, 0.006, 1.96)))
	_lenses = StandardMaterial3D.new()
	_lenses.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lenses.albedo_color = Color(1.0, 0.2, 0.08)
	_lenses.emission_enabled = true
	_lenses.emission = Color(1.0, 0.2, 0.08)
	for z in [-0.55, 0.0, 0.55]:
		var lens := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.022
		sph.height = 0.03
		lens.mesh = sph
		lens.material_override = _lenses
		_gate.add_child(lens)
		lens.position = Vector3(0.07, 2.762, z)
	_light = OmniLight3D.new()
	_light.omni_range = 3.4
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_gate.add_child(_light)
	_light.position = Vector3(-0.2, 1.9, 0.0)
	_beam = MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(0.5, 0.045, 1.94)
	_beam.mesh = slab
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(0.75, 0.95, 1.0, 0.5)
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	_gate.add_child(_beam)
	_beam.position = Vector3(0.0, 2.7, 0.0)
	_fan = MeshInstance3D.new()
	var curtain := QuadMesh.new()
	curtain.size = Vector2(1.94, 1.0)
	_fan.mesh = curtain
	_fan_mat = StandardMaterial3D.new()
	_fan_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fan_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fan_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fan_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fan_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.16)
	_fan.material_override = _fan_mat
	_fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fan.visible = false
	_gate.add_child(_fan)
	_fan.rotation = Vector3(0.0, PI / 2.0, 0.0)
	_set_strips(IDLE, 2.5)


## Het podium: een scherm in een kader boven de poort, naar de kade (−x). Het kader verbergt het
## kleine scherm uit het model en is van achteren een donkere kast.
func _build_stage() -> void:
	var dark := _mat(Color(0.137, 0.149, 0.169), 0.35, 0.55)
	_box(STAGE_POS + Vector3(0.03, 0.0, 0.0), Vector3(0.05, STAGE_SIZE.y + 0.08, STAGE_SIZE.x + 0.1), dark)
	var yellow := _mat(Color(0.949, 0.718, 0.02), 0.15, 0.5)
	_box(STAGE_POS + Vector3(0.005, -STAGE_SIZE.y / 2.0 - 0.035, 0.0), Vector3(0.012, 0.022, STAGE_SIZE.x + 0.1), yellow)
	stage = _screen_quad("Stage_Screen", STAGE_SIZE, STAGE_POS, 0.0)


## Het scherm op de toonbank van het luik, licht achterover, op ooghoogte van een robot.
func _build_payout() -> void:
	var dark := _mat(Color(0.137, 0.149, 0.169), 0.35, 0.55)
	payout = _screen_quad("Payout_Screen", PAYOUT_SIZE, PAYOUT_POS, deg_to_rad(-20.0))
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(PAYOUT_SIZE.x + 0.06, PAYOUT_SIZE.y + 0.06, 0.05)
	frame.mesh = bm
	frame.material_override = dark
	payout.add_child(frame)
	frame.position = Vector3(0.0, 0.0, -0.03)
	# Een voetje op de toonbank.
	_box(Vector3(PAYOUT_POS.x + 0.06, 1.03, PAYOUT_POS.z), Vector3(0.1, 0.06, 0.3), dark)


## Een vlak (QuadMesh, UV 0..1) dat naar −x kijkt, `tilt` rad achterover.
func _screen_quad(n: String, size: Vector2, pos: Vector3, tilt: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate.add_child(mi)
	mi.position = pos
	mi.rotation = Vector3(0.0, -PI / 2.0, 0.0)
	mi.rotate_object_local(Vector3.RIGHT, tilt)
	return mi


func _emissive_box(pos: Vector3, size: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	_box(pos, size, m)
	return m


func _box(pos: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	_gate.add_child(mi)
	mi.position = pos
	return mi


static func _mat(col: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = roughness
	return m
