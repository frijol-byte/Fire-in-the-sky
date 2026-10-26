extends GdUnitTestSuite
## `EncounterDef` and `WaveDef`: the combat test's waves are 1, then 2, then 3 pirates, all of
## ships and profiles that exist, and bad data is reported.


func test_the_combat_test_encounter_is_valid() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test")
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()


func test_the_waves_grow_from_one_to_three_pirates() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test")
	assert_int(def.waves.size()).is_equal(3)
	assert_int(def.waves[0].count()).is_equal(1)
	assert_int(def.waves[1].count()).is_equal(2)
	assert_int(def.waves[2].count()).is_equal(3)


func test_every_pirate_is_a_known_ship_with_a_known_profile() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test")
	for wave: WaveDef in def.waves:
		for slot: int in wave.count():
			assert_object(Content.ship(wave.ship_ids[slot])).is_not_null()
			assert_object(Content.ai_profile(wave.profile_ids[slot])).is_not_null()


func test_pirates_fly_pirate_ships() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test")
	for wave: WaveDef in def.waves:
		for ship_id: StringName in wave.ship_ids:
			assert_array(FlightSim.PIRATE_SHIP_IDS).contains([ship_id])


func test_the_combat_arena_def_exists_and_is_valid() -> void:
	var arena: ArenaDef = Content.get_def(&"arena", &"combat_test") as ArenaDef
	assert_object(arena).is_not_null()
	assert_array(arena.problems()).is_empty()
	assert_str(tr(arena.display_name_key)).is_not_equal(arena.display_name_key)
	assert_array(arena.gate_transforms).is_empty()


func test_bad_data_is_reported() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test").duplicate() as EncounterDef
	def.waves = []
	assert_array(def.problems()).is_not_empty()
	var wave: WaveDef = WaveDef.new()
	assert_array(wave.problems()).is_not_empty()
	wave.ship_ids = [&"pirate_fighter"]
	assert_array(wave.problems()).is_not_empty()
	wave.profile_ids = [&"rookie"]
	assert_array(wave.problems()).is_empty()
	def = Content.encounter(&"combat_test").duplicate() as EncounterDef
	def.spawn_distance_m = 0.0
	assert_array(def.problems()).is_not_empty()


func test_the_stagger_cannot_be_negative() -> void:
	var def: EncounterDef = Content.encounter(&"combat_test").duplicate() as EncounterDef
	def.stagger_seconds = -1.0
	assert_array(def.problems()).is_not_empty()
