extends GdUnitTestSuite
## `CommsStrip`: lines come in, the oldest drops off when the strip is full, and they run out.

const HUD_SCENE: PackedScene = preload("res://ui/hud/flight_hud.tscn")


func _strip() -> CommsStrip:
	var hud: FlightHud = auto_free(HUD_SCENE.instantiate()) as FlightHud
	add_child(hud)
	return hud.comms()


func test_a_pushed_line_shows_the_speaker_and_the_words() -> void:
	var strip: CommsStrip = _strip()
	strip.push("Ashjaw", "Breaking left!")
	assert_int(strip.line_count()).is_equal(1)
	assert_str(strip.line_text(0)).is_equal("Ashjaw: Breaking left!")


func test_the_oldest_line_drops_off_a_full_strip() -> void:
	var strip: CommsStrip = _strip()
	var lines: int = Content.barks().strip_lines
	for index: int in lines + 2:
		strip.push("P", "line %d" % index)
	assert_int(strip.line_count()).is_equal(lines)
	assert_str(strip.line_text(0)).is_equal("P: line 2")


func test_lines_run_out_after_their_time() -> void:
	var strip: CommsStrip = _strip()
	var seconds: float = Content.barks().line_seconds
	strip.push("A", "one")
	strip.advance(seconds * 0.6)
	strip.push("B", "two")
	strip.advance(seconds * 0.5)
	assert_int(strip.line_count()).is_equal(1)
	assert_str(strip.line_text(0)).is_equal("B: two")
	strip.advance(seconds)
	assert_int(strip.line_count()).is_equal(0)


func test_a_line_fades_over_its_last_second() -> void:
	assert_float(CommsStrip.line_alpha(0.0, 5.0)).is_equal(1.0)
	assert_float(CommsStrip.line_alpha(3.9, 5.0)).is_equal(1.0)
	assert_float(CommsStrip.line_alpha(4.5, 5.0)).is_equal_approx(0.5, 0.0001)
	assert_float(CommsStrip.line_alpha(5.0, 5.0)).is_equal(0.0)
