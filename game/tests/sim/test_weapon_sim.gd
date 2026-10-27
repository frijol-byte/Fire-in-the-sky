extends GdUnitTestSuite
## A ship's guns in the physics world: where shots leave, how fast, what energy and heat they cost,
## and what they do to a target dummy through the real damage code.

const TICK: float = SimHelper.TICK


func ship_params() -> Array[Array]:
	return FlightSim.ship_params()


func _armed_ship(ship_id: StringName = &"kestrel") -> Ship:
	var ship: Ship = auto_free(FlightSim.spawn(self, ship_id))
	ship.weapons().seed_spread(1)
	return ship


func _hold_fire(ship: Ship, held: bool = true) -> void:
	var controls: ShipControls = ShipControls.new()
	controls.fire_primary = held
	ship.controls = controls


func test_every_ship_mounts_its_weapon_on_its_primary_sockets(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var ship: Ship = _armed_ship(ship_id)
	var mounts: Array = ship.weapons().mounts(WeaponSystem.GROUP_PRIMARY)
	assert_int(mounts.size()).is_equal(2)
	var weapon: WeaponDef = Content.weapon(ship.def.primary_weapon)
	for mount: WeaponMount in mounts:
		assert_object(mount.weapon).is_same(weapon)
		assert_object(mount.socket).is_not_null()
		assert_bool(mount.socket.is_inside_tree()).is_true()


func test_a_tier_3_ship_gets_a_third_mount_after_rebuild() -> void:
	var ship: Ship = _armed_ship()
	ship.model.set_tier(3)
	ship.weapons().rebuild()
	assert_int(ship.weapons().mounts(WeaponSystem.GROUP_PRIMARY).size()).is_equal(3)


func test_holding_fire_sends_shots_from_the_sockets() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 1)
	var shots: Array[Projectile] = manager.active_shots()
	assert_int(shots.size()).is_greater(0)
	# The first shot leaves the socket it was fired from, not the middle of the ship.
	var sockets: Array = []
	for mount: WeaponMount in ship.weapons().mounts(WeaponSystem.GROUP_PRIMARY):
		sockets.append(mount.socket.global_position)
	var near: bool = false
	for socket_position: Vector3 in sockets:
		if shots[0].previous.distance_to(socket_position) < 1.0:
			near = true
	assert_bool(near).is_true()
	assert_object(shots[0].shooter).is_same(ship)


func test_releasing_fire_stops_the_shots() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 30)
	_hold_fire(ship, false)
	var before: int = manager.spawned_total
	await SimHelper.step_physics(get_tree(), 60)
	assert_int(manager.spawned_total).is_equal(before)


func test_rate_of_fire_matches_the_weapon_def(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship(ship_id)
	var weapon: WeaponDef = Content.weapon(ship.def.primary_weapon)
	# No energy limits and no overheating for this test.
	ship.power().energy = 1.0e6
	ship.power().capacity = 1.0e6
	for mount: WeaponMount in ship.weapons().mounts(WeaponSystem.GROUP_PRIMARY):
		mount.heat = 0.0
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	# Stay under the overheat line: 2 s of fire.
	await SimHelper.step_physics(get_tree(), 120)
	var mounts: int = ship.weapons().mounts(WeaponSystem.GROUP_PRIMARY).size()
	var expected: float = weapon.fire_rate * 2.0 * mounts
	if weapon.heat_per_shot > 0.0:
		assert_bool(ship.weapons().is_overheated(WeaponSystem.GROUP_PRIMARY)).is_false()
	assert_float(float(manager.spawned_total)).is_between(expected - mounts, expected + mounts)


func test_shots_cost_energy_and_stop_when_it_runs_out() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	var weapon: WeaponDef = Content.weapon(ship.def.primary_weapon)
	var power: PowerSystem = ship.power()
	power.regen_per_second = 0.0
	var left_over: float = weapon.energy_cost * 0.5
	power.energy = weapon.energy_cost * 5.0 + left_over
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 120)
	# Exactly five shots were paid for; the half shot left over buys nothing.
	assert_int(manager.spawned_total).is_equal(5)
	assert_float(power.energy).is_equal_approx(left_over, 0.001)
	assert_bool(ship.weapons().energy_starved).is_true()


func test_energy_comes_back_and_the_guns_fire_again() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	ship.power().energy = 0.0
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 30)
	var early: int = manager.spawned_total
	await SimHelper.step_physics(get_tree(), 240)
	assert_int(manager.spawned_total).is_greater(early)


func test_the_autocannon_overheats_locks_out_and_recovers() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship(&"bulwark")
	var weapons: WeaponSystem = ship.weapons()
	var overheats: Array[int] = []
	weapons.overheated.connect(
		func(_group: StringName, mount: WeaponMount) -> void: overheats.append(mount.index)
	)
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	var ticks: int = 0
	while not weapons.is_overheated(WeaponSystem.GROUP_PRIMARY) and ticks < 900:
		await get_tree().physics_frame
		ticks += 1
	assert_bool(weapons.is_overheated(WeaponSystem.GROUP_PRIMARY)).is_true()
	assert_array(overheats).is_not_empty()
	# GDD feel target: a few seconds of continuous fire, not instant and not endless.
	assert_float(ticks * TICK).is_between(2.5, 7.0)
	# While overheated, holding the trigger fires nothing.
	var locked_total: int = manager.spawned_total
	await SimHelper.step_physics(get_tree(), 30)
	assert_int(manager.spawned_total).is_equal(locked_total)
	# Keep holding: it cools to the resume line and starts firing on its own.
	var waited: int = 0
	while weapons.is_overheated(WeaponSystem.GROUP_PRIMARY) and waited < 900:
		await get_tree().physics_frame
		waited += 1
	assert_bool(weapons.is_overheated(WeaponSystem.GROUP_PRIMARY)).is_false()
	await SimHelper.step_physics(get_tree(), 10)
	assert_int(manager.spawned_total).is_greater(locked_total)


func test_the_pulse_laser_builds_no_heat() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	ship.power().energy = 1.0e6
	ship.power().capacity = 1.0e6
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 240)
	assert_float(ship.weapons().heat_fraction(WeaponSystem.GROUP_PRIMARY)).is_equal(0.0)


func test_a_destroyed_ship_cannot_fire() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	ship.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	assert_bool(ship.durability().is_destroyed()).is_true()
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 60)
	assert_int(manager.spawned_total).is_equal(0)


func test_an_ion_hit_does_not_stop_the_primary_guns() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	ship.durability().apply(DamageInfo.make(5.0, DamageInfo.Type.ION))
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 30)
	assert_int(manager.spawned_total).is_greater(0)


func test_without_a_projectile_manager_the_guns_just_do_nothing() -> void:
	var ship: Ship = _armed_ship()
	_hold_fire(ship)
	await SimHelper.step_physics(get_tree(), 10)
	assert_float(ship.power().fraction()).is_equal(1.0)


func test_the_guns_cross_on_the_reticle_at_the_convergence_distance() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	var weapons: WeaponSystem = ship.weapons()
	var weapon: WeaponDef = weapons.weapon_for(WeaponSystem.GROUP_PRIMARY)
	var points: Array[Vector3] = []
	for mount: WeaponMount in weapons.mounts(WeaponSystem.GROUP_PRIMARY):
		var origin: Vector3 = mount.socket.global_position
		var direction: Vector3 = weapons.aim_direction(mount)
		# Distance along the ship's nose at which this shot is level with the convergence point.
		var along: float = weapon.convergence_m
		points.append(origin + direction * (along / -direction.z))
	assert_vector(points[0]).is_equal_approx(points[1], Vector3(0.05, 0.05, 0.05))
	assert_float(points[0].x).is_equal_approx(0.0, 0.05)


func test_a_locked_target_swings_the_guns_by_at_most_the_gimbal() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	var weapons: WeaponSystem = ship.weapons()
	var mount: WeaponMount = weapons.mounts(WeaponSystem.GROUP_PRIMARY)[0]
	var max_angle: float = deg_to_rad(mount.weapon.gimbal_deg)
	# A target 20 degrees off the nose: the guns go to the limit and no further.
	var far: Vector3 = (
		ship.global_position + Vector3(sin(deg_to_rad(20.0)), 0, -cos(deg_to_rad(20.0))) * 300.0
	)
	weapons.set_aim_point(far)
	assert_float(weapons.aim_direction(mount).angle_to(Vector3(0, 0, -1))).is_equal_approx(
		max_angle, 0.001
	)
	# A target 1 degree off: the guns point right at it.
	var near: Vector3 = (
		ship.global_position + Vector3(sin(deg_to_rad(1.0)), 0, -cos(deg_to_rad(1.0))) * 300.0
	)
	weapons.set_aim_point(near)
	var to_near: Vector3 = (near - mount.socket.global_position).normalized()
	assert_float(weapons.aim_direction(mount).angle_to(to_near)).is_less(0.0001)
	# The assist strength scales the limit: half strength, half the swing.
	weapons.set_aim_point(far)
	weapons.gimbal_scale = 0.5
	assert_float(weapons.aim_direction(mount).angle_to(Vector3(0, 0, -1))).is_equal_approx(
		max_angle * 0.5, 0.001
	)
	weapons.gimbal_scale = 1.0
	# The mouse gets no gimbal.
	weapons.gimbal_enabled = false
	assert_float(weapons.aim_direction(mount).angle_to(Vector3(0, 0, -1))).is_less(0.01)
	weapons.clear_aim_point()


func test_laser_and_autocannon_hit_a_dummy_with_their_own_damage_math() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var dummy: TargetDummy = auto_free(CombatSim.spawn_dummy(self, &"sturdy", Vector3(0, 0, -200)))
	await CombatSim.settle(get_tree())
	var log: CombatSim.HitLog = CombatSim.HitLog.new()
	log.attach(manager)
	# One laser shot, then one autocannon shot, straight at the dummy.
	var laser: WeaponDef = Content.weapon(&"pulse_laser")
	var cannon: WeaponDef = Content.weapon(&"autocannon")
	manager.spawn(laser, null, Vector3.ZERO, Vector3(0, 0, -1))
	await CombatSim.run_until_hits(get_tree(), log, 1, 100)
	var table: DamageTable = Content.damage_table()
	var laser_loss: float = dummy.def.shield_capacity - dummy.durability().shield
	assert_float(laser_loss).is_equal_approx(
		laser.damage * table.multiplier(DamageInfo.Type.ENERGY, DamageTable.Layer.SHIELD), 0.001
	)
	var shield_before: float = dummy.durability().shield
	manager.spawn(cannon, null, Vector3.ZERO, Vector3(0, 0, -1))
	await CombatSim.run_until_hits(get_tree(), log, 2, 100)
	var cannon_loss: float = shield_before - dummy.durability().shield
	assert_float(cannon_loss).is_equal_approx(
		cannon.damage * table.multiplier(DamageInfo.Type.KINETIC, DamageTable.Layer.SHIELD), 0.001
	)
	# Kinetic does less to a shield than energy does, and the reverse against armor.
	assert_float(cannon_loss).is_less(laser_loss)


func test_a_ship_shoots_a_dummy_down_and_it_comes_back() -> void:
	auto_free(CombatSim.spawn_manager(self))
	var ship: Ship = _armed_ship()
	var dummy: TargetDummy = auto_free(
		CombatSim.spawn_dummy(self, &"standard", Vector3(0, 0, -150))
	)
	ship.power().regen_per_second = 100.0
	await CombatSim.settle(get_tree())
	_hold_fire(ship)
	var destroyed_at: int = -1
	for tick: int in 1500:
		await get_tree().physics_frame
		if dummy.is_destroyed():
			destroyed_at = tick
			break
	assert_int(destroyed_at).is_greater(0)
	assert_bool(dummy.visible).is_false()
	_hold_fire(ship, false)
	await SimHelper.step_physics(get_tree(), int((dummy.def.respawn_seconds + 0.5) * 60.0))
	assert_bool(dummy.is_destroyed()).is_false()
	assert_bool(dummy.visible).is_true()
	assert_float(dummy.durability().hull).is_equal(dummy.def.hull_capacity)


func test_a_ship_hit_by_a_shot_shows_the_ripple_and_loses_shield() -> void:
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	var shooter: Ship = _armed_ship()
	var victim: Ship = auto_free(FlightSim.spawn(self, &"bulwark"))
	victim.global_position = Vector3(0, 0, -200)
	await CombatSim.settle(get_tree())
	manager.spawn(Content.weapon(&"pulse_laser"), shooter, Vector3(0, 0, -5), Vector3(0, 0, -1))
	await SimHelper.step_physics(get_tree(), 40)
	assert_float(victim.durability().shield).is_less(victim.def.shield_capacity)
	var bubble: ShieldFx = victim.get_node("ShieldFx") as ShieldFx
	assert_int(bubble.active_ripples()).is_equal(1)
	assert_bool(bubble.visible).is_true()
	await SimHelper.step_physics(get_tree(), 60)
	assert_int(bubble.active_ripples()).is_equal(0)
	assert_bool(bubble.visible).is_false()
