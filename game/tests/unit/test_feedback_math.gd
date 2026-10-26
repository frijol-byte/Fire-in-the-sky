extends GdUnitTestSuite
## `FeedbackMath`: the hit marker a hit earns, camera shake from hits and explosions, where a damage
## indicator sits on the ring, the low-shield alarm's hysteresis and marker fading.

var _def: FeedbackDef = null


func before_test() -> void:
	_def = Content.feedback()


func _result(shield: float, armor: float, hull: float, destroyed: bool = false) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	result.shield_damage = shield
	result.armor_damage = armor
	result.hull_damage = hull
	result.destroyed = destroyed
	return result


func test_the_marker_follows_the_deepest_layer_hit() -> void:
	assert_int(FeedbackMath.marker_for(_result(8, 0, 0))).is_equal(FeedbackMath.Marker.SHIELD)
	assert_int(FeedbackMath.marker_for(_result(8, 3, 0))).is_equal(FeedbackMath.Marker.ARMOR)
	assert_int(FeedbackMath.marker_for(_result(0, 3, 1))).is_equal(FeedbackMath.Marker.HULL)
	assert_int(FeedbackMath.marker_for(_result(0, 0, 4))).is_equal(FeedbackMath.Marker.HULL)


func test_the_killing_hit_earns_the_kill_marker() -> void:
	assert_int(FeedbackMath.marker_for(_result(0, 0, 4, true))).is_equal(FeedbackMath.Marker.KILL)


func test_a_hit_that_did_nothing_still_reads_as_a_shield_hit() -> void:
	assert_int(FeedbackMath.marker_for(_result(0, 0, 0))).is_equal(FeedbackMath.Marker.SHIELD)


func test_hull_hits_shake_the_camera_harder_than_shield_hits() -> void:
	var shield: float = FeedbackMath.hit_shake(_result(10, 0, 0), _def)
	var armor: float = FeedbackMath.hit_shake(_result(0, 10, 0), _def)
	var hull: float = FeedbackMath.hit_shake(_result(0, 0, 10), _def)
	assert_float(shield).is_greater(0.0)
	assert_float(armor).is_greater(shield)
	assert_float(hull).is_greater(armor)


func test_one_hit_never_shakes_past_the_cap() -> void:
	assert_float(FeedbackMath.hit_shake(_result(900, 900, 900), _def)).is_equal(_def.shake_hit_max)
	assert_float(FeedbackMath.hit_shake(_result(0, 0, 0), _def)).is_equal(0.0)


func test_explosion_shake_fades_with_distance() -> void:
	assert_float(FeedbackMath.explosion_shake(0.0, _def)).is_equal(_def.shake_explosion_max)
	var half: float = FeedbackMath.explosion_shake(_def.shake_explosion_range_m * 0.5, _def)
	assert_float(half).is_equal_approx(_def.shake_explosion_max * 0.5, 0.0001)
	assert_float(FeedbackMath.explosion_shake(_def.shake_explosion_range_m, _def)).is_equal(0.0)
	assert_float(FeedbackMath.explosion_shake(99999.0, _def)).is_equal(0.0)


func test_the_indicator_angle_is_zero_at_the_top_and_runs_clockwise() -> void:
	assert_float(FeedbackMath.direction_angle(Vector3(0, 1, 0))).is_equal_approx(0.0, 0.0001)
	assert_float(FeedbackMath.direction_angle(Vector3(1, 0, 0))).is_equal_approx(PI * 0.5, 0.0001)
	assert_float(FeedbackMath.direction_angle(Vector3(0, -1, 0))).is_equal_approx(PI, 0.0001)
	assert_float(FeedbackMath.direction_angle(Vector3(-1, 0, 0))).is_equal_approx(-PI * 0.5, 0.0001)


func test_ahead_reads_as_the_top_and_behind_as_the_bottom() -> void:
	# Camera space: -z is ahead.
	assert_float(FeedbackMath.direction_angle(Vector3(0, 0, -1))).is_equal(0.0)
	assert_float(FeedbackMath.direction_angle(Vector3(0, 0, 1))).is_equal(PI)


func test_the_attacker_direction_points_at_the_shooter_else_the_hit_point() -> void:
	var shooter: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(shooter)
	shooter.global_position = Vector3(0, 0, -100)
	var info: DamageInfo = DamageInfo.make(5.0, DamageInfo.Type.ENERGY, shooter, Vector3(7, 0, 0))
	assert_vector(FeedbackMath.attacker_direction(Vector3.ZERO, info)).is_equal_approx(
		Vector3(0, 0, -1), Vector3.ONE * 0.0001
	)
	info.source = null
	assert_vector(FeedbackMath.attacker_direction(Vector3.ZERO, info)).is_equal_approx(
		Vector3(1, 0, 0), Vector3.ONE * 0.0001
	)
	info.hit_point = Vector3.ZERO
	assert_vector(FeedbackMath.attacker_direction(Vector3.ZERO, info)).is_equal(Vector3.ZERO)


func test_the_alarm_starts_low_and_only_stops_once_the_shield_has_recovered() -> void:
	assert_bool(FeedbackMath.alarm_on(false, 0.9, 100.0, _def)).is_false()
	assert_bool(FeedbackMath.alarm_on(false, _def.low_shield_fraction, 100.0, _def)).is_true()
	# Still low enough to keep going between the two thresholds.
	var between: float = (_def.low_shield_fraction + _def.low_shield_clear_fraction) * 0.5
	assert_bool(FeedbackMath.alarm_on(true, between, 100.0, _def)).is_true()
	assert_bool(FeedbackMath.alarm_on(false, between, 100.0, _def)).is_false()
	assert_bool(FeedbackMath.alarm_on(true, _def.low_shield_clear_fraction, 100.0, _def)).is_false()


func test_a_ship_without_a_shield_never_alarms() -> void:
	assert_bool(FeedbackMath.alarm_on(false, 0.0, 0.0, _def)).is_false()
	assert_bool(FeedbackMath.alarm_on(true, 0.0, 0.0, _def)).is_false()


func test_markers_fade_from_full_to_nothing() -> void:
	assert_float(FeedbackMath.fade(0.0, 0.5)).is_equal(1.0)
	assert_float(FeedbackMath.fade(0.25, 0.5)).is_equal_approx(0.5, 0.0001)
	assert_float(FeedbackMath.fade(0.5, 0.5)).is_equal(0.0)
	assert_float(FeedbackMath.fade(2.0, 0.5)).is_equal(0.0)
	assert_float(FeedbackMath.fade(0.1, 0.0)).is_equal(0.0)


func test_every_layer_has_a_label_key() -> void:
	for layer: int in DamageTable.Layer.values():
		assert_str(tr(FeedbackMath.layer_key(layer as DamageTable.Layer))).is_not_equal(
			FeedbackMath.layer_key(layer as DamageTable.Layer)
		)
