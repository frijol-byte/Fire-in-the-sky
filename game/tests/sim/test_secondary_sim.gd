extends GdUnitTestSuite
## A ship's secondary weapon in the physics world: the lock-on rules of the Homing Missile (hold to
## lock, release to launch, nothing happens without a lock), ammo and cooldown, the Rocket Pod's
## salvo, and what an ion hit or a wreck can do.

const TICK: float = SimHelper.TICK
## Lock time of the Homing Missile plus a margin, in ticks.
const LOCKED_TICKS: int = 85

var _manager: MissileManager = null


func before_test() -> void:
	_manager = auto_free(CombatSim.spawn_missile_manager(self))
	auto_free(CombatSim.spawn_manager(self))


## A Kestrel at the origin facing -Z with a hostile Bulwark `distance` metres ahead and `off_axis`
## metres to the right, selected as its target.
func _duel(distance: float = 600.0, off_axis: float = 0.0) -> Array[Ship]:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var target: Ship = auto_free(
		CombatSim.spawn_ship(self, &"bulwark", Vector3(off_axis, 0.0, -distance))
	)
	return [shooter, target]


func _select(shooter: Ship, target: Ship) -> void:
	await SimHelper.step_physics(get_tree(), 3)
	shooter.targeting().select(target)
	await SimHelper.step_physics(get_tree(), 2)


func _hold_secondary(ship: Ship, held: bool = true) -> void:
	var controls: ShipControls = ShipControls.new()
	controls.fire_secondary = held
	ship.controls = controls


func test_holding_on_a_target_for_the_lock_time_then_releasing_launches_a_missile() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	var ammo: int = secondaries.ammo
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	assert_bool(secondaries.lock.is_locked()).is_true()
	assert_int(_manager.launched_total).is_equal(0)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.launched_total).is_equal(1)
	assert_int(secondaries.ammo).is_equal(ammo - 1)
	var missile: Missile = _manager.active_missiles()[0]
	assert_object(missile.target).is_same(ships[1])
	assert_bool(missile.guided).is_true()
	assert_object(missile.shooter).is_same(ships[0])
	assert_bool(secondaries.lock.is_locked()).is_false()


func test_releasing_before_the_lock_completes_launches_nothing() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), 40)
	assert_float(secondaries.lock.progress).is_between(0.4, 0.7)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 5)
	assert_int(_manager.launched_total).is_equal(0)
	assert_int(secondaries.ammo).is_equal(secondaries.def.ammo)
	assert_float(secondaries.lock.progress).is_equal(0.0)


func test_there_is_no_lock_without_a_selected_target() -> void:
	var ships: Array[Ship] = _duel()
	await SimHelper.step_physics(get_tree(), 5)
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS + 10)
	assert_float(ships[0].secondaries().lock.progress).is_equal(0.0)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.launched_total).is_equal(0)


func test_a_target_outside_the_cone_cannot_be_locked() -> void:
	# 600 m ahead and 600 m to the right: 45 degrees off the nose, the cone is 20.
	var ships: Array[Ship] = _duel(600.0, 600.0)
	await _select(ships[0], ships[1])
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS + 10)
	assert_float(ships[0].secondaries().lock.progress).is_equal(0.0)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.launched_total).is_equal(0)


func test_a_target_beyond_the_missiles_range_cannot_be_locked() -> void:
	var ships: Array[Ship] = _duel(1400.0)
	await _select(ships[0], ships[1])
	# The ship's targeting still has it locked (range 1500 m), the missile's seeker does not (1200 m).
	assert_bool(ships[0].targeting().has_lock()).is_true()
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS + 10)
	assert_float(ships[0].secondaries().lock.progress).is_equal(0.0)


func test_the_lock_drains_when_the_target_leaves_the_cone() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	assert_bool(ships[0].secondaries().lock.is_locked()).is_true()
	# Turn the nose away (the target is 600 m ahead; 90 degrees of yaw takes about a second).
	var controls: ShipControls = ShipControls.new()
	controls.fire_secondary = true
	controls.rotate = Vector3(0.0, 1.0, 0.0)
	ships[0].controls = controls
	await SimHelper.step_physics(get_tree(), 90)
	assert_bool(ships[0].secondaries().lock.is_locked()).is_false()
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 3)
	assert_int(_manager.launched_total).is_equal(0)


func test_the_missile_cools_down_before_the_next_lock_can_start() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 2)
	assert_float(secondaries.cooldown_left()).is_greater(1.0)
	# Holding again: no lock until the cooldown is over.
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), 30)
	assert_float(secondaries.lock.progress).is_equal(0.0)
	await SimHelper.step_physics(get_tree(), 60)
	assert_float(secondaries.lock.progress).is_greater(0.0)


func test_an_empty_magazine_cannot_lock_or_launch() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	secondaries.ammo = 0
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS + 10)
	assert_float(secondaries.lock.progress).is_equal(0.0)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.launched_total).is_equal(0)
	assert_int(secondaries.add_ammo(100)).is_equal(secondaries.def.ammo)
	assert_int(secondaries.ammo).is_equal(secondaries.def.ammo)


func test_every_missile_costs_one_round() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	secondaries.ammo = 2
	for shot: int in 2:
		_hold_secondary(ships[0])
		await SimHelper.step_physics(get_tree(), LOCKED_TICKS + 90)
		_hold_secondary(ships[0], false)
		await SimHelper.step_physics(get_tree(), 2)
	assert_int(_manager.launched_total).is_equal(2)
	assert_int(secondaries.ammo).is_equal(0)


func test_an_ion_hit_blocks_the_lock_and_the_launch() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	var secondaries: SecondarySystem = ships[0].secondaries()
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	assert_bool(secondaries.lock.is_locked()).is_true()
	ships[0].durability().apply(DamageInfo.make(5.0, DamageInfo.Type.ION))
	assert_bool(ships[0].durability().devices_disabled()).is_true()
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 3)
	assert_int(_manager.launched_total).is_equal(0)
	# Holding while disabled builds nothing.
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), 30)
	assert_float(secondaries.lock.progress).is_equal(0.0)


func test_a_wreck_cannot_launch() -> void:
	var ships: Array[Ship] = _duel()
	await _select(ships[0], ships[1])
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	ships[0].durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 3)
	assert_int(_manager.launched_total).is_equal(0)


func test_a_missile_leaves_the_launcher_with_the_ships_own_velocity() -> void:
	var ships: Array[Ship] = _duel()
	ships[0].linear_velocity = Vector3(30.0, 0.0, -100.0)
	await _select(ships[0], ships[1])
	_hold_secondary(ships[0])
	await SimHelper.step_physics(get_tree(), LOCKED_TICKS)
	_hold_secondary(ships[0], false)
	await SimHelper.step_physics(get_tree(), 1)
	var missile: Missile = _manager.active_missiles()[0]
	# The ship's velocity (it keeps ~100 m/s of it under flight assist for a while) plus the launch
	# speed along the nose: clearly faster than the launch speed alone, and drifting right.
	assert_float(missile.velocity.length()).is_greater(missile.def.launch_speed + 40.0)
	assert_float(missile.velocity.x).is_greater(0.0)


func test_the_rocket_pod_fires_a_salvo_one_after_another() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	var secondaries: SecondarySystem = shooter.secondaries()
	assert_bool(secondaries.def.is_homing()).is_false()
	secondaries.seed_spread(5)
	var def: SecondaryDef = secondaries.def
	await SimHelper.step_physics(get_tree(), 3)
	var launched_at: Array[int] = []
	# A lambda copies plain variables, so the tick counter lives in an array.
	var clock: Array[int] = [0]
	secondaries.launched.connect(func(_round: Missile) -> void: launched_at.append(clock[0]))
	_hold_secondary(shooter)
	for step: int in 60:
		await get_tree().physics_frame
		clock[0] += 1
	assert_int(launched_at.size()).is_equal(def.salvo_count)
	assert_int(secondaries.ammo).is_equal(def.ammo - def.salvo_count)
	var span: float = float(launched_at[launched_at.size() - 1] - launched_at[0]) * TICK
	assert_float(span).is_equal_approx(def.salvo_interval * float(def.salvo_count - 1), 0.04)
	# Rockets are unguided.
	for missile: Missile in _manager.active_missiles():
		assert_bool(missile.guided).is_false()
		assert_object(missile.target).is_null()


func test_the_rocket_pod_waits_for_its_cooldown_between_salvos() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	var def: SecondaryDef = shooter.secondaries().def
	await SimHelper.step_physics(get_tree(), 3)
	_hold_secondary(shooter)
	# Holding the button: the second salvo starts only once the cooldown has passed.
	await SimHelper.step_physics(get_tree(), 60)
	assert_int(_manager.launched_total).is_equal(def.salvo_count)
	await SimHelper.step_physics(get_tree(), int(def.cooldown / TICK))
	assert_int(_manager.launched_total).is_equal(def.salvo_count * 2)


func test_the_rocket_pod_stops_when_the_magazine_runs_out_mid_salvo() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	shooter.secondaries().ammo = 4
	await SimHelper.step_physics(get_tree(), 3)
	_hold_secondary(shooter)
	await SimHelper.step_physics(get_tree(), 300)
	assert_int(_manager.launched_total).is_equal(4)
	assert_int(shooter.secondaries().ammo).is_equal(0)
	assert_bool(shooter.secondaries().is_firing_salvo()).is_false()


func test_the_pool_reuses_the_oldest_round_when_full() -> void:
	var small: MissileManager = auto_free(CombatSim.spawn_missile_manager(self, 4))
	var def: SecondaryDef = Content.secondary(&"rocket_pod")
	await SimHelper.step_physics(get_tree(), 2)
	for index: int in 10:
		small.launch(def, null, Vector3(0, 0, -1000.0 * index), Vector3.ZERO)
	assert_int(small.launched_total).is_equal(10)
	assert_int(small.active_count()).is_equal(4)
	assert_int(small.pool_size()).is_equal(4)
	# The survivors are the four newest.
	var serials: Array[int] = []
	for missile: Missile in small.active_missiles():
		serials.append(missile.serial)
	assert_array(serials).is_equal([7, 8, 9, 10])
