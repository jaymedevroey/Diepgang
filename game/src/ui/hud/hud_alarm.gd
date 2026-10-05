class_name HudAlarm
extends ColorRect
## Een gloed rond het hele scherm die je voelt zonder ernaar te kijken (ui-04): bij een voorschok en
## een beving, bij een alarm (magma onder de Mol, noodophaling, oververhit, gesmolten) en tijdens de
## laatste tellen van de drop. Zonder geluid (M6) is dit het kanaal dat "nu opletten" zegt.
## Twee bronnen, de sterkste wint:
##   `level` (0..1)  aanhoudend, elke frame gezet door de HUD (bv. de beving), met een puls van `pulse_hz`;
##   `flash()`       een korte opflakkering die vanzelf uitdooft (een alarm, een tel van de aftelling).
## Knippert hooguit 2,5 keer per seconde (veilig voor wie gevoelig is voor flitsen).

const MAX_HZ := 2.5
const SHADER := """
shader_type canvas_item;
// Ronde vignet: in het midden niets, naar de randen donker en dan de kleur van het gevaar.
uniform vec4 tint : source_color = vec4(1.0, 0.35, 0.12, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 uv = UV;
	float v = pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.3);
	float edge = 1.0 - smoothstep(0.0, 0.82, v);
	vec3 c = mix(vec3(0.0), tint.rgb, smoothstep(0.25, 0.95, edge));
	COLOR = vec4(c, clamp(edge * 1.25, 0.0, 1.0) * amount);
}
"""

var level := 0.0
var pulse_hz := 1.0
var tint := UiTheme.DANGER
var _flash := 0.0
var _flash_color := UiTheme.DANGER
var _t := 0.0
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat
	visible = false


## Korte opflakkering (0..1) in een kleur; dooft uit in ±1 s.
func flash(strength := 1.0, col := UiTheme.DANGER) -> void:
	if strength >= _flash:
		_flash_color = col
	_flash = maxf(_flash, clampf(strength, 0.0, 1.0))


## Hoe sterk de gloed nu is (voor tests).
func strength() -> float:
	return maxf(_steady(), _flash)


func _steady() -> float:
	if level <= 0.0:
		return 0.0
	var hz := minf(pulse_hz, MAX_HZ)
	return level * (0.55 + 0.45 * (0.5 + 0.5 * sin(_t * TAU * hz)))


func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 1.1)
	var steady := _steady()
	var a := maxf(steady, _flash)
	visible = a > 0.01
	if visible:
		_mat.set_shader_parameter("amount", a * 0.9)
		_mat.set_shader_parameter("tint", _flash_color if _flash > steady else tint)
