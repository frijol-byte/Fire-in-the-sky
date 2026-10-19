extends GdUnitTestSuite
## Boost: a higher top speed and thrust while held and powered, an energy drain at the defined
## rate, and a clean stop (with a signal) when the capacitor runs dry.

const SECONDS: int = 60
const SHIP_IDS: Array[StringName] = [&"kestrel"]

var _depleted: int = 0


func _spawn(ship_id: StringName) -> Ship:
	var ship: Ship = FlightSim.spawn(self, ship_id)
	auto_free(ship)
	return ship


func _boost(thrust: Vector3 = Vector3(0, 0, 1)) -> ShipControls:
	var controls: ShipControls = FlightSim.controls(thrust)
	controls.boost = true
	return controls


func _count_depleted(_ship: Node) -> void:
	_depleted += 1


func before_test() -> void:
	_depleted = 0
	Events.boost_depleted.connect(_count_depleted)


func after_test() -> void:
	Events.boost_depleted.disconnect(_count_depleted)


func test_boost_reaches_the_boost_max_speed_within_3_percent() -> void:
	for ship_id: StringName in SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var ship: Ship = _spawn(ship_id)
		# Long enough to arrive, short enough that the energy has not run out yet.
		var ticks: int = roundi(0.9 * def.energy_capacity / def.boost_energy_per_second * 60.0)
		var samples: Array[FlightSim.Sample] = await FlightSim.fly(
			get_tree(), ship, _boost(), ticks
		)
		var forward: PackedFloat32Array = FlightSim.speed_along(samples, 2, -1.0)
		var peak: float = 0.0
		for value: float in forward:
			peak = maxf(peak, value)
		assert_float(peak).is_equal_approx(def.boost_max_speed, def.boost_max_speed * 0.03)
		assert_bool(ship.is_boosting()).is_true()


func test_boost_accelerates_harder_than_plain_thrust() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(get_tree(), ship, _boost(), SECONDS)
	var expected: float = def.accel_forward() * def.boost_thrust_multiplier
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(expected, expected * 0.03)


func test_boost_drains_energy_at_the_defined_rate() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	await FlightSim.fly(get_tree(), ship, _boost(), 2 * SECONDS)
	var expected: float = def.energy_capacity - def.boost_energy_per_second * 2.0
	assert_float(ship.power().energy).is_equal_approx(expected, def.boost_energy_per_second * 0.05)


func test_boost_stops_when_energy_runs_out_and_signals_once() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var lasting: float = def.energy_capacity / def.boost_energy_per_second
	await FlightSim.fly(get_tree(), ship, _boost(), roundi((lasting + 0.5) * 60.0))
	assert_bool(ship.is_boosting()).is_false()
	assert_int(_depleted).is_equal(1)
	# Still holding the button for a long time does not restart it: no stutter.
	await FlightSim.fly(get_tree(), ship, _boost(), 6 * SECONDS)
	assert_bool(ship.is_boosting()).is_false()
	assert_int(_depleted).is_equal(1)


func test_speed_falls_back_to_the_normal_cap_after_boost_ends() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var lasting: float = def.energy_capacity / def.boost_energy_per_second
	await FlightSim.fly(get_tree(), ship, _boost(), roundi((lasting + 0.2) * 60.0))
	var plain: ShipControls = FlightSim.controls(Vector3(0, 0, 1))
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(get_tree(), ship, plain, 3 * SECONDS)
	assert_float(-samples[-1].local_velocity.z).is_equal_approx(def.max_speed, def.max_speed * 0.03)


func test_releasing_boost_does_not_signal_depletion() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	await FlightSim.fly(get_tree(), ship, _boost(), SECONDS)
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(Vector3(0, 0, 1)), SECONDS)
	assert_bool(ship.is_boosting()).is_false()
	assert_int(_depleted).is_equal(0)
	assert_float(ship.power().energy).is_less(def.energy_capacity)


func test_energy_regenerates_after_boost_and_boost_works_again() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	await FlightSim.fly(get_tree(), ship, _boost(), 5 * SECONDS)
	assert_int(_depleted).is_equal(1)
	# Let go, wait for the regen delay and a few seconds of regeneration.
	var rest: float = def.energy_regen_delay + def.boost_min_energy / def.energy_regen + 1.0
	await FlightSim.fly(get_tree(), ship, FlightSim.controls(), roundi(rest * 60.0))
	await FlightSim.fly(get_tree(), ship, _boost(), 10)
	assert_bool(ship.is_boosting()).is_true()


func test_boost_cannot_start_below_the_minimum_energy() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	await get_tree().physics_frame
	ship.power().energy = def.boost_min_energy * 0.5
	await FlightSim.fly(get_tree(), ship, _boost(), 5)
	assert_bool(ship.is_boosting()).is_false()


func test_boost_while_drifting_keeps_the_extra_speed() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	var ship: Ship = _spawn(&"kestrel")
	var controls: ShipControls = _boost()
	controls.fa_off = true
	var lasting: float = def.energy_capacity / def.boost_energy_per_second
	await FlightSim.fly(get_tree(), ship, controls, roundi((lasting + 0.2) * 60.0))
	# Boost is over, but FA is still off, so the momentum stays.
	var idle: ShipControls = FlightSim.controls()
	idle.fa_off = true
	var samples: Array[FlightSim.Sample] = await FlightSim.fly(get_tree(), ship, idle, 3 * SECONDS)
	assert_float(-samples[-1].local_velocity.z).is_greater(def.max_speed * 1.2)
