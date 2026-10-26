extends GdUnitTestSuite
## `AIMath`: the AI pilot's pure rules for steering, firing and reaction time (the flying rules are in
## `test_ai_math_flying.gd`).

const RATES: Vector2 = Vector2(1.5, 1.5)
const GAIN: float = 5.0
const KESTREL: ShipDef = preload("res://data/ships/kestrel.tres")
const STANDARD: AIProfileDef = preload("res://data/ai/standard.tres")


func test_a_target_dead_ahead_needs_no_turn() -> void:
	var command: Vector2 = AIMath.turn_command(Vector3(0.0, 0.0, -1.0), RATES, GAIN)
	assert_vector(command).is_equal_approx(Vector2.ZERO, Vector2(0.0001, 0.0001))


func test_the_nose_turns_towards_the_target_in_the_stick_convention() -> void:
	# +yaw is nose right, +pitch is nose up (ShipControls).
	var right: Vector2 = AIMath.turn_command(Vector3(0.2, 0.0, -1.0), RATES, GAIN)
	assert_float(right.y).is_greater(0.0)
	assert_float(right.x).is_equal_approx(0.0, 0.0001)
	var left: Vector2 = AIMath.turn_command(Vector3(-0.2, 0.0, -1.0), RATES, GAIN)
	assert_float(left.y).is_less(0.0)
	var up: Vector2 = AIMath.turn_command(Vector3(0.0, 0.2, -1.0), RATES, GAIN)
	assert_float(up.x).is_greater(0.0)
	var down: Vector2 = AIMath.turn_command(Vector3(0.0, -0.2, -1.0), RATES, GAIN)
	assert_float(down.x).is_less(0.0)


func test_a_small_error_gets_a_small_command_and_a_big_one_saturates() -> void:
	var small: Vector2 = AIMath.turn_command(Vector3(0.02, 0.0, -1.0), RATES, GAIN)
	assert_float(small.y).is_between(0.0, 0.2)
	var big: Vector2 = AIMath.turn_command(Vector3(1.0, 0.0, -0.2), RATES, GAIN)
	assert_float(big.y).is_equal(1.0)


func test_the_command_eases_off_as_the_error_shrinks() -> void:
	var far: float = AIMath.turn_command(Vector3(0.1, 0.0, -1.0), RATES, GAIN).y
	var near: float = AIMath.turn_command(Vector3(0.03, 0.0, -1.0), RATES, GAIN).y
	assert_float(near).is_less(far)


func test_a_target_dead_behind_turns_one_way_instead_of_dithering() -> void:
	var command: Vector2 = AIMath.turn_command(Vector3(0.0, 0.0, 1.0), RATES, GAIN)
	assert_float(command.y).is_equal(1.0)


func test_a_zero_direction_gives_no_command() -> void:
	assert_vector(AIMath.turn_command(Vector3.ZERO, RATES, GAIN)).is_equal(Vector2.ZERO)


func test_feed_forward_adds_the_swing_rate_of_the_target() -> void:
	var plain: Vector2 = AIMath.turn_command(Vector3(0.0, 0.0, -1.0), RATES, GAIN)
	var tracked: Vector2 = AIMath.turn_command(
		Vector3(0.0, 0.0, -1.0), RATES, GAIN, Vector2(0.0, 0.6)
	)
	assert_float(plain.y).is_equal(0.0)
	assert_float(tracked.y).is_equal_approx(0.6 / RATES.y, 0.0001)


func test_swing_rate_follows_a_direction_that_turns_right() -> void:
	var previous: Vector3 = Vector3(0.0, 0.0, -1.0)
	var angle: float = deg_to_rad(1.0)
	var current: Vector3 = Vector3(sin(angle), 0.0, -cos(angle))
	var rate: Vector2 = AIMath.swing_rate(previous, current, Basis.IDENTITY, 1.0 / 60.0)
	# 1 degree in a tick is 60 degrees per second, to the right (positive yaw).
	assert_float(rate.y).is_equal_approx(deg_to_rad(60.0), 0.01)
	assert_float(rate.x).is_equal_approx(0.0, 0.0001)


func test_swing_rate_follows_a_direction_that_turns_up() -> void:
	var previous: Vector3 = Vector3(0.0, 0.0, -1.0)
	var angle: float = deg_to_rad(1.0)
	var current: Vector3 = Vector3(0.0, sin(angle), -cos(angle))
	var rate: Vector2 = AIMath.swing_rate(previous, current, Basis.IDENTITY, 1.0 / 60.0)
	assert_float(rate.x).is_equal_approx(deg_to_rad(60.0), 0.01)


func test_a_jump_in_heading_is_not_tracked() -> void:
	var jump: Vector2 = AIMath.swing_rate(
		Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Basis.IDENTITY, 1.0 / 60.0
	)
	assert_vector(jump).is_equal(Vector2.ZERO)
	var none: Vector2 = AIMath.swing_rate(
		Vector3.ZERO, Vector3(0.0, 0.0, -1.0), Basis.IDENTITY, 1.0 / 60.0
	)
	assert_vector(none).is_equal(Vector2.ZERO)


func test_turn_radius_comes_from_the_ships_speed_and_turn_rate() -> void:
	assert_float(AIMath.turn_radius(KESTREL)).is_equal_approx(
		KESTREL.max_speed / deg_to_rad(90.0), 0.01
	)
	# A slower turner has a wider circle.
	var drayman: ShipDef = Content.ship(&"drayman")
	assert_float(AIMath.turn_radius(drayman)).is_equal_approx(
		drayman.max_speed / deg_to_rad(40.0), 0.01
	)
	assert_float(AIMath.turn_radius(drayman)).is_greater(AIMath.turn_radius(KESTREL))


func test_the_break_off_range_is_never_inside_the_turning_circle() -> void:
	var profile: AIProfileDef = STANDARD.duplicate() as AIProfileDef
	profile.break_off_range_m = 10.0
	assert_float(AIMath.break_off_range(profile, KESTREL)).is_equal_approx(
		AIMath.turn_radius(KESTREL), 0.01
	)
	profile.break_off_range_m = 400.0
	assert_float(AIMath.break_off_range(profile, KESTREL)).is_equal(400.0)


func test_the_fire_cone_widens_for_a_big_close_target() -> void:
	var small: float = AIMath.fire_cone(4.0, 1.0, 500.0)
	assert_float(small).is_equal_approx(deg_to_rad(4.0), 0.0001)
	var big: float = AIMath.fire_cone(4.0, 30.0, 100.0)
	assert_float(big).is_greater(deg_to_rad(4.0))


func test_should_fire_needs_the_aim_and_the_range() -> void:
	var cone: float = deg_to_rad(4.0)
	assert_bool(AIMath.should_fire(deg_to_rad(2.0), 300.0, cone, 400.0)).is_true()
	assert_bool(AIMath.should_fire(deg_to_rad(9.0), 300.0, cone, 400.0)).is_false()
	assert_bool(AIMath.should_fire(deg_to_rad(2.0), 500.0, cone, 400.0)).is_false()


func test_a_threat_is_only_reacted_to_after_the_reaction_time() -> void:
	var seen: float = 0.0
	var reacted_at: float = -1.0
	for tick: int in 120:
		seen = AIMath.seen_time(seen, true, 1.0 / 60.0)
		if reacted_at < 0.0 and AIMath.has_reacted(seen, 0.5):
			reacted_at = (tick + 1) / 60.0
	assert_float(reacted_at).is_equal_approx(0.5, 0.02)
	# It forgets when the threat goes away.
	seen = AIMath.seen_time(seen, false, 1.0 / 60.0)
	assert_float(seen).is_equal(0.0)
	assert_bool(AIMath.has_reacted(seen, 0.0)).is_false()


func test_aim_error_moves_the_aim_point_across_the_line_of_sight() -> void:
	var shooter: Vector3 = Vector3.ZERO
	var lead: Vector3 = Vector3(0.0, 0.0, -400.0)
	# No error: exactly the lead point.
	assert_vector(AIMath.aim_point(shooter, lead, Vector3.ZERO, 3.0)).is_equal_approx(
		lead, Vector3.ONE * 0.001
	)
	# A full error of 3 degrees at 400 m is about 21 m sideways, and none along the line.
	var aimed: Vector3 = AIMath.aim_point(shooter, lead, Vector3(1.0, 0.0, 0.0), 3.0)
	assert_float(aimed.x).is_equal_approx(400.0 * tan(deg_to_rad(3.0)), 0.01)
	assert_float(aimed.z).is_equal_approx(-400.0, 0.001)
	# An error along the line does nothing.
	var along: Vector3 = AIMath.aim_point(shooter, lead, Vector3(0.0, 0.0, -1.0), 3.0)
	assert_vector(along).is_equal_approx(lead, Vector3.ONE * 0.001)


func test_random_in_ball_stays_inside_the_unit_ball() -> void:
	for roll: float in [0.0, 0.25, 0.5, 1.0]:
		assert_float(AIMath.random_in_ball(roll, 1.0 - roll, roll).length()).is_less_equal(1.0001)
	assert_vector(AIMath.random_in_ball(0.5, 0.5, 0.5)).is_equal_approx(
		Vector3.ZERO, Vector3.ONE * 0.0001
	)
