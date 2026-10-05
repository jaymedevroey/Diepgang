shader_type spatial;
// Warmtetrilling onder de stuwraketten van de Mol bij de landing (gevoel-17): een kolom (cilinder)
// rond de vlammen die het beeld erachter laat trillen. Leest het schermbeeld en verschuift het met
// ruis die naar beneden stroomt; zacht aan de randen van de kolom (naar de kijker toe het sterkst) en
// naar onder toe uitdovend. Geen kleur van zichzelf.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 0.018;

varying float along; // 0 = boven (straalpijpen), 1 = onder

float hash(vec2 p) {
	// Dave Hoskins (zonder sin: geen naden).
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// CylinderMesh met hoogte 1, middelpunt in 0.
	along = 0.5 - VERTEX.y;
}

void fragment() {
	float rim = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fade = clamp(1.0 - along, 0.0, 1.0) * smoothstep(0.0, 0.12, along) * smoothstep(0.15, 0.75, rim);
	vec2 q = vec2(UV.x * 18.0, along * 9.0 - TIME * 7.0);
	vec2 off = vec2(noise(q) - 0.5, noise(q + vec2(5.2, 1.3)) - 0.5);
	float k = strength * intensity * fade;
	ALBEDO = textureLod(screen_tex, SCREEN_UV + off * k, 0.0).rgb;
	ALPHA = clamp(fade * intensity * 4.0, 0.0, 1.0);
}
