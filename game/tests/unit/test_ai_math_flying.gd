extends GdUnitTestSuite
## `AIMath`: avoiding rocks, matching speed, collision courses, fire discipline and jinking.


func test_a_rock_ahead_makes_the_ship_turn_away_from_it() -> void:
	# Rock 300 m ahead and 20 m to the left of the path: swing right.
	var heading: Vector3 = AIMath.avoid_heading(
		Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Vector3(-20.0, 0.0, -300.0), 40.0, 20.0, Vector3.UP
	)
	assert_float(heading.x).is_greater(0.05)
	assert_float(heading.z).is_less(0.0)


func test_the_swerve_clears_the_rock_by_the_clearance() -> void:
	var centre: Vector3 = Vector3(0.0, 10.0, -300.0)
	var radius: float = 45.0
	var clearance: float = 20.0
	var heading: Vector3 = AIMath.avoid_heading(
		Vector3.ZERO, Vector3(0.0, 0.0, -1.0), centre, radius, clearance, Vector3.UP
	)
	# Fly the heading and find the closest approach to the rock's centre.
	var closest: float = INF
	for step: int in 400:
		closest = minf(closest, (heading * float(step)).distance_to(centre))
	assert_float(closest).is_greater(radius + clearance - 1.0)


func test_a_rock_dead_ahead_is_passed_on_the_given_side_and_never_by_less_than_the_minimum(
) -> void:
	var heading: Vector3 = AIMath.avoid_heading(
		Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Vector3(0.0, 0.0, -300.0), 40.0, 20.0, Vector3.UP
	)
	assert_float(heading.y).is_greater(0.2)
	assert_float(Vector3(0.0, 0.0, -1.0).angle_to(heading)).is_greater_equal(
		AIMath.MIN_AVOID_ANGLE - 0.001
	)


func test_matched_throttle_is_full_when_far_and_eases_off_when_close() -> void:
	assert_float(AIMath.matched_throttle(900.0, 150.0, 0.0, 180.0)).is_equal(1.0)
	# At the hold distance behind a stationary target the throttle is the minimum.
	assert_float(AIMath.matched_throttle(150.0, 150.0, 0.0, 180.0)).is_equal(AIMath.MIN_THROTTLE)
	# Behind a target flying away at 90 m/s it matches half speed.
	assert_float(AIMath.matched_throttle(150.0, 150.0, 90.0, 180.0)).is_equal_approx(0.5, 0.01)
	# A target flying towards us makes it brake (never below the minimum).
	assert_float(AIMath.matched_throttle(200.0, 150.0, -150.0, 180.0)).is_equal(AIMath.MIN_THROTTLE)


func test_closest_approach_of_a_head_on_pass() -> void:
	# Other ship 400 m ahead and 30 m to the side, flying at us at 200 m/s relative.
	var approach: Vector2 = AIMath.closest_approach(
		Vector3(30.0, 0.0, -400.0), Vector3(0.0, 0.0, 200.0)
	)
	assert_float(approach.x).is_equal_approx(2.0, 0.001)
	assert_float(approach.y).is_equal_approx(30.0, 0.001)


func test_ships_moving_apart_are_closest_now() -> void:
	var approach: Vector2 = AIMath.closest_approach(
		Vector3(0.0, 0.0, -100.0), Vector3(0.0, 0.0, -50.0)
	)
	assert_float(approach.x).is_equal(0.0)
	assert_float(approach.y).is_equal_approx(100.0, 0.001)


func test_collision_course_needs_a_near_pass_soon() -> void:
	var pos: Vector3 = Vector3(5.0, 0.0, -300.0)
	var vel: Vector3 = Vector3(0.0, 0.0, 200.0)
	assert_bool(AIMath.is_collision_course(pos, vel, 20.0, 2.0)).is_true()
	# Passing 60 m wide is not a collision course.
	assert_bool(AIMath.is_collision_course(Vector3(60.0, 0.0, -300.0), vel, 20.0, 2.0)).is_false()
	# Too far away to matter yet.
	assert_bool(AIMath.is_collision_course(Vector3(5.0, 0.0, -900.0), vel, 20.0, 2.0)).is_false()


func test_fire_discipline_rests_the_guns_until_the_capacitor_recovers() -> void:
	assert_bool(AIMath.hold_fire(0.8, false, 0.12, 0.5)).is_false()
	assert_bool(AIMath.hold_fire(0.1, false, 0.12, 0.5)).is_true()
	# Held back: stays held until it is above the high mark.
	assert_bool(AIMath.hold_fire(0.3, true, 0.12, 0.5)).is_true()
	assert_bool(AIMath.hold_fire(0.55, true, 0.12, 0.5)).is_false()


func test_a_jink_direction_is_across_the_line_of_sight() -> void:
	var line: Vector3 = Vector3(0.0, 0.0, -1.0)
	for angle: float in [0.0, 1.0, 2.5, 4.0]:
		var jink: Vector3 = AIMath.jink_direction(line, Vector3.UP, angle)
		assert_float(jink.dot(line)).is_equal_approx(0.0, 0.0001)
		assert_float(jink.length()).is_equal_approx(1.0, 0.0001)
	# Angle 0 is along the reference; half a turn is the opposite side.
	assert_vector(AIMath.jink_direction(line, Vector3.UP, 0.0)).is_equal_approx(
		Vector3.UP, Vector3.ONE * 0.001
	)
	assert_vector(AIMath.jink_direction(line, Vector3.UP, PI)).is_equal_approx(
		Vector3.DOWN, Vector3.ONE * 0.001
	)
	# A reference along the line still gives a usable direction.
	var fallback: Vector3 = AIMath.jink_direction(line, line, 0.0)
	assert_float(fallback.length()).is_equal_approx(1.0, 0.0001)
