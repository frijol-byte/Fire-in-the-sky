class_name ShipModel
extends Node3D
## The visual side of a ship: an imported `.glb` (see `ModelImportRules`) whose root carries this
## script. Shows the parts that belong to the ship's upgrade tier, finds weapon/engine sockets
## and applies the faction paint.

## Highest upgrade tier a model can show (T0 is the stock ship).
const MAX_TIER: int = 3
## The shared material of the engine glow discs; `set_engine_color` swaps it for a tinted copy.
const ENGINE_GLOW_MATERIAL: String = "res://shaders/materials/emissive_engine.tres"

## Tier shown. Setting it updates the parts, so it also works before the node is in the tree.
@export_range(0, 3) var tier: int = 0:
	set = set_tier

var _tier_parts: Array[Node3D] = []
var _sockets: Array[Marker3D] = []
var _paint_meshes: Array[MeshInstance3D] = []
var _glow_meshes: Array[MeshInstance3D] = []


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


## Tints the glowing engine discs of this ship only (art bible 2: Concord blue-white, Cinder Clans
## dirty orange). The ship's other engine effects take their colour from `ShipDef` directly.
func set_engine_color(color: Color) -> void:
	if _glow_meshes.is_empty():
		return
	var material: StandardMaterial3D = (
		(load(ENGINE_GLOW_MATERIAL) as StandardMaterial3D).duplicate() as StandardMaterial3D
	)
	material.albedo_color = color
	material.emission = color
	for mesh_node: MeshInstance3D in _glow_meshes:
		mesh_node.material_override = material


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
	if node is MeshInstance3D and _has_engine_glow_material(node as MeshInstance3D):
		_glow_meshes.append(node as MeshInstance3D)


static func _has_engine_glow_material(mesh_node: MeshInstance3D) -> bool:
	if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() == 0:
		return false
	var material: Material = mesh_node.mesh.surface_get_material(0)
	return material != null and material.resource_path == ENGINE_GLOW_MATERIAL


func _apply_tier() -> void:
	for part: Node3D in _tier_parts:
		part.visible = is_available_at(part, tier)
	for socket: Marker3D in _sockets:
		socket.visible = is_available_at(socket, tier)
