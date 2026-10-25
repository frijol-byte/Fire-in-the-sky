class_name MissileLock
extends RefCounted
## The lock-on of a homing missile (GDD 7.2): hold the secondary button on a target and the lock
## builds for `lock_time` seconds, with beeps that come faster and higher as it closes; release
## when it is locked to launch. Lose the target (out of range or off the nose) and the lock drains
## away faster than it built. This is only the state machine; `SecondarySystem` decides when a
## lock is possible and plays the sounds.

enum State { IDLE, LOCKING, LOCKED }
## What the caller should sound this tick.
enum Beep { NONE, TICK, READY }

## Seconds between beeps at the start of a lock and when it is nearly done.
const BEEP_SLOW: float = 0.45
const BEEP_FAST: float = 0.09
## The lock drains this many times faster than it builds while the target is out of reach.
const DRAIN_FACTOR: float = 2.5
## A lock this close to full counts as full (a tick's rounding must not cost a whole tick).
const FULL_EPSILON: float = 0.0001
## Pitch of the beep at the start and at the end of a lock.
const PITCH_LOW: float = 0.8
const PITCH_HIGH: float = 1.7

var state: State = State.IDLE
## 0..1, 1 when locked.
var progress: float = 0.0

var _beep_left: float = 0.0


## Advances the lock by `dt` seconds. `holding` is the trigger, `can_lock` whether a target is in
## reach, `lock_time` how long a full lock takes. Returns the beep to sound this tick.
func advance(dt: float, holding: bool, can_lock: bool, lock_time: float) -> Beep:
	if not holding:
		reset()
		return Beep.NONE
	var was_locked: bool = state == State.LOCKED
	if can_lock:
		progress = minf(progress + dt / lock_time, 1.0)
	else:
		progress = maxf(progress - dt / lock_time * DRAIN_FACTOR, 0.0)
	if progress >= 1.0 - FULL_EPSILON:
		progress = 1.0
		state = State.LOCKED
		return Beep.NONE if was_locked else Beep.READY
	state = State.LOCKING if progress > 0.0 else State.IDLE
	if state == State.IDLE or not can_lock:
		_beep_left = 0.0
		return Beep.NONE
	_beep_left -= dt
	if _beep_left > 0.0:
		return Beep.NONE
	_beep_left = beep_interval(progress)
	return Beep.TICK


## Drops the lock (trigger released, target changed, weapon disabled).
func reset() -> void:
	state = State.IDLE
	progress = 0.0
	_beep_left = 0.0


func is_locked() -> bool:
	return state == State.LOCKED


## Seconds between beeps at lock `progress` (0..1): slow at first, fast at the end.
static func beep_interval(lock_progress: float) -> float:
	return lerpf(BEEP_SLOW, BEEP_FAST, clampf(lock_progress, 0.0, 1.0))


## Pitch multiplier of the beep at lock `progress`.
static func beep_pitch(lock_progress: float) -> float:
	return lerpf(PITCH_LOW, PITCH_HIGH, clampf(lock_progress, 0.0, 1.0))
