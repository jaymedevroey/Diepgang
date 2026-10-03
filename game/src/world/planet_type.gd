class_name PlanetType
extends RefCounted
## Planeettypes (GDD v3 §4): hemel, zon en sfeer aan de oppervlakte. De lagen en hun kleuren staan
## (nog) in Strata en de rots-shader; dit is wat boven de grond anders is per planeet.
## In Early Access: Roestbol, Fossielwereld, Kristalmaan (enkel Roestbol is nu uitgewerkt).
## Roestbol heeft drie voorgestelde kleurrichtingen (docs/research/hemel.md §5); met --sky=a|b|c
## kies je er een (voor de vergelijking), standaard A.

enum Id { ROESTBOL }

const NAMES: Array[String] = ["Roestbol"]


## Richting (eenheidsvector) uit een kompasrichting en hoogte in graden. Azimut 0 = +z, 90 = +x.
static func dir(azimuth_deg: float, elevation_deg: float) -> Vector3:
	var a := deg_to_rad(azimuth_deg)
	var e := deg_to_rad(elevation_deg)
	return Vector3(cos(e) * sin(a), sin(e), cos(e) * cos(a))


static func _hex(s: String) -> Color:
	return Color.html(s)


## Parameters van een type: hemel (shader-uniforms), zon (licht) en sfeer aan de oppervlakte.
static func params(id: Id, style := "") -> Dictionary:
	if style == "":
		style = str(CmdArgs.value("sky", "a")).to_lower()
	match id:
		_:
			return _roestbol(style)


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
					"sky_energy": 1.1, "dust_tau": 0.45,
				},
				"sun_rotation_deg": Vector3(-35.0, 60.0, 0.0),
				"sun_color": _hex("FFF4E0"), "sun_energy": 1.35,
				"ambient": _hex("8FB5B5"), "ambient_energy": 0.4,
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
					"sky_energy": 1.2, "dust_tau": 0.6,
				},
				"sun_rotation_deg": Vector3(-10.0, 160.0, 0.0),
				"sun_color": _hex("FFC890"), "sun_energy": 1.4,
				"ambient": _hex("8A6A8E"), "ambient_energy": 0.38,
				"fog": _hex("D98F7A"), "fog_density": 0.0015,
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
					"sky_energy": 1.25, "dust_tau": 0.55,
				},
				"sun_rotation_deg": Vector3(-24.0, 80.0, 0.0),
				"sun_color": _hex("FFE9D0"), "sun_energy": 1.3,
				"ambient": _hex("B08878"), "ambient_energy": 0.42,
				"fog": _hex("E8C49A"), "fog_density": 0.0015,
			}
