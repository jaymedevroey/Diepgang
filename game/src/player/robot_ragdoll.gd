class_name RobotRagdoll
extends Node3D
## Een robot als ragdoll (GDD §6 Neergaan; playtest 2026-10-06: "meer ragdoll"). Zes lichamen uit
## robot.glb (romp, hoofd, twee armen, twee benen), verbonden met kegelgewrichten (Jolt).
## - Host: de romp is dynamisch (de hele pop valt, rolt en botst), tenzij iemand hem draagt of hij in
##   een rijdende Mol ligt: dan zet Rescue de romp kinematisch op zijn plek.
## - Clients: de romp volgt de host (kinematisch, 100 ms achter, zoals een vondst); hoofd, armen en
##   benen slingeren lokaal aan hun gewrichten mee. Zo kost een pop één transform per pakketje, en
##   zwaait hij bij iedereen even los.
## De pop zit op de laag LOOT (het vizier van de handschoen vindt hem); spelers botsen er niet tegen
## (anders duwt hij zijn eigen dragers weg).

const MODEL := preload("res://assets/models/robot.glb")
const FACE_SHADER := preload("res://src/player/robot_face.gdshader")
## Onderdelen: naam in robot.glb, massa (kg), botsvorm [soort, maat, plek t.o.v. het draaipunt].
const PARTS := {
	"Torso": [11.0, ["box", Vector3(0.46, 0.38, 0.42), Vector3(0.0, 0.17, 0.03)]],
	"Head": [4.0, ["box", Vector3(0.6, 0.44, 0.46), Vector3(0.0, 0.23, 0.0)]],
	"Arm_L": [1.6, ["capsule", Vector2(0.075, 0.44), Vector3(0.0, -0.17, 0.0)]],
	"Arm_R": [1.6, ["capsule", Vector2(0.075, 0.44), Vector3(0.0, -0.17, 0.0)]],
	"Leg_L": [2.4, ["capsule", Vector2(0.08, 0.44), Vector3(0.0, -0.19, -0.01)]],
	"Leg_R": [2.4, ["capsule", Vector2(0.08, 0.44), Vector3(0.0, -0.19, -0.01)]],
}
## Gewrichten: onderdeel, as van het gewricht langs het lidmaat (wereld bij rechtop staan), zwaai en
## draaiing (graden).
const JOINTS := [["Head", Vector3.UP, 40.0, 25.0], ["Arm_L", Vector3.DOWN, 110.0, 40.0],
		["Arm_R", Vector3.DOWN, 110.0, 40.0], ["Leg_L", Vector3.DOWN, 70.0, 20.0], ["Leg_R", Vector3.DOWN, 70.0, 20.0]]
## Plek van de romp t.o.v. de voeten (het draaipunt van Torso in robot.glb).
const HIP := 0.4

var peer_id := 0
var torso: RigidBody3D
var bodies: Dictionary = {} # naam -> RigidBody3D
var face: ShaderMaterial
## Kinematische romp (client, of gedragen/vastgesjord bij de host).
var pinned := false

var _snapshots: Array = [] # client: [ontvangsttijd ms, Transform3D, in_mol]


## Bouwt de pop op de plek van een staande robot (`feet`: voeten en kijkrichting), in `color`.
## `dynamic`: de romp simuleert zelf (host); anders volgt hij snapshots (client).
func build(feet: Transform3D, color: Color, dynamic: bool) -> void:
	var model := MODEL.instantiate()
	var rest := {}
	for part: String in PARTS:
		var n := model.find_child(part, true, false) as Node3D
		rest[part] = _model_xf(n, model)
	# Eerst de bladeren loskoppelen (hoofd en armen hangen in robot.glb onder de romp).
	for part: String in ["Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Torso"]:
		var mesh := model.find_child(part, true, false) as Node3D
		mesh.get_parent().remove_child(mesh)
		mesh.owner = null
		for c in mesh.find_children("*", "", true, false):
			c.owner = null
		var rb := RigidBody3D.new()
		rb.name = part
		rb.mass = float(PARTS[part][0])
		rb.collision_layer = Layers.LOOT
		rb.collision_mask = Layers.TERRAIN | Layers.LOOT | Layers.LIFT | Layers.DEBRIS | Layers.RUBBLE
		rb.linear_damp = 0.2
		rb.angular_damp = 1.2 if part != "Torso" else 0.6
		rb.continuous_cd = part == "Torso"
		rb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
		rb.set_meta("rescue_peer", peer_id)
		var spec: Array = PARTS[part][1]
		var cs := CollisionShape3D.new()
		if spec[0] == "box":
			var b := BoxShape3D.new()
			b.size = spec[1]
			cs.shape = b
		else:
			var c := CapsuleShape3D.new()
			c.radius = (spec[1] as Vector2).x
			c.height = (spec[1] as Vector2).y
			cs.shape = c
		cs.position = spec[2]
		rb.add_child(cs)
		rb.add_child(mesh)
		mesh.transform = Transform3D.IDENTITY
		add_child(rb)
		rb.global_transform = feet * (rest[part] as Transform3D)
		rb.reset_physics_interpolation()
		bodies[part] = rb
	model.queue_free()
	torso = bodies["Torso"]
	_recolor(color)
	# Gewrichten, op het draaipunt van elk lidmaat.
	for j: Array in JOINTS:
		var limb: RigidBody3D = bodies[j[0]]
		var joint := ConeTwistJoint3D.new()
		joint.name = "Joint_" + str(j[0])
		add_child(joint)
		# De twist-as van een ConeTwistJoint3D is zijn x-as: langs het lidmaat leggen.
		var along: Vector3 = feet.basis * (j[1] as Vector3)
		joint.global_transform = Transform3D(_basis_x_along(along), limb.global_position)
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float(j[2])))
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(float(j[3])))
		joint.node_a = joint.get_path_to(torso)
		joint.node_b = joint.get_path_to(limb)
	# Onderdelen botsen niet met elkaar (ze overlappen bij de schouders en heupen).
	var all: Array = bodies.values()
	for i in all.size():
		for k in range(i + 1, all.size()):
			(all[i] as RigidBody3D).add_collision_exception_with(all[k])
	set_pinned(not dynamic)


## Plek van een onderdeel in robot.glb (t.o.v. de voeten), los van de boom.
static func _model_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _basis_x_along(dir: Vector3) -> Basis:
	var x := dir.normalized()
	var helper := Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var z := x.cross(helper).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _recolor(color: Color) -> void:
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			match mat.resource_name:
				"Body":
					var m := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					m.albedo_color = color
					mi.set_surface_override_material(i, m)
				"Screen":
					if face == null:
						face = ShaderMaterial.new()
						face.shader = FACE_SHADER
						face.set_shader_parameter("dazed", 1.0)
					mi.set_surface_override_material(i, face)


## Kinematisch (gedragen, vastgesjord, of client) of dynamisch (host, los).
func set_pinned(on: bool) -> void:
	pinned = on
	if torso:
		torso.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		torso.freeze = on
		if not on:
			torso.sleeping = false


## Een duw voor de hele pop (een klap, een ontploffing, de worm): elk lichaam dezelfde snelheid erbij,
## plus wat willekeurige draaiing.
func push(velocity: Vector3, spin := 4.0) -> void:
	for rb: RigidBody3D in bodies.values():
		if rb.freeze:
			continue
		rb.linear_velocity += velocity
		rb.angular_velocity += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spin
		rb.sleeping = false


## De hele pop ergens neerzetten (te ver weg of in de rots): alle lichamen mee, zonder te ontploffen.
func teleport(xf: Transform3D) -> void:
	var delta := xf * torso.global_transform.affine_inverse()
	for rb: RigidBody3D in bodies.values():
		rb.global_transform = delta * rb.global_transform
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.reset_physics_interpolation()


## De romp kinematisch naar `xf` (gedragen, vastgesjord, client). Sprongen groter dan 2,5 m: de hele pop mee.
func move_torso(xf: Transform3D) -> void:
	if torso.global_position.distance_to(xf.origin) > 2.5:
		teleport(xf)
		return
	torso.global_transform = xf


## Waar de voeten van een robot zouden staan die hier opstaat (de romp ligt op de grond).
func stand_point(terrain: TerrainAPI) -> Vector3:
	var p := torso.global_position
	var hit := terrain.raycast(p + Vector3.UP * 0.6, p + Vector3.DOWN * 2.5, Layers.TERRAIN | Layers.LIFT)
	return (hit.position as Vector3) + Vector3.UP * 0.05 if not hit.is_empty() else p


## Client: een plek van de host (100 ms achter getekend). `in_mol`: t.o.v. de Mol.
func push_snapshot(xf: Transform3D, in_mol: bool) -> void:
	_snapshots.append([float(Time.get_ticks_msec()), xf, in_mol])
	if _snapshots.size() > 20:
		_snapshots.pop_front()


func clear_snapshots() -> void:
	_snapshots.clear()


## Client: de romp op de geïnterpoleerde plek van de host. `mol`: om plekken in de Mol om te rekenen.
func follow_snapshots(mol: Mol) -> void:
	if _snapshots.is_empty():
		return
	var render_t := float(Time.get_ticks_msec()) - 100.0
	while _snapshots.size() > 2 and _snapshots[1][0] <= render_t:
		_snapshots.pop_front()
	var a: Array = _snapshots[0]
	var b: Array = _snapshots[1] if _snapshots.size() > 1 else a
	var k := 0.0 if b[0] == a[0] else clampf((render_t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	move_torso(_snap_world(a, mol).interpolate_with(_snap_world(b, mol), k))


func _snap_world(s: Array, mol: Mol) -> Transform3D:
	if s[2] and mol and mol.body:
		return mol.body.global_transform * (s[1] as Transform3D)
	return s[1]


## Alle lichamen (voor botsuitzonderingen met dragers).
func all_bodies() -> Array:
	return bodies.values()
