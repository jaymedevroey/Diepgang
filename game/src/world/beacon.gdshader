shader_type spatial;
render_mode unshaded;

// Knipperlampje op de paaltjes van de concessiegrens: oranje, elk paaltje een eigen fase.

uniform vec3 color : source_color = vec3(1.0, 0.45, 0.08);

varying float phase;

void vertex() {
	phase = fract(sin(float(INSTANCE_ID) * 12.9898 + 4.1) * 43758.5453);
}

void fragment() {
	float blink = step(0.55, fract(TIME * 0.7 + phase));
	ALBEDO = color * (0.25 + 2.6 * blink);
}
