extends GdUnitTestSuite
## Targeting in the physics world: what a tap and a double-tap select, how a lock is lost to range
## and to a rock in the way, and how the aim assist helps (and only helps a gamepad).

const LASER_SPEED: float = 520.0

var _saved_device: InputRouter.Device


func before_test() -> void:
	_saved_device = InputRouter.last_device
	Settings.values.clear()


func after_test() -> void:
	InputRouter.last_device = _saved_device
	InputRouter.aim_friction = 1.0
	Settings.values.clear()


func _ship() -> Ship:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	ship.weapons().seed_spread(1)
	return ship


func _dummy(def_id: StringName, origin: Vector3, rail: Vector3 = Vector3.ZERO) -> TargetDummy:
	return auto_free(CombatSim.spawn_dummy(self, def_id, origin, rail))


func test_a_tap_selects_the_hostile_in_the_reticle_and_ignores_the_neutral_in_front() -> void:
	var ship: Ship = _ship()
	var neutral: TargetDummy = _dummy(&"neutral", Vector3(0, 0, -150))
	var hostile: TargetDummy = _dummy(&"standard", Vector3(10, 0, -300))
	await CombatSim.settle(get_tree())
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_same(hostile)
	assert_bool(ship.targeting().has_lock()).is_true()
	# A double-tap takes the nearest of any side.
	ship.targeting().command(ShipControls.Target.NEAREST_ANY)
	assert_object(ship.targeting().target).is_same(neutral)


func test_the_pilots_target_command_is_run_once_and_used_up() -> void:
	var ship: Ship = _ship()
	var near: TargetDummy = _dummy(&"standard", Vector3(0, 0, -200))
	var far: TargetDummy = _dummy(&"standard", Vector3(0, 0, -400))
	await CombatSim.settle(get_tree())
	var controls: ShipControls = ShipControls.new()
	controls.target_cmd = ShipControls.Target.NEAREST_HOSTILE
	ship.controls = controls
	await SimHelper.step_physics(get_tree(), 1)
	assert_object(ship.targeting().target).is_same(near)
	assert_int(controls.target_cmd).is_equal(ShipControls.Target.NONE)
	# Left alone, the same controls object does not cycle on to the next target.
	await SimHelper.step_physics(get_tree(), 10)
	assert_object(ship.targeting().target).is_same(near)
	controls.target_cmd = ShipControls.Target.NEAREST_HOSTILE
	await SimHelper.step_physics(get_tree(), 1)
	assert_object(ship.targeting().target).is_same(far)


func test_a_ships_own_body_and_destroyed_targets_are_not_candidates() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -200))
	await CombatSim.settle(get_tree())
	assert_int(ship.targeting().candidates().size()).is_equal(1)
	dummy.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.ENERGY))
	assert_int(ship.targeting().candidates().size()).is_equal(0)
	ship.targeting().command(ShipControls.Target.NEAREST_ANY)
	assert_object(ship.targeting().target).is_null()


func test_another_ship_can_be_targeted_with_its_name_and_stance() -> void:
	var ship: Ship = _ship()
	var enemy: Ship = auto_free(FlightSim.spawn(self, &"bulwark"))
	enemy.global_position = Vector3(0, 0, -400)
	await CombatSim.settle(get_tree())
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_same(enemy)
	assert_str(enemy.target_name()).is_equal(tr(enemy.def.display_name_key))
	assert_float(enemy.target_radius()).is_greater(1.0)
	enemy.stance = Targeting.Stance.FRIENDLY
	ship.targeting().clear()
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_null()


func test_a_target_that_leaves_lock_range_is_dropped_after_the_grace_time() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -1400))
	await CombatSim.settle(get_tree())
	var lost: Array[int] = []
	ship.targeting().lock_lost.connect(func(_t: Node3D, reason: int) -> void: lost.append(reason))
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_same(dummy)
	dummy.setup(Content.dummy(&"standard"), Vector3(0, 0, -1700))
	await SimHelper.step_physics(get_tree(), 60)
	# One second in: still selected, no lock.
	assert_object(ship.targeting().target).is_same(dummy)
	assert_int(ship.targeting().lock).is_equal(Targeting.Lock.OUT_OF_RANGE)
	assert_bool(ship.targeting().has_lock()).is_false()
	assert_array(lost).is_empty()
	await SimHelper.step_physics(get_tree(), 80)
	assert_object(ship.targeting().target).is_null()
	assert_array(lost).is_equal([Targeting.Lock.OUT_OF_RANGE])


func test_a_target_that_comes_back_into_range_in_time_keeps_its_lock() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -1400))
	await CombatSim.settle(get_tree())
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	dummy.setup(Content.dummy(&"standard"), Vector3(0, 0, -1700))
	await SimHelper.step_physics(get_tree(), 60)
	assert_bool(ship.targeting().has_lock()).is_false()
	dummy.setup(Content.dummy(&"standard"), Vector3(0, 0, -1000))
	await SimHelper.step_physics(get_tree(), 5)
	assert_bool(ship.targeting().has_lock()).is_true()
	assert_float(ship.targeting().lost_for).is_equal(0.0)
	# The clock starts over: another 90 ticks out of range is still within the grace time.
	dummy.setup(Content.dummy(&"standard"), Vector3(0, 0, -1700))
	await SimHelper.step_physics(get_tree(), 90)
	assert_object(ship.targeting().target).is_same(dummy)


func test_a_rock_in_the_way_breaks_the_lock_and_stops_a_tap_picking_it() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -300))
	var wall: StaticBody3D = CombatSim.spawn_wall(self, Vector3(0, 0, -100), Vector3(80, 80, 5))
	await CombatSim.settle(get_tree())
	# Hidden targets are not picked by a tap...
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_null()
	# ...and a lock on one that goes behind a rock is lost.
	wall.queue_free()
	await SimHelper.step_physics(get_tree(), 2)
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_same(dummy)
	var hiding: StaticBody3D = CombatSim.spawn_wall(self, Vector3(0, 0, -100), Vector3(80, 80, 5))
	auto_free(hiding)
	await CombatSim.settle(get_tree())
	await SimHelper.step_physics(get_tree(), 10)
	assert_int(ship.targeting().lock).is_equal(Targeting.Lock.OCCLUDED)
	assert_object(ship.targeting().target).is_same(dummy)
	await SimHelper.step_physics(get_tree(), 130)
	assert_object(ship.targeting().target).is_null()


func test_a_destroyed_target_is_dropped_at_once() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -300))
	await CombatSim.settle(get_tree())
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	assert_object(ship.targeting().target).is_same(dummy)
	dummy.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.ENERGY))
	await SimHelper.step_physics(get_tree(), 2)
	assert_object(ship.targeting().target).is_null()


func test_the_lead_point_leads_a_moving_target() -> void:
	var ship: Ship = _ship()
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -300), Vector3(200, 0, 0))
	await CombatSim.settle(get_tree())
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	await SimHelper.step_physics(get_tree(), 5)
	var targeting: Targeting = ship.targeting()
	assert_bool(targeting.has_lead).is_true()
	assert_float(dummy.velocity.x).is_greater(10.0)
	# Ahead of the dummy along its rail, by about what it covers while a shot flies.
	var ahead: float = targeting.lead_point.x - dummy.global_position.x
	var flight_time: float = dummy.global_position.distance_to(ship.global_position) / LASER_SPEED
	assert_float(ahead).is_equal_approx(dummy.velocity.x * flight_time, 1.5)


func test_only_the_players_ship_gets_aim_assist() -> void:
	var ship: Ship = _ship()
	_dummy(&"standard", Vector3(0, 0, -300))
	await CombatSim.settle(get_tree())
	InputRouter.last_device = InputRouter.Device.GAMEPAD
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	await SimHelper.step_physics(get_tree(), 3)
	# Not flagged as the player's: the guns and the stick are left alone.
	assert_float(InputRouter.aim_friction).is_equal(1.0)
	assert_float(ship.weapons().gimbal_scale).is_equal(1.0)
	var pilot: PlayerPilot = PlayerPilot.new()
	ship.add_child(pilot)
	assert_bool(ship.targeting().is_player).is_true()
	await SimHelper.step_physics(get_tree(), 3)
	assert_float(ship.weapons().gimbal_scale).is_equal_approx(
		Content.difficulty(&"normal").aim_assist_scale, 0.0001
	)
	ship.remove_child(pilot)
	pilot.free()
	assert_bool(ship.targeting().is_player).is_false()
	assert_float(InputRouter.aim_friction).is_equal(1.0)


func test_a_gamepad_gets_friction_on_the_target_and_the_mouse_gets_none() -> void:
	var ship: Ship = _ship()
	_dummy(&"standard", Vector3(0, 0, -300))
	await CombatSim.settle(get_tree())
	ship.targeting().is_player = true
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	InputRouter.last_device = InputRouter.Device.GAMEPAD
	await SimHelper.step_physics(get_tree(), 3)
	var def: TargetingDef = Content.targeting()
	var scale: float = Content.difficulty(&"normal").aim_assist_scale
	assert_float(InputRouter.aim_friction).is_equal_approx(
		1.0 - (1.0 - def.friction_min_factor) * scale, 0.01
	)
	# The mouse: no friction, no gimbal.
	InputRouter.last_device = InputRouter.Device.KEYBOARD_MOUSE
	await SimHelper.step_physics(get_tree(), 3)
	assert_float(InputRouter.aim_friction).is_equal(1.0)
	assert_bool(ship.weapons().gimbal_enabled).is_false()
	# Unless the player asks for it.
	Settings.set_value(AimAssist.SETTING_MOUSE, true)
	await SimHelper.step_physics(get_tree(), 3)
	assert_float(InputRouter.aim_friction).is_less(1.0)
	assert_bool(ship.weapons().gimbal_enabled).is_true()


func test_friction_stops_when_the_nose_is_far_from_the_target() -> void:
	var ship: Ship = _ship()
	_dummy(&"standard", Vector3(0, 0, -300))
	await CombatSim.settle(get_tree())
	ship.targeting().is_player = true
	ship.targeting().command(ShipControls.Target.NEAREST_HOSTILE)
	InputRouter.last_device = InputRouter.Device.GAMEPAD
	# Turn the ship 40 degrees away from the target.
	ship.global_basis = Basis(Vector3.UP, deg_to_rad(40.0))
	await SimHelper.step_physics(get_tree(), 3)
	assert_float(InputRouter.aim_friction).is_equal(1.0)


func _shots_that_hit_the_crossing_dummy(device: InputRouter.Device) -> int:
	var ship: Ship = _ship()
	var manager: ProjectileManager = auto_free(CombatSim.spawn_manager(self))
	# A dummy that starts straight ahead and slides sideways: shots flown at where it is miss it.
	var dummy: TargetDummy = _dummy(&"standard", Vector3(0, 0, -300), Vector3(400, 0, 0))
	await CombatSim.settle(get_tree())
	var hits: CombatSim.HitLog = CombatSim.HitLog.new()
	hits.attach(manager)
	InputRouter.last_device = device
	Settings.set_value(AimAssist.SETTING_DIFFICULTY, &"easy")
	ship.targeting().is_player = true
	ship.targeting().select(dummy)
	var controls: ShipControls = ShipControls.new()
	controls.fire_primary = true
	ship.controls = controls
	await SimHelper.step_physics(get_tree(), 30)
	controls.fire_primary = false
	await SimHelper.step_physics(get_tree(), 90)
	var count: int = 0
	for hit: Dictionary in hits.hits:
		if hit["collider"] == dummy:
			count += 1
	return count


func test_the_gimbal_towards_the_lead_point_hits_a_crossing_target_a_plain_nose_shot_misses(
) -> void:
	var with_assist: int = await _shots_that_hit_the_crossing_dummy(InputRouter.Device.GAMEPAD)
	assert_int(with_assist).is_greater(1)


func test_without_assist_the_same_shots_miss() -> void:
	var without: int = await _shots_that_hit_the_crossing_dummy(InputRouter.Device.KEYBOARD_MOUSE)
	assert_int(without).is_equal(0)
