extends GdUnitTestSuite
## Projectiles in a real physics world: when they arrive, what they hit, what they ignore, and
## that the pool is reused instead of grown.


func _weapon(id: StringName = &"pulse_laser") -> WeaponDef:
	return Content.weapon(id)


func test_a_shot_hits_a_still_dummy_when_it_arrives() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -300))
	)
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	var weapon: WeaponDef = _weapon()
	manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -1))
	var ticks: int = await CombatSim.run_until_hits(get_tree(), log, 1, 120)
	# The shot's centre has to travel to the dummy's surface, less its own radius.
	var distance: float = 300.0 - dummy.def.radius - weapon.projectile_radius
	var expected: int = ceili(distance / weapon.projectile_speed * 60.0)
	assert_int(ticks).is_between(expected - 1, expected + 1)
	assert_object(log.hits[0]["collider"]).is_same(dummy)
	assert_float(dummy.durability().shield).is_less(dummy.def.shield_capacity)
	assert_int(manager.active_count()).is_equal(0)


func test_a_shot_hits_a_moving_dummy_at_the_computed_time() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var origin: Vector3 = Vector3(200, 0, -300)
	var rail: Vector3 = Vector3(-400, 0, 0)
	var dummy: TargetDummy = auto_free(CombatSim.spawn_dummy(self, &"standard", origin, rail))
	await CombatSim.settle(get_tree())
	var weapon: WeaponDef = _weapon()
	var speed: float = dummy.def.rail_speed
	# The dummy has already run for the two ticks `settle` waited.
	var start_time: float = 2.0 * SimHelper.TICK
	var aim: Vector3 = _lead_point(origin, rail, speed, start_time, weapon.projectile_speed)
	var direction: Vector3 = aim.normalized()
	# Independent expectation: walk both along their paths and find the first tick in contact.
	var contact: float = dummy.def.radius + weapon.projectile_radius
	var expected: int = 0
	for tick: int in range(1, 600):
		var t: float = start_time + tick * SimHelper.TICK
		var target: Vector3 = TargetDummy.rail_position(origin, rail, speed, t)
		var shot: Vector3 = direction * weapon.projectile_speed * tick * SimHelper.TICK
		if shot.distance_to(target) <= contact:
			expected = tick
			break
	assert_int(expected).is_greater(0)
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	manager.spawn(weapon, null, Vector3.ZERO, direction)
	var ticks: int = await CombatSim.run_until_hits(get_tree(), log, 1, 300)
	assert_int(ticks).is_between(expected - 2, expected + 2)
	assert_object(log.hits[0]["collider"]).is_same(dummy)


## Where to aim from the origin to meet a dummy on a rail, by solving the intercept.
func _lead_point(
	origin: Vector3, rail: Vector3, speed: float, start_time: float, shot_speed: float
) -> Vector3:
	var velocity: Vector3 = rail.normalized() * speed
	var position: Vector3 = TargetDummy.rail_position(origin, rail, speed, start_time)
	# |position + velocity * t| = shot_speed * t
	var a: float = velocity.dot(velocity) - shot_speed * shot_speed
	var b: float = 2.0 * position.dot(velocity)
	var c: float = position.dot(position)
	var t: float = (-b - sqrt(b * b - 4.0 * a * c)) / (2.0 * a)
	return position + velocity * t


func test_a_shot_that_misses_flies_on_and_expires_at_its_range() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var weapon: WeaponDef = _weapon(&"autocannon")
	var shot: Projectile = manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -1))
	await SimHelper.step_physics(get_tree(), int(weapon.lifetime() * 60.0) - 3)
	assert_int(manager.active_count()).is_equal(1)
	assert_float(shot.travelled).is_less(weapon.range_m)
	await SimHelper.step_physics(get_tree(), 8)
	assert_int(manager.active_count()).is_equal(0)


func test_a_shot_stops_at_a_wall_and_hurts_nothing() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -100), Vector3(200, 200, 2)))
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	manager.spawn(_weapon(), null, Vector3.ZERO, Vector3(0, 0, -1))
	await CombatSim.run_until_hits(get_tree(), log, 1, 100)
	assert_int(log.hits.size()).is_equal(1)
	assert_object(log.hits[0]["info"]).is_null()
	assert_int(manager.active_count()).is_equal(0)


func test_a_fast_shot_does_not_tunnel_through_a_thin_wall() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	# 0.1 m thick; the shot moves 8.7 m per tick.
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -150), Vector3(100, 100, 0.1)))
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	manager.spawn(_weapon(), null, Vector3.ZERO, Vector3(0, 0, -1))
	await CombatSim.run_until_hits(get_tree(), log, 1, 100)
	assert_int(log.hits.size()).is_equal(1)


func test_a_shot_does_not_hit_the_ship_that_fired_it() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	# Starts inside the ship's own hull, flying out.
	manager.spawn(_weapon(), ship, ship.global_position, Vector3(0, 0, -1))
	await SimHelper.step_physics(get_tree(), 30)
	assert_int(log.hits.size()).is_equal(0)
	assert_float(ship.durability().shield).is_equal(ship.def.shield_capacity)


func test_a_shot_hits_another_ship_and_names_the_shooter() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var shooter: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var victim: Ship = auto_free(FlightSim.spawn(self, &"bulwark"))
	victim.global_position = Vector3(0, 0, -200)
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	manager.spawn(_weapon(), shooter, Vector3(0, 0, -5), Vector3(0, 0, -1))
	await CombatSim.run_until_hits(get_tree(), log, 1, 100)
	assert_int(log.hits.size()).is_equal(1)
	assert_object(log.hits[0]["collider"]).is_same(victim)
	assert_object((log.hits[0]["info"] as DamageInfo).source).is_same(shooter)
	assert_float(victim.durability().shield).is_less(victim.def.shield_capacity)


func test_a_destroyed_shooter_does_not_break_a_shot_in_flight() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var shooter: Ship = FlightSim.spawn(self, &"kestrel")
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -300))
	)
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	manager.spawn(_weapon(), shooter, Vector3(0, 0, -5), Vector3(0, 0, -1))
	remove_child(shooter)
	shooter.free()
	await CombatSim.run_until_hits(get_tree(), log, 1, 100)
	assert_int(log.hits.size()).is_equal(1)
	assert_object((log.hits[0]["info"] as DamageInfo).source).is_null()
	assert_object(log.hits[0]["collider"]).is_same(dummy)


func test_the_pool_is_reused_and_nothing_leaks_after_10000_shots() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var weapon: WeaponDef = _weapon(&"autocannon")
	var nodes_before: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	var size: int = manager.pool_size()
	var fired: int = 0
	var max_active: int = 0
	while fired < 10000:
		# 25 shots a tick, fanned out so they spread over the pool's lifetime.
		for burst: int in 25:
			var angle: float = float(fired % 360) * 0.0174
			manager.spawn(weapon, null, Vector3.ZERO, Vector3(sin(angle), 0.1, -cos(angle)))
			fired += 1
		max_active = maxi(max_active, manager.active_count())
		await get_tree().physics_frame
	await SimHelper.step_physics(get_tree(), 200)
	assert_int(manager.spawned_total).is_equal(10000)
	assert_int(manager.pool_size()).is_equal(size)
	assert_int(max_active).is_less_equal(size)
	assert_int(manager.active_count()).is_equal(0)
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_less_equal(nodes_before)
	# Objects: allow a little slack for the engine's own bookkeeping, but nothing near 10000.
	assert_float(Performance.get_monitor(Performance.OBJECT_COUNT)).is_less(objects_before + 50.0)


func test_a_full_pool_gives_up_its_oldest_shot() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var weapon: WeaponDef = _weapon()
	var size: int = manager.pool_size()
	var first: Projectile = manager.spawn(weapon, null, Vector3.ZERO, Vector3.FORWARD)
	for index: int in size - 1:
		manager.spawn(weapon, null, Vector3.ZERO, Vector3.FORWARD)
	assert_int(manager.active_count()).is_equal(size)
	var extra: Projectile = manager.spawn(weapon, null, Vector3(5, 0, 0), Vector3.FORWARD)
	assert_int(manager.active_count()).is_equal(size)
	# The oldest slot was reused: same object, fresh state.
	assert_object(extra).is_same(first)
	assert_vector(extra.position).is_equal(Vector3(5, 0, 0))
