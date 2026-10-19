extends GdUnitTestSuite
## The pure maths of `CameraRig`: smoothing, the chase pose, FOV kick, shake decay, clearance and
## free look. The rig flying a real ship is covered by `tests/sim/test_camera_rig_sim.gd`.

const KESTREL: ShipDef = preload("res://data/ships/kestrel.tres")


func test_smooth_weight_is_one_without_lag_and_frame_rate_independent() -> void:
	assert_float(CameraRig.smooth_weight(0.016, 0.0)).is_equal(1.0)
	assert_float(CameraRig.smooth_weight(0.2, 0.2)).is_equal_approx(1.0 - exp(-1.0), 0.0001)
	# Two half steps close the same fraction as one whole step.
	var half: float = CameraRig.smooth_weight(0.05, 0.2)
	var whole: float = CameraRig.smooth_weight(0.1, 0.2)
	assert_float(1.0 - (1.0 - half) * (1.0 - half)).is_equal_approx(whole, 0.0001)


func test_chase_pose_sits_behind_and_above_and_looks_forward() -> void:
	var pose: Transform3D = CameraRig.chase_pose_for(
		Transform3D.IDENTITY, KESTREL, Basis.IDENTITY, 0.0
	)
	assert_vector(pose.origin).is_equal_approx(KESTREL.chase_offset, Vector3.ONE * 0.001)
	var forward: Vector3 = -pose.basis.z
	assert_float(forward.z).is_less(-0.99)
	# Looks slightly down at the point ahead of the ship, never up.
	assert_float(forward.y).is_less_equal(0.0)
	assert_float(forward.x).is_equal_approx(0.0, 0.0001)


func test_chase_pose_follows_the_ship_orientation_and_position() -> void:
	var ship_basis: Basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var ship_transform: Transform3D = Transform3D(ship_basis, Vector3(100.0, 50.0, -20.0))
	var pose: Transform3D = CameraRig.chase_pose_for(ship_transform, KESTREL, Basis.IDENTITY, 0.0)
	# A yaw of +90 degrees turns the ship's nose to -X, so "behind" is +X.
	var offset: Vector3 = pose.origin - ship_transform.origin
	assert_float(offset.x).is_equal_approx(KESTREL.chase_offset.z, 0.001)
	assert_float(offset.y).is_equal_approx(KESTREL.chase_offset.y, 0.001)
	assert_float((-pose.basis.z).x).is_less(-0.99)


func test_speed_pulls_the_chase_camera_back() -> void:
	var slow: Transform3D = CameraRig.chase_pose_for(
		Transform3D.IDENTITY, KESTREL, Basis.IDENTITY, 0.0
	)
	var fast: Transform3D = CameraRig.chase_pose_for(
		Transform3D.IDENTITY, KESTREL, Basis.IDENTITY, 1.0
	)
	assert_float(fast.origin.z - slow.origin.z).is_equal_approx(KESTREL.chase_speed_pullback, 0.001)


func test_free_look_basis_turns_the_view_the_way_the_stick_points() -> void:
	var right: Vector3 = -CameraRig.free_look_basis(Vector2(PI / 2.0, 0.0)).z
	assert_float(right.x).is_equal_approx(1.0, 0.0001)
	var up: Vector3 = -CameraRig.free_look_basis(Vector2(0.0, PI / 2.0)).z
	assert_float(up.y).is_equal_approx(1.0, 0.0001)
	assert_object(CameraRig.free_look_basis(Vector2.ZERO)).is_equal(Basis.IDENTITY)


func test_looking_back_in_free_look_puts_the_chase_camera_in_front() -> void:
	var look: Basis = CameraRig.free_look_basis(Vector2(PI, 0.0))
	var pose: Transform3D = CameraRig.chase_pose_for(Transform3D.IDENTITY, KESTREL, look, 0.0)
	assert_float(pose.origin.z).is_equal_approx(-KESTREL.chase_offset.z, 0.001)
	assert_float((-pose.basis.z).z).is_greater(0.99)


func test_boost_fov_adds_the_kick_and_clamps_the_amount() -> void:
	assert_float(CameraRig.boost_fov(75.0, 8.0, 0.0)).is_equal(75.0)
	assert_float(CameraRig.boost_fov(75.0, 8.0, 1.0)).is_equal(83.0)
	assert_float(CameraRig.boost_fov(75.0, 8.0, 0.5)).is_equal(79.0)
	assert_float(CameraRig.boost_fov(75.0, 8.0, 3.0)).is_equal(83.0)


func test_shake_fades_to_nothing_over_its_duration() -> void:
	assert_float(CameraRig.shake_amplitude(0.8, 0.0, 1.0)).is_equal(0.8)
	assert_float(CameraRig.shake_amplitude(0.8, 0.5, 1.0)).is_equal_approx(0.2, 0.0001)
	assert_float(CameraRig.shake_amplitude(0.8, 1.0, 1.0)).is_equal(0.0)
	assert_float(CameraRig.shake_amplitude(0.8, 2.0, 1.0)).is_equal(0.0)
	assert_float(CameraRig.shake_amplitude(0.8, 0.0, 0.0)).is_equal(0.0)


func test_clearance_pulls_in_at_once_and_eases_back_out() -> void:
	assert_float(CameraRig.clearance_step(1.0, 0.4, 0.016, 0.4)).is_equal(0.4)
	var back: float = CameraRig.clearance_step(0.4, 1.0, 0.1, 0.4)
	assert_float(back).is_greater(0.4)
	assert_float(back).is_less(1.0)
	# It never overshoots the free distance, however long the frame.
	assert_float(CameraRig.clearance_step(0.4, 1.0, 100.0, 0.4)).is_equal_approx(1.0, 0.0001)
	assert_float(CameraRig.clearance_step(0.4, 0.4, 0.016, 0.4)).is_equal(0.4)


func test_the_kestrel_camera_data_is_valid() -> void:
	assert_array(KESTREL.problems()).is_empty()
	var bad: ShipDef = KESTREL.duplicate() as ShipDef
	bad.chase_offset = Vector3(0.0, 4.0, -1.0)
	bad.chase_rotation_lag = -1.0
	bad.canopy_path = "res://nope.glb"
	var found: String = ", ".join(bad.problems())
	assert_str(found).contains("chase_offset.z")
	assert_str(found).contains("lag")
	assert_str(found).contains("canopy_path")
