class_name FindKinds
extends RefCounted
## Soorten vondsten (GDD §4: families per laag) met hun model uit Blender (tools/blender/finds.py).
##   klei             muntenbuidel, oude fles, tuinkabouter, oude tv (rommel van eerdere bezoekers)
##   zandsteen        skeletten (dijbeen, wervel, rib, schedel, klauw) en een oude mijnwerkerslamp
##   diep zandsteen   ook geode en goudklomp (vlak boven het graniet)
##   graniet          grote schedels, goud, geodes
##   kristal          vooral geodes
##   fossielbed       één skelet in stukken (een set, zie PlanetLoot): klein (Sand strider) of groot (Titan)
## Per planeet een andere mix (PlanetLoot, release-audit ontwerp-5): Roestbol rommel en kleine
## skeletten, Fossielwereld grote skeletten, Kristalmaan breekbare, lichtgevende kristallen.
## Plaatsing volgt uit de seed (FindField), dus elke peer kiest dezelfde soorten.

enum Kind { FEMUR, VERTEBRA, RIB, SKULL, CLAW, LAMP, COINS, BOTTLE, GNOME, TV, GEODE, GOLD,
		TITAN_SKULL, PELVIS, TITAN_FEMUR, SPINE, TUSK, GLOWSHARD, BLOOM, GIANT_GEODE, PAYROLL }
enum Family { SKELETON, RELIC, METAL, JUNK, CRYSTAL }

## Objectnamen in finds.glb. Golf 3 (ontwerp-8): ook op Roestbol en de Kristalmaan iets om samen te
## dragen, als vergrote versie van een bestaand model (MESH_SCALE): een reuzengeode (Kristalmaan,
## breekbaar) en de loonzak van een vorige ploeg (Roestbol, in de kampen).
const KEYS: Array[String] = ["Femur", "Vertebra", "Rib", "Skull", "Claw", "Lamp", "Coins", "Bottle", "Gnome", "Tv", "Geode", "Gold",
		"TitanSkull", "Pelvis", "TitanFemur", "Spine", "Tusk", "Glowshard", "Bloom", "Geode", "Coins"]
const NAMES: Array[String] = ["Femur", "Vertebra", "Rib", "Skull", "Claw", "Miner's lamp", "Coin pouch",
		"Old bottle", "Garden gnome", "Old TV", "Geode", "Gold nugget",
		"Titan skull", "Pelvis", "Giant femur", "Spine segment", "Tusk", "Glowshard", "Crystal bloom",
		"Giant geode", "Payroll sack"]
const FAMILIES: Array[Family] = [Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON,
		Family.RELIC, Family.METAL, Family.JUNK, Family.JUNK, Family.JUNK, Family.CRYSTAL, Family.METAL,
		Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.SKELETON, Family.CRYSTAL, Family.CRYSTAL,
		Family.CRYSTAL, Family.METAL]
const BASE_VALUES: Array[int] = [180, 60, 45, 350, 90, 120, 85, 40, 15, 25, 260, 320,
		600, 360, 280, 150, 220, 240, 420, 620, 540]
## Vergrote modellen (zelfde model, groter): soort -> schaal.
const MESH_SCALE := {Kind.GIANT_GEODE: 2.8, Kind.PAYROLL: 3.6}
## Massa (kg). Boven carry.lift_max (18 kg) til je het niet alleen: alleen sleep je het (traag,
## het schuurt), met twee draag je het (ontwerp-8). Titanschedel, bekken en reuzendijbeen. Een heel
## Titan-skelet (tot 8 stukken) weegt hooguit ±130 kg: het past in het grote laadruim (140 kg, F1),
## niet in het gewone (60 kg).
const MASSES: Array[float] = [8.0, 3.0, 2.0, 14.0, 2.0, 3.0, 2.0, 1.0, 4.0, 12.0, 6.0, 9.0,
		28.0, 22.0, 20.0, 10.0, 8.0, 3.0, 6.0, 26.0, 24.0]
## Breekbaarheid (0 = stevig): kristallen en geodes (GDD §4: "gloeiend en breekbaar"). Een klap
## kost dan sneller gaafheid, een harde klap breekt ze (FindField._check_impact), en de boor
## beschadigt ze meer. Ook verder dan 1 kan (de kristalroos is het broosst).
const FRAGILITY: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.5, 0,
		0, 0, 0, 0, 0, 1.0, 1.4, 0.5, 0]
## Lichtgevende vondsten: kleur van hun licht (een klein lampje zodra ze los zijn). Kapot = uit.
const GLOW := {Kind.GLOWSHARD: Color(0.35, 0.9, 1.0), Kind.BLOOM: Color(1.0, 0.5, 0.86)}
## Kans per soort in elke zone (som hoeft niet 1 te zijn). Per planeet bijgestuurd (PlanetLoot).
const WEIGHTS_CLAY: Array[float] = [0, 0, 0, 0, 0, 0, 30, 30, 18, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const WEIGHTS_SAND: Array[float] = [25, 30, 25, 5, 15, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const WEIGHTS_DEEP: Array[float] = [14, 10, 10, 9, 8, 5, 0, 0, 0, 0, 20, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const WEIGHTS_GRANITE: Array[float] = [10, 6, 6, 12, 8, 6, 0, 0, 0, 0, 24, 26, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const WEIGHTS_CRYSTAL: Array[float] = [4, 2, 2, 8, 6, 2, 0, 0, 0, 0, 46, 22, 0, 0, 0, 0, 0, 0, 0, 0, 0]
## Diep zandsteen: zoveel meter boven de top van het graniet.
const DEEP_BAND := 14.0
## Vondsten met zoveel waarde of meer krijgen een gouden glans bij het vrijkomen.
const PRECIOUS := 200
## Waardeklassen (GDD §4: "elke waardeklasse heeft een eigen geluid en glans"): rommel, gewoon,
## waardevol, kostbaar. Grenzen in finds.cfg. Per klasse: glanskleur, randlicht, fonkels, sterkte
## van het moment bij het vrijkomen, en de toonhoogte van de "ding" (tot het eigen geluid er is, M6).
enum ValueClass { JUNK, COMMON, VALUABLE, PRECIOUS }
const CLASS_GLINT: Array[Color] = [Color(0.9, 0.78, 0.62), Color(1.0, 0.92, 0.75), Color(1.0, 0.8, 0.35), Color(1.0, 0.74, 0.22)]
const CLASS_RIM: Array[float] = [0.18, 0.3, 0.45, 0.6]
const CLASS_SPARKLE: Array[float] = [0.0, 0.25, 0.6, 1.0]
const CLASS_STRENGTH: Array[float] = [0.6, 0.85, 1.15, 1.5]
const CLASS_PITCH: Array[float] = [0.82, 1.0, 1.12, 1.25]
const CLASS_NAMES: Array[String] = ["Junk", "Find", "Valuable find", "Precious find"]


static func value_class(base_value: int) -> ValueClass:
	if base_value >= Tuning.get_i("finds", "class_precious", 300):
		return ValueClass.PRECIOUS
	if base_value >= Tuning.get_i("finds", "class_valuable", 150):
		return ValueClass.VALUABLE
	if base_value >= Tuning.get_i("finds", "class_common", 50):
		return ValueClass.COMMON
	return ValueClass.JUNK

const SOURCE := preload("res://assets/models/finds.glb")
const DETAIL := 7.0

static var _meshes: Dictionary = {}


## Basistabel van een zone (zonder de planeet): klei, zandsteen, diep zandsteen, graniet, kristal.
static func layer_weights(world_y: float, layer: Strata.Layer) -> Array[float]:
	if layer == Strata.Layer.KLEI:
		return WEIGHTS_CLAY
	if layer == Strata.Layer.GRANIET:
		return WEIGHTS_GRANITE
	if layer == Strata.Layer.KRISTAL:
		return WEIGHTS_CRYSTAL
	if world_y < Strata.TOPS_M[1] + DEEP_BAND:
		return WEIGHTS_DEEP
	return WEIGHTS_SAND


## Een soort voor een losse vondst op deze plek en deze planeet (PlanetLoot.weights).
static func pick_kind(rng: RandomNumberGenerator, world_y: float, layer: Strata.Layer, planet := 0) -> Kind:
	return pick_from(rng, PlanetLoot.weights(planet, world_y, layer))


## Gewogen keuze uit een tabel (index = Kind). Altijd één getal uit de rng.
static func pick_from(rng: RandomNumberGenerator, weights: Array[float]) -> Kind:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0 and weights[i] > 0.0:
			return i as Kind
	return Kind.VERTEBRA


## Kan je dit alleen optillen? Zwaarder dan carry.lift_max: alleen sleep je het (ontwerp-8).
static func liftable_alone(mass: float) -> bool:
	return mass <= Tuning.get_f("carry", "lift_max", 18.0)


static func mesh(kind: Kind) -> Mesh:
	if MESH_SCALE.has(kind):
		return _scaled(KEYS[kind], float(MESH_SCALE[kind]))
	return _mesh(KEYS[kind])


## Een vergrote kopie van een model uit finds.glb (zelfde materialen), eenmaal gemaakt.
static func _scaled(key: String, s: float) -> Mesh:
	var cache := "%s@%.2f" % [key, s]
	if _meshes.has(cache):
		return _meshes[cache]
	var src := _mesh(key) as ArrayMesh
	var out := ArrayMesh.new()
	for i in src.get_surface_count():
		var arr := src.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for j in v.size():
			v[j] *= s
		arr[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(src.surface_get_primitive_type(i), arr)
		out.surface_set_material(i, src.surface_get_material(i))
	_meshes[cache] = out
	return out


static var _radii := {}


## Straal van de korst rond deze soort (grootste halve maat + de schil), voor de afstand tussen vondsten.
static func radius(kind: Kind) -> float:
	if not _radii.has(kind):
		var he := mesh(kind).get_aabb().size * 0.5
		_radii[kind] = maxf(he.x, maxf(he.y, he.z)) + 0.12
	return _radii[kind]


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
	if name in ["GlowCyan", "GlowPink"]:
		# Lichtgevend kristal (Kristalmaan): fel, glazig, met een rand. FindItem dooft het als het breekt.
		var c := StandardMaterial3D.new()
		var col := Color(0.42, 0.92, 1.0) if name == "GlowCyan" else Color(1.0, 0.55, 0.88)
		c.albedo_color = col
		c.roughness = 0.08
		c.metallic = 0.0
		c.rim_enabled = true
		c.rim = 0.7
		c.rim_tint = 0.6
		c.emission_enabled = true
		c.emission = col
		c.emission_energy_multiplier = 1.6
		c.set_meta("glow", true)
		return c
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
