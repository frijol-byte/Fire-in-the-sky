class_name MissileGuidance
extends RefCounted
## The maths of a missile, apart from any node so it can be unit tested: proportional navigation
## (how it steers), the closest approach of its path to a point (the proximity fuse), and how much
## a blast hurts at a distance. `MissileManager` calls these every physics tick.
##
## Proportional navigation: the missile turns at a rate proportional to how fast the line of sight
## to its target is swinging. A target on a collision course does not swing the line of sight, so the
## missile just keeps flying; a target that changes course makes the line of sight swing and the
## missile turns to match. A missile can only turn so fast, which is what lets a pilot who changes
## course late enough, hard enough, make it miss.


## `heading` (a unit vector) turned towards the target by proportional navigation, for one tick of
## `dt` seconds. `missile_vel` and `target_vel` give the line-of-sight rate. The turn is `nav_gain`
## times that rate, but never more than `max_turn_rate` radians per second.
static func steer(
	heading: Vector3,
	missile_pos: Vector3,
	missile_vel: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	nav_gain: float,
	max_turn_rate: float,
	dt: float
) -> Vector3:
	var offset: Vector3 = target_pos - missile_pos
	var distance_squared: float = offset.length_squared()
	if distance_squared < 0.0001:
		return heading
	# Angular velocity of the line of sight, as a vector (its axis is the plane's normal).
	var los_rate: Vector3 = offset.cross(target_vel - missile_vel) / distance_squared
	var turn: Vector3 = los_rate * nav_gain
	var rate: float = turn.length()
	if rate < 0.000001:
		return heading
	var angle: float = minf(rate, max_turn_rate) * dt
	return heading.rotated(turn / rate, angle).normalized()


## True when a target `to_target` away (a vector from the missile) is inside the seeker's view:
## within `cone` radians of `heading` (a unit vector). Something on top of the missile is always seen.
static func in_seeker_view(heading: Vector3, to_target: Vector3, cone: float) -> bool:
	return to_target.length_squared() < 0.0001 or heading.angle_to(to_target) <= cone


## Speed after one tick of `dt` seconds of acceleration, up to `max_speed`. A round that starts
## faster than `max_speed` (launched from a boosting ship) slows down to it at the same rate.
static func next_speed(speed: float, acceleration: float, max_speed: float, dt: float) -> float:
	if speed < max_speed:
		return minf(speed + acceleration * dt, max_speed)
	return maxf(speed - acceleration * dt, max_speed)


## Where, as a fraction (0..1) of this tick's motion, the round passes closest to a target.
## `round_pos` moves by `round_motion` over the tick while the target at `target_pos` moves by
## `target_motion`; the closest approach is worked out in the target's own frame, so a fast target
## cannot slip past between two ticks.
static func closest_fraction(
	round_pos: Vector3, round_motion: Vector3, target_pos: Vector3, target_motion: Vector3
) -> float:
	var relative_motion: Vector3 = round_motion - target_motion
	var length_squared: float = relative_motion.length_squared()
	if length_squared < 0.000001:
		return 0.0
	var start: Vector3 = round_pos - target_pos
	return clampf(-start.dot(relative_motion) / length_squared, 0.0, 1.0)


## How far apart the round and its target are at `fraction` of this tick's motion.
static func separation_at(
	round_pos: Vector3,
	round_motion: Vector3,
	target_pos: Vector3,
	target_motion: Vector3,
	fraction: float
) -> float:
	return (
		((round_pos + round_motion * fraction) - (target_pos + target_motion * fraction)).length()
	)


## Damage a blast of full strength `damage` does to something `distance` metres from it (measured
## to the surface of the thing hit): full at the centre, `edge_fraction` of it at `radius`, linear
## in between, nothing beyond.
static func splash_amount(
	damage: float, radius: float, edge_fraction: float, distance: float
) -> float:
	if radius <= 0.0 or distance > radius:
		return 0.0
	return damage * lerpf(1.0, edge_fraction, clampf(distance / radius, 0.0, 1.0))
