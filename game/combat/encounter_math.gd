class_name EncounterMath
extends RefCounted
## The rules of the wave encounter: where each pirate of a wave appears and which wave follows
## which. Pure and unit tested; `EncounterDirector` does the spawning.

## Pirates after the first alternate a little above and below the player's nose, so a wave does
## not arrive in a flat line.
const PITCH_STEP_DEG: float = 7.0


## Where pirate `index` of `count` appears: `distance` metres from `origin` (the player's
## transform), spread evenly over `spread_deg` degrees of yaw about the nose, turned to face the
## player. One pirate comes straight ahead.
static func spawn_transform(
	origin: Transform3D, index: int, count: int, distance: float, spread_deg: float
) -> Transform3D:
	var basis: Basis = origin.basis.orthonormalized()
	var yaw: float = 0.0
	if count > 1:
		yaw = deg_to_rad(spread_deg) * (float(index) / float(count - 1) - 0.5)
	var pitch: float = 0.0
	if index > 0:
		pitch = deg_to_rad(PITCH_STEP_DEG) * (1.0 if index % 2 == 1 else -1.0)
	var direction: Vector3 = -basis.z
	direction = direction.rotated(basis.y, -yaw).rotated(basis.x, pitch)
	var position: Vector3 = origin.origin + direction.normalized() * distance
	var facing: Vector3 = origin.origin - position
	var up: Vector3 = basis.y
	if absf(facing.normalized().dot(up)) > 0.99:
		up = basis.x
	return Transform3D(Basis.looking_at(facing, up), position)


## The wave after `index` out of `count`: the next one, wrapping to the first when `loop`, else
## -1 once the last is done.
static func next_wave(index: int, count: int, loop: bool) -> int:
	if index + 1 < count:
		return index + 1
	return 0 if loop and count > 0 else -1
