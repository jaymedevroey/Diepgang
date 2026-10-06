shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;

// Roest en stof over een oude Mol in een grot (CaveSetPieces, golf 3): een laag over de machine-
// materialen (material_overlay), in wereldruimte (de Mol staat stil). Roestvlekken met strepen die
// naar beneden lopen, en onderaan een korst van het stof van de laag. Zo leest hij als "jaren hier".

uniform vec3 rust_dark : source_color = vec3(0.26, 0.12, 0.06);
uniform vec3 rust_light : source_color = vec3(0.55, 0.28, 0.1);
uniform vec3 dust : source_color = vec3(0.45, 0.33, 0.24);
uniform float floor_y = 0.0;   // wereld-y van de vloer: daar is het stof het dikst
uniform float amount = 0.85;

varying vec3 wpos;

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
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Roest: grote vlekken, en strepen die van de vlekken naar beneden lopen (uitgerekt in y).
	float big = vnoise(wpos * 0.9) * 0.6 + vnoise(wpos * 2.7 + vec3(3.0)) * 0.4;
	float streak = vnoise(vec3(wpos.x * 6.0, wpos.y * 0.6, wpos.z * 6.0) + vec3(7.0));
	float r = smoothstep(0.5, 0.68, big) + smoothstep(0.62, 0.8, streak) * smoothstep(0.35, 0.55, big) * 0.7;
	r = clamp(r, 0.0, 1.0);
	vec3 col = mix(rust_dark, rust_light, vnoise(wpos * 5.0));
	// Stof onderaan (tot ±2 m boven de vloer) en op wat naar boven kijkt.
	float low = 1.0 - smoothstep(0.0, 2.2, wpos.y - floor_y);
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = smoothstep(0.6, 0.95, n.y) * smoothstep(0.4, 0.6, vnoise(wpos * 1.6 + vec3(11.0)));
	float d = clamp(low * (0.6 + 0.4 * vnoise(wpos * 3.0)) + top * 0.7, 0.0, 1.0);
	col = mix(col, dust, d);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	ALPHA = clamp(max(r, d) * amount, 0.0, 1.0);
}
