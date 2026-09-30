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
	"tool_1": KEY_1,
	"tool_2": KEY_2,
	"interact": KEY_E,
	"toggle_tuning": KEY_F1,
}


static func ensure() -> void:
	for action: String in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = KEYS[action]
		InputMap.action_add_event(action, ev)
	for pair in [["tool_prev", MOUSE_BUTTON_WHEEL_UP], ["tool_next", MOUSE_BUTTON_WHEEL_DOWN]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var wheel := InputEventMouseButton.new()
			wheel.button_index = pair[1]
			InputMap.action_add_event(pair[0], wheel)
	if not InputMap.has_action("dig"):
		InputMap.add_action("dig")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("dig", mb)
