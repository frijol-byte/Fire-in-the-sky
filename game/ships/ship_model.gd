class_name ShipModel
extends Node3D
## The visual side of a ship: an imported `.glb` (see `ModelImportRules`) whose root carries this
## script. Shows the parts that belong to the ship's upgrade tier, finds weapon/engine sockets
## and applies the faction paint.

## Highest upgrade tier a model can show (T0 is the stock ship).
const MAX_TIER: int = 3

## Tier shown. Setting it updates the parts, so it also works before the node is in the tree.
@export_range(0, 3) var tier: int = 0:
	set = set_tier

var _tier_parts: Array[Node3D] = []
var _sockets: Array[Marker3D] = []
var _paint_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_scan(self)
	_apply_tier()


## Shows the parts for `new_tier` (clamped to 0..MAX_TIER): `T<n>_` parts when `n <= new_tier`,
## `T0ONLY_` parts only at tier 0. Sockets that need a higher tier are hidden.
func set_tier(new_tier: int) -> void:
	tier = clampi(new_tier, 0, MAX_TIER)
	if is_node_ready():
		_apply_tier()


## Returns the sockets of `kind` (`&"primary"`, `&"engine"`, ...) that exist at the current tier,
## ordered by index.
func get_sockets(kind: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for socket: Marker3D in _sockets:
		if socket.get_meta(ModelImportRules.META_KIND) == kind and is_available_at(socket, tier):
			result.append(socket)
	result.sort_custom(_by_socket_index)
	return result


## Sets the faction paint colours on every painted mesh of this ship only.
func set_paint(primary: Color, secondary: Color) -> void:
	for mesh_node: MeshInstance3D in _paint_meshes:
		mesh_node.set_instance_shader_parameter(&"primary_color", primary)
		mesh_node.set_instance_shader_parameter(&"secondary_color", secondary)


## True when `node` (a tier part or socket) exists at `at_tier`.
static func is_available_at(node: Node, at_tier: int) -> bool:
	var min_tier: int = int(node.get_meta(ModelImportRules.META_MIN_TIER, 0))
	var max_tier: int = int(node.get_meta(ModelImportRules.META_MAX_TIER, MAX_TIER))
	return at_tier >= min_tier and at_tier <= max_tier


static func _by_socket_index(a: Marker3D, b: Marker3D) -> bool:
	return (
		int(a.get_meta(ModelImportRules.META_INDEX)) < int(b.get_meta(ModelImportRules.META_INDEX))
	)


static func _is_socket(node: Node) -> bool:
	return node is Marker3D and node.has_meta(ModelImportRules.META_KIND)


func _scan(node: Node) -> void:
	for child: Node in node.get_children():
		_scan(child)
	if _is_socket(node):
		_sockets.append(node as Marker3D)
	elif (
		node is Node3D
		and (
			node.has_meta(ModelImportRules.META_MIN_TIER)
			or node.has_meta(ModelImportRules.META_MAX_TIER)
		)
	):
		_tier_parts.append(node as Node3D)
	if node is MeshInstance3D and node.has_meta(ModelImportRules.META_PAINT):
		_paint_meshes.append(node as MeshInstance3D)


func _apply_tier() -> void:
	for part: Node3D in _tier_parts:
		part.visible = is_available_at(part, tier)
	for socket: Marker3D in _sockets:
		socket.visible = is_available_at(socket, tier)
