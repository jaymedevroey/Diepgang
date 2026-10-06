shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// Grotdecor uit setpieces.glb (CaveDecor, golf 3 binnen2-06): zwammen, konzoolzwammen, gloeidraden,
// geodes en zoutkorsten. Elk oppervlak een eigen materiaal (base, gloed); de kleur per exemplaar
// (MultiMesh, sRGB) is de gloed van de planeet. Een zwam is mat en gekleurd, enkel de lamellen en de
// stippen gloeien: zo leest hij als zwam en niet als edelsteen.

uniform vec3 base : source_color = vec3(0.6, 0.6, 0.6);
uniform float tint_albedo = 0.0; // hoeveel de kleur per exemplaar de albedo kleurt
uniform float glow = 0.0;        // gloed in de kleur per exemplaar
uniform float rough = 0.7;
uniform float rim_k = 0.0;       // rand die oplicht (glazig: kwarts)

void fragment() {
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = mix(base, tint * 0.55, tint_albedo);
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = tint * glow * (0.85 + 0.6 * fres * rim_k) + base * rim_k * fres * 0.15;
}
