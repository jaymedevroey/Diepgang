shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

// Kristal van Kristalmaan (docs/research/planeten.md §4.3, stijlgids "kristal cyaan, glazig,
// gloeiend"): ondoorzichtig, met nep-doorschijnendheid (geen overdraw).
// - Lavendel lichaam, goud op de kant die naar de lage zon kijkt, een gouden rand in tegenlicht.
// - Glazig: een fresnelrand (de randen van elk facet lichten op, lavendel naar ijsblauw), en een
//   zweem prisma (de tint verschuift met de kijkhoek).
// - Gloed waar geen zon komt: cyaan binnengloed aan de schaduwkant en onderin (planeten.md: "enkel
//   de binnengloed in de schaduw mag gloeien"), sterker naar de rand toe.
// - Glinsters: kleine vlakjes die oplichten en doven als je beweegt (per facet een eigen hoek),
//   enkel aan de zonkant. Kort boven de gloeidrempel: een fonkel, geen waas.
// Vertexkleur: rgb = tint per kristal, a = hoeveel binnengloed (onderaan meer dan in de punt).
// to_sun: richting naar de zon (wereld), gezet door LandformKristal uit het planeettype.
// Golf 3 (buiten-6: "ondoorzichtige, ijsblauwe staven, plastic of ijs, niet glazig en gloeiend"):
// donkerder lichaam (glas heeft weinig eigen kleur), een cyane kern die door de vlakken heen gloeit
// (het felst waar je recht door het kristal kijkt, dus door het meeste glas, en onderaan), randen die
// oplichten, en minder witte glans op de zonkant.

uniform vec3 body : source_color = vec3(0.69, 0.541, 0.863);     // #B08ADC: lavendel dat na AgX en de warme zon nog lavendel is
uniform vec3 sun_side : source_color = vec3(1.0, 0.851, 0.659);  // #FFD9A8
uniform vec3 glow : source_color = vec3(0.31, 0.89, 0.941);      // #4FE3F0 (cyaan: enkel voor kristal)
uniform vec3 ice : source_color = vec3(0.847, 0.8, 0.941);       // #D8CCF0: het lichaam in het licht, de fresnelrand
uniform vec3 to_sun = vec3(0.0, 0.17, -0.98);
uniform float glow_energy = 0.9;
uniform float shadow_glow = 0.45; // cyaan aan de schaduwkant
uniform float fresnel = 0.55;
uniform float prism = 0.35;
uniform float inner = 0.07;      // nep-doorschijnendheid: het lavendel licht zwak op in de schaduw
uniform float sheen = 0.45;      // goudglans op de zonkant (niet maal het lavendel)
uniform float transmit = 0.14;   // gouden rand in tegenlicht (meer maakt het kristal bleek als ijs)
uniform float glint = 0.9;       // scherpe glinster op de facetten
uniform float sparkle = 2.6;     // fonkels die met de kijkhoek aan en uit gaan
uniform float roughness = 0.42;
uniform float specular = 0.1;    // weinig spiegeling van de lichte hemel (anders wit als ijs)
uniform float core = 1.1;        // de gloeiende kern die door het glas schijnt

varying float vglow;
varying vec3 wpos;

void vertex() {
	vglow = COLOR.a;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 wv = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - facing, 3.0);
	float ndl = dot(wn, normalize(to_sun));
	float shade = 1.0 - smoothstep(-0.2, 0.3, ndl); // 1 = schaduwkant
	// Prisma: de tint draait zacht met de kijkhoek (lavendel - roze - ijsblauw), enkel een zweem.
	float ph = dot(wv, wn) * 6.0 + dot(wn, vec3(3.1, 1.7, 2.3));
	vec3 rainbow = 0.5 + 0.5 * cos(ph + vec3(0.0, 2.1, 4.2));
	vec3 albedo = body * COLOR.rgb * mix(vec3(1.0), 0.75 + 0.5 * rainbow, prism * fr) * 0.62;
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	vec3 e = glow * glow_energy * vglow * vglow * (0.3 + 0.7 * facing);
	// Binnengloed in de schaduw: cyaan, het sterkst naar de randen van het silhouet.
	e += glow * shadow_glow * shade * (0.3 + 0.7 * fr) * (0.45 + 0.55 * vglow);
	// Fresnel: de rand van elk facet licht op (glas vangt de lucht), aan de zonkant ijs, in de schaduw cyaan.
	e += mix(ice, glow, shade * 0.4) * fr * fresnel * (0.35 + 0.65 * (1.0 - shade));
	e += albedo * inner;
	// De kern: cyaan dat door het glas schijnt, het felst waar je door het meeste glas kijkt (recht op
	// een vlak), naar de top toe zwakker; wat ruis langs de as zodat het geen effen buis is.
	float depth_k = pow(facing, 1.5);
	float veins = 0.75 + 0.25 * sin(wpos.y * 3.1 + dot(wpos.xz, vec2(1.7, 2.3)));
	e += glow * core * depth_k * (0.35 + 0.65 * vglow) * veins;
	// Fonkels: per facet (vlakke normalen) en per stukje kristal een eigen hoek waaronder het oplicht.
	vec3 cell = floor(wpos * 2.5) + floor(wn * 4.0) * 7.0;
	float h1 = hash3(cell);
	float h2 = hash3(cell + 13.7);
	float flick = pow(max(0.0, sin(dot(wv, vec3(23.0, 17.0, 29.0)) + h1 * 6.283)), 48.0);
	e += sun_side * sparkle * flick * step(0.82, h2) * (1.0 - shade) * smoothstep(0.1, 0.5, facing);
	EMISSION = e;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = clamp(ndl, 0.0, 1.0);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
	// Goud op de zonkant: een brede glans bovenop het lavendel.
	SPECULAR_LIGHT += sun_side * (lit * lit) * ATTENUATION * LIGHT_COLOR * sheen / PI;
	// Glinster: een smalle spiegeling per facet (vlakke normalen: flikkert als je beweegt).
	vec3 h = normalize(LIGHT + VIEW);
	float s = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 90.0);
	SPECULAR_LIGHT += sun_side * s * ATTENUATION * LIGHT_COLOR * glint / PI;
	// Tegenlicht: staat de zon achter het kristal, dan gloeien de vlakken die schuin van je weg
	// draaien goud (de rand van het silhouet). Zonder ATTENUATION: die zegt dat de achterkant in
	// zijn eigen schaduw ligt. Enkel de zon.
	if (LIGHT_IS_DIRECTIONAL) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = 1.0 - facing;
		float back = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * (1.0 - lit) * rim * rim;
		SPECULAR_LIGHT += sun_side * back * LIGHT_COLOR * transmit / PI;
	}
}
