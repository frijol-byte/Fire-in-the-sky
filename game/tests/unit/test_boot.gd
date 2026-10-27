extends GdUnitTestSuite
## `Boot.read_version()` falls back to "dev" when `res://version.txt` is absent or empty, and the
## title screen's buttons lead to the two arenas (A: combat test, Y: flight test).

const BootScript: GDScript = preload("res://core/boot/boot.gd")


func test_read_version_returns_non_empty_string() -> void:
	assert_str(BootScript.read_version()).is_not_empty()


func test_read_version_defaults_to_dev_without_version_file() -> void:
	# version.txt is only written by CI exports, so a checkout has none.
	if FileAccess.file_exists(BootScript.VERSION_PATH):
		return
	assert_str(BootScript.read_version()).is_equal(BootScript.DEV_VERSION)


func test_next_tier_steps_through_all_tiers_and_wraps() -> void:
	var seen: Array[int] = []
	var tier: int = 0
	for step: int in ShipModel.MAX_TIER + 2:
		seen.append(tier)
		tier = BootScript.next_tier(tier)
	assert_array(seen).is_equal([0, 1, 2, 3, 0])


func test_every_tier_has_a_translated_name() -> void:
	for tier: int in ShipModel.MAX_TIER + 1:
		var key: StringName = BootScript.tier_name_key(tier)
		assert_str(tr(key)).override_failure_message("missing key %s" % key).is_not_equal(key)
	assert_that(BootScript.tier_name_key(99)).is_equal(BootScript.tier_name_key(3))


func test_a_button_leads_to_the_combat_test() -> void:
	assert_str(BootScript.destination_for(_pad_press(JOY_BUTTON_A))).is_equal(
		Game.COMBAT_TEST_SCENE
	)


func test_y_button_leads_to_the_flight_test() -> void:
	assert_str(BootScript.destination_for(_pad_press(JOY_BUTTON_Y))).is_equal(
		Game.FLIGHT_TEST_SCENE
	)


func test_other_buttons_and_releases_lead_nowhere() -> void:
	assert_str(BootScript.destination_for(_pad_press(JOY_BUTTON_B))).is_empty()
	var release: InputEventJoypadButton = _pad_press(JOY_BUTTON_A)
	release.pressed = false
	assert_str(BootScript.destination_for(release)).is_empty()


func test_both_arena_scenes_exist() -> void:
	assert_bool(ResourceLoader.exists(Game.COMBAT_TEST_SCENE)).is_true()
	assert_bool(ResourceLoader.exists(Game.FLIGHT_TEST_SCENE)).is_true()


func _pad_press(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event
