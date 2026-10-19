extends GdUnitTestSuite
## The `ArenaDef` content: the flight arena is registered, valid, and bad values are caught.

const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")


func _copy() -> ArenaDef:
	return FLIGHT_TEST.duplicate() as ArenaDef


func test_the_flight_arena_is_registered_and_valid() -> void:
	var arena: ArenaDef = Content.get_def(&"arena", &"flight_test") as ArenaDef
	assert_object(arena).is_not_null()
	assert_array(arena.problems()).is_empty()
	assert_str(tr(arena.display_name_key)).is_not_equal(arena.display_name_key)
	assert_object(Content.ship(arena.spawn_ship_id)).is_not_null()


func test_the_arena_has_the_requested_content() -> void:
	# M1-T5: a 2000 rock field, about 30 solid rocks near the player and a few ring gates.
	assert_int(FLIGHT_TEST.field_rock_count).is_equal(2000)
	assert_int(FLIGHT_TEST.collider_pool_size).is_between(24, 40)
	assert_int(FLIGHT_TEST.gate_transforms.size()).is_between(3, 8)


func test_problems_flags_bad_values() -> void:
	var arena: ArenaDef = _copy()
	arena.field_outer_radius = arena.field_inner_radius
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.field_min_scale = 0.0
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.sky_sun_direction = Vector3.ZERO
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.spawn_look_at = arena.spawn_position
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.field_lane_radius = -1.0
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.collider_pool_size = 0
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.id = &""
	assert_array(arena.problems()).is_not_empty()


func test_light_direction_points_away_from_the_sun() -> void:
	var arena: ArenaDef = _copy()
	arena.sky_sun_direction = Vector3(0.0, 2.0, 0.0)
	assert_vector(arena.light_direction()).is_equal_approx(Vector3.DOWN, Vector3.ONE * 0.0001)
