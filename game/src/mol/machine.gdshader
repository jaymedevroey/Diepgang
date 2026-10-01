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
uniform float detail_scale = 1.0;   // >1 voor kleine voorwerpen (gereedschap): fijnere vlekken en strepen
// Gereedschap in beeld (first person): eigen gezichtsveld en niet door muren steken (zoals
// fov_override en z_clip_scale van StandardMaterial3D).
uniform bool viewmodel = false;
uniform float viewmodel_fov = 68.0;
uniform float viewmodel_zclip = 0.3;

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
	opos = VERTEX * detail_scale;
	wear = COLOR;
	if (viewmodel) {
		float f = 1.0 / tan(radians(viewmodel_fov) * 0.5);
		float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
		mat4 proj = PROJECTION_MATRIX;
		proj[1][1] = f * sign(PROJECTION_MATRIX[1][1]);
		proj[0][0] = f / aspect * sign(PROJECTION_MATRIX[0][0]);
		POSITION = proj * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
		POSITION.z = mix(POSITION.w, POSITION.z, viewmodel_zclip);
	} else {
		// Wie POSITION ergens schrijft, moet het overal doen: Godot gebruikt het dan altijd.
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
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
	// Kromming per pixel (hoe snel de normaal draait per meter): vlak = 0, afgeronde rand = hoog.
	// De vertexkleur alleen volstaat niet: op een vlak met enkel hoekpunten loopt die over het
	// hele vlak door, en dan krijgen dunne platen overal schilfers.
	float curv = length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-4);
	// Zeer grote waarden komen van harde (gesplitste) randen: een sprong in de normaal binnen één
	// pixel. Die negeren, anders zinderen dunne lijntjes bij elke beweging.
	float rim = smoothstep(3.0, 12.0, curv) * (1.0 - smoothstep(70.0, 140.0, curv)) * smoothstep(0.35, 0.8, wear.r);
	float edge = rim * mix(0.45, 1.0, chip) * edge_wear;
	vec3 col = mix(base, bare_metal, edge);
	float met = mix(metallic, 0.85, edge);
	float rough = mix(roughness, 0.32, edge);

	// Vuil in holtes en wat meer onderaan (stof van de tunnel).
	float low = smoothstep(-0.8, -2.8, opos.y / detail_scale);
	// Stof onderaan: zacht en grootschalig (een waas, geen vlekken).
	float dust = low * low_grime * (0.25 + 0.2 * smoothstep(0.2, 0.8, vnoise(opos * 0.8)));
	float dirt = clamp(smoothstep(0.3, 0.9, wear.g) + dust, 0.0, 1.0) * grime;
	col = mix(col, grime_color, dirt * 0.45);
	rough = mix(rough, 0.92, dirt * 0.6);

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
}
