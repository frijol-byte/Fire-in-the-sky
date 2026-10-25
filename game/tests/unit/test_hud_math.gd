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


func test_marker_at_projects_a_real_point() -> void:
	var camera: Camera3D = _camera()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var ahead: HudMath.Marker = HudMath.marker_at(camera, Vector3(0, 0, -250), size, MARGIN)
	assert_bool(ahead.on_screen).is_true()
	assert_vector(ahead.position).is_equal_approx(size * 0.5, Vector2.ONE * 1.0)
	var right: HudMath.Marker = HudMath.marker_at(camera, Vector3(40, 0, -250), size, MARGIN)
	assert_float(right.position.x).is_greater(size.x * 0.5)
	var behind: HudMath.Marker = HudMath.marker_at(camera, Vector3(0, 0, 100), size, MARGIN)
	assert_bool(behind.behind).is_true()
	assert_bool(behind.on_screen).is_false()


func test_marker_at_matches_marker_for_a_far_point() -> void:
	var camera: Camera3D = _camera()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var by_direction: HudMath.Marker = HudMath.marker_for(
		camera, Vector3.ZERO, Vector3(0.2, 0.1, -1), size, MARGIN
	)
	var by_point: HudMath.Marker = HudMath.marker_at(
		camera, Vector3(0.2, 0.1, -1).normalized() * HudMath.MARKER_DISTANCE, size, MARGIN
	)
	assert_vector(by_point.position).is_equal_approx(by_direction.position, Vector2.ONE * 0.01)


func test_projected_radius_shrinks_with_distance_and_grows_with_size() -> void:
	var near: float = HudMath.projected_radius(6.0, 100.0, 75.0, 1080.0)
	var far: float = HudMath.projected_radius(6.0, 400.0, 75.0, 1080.0)
	assert_float(near).is_greater(far)
	assert_float(near / far).is_equal_approx(4.0, 0.001)
	assert_float(HudMath.projected_radius(12.0, 100.0, 75.0, 1080.0)).is_equal_approx(
		near * 2.0, 0.001
	)
	# A target at the camera fills the view; a target of no size takes no room.
	assert_float(HudMath.projected_radius(6.0, 0.0, 75.0, 1080.0)).is_equal(1080.0)
	assert_float(HudMath.projected_radius(0.0, 100.0, 75.0, 1080.0)).is_equal(0.0)


func test_projected_radius_is_what_the_camera_draws() -> void:
	var camera: Camera3D = _camera()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var centre: Vector2 = camera.unproject_position(Vector3(0, 0, -200))
	var edge: Vector2 = camera.unproject_position(Vector3(0, 10, -200))
	var predicted: float = HudMath.projected_radius(10.0, 200.0, camera.fov, size.y)
	assert_float(centre.distance_to(edge)).is_equal_approx(predicted, 0.5)


func test_distance_text_switches_to_kilometres() -> void:
	assert_str(HudMath.distance_text(320.4)).is_equal("320 m")
	assert_str(HudMath.distance_text(999.0)).is_equal("999 m")
	assert_str(HudMath.distance_text(1200.0)).is_equal("1.2 km")


func test_bracket_shapes_differ_by_stance() -> void:
	var hostile: Array[PackedVector2Array] = HudMath.bracket_strokes(Targeting.Stance.HOSTILE, 30.0)
	var neutral: Array[PackedVector2Array] = HudMath.bracket_strokes(Targeting.Stance.NEUTRAL, 30.0)
	var friendly: Array[PackedVector2Array] = HudMath.bracket_strokes(
		Targeting.Stance.FRIENDLY, 30.0
	)
	for strokes: Array[PackedVector2Array] in [hostile, neutral, friendly]:
		assert_int(strokes.size()).is_equal(4)
	# Square corners are three points, arcs have many, so the shapes cannot be mistaken.
	assert_int(hostile[0].size()).is_equal(3)
	assert_int(friendly[0].size()).is_equal(3)
	assert_int(neutral[0].size()).is_greater(3)
	assert_bool(hostile[0] == friendly[0]).is_false()


func test_hostile_brackets_sit_on_the_square_and_neutral_arcs_on_the_circle() -> void:
	for stroke: PackedVector2Array in HudMath.bracket_strokes(Targeting.Stance.HOSTILE, 30.0):
		# The corner is the middle point.
		assert_float(absf(stroke[1].x)).is_equal_approx(30.0, 0.001)
		assert_float(absf(stroke[1].y)).is_equal_approx(30.0, 0.001)
	for stroke: PackedVector2Array in HudMath.bracket_strokes(Targeting.Stance.NEUTRAL, 30.0):
		for point: Vector2 in stroke:
			assert_float(point.length()).is_equal_approx(30.0, 0.001)


func test_friendly_brackets_form_a_diamond() -> void:
	for stroke: PackedVector2Array in HudMath.bracket_strokes(Targeting.Stance.FRIENDLY, 30.0):
		var vertex: Vector2 = stroke[1]
		# A diamond's corners are on the axes.
		var on_axis: bool = absf(vertex.x) < 0.001 or absf(vertex.y) < 0.001
		assert_bool(on_axis).is_true()


func test_arrow_points_point_along_the_direction() -> void:
	var tip_right: PackedVector2Array = HudMath.arrow_points(Vector2(100, 100), Vector2.RIGHT, 10.0)
	assert_vector(tip_right[0]).is_equal_approx(Vector2(110, 100), Vector2.ONE * 0.001)
	assert_float(tip_right[1].x).is_less(100.0)
	assert_float(tip_right[2].x).is_less(100.0)
	var tip_up: PackedVector2Array = HudMath.arrow_points(Vector2(100, 100), Vector2.UP, 10.0)
	assert_vector(tip_up[0]).is_equal_approx(Vector2(100, 90), Vector2.ONE * 0.001)
	# Zero direction still gives a drawable arrow.
	assert_int(HudMath.arrow_points(Vector2.ZERO, Vector2.ZERO, 10.0).size()).is_equal(3)


func test_stance_and_lock_keys_have_strings() -> void:
	var keys: Array[StringName] = []
	for stance: int in Targeting.Stance.values():
		keys.append(HudMath.stance_key(stance as Targeting.Stance))
	keys.append(HudMath.lock_key(Targeting.Lock.OUT_OF_RANGE))
	keys.append(HudMath.lock_key(Targeting.Lock.OCCLUDED))
	keys.append_array([&"HUD_SHIELD", &"HUD_ARMOR", &"HUD_HULL"])
	for key: StringName in keys:
		assert_str(TranslationServer.translate(key)).is_not_equal(str(key))
	assert_str(String(HudMath.lock_key(Targeting.Lock.LOCKED))).is_empty()
