class_name ModelImportRules
extends RefCounted
## What the model post-import step does to a freshly imported `.glb` (art bible 3.1, 3.2).
## Kept apart from the editor-only hook (`model_post_import.gd`) so it can be unit tested.
##
## - Blender role materials become Godot materials (`MATERIALS`).
## - `SOCKET_<kind>_<n>` nodes become `Marker3D` with `kind`, `index` and `min_tier` metadata.
## - `T<n>_*` parts get `min_tier = n`; `T0ONLY_*` parts get `max_tier = 0`.
## - `SUB_<name>` nodes get `subsystem = <name>` metadata.
## - The collision body Godot builds from a `-colonly` mesh is renamed `Collision`, and its
##   shape (Godot makes a trimesh from `-colonly`) becomes a convex hull, since the source mesh
##   is already convex and a trimesh can't be used on a RigidBody3D.
## - Ship models (`models/ships/`) get the `ShipModel` script on their root.

const META_KIND: StringName = &"kind"
const META_INDEX: StringName = &"index"
const META_MIN_TIER: StringName = &"min_tier"
const META_MAX_TIER: StringName = &"max_tier"
const META_SUBSYSTEM: StringName = &"subsystem"
const META_PAINT: StringName = &"paint"
const META_EXTRAS: StringName = &"extras"

const SOCKET_PREFIX: String = "SOCKET_"
const SUBSYSTEM_PREFIX: String = "SUB_"
const T0_ONLY_PREFIX: String = "T0ONLY_"
const COLLISION_NAME: String = "Collision"
const SHIPS_DIR: String = "/models/ships/"

const SHIP_MODEL_SCRIPT: GDScript = preload("res://ships/ship_model.gd")

## Blender material name -> Godot material.
const MATERIALS: Dictionary = {
	"PAINT_PRIMARY": "res://shaders/materials/paint_primary.tres",
	"PAINT_SECONDARY": "res://shaders/materials/paint_secondary.tres",
	"METAL_BARE": "res://shaders/materials/metal_bare.tres",
	"METAL_DARK": "res://shaders/materials/metal_dark.tres",
	"GLASS": "res://shaders/materials/glass.tres",
	"EMISSIVE_ENGINE": "res://shaders/materials/emissive_engine.tres",
	"EMISSIVE_LIGHT": "res://shaders/materials/emissive_light.tres",
	"CRYSTAL": "res://shaders/materials/crystal.tres",
}

## Materials whose colour comes from the ship's paint (see `ShipModel.set_paint`).
const PAINT_MATERIALS: PackedStringArray = ["PAINT_PRIMARY", "PAINT_SECONDARY"]


## Applies every rule to the imported scene `root`. `source_file` is the `.glb` path, used to
## pick the root script. Returns `root`.
static func process(root: Node, source_file: String = "") -> Node:
	_process_node(root, root)
	if SHIPS_DIR in source_file:
		root.set_script(SHIP_MODEL_SCRIPT)
	return root


## Returns the parsed `(kind, index)` of a socket node name such as `SOCKET_primary_2`, or an
## empty dictionary when the name does not follow the convention.
static func parse_socket_name(node_name: String) -> Dictionary:
	if not node_name.begins_with(SOCKET_PREFIX):
		return {}
	var rest: String = node_name.trim_prefix(SOCKET_PREFIX)
	var split: int = rest.rfind("_")
	if split <= 0 or not rest.substr(split + 1).is_valid_int():
		return {}
	return {"kind": StringName(rest.substr(0, split)), "index": rest.substr(split + 1).to_int()}


## Returns `n` for a `T<n>_...` part name (n >= 1), or -1 for any other name.
static func parse_tier_prefix(node_name: String) -> int:
	if node_name.length() < 3 or node_name[0] != "T":
		return -1
	var digits: int = 1
	while digits < node_name.length() and node_name[digits].is_valid_int():
		digits += 1
	if digits == 1 or digits >= node_name.length() or node_name[digits] != "_":
		return -1
	var tier: int = node_name.substr(1, digits - 1).to_int()
	return tier if tier >= 1 else -1


static func _process_node(node: Node, root: Node) -> void:
	# Copy the child list: sockets are replaced while we walk.
	for child: Node in node.get_children():
		_process_node(child, root)
	if node is MeshInstance3D:
		_assign_materials(node as MeshInstance3D)
	if node is StaticBody3D and node != root:
		node.name = COLLISION_NAME
		_make_collision_convex(node)
	_tag_parts(node)
	if node.name.begins_with(SOCKET_PREFIX):
		_make_socket(node, root)


static func _assign_materials(mesh_node: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_node.mesh
	if mesh == null:
		return
	for surface: int in mesh.get_surface_count():
		var source: Material = mesh.surface_get_material(surface)
		if source == null:
			continue
		var role: String = source.resource_name
		if not MATERIALS.has(role):
			continue
		mesh.surface_set_material(surface, load(MATERIALS[role] as String) as Material)
		if role in PAINT_MATERIALS:
			mesh_node.set_meta(META_PAINT, true)


static func _make_collision_convex(body: Node) -> void:
	for child: Node in body.get_children():
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision == null or not collision.shape is ConcavePolygonShape3D:
			continue
		var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		hull.points = (collision.shape as ConcavePolygonShape3D).get_faces()
		collision.shape = hull


static func _tag_parts(node: Node) -> void:
	var node_name: String = node.name
	var tier: int = parse_tier_prefix(node_name)
	if tier > 0:
		node.set_meta(META_MIN_TIER, tier)
	elif node_name.begins_with(T0_ONLY_PREFIX):
		node.set_meta(META_MAX_TIER, 0)
	elif node_name.begins_with(SUBSYSTEM_PREFIX):
		node.set_meta(META_SUBSYSTEM, StringName(node_name.trim_prefix(SUBSYSTEM_PREFIX)))


## Replaces a socket node by a `Marker3D` of the same name and transform. The glTF extras
## (`kind`, `index`, `min_tier`) win over the name; the name is the fallback.
static func _make_socket(node: Node, root: Node) -> void:
	var from_name: Dictionary = parse_socket_name(node.name)
	var extras: Dictionary = {}
	if node.has_meta(META_EXTRAS):
		extras = node.get_meta(META_EXTRAS) as Dictionary
	var kind: StringName = StringName(extras.get("kind", from_name.get("kind", "")) as String)
	if kind.is_empty():
		push_warning("ModelImportRules: '%s' is not a valid socket name" % node.name)
		return
	var marker: Marker3D = Marker3D.new()
	marker.name = node.name
	marker.set_meta(META_KIND, kind)
	marker.set_meta(META_INDEX, int(extras.get("index", from_name.get("index", 0))))
	marker.set_meta(META_MIN_TIER, int(extras.get("min_tier", 0)))
	var parent: Node = node.get_parent()
	var position_in_parent: int = node.get_index()
	marker.transform = (node as Node3D).transform
	parent.remove_child(node)
	parent.add_child(marker)
	parent.move_child(marker, position_in_parent)
	marker.owner = root
	node.free()
