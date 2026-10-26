class_name DestructionManager
extends Node3D
## What happens when a ship (or a target dummy) is destroyed (M2-T6). It listens for
## `Events.ship_destroyed` and, for the thing that blew up:
##   - makes the explosion: the flash, sparks and boom of `CombatFx.explosion`, a fireball card
##     (`shaders/fireball.gdshader`) with a shockwave ring, a point light and a deeper boom;
##   - throws debris chunks (`DebrisField`);
##   - turns a `Ship` into a wreck (`Ship.begin_wreck`: it tumbles, loses its collision and shrinks
##     away; an AI ship is then removed, the player's stays for the respawn flow);
##   - drops loot containers from the thing's `LootTableDef` (`LootManager`). The player's own ship
##     drops none: it loses its cargo and loot to the insurance rules (M4).
##
## Each scene with fighting adds one, like `ProjectileManager`. It makes its own `CombatFx`, debris
## field and loot manager. Fireballs, rings and lights are pooled.

## An explosion went off at `position`. `radius` is the fireball's.
signal blasted(node: Node, position: Vector3, radius: float)

## Group the manager joins, for `for_node`.
const GROUP: StringName = &"destruction_manager"
const FIREBALL_POOL: int = 6
const FIREBALL_SHADER: Shader = preload("res://shaders/fireball.gdshader")
const SOUND_BOOM_DB: float = 2.0
## The big boom is played lower than the missile blast.
const BOOM_PITCH: float = 0.8
## Seed of the debris and loot rolls, so sims repeat.
const ROLL_SEED: int = 4242
## The flash and sparks of `CombatFx.explosion` are this fraction of the fireball's radius.
const FLASH_FACTOR: float = 0.9


class Blast:
	extends RefCounted
	var fireball: MeshInstance3D = null
	var fire_material: ShaderMaterial = null
	var ring: MeshInstance3D = null
	var ring_material: ShaderMaterial = null
	var light: OmniLight3D = null
	var age: float = -1.0
	var radius: float = 1.0
	var fireball_seconds: float = 1.0
	var light_seconds: float = 1.0
	var light_peak: float = 0.0
	var shockwave_factor: float = 1.8


var destruction: DestructionDef = null
var fx: CombatFx = null
var debris: DebrisField = null
var loot: LootManager = null
## Explosions made over the manager's life.
var explosions_total: int = 0

var _blasts: Array[Blast] = []
var _next_blast: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## The destruction manager of the scene `node` is in, or null.
static func for_node(node: Node) -> DestructionManager:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as DestructionManager


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	_rng.seed = ROLL_SEED
	if destruction == null:
		destruction = Content.destruction()
	if fx == null:
		fx = CombatFx.new()
		fx.name = "CombatFx"
		add_child(fx)
	debris = DebrisField.new()
	debris.name = "DebrisField"
	add_child(debris)
	loot = LootManager.new()
	loot.name = "LootManager"
	loot.fx = fx
	add_child(loot)
	for index: int in FIREBALL_POOL:
		_blasts.append(_make_blast(index))
	Events.ship_destroyed.connect(_on_ship_destroyed)


func _process(delta: float) -> void:
	advance(delta)


## Advances every running fireball, ring and light by `delta` seconds. `_process` calls it.
func advance(delta: float) -> void:
	for blast: Blast in _blasts:
		if blast.age < 0.0:
			continue
		blast.age += delta
		_draw(blast)


## Fireballs showing right now.
func active_blasts() -> int:
	var count: int = 0
	for blast: Blast in _blasts:
		if blast.age >= 0.0:
			count += 1
	return count


## An explosion at `position` with a fireball of `radius` metres (see `DestructionMath.fireball_radius`),
## the debris of a wreck of `size` metres moving at `velocity`, and no loot.
func explode(position: Vector3, radius: float, size: float, velocity: Vector3) -> void:
	explosions_total += 1
	fx.explosion(position, radius * FLASH_FACTOR, destruction.fireball_color)
	fx.play(CombatFx.SOUND_EXPLOSION, position, SOUND_BOOM_DB, BOOM_PITCH)
	var blast: Blast = _blasts[_next_blast]
	_next_blast = (_next_blast + 1) % _blasts.size()
	blast.age = 0.0
	blast.radius = radius
	blast.fireball_seconds = destruction.fireball_seconds
	blast.light_seconds = destruction.light_seconds
	blast.light_peak = destruction.light_energy
	blast.shockwave_factor = destruction.shockwave_factor
	blast.fire_material.set_shader_parameter(&"noise_seed", _rng.randf() * 10.0)
	blast.fire_material.set_shader_parameter(&"fire_color", destruction.fireball_color)
	blast.ring_material.set_shader_parameter(&"fire_color", destruction.fireball_color)
	blast.fireball.global_position = position
	blast.ring.global_position = position
	blast.light.global_position = position
	blast.light.omni_range = radius * destruction.light_range_factor
	blast.light.light_color = destruction.fireball_color
	_draw(blast)
	debris.burst(position, velocity, size, destruction, _rng)


func _on_ship_destroyed(node: Node, _info: DamageInfo) -> void:
	var body: Node3D = node as Node3D
	if body == null or not body.is_inside_tree() or not is_inside_tree():
		return
	var size: float = body.call(&"target_radius") if body.has_method(&"target_radius") else 4.0
	var velocity: Vector3 = (
		body.call(&"target_velocity") if body.has_method(&"target_velocity") else Vector3.ZERO
	)
	var position: Vector3 = body.global_position
	explode(position, DestructionMath.fireball_radius(destruction, size), size, velocity)
	var ship: Ship = body as Ship
	var is_player: bool = false
	if ship != null:
		is_player = ship.targeting().is_player
		ship.begin_wreck(destruction, DestructionMath.tumble(_rng, destruction.wreck_tumble_deg))
		if not is_player:
			ship.wreck_faded.connect(_remove_wreck.bind(ship), CONNECT_ONE_SHOT)
	if not is_player:
		_drop_loot(body, position, velocity)
	blasted.emit(body, position, DestructionMath.fireball_radius(destruction, size))


func _drop_loot(body: Node3D, position: Vector3, velocity: Vector3) -> void:
	if not body.has_method(&"loot_table_id"):
		return
	var table: LootTableDef = Content.loot_table(body.call(&"loot_table_id") as StringName)
	if table == null:
		return
	for drop: LootDrop in table.roll(_rng):
		loot.spawn(
			drop,
			position,
			DestructionMath.scatter_velocity(_rng, table.scatter_speed, velocity),
			table.lifetime_seconds,
			table.scatter_drag
		)


## An AI wreck has faded away: take it out of the world.
func _remove_wreck(ship: Ship) -> void:
	if not is_instance_valid(ship):
		return
	var parent: Node = ship.get_parent()
	if parent != null:
		parent.remove_child(ship)
	ship.queue_free()


func _draw(blast: Blast) -> void:
	var fire_t: float = DestructionMath.progress(blast.age, blast.fireball_seconds)
	var fire_on: bool = blast.age < blast.fireball_seconds
	blast.fireball.visible = fire_on
	blast.ring.visible = fire_on
	if fire_on:
		blast.fire_material.set_shader_parameter(&"progress", fire_t)
		blast.ring_material.set_shader_parameter(&"progress", fire_t)
		blast.fireball.scale = Vector3.ONE * blast.radius * 2.0
		blast.ring.scale = Vector3.ONE * blast.radius * 2.0 * blast.shockwave_factor
	var energy: float = DestructionMath.light_energy(
		blast.age, blast.light_seconds, blast.light_peak
	)
	blast.light.light_energy = energy
	blast.light.visible = energy > 0.0
	if not fire_on and energy <= 0.0:
		blast.age = -1.0


func _make_blast(index: int) -> Blast:
	var blast: Blast = Blast.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	blast.fire_material = ShaderMaterial.new()
	blast.fire_material.shader = FIREBALL_SHADER
	blast.fireball = _make_card("Fireball%d" % index, quad, blast.fire_material)
	blast.ring_material = ShaderMaterial.new()
	blast.ring_material.shader = FIREBALL_SHADER
	blast.ring_material.set_shader_parameter(&"ring", true)
	blast.ring = _make_card("Shockwave%d" % index, quad, blast.ring_material)
	blast.light = OmniLight3D.new()
	blast.light.name = "Light%d" % index
	blast.light.shadow_enabled = false
	blast.light.visible = false
	blast.light.light_energy = 0.0
	add_child(blast.light)
	return blast


func _make_card(card_name: String, mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var card: MeshInstance3D = MeshInstance3D.new()
	card.name = card_name
	card.mesh = mesh
	card.material_override = material
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.extra_cull_margin = 4096.0
	card.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	card.visible = false
	add_child(card)
	return card
