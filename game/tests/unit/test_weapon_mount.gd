extends GdUnitTestSuite
## `WeaponMount`: reload rate, heat, overheat lockout and staggering, with no scene involved.

const DT: float = 1.0 / 60.0

var _pulse: WeaponDef
var _cannon: WeaponDef


func before_test() -> void:
	_pulse = Content.weapon(&"pulse_laser").duplicate() as WeaponDef
	_cannon = Content.weapon(&"autocannon").duplicate() as WeaponDef


## Holds the trigger on `mount` for `seconds`, firing whenever allowed. Returns shots fired.
func _burst(mount: WeaponMount, seconds: float) -> int:
	var shots: int = 0
	for _tick: int in roundi(seconds / DT):
		mount.advance(DT, true)
		if mount.can_fire():
			mount.register_shot()
			shots += 1
	return shots


func test_a_new_mount_is_cold_and_ready() -> void:
	var mount: WeaponMount = WeaponMount.create(_pulse, null, 0)
	assert_float(mount.heat).is_equal(0.0)
	assert_bool(mount.overheated).is_false()
	assert_bool(mount.can_fire()).is_true()


func test_a_shot_starts_the_reload() -> void:
	var mount: WeaponMount = WeaponMount.create(_pulse, null, 0)
	mount.register_shot()
	assert_bool(mount.can_fire()).is_false()
	assert_float(mount.cooldown).is_equal_approx(_pulse.interval(), 0.0001)


func test_the_rate_is_exact_even_when_it_is_not_a_whole_number_of_ticks() -> void:
	# 7 shots a second is 8.57 ticks per shot: the leftover must carry over.
	_pulse.fire_rate = 7.0
	_pulse.heat_per_shot = 0.0
	var mount: WeaponMount = WeaponMount.create(_pulse, null, 0)
	var shots: int = _burst(mount, 10.0)
	assert_int(shots).is_between(70, 71)


func test_fast_and_slow_weapons_fire_at_their_own_rates() -> void:
	_pulse.heat_per_shot = 0.0
	_cannon.heat_per_shot = 0.0
	assert_int(_burst(WeaponMount.create(_pulse, null, 0), 5.0)).is_between(20, 21)
	assert_int(_burst(WeaponMount.create(_cannon, null, 0), 5.0)).is_between(60, 61)


func test_an_idle_mount_banks_no_extra_shots() -> void:
	var mount: WeaponMount = WeaponMount.create(_pulse, null, 0)
	for _tick: int in 600:
		mount.advance(DT, false)
	mount.advance(DT, true)
	assert_bool(mount.can_fire()).is_true()
	mount.register_shot()
	mount.advance(DT, true)
	assert_bool(mount.can_fire()).is_false()


func test_waiting_for_energy_does_not_bank_a_burst() -> void:
	var mount: WeaponMount = WeaponMount.create(_pulse, null, 0)
	# Holding the trigger for a long time without ever firing (no energy).
	for _tick: int in 600:
		mount.advance(DT, true)
	var shots: int = 0
	for _tick: int in 30:
		mount.advance(DT, true)
		if mount.can_fire():
			mount.register_shot()
			shots += 1
	# Half a second at 4 shots a second: two or three, not a burst of banked shots.
	assert_int(shots).is_between(2, 3)


func test_each_shot_adds_heat_and_it_cools_down() -> void:
	var mount: WeaponMount = WeaponMount.create(_cannon, null, 0)
	mount.register_shot()
	assert_float(mount.heat).is_equal_approx(_cannon.heat_per_shot, 0.0001)
	mount.advance(1.0, false)
	assert_float(mount.heat).is_equal_approx(
		maxf(_cannon.heat_per_shot - _cannon.cool_rate, 0.0), 0.0001
	)


func test_reaching_the_capacity_overheats_and_the_shot_reports_it() -> void:
	_cannon.heat_per_shot = 40.0
	_cannon.heat_capacity = 100.0
	var mount: WeaponMount = WeaponMount.create(_cannon, null, 0)
	assert_bool(mount.register_shot()).is_false()
	assert_bool(mount.register_shot()).is_false()
	assert_bool(mount.register_shot()).is_true()
	assert_bool(mount.overheated).is_true()
	assert_float(mount.heat).is_equal(100.0)
	assert_float(mount.heat_fraction()).is_equal(1.0)


func test_an_overheated_mount_cannot_fire_until_it_cools_to_the_resume_line() -> void:
	_cannon.heat_per_shot = 100.0
	var mount: WeaponMount = WeaponMount.create(_cannon, null, 0)
	mount.register_shot()
	assert_bool(mount.overheated).is_true()
	var resumed_after: float = -1.0
	var seconds: float = 0.0
	while seconds < 30.0:
		seconds += DT
		if mount.advance(DT, true):
			resumed_after = seconds
			break
	# From 100 down to 40 at 14 per second.
	assert_float(resumed_after).is_equal_approx(60.0 / _cannon.cool_rate, 0.05)
	assert_bool(mount.overheated).is_false()
	assert_bool(mount.can_fire()).is_true()


func test_continuous_autocannon_fire_overheats_in_a_few_seconds() -> void:
	var mount: WeaponMount = WeaponMount.create(_cannon, null, 0)
	var seconds: float = 0.0
	while not mount.overheated and seconds < 30.0:
		mount.advance(DT, true)
		if mount.can_fire():
			mount.register_shot()
		seconds += DT
	assert_float(seconds).is_between(3.0, 7.0)


func test_staggered_mounts_start_one_after_another() -> void:
	_pulse.stagger = true
	var first: WeaponMount = WeaponMount.create(_pulse, null, 0)
	var second: WeaponMount = WeaponMount.create(_pulse, null, 1)
	first.stagger_start(2)
	second.stagger_start(2)
	assert_float(first.cooldown).is_equal(0.0)
	assert_float(second.cooldown).is_equal_approx(_pulse.interval() * 0.5, 0.0001)


func test_unstaggered_mounts_start_together() -> void:
	_cannon.stagger = false
	var second: WeaponMount = WeaponMount.create(_cannon, null, 1)
	second.stagger_start(2)
	assert_float(second.cooldown).is_equal(0.0)
