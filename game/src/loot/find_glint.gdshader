shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, shadows_disabled;

// Glans van een vondst (gevoel-03, binnen-10, binnen-16): een overlay over het hele model.
// - Randlicht (fresnel) in de kleur van de waardeklasse, zodat een vondst loskomt van de klei.
// - Fonkels: kleine puntjes die oplichten en doven; hoe waardevoller, hoe meer.
// - flash: de gloed bij het vrijkomen (boven op de rest).
// Ver weg dooft de rand uit (geen gloeiende vondsten door de hele grot).

uniform vec3 glint_color : source_color = vec3(1.0, 0.85, 0.5);
uniform float rim = 0.3;
uniform float sparkle = 0.0;     // 0 = geen fonkels, 1 = veel
uniform float flash = 0.0;
uniform float fade_near = 10.0;
uniform float fade_far = 22.0;
uniform float seed = 0.0;

varying vec3 opos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(fade_near, fade_far, dist);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// Fonkels: cellen van ±1,7 cm, een klein deel licht kort op, elk op zijn eigen moment.
	vec3 cell = floor(opos * 60.0 + seed);
	float pick = step(1.0 - 0.06 * sparkle, hash(cell));
	float phase = hash(cell + 7.0) * 6.2832;
	float tw = pow(max(0.0, sin(TIME * (2.0 + 3.0 * hash(cell + 3.0)) + phase)), 24.0);
	vec3 c = glint_color * (fres * rim * near + pick * tw * 1.6 * sparkle * near) + glint_color * flash * (0.12 + fres * 0.9);
	ALBEDO = c;
}
