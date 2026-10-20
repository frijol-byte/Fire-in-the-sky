extends GdUnitTestSuite
## `SpeedFx`: the dust scatter, the streak length and the boost streaks' fade.


func test_scatter_is_deterministic_and_stays_in_the_box() -> void:
	var first: PackedVector3Array = SpeedFx.scatter(500, 170.0, 5)
	var second: PackedVector3Array = SpeedFx.scatter(500, 170.0, 5)
	assert_int(first.size()).is_equal(500)
	for index: int in first.size():
		assert_vector(first[index]).is_equal(second[index])
		assert_float(absf(first[index].x)).is_less_equal(85.0)
		assert_float(absf(first[index].y)).is_less_equal(85.0)
		assert_float(absf(first[index].z)).is_less_equal(85.0)


func test_scatter_with_another_seed_differs() -> void:
	var first: PackedVector3Array = SpeedFx.scatter(10, 100.0, 1)
	var second: PackedVector3Array = SpeedFx.scatter(10, 100.0, 2)
	assert_vector(first[0]).is_not_equal(second[0])


func test_streaks_grow_with_speed_and_never_vanish() -> void:
	assert_float(SpeedFx.streak_length(0.0, 0.03, 0.3)).is_equal(0.3)
	assert_float(SpeedFx.streak_length(180.0, 0.03, 0.3)).is_equal_approx(5.4, 0.0001)
	assert_float(SpeedFx.streak_length(320.0, 0.03, 0.3)).is_greater(
		SpeedFx.streak_length(180.0, 0.03, 0.3)
	)


func test_boost_streaks_fade_in_faster_than_they_fade_out() -> void:
	var rising: float = SpeedFx.boost_step(0.0, true, 0.1)
	var falling: float = 1.0 - SpeedFx.boost_step(1.0, false, 0.1)
	assert_float(rising).is_greater(falling)
	assert_float(rising).is_between(0.0, 1.0)


func test_boost_streaks_settle_at_the_ends() -> void:
	var amount: float = 0.0
	for _step: int in 120:
		amount = SpeedFx.boost_step(amount, true, 1.0 / 60.0)
	assert_float(amount).is_greater(0.99)
	for _step: int in 240:
		amount = SpeedFx.boost_step(amount, false, 1.0 / 60.0)
	assert_float(amount).is_less(0.01)


func test_the_node_builds_two_layers_with_the_expected_counts() -> void:
	var fx: SpeedFx = auto_free(SpeedFx.new())
	add_child(fx)
	var dust: MultiMeshInstance3D = fx.get_node("Dust") as MultiMeshInstance3D
	var streaks: MultiMeshInstance3D = fx.get_node("Streaks") as MultiMeshInstance3D
	assert_int(dust.multimesh.instance_count).is_equal(SpeedFx.DUST_COUNT)
	assert_int(streaks.multimesh.instance_count).is_equal(SpeedFx.STREAK_COUNT)
	assert_float(fx.boost_amount()).is_equal(0.0)
