extends GdUnitTestSuite


func test_new_controls_are_idle() -> void:
	assert_bool(ShipControls.new().is_idle()).is_true()


func test_any_field_makes_controls_not_idle() -> void:
	var c: ShipControls = ShipControls.new()
	c.target_cmd = ShipControls.Target.CYCLE_SUBSYSTEM
	assert_bool(c.is_idle()).is_false()
	c = ShipControls.new()
	c.thrust.z = 0.1
	assert_bool(c.is_idle()).is_false()
