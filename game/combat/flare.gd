class_name Flare
extends RefCounted
## One decoy flare burning. `MissileManager` owns a fixed pool of these. A missile whose seeker was
## fooled steers at the flare instead of its target, until the flare burns out.

var active: bool = false
var index: int = 0
## Order of deployment (a reused slot gets a new serial).
var serial: int = 0
var def: DeviceDef = null
## The ship that threw it.
var source: Node = null
var position: Vector3 = Vector3.ZERO
var previous: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Seconds it still burns.
var left: float = 0.0


func start(
	new_def: DeviceDef, new_source: Node, origin: Vector3, start_velocity: Vector3, new_serial: int
) -> void:
	active = true
	serial = new_serial
	def = new_def
	source = new_source
	position = origin
	previous = origin
	velocity = start_velocity
	left = new_def.flare_lifetime


func retire() -> void:
	active = false
	def = null
	source = null


## Brightness 0..1: full while burning, fading away over the last second.
func brightness() -> float:
	return clampf(left, 0.0, 1.0)


func drawn_position(fraction: float) -> Vector3:
	return previous.lerp(position, fraction)
