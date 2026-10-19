extends GdUnitTestSuite
## `RockColliders`: the pool puts bodies on the rocks nearest the target and moves them as the
## target moves. Box shapes stand in for the rock hulls.

const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")

var _arena: ArenaDef = null
var _field: RockField = null
var _colliders: RockColliders = null


func before_test() -> void:
	_arena = FLIGHT_TEST.duplicate() as ArenaDef
	_arena.field_rock_count = 1500
	_arena.collider_pool_size = 8
	_arena.collider_radius = 400.0
	_field = RockField.generate(_arena, PackedFloat32Array([5.0, 5.0, 5.0, 5.0]))
	var shapes: Array[Shape3D] = []
	for _variant: int in 4:
		shapes.append(BoxShape3D.new())
	_colliders = auto_free(RockColliders.new())
	add_child(_colliders)
	_colliders.setup(_field, shapes, _arena)


func test_the_pool_is_filled_with_the_nearest_rocks() -> void:
	var point: Vector3 = Vector3(0.0, 0.0, -300.0)
	_colliders.update_around(point)
	var expected: PackedInt32Array = _field.nearby(point, _arena.collider_radius, 8)
	assert_int(_colliders.active_count()).is_equal(expected.size())
	for rock: int in expected:
		var body: StaticBody3D = _colliders.body_for(rock)
		assert_object(body).is_not_null()
		assert_bool(body.global_transform.is_equal_approx(_field.transforms[rock])).is_true()


func test_never_more_bodies_than_the_pool() -> void:
	_colliders.update_around(Vector3.ZERO)
	assert_int(_colliders.active_count()).is_less_equal(8)


func test_bodies_follow_the_target() -> void:
	_colliders.update_around(Vector3(0.0, 0.0, -300.0))
	var far: Vector3 = Vector3(1500.0, 0.0, 800.0)
	_colliders.update_around(far)
	var expected: PackedInt32Array = _field.nearby(far, _arena.collider_radius, 8)
	assert_int(_colliders.active_count()).is_equal(expected.size())
	for rock: int in _colliders.active_rocks():
		assert_bool(expected.has(rock)).is_true()


func test_a_rock_keeps_its_body_while_it_stays_in_range() -> void:
	var point: Vector3 = Vector3(0.0, 0.0, -300.0)
	_colliders.update_around(point)
	var rock: int = _colliders.active_rocks()[0]
	var body: StaticBody3D = _colliders.body_for(rock)
	_colliders.update_around(point + Vector3(2.0, 0.0, 0.0))
	if _colliders.active_rocks().has(rock):
		assert_object(_colliders.body_for(rock)).is_same(body)


func test_far_from_every_rock_nothing_is_solid() -> void:
	_colliders.update_around(Vector3(0.0, 90000.0, 0.0))
	assert_int(_colliders.active_count()).is_equal(0)


func test_unused_bodies_are_switched_off() -> void:
	_colliders.update_around(Vector3(0.0, 90000.0, 0.0))
	for child: Node in _colliders.get_children():
		var shape: CollisionShape3D = child.get_child(0) as CollisionShape3D
		assert_bool(shape.disabled).is_true()
