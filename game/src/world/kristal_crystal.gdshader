shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_back;

// Kristal van Kristalmaan (docs/research/planeten.md §4.3): ondoorzichtig, met nep-doorschijnendheid
// (geen overdraw). Lavendel lichaam, goud op de kant die naar de lage zon kijkt, een gouden rand
// in tegenlicht (je kijkt naar de zon door het kristal), en een zwakke cyaan binnengloed onderin
// die enkel in de schaduw opvalt (onder de gloeidrempel van 1,2: geen bloom).
// Vertexkleur: rgb = tint per kristal, a = hoeveel binnengloed (onderaan meer dan in de punt).

uniform vec3 body : source_color = vec3(0.69, 0.541, 0.863);     // #B08ADC: lavendel dat na AgX en de warme zon nog lavendel is
uniform vec3 sun_side : source_color = vec3(1.0, 0.851, 0.659);  // #FFD9A8
uniform vec3 glow : source_color = vec3(0.31, 0.89, 0.941);      // #4FE3F0 (cyaan: enkel voor kristal)
uniform float glow_energy = 0.2;
uniform float inner = 0.07;      // nep-doorschijnendheid: het lavendel licht zwak op in de schaduw
uniform float sheen = 0.75;      // goudglans op de zonkant (niet maal het lavendel)
uniform float transmit = 0.14;   // gouden rand in tegenlicht (meer maakt het kristal bleek als ijs)
uniform float glint = 1.2;       // scherpe glinster op de facetten
uniform float roughness = 0.42;
uniform float specular = 0.15;   // weinig spiegeling van de lichte hemel (anders wit als ijs)

varying float vglow;

void vertex() {
	vglow = COLOR.a;
}

void fragment() {
	vec3 albedo = body * COLOR.rgb;
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	// Binnengloed: sterker waar je recht in een vlak kijkt (je kijkt "in" het kristal) en onderin.
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = glow * glow_energy * vglow * vglow * (0.3 + 0.7 * facing) + albedo * inner;
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
