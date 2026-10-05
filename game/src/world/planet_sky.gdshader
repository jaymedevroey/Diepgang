shader_type sky;

// Hemel boven een planeet (docs/research/hemel.md, niveau A): kleuren van een kunstenaar, verdeeld
// met natuurkundig gemotiveerde gewichten. Hemellichamen staan ACHTER de atmosfeer:
//     lucht = achtergrond × T + (1 − T) × waas
// T (doorlaatbaarheid) hangt af van hoeveel lucht je doorkijkt (luchtmassa) en hoe hoog de camera
// hangt: laag bij de horizon is T klein (alles verdwijnt in de waas), hoog in de lucht wordt het
// zenit donkerder. Zo verdwijnen sterren overdag en dooft de reus bij de horizon vanzelf.
// Onder de horizon: een virtuele grond met nevel (van hoog in de lucht zie je de planeet).
// De geringde reus is echt 3D: bol en ringvlak, met schaduw van de ring op de planeet en van de
// planeet op de ring, en licht dat door de ring valt als de zon erachter staat.
// Alle kleuren en richtingen per planeettype (PlanetType).

// --- Lucht en grond: planet_air.gdshaderinc (gedeeld met het planeetdek onder de hub) --------
#include "res://src/world/planet_air.gdshaderinc"

uniform vec3 space : source_color = vec3(0.23, 0.16, 0.29); // wat erachter zit (hoog in de lucht zichtbaar)
uniform float sun_size_deg = 1.4;
uniform float sun_radiance = 30.0;
uniform float star_density = 0.0016;

// --- De reus --------------------------------------------------------------------------------
uniform vec3 giant_dir = vec3(-0.55, 0.38, -0.74);
uniform float giant_radius_deg = 9.5;
uniform vec3 giant_base : source_color = vec3(0.5, 0.64, 0.72);
uniform vec3 giant_band : source_color = vec3(0.31, 0.46, 0.56);
uniform vec3 giant_storm : source_color = vec3(0.85, 0.89, 0.91);
uniform vec3 giant_night : source_color = vec3(0.23, 0.14, 0.13); // planeetschijn (roest)
uniform float ring_open_deg = 20.0; // hoe ver de ring openstaat voor wie kijkt (0 = op de kant)
uniform float ring_roll_deg = 15.0; // kanteling van de ring in beeld
uniform float ring_inner = 1.45; // in straal van de planeet
uniform float ring_outer = 2.35;
uniform vec3 ring_color : source_color = vec3(0.9, 0.84, 0.74);
uniform vec3 ring_glow : source_color = vec3(0.75, 0.85, 0.91); // van achteren belicht
// Hoeveel van de waas vóór de reus en zijn ringen hangt (1 = natuurgetrouw, zoals de lucht zelf).
// Natuurgetrouw verdwijnt hij op 20-25° hoogte voor ±75% in de lichte lucht: een doorzichtige schijf.
// Gestileerd: minder waas, zodat hij als een vast lichaam (met zijn eigen kleur) in de lucht staat.
uniform float giant_haze = 0.35;


// Schijf en ring van de reus. Camera in de oorsprong, planeet op afstand 1. Geeft rgb + alfa.
vec4 giant(vec3 d, vec3 s) {
	vec3 C = normalize(giant_dir);
	float rp = sin(radians(giant_radius_deg));
	// Normaal van het ringvlak: maakt `ring_open_deg` met de kijkrichting, gekanteld met `ring_roll_deg`.
	vec3 up = normalize(vec3(0.0, 1.0, 0.0) - C * C.y);
	vec3 side = normalize(cross(C, up));
	float roll = radians(ring_roll_deg);
	vec3 u = up * cos(roll) + side * sin(roll);
	float op = radians(ring_open_deg);
	vec3 n = normalize(u * cos(op) - C * sin(op));
	// Bol.
	float b = dot(d, C);
	float h = b * b - (dot(C, C) - rp * rp);
	float tp = h > 0.0 ? b - sqrt(h) : -1.0;
	// Ringvlak.
	float dn = dot(d, n);
	float tr = abs(dn) > 1e-5 ? dot(C, n) / dn : -1.0;
	vec4 ring = vec4(0.0);
	if (tr > 0.0) {
		vec3 q = d * tr - C;
		float r = length(q) / rp;
		float x = (r - ring_inner) / (ring_outer - ring_inner);
		if (x > 0.0 && x < 1.0) {
			// Profiel zoals Saturnus, gestileerd (hemel.md: 2-3 banden, één duidelijke opening, een vage
			// stoffige buitenring): een dunne, vage binnenring; de brede, dichte hoofdring (naar buiten
			// toe dichter); een duidelijke donkere opening; een tweede, minder dichte ring met een smalle
			// opening; en een stofring die uitdooft. Geen gelijke lijnen (dat leek een vinylplaat).
			float inner = 0.2 * smoothstep(0.0, 0.05, x) * (1.0 - smoothstep(0.16, 0.19, x));
			float main_r = mix(0.72, 1.0, smoothstep(0.2, 0.5, x)) * smoothstep(0.17, 0.21, x) * (1.0 - smoothstep(0.52, 0.545, x));
			float outer_r = 0.62 * smoothstep(0.6, 0.625, x) * (1.0 - smoothstep(0.83, 0.86, x));
			outer_r *= 1.0 - 0.8 * (smoothstep(0.755, 0.765, x) - smoothstep(0.78, 0.79, x));
			float dusty = 0.13 * smoothstep(0.83, 0.87, x) * (1.0 - smoothstep(0.88, 1.0, x));
			float dens = inner + main_r + outer_r + dusty;
			// Fijne ringetjes als textuur (zwak, en weg waar ze kleiner zijn dan een pixel).
			float fine = 1.0 - smoothstep(0.002, 0.008, fwidth(x));
			dens *= 1.0 + 0.22 * (vnoise(vec3(x * 170.0, 0.5, 0.5)) - 0.5) * fine + 0.18 * (vnoise(vec3(x * 34.0, 2.5, 0.5)) - 0.5);
			dens = clamp(dens, 0.0, 1.0); // boven 1 wordt het tegenlicht (dens · (1 − dens)) negatief
			// Schaduw van de planeet op de ring.
			vec3 Q = d * tr;
			vec3 qc = Q - C;
			float behind = dot(qc, s);
			float shade = 1.0;
			if (behind < 0.0) {
				float dist = length(qc - s * behind);
				shade = smoothstep(rp * 0.97, rp * 1.03, dist);
			}
			// Belichte of onbelichte kant (zon en camera aan dezelfde kant van het vlak?).
			bool lit_side = sign(dot(s, n)) == sign(dot(-C, n));
			vec3 col;
			if (lit_side) {
				col = ring_color * (0.35 + 0.65 * abs(dot(s, n))) * shade;
			} else {
				col = ring_glow * dens * (1.0 - dens) * 4.0 * hg(dot(d, s), 0.6) * 6.0 * shade + ring_color * 0.06;
			}
			ring = vec4(col, clamp(dens, 0.0, 1.0) * 0.9);
		}
	}
	vec4 planet = vec4(0.0);
	if (tp > 0.0) {
		vec3 P = d * tp;
		vec3 N = normalize(P - C);
		float lat = asin(clamp(dot(N, n), -1.0, 1.0));
		vec3 east = normalize(cross(n, vec3(0.0, 1.0, 0.0) + n * 0.001));
		float lon = atan(dot(N, east), dot(N, cross(n, east)));
		float warp = fbm(vec3(lat * 6.0, lon * 1.5, 3.0)) * 1.6;
		float bands = 0.5 + 0.5 * sin(lat * 14.0 + warp);
		vec3 albedo = mix(giant_base, giant_band, smoothstep(0.35, 0.75, bands));
		// Eén storm als blikvanger.
		float storm = smoothstep(0.16, 0.08, length(vec2(lat + 0.32, (lon - 0.6) * 0.55)));
		albedo = mix(albedo, giant_storm, storm * 0.85);
		float ndl = dot(N, s);
		float day = smoothstep(-0.05, 0.25, ndl);
		// Schaduw van de ring op de planeet.
		float sn = dot(s, n);
		if (abs(sn) > 1e-4) {
			float t2 = -dot(P - C, n) / sn;
			if (t2 > 0.0) {
				float r2 = length(P + s * t2 - C) / rp;
				float x2 = (r2 - ring_inner) / (ring_outer - ring_inner);
				if (x2 > 0.0 && x2 < 1.0) {
					day *= 1.0 - 0.75 * smoothstep(0.0, 0.08, x2) * (1.0 - smoothstep(0.9, 1.0, x2));
				}
			}
		}
		float view = clamp(dot(N, -d), 0.0, 1.0);
		vec3 col = albedo * (0.12 + 0.88 * max(ndl, 0.0)) * day * mix(0.6, 1.0, pow(view, 0.4));
		col += giant_night * (1.0 - day) * 0.6; // planeetschijn
		// Atmosfeerrand aan de zonkant: bij een sikkel (de zon achter de reus) een felle lichtrand.
		col += mix(giant_base, giant_storm, 0.5) * pow(1.0 - view, 2.2) * smoothstep(-0.05, 0.45, ndl) * 1.1;
		float edge = smoothstep(0.0, 0.003, h / max(rp, 1e-4)); // zachte rand
		planet = vec4(col, edge);
	}
	// Dichtste eerst: ring vóór de planeet als het ringpunt dichterbij ligt.
	if (planet.a > 0.0 && ring.a > 0.0 && tr < tp) {
		return vec4(mix(planet.rgb, ring.rgb, ring.a), max(planet.a, ring.a));
	}
	if (planet.a > 0.0) {
		return planet;
	}
	return ring;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// Onder de grond staat de zon uit (Atmosphere): dan is LIGHT0_DIRECTION nul, en normalize(0)
	// geeft NaN. Een NaN in de hemel zit dan ook in de weerkaatsing van elk materiaal: alles zwart.
	vec3 s = (LIGHT0_ENABLED && dot(LIGHT0_DIRECTION, LIGHT0_DIRECTION) > 1e-6) ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);
	float mu = dot(d, s);
	float alt = max(POSITION.y - surface_y, 0.0);
	float dip = air_dip(alt);
	float e = asin(clamp(d.y, -1.0, 1.0)) + dip; // hoogte boven de echte horizon
	float k = exp(-alt / haze_height); // lucht boven de camera
	vec3 t_sun = air_sun_t(s, k, dip);
	vec3 haze = air_haze(e, mu, t_sun);

	vec3 col;
	if (e >= 0.0) {
		vec3 T = exp(-dust_tau * k * airmass(e) * DUST_TINT);
		// Achtergrond: de ruimte, sterren, de reus en zijn ringen.
		vec3 bg = space * 0.35;
		if (!AT_CUBEMAP_PASS) {
			vec3 cell = floor(d * 420.0);
			float hs = hash(cell);
			if (hs < star_density) {
				float tw = 0.7 + 0.3 * sin(TIME * (1.0 + hs * 600.0) + hs * 6283.0);
				bg += vec3(1.0, 0.97, 0.92) * tw * 2.5;
			}
		}
		vec4 g = giant(d, s);
		// Sterren enkel waar de lucht echt donker is: hoog boven het stof (de hub), niet in de lichte
		// waas van de drop of aan de grond.
		float dark = 1.0 - smoothstep(0.01, 0.06, luminance(haze * (1.0 - T)));
		col = bg * dark * T + (1.0 - T) * haze;
		// De reus en zijn ringen achter minder waas (giant_haze): ondoorzichtig, in hun eigen kleur.
		vec3 Tg = exp(-dust_tau * giant_haze * k * airmass(e) * DUST_TINT);
		vec3 giant_col = g.rgb * 1.6 * Tg + (1.0 - Tg) * haze;
		col = mix(col, giant_col, g.a);
		// Zon: kleine schijf met randverdonkering, door de atmosfeer.
		float cosr = cos(radians(sun_size_deg));
		if (mu > cosr) {
			float r = sqrt(clamp((1.0 - mu) / (1.0 - cosr), 0.0, 1.0));
			col += sun_color * sun_radiance * (1.0 - 0.6 * r * r) * t_sun * smoothstep(1.0, 0.85, r);
		}
	} else {
		// De planeet onder je (van hoog in de lucht, of voorbij het verre landschap).
		col = planet_ground(POSITION, d, s, alt, e, mu, t_sun, haze, !AT_CUBEMAP_PASS);
	}
	COLOR = col;
}
