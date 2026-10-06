shader_type spatial;
render_mode unshaded, cull_back;

// Camerascherm in de cabine: beeld van de kopcamera met scanlijnen, vignet en wat ruis,
// zodat het leest als een oude bewakingsmonitor en niet als een venster.
// Onder de grond (golf 3, binnen2-15: "een bruine waas"): een nachtcamera met hoog contrast die de
// randen van de rots toont (Sobel op de helderheid), zodat je de tunnel, de laag en een vondst ziet.

uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(0.92, 1.0, 0.95);
uniform float brightness = 1.25;
uniform float lines = 176.0;
uniform float desaturate = 0.35;
uniform float vignette = 0.7;
// Het camerascherm in het model heeft een omgekeerde v; een QuadMesh (statusscherm) niet.
uniform bool flip_v = true;
uniform float edges = 0.0; // 0 = gewoon beeld, 1 = nachtcamera met randen

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
	if (edges > 0.0) {
		// Randen: het verschil in helderheid met de buren (Sobel), sterk versterkt.
		vec2 px = vec2(1.0 / 640.0, 1.0 / 352.0) * 1.5;
		float tl = dot(texture(feed, uv + vec2(-px.x, -px.y)).rgb, vec3(0.333));
		float tc = dot(texture(feed, uv + vec2(0.0, -px.y)).rgb, vec3(0.333));
		float tr = dot(texture(feed, uv + vec2(px.x, -px.y)).rgb, vec3(0.333));
		float ml = dot(texture(feed, uv + vec2(-px.x, 0.0)).rgb, vec3(0.333));
		float mr = dot(texture(feed, uv + vec2(px.x, 0.0)).rgb, vec3(0.333));
		float bl = dot(texture(feed, uv + vec2(-px.x, px.y)).rgb, vec3(0.333));
		float bc = dot(texture(feed, uv + vec2(0.0, px.y)).rgb, vec3(0.333));
		float br = dot(texture(feed, uv + vec2(px.x, px.y)).rgb, vec3(0.333));
		float gx = (tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl);
		float gy = (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr);
		float e = clamp(sqrt(gx * gx + gy * gy) * 6.0, 0.0, 1.0);
		// Helderheid met hoog contrast (een nachtcamera trekt het donker op), en de randen fel.
		float lum = pow(clamp(l * brightness * 2.2, 0.0, 1.0), 0.6);
		lum = smoothstep(0.05, 0.85, lum);
		vec3 night = vec3(1.0, 0.68, 0.3) * (0.05 + 0.36 * lum) + vec3(1.0, 0.86, 0.55) * e * 0.95;
		col = mix(col, night * inside, edges);
	}
	col *= 0.86 + 0.14 * sin(uv.y * lines * 6.2831);
	col += (rnd(uv * 400.0 + fract(TIME * 13.0)) - 0.5) * 0.05;
	col *= 1.0 - smoothstep(0.25, 0.75, length(c * vec2(1.0, 1.4))) * vignette;
	col *= 0.97 + 0.03 * sin(TIME * 47.0);
	ALBEDO = max(col, vec3(0.012, 0.02, 0.018));
}
