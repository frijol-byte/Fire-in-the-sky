extends GdUnitTestSuite
## `Projectile`: launching, retiring and the interpolated draw position.


func test_launch_sets_position_velocity_and_owner() -> void:
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var shot: Projectile = Projectile.new()
	var shooter: Node = auto_free(Node.new())
	shot.launch(weapon, shooter, Vector3(1, 2, 3), Vector3(0, 0, -1), 7)
	assert_bool(shot.active).is_true()
	assert_int(shot.serial).is_equal(7)
	assert_vector(shot.position).is_equal(Vector3(1, 2, 3))
	assert_vector(shot.previous).is_equal(Vector3(1, 2, 3))
	assert_vector(shot.velocity).is_equal(Vector3(0, 0, -weapon.projectile_speed))
	assert_object(shot.shooter).is_same(shooter)
	assert_float(shot.travelled).is_equal(0.0)


func test_a_ship_shooter_is_excluded_from_the_shape_cast() -> void:
	var ship: Ship = auto_free(FlightSim.spawn(self, &"kestrel"))
	var shot: Projectile = Projectile.new()
	shot.launch(Content.weapon(&"pulse_laser"), ship, Vector3.ZERO, Vector3(0, 0, -1), 1)
	assert_array(shot.exclude).is_equal([ship.get_rid()])


func test_a_plain_shooter_excludes_nothing() -> void:
	var shot: Projectile = Projectile.new()
	shot.launch(Content.weapon(&"pulse_laser"), null, Vector3.ZERO, Vector3(0, 0, -1), 1)
	assert_array(shot.exclude).is_empty()


func test_retire_frees_the_slot_and_forgets_the_references() -> void:
	var shot: Projectile = Projectile.new()
	shot.launch(Content.weapon(&"pulse_laser"), null, Vector3.ZERO, Vector3(0, 0, -1), 1)
	shot.retire()
	assert_bool(shot.active).is_false()
	assert_object(shot.weapon).is_null()
	assert_object(shot.shooter).is_null()


func test_launching_again_starts_clean() -> void:
	# A reused slot must not draw a streak from its old position.
	var weapon: WeaponDef = Content.weapon(&"pulse_laser")
	var shot: Projectile = Projectile.new()
	shot.launch(weapon, null, Vector3(500, 0, 0), Vector3(0, 0, -1), 1)
	shot.position = Vector3(500, 0, -300)
	shot.travelled = 300.0
	shot.retire()
	shot.launch(weapon, null, Vector3(0, 10, 0), Vector3(1, 0, 0), 2)
	assert_vector(shot.previous).is_equal(Vector3(0, 10, 0))
	assert_vector(shot.drawn_position(0.0)).is_equal(Vector3(0, 10, 0))
	assert_vector(shot.drawn_position(1.0)).is_equal(Vector3(0, 10, 0))
	assert_float(shot.travelled).is_equal(0.0)


func test_drawn_position_interpolates_between_the_last_two_ticks() -> void:
	var shot: Projectile = Projectile.new()
	shot.previous = Vector3(0, 0, 0)
	shot.position = Vector3(0, 0, -10)
	assert_vector(shot.drawn_position(0.0)).is_equal(Vector3(0, 0, 0))
	assert_vector(shot.drawn_position(0.25)).is_equal(Vector3(0, 0, -2.5))
	assert_vector(shot.drawn_position(1.0)).is_equal(Vector3(0, 0, -10))
