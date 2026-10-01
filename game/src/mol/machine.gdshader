shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Gestileerd machinemateriaal (stijlgids: DRG-trucje). Vertexkleur uit Blender (kit.bake_wear):
//   R = bolle rand  -> verf afgesleten, kaal metaal, lichter
//   G = holte       -> vuil, donkerder
//   B = willekeur per onderdeel -> kleine kleurvariatie
// Vuil en slijtage-vlekken in objectruimte: ze bewegen mee met de machine.

uniform vec3 albedo : source_color = vec3(0.95, 0.72, 0.02);
uniform float metallic = 0.15;
uniform float roughness = 0.5;
uniform float edge_wear = 0.8;      // 0 = geen randslijtage (bv. rubber), 1 = sterk
uniform vec3 bare_metal : source_color = vec3(0.62, 0.62, 0.6);
uniform float grime = 0.6;          // vuil in holtes en onderaan
uniform float low_grime = 1.0;      // tunnelstof onderaan (enkel buiten)
uniform vec3 grime_color : source_color = vec3(0.16, 0.12, 0.09);
uniform float variation = 0.06;
uniform bool hazard = false;        // geel-zwarte strepen
uniform float hazard_scale = 2.2;   // strepen per meter

varying vec3 opos;
varying vec4 wear;

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
	opos = VERTEX;
	wear = COLOR;
}

void fragment() {
	vec3 base = albedo;
	if (hazard) {
		float s = step(0.5, fract((opos.x + opos.y + opos.z) * hazard_scale));
		base = mix(albedo, vec3(0.035), s);
	}
	// Kleine variatie per onderdeel en grote vlekken.
	base *= 1.0 + (wear.b - 0.5) * variation;
	float blotch = vnoise(opos * 1.3) * 0.6 + vnoise(opos * 4.1) * 0.4;
	base *= 0.95 + 0.07 * blotch;

	// Randslijtage: enkel waar de rand bol is én de ruis het toelaat (geen perfecte lijnen).
	float chip = smoothstep(0.55, 0.8, vnoise(opos * 7.0) * 0.55 + vnoise(opos * 19.0) * 0.45);
	float edge = smoothstep(0.45, 0.95, wear.r) * mix(0.35, 1.0, chip) * edge_wear;
	vec3 col = mix(base, bare_metal, edge);
	float met = mix(metallic, 0.85, edge);
	float rough = mix(roughness, 0.32, edge);

	// Vuil in holtes en wat meer onderaan (stof van de tunnel).
	float low = smoothstep(-0.8, -2.8, opos.y);
	float dirt = clamp(smoothstep(0.3, 0.9, wear.g) + low * 0.6 * low_grime * vnoise(opos * 1.7), 0.0, 1.0) * grime;
	col = mix(col, grime_color, dirt * 0.45);
	rough = mix(rough, 0.92, dirt * 0.6);

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
}
