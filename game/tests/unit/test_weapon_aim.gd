extends GdUnitTestSuite
## The pure aim helpers of `WeaponSystem`: the gimbal limit and the spread cone.


func test_limit_angle_passes_a_wanted_direction_inside_the_limit() -> void:
	var forward: Vector3 = Vector3(0, 0, -1)
	var wanted: Vector3 = Vector3(sin(deg_to_rad(2.0)), 0, -cos(deg_to_rad(2.0)))
	var result: Vector3 = WeaponSystem.limit_angle(forward, wanted, deg_to_rad(3.0))
	assert_vector(result).is_equal_approx(wanted, Vector3(0.0001, 0.0001, 0.0001))


func test_limit_angle_clamps_a_wanted_direction_beyond_the_limit() -> void:
	var forward: Vector3 = Vector3(0, 0, -1)
	var wanted: Vector3 = Vector3(sin(deg_to_rad(40.0)), 0, -cos(deg_to_rad(40.0)))
	var result: Vector3 = WeaponSystem.limit_angle(forward, wanted, deg_to_rad(3.0))
	assert_float(result.angle_to(forward)).is_equal_approx(deg_to_rad(3.0), 0.0001)
	# It moved towards the wanted side.
	assert_float(result.x).is_greater(0.0)
	assert_float(result.length()).is_equal_approx(1.0, 0.0001)


func test_limit_angle_works_in_every_direction() -> void:
	var forward: Vector3 = Vector3(0, 0, -1)
	for wanted: Vector3 in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3(1, 1, 0).normalized()]:
		var result: Vector3 = WeaponSystem.limit_angle(forward, wanted, deg_to_rad(3.0))
		assert_float(result.angle_to(forward)).is_equal_approx(deg_to_rad(3.0), 0.0001)
		assert_float(result.angle_to(wanted)).is_less(forward.angle_to(wanted))


func test_limit_angle_with_a_zero_wanted_direction_keeps_forward() -> void:
	var forward: Vector3 = Vector3(0, 0, -1)
	assert_vector(WeaponSystem.limit_angle(forward, Vector3.ZERO, 0.05)).is_equal(forward)


func test_no_spread_leaves_the_direction_alone() -> void:
	var direction: Vector3 = Vector3(0, 0, -1)
	assert_vector(WeaponSystem.spread_direction(direction, 0.0, 0.7, 0.3)).is_equal(direction)


func test_spread_stays_inside_the_cone_and_fills_it() -> void:
	var direction: Vector3 = Vector3(0.3, 0.2, -0.9).normalized()
	var biggest: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for _shot: int in 2000:
		var result: Vector3 = WeaponSystem.spread_direction(
			direction, 2.0, rng.randf(), rng.randf()
		)
		var angle: float = result.angle_to(direction)
		assert_float(result.length()).is_equal_approx(1.0, 0.0001)
		assert_float(angle).is_less_equal(deg_to_rad(2.0) + 0.0001)
		biggest = maxf(biggest, angle)
	assert_float(biggest).is_greater(deg_to_rad(1.9))


func test_spread_at_the_extremes_of_the_random_numbers() -> void:
	var direction: Vector3 = Vector3(0, 0, -1)
	assert_vector(WeaponSystem.spread_direction(direction, 2.0, 0.0, 0.5)).is_equal_approx(
		direction, Vector3(0.0001, 0.0001, 0.0001)
	)
	var edge: Vector3 = WeaponSystem.spread_direction(direction, 2.0, 1.0, 0.0)
	assert_float(edge.angle_to(direction)).is_equal_approx(deg_to_rad(2.0), 0.0001)


func test_spread_works_when_firing_straight_up() -> void:
	var result: Vector3 = WeaponSystem.spread_direction(Vector3.UP, 2.0, 1.0, 0.25)
	assert_float(result.angle_to(Vector3.UP)).is_equal_approx(deg_to_rad(2.0), 0.0001)
