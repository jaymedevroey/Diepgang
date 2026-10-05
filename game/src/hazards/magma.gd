class_name Magma
extends Node3D
## Magma (GDD §3, §6; onderzoek docs/research/magma-en-onrust.md): een stijgend vlak onder de hele
## concessie, de enige klok van een dienst.
## - Klok: `t_eff` = seconden sinds de start + de voorsprong van de bevingen (elke beving zet de
##   klok `quake_advance_s` vooruit, als een golf). De host bezit de starttijd en de bevingen en
##   stuurt ze door; elke peer rekent de hoogte zelf uit met dezelfde curve (magma.cfg).
## - Curve: eerst stil, dan steeds iets sneller (zie `risen`).
## - Regels (host): spelers die erin zakken, smelten (melt_s lang: het beeld wordt wit-oranje en
##   dan zwart). Een gesmolten robot is kapot (Rescue): je vliegt als spookdrone mee tot de dienst
##   voorbij is, de vervanger wordt aangerekend en wat je droeg is weg (ontwerp-7: smelten is niet
##   langer de snelste weg naar huis). Losse buit is weg, de Mol krijgt alarmen en houdt het even
##   uit (te heet: DIG trekt hem op, maar de lading verschroeit), en op `recall_depth` vertrekt hij
##   vanzelf.
## - Hitte (op elke peer, voor de eigen speler): boven de lava trilt het beeld (shimmer_m), en in de
##   hittezone (heat_m) komt er een rode, kloppende rand, schudt het beeld en volgt een waarschuwing.
##   Smelten is zo geen knip meer (release-audit gevoel-12).
## - Beeld (binnen-06): een raster met reliëf rond de camera (deining, bolle korstplaten, bellen) en
##   het grote vlak eronder, rots die erboven opwarmt (global uniform `magma_height` in
##   terrain.gdshader), een flakkerende lamp onder de camera, gensters en rook dichtbij.

const SHADER := preload("res://src/hazards/magma.gdshader")
const HEAT_SHADER := preload("res://src/hazards/magma_heat.gdshader")
## Het raster met reliëf rond de camera: breedte (m) en aantal vakjes per zijde.
const NEAR_SIZE := 96.0
const NEAR_CELLS := 128
## Eigen beeldlaag: de lamp boven het magma verlicht de rots, niet het magma zelf (dat gloeit al;
## anders kleurde hij de donkere korst oranje).
const VISUAL_LAYER := 1 << 9
const SYNC_INTERVAL := 2.0
const RULES_INTERVAL := 0.25

## Een speler begint te smelten (op elke peer): over melt_s staat zijn vervanger in de Mol.
signal melting(peer_id: int)
## Een speler smolt (op elke peer; voor HUD en tests).
signal melted(peer_id: int)
## Losse buit werd opgeslokt (op elke peer).
signal swallowed(find_id: int)
## Een beving zet het magma zoveel meter hoger (op elke peer; voor HUD en geluid).
signal quake_rise(metres: float)

var game: Node # Game
var running := false
## Seconden sinds de start (host bepaalt, clients lopen mee).
var elapsed := 0.0
## Tijdstippen (in `elapsed`) waarop een beving de klok vooruit zette.
var quakes := PackedFloat32Array()
## Wereld-y van het oppervlak van het magma.
var level := -INF
## Previews en tests: het magma vast op deze diepte onder de landingsplek (negatief = de klok).
var debug_depth := -1.0
## Tempo van de klok (opdracht met meer risico: sneller). De host zet het bij de start.
var speed_factor := 1.0

var _surface_y := 0.0
var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _near: MeshInstance3D
var _near_material: ShaderMaterial
var _smoke: GPUParticles3D
var _screen: ColorRect
var _screen_mat: ShaderMaterial
var _danger_warned := false
var _melt_t := -1.0 # lokaal: seconden sinds het smelten begon (-1 = niet)
var _after_t := -1.0 # lokaal: seconden sinds de vervanger er staat (het beeld gaat weer open)
var _light: OmniLight3D
var _light_k := 0.0
var _embers: GPUParticles3D
var _sync_timer := 0.0
var _rules_timer := 0.0
# Host: regels.
var _in_magma := {} # find_id -> seconden in het magma
var _alarm_level := 0 # hoeveel alarmen al gegeven (opnieuw als de Mol wegrijdt)
var _melting := {} # peer -> seconden aan het smelten
var _mol_heat := 0.0
var _recalled := false


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "Surface"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_mesh.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("far_mode", true)
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = 4.0
	_mesh.layers = VISUAL_LAYER
	add_child(_mesh)
	# Het raster met reliëf rond de camera (volgt hem in stappen van twee vakjes).
	_near = MeshInstance3D.new()
	_near.name = "NearSurface"
	var grid := PlaneMesh.new()
	grid.size = Vector2.ONE * NEAR_SIZE
	grid.subdivide_width = NEAR_CELLS - 1
	grid.subdivide_depth = NEAR_CELLS - 1
	_near.mesh = grid
	_near_material = ShaderMaterial.new()
	_near_material.shader = SHADER
	_near.material_override = _near_material
	_near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_near.extra_cull_margin = 2.0
	_near.top_level = true
	_near.layers = VISUAL_LAYER
	add_child(_near)
	_build_smoke()
	_build_screen()
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Color(1.0, 0.42, 0.12)
	_light.shadow_enabled = false
	_light.omni_attenuation = 1.4
	_light.light_volumetric_fog_energy = 0.0
	_light.light_cull_mask = 0xFFFFF & ~VISUAL_LAYER
	add_child(_light)
	_build_embers()
	visible = false
	RenderingServer.global_shader_parameter_set("magma_height", -10000.0)


## Nieuwe wereld: het vlak over de hele concessie, klok op nul (nog niet gestart).
func attach_terrain(terrain: TerrainAPI) -> void:
	var size := terrain.world_size()
	var c := terrain.shaft_center_world()
	_surface_y = terrain.surface_height_at(c.x, c.z)
	_mesh.scale = Vector3(size.x + 80.0, 1.0, size.z + 80.0)
	_mesh.position = Vector3(size.x * 0.5, 0.0, size.z * 0.5)
	running = false
	elapsed = 0.0
	quakes = PackedFloat32Array()
	_reset_rules()
	_update_level()


# --- De klok -----------------------------------------------------------------------------------

## Meter gestegen na `t` seconden effectieve klok (zonder de voorsprong).
static func risen(t: float) -> float:
	var t0 := Tuning.get_f("magma", "sleep_s", 120.0)
	var t1 := maxf(t0 + 1.0, Tuning.get_f("magma", "ramp_s", 300.0))
	var t2 := maxf(t1 + 1.0, Tuning.get_f("magma", "late_s", 1260.0))
	var v1 := Tuning.get_f("magma", "speed_1", 0.22)
	var v2 := Tuning.get_f("magma", "speed_2", 0.38)
	if t <= t0:
		return 0.0
	if t <= t1:
		return 0.5 * v1 * (t - t0) * (t - t0) / (t1 - t0)
	var h1 := 0.5 * v1 * (t1 - t0)
	if t <= t2:
		var u := t - t1
		return h1 + v1 * u + 0.5 * (v2 - v1) / (t2 - t1) * u * u
	var h2 := h1 + v1 * (t2 - t1) + 0.5 * (v2 - v1) * (t2 - t1)
	return h2 + v2 * (t - t2)


## Diepte onder de landingsplek na `t` seconden effectieve klok.
static func depth_at(t: float) -> float:
	return Tuning.get_f("magma", "start_depth", 310.0) - risen(t)


## Effectieve klok nu: de tijd plus de voorsprong van de bevingen (elk als een golf).
func t_eff() -> float:
	var adv := Tuning.get_f("magma", "quake_advance_s", 40.0)
	var wave := maxf(0.1, Tuning.get_f("magma", "wave_s", 10.0))
	var t := elapsed
	for q in quakes:
		t += adv * clampf((elapsed - q) / wave, 0.0, 1.0)
	return t * speed_factor


## Diepte van het magma onder de landingsplek nu.
func depth() -> float:
	return _surface_y - level


## Stijgsnelheid nu (m/s), zonder golf.
func speed() -> float:
	if not running:
		return 0.0
	var t := t_eff()
	return risen(t + speed_factor) - risen(t)


## Hoe lang (s) tot het magma op hoogte `y` staat, volgens de curve (zonder nieuwe bevingen).
## INF als het niet stijgt of nooit zo hoog komt.
func seconds_until(y: float) -> float:
	if y <= level:
		return 0.0
	if not running:
		return INF
	var need := y - level
	var t := t_eff()
	var base := risen(t)
	# Zoeken in stappen van 5 s, dan fijn: de curve stijgt monotoon.
	var dt := 0.0
	while dt < 3600.0:
		if risen(t + dt + 5.0) - base >= need:
			break
		dt += 5.0
	if dt >= 3600.0:
		return INF
	while risen(t + dt) - base < need:
		dt += 0.25
	return dt / speed_factor


## Host: de klok start (bij de landing van de Mol, of meteen als er geen schip is).
func host_start(factor := 1.0) -> void:
	running = true
	elapsed = 0.0
	speed_factor = factor
	quakes = PackedFloat32Array()
	_reset_rules()
	game.unrest.reset()
	_rpc_clock.rpc(running, elapsed, quakes, speed_factor)


func host_stop() -> void:
	running = false
	_rpc_clock.rpc(running, elapsed, quakes, speed_factor)


## Host: een beving zet de klok vooruit (golf over wave_s). Iedereen ziet hoeveel het magma erdoor
## stijgt (ontwerp-12: wat een beving kost, moet je zien).
func host_quake() -> void:
	var te := t_eff()
	var metres := risen(te + Tuning.get_f("magma", "quake_advance_s", 40.0) * speed_factor) - risen(te)
	quakes.append(elapsed)
	_rpc_clock.rpc(running, elapsed, quakes, speed_factor)
	_rpc_quake_rise.rpc(metres)


@rpc("authority", "call_local", "reliable")
func _rpc_quake_rise(metres: float) -> void:
	quake_rise.emit(metres)
	if game == null or not running:
		return
	if metres >= 0.5:
		game.notice.emit("The quake pushed the magma up %d m." % roundi(metres), "warn")
	else:
		game.notice.emit("The quake woke the magma: it will rise sooner.", "warn")


## Late joiner: de klok zoals die nu staat.
func send_state(peer: int) -> void:
	_rpc_clock.rpc_id(peer, running, elapsed, quakes, speed_factor)


@rpc("authority", "call_remote", "reliable")
func _rpc_clock(run: bool, t: float, q: PackedFloat32Array, factor: float) -> void:
	running = run
	speed_factor = factor
	# Kleine verschillen niet laten verspringen (netwerkvertraging): enkel bijsturen.
	if absf(t - elapsed) > 0.5 or not run:
		elapsed = t
	quakes = q
	_update_level()


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_tick(t: float) -> void:
	if running and absf(t - elapsed) > 0.25:
		elapsed = t


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		if multiplayer.is_server():
			_sync_timer += delta
			if _sync_timer >= SYNC_INTERVAL:
				_sync_timer = 0.0
				_rpc_tick.rpc(elapsed)
	_update_level()
	_update_glow(delta)
	if running and multiplayer.is_server():
		_rules_timer += delta
		if _rules_timer >= RULES_INTERVAL:
			_host_rules(_rules_timer)
			_rules_timer = 0.0


func _update_level() -> void:
	level = minf(_surface_y - (debug_depth if debug_depth >= 0.0 else depth_at(t_eff())), _surface_y - 1.5)
	_mesh.position.y = level
	if _near:
		_near.global_position.y = level
	visible = running or elapsed > 0.0
	RenderingServer.global_shader_parameter_set("magma_height", level if visible else -10000.0)
	RenderingServer.global_shader_parameter_set("magma_heat_m", Tuning.get_f("magma", "rock_heat_m", 12.0))


# --- Beeld ---------------------------------------------------------------------------------------

## Lamp onder de camera: hoe dichter bij het magma, hoe feller de wanden van onderen gloeien. Zit er
## rots tussen de camera en het magma, dan dooft hij uit (anders licht hij plafonds door de rots op).
func _update_glow(delta: float) -> void:
	_update_heat(delta)
	var cam := get_viewport().get_camera_3d()
	if cam == null or not visible:
		_light.visible = false
		_embers.emitting = false
		_smoke.emitting = false
		_near.visible = false
		return
	var p := cam.global_position
	var above := p.y - level
	var reach := Tuning.get_f("magma", "glow_m", 45.0)
	var want := clampf(1.0 - above / reach, 0.0, 1.0)
	if want > 0.0 and game and game.terrain:
		var t: TerrainAPI = game.terrain
		var open := 0
		for o: Vector3 in [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0), Vector3(0, 0, 2.5), Vector3(0, 0, -2.5)]:
			var hit := t.raycast(p + o, Vector3(p.x + o.x, level + 0.5, p.z + o.z))
			if hit.is_empty():
				open += 1
		want *= lerpf(0.25, 1.0, open / 5.0)
	_light_k = lerpf(_light_k, want, minf(1.0, delta * 3.0))
	_light.visible = _light_k > 0.01
	_light.global_position = Vector3(p.x, level + 1.5, p.z)
	_light.omni_range = 16.0 + 24.0 * _light_k
	# Lava flakkert: twee trage golven en een snelle hapering.
	var t := Time.get_ticks_msec() / 1000.0
	var flick := 0.82 + 0.1 * sin(t * 2.3) + 0.06 * sin(t * 7.1 + 1.3) + 0.04 * sin(t * 17.0)
	_light.light_energy = 4.0 * _light_k * _light_k * flick
	_embers.global_position = Vector3(p.x, maxf(level + 2.0, p.y - 4.0), p.z)
	_embers.emitting = above < 30.0 and above > -1.0
	_smoke.global_position = Vector3(p.x, level + 0.6, p.z)
	_smoke.emitting = above < 22.0 and above > -1.0
	# Het raster met reliëf onder de camera (enkel als je niet te hoog hangt).
	var step := NEAR_SIZE / NEAR_CELLS * 2.0
	var snap := Vector2(snappedf(p.x, step), snappedf(p.z, step))
	_near.visible = above < 70.0
	_near.global_position = Vector3(snap.x, level, snap.y)
	var rect := Vector4(snap.x, snap.y, NEAR_SIZE * 0.5, 14.0) if _near.visible else Vector4.ZERO
	_material.set_shader_parameter("near_rect", rect)
	_near_material.set_shader_parameter("near_rect", rect)


## Hitte op het scherm van de eigen speler: trillende lucht boven de lava, de rode rand in de
## hittezone, en het smelten zelf.
func _update_heat(delta: float) -> void:
	var p: Player = game.local_player if game else null
	var cam := get_viewport().get_camera_3d()
	var shimmer := 0.0
	var danger := 0.0
	if p and cam and visible and not p.seated and p.life != Rescue.Life.BROKEN:
		var shimmer_m := Tuning.get_f("magma", "shimmer_m", 14.0)
		var heat_m := Tuning.get_f("magma", "heat_m", 3.0)
		shimmer = 1.0 - smoothstep(0.0, shimmer_m, cam.global_position.y - level)
		var feet := p.global_position.y - level
		danger = 1.0 - smoothstep(0.0, heat_m, feet)
		if feet < -2.0:
			danger = 0.0 # onder het magma (door de rots heen): niet hier
		if danger > 0.0 and _melt_t < 0.0:
			p.camera_fx.hold_trauma(0.18 + 0.3 * danger)
			if not _danger_warned:
				_danger_warned = true
				game.notice.emit("Too hot! Get away from the magma before your robot melts.", "alarm")
		elif danger <= 0.0 and feet > heat_m + 2.0:
			_danger_warned = false
	var melt := 0.0
	var black := 0.0
	if _melt_t >= 0.0:
		_melt_t += delta
		var ms := Tuning.get_f("magma", "melt_s", 1.5)
		melt = smoothstep(0.0, ms * 0.45, _melt_t)
		black = smoothstep(ms * 0.45, ms, _melt_t)
		if _melt_t > ms + 3.0:
			_melt_t = -1.0 # geen vervanger gekomen (verbinding weg): niet zwart blijven
	elif _after_t >= 0.0:
		_after_t += delta
		black = 1.0 - smoothstep(0.15, 0.9, _after_t)
		if _after_t > 0.9:
			_after_t = -1.0
	var shimmer_k := shimmer * 0.6
	_screen.visible = shimmer_k > 0.02 or danger > 0.0 or melt > 0.0 or black > 0.0
	if _screen.visible:
		_screen_mat.set_shader_parameter("shimmer", shimmer_k)
		_screen_mat.set_shader_parameter("danger", danger)
		_screen_mat.set_shader_parameter("melt", melt * (1.0 - black))
		_screen_mat.set_shader_parameter("black", black)


func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HeatScreen"
	layer.layer = -1 # boven de 3D-wereld, onder de HUD
	add_child(layer)
	_screen = ColorRect.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_mat = ShaderMaterial.new()
	_screen_mat.shader = HEAT_SHADER
	_screen.material = _screen_mat
	_screen.visible = false
	layer.add_child(_screen)


func _build_smoke() -> void:
	# Donkere rook die traag opstijgt van de lava, rond de camera.
	_smoke = GPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 40
	_smoke.lifetime = 6.0
	_smoke.visibility_aabb = AABB(Vector3(-16, -2, -16), Vector3(32, 22, 32))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(14, 0.3, 14)
	m.direction = Vector3(0, 1, 0)
	m.spread = 15.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.0
	m.gravity = Vector3(0, 0.1, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.5
	m.turbulence_noise_scale = 5.0
	m.scale_min = 1.0
	m.scale_max = 2.2
	var g := Gradient.new()
	g.set_color(0, Color(0.25, 0.12, 0.06, 0.0))
	g.add_point(0.2, Color(0.12, 0.08, 0.07, 0.35))
	g.set_color(g.get_point_count() - 1, Color(0.08, 0.07, 0.07, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	_smoke.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var qm := StandardMaterial3D.new()
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	qm.albedo_texture = dot
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = qm
	_smoke.draw_pass_1 = q
	_smoke.emitting = false
	add_child(_smoke)


func _build_embers() -> void:
	# Gensters die opstijgen rond de camera, enkel vlak boven het magma.
	_embers = GPUParticles3D.new()
	_embers.name = "Embers"
	_embers.amount = 150
	_embers.lifetime = 4.0
	_embers.visibility_aabb = AABB(Vector3(-14, -6, -14), Vector3(28, 24, 28))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(12, 2, 12)
	m.direction = Vector3(0, 1, 0)
	m.spread = 25.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.8
	m.gravity = Vector3(0, 0.15, 0)
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.6
	m.turbulence_noise_scale = 3.0
	m.scale_min = 0.5
	m.scale_max = 1.3
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.0))
	g.add_point(0.15, Color(1.0, 0.7, 0.25, 1.0))
	g.add_point(0.7, Color(1.0, 0.35, 0.05, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.1, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	_embers.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
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
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(4.0, 2.0, 0.8)
	q.material = qm
	_embers.draw_pass_1 = q
	_embers.emitting = false
	add_child(_embers)


# --- Regels (host) -------------------------------------------------------------------------------

func _reset_rules() -> void:
	_in_magma.clear()
	_melting.clear()
	_alarm_level = 0
	_mol_heat = 0.0
	_recalled = false


func _host_rules(dt: float) -> void:
	_rule_players()
	_rule_melting(dt)
	_rule_loot(dt)
	_rule_mol(dt)


## Spelers die in het magma zakken, beginnen te smelten (melt_s), daarna staat een vervanger in de
## Mol (of op het schip), en wat ze droegen is weg.
func _rule_players() -> void:
	var mol: Mol = game.mol
	for pl: Player in game.players.get_children():
		if _melting.has(pl.peer_id) or pl.seated or pl.global_position.y > level - 0.3:
			continue
		if game.rescue and game.rescue.life_of(pl.peer_id) == Rescue.Life.BROKEN:
			continue # een spookdrone smelt niet
		if mol and mol.contains_point(pl.global_position) and mol.body.global_position.y > level - 1.0:
			continue
		_melting[pl.peer_id] = 0.0
		_rpc_melting.rpc(pl.peer_id)


func _rule_melting(dt: float) -> void:
	var mol: Mol = game.mol
	for peer: int in _melting.keys():
		_melting[peer] = float(_melting[peer]) + dt
		if _melting[peer] < Tuning.get_f("magma", "melt_s", 1.5):
			continue
		_melting.erase(peer)
		var pl: Player = game.player_node(peer)
		if pl == null:
			continue
		game.ores.host_lose_bag(pl.peer_id)
		game.company.host_melted()
		_rpc_melted.rpc(pl.peer_id)
		if game.rescue:
			# Kapot: een spookdrone boven het magma, tot de dienst voorbij is (Rescue).
			game.rescue.host_break(pl.peer_id, true)
		else:
			pl.host_teleport(game.spawn_pos_of(pl.peer_id))


@rpc("authority", "call_local", "reliable")
func _rpc_melting(peer_id: int) -> void:
	melting.emit(peer_id)
	var p: Player = game.player_node(peer_id)
	if p == null:
		return
	# Voor iedereen: een stoot gensters en rook waar de robot wegsmelt.
	_melt_burst(p.global_position)
	if p.is_local:
		_melt_t = 0.0
		_after_t = -1.0
		p.stun(Tuning.get_f("magma", "melt_s", 1.5) + 0.2, false)


func _melt_burst(pos: Vector3) -> void:
	var b := _embers.duplicate() as GPUParticles3D
	var pm := (b.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	pm.emission_box_extents = Vector3(0.5, 0.3, 0.5)
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.5
	pm.spread = 35.0
	b.process_material = pm
	b.amount = 90
	b.lifetime = 1.6
	b.one_shot = true
	b.explosiveness = 0.8
	add_child(b)
	b.global_position = Vector3(pos.x, level + 0.4, pos.z)
	b.emitting = true
	get_tree().create_timer(3.0).timeout.connect(b.queue_free)


@rpc("authority", "call_local", "reliable")
func _rpc_melted(peer_id: int) -> void:
	melted.emit(peer_id)
	var p: Player = game.player_node(peer_id)
	if p and p.is_local:
		_melt_t = -1.0
		_after_t = 0.0
		game.notice.emit("Your robot melted. Everything it carried is gone.", "alarm")
	elif p:
		game.notice.emit("A robot melted in the magma.", "warn")


## Losse buit (en vondsten nog in de rots) onder het magma: na swallow_s weg.
func _rule_loot(dt: float) -> void:
	var finds: FindField = game.finds
	var mol: Mol = game.mol
	var keep := {}
	for it: FindItem in finds.items:
		if not is_instance_valid(it) or not it.carriers.is_empty() or it.global_position.y > level:
			continue
		if mol and mol.contains_point(it.global_position) and mol.body.global_position.y > level - 1.0:
			continue
		var t: float = _in_magma.get(it.find_id, 0.0) + dt
		keep[it.find_id] = t
		if t >= Tuning.get_f("magma", "swallow_s", 1.5):
			finds.host_swallow(it.find_id)
	_in_magma = keep


## De Mol: alarmen als het magma eronder komt, hitte als hij erin staat, en de noodophaling.
func _rule_mol(dt: float) -> void:
	var mol: Mol = game.mol
	if mol == null or mol.body == null or mol.mode == Mol.Mode.DOCKED:
		return
	var bottom := mol.body.global_position.y + Mol.TRACK_BOTTOM
	var gap := bottom - level
	var alarms := [Tuning.get_f("magma", "alarm_1", 40.0), Tuning.get_f("magma", "alarm_2", 20.0), Tuning.get_f("magma", "alarm_3", 10.0)]
	if _alarm_level > 0 and gap > alarms[_alarm_level - 1] + 10.0:
		_alarm_level -= 1 # de Mol reed weg: opnieuw waarschuwen als het weer dichtkomt
	if _alarm_level < alarms.size() and gap <= alarms[_alarm_level] and gap > 0.0:
		mol.announce("Magma %d m below the Mole!" % int(alarms[_alarm_level]), "alarm")
		_alarm_level += 1
	if gap < 0.0:
		_mol_heat += dt / maxf(1.0, Tuning.get_f("magma", "mol_heat_s", 25.0))
		if _mol_heat >= 1.0 and mol.host_emergency(5.0, "The Mole is overheating! DIG hauls it up, cargo scorched."):
			_mol_heat = 0.0
			# Te heet: de lading verschroeit (ontwerp-7: het magma kost wat je bij je had).
			var loss := Tuning.get_f("magma", "mol_heat_cargo_loss", 0.4)
			for it: FindItem in mol.cargo_contents():
				var cond := maxf(Tuning.get_f("finds", "min_condition", 0.25), it.condition - loss)
				if cond < it.condition - 0.001:
					game.finds._rpc_condition.rpc(it.find_id, cond)
	else:
		_mol_heat = maxf(0.0, _mol_heat - dt / 10.0)
	if not _recalled and depth() <= Tuning.get_f("magma", "recall_depth", 60.0):
		if mol.host_emergency(20.0, "Emergency extraction: the magma is rising. The Mole leaves in 20 s!"):
			_recalled = true


## Hitte van de Mol (0..1), voor het statusscherm.
func mol_heat() -> float:
	return _mol_heat
