class_name PhysicsLayers
extends RefCounted
## The one place that names the 3D physics layers. Layer numbers are bits in the project's layer
## masks: layer 1 is bit 1, layer 2 is bit 2, layer 3 is bit 4.
##
## - WORLD: rocks, gates and station geometry. The chase camera's clearance ray only sees this.
## - SHIPS: every ship, player and AI alike.
## - TARGETS: target dummies and other things that can be shot but are not ships.
##
## A body sits on its own layer and masks the layers it must collide with. Projectiles shape-cast
## against `PROJECTILE_MASK`.

const WORLD: int = 1
const SHIPS: int = 2
const TARGETS: int = 4

## What a ship's body collides with.
const SHIP_MASK: int = WORLD | SHIPS | TARGETS
## What the chase camera's clearance ray hits: the world only, so a ship behind you cannot yank it in.
const CAMERA_MASK: int = WORLD
## What a projectile's shape cast hits.
const PROJECTILE_MASK: int = WORLD | SHIPS | TARGETS
