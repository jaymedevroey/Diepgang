class_name LandformKristal
extends Landform
## Kristalmaan (docs/research/planeten.md §4.3), hemel C: een kleine donkere maan in een eeuwig
## gouden uur. Het speelgebied ligt op de bodem van een ondiep bekken; een brede kristalader
## (een opgeworpen rug met een breuk in het midden, vol kristallen) loopt schuin langs de concessie
## tot voorbij de kim; een jonge krater met lichte stralen ligt aan de andere kant; lichte
## zeshoekige korstplaten op de vlaktes, basaltzuilen op de bekkenrand, en een half begraven oud
## DIG-booreiland met een rood licht achter de ader.
## De dropcamera kijkt bij het remmen naar −z, de lage zon staat daar ook (licht van achteren):
## de ader komt links of rechts voor in beeld en loopt naar het midden van de kim, de krater ligt
## aan de andere kant schuin vooraan. Elke schaduw is ±5,7 keer zo lang als het ding hoog is.

const PROP_HIDE_M := 1600.0 # verder dan dit niet meer getekend (de hub hangt 1,7 km hoog)
const SMALL_HIDE_M := 700.0 # kristalgruis
## Zichtafstand per stuk van de ader: de verre stukken blijven langer (silhouetten aan de kim in het
## remshot); vanuit de hub (1,7 km hoog) blijft alles verborgen (gecontroleerd: beelden 081–083).
const PART_HIDE := {"VeinBack": PROP_HIDE_M, "VeinNear": PROP_HIDE_M, "VeinMid": 1900.0, "VeinFar": 2500.0,
		"Field": PROP_HIDE_M}
const LIBRARY_SIZE := 20 # kristalgroepen in de bibliotheek (kopieën in het landschap)
const PLATE_REACH := 620.0 # m van de landingsplek: korstplaten
const RED_LIGHT := Color(1.0, 0.16, 0.08)
const VEIN_T := Vector2(-1000.0, 2800.0) # de ader: van achter de landingsplek tot voorbij de kim
const VEIN_W := 30.0 # halve breedte van de rug
const FISSURE_W := 6.0 # halve breedte van de breuk in het midden
const CRYSTAL_TINTS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.93, 0.9, 1.04), Color(1.04, 0.97, 0.94),
		Color(0.88, 0.86, 1.0), Color(1.0, 0.95, 1.02)]

# De ader: een punt naast de concessie, de richting (vooral −z) en de normaal (van de concessie weg).
var side := -1.0 # -1 = ader links (−x), +1 = rechts
var vein_o := Vector2.ZERO
var vein_dir := Vector2.UP
var vein_n := Vector2.LEFT
var vein_h := 7.0
var _vein_noise := FastNoiseLite.new()
var _meander_phase := Vector2.ZERO
# Het bekken: midden, straal, breedte van de wand en hoogte van de rand.
var basin_c := Vector2.ZERO
var basin_r := 760.0
var basin_w := 190.0
var basin_h := 34.0
var _rim_noise := FastNoiseLite.new()
# De jonge straalkrater: midden, straal, diepte en de stralen (hoek, lengte, breedte).
var crater_c := Vector2.ZERO
var crater_r := 40.0
var crater_depth := 15.0
var rays: Array[Vector3] = []
# Korst en donker gruis (waardegroepen), en de ruis die de stralen onderbreekt.
var _crust_noise := FastNoiseLite.new()
var _gravel_noise := FastNoiseLite.new()
var _ray_noise := FastNoiseLite.new()
# Booreiland: plek, kanteling (as en hoek), en de wal van uitgegraven gruis eromheen.
var rig_xz := Vector2.ZERO
var rig_tilt := Vector3.FORWARD
var rig_tilt_deg := 10.0
var _seed := 0


func setup(planet_seed: int, landing_xz: Vector2, size: Vector2) -> void:
	super(planet_seed, landing_xz, size)
	_seed = planet_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = planet_seed * 2654435761 + 29
	side = -1.0 if rng.randf() < 0.5 else 1.0
	# De ader: langs de voorste hoek aan haar kant, schuin naar het midden van de kim.
	var a := deg_to_rad(rng.randf_range(12.0, 18.0))
	vein_dir = Vector2(-side * sin(a), -cos(a))
	var corner := landing + Vector2(side * play_size.x * 0.5, -play_size.y * 0.5)
	vein_n = Vector2(vein_dir.y, -vein_dir.x)
	if vein_n.dot(corner - landing) < 0.0:
		vein_n = -vein_n
	vein_o = corner + vein_n * rng.randf_range(44.0, 56.0)
	vein_h = rng.randf_range(6.0, 8.5)
	_meander_phase = Vector2(rng.randf() * TAU, rng.randf() * TAU)
	_vein_noise.seed = planet_seed + 411
	_vein_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_vein_noise.frequency = 0.004
	_vein_noise.fractal_octaves = 2
	# Het bekken: de landingsplek ligt uit het midden (naar voren en weg van de ader), zodat de rand
	# vooraan ver weg ligt (een lage rug aan de kim) en dichterbij aan de kant achter de ader.
	basin_r = rng.randf_range(720.0, 820.0)
	basin_w = rng.randf_range(170.0, 210.0)
	basin_h = rng.randf_range(28.0, 40.0)
	basin_c = landing + Vector2(side * rng.randf_range(140.0, 200.0), rng.randf_range(120.0, 200.0))
	_rim_noise.seed = planet_seed + 412
	_rim_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rim_noise.frequency = 0.005
	_rim_noise.fractal_octaves = 3
	# De straalkrater: aan de andere kant, schuin vooraan (in het remshot rechts of links van de zon,
	# van 300 m hoog bovenaan in beeld).
	crater_c = landing + Vector2(-side * rng.randf_range(225.0, 260.0), -rng.randf_range(205.0, 235.0))
	crater_r = rng.randf_range(40.0, 50.0)
	crater_depth = crater_r * rng.randf_range(0.34, 0.4)
	rays.clear()
	var n_rays := rng.randi_range(12, 16)
	for i in n_rays:
		var ang := TAU * (i + rng.randf_range(-0.35, 0.35)) / n_rays
		rays.append(Vector3(ang, crater_r * rng.randf_range(5.0, 9.0), rng.randf_range(0.6, 1.4)))
	_crust_noise.seed = planet_seed + 413
	_crust_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_crust_noise.frequency = 1.0 / 110.0
	_crust_noise.fractal_octaves = 2
	_gravel_noise.seed = planet_seed + 414
	_gravel_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_gravel_noise.frequency = 1.0 / 340.0
	_gravel_noise.fractal_octaves = 2
	_ray_noise.seed = planet_seed + 415
	_ray_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ray_noise.frequency = 1.0 / 45.0
	_ray_noise.fractal_octaves = 2
	# Het booreiland: achter de ader (van de concessie uit gezien), ±250 m vooruit.
	var t_rig := rng.randf_range(95.0, 140.0)
	var u_rig := vein_center(t_rig) + rng.randf_range(62.0, 78.0)
	rig_xz = vein_o + vein_dir * t_rig + vein_n * u_rig
	var ta := rng.randf() * TAU
	rig_tilt = Vector3(cos(ta), 0.0, sin(ta))
	rig_tilt_deg = rng.randf_range(8.0, 13.0)


# --- Vormen ------------------------------------------------------------------------------------

## Afstand (m) buiten het speelgebied (0 erbinnen).
func outside_d(p: Vector2) -> float:
	var half := play_size * 0.5
	var dx := maxf(absf(p.x - landing.x) - half.x, 0.0)
	var dz := maxf(absf(p.y - landing.y) - half.y, 0.0)
	return Vector2(dx, dz).length()


## Waar het midden van de ader ligt (dwars, m) op afstand `t` langs haar: recht naast de concessie,
## verder een trage slinger (geen liniaal).
func vein_center(t: float) -> float:
	var amp := 24.0 * smoothstep(80.0, 520.0, absf(t))
	return amp * (0.7 * sin(t * 0.0042 + _meander_phase.x) + 0.3 * sin(t * 0.0115 + _meander_phase.y))


## Plek langs de ader (t) en dwars (du = afstand tot het midden, + = van de concessie weg).
func vein_coords(p: Vector2) -> Vector2:
	var rel := p - vein_o
	var t := rel.dot(vein_dir)
	return Vector2(t, rel.dot(vein_n) - vein_center(t))


## Hoe sterk de ader hier is (0..1): de uiteinden lopen uit, onderweg golft de dikte.
func vein_strength(t: float) -> float:
	var ends := smoothstep(VEIN_T.x, VEIN_T.x + 350.0, t) * (1.0 - smoothstep(VEIN_T.y - 500.0, VEIN_T.y, t))
	return ends * (0.75 + 0.45 * _vein_noise.get_noise_1d(t))


## Afstand tot het midden van het bekken, met een golvende rand (±45 m). Ver van de wand doet die
## golving niets meer (alles wat ervan afhangt is daar constant): dan de gewone afstand, goedkoper.
func basin_d(p: Vector2) -> float:
	var rel := p - basin_c
	var plain := rel.length()
	if plain < basin_r - basin_w - 180.0 or plain > basin_r + 450.0:
		return plain
	return plain + _rim_noise.get_noise_1d(atan2(rel.y, rel.x) * basin_r) * 45.0


func height(x: float, z: float, o: float) -> float:
	var k := Landform.fade_in(o)
	if k <= 0.0:
		return 0.0
	var p := Vector2(x, z)
	return k * (_basin(p) + _vein(p) + _crater(p) + _rig_mound(p))


## Op de bekkenbodem rustig golvend basalt; op de wand en erbuiten de gewone heuvels.
func hills_factor(x: float, z: float) -> float:
	var d := basin_d(Vector2(x, z))
	return lerpf(0.4, 1.0, smoothstep(basin_r - basin_w - 120.0, basin_r, d))


## Ondiep bekken: vlakke bodem, een wand in twee lage treden (lavastromen), een rand en een
## plateau dat buiten langzaam afloopt.
func _basin(p: Vector2) -> float:
	var d := basin_d(p)
	var inner := basin_r - basin_w
	if d <= inner:
		return 0.0
	if d <= basin_r:
		var t := (d - inner) / basin_w
		var s := t * 2.0
		var stepped := (floorf(s) + smoothstep(0.25, 0.8, s - floorf(s))) / 2.0
		return basin_h * lerpf(smoothstep(0.0, 1.0, t), stepped, 0.55)
	var plateau := basin_h * 0.8
	return plateau + (basin_h - plateau) * exp(-(d - basin_r) / 160.0)


## De ader: een opgeworpen rug (±30 m breed, 6–8,5 m hoog) met een breuk in het midden.
func _vein(p: Vector2) -> float:
	var vc := vein_coords(p)
	var du := absf(vc.y)
	if du >= VEIN_W or vc.x < VEIN_T.x or vc.x > VEIN_T.y:
		return 0.0
	var st := vein_strength(vc.x)
	var q := 1.0 - (du * du) / (VEIN_W * VEIN_W)
	var ridge := vein_h * q * q
	var cleft := 0.0
	if du < FISSURE_W:
		var f := 1.0 - du / FISSURE_W
		cleft = vein_h * 0.55 * f * f * (3.0 - 2.0 * f)
	return st * (ridge - cleft)


## Jonge krater: diepe kom, scherpe rand, een lage deken van uitgeworpen gruis eromheen.
func _crater(p: Vector2) -> float:
	var d := p.distance_to(crater_c) / crater_r
	if d >= 3.0:
		return 0.0
	var h := PlanetGenerator._crater_profile(d) * crater_depth
	if d > 1.0:
		h += crater_depth * 0.09 * (1.0 - smoothstep(1.0, 3.0, d))
	return h


## Het booreiland zakte half weg: een lage hoop gruis rond zijn voet.
func _rig_mound(p: Vector2) -> float:
	var d := p.distance_to(rig_xz)
	if d >= 36.0:
		return 0.0
	var f := 1.0 - d / 36.0
	return 5.0 * f * f * (3.0 - 2.0 * f)


# --- Kleur -------------------------------------------------------------------------------------

## Waar lichte korst op de vlakte ligt (0..1): vlekken van 30–80 m, niet op de ader, de krater of
## de bekkenwand.
func crust_mask(p: Vector2) -> float:
	if p.distance_squared_to(landing) > 1400.0 * 1400.0:
		return 0.0
	var m := smoothstep(0.28, 0.42, _crust_noise.get_noise_2dv(p))
	if m <= 0.0:
		return 0.0
	var vc := vein_coords(p)
	m *= smoothstep(VEIN_W + 4.0, VEIN_W + 22.0, absf(vc.y))
	m *= smoothstep(crater_r * 6.0, crater_r * 8.5, p.distance_to(crater_c))
	m *= 1.0 - smoothstep(basin_r - basin_w - 60.0, basin_r - basin_w + 20.0, basin_d(p))
	m *= smoothstep(26.0, 40.0, p.distance_to(rig_xz))
	return m


## Hoe licht het uitgeworpen gruis van de jonge krater hier ligt (0..1): de kom, een deken rond de
## rand en smalle, onderbroken stralen tot 8 kraterstralen ver.
func ray_mask(p: Vector2) -> float:
	var rel := p - crater_c
	var r := rel.length()
	var reach := crater_r * 9.0
	if r > reach:
		return 0.0
	var rn := r / crater_r
	var m := 1.0 - smoothstep(1.15, 2.3, rn)
	if rn > 0.9:
		var ang := atan2(rel.y, rel.x)
		var feather := 0.78 + 0.22 * _ray_noise.get_noise_2dv(p)
		for ray in rays:
			if r > ray.y:
				continue
			var da := absf(wrapf(ang - ray.x, -PI, PI))
			var across := r * sin(minf(da, PI * 0.5))
			var w := (9.0 + 0.11 * r) * ray.z # breed en pluizig: van 300 m hoog meerdere pixels
			if across > w * 1.6:
				continue
			var along := 1.0 - smoothstep(ray.y * 0.5, ray.y, r)
			var k := (1.0 - smoothstep(w * 0.5, w * 1.6, across)) * along * feather
			m = maxf(m, k * (1.0 - smoothstep(0.0, 1.2, rn - 1.0) * 0.25))
	return clampf(m, 0.0, 1.0)


func tint(x: float, z: float) -> Color:
	var p := Vector2(x, z)
	var o := outside_d(p)
	var c := Color(1.0, 1.0, 1.0, 0.0)
	# Donker gruis in grote vlekken (rust en waardegroepen), iets lichter waar het hoger ligt.
	var dark := smoothstep(0.05, 0.45, _gravel_noise.get_noise_2dv(p))
	c = Color(lerpf(1.0, 0.72, dark), lerpf(1.0, 0.72, dark), lerpf(1.0, 0.78, dark), 0.0)
	# De bekkenwand: lagen van basaltstromen; bovenop licht stof.
	var d := basin_d(p)
	var t := clampf((d - (basin_r - basin_w)) / basin_w, 0.0, 1.0)
	c.a = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.9, 1.0, t)) * 0.8
	var top := smoothstep(basin_r - 20.0, basin_r + 80.0, d)
	c = Color(c.r * lerpf(1.0, 1.18, top), c.g * lerpf(1.0, 1.12, top), c.b * lerpf(1.0, 1.14, top), c.a)
	# De ader: donker gebroken basalt op de flanken, licht kristalzand in de breuk.
	var vc := vein_coords(p)
	var du := absf(vc.y)
	if du < VEIN_W + 10.0 and vc.x > VEIN_T.x and vc.x < VEIN_T.y:
		var st := clampf(vein_strength(vc.x) * 1.4, 0.0, 1.0)
		var flank := (1.0 - smoothstep(VEIN_W - 6.0, VEIN_W + 10.0, du)) * st
		c = Color(c.r * lerpf(1.0, 0.6, flank), c.g * lerpf(1.0, 0.6, flank), c.b * lerpf(1.0, 0.7, flank), c.a)
		var sand := (1.0 - smoothstep(FISSURE_W * 1.2, FISSURE_W * 2.4, du)) * st
		c = Color(lerpf(c.r, 1.6, sand), lerpf(c.g, 1.7, sand), lerpf(c.b, 2.0, sand), c.a)
	# Korst: onder de platen donker (de naden tussen de platen tekenen de zeshoeken), verder dan de
	# platen reiken licht (daar is de vlek enkel nog een kleur).
	var crust := crust_mask(p)
	if crust > 0.0:
		# In het speelgebied (en de strook ernaast zonder platen) ook licht: daar tekent de shader de naden.
		var far_k := maxf(smoothstep(PLATE_REACH - 70.0, PLATE_REACH + 10.0, p.distance_to(landing)), 1.0 - smoothstep(4.0, 9.0, o))
		var cc := Color(0.62, 0.6, 0.66).lerp(Color(1.45, 1.42, 1.6), far_k)
		c = Color(lerpf(c.r, cc.r, crust), lerpf(c.g, cc.g, crust), lerpf(c.b, cc.b, crust), c.a)
	# De jonge krater en zijn stralen: vers, licht gruis (tint tot 2,0: zie Landform.tint) op een
	# donkerder vlakte errond, zodat de stralen ook bij een donkere grond en lage zon lezen.
	var rc := p.distance_to(crater_c) / crater_r
	if rc < 12.0:
		var halo := 1.0 - smoothstep(8.0, 12.0, rc)
		c = Color(c.r * lerpf(1.0, 0.55, halo), c.g * lerpf(1.0, 0.55, halo), c.b * lerpf(1.0, 0.6, halo), c.a)
	var ray := ray_mask(p)
	c = Color(lerpf(c.r, 1.9, ray), lerpf(c.g, 1.95, ray), lerpf(c.b, 2.0, ray), c.a * (1.0 - ray))
	return c


## Binnen het speelgebied: naden van de korst waar ze ligt (dezelfde vlekken als de platen erbuiten).
func crust_seams(x: float, z: float) -> float:
	return crust_mask(Vector2(x, z))


# --- Rotsblokken -------------------------------------------------------------------------------

## Hoekig basalt: matig op de bodem, veel puin onder de bekkenwand, uitgeworpen blokken rond de
## jonge krater, gebroken basalt op de flanken van de ader, bijna niets op de korst.
func rock_density(p: Vector2) -> float:
	var dens := 0.45
	var d := basin_d(p)
	var inner := basin_r - basin_w
	dens += 2.2 * smoothstep(inner - 80.0, inner, d) * (1.0 - smoothstep(inner + 40.0, inner + 90.0, d))
	var rc := p.distance_to(crater_c) / crater_r
	dens += 2.6 * smoothstep(1.0, 1.25, rc) * (1.0 - smoothstep(1.8, 3.0, rc))
	# Uitgeworpen brokken liggen ook in de stralen (licht gekleurd door de tint): textuur in de streep.
	if rc > 2.5:
		dens += 1.6 * ray_mask(p)
	var vc := vein_coords(p)
	if vc.x > VEIN_T.x and vc.x < VEIN_T.y:
		dens += 1.2 * smoothstep(8.0, 14.0, absf(vc.y)) * (1.0 - smoothstep(VEIN_W, VEIN_W + 20.0, absf(vc.y)))
	return dens * (1.0 - 0.85 * crust_mask(p))


func rock_scale(p: Vector2) -> float:
	var d := basin_d(p)
	var inner := basin_r - basin_w
	var talus := smoothstep(inner - 80.0, inner, d) * (1.0 - smoothstep(inner + 40.0, inner + 90.0, d))
	var rc := p.distance_to(crater_c) / crater_r
	var ejecta := smoothstep(1.0, 1.25, rc) * (1.0 - smoothstep(1.8, 3.0, rc))
	return 1.0 + 1.0 * talus + 0.8 * ejecta


# --- Eigen dingen (werkthread) -----------------------------------------------------------------

## Waar een kristalgroep komt: één mesh per stuk (de ader in vier stukken langs haar lengte, en de
## losse kristallen over het bekken), met een eigen zichtafstand. Zo blijft het bij een handvol
## draw calls, en valt een stuk dat buiten beeld ligt als geheel weg.
func _part_for(t: float) -> String:
	if t < -250.0:
		return "VeinBack"
	if t < 700.0:
		return "VeinNear"
	if t < 1600.0:
		return "VeinMid"
	return "VeinFar"


func compute_props(s: PlanetSurface) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var lib := _crystal_library()
	var parts := {} # naam -> KristalMesh
	var gravel: Array[Transform3D] = []
	_vein_crystals(s, lib, parts, gravel)
	_scattered_crystals(s, lib, parts)
	var plates := {"CrustLeft": KristalMesh.new(), "CrustRight": KristalMesh.new()}
	_crust_plates(s, plates)
	var basalt := KristalMesh.new()
	_basalt_columns(s, basalt)
	_crater_rays(s, plates["CrustLeft" if crater_c.x < landing.x else "CrustRight"])
	var rig := _rig_meshes(s)
	for m: KristalMesh in parts.values() + plates.values() + [basalt, rig.rust, rig.paint]:
		m.center_on_self()
	var tris := 0
	for m: KristalMesh in parts.values():
		tris += m.triangle_count()
	var plate_tris := 0
	for m: KristalMesh in plates.values():
		plate_tris += m.triangle_count()
	var gravel_tris: int = gravel.size() * lib[0].triangle_count()
	var rig_tris: int = rig.rust.triangle_count() + rig.paint.triangle_count()
	# Eén regel per wereld: wat het kost (werkthread) en hoeveel driehoeken (budget: docs/research/planeten.md §5).
	print("[kristal] eigen dingen %.0f ms, %d driehoeken: kristallen %d (%d stukken), gruis %d × %d, korst en stralen %d, basalt %d, booreiland %d" % [
			(Time.get_ticks_usec() - t0) / 1000.0, tris + gravel_tris + plate_tris + basalt.triangle_count() + rig_tris,
			tris, parts.size(), gravel.size(), lib[0].triangle_count(), plate_tris, basalt.triangle_count(), rig_tris])
	# Een DIG-bord net buiten de concessie aan de kant van de ader, naar binnen gericht (van op de
	# rand te lezen). Tekst in het spel: Engels.
	var sign_xz := landing + Vector2(side * (play_size.x * 0.5 + 7.0), -play_size.y * 0.5 + 34.0)
	var sign_pos := Vector3(sign_xz.x, s.far_height(sign_xz.x, sign_xz.y), sign_xz.y)
	return {"kristal_parts": parts, "kristal_gravel": gravel, "kristal_gravel_mesh": lib[0], "kristal_plates": plates,
			"kristal_basalt": basalt, "kristal_rig": rig, "kristal_sign": sign_pos}


static func _part(parts: Dictionary, name: String) -> KristalMesh:
	if not parts.has(name):
		parts[name] = KristalMesh.new()
	return parts[name]


## Een bibliotheek van kristalgroepen op eenheidsgrootte (het hoofdkristal is 1 m lang). Elke
## groep in het landschap is een kopie: gedraaid, gekanteld en geschaald (native, dus goedkoop).
## Variant 0 is de kleinste (twee buren): die dient ook als gruis.
func _crystal_library() -> Array[KristalMesh]:
	var lib: Array[KristalMesh] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + 101
	for i in LIBRARY_SIZE:
		var km := KristalMesh.new()
		km.cluster(Vector3.ZERO, Vector3.UP, 1.0, rng, CRYSTAL_TINTS[i % CRYSTAL_TINTS.size()], 2 + i % 5)
		lib.append(km)
	return lib


## Een kopie uit de bibliotheek op de grond: `size` m hoog, gedraaid, licht gekanteld.
func _place(km: KristalMesh, lib: Array[KristalMesh], rng: RandomNumberGenerator, x: float, y: float, z: float,
		size: float, lean := 0.18) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	var tilt_axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
	if tilt_axis.length() > 0.01:
		b = Basis(tilt_axis.normalized(), rng.randf_range(0.0, lean)) * b
	km.add_instance(lib[1 + rng.randi() % (lib.size() - 1)], Transform3D(b.scaled(Vector3.ONE * size), Vector3(x, y - 0.05 * size, z)))


## De ader: een dichte band kristalgroepen (4–15 m) in en naast de breuk, om de 140–240 m een grote
## (12–24 m), één reus (±40 m) waar de ader het midden van het remshot kruist, en klein gruis op de
## flanken. Verder weg minder, maar groter (silhouetten aan de kim).
func _vein_crystals(s: PlanetSurface, lib: Array[KristalMesh], parts: Dictionary, gravel: Array[Transform3D]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + 501
	# De reus: net voor de ader de lijn recht vooruit (x = landing.x) kruist.
	var t_giant := 700.0
	if absf(vein_dir.x) > 1e-4:
		t_giant = (landing.x - vein_o.x) / vein_dir.x
	t_giant = clampf(t_giant * rng.randf_range(0.8, 0.9), 420.0, 1000.0)
	var next_hero := VEIN_T.x + rng.randf_range(60.0, 160.0)
	var giant_done := false
	var t := VEIN_T.x + 20.0
	while t < VEIN_T.y - 40.0:
		var st := vein_strength(t)
		var dense := t > -300.0 and t < 900.0
		var step := (rng.randf_range(5.5, 8.0) if dense else rng.randf_range(12.0, 18.0)) / maxf(st, 0.4)
		t += step
		if st < 0.12:
			continue
		var km := _part(parts, _part_for(t))
		var mid := vein_o + vein_dir * t + vein_n * vein_center(t)
		# Een grote groep of de reus: elk uniek gebouwd, met kleinere buren.
		var big := 0.0
		if not giant_done and t >= t_giant:
			giant_done = true
			big = rng.randf_range(36.0, 44.0)
		elif t >= next_hero:
			next_hero = t + rng.randf_range(140.0, 240.0)
			big = rng.randf_range(12.0, 24.0)
		if big > 0.0 and s.outside(mid.x, mid.y) > 12.0 + big * 0.3:
			var up := Vector3(rng.randf_range(-0.12, 0.12), 1.0, rng.randf_range(-0.12, 0.12))
			km.cluster(Vector3(mid.x, s.far_height(mid.x, mid.y) - 0.4, mid.y), up, big, rng, CRYSTAL_TINTS[0],
					7 if big > 30.0 else rng.randi_range(4, 6))
			for k in rng.randi_range(4, 7):
				var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * big * 0.6
				var q := mid + off
				if s.outside(q.x, q.y) > 10.0:
					_place(km, lib, rng, q.x, s.far_height(q.x, q.y), q.y, big * rng.randf_range(0.2, 0.42), 0.5)
		# De band: groepen in de breuk en net ernaast, het grootst in het midden.
		var n := (2 if dense else 1) + (1 if dense and rng.randf() < st - 0.45 else 0)
		for k in n:
			var du := rng.randf_range(-1.0, 1.0)
			var u := du * (FISSURE_W + 8.0)
			var q := mid + vein_dir * rng.randf_range(-step, step) * 0.5 + vein_n * u
			var size := rng.randf_range(6.5, 14.0) * (0.6 + 0.5 * st) * (1.0 - 0.4 * absf(du))
			if not dense:
				size *= rng.randf_range(1.1, 1.5)
			if s.outside(q.x, q.y) < 8.0 + size * 0.3:
				continue
			_place(km, lib, rng, q.x, s.far_height(q.x, q.y), q.y, size, 0.35)
		# Omgevallen kristallen op de flanken: van boven lange lichte strepen (de band wordt breder).
		if dense and rng.randf() < 0.7:
			var gu := (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(FISSURE_W + 6.0, VEIN_W - 4.0)
			var q := mid + vein_dir * rng.randf_range(-step, step) * 0.5 + vein_n * gu
			if s.outside(q.x, q.y) > 10.0:
				var size := rng.randf_range(3.0, 7.0)
				var b := Basis(Vector3.UP, rng.randf() * TAU)
				var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				if axis.length() > 0.01:
					b = Basis(axis.normalized(), rng.randf_range(1.15, 1.45)) * b
				km.add_instance(lib[1 + rng.randi() % (lib.size() - 1)],
						Transform3D(b.scaled(Vector3.ONE * size), Vector3(q.x, s.far_height(q.x, q.y) + 0.05 * size, q.y)))
		# Gruis op de flanken: klein, dunner naar buiten toe (tot 650 m vooruit).
		if t > -400.0 and t < 650.0:
			for k in int(rng.randi_range(1, 4) * st):
				var gu := rng.randf_range(-1.0, 1.0)
				gu = signf(gu) * (FISSURE_W + 3.0 + pow(absf(gu), 0.8) * (VEIN_W - 2.0))
				var q := mid + vein_dir * rng.randf_range(-step, step) * 0.5 + vein_n * gu
				if s.outside(q.x, q.y) < 5.0:
					continue
				var sc := rng.randf_range(0.5, 2.2)
				var b := Basis(Vector3.UP, rng.randf() * TAU)
				var axis := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0))
				var lean := rng.randf_range(0.0, 0.45)
				if axis.length() > 0.01:
					b = Basis(axis.normalized(), lean) * b
				gravel.append(Transform3D(b.scaled(Vector3.ONE * sc), Vector3(q.x, s.far_height(q.x, q.y) - 0.1 * sc, q.y)))


## Losse kristalgroepjes over het bekken (om de ±70 m een kans), en een krans op de rand van de
## jonge krater ("kleinere kraters met kristallen op de rand").
func _scattered_crystals(s: PlanetSurface, lib: Array[KristalMesh], parts: Dictionary) -> void:
	var km := _part(parts, "Field")
	var cell := 70.0
	var reach := 950.0
	var c0x := int(floor((landing.x - reach) / cell))
	var c1x := int(floor((landing.x + reach) / cell))
	var c0z := int(floor((landing.y - reach) / cell))
	var c1z := int(floor((landing.y + reach) / cell))
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			var rng := s._cell_rng(cx, cz, 31)
			var c := Vector2((cx + rng.randf()) * cell, (cz + rng.randf()) * cell)
			if c.distance_to(landing) > reach or rng.randf() > 0.18:
				continue
			if absf(vein_coords(c).y) < VEIN_W + 10.0 or crust_mask(c) > 0.3:
				continue
			for k in rng.randi_range(1, 2):
				var q := c + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
				var size := rng.randf_range(2.0, 6.5) * (2.0 if k == 0 and rng.randf() < 0.15 else 1.0)
				if s.outside(q.x, q.y) < 8.0 + size * 0.3:
					continue
				_place(km, lib, rng, q.x, s.far_height(q.x, q.y), q.y, size, 0.3)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = _seed * 7919 + 777
	# Middelgrote herkenningspunten aan de kim, in de kwadranten waar de ader niet loopt (achter,
	# opzij aan de kant van de krater): van op de grond heeft elke richting zo een silhouet.
	for az: float in [180.0 + rng2.randf_range(-20.0, 20.0), -side * rng2.randf_range(115.0, 145.0),
			-side * rng2.randf_range(55.0, 75.0)]:
		var dir := Vector2(sin(deg_to_rad(az)), -cos(deg_to_rad(az))) # 0° = recht vooruit (−z)
		var q := landing + dir * rng2.randf_range(300.0, 420.0)
		if absf(vein_coords(q).y) < VEIN_W + 20.0 or q.distance_to(crater_c) < crater_r * 2.5:
			q += dir * 120.0
		var size := rng2.randf_range(14.0, 22.0)
		var g := s.far_height(q.x, q.y)
		km.cluster(Vector3(q.x, g - 0.4, q.y), Vector3(rng2.randf_range(-0.1, 0.1), 1.0, rng2.randf_range(-0.1, 0.1)),
				size, rng2, CRYSTAL_TINTS[rng2.randi() % CRYSTAL_TINTS.size()], 5)
		for k in rng2.randi_range(3, 5):
			var off := Vector2(rng2.randf_range(-1.0, 1.0), rng2.randf_range(-1.0, 1.0)) * size * 0.6
			_place(km, lib, rng2, q.x + off.x, s.far_height(q.x + off.x, q.y + off.y), q.y + off.y,
					size * rng2.randf_range(0.2, 0.4), 0.5)
	for i in rng2.randi_range(10, 15):
		var a := rng2.randf() * TAU
		var q := crater_c + Vector2(cos(a), sin(a)) * crater_r * rng2.randf_range(0.95, 1.15)
		if s.outside(q.x, q.y) < 8.0:
			continue
		_place(km, lib, rng2, q.x, s.far_height(q.x, q.y), q.y, rng2.randf_range(2.0, 5.0), 0.5)


## Lichte zeshoekige korstplaten (±9 m breed) in de korstvlekken, op een vast zeshoekrooster in
## wereldruimte, elk gekanteld naar de grond. Naden van ±1 m tonen het donkere basalt eronder.
func _crust_plates(s: PlanetSurface, plates: Dictionary) -> void:
	var R := 5.0 # straal van een cel van het rooster
	var gap := 0.5
	var dx := 1.5 * R
	var dz := sqrt(3.0) * R
	# Vier varianten (licht tot iets donkerder), eenheidsstraal.
	var unit: Array[KristalMesh] = []
	var flat := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for shade: float in [1.0, 0.94, 0.88, 1.04]:
		var km := KristalMesh.new()
		km.hex_plate(Vector3.ZERO, 1.0, 0.0, flat, 0.3, 0.9, Color(shade, shade * 0.98, shade), Color(0.6, 0.55, 0.66))
		unit.append(km)
	var i0 := int(floor((landing.x - PLATE_REACH) / dx))
	var i1 := int(ceil((landing.x + PLATE_REACH) / dx))
	var j0 := int(floor((landing.y - PLATE_REACH) / dz)) - 1
	var j1 := int(ceil((landing.y + PLATE_REACH) / dz)) + 1
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var c := Vector2(i * dx, (j + (0.5 if i % 2 != 0 else 0.0)) * dz)
			if c.distance_to(landing) > PLATE_REACH:
				continue
			var m := crust_mask(c)
			if m < 0.2:
				continue
			var rng := s._cell_rng(i, j, 41)
			# Rafelige randen: aan de rand van een vlek vallen platen weg.
			if rng.randf() > m * 1.6 - 0.2:
				continue
			if s.outside(c.x, c.y) < R + 3.0:
				continue
			var r := (R - gap) * rng.randf_range(0.86, 1.0)
			var y := s.far_height(c.x, c.y)
			var hx := s.far_height(c.x + r * 0.8, c.y)
			var hz := s.far_height(c.x, c.y + r * 0.8)
			var nrm := Vector3(-(hx - y) / (r * 0.8), 1.0, -(hz - y) / (r * 0.8)).normalized()
			var b := Basis(Quaternion(Vector3.UP, nrm)) * Basis.from_scale(Vector3(r, 1.0, r))
			var km: KristalMesh = plates["CrustLeft" if c.x < landing.x else "CrustRight"]
			km.add_instance(unit[rng.randi() % unit.size()], Transform3D(b, Vector3(c.x, y - 0.05, c.y)))


## De stralen van de jonge krater als dunne, lichte linten over de grond (vers fijn gruis). De tint
## alleen haalt het niet: de grond is donker en een lage zon geeft vlak terrein weinig licht, dus
## een lichter albedo maal weinig licht blijft weinig. Een lint met een eigen licht albedo (dezelfde
## korst) leest wel, ook van 300 m. Onderbroken (ruis) en met rafelige randen, zoals op de maan.
func _crater_rays(s: PlanetSurface, km: KristalMesh) -> void:
	var step := 8.0
	var col := Color(0.97, 0.95, 0.98, 0.0)
	for i in rays.size():
		var ray := rays[i]
		var dir := Vector2(cos(ray.x), sin(ray.x))
		var perp := Vector2(-dir.y, dir.x)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 7919 + 1301 + i
		var prev_l := Vector3.INF
		var prev_r := Vector3.INF
		var r := crater_r * 1.15
		while r < ray.y:
			var c := crater_c + dir * r
			var gap := _ray_noise.get_noise_2dv(c) < -0.35 # onderbroken stralen
			var hw := (9.0 + 0.11 * r) * ray.z * 0.4 * (1.0 - smoothstep(ray.y * 0.45, ray.y, r))
			var pl := c + perp * hw * rng.randf_range(0.75, 1.15)
			var pr := c - perp * hw * rng.randf_range(0.75, 1.15)
			var ok := hw > 0.6 and not gap and s.outside(pl.x, pl.y) > 14.0 and s.outside(pr.x, pr.y) > 14.0
			var vl := Vector3(pl.x, s.far_height(pl.x, pl.y) + 0.25, pl.y) if ok else Vector3.INF
			var vr := Vector3(pr.x, s.far_height(pr.x, pr.y) + 0.25, pr.y) if ok else Vector3.INF
			if vl != Vector3.INF and prev_l != Vector3.INF:
				# Bovenvlak naar boven: de normaal van tri(prev_l, vl, vr) moet omhoog wijzen.
				if (vl - prev_l).cross(vr - prev_l).y > 0.0:
					km.quad(prev_l, vl, vr, prev_r, col, col, col, col)
				else:
					km.quad(prev_l, prev_r, vr, vl, col, col, col, col)
			prev_l = vl
			prev_r = vr
			r += step * rng.randf_range(0.8, 1.2)


## Basaltzuilen: groepjes zeshoekige zuilen (tot 14 m) op de binnenwand van het bekken en een paar
## langs de ader. Ze herhalen de zeshoek van de korst op een andere schaal.
func _basalt_columns(s: PlanetSurface, mesh: KristalMesh) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 7919 + 901
	var unit: Array[KristalMesh] = []
	for shade: float in [1.0, 0.86, 1.12]:
		var km := KristalMesh.new()
		km.column(Vector3.ZERO, 1.0, PI / 6.0, 0.0, 1.0, Color(0.1 * shade, 0.075 * shade, 0.12 * shade), Color(0.22, 0.17, 0.22))
		unit.append(km)
	var spots: Array[Vector3] = [] # x, z, schaal
	var tries := 0
	while spots.size() < 12 and tries < 300:
		tries += 1
		var a := rng.randf() * TAU
		var p := basin_c + Vector2(cos(a), sin(a)) * (basin_r - basin_w * rng.randf_range(0.35, 0.85))
		if p.distance_to(landing) > 1150.0 or s.outside(p.x, p.y) < 40.0:
			continue
		spots.append(Vector3(p.x, p.y, rng.randf_range(0.8, 1.4)))
	for k in 4:
		var t := rng.randf_range(-600.0, 900.0)
		var u := vein_center(t) + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(VEIN_W + 15.0, VEIN_W + 45.0)
		var p := vein_o + vein_dir * t + vein_n * u
		if s.outside(p.x, p.y) < 40.0:
			continue
		spots.append(Vector3(p.x, p.y, rng.randf_range(0.6, 1.0)))
	for spot in spots:
		var center := Vector2(spot.x, spot.y)
		var cr := rng.randf_range(1.3, 2.1)
		var rot := rng.randf() * TAU
		var axis_a := Vector2(cos(rot), sin(rot)) * cr * 1.725
		var axis_b := Vector2(cos(rot + PI / 3.0), sin(rot + PI / 3.0)) * cr * 1.725
		var rings := rng.randi_range(2, 3)
		var peak := rng.randf_range(7.0, 14.0) * spot.z
		for a in range(-rings, rings + 1):
			for b in range(-rings, rings + 1):
				if absi(a + b) > rings:
					continue
				var q := center + axis_a * a + axis_b * b
				var dn := q.distance_to(center) / (cr * 1.725 * (rings + 0.5))
				if dn > 1.0 or rng.randf() < 0.18:
					continue
				var g := s.far_height(q.x, q.y)
				var h := peak * (1.0 - 0.75 * dn) * rng.randf_range(0.7, 1.0) + 1.5
				var basis := Basis(Vector3.UP, -rot) * Basis.from_scale(Vector3(cr * 0.97, h, cr * 0.97))
				mesh.add_instance(unit[rng.randi() % unit.size()], Transform3D(basis, Vector3(q.x, g - 1.5, q.y)))


## Het booreiland (half begraven, schuin): vier poten, schoren, een platform met een cabine, de
## boorpijp en de katrol bovenaan. Twee materialen: roest en verbleekte DIG-verf.
func _rig_meshes(s: PlanetSurface) -> Dictionary:
	var rust := KristalMesh.new()
	var paint := KristalMesh.new()
	var g := s.far_height(rig_xz.x, rig_xz.y)
	var bury := 9.0
	var tilt := Basis(Vector3.UP.cross(rig_tilt).normalized(), deg_to_rad(rig_tilt_deg))
	var o := Vector3(rig_xz.x, g, rig_xz.y)
	var at := func(v: Vector3) -> Vector3: return o + tilt * (v - Vector3(0.0, bury, 0.0))
	var wear := Color(0.35, 0.5, 0.5)
	var h := 40.0
	var foot := 6.0
	var top := 1.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			rust.beam(at.call(Vector3(sx * foot, 0.0, sz * foot)), at.call(Vector3(sx * top, h, sz * top)), 0.55, wear)
	for level: float in [0.14, 0.3, 0.46, 0.62, 0.78]:
		var w: float = lerpf(foot, top, level)
		var y: float = h * level
		var w2: float = lerpf(foot, top, level + 0.16)
		var y2: float = h * (level + 0.16)
		var c := [Vector3(-w, y, -w), Vector3(w, y, -w), Vector3(w, y, w), Vector3(-w, y, w)]
		var c2 := [Vector3(-w2, y2, -w2), Vector3(w2, y2, -w2), Vector3(w2, y2, w2), Vector3(-w2, y2, w2)]
		for i in 4:
			rust.beam(at.call(c[i]), at.call(c[(i + 1) % 4]), 0.3, wear)
			rust.beam(at.call(c[i]), at.call(c2[(i + 1) % 4]), 0.22, wear)
	# Platform net boven het gruis, een cabine in verbleekt DIG-geel, een kist.
	rust.box(at.call(Vector3(0.0, bury + 2.5, 0.0)), tilt, Vector3(6.5, 0.35, 6.5), wear)
	paint.box(at.call(Vector3(3.0, bury + 5.0, 2.6)), tilt, Vector3(2.6, 2.2, 2.0), wear)
	rust.box(at.call(Vector3(-3.2, bury + 4.0, -2.8)), tilt, Vector3(1.8, 1.4, 1.6), wear)
	# Boorpijp en de katrol bovenaan.
	rust.beam(at.call(Vector3(0.0, -2.0, 0.0)), at.call(Vector3(0.0, h - 4.0, 0.0)), 0.7, wear)
	paint.box(at.call(Vector3(0.0, h + 0.6, 0.0)), tilt, Vector3(2.0, 0.6, 2.0), wear)
	# Een giek bovenaan met een afgebroken kabel (van ver een herkenbaar silhouet, geen paal).
	var boom_end := Vector3(-13.0, h - 2.0, 0.0)
	rust.beam(at.call(Vector3(-top, h - 1.0, 0.0)), at.call(boom_end), 0.45, wear)
	rust.beam(at.call(Vector3(-top, h - 7.0, 0.0)), at.call(boom_end + Vector3(2.0, 0.0, 0.0)), 0.25, wear)
	rust.beam(at.call(boom_end), at.call(boom_end + Vector3(0.6, -9.0, 0.3)), 0.12, wear)
	# Het pomphuis ernaast, half weggezakt en de andere kant op gekanteld.
	var side_dir := Vector3(rig_tilt.z, 0.0, -rig_tilt.x)
	var shed_xz := o + side_dir * 12.0 - rig_tilt * 3.0
	var shed_g := s.far_height(shed_xz.x, shed_xz.z)
	var shed_b := Basis(rig_tilt, deg_to_rad(-7.0)) * Basis(Vector3.UP, atan2(side_dir.x, side_dir.z))
	rust.box(Vector3(shed_xz.x, shed_g + 0.6, shed_xz.z), shed_b, Vector3(4.5, 2.8, 3.0), wear)
	paint.box(Vector3(shed_xz.x, shed_g + 3.6, shed_xz.z) + shed_b * Vector3(1.8, 0.0, 0.0), shed_b, Vector3(1.2, 0.5, 1.2), wear)
	# Een afgebroken stuk pijp ligt ernaast in het gruis.
	rust.beam(o - side_dir * 9.0 + Vector3(0.0, 0.4, 0.0), o - side_dir * 9.0 + rig_tilt * 16.0 + Vector3(0.0, 0.9, 0.0), 0.9, wear)
	return {"rust": rust, "paint": paint, "lamp": at.call(Vector3(0.0, h + 1.6, 0.0))}


# --- In de scène (hoofdthread) -----------------------------------------------------------------

func commit_props(root: Node3D, out: Dictionary) -> void:
	var node := Node3D.new()
	node.name = "Kristalmaan"
	root.add_child(node)
	var crystal_mat := ShaderMaterial.new()
	crystal_mat.shader = preload("res://src/world/kristal_crystal.gdshader")
	var plate_mat := ShaderMaterial.new()
	plate_mat.shader = crystal_mat.shader
	plate_mat.set_shader_parameter("body", Color.html("B8A2B6"))
	plate_mat.set_shader_parameter("glow_energy", 0.0)
	plate_mat.set_shader_parameter("transmit", 0.0)
	plate_mat.set_shader_parameter("sheen", 0.3)
	plate_mat.set_shader_parameter("glint", 0.5)
	plate_mat.set_shader_parameter("roughness", 0.5)
	var parts: Dictionary = out.get("kristal_parts", {})
	for name: String in parts:
		# Verder dan ±700 m langs de ader geen schaduw: die vallen buiten de scherpe cascades en
		# kosten in elke schaduwpass toch alle driehoeken.
		var shadows: bool = name != "VeinMid" and name != "VeinFar"
		_add_mesh(node, "Crystals" + name, parts[name], crystal_mat, shadows, PART_HIDE.get(name, PROP_HIDE_M))
	var plates: Dictionary = out.get("kristal_plates", {})
	for name: String in plates:
		_add_mesh(node, name, plates[name], plate_mat, false, PROP_HIDE_M)
	var basalt_mat := StandardMaterial3D.new()
	basalt_mat.vertex_color_use_as_albedo = true
	basalt_mat.roughness = 0.92
	if out.has("kristal_basalt"):
		_add_mesh(node, "BasaltColumns", out.kristal_basalt, basalt_mat, true, PROP_HIDE_M)
	if out.has("kristal_gravel_mesh"):
		_commit_gravel(node, out.get("kristal_gravel", []), out.kristal_gravel_mesh, crystal_mat)
	if out.has("kristal_rig"):
		var rig: Dictionary = out.kristal_rig
		_add_mesh(node, "OldRig", rig.rust, MolVisual.machine_material("RedOxide", false, 3.0), true, PROP_HIDE_M)
		_add_mesh(node, "OldRigPaint", rig.paint, MolVisual.machine_material("Yellow", false, 3.0, 0.0, Color(0.95, 0.55, 0.12), 2.0), true, PROP_HIDE_M)
		var lamp := Node3D.new()
		lamp.name = "OldRigBeacon"
		node.add_child(lamp)
		SurfaceDressing.red_light(lamp, rig.lamp, RED_LIGHT, 3.0, 40.0)
	if out.has("kristal_sign"):
		_commit_sign(node, out.kristal_sign)


## Bord van DIG (geel, op twee palen), schuin naar het speelgebied gedraaid. Van ver verborgen.
func _commit_sign(parent: Node3D, pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "LickSign"
	parent.add_child(root)
	root.global_position = pos
	# Naar het speelgebied kijken (de voorkant van het bord is +z van de node), iets schuin.
	var to_play := Vector3(landing.x - pos.x, 0.0, landing.y - pos.z).normalized()
	root.basis = Basis.looking_at(-to_play.rotated(Vector3.UP, side * 0.35), Vector3.UP)
	var km := KristalMesh.new()
	var post := Color(0.3, 0.5, 0.5)
	km.beam(Vector3(-1.4, -0.6, 0.0), Vector3(-1.4, 2.9, 0.0), 0.14, post)
	km.beam(Vector3(1.4, -0.6, 0.0), Vector3(1.4, 2.9, 0.0), 0.14, post)
	var steel := MolVisual.machine_material("DarkSteel", false, 4.0)
	var board := KristalMesh.new()
	board.box(Vector3(0.0, 2.15, 0.0), Basis(), Vector3(1.75, 0.68, 0.04), post)
	var hazard := KristalMesh.new()
	hazard.box(Vector3(0.0, 1.38, 0.0), Basis(), Vector3(1.75, 0.09, 0.05), post)
	hazard.box(Vector3(0.0, 2.92, 0.0), Basis(), Vector3(1.75, 0.09, 0.05), post)
	for pair in [[km, steel], [board, MolVisual.machine_material("Yellow", false, 4.0)],
			[hazard, MolVisual.machine_material("Hazard", false, 4.0)]]:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (pair[0] as KristalMesh).arrays())
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = pair[1]
		mi.visibility_range_end = 220.0
		root.add_child(mi)
	var label := Label3D.new()
	label.text = "DO NOT LICK\nTHE CRYSTALS\n(AGAIN)"
	label.font_size = 72
	label.outline_size = 0
	label.pixel_size = 0.0042
	label.line_spacing = -6.0
	label.modulate = Color(0.05, 0.045, 0.04)
	label.position = Vector3(0.0, 2.15, 0.05)
	label.visibility_range_end = 220.0
	root.add_child(label)


static func _add_mesh(parent: Node3D, name: String, km: KristalMesh, mat: Material, shadows: bool, hide_m: float) -> void:
	if km == null or km.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, km.arrays())
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = hide_m
	parent.add_child(mi)
	mi.position = km.origin


## Klein kristalgruis langs de ader: één MultiMesh met het kleinste groepje (geen schaduw).
static func _commit_gravel(parent: Node3D, gravel: Array, km: KristalMesh, mat: Material) -> void:
	if gravel.is_empty():
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, km.arrays())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = gravel.size()
	for i in gravel.size():
		mm.set_instance_transform(i, gravel[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "CrystalGravel"
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = SMALL_HIDE_M
	parent.add_child(mmi)
