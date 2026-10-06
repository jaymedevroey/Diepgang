shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Gestileerde rots (docs/stijlgids.md, docs/research/rots-en-licht.md).
// Alles in wereldruimte en procedureel: geen UV's nodig op het voxelterrein, geen naden.
//   1. Facetten: 3D-voronoi; elke cel kantelt de normaal een beetje, zodat de wand uit
//      afgebrokkelde vlakken bestaat (het DRG-trucje). Vlakken grenzen hard aan elkaar, zonder
//      lijnen (lijnen op facetranden lazen als glas-in-lood, release-audit binnen-07).
//   2. Kleur per planeet en per laag (Underground: ug_*), met een eigen patroon per laag:
//      klei: gevlekt en fijn gelaagd, in eenheden van ±8 m met elk een merklaag (bleek, donker, koel, grind, of het eigen
//        accent van de planeet: gloeiende geodes, botbedden, kristalinsluitsels) en hier en daar
//        gloeiende knollen · zandsteen: banden met scheve gelaagdheid en een ijzerband ·
//        graniet: koel, in blokken gebroken, met grote spikkels · kristal: donker, met brede
//        kristalnaden en echte kristallen in de rots die oplichten waar je erdoor graaft.
//   3. Aan het oppervlak (de bovenste meter, `surf_height`) een korst per planeet: Roestbol
//      windribbels en stofsporen, Fossielwereld krijtplaten en gruis, Kristalmaan zeshoeken en
//      glinsters. Onder de grond geen barstjes maar gruis op de vloer (binnen-07, buiten-12).
//   4. Stof op vloeren, donkerder onder overhangen, een naad op de laaggrens.
//   5. Erts vlak achter de wand: een verkleuring in de kleur van verweerd erts en grote glinsters
//      die van ver te zien zijn (binnen-03).
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
// Kleuren van de bovenste laag per planeet (PlanetType.ground), sRGB. Standaard: klei (Roestbol).
uniform vec3 surf_base = vec3(0.431, 0.290, 0.208);
uniform vec3 surf_light = vec3(0.604, 0.420, 0.298);
uniform vec3 surf_dark = vec3(0.243, 0.165, 0.122);
// Lagen in een wand van het verre landschap (Landform: COLOR.a = hoeveel), sRGB: licht, midden, donker.
uniform vec3 strata_light = vec3(0.878, 0.706, 0.549);
uniform vec3 strata_mid = vec3(0.722, 0.416, 0.267);
uniform vec3 strata_dark = vec3(0.478, 0.227, 0.165);
// Per planeet (Landform.shader_params): dikte van een laag (m), grenzen tussen licht/midden/donker,
// hoe sterk, vanaf welke helling (normaal.y: volop .. niets), en een sleutellaag (bv. een ijzerband):
// x = hoogte (wereld, m), y = dikte (m), z = sterkte (0 = uit).
// Grote lichte en donkere vlekken in de bovenste laag, in de kleuren van de planeet (rgb = maal de
// kleur, a = hoeveel), over de rand van het speelgebied heen: van boven geen effen vierkant meer.
// Enkel aan de oppervlakte (tot een paar meter onder surface_world_y), niet in de tunnels.
uniform vec4 patch_dark = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 patch_light = vec4(1.0, 1.0, 1.0, 0.0);
uniform float patch_scale = 100.0;
uniform float surface_world_y = 1e6;
// De tint van de landvorm over het speelgebied (PlanetSurface._near_tint_data): rgb gehalveerd (1 =
// neutraal), a = naden van een zeshoekige korst. rect: x/z = oorsprong (m), z = m per texel, w = texels.
uniform sampler2D near_tint : filter_linear, repeat_disable;
uniform vec4 near_tint_rect = vec4(0.0, 0.0, 2.0, 1.0);
uniform bool near_tint_on = false;
// Rooster van de korstplaten (KristalMesh.hex_plate in landform_kristal.gd): straal en naad (m).
uniform vec2 crust_hex = vec2(5.0, 0.5);
uniform float strata_scale = 18.0;
uniform vec2 strata_cuts = vec2(0.45, 0.8);
uniform float strata_strength = 0.5;
uniform vec2 strata_steep = vec2(0.55, 0.85);
uniform vec3 strata_key = vec3(0.0);
uniform vec3 strata_key_color = vec3(0.69, 0.282, 0.165);
uniform float top_kristal = 35.0;
uniform float top_graniet = 80.0;
uniform float top_zandsteen = 125.0;
uniform float vein_energy = 2.4;
uniform float facet_strength = 1.0;
// De ondergrond per planeet (Underground.apply), sRGB, per laag (0 kristal .. 3 klei onder de
// korst): basis, licht, donker en een accent (kristal: ader, graniet: kwarts, zandsteen: ijzerband,
// klei: gloed). Merklagen in de klei: 0 bleek, 1 donker, 2 koel, 3 grind.
uniform int planet_id = 0;
uniform vec3 ug_base[4];
uniform vec3 ug_light[4];
uniform vec3 ug_dark[4];
uniform vec3 ug_accent[4];
uniform vec3 ug_band[4];
// Hoogte van het oppervlak van de generator (TerrainAPI): x = m per texel, y/z = texels, w = aan.
// Zo weet de shader hoe diep een punt onder zijn eigen oppervlak ligt (korst of ondergrond).
uniform sampler2D surf_height : filter_linear, repeat_disable;
uniform vec4 surf_height_rect = vec4(2.0, 1.0, 1.0, 0.0);
// Erts vlak achter de wand (OreField): xyz = cluster (wereld), w = soort. Kleuren lineair.
uniform vec4 ore_points[16];
uniform int ore_count = 0;
uniform vec4 ore_colors[4];
// Verkleuring rond een ader per soort (Underground.ORE_STAIN), lineair; a = hoe sterk.
uniform vec4 ore_stain[4];
// Verse sneden (TerrainAPI._update_fresh): xyz = midden van een recente graafactie, w = straal (m),
// met een gewicht dat in ±35 s uitdooft. Daar is de rots donkerder, vochtiger en zonder stof, met
// een lichte breukrand: zo zie je bij elke slag hoe ver je bent (release-audit binnen-09, gevoel-19).
uniform vec4 fresh_ops[24];
uniform float fresh_w[24];
uniform int fresh_count = 0;
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

const vec3 PINK = vec3(0.659, 0.514, 0.471);
// Facetgrootte (m), kanteling, ruwheid per laag.
const float FACET_SIZE[4] = float[](1.25, 1.45, 1.1, 0.85);
const float FACET_TILT[4] = float[](0.85, 0.8, 0.6, 0.48);
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

// Een knol in een kubuscel van `size` m (enkel de eigen cel: de knol past er altijd in, dus geen
// buren nodig). x = afstand tot het midden / straal (< 1 = erin), y = een hash per knol,
// z = 1 als de cel een knol heeft, w = 1 binnen de cel, naar 0 aan haar rand (voor een schijn rond
// de knol, die anders recht afgesneden wordt). `chance` = kans per cel, rmin/rmax = straal als deel
// van de cel.
vec4 nodule(vec3 p, float size, float chance, float rmin, float rmax, float salt) {
	vec3 q = p / size;
	vec3 ci = floor(q);
	vec3 f = fract(q);
	float h = hash1(ci + vec3(salt));
	float r = mix(rmin, rmax, hash1(ci + vec3(salt + 7.3)));
	vec3 c = vec3(0.5) + (hash33(ci + vec3(salt + 1.7)) - 0.5) * (1.0 - 2.0 * r) * 0.6;
	float d = length(f - c) / r;
	vec3 e = abs(f - 0.5);
	float border = 1.0 - smoothstep(0.34, 0.49, max(max(e.x, e.y), e.z));
	return vec4(d, hash1(ci + vec3(salt + 3.1)), step(1.0 - chance, h), border);
}

// Zoals nodule(), maar ook de plek in de knol: `off` = (p - midden) / straal (lengte = x).
vec4 nodule_at(vec3 p, float size, float chance, float rmin, float rmax, float salt, out vec3 off) {
	vec3 q = p / size;
	vec3 ci = floor(q);
	vec3 f = fract(q);
	float h = hash1(ci + vec3(salt));
	float r = mix(rmin, rmax, hash1(ci + vec3(salt + 7.3)));
	vec3 c = vec3(0.5) + (hash33(ci + vec3(salt + 1.7)) - 0.5) * (1.0 - 2.0 * r) * 0.6;
	off = (f - c) / r;
	float d = length(off);
	vec3 e = abs(f - 0.5);
	float border = 1.0 - smoothstep(0.34, 0.49, max(max(e.x, e.y), e.z));
	return vec4(d, hash1(ci + vec3(salt + 3.1)), step(1.0 - chance, h), border);
}

// Twee raakrichtingen bij normaal n (voor patronen op de wand zelf: facetten, sterretjes).
void tangents(vec3 n, out vec3 t1, out vec3 t2) {
	t1 = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	t2 = cross(n, t1);
}

// Een glinster (golf 3, binnen2-09: geen zachte bolletjes meer, die lazen als bokeh): een klein,
// hard facet met een sterretje, in een kubuscel van `gs` m met kans `chance`. Hij licht fel op als
// zijn facet (een eigen normaal, wat gekanteld t.o.v. de wand) naar de camera kijkt: de lamp zit op je
// hoofd, dus dat is de spiegeling. x = vorm (0..1), y = flits (0..1), z = hash.
vec3 glint(vec3 wp, vec3 n, vec3 view, float gs, float chance, float salt) {
	vec3 cp = wp / gs + vec3(salt);
	vec3 ci = floor(cp);
	float h = hash1(ci);
	if (h < 1.0 - chance) {
		return vec3(0.0);
	}
	vec3 t1;
	vec3 t2;
	tangents(n, t1, t2);
	vec3 lq = fract(cp) - 0.5;
	float a = hash1(ci + vec3(5.1)) * 3.14159;
	vec2 q = vec2(dot(lq, t1), dot(lq, t2)) * 2.0;
	q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
	vec2 aq = abs(q);
	// Een ruitje als kern met vier dunne stralen: hard, met een rand van één pixel.
	float core = 1.0 - smoothstep(0.13, 0.18, aq.x + aq.y);
	float rays = max(1.0 - smoothstep(0.0, 0.05, aq.y) , 0.0) * (1.0 - smoothstep(0.12, 0.45, aq.x))
			+ max(1.0 - smoothstep(0.0, 0.05, aq.x), 0.0) * (1.0 - smoothstep(0.12, 0.45, aq.y));
	vec3 fn = normalize(n + (hash33(ci + vec3(salt)) - 0.5) * 1.1);
	float spec = pow(clamp(dot(fn, view), 0.0, 1.0), 18.0);
	return vec3(max(core, rays * spec), spec, h);
}

// Afstand van p tot een staafje (kristal of bot) in een kubuscel: x = afstand tot de as / straal,
// y = positie langs de as (-1..1), z = 1 als de cel er een heeft. w = hash.
vec4 rod(vec3 p, float size, float chance, float rad, float half_len, float salt) {
	vec3 q = p / size;
	vec3 ci = floor(q);
	float h = hash1(ci + vec3(salt));
	vec3 axis = normalize(hash33(ci + vec3(salt + 4.1)) * 2.0 - 1.0 + vec3(0.0, 0.001, 0.0));
	float rr = rad * mix(0.6, 1.0, hash1(ci + vec3(salt + 2.2)));
	float hl = half_len * mix(0.55, 1.0, hash1(ci + vec3(salt + 5.5)));
	vec3 c = (ci + 0.5) * size;
	vec3 d = p - c;
	float t = clamp(dot(d, axis), -hl, hl);
	float dist = length(d - axis * t);
	return vec4(dist / rr, t / hl, step(1.0 - chance, h), hash1(ci + vec3(salt + 9.9)));
}

// Een zeskantig kristal in een kubuscel van `size` m (het kristal staat in het midden en past
// erin): x = zeskantafstand tot de as / straal (< 1 = erin), y = welk zijvlak (0..5, hash erbij),
// z = 1 als de cel er een heeft, w = 1 binnen de cel en 0 aan haar rand (voor de schijn errond).
vec4 crystal(vec3 p, float size, float chance, float rad, float half_len, float salt) {
	vec3 q = p / size;
	vec3 ci = floor(q);
	float h = hash1(ci + vec3(salt));
	vec3 axis = normalize(hash33(ci + vec3(salt + 4.1)) * 2.0 - 1.0 + vec3(0.0, 0.001, 0.0));
	vec3 u = normalize(cross(axis, abs(axis.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 w = cross(axis, u);
	float rr = rad * mix(0.55, 1.0, hash1(ci + vec3(salt + 2.2)));
	float hl = half_len * mix(0.6, 1.0, hash1(ci + vec3(salt + 5.5)));
	vec3 d = p - (ci + 0.5) * size;
	float t = dot(d, axis);
	vec2 r2 = vec2(dot(d, u), dot(d, w));
	vec2 a = abs(r2);
	float hexd = max(a.x * 0.8660254 + a.y * 0.5, a.y);
	// Een punt aan het uiteinde: het kristal loopt toe (de zeskant krimpt naar de top).
	float taper = clamp((hl - abs(t)) / (rr * 1.6), 0.0, 1.0);
	float dd = hexd / (rr * max(taper, 0.02));
	if (abs(t) > hl) {
		dd = 9.0;
	}
	float side = floor((atan(r2.y, r2.x) + 3.14159265) / 1.0471976);
	vec3 e = abs(fract(q) - 0.5);
	float border = 1.0 - smoothstep(0.36, 0.49, max(max(e.x, e.y), e.z));
	return vec4(dd, side + hash1(ci + vec3(salt + 9.9)), step(1.0 - chance, h), border);
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
	// Diepte onder het eigen oppervlak (m). De korst is enkel de bovenste meter: een gat dat je aan
	// het oppervlak graaft, toont meteen de klei eronder, geen droge barstjes.
	float surf_h = surface_world_y;
	if (surf_height_rect.w > 0.5 && !far_terrain) {
		vec2 suv = (wpos.xz / surf_height_rect.x + 0.5) / surf_height_rect.yz;
		surf_h = texture(surf_height, suv).r;
	}
	float depth = far_terrain ? 0.0 : surf_h - wpos.y;
	float crust_k = 1.0 - smoothstep(0.6, 1.6, depth);
	float under_k = smoothstep(1.2, 5.0, depth);
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

	vec3 base = lin(ug_base[layer]);
	vec3 light = lin(ug_light[layer]);
	vec3 dark = lin(ug_dark[layer]);
	if (layer == 3) { // de bovenste laag: aan het oppervlak de kleuren van de planeet (PlanetType.ground)
		base = mix(lin(surf_base), base, under_k);
		light = mix(lin(surf_light), light, under_k);
		dark = mix(lin(surf_dark), dark, under_k);
	}

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
	// Vloeren onder de grond: gruis, geen platen (de facetten en kantelingen lazen als terrastegels).
	float ug_floor = smoothstep(0.55, 0.85, up) * under_k;
	// Low-poly: de normaal afronden op een vast (per laag gedraaid) rooster van richtingen. Een gebogen
	// wand valt zo uiteen in vlakke facetten die zijn vorm volgen, zoals een grof gemodelleerde rots.
	float ra = float(layer) * 1.7 + seed_s * 0.37;
	mat3 rot = mat3(vec3(cos(ra), 0.0, sin(ra)), vec3(0.0, 1.0, 0.0), vec3(-sin(ra), 0.0, cos(ra)))
			* mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(0.6), sin(0.6)), vec3(0.0, -sin(0.6), cos(0.6)));
	vec3 qv = rot * wn * QUANT[layer];
	vec3 qi = round(qv);
	vec3 nq = transpose(rot) * normalize(qi);
	float facet_id = mix(0.5, hash1(qi + vec3(float(layer) * 3.1)), 1.0 - aa);
	float qamt = QUANT_AMT[layer] * facet_strength * mix(0.6, 1.0, near) * (1.0 - 0.85 * aa);
	qamt *= 1.0 - 0.5 * smoothstep(0.55, 0.9, up); // vloeren zijn vlakker (stof vult op)
	qamt *= 1.0 - 0.6 * ug_floor;
	// Roestbol: zand op vlakke grond aan het oppervlak is niet gefacetteerd (daar liggen ribbels).
	float sand = (planet_id == 0 && layer == 3) ? crust_k * smoothstep(0.75, 0.95, up) : 0.0;
	qamt *= 1.0 - 0.7 * sand;
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
	n = normalize(n + tilt * FACET_TILT[layer] * 0.35 * facet_strength * near * (1.0 - 0.75 * pad_k) * (1.0 - 0.8 * ug_floor));

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
	col *= 0.9 + 0.2 * mix(facet_id, 0.5, 0.6 * ug_floor); // elk vlak een eigen tint, zoals geschilderd (van ver gemiddeld)
	col *= 0.96 + 0.08 * cid;
	float rough = ROUGH[layer];
	vec3 emit = vec3(0.0);
	// Fijn detail tot hier (m): kleine dingen verdwijnen eerder, zodat ze niet flikkeren.
	float det_k = near * (1.0 - smoothstep(0.03, 0.09, px));

	if (layer == 3) {
		// Klei aan het oppervlak: kleine lichte kiezels.
		if (dist < 12.0) {
			float peb = smoothstep(0.86, 0.89, vnoise(wpos * 15.0 + vec3(9.0))) * step(0.5, vnoise(wpos * 1.3 + vec3(2.0)));
			col = mix(col, mix(light, vec3(dot(light, vec3(0.333))), 0.4) * 1.1, peb * 0.35 * near * (1.0 - smoothstep(4.0, 12.0, dist)));
		}
		if (under_k > 0.0 && !far_terrain) {
			// De klei onder de grond: eenheden van ±8 m, elk met een eigen tint en één merklaag van
			// 1,5-3,5 m. Welke merklaag, hangt af van de diepte: bovenaan vooral bleek (kalk, krijt,
			// as), in het midden koel en grind, onderaan donker en het accent van de planeet. Zo zie je
			// om de 5-8 m iets nieuws, en zie je ongeveer hoe diep je zit.
			float uy = y + 0.9 * sin(wpos.x * 0.047 + seed_s) + 0.7 * sin(wpos.z * 0.061 + seed_s * 1.7)
					+ 0.8 * (vnoise(vec3(wpos.xz * 0.08, seed_s)) - 0.5);
			float unit_h = 8.0;
			float uid = floor(uy / unit_h);
			float uf = uy - uid * unit_h; // m in de eenheid
			float hu = hash1(vec3(uid, seed_s, 5.1));
			// Gevlekte klei (zoals echte ondergrond): grijsgroene en donkere vlekken van 0,3-1 m.
			float steep_k = 1.0 - smoothstep(0.55, 0.85, abs(up));
			float mot = vnoise(wpos * 1.5 + vec3(seed_s, 2.0, 0.0)) * 0.65 + vnoise(wpos * 3.8 + vec3(5.0)) * 0.35;
			col = mix(col, lin(ug_band[2]) * 0.95, smoothstep(0.6, 0.68, mot) * 0.3 * under_k);
			col = mix(col, dark, (1.0 - smoothstep(0.3, 0.36, mot)) * 0.25 * under_k);
			// Fijne horizontale laagjes (varven) op de wanden: elke wand leest als een doorsnede.
			float vv = uy * 9.0 + 1.5 * vnoise(wpos * 0.7);
			float varve = sin(vv) * 0.5 + sin(vv * 2.3 + 1.0) * 0.25;
			col *= 1.0 + varve * 0.09 * steep_k * under_k * (1.0 - smoothstep(0.02, 0.06, px));
			col *= mix(vec3(1.0), mix(vec3(0.88, 0.92, 1.0), vec3(1.1, 1.05, 0.98), hu), under_k); // elke eenheid een eigen tint
			float mt = 1.5 + 2.0 * hash1(vec3(uid, seed_s, 9.7));
			float mpos = 1.0 + (unit_h - mt - 2.0) * hash1(vec3(uid, seed_s, 2.3));
			// Golvende randen (±25 cm) en een zachte overgang van ±20 cm: geen verfstreep (binnen2-14).
			float wob = (vnoise(wpos * vec3(0.9, 0.3, 0.9) + vec3(uid * 1.7)) - 0.5) * 0.5;
			float bw = max(fwidth(uf), 1e-3) + 0.2;
			float in_m = smoothstep(mpos - bw + wob, mpos + bw + wob, uf) * (1.0 - smoothstep(mpos + mt - bw - wob, mpos + mt + bw - wob, uf)) * under_k;
			// Korrel: de band is niet egaal, eerder een verzameling klonten.
			in_m *= 0.72 + 0.28 * smoothstep(0.25, 0.7, vnoise(wpos * 2.4 + vec3(uid)));
			float dz = clamp(depth / 70.0, 0.0, 1.0);
			// Gewichten: bleek, donker, koel, grind, accent.
			float w0 = 1.3 * (1.0 - dz) + 0.15;
			float w1 = 1.4 * dz;
			float w2 = 0.8;
			float w3 = 0.7;
			float w4 = (planet_id == 1 ? 0.8 : 0.25) + 0.6 * dz; // Fossielwereld: meer botbedden
			float r = hash1(vec3(uid, seed_s, 7.7)) * (w0 + w1 + w2 + w3 + w4);
			int kind = r < w0 ? 0 : (r < w0 + w1 ? 1 : (r < w0 + w1 + w2 ? 2 : (r < w0 + w1 + w2 + w3 ? 3 : 4)));
			vec3 nod_p = wpos + vec3(seed_s * 3.3, 0.0, seed_s * 1.9);
			if (in_m > 0.0) {
				if (kind == 0) {
					// Bleek (kalk, krijt, as) met knollen: lichter, of vuursteen (zwart) op de Fossielwereld.
					vec3 bc = lin(ug_band[0]);
					col = mix(col, bc * (0.92 + 0.16 * vnoise(wpos * 1.7)), 0.85 * in_m);
					vec4 nd = nodule(nod_p, 0.55, 0.3, 0.14, 0.3, 11.0);
					float nx = nd.x + (vnoise(wpos * 9.0) - 0.5) * 0.5; // grillige rand
					float k = (1.0 - smoothstep(0.85, 1.0, nx)) * nd.z * det_k * in_m * (1.0 - 0.75 * ug_floor);
					vec3 ncol = planet_id == 1 ? lin(ug_band[1]) * 1.4 : bc * 1.18;
					col = mix(col, ncol, k);
					rough = mix(rough, 0.45, k * (planet_id == 1 ? 1.0 : 0.0));
				} else if (kind == 1) {
					// Donker (hematiet, vuursteen, obsidiaan): glanzend, met fijne glinsters.
					col = mix(col, lin(ug_band[1]) * (0.9 + 0.2 * vnoise(wpos * 2.3)), 0.88 * in_m);
					rough = mix(rough, 0.42, in_m);
					float g = hash1(floor(wpos * 22.0) + vec3(seed_s));
					rough = mix(rough, 0.12, step(0.96, g) * in_m * det_k);
				} else if (kind == 2) {
					// Koel (gley, mergel, blauwviolet) met fijne horizontale laagjes, roestvlekken
					// en donkere knolletjes (echte gley is gevlekt, geen effen band).
					col = mix(col, lin(ug_band[2]) * (0.86 + 0.28 * vnoise(wpos * 1.1)), 0.8 * in_m);
					float rust = smoothstep(0.62, 0.74, vnoise(wpos * 1.8 + vec3(4.0)));
					col = mix(col, base * 1.05, rust * 0.45 * in_m);
					vec4 gnd = nodule(nod_p, 0.4, 0.3, 0.1, 0.24, 29.0);
					float gk = (1.0 - smoothstep(0.8, 1.0, gnd.x + (vnoise(wpos * 10.0) - 0.5) * 0.4)) * gnd.z * in_m * det_k;
					col = mix(col, lin(ug_band[2]) * 0.55, gk * 0.7);
					float lam = sin(uy * 34.0 + 2.0 * vnoise(wpos * 0.9));
					col *= 1.0 - 0.12 * smoothstep(0.6, 0.95, lam) * in_m * steep_k * (1.0 - smoothstep(0.02, 0.05, px));
				} else if (kind == 3) {
					// Grind: ronde stenen in drie tinten in een donkere matrix.
					col = mix(col, dark * 1.1, 0.55 * in_m);
					vec4 nd = nodule(nod_p, 0.3, 0.42, 0.12, 0.36, 23.0);
					float nx = nd.x + (vnoise(wpos * 11.0) - 0.5) * 0.45; // geen ronde schijfjes: grillige stenen
					float k = (1.0 - smoothstep(0.8, 1.0, nx)) * nd.z * in_m * (1.0 - smoothstep(0.03, 0.07, px)) * (1.0 - 0.6 * ug_floor);
					vec3 sc = nd.y < 0.4 ? lin(ug_band[3]) : (nd.y < 0.75 ? lin(ug_band[0]) * 0.9 : lin(ug_band[1]) * 1.6);
					col = mix(col, sc * (0.8 + 0.3 * (1.0 - nx)), k * 0.8);
				} else {
					// Het accent van de planeet.
					if (planet_id == 1) {
						// Botbed: ivoren botstukken in grijze mergel.
						col = mix(col, lin(ug_band[2]) * 0.75, 0.85 * in_m);
						// Botten van ±1 m in een donkere mergel: van een paar meter ver te zien.
						vec4 b = rod(wpos + vec3(seed_s), 1.3, 0.6, 0.12, 0.6, 31.0);
						float knob = smoothstep(0.7, 1.0, abs(b.y)) * 0.6; // knobbelige uiteinden
						float k = (1.0 - smoothstep(0.82 + knob, 1.0 + knob, b.x)) * b.z * in_m * near;
						float bedge = (1.0 - smoothstep(1.0 + knob, 1.25 + knob, b.x)) * b.z * in_m * near * (1.0 - k);
						col = mix(col, dark * 0.45, bedge * 0.6); // donkere rand: het bot ligt in de rots
						col = mix(col, lin(vec3(0.88, 0.8, 0.64)) * (0.8 + 0.25 * b.w) * (0.85 + 0.2 * vnoise(wpos * 6.0)), k);
						rough = mix(rough, 0.65, k);
					} else if (planet_id == 2) {
						// Obsidiaan met roze kristalinsluitsels die gloeien.
						col = mix(col, lin(ug_band[1]) * 1.2, 0.85 * in_m);
						rough = mix(rough, 0.25, in_m);
						// Zeskantige kristallen (de doorsnede is hoekig), elk zijvlak een eigen helderheid.
						vec4 c = crystal(wpos + vec3(seed_s), 0.7, 0.5, 0.09, 0.3, 37.0);
						float k = (1.0 - smoothstep(0.85, 1.0, c.x)) * c.z * in_m;
						float facet = 0.3 + 0.7 * hash1(vec3(floor(c.y), 2.9, 7.1));
						vec3 gc = lin(ug_accent[3]);
						col = mix(col, gc * (0.25 + 0.35 * facet), k);
						emit += gc * k * (0.25 + 0.9 * facet);
						rough = mix(rough, 0.06, k);
					} else {
						// Roestbol: een laag vol geodes die koel gloeien, in donkere klei.
						col = mix(col, dark * 0.95, 0.6 * in_m);
					}
				}
			}
			// Gloeiende knollen (geodes, fosfor, kristal): in zakken door de hele klei, het dichtst
			// in de accentlaag en dieper. Klein (10-25 cm) maar fel: van ver lichtpuntjes in het donker.
			if (planet_id != 1 || kind == 4) {
				float pocket = smoothstep(0.58, 0.72, vnoise(wpos * 0.07 + vec3(seed_s, 3.0, 1.0)));
				float chance = mix(0.015, 0.4, pocket) * mix(0.6, 1.4, dz);
				chance = mix(chance, 0.55, (kind == 4 ? in_m : 0.0));
				vec3 noff;
				vec4 nd = nodule_at(nod_p + vec3(0.7), 1.4, chance, 0.08, 0.16, 47.0, noff);
				if (nd.z > 0.0 && nd.x < 1.6) {
					// Een geode: een donkere, ruwe schil (in de rots) rond een kristal waarvan je de
					// zes zijvlakken ziet, elk een andere helderheid. Geen zachte gloed eromheen: hij
					// zit in de wand, hij zweeft niet (binnen2-09).
					vec3 gc = lin(ug_accent[3]);
					vec3 nt1;
					vec3 nt2;
					tangents(n, nt1, nt2);
					vec2 nq = vec2(dot(noff, nt1), dot(noff, nt2));
					float hexd = max(abs(nq.x) * 0.866 + abs(nq.y) * 0.5, abs(nq.y));
					float ragged = (vnoise(wpos * 14.0) - 0.5) * 0.25;
					float core = 1.0 - smoothstep(0.62, 0.7, hexd);
					float rim = (1.0 - smoothstep(0.95 + ragged, 1.1 + ragged, nd.x)) * (1.0 - core);
					float side = floor((atan(nq.y, nq.x) + 3.14159265) / 1.0471976);
					float facet = 0.25 + 0.75 * hash1(vec3(side, nd.y * 31.0, 4.4));
					float pulse = 0.85 + 0.15 * sin(TIME * (0.6 + nd.y) + nd.y * 40.0);
					col = mix(col, dark * 0.3, rim * 0.92 * under_k);
					col = mix(col, gc * (0.2 + 0.4 * facet), core * under_k);
					emit += gc * under_k * core * (0.5 + 1.6 * facet) * pulse;
					emit += vec3(1.0) * under_k * core * (1.0 - smoothstep(0.0, 0.08, abs(hexd - 0.6))) * 0.6; // heldere rand van het kristal
					rough = mix(rough, 0.06, core);
				}
			}
			if (planet_id == 1 && kind != 4) {
				// Fossielwereld: hier en daar een losse botsplinter in het krijt.
				vec4 b = rod(wpos + vec3(seed_s * 2.0), 1.3, 0.24, 0.07, 0.3, 53.0);
				float k = (1.0 - smoothstep(0.85, 1.0, b.x)) * b.z * under_k * det_k;
				col = mix(col, lin(vec3(0.9, 0.83, 0.7)), k);
			}
			// Gruis op de vloer: fijne, ongelijke korrels (geen platen).
			float gr = vnoise(wpos * 6.5 + vec3(seed_s));
			col *= 1.0 + (gr - 0.5) * 0.28 * ug_floor * (1.0 - smoothstep(0.02, 0.06, px));
		}
	} else if (layer == 2) {
		// Zandsteen: horizontale banden van wisselende dikte en tint, licht golvend, met scheve
		// gelaagdheid in de dikke banden en af en toe een roestrode ijzerband.
		float yb = y * 2.6 + 0.6 * sin(wpos.x * 0.17 + wpos.z * 0.12 + seed_s);
		yb += 0.35 * sin(yb * 0.57);
		float bid = floor(yb);
		float h = hash1(vec3(bid, seed_s, 3.3));
		vec3 band = h < 0.22 ? mix(base, dark, 0.75) : (h < 0.72 ? base : mix(base, light, 0.7));
		if (h > 0.9) {
			band = lin(ug_accent[2]);
		}
		col = mix(col, band * (0.95 + 0.1 * cid), 0.75);
		float bf = fract(yb);
		float bfw = max(fwidth(yb), 1e-4);
		float bline = 1.0 - smoothstep(0.035, 0.035 + bfw * 1.5, min(bf, 1.0 - bf));
		col *= 1.0 - bline * 0.25 * clamp(0.035 / bfw, 0.0, 1.0);
		// Scheve gelaagdheid: fijne schuine lijntjes binnen een band (per band een eigen richting).
		float ang = hash1(vec3(bid, seed_s, 8.8)) * 6.2831;
		float sl = yb * 5.0 + dot(wpos.xz, vec2(cos(ang), sin(ang))) * 1.6;
		float lw = max(fwidth(sl), 1e-3);
		float lam = 1.0 - smoothstep(0.06, 0.06 + lw * 1.5, abs(fract(sl) - 0.5) * 2.0 - 0.9);
		col *= 1.0 - 0.09 * lam * step(0.22, h) * step(h, 0.9) * (1.0 - smoothstep(0.03, 0.08, px));
		// IJzerconcreties: donkere ronde knollen.
		vec4 nd = nodule(wpos + vec3(seed_s), 1.1, 0.08, 0.12, 0.3, 61.0);
		float k = (1.0 - smoothstep(0.85, 1.0, nd.x)) * nd.z * det_k;
		col = mix(col, dark * 0.7, k);
	} else if (layer == 1) {
		// Graniet: koel, in blokken gebroken (drie stelsels breukvlakken), met grote zwarte, witte en
		// roze spikkels en een witte kwartsader hier en daar.
		if (planet_id == 1) {
			// Fossielwereld: gneis, golvende donkere en lichte banden (foliatie) door het blok.
			float fol = wpos.y * 1.6 + 1.2 * sin(wpos.x * 0.35 + wpos.z * 0.22) + 0.8 * vnoise(wpos * 0.5);
			float fb = sin(fol * 2.2) * 0.5 + 0.5;
			col = mix(col, dark * 0.9, smoothstep(0.55, 0.85, fb) * 0.55);
			col = mix(col, light * 1.08, (1.0 - smoothstep(0.08, 0.3, fb)) * 0.35);
		} else if (planet_id == 2) {
			// Kristalmaan: basalt in zeskantige zuilen (barsten in een zeshoekig rooster, rechtop).
			vec2 hp = wpos.xz / 1.1;
			vec2 hr = vec2(1.0, 1.7320508);
			vec2 ha = mod(hp, hr) - hr * 0.5;
			vec2 hb = mod(hp + hr * 0.5, hr) - hr * 0.5;
			vec2 hg = dot(ha, ha) < dot(hb, hb) ? ha : hb;
			vec2 hgabs = abs(hg);
			float hd = 0.5 - max(dot(hgabs, normalize(vec2(1.0, 1.7320508))), hgabs.x);
			float hw = max(fwidth(hd), 1e-3);
			float col_line = (1.0 - smoothstep(0.015, 0.015 + hw * 1.5, hd)) * (1.0 - smoothstep(0.6, 0.9, abs(n.y))) * (1.0 - smoothstep(0.04, 0.12, px));
			col *= 1.0 - col_line * 0.6;
			col = mix(col, light, (1.0 - smoothstep(0.0, 0.06, hd - 0.02)) * (1.0 - col_line) * 0.15);
		}
		vec3 jw = wpos + 0.35 * vec3(vnoise(wpos * 0.4), vnoise(wpos * 0.4 + 7.0), vnoise(wpos * 0.4 + 13.0));
		vec3 sp = vec3(2.3, 1.7, 2.9);
		vec3 jd = abs(fract(vec3(jw.x * 0.8 + jw.z * 0.6, jw.y, jw.z * 0.8 - jw.x * 0.6) / sp) - 0.5) * 2.0;
		vec3 jm = vec3(1.0) - jd; // 0 op het breukvlak
		jm *= sp * 0.5; // in meter
		float jmask = smoothstep(0.35, 0.6, vnoise(wpos * 0.25 + vec3(5.0))) * (planet_id == 0 ? 1.0 : 0.45);
		vec3 jwid = max(fwidth(jm), vec3(1e-3));
		vec3 jl = vec3(1.0) - smoothstep(vec3(0.02), vec3(0.02) + jwid * 1.5, jm);
		float jline = max(max(jl.x, jl.y), jl.z);
		jline *= jmask * (1.0 - 0.7 * ug_floor) * (1.0 - smoothstep(0.04, 0.12, px));
		col *= 1.0 - jline * 0.55;
		float kd = 1.0 - smoothstep(3.0, 10.0, dist); // spikkels (1-2 cm): tot ±10 m
		if (kd > 0.0) {
			col = mix(col, lin(ug_dark[1]) * 0.3, smoothstep(0.83, 0.86, vnoise(wpos * 21.0 + vec3(3.1))) * 0.55 * kd);
			col = mix(col, lin(ug_accent[1]), smoothstep(0.85, 0.88, vnoise(wpos * 24.0 + vec3(17.0))) * 0.45 * kd);
			col = mix(col, lin(PINK), smoothstep(0.86, 0.89, vnoise(wpos * 17.0 + vec3(41.0))) * 0.4 * kd * (planet_id == 0 ? 1.0 : 0.0));
			// Kristalmaan: violette fonkels in het basalt.
			emit += lin(ug_accent[1]) * step(0.997, hash1(floor(wpos * 30.0) + vec3(seed_s * 1.3))) * kd * (planet_id == 2 ? 0.35 : 0.0);
			float mica = step(0.975, hash1(floor(wpos * 30.0) + vec3(seed_s)));
			rough = mix(rough, 0.15, mica * kd);
		}
		// Kwartsaders: een paar dunne witte banen door het blok.
		float qz = abs(dot(wpos, normalize(vec3(0.6, 0.35, -0.7))) + 3.0 * vnoise(wpos * 0.15) + seed_s);
		float qd = abs(fract(qz / 9.0) - 0.5) * 9.0;
		float qwid = max(fwidth(qd), 1e-3);
		float quartz = (1.0 - smoothstep(0.05, 0.05 + qwid * 1.5, qd)) * smoothstep(0.55, 0.7, vnoise(wpos * 0.2 + vec3(9.0)));
		col = mix(col, lin(ug_accent[1]) * 1.05, quartz * 0.85);
		rough = mix(rough, 0.3, quartz);
	} else {
		// Kristalgesteente: donker, met dunne lichtgevende naden langs grote breuklijnen, en echte
		// zeskantige kristallen in de rots: waar je erdoor graaft, zie je hun doorsnede oplichten
		// (elk zijvlak een eigen helderheid), en de rots errond krijgt hun schijn.
		vec3 vcol = lin(ug_accent[0]);
		vec3 vc;
		vec2 vv = voronoi(wpos / 2.8 + vec3(5.3, seed_s, 1.7), vc);
		float ve = vv.y * 2.8; // afstand (m) tot de breuklijn
		float vfw = max(fwidth(ve), 1e-4);
		float mask = smoothstep(0.7, 0.8, vnoise(wpos * 0.17 + vec3(11.0))); // slechts een deel van de breuken
		float vw = mix(0.012, 0.03, vnoise(wpos * 0.6 + vec3(2.0)));
		float vein = (1.0 - smoothstep(vw, vw + vfw * 1.5, ve)) * mask;
		float glow = (1.0 - smoothstep(0.0, 1.2, ve)) * mask; // zachte schijn op de rots rond een naad
		float pulse = 0.82 + 0.18 * sin(TIME * 1.1 + hash1(vc) * 6.28);
		emit = vcol * (vein * vein_energy * 0.35 + glow * glow * 0.03) * pulse;
		col = mix(col, vcol * 0.3, vein);
		col = mix(col, light, 0.22); // kristalgesteente iets lichter, anders verdwijnt het in het donker
		rough = mix(rough, 0.08, vein);
		// Kristallen in de rots (een per cel van 2,4 m, 45%), plus kleine in de cellen ertussen.
		vec4 c = crystal(wpos + vec3(seed_s * 2.7), 2.4, 0.45, 0.34, 0.85, 71.0);
		vec4 c2 = crystal(wpos + vec3(1.1, seed_s, 0.6), 0.9, 0.3, 0.1, 0.3, 83.0);
		if (c2.z > 0.5 && (c.z < 0.5 || c2.x < c.x)) {
			c = c2;
		}
		if (c.z > 0.0 && c.x < 3.2) {
			float in_c = 1.0 - smoothstep(0.9, 1.0, c.x);
			float halo = (1.0 - smoothstep(1.0, 3.2, c.x)) * c.w;
			float facet = 0.35 + 0.65 * hash1(vec3(floor(c.y), 3.7, 1.3)); // elk zijvlak een eigen helderheid
			float edge_l = smoothstep(0.75, 0.95, c.x) * in_c; // de rand van de doorsnede: helder
			vec3 cc = mix(vcol, vec3(1.0), 0.2);
			col = mix(col, cc * (0.2 + 0.3 * facet), in_c);
			emit += cc * (in_c * (0.5 + 1.4 * facet) + edge_l * 1.5) * pulse + vcol * halo * halo * 0.1;
			rough = mix(rough, 0.04, in_c);
		}
		// Glinsters: kleine facetjes die flitsen als ze naar de lamp kijken, enkel van dichtbij.
		vec3 cgl = glint(wpos, n, normalize(CAMERA_POSITION_WORLD - wpos), 0.11, 0.012, seed_s);
		emit += mix(vcol, vec3(1.0), 0.5) * cgl.x * (0.3 + 2.5 * cgl.y) * det_k;
	}

	// 3. De korst aan het oppervlak: een eigen patroon per planeet (buiten-12), enkel in de bovenste
	// meter, op vlakke grond en van dichtbij.
	float flat_top = smoothstep(0.5, 0.85, up) * crust_k * (1.0 - 0.8 * pad_k) * (layer == 3 ? 1.0 : 0.0);
	if (flat_top > 0.0 && near > 0.0) {
		if (planet_id == 0) {
			// Roestbol: windribbels (±0,55 m) en lange stofsporen in de windrichting.
			vec2 wd = vec2(0.8, 0.6);
			float along = dot(wpos.xz, wd);
			float across = dot(wpos.xz, vec2(-wd.y, wd.x));
			float rp = (along + 1.6 * vnoise(vec3(wpos.xz * 0.3, 3.0))) * 11.4;
			float rpw = max(fwidth(rp), 1e-3);
			// Asymmetrisch: een lichte kam en een donkere luwte, zoals echte ribbels in de zon.
			float ph = fract(rp / 6.2831853);
			float crest = smoothstep(0.0, 0.7, ph) * (1.0 - smoothstep(0.7, 0.82, ph));
			float rk = clamp(2.0 / rpw, 0.0, 1.0) * flat_top * near * smoothstep(0.75, 0.95, up);
			col *= 1.0 + (crest * 2.0 - 1.0) * 0.1 * rk;
			// De ribbels kantelen de normaal (een lange flank, een steile luwte): zo lezen ze in de zon.
			float slope = ph < 0.7 ? 0.35 : -0.9;
			vec3 wd3 = normalize(vec3(wd.x, 0.0, wd.y));
			n = normalize(n - wd3 * slope * 0.26 * rk);
			float streak = vnoise(vec3(along * 0.06, across * 0.7, seed_s));
			col = mix(col, light * 1.05, smoothstep(0.62, 0.82, streak) * 0.22 * flat_top);
		} else if (planet_id == 1) {
			// Fossielwereld: grillige krijtplaten (geen veelhoeken) met een dunne donkere rand, en gruis.
			float pn = vnoise(vec3(wpos.xz * 0.45, seed_s)) * 0.7 + vnoise(vec3(wpos.xz * 1.3, seed_s + 4.0)) * 0.3;
			float pw = max(fwidth(pn), 1e-3);
			float plate = smoothstep(0.55 - pw, 0.55 + pw, pn);
			col = mix(col, light * 1.1, plate * 0.45 * flat_top);
			col = mix(col, dark, (1.0 - smoothstep(0.3, 0.36, pn)) * 0.3 * flat_top);
			float gr = vnoise(wpos * 9.0);
			col *= 1.0 + (gr - 0.5) * 0.3 * flat_top * (1.0 - smoothstep(0.02, 0.05, px));
			// Gruis: losse donkere vuursteensplinters en lichte schelpjes.
			vec4 nd = nodule(wpos * vec3(1.0, 0.0, 1.0) + vec3(seed_s, 0.0, 0.0), 0.35, 0.22, 0.12, 0.26, 91.0);
			float k = (1.0 - smoothstep(0.75, 1.0, nd.x + (vnoise(wpos * 14.0) - 0.5) * 0.5)) * nd.z * flat_top * det_k;
			col = mix(col, nd.y < 0.55 ? lin(ug_band[1]) * 1.3 : light * 1.15, k * 0.85);
		} else {
			// Kristalmaan: fijne kristalglinsters in het stof (de zeshoeken komen uit near_tint).
			vec3 gp = wpos * 7.0 + vec3(seed_s, 1.0, 2.0);
			float g = hash1(floor(gp));
			float gd = 1.0 - smoothstep(0.1, 0.18, length(fract(gp) - 0.5));
			float tw = pow(max(0.0, sin(TIME * 1.7 + g * 80.0)), 10.0);
			emit += mix(lin(ug_accent[3]), vec3(1.0), 0.4) * step(0.996, g) * gd * tw * 0.9 * flat_top * det_k;
		}
	}

	// Kromming van de vorm zelf: bolle randen vangen licht, holtes worden donkerder (DRG-trucje).
	vec3 g_n = normalize(wnrm);
	float curv = (dot(dFdx(g_n), dpx) + dot(dFdy(g_n), dpy)) / max(dot(dpx, dpx) + dot(dpy, dpy), 1e-6);
	curv *= 1.0 - aa; // per 2×2 pixels: van ver enkel ruis
	col = mix(col, light * 1.12, smoothstep(0.5, 2.2, curv) * 0.35 * near);
	col *= 1.0 - smoothstep(0.5, 2.2, -curv) * 0.3;

	// Verse snede: donkerder, verzadigder (vochtig), wat glans, holtes dieper, en een lichte rand
	// waar het oude oppervlak afbrak.
	float fresh = 0.0;
	float flip = 0.0;
	for (int i = 0; i < fresh_count; i++) {
		vec4 f = fresh_ops[i];
		float d = distance(wpos, f.xyz);
		fresh = max(fresh, (1.0 - smoothstep(f.w * 0.9, f.w * 1.2 + 0.12, d)) * fresh_w[i]);
		// Enkel bij kleine sneden (houweel, boor): bij een grote (de Mol) werd de rand een cirkel op de wand.
		flip = max(flip, (1.0 - smoothstep(0.0, 0.07, abs(d - f.w * 1.2 - 0.16))) * fresh_w[i] * (1.0 - smoothstep(0.7, 1.3, f.w)));
	}
	if (fresh > 0.0 || flip > 0.0) {
		float lum = dot(col, vec3(0.3, 0.59, 0.11));
		vec3 wet = mix(vec3(lum), col, 1.3) * 0.62;
		col = mix(col, wet, fresh * 0.85);
		col *= 1.0 - smoothstep(0.3, 1.6, -curv) * 0.3 * fresh;
		rough = mix(rough, 0.5, fresh);
		flip *= (1.0 - fresh) * smoothstep(0.35, 0.65, vnoise(wpos * 7.0)) * near;
		col = mix(col, light * 1.2, flip * 0.45);
	}

	// 4. Stof op vloeren, donkerder en iets koeler onder overhangen (niet op een verse snede).
	float dn = dust_k > 0.0 ? mix(0.5, vnoise(wpos * 0.8 + vec3(4.0)), dust_k) : 0.5;
	float dust = smoothstep(0.5, 0.88, up) * (0.5 + 0.5 * dn) * (1.0 - 0.4 * under_k) * (1.0 - fresh);
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
	col *= mix(vec3(1.0), vec3(0.62, 0.68, 0.82), ceil_k);

	// Naad op de laaggrens: een donkere lijn met een iets donkerdere contactzone.
	float db = min(min(abs(y - top_kristal), abs(y - top_graniet)), abs(y - top_zandsteen));
	float sfw = max(fwidth(y), 1e-4);
	float seam = 1.0 - smoothstep(0.06, 0.06 + sfw * 1.5, db);
	float contact = 1.0 - smoothstep(0.1, 0.7, db);
	col *= (1.0 - seam * 0.75) * (1.0 - contact * 0.2);
	// Lichte lip net boven de naad: de grens leest als een richel.
	float lip = smoothstep(0.06, 0.1, db) * (1.0 - smoothstep(0.12, 0.22, db)) * near;
	col = mix(col, light * 1.15, lip * 0.35);

	// 5. Erts vlak achter de wand: een verkleuring in de kleur van verweerd erts (koper groen,
	// ijzer roestzwart), en grote glinsters in de kleur van het erts die in de lamp oplichten. De
	// glinsters worden nooit kleiner dan een paar pixels, zodat je een ader ook van 15-20 m ziet.
	float ore_k = 0.0;
	vec3 ore_c = vec3(0.0);
	vec4 ore_s = vec4(0.0);
	for (int i = 0; i < ore_count; i++) {
		float k = 1.0 - smoothstep(0.5, 2.2, distance(wpos, ore_points[i].xyz));
		if (k > ore_k) {
			ore_k = k;
			int kind = int(ore_points[i].w);
			ore_c = ore_colors[kind].rgb;
			ore_s = ore_stain[kind];
		}
	}
	if (ore_k > 0.0) {
		// Verkleuring in aders (uitgerekte ruis), dicht bij de cluster het sterkst: geen bol.
		float sn = vnoise(wpos * vec3(1.6, 5.0, 1.6) + vec3(seed_s)) * 0.7 + vnoise(wpos * 3.3) * 0.3;
		float sk = smoothstep(0.35, 0.85, ore_k) * smoothstep(0.42, 0.62, sn + ore_k * 0.25);
		col = mix(col, ore_s.rgb, sk * ore_s.a);
		// Glinsters: harde facetjes met een sterretje, die oplichten als ze naar de lamp kijken (de lamp
		// zit op je hoofd). Nooit kleiner dan een paar pixels: een ader zie je ook van 15-20 m.
		vec3 view = normalize(CAMERA_POSITION_WORLD - wpos);
		float gs = max(0.14, px * 7.0);
		vec3 gl = glint(wpos, n, view, gs, 0.14 * ore_k, seed_s * 3.1);
		vec3 gcol = mix(ore_c, vec3(1.0), 0.35);
		col = mix(col, gcol * 0.8, gl.x * 0.9);
		emit += gcol * gl.x * (0.25 + 0.7 * ore_k + 3.0 * gl.y) + ore_c * sk * 0.025;
		rough = mix(rough, 0.15, gl.x);
	}

	// Vlekken in de bovenste laag (binnen en buiten het speelgebied, zodat de rand wegvalt).
	if (layer == 3 && (patch_dark.a > 0.0 || patch_light.a > 0.0)) {
		float top_k = far_terrain ? 1.0 : smoothstep(surface_world_y - 9.0, surface_world_y - 3.0, wpos.y) * smoothstep(0.2, 0.6, n.y) * (1.0 - under_k);
		vec3 pp = vec3(wpos.x / patch_scale, 0.0, wpos.z / patch_scale);
		float pm = vnoise(pp) * 0.7 + vnoise(pp * 2.7 + vec3(4.1, 0.0, 9.3)) * 0.3;
		col *= mix(vec3(1.0), patch_dark.rgb, smoothstep(0.58, 0.72, pm) * patch_dark.a * top_k);
		col *= mix(vec3(1.0), patch_light.rgb, (1.0 - smoothstep(0.3, 0.44, pm)) * patch_light.a * top_k);
	}

	// Het speelgebied: dezelfde tint als het verre landschap errond (duinen, bedding, korst, stralen),
	// enkel in de bovenste meters (niet in de tunnels).
	if (near_tint_on && !far_terrain && layer == 3) {
		float nt_k = smoothstep(surface_world_y - 9.0, surface_world_y - 3.0, wpos.y) * smoothstep(0.0, 0.35, n.y) * (1.0 - under_k);
		if (nt_k > 0.0) {
			vec2 nt_uv = ((wpos.xz - near_tint_rect.xy) / near_tint_rect.z + 0.5) / near_tint_rect.w;
			vec4 nt = texture(near_tint, nt_uv);
			col *= mix(vec3(1.0), nt.rgb * 2.0, nt_k);
			if (nt.a > 0.01) {
				// Zeshoeken (platte bovenkant), kolommen om 1,5 R, om de andere een halve rij verschoven.
				float R = crust_hex.x;
				float dx = 1.5 * R;
				float dz = 1.7320508 * R;
				float i0 = floor(wpos.x / dx);
				float best = 1e9;
				for (int k = 0; k < 2; k++) {
					float ci = i0 + float(k);
					float off = mod(ci, 2.0) * 0.5;
					float cj = floor(wpos.z / dz - off + 0.5);
					vec2 q = abs(wpos.xz - vec2(ci * dx, (cj + off) * dz));
					best = min(best, max(q.y, q.x * 0.8660254 + q.y * 0.5));
				}
				float apo = 0.8660254 * R;
				float seam = smoothstep(apo - crust_hex.y - 0.25, apo - crust_hex.y * 0.5, best) * (1.0 - smoothstep(0.6, 2.5, px));
				col *= mix(1.0, 0.55, seam * nt.a * nt_k);
			}
		}
	}

	// Verre landschap: de kleur van de landvorm (stof op de kraterbodem, donkere duinen, de put) en
	// lagen in de wanden, op hoogte (zoals gelaagd gesteente), licht golvend.
	if (far_terrain) {
		col *= vtint.rgb * 2.0; // gehalveerd opgeslagen (8-bit): 1 = neutraal, tot 2 = lichter
		if (vtint.a > 0.01) {
			// Dikke, onregelmatige lagen (±18 m), enkel op de steile delen: op richels ligt stof.
			float sb = wpos.y / strata_scale + 0.45 * vnoise(vec3(wpos.x * 0.004, 0.0, wpos.z * 0.004));
			float band = fract(sb + 0.25 * vnoise(vec3(0.0, wpos.y * 0.09, 0.0)));
			vec3 sc = band < strata_cuts.x ? strata_light : (band < strata_cuts.y ? strata_mid : strata_dark);
			if (strata_key.z > 0.0) {
				float ky = abs(wpos.y + 1.5 * vnoise(vec3(wpos.x * 0.01, 3.0, wpos.z * 0.01)) - strata_key.x);
				sc = mix(sc, strata_key_color, (1.0 - smoothstep(strata_key.y * 0.5, strata_key.y * 0.5 + 0.8, ky)) * strata_key.z);
			}
			float steep = 1.0 - smoothstep(strata_steep.x, strata_steep.y, n.y);
			col = mix(col, lin(sc) * 0.92, vtint.a * steep * strata_strength);
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
		// Barsten: dun en onregelmatig (de breedte wisselt, een deel van de randen is dicht), met een
		// lichte stofrand ernaast. Geen zwart honingraatnet (glas-in-lood) op een licht plafond.
		float edge_d = (d2 - d1) / 1.3; // m
		float cw = mix(0.0015, 0.012, smoothstep(0.4, 0.85, vnoise(wpos * 1.7 + vec3(3.0))));
		float open_k = smoothstep(0.45, 0.62, vnoise(wpos * 0.9 + vec3(seed_s, 8.0, 1.0)));
		float cfw = max(fwidth(edge_d), 1e-4);
		float zcrack = (1.0 - smoothstep(cw, cw + cfw, edge_d)) * open_k;
		float zdust = (1.0 - smoothstep(cw, cw + 0.07, edge_d)) * (1.0 - zcrack) * open_k;
		col = mix(col, col * 1.2 + vec3(0.05, 0.045, 0.035), zone_k * 0.3); // fijn stof
		col = mix(col, light * 1.2, zdust * zone_k * 0.55);
		col = mix(col, col * 0.35, zcrack * zone_k);
	}

	// Magma eronder: de rots warmt op naar donkerrood, vooral vlakken die naar beneden kijken, met
	// een felle rand vlak boven het magma die oplaait. Zo gloeit de plek waar rots en magma elkaar raken.
	float above_m = wpos.y - magma_height;
	if (above_m < magma_heat_m && above_m > -3.0) {
		float heat = 1.0 - smoothstep(0.0, magma_heat_m, max(above_m, 0.0));
		float down = clamp(0.5 - 0.5 * n.y, 0.0, 1.0);
		col = mix(col, col * vec3(0.5, 0.22, 0.15), heat * 0.65);
		emit += vec3(1.0, 0.22, 0.03) * heat * heat * (0.06 + 0.3 * down);
		float flare = 0.75 + 0.25 * sin(TIME * 2.3 + wpos.x * 0.7 + wpos.z * 0.5) * vnoise(vec3(wpos.xz * 0.8, TIME * 0.6));
		float rim = 1.0 - smoothstep(0.0, 0.25 + 0.35 * flare, above_m);
		emit += vec3(1.0, 0.4, 0.06) * rim * rim * 2.6 * flare;
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = rough;
	// Stof en rots weerkaatsen weinig: zonder dit spiegelen vlakke kratervloeren onder een scherende
	// hoek de lichte hemel (witte "meren").
	SPECULAR = 0.18 + 0.25 * (1.0 - rough) * under_k;
	EMISSION = emit;
	AO = (1.0 - contact * 0.3) * (1.0 - smoothstep(0.5, 2.2, -curv) * 0.35);
	AO_LIGHT_AFFECT = 0.5;
}
