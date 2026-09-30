shader_type spatial;
render_mode diffuse_burley;

// Korst rond een vondst (GDD §3): bleek, gespikkeld "matrixgesteente", duidelijk anders dan
// de laag eromheen, zodat je hem herkent zodra hij bloot ligt. Barsten groeien met `damage`.

uniform vec3 base_color : source_color = vec3(0.68, 0.6, 0.47);
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float glint = 0.0; // kort oplichten bij een raak

varying vec3 lpos;

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
	lpos = VERTEX;
	// Knobbelig in plaats van een perfecte ellipsoïde.
	float n = vnoise(VERTEX * 7.0 + seed) * 0.7 + vnoise(VERTEX * 15.0 + seed) * 0.3;
	VERTEX += NORMAL * (n - 0.5) * 0.07;
}

void fragment() {
	vec3 p = lpos + seed;
	float n = vnoise(p * 9.0);
	float fine = vnoise(p * 32.0);
	vec3 col = base_color * (0.82 + 0.3 * n) * (0.9 + 0.15 * fine);
	col *= mix(1.0, 0.45, smoothstep(0.78, 0.82, fine)); // donkere spikkels
	// Barsten: smalle lijnen langs de "0,5-contour" van ruis, breder naarmate de schade groeit.
	float c1 = abs(vnoise(p * 6.0 + 13.0) - 0.5);
	float c2 = abs(vnoise(p * 11.0 + 41.0) - 0.5);
	float width = 0.012 + 0.05 * damage;
	float crack = (1.0 - smoothstep(0.0, width, c1)) + (1.0 - smoothstep(0.0, width * 0.8, c2)) * step(0.45, damage);
	crack *= step(0.01, damage);
	col = mix(col, vec3(0.04, 0.035, 0.03), clamp(crack, 0.0, 1.0) * 0.9);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = base_color * glint * 0.6;
}
