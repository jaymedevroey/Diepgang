class_name PlanetType
extends RefCounted
## Planeettypes (GDD v3 §4): hemel, zon en sfeer aan de oppervlakte. De lagen en hun kleuren staan
## (nog) in Strata en de rots-shader; dit is wat boven de grond anders is per planeet.
## In Early Access: Roestbol, Fossielwereld, Kristalmaan (enkel Roestbol is nu uitgewerkt).

enum Id { ROESTBOL }

const NAMES: Array[String] = ["Roestbol"]


## Parameters van een type: hemel (shader), zon (licht) en mist aan de oppervlakte.
static func params(id: Id) -> Dictionary:
	match id:
		_:
			return {
				"name": "Roestbol",
				"sky": {
					"horizon": Color(0.62, 0.36, 0.26), "zenith": Color(0.07, 0.05, 0.12),
					"haze": Color(0.85, 0.55, 0.38), "sun_color": Color(1.0, 0.82, 0.62),
					"giant_color": Color(0.55, 0.62, 0.78), "giant_band": Color(0.36, 0.42, 0.6),
					"ring_color": Color(0.82, 0.76, 0.66), "giant_dir": Vector3(-0.55, 0.3, -0.78),
					"giant_size": 0.22, "ring_tilt": 0.32,
				},
				# Laag staande zon: lange schaduwen, warm licht.
				"sun_rotation_deg": Vector3(-24.0, 128.0, 0.0),
				"sun_color": Color(1.0, 0.8, 0.62),
				"sun_energy": 1.25,
				"ambient": Color(0.62, 0.46, 0.42),
				"ambient_energy": 0.42,
				"fog": Color(0.55, 0.36, 0.28),
				"fog_density": 0.0045,
			}
