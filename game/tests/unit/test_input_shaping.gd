extends GdUnitTestSuite
## Pure stick math in `InputRouter`: radial deadzone, response curve and clamping.

const DEADZONE: float = 0.2


func test_radial_deadzone_zeroes_small_input() -> void:
	assert_vector(InputRouter.apply_radial_deadzone(Vector2(0.1, 0.1), DEADZONE)).is_equal(
		Vector2.ZERO
	)


func test_radial_deadzone_is_circular_not_square() -> void:
	# Each axis is under 0.2, but together the magnitude (0.28) is over it: so this passes.
	var shaped: Vector2 = InputRouter.apply_radial_deadzone(Vector2(0.2, 0.2), DEADZONE)
	assert_float(shaped.length()).is_greater(0.0)
	# A deflection of exactly the deadzone radius is still zero (0.5 is exact in a float).
	assert_vector(InputRouter.apply_radial_deadzone(Vector2(0.5, 0.0), 0.5)).is_equal(Vector2.ZERO)


func test_radial_deadzone_rescales_so_full_deflection_is_one() -> void:
	var shaped: Vector2 = InputRouter.apply_radial_deadzone(Vector2(0.0, -1.0), DEADZONE)
	assert_vector(shaped).is_equal_approx(Vector2(0.0, -1.0), Vector2(0.001, 0.001))


func test_radial_deadzone_is_continuous_at_the_edge() -> void:
	var just_outside: Vector2 = InputRouter.apply_radial_deadzone(
		Vector2(DEADZONE + 0.001, 0.0), DEADZONE
	)
	assert_float(just_outside.x).is_between(0.0, 0.01)


func test_radial_deadzone_keeps_direction() -> void:
	var stick: Vector2 = Vector2(0.6, 0.3)
	var shaped: Vector2 = InputRouter.apply_radial_deadzone(stick, DEADZONE)
	assert_float(shaped.normalized().dot(stick.normalized())).is_equal_approx(1.0, 0.0001)


func test_curve_with_exponent_one_changes_nothing() -> void:
	var stick: Vector2 = Vector2(0.3, -0.4)
	assert_vector(InputRouter.apply_curve(stick, 1.0)).is_equal_approx(
		stick, Vector2(0.0001, 0.0001)
	)


func test_curve_exponent_two_squares_the_magnitude() -> void:
	var shaped: Vector2 = InputRouter.apply_curve(Vector2(0.5, 0.0), 2.0)
	assert_vector(shaped).is_equal_approx(Vector2(0.25, 0.0), Vector2(0.0001, 0.0001))


func test_curve_keeps_direction_and_full_deflection() -> void:
	var shaped: Vector2 = InputRouter.apply_curve(Vector2(0.0, -1.0), 1.5)
	assert_vector(shaped).is_equal_approx(Vector2(0.0, -1.0), Vector2(0.0001, 0.0001))


func test_shape_stick_clamps_each_axis_so_diagonal_keys_reach_full_thrust() -> void:
	# W + D on a keyboard: both axes at 1.0 (magnitude 1.41).
	var shaped: Vector2 = InputRouter.shape_stick(Vector2.ONE, 0.15, 1.5)
	assert_vector(shaped).is_equal(Vector2.ONE)


func test_shape_stick_is_symmetric() -> void:
	var positive: Vector2 = InputRouter.shape_stick(Vector2(0.6, 0.3), 0.15, 1.5)
	var negative: Vector2 = InputRouter.shape_stick(Vector2(-0.6, -0.3), 0.15, 1.5)
	assert_vector(negative).is_equal_approx(-positive, Vector2(0.0001, 0.0001))


func test_shape_axis_digital_press_is_exactly_one() -> void:
	assert_float(InputRouter.shape_axis(1.0, 0.15, 1.5)).is_equal(1.0)
	assert_float(InputRouter.shape_axis(-1.0, 0.15, 1.5)).is_equal(-1.0)
	assert_float(InputRouter.shape_axis(0.05, 0.15, 1.5)).is_equal(0.0)
