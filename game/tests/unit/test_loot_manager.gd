extends GdUnitTestSuite
## `LootManager`: containers drift, expire, are capped, and the player's tractor pulls and collects.

const DT: float = 1.0 / 60.0


func before_test() -> void:
	GameState.reset()


func after_test() -> void:
	GameState.reset()


func _manager() -> LootManager:
	var manager: LootManager = auto_free(LootManager.new())
	add_child(manager)
	return manager


func _player(position: Vector3 = Vector3.ZERO) -> Ship:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	ship.global_position = position
	ship.targeting().is_player = true
	return ship


func _run(manager: LootManager, collector: Ship, seconds: float) -> void:
	for _tick: int in roundi(seconds / DT):
		manager.advance(DT, collector)


func test_a_container_drifts_and_slows_down() -> void:
	var manager: LootManager = _manager()
	var container: LootContainer = manager.spawn(
		LootDrop.of_credits(10), Vector3(0, 0, -500), Vector3(10, 0, 0), 60.0, 1.4
	)
	_run(manager, null, 1.0)
	var moved: float = container.global_position.x
	assert_float(moved).is_between(4.0, 9.0)
	_run(manager, null, 4.0)
	assert_float(container.global_position.x - moved).is_less(4.0)


func test_a_container_expires_after_its_lifetime() -> void:
	var manager: LootManager = _manager()
	manager.spawn(LootDrop.of_credits(10), Vector3(0, 0, -500), Vector3.ZERO, 2.0)
	var expired: Array = []
	manager.expired.connect(func(container: LootContainer) -> void: expired.append(container))
	_run(manager, null, 1.5)
	assert_int(manager.count()).is_equal(1)
	_run(manager, null, 1.0)
	assert_int(manager.count()).is_equal(0)
	assert_int(expired.size()).is_equal(1)
	assert_int(GameState.credits).is_equal(0)


func test_the_oldest_container_goes_when_the_cap_is_reached() -> void:
	var manager: LootManager = _manager()
	manager.max_containers = 3
	var first: LootContainer = manager.spawn(
		LootDrop.of_credits(1), Vector3.ZERO, Vector3.ZERO, 60.0
	)
	for index: int in 3:
		manager.spawn(LootDrop.of_credits(index + 2), Vector3.ZERO, Vector3.ZERO, 60.0)
	assert_int(manager.count()).is_equal(3)
	# The first container (1 credit) is the one that went.
	for container: LootContainer in manager.containers():
		assert_int(container.drop.credits).is_greater(1)
	assert_int(manager.spawned_total).is_equal(4)


func test_the_tractor_pulls_in_and_collects_a_container() -> void:
	var manager: LootManager = _manager()
	var ship: Ship = _player()
	manager.spawn(LootDrop.of_credits(40), Vector3(0, 0, -150), Vector3.ZERO, 60.0)
	var collected: Array = []
	manager.collected.connect(func(_c: LootContainer, who: Ship) -> void: collected.append(who))
	_run(manager, ship, 3.0)
	assert_int(manager.count()).is_equal(0)
	assert_int(GameState.credits).is_equal(40)
	assert_array(collected).has_size(1)
	assert_int(manager.collected_total).is_equal(1)


func test_a_material_container_pays_the_material() -> void:
	var manager: LootManager = _manager()
	var ship: Ship = _player()
	manager.spawn(LootDrop.of_material(&"coolant", 3), Vector3(0, 0, -60), Vector3.ZERO, 60.0)
	_run(manager, ship, 2.0)
	assert_int(GameState.material_count(&"coolant")).is_equal(3)
	assert_int(GameState.credits).is_equal(0)


func test_a_container_out_of_range_is_left_alone() -> void:
	var manager: LootManager = _manager()
	var ship: Ship = _player()
	var far: float = manager.tractor.range_m + 100.0
	var container: LootContainer = manager.spawn(
		LootDrop.of_credits(40), Vector3(0, 0, -far), Vector3.ZERO, 60.0
	)
	_run(manager, ship, 2.0)
	assert_int(manager.count()).is_equal(1)
	assert_bool(container.is_pulled()).is_false()
	assert_int(GameState.credits).is_equal(0)


func test_no_ship_means_no_pickup() -> void:
	var manager: LootManager = _manager()
	manager.spawn(LootDrop.of_credits(40), Vector3(0, 0, -20), Vector3.ZERO, 60.0)
	_run(manager, null, 2.0)
	assert_int(manager.count()).is_equal(1)
	assert_int(GameState.credits).is_equal(0)


func test_pickup_announces_itself_on_the_event_bus() -> void:
	var manager: LootManager = _manager()
	var ship: Ship = _player()
	var seen: Array = []
	var listener: Callable = func(who: Node, drop: LootDrop) -> void:
		seen.append([who, drop.credits])
	Events.loot_collected.connect(listener)
	manager.spawn(LootDrop.of_credits(25), Vector3(0, 0, -30), Vector3.ZERO, 60.0)
	_run(manager, ship, 1.0)
	Events.loot_collected.disconnect(listener)
	assert_array(seen).has_size(1)
	assert_int(seen[0][1]).is_equal(25)


func test_a_fast_ship_still_catches_a_container() -> void:
	var manager: LootManager = _manager()
	var ship: Ship = _player()
	ship.linear_velocity = Vector3(0, 0, -320)
	manager.spawn(LootDrop.of_credits(40), Vector3(0, 0, -150), Vector3.ZERO, 60.0)
	# The ship is moved by hand at its speed, as the physics would; the container rides along.
	for _tick: int in 240:
		ship.global_position += ship.linear_velocity * DT
		manager.advance(DT, ship)
		if manager.count() == 0:
			break
	assert_int(GameState.credits).is_equal(40)


func test_find_collector_picks_the_live_player_ship_only() -> void:
	var manager: LootManager = _manager()
	var ai: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	assert_object(manager.find_collector()).is_null()
	var player: Ship = _player()
	assert_object(manager.find_collector()).is_same(player)
	player.durability().apply(DamageInfo.make(10000.0, DamageInfo.Type.EXPLOSIVE))
	assert_object(manager.find_collector()).is_null()
	assert_object(ai).is_not_null()
