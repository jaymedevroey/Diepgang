shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Stuwgloed van De Ekster van buiten (EksterExterior): een kegel die uit een straalpijp komt (de
// hoofdmotoren naar achter, de hefstralen onder de buik). Optellend licht: het felst in de kern
// (waar je recht in de kegel kijkt) en bij de straalpijp, uitdovend naar het einde, met een snelle
// flikkering. Geen mist erover: van op de grond moet het schip leven, ook in de waas van Roestbol.
// De kegel is een CylinderMesh: UV.y = 0 aan de bovenkant (de straalpijp), 1 aan het einde.

uniform vec3 color : source_color = vec3(0.55, 0.75, 1.0);
uniform float energy = 2.5;
uniform float seed = 0.0;

varying float along;

void vertex() {
	along = UV.y;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.0);
	float fade = pow(1.0 - clamp(along, 0.0, 1.0), 1.6);
	float flick = 0.82 + 0.18 * sin(TIME * 37.0 + seed * 11.0 + along * 9.0) * sin(TIME * 23.0 + seed * 5.0);
	// Naar het einde toe witter in de kern, aan de rand de kleur.
	vec3 c = mix(color, vec3(1.0), core * (1.0 - along) * 0.5);
	ALBEDO = c * energy * flick;
	ALPHA = clamp(core * fade, 0.0, 1.0);
}
