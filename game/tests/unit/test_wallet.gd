extends GdUnitTestSuite
## The debug wallet in `GameState`: credits, materials and paying out loot.


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


func test_a_new_game_starts_empty() -> void:
	assert_int(GameState.credits).is_equal(0)
	assert_int(GameState.material_count(&"scrap_metal")).is_equal(0)


func test_credits_add_up_and_never_go_below_zero() -> void:
	GameState.add_credits(50)
	GameState.add_credits(25)
	assert_int(GameState.credits).is_equal(75)
	GameState.add_credits(-1000)
	assert_int(GameState.credits).is_equal(0)


func test_materials_are_counted_per_id() -> void:
	GameState.add_material(&"scrap_metal", 2)
	GameState.add_material(&"coolant", 1)
	GameState.add_material(&"scrap_metal", 3)
	assert_int(GameState.material_count(&"scrap_metal")).is_equal(5)
	assert_int(GameState.material_count(&"coolant")).is_equal(1)


func test_collecting_a_drop_pays_credits_or_materials() -> void:
	GameState.collect(LootDrop.of_credits(40))
	GameState.collect(LootDrop.of_material(&"circuitry", 3))
	assert_int(GameState.credits).is_equal(40)
	assert_int(GameState.material_count(&"circuitry")).is_equal(3)


func test_every_change_is_announced() -> void:
	var changes: Array = []
	var listener: Callable = func() -> void: changes.append(true)
	Events.wallet_changed.connect(listener)
	GameState.add_credits(5)
	GameState.add_material(&"coolant", 1)
	GameState.reset()
	Events.wallet_changed.disconnect(listener)
	assert_int(changes.size()).is_equal(3)


func test_to_dict_carries_the_wallet() -> void:
	GameState.add_credits(12)
	GameState.add_material(&"coolant", 4)
	var data: Dictionary = GameState.to_dict()
	assert_int(data["schema_version"]).is_equal(GameState.SCHEMA_VERSION)
	assert_int(data["credits"]).is_equal(12)
	assert_int((data["materials"] as Dictionary)["coolant"]).is_equal(4)
