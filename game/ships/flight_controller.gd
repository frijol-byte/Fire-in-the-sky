class_name FlightController
extends Node
## Turns a `ShipControls` and a `ShipDef` into the ship's next velocities. Player and AI ships
## run exactly this code.
##
## With flight assist (FA) on, the sticks command a *velocity* (throttle x top speed on each
## local axis) and a *turn rate*. Each tick the controller closes a fraction of the error
## (`1 - exp(-gain * dt)`, a first-order response: the derivative term of a position PD
## controller) and clamps the change to what the ship's thrust and torque limits allow
## per axis. The step can never overshoot, so there is no oscillation, and the clamp is
## what makes heavy ships feel heavy.
##
## Everything is in the ship's local axes (Godot: -Z is forward, +X right, +Y up).
## `compute` is a pure function so it is unit tested without any physics.


## The velocities after one tick, in the ship's local axes.
class Result:
	extends RefCounted
	var linear: Vector3 = Vector3.ZERO
	var angular: Vector3 = Vector3.ZERO


## The ship to fly. Set by `Ship`.
var def: ShipDef = null


## Sets the ship's velocities for this tick. Call from `RigidBody3D._integrate_forces` (the body
## must have `custom_integrator` on).
func integrate(state: PhysicsDirectBodyState3D, controls: ShipControls) -> void:
	if def == null:
		return
	var basis: Basis = state.transform.basis.orthonormalized()
	var local_basis: Basis = basis.inverse()
	var result: Result = compute(
		def,
		controls,
		local_basis * state.linear_velocity,
		local_basis * state.angular_velocity,
		state.step
	)
	state.linear_velocity = basis * result.linear
	state.angular_velocity = basis * result.angular


## The single place where the flight-assist response is calculated. `linear_velocity` and
## `angular_velocity` are the current velocities in local axes; `dt` is the tick length.
static func compute(
	def: ShipDef,
	controls: ShipControls,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	dt: float
) -> Result:
	var result: Result = Result.new()
	var linear_target: Vector3 = commanded_linear_velocity(def, controls)
	var angular_target: Vector3 = commanded_angular_velocity(def, controls)
	var linear_step: float = response_fraction(def.fa_linear_gain, dt)
	var angular_step: float = response_fraction(def.fa_angular_gain, dt)

	# Z is forward/back: negative z is forward (forward thrust), positive z is reverse thrust.
	var accel: Vector3 = Vector3(def.accel_lateral(), def.accel_vertical(), 0.0)
	result.linear.x = _approach(
		linear_velocity.x, linear_target.x, linear_step, accel.x, accel.x, dt
	)
	result.linear.y = _approach(
		linear_velocity.y, linear_target.y, linear_step, accel.y, accel.y, dt
	)
	result.linear.z = _approach(
		linear_velocity.z,
		linear_target.z,
		linear_step,
		def.accel_reverse(),
		def.accel_forward(),
		dt
	)

	var torque: Vector3 = def.angular_accel_rad()
	for axis: int in 3:
		result.angular[axis] = _approach(
			angular_velocity[axis],
			angular_target[axis],
			angular_step,
			torque[axis],
			torque[axis],
			dt
		)
	return result


## The velocity the sticks ask for, in local axes. Throttle sets the speed on each axis, then the
## whole vector is limited to `max_speed` (the FA speed limiter).
static func commanded_linear_velocity(def: ShipDef, controls: ShipControls) -> Vector3:
	var thrust: Vector3 = controls.thrust.clamp(-Vector3.ONE, Vector3.ONE)
	var z_speed: float = def.max_speed if thrust.z > 0.0 else def.max_reverse_speed
	var target: Vector3 = Vector3(
		thrust.x * def.max_strafe_speed, thrust.y * def.max_vertical_speed, -thrust.z * z_speed
	)
	return target.limit_length(def.max_speed)


## The turn rate the sticks ask for, in local axes (rad/s). Sign conventions follow
## `ShipControls`: pitch +1 is nose up (+X rotation), yaw +1 is nose right and roll +1 is right
## wing down (both negative rotations about their axes).
static func commanded_angular_velocity(def: ShipDef, controls: ShipControls) -> Vector3:
	var rotate: Vector3 = controls.rotate.clamp(-Vector3.ONE, Vector3.ONE)
	var rates: Vector3 = def.max_angular_rate_rad()
	return Vector3(rotate.x * rates.x, -rotate.y * rates.y, -rotate.z * rates.z)


## The fraction of the velocity error closed in one tick at `gain` (1/s).
static func response_fraction(gain: float, dt: float) -> float:
	return 1.0 - exp(-gain * dt)


## Moves `current` toward `target` by `fraction` of the error, changing it by at most
## `accel_up * dt` upward or `accel_down * dt` downward.
static func _approach(
	current: float, target: float, fraction: float, accel_up: float, accel_down: float, dt: float
) -> float:
	var change: float = (target - current) * fraction
	var limit: float = (accel_up if change > 0.0 else accel_down) * dt
	return current + clampf(change, -limit, limit)
