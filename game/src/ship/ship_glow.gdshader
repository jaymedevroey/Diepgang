shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Stuwgloed van De Ekster van buiten (EksterExterior): een kegel die uit een straalpijp komt (de
// hoofdmotoren naar achter, de hefstralen onder de buik). Optellend licht, met een snelle flikkering.
// Geen mist erover: van op de grond moet het schip leven, ook in de waas van Roestbol.
// Golf 3 (buiten2-8: "witte, uitgebrande kegels, van op de grond een kroon van stekels"): een
// kleurverloop in de lengte en dwars (een wit-blauwe kern vlak bij de straalpijp, naar buiten en naar
// het einde de kleur van de motor en dan warm), zachte randen (de kern is smal), schokdiamanten in de
// kern, en buiten de kern weinig licht.
// De kegel is een CylinderMesh: UV.y = 0 aan de bovenkant (de straalpijp), 1 aan het einde.

uniform vec3 color : source_color = vec3(0.55, 0.75, 1.0);
uniform vec3 warm : source_color = vec3(1.0, 0.55, 0.28);
uniform float energy = 2.5;
uniform float seed = 0.0;

varying float along;

void vertex() {
	along = UV.y;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 4.0);        // smal: het midden van de straal
	float body = pow(facing, 1.6);        // de straal zelf, met zachte randen
	float a = clamp(along, 0.0, 1.0);
	float fade = pow(1.0 - a, 2.2);
	float flick = 0.85 + 0.15 * sin(TIME * 37.0 + seed * 11.0 + along * 9.0) * sin(TIME * 23.0 + seed * 5.0);
	// Schokdiamanten: lichtere knopen in de kern, het dichtst bij de straalpijp.
	float diamonds = 0.75 + 0.25 * smoothstep(0.3, 1.0, sin(a * 40.0 - TIME * 3.0)) * (1.0 - a);
	// Kleur: wit-blauw in de kern bij de straalpijp, de motorkleur in de straal, warm aan het einde.
	vec3 hot = mix(color, vec3(0.9, 0.95, 1.0), 0.75);
	vec3 c = mix(color, warm, smoothstep(0.35, 0.9, a) * 0.7);
	c = mix(c, hot, core * (1.0 - smoothstep(0.0, 0.45, a)));
	ALBEDO = c * energy * flick * diamonds;
	ALPHA = clamp((body * 0.35 + core * 0.65) * fade, 0.0, 1.0);
}
