class_name DebrisField
extends Node3D
## The chunks a destroyed ship throws off (M2-T6): a pool of small pieces (plates, wedges and struts
## built from primitive meshes) that fly off on straight lines, tumble, glow hot at first, cool
## and shrink away. They are pure decoration: no collision, no damage. Nothing is created while
## playing; when every piece is busy, the oldest is reused.

const POOL_SIZE: int = 96
const HOT_COLOR: Color = Color(1.0, 0.45, 0.12)
## Emission strength of a chunk at full heat.
const HOT_ENERGY: float = 3.0
const SHAPES: int = 3


class Chunk:
	extends RefCounted
	var node: MeshInstance3D = null
	var material: StandardMaterial3D = null
	var velocity: Vector3 = Vector3.ZERO
	var spin_axis: Vector3 = Vector3.UP
	var spin_rate: float = 0.0
	var age: float = 0.0
	var lifetime: float = 0.0
	var cool_seconds: float = 1.0
	var size: float = 1.0
	var active: bool = false


var _chunks: Array[Chunk] = []
var _next: int = 0


func _ready() -> void:
	top_level = true
	var meshes: Array[Mesh] = _make_meshes()
	for index: int in POOL_SIZE:
		var chunk: Chunk = Chunk.new()
		chunk.material = StandardMaterial3D.new()
		chunk.material.albedo_color = Color(0.2, 0.2, 0.22)
		chunk.material.metallic = 0.7
		chunk.material.roughness = 0.5
		chunk.material.emission_enabled = true
		chunk.material.emission = HOT_COLOR
		chunk.node = MeshInstance3D.new()
		chunk.node.mesh = meshes[index % SHAPES]
		chunk.node.material_override = chunk.material
		chunk.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		chunk.node.visible = false
		add_child(chunk.node)
		_chunks.append(chunk)


func _process(delta: float) -> void:
	advance(delta)


## Throws `def.debris_count` chunks from `position`. `velocity` is the wreck's own velocity, `radius`
## its size in metres (chunks are a fraction of it). `rng` decides every direction and size.
func burst(
	position: Vector3,
	velocity: Vector3,
	radius: float,
	def: DestructionDef,
	rng: RandomNumberGenerator
) -> void:
	for index: int in def.debris_count:
		var chunk: Chunk = _chunks[_next]
		_next = (_next + 1) % _chunks.size()
		chunk.velocity = DestructionMath.debris_velocity(rng, def, velocity)
		chunk.spin_axis = DestructionMath.random_direction(rng)
		chunk.spin_rate = deg_to_rad(rng.randf_range(0.0, def.debris_spin_max_deg))
		chunk.age = 0.0
		chunk.lifetime = def.debris_lifetime * rng.randf_range(0.7, 1.0)
		chunk.cool_seconds = def.debris_cool_seconds
		chunk.size = radius * rng.randf_range(def.debris_size_min, def.debris_size_max)
		chunk.active = true
		chunk.node.visible = true
		chunk.node.global_transform = Transform3D(
			Basis(DestructionMath.random_direction(rng), rng.randf_range(0.0, TAU)), position
		)
		_draw(chunk)


## Moves every chunk on by `delta` seconds. `_process` calls it; tests call it directly.
func advance(delta: float) -> void:
	for chunk: Chunk in _chunks:
		if not chunk.active:
			continue
		chunk.age += delta
		if chunk.age >= chunk.lifetime:
			chunk.active = false
			chunk.node.visible = false
			continue
		chunk.node.global_position += chunk.velocity * delta
		chunk.node.global_transform.basis = (
			(Basis(chunk.spin_axis, chunk.spin_rate * delta) * chunk.node.global_transform.basis)
			. orthonormalized()
		)
		_draw(chunk)


## How many chunks are flying right now.
func active_count() -> int:
	var count: int = 0
	for chunk: Chunk in _chunks:
		if chunk.active:
			count += 1
	return count


func _draw(chunk: Chunk) -> void:
	var scale_now: float = chunk.size * DestructionMath.debris_scale(chunk.age, chunk.lifetime)
	chunk.node.scale = Vector3.ONE * maxf(scale_now, 0.001)
	chunk.material.emission_energy_multiplier = (
		HOT_ENERGY * DestructionMath.debris_heat(chunk.age, chunk.cool_seconds)
	)


## Three simple generated shapes: a flat plate, a wedge and a strut, each about a unit across.
func _make_meshes() -> Array[Mesh]:
	var plate: BoxMesh = BoxMesh.new()
	plate.size = Vector3(1.0, 0.12, 0.7)
	var wedge: PrismMesh = PrismMesh.new()
	wedge.size = Vector3(0.8, 0.6, 0.15)
	var strut: CylinderMesh = CylinderMesh.new()
	strut.top_radius = 0.05
	strut.bottom_radius = 0.07
	strut.height = 1.2
	strut.radial_segments = 6
	var result: Array[Mesh] = [plate, wedge, strut]
	return result
