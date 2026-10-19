extends GdUnitTestSuite
## `PowerSystem`: the all-or-nothing consumer API and regeneration after a delay.

const DT: float = 1.0 / 60.0

var _power: PowerSystem


func before_test() -> void:
	_power = auto_free(PowerSystem.new())
	_power.configure(Content.ship(&"kestrel"))


func _tick_for(seconds: float) -> void:
	for _tick: int in roundi(seconds / DT):
		_power.tick(DT)


func test_configure_fills_the_capacitor_from_the_def() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	assert_float(_power.capacity).is_equal(def.energy_capacity)
	assert_float(_power.energy).is_equal(def.energy_capacity)
	assert_float(_power.fraction()).is_equal(1.0)


func test_request_spends_and_reports_success() -> void:
	assert_bool(_power.request(30.0)).is_true()
	assert_float(_power.energy).is_equal_approx(_power.capacity - 30.0, 0.001)


func test_request_is_all_or_nothing() -> void:
	_power.energy = 10.0
	assert_bool(_power.request(10.5)).is_false()
	assert_float(_power.energy).is_equal(10.0)
	assert_bool(_power.can_afford(10.0)).is_true()
	assert_bool(_power.can_afford(10.5)).is_false()


func test_negative_requests_are_refused() -> void:
	assert_bool(_power.request(-5.0)).is_false()
	assert_float(_power.energy).is_equal(_power.capacity)


func test_no_regen_during_the_delay() -> void:
	_power.request(50.0)
	_tick_for(_power.regen_delay * 0.9)
	assert_float(_power.energy).is_equal_approx(_power.capacity - 50.0, 0.001)


func test_regen_runs_after_the_delay_at_the_defined_rate() -> void:
	_power.request(50.0)
	_tick_for(_power.regen_delay + 1.0)
	var expected: float = _power.capacity - 50.0 + _power.regen_per_second * 1.0
	assert_float(_power.energy).is_equal_approx(expected, _power.regen_per_second * DT * 2.0)


func test_spending_again_restarts_the_delay() -> void:
	_power.request(50.0)
	_tick_for(_power.regen_delay * 0.9)
	_power.request(1.0)
	_tick_for(_power.regen_delay * 0.9)
	assert_float(_power.energy).is_equal_approx(_power.capacity - 51.0, 0.001)


func test_regen_stops_at_capacity() -> void:
	_power.request(5.0)
	_tick_for(10.0)
	assert_float(_power.energy).is_equal(_power.capacity)
