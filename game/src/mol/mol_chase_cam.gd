class_name MolChaseCam
extends Camera3D
## Buitenzicht voor de piloot (toets C): een camera die achter en boven de Mol hangt.
## Muis draait rond de Mol. Rots tussen de Mol en de camera trekt hem naar binnen, zodat hij
## ook in de eigen tunnel werkt (achter de Mol is de tunnel altijd open: daar kwam hij vandaan).
## Schokt mee met de schok van de piloot (CameraFx: rijden, boren, een harde laag, een beving),
## zodat ook het buitenzicht het gewicht van de Mol laat voelen (gevoel-04).

const PIVOT := Vector3(0.0, 2.4, 1.0) # lokaal: net boven het dak, onder het tunnelplafond
const DISTANCE := 15.0
const MIN_DISTANCE := 3.0
const MARGIN := 0.6

var mol: Mol
var orbit_yaw := 0.0 # relatief tot de Mol; 0 = recht erachter
var orbit_pitch := deg_to_rad(-16.0)
var _dist := DISTANCE
var _initialised := false
var _heading := 0.0
var _dir := Vector3.BACK
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	fov = 70.0
	near = 0.1
	far = 400.0
	top_level = true
	_noise.seed = 19
	_noise.frequency = 1.0
	# Zacht vullicht zoals een helmlamp, anders is de Mol in de tunnel een zwarte vlek.
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.65)
	fill.light_energy = 2.2
	fill.omni_range = 30.0
	fill.omni_attenuation = 0.7
	fill.shadow_enabled = false
	add_child(fill)


func look(relative: Vector2, sensitivity: float) -> void:
	orbit_yaw -= relative.x * sensitivity
	orbit_pitch = clampf(orbit_pitch - relative.y * sensitivity, deg_to_rad(-70.0), deg_to_rad(25.0))


func activate() -> void:
	_initialised = false
	make_current()


func _process(delta: float) -> void:
	if mol == null or mol.body == null or not current:
		return
	# Zoals de Mol getekend wordt (fysica-interpolatie), anders trilt hij in beeld boven 60 fps.
	var xf := mol.body.get_global_transform_interpolated()
	var pivot := xf * PIVOT
	# Enkel de koers van de Mol volgen (vertraagd, voelt zwaar), niet zijn helling: anders
	# kantelt het beeld bij het afdalen.
	_heading = mol.yaw if not _initialised else lerp_angle(_heading, mol.yaw, minf(1.0, delta * 3.0))
	var basis := Basis(Vector3.UP, _heading + orbit_yaw) * Basis(Vector3.RIGHT, orbit_pitch)
	var wanted := basis * Vector3(0, 0, 1)
	# In een tunnel is enkel de richting terug langs de tunnel vrij (zo kwam de Mol): schuif
	# daarnaartoe tot er genoeg ruimte is.
	var tunnel := (xf.basis.z * Vector3(1, 1, 1)).normalized()
	var best_dir := wanted
	var best_len := -1.0
	for k in 6:
		var dir := wanted.slerp(tunnel, k / 5.0)
		var free := _free_length(pivot, dir)
		if free > best_len + 0.5:
			best_len = free
			best_dir = dir
		if free >= DISTANCE * 0.7:
			break
	_dir = best_dir if not _initialised else _dir.slerp(best_dir, minf(1.0, delta * 4.0)).normalized()
	var want := minf(DISTANCE, _free_length(pivot, _dir))
	# Meteen naar binnen (nooit door de rots kijken), traag weer naar buiten.
	_dist = want if want < _dist or not _initialised else lerpf(_dist, want, minf(1.0, delta * 2.0))
	_dist = maxf(_dist, MIN_DISTANCE)
	_initialised = true
	var pos := pivot + _dir * _dist
	global_transform = Transform3D(Basis.looking_at(pivot + xf.basis * Vector3(0, -0.6, -4.0) - pos, Vector3.UP), pos)
	# Schok: dezelfde trauma als de piloot (zijn CameraFx), iets trager en iets groter.
	_t += delta
	var me := get_parent() as Player
	var tr: float = me.camera_fx.trauma() if me and me.camera_fx else 0.0
	if tr > 0.001:
		var amp := deg_to_rad(Tuning.get_f("camera", "shake_max_deg", 2.2)) * 1.3 * tr * tr * Tuning.get_f("camera", "screen_shake_scale", 1.0)
		var f := _t * Tuning.get_f("camera", "shake_frequency", 22.0) * 0.8
		rotate_object_local(Vector3.RIGHT, amp * _noise.get_noise_2d(f, 0.0))
		rotate_object_local(Vector3.UP, amp * _noise.get_noise_2d(0.0, f))
		rotate_object_local(Vector3.FORWARD, amp * 0.5 * _noise.get_noise_2d(f, f))


## Vrije afstand vanaf de Mol in een richting, tot de rots (min. een marge).
func _free_length(pivot: Vector3, dir: Vector3) -> float:
	var hit: Dictionary = mol.game.terrain.raycast(pivot, pivot + dir * (DISTANCE + MARGIN))
	if hit.is_empty():
		return DISTANCE
	return pivot.distance_to(hit.position) - MARGIN
