extends GdUnitTestSuite
## `BarkMath`: behavior names, picking a line without repeating, and the radio gaps.


func test_behavior_names_match_the_bark_def() -> void:
	assert_str(String(BarkMath.behavior_name(AIUtility.Behavior.PURSUE))).is_equal("pursue")
	assert_str(String(BarkMath.behavior_name(AIUtility.Behavior.BREAK_OFF))).is_equal("break_off")
	assert_str(String(BarkMath.behavior_name(AIUtility.Behavior.USE_DEVICE))).is_equal("use_device")
	assert_str(String(BarkMath.behavior_name(99))).is_empty()


func test_a_line_is_never_the_one_just_said() -> void:
	for last: int in 5:
		for step: int in 20:
			var roll: float = step / 20.0
			assert_int(BarkMath.pick_line(5, last, roll)).is_not_equal(last)


func test_every_other_line_can_come_up() -> void:
	var seen: Dictionary[int, bool] = {}
	for step: int in 40:
		seen[BarkMath.pick_line(5, 2, step / 40.0)] = true
	assert_array(seen.keys()).contains_exactly_in_any_order([0, 1, 3, 4])


func test_with_no_last_line_all_lines_can_come_up() -> void:
	var seen: Dictionary[int, bool] = {}
	for step: int in 50:
		seen[BarkMath.pick_line(5, -1, step / 50.0)] = true
	assert_int(seen.size()).is_equal(5)


func test_a_roll_of_one_stays_in_range_and_one_line_is_always_zero() -> void:
	assert_int(BarkMath.pick_line(5, -1, 1.0)).is_equal(4)
	assert_int(BarkMath.pick_line(5, 4, 1.0)).is_equal(3)
	assert_int(BarkMath.pick_line(1, 0, 0.5)).is_equal(0)


func test_the_radio_and_the_pilot_each_need_their_gap() -> void:
	var def: BarkDef = Content.barks()
	var now: float = 100.0
	assert_bool(BarkMath.can_speak(now, -INF, -INF, def)).is_true()
	# The radio spoke a moment ago.
	assert_bool(BarkMath.can_speak(now, now - def.min_gap_seconds + 0.1, -INF, def)).is_false()
	assert_bool(BarkMath.can_speak(now, now - def.min_gap_seconds - 0.01, -INF, def)).is_true()
	# This pilot spoke recently, though the radio has been quiet.
	(
		assert_bool(BarkMath.can_speak(now, -INF, now - def.min_pilot_gap_seconds + 0.1, def))
		. is_false()
	)
	(
		assert_bool(BarkMath.can_speak(now, -INF, now - def.min_pilot_gap_seconds - 0.01, def))
		. is_true()
	)
