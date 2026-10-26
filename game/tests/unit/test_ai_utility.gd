extends GdUnitTestSuite
## `AIUtility`: the behavior scores and the selector that picks among them.

const B = AIUtility.Behavior


## A target 600 m ahead on the nose and nothing dangerous: the calm starting point.
func _calm() -> AIUtility.Situation:
	var s: AIUtility.Situation = AIUtility.Situation.new()
	s.has_target = true
	s.distance = 600.0
	s.angle = 0.0
	s.engage_range = 300.0
	s.break_range = 140.0
	s.aggression = 0.75
	return s


func _best(s: AIUtility.Situation) -> int:
	return AIUtility.select(AIUtility.scores(s), B.PURSUE, 99.0, 0.5)


func test_with_no_target_the_pilot_idles_in_pursue() -> void:
	var s: AIUtility.Situation = AIUtility.Situation.new()
	assert_int(_best(s)).is_equal(B.PURSUE)
	assert_float(AIUtility.score(B.ATTACK_RUN, s)).is_equal(0.0)
	assert_float(AIUtility.score(B.BREAK_OFF, s)).is_equal(0.0)


func test_a_far_target_is_pursued() -> void:
	assert_int(_best(_calm())).is_equal(B.PURSUE)


func test_a_target_ahead_inside_the_engage_range_is_attacked() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	assert_int(_best(s)).is_equal(B.ATTACK_RUN)


func test_a_target_that_ended_up_behind_is_pursued_not_attacked() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.angle = deg_to_rad(150.0)
	assert_float(AIUtility.score(B.ATTACK_RUN, s)).is_equal(0.0)
	assert_int(_best(s)).is_equal(B.PURSUE)


func test_a_collision_course_breaks_off() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 100.0
	s.closing = 180.0
	s.collision_course = true
	assert_int(_best(s)).is_equal(B.BREAK_OFF)


func test_holding_station_close_behind_a_target_does_not_break_off() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 120.0
	s.closing = 0.0
	s.collision_course = false
	assert_int(_best(s)).is_equal(B.ATTACK_RUN)


func test_very_close_and_closing_breaks_off_even_without_a_predicted_collision() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 40.0
	s.closing = 30.0
	assert_int(_best(s)).is_equal(B.BREAK_OFF)


func test_ships_flying_side_by_side_do_not_keep_breaking_off() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 20.0
	s.closing = 2.0
	s.collision_course = false
	assert_float(AIUtility.score(B.BREAK_OFF, s)).is_equal(0.0)


func test_a_missile_lock_evades() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.locked_on = true
	assert_int(_best(s)).is_equal(B.EVADE)


func test_an_incoming_missile_with_flares_ready_uses_the_device() -> void:
	var s: AIUtility.Situation = _calm()
	s.incoming_missile = true
	s.flares_ready = true
	assert_int(_best(s)).is_equal(B.USE_DEVICE)


func test_an_incoming_missile_without_flares_evades() -> void:
	var s: AIUtility.Situation = _calm()
	s.incoming_missile = true
	s.flares_ready = false
	assert_float(AIUtility.score(B.USE_DEVICE, s)).is_equal(0.0)
	assert_int(_best(s)).is_equal(B.EVADE)


func test_a_cautious_pilot_evades_when_shot_and_a_reckless_one_keeps_attacking() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.under_fire = true
	s.aggression = 0.3
	assert_int(_best(s)).is_equal(B.EVADE)
	s.aggression = 0.95
	assert_int(_best(s)).is_equal(B.ATTACK_RUN)


func test_a_nearly_dead_target_pulls_even_a_cautious_pilot_in() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.under_fire = true
	s.aggression = 0.5
	assert_int(_best(s)).is_equal(B.EVADE)
	s.target_hull_fraction = 0.1
	assert_int(_best(s)).is_equal(B.ATTACK_RUN)


func test_a_hurt_cautious_pilot_breaks_off_a_reckless_one_does_not() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.shield_fraction = 0.1
	s.aggression = 0.1
	assert_int(_best(s)).is_equal(B.BREAK_OFF)
	s.aggression = 0.9
	assert_int(_best(s)).is_equal(B.ATTACK_RUN)


func test_a_chaser_in_the_sights_from_behind_evades_a_calm_pilot() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 400.0
	s.angle = deg_to_rad(160.0)
	s.in_sights = true
	s.aggression = 0.2
	assert_int(_best(s)).is_equal(B.EVADE)


func test_the_current_behavior_keeps_the_job_for_its_minimum_time() -> void:
	var scores: Dictionary[int, float] = {
		B.PURSUE: 0.5, B.ATTACK_RUN: 0.6, B.BREAK_OFF: 0.0, B.EVADE: 0.0, B.USE_DEVICE: 0.0
	}
	# Attack scores higher, but pursue was only just chosen and the lead is not urgent.
	assert_int(AIUtility.select(scores, B.PURSUE, 0.1, 0.6)).is_equal(B.PURSUE)
	assert_int(AIUtility.select(scores, B.PURSUE, 0.7, 0.6)).is_equal(B.ATTACK_RUN)


func test_something_much_more_urgent_cuts_in_during_the_minimum_time() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 250.0
	s.incoming_missile = true
	s.flares_ready = true
	var scores: Dictionary[int, float] = AIUtility.scores(s)
	assert_int(AIUtility.select(scores, B.ATTACK_RUN, 0.1, 1.5)).is_equal(B.USE_DEVICE)


func test_a_tie_keeps_the_current_behavior() -> void:
	var tied: Dictionary[int, float] = {
		B.PURSUE: 0.5, B.ATTACK_RUN: 0.5, B.BREAK_OFF: 0.0, B.EVADE: 0.0, B.USE_DEVICE: 0.0
	}
	assert_int(AIUtility.select(tied, B.ATTACK_RUN, 5.0, 0.5)).is_equal(B.ATTACK_RUN)
	assert_int(AIUtility.select(tied, B.PURSUE, 5.0, 0.5)).is_equal(B.PURSUE)


func test_every_score_is_in_a_sane_range() -> void:
	var s: AIUtility.Situation = _calm()
	s.distance = 100.0
	s.closing = 400.0
	s.collision_course = true
	s.under_fire = true
	s.locked_on = true
	s.incoming_missile = true
	s.flares_ready = true
	s.in_sights = true
	s.angle = deg_to_rad(170.0)
	for value: float in AIUtility.scores(s).values():
		assert_float(value).is_between(0.0, 1.3)
