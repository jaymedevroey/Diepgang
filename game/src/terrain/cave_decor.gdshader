shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Zwammen en kristallen in de grotten (CaveDecor). Vertexkleur (sRGB) maal de kleur per exemplaar:
// rgb = kleur, a = hoeveel het gloeit (de hoed van een zwam wel, zijn steel niet).

uniform vec3 glow : source_color = vec3(0.36, 0.95, 0.75);
uniform float energy = 2.0;
uniform float rough = 0.5;
uniform float rim_k = 0.0;

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * mix(1.0, 0.45, COLOR.a);
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	// Een rand die oplicht (glazig), en de gloed zelf: de kleur van het exemplaar.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = (c * 0.6 + glow * 0.4) * energy * COLOR.a * (0.75 + 0.5 * fres * rim_k + 0.25);
}
