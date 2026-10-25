extends GdUnitTestSuite
## `Durability`: layer multipliers, overflow from shield into armor into hull, shield regeneration
## after a delay, the destroyed state, the ion status and the events.

const DT: float = 1.0 / 60.0
const TYPES: Array[DamageInfo.Type] = [
	DamageInfo.Type.ENERGY,
	DamageInfo.Type.KINETIC,
	DamageInfo.Type.EXPLOSIVE,
	DamageInfo.Type.ION,
]

var _durability: Durability
var _table: DamageTable


func before_test() -> void:
	_table = Content.damage_table()
	_durability = auto_free(Durability.new())
	_durability.configure(Content.ship(&"kestrel"))


## Sets the three layers directly, so one test isolates one layer.
func _set_layers(shield: float, armor: float, hull: float) -> void:
	_durability.shield = shield
	_durability.armor = armor
	_durability.hull = hull


func _hit(amount: float, type: DamageInfo.Type) -> DamageResult:
	return _durability.apply(DamageInfo.make(amount, type))


func _tick_for(seconds: float) -> void:
	for _tick: int in roundi(seconds / DT):
		_durability.tick(DT)


func test_configure_fills_every_layer_from_the_def() -> void:
	var def: ShipDef = Content.ship(&"kestrel")
	assert_float(_durability.shield).is_equal(def.shield_capacity)
	assert_float(_durability.armor).is_equal(def.armor_capacity)
	assert_float(_durability.hull).is_equal(def.hull_capacity)
	assert_float(_durability.shield_fraction()).is_equal(1.0)
	assert_bool(_durability.is_destroyed()).is_false()


func test_a_hit_on_the_shield_uses_the_shield_multiplier_for_every_type() -> void:
	for type: DamageInfo.Type in TYPES:
		_set_layers(1000.0, 1000.0, 1000.0)
		var result: DamageResult = _hit(10.0, type)
		var expected: float = 10.0 * _table.multiplier(type, DamageTable.Layer.SHIELD)
		assert_float(result.shield_damage).is_equal_approx(expected, 0.0001)
		assert_float(_durability.shield).is_equal_approx(1000.0 - expected, 0.0001)
		assert_float(_durability.armor).is_equal(1000.0)
		assert_float(_durability.hull).is_equal(1000.0)


func test_a_hit_on_the_armor_uses_the_armor_multiplier_for_every_type() -> void:
	for type: DamageInfo.Type in TYPES:
		_set_layers(0.0, 1000.0, 1000.0)
		var result: DamageResult = _hit(10.0, type)
		var expected: float = 10.0 * _table.multiplier(type, DamageTable.Layer.ARMOR)
		assert_float(result.armor_damage).is_equal_approx(expected, 0.0001)
		assert_float(_durability.armor).is_equal_approx(1000.0 - expected, 0.0001)
		assert_float(_durability.hull).is_equal(1000.0)


func test_a_hit_on_the_hull_uses_the_hull_multiplier_for_every_type() -> void:
	for type: DamageInfo.Type in TYPES:
		_set_layers(0.0, 0.0, 1000.0)
		var result: DamageResult = _hit(10.0, type)
		var expected: float = 10.0 * _table.multiplier(type, DamageTable.Layer.HULL)
		assert_float(result.hull_damage).is_equal_approx(expected, 0.0001)
		assert_float(_durability.hull).is_equal_approx(1000.0 - expected, 0.0001)


func test_damage_overflows_from_shield_into_armor_into_hull() -> void:
	# Kinetic 100: the shield (x0.75) absorbs 30 of the 75 it is offered, so 45 / 0.75 = 60 raw
	# carries on. The armor (x1.5) is offered 90 and absorbs 40, so 50 / 1.5 = 33.33 raw carries
	# on to the hull (x1.0).
	_set_layers(30.0, 40.0, 100.0)
	var result: DamageResult = _hit(100.0, DamageInfo.Type.KINETIC)
	assert_float(result.shield_damage).is_equal_approx(30.0, 0.0001)
	assert_float(result.armor_damage).is_equal_approx(40.0, 0.0001)
	assert_float(result.hull_damage).is_equal_approx(100.0 / 3.0, 0.0001)
	assert_float(_durability.shield).is_equal(0.0)
	assert_float(_durability.armor).is_equal(0.0)
	assert_float(_durability.hull).is_equal_approx(100.0 - 100.0 / 3.0, 0.0001)
	assert_int(result.deepest_layer()).is_equal(DamageTable.Layer.HULL)


func test_nothing_reaches_the_next_layer_while_this_one_holds() -> void:
	_set_layers(100.0, 50.0, 50.0)
	var result: DamageResult = _hit(10.0, DamageInfo.Type.EXPLOSIVE)
	assert_float(result.armor_damage).is_equal(0.0)
	assert_float(result.hull_damage).is_equal(0.0)
	assert_int(result.deepest_layer()).is_equal(DamageTable.Layer.SHIELD)


func test_an_empty_layer_passes_the_whole_hit_on() -> void:
	_set_layers(0.0, 0.0, 100.0)
	var result: DamageResult = _hit(10.0, DamageInfo.Type.ENERGY)
	assert_float(result.shield_damage).is_equal(0.0)
	assert_float(result.armor_damage).is_equal(0.0)
	assert_float(result.hull_damage).is_equal_approx(10.0, 0.0001)


func test_ion_does_no_hull_damage_however_hard_it_hits() -> void:
	_set_layers(0.0, 0.0, 100.0)
	var result: DamageResult = _hit(10000.0, DamageInfo.Type.ION)
	assert_float(result.hull_damage).is_equal(0.0)
	assert_float(_durability.hull).is_equal(100.0)
	assert_bool(_durability.is_destroyed()).is_false()


func test_ion_overflowing_through_shield_and_armor_still_leaves_the_hull_alone() -> void:
	_set_layers(10.0, 10.0, 100.0)
	var result: DamageResult = _hit(10000.0, DamageInfo.Type.ION)
	assert_float(result.shield_damage).is_equal(10.0)
	assert_float(result.armor_damage).is_equal(10.0)
	assert_float(_durability.hull).is_equal(100.0)


func test_zero_and_negative_hits_do_nothing() -> void:
	_durability.shield = 50.0
	_hit(0.0, DamageInfo.Type.ENERGY)
	_hit(-20.0, DamageInfo.Type.ENERGY)
	assert_float(_durability.shield).is_equal(50.0)


func test_shield_does_not_regenerate_during_the_delay() -> void:
	_set_layers(50.0, 60.0, 80.0)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	_tick_for(_durability.shield_regen_delay * 0.9)
	assert_float(_durability.shield).is_equal_approx(40.0, 0.0001)


func test_shield_regenerates_after_the_delay_at_the_defined_rate() -> void:
	_set_layers(50.0, 60.0, 80.0)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	_tick_for(_durability.shield_regen_delay + 1.0)
	var expected: float = 40.0 + _durability.shield_regen_per_second * 1.0
	var slack: float = _durability.shield_regen_per_second * DT * 2.0
	assert_float(_durability.shield).is_equal_approx(expected, slack)


func test_a_new_hit_restarts_the_regen_delay() -> void:
	_set_layers(50.0, 60.0, 80.0)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	_tick_for(_durability.shield_regen_delay * 0.9)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	_tick_for(_durability.shield_regen_delay * 0.9)
	assert_float(_durability.shield).is_equal_approx(30.0, 0.0001)


func test_a_hit_that_only_reaches_the_armor_also_restarts_the_delay() -> void:
	_set_layers(0.0, 60.0, 80.0)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	_tick_for(_durability.shield_regen_delay * 0.9)
	assert_float(_durability.shield).is_equal(0.0)


func test_shield_regen_stops_at_capacity_and_armor_never_regenerates() -> void:
	_set_layers(_durability.shield_capacity - 1.0, 10.0, 10.0)
	_tick_for(_durability.shield_regen_delay + 10.0)
	assert_float(_durability.shield).is_equal(_durability.shield_capacity)
	assert_float(_durability.armor).is_equal(10.0)
	assert_float(_durability.hull).is_equal(10.0)


func test_hull_at_zero_destroys_the_ship() -> void:
	_set_layers(0.0, 0.0, 20.0)
	var result: DamageResult = _hit(25.0, DamageInfo.Type.KINETIC)
	assert_bool(result.destroyed).is_true()
	assert_bool(_durability.is_destroyed()).is_true()
	assert_float(_durability.hull).is_equal(0.0)
	# Overkill is not reported as damage beyond the hull that was there.
	assert_float(result.hull_damage).is_equal(20.0)


func test_a_destroyed_ship_takes_no_more_damage_and_does_not_regenerate() -> void:
	_set_layers(0.0, 0.0, 5.0)
	_hit(100.0, DamageInfo.Type.KINETIC)
	var again: DamageResult = _hit(100.0, DamageInfo.Type.KINETIC)
	assert_float(again.total()).is_equal(0.0)
	assert_bool(again.destroyed).is_false()
	_durability.shield = 0.0
	_tick_for(_durability.shield_regen_delay + 2.0)
	assert_float(_durability.shield).is_equal(0.0)


func test_restore_refills_and_revives() -> void:
	_set_layers(0.0, 0.0, 5.0)
	_hit(100.0, DamageInfo.Type.KINETIC)
	_hit(1.0, DamageInfo.Type.ION)
	_durability.restore()
	assert_bool(_durability.is_destroyed()).is_false()
	assert_float(_durability.hull).is_equal(_durability.hull_capacity)
	assert_bool(_durability.devices_disabled()).is_false()
