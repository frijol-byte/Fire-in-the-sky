class_name TargetDummy
extends AnimatableBody3D
## A practice target: a sphere with the same shield, armor and hull layers as a ship, so every
## weapon is tested against the real damage code. It stands still, or slides back and forth along
## a rail (`rail_position`), and comes back repaired a few seconds after it is destroyed. It joins
## the `GROUP` group so targeting can find it later.
##
## The numbers come from a `DummyDef`; where it stands and how far its rail runs comes from the
## `ArenaDef` that places it. Projectiles hurt it through `durability()`, like a ship.

## Everything shootable that is not a ship joins this group.
const GROUP: StringName = &"targets"
## The shield bubble is this much bigger than the dummy's ball.
const BUBBLE_MARGIN: float = 1.12

## Where the dummy is now, in metres per second (zero for a static dummy). The lead calculation of
## M2-T3 reads it.
var velocity: Vector3 = Vector3.ZERO
var def: DummyDef = null

var _origin: Vector3 = Vector3.ZERO
## Where the dummy was put last tick. With `sync_to_physics` the body's own position only follows
## after the next physics step, so the dummy keeps its own record for working out `velocity`.
var _position: Vector3 = Vector3.ZERO
var _rail: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _respawn_left: float = 0.0
var _destroyed: bool = false
var _shown_health: Vector3i = Vector3i(-1, -1, -1)

@onready var _shape: CollisionShape3D = $Shape
@onready var _mesh: MeshInstance3D = $Mesh
@onready var _durability: Durability = $Durability
@onready var _shield: ShieldFx = $ShieldFx
@onready var _label: Label3D = $Label


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = PhysicsLayers.TARGETS
	collision_mask = 0
	sync_to_physics = true
	Events.ship_destroyed.connect(_on_ship_destroyed)


func _physics_process(delta: float) -> void:
	if def == null:
		return
	_time += delta
	var wanted: Vector3 = rail_position(_origin, _rail, def.rail_speed, _time)
	velocity = (wanted - _position) / delta if delta > 0.0 else Vector3.ZERO
	_position = wanted
	global_position = wanted
	_durability.tick(delta)
	if _destroyed:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			respawn()
	_refresh_label()


## Builds the dummy from `new_def`, standing at `origin` (set `position` to it before the dummy
## enters the tree too, so the physics body never starts somewhere else); a non-zero `rail` makes it slide to
## `origin + rail` and back at the def's rail speed.
func setup(new_def: DummyDef, origin: Vector3, rail: Vector3 = Vector3.ZERO) -> void:
	def = new_def
	_origin = origin
	_rail = rail
	_time = 0.0
	_position = origin
	global_position = origin
	(_shape.shape as SphereShape3D).radius = def.radius
	var sphere: SphereMesh = _mesh.mesh as SphereMesh
	sphere.radius = def.radius
	sphere.height = def.radius * 2.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = def.color
	material.roughness = 0.6
	material.metallic = 0.4
	# A little glow of its own, so it reads against a dark or orange background.
	material.emission_enabled = true
	material.emission = def.color
	material.emission_energy_multiplier = 0.2
	_mesh.material_override = material
	_durability.configure_layers(def.capacities(), def.shield_regen, def.shield_regen_delay, self)
	# A little outside the ball, so the ripple is not drawn into its surface.
	_shield.setup(
		self, Vector3.ZERO, Vector3.ONE * def.radius * BUBBLE_MARGIN / ShieldFx.BOUNDS_MARGIN
	)
	_label.position = Vector3(0.0, def.radius + 2.0, 0.0)
	_refresh_label()


## The dummy's shield, armor and hull (`ProjectileManager` hurts whatever has this).
func durability() -> Durability:
	return _durability


func is_destroyed() -> bool:
	return _destroyed


## Brings a destroyed dummy back, fully repaired.
func respawn() -> void:
	_destroyed = false
	_durability.restore()
	visible = true
	_shape.disabled = false
	_refresh_label()


## Where a dummy on a rail from `origin` to `origin + rail` is after `time` seconds moving at
## `speed`: it runs out and back, forever. With no rail or no speed it stays at `origin`.
static func rail_position(origin: Vector3, rail: Vector3, speed: float, time: float) -> Vector3:
	var length: float = rail.length()
	if length <= 0.0 or speed <= 0.0:
		return origin
	var along: float = fposmod(speed * time, 2.0 * length)
	if along > length:
		along = 2.0 * length - along
	return origin + rail / length * along


func _on_ship_destroyed(ship: Node, _info: DamageInfo) -> void:
	if ship != self:
		return
	_destroyed = true
	_respawn_left = def.respawn_seconds
	visible = false
	_shape.set_deferred(&"disabled", true)
	_refresh_label()


func _refresh_label() -> void:
	var health: Vector3i = Vector3i(
		ceili(_durability.shield), ceili(_durability.armor), ceili(_durability.hull)
	)
	if health == _shown_health:
		return
	_shown_health = health
	_label.text = tr("DUMMY_HEALTH") % [health.x, health.y, health.z]
