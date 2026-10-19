extends GdUnitTestSuite
## `RockField`: the same seed gives the same field, the rocks respect the ArenaDef (counts,
## radii, scales, clear lane, gate clearance) and the nearby-rocks query is exact.

const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")
const VARIANT_RADII: PackedFloat32Array = [5.0, 6.0, 5.5, 5.0]


func _small_arena(count: int = 400) -> ArenaDef:
	var arena: ArenaDef = FLIGHT_TEST.duplicate() as ArenaDef
	arena.field_rock_count = count
	return arena


func test_the_same_seed_gives_the_same_field() -> void:
	var first: RockField = RockField.generate(_small_arena(), VARIANT_RADII)
	var second: RockField = RockField.generate(_small_arena(), VARIANT_RADII)
	assert_int(first.count()).is_equal(second.count())
	for index: int in first.count():
		assert_bool(first.transforms[index].is_equal_approx(second.transforms[index])).is_true()
		assert_int(first.variants[index]).is_equal(second.variants[index])


func test_a_different_seed_gives_a_different_field() -> void:
	var other: ArenaDef = _small_arena()
	other.field_seed += 1
	var first: RockField = RockField.generate(_small_arena(), VARIANT_RADII)
	var second: RockField = RockField.generate(other, VARIANT_RADII)
	assert_bool(first.transforms[0].origin.is_equal_approx(second.transforms[0].origin)).is_false()


func test_the_flight_arena_makes_its_full_field() -> void:
	var field: RockField = RockField.generate(FLIGHT_TEST, VARIANT_RADII)
	assert_int(field.count()).is_equal(FLIGHT_TEST.field_rock_count)


func test_every_variant_is_used() -> void:
	var field: RockField = RockField.generate(_small_arena(), VARIANT_RADII)
	for variant: int in VARIANT_RADII.size():
		assert_bool(field.variants.has(variant)).is_true()


func test_rocks_stay_in_the_belt_with_scales_in_range() -> void:
	var arena: ArenaDef = _small_arena()
	var field: RockField = RockField.generate(arena, VARIANT_RADII)
	for index: int in field.count():
		var rock: Transform3D = field.transforms[index]
		var offset: Vector3 = rock.origin - arena.spawn_position
		assert_float(offset.length()).is_less_equal(arena.field_outer_radius + 0.01)
		# Flattened into a belt: height is at most the vertical scale of the radius.
		assert_float(absf(offset.y)).is_less_equal(
			arena.field_outer_radius * arena.field_vertical_scale + 0.01
		)
		var scale: float = rock.basis.get_scale().x
		assert_float(scale).is_between(arena.field_min_scale - 0.001, arena.field_max_scale + 0.001)
		assert_float(field.radii[index]).is_equal_approx(
			VARIANT_RADII[field.variants[index]] * scale, 0.001
		)


func test_rocks_leave_a_clear_lane_around_the_start() -> void:
	var arena: ArenaDef = _small_arena(1500)
	var field: RockField = RockField.generate(arena, VARIANT_RADII)
	for index: int in field.count():
		var gap: float = (
			field.transforms[index].origin.distance_to(arena.spawn_position) - field.radii[index]
		)
		assert_float(gap).is_greater_equal(arena.field_inner_radius - 0.01)


func test_rocks_keep_clear_of_the_course() -> void:
	var arena: ArenaDef = _small_arena(2000)
	var course: PackedVector3Array = FlightTest.course_line(arena)
	var field: RockField = RockField.generate(arena, VARIANT_RADII, course)
	assert_int(field.count()).is_greater(1500)
	for index: int in field.count():
		for leg: int in course.size() - 1:
			var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(
				field.transforms[index].origin, course[leg], course[leg + 1]
			)
			var gap: float = (
				field.transforms[index].origin.distance_to(nearest) - field.radii[index]
			)
			assert_float(gap).is_greater_equal(arena.field_lane_radius - 0.01)


func test_without_a_course_rocks_may_be_anywhere_outside_the_start_lane() -> void:
	var arena: ArenaDef = _small_arena(300)
	var with_course: RockField = RockField.generate(
		arena, VARIANT_RADII, FlightTest.course_line(arena)
	)
	var without: RockField = RockField.generate(arena, VARIANT_RADII)
	assert_int(without.count()).is_equal(300)
	assert_int(with_course.count()).is_less_equal(300)


func test_small_rocks_outnumber_giants() -> void:
	var arena: ArenaDef = _small_arena(1500)
	var field: RockField = RockField.generate(arena, VARIANT_RADII)
	var halfway: float = (arena.field_min_scale + arena.field_max_scale) * 0.5
	var big: int = 0
	for index: int in field.count():
		if field.transforms[index].basis.get_scale().x > halfway:
			big += 1
	assert_int(big).is_less(field.count() / 5)


func test_the_field_is_denser_near_the_centre() -> void:
	var arena: ArenaDef = _small_arena(1500)
	var field: RockField = RockField.generate(arena, VARIANT_RADII)
	var middle: float = (arena.field_inner_radius + arena.field_outer_radius) * 0.5
	var inside: int = 0
	for index: int in field.count():
		if field.transforms[index].origin.length() < middle:
			inside += 1
	assert_int(inside).is_greater(field.count() / 2)


func test_nearby_matches_a_brute_force_search_and_is_sorted() -> void:
	var field: RockField = RockField.generate(_small_arena(1500), VARIANT_RADII)
	var point: Vector3 = Vector3(150.0, 20.0, -300.0)
	var radius: float = 500.0
	var expected: Array[int] = []
	for index: int in field.count():
		if field.transforms[index].origin.distance_to(point) - field.radii[index] <= radius:
			expected.append(index)
	var found: PackedInt32Array = field.nearby(point, radius, 100000)
	assert_int(found.size()).is_equal(expected.size())
	var last_gap: float = -INF
	for index: int in found:
		assert_bool(expected.has(index)).is_true()
		var gap: float = field.transforms[index].origin.distance_to(point) - field.radii[index]
		assert_float(gap).is_greater_equal(last_gap)
		last_gap = gap


func test_nearby_respects_the_limit() -> void:
	var field: RockField = RockField.generate(_small_arena(1500), VARIANT_RADII)
	var found: PackedInt32Array = field.nearby(Vector3.ZERO, 2000.0, 5)
	assert_int(found.size()).is_equal(5)


func test_no_variants_gives_an_empty_field() -> void:
	assert_int(RockField.generate(_small_arena(), PackedFloat32Array()).count()).is_equal(0)
