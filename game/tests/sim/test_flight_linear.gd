extends GdUnitTestSuite
## Flight assist on: straight-line response. Full stick reaches top speed, releasing it stops
## the ship in the time its thrust allows, and the response never overshoots.

const SECONDS: int = 60
const SHIP_IDS: Array[StringName] = [&"kestrel"]


func _spawn(ship_id: StringName) -> Ship:
	var ship: Ship = FlightSim.spawn(self, ship_id)
	auto_free(ship)
	return ship


func test_full_throttle_reaches_top_speed_within_3_percent() -> void:
	for ship_id: StringName in SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var ship: Ship = _spawn(ship_id)
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), 8 * SECONDS
		)
		var forward: PackedFloat32Array = FlightSim.speed_along(samples, 2, -1.0)
		assert_float(forward[-1]).is_equal_approx(def.max_speed, def.max_speed * 0.03)
		# Straight ahead: nothing leaks into the other axes.
		assert_float(samples[-1].local_velocity.x).is_equal_approx(0.0, 0.5)
		assert_float(samples[-1].local_velocity.y).is_equal_approx(0.0, 0.5)


func test_acceleration_time_matches_thrust_over_mass() -> void:
	for ship_id: StringName in SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var ship: Ship = _spawn(ship_id)
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), 8 * SECONDS
		)
		var forward: PackedFloat32Array = FlightSim.speed_along(samples, 2, -1.0)
		# Thrust limited at first, so 97% of top speed arrives about v / a seconds in.
		var expected: float = def.max_speed * 0.97 / def.accel_forward()
		var took: float = FlightSim.first_time_at_or_above(forward, def.max_speed * 0.97)
		assert_float(took).is_equal_approx(expected, expected * 0.1)


func test_stops_from_top_speed_in_the_time_reverse_thrust_allows() -> void:
	for ship_id: StringName in SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var ship: Ship = _spawn(ship_id)
		ship.linear_velocity = Vector3(0, 0, -def.max_speed)
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, FlightSim.controls(), 10 * SECONDS
		)
		var forward: PackedFloat32Array = FlightSim.speed_along(samples, 2, -1.0)
		var expected: float = def.max_speed / def.accel_reverse()
		# "Stopped" is under 1% of top speed.
		var took: float = FlightSim.first_time_at_or_below(forward, def.max_speed * 0.01)
		assert_float(took).is_equal_approx(expected, expected * 0.1)


func test_stopping_never_reverses_the_ship() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	ship.linear_velocity = Vector3(0, 0, -def.max_speed)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(), 10 * SECONDS
	)
	var lowest: float = INF
	for value: float in FlightSim.speed_along(samples, 2, -1.0):
		lowest = minf(lowest, value)
	# Overshoot below 5% of the speed it started at.
	assert_float(lowest).is_greater(-def.max_speed * 0.05)


func test_speed_never_exceeds_the_command_while_accelerating() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), 8 * SECONDS
	)
	var highest: float = 0.0
	for value: float in FlightSim.speed_along(samples, 2, -1.0):
		highest = maxf(highest, value)
	assert_float(highest).is_less_equal(def.max_speed * 1.05)


func test_half_throttle_holds_half_speed() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(0, 0, 0.5)), 8 * SECONDS
	)
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(def.max_speed * 0.5, 2.0)


func test_strafe_and_vertical_reach_their_own_limits() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(1, 1, 0)), 8 * SECONDS
	)
	assert_float(samples[-1].local_velocity.x).is_equal_approx(
		def.max_strafe_speed, def.max_strafe_speed * 0.03
	)
	assert_float(samples[-1].local_velocity.y).is_equal_approx(
		def.max_vertical_speed, def.max_vertical_speed * 0.03
	)


func test_reverse_has_its_own_limit() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(0, 0, -1)), 8 * SECONDS
	)
	assert_float(samples[-1].local_velocity.z).is_equal_approx(
		def.max_reverse_speed, def.max_reverse_speed * 0.03
	)


func test_diagonal_command_is_limited_to_top_speed() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(1, 1, 1)), 8 * SECONDS
	)
	assert_float(samples[-1].local_velocity.length()).is_less_equal(def.max_speed * 1.03)


func test_velocity_is_followed_in_the_ships_own_axes_after_turning() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	ship.rotation = Vector3(0, deg_to_rad(90.0), 0)  # nose now points toward -X
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), 8 * SECONDS
	)
	assert_float(samples[-1].local_velocity.z).is_equal_approx(-def.max_speed, def.max_speed * 0.03)
	assert_float(ship.linear_velocity.x).is_less(-def.max_speed * 0.97)
