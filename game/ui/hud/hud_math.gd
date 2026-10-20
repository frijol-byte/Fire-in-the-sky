class_name HudMath
extends RefCounted
## The flight HUD's pure rules: where a world direction lands on screen, how a marker that is
## off-screen or behind the camera is pinned to the screen edge, and which boost state to show.
## `FlightHud` draws; this decides. Unit tested.

## What the boost line of the HUD says.
enum BoostState { READY, ACTIVE, CHARGING, EMPTY }

## A direction is projected as a point this far (metres) from the ship, which is far enough
## to read as "that way" at any camera offset.
const MARKER_DISTANCE: float = 2000.0
## Below this speed (m/s) the velocity marker is hidden: the direction of motion is noise.
const MIN_MARKER_SPEED: float = 1.5


## Screen position of the point `direction` * `MARKER_DISTANCE` metres from `origin`, pinned to
## the screen (inset by `margin` px) when it is outside it or behind the camera. `on_screen`
## in the result says whether the marker was inside without pinning.
static func marker_for(
	camera: Camera3D, origin: Vector3, direction: Vector3, view_size: Vector2, margin: float
) -> Marker:
	var marker: Marker = Marker.new()
	var world: Vector3 = origin + direction.normalized() * MARKER_DISTANCE
	var point: Vector2 = camera.unproject_position(world)
	var behind: bool = camera.is_position_behind(world)
	if behind:
		# Projection mirrors a point behind the camera; flipping it through the center points the
		# marker the way the player has to turn.
		var center: Vector2 = view_size * 0.5
		point = center - (point - center)
	var inset: Rect2 = Rect2(Vector2(margin, margin), view_size - Vector2(margin, margin) * 2.0)
	marker.on_screen = not behind and inset.has_point(point)
	marker.position = point if marker.on_screen else clamp_to_edge(point, view_size, margin)
	marker.behind = behind
	return marker


## Pins `point` to the border of the screen rectangle inset by `margin`, along the line from the
## screen center to `point`. A point inside is returned unchanged.
static func clamp_to_edge(point: Vector2, view_size: Vector2, margin: float) -> Vector2:
	var center: Vector2 = view_size * 0.5
	var half: Vector2 = center - Vector2(margin, margin)
	var offset: Vector2 = point - center
	if absf(offset.x) <= half.x and absf(offset.y) <= half.y:
		return point
	var scale: float = minf(
		half.x / absf(offset.x) if offset.x != 0.0 else INF,
		half.y / absf(offset.y) if offset.y != 0.0 else INF
	)
	return center + offset * scale


## The boost line: ACTIVE while firing, EMPTY right after the capacitor ran dry (`depleted_flash`),
## CHARGING while there is not enough energy to start a boost, otherwise READY.
static func boost_state(
	boosting: bool, depleted_flash: bool, energy: float, min_energy: float
) -> BoostState:
	if boosting:
		return BoostState.ACTIVE
	if depleted_flash:
		return BoostState.EMPTY
	if energy < min_energy:
		return BoostState.CHARGING
	return BoostState.READY


## `strings.csv` key of a boost state's text.
static func boost_key(state: BoostState) -> StringName:
	match state:
		BoostState.ACTIVE:
			return &"HUD_BOOST_ACTIVE"
		BoostState.CHARGING:
			return &"HUD_BOOST_CHARGING"
		BoostState.EMPTY:
			return &"HUD_BOOST_EMPTY"
	return &"HUD_BOOST_READY"


## `strings.csv` key of the flight assist text.
static func assist_key(fa_off: bool) -> StringName:
	return &"HUD_FA_OFF" if fa_off else &"HUD_FA_ON"


## Where a HUD marker landed.
class Marker:
	extends RefCounted
	var position: Vector2 = Vector2.ZERO
	## True when the marker is at its true place inside the screen (not pinned to the edge).
	var on_screen: bool = false
	## True when the direction is behind the camera.
	var behind: bool = false
