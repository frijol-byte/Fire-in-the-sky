class_name LootMath
extends RefCounted
## The pure rules of loot containers drifting in space and being pulled in by the tractor beam
## (M2-T6). `LootManager` applies them each physics tick.

## A container shrinks away during the last seconds of its life, so it does not just vanish.
const EXPIRY_FADE_SECONDS: float = 3.0


## True when a container `distance` metres from the ship is within the tractor's range.
static func in_tractor_range(distance: float, tractor: TractorDef) -> bool:
	return distance <= tractor.range_m


## True when a container `distance` metres from the ship is close enough to collect.
static func is_collected(distance: float, tractor: TractorDef) -> bool:
	return distance <= tractor.collect_radius_m


## The speed (m/s relative to the ship) of a container being pulled, after `dt` more seconds.
static func next_pull_speed(speed: float, tractor: TractorDef, dt: float) -> float:
	return minf(speed + tractor.pull_accel * dt, tractor.pull_speed)


## The velocity of a pulled container in the world: it rides along with the ship (so a boosting
## ship still catches it) and closes in on it at `pull_speed`.
static func pulled_velocity(
	ship_velocity: Vector3, container_to_ship: Vector3, pull_speed: float
) -> Vector3:
	if container_to_ship.length_squared() <= 0.0:
		return ship_velocity
	return ship_velocity + container_to_ship.normalized() * pull_speed


## The velocity of a container drifting freely after `dt` seconds: the scatter dies away.
static func drifted_velocity(velocity: Vector3, drag: float, dt: float) -> Vector3:
	return velocity * exp(-drag * dt)


## A container's scale with `left` seconds of life left: full size, shrinking in the last seconds.
static func expiry_scale(left: float) -> float:
	return clampf(left / EXPIRY_FADE_SECONDS, 0.0, 1.0)
