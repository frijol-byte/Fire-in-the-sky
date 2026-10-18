extends GdUnitTestSuite
## Pure math in `InputRouter`: the mouse virtual stick, the target double-tap and device
## detection from raw events.


func test_mouse_stick_inside_deadzone_is_zero() -> void:
	assert_vector(InputRouter.mouse_stick(Vector2(10.0, -10.0), 20.0, 300.0)).is_equal(Vector2.ZERO)


func test_mouse_stick_at_max_radius_is_one() -> void:
	var stick: Vector2 = InputRouter.mouse_stick(Vector2(300.0, 0.0), 20.0, 300.0)
	assert_vector(stick).is_equal_approx(Vector2(1.0, 0.0), Vector2(0.0001, 0.0001))


func test_mouse_stick_beyond_max_radius_is_clamped() -> void:
	var stick: Vector2 = InputRouter.mouse_stick(Vector2(0.0, 900.0), 20.0, 300.0)
	assert_vector(stick).is_equal_approx(Vector2(0.0, 1.0), Vector2(0.0001, 0.0001))


func test_mouse_stick_is_proportional_between_deadzone_and_max() -> void:
	# Halfway between the deadzone ring (20) and the max radius (300) is 160 px.
	var stick: Vector2 = InputRouter.mouse_stick(Vector2(-160.0, 0.0), 20.0, 300.0)
	assert_vector(stick).is_equal_approx(Vector2(-0.5, 0.0), Vector2(0.0001, 0.0001))


func test_mouse_stick_keeps_direction_on_diagonals() -> void:
	var stick: Vector2 = InputRouter.mouse_stick(Vector2(120.0, -120.0), 20.0, 300.0)
	assert_float(stick.x).is_equal_approx(-stick.y, 0.0001)
	assert_float(stick.x).is_greater(0.0)


func test_mouse_stick_applies_exponent() -> void:
	var stick: Vector2 = InputRouter.mouse_stick(Vector2(160.0, 0.0), 20.0, 300.0, 2.0)
	assert_vector(stick).is_equal_approx(Vector2(0.25, 0.0), Vector2(0.0001, 0.0001))


func test_mouse_stick_with_degenerate_radii_is_zero() -> void:
	assert_vector(InputRouter.mouse_stick(Vector2(100.0, 0.0), 50.0, 50.0)).is_equal(Vector2.ZERO)


func test_target_tap_inside_window_is_double_tap() -> void:
	assert_int(InputRouter.resolve_target_tap(5, 18)).is_equal(ShipControls.Target.NEAREST_ANY)
	assert_int(InputRouter.resolve_target_tap(18, 18)).is_equal(ShipControls.Target.NEAREST_ANY)


func test_target_tap_outside_window_is_single_tap() -> void:
	assert_int(InputRouter.resolve_target_tap(19, 18)).is_equal(ShipControls.Target.NEAREST_HOSTILE)


func _key(pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = pressed
	return event


func _axis_motion(value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event


func test_event_device_classifies_events() -> void:
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.pressed = true
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.pressed = true
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.relative = Vector2(3.0, 0.0)
	assert_int(InputRouter.event_device(_key(true))).is_equal(InputRouter.Device.KEYBOARD_MOUSE)
	assert_int(InputRouter.event_device(click)).is_equal(InputRouter.Device.KEYBOARD_MOUSE)
	assert_int(InputRouter.event_device(move)).is_equal(InputRouter.Device.KEYBOARD_MOUSE)
	assert_int(InputRouter.event_device(button)).is_equal(InputRouter.Device.GAMEPAD)
	assert_int(InputRouter.event_device(_axis_motion(0.9))).is_equal(InputRouter.Device.GAMEPAD)


func test_event_device_ignores_stick_drift_releases_and_still_mouse() -> void:
	var still: InputEventMouseMotion = InputEventMouseMotion.new()
	assert_int(InputRouter.event_device(_axis_motion(0.1))).is_equal(-1)
	assert_int(InputRouter.event_device(_key(false))).is_equal(-1)
	assert_int(InputRouter.event_device(still)).is_equal(-1)
