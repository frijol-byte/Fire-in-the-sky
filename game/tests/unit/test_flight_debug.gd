extends GdUnitTestSuite
## The flight debug scene's readout lines.


func test_power_text_shows_energy_and_states() -> void:
	var text: String = FlightDebug.power_text(42.0, 100.0, true, true)
	assert_str(text).contains("42 / 100")
	assert_str(text).contains("FA OFF")
	assert_str(text).contains("BOOST")


func test_power_text_flight_assist_on_without_boost() -> void:
	var text: String = FlightDebug.power_text(100.0, 100.0, false, false)
	assert_str(text).contains("FA ON")
	assert_str(text).not_contains("BOOST")
