extends GdUnitTestSuite
## `TargetingDef` and `DifficultyDef`: the content is registered, valid and sensible.


func test_the_default_targeting_def_is_registered_and_valid() -> void:
	var def: TargetingDef = Content.targeting()
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()
	# The selection cone must be narrower than the screen, the lock longer than the longest gun.
	assert_float(def.select_cone_deg).is_less(45.0)
	for weapon_id: StringName in Content.ids(&"weapon"):
		assert_float(def.lock_range_m).is_greater(Content.weapon(weapon_id).range_m)


func test_bad_targeting_values_are_flagged() -> void:
	var def: TargetingDef = Content.targeting().duplicate() as TargetingDef
	def.lock_range_m = 0.0
	assert_array(def.problems()).is_not_empty()
	def = Content.targeting().duplicate() as TargetingDef
	def.select_cone_deg = 120.0
	assert_array(def.problems()).is_not_empty()
	def = Content.targeting().duplicate() as TargetingDef
	def.lock_loss_seconds = -1.0
	assert_array(def.problems()).is_not_empty()


func test_the_three_difficulties_are_registered_and_valid() -> void:
	for id: StringName in [&"easy", &"normal", &"hard"]:
		var def: DifficultyDef = Content.difficulty(id)
		assert_object(def).is_not_null()
		assert_array(def.problems()).is_empty()
		assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)


func test_bad_difficulty_values_are_flagged() -> void:
	var def: DifficultyDef = Content.difficulty(&"normal").duplicate() as DifficultyDef
	def.aim_assist_scale = 1.5
	assert_array(def.problems()).is_not_empty()
