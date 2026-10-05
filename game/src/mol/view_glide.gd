class_name ViewGlide
extends Node
## Instappen en uitstappen in de Mol zonder harde knip (gevoel-20, gevoel-14): de speler staat meteen
## op zijn nieuwe plek (botsvormen, tests), maar zijn camera glijdt er in `seconds` naartoe vanaf
## waar hij was. Een verschuiving van de camera t.o.v. het hoofd, die uitdooft; enkel beeld.
## Telt bij de positie van de camera op (en haalt het eigen deel van de vorige frame weg), zodat het
## samengaat met wat anders de camera verschuift.

var camera: Camera3D
var _offset := Vector3.ZERO # in de ruimte van de ouder van de camera (het hoofd)
var _applied := Vector3.ZERO
var _t := 1.0
var _dur := 0.3
var _arc := Vector3.ZERO # in de ruimte van de ouder: een boogje omhoog halverwege (over de rugleuning)


## Start een glijbeweging: `from_world` is waar de camera stond vóór de sprong (wereld).
## Aanroepen nadat de speler op zijn nieuwe plek staat.
static func start(player: Node3D, cam: Camera3D, from_world: Vector3, seconds := 0.3, arc_m := 0.0) -> void:
	if cam == null or not cam.is_inside_tree():
		return
	var g := player.get_node_or_null("ViewGlide") as ViewGlide
	if g == null:
		g = ViewGlide.new()
		g.name = "ViewGlide"
		g.camera = cam
		player.add_child(g)
	g._begin(from_world, seconds, arc_m)


func _ready() -> void:
	process_priority = 90 # na de speler zelf, die zijn plek in de stoel elke frame zet


func _begin(from_world: Vector3, seconds: float, arc_m := 0.0) -> void:
	# Waar de camera nu staat zonder onze eigen verschuiving.
	var parent := camera.get_parent() as Node3D
	var now_world := camera.global_position - parent.global_basis * _applied
	var d := from_world - now_world
	if d.length() > 4.0: # een sprong (respawn, de hub): niet glijden
		d = Vector3.ZERO
	_offset = parent.global_basis.inverse() * d
	_arc = parent.global_basis.inverse() * Vector3(0.0, arc_m, 0.0) if d != Vector3.ZERO else Vector3.ZERO
	_dur = maxf(0.05, seconds)
	_t = 0.0
	_apply() # meteen, anders toont het eerste beeld de nieuwe plek al zonder verschuiving


func _process(delta: float) -> void:
	if camera == null:
		return
	_t = minf(1.0, _t + delta / _dur)
	_apply()


func _apply() -> void:
	var k := 1.0 - smoothstep(0.0, 1.0, _t)
	var want := _offset * k + _arc * sin(_t * PI)
	camera.position += want - _applied
	_applied = want
