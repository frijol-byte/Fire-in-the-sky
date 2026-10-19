extends GdUnitTestSuite
## `HudMath`: marker projection, edge pinning and the boost line.

const VIEW: Vector2 = Vector2(1920.0, 1080.0)
const MARGIN: float = 50.0


func _camera() -> Camera3D:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.make_current()
	return camera


func test_clamp_to_edge_keeps_points_inside() -> void:
	var point: Vector2 = Vector2(900.0, 500.0)
	assert_vector(HudMath.clamp_to_edge(point, VIEW, MARGIN)).is_equal(point)


func test_clamp_to_edge_pins_to_the_inset_border_on_the_line_from_the_center() -> void:
	var pinned: Vector2 = HudMath.clamp_to_edge(Vector2(4000.0, 540.0), VIEW, MARGIN)
	assert_vector(pinned).is_equal_approx(Vector2(VIEW.x - MARGIN, 540.0), Vector2.ONE * 0.01)
	var diagonal: Vector2 = HudMath.clamp_to_edge(Vector2(-3000.0, -3000.0), VIEW, MARGIN)
	assert_float(diagonal.y).is_equal_approx(MARGIN, 0.01)
	# Still on the line through the center.
	var center: Vector2 = VIEW * 0.5
	assert_float((diagonal - center).angle()).is_equal_approx((Vector2(-1, -1)).angle(), 0.5)


func test_marker_straight_ahead_is_at_the_screen_center() -> void:
	var camera: Camera3D = _camera()
	var marker: HudMath.Marker = HudMath.marker_for(
		camera, Vector3.ZERO, Vector3(0, 0, -1), get_viewport().get_visible_rect().size, MARGIN
	)
	assert_bool(marker.on_screen).is_true()
	assert_bool(marker.behind).is_false()
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	assert_vector(marker.position).is_equal_approx(center, Vector2.ONE * 1.0)


func test_marker_to_the_side_is_off_center_and_far_side_is_pinned() -> void:
	var camera: Camera3D = _camera()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var slight: HudMath.Marker = HudMath.marker_for(
		camera, Vector3.ZERO, Vector3(0.2, 0, -1), size, MARGIN
	)
	assert_float(slight.position.x).is_greater(size.x * 0.5)
	assert_bool(slight.on_screen).is_true()
	var wide: HudMath.Marker = HudMath.marker_for(
		camera, Vector3.ZERO, Vector3(5, 0, -1), size, MARGIN
	)
	assert_bool(wide.on_screen).is_false()
	assert_float(wide.position.x).is_equal_approx(size.x - MARGIN, 0.01)


func test_marker_behind_the_camera_is_pinned_toward_the_turn_direction() -> void:
	var camera: Camera3D = _camera()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var behind: HudMath.Marker = HudMath.marker_for(
		camera, Vector3.ZERO, Vector3(1, 0, 1), size, MARGIN
	)
	assert_bool(behind.behind).is_true()
	assert_bool(behind.on_screen).is_false()
	# Behind and to the right: pinned on the right side.
	assert_float(behind.position.x).is_greater(size.x * 0.5)


func test_boost_state_priority() -> void:
	var s: HudMath.BoostState = HudMath.boost_state(true, true, 0.0, 10.0)
	assert_int(s).is_equal(HudMath.BoostState.ACTIVE)
	assert_int(HudMath.boost_state(false, true, 50.0, 10.0)).is_equal(HudMath.BoostState.EMPTY)
	assert_int(HudMath.boost_state(false, false, 5.0, 10.0)).is_equal(HudMath.BoostState.CHARGING)
	assert_int(HudMath.boost_state(false, false, 10.0, 10.0)).is_equal(HudMath.BoostState.READY)


func test_every_hud_key_has_a_string() -> void:
	var keys: Array[StringName] = [&"HUD_SPEED", &"HUD_ENERGY"]
	for state: int in HudMath.BoostState.values():
		keys.append(HudMath.boost_key(state as HudMath.BoostState))
	keys.append(HudMath.assist_key(true))
	keys.append(HudMath.assist_key(false))
	for key: StringName in keys:
		assert_str(TranslationServer.translate(key)).is_not_equal(str(key))
