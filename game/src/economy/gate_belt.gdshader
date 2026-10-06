shader_type spatial;

// De band van de taxatiepoort (GateShow, golf 3): zwart rubber met stalen latten die meelopen als de
// band draait (`offset` in meter, gezet per frame). UV.x loopt over de lengte (`belt_len` meter).

uniform float offset = 0.0;
uniform float belt_len = 3.3;
uniform float pitch = 0.24;
uniform vec3 rubber : source_color = vec3(0.045, 0.045, 0.05);
uniform vec3 slat : source_color = vec3(0.26, 0.265, 0.28);
// Gele rand langs beide kanten (een strookje, zoals een lijn op de vloer).
uniform vec3 edge : source_color = vec3(0.949, 0.718, 0.02);

void fragment() {
	float x = UV.x * belt_len - offset;
	float f = fract(x / pitch);
	float s = smoothstep(0.0, 0.015, f) * (1.0 - smoothstep(0.17, 0.19, f));
	float side = step(UV.y, 0.025) + step(0.975, UV.y);
	vec3 col = mix(rubber, slat, s * 0.9);
	col = mix(col, edge * 0.8, side);
	ALBEDO = col;
	METALLIC = s * 0.7 * (1.0 - side);
	ROUGHNESS = mix(0.9, 0.45, s);
}
