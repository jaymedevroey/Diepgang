shader_type canvas_item;

// Hitte van het magma op het scherm (Magma.gd, release-audit binnen-06 en gevoel-12):
// - shimmer: de lucht boven lava trilt (het beeld golft, het meest onderaan);
// - danger: in de hittezone (heat_m) een rode, kloppende rand;
// - melt: smelten, eerst wit-oranje, dan zwart; daarna (na de vervanger) weer open.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float shimmer = 0.0;
uniform float danger = 0.0;
uniform float melt = 0.0; // 0..1 wit-oranje
uniform float black = 0.0; // 0..1 zwart

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	// Golvende lucht: twee lagen ruis die omhoog drijven, sterker onderaan het beeld.
	float k = shimmer * (0.35 + 0.65 * uv.y) + danger * 0.6 + melt;
	vec2 off = vec2(vnoise(uv * vec2(9.0, 5.0) + vec2(0.0, t * 1.7)) - 0.5, vnoise(uv * vec2(7.0, 4.0) + vec2(3.1, t * 1.3)) - 0.5);
	vec3 col = textureLod(screen_tex, uv + off * 0.012 * k, 0.0).rgb;
	// Rode rand in de hittezone (klopt), en wit-oranje als je smelt.
	vec2 c = uv - 0.5;
	float vig = smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.25)));
	float beat = 0.75 + 0.25 * sin(t * 7.0);
	col = mix(col, vec3(1.0, 0.18, 0.04), vig * danger * 0.65 * beat);
	col = mix(col, vec3(1.0, 0.72, 0.42), melt * (0.4 + 0.6 * vig) * 0.95);
	col = mix(col, vec3(0.0), black);
	COLOR = vec4(col, 1.0);
}
