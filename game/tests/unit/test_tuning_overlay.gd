extends GdUnitTestSuite
## The tuning overlay changes the ship's def live, and the pause menu pauses the game.

const DIR: String = "user://tuning"

var _ship: Ship
var _overlay: TuningOverlay


func before_test() -> void:
	_ship = auto_free(load("res://ships/ship.tscn").instantiate()) as Ship
	# Never edit the shared def: other suites read it.
	_ship.def = Content.ship(&"kestrel").duplicate() as ShipDef
	add_child(_ship)
	var rig: CameraRig = auto_free(load("res://ships/camera_rig.tscn").instantiate()) as CameraRig
	add_child(rig)
	_overlay = auto_free(load("res://ui/dev/tuning_overlay.tscn").instantiate()) as TuningOverlay
	add_child(_overlay)
	_overlay.bind(_ship, rig)


func after_test() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(DIR.path_join("kestrel.tres"))


func _slider_for(field: StringName, component: int = TuningParam.WHOLE) -> HSlider:
	var params: Array[TuningParam] = TuningParam.all()
	for index: int in params.size():
		if params[index].field == field and params[index].component == component:
			return _overlay._sliders[index]
	return null


func test_format_value_uses_the_decimals_of_the_step() -> void:
	assert_str(TuningOverlay.format_value(6000.0, 100.0)).is_equal("6000")
	assert_str(TuningOverlay.format_value(0.123, 0.01)).is_equal("0.12")
	assert_str(TuningOverlay.format_value(1.5, 0.5)).is_equal("1.5")


func test_there_is_a_slider_for_every_parameter_showing_the_current_value() -> void:
	assert_int(_overlay._sliders.size()).is_equal(TuningParam.all().size())
	assert_float(_slider_for(&"max_speed").value).is_equal(_ship.def.max_speed)
	assert_float(_slider_for(&"max_angular_rate_deg", 1).value).is_equal(
		_ship.def.max_angular_rate_deg.y
	)


func test_moving_a_slider_changes_the_def_at_once() -> void:
	_slider_for(&"max_speed").value = 222.0
	assert_float(_ship.def.max_speed).is_equal(222.0)
	_slider_for(&"max_angular_rate_deg", 2).value = 111.0
	assert_vector(_ship.def.max_angular_rate_deg).is_equal(Vector3(90.0, 90.0, 111.0))
	_slider_for(&"base_fov").value = 90.0
	assert_float(_ship.def.base_fov).is_equal(90.0)


func test_mass_and_capacitor_changes_reach_the_running_ship() -> void:
	_slider_for(&"mass").value = 9000.0
	assert_float(_ship.mass).is_equal(9000.0)
	_ship.power().energy = 80.0
	_slider_for(&"energy_capacity").value = 60.0
	assert_float(_ship.power().capacity).is_equal(60.0)
	assert_float(_ship.power().energy).is_equal(60.0)


func test_reset_restores_the_values_from_when_it_was_bound() -> void:
	var original_speed: float = _ship.def.max_speed
	_slider_for(&"max_speed").value = 250.0
	_slider_for(&"mass").value = 12000.0
	_overlay.reset_values()
	assert_float(_ship.def.max_speed).is_equal(original_speed)
	assert_float(_ship.mass).is_equal(Content.ship(&"kestrel").mass)
	assert_float(_slider_for(&"max_speed").value).is_equal(original_speed)


func test_copy_values_saves_the_snippet_and_reports_the_path() -> void:
	_slider_for(&"max_speed").value = 205.0
	var path: String = _overlay.copy_values()
	assert_str(path).is_equal(DIR + "/kestrel.tres")
	assert_str(FileAccess.get_file_as_string(path)).contains("max_speed = 205.0")
	assert_str(_overlay._status.text).contains("kestrel.tres")


func test_open_pauses_the_game_and_close_resumes() -> void:
	_overlay.open()
	assert_bool(_overlay.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	_overlay.toggle()
	assert_bool(_overlay.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()
