shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Bot (golf 3, binnen2-08; stijlgids: "botten ivoor met okervlekken"): een vers opgegraven bot, geen
// nieuw plastic. Per pixel in objectruimte (de vertexkleur alleen was te grof op grote, lage-poly
// stukken: dan bleef het egaal ivoor):
//   - okervlekken: grote, grillige vlekken van ijzeroxide uit de grond (twee schalen ruis);
//   - donkere uiteinden en holtes: de gewrichten en kuilen zijn bruin verkleurd (vertexkleur G uit
//     kit.bake_wear, plus de afstand tot het midden van het stuk);
//   - verweerde ruwheid: fijne putjes en haarscheurtjes, en de bolle randen lichter (afgesleten);
//   - `flash` voor het moment bij het vrijkomen (FindItem), zoals de machine-shader.

uniform vec3 ivory : source_color = vec3(0.86, 0.8, 0.66);
uniform vec3 ochre : source_color = vec3(0.62, 0.42, 0.2);
uniform vec3 umber : source_color = vec3(0.3, 0.2, 0.12);
uniform float stain = 0.75;      // hoeveel okervlekken
uniform float detail_scale = 7.0; // >1 voor kleine stukken (fijnere vlekken)
// Lange stukken (dijbeen, rib, slagtand): de uiteinden langs de lange as zijn donkerder.
// half_size = halve maat (objectruimte), center = midden, long_axis = 1 op de lange as (0 = niet).
uniform vec3 half_size = vec3(1.0);
uniform vec3 center = vec3(0.0);
uniform vec3 long_axis = vec3(0.0);
uniform bool dark = false;      // BoneDark: holtes, gaten, het zenuwkanaal
uniform float flash = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.9, 0.7);

varying vec3 opos;
varying vec3 lpos;
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
	lpos = VERTEX;
	opos = VERTEX * detail_scale;
	wear = COLOR;
}

void fragment() {
	if (dark) {
		ALBEDO = umber * (0.8 + 0.3 * vnoise(opos * 3.0));
		ROUGHNESS = 0.9;
		EMISSION = flash_color * flash;
	} else {
		// Grote okervlekken (grillig, met een zachte rand) en een tweede, fijnere laag.
		float n1 = vnoise(opos * 0.55 + vec3(3.1)) * 0.65 + vnoise(opos * 1.4 + vec3(7.7)) * 0.35;
		float n2 = vnoise(opos * 2.6 + vec3(11.0));
		float big = smoothstep(0.48, 0.66, n1) * stain;
		float small = smoothstep(0.62, 0.75, n2) * stain * 0.6;
		vec3 col = ivory * (0.92 + 0.12 * vnoise(opos * 5.0));
		col = mix(col, ochre, clamp(big * 0.75 + small * 0.45, 0.0, 0.85));
		// Holtes en uiteinden: bruin (de grond zit erin), de gewrichtskoppen het donkerst.
		float cav = smoothstep(0.25, 0.85, wear.g);
		float ends = 0.0;
		if (dot(long_axis, long_axis) > 0.0) {
			vec3 q = abs(lpos - center) / max(half_size, vec3(1e-3));
			ends = smoothstep(0.7, 1.0, dot(q, long_axis));
		}
		col = mix(col, umber * 1.3, clamp(cav * 0.55 + ends * 0.45, 0.0, 0.75));
		// Bolle randen afgesleten: lichter, bijna wit.
		col = mix(col, vec3(0.95, 0.92, 0.84), smoothstep(0.45, 0.9, wear.r) * 0.35);
		// Putjes en haarscheurtjes.
		float pit = step(0.86, vnoise(opos * 14.0)) * 0.35;
		float cr = abs(vnoise(opos * 1.9 + vec3(21.0)) - 0.5);
		float crack = (1.0 - smoothstep(0.0, 0.012, cr)) * smoothstep(0.4, 0.7, vnoise(opos * 0.7 + vec3(5.0)));
		col *= 1.0 - pit - crack * 0.55;
		ALBEDO = col;
		ROUGHNESS = mix(0.62, 0.9, big) + pit * 0.3;
		SPECULAR = 0.35;
		EMISSION = flash_color * flash;
	}
}
