class_name RockColliders
extends Node3D
## Makes the rocks near the ship solid. The field draws thousands of rocks with a `MultiMesh`,
## which has no collision; this node keeps a small pool of static bodies and moves them onto the
## rocks nearest to the target (the player's ship), so anything the ship can reach can be hit.
##
## Each tick the nearest rocks within `collider_radius` are chosen. A rock that already has a body
## keeps it, a rock that has just come into range takes a free body, and a body whose rock has
## fallen out of range is switched off.

var _field: RockField = null
var _shapes: Array[Shape3D] = []
var _material: PhysicsMaterial = PhysicsMaterial.new()
var _radius: float = 0.0
var _bodies: Array[StaticBody3D] = []
## Rock index each body currently stands for, -1 when it is free.
var _assigned: PackedInt32Array = []
var _target: Node3D = null


## Creates the pool. `shapes` holds one collision shape per rock variant (same order as the
## field's variants).
func setup(field: RockField, shapes: Array[Shape3D], def: ArenaDef) -> void:
	_field = field
	_shapes = shapes
	_radius = def.collider_radius
	_material.bounce = def.rock_bounce
	_material.friction = def.rock_friction
	for index: int in def.collider_pool_size:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "RockCollider%d" % index
		body.physics_material_override = _material
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.disabled = true
		body.add_child(shape)
		add_child(body)
		_bodies.append(body)
		_assigned.append(-1)


## The node the pool follows (the player's ship).
func set_target(target: Node3D) -> void:
	_target = target


## Number of bodies currently standing on a rock.
func active_count() -> int:
	var count: int = 0
	for rock: int in _assigned:
		if rock >= 0:
			count += 1
	return count


## Rock indices that have a collider right now (any order).
func active_rocks() -> PackedInt32Array:
	var result: PackedInt32Array = []
	for rock: int in _assigned:
		if rock >= 0:
			result.append(rock)
	return result


## The body that stands on `rock`, or null.
func body_for(rock: int) -> StaticBody3D:
	var slot: int = _assigned.find(rock)
	return _bodies[slot] if slot >= 0 else null


func _physics_process(_delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		update_around(_target.global_position)


## Moves the pool to the rocks nearest `point`.
func update_around(point: Vector3) -> void:
	if _field == null:
		return
	var wanted: PackedInt32Array = _field.nearby(point, _radius, _bodies.size())
	var free_slots: PackedInt32Array = []
	for slot: int in _bodies.size():
		var rock: int = _assigned[slot]
		if rock >= 0 and not wanted.has(rock):
			_release(slot)
		if _assigned[slot] < 0:
			free_slots.append(slot)
	for rock: int in wanted:
		if _assigned.has(rock):
			continue
		var slot: int = free_slots[0]
		free_slots.remove_at(0)
		_assign(slot, rock)


func _assign(slot: int, rock: int) -> void:
	var body: StaticBody3D = _bodies[slot]
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	shape.shape = _shapes[_field.variants[rock]]
	shape.disabled = false
	body.global_transform = _field.transforms[rock]
	_assigned[slot] = rock


func _release(slot: int) -> void:
	var shape: CollisionShape3D = _bodies[slot].get_child(0) as CollisionShape3D
	shape.disabled = true
	_assigned[slot] = -1
