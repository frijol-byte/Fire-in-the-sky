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
	_flight.def = def
	_build_model()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_flight.integrate(state, controls)


## Returns the velocity in the ship's own axes (-Z is forward), handy for HUDs and tests.
func local_velocity() -> Vector3:
	return global_basis.orthonormalized().inverse() * linear_velocity


func _build_model() -> void:
	var packed: PackedScene = load(def.model_path) as PackedScene
	model = packed.instantiate() as ShipModel
	add_child(model)
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
