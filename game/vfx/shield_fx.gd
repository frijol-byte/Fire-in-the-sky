class_name ShieldFx
extends MeshInstance3D
## The shield bubble of a ship or target: an ellipsoid around it that shows a ripple where a hit
## took shield (`shaders/shield_ripple.gdshader`). It listens to `Events.ship_damaged`, so it
## needs nothing from the weapons. Up to `RIPPLES` hits show at once; the oldest is replaced.
## The bubble is hidden while no ripple is alive.

const RIPPLES: int = 4
const SHADER: Shader = preload("res://shaders/shield_ripple.gdshader")
## The bubble is this much bigger than the ship's bounding box.
const BOUNDS_MARGIN: float = 1.25
const DURATION: float = 0.7

var _target: Node3D = null
var _material: ShaderMaterial = ShaderMaterial.new()
## Seconds since each ripple's hit, negative when the slot is free.
var _ages: PackedFloat32Array = []
var _directions: PackedVector3Array = []
var _next: int = 0


func _ready() -> void:
	_ages.resize(RIPPLES)
	_directions.resize(RIPPLES)
	_ages.fill(-1.0)
	_material.shader = SHADER
	_material.set_shader_parameter(&"duration", DURATION)
	mesh = SphereMesh.new()
	(mesh as SphereMesh).radius = 1.0
	(mesh as SphereMesh).height = 2.0
	(mesh as SphereMesh).radial_segments = 32
	(mesh as SphereMesh).rings = 16
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	Events.ship_damaged.connect(_on_ship_damaged)


func _process(delta: float) -> void:
	if not visible:
		return
	advance(delta)


## Makes the bubble for `target`: an ellipsoid centred at `center` with the given half sizes, both
## in the target's own space.
func setup(target: Node3D, center: Vector3, half_extents: Vector3) -> void:
	_target = target
	position = center
	scale = half_extents * BOUNDS_MARGIN


## Starts a ripple at the world point `world_point`.
func ripple_at(world_point: Vector3) -> void:
	var local: Vector3 = to_local(world_point)
	var direction: Vector3 = local.normalized() if local.length_squared() > 0.0001 else Vector3.UP
	_ages[_next] = 0.0
	_directions[_next] = direction
	_next = (_next + 1) % RIPPLES
	visible = true
	_push()


## Ages the ripples by `delta` seconds and hides the bubble when none is left.
func advance(delta: float) -> void:
	var alive: bool = false
	for slot: int in RIPPLES:
		if _ages[slot] < 0.0:
			continue
		_ages[slot] += delta
		if _ages[slot] > DURATION:
			_ages[slot] = -1.0
		else:
			alive = true
	visible = alive
	_push()


## Number of ripples showing.
func active_ripples() -> int:
	var count: int = 0
	for age: float in _ages:
		if age >= 0.0:
			count += 1
	return count


## Bounding box of the visible meshes under `root`, in the space of `space_node` (usually the ship).
static func bounds_of(root: Node, space_node: Node3D) -> AABB:
	var to_space: Transform3D = space_node.global_transform.affine_inverse()
	var result: AABB = AABB()
	var found: bool = false
	for mesh_node: MeshInstance3D in _meshes_under(root):
		var box: AABB = to_space * mesh_node.global_transform * mesh_node.get_aabb()
		result = box if not found else result.merge(box)
		found = true
	return result if found else AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))


static func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		var mesh_child: MeshInstance3D = child as MeshInstance3D
		if mesh_child != null and mesh_child.visible and mesh_child.mesh != null:
			# Glows and trails are quads; the hull is what the bubble hugs.
			if not (mesh_child.mesh is QuadMesh or mesh_child.mesh is ImmediateMesh):
				result.append(mesh_child)
		if child is Node3D and not (child as Node3D).visible:
			continue
		result.append_array(_meshes_under(child))
	return result


func _push() -> void:
	for slot: int in RIPPLES:
		var direction: Vector3 = _directions[slot]
		_material.set_shader_parameter(
			StringName("ripple_%d" % slot),
			Vector4(direction.x, direction.y, direction.z, _ages[slot])
		)


func _on_ship_damaged(ship: Node, info: DamageInfo, result: DamageResult) -> void:
	if ship == _target and result.shield_damage > 0.0:
		ripple_at(info.hit_point)
