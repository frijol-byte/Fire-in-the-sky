extends GdUnitTestSuite
## The minimal pause menu: opening pauses the game, closing resumes it.

var _menu: PauseMenu


func before_test() -> void:
	_menu = auto_free(load("res://ui/pause/pause_menu.tscn").instantiate()) as PauseMenu
	add_child(_menu)


func after_test() -> void:
	get_tree().paused = false


func test_open_pauses_and_focuses_resume() -> void:
	_menu.open()
	assert_bool(_menu.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool((_menu.get_node("Panel/Center/Column/Resume") as Button).has_focus()).is_true()


func test_resume_button_closes_it() -> void:
	_menu.open()
	(_menu.get_node("Panel/Center/Column/Resume") as Button).pressed.emit()
	assert_bool(_menu.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_pause_action_toggles_it() -> void:
	var press: InputEventAction = InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	_menu._unhandled_input(press)
	assert_bool(_menu.is_open()).is_true()
	_menu._unhandled_input(press)
	assert_bool(_menu.is_open()).is_false()


func test_pause_is_ignored_while_something_else_has_paused_the_game() -> void:
	get_tree().paused = true
	var press: InputEventAction = InputEventAction.new()
	press.action = &"pause"
	press.pressed = true
	_menu._unhandled_input(press)
	assert_bool(_menu.is_open()).is_false()
