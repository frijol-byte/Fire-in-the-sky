extends GdUnitTestSuite
## `FeedbackDef`: the shipped numbers are valid and each rule that `problems` checks is checked.


func test_the_default_feedback_def_is_valid() -> void:
	var def: FeedbackDef = Content.feedback()
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()


func _problems_with(change: Callable) -> PackedStringArray:
	var def: FeedbackDef = Content.feedback().duplicate() as FeedbackDef
	change.call(def)
	return def.problems()


func test_the_alarm_must_clear_above_where_it_starts() -> void:
	var found: PackedStringArray = _problems_with(
		func(d: FeedbackDef) -> void: d.low_shield_clear_fraction = d.low_shield_fraction
	)
	assert_array(found).is_not_empty()


func test_shake_strengths_stay_between_zero_and_one() -> void:
	assert_array(_problems_with(func(d: FeedbackDef) -> void: d.shake_death = 1.5)).is_not_empty()
	(
		assert_array(_problems_with(func(d: FeedbackDef) -> void: d.shake_hit_max = -0.1))
		. is_not_empty()
	)


func test_durations_must_be_positive() -> void:
	(
		assert_array(_problems_with(func(d: FeedbackDef) -> void: d.indicator_seconds = 0.0))
		. is_not_empty()
	)
	(
		assert_array(_problems_with(func(d: FeedbackDef) -> void: d.shake_hit_seconds = 0.0))
		. is_not_empty()
	)
	(
		assert_array(_problems_with(func(d: FeedbackDef) -> void: d.slowmo_seconds = 0.0))
		. is_not_empty()
	)
	(
		assert_array(_problems_with(func(d: FeedbackDef) -> void: d.alarm_interval = 0.0))
		. is_not_empty()
	)
	assert_array(_problems_with(func(d: FeedbackDef) -> void: d.max_indicators = 0)).is_not_empty()
