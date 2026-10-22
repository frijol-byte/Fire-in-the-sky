extends GdUnitTestSuite
## Each player ship, spawned for real: its model, collision, paint, engine effects and both
## cameras. The flight sims (`test_flight_*`) cover how each one handles.

var _ship: Ship = null
var _rig: CameraRig = null


func ship_params() -> Array[Array]:
	return FlightSim.ship_params()


func _spawn(ship_id: StringName) -> void:
	Settings.values.clear()
	# The first physics frame of a suite is not a full tick for a freshly added body.
	await get_tree().physics_frame
	_ship = FlightSim.spawn(self, ship_id)
	_rig = (load("res://ships/camera_rig.tscn") as PackedScene).instantiate() as CameraRig
	add_child(_rig)
	_rig.set_process(false)
	_rig.attach(_ship)


func after_test() -> void:
	if _rig != null:
		remove_child(_rig)
		_rig.free()
		_rig = null
	if _ship != null:
		remove_child(_ship)
		_ship.free()
		_ship = null
	Settings.values.clear()


func _step(ticks: int, held: ShipControls = null) -> void:
	for tick: int in ticks:
		if held != null:
			_ship.controls = held
		await get_tree().physics_frame
		_rig.update(SimHelper.TICK)


func test_the_ship_gets_its_mass_a_collision_shape_and_paint(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	await _spawn(ship_id)
	assert_float(_ship.mass).is_equal(_ship.def.mass)
	var shapes: int = 0
	for child: Node in _ship.get_children():
		if child is CollisionShape3D:
			shapes += 1
	assert_int(shapes).is_greater(0)
	var hull: MeshInstance3D = _ship.model.get_node("hull") as MeshInstance3D
	assert_that(hull.get_instance_shader_parameter(&"primary_color")).is_equal(
		_ship.def.paint_primary
	)
	assert_that(hull.get_instance_shader_parameter(&"secondary_color")).is_equal(
		_ship.def.paint_secondary
	)


func test_every_engine_socket_gets_a_glow_and_a_trail(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	await _spawn(ship_id)
	var fx: EngineFx = _ship.get_node("EngineFx") as EngineFx
	var sockets: Array[Marker3D] = _ship.model.get_sockets(&"engine")
	assert_int(fx.engine_count()).is_equal(sockets.size())
	for socket: Marker3D in sockets:
		assert_object(socket.get_node_or_null("Glow")).is_not_null()


func test_the_chase_camera_sits_at_the_ships_own_offset(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	await _spawn(ship_id)
	await _step(30)
	var offset: Vector3 = (
		_ship.global_basis.orthonormalized().inverse()
		* (_rig.camera.global_position - _ship.global_position)
	)
	assert_vector(offset).is_equal_approx(_ship.def.chase_offset, Vector3.ONE * 0.1)


func test_the_cockpit_camera_is_at_the_cockpit_socket(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	await _spawn(ship_id)
	_rig.set_view(CameraRig.View.COCKPIT)
	await _step(60)
	var socket: Marker3D = _ship.model.get_sockets(&"cockpit_cam")[0]
	assert_vector(_rig.camera.global_position).is_equal_approx(
		socket.global_position, Vector3.ONE * 0.001
	)
	assert_float((-_rig.camera.global_basis.z).dot(-_ship.global_basis.z)).is_greater(0.999)
