class_name HazardParams
extends RefCounted
## Gevaren per planeet (GDD §4: Kristalmaan heeft "gas, de Graafworm"; ontwerp-5). Pakket F3 zet ze
## per planeettype in `PlanetType.params(id)["hazards"]`, bv. {"gas": 1.8, "worm": 1.3}. Zonder die
## sleutel geldt 1.0. Sleutels:
##   worm      hoe actief de Graafworm is (snelheid, hoe snel hij wakker wordt, hoe vaak hij uitvalt)
##   gas       aantal gasbellen (×)
##   collapse  kans op een instorting (×)
##   unrest    lawaai (×), voor bevingen

static var _cache := {} # planeet-id -> Dictionary


## Factor `key` voor de planeet van deze wereld (1.0 als de planeet er niets over zegt).
static func of(game: Node, key: String, fallback := 1.0) -> float:
	var id := int(game.planet_type) if game != null else 0
	if not _cache.has(id):
		var p: Dictionary = PlanetType.params(id as PlanetType.Id)
		_cache[id] = p.get("hazards", {})
	return float((_cache[id] as Dictionary).get(key, fallback))


## Tests: de cache leegmaken (na een aanpassing van PlanetType).
static func clear() -> void:
	_cache.clear()
