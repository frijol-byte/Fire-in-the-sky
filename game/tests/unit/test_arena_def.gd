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


func test_the_arena_offers_all_three_ships_in_slot_order() -> void:
	assert_array(FLIGHT_TEST.selectable_ship_ids).is_equal([&"kestrel", &"bulwark", &"drayman"])
	for ship_id: StringName in FLIGHT_TEST.selectable_ship_ids:
		assert_object(Content.ship(ship_id)).is_not_null()
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, 1)).is_equal("kestrel")
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, 2)).is_equal("bulwark")
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, 3)).is_equal("drayman")


func test_a_slot_without_a_ship_selects_nothing() -> void:
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, 0)).is_equal("")
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, 4)).is_equal("")
	assert_str(FlightTest.ship_for_slot(FLIGHT_TEST, -1)).is_equal("")
	assert_str(FlightTest.ship_for_slot(null, 1)).is_equal("")
	var arena: ArenaDef = _copy()
	arena.selectable_ship_ids = [&"kestrel"]
	assert_str(FlightTest.ship_for_slot(arena, 2)).is_equal("")


func test_problems_flags_a_bad_ship_list() -> void:
	var arena: ArenaDef = _copy()
	arena.selectable_ship_ids = [&"kestrel", &"kestrel"]
	assert_array(arena.problems()).is_not_empty()
	arena = _copy()
	arena.selectable_ship_ids = [&"kestrel", &"bulwark", &"drayman", &"kestrel"]
	assert_array(arena.problems()).is_not_empty()
