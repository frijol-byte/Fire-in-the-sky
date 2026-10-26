class_name DestructionMath
extends RefCounted
## The pure rules of an explosion (M2-T6): how big the fireball is, how a wreck, debris chunk and
## light fade, and which way and how fast things fly off. Every number comes from a
## `DestructionDef` or a `LootTableDef`; `DestructionManager` and `LootManager` only apply them.

## A wreck keeps its size for this fraction of its fade, then shrinks away.
const WRECK_HOLD_FRACTION: float = 0.35
## Debris keeps its size for this fraction of its life, then shrinks away.
const DEBRIS_HOLD_FRACTION: float = 0.55


## The fireball's radius for a destroyed thing of `target_radius` metres.
static func fireball_radius(def: DestructionDef, target_radius: float) -> float:
	return maxf(def.fireball_min_radius, target_radius * def.fireball_radius_factor)


## How far through a timed effect (0 = start, 1 = over) `age` seconds is.
static func progress(age: float, seconds: float) -> float:
	if seconds <= 0.0:
		return 1.0
	return clampf(age / seconds, 0.0, 1.0)


## The wreck's model scale `age` seconds into its fade: full size at first, then shrinking to 0.
static func wreck_scale(age: float, fade_seconds: float) -> float:
	return 1.0 - smoothstep(WRECK_HOLD_FRACTION, 1.0, progress(age, fade_seconds))


## A debris chunk's scale `age` seconds into its life.
static func debris_scale(age: float, lifetime: float) -> float:
	return 1.0 - smoothstep(DEBRIS_HOLD_FRACTION, 1.0, progress(age, lifetime))


## How hot a debris chunk glows, 1 at the blast to 0 when it has cooled.
static func debris_heat(age: float, cool_seconds: float) -> float:
	return 1.0 - progress(age, cool_seconds)


## The blast light's energy `age` seconds in: the peak, dying away quickly.
static func light_energy(age: float, seconds: float, peak: float) -> float:
	var left: float = 1.0 - progress(age, seconds)
	return peak * left * left


## The shockwave ring's radius at `age` seconds: it races out and slows down.
static func shockwave_radius(
	age: float, seconds: float, fireball_size: float, factor: float
) -> float:
	var t: float = progress(age, seconds)
	return fireball_size * factor * (1.0 - (1.0 - t) * (1.0 - t))


## A random direction, uniform on the sphere.
static func random_direction(rng: RandomNumberGenerator) -> Vector3:
	var z: float = rng.randf_range(-1.0, 1.0)
	var angle: float = rng.randf_range(0.0, TAU)
	var ring: float = sqrt(1.0 - z * z)
	return Vector3(ring * cos(angle), ring * sin(angle), z)


## The velocity of one debris chunk: the wreck's own velocity plus a push away in a random
## direction at a speed within the def's range.
static func debris_velocity(
	rng: RandomNumberGenerator, def: DestructionDef, inherited: Vector3
) -> Vector3:
	var speed: float = rng.randf_range(def.debris_speed_min, def.debris_speed_max)
	return inherited + random_direction(rng) * speed


## The velocity of a loot container leaving a wreck: half the wreck's velocity (it settles into
## the same drift) plus a push of up to `scatter_speed`.
static func scatter_velocity(
	rng: RandomNumberGenerator, scatter_speed: float, inherited: Vector3
) -> Vector3:
	return inherited * 0.5 + random_direction(rng) * rng.randf_range(0.3, 1.0) * scatter_speed


## The wreck's tumble: an angular velocity (radians per second) of up to `max_deg` on each axis.
static func tumble(rng: RandomNumberGenerator, max_deg: float) -> Vector3:
	var limit: float = deg_to_rad(max_deg)
	return Vector3(
		rng.randf_range(-limit, limit),
		rng.randf_range(-limit, limit),
		rng.randf_range(-limit, limit)
	)
