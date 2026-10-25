extends GdUnitTestSuite
## `ProjectileManager` bookkeeping that needs no hits: the pool, the streak look and the lookups.


func _manager() -> ProjectileManager:
	var manager: ProjectileManager = auto_free(ProjectileManager.new())
	add_child(manager)
	return manager


func test_the_pool_is_built_once_and_starts_empty() -> void:
	var manager: ProjectileManager = _manager()
	assert_int(manager.pool_size()).is_equal(ProjectileManager.DEFAULT_CAPACITY)
	assert_int(manager.active_count()).is_equal(0)
	assert_int(manager.spawned_total).is_equal(0)
	assert_object(manager.fx).is_not_null()


func test_spawn_counts_shots_and_normalises_the_direction() -> void:
	var manager: ProjectileManager = _manager()
	var weapon: WeaponDef = Content.weapon(&"autocannon")
	var shot: Projectile = manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -5))
	assert_int(manager.active_count()).is_equal(1)
	assert_int(manager.spawned_total).is_equal(1)
	assert_float(shot.velocity.length()).is_equal_approx(weapon.projectile_speed, 0.001)


func test_a_zero_direction_spawns_nothing() -> void:
	var manager: ProjectileManager = _manager()
	var shot: Projectile = manager.spawn(
		Content.weapon(&"autocannon"), null, Vector3.ZERO, Vector3.ZERO
	)
	assert_object(shot).is_null()
	assert_int(manager.active_count()).is_equal(0)


func test_active_shots_are_listed_oldest_first() -> void:
	var manager: ProjectileManager = _manager()
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	for index: int in 5:
		manager.spawn(weapon, null, Vector3(index, 0, 0), Vector3(0, 0, -1))
	var shots: Array[Projectile] = manager.active_shots()
	assert_int(shots.size()).is_equal(5)
	for index: int in 5:
		assert_float(shots[index].position.x).is_equal(float(index))


func test_stepping_flies_shots_that_hit_nothing() -> void:
	var manager: ProjectileManager = _manager()
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var shot: Projectile = manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -1))
	manager.step(0.1)
	assert_float(shot.position.z).is_equal_approx(-weapon.projectile_speed * 0.1, 0.001)
	assert_float(shot.travelled).is_equal_approx(weapon.projectile_speed * 0.1, 0.001)
	assert_vector(shot.previous).is_equal(Vector3.ZERO)


func test_a_shot_is_retired_exactly_at_its_range() -> void:
	var manager: ProjectileManager = _manager()
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var shot: Projectile = manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -1))
	# One giant step past the range: the shot ends at the range, not beyond it.
	manager.step(10.0)
	assert_int(manager.active_count()).is_equal(0)
	assert_float(shot.position.z).is_equal_approx(-weapon.range_m, 0.001)


func test_draw_streaks_shows_one_instance_per_active_shot() -> void:
	var manager: ProjectileManager = _manager()
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	manager.spawn(weapon, null, Vector3.ZERO, Vector3(0, 0, -1))
	manager.spawn(weapon, null, Vector3(5, 0, 0), Vector3(0, 0, -1))
	manager.draw_streaks(1.0)
	var streaks: MultiMeshInstance3D = manager.get_node("Streaks") as MultiMeshInstance3D
	assert_int(streaks.multimesh.visible_instance_count).is_equal(2)
	manager.step(100.0)
	manager.draw_streaks(1.0)
	assert_int(streaks.multimesh.visible_instance_count).is_equal(0)


func test_streak_transform_trails_behind_the_head_and_has_the_tracer_size() -> void:
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var head: Vector3 = Vector3(0, 0, -100)
	var transform: Transform3D = ProjectileManager.streak_transform(head, Vector3(0, 0, -1), weapon)
	# Centre half a streak behind the head (towards +Z when flying along -Z).
	assert_vector(transform.origin).is_equal_approx(
		Vector3(0, 0, -100 + weapon.tracer_length * 0.5), Vector3(0.001, 0.001, 0.001)
	)
	assert_float(transform.basis.get_scale().z).is_equal_approx(weapon.tracer_length, 0.001)
	assert_float(transform.basis.get_scale().x).is_equal_approx(weapon.tracer_width, 0.001)


func test_streak_transform_survives_a_vertical_shot() -> void:
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var transform: Transform3D = ProjectileManager.streak_transform(
		Vector3.ZERO, Vector3.UP, weapon
	)
	assert_bool(is_nan(transform.origin.x)).is_false()
	assert_float(transform.basis.get_scale().z).is_equal_approx(weapon.tracer_length, 0.001)


func test_durability_of_finds_ships_and_dummies_but_not_rocks() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var rock: StaticBody3D = auto_free(StaticBody3D.new())
	assert_object(ProjectileManager.durability_of(ship)).is_same(ship.durability())
	assert_object(ProjectileManager.durability_of(rock)).is_null()
	assert_object(ProjectileManager.durability_of(null)).is_null()


func test_for_node_finds_the_manager_of_the_scene() -> void:
	var manager: ProjectileManager = _manager()
	var other: Node = auto_free(Node.new())
	add_child(other)
	assert_object(ProjectileManager.for_node(other)).is_same(manager)
	assert_object(ProjectileManager.for_node(null)).is_null()
	assert_object(ProjectileManager.for_node(auto_free(Node.new()))).is_null()
