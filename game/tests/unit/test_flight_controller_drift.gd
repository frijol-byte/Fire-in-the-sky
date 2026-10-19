extends GdUnitTestSuite
## `FlightController` math for FA off (drift) and boost, without physics.

const DT: float = 1.0 / 60.0

var _def: ShipDef


func before_test() -> void:
	_def = Content.ship(&"kestrel")


func _controls(thrust: Vector3 = Vector3.ZERO, fa_off: bool = false) -> ShipControls:
	var controls: ShipControls = ShipControls.new()
	controls.thrust = thrust
	controls.fa_off = fa_off
	return controls


func test_fa_off_keeps_the_velocity_when_the_sticks_are_idle() -> void:
	var velocity: Vector3 = Vector3(20.0, -5.0, -120.0)
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3.ZERO, true), velocity, Vector3.ZERO, DT
	)
	assert_vector(result.linear).is_equal(velocity)


func test_fa_on_pulls_the_same_velocity_toward_zero() -> void:
	var velocity: Vector3 = Vector3(20.0, -5.0, -120.0)
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3.ZERO, false), velocity, Vector3.ZERO, DT
	)
	assert_float(result.linear.length()).is_less(velocity.length())


func test_fa_off_thrust_accelerates_at_thrust_over_mass() -> void:
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1), true), Vector3.ZERO, Vector3.ZERO, DT
	)
	assert_float(result.linear.z).is_equal_approx(-_def.accel_forward() * DT, 0.0001)


func test_fa_off_half_stick_is_half_thrust() -> void:
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0.5, 0, 0), true), Vector3.ZERO, Vector3.ZERO, DT
	)
	assert_float(result.linear.x).is_equal_approx(0.5 * _def.accel_lateral() * DT, 0.0001)


func test_fa_off_thrust_cannot_push_past_the_cap() -> void:
	var velocity: Vector3 = Vector3(0, 0, -_def.max_speed + 0.01)
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1), true), velocity, Vector3.ZERO, DT
	)
	assert_float(result.linear.length()).is_less_equal(_def.max_speed + 0.0001)


func test_fa_off_keeps_speed_that_is_already_above_the_cap() -> void:
	var velocity: Vector3 = Vector3(0, 0, -_def.boost_max_speed)
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1), true), velocity, Vector3.ZERO, DT
	)
	assert_float(result.linear.length()).is_equal_approx(_def.boost_max_speed, 0.0001)


func test_fa_off_thrust_can_still_slow_the_ship_down() -> void:
	var velocity: Vector3 = Vector3(0, 0, -100.0)
	var result: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, -1), true), velocity, Vector3.ZERO, DT
	)
	assert_float(result.linear.z).is_equal_approx(-100.0 + _def.accel_reverse() * DT, 0.0001)


func test_rotation_is_assisted_with_fa_off() -> void:
	var controls: ShipControls = _controls(Vector3.ZERO, true)
	controls.rotate = Vector3(0, 1, 0)
	var result: FlightController.Result = FlightController.compute(
		_def, controls, Vector3.ZERO, Vector3.ZERO, DT
	)
	assert_float(result.angular.y).is_not_equal(0.0)


func test_boost_forces_full_forward_throttle() -> void:
	var thrust: Vector3 = FlightController.effective_thrust(_controls(Vector3(0.3, 0, -0.5)), true)
	assert_vector(thrust).is_equal(Vector3(0.3, 0, 1.0))
	thrust = FlightController.effective_thrust(_controls(Vector3(0.3, 0, -0.5)), false)
	assert_vector(thrust).is_equal(Vector3(0.3, 0, -0.5))


func test_boost_raises_the_commanded_speed_to_the_boost_max() -> void:
	var target: Vector3 = FlightController.commanded_linear_velocity(
		_def, _controls(Vector3(0, 0, 1)), true
	)
	assert_float(target.z).is_equal_approx(-_def.boost_max_speed, 0.001)


func test_boost_multiplies_forward_thrust() -> void:
	var plain: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1)), Vector3.ZERO, Vector3.ZERO, DT, false
	)
	var boosted: FlightController.Result = FlightController.compute(
		_def, _controls(Vector3(0, 0, 1)), Vector3.ZERO, Vector3.ZERO, DT, true
	)
	assert_float(boosted.linear.z / plain.linear.z).is_equal_approx(
		_def.boost_thrust_multiplier, 0.001
	)


func test_limit_excess_leaves_speed_under_the_cap_alone() -> void:
	var velocity: Vector3 = Vector3(10, 0, -100)
	assert_vector(FlightController.limit_excess(velocity, 180.0, 1.0, DT)).is_equal(velocity)


func test_limit_excess_removes_95_percent_in_the_bleed_time() -> void:
	var velocity: Vector3 = Vector3(0, 0, -320.0)
	var ticks: int = roundi(1.0 / DT)
	for _tick: int in ticks:
		velocity = FlightController.limit_excess(velocity, 180.0, 1.0, DT)
	var excess: float = velocity.length() - 180.0
	assert_float(excess).is_equal_approx(140.0 * 0.05, 0.5)


func test_limit_excess_keeps_the_direction() -> void:
	var velocity: Vector3 = Vector3(60, 0, -300)
	var limited: Vector3 = FlightController.limit_excess(velocity, 180.0, 1.0, DT)
	assert_vector(limited.normalized()).is_equal_approx(velocity.normalized(), Vector3.ONE * 0.0001)
	assert_float(limited.length()).is_less(velocity.length())
