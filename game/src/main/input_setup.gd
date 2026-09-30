class_name InputSetup
extends RefCounted
## Standaardtoetsen. Fysieke toetscodes, zodat WASD op AZERTY vanzelf ZQSD wordt.
## Toetsen aanpassen in het spel komt later (GDD §7).

const KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_CTRL,
	"toggle_fly": KEY_V,
	"toggle_stats": KEY_F3,
}


static func ensure() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, ev)
	if not InputMap.has_action("dig"):
		InputMap.add_action("dig")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dig", mb)
