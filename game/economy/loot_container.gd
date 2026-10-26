class_name LootContainer
extends Node3D
## One loot container floating in space: a small spinning crate with a glow, gold for credits and
## cyan for a material. It holds a `LootDrop`; `LootManager` moves it, pulls it to the player's
## ship and pays it out.

## What the container holds.
var drop: LootDrop = null
## Where it is drifting, in m/s.
var velocity: Vector3 = Vector3.ZERO
## Seconds of life left; it is gone at 0.
var left: float = 0.0
## How quickly the drift slows down (see `LootMath.drifted_velocity`).
var drag: float = 0.0
## Closing speed on the ship while being pulled (0 = not pulled yet).
var pull_speed: float = 0.0
## Tumble, in radians per second around each axis.
var spin: Vector3 = Vector3.ZERO
## Size of the crate before it shrinks at the end of its life.
var base_scale: float = 1.0


## True while the tractor beam has hold of the container.
func is_pulled() -> bool:
	return pull_speed > 0.0
