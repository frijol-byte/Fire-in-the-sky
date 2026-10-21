class_name Ship
extends RigidBody3D
## A flying ship: a `RigidBody3D` with a custom integrator, the ship's model and a
## `FlightController`. Whoever pilots it (the player's `PlayerPilot`, an AI, a test) writes
## `controls` each physics tick; nothing else steers the ship.
##
## The body is weightless and undamped: all motion comes from the flight controller. Jolt
## still resolves collisions, and flight assist then pulls the velocity back to the command.

## Everything about this ship class. Set it before the ship enters the tree.
@export var def: ShipDef = null

## The pilot's intent for this tick.
var controls: ShipControls = ShipControls.new()
## The instanced `.glb`, available once the ship is in the tree.
var model: ShipModel = null

@onready var _flight: FlightController = $FlightController
@onready var _power: PowerSystem = $PowerSystem
@onready var _engine_fx: EngineFx = $EngineFx


func _ready() -> void:
	custom_integrator = true
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
	_flight.def = def
	_flight.power = _power
	_flight.boost_depleted.connect(_on_boost_depleted)
	_build_model()
	_engine_fx.setup(self)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_flight.integrate(state, controls)
	_power.tick(state.step)


## The ship's energy capacitor (boost, and later weapons and devices, spend from it).
func power() -> PowerSystem:
	return _power


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
