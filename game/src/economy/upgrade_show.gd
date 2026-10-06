class_name UpgradeShow
extends Node3D
## Upgrades die je ziet, en kopen met een gevolg in de wereld (golf 3: binnen2-11, ui2-11). Enkel beeld,
## op elke peer; de firma (Company) beslist. Gebouwd in code aan de lege punten van het hubmodel, zodat
## het hubmodel niet opnieuw gebouwd moet worden:
## - Gereedschapsrek: de boor T2 hangt op het schaduwbord over de omtrek "MISSING", met een prijskaartje.
##   Gekocht: hij is weg (je hebt hem in de hand) en er hangt een sticker ISSUED TO CREW.
## - Uitgiftebalie: wat je koopt (scanner, helmlamp) schuift als pakje onder het rolluik over de balie
##   naar je toe, en blijft liggen.
## - Mol-werf: naast de console staan een boorkop T2 (de kop van de Mol, kleiner, met carbidetanden) en
##   een bagagebak voor het grotere laadruim, met een prijskaartje. Gekocht: de bok is leeg (INSTALLED)
##   en de Mol draagt ze (MolVisual.set_upgrades).
## Dezelfde modellen staan op de kaarten in de winkel (ShopMenu, `model_for`).
## Geluid: Appraisal.cue("delivery"), geen klank uit code.

## Plan van de hub (tools/blender/interior/layout.py): plan (x, y, z) = hub (x − 7, y, z − 9).
const PLAN_ORIGIN := Vector3(7.0, 0.0, 9.0)
## Waar de boor T2 hangt (plan): over de omtrek MISSING op het schaduwbord (workdeck_niches.py).
const RACK_DRILL := Vector3(0.27, 2.62, 33.0)
## Waar de pakjes over de balie schuiven (plan): van achter het rolluik naar de voorrand van het blad.
const HATCH_IN := Vector3(1.85, 2.165, 37.0)
const HATCH_OUT := [Vector3(2.3, 2.165, 36.55), Vector3(2.3, 2.165, 37.45)]
## De bokken op de Mol-werf (plan), aan de reling naast de console (de looproute blijft vrij).
const YARD_HEAD := Vector3(16.95, 1.2, 6.4)
const YARD_CARGO := Vector3(16.95, 1.2, 12.6)

var ship: Node3D # Ekster
var company: Company
var _drill: Node3D
var _drill_tag: Label3D
var _drill_issued: Label3D
var _parcels := {} # upgrade-id -> Node3D
var _yard := {} # upgrade-id -> [stuk, kaartje, sticker]
var _owned: Array = []
var _mol_model: Node3D


func _init(hub: Node3D) -> void:
	ship = hub
	name = "UpgradeShow"


func _ready() -> void:
	_build_rack()
	_build_yard()


func connect_company(c: Company) -> void:
	company = c
	company.changed.connect(_refresh.bind(true))
	_refresh(false)


func _hub(plan: Vector3) -> Vector3:
	return ship.global_transform * (plan - PLAN_ORIGIN)


## Wat de firma bezit, in de wereld zetten. `animate`: een nieuwe aankoop krijgt zijn moment.
func _refresh(animate: bool) -> void:
	if company == null:
		return
	var price_n := company.team_size()
	for id: String in Upgrades.ORDER:
		var own := company.has_upgrade(id)
		var fresh := own and not _owned.has(id)
		match id:
			Upgrades.DRILL_T2:
				_drill.visible = not own
				_drill_issued.visible = own
				_drill_tag.text = "DRILL T2\n%s" % UiTheme.euro(Upgrades.price(id, price_n))
			Upgrades.SCANNER, Upgrades.LAMP:
				if own and not _parcels.has(id):
					_deliver(id, animate and fresh)
			Upgrades.MOL_HEAD_T2, Upgrades.CARGO:
				var parts: Array = _yard[id]
				(parts[0] as Node3D).visible = not own
				(parts[1] as Label3D).text = "%s\n%s" % [str(Upgrades.info(id).name).to_upper(), UiTheme.euro(Upgrades.price(id, price_n))]
				(parts[1] as Label3D).visible = not own
				(parts[2] as Label3D).visible = own
	_owned = company.upgrades.duplicate()


# --- Gereedschapsrek ----------------------------------------------------------------------------

func _build_rack() -> void:
	_drill = Node3D.new()
	_drill.name = "RackDrillT2"
	add_child(_drill)
	var m := model_for(Upgrades.DRILL_T2)
	_drill.add_child(m)
	# Op de haak, de punt naar links (−z in het plan), de greep omlaag, plat tegen het bord.
	_drill.global_transform = Transform3D(ship.global_basis, _hub(RACK_DRILL))
	_drill_tag = _tag(_hub(RACK_DRILL + Vector3(0.06, 0.3, 0.0)), Vector3(1, 0, 0), 0.0016)
	_drill_issued = _sticker("ISSUED TO CREW", _hub(RACK_DRILL + Vector3(0.05, 0.0, 0.0)), Vector3(1, 0, 0))


# --- Uitgiftebalie ------------------------------------------------------------------------------

## Een pakje met DIG-tape en een etiket glijdt uit het luik (of ligt er al, na het laden).
func _deliver(id: String, animate: bool) -> void:
	var slot := 0 if id == Upgrades.SCANNER else 1
	var box := Node3D.new()
	box.name = "Parcel_" + id
	add_child(box)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.16, 0.36)
	mi.mesh = bm
	mi.material_override = MolVisual.machine_material("Cardboard")
	box.add_child(mi)
	var tape := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.31, 0.165, 0.05)
	tape.mesh = tm
	tape.material_override = MolVisual.machine_material("Yellow")
	box.add_child(tape)
	tape.position = Vector3(0.0, 0.0, 0.13)
	var label := Label3D.new()
	label.text = "%s\nISSUED TO CREW" % str(Upgrades.info(id).name).to_upper()
	label.font = UiTheme.heading()
	label.font_size = 26
	label.pixel_size = 0.001
	label.modulate = UiTheme.ANTHRACITE
	label.outline_size = 0
	box.add_child(label)
	label.position = Vector3(0.152, 0.0, -0.03)
	label.rotation = Vector3(0.0, PI / 2.0, 0.0)
	var to := _hub(HATCH_OUT[slot])
	_parcels[id] = box
	if not animate:
		box.global_position = to
		return
	box.global_position = _hub(HATCH_IN + Vector3(0.0, 0.0, HATCH_OUT[slot].z - HATCH_IN.z))
	box.scale = Vector3.ONE * 0.6
	var tw := box.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(box, "global_position", to, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(box, "scale", Vector3.ONE, 0.5)
	if company and company.appraisal:
		company.appraisal.cue.emit("delivery", to, -1)


# --- Mol-werf -----------------------------------------------------------------------------------

func _build_yard() -> void:
	for id: String in [Upgrades.MOL_HEAD_T2, Upgrades.CARGO]:
		var at := _hub(YARD_HEAD if id == Upgrades.MOL_HEAD_T2 else YARD_CARGO)
		# Een lage bok (een pallet op een stalen frame) met een gele rand.
		var cradle := Node3D.new()
		cradle.name = "Cradle_" + id
		add_child(cradle)
		cradle.global_position = at
		_box(cradle, Vector3(0.0, 0.08, 0.0), Vector3(1.1, 0.16, 1.5), "DarkSteel")
		_box(cradle, Vector3(0.0, 0.17, 0.0), Vector3(1.14, 0.03, 1.54), "Hazard")
		var piece := Node3D.new()
		piece.name = "Piece_" + id
		cradle.add_child(piece)
		var m := model_for(id)
		piece.add_child(m)
		piece.position = Vector3(0.0, 0.19, 0.0)
		if id == Upgrades.MOL_HEAD_T2:
			m.scale = Vector3.ONE * 0.16
			m.rotation = Vector3(PI / 2.0, 0.0, 0.0) # de punt omhoog
			m.position = Vector3(0.0, 0.2, 0.0)
		else:
			m.rotation = Vector3(0.0, 0.0, 0.0)
			m.position = Vector3(0.0, 0.62, 0.0)
		var tag := _tag(at + Vector3(0.62, 1.05, 0.0), Vector3(1, 0, 0), 0.0016)
		var sticker := _sticker("INSTALLED\nON THE MOLE", at + Vector3(0.56, 0.4, 0.0), Vector3(1, 0, 0))
		_yard[id] = [piece, tag, sticker]


# --- Modellen (ook voor de winkel) -------------------------------------------------------------------

## Het ding zelf, zoals je het in de wereld ziet: de boor T2 (het echte model met zijn T2-kleur en
## carbidepunt), de scanner, de helmlamp T2, de boorkop T2 van de Mol (het echte model) en een
## bagagebak van het grotere laadruim. Oorsprong in het midden.
static func model_for(id: String) -> Node3D:
	match id:
		Upgrades.DRILL_T2:
			var d := DrillModel.build(0.0, PickaxeModel.GLOVE, false)
			DrillModel.set_tier(d, true)
			return d
		Upgrades.SCANNER:
			var root := Node3D.new()
			if PickaxeModel.has_part("Scanner"):
				root.add_child(PickaxeModel.part("Scanner", 0.0, PickaxeModel.GLOVE, false))
			return root
		Upgrades.LAMP:
			return lamp_t2()
		Upgrades.MOL_HEAD_T2:
			return mol_head_t2()
		Upgrades.CARGO:
			return cargo_pod()
	return Node3D.new()


## De boorkop T2: de kop uit het model van de Mol, met de materialen van T2 (carbide).
static func mol_head_t2() -> Node3D:
	var src: Node3D = MolVisual.MODEL.instantiate()
	var head := src.find_child("DrillHead", true, false) as Node3D
	var out := Node3D.new()
	if head:
		var copy := head.duplicate() as Node3D
		copy.transform = Transform3D.IDENTITY
		out.add_child(copy)
		MolVisual.apply_head_tier(copy, true)
		# Het midden van de kop op de oorsprong (de kop zit in het model op z −5,6).
		copy.position = Vector3(0.0, 0.0, 6.5)
	src.free()
	return out


## Een bagagebak van het grotere laadruim (op de flank van de Mol): grijsgroen zoals een legerkist
## (zodat hij loskomt van de gele romp), met gele spanbanden, een geel-zwarte strook en een bordje.
## Oorsprong in het midden, lang langs z.
static func cargo_pod() -> Node3D:
	var root := Node3D.new()
	root.name = "CargoPod"
	_box(root, Vector3.ZERO, Vector3(0.42, 1.0, 1.3), "GreyGreen")
	_box(root, Vector3(0.0, 0.52, 0.0), Vector3(0.46, 0.06, 1.34), "Anthracite")
	for z in [-0.42, 0.42]:
		_box(root, Vector3(0.0, 0.0, z), Vector3(0.45, 1.03, 0.07), "Yellow")
	_box(root, Vector3(0.215, -0.32, 0.0), Vector3(0.012, 0.16, 1.2), "Hazard")
	var plate := Label3D.new()
	plate.text = "+80 KG"
	plate.font = UiTheme.heading()
	plate.font_size = 64
	plate.pixel_size = 0.002
	plate.modulate = UiTheme.YELLOW
	plate.outline_size = 0
	root.add_child(plate)
	plate.position = Vector3(0.222, 0.12, 0.0)
	plate.rotation = Vector3(0.0, PI / 2.0, 0.0)
	return root


## De helmlamp T2: een grote ronde lamp met een kap, een gloeiende lens en een beugel.
static func lamp_t2() -> Node3D:
	var root := Node3D.new()
	root.name = "LampT2"
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.075
	cyl.bottom_radius = 0.065
	cyl.height = 0.1
	body.mesh = cyl
	body.material_override = MolVisual.machine_material("Yellow", false, 6.0)
	root.add_child(body)
	body.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	var lens := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 0.06
	lc.bottom_radius = 0.06
	lc.height = 0.012
	lens.mesh = lc
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.92, 0.75)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.9, 0.7)
	lm.emission_energy_multiplier = 3.0
	lens.material_override = lm
	root.add_child(lens)
	lens.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	lens.position = Vector3(0.0, 0.0, -0.055)
	_box(root, Vector3(0.0, -0.075, 0.02), Vector3(0.04, 0.05, 0.06), "Anthracite")
	return root


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = MolVisual.machine_material(mat, false, 2.0)
	parent.add_child(mi)
	mi.position = pos
	return mi


## Een prijskaartje (crème met donkere letters) dat naar `facing` kijkt.
func _tag(at: Vector3, facing: Vector3, px: float) -> Label3D:
	var l := Label3D.new()
	l.font = UiTheme.heading()
	l.font_size = 40
	l.pixel_size = px
	l.modulate = UiTheme.ANTHRACITE
	l.outline_modulate = UiTheme.CREAM
	l.outline_size = 22
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	l.global_position = at
	l.look_at(at - facing, Vector3.UP)
	return l


## Een sticker (geel met donkere letters), zichtbaar als het gekocht is.
func _sticker(text: String, at: Vector3, facing: Vector3) -> Label3D:
	var l := _tag(at, facing, 0.0015)
	l.text = text
	l.outline_modulate = UiTheme.YELLOW
	l.visible = false
	return l
