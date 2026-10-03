class_name DropCam
extends Camera3D
## Het heldenshot (keuze van Jayme, docs/research/drop-en-ophalen.md, ontwerp B): één vaste
## buitencamera, geen rondjes en geen kanteling naar de andere kant.
## - Drop: de camera hangt achter de vallende Mol (achter = de staart van de Mol), eerst iets
##   lager en omhoog kijkend (de Mol valt uit het schip, dat boven in beeld krimpt), en kantelt dan
##   rustig mee naar beneden (de grond komt eraan). Een beetje naijlen in de hoogte verkoopt de
##   versnelling. Bij de landing knipt Player naar binnen, in de klap (stof, schok).
## - Ophalen: een vaste plek op de grond naast de landingsplek, die de Mol nakijkt terwijl de
##   grijper hem naar het schip trekt.
## Enkel lokaal; Player zet hem aan en uit (Mol.CINEMATIC_MODES).

const BEHIND := 30.0 # meter achter de Mol
const TILT_TIME := 4.0 # seconden om van omhoog naar omlaag te kantelen
const LIFT_SHOT := 6.0 # seconden van het buitenbeeld bij het ophalen

var mol: Mol
var _t := 0.0
var _height := 0.0 # naijlende hoogte t.o.v. de Mol
var _ground_pos := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 72.0
	near = 0.2
	far = 4000.0
	top_level = true


func activate(m: Mol) -> void:
	mol = m
	_t = 0.0
	_height = -4.0
	# Ophalen: vast punt op de grond, schuin achter de Mol.
	var p := m.body.global_position + Vector3(14.0, 0.0, 26.0)
	if m.game.terrain:
		p.y = m.game.terrain.surface_height_at(p.x, p.z) + 1.7
	_ground_pos = p
	make_current()


## Hoe lang het buitenbeeld duurt bij het ophalen (daarna terug naar binnen).
func lift_shot_over() -> bool:
	return mol != null and mol.mode == Mol.Mode.LIFTING and _t > LIFT_SHOT


func look(_relative: Vector2, _sensitivity: float) -> void:
	pass # vaste camera: de muis doet niets (geen rondjes, zie het onderzoek)


func _process(delta: float) -> void:
	if mol == null or mol.body == null or not current:
		return
	_t += delta
	var m := mol.body.global_position
	if mol.mode == Mol.Mode.LIFTING:
		global_position = _ground_pos
		look_at(m + Vector3(0, 2.0, 0), Vector3.UP)
		return
	# Drop: achter de Mol (langs zijn eigen as), hoogte en kijkdoel kantelen in TILT_TIME.
	var k := smoothstep(0.0, TILT_TIME, _t)
	var back := mol.body.global_basis.z.normalized()
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	var want_h := lerpf(-4.0, 14.0, k)
	_height = lerpf(_height, want_h, minf(1.0, delta * 3.0)) # naijlen
	var pos := m + back * BEHIND + Vector3(0, _height, 0)
	var t: TerrainAPI = mol.game.terrain
	if t:
		pos.y = maxf(pos.y, t.surface_height_at(pos.x, pos.z) + 2.5)
	var target := m + Vector3(0, lerpf(16.0, -4.0, k), 0) - back * lerpf(0.0, 14.0, k)
	# Schok: harder bij hoge snelheid en als de stuwraketten branden (trauma²).
	var trauma := clampf(absf(mol.vertical_speed) / 42.0 * 0.45 + mol.thrust * 0.55, 0.0, 1.0)
	var s := trauma * trauma * 0.35
	global_position = pos + Vector3(_rng.randf_range(-s, s), _rng.randf_range(-s, s), _rng.randf_range(-s, s))
	look_at(target, Vector3.UP)
