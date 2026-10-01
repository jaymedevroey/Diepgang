class_name FindKinds
extends RefCounted
## Soorten vondsten (GDD §4: families per laag) met hun model uit Blender (tools/blender/finds.py).
##   klei             muntenbuidel, oude fles, tuinkabouter, oude tv (rommel: veel gewicht, weinig waard)
##   zandsteen        skeletten (dijbeen, wervel, rib, schedel, klauw) en een oude mijnwerkerslamp
##   diep zandsteen   zeldzaam: geode en goudklomp (vlak boven het graniet)
## Plaatsing volgt uit de seed (FindField), dus elke peer kiest dezelfde soorten.

enum Kind { FEMUR, VERTEBRA, RIB, SKULL, CLAW, LAMP, COINS, BOTTLE, GNOME, TV, GEODE, GOLD }
enum Family { SKELETON, RELIC, METAL, JUNK, CRYSTAL }

## Objectnamen in finds.glb.
const KEYS: Array[String] = ["Femur", "Vertebra", "Rib", "Skull", "Claw", "Lamp", "Coins", "Bottle", "Gnome", "Tv", "Geode", "Gold"]
const NAMES: Array[String] = ["Dijbeen", "Wervel", "Rib", "Schedel", "Klauw", "Mijnwerkerslamp", "Muntenbuidel",
		"Oude fles", "Tuinkabouter", "Oude tv", "Geode", "Goudklomp"]
const FAMILIES: Array[Family] = [Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON,
		Family.RELIC, Family.METAL, Family.JUNK, Family.JUNK, Family.JUNK, Family.CRYSTAL, Family.METAL]
const BASE_VALUES: Array[int] = [180, 60, 45, 350, 90, 120, 85, 40, 15, 25, 260, 320]
const MASSES: Array[float] = [8.0, 3.0, 2.0, 14.0, 2.0, 3.0, 2.0, 1.0, 4.0, 12.0, 6.0, 9.0]
## Kans per soort in elke zone (som hoeft niet 1 te zijn).
const WEIGHTS_CLAY: Array[float] = [0, 0, 0, 0, 0, 0, 30, 30, 18, 12, 0, 0]
const WEIGHTS_SAND: Array[float] = [25, 30, 25, 5, 15, 10, 0, 0, 0, 0, 0, 0]
const WEIGHTS_DEEP: Array[float] = [14, 10, 10, 9, 8, 5, 0, 0, 0, 0, 20, 16]
## Diep zandsteen: zoveel meter boven de top van het graniet.
const DEEP_BAND := 14.0
## Vondsten met zoveel waarde of meer krijgen een gouden glans bij het vrijkomen.
const PRECIOUS := 200

const SOURCE := preload("res://assets/models/finds.glb")
const DETAIL := 7.0

static var _meshes: Dictionary = {}


static func pick_kind(rng: RandomNumberGenerator, world_y: float, layer: Strata.Layer) -> Kind:
	var weights: Array[float] = WEIGHTS_SAND
	if layer == Strata.Layer.KLEI:
		weights = WEIGHTS_CLAY
	elif world_y < Strata.TOPS_M[1] + DEEP_BAND:
		weights = WEIGHTS_DEEP
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0 and weights[i] > 0.0:
			return i as Kind
	return Kind.VERTEBRA


static func mesh(kind: Kind) -> Mesh:
	return _mesh(KEYS[kind])


## Brokje puin (0..2), eenheidsgrootte.
static func chunk(index: int) -> Mesh:
	return _mesh("Chunk_%d" % (index % 3))


## Materialen per oppervlak, eigen exemplaren (de gloed bij het vrijkomen is per vondst).
static func materials(kind: Kind) -> Array[Material]:
	var out: Array[Material] = []
	var m := mesh(kind)
	for i in m.get_surface_count():
		var src := m.surface_get_material(i)
		var name := src.resource_name if src else ""
		out.append(_material(name))
	return out


static func _material(name: String) -> Material:
	if name in ["Glass", "GlassGreen"]:
		var g := StandardMaterial3D.new()
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.albedo_color = Color(0.25, 0.55, 0.32, 0.55) if name == "GlassGreen" else Color(0.7, 0.85, 0.85, 0.25)
		g.roughness = 0.08
		g.metallic = 0.1
		g.emission_enabled = true
		g.emission = Color(1.0, 0.85, 0.5)
		g.emission_energy_multiplier = 0.0
		return g
	if name == "Screen":
		var s := StandardMaterial3D.new()
		s.albedo_color = Color(0.05, 0.07, 0.07)
		s.roughness = 0.15
		s.metallic = 0.4
		s.emission_enabled = true
		s.emission = Color(1.0, 0.85, 0.5)
		s.emission_energy_multiplier = 0.0
		return s
	if name == "Amethyst":
		var a := StandardMaterial3D.new()
		a.albedo_color = Color(0.62, 0.38, 0.88)
		a.roughness = 0.15
		a.emission_enabled = true
		a.emission = Color(0.55, 0.3, 0.9)
		a.emission_energy_multiplier = 0.9
		return a
	var mm := MolVisual.machine_material(name, false, DETAIL, 0.0, Color(), 0.7)
	if mm:
		return mm
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = Color(0.6, 0.6, 0.6)
	return fallback


static func _mesh(key: String) -> Mesh:
	if _meshes.is_empty():
		var root := SOURCE.instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			_meshes[mi.name] = mi.mesh
		root.free()
	return _meshes[key]
