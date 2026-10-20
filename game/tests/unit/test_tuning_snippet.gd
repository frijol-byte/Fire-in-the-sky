extends GdUnitTestSuite
## The tuning-snippet writer and the list of tuning parameters.

const DIR: String = "user://test_tuning"


func after_test() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


func _def() -> ShipDef:
	return Content.ship(&"kestrel").duplicate() as ShipDef


func test_snippet_lists_every_edited_field_once_in_tres_syntax() -> void:
	var def: ShipDef = _def()
	def.mass = 7500.0
	def.max_angular_rate_deg = Vector3(100, 95, 160)
	var text: String = TuningSnippet.build(def, TuningParam.all())
	assert_str(text).contains("[resource]")
	assert_str(text).contains("\nmass = 7500.0\n")
	assert_str(text).contains("\nmax_angular_rate_deg = Vector3(100, 95, 160)\n")
	var occurrences: int = text.count("max_angular_rate_deg =")
	assert_int(occurrences).is_equal(1)
	assert_str(text).contains("\nbase_fov = ")


func test_snippet_values_load_back_into_a_def() -> void:
	var def: ShipDef = _def()
	def.max_speed = 201.5
	def.chase_rotation_lag = 0.31
	var lines: PackedStringArray = TuningSnippet.build(def, TuningParam.all()).split("\n")
	var restored: ShipDef = Content.ship(&"kestrel").duplicate() as ShipDef
	for line: String in lines:
		var parts: PackedStringArray = line.split(" = ", true, 1)
		if parts.size() == 2:
			restored.set(parts[0], str_to_var(parts[1]))
	assert_float(restored.max_speed).is_equal(201.5)
	assert_float(restored.chase_rotation_lag).is_equal_approx(0.31, 0.00001)
	assert_vector(restored.max_angular_rate_deg).is_equal(def.max_angular_rate_deg)


func test_save_writes_the_snippet_to_a_file_named_after_the_ship() -> void:
	var def: ShipDef = _def()
	var path: String = TuningSnippet.save(def, TuningParam.all(), DIR)
	assert_str(path).is_equal(DIR + "/kestrel.tres")
	assert_str(FileAccess.get_file_as_string(path)).is_equal(
		TuningSnippet.build(def, TuningParam.all())
	)


func test_every_parameter_has_a_label_a_group_and_a_sane_range() -> void:
	var def: ShipDef = _def()
	for param: TuningParam in TuningParam.all():
		for key: StringName in [param.label_key, param.group_key]:
			(
				assert_str(TranslationServer.translate(key))
				. override_failure_message("Missing string key %s" % key)
				. is_not_equal(str(key))
			)
		assert_float(param.step).is_greater(0.0)
		assert_float(param.max_value).is_greater(param.min_value)
		var value: float = param.read(def)
		(
			assert_bool(value >= param.min_value and value <= param.max_value)
			. override_failure_message("%s=%s outside its slider range" % [param.field, value])
			. is_true()
		)


func test_read_and_write_handle_vector_components() -> void:
	var def: ShipDef = _def()
	var yaw: TuningParam = TuningParam.new(&"max_angular_rate_deg", &"K", &"G", 0, 1, 1, 1)
	yaw.write(def, 123.0)
	assert_float(yaw.read(def)).is_equal(123.0)
	assert_vector(def.max_angular_rate_deg).is_equal(Vector3(90.0, 123.0, 150.0))


func test_parameters_cover_the_flight_and_camera_fields() -> void:
	var fields: Dictionary[String, bool] = {}
	for param: TuningParam in TuningParam.all():
		fields[param.property_name()] = true
	for field: String in [
		"mass",
		"thrust_forward",
		"max_speed",
		"max_angular_rate_deg",
		"angular_accel_deg",
		"fa_linear_gain",
		"fa_angular_gain",
		"boost_max_speed",
		"boost_energy_per_second",
		"energy_capacity",
		"chase_position_lag",
		"chase_rotation_lag",
		"base_fov",
	]:
		assert_bool(fields.has(field)).override_failure_message("no slider for " + field).is_true()
