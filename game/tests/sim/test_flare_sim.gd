extends GdUnitTestSuite
## Countermeasure Flares: the device (slot, cooldown, what blocks it), how often a missile is fooled
## (a seeded statistical test), and what a fooled missile does in flight.

const TICK: float = SimHelper.TICK
const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
const FLARES: DeviceDef = preload("res://data/devices/flares.tres")

var _manager: MissileManager = null


func before_test() -> void:
	_manager = auto_free(CombatSim.spawn_missile_manager(self))


func _press(ship: Ship, slot: int) -> void:
	var controls: ShipControls = ShipControls.new()
	controls.device = slot
	ship.controls = controls


## A copy of the flares with the given decoy chance and burn time.
func _flares(chance: float, lifetime: float = FLARES.flare_lifetime) -> DeviceDef:
	var copy: DeviceDef = FLARES.duplicate() as DeviceDef
	copy.decoy_chance = chance
	copy.flare_lifetime = lifetime
	return copy


## `count` homing missiles hunting `ship`, spread on a ring `distance` metres out.
func _swarm(ship: Ship, count: int, distance: float) -> Array[Missile]:
	var swarm: Array[Missile] = []
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var origin: Vector3 = ship.global_position + Vector3(cos(angle), 0.2, sin(angle)) * distance
		swarm.append(_manager.launch(MISSILE, null, origin, Vector3.ZERO, ship))
	return swarm


func _fooled(swarm: Array[Missile]) -> int:
	var fooled: int = 0
	for missile: Missile in swarm:
		if missile.decoy != null:
			fooled += 1
	return fooled


func test_pressing_the_device_button_throws_flares_and_starts_the_cooldown() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 3)
	var uses: Array[int] = []
	ship.devices().used.connect(func(slot: int, _def: DeviceDef) -> void: uses.append(slot))
	assert_bool(ship.devices().is_ready(1)).is_true()
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 1)
	assert_array(uses).is_equal([1])
	assert_int(_manager.active_flares().size()).is_equal(FLARES.flare_count)
	assert_float(ship.devices().cooldown_left(1)).is_greater(FLARES.cooldown - 0.1)
	assert_bool(ship.devices().is_ready(1)).is_false()
	# The press was used up, not repeated every tick.
	assert_int(ship.controls.device).is_equal(0)


func test_a_second_press_during_the_cooldown_does_nothing() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 3)
	var uses: Array[int] = []
	ship.devices().used.connect(func(slot: int, _def: DeviceDef) -> void: uses.append(slot))
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 60)
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 2)
	assert_array(uses).has_size(1)
	assert_int(_manager.active_flares().size()).is_equal(FLARES.flare_count)
	# Once the cooldown is over, it works again.
	await SimHelper.step_physics(get_tree(), int(FLARES.cooldown / TICK))
	assert_bool(ship.devices().is_ready(1)).is_true()
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 1)
	assert_array(uses).has_size(2)


func test_an_empty_slot_does_nothing() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 3)
	assert_int(ship.devices().count()).is_equal(1)
	for slot: int in [2, 3]:
		_press(ship, slot)
		await SimHelper.step_physics(get_tree(), 2)
		assert_bool(ship.devices().use(slot)).is_false()
	assert_int(_manager.active_flares().size()).is_equal(0)


func test_an_ion_hit_blocks_the_flares() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 3)
	ship.durability().apply(DamageInfo.make(5.0, DamageInfo.Type.ION))
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.active_flares().size()).is_equal(0)
	assert_bool(ship.devices().is_ready(1)).is_true()
	# After the ion wears off the device works.
	await SimHelper.step_physics(
		get_tree(), int((Content.damage_table().ion_disable_seconds + 0.5) / TICK)
	)
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.active_flares().size()).is_equal(FLARES.flare_count)


func test_a_wreck_cannot_use_devices() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 3)
	ship.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	_press(ship, 1)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.active_flares().size()).is_equal(0)


func test_a_device_that_costs_energy_needs_the_energy() -> void:
	var costly: DeviceDef = _flares(1.0)
	costly.id = &"flares_costly"
	costly.energy_cost = 30.0
	Content.register(&"device", costly.id, costly)
	var ship_def: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	ship_def.device_ids = [costly.id]
	var ship: Ship = FlightSim.SHIP_SCENE.instantiate() as Ship
	ship.def = ship_def
	add_child(ship)
	auto_free(ship)
	await SimHelper.step_physics(get_tree(), 3)
	ship.power().regen_per_second = 0.0
	ship.power().energy = 20.0
	assert_bool(ship.devices().use(1)).is_false()
	assert_int(_manager.active_flares().size()).is_equal(0)
	assert_float(ship.power().energy).is_equal(20.0)
	ship.power().energy = 100.0
	assert_bool(ship.devices().use(1)).is_true()
	assert_float(ship.power().energy).is_equal_approx(70.0, 0.001)
	Content.unregister(&"device", costly.id)


func test_the_decoy_rate_matches_the_def() -> void:
	# 2000 missiles hunt one ship; one use of the flares rolls once for each (seeded).
	var big: MissileManager = auto_free(CombatSim.spawn_missile_manager(self, 2000))
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 2)
	_manager = big
	var swarm: Array[Missile] = _swarm(ship, 2000, 400.0)
	var fooled: int = big.deploy_flares(ship, FLARES)
	assert_int(fooled).is_equal(_fooled(swarm))
	var rate: float = float(fooled) / 2000.0
	# 0.65 with a standard deviation of 0.011 over 2000 rolls.
	assert_float(rate).is_between(FLARES.decoy_chance - 0.04, FLARES.decoy_chance + 0.04)


func test_the_decoy_rolls_are_repeatable_and_follow_the_seed() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 2)
	var counts: Array[int] = []
	for seed_value: int in [11, 11, 12]:
		var run: MissileManager = auto_free(CombatSim.spawn_missile_manager(self, 400))
		run.seed_rolls(seed_value)
		_swarm_into(run, ship, 400)
		counts.append(run.deploy_flares(ship, FLARES))
	assert_int(counts[0]).is_equal(counts[1])
	assert_int(counts[0]).is_not_equal(counts[2])
	for count: int in counts:
		assert_float(float(count) / 400.0).is_between(0.55, 0.75)


func _swarm_into(manager: MissileManager, ship: Ship, count: int) -> void:
	for index: int in count:
		var angle: float = TAU * float(index) / float(count)
		var origin: Vector3 = ship.global_position + Vector3(cos(angle), 0.2, sin(angle)) * 400.0
		manager.launch(MISSILE, null, origin, Vector3.ZERO, ship)


func test_only_missiles_close_enough_and_hunting_this_ship_are_rolled() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var other: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -2000)))
	await SimHelper.step_physics(get_tree(), 2)
	var sure: DeviceDef = _flares(1.0)
	var close: Array[Missile] = _swarm(ship, 5, sure.decoy_range_m - 50.0)
	var far: Array[Missile] = _swarm(ship, 5, sure.decoy_range_m + 50.0)
	var elsewhere: Array[Missile] = _swarm(other, 5, 300.0)
	var rocket: Missile = _manager.launch(
		Content.secondary(&"rocket_pod"), null, Vector3(0, 0, 100), Vector3.ZERO, ship
	)
	var fooled: int = _manager.deploy_flares(ship, sure)
	assert_int(fooled).is_equal(5)
	assert_int(_fooled(close)).is_equal(5)
	assert_int(_fooled(far)).is_equal(0)
	assert_int(_fooled(elsewhere)).is_equal(0)
	assert_object(rocket.decoy).is_null()


func test_a_fooled_missile_stops_counting_as_incoming() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 2)
	var swarm: Array[Missile] = _swarm(ship, 3, 300.0)
	var fooled_events: Array[Missile] = []
	_manager.decoyed.connect(
		func(missile: Missile, _flare: Flare) -> void: fooled_events.append(missile)
	)
	assert_array(_manager.incoming_for(ship)).has_size(3)
	_manager.deploy_flares(ship, _flares(1.0))
	assert_array(_manager.incoming_for(ship)).is_empty()
	assert_array(fooled_events).has_size(3)
	for missile: Missile in swarm:
		assert_bool(missile.guided).is_true()


## A missile 900 m ahead of a stationary ship, flying at it; the flares go off when it is 250 m out.
func _incoming_with_flares(chance: float) -> Dictionary:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -900)))
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var blasts: CombatSim.BlastLog = CombatSim.BlastLog.new()
	blasts.attach(_manager)
	await SimHelper.step_physics(get_tree(), 3)
	var missile: Missile = _manager.launch(
		MISSILE, shooter, Vector3(0, -1, -905), Vector3(0, 0, MISSILE.launch_speed), ship
	)
	var deployed: bool = false
	for tick: int in int(MISSILE.lifetime / TICK):
		await get_tree().physics_frame
		if not missile.active:
			break
		if not deployed and missile.position.distance_to(ship.global_position) < 250.0:
			deployed = true
			_manager.deploy_flares(ship, _flares(chance))
	return {"ship": ship, "missile": missile, "blasts": blasts}


func test_flares_can_make_a_missile_go_off_harmlessly() -> void:
	var run: Dictionary = await _incoming_with_flares(1.0)
	var ship: Ship = run["ship"] as Ship
	var blasts: CombatSim.BlastLog = run["blasts"] as CombatSim.BlastLog
	assert_int(blasts.blasts.size()).is_equal(1)
	assert_float(ship.durability().shield).is_equal(ship.durability().shield_capacity)
	# It chased a flare and went off at it (or burned out), never at the ship.
	assert_bool(blasts.blasts[0]["harmless"] as bool).is_true()


func test_without_a_decoy_the_same_missile_hits() -> void:
	var run: Dictionary = await _incoming_with_flares(0.0)
	var ship: Ship = run["ship"] as Ship
	var blasts: CombatSim.BlastLog = run["blasts"] as CombatSim.BlastLog
	assert_int(blasts.damaging().size()).is_equal(1)
	assert_float(ship.durability().shield).is_less(ship.durability().shield_capacity)


func test_flares_burn_out_and_a_missile_chasing_one_then_flies_unguided() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 2)
	var missile: Missile = _manager.launch(
		MISSILE, null, Vector3(0, 0, -500), Vector3(0, 0, MISSILE.launch_speed), ship
	)
	_manager.deploy_flares(ship, _flares(1.0, 0.3))
	assert_object(missile.decoy).is_not_null()
	await SimHelper.step_physics(get_tree(), 30)
	assert_array(_manager.active_flares()).is_empty()
	assert_bool(missile.guided).is_false()
	# Burned out for good: it does not go back to the ship either.
	assert_array(_manager.incoming_for(ship)).is_empty()


func test_the_flare_pool_never_grows() -> void:
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	await SimHelper.step_physics(get_tree(), 2)
	for index: int in 40:
		_manager.deploy_flares(ship, FLARES)
	assert_int(_manager.active_flares().size()).is_equal(_manager.flare_capacity)
