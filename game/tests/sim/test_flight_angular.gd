extends GdUnitTestSuite
## Flight assist on: turning. Full stick reaches the max turn rate, the nose points the
## right way, and releasing the stick stops the rotation without overshoot.

const SECONDS: int = 60
## Axis index, name, and the rotation sign the stick convention maps to a local axis.
const AXES: Array[Dictionary] = [
	{"axis": 0, "name": "pitch", "sign": 1.0},
	{"axis": 1, "name": "yaw", "sign": -1.0},
	{"axis": 2, "name": "roll", "sign": -1.0},
]


func _spawn() -> Ship:
	var ship: Ship = FlightSim.spawn(self)
	auto_free(ship)
	return ship


func _full_stick(axis: int, amount: float) -> ShipControls:
	var rotate: Vector3 = Vector3.ZERO
	rotate[axis] = amount
	return FlightSim.controls(Vector3.ZERO, rotate)


func test_turn_rate_matches_the_max_on_every_axis() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var rates: Vector3 = def.max_angular_rate_rad()
	for entry: Dictionary in AXES:
		var axis: int = entry["axis"]
		var ship: Ship = _spawn()
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, _full_stick(axis, 1.0), 2 * SECONDS
		)
		var rate: float = samples[-1].local_angular[axis] * (entry["sign"] as float)
		assert_float(rate).is_equal_approx(rates[axis], rates[axis] * 0.03)
		ship.queue_free()
		await get_tree().physics_frame


func test_full_deflection_does_not_exceed_the_max_rate_by_5_percent() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var rates: Vector3 = def.max_angular_rate_rad()
	for entry: Dictionary in AXES:
		var axis: int = entry["axis"]
		var ship: Ship = _spawn()
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, _full_stick(axis, 1.0), 2 * SECONDS
		)
		var highest: float = 0.0
		for value: float in FlightSim.rate_along(samples, axis, entry["sign"] as float):
			highest = maxf(highest, value)
		assert_float(highest).is_less_equal(rates[axis] * 1.05)
		ship.queue_free()
		await get_tree().physics_frame


func test_stick_directions_point_the_nose_the_right_way() -> void:
	# +pitch is nose up, +yaw is nose right, +roll is right wing down.
	var up: Ship = _spawn()
	await FlightSim.fly(get_tree(), up, _full_stick(0, 1.0), 20)
	assert_float((-up.global_basis.z).y).is_greater(0.1)
	up.queue_free()
	await get_tree().physics_frame

	var right: Ship = _spawn()
	await FlightSim.fly(get_tree(), right, _full_stick(1, 1.0), 20)
	assert_float((-right.global_basis.z).x).is_greater(0.1)
	right.queue_free()
	await get_tree().physics_frame

	var roll: Ship = _spawn()
	await FlightSim.fly(get_tree(), roll, _full_stick(2, 1.0), 20)
	assert_float((roll.global_basis.x).y).is_less(-0.1)


func test_rotation_stops_when_the_stick_is_released_without_overshoot() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var rates: Vector3 = def.max_angular_rate_rad()
	for entry: Dictionary in AXES:
		var axis: int = entry["axis"]
		var ship: Ship = _spawn()
		await FlightSim.fly(get_tree(), ship, _full_stick(axis, 1.0), SECONDS)
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, FlightSim.controls(), SECONDS
		)
		var lowest: float = INF
		for value: float in FlightSim.rate_along(samples, axis, entry["sign"] as float):
			lowest = minf(lowest, value)
		assert_float(lowest).is_greater(-rates[axis] * 0.05)
		assert_float(absf(samples[-1].local_angular[axis])).is_less(rates[axis] * 0.01)
		ship.queue_free()
		await get_tree().physics_frame


func test_a_full_second_of_yaw_turns_close_to_the_max_rate_in_degrees() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn()
	# Spin up for a second, then measure the heading change over the next second.
	await FlightSim.fly(get_tree(), ship, _full_stick(1, 1.0), SECONDS)
	var before: Vector3 = -ship.global_basis.z
	await FlightSim.fly(get_tree(), ship, _full_stick(1, 1.0), SECONDS)
	var turned: float = rad_to_deg(before.angle_to(-ship.global_basis.z))
	assert_float(turned).is_equal_approx(
		def.max_angular_rate_deg.y, def.max_angular_rate_deg.y * 0.03
	)
