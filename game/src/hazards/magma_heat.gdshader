shader_type canvas_item;

// Hitte van het magma op het scherm (Magma.gd, release-audit binnen-06, gevoel-12 en golf 3 binnen2-05):
// - shimmer: de lucht boven lava trilt (het beeld golft, het meest onderaan);
// - danger: in de hittezone (heat_m) een rode, kloppende rand;
// - melt: smelten. Geen egale beige waas meer: de lava komt van onderen het beeld in (een kloppende
//   oranjerode vulling met donkere slakslierten en opstijgende vonken), het beeld (en het gereedschap)
//   gloeit en vervormt, dan zwart; daarna (na de vervanger) weer open;
// - under: de camera zit onder het oppervlak van het magma: het hele beeld is lava.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float shimmer = 0.0;
uniform float danger = 0.0;
uniform float melt = 0.0; // 0..1
uniform float black = 0.0; // 0..1 zwart
uniform float under = 0.0; // 0..1 onder het oppervlak

// Hash zonder sin (Dave Hoskins), zoals magma.gdshader: sin() van grote getallen is op de GPU
// onnauwkeurig, en dat gaf rechthoekige blokken in de lava.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

// Lava in schermruimte: trage, opstijgende stroming met donkere slak en felle kernen.
vec3 lava(vec2 uv, float t) {
	vec2 p = uv * vec2(3.2, 2.2);
	vec2 w = vec2(vnoise(p * 1.3 + vec2(0.0, t * 0.35)), vnoise(p * 1.3 + vec2(5.2, t * 0.3))) - 0.5;
	p += w * 1.4;
	float n = vnoise(p + vec2(0.0, t * 0.5)) * 0.6 + vnoise(p * 2.7 + vec2(t * 0.2, t * 0.9)) * 0.4;
	float slag = smoothstep(0.55, 0.75, vnoise(p * 1.7 + vec2(3.0, t * 0.6)));
	float pulse = 0.85 + 0.15 * sin(t * 3.0 + n * 6.0);
	vec3 deep = vec3(0.45, 0.05, 0.01);
	vec3 hot = vec3(1.0, 0.36, 0.05);
	vec3 core = vec3(1.0, 0.82, 0.4);
	vec3 col = mix(deep, hot, smoothstep(0.3, 0.7, n));
	col = mix(col, core, smoothstep(0.72, 0.9, n) * pulse);
	col = mix(col, vec3(0.06, 0.015, 0.01), slag * 0.85); // donkere slierten
	// Vonken die opstijgen: kleine felle puntjes in een rooster dat omhoog schuift.
	vec2 sp = vec2(uv.x * 40.0, uv.y * 24.0 + t * 6.0);
	vec2 sc = floor(sp);
	float sh = hash(sc);
	float spark = step(0.965, sh) * (1.0 - smoothstep(0.05, 0.2, length(fract(sp) - vec2(0.5, 0.5 + 0.3 * sin(sh * 40.0)))));
	col += vec3(1.0, 0.75, 0.35) * spark * 1.5;
	return col * pulse;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	// Golvende lucht: twee lagen ruis die omhoog drijven, sterker onderaan het beeld (en heel sterk bij
	// het smelten: het gereedschap vervormt mee).
	float k = shimmer * (0.35 + 0.65 * uv.y) + danger * 0.6 + melt * 2.2 + under * 1.5;
	vec2 off = vec2(vnoise(uv * vec2(9.0, 5.0) + vec2(0.0, t * 1.7)) - 0.5, vnoise(uv * vec2(7.0, 4.0) + vec2(3.1, t * 1.3)) - 0.5);
	vec3 col = textureLod(screen_tex, uv + off * 0.012 * k, 0.0).rgb;
	// Rode rand in de hittezone (klopt).
	vec2 c = uv - 0.5;
	float vig = smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.25)));
	float beat = 0.75 + 0.25 * sin(t * 7.0);
	col = mix(col, vec3(1.0, 0.18, 0.04), vig * danger * 0.65 * beat);
	// Smelten: het beeld gloeit (alles wordt heet oranje), en de lava stijgt van onderen in het beeld.
	vec3 lv = lava(uv, t);
	float glow_k = smoothstep(0.0, 0.5, melt);
	col = mix(col, col * vec3(1.6, 0.75, 0.35) + vec3(0.25, 0.05, 0.0), glow_k * 0.7);
	float edge = 1.0 - melt * 1.25 + 0.08 * sin(uv.x * 18.0 + t * 4.0) + 0.06 * vnoise(vec2(uv.x * 9.0, t * 2.0));
	float fill = smoothstep(edge - 0.06, edge + 0.02, uv.y) * step(0.001, melt);
	fill = max(fill, under);
	col = mix(col, lv, fill * 0.94);
	// De rand van de lava: een felle lijn waar ze het beeld in kruipt.
	col += vec3(1.0, 0.6, 0.2) * (1.0 - smoothstep(0.0, 0.03, abs(uv.y - edge))) * step(0.001, melt) * (1.0 - under);
	col = mix(col, vec3(0.0), black);
	COLOR = vec4(col, 1.0);
}
