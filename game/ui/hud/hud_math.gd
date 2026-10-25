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
	return marker_at(camera, origin + direction.normalized() * MARKER_DISTANCE, view_size, margin)


## Same as `marker_for` for a real point in the world (a target, a lead point) instead of a
## direction: where `world` lands on screen, pinned to the edge when off-screen or behind.
static func marker_at(
	camera: Camera3D, world: Vector3, view_size: Vector2, margin: float
) -> Marker:
	var marker: Marker = Marker.new()
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


## How many pixels a sphere of `radius` metres, `distance` metres from the camera, spans as a
## radius on a view `view_height` pixels tall with a vertical field of view of `fov_deg`.
static func projected_radius(
	radius: float, distance: float, fov_deg: float, view_height: float
) -> float:
	if distance <= 0.0:
		return view_height
	var half_height_at_distance: float = distance * tan(deg_to_rad(fov_deg) * 0.5)
	return radius / half_height_at_distance * view_height * 0.5


## "320 m", or "1.2 km" from a kilometre up.
static func distance_text(meters: float) -> String:
	if meters >= 1000.0:
		return TranslationServer.translate("HUD_DISTANCE_KM") % (meters / 1000.0)
	return TranslationServer.translate("HUD_DISTANCE_M") % meters


## `strings.csv` key of a stance's name.
static func stance_key(stance: Targeting.Stance) -> StringName:
	match stance:
		Targeting.Stance.NEUTRAL:
			return &"HUD_STANCE_NEUTRAL"
		Targeting.Stance.FRIENDLY:
			return &"HUD_STANCE_FRIENDLY"
	return &"HUD_STANCE_HOSTILE"


## `strings.csv` key of why a lock is missing (`Targeting.Lock`), or `&""` while locked.
static func lock_key(lock: Targeting.Lock) -> StringName:
	match lock:
		Targeting.Lock.OUT_OF_RANGE:
			return &"HUD_LOCK_OUT_OF_RANGE"
		Targeting.Lock.OCCLUDED:
			return &"HUD_LOCK_OCCLUDED"
	return &""


## The strokes of a target bracket of half-size `half` pixels around the origin, one polyline
## each. The shape says whose side the target is on: square corners for hostile, round arcs for
## neutral, diamond corners for friendly, so it reads without relying on colour.
static func bracket_strokes(stance: Targeting.Stance, half: float) -> Array[PackedVector2Array]:
	var strokes: Array[PackedVector2Array] = []
	var leg: float = half * 0.45
	match stance:
		Targeting.Stance.NEUTRAL:
			# Four arcs of 50 degrees, centred on the diagonals.
			for corner: int in 4:
				var centre: float = PI * 0.25 + PI * 0.5 * corner
				var arc: PackedVector2Array = []
				for step: int in 6:
					var angle: float = centre - deg_to_rad(25.0) + deg_to_rad(10.0) * step
					arc.append(Vector2(cos(angle), sin(angle)) * half)
				strokes.append(arc)
		Targeting.Stance.FRIENDLY:
			# The four corners of a diamond, a short leg each way.
			for corner: int in 4:
				var vertex: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * corner) * half * 1.15
				var previous: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * (corner - 1)) * half * 1.15
				var following: Vector2 = (
					Vector2.RIGHT.rotated(PI * 0.5 * (corner + 1)) * half * 1.15
				)
				var toward_previous: Vector2 = vertex + (previous - vertex).normalized() * leg
				var toward_following: Vector2 = vertex + (following - vertex).normalized() * leg
				strokes.append(PackedVector2Array([toward_previous, vertex, toward_following]))
		_:
			# Hostile: the four corners of a square.
			for sign_x: float in [-1.0, 1.0]:
				for sign_y: float in [-1.0, 1.0]:
					var corner_point: Vector2 = Vector2(sign_x, sign_y) * half
					strokes.append(
						PackedVector2Array(
							[
								corner_point + Vector2(-sign_x * leg, 0.0),
								corner_point,
								corner_point + Vector2(0.0, -sign_y * leg)
							]
						)
					)
	return strokes


## The three corners of an edge arrow of `size` pixels at `position`, pointing along `direction`
## (away from the screen centre, towards the target).
static func arrow_points(position: Vector2, direction: Vector2, size: float) -> PackedVector2Array:
	var forward: Vector2 = (
		direction.normalized() if direction.length_squared() > 0.0 else Vector2.UP
	)
	var side: Vector2 = forward.orthogonal()
	return PackedVector2Array(
		[
			position + forward * size,
			position - forward * size * 0.6 + side * size * 0.8,
			position - forward * size * 0.6 - side * size * 0.8
		]
	)


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
