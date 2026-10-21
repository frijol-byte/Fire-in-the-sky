extends GdUnitTestSuite
## Imported `kestrel.glb`: root script, socket discovery by tier, tier part visibility,
## role materials and paint.

const KESTREL: PackedScene = preload("res://assets/models/ships/kestrel.glb")
const MANIFEST_PATH: String = "res://assets/models/ships/kestrel.manifest.json"


func _make_ship(tier: int = 0) -> ShipModel:
	var node: Node = KESTREL.instantiate()
	assert_object(node).is_instanceof(ShipModel)
	var ship: ShipModel = node as ShipModel
	ship.tier = tier
	add_child(ship)
	auto_free(ship)
	return ship


func _manifest() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH)) as Dictionary


func _visible_parts(ship: ShipModel) -> PackedStringArray:
	var result: PackedStringArray = []
	for child: Node in ship.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			result.append(child.name)
	return result


func test_sockets_are_markers_with_metadata() -> void:
	var ship: ShipModel = _make_ship(3)
	var engines: Array[Marker3D] = ship.get_sockets(&"engine")
	assert_array(engines).has_size(2)
	for index: int in engines.size():
		assert_str(engines[index].name).is_equal("SOCKET_engine_%d" % index)
		assert_int(int(engines[index].get_meta(ModelImportRules.META_INDEX))).is_equal(index)


func test_socket_counts_match_the_manifest_at_every_tier() -> void:
	var manifest_sockets: Array = _manifest()["sockets"] as Array
	for tier: int in ShipModel.MAX_TIER + 1:
		var ship: ShipModel = _make_ship(tier)
		var kinds: Dictionary = {}
		for entry: Dictionary in manifest_sockets:
			if int(entry["min_tier"]) <= tier:
				kinds[entry["kind"]] = int(kinds.get(entry["kind"], 0)) + 1
		for kind: String in kinds:
			(
				assert_int(ship.get_sockets(StringName(kind)).size())
				. override_failure_message("kind %s at tier %d" % [kind, tier])
				. is_equal(kinds[kind] as int)
			)


func test_third_primary_socket_only_exists_at_tier_three() -> void:
	var ship: ShipModel = _make_ship(2)
	assert_array(ship.get_sockets(&"primary")).has_size(2)
	ship.set_tier(3)
	var primaries: Array[Marker3D] = ship.get_sockets(&"primary")
	assert_array(primaries).has_size(3)
	assert_str(primaries[2].name).is_equal("SOCKET_primary_2")


func test_unknown_socket_kind_returns_nothing() -> void:
	assert_array(_make_ship().get_sockets(&"warp_drive")).is_empty()


func test_socket_positions_follow_the_blender_axes() -> void:
	# Nose is Blender +Y = Godot -Z; the engines are at the tail (+Z) and fire backwards.
	var ship: ShipModel = _make_ship()
	var engine: Marker3D = ship.get_sockets(&"engine")[0]
	assert_float(engine.position.z).is_greater(5.0)
	assert_float(engine.global_transform.basis.z.z).is_less(0.0)
	var primary: Marker3D = ship.get_sockets(&"primary")[0]
	assert_float(primary.global_transform.basis.z.z).is_greater(0.0)


func test_tier_parts_are_shown_from_their_tier_up() -> void:
	var ship: ShipModel = _make_ship(0)
	var tier_parts: Dictionary = _manifest()["tier_parts"] as Dictionary
	for tier: int in ShipModel.MAX_TIER + 1:
		ship.set_tier(tier)
		for group: String in tier_parts:
			for part_name: String in tier_parts[group] as Array:
				var expected: bool
				if group == "T0ONLY":
					expected = tier == 0
				else:
					expected = tier >= group.trim_prefix("T").to_int()
				var part: Node3D = ship.get_node(part_name) as Node3D
				(
					assert_bool(part.visible)
					. override_failure_message("%s at tier %d" % [part_name, tier])
					. is_equal(expected)
				)


func test_base_parts_stay_visible_at_every_tier() -> void:
	var ship: ShipModel = _make_ship()
	for tier: int in ShipModel.MAX_TIER + 1:
		ship.set_tier(tier)
		for base: String in ["hull", "wing_L", "wing_R", "canopy_glass"]:
			assert_bool((ship.get_node(base) as Node3D).visible).is_true()


func test_tier_is_clamped() -> void:
	var ship: ShipModel = _make_ship()
	ship.set_tier(99)
	assert_int(ship.tier).is_equal(ShipModel.MAX_TIER)
	ship.set_tier(-4)
	assert_int(ship.tier).is_equal(0)


func test_tier_set_before_entering_the_tree_is_applied_on_ready() -> void:
	var ship: ShipModel = _make_ship(3)
	assert_bool((ship.get_node("T3_nose_cannon") as Node3D).visible).is_true()
	assert_bool((ship.get_node("T0ONLY_stock_cowl") as Node3D).visible).is_false()
	assert_array(_visible_parts(ship)).contains(["T1_dorsal_armor", "T2_engine_pod_L"])


func test_role_materials_become_godot_materials() -> void:
	var ship: ShipModel = _make_ship()
	var paint: Material = (ship.get_node("hull") as MeshInstance3D).get_active_material(0)
	assert_object(paint).is_instanceof(ShaderMaterial)
	assert_str((paint as ShaderMaterial).shader.resource_path).is_equal(
		"res://shaders/faction_paint.gdshader"
	)
	var glass: Material = (ship.get_node("canopy_glass") as MeshInstance3D).get_active_material(0)
	assert_object(glass).is_instanceof(StandardMaterial3D)
	assert_int((glass as StandardMaterial3D).transparency).is_not_equal(
		BaseMaterial3D.TRANSPARENCY_DISABLED
	)
	var engine_glow: Material = (
		(ship.get_node("engine_glow_L") as MeshInstance3D).get_active_material(0)
	)
	assert_bool((engine_glow as StandardMaterial3D).emission_enabled).is_true()


func test_collision_hull_is_kept_and_named() -> void:
	var ship: ShipModel = _make_ship()
	var body: StaticBody3D = ship.get_node("Collision") as StaticBody3D
	assert_object(body).is_not_null()
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	assert_object(shape.shape).is_instanceof(ConvexPolygonShape3D)


func test_set_paint_changes_only_this_ship() -> void:
	var first: ShipModel = _make_ship()
	var second: ShipModel = _make_ship()
	first.set_paint(Color.RED, Color.GREEN)
	var hull_first: MeshInstance3D = first.get_node("hull") as MeshInstance3D
	var hull_second: MeshInstance3D = second.get_node("hull") as MeshInstance3D
	assert_that(hull_first.get_instance_shader_parameter(&"primary_color")).is_equal(Color.RED)
	assert_that(hull_first.get_instance_shader_parameter(&"secondary_color")).is_equal(Color.GREEN)
	assert_that(hull_second.get_instance_shader_parameter(&"primary_color")).is_not_equal(Color.RED)
