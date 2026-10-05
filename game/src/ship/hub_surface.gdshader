shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Oppervlakken van de hub (De Ekster van binnen). Het machinemateriaal (src/mol/machine.gdshader: verf
// met kale randen en grote vlekken) plus wat een ruimte die al jaren dienst doet nodig heeft (release-
// audit binnen-12; stijlgids: "krassen en vuil langs de randen", nostromo-stijl.md: vuil, roet):
//  - vuil en schoppen onderaan wanden en meubels (een golvende band boven de vloer van die zone);
//  - strepen die van boven naar beneden lopen op wanden, in vlekken;
//  - vlekken en spatjes op vloeren;
//  - roet op plafonds;
//  - stof op bovenvlakken (kasten, toonbanken, leidingen).
// Alles in objectruimte van de hub (= plan − (7, 0, 9), zie tools/blender/interior/layout.py): zo kent de
// shader de vloerniveaus per zone. Geen texturen. Vertexkleur uit tools/blender/interior/build.py
// (bake_edges): R = afgeschuinde rand (kaal metaal), B = willekeur per los onderdeel (tint per plaat).

uniform vec3 albedo : source_color = vec3(0.3);
uniform float metallic = 0.4;
uniform float roughness = 0.6;
uniform float edge_wear = 0.5;      // kale randen (afgeschuinde randen vangen licht en slijten)
uniform bool baked = true;          // het model heeft de vertexkleur van bake_edges (anders: kromming)
uniform vec3 bare_metal : source_color = vec3(0.62, 0.62, 0.6);
uniform float dirt = 0.6;           // hoe vuil dit materiaal wordt (MolVisual.MATS.grime)
uniform vec3 grime_color : source_color = vec3(0.13, 0.11, 0.085); // bruin: lichter dan donkere verf, donkerder dan lichte
uniform vec3 dust_color : source_color = vec3(0.42, 0.39, 0.35);
uniform float variation = 0.14;     // tint per plaat (vertexkleur B) en grote, zachte vlekken
uniform bool hazard = false;        // geel-zwarte strepen
uniform float hazard_scale = 2.2;
uniform bool zones = true;          // false voor losse onderdelen met een eigen oorsprong (luiken, klemmen)
uniform float foot = 1.0;           // band onderaan verticale vlakken
uniform float streaks = 0.8;        // strepen op wanden
uniform float floor_dirt = 0.85;    // vlekken op vloeren
uniform float scratches = 0.5;      // gelopen krassen op vloeren (lichter)
uniform float soot = 0.6;           // roet op plafonds
uniform float dust = 0.5;           // stof op bovenvlakken

varying vec3 opos;
varying vec3 onrm;
varying vec4 vcol;

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

// Vloer van de zone onder een punt (layout.py): laadrek +0,6; brug, gang en werkdek +1,2; de verhoging
// van de terminal +1,8; galerij +1,2; uitkijkput −0,6; hangar en kade 0.
float zone_floor(vec3 p) {
	vec2 q = p.xz + vec2(7.0, 9.0);
	if (q.y >= 41.2) {
		return 0.6;
	}
	if (q.y >= 21.0) {
		return distance(q, vec2(3.3, 23.4)) < 2.05 ? 1.8 : 1.2;
	}
	if (q.x >= 16.0) {
		return 1.2;
	}
	if (q.x >= 12.0 && q.y < 2.5) {
		return -0.6;
	}
	return 0.0;
}

// Hoogte boven de vloer. Onder het niveau van de zone (de voorkant van de brug of de galerij, boven de
// hangar): boven de hangarvloer (of de put).
float height_above_floor(vec3 p) {
	float f = zone_floor(p);
	float h = p.y - f;
	if (h < -0.03) {
		h = p.y - (f <= 0.0 ? -0.6 : 0.0);
	}
	return h;
}

void vertex() {
	opos = VERTEX;
	onrm = NORMAL;
	vcol = baked ? COLOR : vec4(0.0, 0.0, 0.5, 1.0);
}

void fragment() {
	vec3 p = opos;
	vec3 n = normalize(onrm);
	vec3 base = albedo;
	if (hazard) {
		float s = step(0.5, fract((p.x + p.y + p.z) * hazard_scale));
		base = mix(albedo, vec3(0.035), s);
	}
	float large = vnoise(p * 0.55);
	float mid = vnoise(p * 2.3);
	base *= 1.0 + (vcol.b - 0.5) * variation + (large - 0.5) * 0.12 + (mid - 0.5) * 0.05;

	// Randslijtage: de afgeschuinde randen (vertexkleur R) zijn kaal waar de ruis het toelaat; zonder
	// vertexkleur de kromming van gladde normalen (zoals machine.gdshader).
	float chip = smoothstep(0.45, 0.75, vnoise(p * 7.0) * 0.55 + vnoise(p * 19.0) * 0.45);
	float rim = vcol.r;
	if (!baked) {
		float curv = length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-4);
		rim = smoothstep(3.0, 12.0, curv) * (1.0 - smoothstep(70.0, 140.0, curv));
	}
	float edge = rim * mix(0.3, 1.0, chip) * edge_wear;
	vec3 col = mix(base, bare_metal, edge);
	float met = mix(metallic, 0.85, edge);
	float rough = mix(roughness, 0.32, edge);

	float up = n.y;
	float vert = 1.0 - smoothstep(0.35, 0.75, abs(up));
	float flr = smoothstep(0.75, 0.95, up);
	float ceil_k = smoothstep(0.75, 0.95, -up);
	float h = zones ? height_above_floor(p) : 9.0;
	// 1. Onderaan wanden en meubels: vuil en schoppen van robotvoeten, een golvende band.
	float band = 1.0 - smoothstep(0.0, 0.3 + 0.28 * mid, h);
	float g_foot = vert * band * step(-0.03, h) * (0.5 + 0.5 * large) * foot;
	// 2. Strepen op wanden: smal langs de wand, lang in de hoogte, enkel in grote vlekken.
	float g_streak = 0.0;
	if (vert > 0.01) {
		vec3 t = normalize(vec3(-n.z, 0.0, n.x) + vec3(1e-4, 0.0, 0.0));
		float u = dot(p, t);
		float s = vnoise(vec3(u * 9.0, p.y * 0.45, 0.0)) * 0.7 + vnoise(vec3(u * 23.0, p.y * 1.1, 3.0)) * 0.3;
		g_streak = vert * smoothstep(0.55, 0.85, s) * smoothstep(0.4, 0.75, large) * streaks;
	}
	// 3. Vloeren: grote vlekken en kleine spatjes; elders gelopen krassen (lichter, kaal).
	float g_floor = 0.0;
	float scuff = 0.0;
	if (flr > 0.01) {
		float speck = smoothstep(0.78, 0.95, vnoise(p * 11.0));
		g_floor = flr * step(h, 0.08) * (smoothstep(0.35, 0.8, large * 0.6 + mid * 0.4) * 0.8 + speck * 0.5) * floor_dirt;
		float sz = smoothstep(0.72, 0.9, vnoise(vec3(p.x * 34.0, 0.0, p.z * 2.6)));
		float sx = smoothstep(0.72, 0.9, vnoise(vec3(p.x * 2.6, 5.0, p.z * 34.0)));
		scuff = flr * step(h, 0.08) * max(sz, sx) * smoothstep(0.35, 0.65, 1.0 - large) * scratches;
	}
	// 4. Roet op plafonds.
	float g_soot = ceil_k * (0.35 + 0.65 * large) * soot;
	col = mix(col, mix(col, bare_metal, 0.5), scuff * dirt);
	rough = mix(rough, 0.4, scuff * dirt);
	float grime = clamp((g_foot + g_streak * 0.8 + g_floor + g_soot) * dirt, 0.0, 0.9);
	col = mix(col, grime_color, grime * 0.85);
	rough = mix(rough, 0.92, grime * 0.7);
	met = mix(met, met * 0.6, grime);
	// 5. Stof op bovenvlakken boven de vloer.
	float dd = flr * smoothstep(0.15, 0.4, h) * smoothstep(0.3, 0.7, mid) * dust * dirt;
	col = mix(col, dust_color, dd * 0.5);
	rough = mix(rough, 0.95, dd * 0.5);

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
}
