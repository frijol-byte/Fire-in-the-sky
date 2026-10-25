extends GdUnitTestSuite
## Missiles and rockets in flight, through the real flight, physics and damage code: a homing
## missile hits a target that does not evade, cannot catch one that boosts away, and misses one that
## boost-drifts across its path at the right moment; the blast hurts through `Durability` with a
## falloff and never hurts the ship that fired it.

const TICK: float = SimHelper.TICK
const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
const ROCKET: SecondaryDef = preload("res://data/secondaries/rocket_pod.tres")
## How far ahead of the shooter the chase target starts.
const CHASE_DISTANCE: float = 700.0

var _manager: MissileManager = null
var _blasts: CombatSim.BlastLog = null


func before_test() -> void:
	_manager = auto_free(CombatSim.spawn_missile_manager(self))
	auto_free(CombatSim.spawn_manager(self))
	_blasts = CombatSim.BlastLog.new()
	_blasts.attach(_manager)


## Launches one homing missile from a shooter at the origin at a Kestrel `CHASE_DISTANCE` metres ahead
## that flies away at `target_speed` (straight ahead, boosting if `boost`). When the missile is within
## `dodge_at` metres the target boost-drifts: it yaws round with flight assist off and boosts across the
## missile's path (a negative `dodge_at` never dodges). Runs until the missile is gone or `seconds`
## pass. Returns {shooter, target, min_gap, ticks, missile}.
func _chase(
	target_speed: float, boost: bool, dodge_at: float = -1.0, seconds: float = 10.0
) -> Dictionary:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var target: Ship = auto_free(
		CombatSim.spawn_ship(self, &"kestrel", Vector3(0.0, 0.0, -CHASE_DISTANCE))
	)
	target.linear_velocity = Vector3(0.0, 0.0, -target_speed)
	await SimHelper.step_physics(get_tree(), 3)
	var cruise: ShipControls = ShipControls.new()
	cruise.thrust = Vector3(0.0, 0.0, 1.0)
	cruise.boost = boost
	target.controls = cruise
	var missile: Missile = _manager.launch(
		MISSILE,
		shooter,
		shooter.global_position + Vector3(0.0, -1.0, -5.0),
		Vector3(0.0, 0.0, -MISSILE.launch_speed),
		target
	)
	var min_gap: float = INF
	var dodging: bool = false
	var ticks: int = 0
	while ticks < int(seconds / TICK) and _manager.active_count() > 0:
		await get_tree().physics_frame
		ticks += 1
		_blasts.ticks = ticks
		if not missile.active:
			break
		min_gap = minf(min_gap, missile.position.distance_to(target.global_position))
		if not dodging and min_gap < dodge_at:
			dodging = true
			var evade: ShipControls = ShipControls.new()
			evade.fa_off = true
			evade.boost = true
			evade.rotate = Vector3(0.0, 1.0, 0.0)
			evade.thrust = Vector3(0.0, 0.0, 1.0)
			target.controls = evade
	return {
		"shooter": shooter,
		"target": target,
		"min_gap": min_gap,
		"ticks": ticks,
		"missile": missile,
	}


func _shield_lost(ship: Ship) -> float:
	return ship.durability().shield_capacity - ship.durability().shield


func test_a_missile_hits_a_target_that_does_not_evade() -> void:
	var run: Dictionary = await _chase(0.0, false)
	var target: Ship = run["target"] as Ship
	assert_int(_blasts.damaging().size()).is_equal(1)
	# Explosive damage is x1.0 against a shield: the full 55 from the middle of the blast.
	assert_float(_shield_lost(target)).is_between(MISSILE.damage * 0.9, MISSILE.damage)
	assert_float(float(run["ticks"]) * TICK).is_less(MISSILE.lifetime - 1.0)
	# The proximity fuse went off close to the target.
	assert_float(run["min_gap"] as float).is_less(MISSILE.fuse_radius_m + 1.0)


func test_a_missile_hits_a_target_flying_straight_away_at_cruising_speed() -> void:
	var run: Dictionary = await _chase(180.0, false)
	assert_int(_blasts.damaging().size()).is_equal(1)
	assert_float(_shield_lost(run["target"] as Ship)).is_greater(MISSILE.damage * 0.5)


func test_a_missile_cannot_catch_a_ship_that_boosts_away() -> void:
	var run: Dictionary = await _chase(320.0, true)
	var target: Ship = run["target"] as Ship
	assert_int(_blasts.damaging().size()).is_equal(0)
	assert_float(_shield_lost(target)).is_equal(0.0)
	# It burned out after its lifetime, harmlessly, still hundreds of metres behind.
	assert_int(_blasts.blasts.size()).is_equal(1)
	assert_bool(_blasts.blasts[0]["harmless"] as bool).is_true()
	assert_float(run["min_gap"] as float).is_greater(200.0)


func test_a_missile_misses_a_target_that_boost_drifts_across_its_path() -> void:
	var run: Dictionary = await _chase(180.0, false, 200.0)
	var target: Ship = run["target"] as Ship
	assert_int(_blasts.damaging().size()).is_equal(0)
	assert_float(_shield_lost(target)).is_equal(0.0)
	assert_float(run["min_gap"] as float).is_greater(MISSILE.fuse_radius_m * 3.0)
	# The seeker lost it for good once it was behind the missile: nothing circles back.
	assert_bool((run["missile"] as Missile).guided).is_false()


func test_the_same_chase_without_the_dodge_is_a_hit() -> void:
	# Control for the test above: the dodge is what makes the difference.
	await _chase(180.0, false)
	assert_int(_blasts.damaging().size()).is_equal(1)


func test_a_dodge_that_comes_too_late_does_not_help() -> void:
	var run: Dictionary = await _chase(180.0, false, 30.0)
	assert_int(_blasts.damaging().size()).is_equal(1)
	assert_float(_shield_lost(run["target"] as Ship)).is_greater(0.0)


func test_a_chase_is_repeatable() -> void:
	var first: Dictionary = await _chase(180.0, false, 200.0)
	var first_gap: float = first["min_gap"] as float
	var first_ticks: int = first["ticks"] as int
	# Clear the stage, then run the same chase again.
	for ship: Ship in [first["target"], first["shooter"]]:
		remove_child(ship)
		ship.free()
	await SimHelper.step_physics(get_tree(), 2)
	_blasts.blasts.clear()
	var second: Dictionary = await _chase(180.0, false, 200.0)
	assert_float(second["min_gap"] as float).is_equal(first_gap)
	assert_int(second["ticks"] as int).is_equal(first_ticks)


func test_a_missile_whose_target_dies_flies_on_and_burns_out() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var target: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -900)))
	await SimHelper.step_physics(get_tree(), 3)
	var damaged: Array[Object] = []
	_manager.damaged.connect(
		func(_round: Missile, collider: Object, _info: DamageInfo, _result: DamageResult) -> void:
			damaged.append(collider)
	)
	var missile: Missile = _manager.launch(
		MISSILE, shooter, Vector3(0, -1, -5), Vector3(0, 0, -MISSILE.launch_speed), target
	)
	await SimHelper.step_physics(get_tree(), 60)
	assert_bool(missile.guided).is_true()
	target.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	await SimHelper.step_physics(get_tree(), 5)
	assert_bool(missile.guided).is_false()
	await SimHelper.step_physics(get_tree(), int(MISSILE.lifetime / TICK))
	assert_int(_manager.active_count()).is_equal(0)
	# It may well have gone off against the wreck, but there was nothing left to hurt.
	assert_array(damaged).is_empty()


func test_incoming_missiles_are_reported_for_the_ship_they_hunt() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var target: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -900)))
	await SimHelper.step_physics(get_tree(), 3)
	var missile: Missile = _manager.launch(
		MISSILE, shooter, Vector3(0, -1, -5), Vector3(0, 0, -MISSILE.launch_speed), target
	)
	assert_array(_manager.incoming_for(target)).contains_exactly([missile])
	assert_array(_manager.incoming_for(shooter)).is_empty()
	# A rocket is never "incoming": nobody steers it at anyone.
	_manager.launch(ROCKET, shooter, Vector3(0, -1, -5), Vector3(0, 0, -200), target)
	assert_array(_manager.incoming_for(target)).has_size(1)


func test_a_rocket_explodes_on_contact_and_hurts_what_it_hits() -> void:
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -300))
	)
	await CombatSim.settle(get_tree())
	var shield: float = dummy.durability().shield
	_manager.launch(ROCKET, shooter, Vector3(0, -1, -5), Vector3(0, 0, -ROCKET.launch_speed))
	await SimHelper.step_physics(get_tree(), 120)
	assert_int(_blasts.damaging().size()).is_equal(1)
	assert_float(dummy.durability().shield).is_less(shield)
	# A rocket hit is a light one.
	assert_float(shield - dummy.durability().shield).is_less_equal(ROCKET.damage)


func test_a_blast_weakens_with_distance_and_stops_at_its_radius() -> void:
	# A rocket hits a wall; three stationary dummies stand at different distances from the impact.
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -200), Vector3(60, 60, 4)))
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	var near: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(10, 0, -190))
	)
	var far: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(-17, 0, -190))
	)
	var outside: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 40, -190))
	)
	await CombatSim.settle(get_tree())
	_manager.launch(ROCKET, shooter, Vector3(0, 0, -5), Vector3(0, 0, -ROCKET.launch_speed))
	await SimHelper.step_physics(get_tree(), 120)
	assert_int(_blasts.damaging().size()).is_equal(1)
	var point: Vector3 = _blasts.damaging()[0]["point"] as Vector3
	for dummy: TargetDummy in [near, far, outside]:
		var surface: float = maxf(point.distance_to(dummy.global_position) - dummy.def.radius, 0.0)
		var expected: float = MissileGuidance.splash_amount(
			ROCKET.damage, ROCKET.splash_radius_m, ROCKET.splash_edge_fraction, surface
		)
		# Explosive damage is x1.0 against a shield, so what the shield lost is the blast's amount.
		var lost: float = dummy.durability().shield_capacity - dummy.durability().shield
		(
			assert_float(lost)
			. override_failure_message(
				"%s: expected %.2f, lost %.2f" % [dummy.name, expected, lost]
			)
			. is_equal_approx(expected, 0.01)
		)
	assert_float(near.durability().shield).is_less(far.durability().shield)
	assert_float(outside.durability().shield).is_equal(outside.durability().shield_capacity)


func test_a_ship_is_never_hurt_by_its_own_blast() -> void:
	# A wall 6 m ahead of the nose: the rocket goes off right beside the ship that fired it.
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -12), Vector3(60, 60, 4)))
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3.ZERO))
	var wingman: Ship = auto_free(CombatSim.spawn_ship(self, &"bulwark", Vector3(0, 0, -6)))
	wingman.global_position = Vector3(12, 0, -2)
	await CombatSim.settle(get_tree())
	_manager.launch(ROCKET, shooter, Vector3(0, 0, -3), Vector3(0, 0, -ROCKET.launch_speed))
	await SimHelper.step_physics(get_tree(), 30)
	assert_int(_blasts.damaging().size()).is_equal(1)
	assert_float(shooter.durability().shield).is_equal(shooter.durability().shield_capacity)
	# ... while a ship that is not the shooter, in the same blast, is hurt.
	assert_float(wingman.durability().shield).is_less(wingman.durability().shield_capacity)


func test_a_missile_blows_up_on_a_rock_without_hurting_anyone() -> void:
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -400), Vector3(80, 80, 4)))
	var shooter: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	var target: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0, 0, -900)))
	await CombatSim.settle(get_tree())
	_manager.launch(
		MISSILE, shooter, Vector3(0, -1, -5), Vector3(0, 0, -MISSILE.launch_speed), target
	)
	await SimHelper.step_physics(get_tree(), 240)
	assert_int(_blasts.blasts.size()).is_equal(1)
	var point: Vector3 = _blasts.blasts[0]["point"] as Vector3
	assert_float(point.z).is_between(-404.0, -396.0)
	assert_float(target.durability().shield).is_equal(target.durability().shield_capacity)
