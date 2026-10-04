class_name RoestbolDustDevil
extends Node3D
## Een stofduivel op Roestbol (docs/research/planeten.md §4.1): een getwiste kolom van stof
## (roestbol_dust_devil.gdshader: transparant, zonder schaduw) en zijn lange schaduw op de grond (een
## decal, van boven het duidelijkste teken). Hij loopt heen en weer over het stuk voor de kop van zijn
## spoor. Enkel decor: elke peer laat hem zelf lopen (geen netwerk nodig).

const SHADER := preload("res://src/world/roestbol_dust_devil.gdshader")
const SPEED := 4.5 # m/s
const HIDE_M := 1250.0 # de hub hangt hoger: daar niet tekenen

## Eén schaduwtextuur voor alle stofduivels (een keer per sessie gemaakt).
static var _shadow_tex: ImageTexture

var _path := PackedVector3Array()
var _dist := PackedFloat32Array() # afstand langs het pad per punt
var _t := 0.0


## `path`: punten op de grond (wereld), `height`: hoogte van de kolom, `to_sun`: richting naar de zon.
func setup(path: PackedVector3Array, height: float, to_sun: Vector3, devil_seed: int) -> void:
	_path = path
	_dist.resize(path.size())
	var acc := 0.0
	for i in path.size():
		if i > 0:
			acc += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
		_dist[i] = acc
	var rng := RandomNumberGenerator.new()
	rng.seed = devil_seed
	_t = rng.randf() * acc * 2.0
	var r0 := rng.randf_range(2.5, 4.0)
	var r1 := height * rng.randf_range(0.14, 0.19)
	var col := MeshInstance3D.new()
	col.name = "Column"
	col.mesh = _tube(height, r0, r1)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("height", height)
	mat.set_shader_parameter("seed", float(devil_seed % 97) * 0.37)
	mat.set_shader_parameter("sun_dir", to_sun)
	col.material_override = mat
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.visibility_range_end = HIDE_M
	add_child(col)
	# De schaduw: zo lang als de zon laag staat, weg van de zon.
	var flat := Vector2(-to_sun.x, -to_sun.z)
	if flat.length() < 0.01:
		return
	flat = flat.normalized()
	var elev := asin(clampf(to_sun.y, 0.05, 1.0))
	var length := minf(height * 0.85 / tan(elev), 320.0)
	var dec := Decal.new()
	dec.name = "Shadow"
	dec.size = Vector3(r1 * 2.6, 70.0, length)
	if _shadow_tex == null:
		_shadow_tex = _shadow_texture(0.16)
	dec.texture_albedo = _shadow_tex
	dec.modulate = Color(0.1, 0.05, 0.04, 0.78)
	dec.albedo_mix = 1.0
	dec.upper_fade = 0.15
	dec.lower_fade = 0.15
	dec.distance_fade_enabled = true
	dec.distance_fade_begin = HIDE_M - 250.0
	dec.distance_fade_length = 200.0
	var z := Vector3(flat.x, 0.0, flat.y)
	var x := Vector3.UP.cross(z).normalized()
	dec.transform = Transform3D(Basis(x, Vector3.UP, z), z * length * 0.5)
	add_child(dec)
	_place()


func _process(delta: float) -> void:
	_t += delta * SPEED
	_place()


## Heen en weer over het pad (pingpong), op de hoogte van de grond.
func _place() -> void:
	if _path.size() < 2:
		return
	var total := _dist[_dist.size() - 1]
	var u := pingpong(_t, total)
	var i := 0
	while i < _dist.size() - 2 and _dist[i + 1] < u:
		i += 1
	var seg := maxf(_dist[i + 1] - _dist[i], 0.001)
	position = _path[i].lerp(_path[i + 1], clampf((u - _dist[i]) / seg, 0.0, 1.0))


## Een open buis die naar boven breder wordt (16 zijden, 12 ringen).
static func _tube(height: float, r0: float, r1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 16
	var rings := 12
	var ring := func(k: int, i: int) -> Vector3:
		var h := float(k) / rings
		var r := lerpf(r0, r1, pow(h, 1.4))
		var a := TAU * i / seg
		return Vector3(cos(a) * r, h * height - 1.0, sin(a) * r)
	for k in rings:
		for i in seg:
			var a: Vector3 = ring.call(k, i)
			var b: Vector3 = ring.call(k, i + 1)
			var c: Vector3 = ring.call(k + 1, i + 1)
			var d: Vector3 = ring.call(k + 1, i)
			for v: Vector3 in [a, b, c, a, c, d]:
				st.set_normal(Vector3(v.x, 0.0, v.z).normalized())
				st.add_vertex(v)
	return st.commit()


## Zachte schaduw van een kolom: smal aan de voet (v = 0), breder naar boven, uitdovend aan het eind.
static func _shadow_texture(base_w: float) -> ImageTexture:
	var w := 32
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var v := float(y) / (h - 1)
		var half := lerpf(base_w, 1.0, pow(v, 1.2)) * 0.5
		var dens := smoothstep(0.0, 0.04, v) * (1.0 - smoothstep(0.55, 1.0, v) * 0.9)
		for x in w:
			var u := absf(float(x) / (w - 1) - 0.5)
			var a := dens * (1.0 - smoothstep(half * 0.45, half, u))
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
