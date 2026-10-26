extends GdUnitTestSuite
## `AIPilot` flying real `Ship`s: it kills a stationary dummy, picks its own enemies, keeps clear of
## rocks, reacts to missiles and locks after its reaction time, and writes `ShipControls` only.

const TICK: float = SimHelper.TICK
const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")
const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
## Seconds the AI has to kill a stationary dummy.
const DUMMY_KILL_LIMIT: float = 60.0
## Most rock collisions an AI may have in a minute of flying through the arena's asteroid belt.
const MAX_ROCK_BUMPS_PER_MINUTE: int = 3

var _kill_tick: int = -1
var _ticks: int = 0


func ship_params() -> Array[Array]:
	return FlightSim.ship_params()


func after_test() -> void:
	Settings.values.clear()


func _noted_kill(_node: Node, _info: DamageInfo) -> void:
	if _kill_tick < 0:
		_kill_tick = _ticks


## Steps `ticks` physics ticks, counting them in `_ticks`.
func _run(ticks: int) -> void:
	for _tick: int in ticks:
		await get_tree().physics_frame
		_ticks += 1


func test_the_ai_kills_a_stationary_dummy_in_under_a_minute(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0.0, 0.0, -900.0))
	)
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			ship_id,
			Vector3.ZERO,
			dummy.position,
			Targeting.Stance.HOSTILE,
			&"standard",
			1,
			dummy
		)
	)
	Events.ship_destroyed.connect(_noted_kill)
	_kill_tick = -1
	_ticks = 0
	var closest: float = INF
	for _tick: int in roundi(DUMMY_KILL_LIMIT / TICK):
		await get_tree().physics_frame
		_ticks += 1
		closest = minf(closest, ship.global_position.distance_to(dummy.global_position))
		if _kill_tick >= 0:
			break
	Events.ship_destroyed.disconnect(_noted_kill)
	assert_int(_kill_tick).override_failure_message("the dummy was never killed").is_greater(0)
	assert_float(_kill_tick * TICK).is_less(DUMMY_KILL_LIMIT)
	# It never rammed the dummy: the dummy is 6 m across and the ship a few metres.
	assert_float(closest).is_greater(9.0)


func test_the_attack_run_cycles_through_pursue_attack_and_break_off() -> void:
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"sturdy", Vector3(0.0, 0.0, -900.0))
	)
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			&"kestrel",
			Vector3.ZERO,
			dummy.position,
			Targeting.Stance.HOSTILE,
			&"standard",
			1,
			dummy
		)
	)
	var pilot: AIPilot = CombatSim.pilot_of(ship)
	var seen: Array[int] = []
	pilot.behavior_changed.connect(func(entered: int) -> void: seen.append(entered))
	var fired: bool = false
	for _tick: int in roundi(40.0 / TICK):
		await get_tree().physics_frame
		fired = fired or ship.controls.fire_primary
	assert_array(seen).contains([AIUtility.Behavior.ATTACK_RUN, AIUtility.Behavior.BREAK_OFF])
	assert_bool(fired).is_true()
	# After a break-off it comes back for another run: attack runs happen more than once.
	assert_int(seen.count(AIUtility.Behavior.ATTACK_RUN)).is_greater(1)
	assert_int(seen.count(AIUtility.Behavior.BREAK_OFF)).is_greater(0)


func test_without_an_enemy_the_pilot_idles_and_does_not_fire() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(self, &"kestrel", Vector3.ZERO, Vector3(0.0, 0.0, -500.0))
	)
	var pilot: AIPilot = CombatSim.pilot_of(ship)
	await SimHelper.step_physics(get_tree(), 120)
	assert_object(pilot.target).is_null()
	assert_int(pilot.behavior).is_equal(AIUtility.Behavior.PURSUE)
	assert_bool(ship.controls.fire_primary).is_false()
	assert_float(ship.controls.thrust.z).is_equal(0.0)
	assert_float(ship.linear_velocity.length()).is_less(1.0)


func test_the_pilot_picks_the_nearest_enemy_and_ignores_friends_and_neutrals() -> void:
	auto_free(CombatSim.spawn_manager(self))
	# Same side (hostile) and neutral dummies are closer than the friendly one: only that is an enemy.
	auto_free(CombatSim.spawn_dummy(self, &"standard", Vector3(100.0, 0.0, -200.0)))
	auto_free(CombatSim.spawn_dummy(self, &"neutral", Vector3(-100.0, 0.0, -250.0)))
	var enemy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"ally", Vector3(0.0, 0.0, -900.0))
	)
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(self, &"kestrel", Vector3.ZERO, Vector3(0.0, 0.0, -900.0))
	)
	var pilot: AIPilot = CombatSim.pilot_of(ship)
	await SimHelper.step_physics(get_tree(), 5)
	assert_object(pilot.target).is_same(enemy)
	# The ship's own targeting follows, so a missile lock can be built on it.
	assert_object(ship.targeting().target).is_same(enemy)


func test_a_friendly_ai_fights_hostile_ships_and_the_players_side_is_friendly() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var player: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3(0.0, 0.0, -600.0)))
	var player_pilot: PlayerPilot = PlayerPilot.new()
	player.add_child(player_pilot)
	assert_int(player.stance).is_equal(Targeting.Stance.FRIENDLY)
	var hostile: Ship = auto_free(
		CombatSim.spawn_ai(self, &"kestrel", Vector3.ZERO, Vector3(0.0, 0.0, -600.0))
	)
	await SimHelper.step_physics(get_tree(), 5)
	assert_object(CombatSim.pilot_of(hostile).target).is_same(player)
	player.remove_child(player_pilot)
	player_pilot.free()


func test_a_pilot_writes_controls_and_never_sets_velocities() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(300.0, 0.0, -600.0))
	)
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			&"kestrel",
			Vector3.ZERO,
			dummy.position,
			Targeting.Stance.HOSTILE,
			&"standard",
			1,
			dummy
		)
	)
	var pilot: AIPilot = CombatSim.pilot_of(ship)
	await SimHelper.step_physics(get_tree(), 10)
	var velocity: Vector3 = ship.linear_velocity
	var angular: Vector3 = ship.angular_velocity
	pilot.tick(TICK)
	assert_vector(ship.linear_velocity).is_equal(velocity)
	assert_vector(ship.angular_velocity).is_equal(angular)
	# What it did do is fill in the controls the flight code reads.
	assert_float(ship.controls.thrust.z).is_greater(0.0)
	assert_float(ship.controls.rotate.y).is_not_equal(0.0)


func test_the_pilot_uses_the_ships_own_numbers() -> void:
	# A freighter turns slower than a fighter, so the same target direction asks for the same
	# fraction of the (lower) top rate: the command is a fraction of the ship's own limits.
	auto_free(CombatSim.spawn_manager(self))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(500.0, 0.0, -500.0))
	)
	var commands: Dictionary[StringName, float] = {}
	for ship_id: StringName in [&"kestrel", &"drayman"]:
		var ship: Ship = auto_free(
			CombatSim.spawn_ai(
				self,
				ship_id,
				Vector3.ZERO,
				Vector3(0.0, 0.0, -500.0),
				Targeting.Stance.HOSTILE,
				&"standard",
				1,
				dummy
			)
		)
		await SimHelper.step_physics(get_tree(), 2)
		commands[ship_id] = absf(ship.controls.rotate.y)
		ship.get_parent().remove_child(ship)
		ship.free()
	# 45 degrees off the nose is far outside the proportional zone: both ask for full turn rate.
	assert_float(commands[&"kestrel"]).is_equal(1.0)
	assert_float(commands[&"drayman"]).is_equal(1.0)


func test_same_seed_same_fight() -> void:
	# The first physics frame of a suite is not a full tick for a freshly added body.
	await get_tree().physics_frame
	var results: Array[Vector3] = []
	for _run_index: int in 2:
		var world: Node3D = Node3D.new()
		add_child(world)
		CombatSim.spawn_manager(world)
		var dummy: TargetDummy = CombatSim.spawn_dummy(
			world, &"standard", Vector3(0.0, 0.0, -700.0)
		)
		var ship: Ship = CombatSim.spawn_ai(
			world,
			&"kestrel",
			Vector3.ZERO,
			dummy.position,
			Targeting.Stance.HOSTILE,
			&"standard",
			5,
			dummy
		)
		await SimHelper.step_physics(get_tree(), 600)
		results.append(ship.global_position)
		remove_child(world)
		world.free()
	assert_vector(results[0]).is_equal_approx(results[1], Vector3.ONE * 0.001)


func test_a_rookie_misses_by_more_than_an_ace() -> void:
	var rookie: AIProfileDef = Content.ai_profile(&"rookie")
	var ace: AIProfileDef = Content.ai_profile(&"ace")
	assert_float(rookie.aim_error_deg).is_greater(ace.aim_error_deg)
	(
		assert_float(
			(
				AIMath
				. aim_point(
					Vector3.ZERO, Vector3(0.0, 0.0, -300.0), Vector3.RIGHT, rookie.aim_error_deg
				)
				. x
			)
		)
		. is_greater(
			(
				AIMath
				. aim_point(
					Vector3.ZERO, Vector3(0.0, 0.0, -300.0), Vector3.RIGHT, ace.aim_error_deg
				)
				. x
			)
		)
	)


# --- Rocks -------------------------------------------------------------------------------------


func test_the_ai_rarely_hits_the_arenas_asteroids(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var colliders: RockColliders = auto_free(CombatSim.spawn_rock_field(self, FLIGHT_TEST))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"sturdy", Vector3(-450.0, 20.0, -450.0))
	)
	var ship: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			ship_id,
			Vector3(450.0, 0.0, 450.0),
			dummy.position,
			Targeting.Stance.HOSTILE,
			&"standard",
			3,
			dummy
		)
	)
	colliders.set_target(ship)
	ship.contact_monitor = true
	ship.max_contacts_reported = 4
	var bumps: Array[int] = [0]
	var last_contact: Array[int] = [-1000]
	var now: Array[int] = [0]
	ship.body_entered.connect(
		func(body: Node) -> void:
			if body.get_parent() != colliders:
				return
			# One scrape can touch several times in a row: count it once.
			if now[0] - last_contact[0] > 60:
				bumps[0] += 1
			last_contact[0] = now[0]
	)
	for _tick: int in 3600:
		await get_tree().physics_frame
		now[0] += 1
	assert_int(colliders.active_count()).is_greater(0)
	assert_int(bumps[0]).is_less_equal(MAX_ROCK_BUMPS_PER_MINUTE)
	# It stayed in the fight (the field did not trap it) and its position is sane.
	assert_bool(ship.global_position.is_finite()).is_true()
	assert_float(ship.global_position.length()).is_less(5000.0)


# --- Missiles, locks and the reaction time ----------------------------------------------------


## A hostile AI kestrel with no enemy to fight, flown by the profile `profile_id`.
func _ai_kestrel(profile_id: StringName) -> Ship:
	return auto_free(
		CombatSim.spawn_ai(
			self,
			&"kestrel",
			Vector3.ZERO,
			Vector3(0.0, 0.0, -500.0),
			Targeting.Stance.HOSTILE,
			profile_id
		)
	)


func _launch_missile_at(manager: MissileManager, ship: Ship, distance: float) -> Missile:
	var origin: Vector3 = ship.global_position + Vector3(-distance, 0.0, 0.0)
	return manager.launch(MISSILE, null, origin, Vector3.ZERO, ship)


## Ticks until the ship's flares go off after `start`, or -1 when they never do within `limit`.
func _ticks_until_flares(ship: Ship, limit: int) -> int:
	var used: Array[int] = [-1]
	var now: Array[int] = [0]
	ship.devices().used.connect(
		func(_slot: int, _def: DeviceDef) -> void:
			if used[0] < 0:
				used[0] = now[0]
	)
	for _tick: int in limit:
		await get_tree().physics_frame
		now[0] += 1
		if used[0] >= 0:
			break
	return used[0]


func test_the_ai_throws_flares_at_an_incoming_missile_after_its_reaction_time() -> void:
	var manager: MissileManager = auto_free(CombatSim.spawn_missile_manager(self))
	var ship: Ship = _ai_kestrel(&"standard")
	await SimHelper.step_physics(get_tree(), 3)
	_launch_missile_at(manager, ship, 1000.0)
	var profile: AIProfileDef = Content.ai_profile(&"standard")
	var tick: int = await _ticks_until_flares(ship, 180)
	assert_int(tick).override_failure_message("the flares were never used").is_greater(0)
	# Not before it could have noticed, and soon after.
	assert_float(tick * TICK).is_greater_equal(profile.reaction_time - 0.05)
	assert_float(tick * TICK).is_less(profile.reaction_time + 0.5)
	assert_int(manager.active_flares().size()).is_greater(0)


func test_a_slower_reaction_time_means_later_flares() -> void:
	var times: Array[float] = []
	for profile_id: StringName in [&"ace", &"rookie"]:
		var world: Node3D = Node3D.new()
		add_child(world)
		var manager: MissileManager = CombatSim.spawn_missile_manager(world)
		var ship: Ship = CombatSim.spawn_ai(
			world,
			&"kestrel",
			Vector3.ZERO,
			Vector3(0.0, 0.0, -500.0),
			Targeting.Stance.HOSTILE,
			profile_id
		)
		await SimHelper.step_physics(get_tree(), 3)
		_launch_missile_at(manager, ship, 1000.0)
		var tick: int = await _ticks_until_flares(ship, 240)
		times.append(tick * TICK)
		remove_child(world)
		world.free()
	assert_float(times[0]).is_greater(0.0)
	assert_float(times[1]).is_greater(times[0] + 0.3)


func test_a_pilot_without_flares_enabled_does_not_throw_them() -> void:
	var manager: MissileManager = auto_free(CombatSim.spawn_missile_manager(self))
	var ship: Ship = _ai_kestrel(&"standard")
	var pilot: AIPilot = CombatSim.pilot_of(ship)
	pilot.profile = pilot.profile.duplicate() as AIProfileDef
	pilot.profile.use_flares = false
	await SimHelper.step_physics(get_tree(), 3)
	_launch_missile_at(manager, ship, 1000.0)
	var tick: int = await _ticks_until_flares(ship, 120)
	assert_int(tick).is_equal(-1)
	# It still reacts: it is evading the missile.
	assert_int(pilot.behavior).is_equal(AIUtility.Behavior.EVADE)


func test_a_pilot_reacts_to_a_missile_lock_by_evading_after_its_reaction_time() -> void:
	auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_missile_manager(self))
	var victim: Ship = auto_free(
		CombatSim.spawn_ai(
			self,
			&"kestrel",
			Vector3.ZERO,
			Vector3(0.0, 0.0, -500.0),
			Targeting.Stance.HOSTILE,
			&"standard"
		)
	)
	# An enemy 700 m away with its nose on the victim holds the secondary trigger: the lock builds.
	var hunter: Ship = auto_free(
		CombatSim.spawn_ship(self, &"kestrel", Vector3(0.0, 0.0, -700.0), Vector3.ZERO)
	)
	hunter.stance = Targeting.Stance.FRIENDLY
	await SimHelper.step_physics(get_tree(), 3)
	hunter.targeting().select(victim)
	var pilot: AIPilot = CombatSim.pilot_of(victim)
	var profile: AIProfileDef = Content.ai_profile(&"standard")
	var evade_tick: int = -1
	var lock_tick: int = -1
	for tick: int in 150:
		var held: ShipControls = ShipControls.new()
		held.fire_secondary = true
		hunter.controls = held
		await get_tree().physics_frame
		if lock_tick < 0 and hunter.secondaries().lock.state != MissileLock.State.IDLE:
			lock_tick = tick
		if evade_tick < 0 and pilot.behavior == AIUtility.Behavior.EVADE:
			evade_tick = tick
	assert_int(lock_tick).override_failure_message("the hunter never built a lock").is_greater(-1)
	assert_int(evade_tick).override_failure_message("the pilot never evaded").is_greater(-1)
	var delay: float = (evade_tick - lock_tick) * TICK
	assert_float(delay).is_greater_equal(profile.reaction_time - 0.05)
	assert_float(delay).is_less(profile.reaction_time + 0.4)
