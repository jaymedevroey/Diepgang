class_name HazardParams
extends RefCounted
## Gevaren per planeet (GDD §4: Kristalmaan heeft "gas, de Graafworm"; ontwerp-5). Pakket F3 zet de
## factoren in `PlanetType.params(id)` (uit planets.cfg): `gas_mult`, `worm_mult`, `quake_mult`.
## Zonder waarde geldt 1.0. Sleutels hier:
##   worm      hoe actief de Graafworm is (snelheid, hoe snel hij wakker wordt, hoe vaak hij uitvalt)   worm_mult
##   gas       aantal gasbellen (×)                                                                    gas_mult
##   collapse  onstabiele zones en de kans op een instorting (×)                                       quake_mult
##   unrest    hoe snel de onrust stijgt door lawaai (×), dus hoe vaak het beeft                       quake_mult

const KEYS := {"worm": "worm_mult", "gas": "gas_mult", "collapse": "quake_mult", "unrest": "quake_mult"}

static var _cache := {} # planeet-id -> Dictionary (de parameters van PlanetType)


## Factor `key` voor de planeet van deze wereld (1.0 als de planeet er niets over zegt).
static func of(game: Node, key: String, fallback := 1.0) -> float:
	var id := int(game.planet_type) if game != null else 0
	if not _cache.has(id):
		_cache[id] = PlanetType.params(id as PlanetType.Id)
	var p: Dictionary = _cache[id]
	return float(p.get(KEYS.get(key, key), fallback))


## Tests: de cache leegmaken (na een aanpassing van planets.cfg).
static func clear() -> void:
	_cache.clear()
