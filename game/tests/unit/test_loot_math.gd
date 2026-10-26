extends GdUnitTestSuite
## `LootMath`: the tractor beam's rules and how containers drift and expire.

const TRACTOR: TractorDef = preload("res://data/combat/tractor_default.tres")


func test_range_and_collection_radii() -> void:
	assert_bool(LootMath.in_tractor_range(TRACTOR.range_m, TRACTOR)).is_true()
	assert_bool(LootMath.in_tractor_range(TRACTOR.range_m + 1.0, TRACTOR)).is_false()
	assert_bool(LootMath.is_collected(TRACTOR.collect_radius_m, TRACTOR)).is_true()
	assert_bool(LootMath.is_collected(TRACTOR.collect_radius_m + 0.1, TRACTOR)).is_false()


func test_the_pull_speeds_up_and_stops_at_the_limit() -> void:
	var speed: float = 0.0
	speed = LootMath.next_pull_speed(speed, TRACTOR, 0.1)
	assert_float(speed).is_equal_approx(TRACTOR.pull_accel * 0.1, 0.0001)
	for _tick: int in 600:
		speed = LootMath.next_pull_speed(speed, TRACTOR, 0.1)
	assert_float(speed).is_equal(TRACTOR.pull_speed)


func test_a_pulled_container_rides_along_with_the_ship() -> void:
	var ship_velocity: Vector3 = Vector3(0.0, 0.0, -300.0)
	var velocity: Vector3 = LootMath.pulled_velocity(ship_velocity, Vector3(0.0, 0.0, -50.0), 90.0)
	# It follows the ship at 300 m/s and closes in on it at 90 m/s relative to it.
	assert_vector(velocity).is_equal(Vector3(0.0, 0.0, -390.0))
	assert_vector(LootMath.pulled_velocity(ship_velocity, Vector3.ZERO, 90.0)).is_equal(
		ship_velocity
	)


func test_scatter_dies_away_with_drag() -> void:
	var start: Vector3 = Vector3(10.0, 0.0, 0.0)
	var later: Vector3 = LootMath.drifted_velocity(start, 1.4, 1.0)
	assert_float(later.x).is_equal_approx(10.0 * exp(-1.4), 0.0001)
	assert_vector(LootMath.drifted_velocity(start, 0.0, 5.0)).is_equal(start)


func test_a_container_shrinks_in_its_last_seconds() -> void:
	assert_float(LootMath.expiry_scale(10.0)).is_equal(1.0)
	assert_float(LootMath.expiry_scale(LootMath.EXPIRY_FADE_SECONDS)).is_equal(1.0)
	assert_float(LootMath.expiry_scale(LootMath.EXPIRY_FADE_SECONDS * 0.5)).is_equal_approx(
		0.5, 0.0001
	)
	assert_float(LootMath.expiry_scale(0.0)).is_equal(0.0)
	assert_float(LootMath.expiry_scale(-1.0)).is_equal(0.0)
