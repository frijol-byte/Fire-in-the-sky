extends GdUnitTestSuite
## `AIProfileDef` content: the three pilot profiles, their ordering and the validation.

const STANDARD: AIProfileDef = preload("res://data/ai/standard.tres")


func test_the_profiles_are_registered_and_valid() -> void:
	for id: StringName in [&"rookie", &"standard", &"ace"]:
		var profile: AIProfileDef = Content.ai_profile(id)
		assert_object(profile).is_not_null()
		assert_array(profile.problems()).is_empty()


func test_an_ace_reacts_faster_aims_better_and_is_bolder_than_a_rookie() -> void:
	var rookie: AIProfileDef = Content.ai_profile(&"rookie")
	var standard: AIProfileDef = Content.ai_profile(&"standard")
	var ace: AIProfileDef = Content.ai_profile(&"ace")
	assert_float(rookie.reaction_time).is_greater(standard.reaction_time)
	assert_float(standard.reaction_time).is_greater(ace.reaction_time)
	assert_float(rookie.aim_error_deg).is_greater(standard.aim_error_deg)
	assert_float(standard.aim_error_deg).is_greater(ace.aim_error_deg)
	assert_float(rookie.aggression).is_less(standard.aggression)
	assert_float(standard.aggression).is_less(ace.aggression)
	assert_float(rookie.turn_gain).is_less(ace.turn_gain)


func test_an_unknown_profile_is_null() -> void:
	assert_object(Content.ai_profile(&"nobody")).is_null()


func test_problems_flags_bad_values() -> void:
	var bad: AIProfileDef = STANDARD.duplicate() as AIProfileDef
	bad.reaction_time = -1.0
	assert_array(bad.problems()).is_not_empty()
	bad = STANDARD.duplicate() as AIProfileDef
	bad.preferred_range_m = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = STANDARD.duplicate() as AIProfileDef
	bad.break_off_range_m = bad.preferred_range_m + 10.0
	assert_array(bad.problems()).is_not_empty()
	bad = STANDARD.duplicate() as AIProfileDef
	bad.turn_gain = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = STANDARD.duplicate() as AIProfileDef
	bad.sight_range_m = bad.preferred_range_m
	assert_array(bad.problems()).is_not_empty()


func test_the_enemy_rule_pairs_hostile_with_friendly_only() -> void:
	var hostile: Targeting.Stance = Targeting.Stance.HOSTILE
	var friendly: Targeting.Stance = Targeting.Stance.FRIENDLY
	var neutral: Targeting.Stance = Targeting.Stance.NEUTRAL
	assert_bool(AIPilot.is_enemy(hostile, friendly)).is_true()
	assert_bool(AIPilot.is_enemy(friendly, hostile)).is_true()
	assert_bool(AIPilot.is_enemy(hostile, hostile)).is_false()
	assert_bool(AIPilot.is_enemy(friendly, friendly)).is_false()
	assert_bool(AIPilot.is_enemy(neutral, hostile)).is_false()
	assert_bool(AIPilot.is_enemy(hostile, neutral)).is_false()
