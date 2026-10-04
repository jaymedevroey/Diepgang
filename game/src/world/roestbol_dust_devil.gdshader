shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Stofduivel van Roestbol (roestbol_dust_devil.gd): een getwiste kolom van stof. Transparant en
// onbelicht (geen schaduw, geen licht nodig); de zonkant iets lichter. Ruis die in een spiraal
// omhoog scrolt, dun aan de randen van de buis (je kijkt door minder stof), zacht onderaan en
// uitwaaierend bovenaan. Alles in objectruimte (kleine getallen: geen naden).

uniform vec3 dust_light : source_color = vec3(0.92, 0.74, 0.58);
uniform vec3 dust_shade : source_color = vec3(0.6, 0.42, 0.34);
uniform float height = 100.0;
uniform float opacity = 0.62;
uniform float spin = 2.4; // hoe snel de spiraal draait
uniform float sway = 0.07; // hoeveel de kolom slingert (deel van de hoogte)
uniform float seed = 0.0;
uniform vec3 sun_dir = vec3(0.0, 0.4, 0.9); // naar de zon (wereld)

varying vec3 opos;
varying vec3 wnrm;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// Waardruis met een periode langs x (rond de kolom: geen naad waar de hoek omslaat).
float vnoise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	float a = hash(vec2(x0, i.y));
	float b = hash(vec2(x1, i.y));
	float c = hash(vec2(x0, i.y + 1.0));
	float d = hash(vec2(x1, i.y + 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	opos = VERTEX;
	float h = clamp(VERTEX.y / height, 0.0, 1.0);
	// De kolom slingert als een slang, bovenaan het meest.
	vec2 s = vec2(sin(TIME * 0.45 + h * 3.1 + seed), cos(TIME * 0.33 + h * 2.3 + seed * 1.7));
	VERTEX.xz += s * h * h * height * sway;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = clamp(opos.y / height, 0.0, 1.0);
	float ang = atan(opos.z, opos.x) / 6.2831853 + 0.5;
	// Spiraal: de hoek schuift op met de hoogte en de tijd.
	vec2 q = vec2(ang * 8.0 + h * 5.0 - TIME * spin * 0.5, h * 7.0 - TIME * 0.5 + seed);
	float n = vnoise(q, 8.0) * 0.62 + vnoise(q * vec2(2.0, 2.3) + vec2(0.0, 5.3), 16.0) * 0.38;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float a = opacity;
	a *= smoothstep(0.0, 0.06, h) * (1.0 - smoothstep(0.5, 1.0, h));
	a *= mix(0.3, 1.0, facing);
	a *= smoothstep(0.22, 0.7, n) * 0.85 + 0.15 * (1.0 - h);
	float lit = 0.55 + 0.45 * max(dot(wnrm, normalize(sun_dir)), 0.0);
	ALBEDO = mix(dust_shade, dust_light, clamp(lit * (0.75 + 0.35 * n), 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 1.0);
}
