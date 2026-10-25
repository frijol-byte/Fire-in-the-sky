class_name CombatSim
extends RefCounted
## Helpers for combat sims: a projectile manager, target dummies and ships with working guns in
## an otherwise empty scene, plus ways to wait for a hit. Used by `test_projectile_sim.gd` and
## `test_weapon_sim.gd`.

const DUMMY_SCENE: PackedScene = preload("res://world/props/target_dummy.tscn")


## Adds a `ProjectileManager` to `parent`.
static func spawn_manager(parent: Node) -> ProjectileManager:
	var manager: ProjectileManager = ProjectileManager.new()
	parent.add_child(manager)
	return manager


## Adds a `MissileManager` to `parent`, with room for `capacity` rounds in flight.
static func spawn_missile_manager(
	parent: Node, capacity: int = MissileManager.DEFAULT_CAPACITY
) -> MissileManager:
	var manager: MissileManager = MissileManager.new()
	manager.capacity = capacity
	parent.add_child(manager)
	return manager


## Adds a ship of `ship_id` to `parent` at `position`, its nose towards `look_at` (default: -Z).
static func spawn_ship(
	parent: Node, ship_id: StringName, position: Vector3, look_at: Vector3 = Vector3.INF
) -> Ship:
	var ship: Ship = FlightSim.spawn(parent, ship_id)
	var facing: Vector3 = Vector3.FORWARD if look_at == Vector3.INF else look_at - position
	ship.global_transform = Transform3D(Basis.looking_at(facing, Vector3.UP), position)
	return ship


## Adds a dummy of `def_id` to `parent`, standing at `origin` (sliding along `rail` if not zero).
static func spawn_dummy(
	parent: Node, def_id: StringName, origin: Vector3, rail: Vector3 = Vector3.ZERO
) -> TargetDummy:
	var dummy: TargetDummy = DUMMY_SCENE.instantiate() as TargetDummy
	dummy.position = origin
	parent.add_child(dummy)
	dummy.setup(Content.dummy(def_id), origin, rail)
	return dummy


## Adds a static wall (a box, `size` metres) centred at `position` on the world layer.
static func spawn_wall(parent: Node, position: Vector3, size: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = PhysicsLayers.WORLD
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	parent.add_child(wall)
	wall.global_position = position
	return wall


## Records every explosion a `MissileManager` reports, as {tick, point, harmless, missile}.
class BlastLog:
	extends RefCounted
	var blasts: Array[Dictionary] = []
	var ticks: int = 0

	func attach(manager: MissileManager) -> void:
		manager.exploded.connect(_on_exploded)

	func _on_exploded(missile: Missile, point: Vector3, harmless: bool) -> void:
		blasts.append({"tick": ticks, "point": point, "harmless": harmless, "missile": missile})

	func damaging() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		for blast: Dictionary in blasts:
			if not (blast["harmless"] as bool):
				result.append(blast)
		return result


## Lets the physics server register freshly added bodies.
static func settle(tree: SceneTree) -> void:
	await SimHelper.step_physics(tree, 2)


## Records every hit the manager reports, as {tick, collider, info, result}.
class HitLog:
	extends RefCounted
	var hits: Array[Dictionary] = []
	var ticks: int = 0

	func attach(manager: ProjectileManager) -> void:
		manager.hit.connect(_on_hit)

	func _on_hit(
		_shot: Projectile, collider: Object, info: DamageInfo, result: DamageResult
	) -> void:
		hits.append({"tick": ticks, "collider": collider, "info": info, "result": result})


## Steps physics up to `max_ticks` times, until `log` has `count` hits. Returns the ticks used.
static func run_until_hits(tree: SceneTree, log: HitLog, count: int, max_ticks: int) -> int:
	log.ticks = 0
	while log.hits.size() < count and log.ticks < max_ticks:
		await tree.physics_frame
		log.ticks += 1
	return log.ticks
