class_name WormVisual
extends Node3D
## Het beeld van de Graafworm (GDD §8: "de worm is een segmentketting"). Enkel zichtbaar als hij
## uitvalt of de Mol ramt; de rest van de tijd zwemt hij onzichtbaar door de rots (Worm: tekens).
## Model: assets/models/worm.glb (tools/blender/worm.py): Worm_Head met vier kaken (Jaw_0..3) en een
## gloeiende keel, Worm_Segment (een gepantserde ring), Worm_Tail. De kop volgt een boog (Bézier) uit
## de rots, door de open ruimte, en terug de rots in; de segmenten volgen zijn spoor.
## Een uitval: telegraph_s waarschuwing (barsten groeien op de rots, een stofgeiser, gerommel), dan de
## boog met open kaken, stof en steentjes waar hij uit en in de rots gaat.

const MODEL_PATH := "res://assets/models/worm.glb"
const SEGMENTS := 9
const SPACING := 1.45
## Lengte van het lijf achter de kop (m).
const BODY_LEN := SPACING * (SEGMENTS + 1.5)

var worm: Worm

var _root: Node3D
var _head: Node3D
var _jaws: Array[Node3D] = []
var _segs: Array[Node3D] = []
var _tail: Node3D
var _light: OmniLight3D
var _poly := PackedVector3Array()
var _cum := PackedFloat32Array()
var _s0 := 0.0 # booglengte waar de Bézier begint
var _s3 := 0.0 # en eindigt
var _t := -1.0
var _tel := 1.3
var _burst := 1.6
var _speed := 6.0
var _emerge := Vector3.ZERO
var _exit := Vector3.ZERO
var _phase := 0 # 0 = waarschuwing, 1 = boog, 2 = duikt weg
var _cracks: Decal
var _geyser: GPUParticles3D
var _exit_burst_done := false
var _short := false


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Chain"
	_root.top_level = true
	add_child(_root)
	_build()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.45, 0.15)
	_light.omni_range = 7.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_head.add_child(_light)
	_light.position = Vector3(0.0, 0.0, -1.6)
	_cracks = Decal.new()
	_cracks.name = "Cracks"
	_cracks.texture_albedo = Worm._crack_texture()
	_cracks.modulate = Color(0.1, 0.06, 0.04)
	_cracks.visible = false
	_cracks.top_level = true
	add_child(_cracks)
	stop()


func _build() -> void:
	var head_mesh: Node3D = null
	var seg_mesh: Node3D = null
	var tail_mesh: Node3D = null
	if ResourceLoader.exists(MODEL_PATH):
		var model := (load(MODEL_PATH) as PackedScene).instantiate()
		head_mesh = model.find_child("Worm_Head", true, false) as Node3D
		seg_mesh = model.find_child("Worm_Segment", true, false) as Node3D
		tail_mesh = model.find_child("Worm_Tail", true, false) as Node3D
		for n: Node3D in [head_mesh, seg_mesh, tail_mesh]:
			if n:
				n.get_parent().remove_child(n)
				n.owner = null
				for c in n.find_children("*", "", true, false):
					c.owner = null
				n.transform = Transform3D.IDENTITY
		model.queue_free()
	if head_mesh == null:
		head_mesh = _fallback_head()
	if seg_mesh == null:
		seg_mesh = _fallback_segment(1.0)
	if tail_mesh == null:
		tail_mesh = _fallback_segment(0.6)
	_head = Node3D.new()
	_head.name = "Head"
	_head.add_child(head_mesh)
	_root.add_child(_head)
	for i in 4:
		var j := head_mesh.find_child("Jaw_%d" % i, true, false) as Node3D
		if j:
			j.set_meta("rest", j.transform)
			_jaws.append(j)
	for i in SEGMENTS:
		var s := Node3D.new()
		s.name = "Seg%d" % i
		var m := seg_mesh.duplicate() as Node3D
		var k := lerpf(1.0, 0.72, float(i) / SEGMENTS)
		m.scale = Vector3(k, k, 1.0)
		s.add_child(m)
		_root.add_child(s)
		_segs.append(s)
	seg_mesh.queue_free()
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.add_child(tail_mesh)
	_root.add_child(_tail)
	for mi: MeshInstance3D in _root.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _fallback_head() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 1.1
	c.height = 3.0
	mi.mesh = c
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = Vector3(0, 0, -0.8)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.33, 0.37)
	m.roughness = 0.7
	mi.material_override = m
	n.add_child(mi)
	return n


func _fallback_segment(r: float) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.0 * r
	c.bottom_radius = 1.05 * r
	c.height = 1.5
	mi.mesh = c
	mi.rotation_degrees = Vector3(90, 0, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.29, 0.33)
	m.roughness = 0.75
	mi.material_override = m
	n.add_child(mi)
	return n


## Punt op een kubische Bézier (vier controlepunten).
static func bezier(p: Array, u: float) -> Vector3:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	var d: Vector3 = p[3]
	var v := 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u


func stop() -> void:
	_t = -1.0
	_root.visible = false
	_cracks.visible = false
	if _light:
		_light.light_energy = 0.0
	set_process(false)


## Een uitval op elk peer (zelfde plan): eerst de waarschuwing op `emerge`, dan de boog.
func play_lunge(path: Array, emerge: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	_short = false
	_start(path, emerge, exit, tel, burst)
	# Waarschuwing: barsten groeien op de rots, stof spuit eruit, de grond rommelt.
	_cracks.visible = true
	_cracks.global_position = emerge + Vector3.UP * 0.8
	_cracks.size = Vector3(0.5, 2.5, 0.5)
	_geyser = _dust(emerge, Vector3.UP, 70, 2.6, 0.5)
	_geyser.emitting = true


## Previews (ter goedkeuring): de worm stil op een plek van zijn boog (`u` 0..1, kaken `open` 0..1).
func hold_pose(path: Array, u: float, open := 0.6) -> void:
	_short = true
	_start(path, path[0], path[3], 0.0, 1.0)
	_root.visible = true
	_phase = 1
	set_process(false)
	var s := _s0 + (_s3 - _s0) * u
	_place(_head, s)
	for i in _segs.size():
		_place(_segs[i], s - 0.62 - SPACING * i)
	_place(_tail, s - 0.62 - SPACING * (_segs.size() - 1) - 0.7)
	_open_jaws(open)
	_light.light_energy = 1.4


func _open_jaws(open: float) -> void:
	for j in _jaws:
		var rest: Transform3D = j.get_meta("rest")
		# Elke kaak klapt naar buiten rond zijn raaklijn aan de muil (vooruit × naar buiten).
		var radial := Vector3(rest.origin.x, rest.origin.y, 0.0)
		radial = radial.normalized() if radial.length() > 0.01 else Vector3.UP
		var axis := Vector3(0, 0, -1).cross(radial).normalized()
		j.transform = Transform3D(Basis(axis, deg_to_rad(55.0) * open) * rest.basis, rest.origin)


## De Mol rammen: geen waarschuwing, de kop slaat vanuit de rots tegen de romp en trekt terug.
func play_ram(at: Vector3, side: Vector3) -> void:
	_short = true
	var p0 := at + side * 3.5
	var p1 := at - side * 0.4
	var p2 := at - side * 0.4 + Vector3.UP * 0.6
	var p3 := at + side * 3.5 + Vector3.UP * 0.4
	_start([p0, p1, p2, p3], at, at, 0.0, 0.8)
	_burst_at(at, -side, 1.2)


func _start(path: Array, emerge: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	_emerge = emerge
	_exit = exit
	_tel = tel
	_burst = burst
	_exit_burst_done = false
	# Het spoor: een stuk recht de rots in vóór het begin (daar zit het lijf nog), de Bézier, en een
	# stuk recht de rots in na het einde (daar duikt het lijf weg).
	_poly = PackedVector3Array()
	var start_dir := ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
	var end_dir := ((path[3] as Vector3) - (path[2] as Vector3)).normalized()
	var ext := BODY_LEN + 2.0
	for i in 8:
		_poly.append((path[0] as Vector3) - start_dir * ext * (1.0 - float(i) / 8.0))
	for i in 41:
		_poly.append(bezier(path, float(i) / 40.0))
	for i in range(1, 9):
		_poly.append((path[3] as Vector3) + end_dir * ext * float(i) / 8.0)
	_cum = PackedFloat32Array()
	_cum.resize(_poly.size())
	_cum[0] = 0.0
	for i in range(1, _poly.size()):
		_cum[i] = _cum[i - 1] + _poly[i].distance_to(_poly[i - 1])
	_s0 = _cum[8]
	_s3 = _cum[48]
	_speed = (_s3 - _s0) / maxf(burst, 0.1)
	_t = 0.0
	_phase = 0
	_root.visible = false
	set_process(true)


func _sample(s: float) -> Vector3:
	s = clampf(s, 0.0, _cum[_cum.size() - 1])
	var lo := 0
	var hi := _cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var span := _cum[hi] - _cum[lo]
	var k := 0.0 if span <= 0.0 else (s - _cum[lo]) / span
	return _poly[lo].lerp(_poly[hi], k)


func _place(n: Node3D, s: float) -> void:
	var p := _sample(s)
	var ahead := _sample(s + 0.6)
	var dir := ahead - p
	if dir.length() < 0.01:
		dir = p - _sample(s - 0.6)
	if dir.length() < 0.01:
		return
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	n.global_transform = Transform3D(Basis.looking_at(dir.normalized(), up), p)


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var tel := _tel
	if _t < tel:
		# Waarschuwing: de barsten groeien.
		var k := _t / maxf(tel, 0.01)
		_cracks.size = Vector3.ONE.lerp(Vector3(3.6, 2.5, 3.6), k)
		_cracks.modulate.a = k
		_local_rumble(_emerge, 0.6 + 0.6 * k)
		return
	if _phase == 0:
		_phase = 1
		_root.visible = true
		if not _short:
			_burst_at(_emerge, Vector3.UP, 1.4)
		if _geyser:
			_geyser.emitting = false
			get_tree().create_timer(3.0).timeout.connect(_geyser.queue_free)
			_geyser = null
	var u := (_t - tel) / maxf(_burst, 0.1)
	# Kop: snel uit de rots, iets trager boven, weer snel erin; daarna zwemt het lijf erachteraan.
	var s := _s0 + (_s3 - _s0) * (u if u <= 1.0 else 1.0) + (_speed * (_t - tel - _burst) if u > 1.0 else 0.0)
	_place(_head, s)
	for i in _segs.size():
		_place(_segs[i], s - 0.62 - SPACING * i)
	_place(_tail, s - 0.62 - SPACING * (_segs.size() - 1) - 0.7)
	# Kaken: open tijdens de boog, dicht als hij wegduikt.
	var open := 0.0
	if u < 1.0:
		open = smoothstep(0.0, 0.2, u) * (1.0 - 0.6 * smoothstep(0.75, 1.0, u))
	_open_jaws(open)
	_light.light_energy = 1.8 * (smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(1.0, 1.3, u)))
	_local_rumble(_sample(s), 1.0)
	if u >= 0.92 and not _exit_burst_done and not _short:
		_exit_burst_done = true
		_burst_at(_exit, Vector3.UP, 1.1)
	if s - BODY_LEN - 1.0 > _s3 or _t > tel + _burst + 4.0:
		stop()
		return
	_cracks.modulate.a = maxf(0.0, _cracks.modulate.a - delta * 0.2)


## De lokale camera schudt mee (dichtbij hard, tot 30 m zacht).
func _local_rumble(at: Vector3, strength: float) -> void:
	var p: Player = worm.game.local_player if worm and worm.game else null
	if p == null or p.camera_fx == null:
		return
	var k := (1.0 - smoothstep(4.0, 30.0, p.global_position.distance_to(at))) * strength
	if k > 0.01:
		p.camera_fx.hold_trauma(0.55 * k)
		p.camera_fx.hold_rumble(4.0 * k)


## Stof, steentjes en een paar brokken waar hij uit of in de rots gaat.
func _burst_at(at: Vector3, normal: Vector3, size: float) -> void:
	var t: TerrainAPI = worm.game.terrain
	var col := Strata.DEBRIS_COLORS[t.layer_at(at - normal * 0.4)]
	var d := _dust(at, normal, int(60 * size), 2.6, 1.6 * size)
	d.one_shot = true
	d.explosiveness = 0.9
	d.emitting = true
	worm.game.fx.grit_puff(at, normal, col)
	for i in int(6 * size):
		hop_pebble(at + Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)), col, 4.0)
	get_tree().create_timer(4.0).timeout.connect(d.queue_free)


## Een steentje dat opspringt (tekens op de vloer, de uitval). Enkel beeld, lokaal.
func hop_pebble(at: Vector3, col: Color, strength := 1.6) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 0
	rb.collision_mask = Layers.TERRAIN
	rb.mass = 0.2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.05
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = randf_range(0.04, 0.09)
	m.height = m.radius * 1.6
	m.radial_segments = 6
	m.rings = 3
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col.darkened(0.2)
	mi.material_override = mat
	rb.add_child(mi)
	add_child(rb)
	rb.global_position = at
	rb.linear_velocity = Vector3(randf_range(-0.6, 0.6), randf_range(0.6, 1.0) * strength, randf_range(-0.6, 0.6))
	get_tree().create_timer(3.5).timeout.connect(rb.queue_free)


## Opslokken: een stofwolkje en een gulzige knip van de kaken.
func gulp(at: Vector3) -> void:
	worm.game.fx.grit_puff(at, Vector3.UP, Color(0.5, 0.4, 0.3))


func _dust(at: Vector3, normal: Vector3, amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var t: TerrainAPI = worm.game.terrain
	var col := Strata.DEBRIS_COLORS[t.layer_at(at - normal * 0.4)]
	var d := GPUParticles3D.new()
	d.amount = maxi(4, amount)
	d.lifetime = lifetime
	d.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 14, 16))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.6 * size
	m.direction = normal
	m.spread = 25.0
	m.initial_velocity_min = 1.0 * size
	m.initial_velocity_max = 3.5 * size
	m.gravity = Vector3(0, -1.2, 0)
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.scale_min = 0.6
	m.scale_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(col, 0.0))
	g.add_point(0.12, Color(col, 0.55))
	g.set_color(g.get_point_count() - 1, Color(col, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
	d.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9) * size
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	qm.albedo_texture = dot
	q.material = qm
	d.draw_pass_1 = q
	add_child(d)
	d.global_position = at
	return d
