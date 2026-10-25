class_name ProjectileManager
extends Node3D
## Flies every shot in the scene. Shots are pooled `Projectile` records, moved each physics tick
## with a sphere shape cast (so a fast shot cannot skip through a target) and drawn as stretched
## streaks by one `MultiMesh`. A shot that meets a body hurts it with `Durability.apply`; the
## body is anything with a `durability()` method (a `Ship` or a `TargetDummy`). Rocks and other
## world geometry just stop the shot.
##
## `WeaponSystem` finds the manager of its scene through the `GROUP` group. Each scene that has
## weapons adds one `ProjectileManager`; it adds its own `CombatFx` for flashes, sparks and sound.
##
## The pool never grows. When it is full, `spawn` reuses the oldest shot, which at the default
## size means a shot that has long left the screen.

## A shot hit something. `collider` is the body, `info` the damage that was dealt (null when the
## body has no durability, e.g. a rock), `result` what it did.
signal hit(shot: Projectile, collider: Object, info: DamageInfo, result: DamageResult)

## Draws every streak: a strip that turns its face to the camera (see the shader).
const STREAK_SHADER: Shader = preload("res://shaders/projectile_streak.gdshader")
## Group every manager joins, for `for_node`.
const GROUP: StringName = &"projectile_manager"
## Shots in the pool.
const DEFAULT_CAPACITY: int = 512
## A direction shorter than this (squared) is refused by `spawn`.
const MIN_DIRECTION_SQUARED: float = 0.001

var capacity: int = DEFAULT_CAPACITY
## Shots spawned over the manager's life (the pool reuse test counts these).
var spawned_total: int = 0
var fx: CombatFx = null

var _pool: Array[Projectile] = []
var _free: PackedInt32Array = []
var _active_count: int = 0
var _serial: int = 0
var _caster: SweepCaster = SweepCaster.new(PhysicsLayers.PROJECTILE_MASK)
var _multimesh: MultiMesh = null
var _streaks: MultiMeshInstance3D = null


## The manager of the scene `node` is in, or null.
static func for_node(node: Node) -> ProjectileManager:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as ProjectileManager


## The `Durability` of whatever `collider` is, or null for rocks and other plain geometry.
static func durability_of(collider: Object) -> Durability:
	if collider != null and collider.has_method(&"durability"):
		return collider.call(&"durability") as Durability
	return null


func _ready() -> void:
	add_to_group(GROUP)
	_build_pool()
	_build_streaks()
	if fx == null:
		fx = CombatFx.new()
		fx.name = "CombatFx"
		add_child(fx)


func _physics_process(delta: float) -> void:
	step(delta)


func _process(_delta: float) -> void:
	draw_streaks(Engine.get_physics_interpolation_fraction())


## Number of shots in flight.
func active_count() -> int:
	return _active_count


## Size of the pool (constant for the manager's life).
func pool_size() -> int:
	return _pool.size()


## The active shots, oldest first (a copy, for tests and tools).
func active_shots() -> Array[Projectile]:
	var result: Array[Projectile] = []
	for shot: Projectile in _pool:
		if shot.active:
			result.append(shot)
	result.sort_custom(func(a: Projectile, b: Projectile) -> bool: return a.serial < b.serial)
	return result


## Fires a shot of `weapon` from `origin` along `direction` (normalised here). Returns it, or
## null when `direction` is zero. A full pool gives up its oldest shot.
func spawn(weapon: WeaponDef, shooter: Node, origin: Vector3, direction: Vector3) -> Projectile:
	if direction.length_squared() < MIN_DIRECTION_SQUARED:
		return null
	var shot: Projectile = _take_slot()
	_serial += 1
	spawned_total += 1
	shot.launch(weapon, shooter, origin, direction.normalized(), _serial)
	_active_count += 1
	return shot


## Moves every active shot by `delta` seconds: a shape cast along its path, damage on a hit,
## and retirement when it has flown its range. `_physics_process` calls it; sims may too.
func step(delta: float) -> void:
	for shot: Projectile in _pool:
		if shot.active:
			_advance(shot, delta)


## Writes the streak transforms for the active shots, drawn `fraction` of the way between their
## last two physics positions. `_process` calls it every frame.
func draw_streaks(fraction: float) -> void:
	var drawn: int = 0
	for shot: Projectile in _pool:
		if not shot.active:
			continue
		var direction: Vector3 = shot.velocity.normalized()
		var head: Vector3 = shot.drawn_position(fraction)
		var weapon: WeaponDef = shot.weapon
		_multimesh.set_instance_transform(drawn, streak_transform(head, direction, weapon))
		_multimesh.set_instance_color(drawn, weapon.tracer_color)
		drawn += 1
	_multimesh.visible_instance_count = drawn


## Transform of a streak whose head is at `head`, flying along `direction`: a box as long as the
## weapon's tracer, trailing behind the head.
static func streak_transform(head: Vector3, direction: Vector3, weapon: WeaponDef) -> Transform3D:
	return streak_at(head, direction, weapon.tracer_length, weapon.tracer_width)


## Transform of a streak `length` metres long and `width` wide whose head is at `head`, flying
## along `direction`. Missiles and flares are drawn with the same shader.
static func streak_at(
	head: Vector3, direction: Vector3, length: float, width: float
) -> Transform3D:
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var basis: Basis = Basis.looking_at(direction, up)
	basis = basis.scaled_local(Vector3(width, width, length))
	return Transform3D(basis, head - direction * length * 0.5)


func _take_slot() -> Projectile:
	if not _free.is_empty():
		var index: int = _free[_free.size() - 1]
		_free.resize(_free.size() - 1)
		return _pool[index]
	# Pool full: reuse the oldest shot.
	var oldest: Projectile = null
	for shot: Projectile in _pool:
		if oldest == null or shot.serial < oldest.serial:
			oldest = shot
	_active_count -= 1
	oldest.retire()
	return oldest


func _retire(shot: Projectile) -> void:
	shot.retire()
	_free.append(shot.index)
	_active_count -= 1


func _advance(shot: Projectile, delta: float) -> void:
	shot.previous = shot.position
	var motion: Vector3 = shot.velocity * delta
	var remaining: float = shot.weapon.range_m - shot.travelled
	var out_of_range: bool = false
	if motion.length() >= remaining:
		motion = motion.normalized() * maxf(remaining, 0.0)
		out_of_range = true
	var contact: Dictionary = _cast(shot, motion)
	if contact.is_empty():
		shot.position += motion
		shot.travelled += motion.length()
		if out_of_range:
			_retire(shot)
		return
	shot.position = contact["position"] as Vector3
	shot.travelled += shot.position.distance_to(shot.previous)
	_land(shot, contact)


## Sweeps the shot's sphere along `motion` (see `SweepCaster.cast`).
func _cast(shot: Projectile, motion: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	return _caster.cast(space, shot.position, motion, shot.weapon.projectile_radius, shot.exclude)


func _land(shot: Projectile, contact: Dictionary) -> void:
	var collider: Object = contact["collider"] as Object
	var point: Vector3 = contact["point"] as Vector3
	var normal: Vector3 = contact["normal"] as Vector3
	var weapon: WeaponDef = shot.weapon
	var durability: Durability = durability_of(collider)
	var info: DamageInfo = null
	var result: DamageResult = null
	if durability != null:
		# The firing ship may have been removed (respawn) while the shot was in flight.
		var source: Node = shot.shooter if is_instance_valid(shot.shooter) else null
		info = DamageInfo.make(weapon.damage, weapon.damage_type, source, point)
		result = durability.apply(info)
	if fx != null:
		fx.impact(point, normal, weapon, result)
	hit.emit(shot, collider, info, result)
	_retire(shot)


func _build_pool() -> void:
	for index: int in capacity:
		var shot: Projectile = Projectile.new()
		shot.index = index
		_pool.append(shot)
	# Slots are taken from the end of `_free`, so the first shot uses slot 0.
	for index: int in range(capacity - 1, -1, -1):
		_free.append(index)


func _build_streaks() -> void:
	_streaks = make_streaks(capacity)
	_multimesh = _streaks.multimesh
	add_child(_streaks)


## A `MultiMeshInstance3D` of `count` streaks (all hidden) drawn with the streak shader: instance
## colour is the streak colour, `streak_at` gives the transform. Missiles and flares use it too.
static func make_streaks(count: int) -> MultiMeshInstance3D:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STREAK_SHADER
	mesh.material = material
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	var streaks: MultiMeshInstance3D = MultiMeshInstance3D.new()
	streaks.name = "Streaks"
	streaks.top_level = true
	streaks.multimesh = multimesh
	streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streaks.extra_cull_margin = 16384.0
	streaks.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return streaks
