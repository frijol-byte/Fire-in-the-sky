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
