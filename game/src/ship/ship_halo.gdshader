shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Halo rond een licht van De Ekster van buiten (navigatielichten, de flitser op de mast, de
// buiklichten): een vlak naar de camera met een zachte, ronde gloed. Van ver blijft hij minstens
// `min_angle` (radialen) groot, zodat je het schip op 340 m hoogte aan zijn lichtjes herkent; van
// dichtbij is hij `size_m` breed. Een beetje naar de camera geschoven, zodat de romp hem niet
// doormidden snijdt. `blink` (0..1) zet EksterExterior elke frame (knipperen, flitsen).

uniform vec3 color : source_color = vec3(1.0, 0.2, 0.1);
uniform float energy = 3.0;
uniform float size_m = 2.0;
uniform float min_angle = 0.006;
uniform float blink = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = max(size_m, length(c) * min_angle);
	VERTEX = VERTEX * s + vec3(0.0, 0.0, 1.5);
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = exp(-r * r * 7.0) * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = color * energy;
	ALPHA = clamp(a * blink, 0.0, 1.0);
}
