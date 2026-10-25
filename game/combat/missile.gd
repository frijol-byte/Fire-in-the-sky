class_name Missile
extends RefCounted
## One missile or rocket in flight. `MissileManager` owns a fixed pool of these and reuses them, so
## a round is data, not a node: nothing is created or freed while the game runs.

## False while the slot is free in the pool.
var active: bool = false
## Slot in the manager's pool.
var index: int = 0
## Order of launching; the oldest active round is the one reused when the pool is full.
var serial: int = 0
var def: SecondaryDef = null
## The ship that fired it (the damage `source`, never hurt by its own splash), or null.
var shooter: Node = null
## What it is steering towards (a ship or a dummy), or null for a dumb-fire rocket.
var target: Node3D = null
## A flare the seeker has been fooled by, and the serial it had when it was chosen (a flare slot is
## reused, so a changed serial means that flare is gone). Null while it still follows `target`.
var decoy: Flare = null
var decoy_serial: int = 0
## True while the seeker still steers. It turns false for good when the target or decoy is gone.
var guided: bool = false
## The shape cast ignores these bodies, so a round does not hit its own ship.
var exclude: Array[RID] = []
var position: Vector3 = Vector3.ZERO
## Where it was one physics tick ago; the picture is drawn between the two (interpolation).
var previous: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Seconds since launch.
var age: float = 0.0
## Metres flown so far.
var travelled: float = 0.0


## Starts the round at `origin` with `start_velocity`. A `new_target` makes it a homing missile.
func launch(
	new_def: SecondaryDef,
	new_shooter: Node,
	origin: Vector3,
	start_velocity: Vector3,
	new_target: Node3D,
	new_serial: int
) -> void:
	active = true
	serial = new_serial
	def = new_def
	shooter = new_shooter
	target = new_target
	decoy = null
	decoy_serial = 0
	guided = new_def.is_homing() and new_target != null
	exclude.clear()
	if new_shooter is CollisionObject3D:
		exclude.append((new_shooter as CollisionObject3D).get_rid())
	position = origin
	previous = origin
	velocity = start_velocity
	age = 0.0
	travelled = 0.0


## Frees the slot.
func retire() -> void:
	active = false
	def = null
	shooter = null
	target = null
	decoy = null
	guided = false
	exclude.clear()


func speed() -> float:
	return velocity.length()


## The direction it is flying, or -Z for a round at rest.
func heading() -> Vector3:
	return velocity.normalized() if velocity.length_squared() > 0.000001 else Vector3.FORWARD


## True while a homing missile is steering at `ship` itself (not at a decoy): the ship should be
## warned.
func is_tracking(ship: Node) -> bool:
	return active and guided and decoy == null and target == ship


## The head, `fraction` (0..1) of the way from last tick's position to this tick's.
func drawn_position(fraction: float) -> Vector3:
	return previous.lerp(position, fraction)
