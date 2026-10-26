extends GdUnitTestSuite
## `EncounterMath`: where the pirates of a wave appear and what follows what.

const START: Transform3D = Transform3D.IDENTITY


func test_a_lone_pirate_comes_straight_ahead_at_the_spawn_distance() -> void:
	var spot: Transform3D = EncounterMath.spawn_transform(START, 0, 1, 800.0, 50.0)
	assert_vector(spot.origin).is_equal_approx(Vector3(0, 0, -800), Vector3.ONE * 0.01)


func test_pirates_start_at_the_distance_and_face_the_player() -> void:
	for count: int in range(1, 4):
		for index: int in count:
			var spot: Transform3D = EncounterMath.spawn_transform(START, index, count, 800.0, 50.0)
			assert_float(spot.origin.length()).is_equal_approx(800.0, 0.5)
			var facing: Vector3 = -spot.basis.z
			assert_float(facing.dot((-spot.origin).normalized())).is_greater(0.999)


func test_a_wave_is_spread_across_the_arc_in_front_of_the_nose() -> void:
	var left: Transform3D = EncounterMath.spawn_transform(START, 0, 3, 800.0, 50.0)
	var middle: Transform3D = EncounterMath.spawn_transform(START, 1, 3, 800.0, 50.0)
	var right: Transform3D = EncounterMath.spawn_transform(START, 2, 3, 800.0, 50.0)
	assert_float(left.origin.x).is_less(middle.origin.x)
	assert_float(middle.origin.x).is_less(right.origin.x)
	var yaw: float = rad_to_deg(atan2(right.origin.x, -right.origin.z))
	assert_float(absf(yaw)).is_equal_approx(25.0, 0.5)
	for spot: Transform3D in [left, middle, right]:
		assert_float(spot.origin.z).is_less(0.0)


func test_pirates_after_the_first_alternate_above_and_below() -> void:
	var first: Transform3D = EncounterMath.spawn_transform(START, 0, 3, 800.0, 50.0)
	var second: Transform3D = EncounterMath.spawn_transform(START, 1, 3, 800.0, 50.0)
	var third: Transform3D = EncounterMath.spawn_transform(START, 2, 3, 800.0, 50.0)
	assert_float(first.origin.y).is_equal_approx(0.0, 0.01)
	assert_float(second.origin.y).is_greater(1.0)
	assert_float(third.origin.y).is_less(-1.0)


func test_the_wave_is_placed_relative_to_where_the_player_looks() -> void:
	var turned: Transform3D = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(100, 0, 0))
	var spot: Transform3D = EncounterMath.spawn_transform(turned, 0, 1, 500.0, 50.0)
	# A quarter turn left makes -Z point at -X.
	assert_vector(spot.origin).is_equal_approx(Vector3(-400, 0, 0), Vector3.ONE * 0.01)


func test_waves_follow_each_other_and_the_last_wraps_or_ends() -> void:
	assert_int(EncounterMath.next_wave(0, 3, true)).is_equal(1)
	assert_int(EncounterMath.next_wave(1, 3, false)).is_equal(2)
	assert_int(EncounterMath.next_wave(2, 3, true)).is_equal(0)
	assert_int(EncounterMath.next_wave(2, 3, false)).is_equal(-1)
	assert_int(EncounterMath.next_wave(0, 0, true)).is_equal(-1)
