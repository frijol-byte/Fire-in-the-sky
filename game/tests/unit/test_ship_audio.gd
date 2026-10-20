extends GdUnitTestSuite
## `ShipAudio`: how the engine hum and the hiss follow the ship, and how the sounds are imported.


func test_engine_pitch_rises_with_power_and_speed() -> void:
	assert_float(ShipAudio.engine_pitch(1.0, 0.0)).is_greater(ShipAudio.engine_pitch(0.0, 0.0))
	assert_float(ShipAudio.engine_pitch(0.5, 1.0)).is_greater(ShipAudio.engine_pitch(0.5, 0.0))
	assert_float(ShipAudio.engine_pitch(-3.0, 0.0)).is_equal(ShipAudio.PITCH_IDLE)


func test_engine_is_louder_at_full_power_and_when_boosting() -> void:
	assert_float(ShipAudio.engine_volume_db(1.0, false)).is_greater(
		ShipAudio.engine_volume_db(0.0, false)
	)
	assert_float(ShipAudio.engine_volume_db(1.0, true)).is_greater(
		ShipAudio.engine_volume_db(1.0, false)
	)


func test_hiss_is_silent_at_rest_and_grows_with_speed() -> void:
	assert_float(ShipAudio.hiss_volume_db(0.0)).is_equal(ShipAudio.SILENT_DB)
	assert_float(ShipAudio.hiss_volume_db(1.0)).is_equal(ShipAudio.HISS_DB_TOP)
	assert_float(ShipAudio.hiss_volume_db(0.7)).is_greater(ShipAudio.hiss_volume_db(0.4))
	assert_float(ShipAudio.hiss_volume_db(9.0)).is_equal(ShipAudio.HISS_DB_TOP)


func test_speed_fraction_is_clamped() -> void:
	assert_float(ShipAudio.speed_fraction(160.0, 320.0)).is_equal(0.5)
	assert_float(ShipAudio.speed_fraction(900.0, 320.0)).is_equal(1.0)
	assert_float(ShipAudio.speed_fraction(10.0, 0.0)).is_equal(1.0)


func test_the_hum_and_the_hiss_loop_and_the_whoosh_does_not() -> void:
	assert_int(ShipAudio.ENGINE_STREAM.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(ShipAudio.HISS_STREAM.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_int(ShipAudio.WHOOSH_STREAM.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)
	# The loop runs over the whole sound (to its last frame).
	var frames: int = ShipAudio.ENGINE_STREAM.data.size() / 2
	assert_int(ShipAudio.ENGINE_STREAM.loop_begin).is_equal(0)
	assert_int(ShipAudio.ENGINE_STREAM.loop_end).is_equal(frames - 1)


func test_the_three_sounds_exist_and_are_16_bit_mono() -> void:
	for stream: AudioStreamWAV in [
		ShipAudio.ENGINE_STREAM, ShipAudio.HISS_STREAM, ShipAudio.WHOOSH_STREAM
	]:
		assert_int(stream.format).is_equal(AudioStreamWAV.FORMAT_16_BITS)
		assert_bool(stream.stereo).is_false()
		assert_float(stream.get_length()).is_greater(0.5)
