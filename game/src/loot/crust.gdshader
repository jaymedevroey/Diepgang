shader_type spatial;
render_mode diffuse_burley;

// Korst rond een vondst (GDD §3, binnen-04): een gebroken rotsknol met facetten (vlakke normalen),
// in de kleur van de laag, met een hint van wat erin zit: plekken in de kleur van de familie
// (ivoor, goud, paars kristal), die met de schade meer bloot komen; metaal en kristal glanzen.
// Barsten groeien met `damage`.

uniform vec3 base_color : source_color = vec3(0.68, 0.6, 0.47);
uniform vec3 hint_color : source_color = vec3(0.93, 0.88, 0.74);
uniform float hint_glint = 0.0; // 0 = dof (bot), 1 = glanst (goud, kristal)
uniform float speckle = 0.4;     // donkere spikkels (graniet: veel)
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
	// Een knol, geen ei: grove bulten en een paar afgebroken vlakken.
	vec3 s = VERTEX + seed;
	float n = vnoise(s * 2.3) * 0.55 + vnoise(s * 5.0) * 0.3 + vnoise(s * 11.0) * 0.15;
	float cut = smoothstep(0.62, 0.7, vnoise(s * 1.7 + 7.0)) * 0.12; // vlakke breuk
	VERTEX += NORMAL * ((n - 0.5) * 0.28 - cut);
}

void fragment() {
	// Vlakke normalen per driehoek: facetten zoals het puin.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	vec3 p = lpos + seed;
	float n = vnoise(p * 9.0);
	float fine = vnoise(p * 32.0);
	vec3 col = base_color * (0.8 + 0.32 * n) * (0.9 + 0.15 * fine);
	col *= mix(1.0, 0.45, smoothstep(0.8 - 0.06 * speckle, 0.84 - 0.06 * speckle, fine)); // donkere spikkels
	// Hint: vlekken in de kleur van wat erin zit, groter naarmate de korst afbrokkelt.
	float h = vnoise(p * 4.5 + 31.0) * 0.7 + vnoise(p * 13.0 + 5.0) * 0.3;
	float hint = smoothstep(0.73 - 0.24 * damage, 0.77 - 0.24 * damage, h);
	col = mix(col, hint_color, hint * 0.92);
	// Glans van metaal en kristal: fonkelende puntjes in de hintvlekken.
	float sparkle = step(0.93, hash(floor(p * 60.0))) * hint * hint_glint;
	sparkle *= 0.5 + 0.5 * sin(TIME * 5.0 + hash(floor(p * 60.0) + 3.0) * 6.28);
	// Barsten: smalle lijnen langs de "0,5-contour" van ruis, breder naarmate de schade groeit.
	float c1 = abs(vnoise(p * 6.0 + 13.0) - 0.5);
	float c2 = abs(vnoise(p * 11.0 + 41.0) - 0.5);
	float width = 0.012 + 0.05 * damage;
	float crack = (1.0 - smoothstep(0.0, width, c1)) + (1.0 - smoothstep(0.0, width * 0.8, c2)) * step(0.45, damage);
	crack *= step(0.01, damage);
	col = mix(col, vec3(0.04, 0.035, 0.03), clamp(crack, 0.0, 1.0) * 0.9);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.35, hint * hint_glint);
	METALLIC = hint * hint_glint * 0.6;
	EMISSION = base_color * glint * 0.6 + hint_color * sparkle * 2.5;
}
