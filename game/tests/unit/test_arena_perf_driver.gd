extends GdUnitTestSuite
## The performance script's statistics and its scripted flight.


func test_summarize_gives_average_percentile_and_worst() -> void:
	var times: PackedFloat64Array = []
	for index: int in 100:
		times.append(float(index + 1))
	var stats: Dictionary = ArenaPerfDriver.summarize(times)
	assert_float(stats["avg_ms"] as float).is_equal_approx(50.5, 0.0001)
	assert_float(stats["p95_ms"] as float).is_equal(95.0)
	assert_float(stats["max_ms"] as float).is_equal(100.0)
	assert_float(stats["fps"] as float).is_equal_approx(1000.0 / 50.5, 0.0001)


func test_summarize_of_nothing_is_zero() -> void:
	assert_float(ArenaPerfDriver.summarize(PackedFloat64Array())["fps"] as float).is_equal(0.0)


func test_the_flight_boosts_after_a_while_and_always_has_throttle() -> void:
	var early: ShipControls = ArenaPerfDriver.controls_for_tick(1)
	var late: ShipControls = ArenaPerfDriver.controls_for_tick(ArenaPerfDriver.BOOST_FROM_TICK + 1)
	assert_bool(early.boost).is_false()
	assert_bool(late.boost).is_true()
	assert_float(early.thrust.z).is_equal(1.0)
	assert_float(late.thrust.z).is_equal(1.0)


func test_the_flight_changes_turn_direction() -> void:
	var turns: Array[float] = []
	for phase: int in 4:
		var rate: float = (
			ArenaPerfDriver.controls_for_tick(phase * ArenaPerfDriver.TURN_EVERY_TICKS).rotate.y
		)
		turns.append(snappedf(rate, 0.01))
	assert_array(turns).contains([0.0, 0.4, -0.4])
