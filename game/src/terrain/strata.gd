class_name Strata
extends RefCounted
## Lagen van de put (GDD §4), van onder naar boven.
## Moet overeenkomen met terrain.gdshader (zelfde grenzen, golving en kleuren).

enum Layer { KRISTAL, GRANIET, ZANDSTEEN, KLEI }
## Gereedschap-niveau: 0 = houweel, 1 = boor T1, 2 = boor T2.
enum Tool { HOUWEEL, BOOR_T1, BOOR_T2 }

const NAMES: Array[String] = ["Kristal", "Graniet", "Zandsteen", "Klei"]
## Bovengrens van elke laag in meter boven de bodem. Klei loopt tot aan het oppervlak.
const TOPS_M: Array[float] = [35.0, 80.0, 125.0]
## Welk gereedschap een laag minstens nodig heeft (GDD §4, tabel Lagen).
const MIN_TOOL: Array[Tool] = [Tool.BOOR_T2, Tool.BOOR_T2, Tool.BOOR_T1, Tool.HOUWEEL]
## Kleur van stof en brokjes per laag (iets lichter dan de wand, zodat puin leesbaar blijft).
const DEBRIS_COLORS: Array[Color] = [
	Color(0.18, 0.2, 0.3),
	Color(0.5, 0.5, 0.53),
	Color(0.8, 0.64, 0.42),
	Color(0.55, 0.38, 0.27),
]


static func boundary_offset(x: float, z: float, pit_seed: int) -> float:
	return 1.5 * sin(x * 0.13 + pit_seed * 0.7) + 1.2 * sin(z * 0.09 + pit_seed * 1.3)


static func layer_at(world: Vector3, pit_seed: int) -> Layer:
	var y := world.y + boundary_offset(world.x, world.z, pit_seed)
	for i in TOPS_M.size():
		if y < TOPS_M[i]:
			return i as Layer
	return Layer.KLEI


static func can_dig(layer: Layer, tool: Tool) -> bool:
	return tool >= MIN_TOOL[layer]
