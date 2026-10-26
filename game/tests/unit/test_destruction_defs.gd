extends GdUnitTestSuite
## `DestructionDef` and `TractorDef`: the shipped defaults and what `problems()` rejects.

const DESTRUCTION: DestructionDef = preload("res://data/combat/destruction_default.tres")
const TRACTOR: TractorDef = preload("res://data/combat/tractor_default.tres")


func test_the_defaults_are_registered_and_valid() -> void:
	assert_object(Content.destruction()).is_not_null()
	assert_array(Content.destruction().problems()).is_empty()
	assert_object(Content.tractor()).is_not_null()
	assert_array(Content.tractor().problems()).is_empty()


func test_destruction_problems_flags_bad_values() -> void:
	var bad: DestructionDef = DESTRUCTION.duplicate() as DestructionDef
	bad.fireball_seconds = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = DESTRUCTION.duplicate() as DestructionDef
	bad.debris_speed_max = bad.debris_speed_min - 1.0
	assert_array(bad.problems()).is_not_empty()
	bad = DESTRUCTION.duplicate() as DestructionDef
	bad.debris_count = -1
	assert_array(bad.problems()).is_not_empty()
	bad = DESTRUCTION.duplicate() as DestructionDef
	bad.wreck_fade_seconds = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = DESTRUCTION.duplicate() as DestructionDef
	bad.respawn_input_delay = -0.1
	assert_array(bad.problems()).is_not_empty()
	bad = DESTRUCTION.duplicate() as DestructionDef
	bad.debris_size_min = 0.0
	assert_array(bad.problems()).is_not_empty()


func test_tractor_problems_flags_bad_values() -> void:
	var bad: TractorDef = TRACTOR.duplicate() as TractorDef
	bad.range_m = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = TRACTOR.duplicate() as TractorDef
	bad.collect_radius_m = bad.range_m
	assert_array(bad.problems()).is_not_empty()
	bad = TRACTOR.duplicate() as TractorDef
	bad.pull_speed = 0.0
	assert_array(bad.problems()).is_not_empty()


func test_the_tractor_collects_inside_a_ships_length() -> void:
	# The Kestrel is about 20 m long; the collect radius is measured from its centre.
	assert_float(TRACTOR.collect_radius_m).is_between(4.0, 20.0)
	assert_float(TRACTOR.range_m).is_greater(TRACTOR.collect_radius_m * 5.0)
