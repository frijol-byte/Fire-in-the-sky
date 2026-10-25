extends GdUnitTestSuite
## `MissileGuidance`: proportional navigation, speed, the fuse geometry and the splash falloff.

const DT: float = 1.0 / 60.0


## Flies a missile and a constant-velocity target for up to `seconds` with PN guidance and returns the
## closest distance between them.
func _closest_approach(
	missile_pos: Vector3,
	missile_vel: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	turn_rate_deg: float,
	seconds: float
) -> float:
	var closest: float = missile_pos.distance_to(target_pos)
	var speed: float = missile_vel.length()
	var heading: Vector3 = missile_vel.normalized()
	for tick: int in int(seconds / DT):
		heading = MissileGuidance.steer(
			heading,
			missile_pos,
			heading * speed,
			target_pos,
			target_vel,
			4.0,
			deg_to_rad(turn_rate_deg),
			DT
		)
		missile_pos += heading * speed * DT
		target_pos += target_vel * DT
		closest = minf(closest, missile_pos.distance_to(target_pos))
	return closest


func test_a_target_on_a_collision_course_does_not_turn_the_missile() -> void:
	var heading: Vector3 = Vector3.FORWARD
	var turned: Vector3 = MissileGuidance.steer(
		heading, Vector3.ZERO, heading * 200.0, Vector3(0, 0, -500), Vector3.ZERO, 4.0, 1.0, DT
	)
	assert_vector(turned).is_equal_approx(heading, Vector3.ONE * 0.0001)


func test_a_crossing_target_turns_the_missile_towards_it() -> void:
	# Target 500 m ahead, moving to the right (+x): the nose must swing right.
	var turned: Vector3 = MissileGuidance.steer(
		Vector3.FORWARD,
		Vector3.ZERO,
		Vector3.FORWARD * 200.0,
		Vector3(0, 0, -500),
		Vector3(80, 0, 0),
		4.0,
		5.0,
		DT
	)
	assert_float(turned.x).is_greater(0.0)
	assert_float(turned.y).is_equal_approx(0.0, 0.0001)
	assert_float(turned.length()).is_equal_approx(1.0, 0.0001)


func test_the_turn_rate_is_limited() -> void:
	# A target right next to the line of sight swings it fast; the turn per tick stops at the limit.
	var limit: float = deg_to_rad(40.0)
	var turned: Vector3 = MissileGuidance.steer(
		Vector3.FORWARD,
		Vector3.ZERO,
		Vector3.FORWARD * 200.0,
		Vector3(40, 0, -60),
		Vector3(150, 0, 0),
		4.0,
		limit,
		DT
	)
	assert_float(Vector3.FORWARD.angle_to(turned)).is_equal_approx(limit * DT, 0.0001)


func test_a_target_at_the_missile_changes_nothing() -> void:
	var turned: Vector3 = MissileGuidance.steer(
		Vector3.FORWARD,
		Vector3.ONE,
		Vector3.FORWARD * 200.0,
		Vector3.ONE,
		Vector3.ZERO,
		4.0,
		1.0,
		DT
	)
	assert_vector(turned).is_equal(Vector3.FORWARD)


func test_navigation_catches_a_target_that_flies_a_straight_line() -> void:
	# The target crosses in front at 120 m/s; a 55 deg/s missile at 250 m/s still gets inside 3 m.
	var closest: float = _closest_approach(
		Vector3.ZERO, Vector3(0, 0, -250), Vector3(-300, 0, -900), Vector3(120, 0, 0), 55.0, 8.0
	)
	assert_float(closest).is_less(3.0)


func test_a_target_that_turns_hard_late_is_missed_by_a_slow_turner() -> void:
	# Same geometry, but the target is already moving away sideways fast and the missile turns
	# slowly: the missile cannot bring its nose round in time and flies past.
	var closest: float = _closest_approach(
		Vector3.ZERO, Vector3(0, 0, -250), Vector3(0, 0, -200), Vector3(300, 0, 0), 20.0, 4.0
	)
	assert_float(closest).is_greater(30.0)


func test_speed_climbs_to_the_top_speed_and_stays() -> void:
	var speed: float = 100.0
	for tick: int in 600:
		speed = MissileGuidance.next_speed(speed, 160.0, 290.0, DT)
	assert_float(speed).is_equal(290.0)
	assert_float(MissileGuidance.next_speed(100.0, 160.0, 290.0, 0.5)).is_equal_approx(
		180.0, 0.0001
	)


func test_a_round_launched_too_fast_slows_down_to_the_top_speed() -> void:
	assert_float(MissileGuidance.next_speed(440.0, 160.0, 290.0, 0.5)).is_equal_approx(
		360.0, 0.0001
	)
	assert_float(MissileGuidance.next_speed(300.0, 160.0, 290.0, 0.5)).is_equal(290.0)


func test_closest_fraction_finds_the_pass_even_when_the_round_would_skip_the_target() -> void:
	# 100 m/s tick: the round moves 10 m along x past a target 1 m off the line.
	var fraction: float = MissileGuidance.closest_fraction(
		Vector3(-5, 0, 0), Vector3(10, 0, 0), Vector3(0, 1, 0), Vector3.ZERO
	)
	assert_float(fraction).is_equal_approx(0.5, 0.0001)
	(
		assert_float(
			MissileGuidance.separation_at(
				Vector3(-5, 0, 0), Vector3(10, 0, 0), Vector3(0, 1, 0), Vector3.ZERO, fraction
			)
		)
		. is_equal_approx(1.0, 0.0001)
	)


func test_closest_fraction_is_clamped_to_this_tick() -> void:
	# The round is still approaching at the end of the tick: closest point is the end.
	(
		assert_float(
			MissileGuidance.closest_fraction(
				Vector3.ZERO, Vector3(1, 0, 0), Vector3(50, 0, 0), Vector3.ZERO
			)
		)
		. is_equal(1.0)
	)
	# Moving away: the start.
	(
		assert_float(
			MissileGuidance.closest_fraction(
				Vector3.ZERO, Vector3(-1, 0, 0), Vector3(50, 0, 0), Vector3.ZERO
			)
		)
		. is_equal(0.0)
	)
	# No relative motion: the start, without dividing by zero.
	(
		assert_float(
			MissileGuidance.closest_fraction(
				Vector3.ZERO, Vector3.ONE, Vector3(5, 5, 5), Vector3.ONE
			)
		)
		. is_equal(0.0)
	)


func test_a_moving_target_is_judged_in_its_own_frame() -> void:
	# Target moves +x 10 m this tick while the round moves +x 10 m beside it: they stay 1 m apart.
	var gap: float = MissileGuidance.separation_at(
		Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(0, 1, 0), Vector3(10, 0, 0), 0.5
	)
	assert_float(gap).is_equal_approx(1.0, 0.0001)


func test_splash_is_full_at_the_centre_less_at_the_edge_and_nothing_beyond() -> void:
	assert_float(MissileGuidance.splash_amount(60.0, 16.0, 0.35, 0.0)).is_equal(60.0)
	assert_float(MissileGuidance.splash_amount(60.0, 16.0, 0.35, 16.0)).is_equal_approx(
		21.0, 0.0001
	)
	assert_float(MissileGuidance.splash_amount(60.0, 16.0, 0.35, 8.0)).is_equal_approx(40.5, 0.0001)
	assert_float(MissileGuidance.splash_amount(60.0, 16.0, 0.35, 16.01)).is_equal(0.0)
	assert_float(MissileGuidance.splash_amount(60.0, 0.0, 0.35, 0.0)).is_equal(0.0)


func test_the_seeker_sees_a_cone_around_the_nose() -> void:
	var cone: float = deg_to_rad(110.0)
	(
		assert_bool(MissileGuidance.in_seeker_view(Vector3.FORWARD, Vector3(0, 0, -100), cone))
		. is_true()
	)
	# 90 degrees off to the side is still in view; straight behind is not.
	assert_bool(MissileGuidance.in_seeker_view(Vector3.FORWARD, Vector3(100, 0, 0), cone)).is_true()
	(
		assert_bool(MissileGuidance.in_seeker_view(Vector3.FORWARD, Vector3(0, 0, 100), cone))
		. is_false()
	)
	# 120 degrees round: just out of view.
	var behind: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(120.0)) * 100.0
	assert_bool(MissileGuidance.in_seeker_view(Vector3.FORWARD, behind, cone)).is_false()
	# Something on top of the missile is always seen.
	assert_bool(MissileGuidance.in_seeker_view(Vector3.FORWARD, Vector3.ZERO, cone)).is_true()
