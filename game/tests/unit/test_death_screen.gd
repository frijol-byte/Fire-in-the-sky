extends GdUnitTestSuite
## `DeathScreen`: it comes up after its delay, ignores the button for a moment and then asks for
## a respawn exactly once.

const SCENE: PackedScene = preload("res://ui/death/death_screen.tscn")


func _screen() -> DeathScreen:
	var screen: DeathScreen = auto_free(SCENE.instantiate()) as DeathScreen
	add_child(screen)
	return screen


func test_it_is_hidden_until_armed() -> void:
	var screen: DeathScreen = _screen()
	assert_bool(screen.is_open()).is_false()
	assert_bool(screen.is_pending()).is_false()


func test_it_comes_up_after_the_delay() -> void:
	var screen: DeathScreen = _screen()
	screen.arm(2.0, 1.0, "cause")
	assert_bool(screen.is_pending()).is_true()
	screen.advance(1.9)
	assert_bool(screen.is_open()).is_false()
	screen.advance(0.2)
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.is_pending()).is_false()
	assert_str((screen.get_node("Panel/Center/Column/Cause") as Label).text).is_equal("cause")
	screen.close()


func test_the_button_ignores_presses_until_the_input_delay_is_over() -> void:
	var screen: DeathScreen = _screen()
	var requests: Array = []
	screen.respawn_requested.connect(func() -> void: requests.append(true))
	screen.arm(0.5, 1.0, "")
	screen.advance(0.6)
	assert_bool(screen.accepts_input()).is_false()
	screen.request_respawn()
	assert_array(requests).is_empty()
	assert_bool(screen.is_open()).is_true()
	screen.advance(1.1)
	assert_bool(screen.accepts_input()).is_true()
	screen.request_respawn()
	assert_array(requests).has_size(1)
	assert_bool(screen.is_open()).is_false()


func test_a_respawn_is_requested_only_once() -> void:
	var screen: DeathScreen = _screen()
	var requests: Array = []
	screen.respawn_requested.connect(func() -> void: requests.append(true))
	screen.arm(0.0, 0.0, "")
	assert_bool(screen.is_open()).is_true()
	screen.request_respawn()
	screen.request_respawn()
	assert_array(requests).has_size(1)


func test_nothing_happens_before_the_screen_is_up() -> void:
	var screen: DeathScreen = _screen()
	var requests: Array = []
	screen.respawn_requested.connect(func() -> void: requests.append(true))
	screen.request_respawn()
	screen.arm(5.0, 0.0, "")
	screen.request_respawn()
	assert_array(requests).is_empty()
	screen.close()


func test_closing_cancels_a_pending_screen() -> void:
	var screen: DeathScreen = _screen()
	screen.arm(2.0, 0.0, "")
	screen.close()
	screen.advance(5.0)
	assert_bool(screen.is_open()).is_false()


func test_the_button_goes_with_the_screen() -> void:
	var screen: DeathScreen = _screen()
	var button: Button = screen.get_node("Panel/Center/Column/Respawn") as Button
	screen.arm(0.0, 1.0, "")
	assert_bool(button.disabled).is_true()
	screen.advance(1.1)
	assert_bool(button.disabled).is_false()
	screen.close()


func test_the_cause_names_the_killer_or_the_hull_breach() -> void:
	var screen: DeathScreen = _screen()
	assert_str(screen.cause_text(null)).is_equal(tr("DEATH_NO_KILLER"))
	var ship: Ship = auto_free(FlightSim.spawn(self, &"drayman"))
	assert_str(screen.cause_text(ship)).contains(tr(ship.def.display_name_key))
	assert_str(screen.cause_text(ship)).is_not_equal(tr("DEATH_NO_KILLER"))
