extends GdUnitTestSuite
## `DebrisField`: a burst throws the def's number of chunks, they fly, cool, shrink and are
## recycled, and the pool never grows.

const LOOK: DestructionDef = preload("res://data/combat/destruction_default.tres")


func _field() -> DebrisField:
	var field: DebrisField = auto_free(DebrisField.new())
	add_child(field)
	return field


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func test_a_burst_throws_the_defs_number_of_chunks() -> void:
	var field: DebrisField = _field()
	assert_int(field.active_count()).is_equal(0)
	field.burst(Vector3(0, 0, -100), Vector3.ZERO, 6.0, LOOK, _rng())
	assert_int(field.active_count()).is_equal(LOOK.debris_count)


func test_chunks_move_away_from_the_blast() -> void:
	var field: DebrisField = _field()
	var origin: Vector3 = Vector3(0, 0, -100)
	field.burst(origin, Vector3.ZERO, 6.0, LOOK, _rng())
	field.advance(1.0)
	var moved: int = 0
	for child: Node in field.get_children():
		var chunk: MeshInstance3D = child as MeshInstance3D
		if chunk != null and chunk.visible and chunk.global_position.distance_to(origin) > 5.0:
			moved += 1
	assert_int(moved).is_equal(LOOK.debris_count)


func test_chunks_leave_when_their_time_is_up() -> void:
	var field: DebrisField = _field()
	field.burst(Vector3.ZERO, Vector3.ZERO, 6.0, LOOK, _rng())
	field.advance(LOOK.debris_lifetime + 0.5)
	assert_int(field.active_count()).is_equal(0)
	for child: Node in field.get_children():
		assert_bool((child as MeshInstance3D).visible).is_false()


func test_the_pool_is_reused_when_it_is_full() -> void:
	var field: DebrisField = _field()
	var children: int = field.get_child_count()
	for _burst: int in 20:
		field.burst(Vector3.ZERO, Vector3.ZERO, 6.0, LOOK, _rng())
	assert_int(field.get_child_count()).is_equal(children)
	assert_int(field.active_count()).is_less_equal(DebrisField.POOL_SIZE)


func test_chunks_start_hot_and_end_cold_and_small() -> void:
	var field: DebrisField = _field()
	field.burst(Vector3.ZERO, Vector3.ZERO, 10.0, LOOK, _rng())
	var chunk: MeshInstance3D = field.get_child(0) as MeshInstance3D
	var material: StandardMaterial3D = chunk.material_override as StandardMaterial3D
	assert_float(material.emission_energy_multiplier).is_equal(DebrisField.HOT_ENERGY)
	field.advance(LOOK.debris_cool_seconds + 0.1)
	assert_float(material.emission_energy_multiplier).is_equal(0.0)
	var size_before: float = chunk.scale.x
	field.advance(LOOK.debris_lifetime * 0.9)
	if chunk.visible:
		assert_float(chunk.scale.x).is_less(size_before)


func test_a_burst_is_repeatable_with_the_same_seed() -> void:
	var first: DebrisField = _field()
	var second: DebrisField = _field()
	first.burst(Vector3.ZERO, Vector3.ZERO, 6.0, LOOK, _rng())
	second.burst(Vector3.ZERO, Vector3.ZERO, 6.0, LOOK, _rng())
	first.advance(0.5)
	second.advance(0.5)
	for index: int in LOOK.debris_count:
		var a: MeshInstance3D = first.get_child(index) as MeshInstance3D
		var b: MeshInstance3D = second.get_child(index) as MeshInstance3D
		assert_vector(a.global_position).is_equal(b.global_position)
