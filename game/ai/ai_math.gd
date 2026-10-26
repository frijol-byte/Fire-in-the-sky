class_name AIMath
extends RefCounted
## The AI pilot's pure rules: turning a direction into stick commands, when to fire, how long a
## threat takes to be noticed, the turning circle and how to steer around a rock. No nodes and no
## physics, so each is unit tested; `AIPilot` feeds them with what it sees.
##
## Angles are radians unless a name says `_deg`. Directions in the ship's own axes use Godot's
## convention (-Z forward, +X right, +Y up), the same as `ShipControls`.

## A heading that moves more than this between two ticks is a new heading, not a tracked target.
const MAX_SWING_PER_TICK: float = deg_to_rad(3.0)
## A swerve round a rock turns the nose at least this much.
const MIN_AVOID_ANGLE: float = deg_to_rad(25.0)
## The least forward throttle a pilot holds while matching speed (it never stops dead).
const MIN_THROTTLE: float = 0.1

## A target more than this far off the nose counts as behind the ship.
const BEHIND_ANGLE: float = deg_to_rad(100.0)


## The pitch (x) and yaw (y) stick commands, -1..1, that turn the nose towards `local_dir` (a
## direction in the ship's own axes). `rates` is the ship's top (pitch, yaw) turn rate in rad/s and
## `gain` how many times per second the remaining angle is closed: the rate asked for is the angle
## error times the gain, so the nose eases onto the target instead of overshooting it. `feed_forward`
## (pitch, yaw rad/s) is how fast the direction itself is swinging, added so a crossing target is
## tracked without the lag of a pure proportional chase.
static func turn_command(
	local_dir: Vector3, rates: Vector2, gain: float, feed_forward: Vector2 = Vector2.ZERO
) -> Vector2:
	if local_dir.length_squared() < 0.000001:
		return Vector2.ZERO
	var yaw_error: float = atan2(local_dir.x, -local_dir.z)
	var pitch_error: float = atan2(local_dir.y, Vector2(local_dir.x, local_dir.z).length())
	# Dead behind: either way round is as short, so pick right rather than dither.
	if local_dir.z > 0.0 and absf(local_dir.x) < 0.0001:
		yaw_error = PI
	return Vector2(
		clampf((pitch_error * gain + feed_forward.x) / maxf(rates.x, 0.001), -1.0, 1.0),
		clampf((yaw_error * gain + feed_forward.y) / maxf(rates.y, 0.001), -1.0, 1.0)
	)


## How fast the direction `previous` swung to `current` (world unit vectors, `delta` seconds apart),
## as (pitch, yaw) rad/s in the axes of `basis`, in the sign convention of `turn_command`. Zero when
## the swing is too big to be smooth tracking (a new heading, not a moving target).
static func swing_rate(previous: Vector3, current: Vector3, basis: Basis, delta: float) -> Vector2:
	if delta <= 0.0 or previous.length_squared() < 0.5 or current.length_squared() < 0.5:
		return Vector2.ZERO
	if previous.angle_to(current) > MAX_SWING_PER_TICK:
		return Vector2.ZERO
	var omega: Vector3 = to_local(basis, previous.cross(current) / delta)
	return Vector2(omega.x, -omega.y)


## `direction` (a world direction) in the axes of `basis`.
static func to_local(basis: Basis, direction: Vector3) -> Vector3:
	return basis.orthonormalized().inverse() * direction


## The angle in radians between the nose and a world `direction`.
static func angle_off_nose(basis: Basis, direction: Vector3) -> float:
	return (-basis.orthonormalized().z).angle_to(direction)


## The radius of the tightest turn the ship makes at top speed, in metres. A pilot that breaks off
## closer than this cannot get its nose round before it arrives.
static func turn_radius(def: ShipDef) -> float:
	var slowest: float = minf(def.max_angular_rate_rad().x, def.max_angular_rate_rad().y)
	return def.max_speed / maxf(slowest, 0.001)


## The distance below which the pilot breaks off: the profile's, or the ship's turning circle if
## that is larger.
static func break_off_range(profile: AIProfileDef, def: ShipDef) -> float:
	return maxf(profile.break_off_range_m, turn_radius(def))


## Half-angle of the cone the aim has to be inside before the guns fire at a target `distance`
## metres away and `radius` metres big: the profile's cone, widened to cover the target's size.
static func fire_cone(cone_deg: float, radius: float, distance: float) -> float:
	var size: float = atan2(radius * 0.8, maxf(distance, 1.0))
	return maxf(deg_to_rad(cone_deg), size)


## True when the guns should fire: the aim is within the cone and the target is inside `max_range`.
static func should_fire(angle: float, distance: float, cone: float, max_range: float) -> bool:
	return distance <= max_range and angle <= cone


## How long a threat has been seen, in seconds, after one more tick: counts up while `present` and
## resets when it goes away.
static func seen_time(seen: float, present: bool, delta: float) -> float:
	return seen + delta if present else 0.0


## True once a threat has been seen for the reaction time: the pilot only reacts then.
static func has_reacted(seen: float, reaction_time: float) -> bool:
	return seen > 0.0 and seen >= reaction_time


## The aim point: the lead point moved sideways by `error` (a vector in the plane across the line of
## sight, unit length at most, from the pilot's random roll) times the aim error at that distance.
static func aim_point(
	shooter_pos: Vector3, lead_point: Vector3, error: Vector3, error_deg: float
) -> Vector3:
	var to_lead: Vector3 = lead_point - shooter_pos
	var distance: float = to_lead.length()
	if distance < 0.001:
		return lead_point
	var line: Vector3 = to_lead / distance
	var across: Vector3 = error - line * error.dot(line)
	return lead_point + across * tan(deg_to_rad(error_deg)) * distance


## A random vector in the unit ball, from three rolls in 0..1 (so a test can feed fixed numbers).
static func random_in_ball(u: float, v: float, w: float) -> Vector3:
	var direction: Vector3 = Vector3(u * 2.0 - 1.0, v * 2.0 - 1.0, w * 2.0 - 1.0)
	return direction.limit_length(1.0)


## The direction to fly to pass a rock without hitting it. The ship is at `origin` flying along
## `travel`; the rock is a sphere of `rock_radius` around `rock_centre`, and the ship wants
## `clearance` metres of daylight past it. The result is `travel` turned away from the rock far
## enough to clear it by then, and never by less than `MIN_AVOID_ANGLE`. `up` is any vector not along
## `travel`; it picks the side when the rock is dead ahead.
static func avoid_heading(
	origin: Vector3,
	travel: Vector3,
	rock_centre: Vector3,
	rock_radius: float,
	clearance: float,
	up: Vector3
) -> Vector3:
	var line: Vector3 = travel.normalized()
	var to_rock: Vector3 = rock_centre - origin
	var along: float = maxf(to_rock.dot(line), 1.0)
	var lateral: Vector3 = to_rock - line * to_rock.dot(line)
	var away: Vector3 = -lateral.normalized() if lateral.length() > 0.5 else Vector3.ZERO
	if away == Vector3.ZERO:
		away = up - line * up.dot(line)
		if away.length_squared() < 0.0001:
			away = line.cross(Vector3.RIGHT)
		away = away.normalized()
	var needed: float = maxf(rock_radius + clearance - lateral.length(), 0.0)
	var sideways: float = maxf(needed * 1.3, along * tan(MIN_AVOID_ANGLE))
	return (line * along + away * sideways).normalized()


## A unit vector across `line_of_sight` (a direction): the jink direction for a roll `angle` about
## the line. `reference` is any vector not along the line.
static func jink_direction(line_of_sight: Vector3, reference: Vector3, angle: float) -> Vector3:
	var line: Vector3 = line_of_sight.normalized()
	var side: Vector3 = reference - line * reference.dot(line)
	if side.length_squared() < 0.0001:
		side = line.cross(Vector3.RIGHT)
	return side.normalized().rotated(line, angle)


## The throttle (0..1) that closes on a target `distance` metres ahead without ramming it. Far out
## it is full; inside three times `hold_distance` the pilot matches the target's speed along the
## line of sight (`target_along`, positive when it flies away) and eases the gap towards
## `hold_distance`, so a tail chase stays in the guns instead of overshooting.
static func matched_throttle(
	distance: float, hold_distance: float, target_along: float, max_speed: float
) -> float:
	var far: float = hold_distance * 3.0
	if distance >= far:
		return 1.0
	var closing: float = clampf((distance - hold_distance) * 0.8, -max_speed * 0.5, max_speed)
	return clampf((target_along + closing) / maxf(max_speed, 0.001), MIN_THROTTLE, 1.0)


## When two ships on straight courses are closest, and how close: (seconds from now, metres).
## `relative_pos` and `relative_vel` are the other ship's position and velocity minus ours. Ships
## that are moving apart are closest now.
static func closest_approach(relative_pos: Vector3, relative_vel: Vector3) -> Vector2:
	var speed_squared: float = relative_vel.length_squared()
	if speed_squared < 0.0001:
		return Vector2(0.0, relative_pos.length())
	var time: float = maxf(-relative_pos.dot(relative_vel) / speed_squared, 0.0)
	return Vector2(time, (relative_pos + relative_vel * time).length())


## True when the ships will pass closer than `contact_distance` within `horizon` seconds.
static func is_collision_course(
	relative_pos: Vector3, relative_vel: Vector3, contact_distance: float, horizon: float
) -> bool:
	var approach: Vector2 = closest_approach(relative_pos, relative_vel)
	return approach.x <= horizon and approach.y <= contact_distance and approach.x > 0.0


## Fire discipline for an energy weapon: stops firing when the capacitor falls below `low`
## (fraction of its capacity) and starts again only once it is back above `high`. A held trigger on
## an empty capacitor spends nothing, so the capacitor never gets its regeneration; resting it
## gives the next burst. `holding` is whether the pilot was already holding fire back.
static func hold_fire(energy_fraction: float, holding: bool, low: float, high: float) -> bool:
	if holding:
		return energy_fraction < high
	return energy_fraction < low
