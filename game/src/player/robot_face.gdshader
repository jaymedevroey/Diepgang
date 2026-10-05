shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Schermgezicht van de robot (GDD §8): pixelogen op een donker scherm.
// UV: v omhoog; u loopt van rechts naar links gezien van voren (zie tools/blender/robot.py).

uniform vec3 face_color : source_color = vec3(0.35, 0.95, 1.0);
uniform float brightness = 4.5;
uniform float blink = 0.0;           // 0 = open, 1 = dicht
uniform vec2 look = vec2(0.0);       // -1..1, x = naar rechts (vanuit de robot), y = omhoog
uniform float happy = 0.0;           // 0..1: ogen worden boogjes ^^
uniform float squint = 0.0;          // 0..1: ogen worden streepjes (inspanning)
uniform float dazed = 0.0;           // 0..1: ogen worden kruisjes (neergegaan, ragdoll)

const vec2 GRID = vec2(18.0, 10.0);

float eye(vec2 c, vec2 center) {
	vec2 d = c - center;
	float half_h = mix(2.5, 0.5, max(blink, squint * 0.8));
	float rect = step(abs(d.x), 1.1) * step(abs(d.y), half_h);
	// Blije boog: bovenste rij + twee schouders.
	float arc = step(abs(d.x), 1.6) * step(abs(d.y - 0.5), 0.5) * (1.0 - step(abs(d.x), 0.6) * step(d.y, 0.5))
		+ step(abs(abs(d.x) - 2.0), 0.5) * step(abs(d.y + 0.5), 0.5);
	// Kruisje (neergegaan): twee diagonalen van 5 × 5 pixels.
	float cross_eye = step(abs(d.x), 2.1) * step(abs(d.y), 2.1) * (step(abs(d.x - d.y), 0.5) + step(abs(d.x + d.y), 0.5));
	float shape = mix(rect, clamp(arc, 0.0, 1.0), step(0.5, happy));
	return mix(shape, clamp(cross_eye, 0.0, 1.0), step(0.5, dazed));
}

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, 1.0 - UV.y); // naar "van voren gezien, x rechts, y omhoog"
	vec2 cell = floor(uv * GRID);
	vec2 f = fract(uv * GRID);
	float pixel = step(0.06, f.x) * step(f.x, 0.94) * step(0.06, f.y) * step(f.y, 0.94);
	// Van ver weg zijn de spleten kleiner dan een schermpixel: dan weglaten (anti-aliasing).
	float cell_px = 1.0 / max(fwidth(uv.y * GRID.y), 1e-4);
	pixel = mix(1.0, pixel, smoothstep(5.0, 10.0, cell_px));
	vec2 c = cell + 0.5;
	vec2 offset = look * vec2(1.5, 1.0);
	float eyes = eye(c, vec2(5.5, 5.5) + offset) + eye(c, vec2(12.5, 5.5) + offset);
	eyes = clamp(eyes, 0.0, 1.0) * pixel;
	// Zwakke gloed van het scherm zelf.
	ALBEDO = vec3(0.01, 0.015, 0.02);
	ROUGHNESS = 0.15;
	SPECULAR = 0.7;
	EMISSION = face_color * (eyes * brightness + 0.04);
}
