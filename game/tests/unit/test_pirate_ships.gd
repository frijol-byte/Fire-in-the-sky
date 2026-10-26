extends GdUnitTestSuite
## The Cinder Clans' ships (M2-T7): their defs, what their models promise (size, sockets, no tiers,
## one collision hull) and how they differ from the Concord ships they fight (art bible 2).

## Length range in metres per ship (GDD 8.1: fighters 12-20 m).
const LENGTH: Dictionary[StringName, Vector2] = {
	&"pirate_fighter": Vector2(14.0, 18.0),
	&"pirate_interceptor": Vector2(9.0, 13.0),
}


func ship_params() -> Array[Array]:
	var result: Array[Array] = []
	for ship_id: StringName in FlightSim.PIRATE_SHIP_IDS:
		result.append([ship_id])
	return result


func _manifest(def: ShipDef) -> Dictionary:
	var path: String = def.model_path.get_basename() + ".manifest.json"
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _model(def: ShipDef) -> ShipModel:
	var model: ShipModel = (load(def.model_path) as PackedScene).instantiate() as ShipModel
	add_child(model)
	auto_free(model)
	return model


func test_the_defs_are_valid_and_named(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var def: ShipDef = Content.ship(ship_id)
	assert_object(def).is_not_null()
	assert_array(def.problems()).is_empty()
	assert_str(tr(def.display_name_key)).is_not_equal(def.display_name_key)
	assert_object(Content.weapon(def.primary_weapon)).is_not_null()
	assert_object(Content.loot_table(def.loot_table_id)).is_not_null()


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
	var model: ShipModel = _model(def)
	assert_array(model.get_sockets(&"primary")).has_size(def.primary_slots)
	assert_array(model.get_sockets(&"secondary")).has_size(def.secondary_slots)
	assert_array(model.get_sockets(&"engine")).has_size(2)
	assert_array(model.get_sockets(&"cockpit_cam")).has_size(1)


func test_pirates_have_no_upgrade_tiers_and_one_collision_hull(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	var manifest: Dictionary = _manifest(Content.ship(ship_id))
	var tier_parts: Dictionary = manifest["tier_parts"] as Dictionary
	for group: String in ["T1", "T2", "T3", "T0ONLY"]:
		assert_array(tier_parts[group] as Array).is_empty()
	assert_array(manifest["collision"] as Array).has_size(1)
	var model: ShipModel = _model(Content.ship(ship_id))
	var body: StaticBody3D = model.get_node("Collision") as StaticBody3D
	assert_object((body.get_child(0) as CollisionShape3D).shape).is_instanceof(ConvexPolygonShape3D)


func test_pirate_ships_are_asymmetric(
	ship_id: StringName, _test_parameters := ship_params()
) -> void:
	# Art bible 2: the Cinder Clans' kit-bash is lopsided. The two wings differ in size.
	var parts: Dictionary = _manifest(Content.ship(ship_id))["parts"] as Dictionary
	var right: int = (parts["wing_R"] as Dictionary)["triangles"] as int
	var left: int = (parts["wing_L"] as Dictionary)["triangles"] as int
	assert_int(right).is_greater(0)
	assert_int(left).is_greater(0)
	var model: ShipModel = _model(Content.ship(ship_id))
	var wing_r: MeshInstance3D = model.get_node("wing_R") as MeshInstance3D
	var wing_l: MeshInstance3D = model.get_node("wing_L") as MeshInstance3D
	assert_float(absf(wing_r.get_aabb().size.x - wing_l.get_aabb().size.x)).is_greater(0.5)


func test_pirates_look_different_from_the_concord_ships() -> void:
	var concord: ShipDef = Content.ship(&"kestrel")
	for ship_id: StringName in FlightSim.PIRATE_SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		assert_bool(def.paint_primary == concord.paint_primary).is_false()
		# Rust red: more red than blue. Engines: a dirty orange, where Concord's are blue-white.
		assert_float(def.paint_primary.r).is_greater(def.paint_primary.b + 0.2)
		assert_float(def.engine_color.r).is_greater(def.engine_color.b + 0.3)
		assert_float(concord.engine_color.b).is_greater(concord.engine_color.r)


func test_the_engine_glow_uses_the_ships_colour() -> void:
	for ship_id: StringName in [&"kestrel", &"pirate_fighter"]:
		var ship: Ship = auto_free(FlightSim.spawn(self, ship_id)) as Ship
		var fx: EngineFx = ship.get_node("EngineFx") as EngineFx
		fx.update(0.0)
		var socket: Marker3D = ship.model.get_sockets(&"engine")[0]
		var glow: MeshInstance3D = socket.get_node("Glow") as MeshInstance3D
		var material: StandardMaterial3D = (glow.mesh as QuadMesh).material as StandardMaterial3D
		var expected: Color = ship.def.engine_color
		assert_float(material.albedo_color.r).is_equal_approx(expected.r, 0.01)
		assert_float(material.albedo_color.b).is_equal_approx(expected.b, 0.01)


func test_pirates_are_weaker_than_the_players_light_fighter() -> void:
	# GDD: 1v3 against pirates is the M2 exit test, so one pirate is no match for one Kestrel.
	var kestrel: ShipDef = Content.ship(&"kestrel")
	for ship_id: StringName in FlightSim.PIRATE_SHIP_IDS:
		var def: ShipDef = Content.ship(ship_id)
		var pirate_total: float = def.shield_capacity + def.armor_capacity + def.hull_capacity
		var kestrel_total: float = (
			kestrel.shield_capacity + kestrel.armor_capacity + kestrel.hull_capacity
		)
		assert_float(pirate_total).is_less(kestrel_total)


func test_the_engine_discs_take_the_ships_colour() -> void:
	var concord: Ship = auto_free(FlightSim.spawn(self, &"kestrel")) as Ship
	var pirate: Ship = auto_free(FlightSim.spawn(self, &"pirate_fighter")) as Ship
	for ship: Ship in [concord, pirate]:
		var discs: Array[Node] = ship.model.find_children(
			"engine_glow*", "MeshInstance3D", true, false
		)
		assert_array(discs).is_not_empty()
		var material: StandardMaterial3D = (
			(discs[0] as MeshInstance3D).material_override as StandardMaterial3D
		)
		assert_float(material.emission.r).is_equal_approx(ship.def.engine_color.r, 0.001)
		assert_float(material.emission.b).is_equal_approx(ship.def.engine_color.b, 0.001)
	var shared: StandardMaterial3D = load(ShipModel.ENGINE_GLOW_MATERIAL) as StandardMaterial3D
	# The shared material is not touched: another Kestrel is still blue.
	assert_float(shared.emission.b).is_greater(shared.emission.r)
