extends GdUnitTestSuite
## `TargetDummy`: the rail it slides on, its stats from the def, and destruction and respawn.

const DUMMY_SCENE: PackedScene = preload("res://world/props/target_dummy.tscn")
const DT: float = 1.0 / 60.0


func _dummy(def_id: StringName = &"standard", rail: Vector3 = Vector3.ZERO) -> TargetDummy:
	var dummy: TargetDummy = auto_free(DUMMY_SCENE.instantiate()) as TargetDummy
	add_child(dummy)
	dummy.setup(Content.dummy(def_id), Vector3(10, 0, -50), rail)
	return dummy


func test_rail_position_runs_out_and_back() -> void:
	var origin: Vector3 = Vector3(0, 5, 0)
	var rail: Vector3 = Vector3(100, 0, 0)
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 0.0)).is_equal(origin)
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 5.0)).is_equal(Vector3(50, 5, 0))
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 10.0)).is_equal(Vector3(100, 5, 0))
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 15.0)).is_equal(Vector3(50, 5, 0))
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 20.0)).is_equal(origin)
	assert_vector(TargetDummy.rail_position(origin, rail, 10.0, 25.0)).is_equal(Vector3(50, 5, 0))


func test_rail_position_with_no_rail_or_no_speed_stays_put() -> void:
	var origin: Vector3 = Vector3(1, 2, 3)
	assert_vector(TargetDummy.rail_position(origin, Vector3.ZERO, 10.0, 7.0)).is_equal(origin)
	assert_vector(TargetDummy.rail_position(origin, Vector3(50, 0, 0), 0.0, 7.0)).is_equal(origin)


func test_setup_takes_the_layers_and_size_from_the_def() -> void:
	var dummy: TargetDummy = _dummy(&"sturdy")
	var def: DummyDef = Content.dummy(&"sturdy")
	assert_float(dummy.durability().shield).is_equal(def.shield_capacity)
	assert_float(dummy.durability().armor).is_equal(def.armor_capacity)
	assert_float(dummy.durability().hull).is_equal(def.hull_capacity)
	(
		assert_float(((dummy.get_node("Shape") as CollisionShape3D).shape as SphereShape3D).radius)
		. is_equal(def.radius)
	)


func test_a_dummy_is_on_the_target_layer_and_in_the_targets_group() -> void:
	var dummy: TargetDummy = _dummy()
	assert_int(dummy.collision_layer).is_equal(PhysicsLayers.TARGETS)
	assert_bool(dummy.is_in_group(TargetDummy.GROUP)).is_true()


func test_the_label_shows_the_layers_and_follows_damage() -> void:
	var dummy: TargetDummy = _dummy()
	var label: Label3D = dummy.get_node("Label") as Label3D
	assert_str(label.text).is_equal("S 120  A 100  H 120")
	dummy.durability().apply(DamageInfo.make(40.0, DamageInfo.Type.EXPLOSIVE))
	dummy._physics_process(DT)
	assert_str(label.text).is_equal("S 80  A 100  H 120")


func test_destroying_a_dummy_hides_it_and_it_returns_repaired() -> void:
	var dummy: TargetDummy = _dummy()
	dummy.durability().apply(DamageInfo.make(100000.0, DamageInfo.Type.EXPLOSIVE))
	assert_bool(dummy.is_destroyed()).is_true()
	assert_bool(dummy.visible).is_false()
	var ticks: int = roundi(dummy.def.respawn_seconds / DT) - 2
	for _tick: int in ticks:
		dummy._physics_process(DT)
	assert_bool(dummy.is_destroyed()).is_true()
	for _tick: int in 4:
		dummy._physics_process(DT)
	assert_bool(dummy.is_destroyed()).is_false()
	assert_bool(dummy.visible).is_true()
	assert_float(dummy.durability().hull).is_equal(dummy.def.hull_capacity)
	assert_float(dummy.durability().shield).is_equal(dummy.def.shield_capacity)


func test_a_moving_dummy_reports_its_velocity() -> void:
	var dummy: TargetDummy = _dummy(&"standard", Vector3(200, 0, 0))
	for _tick: int in 30:
		dummy._physics_process(DT)
	assert_float(dummy.velocity.x).is_equal_approx(dummy.def.rail_speed, 0.5)
	assert_float(dummy.velocity.y).is_equal_approx(0.0, 0.001)


func test_a_standing_dummy_has_no_velocity() -> void:
	var dummy: TargetDummy = _dummy(&"sturdy")
	for _tick: int in 10:
		dummy._physics_process(DT)
	assert_vector(dummy.velocity).is_equal(Vector3.ZERO)
