extends GdUnitTestSuite
## The same inputs must give the same flight, tick for tick, so sims and replays can be trusted.

const TICKS: int = 240


func _run() -> Array[FlightSim.Sample]:
	var ship: Ship = FlightSim.spawn(self)
	var samples: Array[FlightSim.Sample] = []
	# A maneuver that touches every axis: accelerate and turn, then reverse and roll.
	var script: Array[ShipControls] = [
		FlightSim.controls(Vector3(0.3, 0.2, 1.0), Vector3(0.5, 0.8, 0.0)),
		FlightSim.controls(Vector3(-0.4, -0.1, -0.5), Vector3(-0.2, -0.6, 1.0)),
	]
	for tick: int in TICKS:
		ship.controls = script[tick / 120]
		await get_tree().physics_frame
		samples.append(FlightSim.snapshot(ship, tick + 1))
	remove_child(ship)
	ship.free()
	return samples


func test_same_inputs_give_identical_flights() -> void:
	# The first physics frame of a suite is not a full tick for a freshly added body, which would
	# shift the first run by one tick. Let it pass before recording anything.
	await get_tree().physics_frame
	var first: Array[FlightSim.Sample] = await _run()
	var second: Array[FlightSim.Sample] = await _run()
	assert_int(second.size()).is_equal(first.size())
	for index: int in first.size():
		assert_vector(second[index].position).is_equal(first[index].position)
		assert_vector(second[index].local_velocity).is_equal(first[index].local_velocity)
		assert_vector(second[index].local_angular).is_equal(first[index].local_angular)
	# And the maneuver did something.
	assert_float(first[-1].position.length()).is_greater(100.0)
