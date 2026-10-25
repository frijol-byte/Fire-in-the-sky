extends GdUnitTestSuite
## `AimAssist`: strength from difficulty, slider and device, reticle friction and the gimbal limit.

const ZONE: float = 0.1


func after_test() -> void:
	Settings.values.clear()


func test_strength_is_the_difficulty_scale_times_the_slider_for_a_gamepad() -> void:
	assert_float(AimAssist.strength(0.7, 1.0, true, false)).is_equal_approx(0.7, 0.0001)
	assert_float(AimAssist.strength(0.7, 0.5, true, false)).is_equal_approx(0.35, 0.0001)
	assert_float(AimAssist.strength(1.0, 0.0, true, false)).is_equal(0.0)


func test_the_mouse_gets_no_assist_unless_asked() -> void:
	assert_float(AimAssist.strength(1.0, 1.0, false, false)).is_equal(0.0)
	assert_float(AimAssist.strength(1.0, 1.0, false, true)).is_equal(1.0)


func test_strength_is_kept_between_zero_and_one() -> void:
	assert_float(AimAssist.strength(3.0, 2.0, true, false)).is_equal(1.0)
	assert_float(AimAssist.strength(-1.0, 1.0, true, false)).is_equal(0.0)


func test_current_strength_reads_the_difficulty_and_settings() -> void:
	# Normal difficulty, slider at its default.
	assert_float(AimAssist.current_strength(true)).is_equal_approx(
		Content.difficulty(&"normal").aim_assist_scale, 0.0001
	)
	assert_float(AimAssist.current_strength(false)).is_equal(0.0)
	Settings.set_value(AimAssist.SETTING_DIFFICULTY, &"hard")
	assert_float(AimAssist.current_strength(true)).is_equal_approx(
		Content.difficulty(&"hard").aim_assist_scale, 0.0001
	)
	Settings.set_value(AimAssist.SETTING_STRENGTH, 0.0)
	assert_float(AimAssist.current_strength(true)).is_equal(0.0)
	Settings.set_value(AimAssist.SETTING_STRENGTH, 1.0)
	Settings.set_value(AimAssist.SETTING_MOUSE, true)
	assert_float(AimAssist.current_strength(false)).is_greater(0.0)


func test_easier_difficulties_assist_more() -> void:
	var easy: float = Content.difficulty(&"easy").aim_assist_scale
	var normal: float = Content.difficulty(&"normal").aim_assist_scale
	var hard: float = Content.difficulty(&"hard").aim_assist_scale
	assert_float(easy).is_greater(normal)
	assert_float(normal).is_greater(hard)
	assert_float(hard).is_greater(0.0)


func test_friction_is_off_outside_the_zone_and_without_strength() -> void:
	assert_float(AimAssist.friction_factor(ZONE, ZONE, 0.4, 1.0)).is_equal(1.0)
	assert_float(AimAssist.friction_factor(ZONE * 2.0, ZONE, 0.4, 1.0)).is_equal(1.0)
	assert_float(AimAssist.friction_factor(0.0, ZONE, 0.4, 0.0)).is_equal(1.0)
	assert_float(AimAssist.friction_factor(0.0, 0.0, 0.4, 1.0)).is_equal(1.0)


func test_friction_is_strongest_on_the_target() -> void:
	assert_float(AimAssist.friction_factor(0.0, ZONE, 0.4, 1.0)).is_equal_approx(0.4, 0.0001)
	# Half strength only goes half way down.
	assert_float(AimAssist.friction_factor(0.0, ZONE, 0.4, 0.5)).is_equal_approx(0.7, 0.0001)


func test_friction_eases_in_smoothly_towards_the_target() -> void:
	var previous: float = 1.0
	for step: int in range(1, 11):
		var angle: float = ZONE * (1.0 - step / 10.0)
		var factor: float = AimAssist.friction_factor(angle, ZONE, 0.4, 1.0)
		assert_float(factor).is_less_equal(previous)
		previous = factor
	# Just inside the zone the stick has barely slowed.
	assert_float(AimAssist.friction_factor(ZONE * 0.98, ZONE, 0.4, 1.0)).is_greater(0.99)


func test_the_zone_grows_with_the_angle_the_target_covers() -> void:
	var far: float = AimAssist.friction_zone(0.1, 6.0, 1000.0)
	var near: float = AimAssist.friction_zone(0.1, 6.0, 60.0)
	assert_float(far).is_greater(0.1)
	assert_float(near).is_greater(far)
	assert_float(AimAssist.friction_zone(0.1, 6.0, 0.0)).is_equal(0.1)


func test_the_gimbal_limit_scales_with_strength() -> void:
	assert_float(AimAssist.gimbal_limit_deg(3.0, 1.0)).is_equal(3.0)
	assert_float(AimAssist.gimbal_limit_deg(3.0, 0.5)).is_equal(1.5)
	assert_float(AimAssist.gimbal_limit_deg(3.0, 0.0)).is_equal(0.0)
	assert_float(AimAssist.gimbal_limit_deg(3.0, 4.0)).is_equal(3.0)
