extends GdUnitTestSuite
## The three player ships (GDD 4.4): their `ShipDef` numbers, how they differ and what their
## models promise (size, sockets, tiers, collision, paint).

## GDD 4.4 starting values: max speed, boost max, forward accel, strafe accel, pitch/yaw, roll.
const GDD: Dictionary[StringName, Array] = {
	&"kestrel": [180.0, 320.0, 60.0, 110.0, 90.0, 150.0],
	&"bulwark": [140.0, 260.0, 45.0, 78.0, 65.0, 110.0],
	&"drayman": [110.0, 200.0, 30.0, 54.0, 40.0, 70.0],
}
## Length range in metres per ship (GDD 4.4: fighters 12-20 m, freighters ~35 m).
const LENGTH: Dictionary[StringName, Vector2] = {
	&"kestrel": Vector2(12.0, 16.0),
	&"bulwark": Vector2(16.0, 20.0),
	&"drayman": Vector2(32.0, 38.0),
}


func ship_params() -> Array[Array]:
	var result: Array[Array] = []
	for ship_id: StringName in FlightSim.PLAYER_SHIP_IDS:
		result.append([ship_id])
	return result


func _manifest(def: ShipDef) -> Dictionary:
	var path: String = def.model_path.get_basename() + ".manifest.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _model(def: ShipDef, tier: int) -> ShipModel:
	var model: ShipModel = (load(def.model_path) as PackedScene).instantiate() as ShipModel
	model.tier = tier
	add_child(model)
	auto_free(model)
	return model


func test_every_ship_def_is_simulated() -> void:
	var ids: Array[StringName] = Content.ids(&"ship")
	assert_array(ids).contains_exactly_in_any_order(FlightSim.SHIP_IDS)


func test_the_def_is_valid_and_named(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()
	assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)


func test_the_def_has_the_gdd_starting_values(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	var gdd: Array = GDD[ship_id]
	assert_float(def.max_speed).is_equal(gdd[0] as float)
	assert_float(def.boost_max_speed).is_equal(gdd[1] as float)
	assert_float(def.accel_forward()).is_equal_approx(gdd[2] as float, 0.001)
	assert_float(def.accel_lateral()).is_equal_approx(gdd[3] as float, 0.001)
	assert_float(def.max_angular_rate_deg.x).is_equal(gdd[4] as float)
	assert_float(def.max_angular_rate_deg.y).is_equal(gdd[4] as float)
	assert_float(def.max_angular_rate_deg.z).is_equal(gdd[5] as float)


func test_heavier_ships_are_slower_and_turn_slower() -> void:
	var light: ShipDef = Content.ship(&"kestrel")
	var heavy: ShipDef = Content.ship(&"bulwark")
	var freighter: ShipDef = Content.ship(&"drayman")
	assert_float(light.mass).is_less(heavy.mass)
	assert_float(heavy.mass).is_less(freighter.mass)
	assert_float(light.max_speed).is_greater(heavy.max_speed)
	assert_float(heavy.max_speed).is_greater(freighter.max_speed)
	assert_float(light.accel_forward()).is_greater(heavy.accel_forward())
	assert_float(heavy.accel_forward()).is_greater(freighter.accel_forward())
	assert_float(light.max_angular_rate_deg.y).is_greater(heavy.max_angular_rate_deg.y)
	assert_float(heavy.max_angular_rate_deg.y).is_greater(freighter.max_angular_rate_deg.y)
	# The bigger the ship, the further back the chase camera sits.
	assert_float(light.chase_offset.z).is_less(heavy.chase_offset.z)
	assert_float(heavy.chase_offset.z).is_less(freighter.chase_offset.z)


func test_each_ship_has_its_own_paint() -> void:
	var seen: Array[Color] = []
	for ship_id: StringName in FlightSim.PLAYER_SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		assert_array(seen).not_contains([def.paint_primary])
		seen.append(def.paint_primary)


func test_the_model_has_the_class_length(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var size: Array = (
		((_manifest(Content.ship(ship_id))["bounds"] as Dictionary)["T0"] as Dictionary)["size"]
		as Array
	)
	var range: Vector2 = LENGTH[ship_id]
	assert_float(size[1] as float).is_between(range.x, range.y)


func test_the_model_has_the_sockets_a_ship_needs(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	var model: ShipModel = _model(def, 0)
	assert_array(model.get_sockets(&"primary")).has_size(def.primary_slots)
	assert_array(model.get_sockets(&"secondary")).has_size(def.secondary_slots)
	assert_array(model.get_sockets(&"engine")).is_not_empty()
	assert_array(model.get_sockets(&"cockpit_cam")).has_size(1)
	# The extra primary exists only on a T3 ship.
	model.set_tier(3)
	assert_array(model.get_sockets(&"primary")).has_size(def.primary_slots + 1)


func test_every_tier_adds_parts(ship_id: StringName, _test_parameters := ship_params()) -> void:
	var manifest: Dictionary = _manifest(Content.ship(ship_id))
	var tier_parts: Dictionary = manifest["tier_parts"] as Dictionary
	for group: String in ["T1", "T2", "T3"]:
		assert_array(tier_parts[group] as Array).is_not_empty()
	assert_array(tier_parts["T0ONLY"] as Array).is_not_empty()
	assert_array(manifest["collision"] as Array).has_size(1)


func test_the_model_has_a_collision_hull_and_paint(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var model: ShipModel = _model(Content.ship(ship_id), 0)
	var body: StaticBody3D = model.get_node("Collision") as StaticBody3D
	assert_object((body.get_child(0) as CollisionShape3D).shape).is_instanceof(ConvexPolygonShape3D)
	var hull: MeshInstance3D = model.get_node("hull") as MeshInstance3D
	assert_bool(hull.get_meta(&"paint", false) as bool).is_true()
