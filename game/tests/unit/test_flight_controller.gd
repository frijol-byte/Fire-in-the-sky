extends GdUnitTestSuite
## `FlightController` math without physics: command mapping, per-axis limits, no overshoot.

const DT: float = 1.0 / 60.0

var _def: ShipDef


func before_test() -> void:
	_def = Content.ship(&"kestrel")


func _controls(thrust: Vector3 = Vector3.ZERO, rotate: Vector3 = Vector3.ZERO) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	controls.thrust = thrust
	controls.rotate = rotate
	return controls


func test_forward_command_points_down_negative_z() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(0, 0, 1))
	)
	assert_vector(target).is_equal_approx(Vector3(0, 0, -_def.max_speed), Vector3(0.01, 0.01, 0.01))


func test_reverse_command_uses_the_reverse_speed() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(0, 0, -1))
	)
	assert_float(target.z).is_equal_approx(_def.max_reverse_speed, 0.01)


func test_strafe_and_vertical_commands() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(1, -1, 0))
	)
	assert_float(target.x).is_equal_approx(_def.max_strafe_speed, 0.01)
	assert_float(target.y).is_equal_approx(-_def.max_vertical_speed, 0.01)


func test_command_is_limited_to_max_speed() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(1, 1, 1))
	)
	assert_float(target.length()).is_less_equal(_def.max_speed + 0.001)


func test_out_of_range_sticks_are_clamped() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(0, 0, 5))
	)
	assert_float(target.z).is_equal_approx(-_def.max_speed, 0.01)


func test_angular_command_signs_follow_the_stick_convention() -> void:
	var rates: Vector3 = _def.max_angular_rate_rad()
	var target: Vector3 = FlightController.commanded_angular_velocity(
		_def, _controls(Vector3.ZERO, Vector3.ONE)
	)
	assert_float(target.x).is_equal_approx(rates.x, 0.0001)
	assert_float(target.y).is_equal_approx(-rates.y, 0.0001)
	assert_float(target.z).is_equal_approx(-rates.z, 0.0001)


func test_one_tick_never_exceeds_the_thrust_limit() -> void:
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1)), Vector3.ZERO, Vector3.ZERO, DT
	)
	assert_float(result.linear.z).is_equal_approx(-_def.accel_forward() * DT, 0.0001)


func test_reverse_thrust_limits_braking_but_forward_thrust_limits_speeding_up() -> void:
	var moving: Vector3 = Vector3(0, 0, -100)
	var braking: FlightController.Result = FlightController.compute(
		_def, _controls(), moving, Vector3.ZERO, DT
	)
	assert_float(braking.linear.z - moving.z).is_equal_approx(_def.accel_reverse() * DT, 0.0001)
	var backing: FlightController.Result = FlightController.compute(
		_def, _controls(), Vector3(0, 0, 100), Vector3.ZERO, DT
	)
	assert_float(100.0 - backing.linear.z).is_equal_approx(_def.accel_forward() * DT, 0.0001)


func test_a_small_error_is_closed_proportionally_not_in_one_step() -> void:
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 0.5)), Vector3(0, 0, -89), Vector3.ZERO, DT
	)
	var fraction: float = FlightController.response_fraction(_def.fa_linear_gain, DT)
	assert_float(result.linear.z).is_equal_approx(-89.0 - fraction, 0.0001)


func test_the_response_converges_without_crossing_the_target() -> void:
	var velocity: Vector3 = Vector3(0, 0, -150)
	var angular: Vector3 = Vector3(0, 1.0, 0)
	for tick: int in 600:
		var result: FlightController.Result = FlightController.compute(
			_def, _controls(Vector3(0, 0, 0.5)), velocity, angular, DT
		)
		velocity = result.linear
		angular = result.angular
		assert_float(velocity.z).is_less_equal(-_def.max_speed * 0.5 + 0.0001)
		assert_float(angular.y).is_greater_equal(-0.0001)
	assert_float(velocity.z).is_equal_approx(-_def.max_speed * 0.5, 0.01)
	assert_float(angular.y).is_equal_approx(0.0, 0.001)


func test_response_fraction_is_the_exact_exponential_step() -> void:
	assert_float(FlightController.response_fraction(6.0, 0.0)).is_equal_approx(0.0, 0.00001)
	assert_float(FlightController.response_fraction(6.0, 1.0)).is_equal_approx(
		1.0 - exp(-6.0), 0.00001
	)
	# A huge gain closes the whole error but never more.
	assert_float(FlightController.response_fraction(1000.0, DT)).is_less_equal(1.0)
