class_name WormVisual
extends Node3D
## Het beeld van de Graafworm, "the Gulper" (GDD §8: "de worm is een segmentketting"). Enkel zichtbaar
## als hij uitvalt, iemand vasthoudt of de Mol raakt; de rest van de tijd zwemt hij onzichtbaar door
## de rots (Worm: tekens).
## Model: assets/models/worm.glb (tools/blender/worm.py): Worm_Head met kaken (Jaw_0..) rond een
## vlezige muil, Worm_Segment (een gepantserde ring met gloeiende naden), Worm_Tail. De kop volgt een
## spoor (een polylijn); de segmenten volgen hem op vaste afstand.
## - Uitval: eerst een waarschuwing op de rots waar hij doorkomt (barsten die gloeien, een stofgeiser,
##   springende steentjes), dan barst de rots open met scherven en komt de kop traag naar buiten, snel
##   door de ruimte, en weer de rots in (binnen2-02).
## - Grijpen: de kop sleurt zijn prooi over de vloer; het lijf ploegt eronder (stof en steentjes langs
##   het spoor). Daarna duikt hij de vloer in.
## - De Mol: de kop stopt tegen de romp (binnen2-01: niet erdoor), bijt (climax) en trekt terug de
##   grond in, weg van de Mol.

const MODEL_PATH := "res://assets/models/worm.glb"
const SEGMENTS := 9
const SPACING := 1.45
## Lengte van het lijf achter de kop (m).
const BODY_LEN := SPACING * (SEGMENTS + 1.5)

enum Show { NONE, LUNGE, GRAB, DIVE, BITE, RAM, HOLD }

var worm: Worm

var _root: Node3D
var _head: Node3D
var _jaws: Array[Node3D] = []
var _segs: Array[Node3D] = []
var _tail: Node3D
var _light: OmniLight3D
var _poly := PackedVector3Array()
var _cum := PackedFloat32Array()
var _show := Show.NONE
var _hs := 0.0 # booglengte van de kop op het spoor
var _s0 := 0.0 # uitval: waar de Bézier begint
var _s3 := 0.0 # en eindigt
var _t := -1.0
var _tel := 1.6
var _burst := 1.9
var _speed := 6.0
var _emerge := Vector3.ZERO
var _normal := Vector3.UP
var _exit := Vector3.ZERO
var _phase := 0 # uitval: 0 = waarschuwing, 1 = boog
var _cracks: Decal
var _glow_decal: Decal
var _glow: OmniLight3D
var _geyser: GPUParticles3D
var _exit_burst_done := false
var _short := false
var _sink := false # grijpen: het lijf achter de kop zit in de vloer
var _end_s := 0.0 # waar de kop stopt (grijpen, rammen)
var _hold_t := 0.0
var _furrow_t := 0.0
var _pebble_t := 0.0
var _bite_local := Vector3.ZERO
var _bite_normal := Vector3.UP
var _chomp := 0.0
var _flinch := Vector3.ZERO
var _jerk := 0.0
var _flash := 0.0


func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Chain"
	_root.top_level = true
	add_child(_root)
	_build()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.42, 0.12)
	_light.omni_range = 8.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_head.add_child(_light)
	_light.position = Vector3(0.0, 0.0, -1.8)
	_cracks = Decal.new()
	_cracks.name = "Cracks"
	_cracks.texture_albedo = Worm._crack_texture()
	_cracks.modulate = Color(0.1, 0.06, 0.04)
	_cracks.visible = false
	_cracks.top_level = true
	add_child(_cracks)
	# De gloed door de barsten: enkel licht (emissie), oranjerood, en een lamp die de rots kleurt.
	_glow_decal = Decal.new()
	_glow_decal.name = "CrackGlow"
	_glow_decal.texture_emission = Worm._crack_texture()
	_glow_decal.emission_energy = 0.0
	_glow_decal.modulate = Color(1.0, 0.38, 0.1)
	_glow_decal.visible = false
	_glow_decal.top_level = true
	add_child(_glow_decal)
	_glow = OmniLight3D.new()
	_glow.name = "CrackLight"
	_glow.light_color = Color(1.0, 0.36, 0.1)
	_glow.omni_range = 6.0
	_glow.light_energy = 0.0
	_glow.shadow_enabled = false
	_glow.top_level = true
	add_child(_glow)
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
	for i in 6:
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
	_show = Show.NONE
	_root.visible = false
	_cracks.visible = false
	_glow_decal.visible = false
	if _glow:
		_glow.light_energy = 0.0
	if _light:
		_light.light_energy = 0.0
	set_process(false)


## Waar de kop nu is, als hij boven de grond in beeld is (anders Vector3.INF).
func head_world() -> Vector3:
	if not _root.visible or _show in [Show.NONE, Show.HOLD]:
		return Vector3.INF
	return _head.global_position


# --- Plannen (van Worm, op elk peer) ---------------------------------------------------------------

## Een uitval op elk peer (zelfde plan): eerst de waarschuwing op `emerge` (de rots met normaal
## `normal`: de vloer, of een wand bij een doorbraak), dan de boog.
func play_lunge(path: Array, emerge: Vector3, normal: Vector3, exit: Vector3, tel: float, burst: float) -> void:
	_short = false
	_sink = false
	_set_path_bezier(path, burst)
	_show = Show.LUNGE
	_emerge = emerge
	_normal = normal.normalized() if normal.length() > 0.1 else Vector3.UP
	_exit = exit
	_tel = tel
	_burst = burst
	_t = 0.0
	_phase = 0
	_exit_burst_done = false
	_root.visible = false
	set_process(true)
	# Waarschuwing: barsten groeien op de rots en gloeien op, stof spuit eruit, de grond rommelt.
	var b := _basis_up(_normal)
	_cracks.global_transform = Transform3D(b, emerge + _normal * 0.8)
	_cracks.size = Vector3(0.5, 2.5, 0.5)
	_cracks.modulate.a = 0.0
	_cracks.visible = true
	_glow_decal.global_transform = _cracks.global_transform
	_glow_decal.size = _cracks.size
	_glow_decal.emission_energy = 0.0
	_glow_decal.visible = true
	_glow.global_position = emerge + _normal * 0.5
	_glow.light_energy = 0.0
	_geyser = _dust(emerge, _normal, 70, 2.6, 0.5)
	_geyser.emitting = true


## Grijpen: vanaf waar de kop nu is, het pad over de vloer af aan `speed` m/s.
func play_grab(path: PackedVector3Array, speed: float) -> void:
	# Het spoor: wat het lijf al aflegde (tot de kop), dan het sleeppad.
	var keep := PackedVector3Array()
	if _show in [Show.LUNGE, Show.GRAB] and _poly.size() > 1:
		for i in _poly.size():
			if _cum[i] < _hs - 0.3:
				keep.append(_poly[i])
	else:
		# Geen uitval gezien (late joiner): het lijf komt recht uit de vloer onder het begin.
		for i in 6:
			keep.append(path[0] + Vector3.DOWN * (BODY_LEN + 2.0) * (1.0 - i / 6.0))
	keep.append_array(path)
	_set_poly(keep)
	_hs = _arclen_at(keep.size() - path.size())
	_end_s = _cum[_cum.size() - 1]
	_speed = speed
	_show = Show.GRAB
	_sink = true
	_short = true
	_t = 0.0
	_root.visible = true
	_cracks.visible = false
	_glow_decal.visible = false
	_glow.light_energy = 0.0
	set_process(true)


## Losgelaten: de kop duikt bij `at` de vloer in, het lijf erachteraan.
func end_grab(at: Vector3) -> void:
	if _show != Show.GRAB or _poly.size() < 2:
		stop()
		return
	var fwd := _sample(_hs) - _sample(_hs - 0.8)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.05 else Vector3(1, 0, 0)
	var head := _sample(_hs)
	var pts := PackedVector3Array()
	for i in _poly.size():
		if _cum[i] < _hs - 0.05:
			pts.append(_poly[i])
	pts.append(head)
	pts.append(head + fwd * 1.0 + Vector3.DOWN * 0.6)
	pts.append(head + fwd * 1.8 + Vector3.DOWN * 2.5)
	pts.append(head + fwd * 2.2 + Vector3.DOWN * (4.0 + BODY_LEN))
	var s_head := 0.0
	for i in range(1, pts.size() - 3):
		s_head += pts[i].distance_to(pts[i - 1])
	_set_poly(pts)
	_hs = s_head
	_end_s = _cum[_cum.size() - 1]
	_speed = 7.0
	_show = Show.DIVE
	_burst_at(at + Vector3.DOWN * HOLD_OFFSET, Vector3.UP, 1.1)


const HOLD_OFFSET := 0.9


## De Mol rammen midden in de dienst: de kop komt uit de grond naast de Mol, stopt tegen de romp
## (`at`, normaal `normal` naar buiten), klapt de kaken dicht en trekt terug de grond in.
func play_ram(at: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	var flat := Vector3(n.x, 0.0, n.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3(1, 0, 0)
	var stop_at := at + n * 0.9
	var pts := PackedVector3Array()
	pts.append(stop_at + flat * 3.6 + Vector3.DOWN * (3.0 + BODY_LEN))
	pts.append(stop_at + flat * 3.6 + Vector3.DOWN * 3.0)
	pts.append(stop_at + flat * 2.6 + Vector3.DOWN * 1.2)
	pts.append(stop_at + flat * 1.2 + Vector3.DOWN * 0.2)
	pts.append(stop_at)
	_set_poly(pts)
	_hs = _cum[1]
	_end_s = _cum[_cum.size() - 1]
	_speed = 14.0
	_show = Show.RAM
	_sink = false
	_short = true
	_hold_t = 0.0
	_t = 0.0
	_root.visible = true
	set_process(true)
	_burst_at(stop_at + flat * 2.4 + Vector3.DOWN * 1.0, Vector3.UP, 1.0)
	_sparks(at, n)


## De climax: de kop bijt in de romp van de Mol (`local`, `normal`: t.o.v. de Mol) tot end_bite.
func play_bite(local: Vector3, normal: Vector3) -> void:
	_bite_local = local
	_bite_normal = normal.normalized()
	_show = Show.BITE
	_sink = false
	_short = true
	_t = 0.0
	_root.visible = true
	_rebuild_bite()
	_hs = _cum[_cum.size() - 1]
	set_process(true)
	var mol: Mol = worm.game.mol if worm and worm.game else null
	if mol and mol.body:
		var at := mol.body.global_transform * local
		var n := mol.body.global_basis * _bite_normal
		_sparks(at, n)
		_burst_at(at + n * 2.0 + Vector3.DOWN * 1.5, Vector3.UP, 1.2)


## De beet is voorbij: de kop trekt terug langs zijn lijf de grond in (het spoor blijft liggen, de Mol
## rijdt verder).
func end_bite() -> void:
	if _show != Show.BITE:
		return
	_show = Show.DIVE
	_speed = -7.0
	_end_s = -BODY_LEN - 2.0


## Een slag op de kop: hij deinst terug, vonken en een flits.
func flinch(at: Vector3) -> void:
	if _show in [Show.NONE, Show.HOLD]:
		return
	var away := _head.global_position - at
	_flinch = (away.normalized() if away.length() > 0.05 else Vector3.UP) * 0.5
	_flash = 1.0
	_sparks(at, (at - _head.global_position).normalized())
	if worm and worm.game:
		worm.game.fx.grit_puff(at, Vector3.UP, Color(0.5, 0.3, 0.25))


## Het slachtoffer spartelt of de piloot schudt: de kop schokt.
func jerk() -> void:
	_jerk = 1.0


## Previews (ter goedkeuring): de worm stil op een plek van zijn boog (`u` 0..1, kaken `open` 0..1).
func hold_pose(path: Array, u: float, open := 0.6) -> void:
	_short = true
	_sink = false
	_set_path_bezier(path, 1.0)
	_show = Show.HOLD
	_root.visible = true
	set_process(false)
	_hs = _s0 + (_s3 - _s0) * u
	_place_chain(_hs)
	_open_jaws(open)
	_light.light_energy = 2.2


# --- Spoor ----------------------------------------------------------------------------------------

func _set_path_bezier(path: Array, burst: float) -> void:
	# Het spoor: een stuk recht de rots in vóór het begin (daar zit het lijf nog), de Bézier, en een
	# stuk recht de rots in na het einde (daar duikt het lijf weg).
	var pts := PackedVector3Array()
	var start_dir := ((path[1] as Vector3) - (path[0] as Vector3)).normalized()
	var end_dir := ((path[3] as Vector3) - (path[2] as Vector3)).normalized()
	var ext := BODY_LEN + 2.0
	for i in 8:
		pts.append((path[0] as Vector3) - start_dir * ext * (1.0 - float(i) / 8.0))
	for i in 41:
		pts.append(bezier(path, float(i) / 40.0))
	for i in range(1, 9):
		pts.append((path[3] as Vector3) + end_dir * ext * float(i) / 8.0)
	_set_poly(pts)
	_s0 = _cum[8]
	_s3 = _cum[48]
	_speed = (_s3 - _s0) / maxf(burst, 0.1)
	_hs = _s0


func _set_poly(pts: PackedVector3Array) -> void:
	_poly = pts
	_cum = PackedFloat32Array()
	_cum.resize(_poly.size())
	if _poly.is_empty():
		return
	_cum[0] = 0.0
	for i in range(1, _poly.size()):
		_cum[i] = _cum[i - 1] + _poly[i].distance_to(_poly[i - 1])


func _arclen_at(index: int) -> float:
	return _cum[clampi(index, 0, _cum.size() - 1)]


## De beet: van diep in de grond schuin omhoog naar de romp, elke frame opnieuw (de Mol rijdt).
func _rebuild_bite() -> void:
	var mol: Mol = worm.game.mol if worm and worm.game else null
	if mol == null or mol.body == null:
		return
	var at := mol.body.global_transform * _bite_local
	var n := (mol.body.global_basis * _bite_normal).normalized()
	var flat := Vector3(n.x, 0.0, n.z)
	flat = flat.normalized() if flat.length() > 0.1 else Vector3(1, 0, 0)
	var head := at + n * 0.9
	var pts := PackedVector3Array()
	pts.append(head + flat * 3.4 + Vector3.DOWN * (3.5 + BODY_LEN))
	pts.append(head + flat * 3.4 + Vector3.DOWN * 3.5)
	pts.append(head + flat * 2.8 + Vector3.DOWN * 1.6)
	pts.append(head + flat * 1.6 + Vector3.DOWN * 0.4)
	pts.append(head + n * 0.6)
	pts.append(head)
	_set_poly(pts)


func _sample(s: float) -> Vector3:
	if _poly.is_empty():
		return Vector3.ZERO
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


func _place(n: Node3D, s: float, sink: float) -> void:
	var p := _sample(s)
	var ahead := _sample(s + 0.6)
	var dir := ahead - p
	if dir.length() < 0.01:
		dir = p - _sample(s - 0.6)
	if dir.length() < 0.01:
		return
	p.y -= sink
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	n.global_transform = Transform3D(Basis.looking_at(dir.normalized(), up), p)


## De ketting op het spoor: de kop op `hs`, de segmenten erachter. Bij grijpen zakt het lijf achter de
## kop de vloer in (het ploegt eronder).
func _place_chain(hs: float) -> void:
	_place(_head, hs, 0.0)
	_head.global_position += _flinch + Vector3(sin(_t * 47.0), cos(_t * 39.0), sin(_t * 31.0)) * 0.12 * _jerk
	for i in _segs.size():
		var back := 0.62 + SPACING * i
		_place(_segs[i], hs - back, _sink_at(back))
	var tb := 0.62 + SPACING * (_segs.size() - 1) + 0.7
	_place(_tail, hs - tb, _sink_at(tb))


func _sink_at(back: float) -> float:
	if not _sink:
		return 0.0
	return smoothstep(0.8, 4.5, back) * 1.7


func _open_jaws(open: float) -> void:
	for j in _jaws:
		var rest: Transform3D = j.get_meta("rest")
		# Elke kaak klapt naar buiten rond zijn raaklijn aan de muil (vooruit × naar buiten).
		var radial := Vector3(rest.origin.x, rest.origin.y, 0.0)
		radial = radial.normalized() if radial.length() > 0.01 else Vector3.UP
		var axis := Vector3(0, 0, -1).cross(radial).normalized()
		j.transform = Transform3D(Basis(axis, deg_to_rad(62.0) * open) * rest.basis, rest.origin)


static func _basis_up(n: Vector3) -> Basis:
	var y := n.normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


# --- Verloop --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _show == Show.NONE:
		return
	_t += delta
	_flinch = _flinch.lerp(Vector3.ZERO, minf(1.0, delta * 9.0))
	_jerk = maxf(0.0, _jerk - delta * 4.0)
	_flash = maxf(0.0, _flash - delta * 4.0)
	match _show:
		Show.LUNGE:
			_lunge_step(delta)
		Show.GRAB:
			_hs = minf(_end_s, _hs + _speed * delta)
			_place_chain(_hs)
			_chomp += delta
			_open_jaws(0.28 + 0.12 * sin(_chomp * 9.0))
			_light.light_energy = 2.4 + 2.0 * _flash
			# Het lijf ploegt door de vloer: stof en steentjes achter de kop.
			_furrow_t -= delta
			if _furrow_t <= 0.0 and worm and worm.game:
				_furrow_t = 0.22
				var behind := _sample(_hs - 1.6) + Vector3.DOWN * HOLD_OFFSET
				var col: Color = Strata.DEBRIS_COLORS[worm.game.terrain.layer_at(behind + Vector3.DOWN * 0.3)]
				worm.game.fx.grit_puff(behind, Vector3.UP, col)
				hop_pebble(behind + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6)), col, 2.4)
			_local_rumble(_head.global_position, 0.8)
		Show.DIVE:
			_hs += _speed * delta
			_place_chain(_hs)
			_open_jaws(0.0)
			_light.light_energy = maxf(0.0, _light.light_energy - delta * 4.0)
			var gone := _hs - BODY_LEN - 1.0 > _end_s if _speed > 0.0 else _hs < _end_s
			if gone or _t > 8.0:
				stop()
		Show.BITE:
			_rebuild_bite()
			_hs = _cum[_cum.size() - 1]
			_place_chain(_hs)
			_chomp += delta
			_open_jaws(0.15 + 0.5 * absf(sin(_chomp * 5.5)))
			_light.light_energy = 2.4 + 2.0 * _flash
			_local_rumble(_head.global_position, 0.7)
		Show.RAM:
			if _hs < _end_s:
				_hs = minf(_end_s, _hs + _speed * delta)
				_open_jaws(0.7)
			else:
				_hold_t += delta
				_open_jaws(maxf(0.0, 0.7 - _hold_t * 5.0))
				if _hold_t > 0.35:
					_show = Show.DIVE
					_speed = -8.0
					_end_s = -1.0
			_place_chain(_hs)
			_light.light_energy = 2.4


func _lunge_step(delta: float) -> void:
	var tel := _tel
	if _t < tel:
		# Waarschuwing: de barsten groeien en gloeien op, steentjes springen, het stof spuit.
		var k := _t / maxf(tel, 0.01)
		_cracks.size = Vector3(0.6, 2.5, 0.6).lerp(Vector3(4.2, 2.5, 4.2), k)
		_cracks.modulate.a = k
		_glow_decal.size = _cracks.size
		_glow_decal.emission_energy = 6.0 * k * k * (0.75 + 0.25 * sin(_t * 23.0))
		_glow.light_energy = 3.5 * k * k
		_glow.omni_range = 3.0 + 4.0 * k
		_local_rumble(_emerge, 0.6 + 0.7 * k)
		_pebble_t -= delta
		if _pebble_t <= 0.0 and worm and worm.game:
			_pebble_t = lerpf(0.25, 0.05, k)
			var col: Color = Strata.DEBRIS_COLORS[worm.game.terrain.layer_at(_emerge - _normal * 0.4)]
			var b := _basis_up(_normal)
			var off := b * Vector3(randf_range(-1.4, 1.4), 0.1, randf_range(-1.4, 1.4)) * (0.4 + k)
			hop_pebble(_emerge + off, col, 1.6 + 3.0 * k)
		return
	if _phase == 0:
		_phase = 1
		_root.visible = true
		# De rots barst open: een kegel scherven, stof, een flits van de gloed.
		_burst_at(_emerge, _normal, 1.6)
		_shards(_emerge, _normal, 14)
		_glow.light_energy = 6.0
		if _geyser:
			_geyser.emitting = false
			get_tree().create_timer(3.0).timeout.connect(_geyser.queue_free)
			_geyser = null
	var u := (_t - tel) / maxf(_burst, 0.1)
	var s := _s0 + (_s3 - _s0) * Worm.lunge_param(minf(u, 1.0)) + (_speed * (_t - tel - _burst) if u > 1.0 else 0.0)
	_hs = s
	_place_chain(s)
	# Kaken: open tijdens de boog, dicht als hij wegduikt.
	var open := 0.0
	if u < 1.0:
		open = smoothstep(0.0, 0.25, u) * (1.0 - 0.6 * smoothstep(0.75, 1.0, u))
	_open_jaws(open)
	_light.light_energy = 2.6 * (smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(1.0, 1.3, u))) + 2.0 * _flash
	_glow.light_energy = maxf(0.0, _glow.light_energy - delta * 5.0)
	_glow_decal.emission_energy = maxf(0.0, _glow_decal.emission_energy - delta * 6.0)
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


# --- Effecten (lokaal) ----------------------------------------------------------------------------

## Stof, steentjes en een paar brokken waar hij uit of in de rots gaat.
func _burst_at(at: Vector3, normal: Vector3, size: float) -> void:
	if worm == null or worm.game == null:
		return
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


## Een kegel scherven uit de rots (de vloer barst open). Enkel beeld, lokaal.
func _shards(at: Vector3, normal: Vector3, count: int) -> void:
	if worm == null or worm.game == null:
		return
	var col: Color = Strata.DEBRIS_COLORS[worm.game.terrain.layer_at(at - normal * 0.4)]
	var b := _basis_up(normal)
	for i in count:
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = Layers.TERRAIN
		rb.mass = 2.0
		var sz := Vector3(randf_range(0.12, 0.34), randf_range(0.08, 0.2), randf_range(0.12, 0.3))
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sz
		cs.shape = sh
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = sz
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col.darkened(randf_range(0.0, 0.35))
		mat.roughness = 0.9
		mi.material_override = mat
		rb.add_child(mi)
		add_child(rb)
		var a := randf() * TAU
		var r := randf_range(0.2, 1.2)
		rb.global_position = at + b * Vector3(cos(a) * r, 0.25, sin(a) * r)
		rb.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var out := b * Vector3(cos(a) * randf_range(0.6, 2.2), randf_range(4.0, 7.5), sin(a) * randf_range(0.6, 2.2))
		rb.linear_velocity = out
		rb.angular_velocity = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		get_tree().create_timer(randf_range(3.0, 4.5)).timeout.connect(rb.queue_free)


## Vonken en gruis waar de kop de romp van de Mol raakt.
func _sparks(at: Vector3, normal: Vector3) -> void:
	if worm == null or worm.game == null:
		return
	worm.game.fx.clink(at, normal, Color(0.55, 0.5, 0.42))
	worm.game.fx.grit_puff(at, normal, Color(0.45, 0.38, 0.3))


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
