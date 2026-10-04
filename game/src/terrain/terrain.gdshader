shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Gestileerde rots (docs/stijlgids.md, docs/research/rots-en-licht.md).
// Alles in wereldruimte en procedureel: geen UV's nodig op het voxelterrein, geen naden.
//   1. Facetten: 3D-voronoi; elke cel kantelt de normaal een beetje, zodat de wand uit
//      afgebrokkelde vlakken bestaat (het DRG-trucje). Aan de randen van een cel vloeit de
//      kanteling weg (afgeschuinde rand), met een donker barstje en een lichter randje.
//   2. Kleur: grote vlekken, een tint per facet, en een eigen patroon per laag:
//      klei kiezels en droge barstjes · zandsteen banden en platen · graniet spikkels ·
//      kristal donker met spaarzame lichtgevende aders en glinsters.
//   3. Stof op vloeren, donkerder onder overhangen, een naad op de laaggrens.
// Fijne details vervagen met de afstand (geen flikkeren). Laaggrenzen = strata.gd.
// Wat verder ligt dan de fijne details (facetten 90 m, kiezels en barstjes 12-34 m), rekent de
// shader niet meer uit: van hoog in de lucht is bijna al het terrein ver weg. Verder dan 150 m
// komen er grote vlekken bij (geologie op landschapsschaal), en ruis die kleiner is dan een pixel
// vervaagt naar zijn gemiddelde (anders zindert het verre landschap).

uniform float seed_f = 1.0;
// Verre landschap (PlanetSurface): altijd klei (het buigt met de planeet weg, dus zijn hoogte zegt
// niets over de laag), nooit weggesneden.
uniform bool far_terrain = false;
// Landingsplek (PlanetSurface): xy = midden (wereld x/z), z = straal van de aangestampte kern,
// w = waar ze overgaat in het gewone terrein (m). 0 = geen.
uniform vec4 landing_pad = vec4(0.0);
// Lagen in een wand van het verre landschap (Landform: COLOR.a = hoeveel), sRGB: licht, midden, donker.
uniform vec3 strata_light = vec3(0.878, 0.706, 0.549);
uniform vec3 strata_mid = vec3(0.722, 0.416, 0.267);
uniform vec3 strata_dark = vec3(0.478, 0.227, 0.165);
uniform float top_kristal = 35.0;
uniform float top_graniet = 80.0;
uniform float top_zandsteen = 125.0;
uniform float vein_energy = 2.4;
uniform float facet_strength = 1.0;
// Erts vlak achter de wand (OreField): xyz = cluster (wereld), w = soort. Kleuren lineair.
uniform vec4 ore_points[16];
uniform int ore_count = 0;
uniform vec4 ore_colors[4];
// Grof raster van het speelgebied (PlanetSurface): dichter dan dit bij de camera is het echte
// voxelterrein geladen, dus daar niet tekenen (anders sluit het gaten en tunnels af). 0 = uit.
uniform float near_cutoff = 0.0;
// Onstabiele zones (Unrest): xyz = midden, w = straal. Waar de wand in een zone ligt: een net van
// donkere barsten en fijn stof (en Unrest laat er stof uit het plafond sijpelen).
uniform vec4 hazard_zones[16];
uniform int hazard_count = 0;
// Magma (Magma.gd): hoogte van het oppervlak, en tot hoe hoog de rots erboven opwarmt.
global uniform float magma_height;
global uniform float magma_heat_m;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 vtint; // verre landschap: tint van de landvorm (rgb maal de rotskleur, a = lagen)

// Palet in sRGB (stijlgids), per laag: 0 kristal, 1 graniet, 2 zandsteen, 3 klei.
const vec3 PAL_BASE[4] = vec3[](vec3(0.137, 0.157, 0.220), vec3(0.373, 0.392, 0.420), vec3(0.690, 0.541, 0.333), vec3(0.431, 0.290, 0.208));
const vec3 PAL_LIGHT[4] = vec3[](vec3(0.227, 0.259, 0.376), vec3(0.604, 0.620, 0.639), vec3(0.820, 0.678, 0.447), vec3(0.604, 0.420, 0.298));
const vec3 PAL_DARK[4] = vec3[](vec3(0.071, 0.078, 0.114), vec3(0.165, 0.176, 0.200), vec3(0.478, 0.357, 0.204), vec3(0.243, 0.165, 0.122));
const vec3 PINK = vec3(0.659, 0.514, 0.471);
const vec3 CYAN = vec3(0.310, 0.890, 0.941);
// Facetgrootte (m), kanteling, ruwheid per laag.
const float FACET_SIZE[4] = float[](1.25, 1.45, 1.1, 0.85);
const float FACET_TILT[4] = float[](0.85, 0.8, 0.6, 0.48);
const float CRACKS[4] = float[](0.0, 0.22, 0.0, 0.8); // hoeveel barstjes (klei: droge modder op vloeren, graniet: breuken)
// Low-poly-facetten: fijnheid van het richtingenrooster (hoger = meer, kleinere vlakken) en sterkte.
const float QUANT[4] = float[](2.6, 2.2, 2.3, 2.0);
const float QUANT_AMT[4] = float[](0.95, 0.95, 0.85, 0.8);
const float ROUGH[4] = float[](0.36, 0.8, 0.9, 0.96);

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash1(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash1(i), hash1(i + vec3(1, 0, 0)), f.x),
			mix(hash1(i + vec3(0, 1, 0)), hash1(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash1(i + vec3(0, 0, 1)), hash1(i + vec3(1, 0, 1)), f.x),
			mix(hash1(i + vec3(0, 1, 1)), hash1(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Voronoi: x = afstand tot de dichtste celkern, y = afstand tot de grens met de tweede cel
// (exact: afstand tot het middelloodvlak); cell = roosterpunt van de dichtste cel.
vec2 voronoi(vec3 p, out vec3 cell) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec3 r1 = vec3(0.0);
	vec3 r2 = vec3(1.0);
	cell = i;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + 0.1 + hash33(i + g) * 0.8 - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					r2 = r1;
					f1 = d;
					r1 = r;
					cell = i + g;
				} else if (d < f2) {
					f2 = d;
					r2 = r;
				}
			}
		}
	}
	return vec2(sqrt(f1), (f2 - f1) / (2.0 * max(length(r2 - r1), 1e-3)));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vtint = COLOR;
}

void fragment() {
	float dist = distance(wpos, CAMERA_POSITION_WORLD);
	if (near_cutoff > 0.0 && dist < near_cutoff) {
		discard;
	}
	// De seed klein houden: een opdracht heeft een seed van honderdduizenden, en als verschuiving in
	// de ruiscoördinaten blijft daar in 32 bit niets van over. Alle ruis viel dan samen tot een
	// regelmatig raster (donkere lijnen om de 0,85 m op de landingsplek).
	float seed_s = mod(seed_f, 61.0);
	vec3 wn = normalize(wnrm);
	float offset = 1.5 * sin(wpos.x * 0.13 + seed_f * 0.7) + 1.2 * sin(wpos.z * 0.09 + seed_f * 1.3);
	float y = wpos.y + offset;
	int layer = y < top_kristal ? 0 : (y < top_graniet ? 1 : (y < top_zandsteen ? 2 : 3));
	if (far_terrain) {
		layer = 3;
	}
	float near = 1.0 - smoothstep(12.0, 34.0, dist); // fijne details enkel van dichtbij
	// Hoe groot een pixel hier is (m; gemiddelde van beide assen, zodat scherend kijken over de grond
	// de facetten niet wegneemt). Wat kleiner is dan een paar pixels, vervaagt naar zijn gemiddelde:
	// anders kruipt van hoog in de lucht een fijn dambord over het terrein (ruisroosters, de afgeronde
	// normalen per voxeldriehoek van 0,5 m, en de kromming per 2×2 pixels).
	vec3 dpx = dFdx(wpos);
	vec3 dpy = dFdy(wpos);
	float px = sqrt(length(dpx) * length(dpy));
	float wave_k = (1.0 - smoothstep(300.0, 900.0, dist)) * (1.0 - smoothstep(0.25, 0.7, px)); // golving, 2 m
	float fine_k = (1.0 - smoothstep(250.0, 700.0, dist)) * (1.0 - smoothstep(1.2, 3.5, px)); // vlekken, 9 m
	float dust_k = fine_k * (1.0 - smoothstep(0.15, 0.45, px)); // stof, 1,25 m
	float aa = smoothstep(0.1, 0.35, px); // facetten en kromming: 0 = scherp, 1 = uitgemiddeld

	vec3 base = lin(PAL_BASE[layer]);
	vec3 light = lin(PAL_LIGHT[layer]);
	vec3 dark = lin(PAL_DARK[layer]);

	// Grote golving in de wand (één ruisgradiënt): breekt de gladheid van de voxels.
	if (wave_k > 0.0) {
		float e = 0.12;
		vec3 mp = wpos * 0.5;
		float m0 = vnoise(mp);
		vec3 mg = vec3(vnoise(mp + vec3(e, 0, 0)) - m0, vnoise(mp + vec3(0, e, 0)) - m0, vnoise(mp + vec3(0, 0, e)) - m0) / e;
		wn = normalize(wn - (mg - dot(mg, wn) * wn) * 0.28 * wave_k);
	}

	// 1. Facetten. Zandsteen in platte platen, graniet in blokken. De voronoi is het duurste deel van
	// de shader en verder dan 34 m enkel nog een tint per cel (±4%): die vervaagt tot 90 m, verder
	// wordt hij niet meer uitgerekend.
	vec3 aniso = layer == 2 ? vec3(1.0, 2.6, 1.0) : (layer == 1 ? vec3(0.95, 1.1, 0.95) : vec3(1.0));
	vec3 cell = vec3(0.0);
	vec2 v = vec2(0.5, 1.0);
	float cid = 0.5;
	float vor_k = 1.0 - smoothstep(60.0, 90.0, dist);
	if (vor_k > 0.0) {
		v = voronoi(wpos * aniso / FACET_SIZE[layer] + vec3(seed_s * 7.31, 0.0, 3.7), cell);
		cid = mix(0.5, hash1(cell + 0.37), vor_k);
	}
	float edge = v.y * FACET_SIZE[layer]; // afstand (m) tot de grens met de buurfacet
	float fw = max(fwidth(edge), 1e-4);
	float up = wn.y;
	// Low-poly: de normaal afronden op een vast (per laag gedraaid) rooster van richtingen. Een gebogen
	// wand valt zo uiteen in vlakke facetten die zijn vorm volgen, zoals een grof gemodelleerde rots.
	float ra = float(layer) * 1.7 + seed_s * 0.37;
	mat3 rot = mat3(vec3(cos(ra), 0.0, sin(ra)), vec3(0.0, 1.0, 0.0), vec3(-sin(ra), 0.0, cos(ra)))
			* mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(0.6), sin(0.6)), vec3(0.0, -sin(0.6), cos(0.6)));
	vec3 qv = rot * wn * QUANT[layer];
	vec3 qi = round(qv);
	vec3 nq = transpose(rot) * normalize(qi);
	float facet_id = mix(0.5, hash1(qi + cell * 0.0 + vec3(float(layer) * 3.1)), 1.0 - aa);
	float qamt = QUANT_AMT[layer] * facet_strength * mix(0.6, 1.0, near) * (1.0 - 0.85 * aa);
	qamt *= 1.0 - 0.5 * smoothstep(0.55, 0.9, up); // vloeren zijn vlakker (stof vult op)
	// De landingsplek: aangestampt stof in het midden, dat aan de rand (ruw, niet rond) overgaat in
	// het gewone terrein. Daar minder platen en barsten, zodat het geen tegelvloer wordt.
	float pad_k = 0.0;
	float pad_d = 1e6;
	if (landing_pad.w > 0.0) {
		pad_d = distance(wpos.xz, landing_pad.xy);
		float rough_edge = (vnoise(vec3(wpos.xz * 0.12, 7.0)) - 0.5) * 9.0;
		pad_k = (1.0 - smoothstep(landing_pad.z, landing_pad.w, pad_d + rough_edge)) * smoothstep(0.8, 0.95, up);
	}
	vec3 n = normalize(mix(wn, nq, qamt));
	// Daarbovenop een kleine willekeurige kanteling per voronoi-cel: breekt grote vlakke wanden.
	vec3 rv = hash33(cell + vec3(31.7, 5.1, 9.9)) * 2.0 - 1.0;
	vec3 tilt = rv - dot(rv, n) * n;
	// Geen afschuining: die tekende een omtrek rond elke cel. Vlakken grenzen hard aan elkaar.
	n = normalize(n + tilt * FACET_TILT[layer] * 0.35 * facet_strength * near * (1.0 - 0.75 * pad_k));

	// 2. Kleur: grote vlekken, een tint per facet, af en toe een lichter of donkerder vlak.
	float big = mix(0.5, vnoise(wpos * 0.11 + vec3(seed_s)), fine_k);
	vec3 col = mix(base, light, smoothstep(0.55, 0.85, big) * 0.55);
	col = mix(col, dark, (1.0 - smoothstep(0.15, 0.42, big)) * 0.5);
	// Van ver: grote vlekken (donkere puinvelden, lichte stofvlakten) van honderden meters.
	float far_k = smoothstep(150.0, 500.0, dist);
	if (far_k > 0.0) {
		float lv = vnoise(vec3(wpos.xz * 0.0036, seed_s * 1.7)) * 0.6 + vnoise(vec3(wpos.xz * 0.0011, seed_s + 5.0)) * 0.4;
		col = mix(col, dark * 1.5, smoothstep(0.56, 0.8, lv) * 0.5 * far_k);
		col = mix(col, light, smoothstep(0.44, 0.22, lv) * 0.3 * far_k);
	}
	col *= 0.9 + 0.2 * facet_id; // elk vlak een eigen tint, zoals geschilderd (van ver gemiddeld)
	// Grens tussen twee vlakken: een dun licht lijntje, zoals een afgeschuinde rand die licht vangt.
	float qedge = step(0.001, dot(fwidth(qi), vec3(1.0)));
	col = mix(col, light * 1.15, qedge * 0.22 * near * qamt);
	col *= 0.96 + 0.08 * cid;
	float rough = ROUGH[layer];
	vec3 emit = vec3(0.0);

	if (layer == 3) {
		// Klei: kleine lichte kiezels.
		if (dist < 12.0) {
			float peb = smoothstep(0.86, 0.89, vnoise(wpos * 15.0 + vec3(9.0))) * step(0.5, vnoise(wpos * 1.3 + vec3(2.0)));
			col = mix(col, mix(light, vec3(dot(light, vec3(0.333))), 0.4) * 1.1, peb * 0.35 * near * (1.0 - smoothstep(4.0, 12.0, dist)));
		}
	} else if (layer == 2) {
		// Zandsteen: horizontale banden van wisselende dikte en tint, licht golvend.
		float yb = y * 2.6 + 0.6 * sin(wpos.x * 0.17 + wpos.z * 0.12 + seed_s);
		yb += 0.35 * sin(yb * 0.57);
		float h = hash1(vec3(floor(yb), seed_s, 3.3));
		vec3 band = h < 0.25 ? mix(base, dark, 0.7) : (h < 0.78 ? base : mix(base, light, 0.6));
		col = mix(col, band * (0.95 + 0.1 * cid), 0.7);
		float bf = fract(yb);
		float bfw = max(fwidth(yb), 1e-4);
		float bline = 1.0 - smoothstep(0.035, 0.035 + bfw * 1.5, min(bf, 1.0 - bf));
		col *= 1.0 - bline * 0.22 * clamp(0.035 / bfw, 0.0, 1.0);
	} else if (layer == 1) {
		// Graniet: zwarte, witte en roze spikkels.
		float k = near;
		k *= 1.0 - smoothstep(3.0, 12.0, dist); // spikkels zijn klein: enkel van dichtbij
		if (k > 0.0) {
			col = mix(col, vec3(0.015), smoothstep(0.8, 0.84, vnoise(wpos * 24.0 + vec3(3.1))) * 0.55 * k);
			col = mix(col, lin(vec3(0.88, 0.88, 0.86)), smoothstep(0.84, 0.88, vnoise(wpos * 28.0 + vec3(17.0))) * 0.4 * k);
			col = mix(col, lin(PINK), smoothstep(0.83, 0.87, vnoise(wpos * 18.0 + vec3(41.0))) * 0.4 * k);
		}
		col = mix(col, mix(col, lin(PINK), 0.25), smoothstep(0.55, 0.8, vnoise(wpos * 0.6 + vec3(2.0)))); // roze waas in vlekken
	} else {
		// Kristal: spaarzame lichtgevende aders langs grote breuklijnen, en glinsters.
		vec3 vc;
		vec2 vv = voronoi(wpos / 2.8 + vec3(5.3, seed_s, 1.7), vc);
		float ve = vv.y * 2.8; // afstand (m) tot de breuklijn
		float vfw = max(fwidth(ve), 1e-4);
		float mask = smoothstep(0.62, 0.74, vnoise(wpos * 0.17 + vec3(11.0))); // slechts een klein deel van de breuken
		float vein = (1.0 - smoothstep(0.022, 0.022 + vfw * 1.5, ve)) * mask;
		float halo = (1.0 - smoothstep(0.0, 0.45, ve)) * mask;
		float glow = (1.0 - smoothstep(0.0, 1.6, ve)) * mask; // zachte cyane schijn op de rots rond een ader
		float pulse = 0.78 + 0.22 * sin(TIME * 1.3 + hash1(vc) * 6.28);
		vec3 cy = lin(CYAN);
		emit = cy * (vein * vein_energy + halo * halo * 0.08 + glow * glow * 0.035) * pulse;
		col = mix(col, cy * 0.35, vein);
		col += cy * halo * 0.04;
		col = mix(col, light, 0.3); // kristalgesteente iets lichter, anders verdwijnt het in het donker
		rough = mix(rough, 0.15, vein);
		float g = hash1(floor(wpos * 15.0) + vec3(seed_s));
		float twinkle = pow(max(0.0, sin(TIME * 2.1 + g * 97.0)), 14.0);
		emit += mix(cy, vec3(1.0), 0.5) * step(0.993, g) * twinkle * 1.6 * near;
	}

	// Barstjes op de facetgrenzen, en net erbinnen een lichter randje (afgeschuinde rand vangt licht).
	// Enkel in vlekken: overal barstjes leest als tegels.
	float cw = 0.018;
	// (Enkel dichtbij uitrekenen: verder dan 34 m is camp nul.)
	float cmask = near > 0.0 ? smoothstep(0.45, 0.7, vnoise(wpos * 0.33 + vec3(21.0))) * CRACKS[layer] * (1.0 - 0.8 * pad_k) : 0.0;
	if (layer == 3) {
		cmask *= smoothstep(0.45, 0.8, up); // klei: enkel droge barsten op de vloer
	}
	float camp = clamp(cw / fw, 0.0, 1.0) * near; // ondermaats op afstand: vervagen i.p.v. flikkeren
	float crack = 1.0 - smoothstep(cw, cw + fw * 1.5, edge);
	col *= 1.0 - crack * 0.6 * camp * cmask;


	// Kromming van de vorm zelf: bolle randen vangen licht, holtes worden donkerder (DRG-trucje).
	vec3 g_n = normalize(wnrm);
	float curv = (dot(dFdx(g_n), dpx) + dot(dFdy(g_n), dpy)) / max(dot(dpx, dpx) + dot(dpy, dpy), 1e-6);
	curv *= 1.0 - aa; // per 2×2 pixels: van ver enkel ruis
	col = mix(col, light * 1.12, smoothstep(0.5, 2.2, curv) * 0.35 * near);
	col *= 1.0 - smoothstep(0.5, 2.2, -curv) * 0.3;

	// 3. Stof op vloeren, donkerder en iets koeler onder overhangen.
	float dn = dust_k > 0.0 ? mix(0.5, vnoise(wpos * 0.8 + vec3(4.0)), dust_k) : 0.5;
	float dust = smoothstep(0.5, 0.88, up) * (0.5 + 0.5 * dn);
	vec3 dust_col = mix(light, vec3(dot(light, vec3(0.333))), 0.3);
	col = mix(col, dust_col, dust * 0.45);
	rough = mix(rough, 1.0, dust);
	if (pad_k > 0.0) {
		// Aangestampt stof, en in het midden een vlek die de stuwraketten van de Mol hebben geschroeid.
		col = mix(col, dust_col * 0.93, 0.35 * pad_k);
		float burn = (1.0 - smoothstep(2.5, 12.0, pad_d)) * (0.55 + 0.45 * vnoise(vec3(wpos.xz * 0.45, 3.0)));
		col *= 1.0 - 0.28 * burn * pad_k;
	}
	float ceil_k = smoothstep(0.35, 0.85, -up);
	col *= mix(vec3(1.0), vec3(0.66, 0.7, 0.8), ceil_k);

	// Naad op de laaggrens: een donkere lijn met een iets donkerdere contactzone.
	float db = min(min(abs(y - top_kristal), abs(y - top_graniet)), abs(y - top_zandsteen));
	float sfw = max(fwidth(y), 1e-4);
	float seam = 1.0 - smoothstep(0.06, 0.06 + sfw * 1.5, db);
	float contact = 1.0 - smoothstep(0.1, 0.7, db);
	col *= (1.0 - seam * 0.75) * (1.0 - contact * 0.2);
	// Lichte lip net boven de naad: de grens leest als een richel.
	float lip = smoothstep(0.06, 0.1, db) * (1.0 - smoothstep(0.12, 0.22, db)) * near;
	col = mix(col, light * 1.15, lip * 0.35);

	// Erts vlak achter de wand: fonkelende spikkels in de kleur van het erts, en een lichte
	// verkleuring rond de ader. Zo zie je waar je moet graven.
	float ore_k = 0.0;
	vec3 ore_c = vec3(0.0);
	for (int i = 0; i < ore_count; i++) {
		float k = 1.0 - smoothstep(0.4, 1.8, distance(wpos, ore_points[i].xyz));
		if (k > ore_k) {
			ore_k = k;
			ore_c = ore_colors[int(ore_points[i].w)].rgb;
		}
	}
	if (ore_k > 0.0) {
		// Kleine ronde fonkels (±3 cm), weinig, meer naarmate je dichter bij de ader zit.
		vec3 cp = wpos * 34.0 + vec3(seed_s * 3.1);
		vec3 ci = floor(cp);
		float h = hash1(ci);
		float r = 0.2 + 0.14 * hash1(ci + vec3(7.3));
		float speck = step(1.0 - 0.14 * ore_k, h) * (1.0 - smoothstep(r * 0.55, r, length(fract(cp) - 0.5)));
		float twinkle = 0.5 + 0.5 * sin(TIME * 2.6 + h * 60.0);
		speck *= near;
		col = mix(col, ore_c * 0.4, ore_k * ore_k * 0.28);
		col = mix(col, ore_c, speck * 0.8);
		emit += ore_c * (speck * twinkle * (0.9 + 1.6 * ore_k) + ore_k * ore_k * 0.04);
	}

	// Verre landschap: de kleur van de landvorm (stof op de kraterbodem, donkere duinen, de put) en
	// lagen in de wanden, op hoogte (zoals gelaagd gesteente), licht golvend.
	if (far_terrain) {
		col *= vtint.rgb;
		if (vtint.a > 0.01) {
			// Dikke, onregelmatige lagen (±18 m), enkel op de steile delen: op richels ligt stof.
			float sb = wpos.y / 18.0 + 0.45 * vnoise(vec3(wpos.x * 0.004, 0.0, wpos.z * 0.004));
			float band = fract(sb + 0.25 * vnoise(vec3(0.0, wpos.y * 0.09, 0.0)));
			vec3 sc = band < 0.45 ? strata_light : (band < 0.8 ? strata_mid : strata_dark);
			float steep = 1.0 - smoothstep(0.55, 0.85, n.y);
			col = mix(col, lin(sc) * 0.92, vtint.a * steep * 0.5);
		}
	}

	// Onstabiele zone: een net van donkere barsten, licht stof, en gele krijtstrepen op het plafond.
	float zone_k = 0.0;
	for (int i = 0; i < hazard_count; i++) {
		vec3 dz = wpos - hazard_zones[i].xyz;
		float r = hazard_zones[i].w;
		zone_k = max(zone_k, 1.0 - smoothstep(r * 0.75, r * 1.05, length(dz)));
	}
	if (zone_k > 0.0) {
		vec3 zc = wpos * 1.3 + vec3(seed_s * 5.7);
		vec3 zi = floor(zc);
		vec3 zf = fract(zc);
		// Voronoi in 3D (grof), de randen zijn de barsten.
		float d1 = 8.0;
		float d2 = 8.0;
		for (int k = 0; k < 27; k++) {
			vec3 g = vec3(float(k % 3) - 1.0, float((k / 3) % 3) - 1.0, float(k / 9) - 1.0);
			vec3 o = vec3(hash1(zi + g), hash1(zi + g + vec3(3.1)), hash1(zi + g + vec3(7.7)));
			float d = length(g + o - zf);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
		float zcrack = 1.0 - smoothstep(0.0, 0.11, d2 - d1);
		float ceiling = clamp(-n.y, 0.0, 1.0);
		col = mix(col, col * 1.3 + vec3(0.07, 0.06, 0.045), zone_k * 0.4); // fijn stof
		col = mix(col, vec3(0.015, 0.012, 0.01), zcrack * zone_k * (0.7 + 0.3 * ceiling));
	}

	// Magma eronder: de rots warmt op naar donkerrood, vooral vlakken die naar beneden kijken, met
	// een felle rand vlak boven het magma. Zo gloeit de plek waar rots en magma elkaar raken.
	float above_m = wpos.y - magma_height;
	if (above_m < magma_heat_m && above_m > -3.0) {
		float heat = 1.0 - smoothstep(0.0, magma_heat_m, max(above_m, 0.0));
		float down = clamp(0.5 - 0.5 * n.y, 0.0, 1.0);
		col = mix(col, col * vec3(0.5, 0.22, 0.15), heat * 0.65);
		emit += vec3(1.0, 0.22, 0.03) * heat * heat * (0.06 + 0.3 * down);
		float rim = 1.0 - smoothstep(0.0, 0.3, above_m);
		emit += vec3(1.0, 0.36, 0.05) * rim * rim * 2.2;
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	// Stof en rots weerkaatsen weinig: zonder dit spiegelen vlakke kratervloeren onder een scherende
	// hoek de lichte hemel (witte "meren").
	SPECULAR = 0.18;
	EMISSION = emit;
	AO = (1.0 - contact * 0.3) * (1.0 - smoothstep(0.5, 2.2, -curv) * 0.35) * (1.0 - crack * 0.5 * camp * cmask);
	AO_LIGHT_AFFECT = 0.5;
}
