class_name SweepCaster
extends RefCounted
## Moves a sphere through the physics world and reports the first thing it touches. Shots and
## missiles use it so a fast round cannot skip through a target between two physics ticks. It
## holds its own query objects, so one caster is made per manager and reused every tick.

var _query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _shapes: Dictionary[float, SphereShape3D] = {}


## `mask` is the physics layers the sphere collides with (see `PhysicsLayers`).
func _init(mask: int) -> void:
	_query.collision_mask = mask
	_query.collide_with_areas = false
	_ray.collision_mask = mask
	_ray.collide_with_areas = false


## Sweeps a sphere of `radius` from `from` along `motion`, ignoring the bodies in `exclude`.
## Returns {} when nothing is in the way, otherwise the first contact: {position (the sphere's
## centre when it touched), point, normal, collider}.
func cast(
	space: PhysicsDirectSpaceState3D,
	from: Vector3,
	motion: Vector3,
	radius: float,
	exclude: Array[RID]
) -> Dictionary:
	if motion.length_squared() < 0.000001:
		return {}
	_query.shape = _shape_for(radius)
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = motion
	_query.exclude = exclude
	var fractions: PackedFloat32Array = space.cast_motion(_query)
	if fractions.size() < 2 or fractions[0] >= 1.0:
		return {}
	var touching: Vector3 = from + motion * fractions[1]
	_query.transform = Transform3D(Basis.IDENTITY, touching)
	_query.motion = Vector3.ZERO
	var rest: Dictionary = space.get_rest_info(_query)
	if not rest.is_empty():
		return {
			"position": touching,
			"point": rest["point"] as Vector3,
			"normal": rest["normal"] as Vector3,
			"collider": instance_from_id(rest["collider_id"] as int),
		}
	# The sweep stopped just short of contact: a ray along the path finds what is there.
	_ray.from = from
	_ray.to = touching + motion.normalized() * radius * 2.0
	_ray.exclude = exclude
	var ray_hit: Dictionary = space.intersect_ray(_ray)
	if ray_hit.is_empty():
		return {}
	return {
		"position": touching,
		"point": ray_hit["position"] as Vector3,
		"normal": ray_hit["normal"] as Vector3,
		"collider": ray_hit["collider"] as Object,
	}


func _shape_for(radius: float) -> SphereShape3D:
	if not _shapes.has(radius):
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = radius
		_shapes[radius] = shape
	return _shapes[radius]
