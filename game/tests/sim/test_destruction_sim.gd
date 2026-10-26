extends GdUnitTestSuite
## Destruction (M2-T6) in a scene with a `DestructionManager`: dummies and ships blow up, ships
## become wrecks that tumble and fade, loot drops, and the player's tractor collects it.

const TICK: float = SimHelper.TICK
## A hit that destroys anything in the game.
const KILLING_BLOW: float = 100000.0

var _blasts: Array[Dictionary] = []


func before_test() -> void:
	GameState.reset()
	_blasts.clear()


func after_test() -> void:
	GameState.reset()


func _manager() -> DestructionManager:
	var manager: DestructionManager = auto_free(DestructionManager.new())
	add_child(manager)
	manager.blasted.connect(
		func(node: Node, position: Vector3, radius: float) -> void:
			_blasts.append({"node": node, "position": position, "radius": radius})
	)
	return manager


func _kill(target: Node) -> void:
	(target.call(&"durability") as Durability).apply(
		DamageInfo.make(KILLING_BLOW, DamageInfo.Type.EXPLOSIVE)
	)


func _run(seconds: float) -> void:
	await SimHelper.step_physics(get_tree(), roundi(seconds / TICK))


func ship_params() -> Array[Array]:
	return FlightSim.ship_params()


func test_a_destroyed_dummy_explodes_and_drops_loot() -> void:
	var manager: DestructionManager = _manager()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -200))
	)
	var table: LootTableDef = Content.loot_table(dummy.def.loot_table_id)
	_kill(dummy)
	assert_int(manager.explosions_total).is_equal(1)
	assert_int(_blasts.size()).is_equal(1)
	assert_vector(_blasts[0]["position"]).is_equal(dummy.global_position)
	assert_float(_blasts[0]["radius"]).is_greater_equal(manager.destruction.fireball_min_radius)
	assert_int(manager.debris.active_count()).is_equal(manager.destruction.debris_count)
	assert_int(manager.loot.count()).is_between(table.containers_min, table.containers_max)
	assert_int(manager.active_blasts()).is_equal(1)


func test_the_fireball_runs_its_course_and_the_debris_goes_away() -> void:
	var manager: DestructionManager = _manager()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -200))
	)
	_kill(dummy)
	await _run(0.5)
	assert_int(manager.active_blasts()).is_equal(1)
	assert_int(manager.debris.active_count()).is_greater(0)
	await _run(manager.destruction.debris_lifetime + 0.5)
	assert_int(manager.active_blasts()).is_equal(0)
	assert_int(manager.debris.active_count()).is_equal(0)


func test_a_destroyed_ship_becomes_a_wreck(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var manager: DestructionManager = _manager()
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, ship_id, Vector3(0, 0, -300)))
	ship.stance = Targeting.Stance.HOSTILE
	await _run(0.2)
	assert_bool(ship.is_wrecked()).is_false()
	assert_bool(ship.is_in_group(Targeting.GROUP)).is_true()
	_kill(ship)
	assert_bool(ship.is_wrecked()).is_true()
	assert_int(ship.collision_layer).is_equal(0)
	assert_int(ship.collision_mask).is_equal(0)
	assert_bool(ship.is_in_group(Targeting.GROUP)).is_false()
	assert_int(manager.explosions_total).is_equal(1)
	assert_float(_blasts[0]["radius"]).is_greater_equal(manager.destruction.fireball_min_radius)
	var table: LootTableDef = Content.loot_table(ship.def.loot_table_id)
	assert_int(manager.loot.count()).is_between(table.containers_min, table.containers_max)


func test_a_wreck_coasts_and_tumbles_and_nobody_flies_it() -> void:
	_manager()
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -300)))
	ship.stance = Targeting.Stance.HOSTILE
	var forward: ShipControls = FlightSim.controls(Vector3(0, 0, 1))
	await FlightSim.fly(get_tree(), ship, forward, 90)
	var speed: float = ship.linear_velocity.length()
	assert_float(speed).is_greater(10.0)
	_kill(ship)
	# Full throttle is still held, and the wreck ignores it: it neither speeds up nor brakes.
	await FlightSim.fly(get_tree(), ship, forward, 60)
	assert_float(ship.linear_velocity.length()).is_equal_approx(speed, speed * 0.02)
	assert_float(ship.angular_velocity.length()).is_greater(0.05)
	assert_bool(ship.is_boosting()).is_false()


func test_a_wreck_cannot_fire() -> void:
	_manager()
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -300)))
	var held: ShipControls = ShipControls.new()
	held.fire_primary = true
	_kill(ship)
	await FlightSim.fly(get_tree(), ship, held, 30)
	assert_int(ProjectileManager.for_node(self).active_count()).is_equal(0)


func test_an_ai_wreck_fades_and_leaves_the_world() -> void:
	var manager: DestructionManager = _manager()
	var ship: Ship = CombatSim.spawn_ai(
		self, &"kestrel", Vector3(0, 0, -300), Vector3(0, 0, -400), Targeting.Stance.HOSTILE
	)
	await _run(0.2)
	_kill(ship)
	var fade: float = manager.destruction.wreck_fade_seconds
	await _run(fade * 0.5)
	assert_bool(is_instance_valid(ship)).is_true()
	assert_float(ship.model.scale.x).is_between(0.001, 1.0)
	await _run(fade * 0.6 + 0.2)
	assert_bool(is_instance_valid(ship) and ship.is_inside_tree()).is_false()


func test_the_players_wreck_stays_for_the_respawn() -> void:
	var manager: DestructionManager = _manager()
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -300)))
	ship.targeting().is_player = true
	_kill(ship)
	await _run(manager.destruction.wreck_fade_seconds + 0.5)
	assert_bool(ship.is_inside_tree()).is_true()
	assert_bool(ship.model.visible).is_false()
	# The player's own ship drops nothing.
	assert_int(manager.loot.count()).is_equal(0)
	assert_int(manager.explosions_total).is_equal(1)


func test_a_wreck_sets_its_engines_dark() -> void:
	_manager()
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -300)))
	var engines: EngineFx = ship.get_node("EngineFx") as EngineFx
	assert_bool(engines.is_off()).is_false()
	_kill(ship)
	assert_bool(engines.is_off()).is_true()


func test_the_player_collects_the_loot_of_a_kill() -> void:
	var manager: DestructionManager = _manager()
	var player: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	player.targeting().is_player = true
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -120))
	)
	_kill(dummy)
	var dropped: int = manager.loot.count()
	assert_int(dropped).is_greater(0)
	await _run(8.0)
	assert_int(manager.loot.count()).is_equal(0)
	assert_int(manager.loot.collected_total).is_equal(dropped)
	var gained: int = GameState.credits
	for id: StringName in GameState.materials:
		gained += GameState.materials[id]
	assert_int(gained).is_greater(0)


func test_loot_nobody_collects_expires() -> void:
	var manager: DestructionManager = _manager()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -5000))
	)
	var table: LootTableDef = Content.loot_table(dummy.def.loot_table_id)
	_kill(dummy)
	assert_int(manager.loot.count()).is_greater(0)
	await _run(table.lifetime_seconds + 1.0)
	assert_int(manager.loot.count()).is_equal(0)
	assert_int(GameState.credits).is_equal(0)


func test_the_same_kill_drops_the_same_loot_every_time() -> void:
	var runs: Array[Array] = []
	for _run_index: int in 2:
		var manager: DestructionManager = DestructionManager.new()
		add_child(manager)
		var dummy: TargetDummy = CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -200))
		_kill(dummy)
		var credits: Array = []
		for container: LootContainer in manager.loot.containers():
			credits.append(
				[container.drop.credits, container.drop.material_id, container.drop.amount]
			)
		runs.append(credits)
		remove_child(dummy)
		dummy.free()
		remove_child(manager)
		manager.free()
	assert_array(runs[0]).is_equal(runs[1])


func test_many_kills_do_not_grow_the_pools() -> void:
	var manager: DestructionManager = _manager()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -200))
	)
	var children: int = manager.get_child_count()
	var debris_children: int = manager.debris.get_child_count()
	for _kill_index: int in 30:
		dummy.respawn()
		_kill(dummy)
		await _run(0.1)
	assert_int(manager.explosions_total).is_equal(30)
	assert_int(manager.debris.get_child_count()).is_equal(debris_children)
	assert_int(manager.get_child_count()).is_equal(children)
	assert_int(manager.loot.count()).is_less_equal(manager.loot.max_containers)


func test_a_dummy_that_is_destroyed_comes_back_whole() -> void:
	_manager()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -200))
	)
	_kill(dummy)
	assert_bool(dummy.is_destroyed()).is_true()
	await _run(dummy.def.respawn_seconds + 0.5)
	assert_bool(dummy.is_destroyed()).is_false()
	assert_float(dummy.durability().hull).is_equal(dummy.def.hull_capacity)


func test_a_gun_kill_leaves_a_wreck_and_loot() -> void:
	var manager: DestructionManager = _manager()
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var target: Ship = auto_free(
		CombatSim.spawn_ship(self, &"drayman", Vector3(0, 0, -600), Vector3(0, 0, 0))
	)
	target.stance = Targeting.Stance.HOSTILE
	var shooter: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			&"kestrel",
			Vector3.ZERO,
			target.global_position,
			Targeting.Stance.FRIENDLY,
			&"standard",
			1,
			target
		)
	)
	var limit: int = roundi(120.0 / TICK)
	for _tick: int in limit:
		await get_tree().physics_frame
		if target.is_wrecked():
			break
	assert_bool(target.is_wrecked()).is_true()
	assert_bool(shooter.is_wrecked()).is_false()
	assert_int(manager.explosions_total).is_equal(1)
	assert_int(manager.loot.count()).is_greater(0)
