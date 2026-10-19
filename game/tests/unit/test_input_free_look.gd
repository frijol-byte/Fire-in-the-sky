extends GdUnitTestSuite
## Free look: with the setting on, holding `free_look` moves the aim input from the ship to the
## camera (`InputRouter.free_look_vector`).


func before_test() -> void:
	Settings.values.clear()


func after_test() -> void:
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)
	Settings.values.clear()


func test_free_look_does_nothing_unless_the_setting_is_on() -> void:
	Input.action_press("free_look")
	Input.action_press("yaw_right")
	assert_bool(InputRouter.free_look_active()).is_false()
	assert_vector(InputRouter.free_look_vector()).is_equal(Vector2.ZERO)
	assert_float(InputRouter.build_controls().rotate.y).is_equal(1.0)


func test_held_free_look_moves_the_aim_input_from_the_ship_to_the_camera() -> void:
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Input.action_press("yaw_right")
	Input.action_press("pitch_up")
	# Not held: the stick aims the ship and the camera ignores it.
	assert_vector(InputRouter.free_look_vector()).is_equal(Vector2.ZERO)
	assert_float(InputRouter.build_controls().rotate.y).is_equal(1.0)
	Input.action_press("free_look")
	assert_bool(InputRouter.free_look_active()).is_true()
	assert_vector(InputRouter.free_look_vector()).is_equal(Vector2(1.0, 1.0))
	var c: ShipControls = InputRouter.build_controls()
	assert_float(c.rotate.x).is_equal(0.0)
	assert_float(c.rotate.y).is_equal(0.0)


func test_free_look_follows_the_invert_y_setting_and_roll_still_works() -> void:
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	Settings.set_value(InputRouter.SETTING_INVERT_Y, true)
	Input.action_press("free_look")
	Input.action_press("pitch_up")
	Input.action_press("roll_right")
	assert_float(InputRouter.free_look_vector().y).is_equal(-1.0)
	assert_float(InputRouter.build_controls().rotate.z).is_equal(1.0)
