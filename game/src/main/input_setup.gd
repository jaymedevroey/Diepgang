class_name InputSetup
extends RefCounted
## Standaardtoetsen. Fysieke toetscodes, zodat WASD op AZERTY vanzelf ZQSD wordt.
## Omzetten kan in de instellingen (Settings.BINDABLE).

const KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"crouch": KEY_CTRL,
	"toggle_stats": KEY_F3,
	"tool_1": KEY_1,
	"tool_2": KEY_2,
	"interact": KEY_E,
	"horn": KEY_H,
	"mol_view": KEY_C,
	"sonar_ping": KEY_F,
	"beacon": KEY_G,
	"skip_cinematic": KEY_SPACE,
	"scan": KEY_Q,
}
## Ontwikkelaarstoetsen: de actie bestaat altijd (de code mag ernaar vragen), maar krijgt enkel in
## de ontwikkelaarsmodus een toets (CmdArgs.dev_mode: debug-build of --dev). In de demo doet V niets
## en opent F1 geen tuningmenu (gevoel-07, ui-06).
const DEV_KEYS := {
	"toggle_fly": KEY_V,
	"toggle_tuning": KEY_F1,
}


## De toetsen die deze build krijgt: in de ontwikkelaarsmodus ook de ontwikkelaarstoetsen.
static func keys_for(dev: bool) -> Dictionary:
	var keys := KEYS.duplicate()
	if dev:
		keys.merge(DEV_KEYS)
	return keys


static func ensure() -> void:
	var keys := keys_for(CmdArgs.dev_mode())
	for action: String in KEYS.keys() + DEV_KEYS.keys():
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		if keys.has(action):
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
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
