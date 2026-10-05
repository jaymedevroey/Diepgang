class_name DigFx
extends Node3D
## Lokale, cosmetische effecten van graven: stof, steentjes, vonken en geluid.
## Niets hiervan gaat over het netwerk; enkel terreinbewerkingen worden gesynchroniseerd.

enum Stream { GRIT, SPARKS, DUST, STEAM }

const LAYER_DEBRIS := 1 << 3
const MAX_PEBBLES := 64
const PEBBLE_LIFETIME := 14.0 # puin blijft even op de vloer liggen (binnen-09)
const MAX_CUTS := 12

const SFX := {
	"clay": ["pick_clay_1", "pick_clay_2", "pick_clay_3", "pick_clay_4", "pick_clay_5"],
	"clink": ["pick_clink_1", "pick_clink_2", "pick_clink_3", "pick_clink_4"],
	"whoosh": ["pick_whoosh_1", "pick_whoosh_2", "pick_whoosh_3"],
	"crumble": ["crumble_1", "crumble_2", "crumble_3"],
	"tok": ["crust_tok_1", "crust_tok_2", "crust_tok_3", "crust_tok_4"],
	"break": ["crust_break_1", "crust_break_2"],
	"ding": ["find_ding"],
}
const CRUST_COLOR := Color(0.72, 0.64, 0.5)

var _streams: Dictionary = {}
var _pebbles: Array[RigidBody3D] = []
var _dust_material: ParticleProcessMaterial
var _dust_draw: QuadMesh
var _spark_material: ParticleProcessMaterial
var _spark_draw: QuadMesh
var _grit_material: ParticleProcessMaterial
var _grit_draw: Mesh
var _star_material: ParticleProcessMaterial
var _star_draw: QuadMesh
var _steam_material: ParticleProcessMaterial
var _cuts: Array[Decal] = []
var _cut_texture: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	for key: String in SFX:
		var r := AudioStreamRandomizer.new()
		r.random_pitch = 1.08
		r.random_volume_offset_db = 1.5
		r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		for name: String in SFX[key]:
			r.add_stream(-1, load("res://assets/audio/sfx/%s.wav" % name))
		_streams[key] = r
	_build_materials()


## Houweel raakt graafbare grond. Het stof is lichter dan de wand en blijft dicht bij de inslag,
## zodat de verse kuil leesbaar blijft (gevoel-19, binnen-09).
func impact(pos: Vector3, normal: Vector3, color: Color, pebbles: int) -> void:
	_burst_dust(pos, normal, color.lightened(0.22), 4, 0.5, 0.3, 0.75)
	_burst_grit(pos, normal, color, 14)
	for i in pebbles:
		_spawn_pebble(pos + normal * 0.15, normal, color)
	play("clay", pos, 0.0)
	play("crumble", pos, -9.0, 0.12)


## Verse snede: de binnenkant van de kuil is even donkerder en vochtiger dan de wand, en droogt in
## ±25 s op (binnen-09). Een decal die over de kuil valt; de oudste maakt plaats.
func fresh_cut(pos: Vector3, normal: Vector3, radius: float) -> void:
	if _cut_texture == null:
		_cut_texture = _blotch_texture()
	var d: Decal
	if _cuts.size() >= MAX_CUTS:
		d = _cuts.pop_front()
		var old: Tween = d.get_meta("tween", null)
		if old:
			old.kill()
	else:
		d = Decal.new()
		d.texture_albedo = _cut_texture
		d.cull_mask = ~(1 << 1) # niet op het gereedschap in beeld
		d.normal_fade = 0.25
		d.upper_fade = 0.15
		d.lower_fade = 0.15
		add_child(d)
	_cuts.append(d)
	var s := radius * 1.7
	d.size = Vector3(s, 1.4, s)
	var y := normal.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	d.global_transform = Transform3D(Basis(x, y, x.cross(y)).rotated(y, _rng.randf() * TAU), pos + y * 0.25)
	d.modulate = Color(Tuning.get_f("pickaxe", "fresh_cut_tint", 0.45), Tuning.get_f("pickaxe", "fresh_cut_tint", 0.45) * 0.9,
			Tuning.get_f("pickaxe", "fresh_cut_tint", 0.45) * 0.85, 1.0)
	d.albedo_mix = Tuning.get_f("pickaxe", "fresh_cut_mix", 0.7)
	var tw := d.create_tween()
	tw.tween_interval(Tuning.get_f("pickaxe", "fresh_cut_s", 25.0) * 0.4)
	tw.tween_property(d, "albedo_mix", 0.0, Tuning.get_f("pickaxe", "fresh_cut_s", 25.0) * 0.6)
	d.set_meta("tween", tw)


## Houweel of boor raakt een korst: droge tok, stof en schilfers in de kleur van de korst.
func crust_hit(pos: Vector3, normal: Vector3, with_sound := true, tint := CRUST_COLOR) -> void:
	_burst_dust(pos, normal, tint.lightened(0.15), 5, 0.6, 0.35, 1.0)
	_burst_grit(pos, normal, tint, 12)
	if with_sound:
		_spawn_pebble(pos + normal * 0.1, normal, tint)
		play("tok", pos, -1.0)


## Korst springt open (gevoel-03). Eerst de vondst: schelpen van de korst vliegen naar buiten weg
## (niet naar de speler), een licht en sterretjes in de glans van de waardeklasse; pas daarna een
## kleine, lage stofring. `toward`: richting van de speler (daar komt het stof niet).
func crust_break(pos: Vector3, size: float, tint := CRUST_COLOR, glint := Color(1.0, 0.9, 0.7), strength := 1.0,
		toward := Vector3.ZERO, follow: Node3D = null) -> void:
	var away := -toward.normalized() if toward.length() > 0.01 else Vector3.ZERO
	for i in 8:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1), _rng.randf_range(-1, 1)).normalized()
		if away != Vector3.ZERO and dir.dot(away) < -0.2:
			dir = (dir + away * 1.2).normalized()
		_spawn_pebble(pos + dir * size * 0.5, dir, tint, 1.6)
	_burst_grit(pos, Vector3.UP, tint, 16)
	_flash(pos + Vector3(0, 0.15, 0), glint, Tuning.get_f("finds", "reveal_light", 5.0) * strength,
			Tuning.get_f("finds", "reveal_light_s", 1.8) * strength, 4.0)
	_sparkle(pos, glint, size, strength, follow)
	play("break", pos, 0.0)
	# Het stof pas een tel later, laag en naar buiten (weg van de speler), niet over de vondst.
	await get_tree().create_timer(Tuning.get_f("finds", "reveal_dust_delay_s", 0.35)).timeout
	for k in 4:
		var a := k * TAU / 4.0 + _rng.randf() * 0.6
		var out := Vector3(cos(a), 0.05, sin(a))
		if away != Vector3.ZERO and out.dot(away) < -0.3:
			continue
		_burst_dust(pos + out * size * 0.9 - Vector3(0, size * 0.6, 0), out.normalized(), tint, 2, 0.35 + size * 0.5, 0.22, 0.9)


## Erts geraakt: een heldere tik, fonkels in de kleur van het erts en een paar brokjes (gevoel-16).
func ore_hit(pos: Vector3, normal: Vector3, kind: int, with_sound := true) -> void:
	var col: Color = OreKinds.COLORS[kind]
	_burst_grit(pos, normal, col, 8)
	_sparkle_burst(pos + normal * 0.05, normal, col.lightened(0.35), 10)
	if with_sound:
		_spawn_pebble(pos + normal * 0.12, normal, col)
		play("clink", pos, -7.0, 0.0, 1.45)
		play("clay", pos, -8.0)


## Ertszak gestort in de trechter: brokjes in de kleur van het erts vallen erin, gerammel, en
## "+€X" erboven (gevoel-16). `counts`: eenheden per OreKinds.Kind.
func ore_pour(pos: Vector3, counts: PackedInt32Array, gain: int) -> void:
	var cols: Array[Color] = []
	for k in counts.size():
		for i in mini(counts[k], 6):
			cols.append(OreKinds.COLORS[k])
	cols.shuffle()
	# De trechter hangt onder het dak: de brokjes vallen er net boven in, de tekst staat ervoor.
	for i in mini(cols.size(), 14):
		var at := pos + Vector3(_rng.randf_range(-0.12, 0.12), 0.12 + i * 0.03, _rng.randf_range(-0.12, 0.12))
		_spawn_pebble(at, Vector3.DOWN, cols[i], 0.5)
	for i in 4:
		play("crumble", pos, -6.0, i * 0.12, 1.3)
		play("clink", pos, -14.0, 0.06 + i * 0.12, 1.6)
	var cam := get_viewport().get_camera_3d()
	var toward := (cam.global_position - pos).normalized() * 0.4 if cam else Vector3.ZERO
	float_text(pos + toward + Vector3(0, -0.1, 0), "+€%d" % gain, Color(0.55, 1.0, 0.45), 1.0, 1.8)


## Een tekst die even boven een plek zweeft en opstijgt (bv. "−€12" bij schade, "+3 Copper").
func float_text(pos: Vector3, text: String, color: Color, size := 1.0, seconds := 1.4) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.heading()
	l.font_size = int(64 * size)
	l.pixel_size = 0.0024
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(0, 0.45 * size, 0), seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, seconds * 0.4).set_delay(seconds * 0.6)
	tw.chain().tween_callback(l.queue_free)


## Harde landing: een lage stofring rond de voeten, naar buiten (niet in het gezicht).
func land_dust(pos: Vector3, color: Color, size: float) -> void:
	for k in 6:
		var a := k * TAU / 6.0 + _rng.randf() * 0.5
		var out := Vector3(cos(a), 0.18, sin(a)).normalized()
		_burst_dust(pos + Vector3(cos(a), 0.0, sin(a)) * 0.25, out, color.lightened(0.15), 3, 0.7 * size)
	_burst_grit(pos, Vector3.UP, color, int(8 * size))


## Boorhap van een andere speler: kleine gruiswolk, geen steentjes of geluid
## (zijn motorgeluid komt van zijn robot).
func grit_puff(pos: Vector3, normal: Vector3, color: Color) -> void:
	_burst_grit(pos, normal, color, 5)
	_burst_dust(pos, normal, color, 3, 0.8)


## Doorlopende stroom (boor). De eigenaar zet emitting, positie en kleur, en ruimt op.
func make_stream(kind: Stream) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false
	p.emitting = false
	match kind:
		Stream.GRIT:
			p.process_material = _grit_material
			p.draw_pass_1 = _grit_draw
			p.amount = 70
			p.lifetime = 0.8
			var m := StandardMaterial3D.new()
			m.roughness = 1.0
			p.material_override = m
		Stream.SPARKS:
			p.process_material = _spark_material
			p.draw_pass_1 = _spark_draw
			p.amount = 40
			p.lifetime = 0.25
			p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
		Stream.DUST:
			p.process_material = _dust_material
			p.draw_pass_1 = _dust_draw
			p.amount = 18
			p.lifetime = 1.0
			p.material_override = _dust_draw.material.duplicate()
		Stream.STEAM:
			# Stoom van een oververhitte boor: witte pluimen die opstijgen.
			p.process_material = _steam_material
			p.amount = 14
			p.lifetime = 1.2
			var sm := _dust_draw.material.duplicate() as StandardMaterial3D
			sm.albedo_color = Color(0.92, 0.92, 0.9, 0.3)
			sm.proximity_fade_enabled = false
			sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			sm.distance_fade_min_distance = 0.25
			sm.distance_fade_max_distance = 0.7
			# Een eigen, klein vlak: de pluimen zijn een paar cm, geen wolk van een halve meter.
			var q := QuadMesh.new()
			q.size = Vector2(0.1, 0.1)
			q.material = sm
			p.draw_pass_1 = q
	add_child(p)
	return p


func tint_stream(p: GPUParticles3D, color: Color) -> void:
	var m := p.material_override as StandardMaterial3D
	if m == null:
		return
	if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
		m.albedo_color = Color(color, 0.45)
	else:
		m.albedo_color = color


## Houweel ketst af op te harde rots.
func clink(pos: Vector3, normal: Vector3, color: Color) -> void:
	_burst_sparks(pos, normal)
	_burst_dust(pos, normal, color, 6, 0.5)
	_flash(pos + normal * 0.2)
	play("clink", pos, -2.0)


func play(key: String, pos: Vector3, volume_db := 0.0, delay := 0.0, pitch := 1.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 6.0
	p.max_distance = 40.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Deeltjes -----------------------------------------------------------------

func _burst_dust(pos: Vector3, normal: Vector3, color: Color, amount: int, scale_mul: float,
		alpha := 0.45, lifetime := 1.6) -> void:
	var p := _one_shot(_dust_material, _dust_draw, amount, lifetime, pos, normal)
	p.explosiveness = 0.85
	p.scale = Vector3.ONE * scale_mul
	var m := _dust_draw.material.duplicate() as StandardMaterial3D
	m.albedo_color = Color(color, alpha)
	p.material_override = m


## Sterretjes rond een vrijgekomen vondst: additief, in de glans van zijn waardeklasse, een paar
## seconden lang (boven het stof uit: ze zitten dicht bij de vondst en het stof komt later).
func _sparkle(pos: Vector3, color: Color, size: float, strength: float, follow: Node3D = null) -> void:
	var p := GPUParticles3D.new()
	p.process_material = _star_material
	p.draw_pass_1 = _star_draw
	p.amount = int(lerpf(10.0, 36.0, clampf(strength - 0.5, 0.0, 1.0)))
	p.lifetime = 0.9
	p.local_coords = false
	var m := _star_draw.material.duplicate() as StandardMaterial3D
	m.albedo_color = Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0)
	p.material_override = m
	# Met de vondst mee (hij springt eruit); de sterretjes zelf blijven in de wereld hangen.
	if follow and is_instance_valid(follow):
		follow.add_child(p)
		p.top_level = false
		p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	else:
		add_child(p)
	p.global_position = pos
	p.global_basis = Basis().scaled(Vector3.ONE * clampf(size * 2.2, 0.6, 1.6))
	p.emitting = true
	var secs := Tuning.get_f("finds", "reveal_sparkle_s", 2.2) * strength
	get_tree().create_timer(secs).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	get_tree().create_timer(secs + 1.2).timeout.connect(p.queue_free)


## Korte uitbarsting sterretjes langs een normaal (erts).
func _sparkle_burst(pos: Vector3, normal: Vector3, color: Color, amount: int) -> void:
	var p := _one_shot(_star_material, _star_draw, amount, 0.5, pos, normal)
	p.scale = Vector3.ONE * 0.5
	var m := _star_draw.material.duplicate() as StandardMaterial3D
	m.albedo_color = Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
	p.material_override = m


## Kopie van een mesh, verkleind (deeltjes schalen hun mesh niet zelf naar een maat).
static func _scaled(src: Mesh, size: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(src, 0, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO))
	return st.commit()


func _burst_grit(pos: Vector3, normal: Vector3, color: Color, amount: int) -> void:
	var p := _one_shot(_grit_material, _grit_draw, amount, 0.9, pos, normal)
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.25)
	m.roughness = 1.0
	p.material_override = m


func _burst_sparks(pos: Vector3, normal: Vector3) -> void:
	var p := _one_shot(_spark_material, _spark_draw, 26, 0.36, pos, normal)
	# Uitgerekt langs de snelheid, met het vlak naar de camera (geen rechtopstaande staafjes).
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY


func _one_shot(material: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float,
		pos: Vector3, normal: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = material
	p.draw_pass_1 = mesh
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	add_child(p)
	p.global_position = pos + normal * 0.05
	# ParticleProcessMaterial.direction is +X in lokale ruimte: draai X naar de normaal.
	p.global_basis = _basis_x_to(normal)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)
	return p


func _flash(pos: Vector3, color := Color(1.0, 0.7, 0.35), energy := 2.5, seconds := 0.12, light_range := 3.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)
	light.global_position = pos
	var tw := create_tween()
	if seconds > 0.3:
		# Lange gloed (een vondst): kort vol, dan rustig uitdoven.
		tw.tween_interval(seconds * 0.25)
		tw.tween_property(light, "light_energy", 0.0, seconds * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(light, "light_energy", 0.0, seconds)
	tw.tween_callback(light.queue_free)


# --- Steentjes (echte fysica, lokaal) -----------------------------------------

func _spawn_pebble(pos: Vector3, normal: Vector3, color: Color, speed_mul := 1.0) -> void:
	if _pebbles.size() >= MAX_PEBBLES:
		var oldest: RigidBody3D = _pebbles.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var body := RigidBody3D.new()
	body.collision_layer = LAYER_DEBRIS
	body.collision_mask = Layers.TERRAIN | Layers.LIFT
	body.mass = 0.15
	body.continuous_cd = true
	var s := _rng.randf_range(0.05, 0.11)
	# Een echt rotsbrokje (finds.glb: Chunk_0..2), geen kubusje. Botsen gaat met een doosje.
	var dims := Vector3(s, s * _rng.randf_range(0.6, 1.0), s * _rng.randf_range(0.7, 1.3))
	var shape := BoxShape3D.new()
	shape.size = dims * 0.85
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var mesh := MeshInstance3D.new()
	mesh.mesh = FindKinds.chunk(_rng.randi_range(0, 2))
	mesh.scale = dims
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(_rng.randf_range(0.1, 0.35))
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(cs)
	body.add_child(mesh)
	# Fysica: vloeiend tekenen tussen twee ticks (de rest van de effecten staat stil of beweegt zelf).
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(body)
	body.global_position = pos + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1))
	body.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
	body.reset_physics_interpolation()
	var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1)) * 0.9
	body.linear_velocity = (normal + spread).normalized() * _rng.randf_range(1.2, 2.8) * speed_mul
	body.angular_velocity = Vector3(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
	_pebbles.append(body)
	var tw := body.create_tween()
	tw.tween_interval(PEBBLE_LIFETIME)
	tw.tween_property(mesh, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(func() -> void:
		_pebbles.erase(body)
		body.queue_free())


# --- Materialen ---------------------------------------------------------------

func _build_materials() -> void:
	# Stof: zachte, grote vlokken die langzaam uitzetten en wegvallen.
	_dust_material = ParticleProcessMaterial.new()
	_dust_material.direction = Vector3(1, 0, 0)
	_dust_material.spread = 70.0
	_dust_material.initial_velocity_min = 0.4
	_dust_material.initial_velocity_max = 1.6
	_dust_material.gravity = Vector3(0, -0.6, 0)
	_dust_material.damping_min = 1.5
	_dust_material.damping_max = 2.5
	_dust_material.scale_min = 0.4
	_dust_material.scale_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_dust_material.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_dust_material.color_ramp = fade_tex
	_dust_material.angle_min = -180.0
	_dust_material.angle_max = 180.0

	_dust_draw = QuadMesh.new()
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.albedo_texture = _puff_texture()
	dm.roughness = 1.0
	dm.proximity_fade_enabled = true
	dm.proximity_fade_distance = 0.4
	_dust_draw.material = dm

	# Gruis: kleine blokjes die snel wegspatten en vallen.
	_grit_material = ParticleProcessMaterial.new()
	_grit_material.direction = Vector3(1, 0, 0)
	_grit_material.spread = 55.0
	_grit_material.initial_velocity_min = 1.5
	_grit_material.initial_velocity_max = 3.5
	_grit_material.gravity = Vector3(0, -9.8, 0)
	_grit_material.scale_min = 0.5
	_grit_material.scale_max = 1.2
	_grit_material.angular_velocity_min = -400.0
	_grit_material.angular_velocity_max = 400.0
	_grit_draw = _scaled(FindKinds.chunk(1), 0.032)

	# Vonken (gevoel-10): fel en kort, in een kegel rond de normaal (van de wand weg), uitgerekt
	# langs hun snelheid (GPUParticles3D.transform_align, Y langs de snelheid, vlak naar de camera),
	# en onzichtbaar dichter dan ±0,6 m bij de camera (geen neonbalken over het beeld).
	_spark_material = ParticleProcessMaterial.new()
	_spark_material.direction = Vector3(1, 0, 0)
	_spark_material.spread = 38.0
	_spark_material.initial_velocity_min = 3.0
	_spark_material.initial_velocity_max = 6.0
	_spark_material.gravity = Vector3(0, -9.8, 0)
	_spark_material.particle_flag_align_y = true
	_spark_material.scale_min = 0.5
	_spark_material.scale_max = 1.0
	var spark_fade := Gradient.new()
	spark_fade.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	spark_fade.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	var spark_tex := GradientTexture1D.new()
	spark_tex.gradient = spark_fade
	_spark_material.color_ramp = spark_tex
	_spark_draw = QuadMesh.new()
	_spark_draw.size = Vector2(0.011, 0.08)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(4.0, 2.5, 1.2)
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 0.6
	sm.distance_fade_max_distance = 1.0
	_spark_draw.material = sm

	# Sterretjes (glans van een vondst, fonkels van erts): kleine kruisjes die oplichten en doven.
	_star_material = ParticleProcessMaterial.new()
	_star_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_star_material.emission_sphere_radius = 0.28
	_star_material.direction = Vector3(1, 0, 0)
	_star_material.spread = 180.0
	_star_material.initial_velocity_min = 0.05
	_star_material.initial_velocity_max = 0.35
	_star_material.gravity = Vector3(0, 0.15, 0)
	_star_material.scale_min = 0.5
	_star_material.scale_max = 1.3
	_star_material.angle_min = -45.0
	_star_material.angle_max = 45.0
	var twinkle := Curve.new()
	twinkle.add_point(Vector2(0.0, 0.0))
	twinkle.add_point(Vector2(0.2, 1.0))
	twinkle.add_point(Vector2(1.0, 0.0))
	var twinkle_tex := CurveTexture.new()
	twinkle_tex.curve = twinkle
	_star_material.scale_curve = twinkle_tex
	_star_draw = QuadMesh.new()
	_star_draw.size = Vector2(0.07, 0.07)
	var stm := StandardMaterial3D.new()
	stm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	stm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	stm.albedo_texture = _star_texture()
	stm.no_depth_test = false
	_star_draw.material = stm

	# Stoom: trage witte pluimen die opstijgen en uitzetten.
	_steam_material = _dust_material.duplicate() as ParticleProcessMaterial
	_steam_material.direction = Vector3(0, 1, 0)
	_steam_material.spread = 25.0
	_steam_material.initial_velocity_min = 0.3
	_steam_material.initial_velocity_max = 0.7
	_steam_material.gravity = Vector3(0, 0.6, 0)
	_steam_material.scale_min = 0.5
	_steam_material.scale_max = 1.0


## Sterretje: een zacht kruis met een heldere kern.
static func _star_texture() -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5) / (size * 0.5)
			var core := clampf(1.0 - p.length() * 2.2, 0.0, 1.0)
			var cross := clampf(1.0 - absf(p.x) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(p.y), 0.0, 1.0) \
					+ clampf(1.0 - absf(p.y) * 9.0, 0.0, 1.0) * clampf(1.0 - absf(p.x), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(core * core + cross * 0.8, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Vlek voor de verse snede: donker in het midden, rafelige rand.
static func _blotch_texture() -> Texture2D:
	var size := 64
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			# Rafelige rand, maar naar de rand van de doos altijd helemaal weg (geen rechthoeken).
			var edge := clampf((0.85 - d) * 2.5 + noise.get_noise_2d(x, y) * 0.8, 0.0, 1.0)
			edge *= clampf((1.0 - d) / 0.3, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, edge * edge))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Wolkje: ruis maal een zachte radiale afval, zodat stof geen egale schijf wordt.
static func _puff_texture() -> Texture2D:
	var size := 64
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5, y - size * 0.5).length() / (size * 0.5)
			var falloff := clampf(1.0 - d, 0.0, 1.0)
			var cloud := clampf(noise.get_noise_2d(x, y) * 0.9 + 0.55, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, falloff * falloff * cloud))
	return ImageTexture.create_from_image(img)


static func _basis_x_to(dir: Vector3) -> Basis:
	var x := dir.normalized()
	var up := Vector3.UP if absf(x.y) < 0.95 else Vector3.FORWARD
	var z := x.cross(up).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)
