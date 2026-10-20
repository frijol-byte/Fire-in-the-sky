extends GdUnitTestSuite
## F1 / F12 and the Select / Back + Start gamepad chords.


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _button(index: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event


func test_f1_toggles_the_overlay_and_f12_captures() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	assert_int(hotkeys.feed(_key(KEY_F1))).is_equal(DevHotkeys.Command.TOGGLE_OVERLAY)
	assert_int(hotkeys.feed(_key(KEY_F12))).is_equal(DevHotkeys.Command.CAPTURE_BUG)


func test_key_release_echo_and_other_keys_do_nothing() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	assert_int(hotkeys.feed(_key(KEY_F1, false))).is_equal(DevHotkeys.Command.NONE)
	assert_int(hotkeys.feed(_key(KEY_F12, true, true))).is_equal(DevHotkeys.Command.NONE)
	assert_int(hotkeys.feed(_key(KEY_A))).is_equal(DevHotkeys.Command.NONE)


func test_select_alone_toggles_the_overlay_when_released() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	assert_int(hotkeys.feed(_button(JOY_BUTTON_BACK, true))).is_equal(DevHotkeys.Command.NONE)
	assert_int(hotkeys.feed(_button(JOY_BUTTON_BACK, false))).is_equal(
		DevHotkeys.Command.TOGGLE_OVERLAY
	)


func test_select_then_start_captures_and_does_not_open_the_overlay() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	hotkeys.feed(_button(JOY_BUTTON_BACK, true))
	assert_int(hotkeys.feed(_button(JOY_BUTTON_START, true))).is_equal(
		DevHotkeys.Command.CAPTURE_BUG
	)
	assert_int(hotkeys.feed(_button(JOY_BUTTON_START, false))).is_equal(DevHotkeys.Command.NONE)
	assert_int(hotkeys.feed(_button(JOY_BUTTON_BACK, false))).is_equal(DevHotkeys.Command.NONE)


func test_start_then_select_also_captures() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	hotkeys.feed(_button(JOY_BUTTON_START, true))
	assert_int(hotkeys.feed(_button(JOY_BUTTON_BACK, true))).is_equal(
		DevHotkeys.Command.CAPTURE_BUG
	)
	hotkeys.feed(_button(JOY_BUTTON_BACK, false))
	hotkeys.feed(_button(JOY_BUTTON_START, false))


func test_select_works_again_after_a_chord() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	hotkeys.feed(_button(JOY_BUTTON_BACK, true))
	hotkeys.feed(_button(JOY_BUTTON_START, true))
	hotkeys.feed(_button(JOY_BUTTON_START, false))
	hotkeys.feed(_button(JOY_BUTTON_BACK, false))
	hotkeys.feed(_button(JOY_BUTTON_BACK, true))
	assert_int(hotkeys.feed(_button(JOY_BUTTON_BACK, false))).is_equal(
		DevHotkeys.Command.TOGGLE_OVERLAY
	)


func test_start_alone_does_nothing() -> void:
	var hotkeys: DevHotkeys = DevHotkeys.new()
	assert_int(hotkeys.feed(_button(JOY_BUTTON_START, true))).is_equal(DevHotkeys.Command.NONE)
	assert_int(hotkeys.feed(_button(JOY_BUTTON_START, false))).is_equal(DevHotkeys.Command.NONE)
