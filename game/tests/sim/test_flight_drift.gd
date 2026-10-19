extends GdUnitTestSuite
## Flight assist off: momentum is kept while the nose turns, thrust has a cap, and flight assist
## blends excess speed away when it comes back on.

const SECONDS: int = 60
const SHIP_IDS: Array[StringName] = [&"kestrel"]


func _spawn(ship_id: StringName) -> Ship:
	var ship: Ship = FlightSim.spawn(self, ship_id)
	auto_free(ship)
	return ship


func _drift(thrust: Vector3 = Vector3.ZERO, rotate: Vector3 = Vector3.ZERO) -> ShipControls:
	var controls: ShipControls = FlightSim.controls(thrust, rotate)
	controls.fa_off = true
	return controls


func test_drift_turn_keeps_the_velocity_while_the_nose_flips() -> void:
	for ship_id: StringName in SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var ship: Ship = _spawn(ship_id)
		var start: Vector3 = Vector3(0, 0, -def.max_speed * 0.8)
		ship.linear_velocity = start
		# Full yaw for long enough to turn well past 180 degrees.
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, _drift(Vector3.ZERO, Vector3(0, 1, 0)), 3 * SECONDS
		)
		var flipped_at: int = -1
		for sample: FlightSim.Sample in samples:
			# The velocity vector in the world must not move at all.
			assert_vector(sample.basis * sample.local_velocity).is_equal_approx(
				start, Vector3.ONE * 0.05
			)
			if flipped_at < 0 and (sample.basis * Vector3(0, 0, -1)).z > 0.99:
				flipped_at = sample.tick
		assert_int(flipped_at).is_greater(0)
		# Nose now points backward along the travel direction, yet speed is unchanged.
		assert_float(ship.linear_velocity.length()).is_equal_approx(start.length(), 0.1)


func test_idle_sticks_keep_the_speed_for_ten_seconds() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	ship.linear_velocity = Vector3(0, 0, -def.max_speed)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _drift(), 10 * SECONDS
	)
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(def.max_speed, 0.1)
	assert_float(samples[-1].position.z).is_less(-def.max_speed * 9.5)


func test_fa_off_thrust_accelerates_at_the_ships_forward_accel() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _drift(Vector3(0, 0, 1)), SECONDS
	)
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(
		def.accel_forward() * 1.0, def.accel_forward() * 0.03
	)


func test_fa_off_thrust_stops_at_the_speed_cap() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _drift(Vector3(0, 0, 1)), 8 * SECONDS
	)
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(def.max_speed, def.max_speed * 0.03)


func test_rotation_stays_assisted_with_fa_off() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _drift(Vector3.ZERO, Vector3(0, 1, 0)), SECONDS
	)
	# Yaw +1 is nose right: a negative rotation about +Y.
	assert_float(-samples[-1].local_angular.y).is_equal_approx(
		def.max_angular_rate_rad().y, def.max_angular_rate_rad().y * 0.03
	)
	# And letting go stops the turn.
	var stopped: Array[FlightSim.Sample] = await FlightSim.fly(get_tree(), ship, _drift(), SECONDS)
	assert_float(stopped[-1].local_angular.length()).is_less(0.01)


func test_turning_back_on_flight_assist_stops_a_drifting_ship() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	ship.linear_velocity = Vector3(0, 0, -def.max_speed)
	await FlightSim.fly(get_tree(), ship, _drift(), SECONDS)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(), 10 * SECONDS
	)
	var speed: PackedFloat32Array = FlightSim.speed_along(samples, 2, -1.0)
	assert_float(FlightSim.first_time_at_or_below(speed, def.max_speed * 0.01)).is_greater(0.0)


func test_excess_speed_blends_away_in_about_a_second_when_fa_returns() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	ship.linear_velocity = Vector3(0, 0, -def.boost_max_speed)
	# Hold full forward throttle with FA on: only the speed limiter acts on the excess.
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), 2 * SECONDS
	)
	var excess: float = def.boost_max_speed - def.max_speed
	var at_bleed_time: float = -(
		samples[roundi(def.fa_excess_bleed_time * 60.0) - 1].local_velocity.z
	)
	assert_float(at_bleed_time - def.max_speed).is_less_equal(excess * 0.07)
	# Smooth: the speed never rises and never steps by more than a tenth of the excess per tick.
	var previous: float = def.boost_max_speed
	for sample: FlightSim.Sample in samples:
		var speed: float = -sample.local_velocity.z
		assert_float(speed).is_less_equal(previous + 0.01)
		assert_float(previous - speed).is_less(excess * 0.1)
		previous = speed
	assert_float(previous).is_equal_approx(def.max_speed, def.max_speed * 0.03)
