extends GdUnitTestSuite
## The mouse virtual stick while the cursor is captured (M1 review gate): a captured cursor stays
## at the screen center, so `InputRouter` adds up the mouse's motion instead of reading where the
## cursor is.

var _saved_device: InputRouter.Device
var _saved_seen: bool


func before_test() -> void:
	_saved_device = InputRouter.last_device
	_saved_seen = InputRouter._mouse_seen
	InputRouter.last_device = InputRouter.Device.KEYBOARD_MOUSE
	InputRouter.recenter_mouse()


func after_test() -> void:
	InputRouter.recenter_mouse()
	InputRouter._mouse_seen = _saved_seen
	InputRouter.last_device = _saved_device
	Settings.values.clear()


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = relative
	return event


func test_accumulate_adds_motion() -> void:
	var offset: Vector2 = InputRouter.accumulate_mouse_offset(Vector2(10, 0), Vector2(5, -4), 300.0)
	assert_vector(offset).is_equal(Vector2(15, -4))


func test_accumulate_is_held_at_the_max_radius() -> void:
	var offset: Vector2 = InputRouter.accumulate_mouse_offset(
		Vector2(290, 0), Vector2(500, 0), 300.0
	)
	assert_vector(offset).is_equal_approx(Vector2(300, 0), Vector2(0.001, 0.001))
	# Moving back eases off at once: no motion is "stored" beyond the edge.
	offset = InputRouter.accumulate_mouse_offset(offset, Vector2(-100, 0), 300.0)
	assert_vector(offset).is_equal_approx(Vector2(200, 0), Vector2(0.001, 0.001))


func test_mouse_motion_events_move_the_stick() -> void:
	InputRouter.observe_event(_motion(Vector2(40, 0)))
	InputRouter.observe_event(_motion(Vector2(20, -30)))
	assert_vector(InputRouter._mouse_offset).is_equal(Vector2(60, -30))
	# The default radius is 0.35 of the viewport height: far more than this.
	InputRouter.observe_event(_motion(Vector2(5000, 0)))
	var radius: float = (
		InputRouter.DEFAULT_MOUSE_RADIUS * InputRouter.get_viewport().get_visible_rect().size.y
	)
	assert_float(InputRouter._mouse_offset.length()).is_equal_approx(radius, 0.01)


func test_switching_to_the_gamepad_recenters_the_stick() -> void:
	InputRouter.observe_event(_motion(Vector2(80, 0)))
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.pressed = true
	InputRouter.observe_event(button)
	assert_vector(InputRouter._mouse_offset).is_equal(Vector2.ZERO)


func test_mouse_flight_active_needs_mouse_flight_and_the_mouse() -> void:
	InputRouter._mouse_seen = true
	assert_bool(InputRouter.mouse_flight_active()).is_true()
	Settings.set_value(InputRouter.SETTING_MOUSE_FLIGHT, false)
	assert_bool(InputRouter.mouse_flight_active()).is_false()
	Settings.values.clear()
	InputRouter.last_device = InputRouter.Device.GAMEPAD
	assert_bool(InputRouter.mouse_flight_active()).is_false()


func test_captured_cursor_uses_the_added_up_motion() -> void:
	var view: Vector2 = Vector2(1920, 1080)
	# A captured cursor sits at the center whatever the mouse does.
	var offset: Vector2 = InputRouter.virtual_stick_offset(
		true, Vector2(120, -40), view * 0.5, view
	)
	assert_vector(offset).is_equal(Vector2(120, -40))


func test_visible_cursor_uses_its_position() -> void:
	var view: Vector2 = Vector2(1920, 1080)
	var offset: Vector2 = InputRouter.virtual_stick_offset(
		false, Vector2(120, -40), Vector2(1060, 500), view
	)
	assert_vector(offset).is_equal(Vector2(100, -40))
