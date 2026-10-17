extends GdUnitTestSuite
## `ModelImportRules` on small hand-built scenes (the rules the post-import hook applies).


func _mesh_with_material(role: String) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = role
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	return node


func _scene(children: Array[Node3D]) -> Node3D:
	var root: Node3D = auto_free(Node3D.new()) as Node3D
	for child: Node3D in children:
		root.add_child(child)
		child.owner = root
	return root


func _named(node: Node3D, node_name: String) -> Node3D:
	node.name = node_name
	return node


func _socket(node_name: String, extras: Dictionary) -> Node3D:
	var node: Node3D = _named(Node3D.new(), node_name)
	node.set_meta("extras", extras)
	node.position = Vector3(1, 2, 3)
	return node


func test_parse_socket_name() -> void:
	assert_that(ModelImportRules.parse_socket_name("SOCKET_primary_2")).is_equal(
		{"kind": &"primary", "index": 2}
	)
	assert_that(ModelImportRules.parse_socket_name("SOCKET_cockpit_cam_0")).is_equal(
		{"kind": &"cockpit_cam", "index": 0}
	)
	assert_that(ModelImportRules.parse_socket_name("SOCKET_primary")).is_equal({})
	assert_that(ModelImportRules.parse_socket_name("SOCKET_primary_x")).is_equal({})
	assert_that(ModelImportRules.parse_socket_name("hull")).is_equal({})


func test_parse_tier_prefix() -> void:
	assert_int(ModelImportRules.parse_tier_prefix("T1_plate")).is_equal(1)
	assert_int(ModelImportRules.parse_tier_prefix("T3_nose_cannon")).is_equal(3)
	assert_int(ModelImportRules.parse_tier_prefix("T12_x")).is_equal(12)
	assert_int(ModelImportRules.parse_tier_prefix("T0ONLY_cowl")).is_equal(-1)
	assert_int(ModelImportRules.parse_tier_prefix("T0_x")).is_equal(-1)
	assert_int(ModelImportRules.parse_tier_prefix("Tail_fin")).is_equal(-1)
	assert_int(ModelImportRules.parse_tier_prefix("T1")).is_equal(-1)
	assert_int(ModelImportRules.parse_tier_prefix("hull")).is_equal(-1)


func test_sockets_become_markers_keeping_name_transform_and_order() -> void:
	var root: Node3D = _scene(
		[
			_named(Node3D.new(), "before"),
			_socket("SOCKET_turret_1", {"kind": "turret", "index": 1.0, "min_tier": 2.0}),
			_named(Node3D.new(), "after"),
		]
	)
	ModelImportRules.process(root)
	var marker: Marker3D = root.get_node("SOCKET_turret_1") as Marker3D
	assert_object(marker).is_not_null()
	assert_int(marker.get_index()).is_equal(1)
	assert_that(marker.position).is_equal(Vector3(1, 2, 3))
	assert_that(marker.get_meta(ModelImportRules.META_KIND)).is_equal(&"turret")
	assert_int(marker.get_meta(ModelImportRules.META_INDEX) as int).is_equal(1)
	assert_int(marker.get_meta(ModelImportRules.META_MIN_TIER) as int).is_equal(2)
	assert_object(marker.owner).is_same(root)


func test_socket_without_extras_falls_back_to_its_name() -> void:
	var root: Node3D = _scene([_named(Node3D.new(), "SOCKET_engine_3")])
	ModelImportRules.process(root)
	var marker: Marker3D = root.get_node("SOCKET_engine_3") as Marker3D
	assert_that(marker.get_meta(ModelImportRules.META_KIND)).is_equal(&"engine")
	assert_int(marker.get_meta(ModelImportRules.META_INDEX) as int).is_equal(3)
	assert_int(marker.get_meta(ModelImportRules.META_MIN_TIER) as int).is_equal(0)


func test_tier_and_subsystem_parts_are_tagged() -> void:
	var root: Node3D = _scene(
		[
			_named(Node3D.new(), "T2_pod"),
			_named(Node3D.new(), "T0ONLY_cowl"),
			_named(Node3D.new(), "SUB_reactor"),
			_named(Node3D.new(), "hull"),
		]
	)
	ModelImportRules.process(root)
	assert_int(root.get_node("T2_pod").get_meta(ModelImportRules.META_MIN_TIER) as int).is_equal(2)
	(
		assert_int(root.get_node("T0ONLY_cowl").get_meta(ModelImportRules.META_MAX_TIER) as int)
		. is_equal(0)
	)
	assert_that(root.get_node("SUB_reactor").get_meta(ModelImportRules.META_SUBSYSTEM)).is_equal(
		&"reactor"
	)
	assert_bool(root.get_node("hull").get_meta_list().is_empty()).is_true()


func test_every_role_material_is_mapped_to_an_existing_resource() -> void:
	for role: String in ModelImportRules.MATERIALS:
		var node: MeshInstance3D = _mesh_with_material(role)
		var root: Node3D = _scene([node])
		ModelImportRules.process(root)
		var result: Material = node.mesh.surface_get_material(0)
		assert_object(result).override_failure_message(role).is_not_null()
		assert_str(result.resource_path).is_equal(ModelImportRules.MATERIALS[role] as String)


func test_only_paint_meshes_are_flagged_for_paint() -> void:
	var painted: MeshInstance3D = _mesh_with_material("PAINT_SECONDARY")
	var metal: MeshInstance3D = _mesh_with_material("METAL_BARE")
	ModelImportRules.process(_scene([painted, metal]))
	assert_bool(painted.has_meta(ModelImportRules.META_PAINT)).is_true()
	assert_bool(metal.has_meta(ModelImportRules.META_PAINT)).is_false()


func test_unknown_material_is_left_alone() -> void:
	var node: MeshInstance3D = _mesh_with_material("MYSTERY")
	var original: Material = node.mesh.surface_get_material(0)
	ModelImportRules.process(_scene([node]))
	assert_object(node.mesh.surface_get_material(0)).is_same(original)


func test_collision_body_is_renamed_but_not_the_root() -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "@StaticBody3D@42"
	var root: Node3D = _scene([body])
	ModelImportRules.process(root)
	assert_object(root.get_node_or_null("Collision")).is_same(body)


func test_ship_models_get_the_ship_model_script_and_others_do_not() -> void:
	var ship_root: Node3D = _scene([])
	ModelImportRules.process(ship_root, "res://assets/models/ships/x.glb")
	assert_object(ship_root.get_script()).is_same(ModelImportRules.SHIP_MODEL_SCRIPT)
	var prop_root: Node3D = _scene([])
	ModelImportRules.process(prop_root, "res://assets/models/props/rock.glb")
	assert_object(prop_root.get_script()).is_null()
