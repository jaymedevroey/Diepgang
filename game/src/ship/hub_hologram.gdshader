shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Hologram boven de opdrachttafel (HubScreens): het beeld van een SubViewport (zwarte achtergrond)
// als lichtende tekst op een doorschijnend, donker cyaan vlak, met lopende scanlijnen, een zakkende
// band, wat flikkering en zachte randen. Het donkere vlak houdt de tekst leesbaar voor een lichte
// achtergrond (de hangar). Van achteren gezien gespiegeld terug, zodat de tekst ook dan leesbaar is.

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform vec3 panel_color : source_color = vec3(0.01, 0.06, 0.08);
uniform vec3 glow_color : source_color = vec3(0.31, 0.89, 0.94);
uniform float panel_alpha = 0.5;
uniform float brightness = 1.8;
uniform float lines = 144.0;

float rnd(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y); // viewporttextuur staat ondersteboven op dit vlak
	if (!FRONT_FACING) {
		uv.x = 1.0 - uv.x;
	}
	// Af en toe een korte storing: een smalle strook schuift even opzij.
	float gseed = floor(TIME * 7.0);
	float strip = step(abs(uv.y - rnd(gseed + 1.7)), 0.035);
	uv.x += step(0.95, rnd(gseed)) * strip * (rnd(gseed + 3.1) - 0.5) * 0.04;
	vec3 col = texture(feed, uv).rgb;
	float lum = max(col.r, max(col.g, col.b));
	// Scanlijnen die langzaam lopen; op afstand (dicht opeen) vervagen ze in plaats van te flikkeren.
	float phase = uv.y * lines - TIME * 3.0;
	float aa = clamp(1.0 - fwidth(phase) * 1.2, 0.0, 1.0);
	float scan = 1.0 - 0.3 * aa * (0.5 - 0.5 * sin(phase * 6.2831));
	// Een lichtere band die van boven naar onder zakt, en wat flikkering.
	float band = 1.0 - smoothstep(0.0, 0.06, abs(fract(uv.y - TIME * 0.12) - 0.5));
	float flick = 0.92 + 0.08 * sin(TIME * 31.0) * sin(TIME * 13.7);
	// Zachte randen.
	float edge = smoothstep(0.0, 0.02, uv.x) * smoothstep(1.0, 0.98, uv.x)
			* smoothstep(0.0, 0.04, uv.y) * smoothstep(1.0, 0.96, uv.y);
	vec3 panel = panel_color + glow_color * (0.04 + 0.05 * band) * (0.6 + 0.4 * uv.y);
	vec3 light = col * brightness * scan * flick * (1.0 + 0.3 * band);
	float a_text = clamp(lum * 1.6, 0.0, 1.0);
	ALBEDO = mix(panel, light, a_text);
	ALPHA = clamp(max(panel_alpha * scan, a_text), 0.0, 1.0) * edge * (FRONT_FACING ? 1.0 : 0.6);
}
