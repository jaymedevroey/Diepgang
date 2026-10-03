shader_type spatial;
render_mode depth_draw_opaque;

// Magma (Magma.gd): één groot vlak onder de hele concessie. Donkere korstplaten die traag drijven,
// felle barsten ertussen, en grote warme vlekken die langzaam kloppen. Werkt in wereldmeters,
// zodat het vlak mag schuiven en groeien zonder dat het patroon meeschuift.

uniform vec3 crust_color : source_color = vec3(0.07, 0.035, 0.025);
uniform vec3 hot_color : source_color = vec3(1.0, 0.32, 0.04);
uniform vec3 core_color : source_color = vec3(1.0, 0.78, 0.32);
uniform float emission_energy = 5.0;
uniform float base_glow = 0.06; // ook de korst gloeit een beetje, nooit pikzwart
uniform float cell_size = 2.6; // meter per korstplaat
uniform float drift = 0.06; // m/s

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
// Geeft (afstand tot de rand, afstand tot de kern).
vec2 voronoi(vec2 x, float t) {
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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	vec2 p = wpos.xz / cell_size + vec2(t * drift, t * drift * 0.55) / cell_size;
	// Kronkelende stroming: het patroon trekt langzaam scheef.
	vec2 warp = vec2(vnoise(p * 0.35 + t * 0.02), vnoise(p * 0.35 + 19.7 - t * 0.017)) - 0.5;
	p += warp * 1.1;
	vec2 v = voronoi(p, t * 0.12);
	float edge = v.x; // 0 op de rand tussen twee platen
	float w = fwidth(edge) * 1.5;
	// Niet elke barst is even open: breedte en gloed wisselen langs de barst (trage ruis).
	float open = smoothstep(0.2, 0.75, vnoise(p * 0.9 + vec2(t * 0.05, 3.7)));
	float width = mix(0.015, 0.07, open);
	float crack = (1.0 - smoothstep(0.0, width + w, edge)) * mix(0.25, 1.0, open);
	float crack_core = (1.0 - smoothstep(0.0, width * 0.35 + w, edge)) * open;
	// Grote warme vlekken (meters) die langzaam kloppen; daar is de korst dun.
	float heat = vnoise(wpos.xz * 0.045 + vec2(t * 0.01, -t * 0.013));
	heat = smoothstep(0.25, 0.85, heat);
	float pulse = 0.65 + 0.35 * sin(t * 1.1 + heat * 9.0);
	float thin = heat * pulse * smoothstep(0.1, 0.35, edge); // midden van een plaat gloeit door
	float glow = crack * (0.55 + 0.6 * heat) + crack_core * 0.8 + thin * 0.35;
	// Platen een beetje bol: donkerder aan de rand, lichter in het midden.
	float dome = smoothstep(0.0, 0.25, edge);
	ALBEDO = crust_color * (0.6 + 0.6 * dome) * (1.0 - crack);
	ROUGHNESS = mix(0.95, 0.6, crack);
	METALLIC = 0.0;
	SPECULAR = 0.2;
	vec3 e = mix(hot_color, core_color, clamp(crack_core * 0.8 + heat * crack * 0.5, 0.0, 1.0));
	EMISSION = e * (glow * emission_energy + base_glow * (0.6 + heat));
}
