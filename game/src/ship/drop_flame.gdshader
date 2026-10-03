shader_type spatial;
// Vlam van een stuwraket onder de Mol bij het remmen na de drop: een kegel (punt omlaag), van
// wit-geel bij de straalpijp naar oranje en doorzichtig aan de punt, met flakkerende ruis die naar
// beneden stroomt en zachte randen (naar de kijker toe het felst). Additief, onbelicht.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.92, 0.7);
uniform vec3 mid_color : source_color = vec3(1.0, 0.55, 0.15);
uniform vec3 tip_color : source_color = vec3(0.6, 0.18, 0.05);

varying float along; // 0 = straalpijp, 1 = punt

float hash(vec2 p) {
	// Dave Hoskins (zonder sin: geen naden).
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// CylinderMesh met hoogte 1, middelpunt in 0: y = +0,5 is de straalpijp, −0,5 de punt.
	along = 0.5 - VERTEX.y;
}

void fragment() {
	float rim = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	// Geklemd: op de punt is along door afronding net boven 1, en pow() van iets negatiefs is NaN
	// (een NaN in een additief materiaal werd een witte bol door de gloed).
	float a = clamp(1.0 - along, 0.0, 1.0);
	float n = noise(vec2(UV.x * 6.0 + seed * 13.0, along * 5.0 - TIME * 14.0));
	float n2 = noise(vec2(UV.x * 13.0 - seed * 7.0, along * 11.0 - TIME * 23.0));
	float flick = 0.65 + 0.45 * n + 0.25 * n2;
	vec3 col = mix(core_color, mid_color, smoothstep(0.0, 0.45, along));
	col = mix(col, tip_color, smoothstep(0.45, 1.0, along));
	float alpha = pow(rim, 1.6) * pow(a, 1.3) * flick * intensity;
	// Een felle kern vlak onder de straalpijp.
	col += core_color * smoothstep(0.2, 0.0, along) * pow(rim, 3.0) * 0.6;
	ALBEDO = col * alpha * 1.6;
}
