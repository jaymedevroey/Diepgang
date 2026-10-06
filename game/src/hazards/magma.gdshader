shader_type spatial;
render_mode depth_draw_opaque, cull_back;

// Magma (Magma.gd, release-audit binnen-06): een stijgend lavameer onder de hele concessie.
// - Twee delen met dezelfde shader: een fijn raster rond de camera met reliëf (trage deining,
//   bolle korstplaten, bellen die opzwellen en openspatten), en het grote vlak eronder, dat binnen
//   het raster niet tekent. Het reliëf dooft uit naar de rand van het raster, zodat ze aansluiten.
// - Variatie op twee schalen: grote stukken open lava (fel, met stromende strepen en drijvende
//   korstschotsen) tegenover dichte korst (donkere platen met gloeiende barsten). Zo leest het niet
//   meer als één tegelpatroon (een voetbal).
// - Werkt in wereldmeters: het vlak mag schuiven en groeien zonder dat het patroon meeschuift.

uniform vec3 crust_color : source_color = vec3(0.045, 0.03, 0.026);
uniform vec3 crust_edge : source_color = vec3(0.16, 0.12, 0.11); // afgekoelde, grijzige rand van een plaat
uniform vec3 hot_color : source_color = vec3(1.0, 0.32, 0.04);
uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.32);
uniform float emission_energy = 5.0;
uniform float base_glow = 0.06; // ook de korst gloeit een beetje, nooit pikzwart
uniform float cell_size = 2.6; // meter per korstplaat
uniform float drift = 0.06; // m/s
uniform float relief = 1.0; // hoogte van het reliëf (×, enkel het raster rond de camera)
// Het raster rond de camera: xy = midden (wereld x/z), z = halve breedte (m), w = band waarin het
// reliëf uitdooft (m). Het grote vlak (far_mode) tekent niet binnen het raster.
uniform vec4 near_rect = vec4(0.0);
uniform bool far_mode = false;

varying vec3 wpos;

// Hash zonder sin (Dave Hoskins): sin() van grote getallen is op de GPU onnauwkeurig, en dat gaf
// rechte naden door het patroon.
vec2 hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i).x;
	float b = hash2(i + vec2(1.0, 0.0)).x;
	float c = hash2(i + vec2(0.0, 1.0)).x;
	float d = hash2(i + vec2(1.0, 1.0)).x;
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 cell_point(vec2 cell, float t) {
	vec2 o = hash2(cell);
	return 0.5 + 0.38 * sin(t + 6.2831 * o); // kernen wiebelen traag
}

// Voronoi met de echte afstand tot de rand van de cel (Inigo Quilez, "voronoi edges"): eerst de
// dichtste kern, dan de randen met de buren in 5×5. Met enkel F2 − F1 in 3×3 krijg je rechte naden.
// Geeft (afstand tot de rand, afstand tot de kern); cell = de cel.
vec2 voronoi(vec2 x, float t, out vec2 cell) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + cell_point(n + g, t) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	cell = n + mg;
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + cell_point(n + g, t) - f;
			vec2 dr = r - mr;
			if (dot(dr, dr) > 1e-5) {
				edge = min(edge, dot(0.5 * (mr + r), normalize(dr)));
			}
		}
	}
	return vec2(edge, length(mr));
}

// Open lava (1) of dichte korst (0), in stukken van tientallen meters die traag verschuiven, en
// rivieren: lange, kronkelende stromen open lava tussen de korstvelden (golf 3: van ver geen plaat met
// een celpatroon, maar een meer met stromen).
float openness(vec2 xz, float t) {
	float n = vnoise(xz * 0.05 + vec2(t * 0.004, -t * 0.003)) * 0.65 + vnoise(xz * 0.13 + vec2(7.1, 2.3)) * 0.35;
	vec2 q = xz * 0.028 + vec2(vnoise(xz * 0.017 + vec2(3.3, 1.1)), vnoise(xz * 0.017 + vec2(8.7, 4.2))) * 2.2 + vec2(t * 0.002, 0.0);
	float ridge = 1.0 - abs(vnoise(q) * 2.0 - 1.0);
	return max(smoothstep(0.45, 0.62, n), smoothstep(0.84, 0.95, ridge));
}

// Een bel per cel van 3,5 m (enkel in open lava): x = hoe ver in de bel (1 = rand), y = fase (0..1:
// opzwellen, op het einde openspatten), z = 1 als er nu een bel is.
vec3 bubble(vec2 xz, float t) {
	vec2 bc = floor(xz / 3.5);
	vec2 h = hash2(bc + vec2(17.0, 3.0));
	float period = 2.5 + 3.5 * h.y;
	float ph = fract(t / period + h.x);
	vec2 bp = (bc + 0.3 + 0.4 * hash2(bc + vec2(9.0, 1.0))) * 3.5;
	float r = mix(0.12, 0.7, ph) * (0.6 + 0.4 * h.y);
	return vec3(length(xz - bp) / r, ph, step(0.45, h.x));
}

// Plaatpatroon en reliëf (hoogte in m). Dezelfde functie in vertex en fragment.
vec4 pattern(vec2 xz, float t, out vec2 cell) {
	vec2 p = xz / cell_size + vec2(t * drift, t * drift * 0.55) / cell_size;
	// Kronkelende stroming: het patroon trekt langzaam scheef, op twee schalen (grillige platen van
	// ongelijke grootte, geen regelmatig tegelpatroon).
	vec2 warp = vec2(vnoise(p * 0.35 + t * 0.02), vnoise(p * 0.35 + 19.7 - t * 0.017)) - 0.5;
	vec2 warp2 = vec2(vnoise(p * 0.11 + 4.2), vnoise(p * 0.11 + 31.5)) - 0.5;
	p += warp * 1.3 + warp2 * 3.0;
	vec2 v = voronoi(p, t * 0.12, cell);
	return vec4(v, p);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (!far_mode && near_rect.z > 0.0) {
		vec2 d = abs(wpos.xz - near_rect.xy);
		float k = 1.0 - smoothstep(near_rect.z - near_rect.w, near_rect.z - 1.0, max(d.x, d.y));
		float t = TIME;
		float open = openness(wpos.xz, t);
		vec2 cell;
		vec4 pv = pattern(wpos.xz, t, cell);
		// Korstplaten bol (in de dichte korst), barsten diep; daarover een trage deining.
		float raft = smoothstep(0.0, 0.35, pv.x) * mix(0.45, 0.12, open);
		float swell = 0.22 * sin(wpos.x * 0.19 + t * 0.45) * sin(wpos.z * 0.15 - t * 0.37)
				+ 0.16 * (vnoise(wpos.xz * 0.12 + vec2(t * 0.05)) - 0.5);
		vec3 b = bubble(wpos.xz, t);
		float dome = b.z * open * (1.0 - smoothstep(0.0, 1.0, b.x)) * smoothstep(0.0, 0.85, b.y) * (1.0 - smoothstep(0.9, 1.0, b.y)) * 0.3;
		float h = (raft + swell + dome) * relief * k;
		VERTEX.y += h;
		wpos.y += h;
	}
}

void fragment() {
	if (far_mode && near_rect.z > 0.0) {
		vec2 d = abs(wpos.xz - near_rect.xy);
		if (max(d.x, d.y) < near_rect.z - 1.5) {
			discard; // hier tekent het raster met reliëf
		}
	}
	float t = TIME;
	float open = openness(wpos.xz, t);
	// Van ver lost het celpatroon op in een gloed (anders een tegelvloer tot aan de kim, binnen-06):
	// de barsten doven uit, de warme vlekken en de rivieren blijven.
	float far_k = smoothstep(16.0, 55.0, distance(wpos, CAMERA_POSITION_WORLD));
	vec2 cell;
	vec4 pv = pattern(wpos.xz, t, cell);
	float edge = pv.x; // 0 op de rand tussen twee platen
	float w = fwidth(edge) * 1.5;
	// Niet elke barst is even open: breedte en gloed wisselen langs de barst (trage ruis), en in de
	// open lava zijn de "platen" enkel losse schotsen.
	float crackn = smoothstep(0.2, 0.75, vnoise(pv.zw * 0.9 + vec2(t * 0.05, 3.7)));
	float width = mix(0.015, 0.07, crackn) + open * 0.35;
	// De meeste barsten zijn dof rood, enkele fel (anders een net van neonlijnen).
	float bright = max(smoothstep(0.55, 0.92, crackn), open);
	float crack = (1.0 - smoothstep(0.0, width + w, edge)) * mix(0.18, 1.0, bright);
	float crack_core = (1.0 - smoothstep(0.0, width * 0.35 + w, edge)) * bright;
	// Schotsen in de open lava: enkel een deel van de cellen heeft er een (en kleiner).
	float raft_here = step(open * 0.85, hash2(cell + vec2(4.0, 8.0)).x);
	float lava = max(crack, 1.0 - raft_here);
	// Stromende strepen in de open lava: lichter en donkerder, trekken traag mee.
	vec2 flow = normalize(vec2(0.8, 0.45));
	float along = dot(wpos.xz, flow);
	float across = dot(wpos.xz, vec2(-flow.y, flow.x));
	float streak = vnoise(vec2(along * 0.22 - t * 0.35, across * 1.4)) * 0.6 + vnoise(vec2(along * 0.6 - t * 0.6, across * 3.0)) * 0.4;
	// Grote warme vlekken (meters) die langzaam kloppen; daar is de korst dun.
	float heat = smoothstep(0.25, 0.85, vnoise(wpos.xz * 0.045 + vec2(t * 0.01, -t * 0.013)));
	float pulse = 0.65 + 0.35 * sin(t * 1.1 + heat * 9.0);
	float thin = heat * pulse * smoothstep(0.15, 0.4, edge) * (1.0 - lava) * 0.3; // midden van een plaat gloeit zwak door
	// Bellen: zwellen op, en spatten open met een felle ring.
	vec3 b = bubble(wpos.xz, t);
	float bub = b.z * open * (1.0 - smoothstep(0.85, 1.0, b.x)) * (1.0 - smoothstep(0.9, 1.0, b.y));
	float ring = b.z * open * smoothstep(0.9, 1.0, b.y) * (1.0 - smoothstep(0.0, 0.25, abs(b.x - 1.0 - (b.y - 0.9) * 8.0)));
	// Korst: donker, met een grijzige afgekoelde rand en een bol midden.
	float dome = smoothstep(0.0, 0.3, edge);
	vec3 crust = mix(crust_edge, crust_color, dome) * (0.75 + 0.5 * hash2(cell).x);
	// Afgekoelde korst: grijzige, ruwe schilfers (geen effen zwart).
	crust = mix(crust, crust_edge * 1.4, smoothstep(0.6, 0.85, vnoise(wpos.xz * 1.7 + cell * 3.1)) * 0.5);
	crust = mix(crust, crust_color * 0.8, far_k * 0.6);
	vec3 alb = mix(crust, hot_color * 0.35, lava);
	ALBEDO = alb;
	ROUGHNESS = mix(0.92, 0.55, lava);
	METALLIC = 0.0;
	SPECULAR = 0.25;
	// Gloed: barsten en open lava fel, met strepen; schotsen enkel aan hun rand.
	float open_glow = (1.0 - raft_here) * mix(0.12, 0.6, streak * streak);
	float glow = (crack * (0.55 + 0.6 * heat) * (1.0 - open * 0.6) + crack_core * 0.8 * (1.0 - open * 0.5)) * (1.0 - 0.8 * far_k)
			+ far_k * (0.06 + 0.22 * heat) * (1.0 - open) + thin * 0.35 + open_glow + bub * 0.4 + ring * 2.0;
	vec3 deep = vec3(0.6, 0.06, 0.01); // dof rood: barsten die bijna dicht zijn
	vec3 e = mix(deep, hot_color, clamp(bright + heat * 0.5, 0.0, 1.0));
	e = mix(e, core_color, clamp(crack_core * 0.8 * (1.0 - open) + heat * crack * 0.4 + (1.0 - raft_here) * smoothstep(0.6, 0.9, streak) * 0.8 + ring + bub * 0.4, 0.0, 1.0));
	EMISSION = e * (glow * emission_energy + base_glow * (0.6 + heat));
	// Facetten van het reliëf (van dichtbij, op het raster): de normaal uit de vorm zelf.
	if (!far_mode) {
		vec3 nw = normalize(cross(dFdy(wpos), dFdx(wpos)));
		if (nw.y < 0.0) {
			nw = -nw;
		}
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
