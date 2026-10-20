class_name RockField
extends RefCounted
## Where every rock of an asteroid field is: a pure function of the `ArenaDef` and the rock
## variants' sizes, so the same seed always gives the same field. Holds one transform, variant
## and radius per rock and a coarse grid for asking "which rocks are near here?" quickly.
##
## The field only knows positions. `AsteroidField` draws them and `RockColliders` makes the ones
## near the ship solid.

## Edge length of a grid cell. Bigger than the typical query so that a query visits few cells.
const CELL_SIZE: float = 300.0
## Tries to find a spot for one rock before it is dropped.
const MAX_ATTEMPTS: int = 40

## One transform per rock (rotation and uniform scale included).
var transforms: Array[Transform3D] = []
## Which rock variant (index into the variant list) each rock is.
var variants: PackedInt32Array = []
## Radius of each rock in metres, after scaling.
var radii: PackedFloat32Array = []

var _grid: Dictionary[Vector3i, PackedInt32Array] = {}
var _biggest_radius: float = 0.0


## Builds the field for `def`. `variant_radii` holds the radius of each rock variant at scale 1;
## `course` is the line (start, then every gate) that rocks keep `def.field_lane_radius` away from.
static func generate(
	def: ArenaDef, variant_radii: PackedFloat32Array, course: PackedVector3Array = []
) -> RockField:
	var field: RockField = RockField.new()
	if variant_radii.is_empty():
		return field
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = def.field_seed
	for _index: int in def.field_rock_count:
		for _attempt: int in MAX_ATTEMPTS:
			var rock: Dictionary = _roll_rock(rng, def, variant_radii)
			if _is_clear(rock, def, course):
				field._add(
					rock["transform"] as Transform3D,
					rock["variant"] as int,
					rock["radius"] as float
				)
				break
	return field


## Number of rocks.
func count() -> int:
	return transforms.size()


## Returns the indices of up to `max_count` rocks whose surface is within `radius` of `point`,
## nearest first. Distance is measured to the rock's surface, so a giant counts from its edge.
func nearby(point: Vector3, radius: float, max_count: int) -> PackedInt32Array:
	var found: Array[Vector2] = []
	var reach: float = radius + _biggest_radius
	var low: Vector3i = _cell_of(point - Vector3.ONE * reach)
	var high: Vector3i = _cell_of(point + Vector3.ONE * reach)
	for x: int in range(low.x, high.x + 1):
		for y: int in range(low.y, high.y + 1):
			for z: int in range(low.z, high.z + 1):
				var cell: PackedInt32Array = _grid.get(Vector3i(x, y, z), PackedInt32Array())
				for index: int in cell:
					var gap: float = transforms[index].origin.distance_to(point) - radii[index]
					if gap <= radius:
						found.append(Vector2(gap, index))
	found.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: PackedInt32Array = []
	for entry: Vector2 in found:
		if result.size() >= max_count:
			break
		result.append(int(entry.y))
	return result


static func _roll_rock(
	rng: RandomNumberGenerator, def: ArenaDef, variant_radii: PackedFloat32Array
) -> Dictionary:
	var span: float = def.field_outer_radius - def.field_inner_radius
	var distance: float = def.field_inner_radius + span * pow(rng.randf(), def.field_density_bias)
	var direction: Vector3 = _random_direction(rng)
	direction.y *= def.field_vertical_scale
	var scale: float = lerpf(
		def.field_min_scale, def.field_max_scale, pow(rng.randf(), def.field_scale_bias)
	)
	var variant: int = rng.randi() % variant_radii.size()
	var rotation: Basis = (
		Basis(Quaternion(_random_direction(rng), rng.randf_range(0.0, TAU)))
		. scaled(Vector3.ONE * scale)
	)
	var position: Vector3 = def.spawn_position + direction * distance
	return {
		"transform": Transform3D(rotation, position),
		"variant": variant,
		"radius": variant_radii[variant] * scale,
	}


static func _is_clear(rock: Dictionary, def: ArenaDef, course: PackedVector3Array) -> bool:
	var position: Vector3 = (rock["transform"] as Transform3D).origin
	var radius: float = rock["radius"] as float
	# A clear lane around the start.
	if position.distance_to(def.spawn_position) - radius < def.field_inner_radius:
		return false
	# A clear lane along the course.
	for index: int in course.size() - 1:
		var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(
			position, course[index], course[index + 1]
		)
		if position.distance_to(nearest) - radius < def.field_lane_radius:
			return false
	return true


static func _random_direction(rng: RandomNumberGenerator) -> Vector3:
	# Uniform on the sphere.
	var z: float = rng.randf_range(-1.0, 1.0)
	var angle: float = rng.randf_range(0.0, TAU)
	var ring: float = sqrt(1.0 - z * z)
	return Vector3(ring * cos(angle), z, ring * sin(angle))


func _add(transform: Transform3D, variant: int, radius: float) -> void:
	var index: int = transforms.size()
	transforms.append(transform)
	variants.append(variant)
	radii.append(radius)
	_biggest_radius = maxf(_biggest_radius, radius)
	var cell: Vector3i = _cell_of(transform.origin)
	var members: PackedInt32Array = _grid.get(cell, PackedInt32Array())
	members.append(index)
	_grid[cell] = members


static func _cell_of(point: Vector3) -> Vector3i:
	return Vector3i((point / CELL_SIZE).floor())
