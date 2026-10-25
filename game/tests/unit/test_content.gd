extends GdUnitTestSuite
## `Content` scans `res://data/` and indexes defs by kind and id.

const KESTREL: ShipDef = preload("res://data/ships/kestrel.tres")


func _kestrel_copy() -> ShipDef:
	return KESTREL.duplicate() as ShipDef


func test_the_kestrel_is_loaded_with_gdd_values() -> void:
	var kestrel: ShipDef = Content.ship(&"kestrel")
	assert_object(kestrel).is_not_null()
	# GDD 4.4, light fighter.
	assert_float(kestrel.max_speed).is_equal(180.0)
	assert_float(kestrel.boost_max_speed).is_equal(320.0)
	assert_float(kestrel.accel_forward()).is_equal_approx(60.0, 0.001)
	assert_float(kestrel.accel_lateral()).is_equal_approx(110.0, 0.001)
	assert_vector(kestrel.max_angular_rate_deg).is_equal(Vector3(90, 90, 150))


func test_unknown_ids_and_kinds_return_null() -> void:
	assert_object(Content.ship(&"no_such_ship")).is_null()
	assert_object(Content.get_def(&"no_such_kind", &"kestrel")).is_null()


func test_every_registered_ship_def_is_valid() -> void:
	var ids: Array[StringName] = Content.ids(&"ship")
	assert_array(ids).contains([&"kestrel"])
	for id: StringName in ids:
		var def: ShipDef = Content.ship(id)
		assert_str(def.id).is_equal(id)
		assert_array(def.problems()).is_empty()
		assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)


func test_the_model_of_every_ship_instantiates_as_a_ship_model() -> void:
	for id: StringName in Content.ids(&"ship"):
		var packed: PackedScene = load(Content.ship(id).model_path) as PackedScene
		var model: Node = packed.instantiate()
		assert_object(model).is_instanceof(ShipModel)
		model.free()


func test_load_directory_registers_defs_and_skips_invalid_ones() -> void:
	var dir_path: String = "user://content_test"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var good: ShipDef = _kestrel_copy()
	good.id = &"test_good"
	assert_int(ResourceSaver.save(good, dir_path + "/good.tres")).is_equal(OK)
	var bad: ShipDef = good.duplicate() as ShipDef
	bad.id = &"test_bad"
	bad.mass = 0.0
	assert_int(ResourceSaver.save(bad, dir_path + "/bad.tres")).is_equal(OK)

	var loaded: int = Content.load_directory(dir_path)

	assert_int(loaded).is_equal(1)
	assert_object(Content.ship(&"test_good")).is_not_null()
	assert_object(Content.ship(&"test_bad")).is_null()
	Content.unregister(&"ship", &"test_good")
	DirAccess.remove_absolute(dir_path + "/good.tres")
	DirAccess.remove_absolute(dir_path + "/bad.tres")


func test_problems_reports_bad_values() -> void:
	var def: ShipDef = _kestrel_copy()
	def.max_speed = -1.0
	def.model_path = "res://nope.glb"
	def.id = &""
	var found: String = ", ".join(def.problems())
	assert_str(found).contains("max_speed must be above 0")
	assert_str(found).contains("model_path")
	assert_str(found).contains("id is empty")
	var no_response: ShipDef = _kestrel_copy()
	no_response.strafe_response_time = 0.0
	assert_str(", ".join(no_response.problems())).contains("strafe_response_time")
	var slow_boost: ShipDef = _kestrel_copy()
	slow_boost.boost_max_speed = slow_boost.max_speed - 1.0
	assert_str(", ".join(slow_boost.problems())).contains("boost_max_speed")


func test_problems_reports_bad_energy_and_boost_values() -> void:
	var def: ShipDef = _kestrel_copy()
	def.boost_min_energy = def.energy_capacity + 1.0
	def.energy_regen = -1.0
	def.fa_excess_bleed_time = 0.0
	def.boost_energy_per_second = 0.0
	var found: String = ", ".join(def.problems())
	assert_str(found).contains("boost_min_energy")
	assert_str(found).contains("energy_regen")
	assert_str(found).contains("fa_excess_bleed_time")
	assert_str(found).contains("boost_energy_per_second")
