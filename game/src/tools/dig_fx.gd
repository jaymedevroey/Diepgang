class_name DigFx
extends Node3D
## Lokale, cosmetische effecten van graven: stof, steentjes, vonken en geluid.
## Niets hiervan gaat over het netwerk; enkel terreinbewerkingen worden gesynchroniseerd.

enum Stream { GRIT, SPARKS, DUST }

const LAYER_DEBRIS := 1 << 3
const MAX_PEBBLES := 48
const PEBBLE_LIFETIME := 5.0

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
var _grit_draw: BoxMesh
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


## Houweel raakt graafbare grond.
func impact(pos: Vector3, normal: Vector3, color: Color, pebbles: int) -> void:
	_burst_dust(pos, normal, color, 12, 1.0)
	_burst_grit(pos, normal, color, 14)
	for i in pebbles:
		_spawn_pebble(pos + normal * 0.15, normal, color)
	play("clay", pos, 0.0)
	play("crumble", pos, -9.0, 0.12)


## Houweel of boor raakt een korst: droge tok, bleek stof, geen steentjes.
func crust_hit(pos: Vector3, normal: Vector3, with_sound := true) -> void:
	_burst_dust(pos, normal, CRUST_COLOR, 8, 0.7)
	_burst_grit(pos, normal, CRUST_COLOR, 10)
	if with_sound:
		play("tok", pos, -1.0)


## Korst springt open: brokken in alle richtingen.
func crust_break(pos: Vector3, size: float) -> void:
	for n in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		_burst_dust(pos, n, CRUST_COLOR, 6, 1.0 + size)
		_burst_grit(pos, n, CRUST_COLOR, 10)
	for i in 6:
		_spawn_pebble(pos + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)) * size * 0.6,
				Vector3.UP, CRUST_COLOR)
	play("break", pos, 0.0)


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
			p.amount = 50
			p.lifetime = 0.3
		Stream.DUST:
			p.process_material = _dust_material
			p.draw_pass_1 = _dust_draw
			p.amount = 26
			p.lifetime = 1.4
			p.material_override = _dust_draw.material.duplicate()
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


func play(key: String, pos: Vector3, volume_db := 0.0, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[key]
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 40.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


# --- Deeltjes -----------------------------------------------------------------

func _burst_dust(pos: Vector3, normal: Vector3, color: Color, amount: int, scale_mul: float) -> void:
	var p := _one_shot(_dust_material, _dust_draw, amount, 1.6, pos, normal)
	p.explosiveness = 0.85
	p.scale = Vector3.ONE * scale_mul
	var m := _dust_draw.material.duplicate() as StandardMaterial3D
	m.albedo_color = Color(color, 0.45)
	p.material_override = m


func _burst_grit(pos: Vector3, normal: Vector3, color: Color, amount: int) -> void:
	var p := _one_shot(_grit_material, _grit_draw, amount, 0.9, pos, normal)
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.25)
	m.roughness = 1.0
	p.material_override = m


func _burst_sparks(pos: Vector3, normal: Vector3) -> void:
	_one_shot(_spark_material, _spark_draw, 18, 0.35, pos, normal)


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


func _flash(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.5
	light.omni_range = 3.0
	add_child(light)
	light.global_position = pos
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.12)
	tw.tween_callback(light.queue_free)


# --- Steentjes (echte fysica, lokaal) -----------------------------------------

func _spawn_pebble(pos: Vector3, normal: Vector3, color: Color) -> void:
	if _pebbles.size() >= MAX_PEBBLES:
		var oldest: RigidBody3D = _pebbles.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var body := RigidBody3D.new()
	body.collision_layer = LAYER_DEBRIS
	body.collision_mask = TerrainAPI.COLLISION_LAYER
	body.mass = 0.15
	body.continuous_cd = true
	var s := _rng.randf_range(0.05, 0.11)
	var box := BoxMesh.new()
	box.size = Vector3(s, s * _rng.randf_range(0.6, 1.0), s * _rng.randf_range(0.7, 1.3))
	var shape := BoxShape3D.new()
	shape.size = box.size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(_rng.randf_range(0.1, 0.35))
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(cs)
	body.add_child(mesh)
	add_child(body)
	body.global_position = pos + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1))
	body.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
	var spread := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1), _rng.randf_range(-1, 1)) * 0.9
	body.linear_velocity = (normal + spread).normalized() * _rng.randf_range(1.2, 2.8)
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
	_grit_draw = BoxMesh.new()
	_grit_draw.size = Vector3.ONE * 0.03

	# Vonken: fel, kort, uitgerekt in de bewegingsrichting.
	_spark_material = ParticleProcessMaterial.new()
	_spark_material.direction = Vector3(1, 0, 0)
	_spark_material.spread = 65.0
	_spark_material.initial_velocity_min = 3.0
	_spark_material.initial_velocity_max = 6.5
	_spark_material.gravity = Vector3(0, -9.8, 0)
	_spark_material.particle_flag_align_y = true
	_spark_material.scale_min = 0.6
	_spark_material.scale_max = 1.0
	var spark_fade := Gradient.new()
	spark_fade.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	spark_fade.set_color(1, Color(1.0, 0.35, 0.05, 0.0))
	var spark_tex := GradientTexture1D.new()
	spark_tex.gradient = spark_fade
	_spark_material.color_ramp = spark_tex
	_spark_draw = QuadMesh.new()
	_spark_draw.size = Vector2(0.015, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(4.0, 2.5, 1.2)
	_spark_draw.material = sm


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
