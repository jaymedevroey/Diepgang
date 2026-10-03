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

// --- Lucht ---------------------------------------------------------------------------------
uniform vec3 zenith : source_color = vec3(0.63, 0.44, 0.37);
uniform vec3 mid_sky : source_color = vec3(0.79, 0.59, 0.48);
uniform vec3 horizon : source_color = vec3(0.91, 0.77, 0.6);
uniform vec3 haze_band : source_color = vec3(0.95, 0.85, 0.71);
uniform vec3 aureole : source_color = vec3(0.66, 0.77, 0.85); // krans rond de zon (stof stuurt blauw naar voren)
uniform vec3 space : source_color = vec3(0.23, 0.16, 0.29); // wat erachter zit (hoog in de lucht zichtbaar)
uniform float sky_energy = 1.25;
uniform float dust_tau = 0.55; // optische dikte recht omhoog, aan de grond
uniform float haze_height = 900.0; // m: hoe snel de lucht dunner wordt met de hoogte
uniform float planet_radius = 30000.0; // m, gestileerd (kimdaling van hoog in de lucht)
uniform float surface_y = 285.0; // hoogte van het oppervlak in de wereld (m)
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.9);
uniform float sun_size_deg = 1.4;
uniform float sun_radiance = 30.0;
uniform float star_density = 0.0016;

// --- Grond onder de horizon ----------------------------------------------------------------
uniform vec3 ground_lit : source_color = vec3(0.71, 0.33, 0.18);
uniform vec3 ground_shadow : source_color = vec3(0.35, 0.18, 0.21);
uniform float ground_fog_density = 0.005; // per m aan de grond
uniform float ground_fog_height = 80.0; // m

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


float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.03) * 0.3 + vnoise(p * 4.1) * 0.2;
}

// Henyey-Greenstein: hoe sterk licht naar voren verstrooid wordt (g ≈ 0,65 voor stof).
float hg(float mu, float g) {
	float g2 = g * g;
	return (1.0 - g2) / (4.0 * PI * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// Luchtmassa (Kasten–Young), e = hoogte boven de echte horizon in radialen.
float airmass(float e) {
	float deg = max(degrees(e), 0.0);
	return 1.0 / (sin(max(e, 0.0)) + 0.50572 * pow(deg + 6.07995, -1.6364));
}

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

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
			// Profiel: drie banden en één duidelijke opening, een vage stofrand buiten.
			float dens = smoothstep(0.0, 0.06, x) * (1.0 - smoothstep(0.93, 1.0, x));
			dens *= 0.55 + 0.45 * sin(x * 38.0 + vnoise(vec3(x * 60.0, 1.0, 2.0)) * 2.0);
			dens *= 1.0 - 0.9 * (smoothstep(0.55, 0.58, x) - smoothstep(0.62, 0.65, x)); // de opening
			dens *= mix(1.0, 0.35, smoothstep(0.75, 0.95, x));
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
		col += giant_base * pow(1.0 - view, 4.0) * smoothstep(-0.2, 0.4, ndl) * 0.8; // atmosfeerrand
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
	float dip = sqrt(2.0 * alt / planet_radius);
	float e = asin(clamp(d.y, -1.0, 1.0)) + dip; // hoogte boven de echte horizon
	float k = exp(-alt / haze_height); // lucht boven de camera
	vec3 tint = vec3(0.8, 1.0, 1.35); // stof slorpt blauw op
	float sun_e = asin(clamp(s.y, -1.0, 1.0)) + dip;
	vec3 t_sun = exp(-dust_tau * k * airmass(sun_e) * tint);

	// Waas (verstrooid licht): verloop van horizon over midden naar zenit, een waasband vlak boven
	// de horizon, en de gloed rond de zon (twee overgangen tegelijk: van onder en van opzij).
	float el = clamp(e / (PI * 0.5), 0.0, 1.0);
	vec3 haze = mix(horizon, mid_sky, smoothstep(0.0, 0.3, el));
	haze = mix(haze, zenith, smoothstep(0.3, 1.0, el));
	haze = mix(haze, haze_band, exp(-max(e, 0.0) * 14.0) * 0.6);
	haze *= mix(0.85, 1.15, smoothstep(-0.6, 1.0, mu)); // zonkant iets lichter
	haze += aureole * hg(mu, 0.65) * 2.2 * t_sun;
	haze += sun_color * hg(mu, 0.92) * 0.35 * t_sun;
	haze *= sky_energy;

	vec3 col;
	if (e >= 0.0) {
		vec3 T = exp(-dust_tau * k * airmass(e) * tint);
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
		bg = mix(bg, g.rgb * 1.6, g.a);
		// Sterren enkel waar de lucht donker genoeg is (de reus is fel genoeg om er altijd te zijn).
		float dark = 1.0 - smoothstep(0.03, 0.2, luminance(haze * (1.0 - T)));
		vec3 visible_bg = mix(bg * dark, bg, g.a);
		col = visible_bg * T + (1.0 - T) * haze;
		// Zon: kleine schijf met randverdonkering, door de atmosfeer.
		float cosr = cos(radians(sun_size_deg));
		if (mu > cosr) {
			float r = sqrt(clamp((1.0 - mu) / (1.0 - cosr), 0.0, 1.0));
			col += sun_color * sun_radiance * (1.0 - 0.6 * r * r) * t_sun * smoothstep(1.0, 0.85, r);
		}
	} else {
		// Virtuele grond (van hoog in de lucht): roest met donkere vlekken, zon en schaduw, en de
		// nevel van de stoflaag (exacte integraal over de hoogte, Inigo Quilez).
		float dy = max(-sin(e), 1e-4);
		float dist = (alt + 2.0) / dy;
		vec3 hit = POSITION + d * dist;
		float patches = fbm(hit * 0.004) * 0.7 + fbm(hit * 0.02) * 0.3;
		vec3 ground = mix(ground_shadow, ground_lit, smoothstep(0.25, 0.75, patches));
		ground *= 0.35 + 0.65 * max(s.y, 0.0) * 1.4;
		float b = 1.0 / ground_fog_height;
		float tau = ground_fog_density / b * exp(-b * 0.0) * (1.0 - exp(-b * (alt + 2.0))) / dy;
		vec3 Tg = exp(-tau * tint);
		vec3 far_haze = mix(horizon, haze_band, 0.5) * sky_energy + aureole * hg(mu, 0.65) * 1.5 * t_sun;
		col = ground * Tg + (1.0 - Tg) * far_haze;
		// Net onder de horizon zacht in de waas laten overgaan.
		col = mix(col, haze, exp(e * 40.0));
	}
	COLOR = col;
}
