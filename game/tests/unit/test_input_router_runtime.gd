extends GdUnitTestSuite
## The `InputRouter` autoload end to end: simulated actions in, `ShipControls` out; device
## switching and its signal; glyph text.

## Keep in step with `NO_GAMEPAD_YET` in test_input_router.gd.
const NO_GAMEPAD_YET: PackedStringArray = ["flight_assist_off", "fire_primary", "fire_secondary"]

var _saved_device: InputRouter.Device


func before_test() -> void:
	_saved_device = InputRouter.last_device
	InputRouter.last_device = InputRouter.Device.GAMEPAD


func after_test() -> void:
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	Settings.values.clear()
	InputRouter.last_device = _saved_device


func test_idle_input_gives_idle_controls() -> void:
	assert_bool(InputRouter.build_controls().is_idle()).is_true()


func test_full_forward_and_strafe_keys_give_full_thrust() -> void:
	Input.action_press("thrust_forward")
	Input.action_press("strafe_left")
	var c: ShipControls = InputRouter.build_controls()
	assert_vector(c.thrust).is_equal(Vector3(-1.0, 0.0, 1.0))


func test_opposite_keys_cancel() -> void:
	Input.action_press("thrust_forward")
	Input.action_press("thrust_back")
	assert_float(InputRouter.build_controls().thrust.z).is_equal(0.0)


func test_vertical_thrust_and_roll() -> void:
	Input.action_press("thrust_up")
	Input.action_press("roll_right")
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.thrust.y).is_equal(1.0)
	assert_float(c.rotate.z).is_equal(1.0)


func test_stick_inside_deadzone_is_ignored_and_pitch_up_is_positive() -> void:
	Input.action_press("pitch_up", 0.1)
	assert_float(InputRouter.build_controls().rotate.x).is_equal(0.0)
	Input.action_press("pitch_up", 1.0)
	assert_float(InputRouter.build_controls().rotate.x).is_equal(1.0)


func test_invert_y_flips_pitch_only() -> void:
	Input.action_press("pitch_up")
	Input.action_press("yaw_right")
	Settings.set_value(InputRouter.SETTING_INVERT_Y, true)
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.rotate.x).is_equal(-1.0)
	assert_float(c.rotate.y).is_equal(1.0)


func test_response_curve_setting_changes_a_half_stick() -> void:
	Settings.set_value(InputRouter.SETTING_STICK_DEADZONE, 0.0)
	Settings.set_value(InputRouter.SETTING_CURVE_EXPONENT, 2.0)
	Input.action_press("yaw_right", 0.5)
	assert_float(InputRouter.build_controls().rotate.y).is_equal_approx(0.25, 0.0001)


func test_buttons_map_to_fields() -> void:
	Input.action_press("boost")
	Input.action_press("flight_assist_off")
	Input.action_press("fire_primary")
	Input.action_press("fire_secondary")
	var c: ShipControls = InputRouter.build_controls()
	assert_bool(c.boost).is_true()
	assert_bool(c.fa_off).is_true()
	assert_bool(c.fire_primary).is_true()
	assert_bool(c.fire_secondary).is_true()


func test_one_shot_commands() -> void:
	Input.action_press("device_2")
	Input.action_press("interact")
	var c: ShipControls = InputRouter.build_controls()
	assert_int(c.device).is_equal(2)
	assert_bool(c.interact).is_true()


func test_mouse_does_not_steer_before_it_moves() -> void:
	InputRouter.last_device = InputRouter.Device.KEYBOARD_MOUSE
	assert_vector(InputRouter.build_controls().rotate).is_equal(Vector3.ZERO)


func test_switching_device_emits_signal_once() -> void:
	InputRouter.last_device = InputRouter.Device.KEYBOARD_MOUSE
	var pressed: InputEventJoypadButton = InputEventJoypadButton.new()
	pressed.pressed = true
	var received: Array[int] = []
	var listener: Callable = func(device: int) -> void: received.append(device)
	Events.input_device_changed.connect(listener)
	InputRouter.observe_event(pressed)
	InputRouter.observe_event(pressed)
	Events.input_device_changed.disconnect(listener)
	assert_array(received).is_equal([InputRouter.Device.GAMEPAD])
	assert_int(InputRouter.last_device).is_equal(InputRouter.Device.GAMEPAD)


func test_glyphs_for_gamepad() -> void:
	assert_str(InputRouter.glyph_for(&"thrust_forward", InputRouter.Device.GAMEPAD)).is_equal("RT")
	assert_str(InputRouter.glyph_for(&"thrust_back", InputRouter.Device.GAMEPAD)).is_equal("LT")
	assert_str(InputRouter.glyph_for(&"boost", InputRouter.Device.GAMEPAD)).is_equal("A")
	assert_str(InputRouter.glyph_for(&"thrust_up", InputRouter.Device.GAMEPAD)).is_equal(
		"Left stick up"
	)
	# No gamepad button until M2-T2 (fire) or the owner's next layout call (drift).
	assert_str(InputRouter.glyph_for(&"fire_primary", InputRouter.Device.GAMEPAD)).is_equal("--")
	assert_str(InputRouter.glyph_for(&"flight_assist_off", InputRouter.Device.GAMEPAD)).is_equal(
		"--"
	)


func test_glyphs_for_keyboard_and_mouse() -> void:
	assert_str(InputRouter.glyph_for(&"fire_primary", InputRouter.Device.KEYBOARD_MOUSE)).is_equal(
		"LMB"
	)
	(
		assert_str(InputRouter.glyph_for(&"thrust_forward", InputRouter.Device.KEYBOARD_MOUSE))
		. is_equal("W")
	)
	assert_str(InputRouter.glyph_for(&"yaw_left", InputRouter.Device.KEYBOARD_MOUSE)).is_equal(
		"Mouse"
	)


func test_glyph_follows_last_device() -> void:
	InputRouter.last_device = InputRouter.Device.GAMEPAD
	assert_str(InputRouter.glyph_for(&"thrust_forward")).is_equal("RT")
	InputRouter.last_device = InputRouter.Device.KEYBOARD_MOUSE
	assert_str(InputRouter.glyph_for(&"thrust_forward")).is_equal("W")


func test_glyph_for_unknown_action_is_empty() -> void:
	assert_str(InputRouter.glyph_for(&"no_such_action")).is_equal("")


func test_every_action_has_a_glyph_on_both_devices() -> void:
	for action: String in InputRouter.ACTIONS:
		for device: int in [InputRouter.Device.GAMEPAD, InputRouter.Device.KEYBOARD_MOUSE]:
			# Same exemptions as `NO_GAMEPAD_YET` in test_input_router.gd.
			if device == InputRouter.Device.GAMEPAD and action in NO_GAMEPAD_YET:
				continue
			var glyph: String = InputRouter.glyph_for(StringName(action), device)
			(
				assert_str(glyph)
				. override_failure_message("No glyph for '%s' on device %d" % [action, device])
				. is_not_equal("--")
			)
