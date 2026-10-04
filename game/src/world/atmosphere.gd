class_name Atmosphere
extends Node
## Sfeer volgens de diepte van de camera (stijlgids §Licht, docs/research/rots-en-licht.md):
## - elke laag een eigen misttint en omgevingslicht (klei roodbruin, zandsteen goud,
##   graniet blauwgrijs, kristal indigo), vloeiend overgaand;
## - boven de grond de hemel van de planeet (PlanetType) met een laagstaande zon en schaduwen,
##   die uitdooft zodra je onder de grond zit;
## - kleurgrading: hooglichten warm, schaduwen koel (een kleine LUT, in code gemaakt);
## - zwevende stofjes rond de camera, enkel zichtbaar in het licht;
## - de helderheid uit de instellingen;
## - in De Ekster een koeler, binnenlicht; hoog boven de grond minder nevel (de planeet onder je);
## - onder de hub een planeetdek (planet_deck.gdshader): door de open baai zie je de planeet ver
##   onder je, getekend zoals de hemel ze tekent, nooit wat er echt 1,7 km lager ligt.
## Alles lokaal per speler: elke client kijkt naar zijn eigen camera. Na een cameraknip: snap().

# Per laag (0 kristal · 1 graniet · 2 zandsteen · 3 klei): mist, verstrooiing in lichtbundels, omgevingslicht.
const FOG := [Color(0.018, 0.022, 0.05), Color(0.03, 0.034, 0.042), Color(0.055, 0.042, 0.026), Color(0.05, 0.03, 0.022)]
const SCATTER := [Color(0.6, 0.78, 1.0), Color(0.78, 0.8, 0.84), Color(0.95, 0.84, 0.64), Color(0.92, 0.74, 0.6)]
const AMBIENT := [Color(0.22, 0.26, 0.42), Color(0.27, 0.28, 0.31), Color(0.36, 0.3, 0.22), Color(0.36, 0.26, 0.2)]
const SURFACE_FOG := Color(0.035, 0.032, 0.04)
## Kleur van het teruggekaatste licht per laag (de rots kleurt het licht van de helmlamp).
const BOUNCE := [Color(0.3, 0.38, 0.62), Color(0.62, 0.62, 0.64), Color(0.9, 0.7, 0.44), Color(0.82, 0.55, 0.38)]
const BOUNCE_REACH := 16.0
## In De Ekster: omgevingslicht en mist van een hangar (koel, wat blauw).
const SHIP_AMBIENT := Color(0.55, 0.6, 0.72)
const SHIP_FOG := Color(0.03, 0.035, 0.045)

var env: Environment
var terrain: TerrainAPI
var ship: Ekster:
	set(value):
		ship = value
		_place_deck()
var _ship_k := 0.0
var _moon: DirectionalLight3D
var _dust: GPUParticles3D
var _bounce: OmniLight3D
var _bounce_pos := Vector3.ZERO
var _bounce_energy := 0.0
var _fog := Color()
var _scatter := Color()
var _ambient := Color()
var _depth := 0.0
var _ready_once := false
var _planet: Dictionary = {}
var _deck: MeshInstance3D


func setup(environment: Environment, terrain_api: TerrainAPI, planet := PlanetType.Id.ROESTBOL) -> void:
	env = environment
	terrain = terrain_api
	_planet = PlanetType.params(planet)
	env.background_mode = Environment.BG_SKY
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://src/world/planet_sky.gdshader")
	var air := _air_params()
	for k: String in air:
		sky_mat.set_shader_parameter(k, air[k])
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR # geen hemellicht in de grotten
	# De hemel heeft zijn eigen waas: de mist mag er niet nog eens overheen (docs/research/hemel.md).
	env.fog_sky_affect = 0.0
	env.glow_hdr_threshold = 1.2
	if "tonemap_agx_contrast" in env:
		env.set("tonemap_agx_contrast", 1.35)
	env.adjustment_enabled = true
	env.adjustment_color_correction = _grading_lut()
	_apply_brightness()
	Settings.changed.connect(func(key: String) -> void:
		if key == "video/brightness" or key == "video":
			_apply_brightness())

	# De zon van de planeet: laag, warm, met lange schaduwen. Onder de grond dooft hij uit.
	_moon = DirectionalLight3D.new()
	_moon.name = "Sun"
	_moon.light_color = _planet.sun_color
	_moon.light_energy = 0.0
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 140.0
	var rot: Vector3 = _planet.sun_rotation_deg
	_moon.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	add_child(_moon)
	_build_dust()
	# Nep-terugkaatsing (zoals de zaklamp in The Last of Us): een zwak lampje zonder schaduw net
	# vóór waar je naar kijkt, in de kleur van die rots. Geen GI nodig.
	_bounce = OmniLight3D.new()
	_bounce.name = "LampBounce"
	_bounce.shadow_enabled = false
	_bounce.omni_range = 6.0
	_bounce.omni_attenuation = 1.4
	_bounce.light_volumetric_fog_energy = 0.0
	_bounce.light_specular = 0.0
	_bounce.top_level = true
	add_child(_bounce)


## Andere planeet (een nieuwe opdracht): de hemel, de zon en de sfeer van die planeet.
func set_planet(planet: PlanetType.Id) -> void:
	var p := PlanetType.params(planet)
	if env == null or str(p.get("name", "")) == str(_planet.get("name", "")):
		return
	_planet = p
	var air := _air_params()
	var sky_mat := env.sky.sky_material as ShaderMaterial if env.sky else null
	if sky_mat:
		for k: String in air:
			sky_mat.set_shader_parameter(k, air[k])
	_moon.light_color = _planet.sun_color
	var rot: Vector3 = _planet.sun_rotation_deg
	_moon.rotation = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	if _deck:
		var mat := _deck.material_override as ShaderMaterial
		for k: String in air:
			mat.set_shader_parameter(k, air[k])
		mat.set_shader_parameter("sun_dir", _moon.global_basis.z)
	snap()


## Wat de hemel en het planeetdek allebei nodig hebben (planet_air.gdshaderinc): de kleuren van de
## planeet, de hoogte van het oppervlak (de hemel rekent zelf hoe hoog de camera hangt), de straal
## (zelfde kromming als het verre landschap) en het licht waarmee het echte terrein belicht wordt.
func _air_params() -> Dictionary:
	var air: Dictionary = (_planet.sky as Dictionary).duplicate()
	var c := terrain.shaft_center_world()
	air["surface_y"] = terrain.surface_height_at(c.x, c.z)
	air["planet_radius"] = Tuning.get_f("sky", "planet_radius_m", 30000.0)
	air["sun_light"] = _planet.sun_color
	air["sun_energy"] = float(_planet.get("sun_energy", 1.0))
	air["ambient_color"] = _planet.get("ambient", SURFACE_FOG)
	air["ambient_energy"] = float(_planet.get("ambient_energy", 0.3))
	return air


## Planeetdek onder de hub: een vlak van 4 × 4 km, hub_deck_below_m onder de baai. Het tekent per
## pixel de planeet zoals de hemel ze tekent (planet_deck.gdshader), dus het verbergt alles wat
## echt onder de hub ligt (het buitenschip, het voxelterrein van de landingsplek) zonder naad met
## de hemel. Van onder (de drop, de grond) is het onzichtbaar.
func _place_deck() -> void:
	if ship == null or not is_inside_tree() or _planet.is_empty():
		return
	if _deck == null:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/planet_deck.gdshader")
		var air := _air_params()
		for k: String in air:
			mat.set_shader_parameter(k, air[k])
		mat.set_shader_parameter("sun_dir", _moon.global_basis.z)
		var plane := PlaneMesh.new()
		plane.size = Vector2(4000.0, 4000.0)
		_deck = MeshInstance3D.new()
		_deck.name = "PlanetDeck"
		_deck.mesh = plane
		_deck.material_override = mat
		_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_deck.extra_cull_margin = 16384.0 # het vlak tekent ook wat erachter "ligt": nooit wegsnijden
		add_child(_deck)
	_deck.global_position = ship.dock_transform().origin - Vector3(0.0, Tuning.get_f("sky", "hub_deck_below_m", 250.0), 0.0)


## Meteen de doelwaarden (mist, omgevingslicht, de overgang naar het schip) toepassen, zonder de
## zachte overgang van elke frame. Voor een cameraknip (hub -> drop -> binnen in de Mol).
func snap() -> void:
	_update(0.0, true)


func _apply_brightness() -> void:
	if env:
		env.adjustment_brightness = clampf(Settings.get_f("video/brightness"), 0.5, 2.0)


func _process(delta: float) -> void:
	_update(delta, false)


func _update(delta: float, snap_now: bool) -> void:
	# Bij een nieuwe wereld is het oude terrein al weg (of nog niet vrijgegeven, maar uit de boom)
	# tot main het nieuwe zet als het geladen is: dan niets doen (geen straal op het oude terrein).
	if env == null or not is_instance_valid(terrain) or not terrain.is_inside_tree() or not terrain.is_loaded:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	var depth := maxf(0.0, terrain.surface_height_at(p.x, p.z) - p.y)
	var altitude := maxf(0.0, p.y - terrain.surface_height_at(p.x, p.z))
	var in_ship := ship != null and ship.contains(p)
	# Schaduw tot ver weg als je hoog hangt (de drop): anders is het reliëf van boven vlak (de
	# schaduw stopte op 140 m). Aan de grond blijft hij kort en scherp.
	_moon.directional_shadow_max_distance = lerpf(140.0, Tuning.get_f("sky", "drop_shadow_m", 900.0), smoothstep(25.0, 260.0, altitude))
	_ship_k = (1.0 if in_ship else 0.0) if snap_now else move_toward(_ship_k, 1.0 if in_ship else 0.0, delta * 2.0)
	# Laag met een zachte overgang: kijk iets boven en onder je.
	var y := p.y + Strata.boundary_offset(p.x, p.z, terrain.pit_seed)
	var f := _layer_blend(y)
	var fog: Color = _mix4(FOG, f)
	var scatter: Color = _mix4(SCATTER, f)
	var ambient: Color = _mix4(AMBIENT, f)
	# Aan de oppervlakte: de stoffige lucht van de planeet, verder zicht, helder omgevingslicht.
	var surface := 1.0 - smoothstep(2.0, 10.0, depth)
	fog = fog.lerp(_planet.get("fog", SURFACE_FOG), surface).lerp(SHIP_FOG, _ship_k)
	ambient = ambient.lerp(_planet.get("ambient", ambient), surface).lerp(SHIP_AMBIENT, _ship_k)
	var k := 1.0 if snap_now or not _ready_once else minf(1.0, delta * 1.5)
	_ready_once = true
	_fog = _fog.lerp(fog, k)
	_scatter = _scatter.lerp(scatter, k)
	_ambient = _ambient.lerp(ambient, k)
	env.fog_light_color = _fog
	env.volumetric_fog_albedo = _scatter
	env.ambient_light_color = _ambient
	var under := lerpf(0.16, 0.1, smoothstep(5.0, 60.0, depth)) + 0.07 * float(f[0]) # kristal: wat indigo
	var ship_ambient := Tuning.get_f("sky", "ship_ambient_energy", 0.3) # de hub heeft donkere wanden en kleine lampen
	env.ambient_light_energy = lerpf(lerpf(under, float(_planet.get("ambient_energy", 0.3)), surface), ship_ambient, _ship_k)
	env.volumetric_fog_density = lerpf(0.008, 0.022, smoothstep(2.0, 20.0, depth)) * lerpf(1.0, 0.35, surface) * lerpf(1.0, 0.6, _ship_k)
	# Hoog in de lucht (De Ekster, de drop): dunnere nevel, zodat je de planeet onder je ziet. Het
	# verre landschap aan de horizon (4,6 km op 340 m) verdwijnt er toch voor ±90% in.
	var high := Tuning.get_f("sky", "fog_altitude_factor", 0.4)
	env.fog_density = lerpf(0.015, float(_planet.get("fog_density", 0.006)), surface) * lerpf(1.0, high, smoothstep(30.0, 250.0, altitude))
	# Boven de grond neemt de mist de kleur van de hemel in die richting aan (luchtperspectief);
	# onder de grond de kleur van de laag. Gloed: matig in de zon, sterker in het donker (lampen, kristal).
	env.fog_aerial_perspective = 0.85 * surface * (1.0 - _ship_k)
	env.fog_sun_scatter = 0.2 * surface
	env.glow_intensity = lerpf(0.85, 0.45, surface)
	# Het zonlicht dooft uit onder de grond (geen schaduw door 100 m rots heen).
	_moon.light_energy = float(_planet.get("sun_energy", 1.0)) * surface
	_moon.visible = surface > 0.01
	_update_bounce(cam, depth, delta, snap_now)
	# Stofjes volgen de camera.
	_dust.global_position = p
	_dust.emitting = depth > 1.5
	_depth = depth


func _update_bounce(cam: Camera3D, depth: float, delta: float, snap_now := false) -> void:
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var hit := terrain.raycast(from, from + dir * BOUNCE_REACH)
	var want := 0.0
	if not hit.is_empty() and depth > 1.0:
		var d := from.distance_to(hit.position)
		var target: Vector3 = hit.position + (hit.normal as Vector3) * 0.9 - dir * 0.3
		_bounce_pos = target if _bounce_energy < 0.01 else _bounce_pos.lerp(target, minf(1.0, delta * 10.0))
		want = Tuning.get_f("player", "lamp_bounce_energy", 0.35) * (1.0 - smoothstep(3.0, BOUNCE_REACH, d))
		var layer := terrain.layer_at(hit.position)
		_bounce.light_color = (_bounce.light_color as Color).lerp(BOUNCE[layer], minf(1.0, delta * 4.0))
	_bounce_energy = want if snap_now else move_toward(_bounce_energy, want, delta * 2.0)
	_bounce.global_position = _bounce_pos
	_bounce.light_energy = _bounce_energy
	_bounce.visible = _bounce_energy > 0.005


## Gewichten per laag (som 1) met een overgang van ±3 m rond elke grens.
func _layer_blend(y: float) -> Array:
	var w := [0.0, 0.0, 0.0, 0.0]
	var tops: Array[float] = Strata.TOPS_M
	var t0 := smoothstep(tops[0] - 3.0, tops[0] + 3.0, y)
	var t1 := smoothstep(tops[1] - 3.0, tops[1] + 3.0, y)
	var t2 := smoothstep(tops[2] - 3.0, tops[2] + 3.0, y)
	w[0] = 1.0 - t0
	w[1] = t0 - t1
	w[2] = t1 - t2
	w[3] = t2
	return w


func _mix4(cols: Array, w: Array) -> Color:
	var c := Color(0, 0, 0)
	for i in 4:
		c += (cols[i] as Color) * float(w[i])
	return Color(c.r, c.g, c.b, 1.0)


## Kleurgrading als 3D-LUT (16³): schaduwen koeler, hooglichten warmer, iets meer verzadiging.
func _grading_lut() -> ImageTexture3D:
	var n := 16
	var images: Array[Image] = []
	for b in n:
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		for g in n:
			for r in n:
				var c := Vector3(r, g, b) / float(n - 1)
				var l := c.dot(Vector3(0.2126, 0.7152, 0.0722))
				var shadow := Vector3(0.94, 0.98, 1.08)
				var high := Vector3(1.03, 1.0, 0.95)
				var tint := shadow.lerp(high, smoothstep(0.05, 0.55, l))
				var o := c * tint
				# Iets meer verzadiging.
				var lo := o.dot(Vector3(0.2126, 0.7152, 0.0722))
				o = Vector3(lo, lo, lo).lerp(o, 1.1) # wat verzadiging terug (AgX haalt ze al weg)
				img.set_pixel(r, g, Color(clampf(o.x, 0, 1), clampf(o.y, 0, 1), clampf(o.z, 0, 1)))
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, n, n, n, false, images)
	return tex


## Stofjes: kleine, belichte deeltjes in een doos rond de camera. In het donker onzichtbaar,
## in een lichtbundel glinsteren ze (stijlgids: "stof zweeft zichtbaar in elke lichtbundel").
func _build_dust() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "Dust"
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(5, 3, 5)
	m.gravity = Vector3(0, -0.015, 0)
	m.direction = Vector3(0.3, 0.1, 0.2)
	m.spread = 180.0
	m.initial_velocity_min = 0.02
	m.initial_velocity_max = 0.1
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.35
	m.turbulence_noise_scale = 2.5
	m.scale_min = 0.6
	m.scale_max = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 1))
	g.add_point(0.75, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	_dust.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var qm := StandardMaterial3D.new()
	var dot := GradientTexture2D.new() # rond en zacht, geen vierkantjes
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 32
	dot.height = 32
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	qm.albedo_texture = dot
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.95, 0.85, 0.7)
	qm.roughness = 1.0
	q.material = qm
	_dust.draw_pass_1 = q
	_dust.amount = 700
	_dust.lifetime = 9.0
	_dust.preprocess = 9.0
	_dust.local_coords = false
	_dust.visibility_aabb = AABB(Vector3(-7, -5, -7), Vector3(14, 10, 14))
	_dust.top_level = true
	add_child(_dust)
