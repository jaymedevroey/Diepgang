class_name DropCam
extends Camera3D
## Buitenbeeld tijdens de drop en het ophalen (zoals in Helldivers): de camera hangt naast de
## Mol en kijkt naar hem. Bij de drop eerst van onder (de Mol valt uit de baai van De Ekster),
## gaandeweg van boven (de planeet komt eraan); bij het ophalen van opzij met het schip erboven.
## Muis draait rond de Mol. Enkel lokaal; Player zet hem aan en uit (Mol.CINEMATIC_MODES).

const DISTANCE := 20.0

var mol: Mol
var orbit_yaw := 0.7
var _pitch_offset := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	fov = 66.0
	near = 0.2
	far = 3000.0
	top_level = true


func activate(m: Mol) -> void:
	mol = m
	_pitch_offset = 0.0
	make_current()


func look(relative: Vector2, sensitivity: float) -> void:
	orbit_yaw -= relative.x * sensitivity
	_pitch_offset = clampf(_pitch_offset - relative.y * sensitivity, -0.6, 0.6)


func _process(delta: float) -> void:
	if mol == null or mol.body == null or not current:
		return
	var t: TerrainAPI = mol.game.terrain
	var ship: Ekster = mol.game.ship
	var target := mol.body.global_position + Vector3(0, 0.6, 0)
	orbit_yaw += delta * 0.1
	var pitch := 0.15
	if mol.mode == Mol.Mode.DROPPING and ship:
		# Van onder het schip (−) naar boven de Mol (+) naarmate hij valt.
		var fallen := clampf((ship.global_position.y - target.y) / Ekster.ALTITUDE, 0.0, 1.0)
		pitch = lerpf(-0.55, 0.55, smoothstep(0.0, 0.5, fallen))
	elif mol.mode == Mol.Mode.LIFTING:
		pitch = 0.05
	pitch = clampf(pitch + _pitch_offset, -1.2, 1.2)
	var dir := Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, -pitch) * Vector3(0, 0, 1)
	var pos := target + dir * DISTANCE
	if t:
		pos.y = maxf(pos.y, t.surface_height_at(pos.x, pos.z) + 2.5)
	# Schokken: harder bij hoge snelheid en als de stuwraketten branden.
	_shake = clampf(absf(mol.vertical_speed) / 45.0 * 0.5 + mol.thrust * 0.6, 0.0, 1.0)
	var jitter := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 0.12
	global_position = pos + jitter
	look_at(target, Vector3.UP)
