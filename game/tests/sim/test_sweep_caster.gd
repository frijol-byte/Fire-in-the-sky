extends GdUnitTestSuite
## `SweepCaster`: the sphere sweep shots and missiles share.

var _caster: SweepCaster = null


func before_test() -> void:
	_caster = SweepCaster.new(PhysicsLayers.PROJECTILE_MASK)


func _space() -> PhysicsDirectSpaceState3D:
	return (get_tree().root.get_world_3d() as World3D).direct_space_state


func test_a_clear_path_reports_nothing() -> void:
	var contact: Dictionary = _caster.cast(
		_space(), Vector3.ZERO, Vector3(0, 0, -100), 0.5, [] as Array[RID]
	)
	assert_bool(contact.is_empty()).is_true()


func test_a_wall_in_the_way_is_reported_where_the_sphere_touches_it() -> void:
	var wall: StaticBody3D = auto_free(
		CombatSim.spawn_wall(self, Vector3(0, 0, -50), Vector3(40, 40, 4))
	)
	await CombatSim.settle(get_tree())
	var contact: Dictionary = _caster.cast(
		_space(), Vector3.ZERO, Vector3(0, 0, -100), 0.5, [] as Array[RID]
	)
	assert_bool(contact.is_empty()).is_false()
	assert_object(contact["collider"] as Object).is_same(wall)
	# The wall's near face is at z = -48; the sphere's centre stops half a metre short of it.
	assert_float((contact["position"] as Vector3).z).is_equal_approx(-47.5, 0.1)
	assert_float((contact["point"] as Vector3).z).is_equal_approx(-48.0, 0.1)


func test_a_wall_beyond_the_motion_is_not_hit() -> void:
	auto_free(CombatSim.spawn_wall(self, Vector3(0, 0, -50), Vector3(40, 40, 4)))
	await CombatSim.settle(get_tree())
	var contact: Dictionary = _caster.cast(
		_space(), Vector3.ZERO, Vector3(0, 0, -30), 0.5, [] as Array[RID]
	)
	assert_bool(contact.is_empty()).is_true()


func test_an_excluded_body_is_ignored() -> void:
	var wall: StaticBody3D = auto_free(
		CombatSim.spawn_wall(self, Vector3(0, 0, -50), Vector3(40, 40, 4))
	)
	await CombatSim.settle(get_tree())
	var contact: Dictionary = _caster.cast(
		_space(), Vector3.ZERO, Vector3(0, 0, -100), 0.5, [wall.get_rid()] as Array[RID]
	)
	assert_bool(contact.is_empty()).is_true()


func test_a_zero_motion_reports_nothing() -> void:
	var contact: Dictionary = _caster.cast(
		_space(), Vector3.ZERO, Vector3.ZERO, 0.5, [] as Array[RID]
	)
	assert_bool(contact.is_empty()).is_true()


func test_a_fast_sphere_cannot_skip_a_thin_wall() -> void:
	var wall: StaticBody3D = auto_free(
		CombatSim.spawn_wall(self, Vector3(0, 0, -50), Vector3(40, 40, 0.2))
	)
	await CombatSim.settle(get_tree())
	var contact: Dictionary = _caster.cast(
		_space(), Vector3(0, 0, -20), Vector3(0, 0, -200), 0.3, [] as Array[RID]
	)
	assert_object(contact["collider"] as Object).is_same(wall)
