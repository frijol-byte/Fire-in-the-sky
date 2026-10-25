extends GdUnitTestSuite
## `MissileWarning`'s pure rules, and the secondary / device lines of the flight HUD.

const MISSILE: SecondaryDef = preload("res://data/secondaries/homing_missile.tres")
const ROCKETS: SecondaryDef = preload("res://data/secondaries/rocket_pod.tres")
const FLARES: DeviceDef = preload("res://data/devices/flares.tres")


func test_time_to_impact_uses_the_closing_speed() -> void:
	# 600 m apart, missile at 300 m/s straight at a ship flying away at 100 m/s: 3 s.
	var seconds: float = MissileWarning.time_to_impact(
		Vector3.ZERO, Vector3(0, 0, -300), Vector3(0, 0, -600), Vector3(0, 0, -100)
	)
	assert_float(seconds).is_equal_approx(3.0, 0.0001)


func test_time_to_impact_is_infinite_when_not_closing() -> void:
	(
		assert_float(
			MissileWarning.time_to_impact(
				Vector3.ZERO, Vector3(0, 0, -100), Vector3(0, 0, -600), Vector3(0, 0, -300)
			)
		)
		. is_equal(INF)
	)
	(
		assert_float(
			MissileWarning.time_to_impact(
				Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -600), Vector3.ZERO
			)
		)
		. is_equal(INF)
	)


func test_time_to_impact_is_zero_when_on_top_of_the_ship() -> void:
	(
		assert_float(
			MissileWarning.time_to_impact(Vector3.ZERO, Vector3.ONE, Vector3.ZERO, Vector3.ZERO)
		)
		. is_equal(0.0)
	)


func test_the_alarm_speeds_up_as_the_missile_closes() -> void:
	assert_float(MissileWarning.beep_interval(INF)).is_equal(MissileWarning.BEEP_SLOW)
	assert_float(MissileWarning.beep_interval(MissileWarning.FAR_SECONDS)).is_equal(
		MissileWarning.BEEP_SLOW
	)
	assert_float(MissileWarning.beep_interval(0.0)).is_equal(MissileWarning.BEEP_FAST)
	var previous: float = MissileWarning.BEEP_SLOW + 1.0
	for seconds: float in [6.0, 4.0, 2.0, 1.0, 0.6]:
		var interval: float = MissileWarning.beep_interval(seconds)
		assert_float(interval).is_less_equal(previous)
		previous = interval


func test_the_banner_flashes() -> void:
	var lit: int = 0
	var samples: int = 300
	for index: int in samples:
		if MissileWarning.flash_on(float(index) / 100.0):
			lit += 1
	assert_int(lit).is_between(samples / 2, samples - samples / 5)
	assert_bool(MissileWarning.flash_on(0.0)).is_true()


func test_secondary_line_shows_name_and_ammo() -> void:
	var lock: MissileLock = MissileLock.new()
	var text: String = FlightHud.secondary_text(MISSILE, 6, lock, 0.0, false, false)
	assert_str(text).contains("HOMING MISSILE")
	assert_str(text).contains("6")
	assert_str(FlightHud.secondary_text(null, 0, lock, 0.0, false, false)).is_empty()


func test_secondary_line_shows_the_lock_and_why_it_cannot_fire() -> void:
	var lock: MissileLock = MissileLock.new()
	lock.state = MissileLock.State.LOCKING
	lock.progress = 0.5
	assert_str(FlightHud.secondary_text(MISSILE, 6, lock, 0.0, false, false)).contains(
		"LOCKING 50%"
	)
	lock.state = MissileLock.State.LOCKED
	lock.progress = 1.0
	assert_str(FlightHud.secondary_text(MISSILE, 6, lock, 0.0, false, false)).contains("LOCKED")
	lock.reset()
	assert_str(FlightHud.secondary_text(MISSILE, 0, lock, 0.0, false, false)).contains("NO AMMO")
	assert_str(FlightHud.secondary_text(MISSILE, 3, lock, 0.8, false, false)).contains("RELOADING")
	assert_str(FlightHud.secondary_text(MISSILE, 3, lock, 0.0, false, true)).contains("DISABLED")
	# A salvo in progress with the last rocket gone is not "no ammo" yet, nor "reloading".
	var mid_salvo: String = FlightHud.secondary_text(ROCKETS, 0, lock, 0.0, true, false)
	assert_str(mid_salvo).not_contains("NO AMMO")


func test_device_line_shows_ready_or_the_cooldown() -> void:
	assert_str(FlightHud.device_text(FLARES, 0.0)).contains("FLARES").contains("READY")
	assert_str(FlightHud.device_text(FLARES, 4.2)).contains("5 s")
	assert_str(FlightHud.device_text(null, 0.0)).is_empty()
