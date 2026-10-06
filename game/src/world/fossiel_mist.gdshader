shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Warme lage mist in de geulen van Fossielwereld (docs/research/planeten.md §4.2, §5 "Sfeer"):
// één transparant vlak dat de bodem van de geulen volgt (LandformFossiel bouwt het, een paar meter
// boven de geulbodem). Hoe dik de mist is, volgt uit de diepte: de afstand die de kijkstraal onder
// het vlak aflegt tot hij het terrein raakt. Zo vult de mist de geulen en steken de ruggen erdoor,
// van boven en van opzij, zonder volumetrische mist. Zacht: de dikte loopt over meters in (geen harde
// lijn waar het vlak een helling raakt), de rand van het mistgebied dooft uit (hoekpuntkleur), en de
// gewone mist doet er niet aan mee (die maakte het warme stof grijs in de teal lucht).

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec3 mist_color : source_color = vec3(0.914, 0.706, 0.561); // #E9B48F
uniform vec3 mist_light : source_color = vec3(0.98, 0.86, 0.74);
uniform float density = 0.07; // per meter kijkstraal
uniform float max_alpha = 0.45;
uniform float soft_m = 7.0; // zoveel meter dikte voor de mist volop telt
uniform float near_fade_m = 25.0; // dichtbij de camera weg (geen muur voor de lens)
uniform float far_fade_m = 1400.0; // verder neemt de gewone mist het over
uniform float drift = 0.6; // m/s

varying vec3 wp;
varying float edge_a;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge_a = COLOR.a;
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float scene_d = length(view.xyz);
	float frag_d = length(VERTEX);
	float thick = max(scene_d - frag_d, 0.0);
	// Slierten: twee lagen ruis die langzaam met de wind meedrijven (wereldruimte, kleine getallen).
	vec2 q = mod(wp.xz, 4096.0);
	float t = TIME * drift;
	float n = vnoise(q * 0.018 + vec2(t * 0.011, t * 0.004)) * 0.65 + vnoise(q * 0.061 - vec2(t * 0.02, -t * 0.013)) * 0.35;
	// Van boven (de drop) dunner: daar zie je de geulen door de mist heen; van opzij dik.
	vec3 vdir = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	// Golf 3 (buiten-14): de dropcamera kijkt 17-30° omlaag; daar al dun, zodat de geulen er niet als
	// blokken in staan.
	float dens = density * mix(0.35, 1.35, n) * mix(1.0, 0.12, smoothstep(0.12, 0.55, abs(vdir.y)));
	// Zachte bovenrand: hoe dichter bij de rand van het vlak (dun), hoe minder; en nooit een vlakke
	// plaat (de slierten breken de rand).
	float a = (1.0 - exp(-thick * dens)) * smoothstep(0.0, soft_m * (0.7 + 0.8 * n), thick);
	a *= smoothstep(near_fade_m, near_fade_m * 2.5, frag_d) * (1.0 - smoothstep(far_fade_m * 0.6, far_fade_m, frag_d));
	a *= smoothstep(0.0, 0.9, edge_a) * mix(0.55, 1.0, n); // rand van het mistgebied, en slierten
	ALBEDO = mix(mist_color, mist_light, smoothstep(0.55, 0.85, n) * 0.5);
	ALPHA = clamp(a, 0.0, max_alpha);
}
