extends GdUnitTestSuite
## `DestructionMath`: fireball size, the fades and the random launch velocities.

const LOOK: DestructionDef = preload("res://data/combat/destruction_default.tres")


func _rng(seed_value: int = 5) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_the_fireball_scales_with_the_ship_but_has_a_minimum() -> void:
	assert_float(DestructionMath.fireball_radius(LOOK, 1.0)).is_equal(LOOK.fireball_min_radius)
	var big: float = DestructionMath.fireball_radius(LOOK, 20.0)
	assert_float(big).is_equal_approx(20.0 * LOOK.fireball_radius_factor, 0.001)
	assert_float(big).is_greater(DestructionMath.fireball_radius(LOOK, 5.0))


func test_progress_runs_from_zero_to_one_and_stops() -> void:
	assert_float(DestructionMath.progress(0.0, 2.0)).is_equal(0.0)
	assert_float(DestructionMath.progress(1.0, 2.0)).is_equal(0.5)
	assert_float(DestructionMath.progress(5.0, 2.0)).is_equal(1.0)
	assert_float(DestructionMath.progress(-1.0, 2.0)).is_equal(0.0)
	assert_float(DestructionMath.progress(1.0, 0.0)).is_equal(1.0)


func test_a_wreck_holds_its_size_then_shrinks_to_nothing() -> void:
	assert_float(DestructionMath.wreck_scale(0.0, 2.5)).is_equal(1.0)
	var held: float = 2.5 * DestructionMath.WRECK_HOLD_FRACTION
	assert_float(DestructionMath.wreck_scale(held, 2.5)).is_equal(1.0)
	var middle: float = DestructionMath.wreck_scale(held + (2.5 - held) * 0.5, 2.5)
	assert_float(middle).is_between(0.2, 0.8)
	assert_float(DestructionMath.wreck_scale(2.5, 2.5)).is_equal(0.0)
	assert_float(DestructionMath.wreck_scale(9.0, 2.5)).is_equal(0.0)


func test_debris_shrinks_late_and_cools_early() -> void:
	assert_float(DestructionMath.debris_scale(0.0, 4.0)).is_equal(1.0)
	assert_float(DestructionMath.debris_scale(4.0, 4.0)).is_equal(0.0)
	assert_float(DestructionMath.debris_scale(1.0, 4.0)).is_equal(1.0)
	assert_float(DestructionMath.debris_heat(0.0, 1.6)).is_equal(1.0)
	assert_float(DestructionMath.debris_heat(0.8, 1.6)).is_equal(0.5)
	assert_float(DestructionMath.debris_heat(5.0, 1.6)).is_equal(0.0)


func test_the_blast_light_starts_at_its_peak_and_dies_away() -> void:
	assert_float(DestructionMath.light_energy(0.0, 1.0, 6.0)).is_equal(6.0)
	assert_float(DestructionMath.light_energy(0.5, 1.0, 6.0)).is_equal_approx(1.5, 0.0001)
	assert_float(DestructionMath.light_energy(1.0, 1.0, 6.0)).is_equal(0.0)
	assert_float(DestructionMath.light_energy(3.0, 1.0, 6.0)).is_equal(0.0)


func test_the_shockwave_races_out_and_slows() -> void:
	var at: Callable = func(t: float) -> float:
		return DestructionMath.shockwave_radius(t, 1.0, 10.0, 2.0)
	assert_float(at.call(0.0)).is_equal(0.0)
	assert_float(at.call(1.0)).is_equal(20.0)
	var first_tenth: float = at.call(0.1)
	var last_tenth: float = (at.call(1.0) as float) - (at.call(0.9) as float)
	assert_float(first_tenth).is_greater(last_tenth * 3.0)


func test_random_directions_are_unit_length_and_spread_out() -> void:
	var rng: RandomNumberGenerator = _rng()
	var total: Vector3 = Vector3.ZERO
	for _index: int in 400:
		var direction: Vector3 = DestructionMath.random_direction(rng)
		assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
		total += direction
	# Uniform on the sphere: the average direction is near zero.
	assert_float((total / 400.0).length()).is_less(0.15)


func test_debris_flies_off_within_the_speed_range_of_the_wreck() -> void:
	var rng: RandomNumberGenerator = _rng()
	var wreck: Vector3 = Vector3(0.0, 0.0, -80.0)
	for _index: int in 100:
		var relative: Vector3 = DestructionMath.debris_velocity(rng, LOOK, wreck) - wreck
		assert_float(relative.length()).is_between(
			LOOK.debris_speed_min - 0.01, LOOK.debris_speed_max + 0.01
		)


func test_loot_scatters_around_half_the_wreck_velocity() -> void:
	var rng: RandomNumberGenerator = _rng()
	var wreck: Vector3 = Vector3(100.0, 0.0, 0.0)
	for _index: int in 100:
		var relative: Vector3 = DestructionMath.scatter_velocity(rng, 14.0, wreck) - wreck * 0.5
		assert_float(relative.length()).is_less_equal(14.0 + 0.01)
	var still: Vector3 = DestructionMath.scatter_velocity(rng, 0.0, Vector3.ZERO)
	assert_vector(still).is_equal(Vector3.ZERO)


func test_tumble_stays_within_the_limit_and_repeats_with_the_seed() -> void:
	var limit: float = deg_to_rad(55.0)
	var first: Vector3 = DestructionMath.tumble(_rng(3), 55.0)
	assert_vector(first).is_equal(DestructionMath.tumble(_rng(3), 55.0))
	for axis: int in 3:
		assert_float(absf(first[axis])).is_less_equal(limit)
	assert_vector(DestructionMath.tumble(_rng(), 0.0)).is_equal(Vector3.ZERO)
