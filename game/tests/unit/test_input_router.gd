extends GdUnitTestSuite
## Every action named in `InputRouter.ACTIONS` must exist in the InputMap with at least one
## keyboard/mouse event and at least one gamepad event (the game is gamepad-first).

## Pitch/yaw are steered by the mouse position (virtual joystick), which `InputRouter` reads
## directly (see `InputRouter.mouse_stick`), so they have no keyboard/mouse action event.
const MOUSE_STEERED: PackedStringArray = ["pitch_up", "pitch_down", "yaw_left", "yaw_right"]
## Actions with no gamepad button on purpose:
## - flight_assist_off: the owner will give it a new button or trigger later (keyboard: Shift).
const NO_GAMEPAD_YET: PackedStringArray = ["flight_assist_off"]


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


func test_exempt_actions_really_have_no_gamepad_event() -> void:
	# Keeps the exemption list honest: remove an action from it once it gets a button.
	for action: String in NO_GAMEPAD_YET:
		for event: InputEvent in InputMap.action_get_events(action):
			(
				assert_bool(event is InputEventJoypadButton or event is InputEventJoypadMotion)
				. override_failure_message("'%s' has a gamepad event; drop its exemption" % action)
				. is_false()
			)


func _pad_axis_of(action: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion: InputEventJoypadMotion = event
			result.append(Vector2(motion.axis, motion.axis_value))
	return result


func test_gamepad_flight_layout() -> void:
	# (axis index, direction): RT = 5, LT = 4, left stick X = 0, left stick Y = 1.
	assert_array(_pad_axis_of("thrust_forward")).is_equal([Vector2(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	assert_array(_pad_axis_of("thrust_back")).is_equal([Vector2(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	assert_array(_pad_axis_of("thrust_up")).is_equal([Vector2(JOY_AXIS_LEFT_Y, -1.0)])
	assert_array(_pad_axis_of("thrust_down")).is_equal([Vector2(JOY_AXIS_LEFT_Y, 1.0)])
	assert_array(_pad_axis_of("strafe_left")).is_equal([Vector2(JOY_AXIS_LEFT_X, -1.0)])
	assert_array(_pad_axis_of("strafe_right")).is_equal([Vector2(JOY_AXIS_LEFT_X, 1.0)])


func test_paddles_and_b_are_unbound_on_the_gamepad() -> void:
	for action: String in InputRouter.ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				var index: int = (event as InputEventJoypadButton).button_index
				(
					assert_bool(index in [JOY_BUTTON_B, JOY_BUTTON_PADDLE1, JOY_BUTTON_PADDLE2])
					. override_failure_message("'%s' is on a button M1-F1 freed" % action)
					. is_false()
				)


func _pad_buttons_of(action: String) -> Array[int]:
	var result: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			result.append((event as InputEventJoypadButton).button_index)
	return result


func test_fire_is_on_a_and_x_and_boost_moved_to_l3() -> void:
	# M2-T2 (owner decision 2026-10-25): RT/LT are throttle, so A / X fire and boost moves to L3.
	assert_array(_pad_buttons_of("fire_primary")).is_equal([JOY_BUTTON_A])
	assert_array(_pad_buttons_of("fire_secondary")).is_equal([JOY_BUTTON_X])
	assert_array(_pad_buttons_of("boost")).is_equal([JOY_BUTTON_LEFT_STICK])


func test_nothing_else_shares_a_or_the_fire_buttons() -> void:
	# A is fire only; boost and cruise drive may share L3 (cruise has no gameplay until M4).
	for action: String in InputRouter.ACTIONS:
		if action in ["fire_primary"]:
			continue
		assert_array(_pad_buttons_of(action)).not_contains([JOY_BUTTON_A])


func test_target_nearest_is_on_y_and_x_is_only_secondary_fire() -> void:
	# M2-T3: target_nearest left X for Y (shared with interact, which has no gameplay until M4).
	assert_array(_pad_buttons_of("target_nearest")).is_equal([JOY_BUTTON_Y])
	assert_array(_pad_buttons_of("interact")).is_equal([JOY_BUTTON_Y])
	for action: String in InputRouter.ACTIONS:
		if action != "fire_secondary":
			assert_array(_pad_buttons_of(action)).not_contains([JOY_BUTTON_X])


func test_look_at_target_is_a_hold_on_paddle_4_and_b() -> void:
	assert_bool(InputRouter.ACTIONS.has("look_at_target")).is_true()
	assert_array(_pad_buttons_of("look_at_target")).is_equal([JOY_BUTTON_PADDLE4])
	var keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events("look_at_target"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	assert_array(keys).is_equal([KEY_B])
