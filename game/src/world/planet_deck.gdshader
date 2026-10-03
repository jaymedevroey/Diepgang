shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_back, depth_draw_opaque;

// Planeetdek onder de hub (Atmosphere): een groot vlak ver onder De Ekster dat tekent wat de hemel
// onder de horizon tekent (planet_air.gdshaderinc): de planeet ver onder je, door de stofnevel.
// Zo zie je door de open baai of de valschacht nooit wat er echt onder de hub ligt (het buitenschip,
// het stukje voxelterrein van de landingsplek, 1,7 km lager), en ook geen lege lucht. Boven de
// horizon (de rand van het dek) valt het weg: daar tekent de hemel zelf verder.
// Enkel van boven zichtbaar (cull_back): van op de planeet of tijdens de drop zie je het nooit.

#include "res://src/world/planet_air.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0); // naar de zon (wereld)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 ro = CAMERA_POSITION_WORLD;
	vec3 d = normalize(wpos - ro);
	float alt = max(ro.y - surface_y, 0.0);
	float dip = air_dip(alt);
	float e = asin(clamp(d.y, -1.0, 1.0)) + dip;
	if (e >= 0.0) {
		discard;
	}
	vec3 s = normalize(sun_dir);
	float mu = dot(d, s);
	float k = exp(-alt / haze_height);
	vec3 t_sun = air_sun_t(s, k, dip);
	vec3 haze = air_haze(e, mu, t_sun);
	ALBEDO = planet_ground(ro, d, s, alt, e, mu, t_sun, haze, true);
}
