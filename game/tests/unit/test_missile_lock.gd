extends GdUnitTestSuite
## `MissileLock`: the lock builds while the trigger is held on a target, drains when the target is
## lost, and beeps faster as it closes.

const LOCK_TIME: float = 1.2
const DT: float = 1.0 / 60.0


## Holds the trigger on a reachable target for `seconds` and returns the beeps sounded.
func _hold(lock: MissileLock, seconds: float, can_lock: bool = true) -> Array[MissileLock.Beep]:
	var beeps: Array[MissileLock.Beep] = []
	for tick: int in roundi(seconds / DT):
		var beep: MissileLock.Beep = lock.advance(DT, true, can_lock, LOCK_TIME)
		if beep != MissileLock.Beep.NONE:
			beeps.append(beep)
	return beeps


func test_a_fresh_lock_is_idle() -> void:
	var lock: MissileLock = MissileLock.new()
	assert_int(lock.state).is_equal(MissileLock.State.IDLE)
	assert_float(lock.progress).is_equal(0.0)
	assert_bool(lock.is_locked()).is_false()


func test_holding_on_a_target_locks_after_the_lock_time() -> void:
	var lock: MissileLock = MissileLock.new()
	_hold(lock, LOCK_TIME - 0.1)
	assert_int(lock.state).is_equal(MissileLock.State.LOCKING)
	assert_float(lock.progress).is_between(0.9, 0.95)
	_hold(lock, 0.2)
	assert_bool(lock.is_locked()).is_true()
	assert_float(lock.progress).is_equal(1.0)


func test_releasing_drops_the_lock() -> void:
	var lock: MissileLock = MissileLock.new()
	_hold(lock, 0.6)
	lock.advance(DT, false, true, LOCK_TIME)
	assert_int(lock.state).is_equal(MissileLock.State.IDLE)
	assert_float(lock.progress).is_equal(0.0)


func test_losing_the_target_drains_the_lock_faster_than_it_built() -> void:
	var lock: MissileLock = MissileLock.new()
	_hold(lock, LOCK_TIME)
	assert_bool(lock.is_locked()).is_true()
	_hold(lock, 0.2, false)
	assert_bool(lock.is_locked()).is_false()
	assert_int(lock.state).is_equal(MissileLock.State.LOCKING)
	# 0.2 s of draining at 2.5x undoes 0.42 of a 1.2 s lock.
	assert_float(lock.progress).is_between(0.55, 0.62)
	_hold(lock, 1.0, false)
	assert_int(lock.state).is_equal(MissileLock.State.IDLE)


func test_nothing_builds_without_a_target() -> void:
	var lock: MissileLock = MissileLock.new()
	var beeps: Array[MissileLock.Beep] = _hold(lock, 2.0, false)
	assert_int(lock.state).is_equal(MissileLock.State.IDLE)
	assert_array(beeps).is_empty()


func test_beeps_come_faster_and_end_with_one_ready_tone() -> void:
	var lock: MissileLock = MissileLock.new()
	var times: Array[float] = []
	var elapsed: float = 0.0
	var ready_at: float = -1.0
	for tick: int in roundi((LOCK_TIME + 0.5) / DT):
		elapsed += DT
		var beep: MissileLock.Beep = lock.advance(DT, true, true, LOCK_TIME)
		if beep == MissileLock.Beep.TICK:
			times.append(elapsed)
		elif beep == MissileLock.Beep.READY:
			ready_at = elapsed
	assert_int(times.size()).is_greater(3)
	var first_gap: float = times[1] - times[0]
	var last_gap: float = times[times.size() - 1] - times[times.size() - 2]
	assert_float(last_gap).is_less(first_gap)
	assert_float(ready_at).is_between(LOCK_TIME - 0.05, LOCK_TIME + 0.05)
	# Once locked, no more beeps are sounded.
	assert_float(times[times.size() - 1]).is_less(ready_at)


func test_beep_interval_and_pitch_escalate() -> void:
	assert_float(MissileLock.beep_interval(0.0)).is_equal_approx(MissileLock.BEEP_SLOW, 0.0001)
	assert_float(MissileLock.beep_interval(1.0)).is_equal_approx(MissileLock.BEEP_FAST, 0.0001)
	assert_float(MissileLock.beep_interval(0.5)).is_between(
		MissileLock.BEEP_FAST, MissileLock.BEEP_SLOW
	)
	assert_float(MissileLock.beep_pitch(1.0)).is_greater(MissileLock.beep_pitch(0.0))
	assert_float(MissileLock.beep_interval(5.0)).is_equal_approx(MissileLock.BEEP_FAST, 0.0001)
