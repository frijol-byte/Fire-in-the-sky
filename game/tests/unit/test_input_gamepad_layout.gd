extends GdUnitTestSuite
## The gamepad flight layout (M1-F1) through `InputRouter.build_controls`: RT is throttle, LT is
## brake, and the left stick is strafe (X) plus up/down (Y). The bindings themselves are checked
## in test_input_router.gd.

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


func test_rt_is_throttle_lt_is_brake_and_both_cancel() -> void:
	Input.action_press("thrust_forward", 1.0)
	assert_float(InputRouter.build_controls().thrust.z).is_equal(1.0)
	Input.action_release("thrust_forward")
	Input.action_press("thrust_back", 1.0)
	assert_float(InputRouter.build_controls().thrust.z).is_equal(-1.0)
	Input.action_press("thrust_forward", 1.0)
	assert_float(InputRouter.build_controls().thrust.z).is_equal(0.0)


func test_trigger_pull_is_analog_throttle() -> void:
	Settings.set_value(InputRouter.SETTING_STICK_DEADZONE, 0.0)
	Settings.set_value(InputRouter.SETTING_CURVE_EXPONENT, 1.0)
	Input.action_press("thrust_forward", 0.5)
	assert_float(InputRouter.build_controls().thrust.z).is_equal_approx(0.5, 0.0001)


func test_left_stick_y_is_vertical_thrust_and_stick_up_is_ship_up() -> void:
	# The stick pushed up is Y -1 on the pad, which the InputMap routes to `thrust_up`.
	Input.action_press("thrust_up", 1.0)
	var c: ShipControls = InputRouter.build_controls()
	assert_vector(c.thrust).is_equal(Vector3(0.0, 1.0, 0.0))
	Input.action_release("thrust_up")
	Input.action_press("thrust_down", 1.0)
	assert_vector(InputRouter.build_controls().thrust).is_equal(Vector3(0.0, -1.0, 0.0))


func test_left_stick_is_one_radial_stick_for_strafe_and_vertical() -> void:
	Settings.set_value(InputRouter.SETTING_STICK_DEADZONE, 0.0)
	Settings.set_value(InputRouter.SETTING_CURVE_EXPONENT, 1.0)
	Input.action_press("strafe_right", 0.6)
	Input.action_press("thrust_up", 0.8)
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.thrust.x).is_equal_approx(0.6, 0.0001)
	assert_float(c.thrust.y).is_equal_approx(0.8, 0.0001)
	assert_float(c.thrust.z).is_equal(0.0)


func test_thrust_leaves_pitch_yaw_and_roll_alone() -> void:
	Input.action_press("thrust_forward")
	Input.action_press("thrust_up")
	Input.action_press("strafe_left")
	assert_vector(InputRouter.build_controls().rotate).is_equal(Vector3.ZERO)
