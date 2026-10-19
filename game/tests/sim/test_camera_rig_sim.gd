extends GdUnitTestSuite
## `CameraRig` following a real `Ship`: rigid translation, lag when turning, FOV kick, clearance
## from walls, the cockpit blend and shake. The rig is stepped by hand (one `update` per physics
## tick) so the timing is exact.

var _ship: Ship = null
var _rig: CameraRig = null


func before_test() -> void:
	Settings.values.clear()
	# The first physics frame of a suite is not a full tick for a freshly added body.
	await get_tree().physics_frame
	_ship = FlightSim.spawn(self)
	_rig = (load("res://ships/camera_rig.tscn") as PackedScene).instantiate() as CameraRig
	add_child(_rig)
	_rig.set_process(false)
	_rig.attach(_ship)


func after_test() -> void:
	# Ships left in the tree would sit in the camera's way in the next test.
	remove_child(_rig)
	_rig.free()
	remove_child(_ship)
	_ship.free()
	Settings.values.clear()
	Input.flush_buffered_events()
	for action: String in InputRouter.ACTIONS:
		Input.action_release(action)


func _step(ticks: int, held: ShipControls = null) -> void:
	for tick: int in ticks:
		if held != null:
			_ship.controls = held
		await get_tree().physics_frame
		_rig.update(SimHelper.TICK)


## The angle in degrees between where the camera looks and where the chase pose says it should.
func _angle_from_ideal() -> float:
	var ideal: Transform3D = CameraRig.chase_pose_for(
		_ship.global_transform, _ship.def, Basis.IDENTITY, _speed_fraction()
	)
	return rad_to_deg((-ideal.basis.z).angle_to(-_rig.camera.global_basis.z))


func _speed_fraction() -> float:
	return clampf(_ship.linear_velocity.length() / _ship.def.boost_max_speed, 0.0, 1.0)


func _camera_offset_in_ship_axes() -> Vector3:
	return (
		_ship.global_basis.orthonormalized().inverse()
		* (_rig.camera.global_position - _ship.global_position)
	)


func test_flying_straight_keeps_the_camera_at_the_chase_offset() -> void:
	await _step(120, FlightSim.controls(Vector3(0.0, 0.0, 1.0)))
	# Top speed is not reached yet at 2 s, but the camera is already pulled back a little.
	var offset: Vector3 = _camera_offset_in_ship_axes()
	assert_float(offset.y).is_equal_approx(_ship.def.chase_offset.y, 0.05)
	assert_float(offset.z).is_between(
		_ship.def.chase_offset.z, _ship.def.chase_offset.z + _ship.def.chase_speed_pullback + 0.1
	)
	assert_float(offset.x).is_equal_approx(0.0, 0.05)
	# It looks where the ship is going.
	var forward: Vector3 = -_rig.camera.global_basis.z
	assert_float(forward.dot(-_ship.global_basis.z)).is_greater(0.99)


func test_camera_lags_a_turn_and_catches_up_when_it_ends() -> void:
	await _step(60, FlightSim.controls(Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0)))
	var ship_forward: Vector3 = -_ship.global_basis.z
	var camera_forward: Vector3 = -_rig.camera.global_basis.z
	var lag_degrees: float = rad_to_deg(ship_forward.angle_to(camera_forward))
	# The ship is turning at 90 deg/s: the camera trails by a visible but modest angle.
	assert_float(lag_degrees).is_between(3.0, 30.0)
	await _step(180, FlightSim.controls(Vector3(0.0, 0.0, 1.0)))
	assert_float(_angle_from_ideal()).is_less(0.5)


func test_zero_lag_makes_the_camera_rigid() -> void:
	_ship.def = _ship.def.duplicate() as ShipDef
	_ship.def.chase_position_lag = 0.0
	_ship.def.chase_rotation_lag = 0.0
	await _step(45, FlightSim.controls(Vector3.ZERO, Vector3(0.5, 1.0, 0.5)))
	var ship_forward: Vector3 = -_ship.global_basis.z
	var camera_forward: Vector3 = -_rig.camera.global_basis.z
	# Only the fixed downward look at the aim point separates them.
	assert_float(rad_to_deg(ship_forward.angle_to(camera_forward))).is_less(5.0)
	var offset: Vector3 = _camera_offset_in_ship_axes()
	assert_float(offset.y).is_equal_approx(_ship.def.chase_offset.y, 0.05)


func test_boost_kicks_the_fov_up_and_it_settles_back() -> void:
	var base: float = _ship.def.base_fov
	assert_float(_rig.camera.fov).is_equal_approx(base, 0.001)
	var boosting: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	boosting.boost = true
	await _step(120, boosting)
	assert_float(_rig.camera.fov).is_equal_approx(base + _ship.def.boost_fov_kick, 0.2)
	await _step(240, FlightSim.controls())
	assert_float(_rig.camera.fov).is_equal_approx(base, 0.2)


func test_the_fov_kick_ends_when_boost_runs_out_of_energy() -> void:
	var boosting: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	boosting.boost = true
	await _step(60, boosting)
	assert_bool(_ship.is_boosting()).is_true()
	# Boost stays held, but the capacitor is empty: boost cuts out and so does the kick.
	_ship.power().energy = 0.0
	await _step(240, boosting)
	assert_bool(_ship.is_boosting()).is_false()
	assert_float(_rig.camera.fov).is_equal_approx(_ship.def.base_fov, 0.3)


func test_no_fov_kick_when_boost_is_held_with_an_empty_capacitor() -> void:
	_ship.power().energy = 0.0
	var boosting: ShipControls = FlightSim.controls(Vector3(0.0, 0.0, 1.0))
	boosting.boost = true
	await _step(30, boosting)
	assert_bool(_ship.is_boosting()).is_false()
	assert_float(_rig.camera.fov).is_equal_approx(_ship.def.base_fov, 0.2)


func test_a_wall_behind_the_ship_pulls_the_camera_in_and_it_recovers() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 200.0, 2.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = Vector3(0.0, 0.0, 9.0)
	await _step(30)
	var distance: float = _rig.camera.global_position.distance_to(_ship.global_position)
	assert_float(distance).is_less(8.0)
	assert_float(distance).is_greater(1.0)
	# The camera stays on the ship's side of the wall.
	assert_float(_rig.camera.global_position.z).is_less(8.0)
	remove_child(wall)
	wall.free()
	await _step(240)
	var recovered: float = _rig.camera.global_position.distance_to(_ship.global_position)
	assert_float(recovered).is_greater(14.0)


func test_toggle_blends_into_the_cockpit_and_back() -> void:
	var seen: Array[int] = []
	_rig.view_changed.connect(func(view: int) -> void: seen.append(view))
	_rig.toggle_view()
	await _step(int(CameraRig.BLEND_TIME * 60.0) + 3)
	assert_bool(_rig.is_cockpit()).is_true()
	var sockets: Array[Marker3D] = _ship.model.get_sockets(&"cockpit_cam")
	assert_vector(_rig.camera.global_position).is_equal_approx(
		sockets[0].global_position, Vector3.ONE * 0.001
	)
	assert_bool(_ship.model.visible).is_false()
	_rig.toggle_view()
	await _step(int(CameraRig.BLEND_TIME * 60.0) + 120)
	assert_bool(_ship.model.visible).is_true()
	assert_bool(_rig.is_cockpit()).is_false()
	assert_array(seen).is_equal([CameraRig.View.COCKPIT, CameraRig.View.CHASE])


func test_the_blend_is_gradual() -> void:
	_rig.toggle_view()
	await _step(5)
	var chase_distance: float = _ship.def.chase_offset.length()
	var distance: float = _rig.camera.global_position.distance_to(_ship.global_position)
	assert_float(distance).is_less(chase_distance)
	assert_float(distance).is_greater(1.0)
	assert_bool(_ship.model.visible).is_true()


func test_the_cockpit_view_shows_a_canopy_and_looks_along_the_nose() -> void:
	_rig.set_view(CameraRig.View.COCKPIT)
	await _step(60)
	var canopies: Array[Node] = _rig.get_children().filter(
		func(n: Node) -> bool: return n is Node3D
	)
	assert_array(canopies).is_not_empty()
	assert_float((-_rig.camera.global_basis.z).dot(-_ship.global_basis.z)).is_greater(0.999)


func test_shake_moves_the_camera_then_dies_away() -> void:
	await _step(10)
	var calm: Vector3 = _rig.camera.global_position
	_rig.shake(1.0, 0.5)
	await _step(8)
	# The ship is still, so any camera movement is the shake.
	assert_float(_rig.camera.global_position.distance_to(calm)).is_greater(0.01)
	assert_float(_rig.camera.global_position.distance_to(calm)).is_less(1.0)
	await _step(60)
	assert_float(_rig.shake_now()).is_equal(0.0)
	assert_vector(_rig.camera.global_position).is_equal_approx(calm, Vector3.ONE * 0.01)


func test_shake_can_be_turned_off_in_settings() -> void:
	await _step(10)
	var calm: Vector3 = _rig.camera.global_position
	Settings.set_value(CameraRig.SETTING_SHAKE, 0.0)
	_rig.shake(1.0, 0.5)
	await _step(8)
	assert_vector(_rig.camera.global_position).is_equal_approx(calm, Vector3.ONE * 0.001)


func test_a_weaker_shake_does_not_cut_a_stronger_one_short() -> void:
	_rig.shake(1.0, 1.0)
	_rig.shake(0.2, 0.2)
	assert_float(_rig.shake_now()).is_equal_approx(1.0, 0.0001)


func test_free_look_is_off_by_default_and_turns_the_camera_when_enabled() -> void:
	Input.action_press("free_look")
	Input.action_press("yaw_right", 1.0)
	await _step(30)
	assert_float(rad_to_deg((-_rig.camera.global_basis.z).angle_to(-_ship.global_basis.z))).is_less(
		5.0
	)
	Settings.set_value(InputRouter.SETTING_FREE_LOOK, true)
	await _step(60)
	var forward: Vector3 = -_rig.camera.global_basis.z
	# The stick points right, so the view turns far to the right; the ship keeps pointing ahead.
	assert_float(forward.x).is_greater(0.4)
	assert_float(rad_to_deg(forward.angle_to(-_ship.global_basis.z))).is_greater(120.0)
	assert_float((-_ship.global_basis.z).z).is_less(-0.99)
	Input.action_release("free_look")
	Input.action_release("yaw_right")
	await _step(120)
	assert_float(rad_to_deg((-_rig.camera.global_basis.z).angle_to(-_ship.global_basis.z))).is_less(
		5.0
	)
