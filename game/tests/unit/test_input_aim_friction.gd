extends GdUnitTestSuite
## Reticle friction (M2-T3): `InputRouter.aim_friction` slows the aim stick, but not the free-look
## camera, and `look_at_target` is a plain hold.


func before_test() -> void:
	Settings.values.clear()
	Settings.set_value(InputRouter.SETTING_STICK_DEADZONE, 0.0)
	Settings.set_value(InputRouter.SETTING_CURVE_EXPONENT, 1.0)


func after_test() -> void:
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	InputRouter.aim_friction = 1.0
	Settings.values.clear()


func test_no_friction_leaves_the_aim_alone() -> void:
	Input.action_press("yaw_right", 0.8)
	assert_float(InputRouter.build_controls().rotate.y).is_equal_approx(0.8, 0.0001)


func test_friction_scales_the_aim_stick() -> void:
	Input.action_press("yaw_right", 0.8)
	Input.action_press("pitch_up", 1.0)
	InputRouter.aim_friction = 0.5
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.rotate.y).is_equal_approx(0.4, 0.0001)
	assert_float(c.rotate.x).is_equal_approx(0.5, 0.0001)


func test_friction_leaves_roll_and_thrust_alone() -> void:
	Input.action_press("roll_right")
	Input.action_press("thrust_forward")
	InputRouter.aim_friction = 0.3
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.rotate.z).is_equal(1.0)
	assert_float(c.thrust.z).is_equal(1.0)


func test_the_free_look_camera_is_not_slowed_by_friction() -> void:
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Input.action_press("free_look")
	Input.action_press("yaw_right")
	InputRouter.aim_friction = 0.3
	assert_vector(InputRouter.free_look_vector()).is_equal(Vector2(1.0, 0.0))


func test_look_at_target_is_a_hold_that_free_look_overrides() -> void:
	assert_bool(InputRouter.look_at_target_active()).is_false()
	Input.action_press("look_at_target")
	assert_bool(InputRouter.look_at_target_active()).is_true()
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Input.action_press("free_look")
	assert_bool(InputRouter.look_at_target_active()).is_false()
