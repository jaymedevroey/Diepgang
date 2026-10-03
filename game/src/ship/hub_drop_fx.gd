class_name HubDropFx
extends Node3D
## De drop in de hub (De Ekster van binnen), voor wie in de hangar staat én voor wie in de Mol zit:
## - aftellen: een sirene en vier draaiende zwaailichten op de hoeken van de baai; de laatste
##   tellen kleurt de hangar rood (gelijk met het licht in de Mol);
## - de luiken open: tocht en stof dat naar beneden gezogen wordt, warm licht van onder (de planeet);
## - het loslaten: de klemmen op de rand van de baai draaien open (als het model ze heeft);
## - de lichtjes in de schacht (Shaft_Lights, als het model ze heeft) knipperen en lopen.
## Geen spellogica: alles volgt de toestand van de Mol (op elk peer gelijk). In Ekster._ready()
## aangemaakt met één regel.

## Klemmen (contract van art): Clamp_0/1 bakboord voor/achter, Clamp_2/3 stuurboord, elk een eigen
## mesh met de oorsprong op het scharnier (plan y 2,6). Open = draaien om de lokale z-as (langs de
## Mol): −35° aan bakboord, +35° aan stuurboord (de koppen blijven ≥1 m van de vallende Mol), in
## CLAMP_S seconden, net voor het loslaten; weer dicht (0) als de Mol terug in de baai staat.
const CLAMP_AXIS := Vector3.BACK
const CLAMP_OPEN_DEG := [-35.0, -35.0, 35.0, 35.0]
const CLAMP_S := 0.35
## De baai in het plan (layout.py BAY, t.o.v. het midden van de Mol): halve breedte en lengte.
const BAY_HALF := Vector2(4.0, 7.0)

var ship: Ekster
var _center := Vector3.ZERO # midden van de baaivloer (lokaal in de hub)
var _beacons: Array[SpotLight3D] = []
var _wash: OmniLight3D
var _below: SpotLight3D
var _alarm: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
var _dust: GPUParticles3D
var _clamps: Array[Node3D] = []
var _clamp_rest: Array[Basis] = []
var _clamp_deg: Array[float] = []
var _clamp_open := 0.0
var _clamp_want := 0.0
var _shaft_mats: Array[StandardMaterial3D] = []
var _shaft_base := 1.0
var _spin := 0.0
var _since_release := INF
var _doors_was := false
var _gust := 0.0
var _hooked := false


func _init(s: Ekster) -> void:
	ship = s
	name = "HubDropFx"


func _ready() -> void:
	_center = ship.to_local(ship.dock_transform().origin) + Vector3(0.0, Mol.TRACK_BOTTOM, 0.0)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var s := SpotLight3D.new()
			s.light_color = Color(1.0, 0.5, 0.1)
			s.light_energy = 0.0
			s.spot_range = 28.0
			s.spot_angle = 20.0
			s.spot_angle_attenuation = 0.8
			s.shadow_enabled = false
			s.light_volumetric_fog_energy = 2.0
			s.visible = false
			add_child(s)
			s.position = _center + Vector3(sx * (BAY_HALF.x + 0.6), 0.6, sz * (BAY_HALF.y + 0.6))
			_beacons.append(s)
	_wash = OmniLight3D.new()
	_wash.light_color = Color(1.0, 0.1, 0.05)
	_wash.light_energy = 0.0
	_wash.omni_range = 32.0
	_wash.omni_attenuation = 1.2
	_wash.shadow_enabled = false
	_wash.visible = false
	add_child(_wash)
	_wash.position = _center + Vector3(0.0, 6.5, 0.0)
	_below = SpotLight3D.new()
	_below.light_color = Color(1.0, 0.84, 0.62)
	_below.light_energy = 0.0
	_below.spot_range = 22.0
	_below.spot_angle = 50.0
	_below.shadow_enabled = false
	_below.visible = false
	add_child(_below)
	_below.position = _center + Vector3(0.0, -7.5, 0.0)
	_below.rotation = Vector3(PI / 2.0, 0.0, 0.0) # omhoog door de baai
	_alarm = _sound("drop_alarm", _center + Vector3(0.0, 5.0, 0.0), 16.0, 90.0)
	_wind = _sound("drop_wind_bay", _center + Vector3(0.0, -2.0, 0.0), 8.0, 60.0)
	_build_dust()
	for i in 4:
		var c: Node3D = ship.anchors.get("Clamp_%d" % i)
		if c:
			_clamps.append(c)
			_clamp_rest.append(c.basis)
			_clamp_deg.append(CLAMP_OPEN_DEG[i])
	var shaft: MeshInstance3D = ship.anchors.get("Shaft_Lights") as MeshInstance3D
	if shaft and shaft.mesh:
		for i in shaft.mesh.get_surface_count():
			var m := shaft.get_active_material(i) as StandardMaterial3D
			if m:
				var own := m.duplicate() as StandardMaterial3D # niet het gedeelde paletmateriaal
				shaft.set_surface_override_material(i, own)
				_shaft_mats.append(own)
				_shaft_base = own.emission_energy_multiplier


func _sound(sound: String, pos: Vector3, unit: float, max_d: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = DropAudio.stream(sound)
	p.unit_size = unit
	p.max_distance = max_d
	p.volume_db = -80.0
	add_child(p)
	p.position = pos
	return p


func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(BAY_HALF.x + 1.5, 0.3, BAY_HALF.y + 1.5)
	m.direction = Vector3(0, -1, 0)
	m.spread = 25.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 3.0
	m.gravity = Vector3(0, -6.0, 0)
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.color = Color(0.72, 0.66, 0.58, 0.45)
	_dust.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05) # stofjes: de maat zit in het mesh (schaal 0,03 gaf vierkanten van 1 m)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	_dust.draw_pass_1 = q
	_dust.amount = 120
	_dust.lifetime = 1.6
	_dust.emitting = false
	_dust.visibility_aabb = AABB(Vector3(-10, -15, -12), Vector3(20, 20, 24))
	add_child(_dust)
	_dust.position = _center + Vector3(0.0, 0.4, 0.0)


func _process(delta: float) -> void:
	var game: Game = ship.game
	var mol: Mol = game.mol if game else null
	if mol == null or mol.body == null:
		return
	if not _hooked:
		_hooked = true
		mol.drop_event.connect(_on_drop_event)
	var counting := mol.mode == Mol.Mode.DROP_COUNTDOWN
	var red_at := Tuning.get_f("ship", "drop_ramp_close_s", 3.0)
	if mol.mode == Mol.Mode.DROPPING:
		_since_release += delta
	elif counting:
		_since_release = INF
	var hot := counting or mol.mode == Mol.Mode.DROPPING and _since_release < 3.0
	# Sirene tot de laatste tellen, dan stil (de piepjes van de Mol nemen het over).
	var alarm_on := counting and mol.countdown > red_at
	if alarm_on and not _alarm.playing:
		_alarm.play()
	_alarm.volume_db = move_toward(_alarm.volume_db, -7.0 if alarm_on else -80.0, delta * (120.0 if alarm_on else 50.0))
	if _alarm.playing and _alarm.volume_db <= -79.0:
		_alarm.stop()
	# Zwaailichten.
	_spin += delta * TAU * 0.9
	for i in _beacons.size():
		var b := _beacons[i]
		b.visible = hot
		b.light_energy = 14.0 if hot else 0.0
		b.rotation = Vector3(deg_to_rad(-12.0), _spin + i * PI * 0.5, 0.0)
	# Rood licht in de hangar: de laatste tellen en net na het loslaten.
	var red := hot and (not counting or mol.countdown <= red_at)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.3)
	_wash.light_energy = lerpf(_wash.light_energy, (1.5 + 4.0 * pulse) if red else 0.0, minf(1.0, delta * 8.0))
	_wash.visible = _wash.light_energy > 0.02
	# Luiken open: licht van onder, tocht, stof dat de baai in gezogen wordt.
	var doors := ship.door_amount
	if ship.doors_open and not _doors_was:
		_gust = 3.0
	_doors_was = ship.doors_open
	_gust = maxf(0.0, _gust - delta)
	_below.light_energy = 3.5 * doors
	_below.visible = doors > 0.02
	var wind_want := -80.0 if doors < 0.02 else lerpf(-24.0, -9.0, clampf(_gust / 3.0, 0.0, 1.0)) + 6.0 * (doors - 1.0)
	if doors > 0.02 and not _wind.playing:
		_wind.play()
	_wind.volume_db = move_toward(_wind.volume_db, wind_want, delta * 40.0)
	if _wind.playing and _wind.volume_db <= -79.0:
		_wind.stop()
	_dust.emitting = _gust > 0.0 and doors > 0.1
	# Klemmen: gaan open in de laatste CLAMP_S seconden (helemaal open bij het loslaten), weer dicht
	# als de Mol terug in de baai staat.
	if counting and mol.countdown <= CLAMP_S:
		_clamp_want = 1.0
	elif mol.mode == Mol.Mode.DOCKED:
		_clamp_want = 0.0
	_clamp_open = move_toward(_clamp_open, _clamp_want, delta / (CLAMP_S if _clamp_want > 0.5 else 1.5))
	for i in _clamps.size():
		_clamps[i].basis = _clamp_rest[i] * Basis(CLAMP_AXIS, deg_to_rad(_clamp_deg[i]) * smoothstep(0.0, 1.0, _clamp_open))
	# Lichtjes in de schacht: rood knipperen tijdens het aftellen, lopen als de luiken open zijn.
	for m in _shaft_mats:
		var e := _shaft_base
		if counting:
			e = _shaft_base * (0.4 + 1.6 * float(fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25))
		elif hot:
			e = _shaft_base * (1.0 + 2.0 * pulse)
		m.emission_energy_multiplier = e


func _on_drop_event(event: Mol.Event) -> void:
	if event == Mol.Event.RELEASE:
		_clamp_want = 1.0
		_since_release = 0.0
