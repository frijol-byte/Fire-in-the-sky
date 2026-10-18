class_name FlightSim
extends RefCounted
## Helpers for flight sims: spawn a ship in empty space, fly it with scripted controls and
## record what it did. Every sim in `test_flight_*.gd` goes through here so they all fly the
## same `Ship` scene the game does.

const SHIP_SCENE: PackedScene = preload("res://ships/ship.tscn")


## One recorded tick.
class Sample:
	extends RefCounted
	var tick: int = 0
	var position: Vector3 = Vector3.ZERO
	var basis: Basis = Basis.IDENTITY
	## Velocity in the ship's own axes.
	var local_velocity: Vector3 = Vector3.ZERO
	## Angular velocity in the ship's own axes.
	var local_angular: Vector3 = Vector3.ZERO


## Creates a ship of `ship_id` at the origin, facing -Z, and adds it to `parent`.
static func spawn(parent: Node, ship_id: StringName = &"kestrel") -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate() as Ship
	ship.def = Content.ship(ship_id)
	parent.add_child(ship)
	return ship


## Controls with only the given thrust and rotation set.
static func controls(
	thrust: Vector3 = Vector3.ZERO, rotate: Vector3 = Vector3.ZERO
) -> ShipControls:
	var result: ShipControls = ShipControls.new()
	result.thrust = thrust
	result.rotate = rotate
	return result


## Holds `ship.controls` at `held` for `ticks` physics ticks and returns one `Sample` per tick.
static func fly(tree: SceneTree, ship: Ship, held: ShipControls, ticks: int) -> Array[Sample]:
	ship.controls = held
	var samples: Array[Sample] = []
	for tick: int in ticks:
		await tree.physics_frame
		samples.append(snapshot(ship, samples.size() + 1))
	return samples


## Records the ship's current state.
static func snapshot(ship: Ship, tick: int) -> Sample:
	var sample: Sample = Sample.new()
	var inverse: Basis = ship.global_basis.orthonormalized().inverse()
	sample.tick = tick
	sample.position = ship.global_position
	sample.basis = ship.global_basis
	sample.local_velocity = inverse * ship.linear_velocity
	sample.local_angular = inverse * ship.angular_velocity
	return sample


## Seconds at which `values[i]` first reaches `threshold` (counting upward), or -1.0.
static func first_time_at_or_above(values: PackedFloat32Array, threshold: float) -> float:
	for index: int in values.size():
		if values[index] >= threshold:
			return (index + 1) * SimHelper.TICK
	return -1.0


## Seconds at which `values[i]` first falls to `threshold` or below, or -1.0.
static func first_time_at_or_below(values: PackedFloat32Array, threshold: float) -> float:
	for index: int in values.size():
		if values[index] <= threshold:
			return (index + 1) * SimHelper.TICK
	return -1.0


## Extracts one component of the samples' local velocity as a float array.
static func speed_along(
	samples: Array[Sample], axis: int, sign_factor: float = 1.0
) -> PackedFloat32Array:
	var result: PackedFloat32Array = []
	for sample: Sample in samples:
		result.append(sample.local_velocity[axis] * sign_factor)
	return result


## Extracts one component of the samples' local angular velocity as a float array.
static func rate_along(
	samples: Array[Sample], axis: int, sign_factor: float = 1.0
) -> PackedFloat32Array:
	var result: PackedFloat32Array = []
	for sample: Sample in samples:
		result.append(sample.local_angular[axis] * sign_factor)
	return result
