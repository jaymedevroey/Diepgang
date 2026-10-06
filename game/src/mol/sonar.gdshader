shader_type canvas_item;
render_mode unshaded;

// Sonarbeeld (SonarScreen): ronde scoop met kop boven, draaiende veeg met naloop, blips met een
// gloed, ▲/▼ voor boven/onder de Mol, haakjes rond het doel, en rechts een dieptestrook.
// De rand van de scoop is het bereik van een PING; de veeg (stil luisteren) komt maar tot de
// binnenste cirkel (`quiet`). Daarbuiten blijft het donker, tot een PING-ring uitloopt.
// Groen fosfor zoals een oude beeldbuis. Pixels = millimeters op het scherm in de Mol.

uniform vec2 size = vec2(860.0, 560.0);
uniform vec2 scope_c = vec2(260.0, 280.0);
uniform float scope_r = 245.0;
uniform vec4 strip = vec4(548.0, 60.0, 570.0, 500.0); // x0, y0, x1, y1
uniform float strip_range = 20.0; // meter boven en onder
uniform float sweep = 0.0; // radialen, met de klok mee, 0 = vooruit (boven)
uniform float noise = 0.0; // 0..1
uniform float quiet = 0.5; // bereik van de veeg, als deel van de straal
uniform float ping_r = -1.0; // straal van de PING-ring (deel van de straal), of -1
uniform int count = 0;
uniform vec4 blips[24]; // xy: -1..1 (x rechts, y vooruit), z: helderheid, w: grootte 0..2 (+3 = scherp, van een PING)
uniform float heights[24]; // meter t.o.v. de Mol (+ = boven)
uniform int target = -1;
// De Graafworm ("the Gulper"): xy in de scoop (-1..1), z = sterkte (0 = niet te zien), w = hoogte t.o.v.
// de Mol (m). In zijn eigen kleur (rood-oranje: gevaar, niet het groen van een vondst; ui2-05), en
// `threat_hot` = 1 als hij aanvalt (sneller kloppen).
uniform vec4 threat = vec4(0.0);
uniform float threat_hot = 0.0;
uniform vec3 threat_col : source_color = vec3(1.0, 0.3, 0.1);
uniform float level = 2.5; // binnen ±level meter: "gelijk", geen pijltje
uniform vec3 phosphor : source_color = vec3(0.42, 1.0, 0.52);

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float line_aa(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.0, d);
}

// Driehoekje met de punt naar boven (dir = 1) of beneden (dir = -1), halve breedte s.
float tri(vec2 q, float s, float dir) {
	q.y *= dir; // punt bij q.y = -s (boven op het scherm), omgekeerd voor dir = -1
	float t = (q.y + s) / (1.8 * s); // 0 aan de punt, 1 aan de basis
	float inside = step(0.0, t) * step(t, 1.0);
	return inside * (1.0 - smoothstep(t * s - 0.8, t * s + 0.8, abs(q.x)));
}

vec2 blip_pos(int i) {
	return scope_c + vec2(blips[i].x, -blips[i].y) * scope_r;
}

float blip_size(int i) {
	return 7.0 + 4.5 * mod(blips[i].w, 3.0);
}

bool blip_sharp(int i) {
	return blips[i].w > 2.5;
}

void fragment() {
	vec2 p = UV * size;
	float g = 0.0; // fosforhelderheid
	float w = 0.0; // de worm (eigen kleur)

	// --- Scoop ---------------------------------------------------------------------------------
	vec2 d = p - scope_c;
	float r = length(d);
	float in_scope = 1.0 - smoothstep(scope_r - 1.0, scope_r + 1.0, r);
	if (r < scope_r + 6.0) {
		float a = mod(atan(d.x, -d.y), TAU); // met de klok mee vanaf boven
		float qr = quiet * scope_r;
		float in_quiet = 1.0 - smoothstep(qr - 1.0, qr + 1.0, r);
		g += (0.018 + 0.03 * in_quiet) * (1.0 - 0.6 * r / scope_r) * in_scope;
		// Ringen om de kwart; de grens van de veeg feller, buiten die grens gestippeld.
		for (int i = 1; i <= 3; i++) {
			float ri = scope_r * float(i) / 4.0;
			float dots = ri > qr + 2.0 ? step(0.5, fract(a * ri / 14.0)) : 1.0;
			g += 0.16 * line_aa(abs(r - ri), 1.4) * in_scope * dots;
		}
		g += 0.3 * line_aa(abs(r - qr), 2.0) * in_scope;
		g += 0.55 * line_aa(abs(r - scope_r + 1.5), 2.0);
		g += 0.09 * (line_aa(abs(d.x), 1.2) + line_aa(abs(d.y), 1.2)) * in_scope;
		// Streepjes langs de rand: om de 10°, om de 30° langer.
		float step10 = abs(mod(a + PI / 36.0, PI / 18.0) - PI / 36.0) * r;
		float step30 = abs(mod(a + PI / 12.0, PI / 6.0) - PI / 12.0) * r;
		g += 0.35 * line_aa(step10, 1.3) * step(scope_r - 9.0, r) * in_scope;
		g += 0.45 * line_aa(step30, 2.0) * step(scope_r - 18.0, r) * in_scope;
		// Veeg: felle lijn met een naloop erachter, tot de grens van het stille bereik.
		float behind = mod(sweep - a, TAU);
		g += 0.26 * exp(-behind * 2.4) * in_quiet;
		vec2 dir = vec2(sin(sweep), -cos(sweep));
		float along = dot(d, dir);
		float perp = abs(d.x * dir.y - d.y * dir.x);
		g += 0.75 * line_aa(perp, 2.0) * step(0.0, along) * in_quiet;
		// PING: een felle ring die uitloopt, met een gloed erachter die uitdooft naar de rand.
		if (ping_r >= 0.0) {
			float pr = ping_r * scope_r;
			float fade = 1.0 - 0.5 * ping_r;
			g += 1.1 * fade * line_aa(abs(r - pr), 3.0) * in_scope;
			g += 0.3 * fade * exp(-max(pr - r, 0.0) / 28.0) * step(r, pr) * in_scope;
		}
		// Ruis van het eigen lawaai: korrels en vlekjes die meedraaien met de tijd.
		float speck = rnd(floor(p / 3.0) + floor(TIME * 14.0));
		g += step(1.0 - noise * 0.022, speck) * 0.6 * in_scope;
		g += (rnd(p + fract(TIME * 7.0)) - 0.5) * (0.03 + 0.06 * noise) * in_scope;
		// De Mol in het midden: een pijltje naar voren.
		g += 0.95 * tri(d + vec2(0.0, 1.0), 8.0, 1.0);
	}
	// Blips.
	for (int i = 0; i < count; i++) {
		vec2 q = p - blip_pos(i);
		float s = blip_size(i);
		float b = blips[i].z;
		float dd = dot(q, q);
		if (blip_sharp(i)) {
			// Scherp (PING): een kleine harde kern met een ringetje, geen wolk.
			float ss = s * 0.6;
			g += b * (1.5 * (1.0 - smoothstep(ss - 1.0, ss + 1.0, sqrt(dd))) + 0.7 * line_aa(abs(sqrt(dd) - ss - 6.0), 1.6));
		} else {
			g += b * (1.3 * exp(-dd / (s * s)) + 0.4 * exp(-dd / (9.0 * s * s)));
		}
		// Boven of onder de Mol.
		float h = heights[i];
		if (h > level) {
			g += max(b, 0.25) * 1.2 * tri(q + vec2(0.0, s + 13.0), 8.0, 1.0);
		} else if (h < -level) {
			g += max(b, 0.25) * 1.2 * tri(q - vec2(0.0, s + 13.0), 8.0, -1.0);
		}
		if (i == target) {
			// Haakjes rond het doel (vier bogen op de diagonalen), licht pulserend.
			float rr = s + 17.0 + sin(TIME * 4.0) * 1.5;
			float ang = atan(q.y, q.x);
			float arc = step(0.55, abs(sin(2.0 * ang)));
			g += 0.9 * line_aa(abs(length(q) - rr), 2.2) * arc * max(b, 0.35);
		}
	}
	// De worm: een grote rode vlek met een rafelige rand die klopt (iets groots), een krans tanden
	// die naar binnen wijzen (een muil: zijn eigen teken), en ringen die uitlopen.
	if (threat.z > 0.0) {
		vec2 tc = scope_c + vec2(threat.x, -threat.y) * scope_r;
		vec2 q = p - tc;
		float dq = length(q);
		float ang = atan(q.y, q.x);
		float hz = mix(5.5, 11.0, threat_hot);
		float beat = 0.5 + 0.5 * sin(TIME * hz);
		float rad = 26.0 + 10.0 * beat + 5.0 * sin(ang * 5.0 + TIME * 3.0) + 3.0 * sin(ang * 9.0 - TIME * 4.0);
		float fill = 1.0 - smoothstep(rad - 6.0, rad + 2.0, dq);
		// De muil: een donkere kern met acht tanden die naar het midden wijzen.
		float teeth = smoothstep(0.55, 0.95, abs(sin(ang * 4.0 + TIME * 0.8))) * smoothstep(rad * 0.25, rad * 0.75, dq);
		float hole = 1.0 - smoothstep(rad * 0.3, rad * 0.55, dq);
		w += threat.z * 1.6 * fill * (0.55 + 0.45 * beat) * (1.0 - 0.8 * hole) * (1.0 - 0.55 * teeth);
		w += threat.z * 0.6 * exp(-max(dq - rad, 0.0) / 18.0);
		for (int k = 0; k < 2; k++) {
			float rr = mod(TIME * 38.0 + float(k) * 40.0, 80.0) + rad;
			w += threat.z * 0.7 * (1.0 - (rr - rad) / 80.0) * line_aa(abs(dq - rr), 2.5);
		}
		if (threat.w > level) {
			w += threat.z * 1.2 * tri(q + vec2(0.0, rad + 16.0), 11.0, 1.0);
		} else if (threat.w < -level) {
			w += threat.z * 1.2 * tri(q - vec2(0.0, rad + 16.0), 11.0, -1.0);
		}
	}
	g *= max(in_scope, step(scope_r + 6.0, r)); // blips buiten de scoop vallen weg
	w *= max(in_scope, step(scope_r + 6.0, r));

	// --- Dieptestrook ------------------------------------------------------------------------
	if (p.x > strip.x - 6.0 && p.x < strip.z + 6.0 && p.y > strip.y - 6.0 && p.y < strip.w + 6.0) {
		float in_strip = step(strip.x, p.x) * step(p.x, strip.z) * step(strip.y, p.y) * step(p.y, strip.w);
		float yc = (strip.y + strip.w) * 0.5;
		float px_m = (strip.w - strip.y) * 0.5 / strip_range;
		g += 0.05 * in_strip;
		// Rand.
		g += 0.4 * (line_aa(abs(p.x - strip.x), 1.5) + line_aa(abs(p.x - strip.z), 1.5)) * step(strip.y, p.y) * step(p.y, strip.w);
		// Streepjes om de 5 m (om de 10 m langer), de Mol op de middellijn.
		float m = (yc - p.y) / px_m;
		float t5 = abs(mod(m + 2.5, 5.0) - 2.5) * px_m;
		float t10 = abs(mod(m + 5.0, 10.0) - 5.0) * px_m;
		g += 0.35 * line_aa(t5, 1.3) * step(strip.z - 7.0, p.x) * in_strip;
		g += 0.5 * line_aa(t10, 1.6) * step(strip.z - 13.0, p.x) * in_strip;
		g += 0.9 * line_aa(abs(p.y - yc), 2.5) * in_strip;
		for (int i = 0; i < count; i++) {
			float h = clamp(heights[i], -strip_range * 0.97, strip_range * 0.97);
			float y = yc - h * px_m;
			float lw = (i == target) ? 3.5 : 2.2;
			g += blips[i].z * 1.1 * line_aa(abs(p.y - y), lw) * in_strip;
		}
		// De worm in de dieptestrook: een dikke rode streep.
		if (threat.z > 0.0) {
			float th = clamp(threat.w, -strip_range * 0.97, strip_range * 0.97);
			w += threat.z * 1.4 * line_aa(abs(p.y - (yc - th * px_m)), 5.0) * in_strip;
		}
	}

	vec3 col = vec3(0.01, 0.028, 0.016) + phosphor * g;
	// Overbelicht naar wit, zoals fosfor.
	col += vec3(max(g - 0.9, 0.0) * 0.5);
	// De worm over het groen: rood-oranje, dat het groen eronder wegdrukt.
	col = mix(col, threat_col * (0.35 + w) + vec3(max(w - 1.1, 0.0) * 0.3, max(w - 1.1, 0.0) * 0.15, 0.0), clamp(w * 1.4, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
