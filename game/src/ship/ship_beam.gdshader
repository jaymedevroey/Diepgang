shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Lichtbundel uit de buik van De Ekster bij het ophalen (golf 3, buiten2-3: "het schip vroeger
// aankondigen met een lichtbundel"): een kegel van de baai naar de grijper. Zacht aan de randen
// (waar je langs de kegel kijkt), het felst bij de schijnwerpers, met stof dat erin zweeft. Met mist:
// van ver dooft hij in de waas. De kegel is een CylinderMesh: UV.y = 0 boven (de baai), 1 onderaan.

uniform vec3 color : source_color = vec3(1.0, 0.86, 0.66);
uniform float energy = 0.35;
uniform float amount = 1.0; // 0 = uit (de grijper hangt in de baai)

varying float along;
varying vec3 wp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	along = UV.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = pow(facing, 2.5);
	float a = clamp(along, 0.0, 1.0);
	float fade = mix(1.0, 0.35, a) * smoothstep(0.0, 0.04, a);
	// Stof in de bundel: trage vlekjes die naar beneden drijven.
	vec3 q = floor(vec3(wp.x * 0.6, wp.y * 0.25 + TIME * 0.6, wp.z * 0.6));
	float motes = 0.85 + 0.3 * hash(q);
	ALBEDO = color * energy * motes;
	ALPHA = clamp(soft * fade * amount, 0.0, 1.0);
}
