shader_type sky;

// Nachtlucht boven de put (enkel in het hoofdmenu): warme horizon van de werflampen,
// diep blauwzwart boven, en een paar sterren die zacht twinkelen.

uniform vec3 horizon : source_color = vec3(0.10, 0.065, 0.045);
uniform vec3 zenith : source_color = vec3(0.012, 0.016, 0.03);
uniform float star_density = 0.0016;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float up = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon, zenith, pow(up, 0.45));
	// Sterren: op een raster in de kijkrichting, enkel boven de horizon.
	vec3 cell = floor(EYEDIR * 320.0);
	float h = hash(cell);
	if (h < star_density && EYEDIR.y > 0.08) {
		float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 900.0) + h * 6283.0);
		col += vec3(0.85, 0.9, 1.0) * tw * smoothstep(0.08, 0.35, EYEDIR.y) * 1.4;
	}
	COLOR = col;
}
