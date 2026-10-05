class_name Landform
extends RefCounted
## Grote landvormen rond het speelgebied, per planeettype (docs/research/planeten.md §3–4).
## Het speelgebied ligt IN een landvorm, niet in het midden ervan: zo valt de rand van het gebied
## weg tegen iets groters, en van boven lees je een plek in plaats van een vierkant.
## Elke planeet heeft een eigen subklasse (landform_roestbol.gd, landform_fossiel.gd,
## landform_kristal.gd). Alles hangt enkel af van de seed (elke peer ziet hetzelfde) en is veilig
## op een werkthread (geen scène, geen gedeelde toestand na setup), behalve commit_props (hoofdthread).
## Wat een planeet invult:
##   setup        keuzes uit de seed (waar de wand, de put, de duinen ... liggen)
##   height       hoogte boven/onder de basis van het verre landschap
##   hills_factor hoeveel van de gewone heuvels er mag blijven (0..1)
##   tint         kleur van het landschap (rgb maal de rotskleur) en a = lagen in steile wanden
##   rock_density hoeveel losse rotsblokken per cel van 24 m (≈ 0..4), rock_scale hoe groot
##   compute_props / commit_props   eigen dingen (booreiland, botten, kristallen ...)
##   near_height  vormen die het speelgebied binnenlopen (duinen, een bedding): in het voxelterrein
## De tint geldt ook binnen het speelgebied (PlanetSurface bakt ze in een textuur voor het
## voxelterrein): niet naar neutraal laten vervagen aan de rand, dan loopt de kleur gewoon door.

## Waar de landvorm begint mee te tellen (m buiten het speelgebied): op de rand zelf moet het verre
## landschap exact op het voxelterrein aansluiten.
const FADE_IN := Vector2(15.0, 70.0)

var landing := Vector2.ZERO # landingsplek (wereld x/z)
var play_size := Vector2.ZERO
## Wind (eenheid, wereld x/z): duinen, stofsporen en stofwolken volgen hem.
var wind := Vector2.RIGHT


static func create(id: PlanetType.Id) -> Landform:
	match id:
		PlanetType.Id.FOSSIELWERELD:
			return LandformFossiel.new()
		PlanetType.Id.KRISTALMAAN:
			return LandformKristal.new()
		_:
			return LandformRoestbol.new()


func setup(_planet_seed: int, landing_xz: Vector2, size: Vector2) -> void:
	landing = landing_xz
	play_size = size


## Hoogte (m) boven of onder de basis van het verre landschap; `o` = afstand buiten het speelgebied.
func height(_x: float, _z: float, _o: float) -> float:
	return 0.0


## Vormen die het speelgebied binnenlopen (m, zoals height). TerrainAPI bakt ze op een raster over
## het speelgebied plus FADE_IN.y en de generator legt ze in het voxelterrein; voorbij FADE_IN.y neemt
## height() het over, dus height() moet dezelfde vormen bevatten. Enkel lezen (geen gedeelde
## toestand): het raster wordt op de hoofdthread gebakken, vóór de werkthread van PlanetSurface.
func near_height(_x: float, _z: float) -> float:
	return 0.0


## Heeft deze planeet vormen in het speelgebied (anders bakt TerrainAPI niets)?
func has_near() -> bool:
	return false


## Hoe sterk hier de naden van een zeshoekige korst getekend worden (0..1), in het voxelterrein
## (de shader legt hetzelfde rooster als KristalMesh.hex_plate buiten het speelgebied).
func crust_seams(_x: float, _z: float) -> float:
	return 0.0


func hills_factor(_x: float, _z: float) -> float:
	return 1.0


func tint(_x: float, _z: float) -> Color:
	return Color(1.0, 1.0, 1.0, 0.0)


## Losse rotsblokken per cel van 24 m (gemiddeld), en hoe groot ze hier zijn (maal 0,7..3,6 m).
func rock_density(_p: Vector2) -> float:
	return 0.4


func rock_scale(_p: Vector2) -> float:
	return 1.0


## Uniforms voor de rotsshader van het verre landschap (dikte, verdeling en sterkte van de lagen,
## een sleutellaag). `surface_y` = hoogte van het oppervlak in het speelgebied. Een planeet die iets
## wil, voegt toe aan deze standaardwaarden (die zetten ook terug wat een vorige planeet zette).
func shader_params(_surface_y: float) -> Dictionary:
	return {"strata_scale": 18.0, "strata_cuts": Vector2(0.45, 0.8), "strata_strength": 0.5,
			"strata_steep": Vector2(0.55, 0.85), "strata_key": Vector3.ZERO}


## Landmarks voor de kaart van het planeetdek onder de hub (PlanetSurface._land_map_data), die de
## tint alleen niet toont (dingen, geen grond): [[Vector2 plek, straal m, Color sRGB (a = sterkte)], ...].
## Op de werkthread, na compute-achtige setup (enkel lezen).
func map_marks() -> Array:
	return []


## Op de werkthread: waar de eigen dingen van de planeet staan. `s` geeft far_height en outside.
func compute_props(_s: PlanetSurface) -> Dictionary:
	return {}


## Op de hoofdthread: de eigen dingen in de scène hangen (onder `root`).
func commit_props(_root: Node3D, _out: Dictionary) -> void:
	pass


## Dempt alles vlak bij het speelgebied (de rand moet op het voxelterrein aansluiten).
static func fade_in(o: float) -> float:
	return smoothstep(FADE_IN.x, FADE_IN.y, o)
