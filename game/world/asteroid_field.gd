class_name AsteroidField
extends Node3D
## An asteroid field: thousands of rocks drawn with one `MultiMeshInstance3D` per rock variant,
## plus `RockColliders`, a small pool of solid rocks that follows the player's ship (the
## multimesh has no collision). Where the rocks are comes from `RockField`.
##
## The four rock variants are the Blender props `asteroid_a` .. `asteroid_d`.

const VARIANT_PATHS: Array[String] = [
	"res://assets/models/props/asteroid_a.glb",
	"res://assets/models/props/asteroid_b.glb",
	"res://assets/models/props/asteroid_c.glb",
	"res://assets/models/props/asteroid_d.glb",
]

## The layout of the field, once built.
var field: RockField = null
## The solid rocks around the ship, once built.
var colliders: RockColliders = null


## Builds the rocks for `def`. `course` is the line of the gate course (start, then each gate),
## which rocks keep clear of.
func build(def: ArenaDef, course: PackedVector3Array = []) -> void:
	var meshes: Array[Mesh] = []
	var shapes: Array[Shape3D] = []
	var radii: PackedFloat32Array = []
	for path: String in VARIANT_PATHS:
		var variant: Dictionary = load_variant(path)
		meshes.append(variant["mesh"] as Mesh)
		shapes.append(variant["shape"] as Shape3D)
		radii.append(variant["radius"] as float)
	field = RockField.generate(def, radii, course)
	for variant_index: int in meshes.size():
		_add_multimesh(variant_index, meshes[variant_index])
	colliders = RockColliders.new()
	colliders.name = "Colliders"
	add_child(colliders)
	colliders.setup(field, shapes, def)


## Makes the rocks around `target` solid (and keeps doing so as it moves).
func follow(target: Node3D) -> void:
	colliders.set_target(target)


## Reads one rock model: its mesh, its convex collision shape and its radius at scale 1.
static func load_variant(path: String) -> Dictionary:
	var root: Node = (load(path) as PackedScene).instantiate()
	var mesh_node: MeshInstance3D = _first_mesh(root)
	var body: Node = root.get_node_or_null(ModelImportRules.COLLISION_NAME)
	var result: Dictionary = {"mesh": null, "shape": null, "radius": 1.0}
	if mesh_node != null:
		result["mesh"] = mesh_node.mesh
		result["radius"] = mesh_node.mesh.get_aabb().get_longest_axis_size() * 0.5
	if body != null:
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				result["shape"] = (child as CollisionShape3D).shape
	root.free()
	return result


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var found: MeshInstance3D = _first_mesh(child)
		if found != null:
			return found
	return null


func _add_multimesh(variant_index: int, mesh: Mesh) -> void:
	var indices: PackedInt32Array = []
	for rock: int in field.count():
		if field.variants[rock] == variant_index:
			indices.append(rock)
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = indices.size()
	for slot: int in indices.size():
		multi.set_instance_transform(slot, field.transforms[indices[slot]])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "Rocks%d" % variant_index
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
