shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Lagen per hoogte in wereldruimte. Grenzen en golving moeten overeenkomen met strata.gd.
// Elke laag heeft een eigen kleur én patroon (leesbaar voor kleurenblinden, GDD §4).

uniform float seed_f = 1.0;
uniform float top_kristal = 35.0;
uniform float top_graniet = 80.0;
uniform float top_zandsteen = 125.0;

uniform vec3 col_klei : source_color = vec3(0.45, 0.30, 0.21);
uniform vec3 col_zandsteen : source_color = vec3(0.72, 0.56, 0.34);
uniform vec3 col_graniet : source_color = vec3(0.42, 0.42, 0.45);
uniform vec3 col_kristal : source_color = vec3(0.12, 0.13, 0.20);
uniform vec3 col_ader : source_color = vec3(0.30, 0.95, 1.00);
uniform float ader_energy = 1.6;

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
	float offset = 1.5 * sin(wpos.x * 0.13 + seed_f * 0.7) + 1.2 * sin(wpos.z * 0.09 + seed_f * 1.3);
	float y = wpos.y + offset;
	float n = vnoise(wpos * 1.7);
	float fine = vnoise(wpos * 7.0);
	vec3 base;
	float rough = 0.92;
	vec3 emit = vec3(0.0);

	if (y < top_kristal) {
		// Donker met lichtgevende cyaan aders.
		base = col_kristal * (0.8 + 0.4 * n);
		float v = vnoise(wpos * 0.9);
		float ader = smoothstep(0.46, 0.5, v) - smoothstep(0.5, 0.54, v);
		emit = col_ader * ader * ader_energy;
		base = mix(base, col_ader * 0.4, ader);
		rough = 0.45;
	} else if (y < top_graniet) {
		// Grijs met grove donkere spikkels.
		base = col_graniet * (0.85 + 0.3 * n);
		base *= mix(1.0, 0.3, smoothstep(0.72, 0.8, fine));
		base *= mix(1.0, 1.35, smoothstep(0.85, 0.9, vnoise(wpos * 3.1)));
		rough = 0.8;
	} else if (y < top_zandsteen) {
		// Horizontale banden.
		float band = 0.5 + 0.5 * sin(y * 5.0 + n * 2.5);
		base = col_zandsteen * (0.72 + 0.35 * band) * (0.92 + 0.12 * fine);
	} else {
		// Egale klei met fijne korrel.
		base = col_klei * (0.85 + 0.2 * n) * (0.9 + 0.15 * fine);
		rough = 0.97;
	}

	ALBEDO = base;
	ROUGHNESS = rough;
	EMISSION = emit;
}
