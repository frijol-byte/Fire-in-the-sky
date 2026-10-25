extends GdUnitTestSuite
## Flight assist on: how quickly the side and up/down thrusters respond (M1-F1). Full strafe or
## full vertical thrust must reach 90% of its speed limit within `ShipDef.strafe_response_time`,
## and letting go must stop the ship again (to 10% of the limit) within the same time, without
## swinging past zero.

## Reached means this fraction of the speed limit; stopped means this fraction or less.
const REACHED: float = 0.9
const STOPPED: float = 0.1
const SECONDS: int = 60
## Axis index in local velocity, and the stick that commands it.
const AXES: Dictionary[StringName, int] = {&"strafe": 0, &"vertical": 1}


## Every test runs once per ship and per axis.
func axis_params() -> Array[Array]:
	var result: Array[Array] = []
	for ship_id: StringName in FlightSim.SHIP_IDS:
		for axis_name: StringName in AXES:
			result.append([ship_id, axis_name])
	return result


func _spawn(ship_id: StringName) -> Ship:
	var ship: Ship = FlightSim.spawn(self, ship_id)
	auto_free(ship)
	return ship


func _limit(def: ShipDef, axis_name: StringName) -> float:
	return def.max_strafe_speed if axis_name == &"strafe" else def.max_vertical_speed


func _stick(axis_name: StringName, value: float) -> ShipControls:
	var thrust: Vector3 = Vector3.ZERO
	thrust[AXES[axis_name]] = value
	return FlightSim.controls(thrust)


func test_full_thrust_reaches_90_percent_within_the_response_time(
	ship_id: StringName, axis_name: StringName, _test_parameters := axis_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	var ship: Ship = _spawn(ship_id)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _stick(axis_name, 1.0), 4 * SECONDS
	)
	var speed: PackedFloat32Array = FlightSim.speed_along(samples, AXES[axis_name])
	var took: float = FlightSim.first_time_at_or_above(speed, _limit(def, axis_name) * REACHED)
	assert_float(took).is_greater(0.0)
	assert_float(took).is_less_equal(def.strafe_response_time)


func test_the_other_axes_stay_quiet_while_strafing(
	ship_id: StringName, axis_name: StringName, _test_parameters := axis_params()
) -> void:
	var ship: Ship = _spawn(ship_id)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _stick(axis_name, 1.0), 2 * SECONDS
	)
	for axis: int in 3:
		if axis != AXES[axis_name]:
			assert_float(samples[-1].local_velocity[axis]).is_equal_approx(0.0, 0.01)


func test_releasing_the_stick_stops_within_the_response_time_without_overshoot(
	ship_id: StringName, axis_name: StringName, _test_parameters := axis_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	var limit: float = _limit(def, axis_name)
	var ship: Ship = _spawn(ship_id)
	var direction: Vector3 = Vector3.ZERO
	direction[AXES[axis_name]] = limit
	ship.linear_velocity = ship.global_basis * direction
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, FlightSim.controls(), 4 * SECONDS
	)
	var speed: PackedFloat32Array = FlightSim.speed_along(samples, AXES[axis_name])
	var took: float = FlightSim.first_time_at_or_below(speed, limit * STOPPED)
	assert_float(took).is_greater(0.0)
	assert_float(took).is_less_equal(def.strafe_response_time)
	var lowest: float = INF
	for value: float in speed:
		lowest = minf(lowest, value)
	# No swing to the other side: at most a rounding error below zero.
	assert_float(lowest).is_greater(-limit * 0.01)


func test_reversing_the_stick_never_overshoots_the_other_limit(
	ship_id: StringName, axis_name: StringName, _test_parameters := axis_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	var limit: float = _limit(def, axis_name)
	var ship: Ship = _spawn(ship_id)
	await FlightSim.fly(get_tree(), ship, _stick(axis_name, 1.0), 2 * SECONDS)
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(
		get_tree(), ship, _stick(axis_name, -1.0), 4 * SECONDS
	)
	var speed: PackedFloat32Array = FlightSim.speed_along(samples, AXES[axis_name])
	var lowest: float = INF
	for value: float in speed:
		lowest = minf(lowest, value)
	assert_float(lowest).is_greater_equal(-limit * 1.03)
	assert_float(speed[-1]).is_equal_approx(-limit, limit * 0.03)


func test_the_three_classes_stay_distinct() -> void:
	var kestrel: ShipDef = Content.ship(&"kestrel")
	var bulwark: ShipDef = Content.ship(&"bulwark")
	var drayman: ShipDef = Content.ship(&"drayman")
	assert_float(kestrel.strafe_response_time).is_less(bulwark.strafe_response_time)
	assert_float(bulwark.strafe_response_time).is_less(drayman.strafe_response_time)
	# Freighter slowest in raw lateral acceleration, too.
	assert_float(kestrel.accel_lateral()).is_greater(bulwark.accel_lateral())
	assert_float(bulwark.accel_lateral()).is_greater(drayman.accel_lateral())
