class_name LootManager
extends Node3D
## Looks after every loot container in the scene (M2-T6): drops them where a ship blew up, lets
## them drift and expire, and runs the player's tractor beam. A container within the tractor's
## range of the player's ship is pulled in, and collected when it reaches the ship: `GameState`
## pays it out (the debug wallet) and `Events.loot_collected` is emitted. Only the player's ship has
## a tractor; AI ships ignore loot.
##
## `DestructionManager` owns one and spawns into it. The number of containers never grows past
## `max_containers`: when it is full, the oldest one goes.

signal collected(container: LootContainer, ship: Ship)
signal expired(container: LootContainer)

## Group the manager joins, for `for_node`.
const GROUP: StringName = &"loot_manager"
const DEFAULT_MAX_CONTAINERS: int = 48
const CRATE_SIZE: float = 1.8
const GLOW_SIZE: float = 7.0
const GLOW_TEXTURE_SIZE: int = 64
const CREDITS_COLOR: Color = Color(1.0, 0.8, 0.25)
const MATERIAL_COLOR: Color = Color(0.35, 0.85, 1.0)
const SPIN_MAX: float = 1.6
const SOUND_PICKUP: AudioStreamWAV = preload("res://assets/audio/sfx/loot_pickup.wav")
const PICKUP_SOUND_DB: float = -4.0

var max_containers: int = DEFAULT_MAX_CONTAINERS
var tractor: TractorDef = null
## Plays the pickup sound (set by `DestructionManager`; without it pickups are silent).
var fx: CombatFx = null
## Containers dropped over the manager's life, and collected.
var spawned_total: int = 0
var collected_total: int = 0

var _containers: Array[LootContainer] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _crate_mesh: BoxMesh = null
var _glow_mesh: QuadMesh = null
var _credits_materials: Array[Material] = []
var _material_materials: Array[Material] = []


## The loot manager of the scene `node` is in, or null.
static func for_node(node: Node) -> LootManager:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as LootManager


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	if tractor == null:
		tractor = Content.tractor()
	_rng.seed = 24601
	_crate_mesh = BoxMesh.new()
	_crate_mesh.size = Vector3.ONE * CRATE_SIZE
	_glow_mesh = QuadMesh.new()
	_glow_mesh.size = Vector2.ONE * GLOW_SIZE
	var glow: GradientTexture2D = _glow_texture()
	_credits_materials = _make_materials(CREDITS_COLOR, glow)
	_material_materials = _make_materials(MATERIAL_COLOR, glow)


func _physics_process(delta: float) -> void:
	if tractor == null:
		return
	advance(delta, find_collector())


## Drops `drop` at `position`, drifting at `velocity` and gone after `lifetime` seconds. Returns the
## container (the oldest is removed first when there are `max_containers`).
func spawn(
	drop: LootDrop, position: Vector3, velocity: Vector3, lifetime: float, drag: float = 0.0
) -> LootContainer:
	while _containers.size() >= max_containers:
		_remove(_containers[0])
	var container: LootContainer = LootContainer.new()
	container.drop = drop
	container.velocity = velocity
	container.left = lifetime
	container.spin = Vector3(
		_rng.randf_range(-SPIN_MAX, SPIN_MAX),
		_rng.randf_range(-SPIN_MAX, SPIN_MAX),
		_rng.randf_range(-SPIN_MAX, SPIN_MAX)
	)
	container.drag = drag
	var materials: Array[Material] = (
		_credits_materials if drop.is_credits() else _material_materials
	)
	var crate: MeshInstance3D = MeshInstance3D.new()
	crate.name = "Crate"
	crate.mesh = _crate_mesh
	crate.material_override = materials[0]
	crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(crate)
	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.name = "Glow"
	glow.mesh = _glow_mesh
	glow.material_override = materials[1]
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	container.add_child(glow)
	add_child(container)
	container.global_position = position
	_containers.append(container)
	spawned_total += 1
	return container


## How many containers are floating about.
func count() -> int:
	return _containers.size()


## The containers floating about, oldest first.
func containers() -> Array[LootContainer]:
	return _containers.duplicate()


## Moves every container by `delta` seconds, pulling those near `collector` (the player's ship, or
## null for none) and collecting those it reaches. `_physics_process` calls it; sims may too.
func advance(delta: float, collector: Ship) -> void:
	var gone: Array[LootContainer] = []
	var caught: Array[LootContainer] = []
	for container: LootContainer in _containers:
		container.left -= delta
		if container.left <= 0.0:
			gone.append(container)
			continue
		_move(container, delta, collector)
		if collector != null and _reached(container, collector):
			caught.append(container)
	for container: LootContainer in caught:
		_collect(container, collector)
	for container: LootContainer in gone:
		expired.emit(container)
		_remove(container)


## The player's ship, if there is one that is alive: the one with its `Targeting.is_player` set.
func find_collector() -> Ship:
	for node: Node in get_tree().get_nodes_in_group(Targeting.GROUP):
		var ship: Ship = node as Ship
		if ship != null and ship.targeting().is_player and not ship.durability().is_destroyed():
			return ship
	return null


func _move(container: LootContainer, delta: float, collector: Ship) -> void:
	var pulled: bool = false
	if collector != null:
		var to_ship: Vector3 = collector.global_position - container.global_position
		pulled = LootMath.in_tractor_range(to_ship.length(), tractor)
		if pulled:
			container.pull_speed = LootMath.next_pull_speed(container.pull_speed, tractor, delta)
			container.velocity = LootMath.pulled_velocity(
				collector.linear_velocity, to_ship, container.pull_speed
			)
	if not pulled:
		container.pull_speed = 0.0
		container.velocity = LootMath.drifted_velocity(container.velocity, container.drag, delta)
	container.global_position += container.velocity * delta
	container.rotate_x(container.spin.x * delta)
	container.rotate_y(container.spin.y * delta)
	container.rotate_z(container.spin.z * delta)
	container.scale = Vector3.ONE * LootMath.expiry_scale(container.left)


func _reached(container: LootContainer, collector: Ship) -> bool:
	var distance: float = collector.global_position.distance_to(container.global_position)
	return LootMath.is_collected(distance, tractor)


func _collect(container: LootContainer, collector: Ship) -> void:
	GameState.collect(container.drop)
	collected_total += 1
	Events.loot_collected.emit(collector, container.drop)
	collected.emit(container, collector)
	if fx != null:
		fx.play(SOUND_PICKUP, container.global_position, PICKUP_SOUND_DB)
	_remove(container)


func _remove(container: LootContainer) -> void:
	_containers.erase(container)
	remove_child(container)
	container.free()


func _make_materials(color: Color, glow_texture: Texture2D) -> Array[Material]:
	var crate: StandardMaterial3D = StandardMaterial3D.new()
	crate.albedo_color = color.darkened(0.45)
	crate.metallic = 0.5
	crate.roughness = 0.45
	crate.emission_enabled = true
	crate.emission = color
	crate.emission_energy_multiplier = 1.6
	var halo: StandardMaterial3D = StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.billboard_keep_scale = true
	halo.albedo_texture = glow_texture
	halo.albedo_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.8)
	halo.disable_receive_shadows = true
	halo.cull_mode = BaseMaterial3D.CULL_DISABLED
	var result: Array[Material] = [crate, halo]
	return result


func _glow_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray(
		[Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.35), Color(1.0, 1.0, 1.0, 0.0)]
	)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE
	return texture
