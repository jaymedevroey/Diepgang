class_name LandformRoestbol
extends Landform
## Roestbol (docs/research/planeten.md §4.1): de bodem van een oude reuzenkrater met perzikkleurig
## stof. Schuin vóór de landingsplek staat de kraterwand: harde en zachte lagen op hun echte hoogte
## (richels waar een harde laag ligt, puin eronder), geulen die in de rand snijden met een puinwaaier
## aan hun voet, baaien en uitlopers (geen cirkel, geen stadion). Op de bodem kruipen donkere
## basaltduinen met de wind mee en trokken stofduivels donkere krullen door het stof. Opzij ligt de
## dagbouwput van een vorige DIG-concessie, met een boortoren, een pijpleiding tot voorbij de kim,
## meetpalen, een reclamebord en een afgeschreven Mol (RoestbolProps bouwt die).
## Alles hangt enkel af van de seed. setup op de hoofdthread kiest enkel de grote lijnen (wand, wind);
## het zware deel (tabellen per boog, put, duinen, sporen, DIG-spullen) gebeurt bij het eerste gebruik,
## op de werkthread (_ensure). height en tint per hoekpunt: snel, met tabellen in plaats van ruis.

const DUNE_CELL := 96.0
const TRACK_CELL := 48.0
const FAN_CELL := 128.0
const ARC_STEP := 6.0 # m langs de rand per stap in de tabellen
const PIPE_STEP := 12.0
const PIPE_LENGTH := 1600.0
## Duinen, sporen, de put en de DIG-spullen liggen binnen deze afstand van de landingsplek (m).
const NEAR_M := 1250.0

# Krater: midden, straal, gemiddelde breedte van de wand, hoogte van de rand en het plateau erbuiten.
var crater_c := Vector2.ZERO
var crater_r := 1400.0
var wall_w := 100.0
var rim_h := 125.0
var plateau_h := 85.0
var rim_dir := Vector2.UP
var _a0 := 0.0 # hoek (vanuit het kratermidden) van de landingsplek: daar is de boog 0
var _r0 := 1400.0 # straal waarmee de tabellen gemaakt zijn (boog in m = hoek × _r0)
# Tabellen per hoek (_n stappen rond): verschuiving van de rand (baaien en uitlopers), breedte van de
# wand, hoogte van de rand, hoe sterk de richels zijn, hoe hoog het puin, hoeveel lagen je ziet, en
# hoe diep een geul hier snijdt.
var _n := 0
var _off := PackedFloat32Array()
var _w := PackedFloat32Array()
var _rim := PackedFloat32Array()
var _terr := PackedFloat32Array()
var _talus := PackedFloat32Array()
var _apron := PackedFloat32Array()
var _strata := PackedFloat32Array()
var _gully := PackedFloat32Array()
# Harde lagen: bovenkant (m boven de bodem) en welk deel van de laag klif is (de rest is richel).
var _layer_top := PackedFloat32Array()
var _layer_cliff := PackedFloat32Array()
# Puinwaaiers aan de voet van de geulen: x, z, straal, hoogte.
var fans: Array[Vector4] = []
var _fan_grid := {} # Vector2i -> Array[int]

# Mijnput: midden, straal, diepte, aantal terrassen; de rijweg naar beneden; stortbergen ernaast.
var pit_c := Vector2.ZERO
var pit_r := 120.0
var pit_depth := 42.0
var pit_steps := 7
var pit_dir := Vector2.RIGHT
var _ramp_a0 := 0.0 # hoek waar de rijweg boven begint
var _ramp_turn := 1.0 # +1 of −1: draairichting naar beneden
var _spoil_phase := 0.0
var _rig_ang := 0.0 # hoek (vanuit het midden van de put) van de boortoren: daar geen wal
var dumps: Array[Vector4] = [] # x, z, straal, hoogte

# Duinen: x, z, straal, hoogte; de wind blaast langs `wind` (de horens van de sikkel wijzen mee).
var dunes: Array[Vector4] = []
var _dune_grid := {} # Vector2i -> Array[int]
# Sporen van stofduivels: punten (om de 8 m), halve breedte en hoe donker.
var tracks: Array[PackedVector2Array] = []
var _track_w := PackedFloat32Array()
var _track_k := PackedFloat32Array()
var _track_grid := {} # Vector2i -> PackedInt32Array (spoor << 16 | stuk)

# DIG-spullen (2D; de hoogtes komen op de werkthread in compute_props).
var pipe := PackedVector2Array() # de pijpleiding, van de put tot voorbij de kim
var rig_xz := Vector2.ZERO
var rig_yaw := 0.0
var board_xz := Vector2.ZERO
var board_yaw := 0.0
var board_text := ""
var wreck_xz := Vector2.ZERO
var wreck_yaw := 0.0
var stakes := PackedVector2Array()
# Stofduivels: [Vector2 midden van het spoor waar hij nu loopt, richting, hoogte] per duivel.
var devils: Array = []

var _wiggle := FastNoiseLite.new()
var _bay := FastNoiseLite.new()
var _par := FastNoiseLite.new()
var _clump := FastNoiseLite.new()
var _seed := 0
var _built := false
var _a_rim := 0.0
var _rim_dist := 420.0

const BOARD_LINES: Array[String] = [
	"THIS PLANET IS PROPERTY OF DIG.\nSO ARE YOU.",
	"SAFETY IS OUR\n#4 PRIORITY",
	"DAYS WITHOUT INCIDENT:\n0",
	"CLAIM BOUNDARY.\nTRESPASSERS WILL BE HIRED.",
]


func setup(planet_seed: int, landing_xz: Vector2, size: Vector2) -> void:
	super(planet_seed, landing_xz, size)
	_seed = planet_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 2654435761 + 17
	# De wand ligt schuin vóór de landingsplek (−z is waar de dropcamera naar kijkt bij het remmen):
	# links- of rechtsvoor, zodat hij het beeld kadert en de horizon vrij blijft.
	var a_rim := deg_to_rad(-90.0 + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(36.0, 52.0))
	rim_dir = Vector2(cos(a_rim), sin(a_rim))
	_a_rim = a_rim
	_rim_dist = rng.randf_range(400.0, 450.0)
	crater_r = rng.randf_range(1500.0, 1900.0)
	crater_c = landing - rim_dir * (crater_r - _rim_dist)
	_r0 = crater_r
	var rel := landing - crater_c
	_a0 = atan2(rel.y, rel.x)
	rim_h = rng.randf_range(120.0, 150.0)
	plateau_h = rim_h * rng.randf_range(0.62, 0.75)
	wall_w = rng.randf_range(95.0, 120.0)
	# Wind schuin langs de wand: de duinen kruipen over de kraterbodem.
	wind = rim_dir.rotated(deg_to_rad(90.0 + rng.randf_range(-30.0, 30.0)))
	_built = false


## Het zware deel: pas bij het eerste gebruik (height, hills_factor, tint, compute_props), dus op de
## werkthread van PlanetSurface en niet op de hoofdthread. Daarna enkel nog lezen.
func _ensure() -> void:
	if _built:
		return
	_built = true
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 2654435761 + 29
	var planet_seed := _seed
	for n: FastNoiseLite in [_wiggle, _bay, _par, _clump]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wiggle.seed = planet_seed + 311
	_wiggle.frequency = 0.0065
	_wiggle.fractal_octaves = 2
	_bay.seed = planet_seed + 312
	_bay.frequency = 0.0011
	_bay.fractal_octaves = 2
	_par.seed = planet_seed + 313
	_par.frequency = 0.003
	_par.fractal_octaves = 2
	_clump.seed = planet_seed + 314
	_clump.frequency = 0.011
	_clump.fractal_octaves = 2
	_make_layers(rng)
	_make_wall_tables(rng)
	_fit_wall_distance(_rim_dist)
	_make_fans(rng)
	_make_pit(rng, _a_rim)
	_make_sites(rng)
	_make_pipe(rng)
	_make_dunes(rng)
	_make_tracks(rng)


# --- Keuzes uit de seed ----------------------------------------------------------------------------

## Harde lagen op vaste hoogtes (zoals echt gelaagd gesteente): onregelmatig dik, een klif bovenaan
## elke laag en een richel eronder. Waar de rand lager is, zie je er gewoon minder.
func _make_layers(rng: RandomNumberGenerator) -> void:
	_layer_top.clear()
	_layer_cliff.clear()
	var h := rng.randf_range(8.0, 16.0)
	_layer_top.append(0.0)
	_layer_cliff.append(0.5)
	while h < rim_h * 1.3:
		_layer_top.append(h)
		_layer_cliff.append(rng.randf_range(0.3, 0.7))
		h += rng.randf_range(13.0, 32.0)
	_layer_top.append(h)
	_layer_cliff.append(0.5)


## Per stap van 6 m rond de krater: de vorm van de wand (uit ruis, eenmalig), en de geulen.
func _make_wall_tables(rng: RandomNumberGenerator) -> void:
	_n = int(ceil(TAU * _r0 / ARC_STEP))
	# (Packed arrays zijn waarden in GDScript: elk apart vergroten, niet via een lus over een kopie.)
	_off.resize(_n)
	_w.resize(_n)
	_rim.resize(_n)
	_terr.resize(_n)
	_talus.resize(_n)
	_apron.resize(_n)
	_strata.resize(_n)
	_gully.resize(_n)
	for i in _n:
		var arc := (float(i) / _n * TAU - PI) * _r0
		# Baaien en uitlopers (±150 m) en een kleinere golf (±35 m): de rand is geen cirkel.
		_off[i] = _bay.get_noise_1d(arc) * 150.0 + _wiggle.get_noise_1d(arc) * 35.0
		_w[i] = wall_w * (0.72 + 0.6 * _n01(arc, 1))
		_rim[i] = rim_h * (0.78 + 0.4 * _n01(arc, 2))
		_terr[i] = lerpf(0.2, 1.0, smoothstep(0.2, 0.8, _n01(arc, 3)))
		_talus[i] = lerpf(0.12, 0.32, _n01(arc, 4))
		_apron[i] = lerpf(25.0, 70.0, _n01(arc, 5))
		_strata[i] = lerpf(0.25, 0.62, _n01(arc, 6))
		_gully[i] = 0.0
	# Geulen: om de 70–210 m een V-snede (dieper bovenaan, ze kerven de rand).
	var arc := -PI * _r0
	while arc < PI * _r0:
		arc += rng.randf_range(70.0, 210.0)
		var half := rng.randf_range(9.0, 22.0)
		var depth := rng.randf_range(0.25, 0.7)
		var i0 := int(floor((arc - half) / _r0 / TAU * _n + _n * 0.5))
		var i1 := int(ceil((arc + half) / _r0 / TAU * _n + _n * 0.5))
		for i in range(i0, i1 + 1):
			var a := (float(i) / _n * TAU - PI) * _r0
			var v := 1.0 - absf(a - arc) / half
			if v > 0.0:
				var j := posmod(i, _n)
				_gully[j] = maxf(_gully[j], depth * v * v * (3.0 - 2.0 * v))


## Ruis 0..1 per boog, `row` = een eigen spoor (onafhankelijk van de andere).
func _n01(arc: float, row: int) -> float:
	return clampf(_par.get_noise_2d(arc, row * 1733.0) * 0.75 + 0.5, 0.0, 1.0)


## De rand staat op `dist` m van de landingsplek (het dichtste punt, met de baaien erbij), en het puin
## aan de voet blijft ver genoeg van het speelgebied.
func _fit_wall_distance(dist: float) -> void:
	for it in 2:
		var best_rim := INF
		var best_toe := INF
		for k in range(-160, 161):
			var ang := _a0 + k * ARC_STEP / _r0
			var i := _idx(ang)
			var dir := Vector2(cos(ang), sin(ang))
			var r_rim := crater_r - _off[i]
			best_rim = minf(best_rim, (crater_c + dir * r_rim).distance_to(landing))
			best_toe = minf(best_toe, (crater_c + dir * (r_rim - _w[i] - _apron[i])).distance_to(landing))
		var push := maxf(dist - best_rim, 245.0 - best_toe)
		crater_r += push


func _idx(ang: float) -> int:
	return posmod(int(round((wrapf(ang - _a0, -PI, PI) + PI) / TAU * _n)), _n)


## Een puinwaaier aan de voet van elke diepe geul (enkel in het deel van de wand dat je ziet).
func _make_fans(rng: RandomNumberGenerator) -> void:
	fans.clear()
	for i in _n:
		var prev := _gully[posmod(i - 1, _n)]
		var next := _gully[posmod(i + 1, _n)]
		if _gully[i] < 0.22 or _gully[i] < prev or _gully[i] < next:
			continue
		var ang := _a0 + (float(i) / _n * TAU - PI)
		if absf(wrapf(ang - _a0, -PI, PI)) * _r0 > 1700.0:
			continue
		var dir := Vector2(cos(ang), sin(ang))
		var foot := crater_r - _off[i] - _w[i]
		# Het midden ligt in de monding van de geul (in de wand), zodat de top van de kegel er verstopt zit.
		var c := crater_c + dir * (foot + 18.0)
		var r := rng.randf_range(45.0, 90.0) * (0.6 + _gully[i])
		# Nooit tot in het speelgebied (plus de overgang).
		r = minf(r, c.distance_to(landing) - 215.0)
		if r < 20.0:
			continue
		fans.append(Vector4(c.x, c.y, r, r * rng.randf_range(0.2, 0.32)))
	_fan_grid = _grid_of(fans, FAN_CELL, 1.0)


## Open mijnput: opzij (links of rechts van de wand), zodat hij van boven en bij het remmen in beeld
## komt, en nooit tegen de wand.
func _make_pit(rng: RandomNumberGenerator, a_rim: float) -> void:
	pit_r = rng.randf_range(140.0, 165.0)
	pit_depth = rng.randf_range(34.0, 42.0)
	pit_steps = rng.randi_range(4, 5)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for attempt in 2:
		var a_pit := a_rim + side * deg_to_rad(90.0 + rng.randf_range(-15.0, 25.0))
		pit_dir = Vector2(cos(a_pit), sin(a_pit))
		pit_c = landing + pit_dir * (play_size.x * 0.5 + 75.0 + pit_r)
		if crater_d(pit_c) < _foot_at(pit_c) - pit_r * 1.7 - 40.0:
			break
		side = -side
	var to_land := (landing - pit_c).angle()
	_ramp_turn = 1.0 if rng.randf() < 0.5 else -1.0
	_ramp_a0 = to_land + _ramp_turn * deg_to_rad(rng.randf_range(20.0, 50.0))
	_spoil_phase = rng.randf() * TAU
	dumps.clear()
	# Twee stortbergen (vlakke toppen) aan de kant weg van de landingsplek.
	for k in 2:
		var a := (pit_c - landing).angle() + deg_to_rad(rng.randf_range(-70.0, 70.0))
		var r := rng.randf_range(32.0, 50.0)
		var c := pit_c + Vector2(cos(a), sin(a)) * (pit_r * 1.5 + r * 0.8)
		if _in_area(c, r + 80.0) or crater_d(c) > _foot_at(c) - r - 60.0:
			continue
		dumps.append(Vector4(c.x, c.y, r, rng.randf_range(9.0, 15.0)))


## Waar de kleine DIG-dingen staan: de boortoren aan de rand van de put, het bord vlak buiten het
## speelgebied (leesbaar van aan de paaltjes), de afgeschreven Mol opzij, en rijen meetpalen.
func _make_sites(rng: RandomNumberGenerator) -> void:
	var to_land := (landing - pit_c).normalized()
	var rig_dir := to_land.rotated(_ramp_turn * deg_to_rad(rng.randf_range(70.0, 110.0)))
	_rig_ang = rig_dir.angle()
	rig_xz = pit_c + rig_dir * pit_r * 1.06
	rig_yaw = (pit_c - rig_xz).angle()
	# Het bord: achter of opzij (niet aan de kant van de wand of de put), 30–40 m buiten de rand.
	var half := play_size * 0.5
	var away := -(rim_dir + pit_dir).normalized()
	var b_dir := away.rotated(deg_to_rad(rng.randf_range(-35.0, 35.0)))
	var reach := minf(half.x / maxf(absf(b_dir.x), 0.01), half.y / maxf(absf(b_dir.y), 0.01))
	board_xz = landing + b_dir * (reach + rng.randf_range(30.0, 40.0))
	board_yaw = (landing - board_xz).angle()
	board_text = BOARD_LINES[rng.randi() % BOARD_LINES.size()]
	# De Mol: aan de andere kant dan het bord, 190–260 m ver, scheef in het zand.
	var w_dir := b_dir.rotated((1.0 if rng.randf() < 0.5 else -1.0) * deg_to_rad(rng.randf_range(80.0, 110.0)))
	for k in 6:
		wreck_xz = landing + w_dir * rng.randf_range(195.0, 260.0)
		if crater_d(wreck_xz) < _foot_at(wreck_xz) - 90.0 and wreck_xz.distance_to(pit_c) > pit_r * 1.9 and not _in_area(wreck_xz, 45.0):
			break
		w_dir = w_dir.rotated(deg_to_rad(40.0))
	wreck_yaw = rng.randf() * TAU
	# Meetpalen: een rij van de hoek van het speelgebied naar de put (een geplande rijweg), en een
	# rij dwars over de bodem. Een stippellijn van boven.
	stakes.clear()
	var corner := landing + Vector2(signf(pit_dir.x) * half.x, signf(pit_dir.y) * half.y)
	var a := corner + (pit_c - corner).normalized() * 40.0
	var b := pit_c - (pit_c - corner).normalized() * (pit_r * 1.3)
	_stake_line(a, b, 11.0)
	var c0 := landing + away.rotated(deg_to_rad(rng.randf_range(60.0, 100.0))) * rng.randf_range(210.0, 260.0)
	var c_dir := away.rotated(deg_to_rad(rng.randf_range(-20.0, 20.0)))
	_stake_line(c0, c0 + c_dir * rng.randf_range(140.0, 200.0), 12.0)


func _stake_line(a: Vector2, b: Vector2, step: float) -> void:
	var n := int(a.distance_to(b) / step)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(n, 1))
		if _in_area(p, 12.0) or crater_d(p) > _foot_at(p) - 40.0:
			continue
		stakes.append(p)


## De pijpleiding: van de rand van de put, schuin langs het speelgebied (nooit erin), en verder in een
## lichte bocht tot voorbij de kim. De lijn die het oog volgt, niet de rand van het vierkant.
func _make_pipe(rng: RandomNumberGenerator) -> void:
	pipe.clear()
	var to_land := (landing - pit_c).normalized()
	# orthogonal() = 90° met de klok mee: wijst die weg van de wand, dan draaien we die kant op (−).
	var sign_ := -1.0 if to_land.orthogonal().dot(rim_dir) < 0.0 else 1.0
	var p := pit_c + to_land.rotated(sign_ * deg_to_rad(55.0)) * pit_r * 1.08
	var heading := to_land.rotated(sign_ * deg_to_rad(rng.randf_range(34.0, 42.0)))
	var bend := sign_ * deg_to_rad(rng.randf_range(8.0, 16.0)) / 900.0 # rad per m
	var s := 0.0
	while s < PIPE_LENGTH:
		pipe.append(p)
		# Weg van het speelgebied duwen als hij er te dicht bij komt.
		var o := _area_dist(p)
		if o < 70.0:
			var out := (p - landing).normalized()
			var turn := signf(heading.cross(out))
			heading = heading.rotated(turn * deg_to_rad(4.0))
		# Langs de wand afbuigen (niet erop): de leiding volgt dan de voet.
		if crater_d(p) > _toe_at(p) - 90.0:
			var inward := (crater_c - p).normalized()
			heading = heading.rotated(signf(heading.cross(inward)) * deg_to_rad(6.0))
		heading = heading.rotated(bend * PIPE_STEP)
		p += heading * PIPE_STEP
		s += PIPE_STEP


## Duinen: een veld donkere sikkels aan de voet van de wand (tussen de wand en het speelgebied) en
## losse duinen verder op de bodem, ook naast het speelgebied (in het beeld van 300 m).
func _make_dunes(rng: RandomNumberGenerator) -> void:
	dunes.clear()
	var tries := 0
	# Eerst een paar die het speelgebied in kruipen (graafbaar zand in het voxelterrein, near_height),
	# lager dan erbuiten (het oppervlak ligt 15 m onder de bovenkant van het volume). Niet op de
	# landingsplek en niet tegen de Mol aan.
	var want_in := rng.randi_range(3, 5)
	while dunes.size() < want_in and tries < 400:
		tries += 1
		var p := landing + Vector2(rng.randf_range(-0.62, 0.62) * play_size.x, rng.randf_range(-0.62, 0.62) * play_size.y)
		var r := rng.randf_range(20.0, 32.0)
		if p.distance_to(landing) < 60.0 + r:
			continue
		var bad := false
		for d in dunes:
			if p.distance_to(Vector2(d.x, d.y)) < (d.z + r) * 1.1:
				bad = true
				break
		if not bad:
			dunes.append(Vector4(p.x, p.y, r, r * rng.randf_range(0.14, 0.19)))
	tries = 0
	while dunes.size() < 62 and tries < 2000:
		tries += 1
		var p: Vector2
		var r: float
		var kind := rng.randf()
		if kind < 0.3:
			# Vóór de landingsplek (−z): wat je bij het remmen over de neus ziet.
			var ang := -PI * 0.5 + rng.randf_range(-1.2, 1.2)
			p = landing + Vector2(cos(ang), sin(ang)) * rng.randf_range(225.0, 520.0)
			r = rng.randf_range(32.0, 55.0)
		elif kind < 0.55:
			# Het veld onder de wand: langs de voet, 40–220 m ervoor.
			var k := rng.randf_range(-110.0, 110.0)
			var ang := _a0 + k * ARC_STEP / _r0
			var i := _idx(ang)
			var dir := Vector2(cos(ang), sin(ang))
			var toe := crater_r - _off[i] - _w[i] - _apron[i]
			p = crater_c + dir * (toe - rng.randf_range(30.0, 230.0))
			r = rng.randf_range(26.0, 50.0)
		elif kind < 0.8:
			# Dicht bij het speelgebied, in het beeld van de drop.
			var ang := rng.randf() * TAU
			p = landing + Vector2(cos(ang), sin(ang)) * rng.randf_range(210.0, 470.0)
			r = rng.randf_range(28.0, 50.0)
		else:
			var ang := rng.randf() * TAU
			p = landing + Vector2(cos(ang), sin(ang)) * lerpf(400.0, 1100.0, sqrt(rng.randf()))
			r = rng.randf_range(24.0, 60.0)
		if _in_area(p, Landform.FADE_IN.y + r * 0.6):
			continue
		if p.distance_to(pit_c) < pit_r * 1.55 + r:
			continue
		if crater_d(p) > _toe_at(p) - r * 0.6:
			continue
		var bad := false
		for q in [rig_xz, board_xz, wreck_xz]:
			if p.distance_to(q) < r + 25.0:
				bad = true
		for d in dunes:
			if p.distance_to(Vector2(d.x, d.y)) < (d.z + r) * 0.85:
				bad = true
				break
		if bad:
			continue
		dunes.append(Vector4(p.x, p.y, r, r * rng.randf_range(0.16, 0.22)))
	_dune_grid = _grid_of(dunes, DUNE_CELL, 1.7)


## Sporen van stofduivels: lange donkere krullen (het stof is weggeblazen, de donkere grond eronder
## ligt bloot). Ze lopen ongeveer met de wind mee en draaien soms een lus. Enkel op de bodem.
func _make_tracks(rng: RandomNumberGenerator) -> void:
	tracks.clear()
	_track_w.clear()
	_track_k.clear()
	devils.clear()
	var want := rng.randi_range(11, 15)
	var tries := 0
	while tracks.size() < want and tries < 80:
		tries += 1
		var ang := rng.randf() * TAU
		var p := landing + Vector2(cos(ang), sin(ang)) * rng.randf_range(170.0, 620.0)
		var heading := wind.rotated(rng.randf_range(-0.9, 0.9))
		# Begin een eind terug langs de wind, zodat het spoor ook langs het speelgebied loopt.
		p -= heading * rng.randf_range(0.0, 250.0)
		var length := rng.randf_range(260.0, 800.0)
		# Draaien (rad per m), op en neer langs het spoor: soms een flauwe bocht, soms een lus.
		var curl := rng.randf_range(0.003, 0.02) * (1.0 if rng.randf() < 0.5 else -1.0)
		var wave := rng.randf_range(50.0, 140.0)
		var ph := rng.randf() * TAU
		var pts := PackedVector2Array()
		var s := 0.0
		while s < length:
			var ok := p.distance_to(landing) > 45.0 and p.distance_to(pit_c) > pit_r * 1.5 and crater_d(p) < _toe_at(p) - 10.0 and p.distance_to(landing) < NEAR_M - 40.0
			if ok:
				pts.append(p)
			elif pts.size() > 1:
				break
			else:
				pts.clear()
			heading = heading.rotated(curl * 8.0 * sin(s / wave + ph) + rng.randf_range(-0.02, 0.02))
			p += heading * 8.0
			s += 8.0
		if pts.size() < 12:
			continue
		tracks.append(pts)
		_track_w.append(rng.randf_range(6.0, 9.0))
		_track_k.append(rng.randf_range(0.42, 0.58))
	_track_grid.clear()
	for t in tracks.size():
		var pts := tracks[t]
		var w := _track_w[t]
		for s in pts.size() - 1:
			var a := pts[s]
			var b := pts[s + 1]
			for gz in range(int(floor((minf(a.y, b.y) - w) / TRACK_CELL)), int(floor((maxf(a.y, b.y) + w) / TRACK_CELL)) + 1):
				for gx in range(int(floor((minf(a.x, b.x) - w) / TRACK_CELL)), int(floor((maxf(a.x, b.x) + w) / TRACK_CELL)) + 1):
					var key := Vector2i(gx, gz)
					if not _track_grid.has(key):
						_track_grid[key] = PackedInt32Array()
					var arr: PackedInt32Array = _track_grid[key]
					arr.append((t << 16) | s)
					_track_grid[key] = arr
	# Twee stofduivels aan de kop van een spoor: één die je bij het remmen ziet (vóór je), één opzij.
	var order: Array[int] = []
	for t in tracks.size():
		order.append(t)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _devil_score(tracks[a]) > _devil_score(tracks[b]))
	for t in order:
		var pts := tracks[t]
		var head := pts[pts.size() - 1]
		if _devil_score(pts) < -5.0 or (not devils.is_empty() and head.distance_to(devils[0][0]) < 350.0):
			continue
		var dir := (head - pts[pts.size() - 4]).normalized()
		devils.append([head, dir, rng.randf_range(80.0, 130.0)])
		if devils.size() == 2:
			break


## Hoe goed een spoor is voor een stofduivel aan zijn kop: vóór de landingsplek en op 350–700 m, en
## nooit met zijn pad of zijn lange schaduw (een decal) over het speelgebied.
func _devil_score(pts: PackedVector2Array) -> float:
	var head := pts[pts.size() - 1]
	var dir := (head - pts[pts.size() - 4]).normalized()
	var d := head.distance_to(landing)
	var score := -(head - landing).normalized().y + (1.0 if d > 330.0 and d < 750.0 else -2.0)
	var sun: Vector3 = PlanetType.params(PlanetType.Id.ROESTBOL).sun_rotation_deg
	var to_sun := Basis.from_euler(Vector3(deg_to_rad(sun.x), deg_to_rad(sun.y), deg_to_rad(sun.z))).z
	var shadow := Vector2(-to_sun.x, -to_sun.z).normalized()
	for k in 12:
		var p := head - dir * 60.0 + dir * (k * 22.0)
		for t in 6:
			if _in_area(p + shadow * (t * 60.0), 40.0):
				return score - 10.0
	return score


static func _grid_of(items: Array[Vector4], cell: float, reach_k: float) -> Dictionary:
	var grid := {}
	for i in items.size():
		var d := items[i]
		var reach := d.z * reach_k
		for gz in range(int(floor((d.y - reach) / cell)), int(floor((d.y + reach) / cell)) + 1):
			for gx in range(int(floor((d.x - reach) / cell)), int(floor((d.x + reach) / cell)) + 1):
				var key := Vector2i(gx, gz)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(i)
	return grid


## Ligt p in het speelgebied, plus `margin` m?
func _in_area(p: Vector2, margin: float) -> bool:
	var half := play_size * 0.5 + Vector2(margin, margin)
	return absf(p.x - landing.x) < half.x and absf(p.y - landing.y) < half.y


## Afstand (m) tot het speelgebied (0 erbinnen).
func _area_dist(p: Vector2) -> float:
	var half := play_size * 0.5
	var dx := maxf(absf(p.x - landing.x) - half.x, 0.0)
	var dz := maxf(absf(p.y - landing.y) - half.y, 0.0)
	return Vector2(dx, dz).length()


# --- Vorm (werkthread) ---------------------------------------------------------------------------

## Hoogte (m) boven of onder de basis van het verre landschap; `o` = afstand buiten het speelgebied.
func height(x: float, z: float, o: float) -> float:
	var k := Landform.fade_in(o)
	if k <= 0.0:
		return 0.0
	_ensure()
	var p := Vector2(x, z)
	var h := _crater(p)
	# De put en de duinen liggen allemaal binnen NEAR_M van de landingsplek (de grove schijf niet).
	if p.distance_squared_to(landing) < NEAR_M * NEAR_M:
		h += _pit(p) + _dunes(p)
	return k * h


## Rustig op de kraterbodem (duinen en sporen blijven leesbaar), bijna niets in de wand (de lagen
## liggen op hun hoogte), en pas ver achter de rand weer de gewone heuvels (een strakke rand).
## De duinen die het speelgebied in kruipen (de krater en de put liggen er ver genoeg vanaf).
func near_height(x: float, z: float) -> float:
	_ensure()
	return _dunes(Vector2(x, z))


func has_near() -> bool:
	return true


func hills_factor(x: float, z: float) -> float:
	_ensure()
	var rel := Vector2(x, z) - crater_c
	var i := _idx(atan2(rel.y, rel.x))
	var d := rel.length() + _off[i]
	var foot := crater_r - _w[i]
	if d < foot:
		return lerpf(0.28, 0.1, smoothstep(foot - 120.0, foot, d))
	if d < crater_r:
		return 0.1
	return lerpf(0.1, 0.55, smoothstep(crater_r + 100.0, crater_r + 900.0, d))


## Afstand tot het kratermidden, met baaien en uitlopers (de wand is geen cirkel).
func crater_d(p: Vector2) -> float:
	var rel := p - crater_c
	return rel.length() + _off[_idx(atan2(rel.y, rel.x))]


func _angle(p: Vector2) -> float:
	var rel := p - crater_c
	return atan2(rel.y, rel.x)


## crater_d waar de voet van de wand ligt (begin van de klif) en waar het puin begint.
func _foot_at(p: Vector2) -> float:
	return crater_r - _w[_idx(_angle(p))]


func _toe_at(p: Vector2) -> float:
	var i := _idx(_angle(p))
	return crater_r - _w[i] - _apron[i]


## Reuzenkrater: vlakke bodem, puin aan de voet (met waaiers onder de geulen), een wand van harde
## lagen (klif) en zachte lagen (richel), een rand die door de geulen gekerfd wordt, en daarbuiten een
## plateau dat langzaam afloopt.
func _crater(p: Vector2) -> float:
	var rel := p - crater_c
	var r := rel.length()
	var f := (wrapf(atan2(rel.y, rel.x) - _a0, -PI, PI) + PI) / TAU * _n
	var i0 := int(f)
	var t := f - i0
	var i1 := i0 + 1 if i0 + 1 < _n else 0
	var d := r + lerpf(_off[i0], _off[i1], t)
	var w := lerpf(_w[i0], _w[i1], t)
	var foot := crater_r - w
	# Waaiers reiken hooguit ±110 m voor de voet: verder op de bodem is hier niets.
	if d < foot - 130.0:
		return 0.0
	var fan := _fan(p)
	var rim := lerpf(_rim[i0], _rim[i1], t)
	var g := lerpf(_gully[i0], _gully[i1], t)
	if d > crater_r:
		var top := plateau_h + (rim - plateau_h) * exp(-(d - crater_r) / 170.0)
		return top * (1.0 - 0.4 * g * exp(-(d - crater_r) / 35.0))
	var hw := 0.0
	if d > foot:
		var u := (d - foot) / w
		var h0 := rim * u
		var ht := _terrace(h0)
		hw = lerpf(h0, ht, lerpf(_terr[i0], _terr[i1], t))
		# Bovenaan de rand: een rechte kap (de hardste laag), en geulen die er een kerf in snijden.
		hw = lerpf(hw, h0, smoothstep(0.88, 1.0, u))
		hw *= 1.0 - 0.4 * g * smoothstep(0.05, 0.85, u)
	# Puin aan de voet: hol (vlak aan de teen, steil tegen de klif), hoger onder een geul.
	var apron := lerpf(_apron[i0], _apron[i1], t)
	var toe := foot - apron
	var th := rim * lerpf(_talus[i0], _talus[i1], t) * (1.0 + 0.8 * g)
	var tal := th * pow(clampf((d - toe) / (apron + w * 0.35), 0.0, 1.0), 1.5) + fan
	return maxf(hw, tal)


## Gelaagd gesteente: op hoogte h0 (een gladde helling) wordt het een trap van kliffen en richels.
func _terrace(h0: float) -> float:
	var n := _layer_top.size()
	for k in n - 1:
		var lo := _layer_top[k]
		var hi := _layer_top[k + 1]
		if h0 < hi:
			var t := (h0 - lo) / (hi - lo)
			var c := _layer_cliff[k + 1]
			return lo + (hi - lo) * (0.14 * t + 0.86 * smoothstep(1.0 - c, 1.0, t))
	return h0


func _fan(p: Vector2) -> float:
	var ids: Variant = _fan_grid.get(Vector2i(int(floor(p.x / FAN_CELL)), int(floor(p.y / FAN_CELL))))
	if ids == null:
		return 0.0
	var h := 0.0
	for i: int in ids:
		var fc := fans[i]
		var dd := p.distance_to(Vector2(fc.x, fc.y)) / fc.z
		if dd < 1.0:
			h = maxf(h, fc.w * pow(1.0 - dd, 2.0))
	return h


## Open mijnput: terrassen van 5–7 m naar beneden, een rijweg die er schuin doorheen naar de bodem
## loopt, een wal van afval eromheen (met gaten) en twee stortbergen met een vlakke top.
func _pit(p: Vector2) -> float:
	var rel := p - pit_c
	var dn := rel.length() / pit_r
	var h := 0.0
	for dm in dumps:
		var dd := p.distance_to(Vector2(dm.x, dm.y)) / dm.z
		if dd < 1.0:
			h = maxf(h, dm.w * clampf((1.0 - dd) * 2.6, 0.0, 1.0))
	if dn >= 1.55:
		return h
	if dn >= 1.0:
		var b := (dn - 1.0) / 0.55
		var gap := smoothstep(-0.2, 0.4, sin(rel.angle() * 3.0 + _spoil_phase))
		# Een vlakke plek voor de boortoren (geen wal onder zijn poten).
		gap *= smoothstep(0.12, 0.3, absf(wrapf(rel.angle() - _rig_ang, -PI, PI)))
		return maxf(h, 7.0 * sin(b * PI) * (1.0 - b * 0.4) * gap)
	var bottom := 0.3
	var s := clampf((1.0 - dn) / (1.0 - bottom), 0.0, 1.0) * pit_steps
	var level := floorf(s) + smoothstep(0.7, 1.0, s - floorf(s))
	h = -pit_depth * minf(level, float(pit_steps)) / pit_steps
	# Rijweg: een helling van 14 m breed langs de wand, van de rand tot op de bodem (1,3 keer rond).
	var along := wrapf((rel.angle() - _ramp_a0) * _ramp_turn, 0.0, TAU) / (1.3 * PI)
	for lap in 2:
		var q := along + lap * (TAU / (1.3 * PI))
		if q > 1.0:
			break
		var rr := lerpf(0.98, bottom + 0.04, q) * pit_r
		var m := 1.0 - smoothstep(5.0, 8.0, absf(rel.length() - rr))
		if m > 0.0:
			h = lerpf(h, -pit_depth * q, m)
	return h


## Barchans: een heuvel die breder is dan lang, met een uitgeholde glijhelling aan de kant onder de
## wind (de horens wijzen mee). Scherpe kam.
func _dunes(p: Vector2) -> float:
	var ids: Variant = _dune_grid.get(Vector2i(int(floor(p.x / DUNE_CELL)), int(floor(p.y / DUNE_CELL))))
	if ids == null:
		return 0.0
	var h := 0.0
	var side := wind.orthogonal()
	for i: int in ids:
		var d := dunes[i]
		var q := p - Vector2(d.x, d.y)
		var al := q.dot(wind) / d.z
		var ac := q.dot(side) / d.z
		var body := 1.0 - (al * al / 0.72 + ac * ac)
		if body <= 0.0:
			continue
		var ha := (al - 0.5) / 0.75
		var hc := ac / 0.7
		var hollow := 1.0 - (ha * ha + hc * hc)
		h += d.w * pow(clampf(body - maxf(hollow, 0.0) * 1.3, 0.0, 1.0), 0.75)
	return h


func _dune_mask(p: Vector2) -> float:
	var ids: Variant = _dune_grid.get(Vector2i(int(floor(p.x / DUNE_CELL)), int(floor(p.y / DUNE_CELL))))
	if ids == null:
		return 0.0
	var m := 0.0
	var side := wind.orthogonal()
	for i: int in ids:
		var d := dunes[i]
		var q := p - Vector2(d.x, d.y)
		var al := q.dot(wind) / d.z
		var ac := q.dot(side) / d.z
		# Het zand zelf, en een zachte waas van donker zand rond de duin (meer aan de kant van de wind).
		var body := 1.0 - (al * al / 0.72 + ac * ac)
		var ha := (al - 0.5) / 0.72
		var hc := ac / 0.68
		var hollow := 1.0 - (ha * ha + hc * hc)
		var core := clampf((body - maxf(hollow, 0.0) * 1.2) * 7.0, 0.0, 1.0)
		var al2 := (al + 0.3) / 1.5
		var halo := clampf((1.0 - (al2 * al2 + ac * ac / 1.3)) * 1.5, 0.0, 1.0) * 0.2
		m = maxf(m, maxf(core, halo))
	return m


func _track_mask(p: Vector2) -> float:
	var ids: Variant = _track_grid.get(Vector2i(int(floor(p.x / TRACK_CELL)), int(floor(p.y / TRACK_CELL))))
	if ids == null:
		return 0.0
	var m := 0.0
	for code: int in ids:
		var t := code >> 16
		var s := code & 0xFFFF
		var pts := tracks[t]
		var w := _track_w[t]
		var dist := _seg_dist(p, pts[s], pts[s + 1])
		if dist < w:
			m = maxf(m, _track_k[t] * (1.0 - smoothstep(w * 0.3, w, dist)))
	return m


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-4), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Kleur ------------------------------------------------------------------------------------------

## Kleur van het landschap hier: rgb vermenigvuldigt de rotskleur, a = hoeveel lagen (strata) er in de
## wand te zien zijn (de shader tekent ze op hoogte, enkel op steile stukken).
func tint(x: float, z: float) -> Color:
	_ensure()
	var p := Vector2(x, z)
	var rel := p - crater_c
	var f := (wrapf(atan2(rel.y, rel.x) - _a0, -PI, PI) + PI) / TAU * _n
	var i0 := int(f)
	var t := f - i0
	var i1 := i0 + 1 if i0 + 1 < _n else 0
	var d := rel.length() + lerpf(_off[i0], _off[i1], t)
	var w := lerpf(_w[i0], _w[i1], t)
	var foot := crater_r - w
	var toe := foot - lerpf(_apron[i0], _apron[i1], t)
	# Ver weg op de bodem (de grove schijf, in de waas): enkel het stof, zonder vlekken of sporen.
	var far := p.distance_squared_to(landing) > NEAR_M * NEAR_M
	if far and d < toe - 20.0:
		return Color(1.14, 1.05, 0.95, 0.0)
	# Perzikkleurig stof op de bodem, met grote vlekken (lichter en donkerder stof). Ook in het
	# speelgebied (PlanetSurface bakt de tint voor het voxelterrein): geen rand.
	var blot := 0.0 if far else _clump.get_noise_2d(x * 0.3, z * 0.3)
	var c := Color(1.14 + 0.1 * blot, 1.05 + 0.08 * blot, 0.95 + 0.04 * blot)
	var a := 0.0
	if d > toe - 20.0:
		# Puin: grijzer en ruwer; een waaier is vers en lichter.
		var scree := smoothstep(toe - 20.0, toe + 25.0, d) * (1.0 - smoothstep(crater_r - 4.0, crater_r + 10.0, d))
		var fan := clampf(_fan(p) / 6.0, 0.0, 1.0)
		c = c.lerp(Color(1.0, 0.9, 0.84), scree * 0.7)
		c = c.lerp(Color(1.16, 1.02, 0.9), fan * 0.6)
		# De wand: lagen (matig contrast, wisselend langs de rand), donkerder in de geulen.
		var u := clampf((d - foot) / w, 0.0, 1.0)
		var wall := smoothstep(0.02, 0.15, u) * (1.0 - smoothstep(0.96, 1.0, u)) * float(d > foot)
		a = wall * lerpf(_strata[i0], _strata[i1], t)
		c = c.lerp(Color(0.86, 0.76, 0.72), wall * lerpf(_gully[i0], _gully[i1], t) * 0.7)
		# Bovenop de rand en het plateau: lichter, stoffiger.
		var top := smoothstep(crater_r - 8.0, crater_r + 50.0, d)
		c = c.lerp(Color(1.3, 1.16, 1.0), top * 0.8)
	else:
		# Sporen van stofduivels (enkel op de bodem).
		var tk := _track_mask(p)
		c = Color(c.r * (1.0 - tk), c.g * (1.0 - tk * 0.95), c.b * (1.0 - tk * 0.85))
	if far:
		c.a = a
		return c
	# Donker basaltzand in de duinen.
	var dune := _dune_mask(p)
	c = c.lerp(Color(0.22, 0.19, 0.25), dune)
	# De put: grijzer gesteente, een donkere plas slib op de bodem, lichte hopen op de rand.
	var dp := p.distance_to(pit_c) / pit_r
	if dp < 1.6:
		var inside := 1.0 - smoothstep(0.94, 1.0, dp)
		var spoil := smoothstep(1.0, 1.1, dp) * (1.0 - smoothstep(1.3, 1.55, dp))
		c = c.lerp(Color(0.9, 0.84, 0.82), inside)
		# Terrassen: lichte vloeren (stof), donkere wanden (vers gesteente): ringen van boven.
		var st := clampf((1.0 - dp) / 0.7, 0.0, 1.0) * pit_steps
		var fr := st - floorf(st)
		var riser := smoothstep(0.7, 0.78, fr) * (1.0 - smoothstep(0.95, 1.0, fr)) * float(st < pit_steps)
		var shade := lerpf(1.1, 0.74, riser) * inside + (1.0 - inside)
		c = Color(c.r * shade, c.g * shade, c.b * shade)
		c = c.lerp(Color(0.5, 0.45, 0.48), (1.0 - smoothstep(0.12, 0.2, dp)) * 0.8)
		c = c.lerp(Color(1.3, 1.2, 1.08), spoil * 0.8)
		a = maxf(a, inside * 0.45)
	for dm in dumps:
		var dd := p.distance_to(Vector2(dm.x, dm.y)) / dm.z
		if dd < 1.0:
			c = c.lerp(Color(1.25, 1.15, 1.06), (1.0 - smoothstep(0.7, 1.0, dd)) * 0.8)
	c.a = a
	return c


# --- Rotsblokken ------------------------------------------------------------------------------------

## Geen losse rotsen van SurfaceDressing: Roestbol strooit zijn eigen rotsen (RoestbolProps: drie
## vormen, in groepjes, met de juiste kleur), zodat ze bij de wand, de waaiers en de put passen.
func rock_density(_p: Vector2) -> float:
	return 0.0


# --- Eigen dingen -----------------------------------------------------------------------------------

func compute_props(s: PlanetSurface) -> Dictionary:
	_ensure()
	return RoestbolProps.compute(self, s)


func commit_props(root: Node3D, out: Dictionary) -> void:
	RoestbolProps.commit(self, root, out)
