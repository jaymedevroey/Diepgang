shader_type sky;

// Hemel boven een planeet (GDD v3 §4, §8): stoffige horizon, donkere top, een kleine zon met gloed,
// een grote geringde planeet laag aan de hemel, en sterren waar de lucht donker genoeg is.
// Alle kleuren en richtingen per planeettype (PlanetType).

uniform vec3 horizon : source_color = vec3(0.62, 0.36, 0.26);
uniform vec3 zenith : source_color = vec3(0.07, 0.05, 0.12);
uniform vec3 haze : source_color = vec3(0.85, 0.55, 0.38);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.62);
uniform vec3 giant_color : source_color = vec3(0.55, 0.62, 0.78);
uniform vec3 giant_band : source_color = vec3(0.36, 0.42, 0.6);
uniform vec3 ring_color : source_color = vec3(0.82, 0.76, 0.66);
uniform vec3 giant_dir = vec3(-0.55, 0.32, -0.77);
uniform float giant_size = 0.22; // hoekstraal (radialen)
uniform float ring_tilt = 0.32;
uniform float star_density = 0.0012;
uniform float stars_from = 0.55; // pas sterren hoog in de lucht (overdag zie je er weinig)

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

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -0.2, 1.0);
	vec3 col = mix(horizon, zenith, pow(clamp(up, 0.0, 1.0), 0.55));
	// Stofband net boven de horizon.
	col = mix(col, haze, exp(-abs(up) * 9.0) * 0.55);
	// Onder de horizon: donkerder (het verre landschap dekt dit meestal af).
	if (up < 0.0) {
		col = mix(col, horizon * 0.45, smoothstep(0.0, -0.15, up));
	}

	// Sterren, vooral in het donkere deel en niet bij de zon.
	vec3 sun = normalize(LIGHT0_DIRECTION);
	float sun_d = dot(d, sun);
	vec3 cell = floor(d * 360.0);
	float h = hash(cell);
	if (h < star_density && d.y > stars_from) {
		float tw = 0.65 + 0.35 * sin(TIME * (1.0 + h * 700.0) + h * 6283.0);
		col += vec3(0.9, 0.92, 1.0) * tw * smoothstep(stars_from, stars_from + 0.3, d.y) * (1.0 - smoothstep(0.8, 0.98, sun_d)) * 0.6;
	}
	// Nevelslierten (zacht, groot).
	float neb = vnoise(d * 3.0 + vec3(4.0)) * vnoise(d * 7.0 - vec3(2.0));
	col += vec3(0.32, 0.18, 0.4) * smoothstep(0.25, 0.6, neb) * smoothstep(0.25, 0.7, d.y) * 0.12;

	// Grote planeet met banden en een ring.
	vec3 g = normalize(giant_dir);
	float gd = acos(clamp(dot(d, g), -1.0, 1.0));
	vec3 gx = normalize(cross(g, vec3(0.0, 1.0, 0.0)));
	vec3 gy = normalize(cross(gx, g));
	vec2 q = vec2(dot(d - g, gx), dot(d - g, gy)) / giant_size;
	// Ring: een ellips in het vlak van de planeet, gekanteld.
	vec2 rq = vec2(q.x, q.y / ring_tilt);
	float rr = length(rq);
	float ring = smoothstep(1.35, 1.42, rr) * (1.0 - smoothstep(2.05, 2.15, rr));
	ring *= 0.55 + 0.45 * sin(rr * 40.0);
	bool behind_ring = q.y > 0.0; // bovenste helft van de ring ligt achter de planeet
	if (gd < giant_size) {
		float lat = q.y;
		float bands = 0.5 + 0.5 * sin(lat * 13.0 + vnoise(vec3(q * 3.0, 1.0)) * 2.5);
		vec3 gcol = mix(giant_color, giant_band, bands);
		// Belicht vanuit de zon: dag-nachtkant.
		vec3 nrm = normalize(g + (gx * q.x + gy * q.y) * giant_size * 0.9);
		float lit = clamp(dot(nrm, sun) * 0.9 + 0.25, 0.08, 1.0);
		vec3 gfinal = gcol * lit;
		// Rand van de schijf zacht in de lucht laten overgaan.
		float edge = smoothstep(giant_size, giant_size * 0.96, gd);
		col = mix(col, gfinal, edge);
		if (!behind_ring) {
			col = mix(col, ring_color * lit, ring * 0.85);
		}
	} else {
		col = mix(col, ring_color * 0.8, ring * 0.7);
		// Dunne atmosfeer rond de reus.
		col += giant_color * exp(-(gd - giant_size) * 60.0) * 0.12;
	}

	// Zon: kleine schijf, gloed en een brede waas.
	col += sun_color * smoothstep(0.9992, 0.9996, sun_d) * 6.0;
	col += sun_color * pow(max(sun_d, 0.0), 260.0) * 1.6;
	col += haze * pow(max(sun_d, 0.0), 8.0) * 0.35;
	COLOR = col;
}
