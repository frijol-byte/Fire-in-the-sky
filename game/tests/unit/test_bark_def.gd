extends GdUnitTestSuite
## `BarkDef`: five lines for every behavior that barks, every line translated, callsigns too.


func test_the_default_bark_def_is_valid() -> void:
	var def: BarkDef = Content.barks()
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()


func test_every_behavior_has_five_distinct_translated_lines() -> void:
	var def: BarkDef = Content.barks()
	assert_int(def.line_count).is_equal(5)
	for behavior_name: StringName in def.behaviors:
		var seen: Array[String] = []
		for line: int in def.line_count:
			var key: String = def.key_for(behavior_name, line)
			var text: String = tr(key)
			assert_str(text).is_not_equal(key)
			assert_array(seen).not_contains([text])
			seen.append(text)


func test_every_ai_behavior_can_bark() -> void:
	var def: BarkDef = Content.barks()
	for behavior_name: String in AIUtility.Behavior.keys():
		assert_float(def.chance_for(StringName(behavior_name.to_lower()))).is_greater(0.0)


func test_the_example_lines_from_the_design_are_there() -> void:
	var def: BarkDef = Content.barks()
	var lines: Array[String] = []
	for behavior_name: StringName in def.behaviors:
		for line: int in def.line_count:
			lines.append(tr(def.key_for(behavior_name, line)))
	assert_array(lines).contains(["Breaking left!", "He's on me!"])


func test_keys_are_named_after_the_behavior_and_numbered_from_one() -> void:
	var def: BarkDef = Content.barks()
	assert_str(def.key_for(&"break_off", 0)).is_equal("BARK_BREAK_OFF_1")
	assert_str(def.key_for(&"evade", 4)).is_equal("BARK_EVADE_5")


func test_a_behavior_without_barks_has_no_chance() -> void:
	assert_float(Content.barks().chance_for(&"dance")).is_equal(0.0)


func test_every_callsign_is_translated() -> void:
	var def: BarkDef = Content.barks()
	assert_array(def.callsign_keys).is_not_empty()
	for key: StringName in def.callsign_keys:
		assert_str(tr(String(key))).is_not_equal(String(key))


func test_bad_data_is_reported() -> void:
	var def: BarkDef = Content.barks().duplicate() as BarkDef
	def.behaviors.append(&"dance")
	assert_array(def.problems()).is_not_empty()
	def = Content.barks().duplicate() as BarkDef
	def.line_count = 1
	assert_array(def.problems()).is_not_empty()
	def = Content.barks().duplicate() as BarkDef
	def.chances[0] = 1.5
	assert_array(def.problems()).is_not_empty()
