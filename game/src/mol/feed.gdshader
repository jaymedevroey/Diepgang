shader_type spatial;
render_mode unshaded, cull_back;

// Camerascherm in de cabine: beeld van de kopcamera met scanlijnen, vignet en wat ruis,
// zodat het leest als een oude bewakingsmonitor en niet als een venster.

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(0.92, 1.0, 0.95);
uniform float brightness = 1.25;
uniform float lines = 176.0;
uniform float desaturate = 0.35;
uniform float vignette = 0.7;
// Het camerascherm in het model heeft een omgekeerde v; een QuadMesh (statusscherm) niet.
uniform bool flip_v = true;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = flip_v ? vec2(UV.x, 1.0 - UV.y) : UV; // viewporttextuur staat ondersteboven op het model
	// Lichte tonvervorming van een bolle beeldbuis.
	vec2 c = uv - 0.5;
	uv = 0.5 + c * (1.0 + 0.06 * dot(c, c));
	// Buiten het beeld (door de bolling) zwart, zoals de rand van een beeldbuis; niet de overkant herhalen.
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 col = texture(feed, uv).rgb * brightness * inside;
	float l = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(l), desaturate) * tint; // wat ontzadigd
	col *= 0.86 + 0.14 * sin(uv.y * lines * 6.2831);
	col += (rnd(uv * 400.0 + fract(TIME * 13.0)) - 0.5) * 0.05;
	col *= 1.0 - smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.4))) * vignette;
	col *= 0.97 + 0.03 * sin(TIME * 47.0);
	ALBEDO = max(col, vec3(0.012, 0.02, 0.018));
}
