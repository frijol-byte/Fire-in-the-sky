extends GdUnitTestSuite
## `EngineFx`: the throttle-to-glow mapping and the ribbon maths. The glows and trails on a
## real ship are covered by `tests/sim/test_engine_fx_sim.gd`.


func test_idle_throttle_gives_the_idle_level_and_full_throttle_gives_one() -> void:
	assert_float(EngineFx.target_level(0.0, false)).is_equal(EngineFx.IDLE_LEVEL)
	assert_float(EngineFx.target_level(1.0, false)).is_equal(1.0)
	assert_float(EngineFx.target_level(-1.0, false)).is_equal(EngineFx.IDLE_LEVEL)
	assert_float(EngineFx.target_level(0.5, false)).is_between(EngineFx.IDLE_LEVEL, 1.0)


func test_boosting_is_always_full_level() -> void:
	assert_float(EngineFx.target_level(0.0, true)).is_equal(1.0)


func test_the_level_eases_towards_its_target() -> void:
	var level: float = EngineFx.level_step(0.0, 1.0, 1.0 / 60.0)
	assert_float(level).is_between(0.0, 1.0)
	for _step: int in 120:
		level = EngineFx.level_step(level, 1.0, 1.0 / 60.0)
	assert_float(level).is_greater(0.99)


func test_glow_and_trail_grow_with_level_and_boost() -> void:
	assert_float(EngineFx.glow_size(1.0, 0.0)).is_greater(EngineFx.glow_size(0.2, 0.0))
	assert_float(EngineFx.glow_size(1.0, 1.0)).is_greater(EngineFx.glow_size(1.0, 0.0))
	assert_float(EngineFx.trail_width(1.0, 0.0)).is_greater(EngineFx.trail_width(0.2, 0.0))
	assert_float(EngineFx.trail_width(1.0, 1.0)).is_greater(EngineFx.trail_width(1.0, 0.0))
	assert_float(EngineFx.glow_alpha(0.0)).is_between(0.0, 1.0)
	assert_float(EngineFx.glow_alpha(5.0)).is_equal(1.0)


func test_trim_keeps_the_newest_points_within_the_length() -> void:
	var points: PackedVector3Array = []
	for index: int in 11:
		points.append(Vector3(0.0, 0.0, float(index) * 10.0))
	var trimmed: PackedVector3Array = EngineFx.trim_to_length(points, 35.0)
	# 35 m of path: three 10 m gaps fit (4 points), a fourth does not.
	assert_int(trimmed.size()).is_equal(4)
	assert_vector(trimmed[trimmed.size() - 1]).is_equal(points[10])
	assert_int(EngineFx.trim_to_length(points, 1000.0).size()).is_equal(11)
	assert_int(EngineFx.trim_to_length(PackedVector3Array(), 10.0).size()).is_equal(0)


func test_ribbon_fades_out_close_to_the_camera() -> void:
	var points: PackedVector3Array = PackedVector3Array(
		[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, 2)]
	)
	var far_camera: Dictionary = EngineFx.ribbon(points, Vector3(0.0, 80.0, 1.0), 1.0, Color.WHITE)
	var near_camera: Dictionary = EngineFx.ribbon(points, Vector3(0.0, 3.0, 1.0), 1.0, Color.WHITE)
	assert_float((far_camera["colors"] as PackedColorArray)[5].a).is_greater(0.99)
	assert_float((near_camera["colors"] as PackedColorArray)[5].a).is_equal(0.0)


func test_ribbon_needs_two_points() -> void:
	var data: Dictionary = EngineFx.ribbon(
		PackedVector3Array([Vector3.ZERO]), Vector3.UP, 1.0, Color.WHITE
	)
	assert_int((data["vertices"] as PackedVector3Array).size()).is_equal(0)


func test_ribbon_has_two_vertices_per_point_and_tapers_to_a_point() -> void:
	var points: PackedVector3Array = []
	for index: int in 10:
		points.append(Vector3(0.0, 0.0, float(index) * 2.0))
	var data: Dictionary = EngineFx.ribbon(points, Vector3(0.0, 500.0, 10.0), 2.0, Color.WHITE)
	var vertices: PackedVector3Array = data["vertices"]
	var colors: PackedColorArray = data["colors"]
	assert_int(vertices.size()).is_equal(20)
	assert_int(colors.size()).is_equal(20)
	# The oldest point (first) has no width, the newest (last) has the full width.
	assert_float(vertices[0].distance_to(vertices[1])).is_equal_approx(0.0, 0.0001)
	assert_float(vertices[18].distance_to(vertices[19])).is_equal_approx(2.0, 0.0001)
	# And it fades out towards the oldest point.
	assert_float(colors[0].a).is_equal_approx(0.0, 0.0001)
	assert_float(colors[19].a).is_greater(0.99)


func test_ribbon_faces_the_camera() -> void:
	# A trail along Z seen from above (+Y) is widened along X; seen from the side (+X), along Y.
	var points: PackedVector3Array = PackedVector3Array(
		[Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, 2)]
	)
	var from_above: Dictionary = EngineFx.ribbon(points, Vector3(0.0, 40.0, 1.0), 2.0, Color.WHITE)
	var top: PackedVector3Array = from_above["vertices"]
	var across: Vector3 = (top[4] - top[5]).normalized()
	assert_float(absf(across.x)).is_greater(0.99)
	var from_side: Dictionary = EngineFx.ribbon(points, Vector3(40.0, 0.0, 1.0), 2.0, Color.WHITE)
	var side: PackedVector3Array = from_side["vertices"]
	var across_side: Vector3 = (side[4] - side[5]).normalized()
	assert_float(absf(across_side.y)).is_greater(0.99)


func test_ribbon_copes_with_a_camera_in_line_with_the_trail() -> void:
	var points: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, 1)])
	var data: Dictionary = EngineFx.ribbon(points, Vector3(0.0, 0.0, 50.0), 1.0, Color.WHITE)
	for vertex: Vector3 in data["vertices"] as PackedVector3Array:
		assert_bool(is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z)).is_true()
