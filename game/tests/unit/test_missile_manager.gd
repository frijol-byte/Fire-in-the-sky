extends GdUnitTestSuite
## `MissileManager` bookkeeping that needs no hits: the pools, the streaks, flares and the lookups.

const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
const ROCKET: SecondaryDef = preload("res://data/secondaries/rocket_pod.tres")
const FLARES: DeviceDef = preload("res://data/devices/flares.tres")


func _manager(capacity: int = MissileManager.DEFAULT_CAPACITY) -> MissileManager:
	var manager: MissileManager = auto_free(MissileManager.new())
	manager.capacity = capacity
	add_child(manager)
	return manager


func test_the_pools_are_built_once_and_start_empty() -> void:
	var manager: MissileManager = _manager()
	assert_int(manager.pool_size()).is_equal(MissileManager.DEFAULT_CAPACITY)
	assert_int(manager.active_count()).is_equal(0)
	assert_int(manager.launched_total).is_equal(0)
	assert_array(manager.active_flares()).is_empty()
	assert_object(manager.fx).is_not_null()
	assert_object(MissileManager.for_node(manager)).is_same(manager)


func test_launching_counts_rounds_and_a_rocket_is_never_guided() -> void:
	var manager: MissileManager = _manager()
	var target: Node3D = auto_free(Node3D.new())
	add_child(target)
	var missile: Missile = manager.launch(MISSILE, null, Vector3.ZERO, Vector3(0, 0, -100), target)
	var rocket: Missile = manager.launch(ROCKET, null, Vector3.ZERO, Vector3(0, 0, -100), target)
	assert_int(manager.active_count()).is_equal(2)
	assert_bool(missile.guided).is_true()
	assert_bool(rocket.guided).is_false()
	# A missile with no target is a plain dumb round too.
	assert_bool(manager.launch(MISSILE, null, Vector3.ZERO, Vector3(0, 0, -100)).guided).is_false()


func test_active_missiles_are_listed_oldest_first() -> void:
	var manager: MissileManager = _manager()
	for index: int in 5:
		manager.launch(ROCKET, null, Vector3(index, 0, 0), Vector3(0, 0, -100))
	var rounds: Array[Missile] = manager.active_missiles()
	for index: int in 5:
		assert_float(rounds[index].position.x).is_equal(float(index))


func test_a_missile_that_hits_nothing_flies_straight_and_burns_out_harmlessly() -> void:
	var manager: MissileManager = _manager()
	var blasts: Array[bool] = []
	manager.exploded.connect(
		func(_missile: Missile, _point: Vector3, harmless: bool) -> void: blasts.append(harmless)
	)
	var missile: Missile = manager.launch(ROCKET, null, Vector3.ZERO, Vector3(0, 0, -100))
	manager.step(0.5)
	assert_float(missile.position.z).is_less(0.0)
	assert_vector(missile.previous).is_equal(Vector3.ZERO)
	assert_float(missile.age).is_equal_approx(0.5, 0.0001)
	# Accelerating from 100 m/s: faster than it started.
	assert_float(missile.speed()).is_greater(100.0)
	for tick: int in int(ROCKET.lifetime / 0.5):
		manager.step(0.5)
	assert_int(manager.active_count()).is_equal(0)
	assert_array(blasts).is_equal([true])


func test_the_streaks_count_two_per_round_and_one_per_flare() -> void:
	var manager: MissileManager = _manager()
	var ship: Node3D = auto_free(Node3D.new())
	add_child(ship)
	for index: int in 3:
		manager.launch(ROCKET, null, Vector3(index, 0, 0), Vector3(0, 0, -100))
	manager.deploy_flares(ship, FLARES)
	manager.draw_streaks(0.5)
	var multimesh: MultiMesh = (manager.get_node("Streaks") as MultiMeshInstance3D).multimesh
	assert_int(multimesh.visible_instance_count).is_equal(
		3 * MissileManager.STREAKS_PER_MISSILE + FLARES.flare_count
	)
	# Nothing left: nothing drawn.
	for tick: int in 100:
		manager.step(0.1)
	manager.draw_streaks(0.5)
	assert_int(multimesh.visible_instance_count).is_equal(0)


func test_a_flare_burns_for_its_lifetime_and_fades_at_the_end() -> void:
	var manager: MissileManager = _manager()
	var ship: Node3D = auto_free(Node3D.new())
	add_child(ship)
	manager.deploy_flares(ship, FLARES)
	var flare: Flare = manager.active_flares()[0]
	assert_float(flare.brightness()).is_equal(1.0)
	manager.step(FLARES.flare_lifetime - 0.5)
	assert_float(flare.brightness()).is_equal_approx(0.5, 0.001)
	manager.step(0.6)
	assert_array(manager.active_flares()).is_empty()


func test_flares_leave_the_ship_sideways_with_its_own_drift() -> void:
	var manager: MissileManager = _manager()
	var ship: Ship = auto_free(CombatSim.spawn_ship(self, &"kestrel", Vector3.ZERO))
	ship.linear_velocity = Vector3(0.0, 0.0, -100.0)
	manager.deploy_flares(ship, FLARES)
	var forward_drift: float = 0.0
	for flare: Flare in manager.active_flares():
		forward_drift += flare.velocity.z
		assert_float(flare.velocity.length()).is_greater(10.0)
	# On average they carry a good part of the ship's forward speed (-Z), not zero and not all of it.
	forward_drift /= float(FLARES.flare_count)
	assert_float(forward_drift).is_between(-100.0, -30.0)
