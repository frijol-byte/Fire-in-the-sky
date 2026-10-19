extends GdUnitTestSuite
## The engine glow, the trails, the dust and the sounds following a real `Ship`.

var _ship: Ship = null


func before_test() -> void:
	await get_tree().physics_frame
	_ship = FlightSim.spawn(self)


func after_test() -> void:
	remove_child(_ship)
	_ship.free()


func test_each_engine_socket_gets_a_glow_and_a_trail() -> void:
	var fx: EngineFx = _ship.get_node("EngineFx") as EngineFx
	assert_int(fx.engine_count()).is_equal(_ship.model.get_sockets(&"engine").size())
	assert_int(fx.engine_count()).is_greater(0)
	for socket: Marker3D in _ship.model.get_sockets(&"engine"):
		assert_object(socket.get_node_or_null("Glow")).is_not_null()


func test_the_trail_builds_up_behind_a_flying_ship_and_is_capped() -> void:
	var fx: EngineFx = _ship.get_node("EngineFx") as EngineFx
	_ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	await SimHelper.step_physics(get_tree(), 10)
	assert_int(fx.trail_length(0)).is_between(5, EngineFx.TRAIL_POINTS)
	await SimHelper.step_physics(get_tree(), EngineFx.TRAIL_POINTS * 2)
	assert_int(fx.trail_length(0)).is_equal(EngineFx.TRAIL_POINTS)


func test_the_engine_level_follows_throttle_and_boost() -> void:
	var fx: EngineFx = _ship.get_node("EngineFx") as EngineFx
	for _step: int in 120:
		fx.update(1.0 / 60.0)
	assert_float(fx.level()).is_equal_approx(EngineFx.IDLE_LEVEL, 0.02)
	_ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	for _step: int in 120:
		fx.update(1.0 / 60.0)
	assert_float(fx.level()).is_greater(0.95)


func test_boost_streaks_come_in_while_boosting_and_leave_after() -> void:
	var fx: SpeedFx = auto_free(SpeedFx.new())
	add_child(fx)
	fx.attach(_ship)
	var controls: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	controls.boost = true
	_ship.controls = controls
	for _tick: int in 90:
		await get_tree().physics_frame
		fx.update(SimHelper.TICK)
	assert_bool(_ship.is_boosting()).is_true()
	assert_float(fx.boost_amount()).is_greater(0.9)
	_ship.controls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	for _tick: int in 120:
		await get_tree().physics_frame
		fx.update(SimHelper.TICK)
	assert_float(fx.boost_amount()).is_less(0.05)


func test_the_flight_sounds_follow_the_ship() -> void:
	var audio: ShipAudio = auto_free(ShipAudio.new())
	add_child(audio)
	audio.attach(_ship)
	audio.update(SimHelper.TICK)
	var idle_pitch: float = (audio.get_child(0) as AudioStreamPlayer).pitch_scale
	var controls: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	controls.boost = true
	_ship.controls = controls
	for _tick: int in 120:
		await get_tree().physics_frame
		audio.update(SimHelper.TICK)
	var engine: AudioStreamPlayer = audio.get_child(0) as AudioStreamPlayer
	var hiss: AudioStreamPlayer = audio.get_child(1) as AudioStreamPlayer
	assert_float(engine.pitch_scale).is_greater(idle_pitch)
	assert_float(hiss.volume_db).is_greater(ShipAudio.SILENT_DB + 5.0)
