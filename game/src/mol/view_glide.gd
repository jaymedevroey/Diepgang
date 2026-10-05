class_name ViewGlide
extends Node
## Instappen en uitstappen in de Mol zonder harde knip (gevoel-20, gevoel-14): de speler staat meteen
## op zijn nieuwe plek (botsvormen, tests), maar zijn camera glijdt er in `seconds` naartoe vanaf
## waar hij was. Een verschuiving van de camera t.o.v. zijn ouder (de CamRig van de speler), die
## uitdooft; enkel beeld. De CamRig zet het oog pas in de volgende _process op de nieuwe plek
## (Player._update_rig, process_priority −100): daarom meten we daar, niet bij de start.
## Telt bij de positie van de camera op (en haalt het eigen deel van de vorige frame weg), zodat het
## samengaat met wat anders de camera verschuift.

var camera: Camera3D
var _offset := Vector3.ZERO # in de ruimte van de ouder van de camera (het hoofd)
var _applied := Vector3.ZERO
var _t := 1.0
var _dur := 0.3
var _arc := Vector3.ZERO # in de ruimte van de ouder: een boogje omhoog halverwege (over de rugleuning)
var _from := Vector3.ZERO
var _arc_m := 0.0
var _pending := false


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
	_from = from_world
	_arc_m = arc_m
	_dur = maxf(0.05, seconds)
	_t = 0.0
	_pending = true


func _process(delta: float) -> void:
	if camera == null:
		return
	if _pending:
		# Het oog staat nu op zijn nieuwe plek: van daar terug naar waar de camera was.
		_pending = false
		var parent := camera.get_parent() as Node3D
		var now_world := camera.global_position - parent.global_basis * _applied
		var d := _from - now_world
		if d.length() > 4.0: # een sprong (respawn, de hub): niet glijden
			d = Vector3.ZERO
		_offset = parent.global_basis.inverse() * d
		_arc = parent.global_basis.inverse() * Vector3(0.0, _arc_m, 0.0) if d != Vector3.ZERO else Vector3.ZERO
	else:
		_t = minf(1.0, _t + delta / _dur)
	_apply()


func _apply() -> void:
	var k := 1.0 - smoothstep(0.0, 1.0, _t)
	var want := _offset * k + _arc * sin(_t * PI)
	camera.position += want - _applied
	_applied = want
