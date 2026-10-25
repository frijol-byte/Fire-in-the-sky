extends GdUnitTestSuite
## `Lead`: where to aim at a moving target. The solutions are checked by flying the shot: at the
## time the solver gives, a shot fired at the lead point and the target are in the same place.

const SPEED: float = 500.0


## Where a shot fired from `from` at `lead` with `speed` is after `time`, and where the target is.
func _meet(from: Vector3, target: Vector3, velocity: Vector3, lead: Vector3, time: float) -> void:
	var shot_at: Vector3 = from + (lead - from).normalized() * SPEED * time
	var target_at: Vector3 = target + velocity * time
	assert_vector(shot_at).is_equal_approx(target_at, Vector3.ONE * 0.05)


func test_a_stationary_target_is_aimed_at_directly() -> void:
	var target: Vector3 = Vector3(10, -20, -300)
	var lead: Vector3 = Lead.solve(Vector3.ZERO, Vector3.ZERO, target, Vector3.ZERO, SPEED)
	assert_vector(lead).is_equal_approx(target, Vector3.ONE * 0.001)
	var time: float = Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, Vector3.ZERO, SPEED)
	assert_float(time).is_equal_approx(target.length() / SPEED, 0.0001)


func test_a_crossing_target_is_led_ahead_of_it() -> void:
	var target: Vector3 = Vector3(0, 0, -400)
	var velocity: Vector3 = Vector3(100, 0, 0)
	var lead: Vector3 = Lead.solve(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)
	# Ahead of the target along its motion.
	assert_float(lead.x).is_greater(0.0)
	assert_float(lead.z).is_equal_approx(-400.0, 0.001)
	var time: float = Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)
	_meet(Vector3.ZERO, target, velocity, lead, time)


func test_a_target_flying_at_us_is_met_sooner() -> void:
	var target: Vector3 = Vector3(0, 0, -600)
	var coming: float = Lead.time_to_hit(
		Vector3.ZERO, Vector3.ZERO, target, Vector3(0, 0, 150), SPEED
	)
	var still: float = Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, Vector3.ZERO, SPEED)
	assert_float(coming).is_less(still)
	assert_float(coming).is_equal_approx(600.0 / (SPEED + 150.0), 0.0001)


func test_a_target_running_away_slower_than_the_shot_is_still_caught() -> void:
	var target: Vector3 = Vector3(0, 0, -300)
	var velocity: Vector3 = Vector3(0, 0, -200)
	var time: float = Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)
	assert_float(time).is_equal_approx(300.0 / (SPEED - 200.0), 0.0001)


func test_the_solution_works_in_every_direction() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for _i: int in 50:
		var from: Vector3 = Vector3(rng.randf_range(-50, 50), rng.randf_range(-50, 50), 0.0)
		var target: Vector3 = Vector3(
			rng.randf_range(-500, 500), rng.randf_range(-500, 500), rng.randf_range(-500, 500)
		)
		var velocity: Vector3 = Vector3(
			rng.randf_range(-200, 200), rng.randf_range(-200, 200), rng.randf_range(-200, 200)
		)
		var time: float = Lead.time_to_hit(from, Vector3.ZERO, target, velocity, SPEED)
		assert_float(time).is_greater(0.0)
		_meet(from, target, velocity, Lead.solve(from, Vector3.ZERO, target, velocity, SPEED), time)


func test_a_target_that_outruns_the_shot_has_no_solution_and_falls_back_to_its_position() -> void:
	var target: Vector3 = Vector3(0, 0, -300)
	var velocity: Vector3 = Vector3(0, 0, -800)
	assert_float(Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)).is_less(0.0)
	assert_vector(Lead.solve(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)).is_equal(target)


func test_a_target_flying_off_at_exactly_the_shot_speed_cannot_be_caught() -> void:
	var target: Vector3 = Vector3(0, 0, -300)
	var velocity: Vector3 = Vector3(0, 0, -SPEED)
	assert_float(Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, velocity, SPEED)).is_less(0.0)


func test_equal_speed_across_the_line_of_sight_is_solved() -> void:
	# Same speed as the shot, moving straight at us: the linear case of the equation.
	var target: Vector3 = Vector3(0, 0, -1000)
	var time: float = Lead.time_to_hit(
		Vector3.ZERO, Vector3.ZERO, target, Vector3(0, 0, SPEED), SPEED
	)
	assert_float(time).is_equal_approx(1000.0 / (2.0 * SPEED), 0.0001)


func test_a_shot_with_no_speed_falls_back() -> void:
	var target: Vector3 = Vector3(5, 5, -100)
	assert_float(Lead.time_to_hit(Vector3.ZERO, Vector3.ZERO, target, Vector3.ONE, 0.0)).is_less(
		0.0
	)
	assert_vector(Lead.solve(Vector3.ZERO, Vector3.ZERO, target, Vector3.ONE, 0.0)).is_equal(target)


func test_a_target_at_the_shooter_is_hit_at_once() -> void:
	var here: Vector3 = Vector3(1, 2, 3)
	assert_float(Lead.time_to_hit(here, Vector3.ZERO, here, Vector3(9, 9, 9), SPEED)).is_equal(0.0)


func test_shooter_velocity_matters_only_for_a_weapon_that_inherits_it() -> void:
	var target: Vector3 = Vector3(0, 0, -400)
	var shooter_velocity: Vector3 = Vector3(0, 0, -150)
	var without: Vector3 = Lead.solve(Vector3.ZERO, shooter_velocity, target, Vector3.ZERO, SPEED)
	assert_vector(without).is_equal_approx(target, Vector3.ONE * 0.001)
	# The shot carries the ship's speed, so the still target drifts towards the shot.
	var inherits: Vector3 = Lead.solve(
		Vector3.ZERO, shooter_velocity, target, Vector3.ZERO, SPEED, true
	)
	var time: float = Lead.time_to_hit(
		Vector3.ZERO, shooter_velocity, target, Vector3.ZERO, SPEED, true
	)
	assert_float(time).is_greater(0.0)
	assert_vector(inherits).is_equal_approx(target + Vector3(0, 0, 150) * time, Vector3.ONE * 0.001)
