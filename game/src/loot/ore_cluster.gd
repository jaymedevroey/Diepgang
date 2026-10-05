class_name OreCluster
extends StaticBody3D
## Een ertscluster in de rots (OreField). Eigen collider op laag CRUST, zodat houweel en boor hem
## raken zoals een korst. De host houdt de levens bij; elk leven is één eenheid erts.

var cluster_id := -1
var kind: OreKinds.Kind
var hp := 4.0
var max_hp := 4.0

var _mesh: MeshInstance3D
var _pulse: Tween


func setup(id: int, kind_value: OreKinds.Kind, units: int, variant: int) -> void:
	cluster_id = id
	kind = kind_value
	max_hp = units
	hp = units
	name = "Ore%d" % id
	collision_layer = Layers.CRUST
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	_mesh.mesh = OreKinds.mesh(kind, variant)
	_mesh.material_override = OreKinds.material(kind)
	_mesh.visibility_range_end = Tuning.get_f("ore", "draw_distance", 55.0)
	add_child(_mesh)
	var shape := SphereShape3D.new()
	shape.radius = 0.5 # de naalden steken in alle richtingen uit (OreKinds._build)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(0, 0.1, 0)
	add_child(cs)


## Nieuwe levens van de host. Kleiner naarmate hij leger raakt; leeg = weg (geen collider meer).
func set_hp(value: float) -> void:
	var hit := value < hp
	hp = value
	var size := 0.45 + 0.55 * clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	if hp <= 0.0:
		visible = false
		collision_layer = 0
		return
	if not hit or not is_inside_tree():
		_mesh.scale = Vector3.ONE * size
		return
	# Korte puls bij een treffer.
	if _pulse:
		_pulse.kill()
	_mesh.scale = Vector3.ONE * size * 1.12
	_pulse = create_tween()
	_pulse.tween_property(_mesh, "scale", Vector3.ONE * size, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func depleted() -> bool:
	return hp <= 0.0
