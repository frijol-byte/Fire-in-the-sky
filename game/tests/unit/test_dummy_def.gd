extends GdUnitTestSuite
## `DummyDef` content, and the dummies the flight arena places.

const STANDARD: DummyDef = preload("res://data/combat/dummy_standard.tres")


func test_the_dummies_are_registered_and_valid() -> void:
	for id: StringName in [&"standard", &"sturdy"]:
		var def: DummyDef = Content.dummy(id)
		assert_object(def).is_not_null()
		assert_array(def.problems()).is_empty()
		assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)


func test_problems_flags_bad_values() -> void:
	var def: DummyDef = STANDARD.duplicate() as DummyDef
	def.hull_capacity = 0.0
	assert_array(def.problems()).is_not_empty()
	def = STANDARD.duplicate() as DummyDef
	def.radius = 0.0
	assert_array(def.problems()).is_not_empty()
	def = STANDARD.duplicate() as DummyDef
	def.respawn_seconds = -1.0
	assert_array(def.problems()).is_not_empty()


func test_capacities_are_shield_armor_hull() -> void:
	assert_vector(STANDARD.capacities()).is_equal(Vector3(120, 100, 120))


func test_the_flight_arena_places_valid_dummies() -> void:
	var arena: ArenaDef = Content.get_def(&"arena", &"flight_test") as ArenaDef
	assert_int(arena.dummy_ids.size()).is_greater(2)
	assert_int(arena.dummy_origins.size()).is_equal(arena.dummy_ids.size())
	assert_int(arena.dummy_rails.size()).is_equal(arena.dummy_ids.size())
	var moving: int = 0
	for index: int in arena.dummy_ids.size():
		assert_object(Content.dummy(arena.dummy_ids[index])).is_not_null()
		if arena.dummy_rails[index] != Vector3.ZERO:
			moving += 1
	# The card asks for both static and moving targets.
	assert_int(moving).is_greater(0)
	assert_int(moving).is_less(arena.dummy_ids.size())


func test_mismatched_dummy_arrays_are_flagged() -> void:
	var arena: ArenaDef = (
		(Content.get_def(&"arena", &"flight_test") as ArenaDef).duplicate() as ArenaDef
	)
	# Assigned, not cleared: `duplicate()` shares the arrays with the real resource.
	var no_rails: Array[Vector3] = []
	arena.dummy_rails = no_rails
	assert_array(arena.problems()).is_not_empty()
