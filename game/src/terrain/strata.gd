class_name Strata
extends RefCounted
## Lagen van de put (GDD §4), van onder naar boven.
## Moet overeenkomen met terrain.gdshader (zelfde grenzen en golving).

enum Layer { KRISTAL, GRANIET, ZANDSTEEN, KLEI }

const NAMES: Array[String] = ["Kristal", "Graniet", "Zandsteen", "Klei"]
## Bovengrens van elke laag in meter boven de bodem. Klei loopt tot aan het oppervlak.
const TOPS_M: Array[float] = [35.0, 80.0, 125.0]


static func boundary_offset(x: float, z: float, pit_seed: int) -> float:
	return 1.5 * sin(x * 0.13 + pit_seed * 0.7) + 1.2 * sin(z * 0.09 + pit_seed * 1.3)


static func layer_at(world: Vector3, pit_seed: int) -> Layer:
	var y := world.y + boundary_offset(world.x, world.z, pit_seed)
	for i in TOPS_M.size():
		if y < TOPS_M[i]:
			return i as Layer
	return Layer.KLEI
