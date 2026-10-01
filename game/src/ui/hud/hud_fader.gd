class_name HudFader
extends Control
## HUD-onderdeel met een zichtbaarheid uit de instellingen (zoals DRG): uit, dynamisch of altijd.
## Dynamisch: in beeld na `poke()` (er veranderde iets) of zolang `active` waar is, daarna vervagen.

var mode_key := ""
var hold := 3.0 # seconden in beeld na een poke
var active := false # bv. zolang je iets draagt: blijven tonen
var blocked := false # nu niet tonen, wat de instelling ook is (bv. gereedschap in de stoel)
## Enkel tonen als er iets te tonen is (prompt, draagkaartje): dan betekent "altijd" "zolang actief".
var needs_content := false
var _until := 0.0
var _alpha := 0.0


func poke(seconds := -1.0) -> void:
	_until = maxf(_until, _now() + (hold if seconds < 0.0 else seconds))


func _process(delta: float) -> void:
	var mode := int(Settings.get_value(mode_key)) if mode_key != "" else Settings.HUD_ALWAYS
	var want := 0.0
	if blocked:
		want = 0.0
	elif mode == Settings.HUD_ALWAYS:
		want = 1.0 if not needs_content or active or _now() < _until else 0.0
	elif mode == Settings.HUD_DYNAMIC:
		want = 1.0 if active or _now() < _until else 0.0
	# Snel in beeld, traag weg.
	_alpha = move_toward(_alpha, want, delta * (6.0 if want > _alpha else 1.6))
	modulate.a = _alpha
	visible = _alpha > 0.01


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
