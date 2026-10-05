// De lucht en de planeet onder de horizon (docs/research/hemel.md), gedeeld door de hemel
// (planet_sky.gdshader) en het planeetdek onder de hub (planet_deck.gdshader). Zo tekenen ze exact
// hetzelfde: waar het dek ophoudt, gaat de hemel naadloos verder.
//   waas        verloop horizon - midden - zenit, waasband, krans rond de zon
//   grond       een bol met straal planet_radius recht onder de camera (dezelfde kromming als het
//               verre landschap in PlanetSurface), in het kleipalet van de rotsshader, belicht door
//               de zon en het omgevingslicht zoals het echte terrein, met kraters en mesa's;
//               daarover de stofnevel (dicht aan de grond, dunner hogerop).

// --- Lucht ---------------------------------------------------------------------------------
uniform vec3 zenith : source_color = vec3(0.63, 0.44, 0.37);
uniform vec3 mid_sky : source_color = vec3(0.79, 0.59, 0.48);
uniform vec3 horizon : source_color = vec3(0.91, 0.77, 0.6);
uniform vec3 haze_band : source_color = vec3(0.95, 0.85, 0.71);
uniform vec3 aureole : source_color = vec3(0.66, 0.77, 0.85); // krans rond de zon (stof stuurt blauw naar voren)
// Hoe sterk de lucht rond de zon de kleur van de krans aanneemt (0 = enkel het lichte schijnsel erbovenop,
// dat na AgX wit wordt). Mars: een blauwe krans in een karamel lucht (hemel A).
uniform float aureole_mix = 0.0;
uniform float sky_energy = 1.25;
uniform float dust_tau = 0.55; // optische dikte recht omhoog, aan de grond
uniform float haze_height = 900.0; // m: hoe snel de lucht dunner wordt met de hoogte
uniform float planet_radius = 30000.0; // m, gestileerd (kimdaling van hoog in de lucht)
uniform float surface_y = 285.0; // hoogte van het oppervlak in de wereld (m)
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.9); // de zonneschijf

// --- Grond onder de horizon ----------------------------------------------------------------
// Albedo zoals het verre terrein er gemiddeld uitziet (klei met stof op de vlakken).
uniform vec3 ground_light : source_color = vec3(0.64, 0.44, 0.31);
uniform vec3 ground_base : source_color = vec3(0.5, 0.33, 0.23);
uniform vec3 ground_dark : source_color = vec3(0.3, 0.18, 0.13);
// Het licht van de zon (DirectionalLight van Atmosphere) en het omgevingslicht.
uniform vec3 sun_light : source_color = vec3(1.0, 0.91, 0.82);
uniform float sun_energy = 1.3;
uniform vec3 ambient_color : source_color = vec3(0.69, 0.53, 0.47);
uniform float ambient_energy = 0.42;
uniform float ground_fog_density = 0.0035; // per m aan de grond
uniform float ground_fog_height = 80.0; // m

const vec3 DUST_TINT = vec3(0.8, 1.0, 1.35); // stof slorpt blauw op

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

// Hash zonder sin (Dave Hoskins): geen naden bij grote coördinaten.
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
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

// Kimdaling: zo ver zakt de horizon onder de horizontale lijn op hoogte `alt` (m).
float air_dip(float alt) {
	return sqrt(2.0 * alt / planet_radius);
}

// Doorlaatbaarheid van de lucht voor het zonlicht (k = lucht boven de camera).
vec3 air_sun_t(vec3 s, float k, float dip) {
	float sun_e = asin(clamp(s.y, -1.0, 1.0)) + dip;
	return exp(-dust_tau * k * airmass(sun_e) * DUST_TINT);
}

// Waas (verstrooid licht): verloop van horizon over midden naar zenit, een waasband vlak boven
// de horizon, en de gloed rond de zon (twee overgangen tegelijk: van onder en van opzij).
vec3 air_haze(float e, float mu, vec3 t_sun) {
	float el = clamp(e / (PI * 0.5), 0.0, 1.0);
	vec3 haze = mix(horizon, mid_sky, smoothstep(0.0, 0.3, el));
	haze = mix(haze, zenith, smoothstep(0.3, 1.0, el));
	haze = mix(haze, haze_band, exp(-max(e, 0.0) * 14.0) * 0.6);
	haze *= mix(0.85, 1.15, smoothstep(-0.6, 1.0, mu)); // zonkant iets lichter
	// De krans: binnen ±25° van de zon kleurt de waas naar de krans, met dezelfde helderheid (anders
	// telt het enkel als licht, en dat maakt de tonemapper wit). Het schijnsel erbovenop wordt kleiner.
	float aw = aureole_mix * (1.0 - smoothstep(0.05, 0.5, acos(clamp(mu, -1.0, 1.0))));
	haze = mix(haze, aureole * luminance(haze) / max(luminance(aureole), 1e-3) * 1.12, aw);
	haze += aureole * hg(mu, 0.65) * 2.2 * t_sun * (1.0 - 0.6 * aureole_mix);
	haze += sun_color * hg(mu, 0.92) * 0.35 * t_sun;
	return haze * sky_energy;
}

float fbm2(vec2 p) {
	return fbm(vec3(p, 1.7));
}

// Grof reliëf van de verre planeet (m): mesa's met vlakke toppen en brede ruggen.
float air_relief(vec2 p) {
	float mesa = smoothstep(0.58, 0.63, fbm2(p / 2600.0 + 11.0));
	return 90.0 * mesa + 45.0 * (fbm2(p / 950.0 + 3.0) - 0.5);
}

// Kraters (één per cel van 420 m, niet in elke cel): x = kleurfactor, yz = helling (dh/dx, dh/dz).
vec3 air_craters(vec2 p, float fp) {
	const float CELL = 420.0;
	vec2 cell = floor(p / CELL);
	vec3 res = vec3(1.0, 0.0, 0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 c = cell + vec2(float(i), float(j));
			vec2 h = hash22(c + 17.0);
			if (h.x > 0.62) {
				continue;
			}
			vec2 cc = (c + 0.2 + 0.6 * hash22(c + 3.1)) * CELL;
			float r = mix(40.0, 160.0, h.y * h.y);
			vec2 dv = p - cc;
			float dl = length(dv);
			float d = dl / r;
			if (d > 1.8) {
				continue;
			}
			// Zelfde profiel als PlanetGenerator._crater_profile (kom tot d = 1, opstaande rand).
			float dprof = (d < 1.0 ? 2.0 * d : 0.0) + 0.32 * exp(-pow((d - 1.0) / 0.22, 2.0)) * (-2.0 * (d - 1.0) / (0.22 * 0.22));
			float vis = smoothstep(2.0, 6.0, r / max(fp, 1e-3)); // te klein voor een pixel: weg
			vec2 dir = dv / max(dl, 1e-3);
			res.yz += dir * dprof * 0.2 * vis; // diepte 0,2 r: helling = dprof · 0,2
			float floor_k = 1.0 - smoothstep(0.6, 1.0, d);
			float rim_k = exp(-pow((d - 1.05) / 0.16, 2.0));
			float ejecta = 1.0 - smoothstep(1.0, 1.8, d);
			res.x *= mix(1.0, (1.0 - 0.18 * floor_k) * (1.0 + 0.1 * rim_k) * (1.0 + 0.05 * ejecta), vis);
		}
	}
	return res;
}

// De planeet onder de horizon, gezien vanaf `ro` in richting `d` (e < 0). `haze` = de waas net
// boven de horizon in die richting (voor de overgang), `detail` = kraters en reliëf (niet in de
// kleine cubemap van de hemel).
vec3 planet_ground(vec3 ro, vec3 d, vec3 s, float alt, float e, float mu, vec3 t_sun, vec3 haze, bool detail) {
	// Snijden met de bol (middelpunt recht onder de camera, zoals de kimdaling).
	float R = planet_radius;
	vec3 C = vec3(ro.x, surface_y - R, ro.z);
	vec3 oc = ro - C;
	float b = dot(oc, d);
	float c = dot(oc, oc) - R * R;
	float disc = b * b - c;
	float t = disc > 0.0 ? -b - sqrt(disc) : sqrt(max(c, 0.0)); // net ernaast: langs de raaklijn
	t = max(t, 0.0);
	vec3 hit = ro + d * t;
	vec3 N = normalize(hit - C);
	vec2 p = hit.xz;
	float fp = t * 0.0015 + 0.5; // ±m per pixel daar
	// Albedo: grote vlekken (puinvelden, stofvlakten), kleinere vervagen met de afstand.
	float v = fbm2(p / 1700.0) * 0.5 + fbm2(p / 380.0 + 3.7) * 0.35;
	v += mix(0.5, fbm2(p / 90.0 + 9.1), 1.0 - smoothstep(10.0, 40.0, fp)) * 0.15;
	vec3 alb = mix(ground_dark, ground_base, smoothstep(0.3, 0.46, v));
	alb = mix(alb, ground_light, smoothstep(0.54, 0.7, v));
	vec3 n = N;
	if (detail) {
		vec3 cr = air_craters(p, fp);
		alb *= cr.x;
		// Helling van het reliëf (eindige verschillen) plus die van de kraters.
		float eps = max(60.0, fp * 2.0);
		float h0 = air_relief(p);
		vec2 g = vec2(air_relief(p + vec2(eps, 0.0)) - h0, air_relief(p + vec2(0.0, eps)) - h0) / eps;
		g += cr.yz;
		float mesa = smoothstep(0.58, 0.63, fbm2(p / 2600.0 + 11.0));
		alb = mix(alb, ground_dark * 1.25, mesa * 0.35); // mesa's: donkere kap
		n = normalize(N - vec3(g.x, 0.0, g.y));
	}
	float ndl = max(dot(n, s), 0.0);
	vec3 lit = alb * (sun_light * sun_energy * ndl + ambient_color * ambient_energy);
	// Stofnevel tussen camera en grond: dicht aan de grond, schaalhoogte ground_fog_height. Op een
	// bol loopt een scherende straal lang door de onderste laag: de invalshoek op de grond telt.
	float H = ground_fog_height;
	float cos_i = max(dot(-d, N), 0.6 * sqrt(2.0 * H / R));
	float tau = ground_fog_density * H * (1.0 - exp(-(alt + 2.0) / H)) / cos_i;
	vec3 Tg = exp(-tau * DUST_TINT);
	vec3 far_haze = mix(horizon, haze_band, 0.5) * sky_energy + aureole * hg(mu, 0.65) * 1.5 * t_sun;
	// Recht naar beneden kijk je door een dunne, door de zon belichte stoflaag: die is minder fel
	// dan de waas aan de kim (waar je er kilometers door kijkt). Zo blijft de planeet leesbaar.
	far_haze *= mix(1.0, 0.4, smoothstep(0.1, 0.8, cos_i));
	vec3 col = lit * Tg + (1.0 - Tg) * far_haze;
	// Net onder de horizon zacht in de waas laten overgaan.
	return mix(col, haze, exp(e * 40.0));
}
