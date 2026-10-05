class_name SpectatorDrone
extends Node3D
## De spookdrone van een kapotte robot, zoals de anderen hem zien (GDD §6: "Ben je volledig kapot,
## dan kijk je mee als spookdrone"). Een bolletje in de spelerskleur, half doorzichtig, met een
## cyaan oog, twee rotortjes en een knipperlicht. Hij kan piepen en knipperen (E), niet praten
## (plezier-en-design §9: dat is de grap). Zweeft en wiebelt; hij botst nergens mee.

var _body: MeshInstance3D
var _eye: StandardMaterial3D
var _blink: StandardMaterial3D
var _light: OmniLight3D
var _rotors: Array[MeshInstance3D] = []
var _t := 0.0
var _beep := 0.0


func setup(color: Color) -> void:
	_body = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.24
	s.height = 0.4
	s.radial_segments = 20
	s.rings = 10
	_body.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	m.rim = 0.8
	_body.material_override = m
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.position.y = 1.0
	add_child(_body)
	# Oog: een cyaan schermpje vooraan (zoals het gezicht van de robot).
	var eye := MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.2, 0.09, 0.03)
	eye.mesh = q
	_eye = StandardMaterial3D.new()
	_eye.albedo_color = Color(0.02, 0.03, 0.04)
	_eye.emission_enabled = true
	_eye.emission = Color(0.35, 0.95, 1.0)
	_eye.emission_energy_multiplier = 3.0
	eye.material_override = _eye
	eye.position = Vector3(0.0, 0.02, -0.21)
	_body.add_child(eye)
	# Twee rotortjes opzij.
	for side in [-1.0, 1.0]:
		var r := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.13
		c.bottom_radius = 0.13
		c.height = 0.015
		r.mesh = c
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.85, 0.88, 0.92, 0.35)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r.material_override = rm
		r.position = Vector3(side * 0.3, 0.08, 0.0)
		_body.add_child(r)
		_rotors.append(r)
	# Knipperlicht bovenop.
	var tip := MeshInstance3D.new()
	var ts := SphereMesh.new()
	ts.radius = 0.04
	ts.height = 0.08
	tip.mesh = ts
	_blink = StandardMaterial3D.new()
	_blink.albedo_color = Color(1.0, 0.2, 0.1)
	_blink.emission_enabled = true
	_blink.emission = Color(1.0, 0.2, 0.08)
	tip.material_override = _blink
	tip.position = Vector3(0.0, 0.22, 0.0)
	_body.add_child(tip)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.9, 1.0)
	_light.omni_range = 3.0
	_light.light_energy = 0.5
	_light.shadow_enabled = false
	_body.add_child(_light)


## Piepen en knipperen (de drone mag niet praten).
func beep() -> void:
	_beep = 1.0


func _process(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	_beep = maxf(0.0, _beep - delta * 1.5)
	_body.position.y = 1.0 + sin(_t * 2.1) * 0.06
	_body.rotation.z = sin(_t * 1.3) * 0.12
	for r in _rotors:
		r.rotate_y(delta * 40.0)
	var on := fmod(_t, 1.2) < 0.15 or (_beep > 0.0 and fmod(_t, 0.16) < 0.08)
	_blink.emission_energy_multiplier = 6.0 if on else 0.3
	_eye.emission_energy_multiplier = 3.0 + _beep * 6.0
	_light.light_energy = 0.5 + _beep * 2.5
