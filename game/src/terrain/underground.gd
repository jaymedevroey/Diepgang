class_name Underground
extends RefCounted
## De ondergrond per planeet (release-audit binnen-01/02/08): kleuren per laag, de merklagen in de
## klei, wat er gloeit, en de kleur van verweerd erts in de wand. Voor terrain.gdshader (TerrainAPI
## zet de uniforms) en CaveDecor (zwammen, kristallen, druipsteen).
##
## Waarom zo (docs/stijlgids.md "elke diepte een eigen kleur, patroon en mist", GDD §4 "kleur én
## patroon, leesbaar voor kleurenblinden"):
## - Waarde eerst: elke laag heeft licht, midden en donker, en de klei krijgt merklagen die in
##   grijswaarden verschillen (bleek, donker, grind), niet enkel in tint.
## - Koud = van de diepte: in elke klei zit een koele merklaag en iets dat koel gloeit, zodat de
##   amber helmlamp contrasteert in plaats van alles te kleuren.
## - Per planeet één eigen ondergrond: Roestbol rode klei met kalk, gley en hematiet en gloeiende
##   geodes; Fossielwereld krijt met vuursteen, mergel en botbedden; Kristalmaan violette as met
##   obsidiaan en roze kristalinsluitsels.
## Alle kleuren in sRGB (de shader zet ze om), behalve ORE_STAIN.

## Per planeet (PlanetType.Id), per laag (Strata.Layer: 0 kristal, 1 graniet, 2 zandsteen, 3 klei
## onder de korst): basis, licht, donker.
const PALETTE := [
	# Roestbol
	{
		"base": ["222739", "5C6672", "B48C58", "6B4436"],
		"light": ["3A4262", "A3ACB6", "DCBC86", "A87B5F"],
		"dark": ["10131C", "262B33", "7A5634", "3A2520"],
		# Per laag een accent: kristal (ader), graniet (kwarts), zandsteen (ijzerband), klei (gloed).
		"accent": ["4FE3F0", "E4E2DA", "9C4A2C", "3EE6B0"],
		# Merklagen in de klei: bleek (kalk), donker (hematiet), koel (gley), grind.
		"bands": ["CBB79A", "3C1F1D", "6E7A70", "8A8580"],
		# Gloed van de zwammen in grotten (CaveDecor).
		"fungus": "5CF2C0",
	},
	# Fossielwereld
	{
		"base": ["1C2A30", "4E5956", "9E9468", "C2B596"],
		"light": ["36505A", "8E9A96", "CDC598", "E6DCC2"],
		"dark": ["0C1418", "222A28", "5E5A40", "7E7A70"],
		"accent": ["5CF0C8", "D8DCD0", "E8DEC4", "C6F26A"],
		# Krijt met vuursteen, vuursteen, mergel, schelpengruis.
		"bands": ["EFE8D8", "26262C", "8B98A2", "D8C9A4"],
		"fungus": "C6F26A",
	},
	# Kristalmaan
	{
		"base": ["241A3A", "3C3C4C", "9A6E86", "4E3F63"],
		"light": ["44346A", "70708A", "C79CB2", "7E6C96"],
		"dark": ["120C1E", "1A1A24", "5C3E52", "241B34"],
		"accent": ["C477FF", "B8A8D8", "E2CFE0", "FF6AD8"],
		# Bleke as, obsidiaan, blauwviolet, puimsteen.
		"bands": ["B4A6C6", "141019", "5A6290", "9C90A8"],
		"fungus": "FF7ADC",
	},
]

## Verweerd erts in de wand (OreKinds.Kind: koper, ijzer, zilver, lichtkristal), lineair: rgb =
## de verkleuring rond de ader, a = hoe sterk. Koper groen-turkoois (malachiet) op rode klei,
## ijzer roestrood-zwart, zilver donker blauwgrijs, lichtkristal cyaan.
const ORE_STAIN: Array[Color] = [
	Color(0.035, 0.30, 0.20, 0.8),
	Color(0.11, 0.018, 0.012, 0.75),
	Color(0.05, 0.06, 0.085, 0.7),
	Color(0.02, 0.2, 0.28, 0.7),
]


static func _row(planet: int) -> Dictionary:
	return PALETTE[clampi(planet, 0, PALETTE.size() - 1)]


static func color(planet: int, key: String, layer: int) -> Color:
	return Color.html(_row(planet)[key][layer])


static func band(planet: int, i: int) -> Color:
	return Color.html(_row(planet).bands[i])


static func fungus(planet: int) -> Color:
	return Color.html(_row(planet).fungus)


## Kleur van stof en brokjes per laag op deze planeet: iets lichter dan de wand (zie Strata).
static func debris_colors(planet: int) -> Array[Color]:
	var out: Array[Color] = []
	for layer in 4:
		out.append(color(planet, "base", layer).lerp(color(planet, "light", layer), 0.45))
	return out


## De uniforms van terrain.gdshader voor deze planeet.
static func apply(mat: ShaderMaterial, planet: int) -> void:
	for key: String in ["base", "light", "dark", "accent"]:
		var arr := PackedVector3Array()
		for layer in 4:
			var c := color(planet, key, layer)
			arr.append(Vector3(c.r, c.g, c.b))
		mat.set_shader_parameter("ug_" + key, arr)
	var bands := PackedVector3Array()
	for i in 4:
		var c := band(planet, i)
		bands.append(Vector3(c.r, c.g, c.b))
	mat.set_shader_parameter("ug_band", bands)
	var stain := PackedVector4Array()
	for c: Color in ORE_STAIN:
		stain.append(Vector4(c.r, c.g, c.b, c.a))
	mat.set_shader_parameter("ore_stain", stain)
	mat.set_shader_parameter("planet_id", planet)
