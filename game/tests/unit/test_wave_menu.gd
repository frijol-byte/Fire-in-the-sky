extends GdUnitTestSuite
## `WaveMenu`: one button per wave, choosing one closes the menu and says which, and the menu
## pauses the game while it is open.

const SCENE: PackedScene = preload("res://ui/dev/wave_menu.tscn")


func after_test() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _menu() -> WaveMenu:
	var menu: WaveMenu = auto_free(SCENE.instantiate()) as WaveMenu
	add_child(menu)
	menu.setup(PackedInt32Array([1, 2, 3]), false)
	return menu


func test_it_has_a_button_per_wave_with_the_pirate_count() -> void:
	var menu: WaveMenu = _menu()
	assert_int(menu.wave_button_count()).is_equal(3)
	var column: Node = menu.get_node("Panel/Center/Column/Waves")
	assert_str((column.get_child(0) as Button).text).is_equal("Wave 1 (1 pirate(s))")
	assert_str((column.get_child(2) as Button).text).is_equal("Wave 3 (3 pirate(s))")


func test_setting_up_again_replaces_the_buttons() -> void:
	var menu: WaveMenu = _menu()
	menu.setup(PackedInt32Array([4]), true)
	await get_tree().process_frame
	assert_int(menu.wave_button_count()).is_equal(1)
	assert_int(menu.get_node("Panel/Center/Column/Waves").get_child_count()).is_equal(1)
	(
		assert_bool((menu.get_node("Panel/Center/Column/Slowmo") as CheckButton).button_pressed)
		. is_true()
	)


func test_opening_pauses_the_game_and_closing_resumes_it() -> void:
	var menu: WaveMenu = _menu()
	assert_bool(menu.is_open()).is_false()
	menu.open()
	assert_bool(menu.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	menu.close()
	assert_bool(menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_toggling_opens_and_closes() -> void:
	var menu: WaveMenu = _menu()
	menu.toggle()
	assert_bool(menu.is_open()).is_true()
	menu.toggle()
	assert_bool(menu.is_open()).is_false()


func test_it_does_not_open_over_the_pause_menu() -> void:
	var menu: WaveMenu = _menu()
	get_tree().paused = true
	menu.toggle()
	assert_bool(menu.is_open()).is_false()


func test_choosing_a_wave_closes_the_menu_and_reports_it() -> void:
	var menu: WaveMenu = _menu()
	var chosen: Array[int] = []
	menu.wave_chosen.connect(func(index: int) -> void: chosen.append(index))
	menu.open()
	menu.choose_wave(2)
	assert_array(chosen).contains_exactly([2])
	assert_bool(menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_the_other_buttons_report_and_close() -> void:
	var menu: WaveMenu = _menu()
	var seen: Array[String] = []
	menu.restart_requested.connect(func() -> void: seen.append("restart"))
	menu.next_requested.connect(func() -> void: seen.append("next"))
	menu.clear_requested.connect(func() -> void: seen.append("clear"))
	menu.slowmo_changed.connect(func(on: bool) -> void: seen.append("slowmo %s" % on))
	for name: String in ["Restart", "Next", "Clear"]:
		menu.open()
		(menu.get_node("Panel/Center/Column/" + name) as Button).pressed.emit()
		assert_bool(menu.is_open()).is_false()
	(menu.get_node("Panel/Center/Column/Slowmo") as CheckButton).button_pressed = true
	assert_array(seen).contains_exactly(["restart", "next", "clear", "slowmo true"])
