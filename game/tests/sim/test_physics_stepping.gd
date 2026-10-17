extends GdUnitTestSuite
## Example sim test: shows how to step physics N ticks headless and get the same answer every
## run. Copy this pattern for flight, AI and economy sims.

const VELOCITY: Vector3 = Vector3(0.0, 0.0, -30.0)
const TICKS: int = 60


func _run_drift() -> Vector3:
	var body: RigidBody3D = SimHelper.make_drifting_body(VELOCITY)
	add_child(body)
	await SimHelper.step_physics(get_tree(), TICKS)
	var end: Vector3 = body.global_position
	# Free immediately so the second run does not start inside the first body.
	remove_child(body)
	body.free()
	return end


func test_drifting_body_travels_velocity_times_time() -> void:
	var end: Vector3 = await _run_drift()
	var expected: Vector3 = VELOCITY * (TICKS * SimHelper.TICK)
	assert_vector(end).is_equal_approx(expected, Vector3(0.5, 0.5, 0.5))


func test_same_setup_gives_identical_result_twice() -> void:
	var first: Vector3 = await _run_drift()
	var second: Vector3 = await _run_drift()
	# Same ticks, same inputs: the body starts at the origin both times, so the end
	# positions must agree to within float noise.
	assert_vector(second).is_equal_approx(first, Vector3(0.01, 0.01, 0.01))
