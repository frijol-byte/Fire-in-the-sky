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
## With FA off the sticks are plain thrust: the ship keeps its momentum, and only rotation stays
## assisted. Thrust cannot push the speed above the current cap, but speed already above it
## (from a boost) is kept. When FA comes back on, that excess blends away over
## `ShipDef.fa_excess_bleed_time`.
##
## Boost (held and powered) forces full forward throttle, multiplies forward thrust and raises
## the cap to `boost_max_speed`. It drains the `PowerSystem` and stops when the capacitor runs
## dry; it can only be started again after the button is released and `boost_min_energy` is
## available.
##
## Everything is in the ship's local axes (Godot: -Z is forward, +X right, +Y up).
## `compute` is a pure function so it is unit tested without any physics.

## Emitted on the tick boost stops because the capacitor ran dry.
signal boost_depleted

## `exp(-3)` is about 5%: the exponent that closes 95% of the excess in one bleed time.
const EXCESS_DECAY_95: float = 3.0


## The velocities after one tick, in the ship's local axes.
class Result:
	extends RefCounted
	var linear: Vector3 = Vector3.ZERO
	var angular: Vector3 = Vector3.ZERO


## The ship to fly. Set by `Ship`.
var def: ShipDef = null
## The ship's capacitor, spent by boost. Set by `Ship`.
var power: PowerSystem = null
## True while boost is actually firing this tick.
var boosting: bool = false

var _boost_locked: bool = false


## Sets the ship's velocities for this tick. Call from `RigidBody3D._integrate_forces` (the body
## must have `custom_integrator` on).
func integrate(state: PhysicsDirectBodyState3D, controls: ShipControls) -> void:
	if def == null:
		return
	boosting = _update_boost(controls.boost, state.step)
	var basis: Basis = state.transform.basis.orthonormalized()
	var local_basis: Basis = basis.inverse()
	var result: Result = compute(
		def,
		controls,
		local_basis * state.linear_velocity,
		local_basis * state.angular_velocity,
		state.step,
		boosting
	)
	state.linear_velocity = basis * result.linear
	state.angular_velocity = basis * result.angular


## Decides whether boost fires this tick and spends its energy.
func _update_boost(wanted: bool, dt: float) -> bool:
	if not wanted:
		_boost_locked = false
		return false
	if _boost_locked or power == null:
		return false
	if not boosting and power.energy < def.boost_min_energy:
		return false
	if power.request(def.boost_energy_per_second * dt):
		return true
	# Dry: stay off until the pilot lets go of the button.
	_boost_locked = true
	boost_depleted.emit()
	return false


## The single place where the flight response is calculated. `linear_velocity` and
## `angular_velocity` are the current velocities in local axes; `dt` is the tick length.
## `boosting` is whether boost is actually firing (the caller has already checked the energy).
static func compute(
	def: ShipDef,
	controls: ShipControls,
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	dt: float,
	boosting: bool = false
) -> Result:
	var result: Result = Result.new()
	var thrust: Vector3 = effective_thrust(controls, boosting)
	var forward_accel: float = (
		def.accel_forward() * (def.boost_thrust_multiplier if boosting else 1.0)
	)
	var cap: float = speed_cap(def, boosting)

	# Speed above the cap blends away under FA; with FA off it is momentum and stays.
	var velocity: Vector3 = linear_velocity
	if not controls.fa_off:
		velocity = limit_excess(velocity, cap, def.fa_excess_bleed_time, dt)

	if controls.fa_off:
		result.linear = drift_velocity(def, thrust, velocity, forward_accel, cap, dt)
	else:
		var linear_target: Vector3 = commanded_linear_velocity(def, controls, boosting)
		var linear_step: float = response_fraction(def.fa_linear_gain, dt)
		# Z is forward/back: negative z is forward (forward thrust), positive z is reverse thrust.
		var accel: Vector3 = Vector3(def.accel_lateral(), def.accel_vertical(), 0.0)
		result.linear.x = _approach(velocity.x, linear_target.x, linear_step, accel.x, accel.x, dt)
		result.linear.y = _approach(velocity.y, linear_target.y, linear_step, accel.y, accel.y, dt)
		result.linear.z = _approach(
			velocity.z, linear_target.z, linear_step, def.accel_reverse(), forward_accel, dt
		)

	var angular_target: Vector3 = commanded_angular_velocity(def, controls)
	var angular_step: float = response_fraction(def.fa_angular_gain, dt)
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


## The thrust stick after boost: boosting forces full forward throttle.
static func effective_thrust(controls: ShipControls, boosting: bool) -> Vector3:
	var thrust: Vector3 = controls.thrust.clamp(-Vector3.ONE, Vector3.ONE)
	if boosting:
		thrust.z = 1.0
	return thrust


## The speed the ship is allowed to reach by thrust alone.
static func speed_cap(def: ShipDef, boosting: bool) -> float:
	return def.boost_max_speed if boosting else def.max_speed


## Brings the length of `velocity` toward `cap` if it is longer, closing 95% of the excess in
## `bleed_time` seconds. Shorter velocities are returned unchanged.
static func limit_excess(velocity: Vector3, cap: float, bleed_time: float, dt: float) -> Vector3:
	var speed: float = velocity.length()
	if speed <= cap:
		return velocity
	var kept: float = exp(-EXCESS_DECAY_95 / maxf(bleed_time, 0.001) * dt)
	return velocity * ((cap + (speed - cap) * kept) / speed)


## FA off: the sticks are thrust, with no damping. Thrust never raises the speed above `cap`,
## but speed that is already higher is left alone.
static func drift_velocity(
	def: ShipDef, thrust: Vector3, velocity: Vector3, forward_accel: float, cap: float, dt: float
) -> Vector3:
	var z_accel: float = forward_accel if thrust.z > 0.0 else def.accel_reverse()
	var push: Vector3 = Vector3(
		thrust.x * def.accel_lateral(), thrust.y * def.accel_vertical(), -thrust.z * z_accel
	)
	var next: Vector3 = velocity + push * dt
	var limit: float = maxf(cap, velocity.length())
	return next.limit_length(limit)


## The velocity the sticks ask for, in local axes. Throttle sets the speed on each axis, then the
## whole vector is limited to the cap (`max_speed`, or `boost_max_speed` while boosting).
static func commanded_linear_velocity(
	def: ShipDef, controls: ShipControls, boosting: bool = false
) -> Vector3:
	var thrust: Vector3 = effective_thrust(controls, boosting)
	var cap: float = speed_cap(def, boosting)
	var z_speed: float = cap if thrust.z > 0.0 else def.max_reverse_speed
	var target: Vector3 = Vector3(
		thrust.x * def.max_strafe_speed, thrust.y * def.max_vertical_speed, -thrust.z * z_speed
	)
	return target.limit_length(cap)


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
