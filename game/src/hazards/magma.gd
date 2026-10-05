class_name Magma
extends Node3D
## Magma (GDD §3, §6; onderzoek docs/research/magma-en-onrust.md): een stijgend vlak onder de hele
## concessie, de enige klok van een dienst.
## - Klok: `t_eff` = seconden sinds de start + de voorsprong van de bevingen (elke beving zet de
##   klok `quake_advance_s` vooruit, als een golf). De host bezit de starttijd en de bevingen en
##   stuurt ze door; elke peer rekent de hoogte zelf uit met dezelfde curve (magma.cfg).
## - Curve: eerst stil, dan steeds iets sneller (zie `risen`).
## - Regels (host): spelers die erin zakken, smelten (een vervanger in de Mol), losse buit is weg,
##   de Mol krijgt alarmen en houdt het even uit, en op `recall_depth` vertrekt hij vanzelf.
## - Beeld: één plaat met een shader, rots die erboven opwarmt (global uniform `magma_height` in
##   terrain.gdshader), een lamp onder de camera, gensters en een warme mist dichtbij.

const SHADER := preload("res://src/hazards/magma.gdshader")
const SYNC_INTERVAL := 2.0
const RULES_INTERVAL := 0.25

## Een speler smolt (op elke peer; voor HUD en tests).
signal melted(peer_id: int)
## Losse buit werd opgeslokt (op elke peer).
signal swallowed(find_id: int)

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
var _light: OmniLight3D
var _light_k := 0.0
var _embers: GPUParticles3D
var _sync_timer := 0.0
var _rules_timer := 0.0
# Host: regels.
var _in_magma := {} # find_id -> seconden in het magma
var _alarm_level := 0 # hoeveel alarmen al gegeven (opnieuw als de Mol wegrijdt)
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
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.extra_cull_margin = 4.0
	add_child(_mesh)
	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Color(1.0, 0.42, 0.12)
	_light.shadow_enabled = false
	_light.omni_attenuation = 1.4
	_light.light_volumetric_fog_energy = 0.0
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


## Host: een beving zet de klok vooruit (golf over wave_s).
func host_quake() -> void:
	quakes.append(elapsed)
	_rpc_clock.rpc(running, elapsed, quakes, speed_factor)


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
	visible = running or elapsed > 0.0
	RenderingServer.global_shader_parameter_set("magma_height", level if visible else -10000.0)
	RenderingServer.global_shader_parameter_set("magma_heat_m", Tuning.get_f("magma", "rock_heat_m", 12.0))


# --- Beeld ---------------------------------------------------------------------------------------

## Lamp onder de camera: hoe dichter bij het magma, hoe feller de wanden van onderen gloeien. Zit er
## rots tussen de camera en het magma, dan dooft hij uit (anders licht hij plafonds door de rots op).
func _update_glow(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not visible:
		_light.visible = false
		_embers.emitting = false
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
	_light.light_energy = 4.0 * _light_k * _light_k
	_embers.global_position = Vector3(p.x, maxf(level + 2.0, p.y - 4.0), p.z)
	_embers.emitting = above < 30.0 and above > -1.0


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
	_alarm_level = 0
	_mol_heat = 0.0
	_recalled = false


func _host_rules(dt: float) -> void:
	_rule_players()
	_rule_loot(dt)
	_rule_mol(dt)


## Spelers die in het magma zakken, smelten: een vervanger staat in de Mol (of op het schip),
## en wat ze droegen is weg.
func _rule_players() -> void:
	var mol: Mol = game.mol
	for pl: Player in game.players.get_children():
		if pl.seated or pl.global_position.y > level - 0.3:
			continue
		if mol and mol.contains_point(pl.global_position) and mol.body.global_position.y > level - 1.0:
			continue
		var to: Vector3 = game.spawn_pos_of(pl.peer_id)
		if mol and mol.body.global_position.y + Mol.TRACK_BOTTOM > level + 2.0 and mol.mode != Mol.Mode.DOCKED:
			to = mol.to_world_mol(Vector3(0.0, -1.2, 1.2))
		game.ores.host_lose_bag(pl.peer_id)
		game.company.host_melted()
		pl.host_teleport(to)
		_rpc_melted.rpc(pl.peer_id)


@rpc("authority", "call_local", "reliable")
func _rpc_melted(peer_id: int) -> void:
	melted.emit(peer_id)
	var p: Player = game.player_node(peer_id)
	if p and p.is_local:
		game.notice.emit("Your robot melted in the magma. DIG sent a replacement (costs to follow).", "warn")
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
		mol.announce("! MAGMA %d M BELOW THE MOLE" % int(alarms[_alarm_level]))
		_alarm_level += 1
	if gap < 0.0:
		_mol_heat += dt / maxf(1.0, Tuning.get_f("magma", "mol_heat_s", 25.0))
		if _mol_heat >= 1.0 and mol.host_emergency(5.0, "The Mole is overheating: DIG is hauling it up!"):
			_mol_heat = 0.0
	else:
		_mol_heat = maxf(0.0, _mol_heat - dt / 10.0)
	if not _recalled and depth() <= Tuning.get_f("magma", "recall_depth", 60.0):
		if mol.host_emergency(20.0, "Emergency extraction: the magma is rising. The Mole leaves in 20 s!"):
			_recalled = true


## Hitte van de Mol (0..1), voor het statusscherm.
func mol_heat() -> float:
	return _mol_heat
