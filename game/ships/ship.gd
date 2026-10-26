class_name Ship
extends RigidBody3D
## A flying ship: a `RigidBody3D` with a custom integrator, the ship's model and a
## `FlightController`. Whoever pilots it (the player's `PlayerPilot`, an AI, a test) writes
## `controls` each physics tick; nothing else steers the ship.
##
## When the ship is destroyed `DestructionManager` calls `begin_wreck`: the ship stops flying, tumbles
## on, loses its collision and its targetability, and its model shrinks away (`wreck_faded` is
## emitted when it is gone). The ship node itself stays until whoever owns it removes it.
##
## The body is weightless and undamped: all motion comes from the flight controller. Jolt
## still resolves collisions, and flight assist then pulls the velocity back to the command.

## Emitted once, when a wreck's model has shrunk away completely.
signal wreck_faded

## Everything about this ship class. Set it before the ship enters the tree.
@export var def: ShipDef = null

## The pilot's intent for this tick.
var controls: ShipControls = ShipControls.new()
## The instanced `.glb`, available once the ship is in the tree.
var model: ShipModel = null
## Whose side this ship is on, as other ships' targeting and the HUD see it. Whoever spawns an
## enemy or an ally sets it (factions arrive in M6).
var stance: Targeting.Stance = Targeting.Stance.HOSTILE

var _target_radius: float = 6.0
## Seconds since the ship became a wreck, or -1 while it is a ship.
var _wreck_age: float = -1.0
var _wreck_fade: float = 1.0
var _wreck_spin: Vector3 = Vector3.ZERO
var _wreck_faded: bool = false

@onready var _flight: FlightController = $FlightController
@onready var _power: PowerSystem = $PowerSystem
@onready var _durability: Durability = $Durability
@onready var _weapons: WeaponSystem = $WeaponSystem
@onready var _secondaries: SecondarySystem = $SecondarySystem
@onready var _devices: DeviceSystem = $DeviceSystem
@onready var _targeting: Targeting = $Targeting
@onready var _shield_fx: ShieldFx = $ShieldFx
@onready var _engine_fx: EngineFx = $EngineFx


func _ready() -> void:
	custom_integrator = true
	collision_layer = PhysicsLayers.SHIPS
	collision_mask = PhysicsLayers.SHIP_MASK
	gravity_scale = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	# A resting body would go to sleep and stop running the flight controller.
	can_sleep = false
	# At 320 m/s a ship moves 5 m per tick: sweep so it cannot tunnel through rocks.
	continuous_cd = true
	if def == null:
		Log.error(&"ship", "Ship has no ShipDef")
		return
	mass = def.mass
	_power.configure(def)
	_durability.configure(def, self)
	_flight.def = def
	_flight.power = _power
	_flight.boost_depleted.connect(_on_boost_depleted)
	_build_model()
	_engine_fx.setup(self)
	_weapons.configure(self)
	_secondaries.configure(self)
	_devices.configure(self)
	add_to_group(Targeting.GROUP)
	var bounds: AABB = ShieldFx.bounds_of(model, self)
	_target_radius = bounds.size.length() * 0.5
	_shield_fx.setup(self, bounds.get_center(), bounds.size * 0.5)


func _process(_delta: float) -> void:
	if _wreck_age >= 0.0 and not _wreck_faded:
		_fade_wreck()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _wreck_age >= 0.0:
		# A wreck coasts on with the velocity it had and tumbles; nobody flies it any more.
		state.angular_velocity = _wreck_spin
		_wreck_age += state.step
		return
	_flight.integrate(state, controls)
	_power.tick(state.step)
	_durability.tick(state.step)


## `LootTableDef` id of what this ship drops when destroyed (empty for none).
func loot_table_id() -> StringName:
	return def.loot_table_id


## Turns the destroyed ship into a wreck: it coasts and tumbles at the angular velocity `spin`
## (radians per second), stops colliding and being targeted, its engines go dark, and its model
## shrinks away over `look.wreck_fade_seconds`. Call it once, after the hull is gone.
func begin_wreck(look: DestructionDef, spin: Vector3) -> void:
	if _wreck_age >= 0.0:
		return
	_wreck_age = 0.0
	_wreck_fade = look.wreck_fade_seconds
	_wreck_spin = spin
	_wreck_faded = false
	collision_layer = 0
	collision_mask = 0
	remove_from_group(Targeting.GROUP)
	_flight.boosting = false
	_engine_fx.shut_down()
	_shield_fx.visible = false
	controls = ShipControls.new()


## True once the ship has been destroyed and is only a wreck.
func is_wrecked() -> bool:
	return _wreck_age >= 0.0


## The ship's energy capacitor (boost, and later weapons and devices, spend from it).
func power() -> PowerSystem:
	return _power


## The ship's shield, armor and hull. `durability().apply(info)` is the only way to hurt it.
func durability() -> Durability:
	return _durability


## The ship's guns. They fire while `controls.fire_primary` is held.
func weapons() -> WeaponSystem:
	return _weapons


## The ship's missiles or rockets. They launch while `controls.fire_secondary` is held / pressed.
func secondaries() -> SecondarySystem:
	return _secondaries


## The ship's devices (flares). `controls.device` uses one.
func devices() -> DeviceSystem:
	return _devices


## The ship's target selection and lock. The pilot's `controls.target_cmd` drives it.
func targeting() -> Targeting:
	return _targeting


## The methods below make a ship a valid target for `Targeting` (see its header).
func target_name() -> String:
	return tr(def.display_name_key)


func target_stance() -> Targeting.Stance:
	return stance


func target_velocity() -> Vector3:
	return linear_velocity


## Roughly how big the ship looks, in metres: half the diagonal of its hull's bounding box.
func target_radius() -> float:
	return _target_radius


## Re-reads the values of `def` that are copied at spawn (mass, the capacitor). The flight
## controller and camera read `def` every tick, so the tuning overlay only needs this one call.
func refresh_from_def() -> void:
	mass = def.mass
	_power.retune(def)


## True while boost is firing.
func is_boosting() -> bool:
	return _flight.boosting


## Returns the velocity in the ship's own axes (-Z is forward), handy for HUDs and tests.
func local_velocity() -> Vector3:
	return global_basis.orthonormalized().inverse() * linear_velocity


func _fade_wreck() -> void:
	var amount: float = DestructionMath.wreck_scale(_wreck_age, _wreck_fade)
	model.scale = Vector3.ONE * maxf(amount, 0.001)
	if amount <= 0.0:
		_wreck_faded = true
		model.visible = false
		wreck_faded.emit()


func _on_boost_depleted() -> void:
	Events.boost_depleted.emit(self)


func _build_model() -> void:
	var packed: PackedScene = load(def.model_path) as PackedScene
	model = packed.instantiate() as ShipModel
	add_child(model)
	model.set_paint(def.paint_primary, def.paint_secondary)
	_adopt_collision(model)


## The imported model carries a `Collision` StaticBody3D with a convex hull. A static body
## inside a rigid body would block it, so the shapes move onto the ship and the body is freed.
func _adopt_collision(from_model: Node) -> void:
	var body: Node = from_model.get_node_or_null(ModelImportRules.COLLISION_NAME)
	if body == null:
		return
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).reparent(self, true)
	from_model.remove_child(body)
	body.free()
