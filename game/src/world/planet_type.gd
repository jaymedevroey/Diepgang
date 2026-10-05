class_name PlanetType
extends RefCounted
## Planeettypes (GDD v3 §4, docs/research/planeten.md): hemel, zon, sfeer aan de oppervlakte, de
## kleuren van de bovenste laag en de landvorm rond het speelgebied (Landform.create).
## De drie hemelrichtingen uit docs/research/hemel.md §5 zijn drie planeten (Jayme, 2026-10-04):
## Roestbol = A (karamel met een blauwe krans), Fossielwereld = B (teal boven roest),
## Kristalmaan = C (paars gouden uur). Met --sky=a|b|c forceer je een hemel (voor vergelijkingen).

enum Id { ROESTBOL, FOSSIELWERELD, KRISTALMAAN }

const NAMES: Array[String] = ["Rustbowl", "Fossil World", "Crystal Moon"]
const SKY_STYLE: Array[String] = ["a", "b", "c"]


## Kleuren van de bovenste laag (de rots aan de oppervlakte en het verre landschap), sRGB: basis,
## licht, donker, de lagen in steile wanden (licht, midden, donker), en de losse rotsblokken.
## relief_*: de kleur volgt de vorm (PlanetSurface.relief_at): laagtes maal relief_dark, hoogtes en
## randen maal relief_light, vol bij relief_m meter boven of onder het gemiddelde van de omgeving.
static func ground(id: Id) -> Dictionary:
	match id:
		Id.FOSSIELWERELD:
			# Kalksteen (crème in de zon, koel in de schaduw), mergel en een roestige ijzerband.
			return {"patch_dark": Color(0.86, 0.8, 0.72, 0.3), "patch_light": Color(1.08, 1.06, 1.03, 0.5), "patch_scale": 80.0,
					"base": _hex("C9B48C"), "light": _hex("E2CFA8"), "dark": _hex("7C8C8E"),
					"strata": [_hex("E2CFA8"), _hex("C9A46E"), _hex("8C9AA0")], "rock": _hex("A08E70"),
					# Geulbodems: okerstof en grijsblauwe klei, donker (het enige donker was het skelet).
					"relief_m": 1.1, "relief_dark": Color(0.74, 0.74, 0.78), "relief_light": Color(1.1, 1.08, 1.04)}
		Id.KRISTALMAAN:
			# Donker violet basalt met lange schaduwen.
			return {"patch_dark": Color(0.7, 0.68, 0.8, 0.65), "patch_light": Color(1.35, 1.3, 1.45, 0.45), "patch_scale": 70.0,
					"base": _hex("54446A"), "light": _hex("7C6890"), "dark": _hex("2C2240"),
					"strata": [_hex("7A6080"), _hex("5A4466"), _hex("2E2440")], "rock": _hex("3E3248"),
					# Kraterranden en ruggen vangen het gouden licht; kommen blijven diep violet.
					"relief_m": 1.3, "relief_dark": Color(0.76, 0.72, 0.84), "relief_light": Color(1.42, 1.28, 1.28)}
		_:
			# Roestbol: klei (de stijlgids), lagen in de kraterwand zoals in het onderzoek.
			return {"patch_dark": Color(0.55, 0.46, 0.46, 0.75), "patch_light": Color(1.16, 1.08, 0.97, 0.55), "patch_scale": 110.0,
					"base": Color(0.431, 0.290, 0.208), "light": Color(0.604, 0.420, 0.298), "dark": Color(0.243, 0.165, 0.122),
					"strata": [_hex("E0B48C"), _hex("B86A44"), _hex("7A3A2A")], "rock": _hex("6A3A2B"),
					# Donker basaltzand in de laagtes (#3E2626), licht perzikstof op de ruggen (#D9A27E).
					"relief_m": 1.3, "relief_dark": Color(0.5, 0.43, 0.56), "relief_light": Color(1.42, 1.27, 1.08)}


## Richting (eenheidsvector) uit een kompasrichting en hoogte in graden. Azimut 0 = +z, 90 = +x.
static func dir(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var a := deg_to_rad(azimuth_deg)
	var e := deg_to_rad(elevation_deg)
	return Vector3(cos(e) * sin(a), sin(e), cos(e) * cos(a))


static func _hex(s: String) -> Color:
	return Color.html(s)


## Parameters van een type: hemel (shader-uniforms), zon (licht) en sfeer aan de oppervlakte, plus hoe
## de planeet speelt (play()).
static func params(id: Id, style := "") -> Dictionary:
	if style == "":
		style = str(CmdArgs.value("sky", SKY_STYLE[clampi(int(id), 0, SKY_STYLE.size() - 1)])).to_lower()
	var p := _roestbol(style)
	p["name"] = NAMES[clampi(int(id), 0, NAMES.size() - 1)]
	p["ground"] = ground(id)
	p.merge(play(id), true)
	return p


## Wat de planeet in het spelen anders maakt (release-audit ontwerp-5, GDD §4): een korte zin (voor de
## contractkaarten), wat er te vinden is, en de factoren voor de gevaren. Pakket F2 leest gas_mult,
## worm_mult en quake_mult (met 1.0 als standaard); de buit zelf zit in PlanetLoot. Uit planets.cfg.
const TAGLINES: Array[String] = [
	"Junk camps, ore and small skeletons. A good first dig.",
	"Giant skeletons in pieces. Bring a buddy to carry them.",
	"Fragile glowing crystals. More gas, and the worm is restless.",
]


static func play(id: Id) -> Dictionary:
	var i := clampi(int(id), 0, 2)
	return {
		"tagline": TAGLINES[i],
		"heavy_finds": i == Id.FOSSIELWERELD,
		"fragile_finds": i == Id.KRISTALMAAN,
		"gas_mult": PlanetLoot.value(i, "gas", 1.0),
		"worm_mult": PlanetLoot.value(i, "worm", 1.0),
		"quake_mult": PlanetLoot.value(i, "quake", 1.0),
		"ore_mult": PlanetLoot.value(i, "ore_veins", 1.0),
	}


static func _roestbol(style: String) -> Dictionary:
	match style:
		"b":
			# Teal boven roest: complementair, twee duidelijke lagen (warm stof laag, koele lucht).
			return {
				"name": "Roestbol",
				"sky": {
					"zenith": _hex("1F5E6E"), "mid_sky": _hex("4F9AA0"), "horizon": _hex("BFE0D2"), "haze_band": _hex("E9B48F"),
					"aureole": _hex("D8F4F0"), "space": _hex("12384A"), "sun_color": _hex("FFFBF0"),
					"ground_lit": _hex("B0482A"), "ground_shadow": _hex("3E2A3C"),
					"giant_base": _hex("B48FC4"), "giant_band": _hex("7A5A9C"), "giant_storm": _hex("EADCF0"),
					"giant_night": _hex("3A2228"), "ring_color": _hex("F0DDB0"), "ring_glow": _hex("FFE9C4"),
					"giant_dir": dir(210.0, 25.0), "giant_radius_deg": 9.0, "ring_open_deg": 22.0, "ring_roll_deg": 12.0,
					"sky_energy": 1.1, "dust_tau": 0.45, "giant_haze": 0.35, "aureole_mix": 0.25,
				},
				# Release-audit buiten-3 (ronde 2): lager en van opzij t.o.v. de dropcamera (die naar de klif
				# kijkt), zodat elke rug een zon- en een schaduwkant toont; van achter maakte het alles vlak.
				"sun_rotation_deg": Vector3(-24.0, 88.0, 0.0),
				"sun_color": _hex("FFF4E0"), "sun_energy": 1.4,
				"ambient": _hex("8FB5B5"), "ambient_energy": 0.24,
				"fog": _hex("E0A27E"), "fog_density": 0.0015,
			}
		"c":
			# Paars gouden uur: de zon staat altijd laag, de reus is een sikkel met ringen in tegenlicht.
			return {
				"name": "Roestbol",
				"sky": {
					"zenith": _hex("2B2350"), "mid_sky": _hex("6B5A8E"), "horizon": _hex("F2A65A"), "haze_band": _hex("D98F7A"),
					"aureole": _hex("FFE3B0"), "space": _hex("140F2A"), "sun_color": _hex("FFE3B0"),
					"ground_lit": _hex("C8642F"), "ground_shadow": _hex("4A2F4F"),
					"giant_base": _hex("F5E6C8"), "giant_band": _hex("C9A88A"), "giant_storm": _hex("FFF4E0"),
					"giant_night": _hex("4A2A22"), "ring_color": _hex("CDB79A"), "ring_glow": _hex("FFD9A8"),
					"giant_dir": dir(205.0, 24.0), "giant_radius_deg": 10.0, "ring_open_deg": 16.0, "ring_roll_deg": -18.0,
					"sky_energy": 1.2, "dust_tau": 0.6, "giant_haze": 0.3, "aureole_mix": 0.35,
				},
				"sun_rotation_deg": Vector3(-10.0, 160.0, 0.0),
				"sun_color": _hex("FFC890"), "sun_energy": 1.4,
				"ambient": _hex("8A74B0"), "ambient_energy": 0.65,
				"fog": _hex("9A6A88"), "fog_density": 0.0006,
			}
		_:
			# A: karamel met een blauwe krans (op Mars gebaseerd): lichte warme koepel, koele accenten.
			return {
				"name": "Roestbol",
				"sky": {
					"zenith": _hex("A0705F"), "mid_sky": _hex("C9977A"), "horizon": _hex("E8C49A"), "haze_band": _hex("F3D9B5"),
					"aureole": _hex("A9C4D8"), "space": _hex("3B2A4A"), "sun_color": _hex("FFF4E6"),
					"ground_lit": _hex("B5532E"), "ground_shadow": _hex("5A2E35"),
					"giant_base": _hex("7FA3B8"), "giant_band": _hex("4F7690"), "giant_storm": _hex("D8E3E8"),
					"giant_night": _hex("3A2420"), "ring_color": _hex("E6D6BC"), "ring_glow": _hex("BFD8E8"),
					"giant_dir": dir(200.0, 22.0), "giant_radius_deg": 9.5, "ring_open_deg": 20.0, "ring_roll_deg": 15.0,
					"sky_energy": 1.25, "dust_tau": 0.55, "giant_haze": 0.12, "aureole_mix": 0.8,
				},
				"sun_rotation_deg": Vector3(-24.0, 80.0, 0.0),
				"sun_color": _hex("FFE9D0"), "sun_energy": 1.3,
				# Koel mauve vullicht (buiten-4): warm licht, koele schaduw, zoals ground_shadow van hemel A.
				"ambient": _hex("8E7A98"), "ambient_energy": 0.38,
				"fog": _hex("E8C49A"), "fog_density": 0.0008,
			}
