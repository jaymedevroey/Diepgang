class_name ImpactFx
extends CanvasLayer
## Het klapmoment van de lokale speler (release-audit golf 3, gevoel2-02, gevoel2-10, binnen2-03):
## een korte flits over het hele beeld (wit, dan de kleur van de klap) en een FOV-stoot. De hit-stop
## zelf (het beeld dat even blijft staan voor de volgcamera) zit in Player (_impact_hold).
## Enkel lokaal en enkel beeld: elk peer toont zijn eigen klap.
## Waarden in camera.cfg (impact_*). Uit te zetten met de schermschok (Settings interface/camera_shake)
## en de instelling voor flitsen: de flits is nooit feller dan impact_flash_max.

## Een klap trof de lokale speler (bron, sterkte 0..1): haak voor het geluid (M6: een doffe klap,
## een kreun van de robot). Geen geluid uit code.
signal hit(source: String, strength: float)

var _rect: ColorRect
var _alpha := 0.0
var _color := Color.WHITE
var _tint := Color.WHITE
var _since := 10.0
## FOV-stoot in graden (veer): Player telt hem bij de FOV.
var fov_kick := 0.0
var _fov_vel := 0.0


func _ready() -> void:
	layer = 60 # boven de wereld, onder menu's
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(1, 1, 1, 0)
	_rect.visible = false
	add_child(_rect)


## Een klap: `strength` 0..1, `tint` de kleur waarin de flits uitdooft (wit = een rots, oranje = gas,
## rood = de worm). Twee klappen kort na elkaar (de voorspelling en daarna de host) tellen als één.
func punch(strength: float, tint := Color.WHITE, source := "") -> void:
	strength = clampf(strength, 0.0, 1.0)
	var fresh := _since > Tuning.get_f("camera", "impact_merge_s", 0.25)
	_since = 0.0
	var scale := Settings.get_f("interface/camera_shake") if Settings.DEFAULTS.has("interface/camera_shake") else 1.0
	var a := strength * Tuning.get_f("camera", "impact_flash_max", 0.55) * clampf(0.35 + 0.65 * scale, 0.0, 1.0)
	_alpha = maxf(_alpha, a)
	_tint = tint
	_color = Color.WHITE
	_fov_vel += Tuning.get_f("camera", "impact_fov_deg", 9.0) * strength * 40.0 * scale * (1.0 if fresh else 0.4)
	if fresh:
		hit.emit(source, strength)


func _process(delta: float) -> void:
	_since += delta
	# FOV-stoot: een veer (in stapjes, zoals CameraFx).
	var left := minf(delta, 0.1)
	while left > 0.0:
		var h := minf(left, 1.0 / 120.0)
		_fov_vel += (-fov_kick * Tuning.get_f("camera", "impact_fov_stiffness", 120.0) - _fov_vel * Tuning.get_f("camera", "impact_fov_damping", 14.0)) * h
		fov_kick += _fov_vel * h
		left -= h
	if _alpha <= 0.001:
		_rect.visible = false
		return
	# Eerst wit, binnen ±0,06 s naar de kleur van de klap, dan uitdoven.
	_color = _color.lerp(_tint, minf(1.0, delta * 16.0))
	_alpha = move_toward(_alpha, 0.0, delta * Tuning.get_f("camera", "impact_flash_fade", 2.6))
	_rect.visible = true
	_rect.color = Color(_color, _alpha)
