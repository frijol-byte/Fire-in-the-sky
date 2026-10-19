extends GdUnitTestSuite
## `SkyBaker`: the cube face table (the shader holds the same one), the shader parameters, and
## the headless fallback. The picture itself is checked with the screenshot harness.

const FLIGHT_TEST: ArenaDef = preload("res://data/arenas/flight_test.tres")

const FACE_AXES: Array[Vector3] = [
	Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD
]


func test_each_face_centre_looks_along_its_axis() -> void:
	for face: int in FACE_AXES.size():
		var direction: Vector3 = SkyBaker.face_direction(face, Vector2(0.5, 0.5))
		assert_vector(direction).is_equal_approx(FACE_AXES[face], Vector3.ONE * 0.0001)


func test_face_directions_are_unit_vectors_that_stay_on_their_face() -> void:
	for face: int in FACE_AXES.size():
		for uv: Vector2 in [Vector2.ZERO, Vector2(1.0, 0.0), Vector2(0.2, 0.9), Vector2.ONE]:
			var direction: Vector3 = SkyBaker.face_direction(face, uv)
			assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
			assert_float(direction.dot(FACE_AXES[face])).is_greater(0.5)


func test_the_corners_of_neighbouring_faces_meet() -> void:
	# The right edge of +X is the left edge of -Z (looking from inside, going round the horizon).
	var a: Vector3 = SkyBaker.face_direction(0, Vector2(1.0, 0.5))
	var b: Vector3 = SkyBaker.face_direction(5, Vector2(0.0, 0.5))
	assert_vector(a).is_equal_approx(b, Vector3.ONE * 0.0001)
	# And the right edge of -Z is the left edge of -X.
	var c: Vector3 = SkyBaker.face_direction(5, Vector2(1.0, 0.5))
	var d: Vector3 = SkyBaker.face_direction(1, Vector2(0.0, 0.5))
	assert_vector(c).is_equal_approx(d, Vector3.ONE * 0.0001)


func test_the_parameters_come_from_the_arena() -> void:
	var parameters: Dictionary = SkyBaker.bake_parameters(FLIGHT_TEST)
	assert_float(parameters["seed"] as float).is_equal(FLIGHT_TEST.sky_seed)
	assert_vector(parameters["sun_direction"] as Vector3).is_equal_approx(
		FLIGHT_TEST.sky_sun_direction.normalized(), Vector3.ONE * 0.0001
	)
	assert_float(parameters["sun_radius"] as float).is_equal_approx(
		deg_to_rad(FLIGHT_TEST.sky_sun_radius_deg), 0.0001
	)


func test_a_headless_run_cannot_bake_and_returns_no_sky() -> void:
	if SkyBaker.can_bake():
		return
	var baker: SkyBaker = auto_free(SkyBaker.new())
	add_child(baker)
	var sky: Sky = await baker.bake(FLIGHT_TEST)
	assert_object(sky).is_null()
