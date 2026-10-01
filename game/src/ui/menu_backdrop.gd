class_name MenuBackdrop
extends Node3D
## Levende achtergrond van het hoofdmenu (zoals het ruimteschip in DRG of het vliegtuigwrak in PEAK):
## de Mol geparkeerd aan de rand van de put, klep open, lampen aan, rook, stof in de lichtbundels,
## en een camera die traag rondzweeft. Decor: tools/blender/menu_set.py.

const SET := preload("res://assets/models/menu_set.glb")
## Camerastanden: [positie, kijkpunt]. Het menu staat links in beeld, de Mol rechts.
const SHOTS := {
	"main": [Vector3(-12.5, 0.4, -15.5), Vector3(0.5, -0.8, -3.0)],
	"settings": [Vector3(-7.5, 3.4, -14.0), Vector3(1.0, 0.0, -4.0)],
	"join": [Vector3(-10.0, -0.9, 9.5), Vector3(0.5, -1.6, 2.5)],
}

var camera: Camera3D
var mol: MolVisual
var _from := Transform3D()
var _to := Transform3D()
var _blend := 1.0
var _time := 0.0
var _shot := "main"


func _ready() -> void:
	var set_root := SET.instantiate()
	add_child(set_root)
	for mi: MeshInstance3D in set_root.find_children("*", "MeshInstance3D", true, false):
		_apply_set_materials(mi)
	var anchors := {}
	for n in set_root.find_children("*", "Node3D", true, false):
		anchors[n.name] = n

	mol = MolVisual.new()
	mol.lights_on = true
	mol.beacons = true
	mol.ramp_open = true
	mol.feed_active = false
	add_child(mol)

	# Werflamp op de mast: warme bundel met schaduw, door de mist zichtbaar.
	var flood := SpotLight3D.new()
	flood.light_color = Color(1.0, 0.78, 0.5)
	flood.light_energy = 9.0
	flood.spot_range = 45.0
	flood.spot_angle = 26.0
	flood.spot_angle_attenuation = 0.6
	flood.shadow_enabled = true
	flood.light_volumetric_fog_energy = 2.0
	(anchors["Flood_Light"] as Node3D).add_child(flood)
	flood.position = Vector3(0, 0, -0.9) # vóór de lampkop: in de behuizing zou hij zichzelf beschaduwen
	var sign := OmniLight3D.new()
	sign.light_color = Color(1.0, 0.8, 0.55)
	sign.light_energy = 1.4
	sign.omni_range = 4.0
	(anchors["Sign_Light"] as Node3D).add_child(sign)
	# Koud maanlicht van linksboven: silhouetten tegen de donkere lucht.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	moon.rotation = Vector3(deg_to_rad(-28), deg_to_rad(150), 0) # van achteren: randlicht op de Mol
	add_child(moon)
	# Iets gloeit diep in de put.
	var deep := OmniLight3D.new()
	deep.light_color = Color(1.0, 0.42, 0.12)
	deep.light_energy = 3.0
	deep.omni_range = 34.0
	deep.omni_attenuation = 1.6
	deep.position = Vector3(30.0, -26.0, -2.0)
	add_child(deep)
	_build_dust()

	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.environment = _night_environment()
	camera.make_current()
	var t := _shot_xf("main")
	_from = t
	_to = t
	camera.global_transform = t


## Naar een andere camerastand zweven (bv. bij de instellingen).
func go_to(shot: String) -> void:
	if shot == _shot:
		return
	_shot = shot
	_from = camera.global_transform
	_to = _shot_xf(shot)
	_blend = 0.0


func _process(delta: float) -> void:
	_time += delta
	_blend = minf(1.0, _blend + delta / 2.2)
	var k := _blend * _blend * (3.0 - 2.0 * _blend) # zacht in en uit
	var base := _from.interpolate_with(_to, k)
	# Traag ademen en een beetje rondzweven, zoals een cameraman op een statief in de wind.
	var sway := Vector3(sin(_time * 0.11) * 0.9, sin(_time * 0.17) * 0.25, cos(_time * 0.09) * 0.6)
	var look_sway := Vector3(sin(_time * 0.13) * 0.25, sin(_time * 0.21) * 0.08, 0.0)
	var pos := base.origin + sway
	var target := base.origin - base.basis.z * 12.0 + look_sway
	camera.global_transform = Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


## Eigen omgeving voor de menucamera: zelfde mist en gloed als in het spel, maar met een nachtlucht.
func _night_environment() -> Environment:
	var src: Environment = (get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment).environment if get_parent().has_node("WorldEnvironment") else null
	var env: Environment = src.duplicate() if src else Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://src/ui/night_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.27, 0.24)
	env.ambient_light_energy = 0.35
	env.fog_density = 0.012
	env.volumetric_fog_density = 0.02
	env.glow_intensity = 1.1
	return env


func _shot_xf(shot: String) -> Transform3D:
	var s: Array = SHOTS[shot]
	var pos: Vector3 = s[0]
	var look: Vector3 = s[1]
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


func _apply_set_materials(mi: MeshInstance3D) -> void:
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i)
		var name := src.resource_name if src else ""
		var m: Material = MolVisual.machine_material(name)
		if name in ["Clay", "Rock", "Concrete"]:
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = name != "Concrete"
			s.vertex_color_is_srgb = true # in Blender als sRGB-kleur bedoeld
			s.albedo_color = Color(1, 1, 1) if name != "Concrete" else Color(0.5, 0.48, 0.45)
			s.roughness = 0.95
			m = s
		elif name in ["Lens", "Bulb"]:
			var e := StandardMaterial3D.new()
			e.albedo_color = Color(1.0, 0.85, 0.6)
			e.emission_enabled = true
			e.emission = Color(1.0, 0.8, 0.5)
			e.emission_energy_multiplier = 5.0
			m = e
		if m:
			mi.set_surface_override_material(i, m)


## Stofjes die in het licht zweven.
func _build_dust() -> void:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(9, 4, 9)
	mat.gravity = Vector3(0, -0.02, 0)
	mat.initial_velocity_min = 0.02
	mat.initial_velocity_max = 0.12
	mat.direction = Vector3(1, 0.2, 0.3)
	mat.spread = 180.0
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.4
	mat.turbulence_noise_scale = 3.0
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	mat.color_ramp = rt
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.018)
	var qm := StandardMaterial3D.new()
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.9, 0.75, 0.55)
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	q.material = qm
	p.draw_pass_1 = q
	p.amount = 900
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-20, -8, -20), Vector3(40, 16, 40))
	p.position = Vector3(-2, 0.0, -3)
	add_child(p)
