class_name Lead
extends RefCounted
## The lead calculation: where to aim so a shot of a given speed meets a moving target. Pure maths,
## no nodes, so it is unit tested with moving targets and used by both the HUD's lead indicator and
## the aim assist (`Targeting`).
##
## A shot flies in a straight line at `projectile_speed` from the shooter's position. In this game
## a shot does not inherit the shooter's velocity (`WeaponDef.projectile_speed`), so by default only
## the target's velocity matters; pass `inherit_velocity` for a weapon that does inherit it.


## Seconds until a shot fired now from `shooter_pos` can meet a target now at `target_pos` moving
## at `target_vel` (both constant), or -1.0 when it never can (the target runs away faster than the
## shot, or the shot has no speed). With `inherit_velocity` the shot also carries `shooter_vel`.
static func time_to_hit(
	shooter_pos: Vector3,
	shooter_vel: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	projectile_speed: float,
	inherit_velocity: bool = false
) -> float:
	if projectile_speed <= 0.0:
		return -1.0
	var offset: Vector3 = target_pos - shooter_pos
	var relative_vel: Vector3 = _relative_velocity(shooter_vel, target_vel, inherit_velocity)
	# |offset + relative_vel * t| = projectile_speed * t, as a quadratic in t.
	var a: float = relative_vel.length_squared() - projectile_speed * projectile_speed
	var b: float = 2.0 * offset.dot(relative_vel)
	var c: float = offset.length_squared()
	if c <= 0.0:
		return 0.0
	if absf(a) < 0.000001:
		# Target speed equals shot speed: the equation is linear.
		return -c / b if b < 0.0 else -1.0
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root: float = sqrt(discriminant)
	var first: float = (-b - root) / (2.0 * a)
	var second: float = (-b + root) / (2.0 * a)
	var low: float = minf(first, second)
	var high: float = maxf(first, second)
	if low > 0.0:
		return low
	return high if high > 0.0 else -1.0


## The point to aim at (world space). Falls back to `target_pos` itself when no shot can reach
## the target (see `time_to_hit`), so the aim never jumps somewhere meaningless. For a weapon whose
## shots do not inherit the shooter's velocity this is exactly where the target will be when the
## shot arrives.
static func solve(
	shooter_pos: Vector3,
	shooter_vel: Vector3,
	target_pos: Vector3,
	target_vel: Vector3,
	projectile_speed: float,
	inherit_velocity: bool = false
) -> Vector3:
	var time: float = time_to_hit(
		shooter_pos, shooter_vel, target_pos, target_vel, projectile_speed, inherit_velocity
	)
	if time < 0.0:
		return target_pos
	return target_pos + _relative_velocity(shooter_vel, target_vel, inherit_velocity) * time


## How fast the target moves as the shot sees it: the shot carries the shooter's velocity only for a
## weapon that inherits it.
static func _relative_velocity(
	shooter_vel: Vector3, target_vel: Vector3, inherit_velocity: bool
) -> Vector3:
	return target_vel - (shooter_vel if inherit_velocity else Vector3.ZERO)
