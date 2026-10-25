extends GdUnitTestSuite
## `Durability`: the ion status and the `Events` it emits.

const DT: float = 1.0 / 60.0

var _durability: Durability
var _table: DamageTable


func before_test() -> void:
	_table = Content.damage_table()
	_durability = auto_free(Durability.new())
	_durability.configure(Content.ship(&"kestrel"))


func _set_layers(shield: float, armor: float, hull: float) -> void:
	_durability.shield = shield
	_durability.armor = armor
	_durability.hull = hull


func _hit(amount: float, type: DamageInfo.Type) -> DamageResult:
	return _durability.apply(DamageInfo.make(amount, type))


func _tick_for(seconds: float) -> void:
	for _tick: int in roundi(seconds / DT):
		_durability.tick(DT)


func test_ion_starts_the_status_for_the_table_duration() -> void:
	assert_bool(_durability.devices_disabled()).is_false()
	var result: DamageResult = _hit(1.0, DamageInfo.Type.ION)
	assert_bool(result.ion_disabled).is_true()
	assert_bool(_durability.devices_disabled()).is_true()
	assert_float(_durability.status_remaining(DamageTable.STATUS_ION)).is_equal(
		_table.ion_disable_seconds
	)


func test_the_ion_status_expires() -> void:
	_hit(1.0, DamageInfo.Type.ION)
	_tick_for(_table.ion_disable_seconds * 0.9)
	assert_bool(_durability.devices_disabled()).is_true()
	_tick_for(_table.ion_disable_seconds * 0.2)
	assert_bool(_durability.devices_disabled()).is_false()
	assert_float(_durability.status_remaining(DamageTable.STATUS_ION)).is_equal(0.0)


func test_a_second_ion_hit_restarts_the_timer_without_stacking() -> void:
	_hit(1.0, DamageInfo.Type.ION)
	_tick_for(_table.ion_disable_seconds * 0.5)
	_hit(1.0, DamageInfo.Type.ION)
	assert_float(_durability.status_remaining(DamageTable.STATUS_ION)).is_equal(
		_table.ion_disable_seconds
	)


func test_other_damage_types_do_not_disable_devices() -> void:
	_hit(10.0, DamageInfo.Type.ENERGY)
	_hit(10.0, DamageInfo.Type.KINETIC)
	_hit(10.0, DamageInfo.Type.EXPLOSIVE)
	assert_bool(_durability.devices_disabled()).is_false()


func test_a_damaging_hit_emits_ship_damaged_with_the_result() -> void:
	var seen: Array = []
	var listener: Callable = func(ship: Node, info: DamageInfo, result: DamageResult) -> void:
		seen.append([ship, info, result])
	Events.ship_damaged.connect(listener)
	var shooter: Node = auto_free(Node.new())
	var info: DamageInfo = DamageInfo.make(
		10.0, DamageInfo.Type.ENERGY, shooter, Vector3(1, 2, 3), &"engine"
	)
	var result: DamageResult = _durability.apply(info)
	Events.ship_damaged.disconnect(listener)

	assert_array(seen).has_size(1)
	assert_object(seen[0][1]).is_same(info)
	assert_object(seen[0][2]).is_same(result)
	assert_object(info.source).is_same(shooter)
	assert_vector(info.hit_point).is_equal(Vector3(1, 2, 3))
	assert_str(info.subsystem).is_equal("engine")


func test_ship_destroyed_is_emitted_exactly_once() -> void:
	var kills: Array = []
	var listener: Callable = func(_ship: Node, info: DamageInfo) -> void: kills.append(info)
	Events.ship_destroyed.connect(listener)
	_set_layers(0.0, 0.0, 5.0)
	var killing: DamageInfo = DamageInfo.make(50.0, DamageInfo.Type.KINETIC)
	_durability.apply(killing)
	_durability.apply(DamageInfo.make(50.0, DamageInfo.Type.KINETIC))
	Events.ship_destroyed.disconnect(listener)

	assert_array(kills).has_size(1)
	assert_object(kills[0]).is_same(killing)


func test_a_hit_that_does_no_damage_emits_no_damaged_event() -> void:
	var seen: Array = []
	var listener: Callable = func(_ship: Node, _info: DamageInfo, _result: DamageResult) -> void:
		seen.append(true)
	Events.ship_damaged.connect(listener)
	_set_layers(0.0, 0.0, 100.0)
	_hit(50.0, DamageInfo.Type.ION)
	Events.ship_damaged.disconnect(listener)
	assert_array(seen).is_empty()
