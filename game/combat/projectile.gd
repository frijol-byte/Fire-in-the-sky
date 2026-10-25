class_name Projectile
extends RefCounted
## One shot in flight. `ProjectileManager` owns a fixed pool of these and reuses them, so a shot
## is data, not a node: nothing is created or freed while the game runs.

## False while the slot is free in the pool.
var active: bool = false
## Slot in the manager's pool.
var index: int = 0
## Order of spawning; the oldest active shot is the one reused when the pool is full.
var serial: int = 0
var weapon: WeaponDef = null
## The ship that fired it (the damage `source`), or null.
var shooter: Node = null
## The shape cast ignores these bodies, so a shot does not hit its own ship.
var exclude: Array[RID] = []
var position: Vector3 = Vector3.ZERO
## Where it was one physics tick ago; the picture is drawn between the two (interpolation).
var previous: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Metres flown so far.
var travelled: float = 0.0


## Starts the shot at `origin` flying along `direction` (a unit vector) at the weapon's speed.
func launch(
	new_weapon: WeaponDef, new_shooter: Node, origin: Vector3, direction: Vector3, new_serial: int
) -> void:
	active = true
	serial = new_serial
	weapon = new_weapon
	shooter = new_shooter
	exclude.clear()
	if new_shooter is CollisionObject3D:
		exclude.append((new_shooter as CollisionObject3D).get_rid())
	position = origin
	previous = origin
	velocity = direction * new_weapon.projectile_speed
	travelled = 0.0


## Frees the slot.
func retire() -> void:
	active = false
	weapon = null
	shooter = null
	exclude.clear()


## The shot's head, `fraction` (0..1) of the way from last tick's position to this tick's.
func drawn_position(fraction: float) -> Vector3:
	return previous.lerp(position, fraction)
