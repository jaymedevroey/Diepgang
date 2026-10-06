shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// De romp van De Ekster van buiten (release-audit buiten-10, ronde 2: "de rompplaten zijn van dichtbij
// vlak"). Het machinemateriaal (src/mol/machine.gdshader: verf, kale randen, vuil in holtes) plus wat
// een schip dat al jaren vliegt op zijn huid heeft (stijlgids: "geklonken platen, krassen en vuil
// langs de randen"; docs/research/nostromo-stijl.md):
//  - kleinere platen binnen de grote panelen, in verspringende rijen, met een donkere naad en een
//    lichte bovenrand (de plaat vangt licht), elk een eigen tint (vervangen platen, oude verf);
//  - klinknagels langs de naden (enkel van dichtbij);
//  - strepen die onder elke naad naar beneden lopen (roest en vuil dat uitzakt);
//  - roet rond de motoren en de hefstralen, krassen in de verf.
// Alles in de ruimte van het schip (ship_inv: wereld -> schip, gezet door EksterExterior), zodat
// "onder", "achter" en de plaatrijen voor elk onderdeel hetzelfde betekenen. Het silhouet blijft.
// Vertexkleur uit Blender (kit.bake_wear): R = bolle rand, G = holte, B = willekeur per onderdeel.

uniform vec3 albedo : source_color = vec3(0.42, 0.424, 0.408);
uniform float metallic = 0.45;
uniform float roughness = 0.6;
uniform float edge_wear = 0.5;
uniform vec3 bare_metal : source_color = vec3(0.66, 0.66, 0.64);
uniform float grime = 0.7;
uniform vec3 grime_color : source_color = vec3(0.13, 0.11, 0.09);
uniform vec3 rust_color : source_color = vec3(0.36, 0.2, 0.12);
uniform mat4 ship_inv = mat4(1.0);
uniform vec2 plate = vec2(3.6, 1.8);  // plaat (m): langs, dwars (een plaat is 1 tot 4 lengtes)
uniform float seam_w = 0.03;           // breedte van een naad (m)
uniform float plating = 1.0;           // 0 = geen platen (losse onderdelen)
uniform float panel_tint = 0.06;       // tint per plaat
uniform float streaks = 0.8;           // strepen onder de naden
uniform float soot = 0.8;              // roet bij de motoren
uniform float scratches = 0.6;         // krassen in de verf
uniform vec2 engine_z = vec2(58.0, 86.0); // van waar tot waar het motorblok loopt (z, m)

varying vec3 spos;
varying vec3 snrm;
varying vec4 wear;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

float vnoise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	spos = (ship_inv * vec4(w, 1.0)).xyz;
	snrm = normalize((ship_inv * vec4(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz), 0.0)).xyz);
	wear = COLOR;
}

void fragment() {
	vec3 n = normalize(snrm);
	vec3 an = abs(n);
	// Pixelgrootte (m): fijne dingen (naden, nagels, krassen) vervagen voor ze gaan zinderen.
	float px = length(fwidth(spos));
	// Plaatvlak: zijkanten (u = langs het schip, v = omhoog), boven en onder (u = langs, v = dwars),
	// voor- en achterkant (u = dwars, v = omhoog).
	vec2 uv = an.x >= an.y && an.x >= an.z ? spos.zy : (an.y >= an.z ? spos.zx : spos.xy);
	bool side = an.y < an.x || an.y < an.z;
	// Rijen platen; per rij een eigen verschuiving en niet elke staande naad (platen van 1 tot 3
	// lengtes): geen metselwerk, maar platen zoals ze vervangen en bijgelast zijn.
	float row = floor(uv.y / plate.y);
	float u = uv.x / plate.x + hash2(vec2(row, 3.7)) * 7.0;
	float k0 = floor(u);
	float fu = fract(u);
	bool left_on = hash2(vec2(k0, row)) > 0.55;
	bool right_on = hash2(vec2(k0 + 1.0, row)) > 0.55;
	vec2 cell = vec2(left_on ? k0 : k0 - 1.0, row);
	float fv = fract(uv.y / plate.y);
	float du = min(left_on ? fu : 9.0, right_on ? 1.0 - fu : 9.0) * plate.x; // m tot de naad links/rechts
	float dv = min(fv, 1.0 - fv) * plate.y; // m tot de naad onder/boven
	float d_top = (1.0 - fv) * plate.y;     // m tot de naad erboven
	float fine = 1.0 - smoothstep(0.03, 0.12, px);
	float mid = 1.0 - smoothstep(0.25, 1.2, px);
	float pl = plating;

	vec3 base = albedo;
	// Kleine variatie per onderdeel, grote vlekken en een eigen tint per plaat (vervangen platen,
	// oude verf, een paar in primer).
	base *= 1.0 + (wear.b - 0.5) * 0.06;
	float blotch = vnoise(spos * 0.11) * 0.6 + vnoise(spos * 0.37) * 0.4;
	base *= 0.95 + 0.08 * blotch;
	float hc = hash2(cell + vec2(17.0 * float(an.y >= an.x && an.y >= an.z), 5.0 * float(an.z > an.x && an.z > an.y)));
	base *= 1.0 + (hc - 0.5) * 2.0 * panel_tint * pl * mid;
	float odd = step(0.95, hc) * pl * mid;
	base = mix(base, base * vec3(1.1, 0.94, 0.84), odd * 0.6); // een plaat in primer (roestbruin)
	base = mix(base, base * vec3(0.86, 0.9, 0.94), step(hc, 0.06) * pl * mid * 0.8); // een nieuwere, koelere plaat

	// Randslijtage: bolle randen (vertexkleur en kromming per pixel), met ruis.
	float chip = smoothstep(0.55, 0.8, vnoise(spos * 3.0) * 0.55 + vnoise(spos * 9.0) * 0.45);
	float curv = length(fwidth(NORMAL)) / max(length(fwidth(VERTEX)), 1e-4);
	float rim = smoothstep(3.0, 12.0, curv) * (1.0 - smoothstep(70.0, 140.0, curv)) * smoothstep(0.35, 0.8, wear.r);
	float edge = rim * mix(0.45, 1.0, chip) * edge_wear;
	// Afgesleten verf langs de bovenrand van een plaat (waar laarzen en kabels schuren).
	edge = max(edge, (1.0 - smoothstep(0.0, 0.08, d_top)) * chip * 0.6 * edge_wear * pl * fine);
	vec3 col = mix(base, bare_metal, edge);
	float met = mix(metallic, 0.85, edge);
	float rough = mix(roughness, 0.32, edge);

	// Naden: een donkere lijn met een lichte rand erboven (de plaat eronder steekt uit en vangt licht).
	float sw = seam_w * 0.5;
	float aa = max(px, 1e-4);
	float seam = (1.0 - smoothstep(sw, sw + aa * 1.5, min(du, dv))) * pl * mid;
	float lip = (1.0 - smoothstep(sw, sw + 0.05 + aa, d_top)) * smoothstep(sw * 0.5, sw + aa, d_top) * pl * fine;
	col = mix(col, col * 0.6, seam * 0.75);
	col = mix(col, col * 1.22 + vec3(0.02), lip * 0.6 * float(side));
	rough = mix(rough, 0.85, seam);

	// Klinknagels langs de liggende naden: om de 0,32 m, 9 cm van de naad, een lichte kop met een donkere rand.
	if (fine > 0.0 && pl > 0.0) {
		float along_h = uv.x / 0.32;
		vec2 rq = vec2((fract(along_h) - 0.5) * 0.32, dv - 0.09);
		float rd = length(rq);
		float head = 1.0 - smoothstep(0.018, 0.018 + aa, rd);
		float ring = (1.0 - smoothstep(0.03, 0.03 + aa, rd)) * (1.0 - head);
		col = mix(col, col * 0.55, ring * fine * 0.7);
		col = mix(col, mix(col, bare_metal, 0.35) * 1.15, head * fine);
		met = mix(met, 0.7, head * fine);
	}

	// Strepen: roest en vuil zakken onder elke naad uit en lopen naar beneden (zijkanten), plus lange
	// strepen over meerdere platen.
	if (side) {
		float drip = vnoise2(vec2(uv.x * 3.1, row * 7.3)) * 0.7 + vnoise2(vec2(uv.x * 11.0, row * 3.1)) * 0.3;
		float under = exp(-d_top / mix(0.2, 0.7, hash2(cell + 3.1))) * smoothstep(0.62, 0.85, drip) * pl;
		float longs = smoothstep(0.68, 0.9, vnoise2(vec2(uv.x * 0.9, spos.y * 0.035)) * 0.7 + vnoise2(vec2(uv.x * 4.0, spos.y * 0.08)) * 0.3);
		float st = clamp(under * 0.7 + longs * 0.3, 0.0, 1.0) * streaks * mid;
		col = mix(col, mix(grime_color, rust_color, hc), st * 0.35);
		rough = mix(rough, 0.8, st * 0.5);
	}

	// Roet: rond het motorblok (achteraan, meer op de achterkant) en onder de buik bij de hefstralen.
	float eng = smoothstep(engine_z.x, engine_z.y, spos.z) * (0.55 + 0.45 * smoothstep(0.3, 0.9, n.z));
	float belly = smoothstep(-0.3, -0.9, n.y) * 0.45;
	// Golf 3 (buiten-10: "ronde, wazige vlekken, waterkringen"): roet in strepen langs de stroming (de
	// lengte van het schip), met een scherpere rand, geen ronde vlekken.
	float sn = vnoise(vec3(spos.x * 1.1, spos.y * 1.1, spos.z * 0.045)) * 0.65 + vnoise(vec3(spos.x * 3.2, spos.y * 3.2, spos.z * 0.12)) * 0.35;
	float sootk = clamp((eng + belly) * smoothstep(0.42, 0.62, sn), 0.0, 1.0) * soot;
	col = mix(col, grime_color * 0.55, sootk * 0.6);
	rough = mix(rough, 0.9, sootk * 0.5);
	met = mix(met, 0.1, sootk * 0.5);

	// Krassen: dunne lichte lijnen in willekeurige richtingen, in sommige platen (enkel van dichtbij).
	if (fine > 0.0 && scratches > 0.0) {
		float ha = hash2(cell * 1.7 + 9.0);
		float ang = ha * 6.2831;
		vec2 dir = vec2(cos(ang), sin(ang));
		float sl = dot(uv, dir) * 7.0 + vnoise2(uv * 1.5) * 2.0;
		float lw = max(fwidth(sl), 1e-3);
		float line = 1.0 - smoothstep(0.04, 0.04 + lw * 1.5, abs(fract(sl) - 0.5) * 2.0 - 0.92);
		float sm = step(0.55, ha) * smoothstep(0.55, 0.75, vnoise2(uv * 0.9 + 3.0));
		float scr = line * sm * fine * scratches;
		col = mix(col, bare_metal * 1.05, scr * 0.5);
		met = mix(met, 0.8, scr * 0.5);
		rough = mix(rough, 0.35, scr * 0.5);
	}

	// Vuil in holtes (vertexkleur) en wat meer onderaan het schip.
	float low = smoothstep(-6.0, -14.0, spos.y) * 0.3;
	float dirt = clamp(smoothstep(0.3, 0.9, wear.g) + low * smoothstep(0.45, 0.75, vnoise(spos * 0.2)), 0.0, 1.0) * grime;
	col = mix(col, grime_color, dirt * 0.45);
	rough = mix(rough, 0.92, dirt * 0.6);

	ALBEDO = col;
	METALLIC = met;
	ROUGHNESS = rough;
}
