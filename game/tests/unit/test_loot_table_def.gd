extends GdUnitTestSuite
## `LootTableDef`: the shipped tables, their problems and the roll that turns one into drops.

const LIGHT: LootTableDef = preload("res://data/loot/loot_light.tres")


func _rng(seed_value: int = 7) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_the_shipped_tables_are_registered_and_valid() -> void:
	assert_array(Content.ids(&"loot_table")).contains_exactly(
		[&"dummy", &"heavy", &"light", &"medium"]
	)
	for id: StringName in Content.ids(&"loot_table"):
		assert_array(Content.loot_table(id).problems()).is_empty()


func test_every_ship_and_dummy_names_a_loot_table_that_exists() -> void:
	for id: StringName in Content.ids(&"ship"):
		var ship: ShipDef = Content.ship(id)
		assert_object(Content.loot_table(ship.loot_table_id)).is_not_null()
	for id: StringName in Content.ids(&"dummy"):
		var dummy: DummyDef = Content.dummy(id)
		assert_object(Content.loot_table(dummy.loot_table_id)).is_not_null()


func test_bigger_ships_drop_richer_loot() -> void:
	var light: LootTableDef = Content.loot_table(&"light")
	var heavy: LootTableDef = Content.loot_table(&"heavy")
	assert_int(heavy.containers_max).is_greater(light.containers_max)
	assert_int(heavy.credits_max).is_greater(light.credits_max)


func test_every_material_has_a_display_name() -> void:
	for id: StringName in Content.ids(&"loot_table"):
		for material_id: StringName in Content.loot_table(id).material_ids:
			var key: String = "MATERIAL_%s" % String(material_id).to_upper()
			assert_str(tr(key)).is_not_equal(key)


func test_problems_flags_bad_values() -> void:
	var bad: LootTableDef = LIGHT.duplicate() as LootTableDef
	bad.containers_max = bad.containers_min - 1
	assert_array(bad.problems()).is_not_empty()
	bad = LIGHT.duplicate() as LootTableDef
	bad.credits_min = -1
	assert_array(bad.problems()).is_not_empty()
	bad = LIGHT.duplicate() as LootTableDef
	bad.material_chance = 1.5
	assert_array(bad.problems()).is_not_empty()
	bad = LIGHT.duplicate() as LootTableDef
	bad.material_ids = []
	assert_array(bad.problems()).is_not_empty()
	bad = LIGHT.duplicate() as LootTableDef
	bad.lifetime_seconds = 0.0
	assert_array(bad.problems()).is_not_empty()
	bad = LIGHT.duplicate() as LootTableDef
	bad.material_amount_min = 0
	assert_array(bad.problems()).is_not_empty()


func test_a_roll_stays_within_the_table() -> void:
	var rng: RandomNumberGenerator = _rng()
	for _round: int in 40:
		var drops: Array[LootDrop] = LIGHT.roll(rng)
		assert_int(drops.size()).is_between(LIGHT.containers_min, LIGHT.containers_max)
		for drop: LootDrop in drops:
			if drop.is_credits():
				assert_int(drop.credits).is_between(LIGHT.credits_min, LIGHT.credits_max)
				assert_int(drop.amount).is_equal(0)
			else:
				assert_array(LIGHT.material_ids).contains([drop.material_id])
				assert_int(drop.amount).is_between(
					LIGHT.material_amount_min, LIGHT.material_amount_max
				)
				assert_int(drop.credits).is_equal(0)


func test_the_same_seed_rolls_the_same_loot() -> void:
	var first: Array[LootDrop] = LIGHT.roll(_rng(99))
	var second: Array[LootDrop] = LIGHT.roll(_rng(99))
	assert_int(second.size()).is_equal(first.size())
	for index: int in first.size():
		assert_int(second[index].credits).is_equal(first[index].credits)
		assert_str(String(second[index].material_id)).is_equal(String(first[index].material_id))
		assert_int(second[index].amount).is_equal(first[index].amount)


func test_material_chance_zero_gives_only_credits_and_one_only_materials() -> void:
	var credits_only: LootTableDef = LIGHT.duplicate() as LootTableDef
	credits_only.material_chance = 0.0
	var materials_only: LootTableDef = LIGHT.duplicate() as LootTableDef
	materials_only.material_chance = 1.0
	var rng: RandomNumberGenerator = _rng()
	for _round: int in 20:
		for drop: LootDrop in credits_only.roll(rng):
			assert_bool(drop.is_credits()).is_true()
		for drop: LootDrop in materials_only.roll(rng):
			assert_bool(drop.is_credits()).is_false()


func test_a_table_with_no_materials_still_rolls() -> void:
	var table: LootTableDef = LIGHT.duplicate() as LootTableDef
	table.material_ids = []
	table.material_chance = 0.0
	assert_array(table.problems()).is_empty()
	assert_array(table.roll(_rng())).is_not_empty()


func test_an_empty_table_drops_nothing() -> void:
	var table: LootTableDef = LIGHT.duplicate() as LootTableDef
	table.containers_min = 0
	table.containers_max = 0
	assert_array(table.roll(_rng())).is_empty()
