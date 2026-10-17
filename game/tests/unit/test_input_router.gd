extends GdUnitTestSuite
## Every action named in `InputRouter.ACTIONS` must exist in the InputMap with at least one
## keyboard/mouse event and at least one gamepad event (the game is gamepad-first).

## Pitch/yaw are steered by the mouse position (virtual joystick), which `InputRouter` reads
## directly in the flight task, so they have no keyboard/mouse action event.
const MOUSE_STEERED: PackedStringArray = ["pitch_up", "pitch_down", "yaw_left", "yaw_right"]

## The GDD (section 5) gives vertical strafe no gamepad button yet; the flight task decides.
const NO_GAMEPAD_YET: PackedStringArray = ["thrust_up", "thrust_down"]


func test_actions_list_is_not_empty() -> void:
	assert_array(InputRouter.ACTIONS).is_not_empty()


func test_every_action_exists_in_input_map() -> void:
	for action: String in InputRouter.ACTIONS:
		(
			assert_bool(InputMap.has_action(action))
			. override_failure_message("Action '%s' is not in project.godot" % action)
			. is_true()
		)


func test_every_action_has_a_gamepad_event() -> void:
	for action: String in InputRouter.ACTIONS:
		if action in NO_GAMEPAD_YET:
			continue
		var has_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				has_pad = true
		(
			assert_bool(has_pad)
			. override_failure_message("Action '%s' has no gamepad binding" % action)
			. is_true()
		)


func test_every_action_has_a_keyboard_or_mouse_event() -> void:
	for action: String in InputRouter.ACTIONS:
		if action in MOUSE_STEERED:
			continue
		var has_kbm: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey or event is InputEventMouseButton:
				has_kbm = true
		(
			assert_bool(has_kbm)
			. override_failure_message("Action '%s' has no keyboard/mouse binding" % action)
			. is_true()
		)


func test_actions_have_no_duplicates() -> void:
	var seen: Dictionary = {}
	for action: String in InputRouter.ACTIONS:
		(
			assert_bool(seen.has(action))
			. override_failure_message("Duplicate action '%s'" % action)
			. is_false()
		)
		seen[action] = true
