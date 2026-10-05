class_name PlanetLoot
extends RefCounted
## Buit per planeet (release-audit ontwerp-5 en ontwerp-8, GDD §4 Planeettypes en Buit). Elke planeet
## moet anders spelen, niet enkel anders ogen:
##   Roestbol       de basis: kampen van vorige bezoekers (rommel, munten) in de klei, meer erts, kleine
##                  skeletten (Sand strider, 3-5 stukken) in het zandsteen. Rustig: weinig gas, trage worm.
##   Fossielwereld  veel grote skeletten in stukken (Titan, 5-8 stukken, waarvan 2-4 te zwaar om alleen
##                  te tillen): samen opgraven en met twee dragen. Bedden al vanaf ±18 m. Weinig rommel en erts.
##   Kristalmaan    breekbare, lichtgevende kristallen in kristalgrotten rond de grotten (een klap of de boor
##                  kost ze veel, een harde klap breekt ze): voorzichtig bikken en dragen. Meer gas, een
##                  actievere worm (F2 leest de factoren via PlanetType.params).
## Aantallen en factoren staan in data/tuning/planets.cfg (achtervoegsel _roestbol, _fossiel, _kristal);
## de tabellen hieronder zijn de mix per laag. Alles volgt uit de seed: elke peer maakt dezelfde buit.

const SUFFIX: Array[String] = ["roestbol", "fossiel", "kristal"]

## Factor per familie (FindKinds.Family: SKELETON, RELIC, METAL, JUNK, CRYSTAL) op de basistabel per laag.
const FAMILY_MULT := [
	[1.0, 1.2, 1.2, 1.3, 0.7],   # Roestbol: rommel en metaal, weinig kristal
	[1.5, 0.8, 0.6, 0.35, 0.5],  # Fossielwereld: botten
	[0.45, 0.8, 1.0, 0.6, 1.2],  # Kristalmaan: kristallen
]
## Extra gewichten per zone (bovenop de basistabel), per planeet. Zones: zie zone().
const EXTRA := [
	{},
	{
		"clay": {FindKinds.Kind.FEMUR: 8, FindKinds.Kind.VERTEBRA: 12, FindKinds.Kind.RIB: 12, FindKinds.Kind.CLAW: 10, FindKinds.Kind.SKULL: 2, FindKinds.Kind.SPINE: 3, FindKinds.Kind.TUSK: 3},
		"sand": {FindKinds.Kind.SPINE: 6, FindKinds.Kind.TUSK: 6},
		"deep": {FindKinds.Kind.SPINE: 4, FindKinds.Kind.TUSK: 6},
		"granite": {FindKinds.Kind.TUSK: 6, FindKinds.Kind.SPINE: 4},
	},
	{
		"clay": {FindKinds.Kind.GLOWSHARD: 16, FindKinds.Kind.BLOOM: 4, FindKinds.Kind.GEODE: 6},
		"sand": {FindKinds.Kind.GLOWSHARD: 20, FindKinds.Kind.BLOOM: 8, FindKinds.Kind.GEODE: 6},
		"deep": {FindKinds.Kind.GLOWSHARD: 14, FindKinds.Kind.BLOOM: 14},
		"granite": {FindKinds.Kind.GLOWSHARD: 16, FindKinds.Kind.BLOOM: 20},
		"crystal": {FindKinds.Kind.GLOWSHARD: 20, FindKinds.Kind.BLOOM: 26},
	},
]

## Skeletten (sets, ontwerp-9): een bed is één skelet. `core` zit er altijd in, de rest komt uit `pool`
## (zonder terugleggen), samen min..max stukken. `half_len`: halve lengte van het bed langs de rug (m).
## F1 rekent de setbonus uit bij de taxatie (FindItem.set_id en set_size).
const SETS := {
	"strider": {"name": "Sand strider", "core": [FindKinds.Kind.SKULL], "min": 3, "max": 5, "half_len": 3.8,
			"pool": [FindKinds.Kind.FEMUR, FindKinds.Kind.FEMUR, FindKinds.Kind.VERTEBRA, FindKinds.Kind.VERTEBRA, FindKinds.Kind.VERTEBRA, FindKinds.Kind.RIB, FindKinds.Kind.RIB, FindKinds.Kind.CLAW, FindKinds.Kind.CLAW]},
	"titan": {"name": "Titan", "core": [FindKinds.Kind.TITAN_SKULL, FindKinds.Kind.PELVIS], "min": 5, "max": 8, "half_len": 6.8,
			"pool": [FindKinds.Kind.TITAN_FEMUR, FindKinds.Kind.TITAN_FEMUR, FindKinds.Kind.SPINE, FindKinds.Kind.SPINE, FindKinds.Kind.SPINE, FindKinds.Kind.TUSK, FindKinds.Kind.TUSK, FindKinds.Kind.RIB, FindKinds.Kind.RIB]},
}
## Waar een stuk in het bed ligt, zoals in het beest: plek langs de rug (−1 = kop, +1 = staart) en
## of het opzij ligt (paren links en rechts). Een bed leest zo als een skelet, niet als een hoopje.
const SLOTS := {
	FindKinds.Kind.SKULL: [-1.0, false], FindKinds.Kind.TITAN_SKULL: [-1.0, false], FindKinds.Kind.TUSK: [-0.82, true],
	FindKinds.Kind.VERTEBRA: [-0.35, false], FindKinds.Kind.SPINE: [-0.4, false], FindKinds.Kind.RIB: [-0.15, true],
	FindKinds.Kind.PELVIS: [0.42, false], FindKinds.Kind.FEMUR: [0.62, true], FindKinds.Kind.TITAN_FEMUR: [0.66, true], FindKinds.Kind.CLAW: [0.92, true],
}
## Kamp van vorige bezoekers (Roestbol) en kristalgrot (Kristalmaan): waaruit een hoopje bestaat.
const CAMP_POOL := [FindKinds.Kind.TV, FindKinds.Kind.GNOME, FindKinds.Kind.BOTTLE, FindKinds.Kind.BOTTLE, FindKinds.Kind.COINS, FindKinds.Kind.COINS, FindKinds.Kind.LAMP]
const POCKET_POOL := [FindKinds.Kind.GLOWSHARD, FindKinds.Kind.GLOWSHARD, FindKinds.Kind.GLOWSHARD, FindKinds.Kind.BLOOM, FindKinds.Kind.BLOOM, FindKinds.Kind.GEODE]


## Een getal uit planets.cfg voor deze planeet (`key` + "_" + achtervoegsel).
static func value(planet: int, key: String, fallback: float) -> float:
	return Tuning.get_f("planets", "%s_%s" % [key, SUFFIX[clampi(planet, 0, 2)]], fallback)


static func count(planet: int, key: String, fallback: int) -> int:
	return int(round(value(planet, key, fallback)))


## Zone van een plek: klei, zandsteen, diep zandsteen, graniet of kristal (zoals FindKinds.layer_weights).
static func zone(world_y: float, layer: Strata.Layer) -> String:
	match layer:
		Strata.Layer.KLEI:
			return "clay"
		Strata.Layer.GRANIET:
			return "granite"
		Strata.Layer.KRISTAL:
			return "crystal"
	return "deep" if world_y < Strata.TOPS_M[1] + FindKinds.DEEP_BAND else "sand"


## Gewichten per soort voor een losse vondst op deze plek en planeet.
static func weights(planet: int, world_y: float, layer: Strata.Layer) -> Array[float]:
	var p := clampi(planet, 0, 2)
	var out: Array[float] = FindKinds.layer_weights(world_y, layer).duplicate()
	var mult: Array = FAMILY_MULT[p]
	for i in out.size():
		out[i] *= float(mult[FindKinds.FAMILIES[i]])
	var extra: Dictionary = (EXTRA[p] as Dictionary).get(zone(world_y, layer), {})
	for k: int in extra:
		out[k] += float(extra[k])
	return out


## De stukken van één skelet (soorten), gekozen met de rng: eerst `core`, dan uit `pool`.
static func set_pieces(rng: RandomNumberGenerator, set_key: String) -> Array[int]:
	var spec: Dictionary = SETS[set_key]
	var n := rng.randi_range(int(spec.min), int(spec.max))
	var out: Array[int] = []
	for k: int in spec.core:
		out.append(k)
	var pool: Array = (spec.pool as Array).duplicate()
	while out.size() < n and not pool.is_empty():
		out.append(int(pool.pop_at(rng.randi() % pool.size())))
	return out
