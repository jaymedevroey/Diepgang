shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Hologram boven de opdrachttafel (HubScreens): het beeld van een SubViewport (zwarte achtergrond)
// als lichtende lijnen en tekst op een donker vlak, met lopende scanlijnen, een zakkende band, wat
// flikkering en zachte randen. Golf 3 (ui-03): in DIG-amber in plaats van cyaan, en de achterplaat is
// dicht (de achterwand met PROFIT liep door de letters). Van achteren gespiegeld terug, zodat de tekst
// ook dan leesbaar is.

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform vec3 panel_color : source_color = vec3(0.05, 0.03, 0.015);
uniform vec3 glow_color : source_color = vec3(1.0, 0.71, 0.35);
uniform float panel_alpha = 0.97;
uniform float front_panel_alpha = 1.0;
uniform vec3 front_panel_color : source_color = vec3(0.035, 0.022, 0.012);
uniform float brightness = 1.6;
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
	uv.x += step(0.95, rnd(gseed)) * strip * (rnd(gseed + 3.1) - 0.5) * 0.03;
	vec3 col = texture(feed, uv).rgb;
	float lum = max(col.r, max(col.g, col.b));
	// Scanlijnen die langzaam lopen; op afstand (dicht opeen) vervagen ze in plaats van te flikkeren.
	float phase = uv.y * lines - TIME * 3.0;
	float aa = clamp(1.0 - fwidth(phase) * 1.2, 0.0, 1.0);
	float scan = 1.0 - 0.22 * aa * (0.5 - 0.5 * sin(phase * 6.2831));
	// Een lichtere band die van boven naar onder zakt, en wat flikkering.
	float band = 1.0 - smoothstep(0.0, 0.06, abs(fract(uv.y - TIME * 0.12) - 0.5));
	float flick = 0.94 + 0.06 * sin(TIME * 31.0) * sin(TIME * 13.7);
	// Zachte randen.
	float edge = smoothstep(0.0, 0.015, uv.x) * smoothstep(1.0, 0.985, uv.x)
			* smoothstep(0.0, 0.03, uv.y) * smoothstep(1.0, 0.97, uv.y);
	vec3 base = FRONT_FACING ? front_panel_color : panel_color;
	vec3 panel = base + glow_color * (0.03 + 0.04 * band) * (0.6 + 0.4 * uv.y);
	vec3 light = col * brightness * scan * flick * (1.0 + 0.25 * band);
	float a_text = clamp(lum * 1.6, 0.0, 1.0);
	ALBEDO = mix(panel, light, a_text);
	// Een dichte plaat: de scanlijnen kleuren enkel, ze maken het vlak niet doorzichtig.
	float pa = FRONT_FACING ? front_panel_alpha : panel_alpha;
	ALPHA = clamp(max(pa, a_text), 0.0, 1.0) * edge;
}
