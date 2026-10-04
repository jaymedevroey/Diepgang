shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Versteend bot (Fossielwereld, docs/research/planeten.md §4.2): donker, met een warme glans op
// sommige vlakken, en kalkstof bovenop en onderaan, waar het bot uit het sediment komt.
// Vertexkleur (fossiel_bones.gd): r = glans per vlak, a = stof van de grond.

uniform vec3 bone_dark : source_color = vec3(0.227, 0.165, 0.180); // #3A2A2E
uniform vec3 bone_gloss : source_color = vec3(0.420, 0.290, 0.227); // #6B4A3A
uniform vec3 dust : source_color = vec3(0.788, 0.706, 0.549); // #C9B48C (kalkstof)
uniform float top_dust = 0.22;
uniform float ground_dust = 0.45;

varying vec3 wn;
varying vec3 wp;

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
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wn = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = COLOR.r;
	vec3 col = mix(bone_dark, bone_gloss, smoothstep(0.25, 0.9, g));
	// Mineraaladers: lichte en donkere vlekken (van dichtbij), van ver gemiddeld.
	float dist = length(VERTEX);
	float k = 1.0 - smoothstep(60.0, 160.0, dist);
	col *= mix(1.0, 0.85 + 0.3 * vnoise(wp * 0.7), k);
	float up = normalize(wn).y;
	float d = smoothstep(0.55, 0.95, up) * top_dust * (0.6 + 0.4 * vnoise(wp * 0.4));
	d = max(d, COLOR.a * ground_dust * (0.7 + 0.3 * vnoise(wp * 1.3)));
	col = mix(col, dust, clamp(d, 0.0, 0.85));
	ALBEDO = col;
	ROUGHNESS = mix(0.42, 0.95, clamp(d * 1.4 + (1.0 - g) * 0.25, 0.0, 1.0));
	SPECULAR = 0.55;
}
