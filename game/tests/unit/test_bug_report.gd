extends GdUnitTestSuite
## `BugReport`: the folder it writes (screenshot, log, state dump) and the JSON-safe state.

const ROOT: String = "user://test_bug_reports"


func after_test() -> void:
	_remove_dir(ROOT)


func _remove_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub: String in DirAccess.get_directories_at(path):
		_remove_dir(path.path_join(sub))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _spawn_ship() -> Ship:
	var ship: Ship = auto_free(load("res://ships/ship.tscn").instantiate()) as Ship
	ship.def = Content.ship(&"kestrel")
	add_child(ship)
	return ship


func test_write_creates_screenshot_log_and_state_files() -> void:
	var image: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var folder: String = BugReport.write(
		ROOT, {"scene": "res://x.tscn"}, PackedStringArray(["one", "two"]), image
	)
	assert_str(folder).starts_with(ROOT)
	assert_bool(FileAccess.file_exists(folder.path_join(BugReport.SCREENSHOT_FILE))).is_true()
	var log_text: String = FileAccess.get_file_as_string(folder.path_join(BugReport.LOG_FILE))
	assert_str(log_text).is_equal("one\ntwo\n")
	var state: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(folder.path_join(BugReport.STATE_FILE))
	)
	assert_str((state as Dictionary)["scene"]).is_equal("res://x.tscn")


func test_write_without_an_image_skips_the_screenshot() -> void:
	var folder: String = BugReport.write(ROOT, {}, PackedStringArray(), null)
	assert_bool(FileAccess.file_exists(folder.path_join(BugReport.SCREENSHOT_FILE))).is_false()
	assert_bool(FileAccess.file_exists(folder.path_join(BugReport.STATE_FILE))).is_true()


func test_two_reports_in_the_same_second_get_separate_folders() -> void:
	var first: String = BugReport.write(ROOT, {}, PackedStringArray(), null)
	var second: String = BugReport.write(ROOT, {}, PackedStringArray(), null)
	assert_str(second).is_not_equal(first)
	assert_bool(DirAccess.dir_exists_absolute(first)).is_true()
	assert_bool(DirAccess.dir_exists_absolute(second)).is_true()


func test_timestamp_name_is_safe_for_folders() -> void:
	assert_str(BugReport.timestamp_name("2026-10-19T14:03:22")).is_equal("2026-10-19_14-03-22")


func test_json_safe_converts_vectors_and_nested_values() -> void:
	var safe: Variant = BugReport.json_safe(
		{
			&"pos": Vector3(1, 2, 3),
			"list": [Vector2(4, 5), &"name"],
			"flag": true,
			"color": Color.RED
		}
	)
	var dict: Dictionary = safe
	assert_array(dict["pos"]).is_equal([1.0, 2.0, 3.0])
	assert_array(dict["list"]).is_equal([[4.0, 5.0], "name"])
	assert_bool(dict["flag"]).is_true()
	assert_str(dict["color"]).is_equal(var_to_str(Color.RED))
	# It must survive JSON.
	assert_object(JSON.parse_string(JSON.stringify(safe))).is_not_null()


func test_ship_state_describes_the_ship() -> void:
	var ship: Ship = _spawn_ship()
	ship.linear_velocity = Vector3(0, 0, -50)
	var state: Dictionary = BugReport.ship_state(ship)
	assert_str(state["id"]).is_equal("kestrel")
	assert_float(state["speed"]).is_equal_approx(50.0, 0.01)
	assert_array(state["velocity"]).has_size(3)
	assert_float(state["energy"]).is_equal(ship.def.energy_capacity)
	assert_bool(state["boosting"]).is_false()
	assert_float(state["shield"]).is_equal(ship.def.shield_capacity)
	assert_float(state["armor"]).is_equal(ship.def.armor_capacity)
	assert_float(state["hull"]).is_equal(ship.def.hull_capacity)
	assert_bool(state["devices_disabled"]).is_false()


func test_ship_state_is_empty_without_a_ship() -> void:
	assert_dict(BugReport.ship_state(null)).is_empty()


func test_state_dict_has_scene_ship_and_settings() -> void:
	var ship: Ship = _spawn_ship()
	var state: Dictionary = BugReport.state_dict(
		"res://core/debug/flight_debug.tscn",
		ship,
		{"camera/free_look": true, "controls/invert_y": false},
		InputRouter.Device.GAMEPAD
	)
	assert_str(state["scene"]).is_equal("res://core/debug/flight_debug.tscn")
	assert_str(state["input_device"]).is_equal("GAMEPAD")
	assert_bool((state["settings"] as Dictionary)["camera/free_look"]).is_true()
	assert_dict(state["ship"]).is_not_empty()
	for key: String in ["time", "version", "engine", "renderer"]:
		assert_bool(state.has(key)).is_true()


func test_capture_writes_a_report_for_the_running_game() -> void:
	var ship: Ship = _spawn_ship()
	Log.info(&"test", "bug capture probe line")
	var folder: String = BugReport.capture(get_tree(), ship, ROOT)
	assert_str(folder).starts_with(ROOT)
	var log_text: String = FileAccess.get_file_as_string(folder.path_join(BugReport.LOG_FILE))
	assert_str(log_text).contains("bug capture probe line")
	var state: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(folder.path_join(BugReport.STATE_FILE))
	)
	assert_str((state["ship"] as Dictionary)["id"]).is_equal("kestrel")
