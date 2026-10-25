class_name CameraRig
extends Node3D
## The player's camera: a chase view (behind and above the ship, with spring lag, an FOV kick on
## boost and clearance from geometry) and a cockpit view (at the model's `SOCKET_cockpit_cam_0`,
## inside a canopy frame), with a short blend between them, a shake API and an optional free
## look. Attach it to a ship with `attach()`; it is a sibling of the ship, never a child, so the
## ship's physics and the camera's lag stay separate.
##
## The camera updates every rendered frame (`_process`), reading the ship's transform. All the
## numbers (offset, lag, FOV) come from the ship's `ShipDef`; only feel constants common to every
## ship live here.

## Emitted when the view changes. `view` is a `View` value. (`Events.camera_view_changed` carries
## it to systems that do not hold the rig, like the HUD.)
signal view_changed(view: int)

enum View { CHASE, COCKPIT }

## Settings key: strength of camera shake, 0 (off) to 1. Accessibility option.
const SETTING_SHAKE: String = "camera/shake"
const DEFAULT_SHAKE: float = 1.0

## Seconds a full blend between the two views takes.
const BLEND_TIME: float = 0.35
## The exterior model hides and the canopy shows once the blend passes this point.
const COCKPIT_SHOW_WEIGHT: float = 0.6

## Chase camera clearance: how far in front of a wall the camera stops, the smallest fraction of
## the way to the camera it may be pulled in to, and the time constant of the way back out.
const CLEARANCE_MARGIN: float = 0.6
const CLEARANCE_MIN_FRACTION: float = 0.12
const CLEARANCE_RECOVER_TAU: float = 0.4

## Time constants (seconds) of the FOV kick building up and fading.
const FOV_KICK_IN_TAU: float = 0.15
const FOV_KICK_OUT_TAU: float = 0.35

## Free look: the most the camera turns, and how fast it follows the stick.
const FREE_LOOK_MAX_YAW: float = deg_to_rad(150.0)
const FREE_LOOK_MAX_PITCH: float = deg_to_rad(60.0)
const FREE_LOOK_TAU: float = 0.08

## Shake at strength 1: the largest push (metres) and twist (radians), and how fast it jitters.
const SHAKE_MAX_OFFSET: float = 0.4
const SHAKE_MAX_ANGLE: float = deg_to_rad(2.0)
const SHAKE_FREQUENCY: float = 18.0
const SHAKE_SEED: int = 17

## Where the eye sits (ship axes) when a model has no cockpit socket.
const FALLBACK_EYE: Vector3 = Vector3(0.0, 1.0, -2.0)

## Physics layers the chase camera avoids. Layer 1 is where world geometry lives for now.
@export_flags_3d_physics var clearance_mask: int = PhysicsLayers.CAMERA_MASK

var ship: Ship = null
var view: View = View.CHASE

var _canopy: Node3D = null
var _socket: Marker3D = null
var _chase_offset: Vector3 = Vector3.ZERO
var _chase_rotation: Quaternion = Quaternion.IDENTITY
var _clearance: float = 1.0
## 0 is the chase view, 1 the cockpit view; moves toward the active view over `BLEND_TIME`.
var _cockpit_weight: float = 0.0
var _boost_amount: float = 0.0
## Free look as (yaw, pitch) in radians, smoothed.
var _look: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_elapsed: float = 0.0
var _noise: FastNoiseLite = FastNoiseLite.new()

## The scene's camera. Its transform is set from here, in world space.
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	# The rig places the camera itself every rendered frame, from interpolated ship transforms;
	# interpolating the camera's own transform as well would add a second, wrong smoothing.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.seed = SHAKE_SEED
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 1.0
	camera.near = 0.05
	camera.far = 20000.0


func _process(delta: float) -> void:
	update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle") and not event.is_echo():
		toggle_view()


func _exit_tree() -> void:
	_show_exterior(true)


## Follows `new_ship` from now on. Call it once the ship is in the tree; the camera snaps to the
## new ship's chase pose.
func attach(new_ship: Ship) -> void:
	_show_exterior(true)
	ship = new_ship
	_socket = null
	if ship.model != null:
		var sockets: Array[Marker3D] = ship.model.get_sockets(&"cockpit_cam")
		if not sockets.is_empty():
			_socket = sockets[0]
	_build_canopy()
	_cockpit_weight = 1.0 if view == View.COCKPIT else 0.0
	_look = Vector2.ZERO
	_boost_amount = 0.0
	_clearance = 1.0
	var target: Transform3D = _chase_target(Basis.IDENTITY)
	_chase_offset = target.origin - _ship_transform().origin
	_chase_rotation = target.basis.get_rotation_quaternion()
	update(0.0)


## Switches to the other view, blending over `BLEND_TIME`.
func toggle_view() -> void:
	set_view(View.COCKPIT if view == View.CHASE else View.CHASE)


## Switches to `new_view`, blending over `BLEND_TIME`.
func set_view(new_view: View) -> void:
	if new_view == view:
		return
	view = new_view
	view_changed.emit(view)
	Events.camera_view_changed.emit(view)


## Shakes the camera. `strength` is 0..1 (1 = `SHAKE_MAX_OFFSET` / `SHAKE_MAX_ANGLE`), and the
## shake fades out over `duration` seconds. A new shake only replaces the one running if it is
## stronger than what is left of it. The shake setting (`camera/shake`) scales it.
func shake(strength: float, duration: float) -> void:
	if duration <= 0.0 or strength <= 0.0:
		return
	if strength <= shake_amplitude(_shake_strength, _shake_elapsed, _shake_duration):
		return
	_shake_strength = minf(strength, 1.0)
	_shake_duration = duration
	_shake_elapsed = 0.0


## Current shake strength, 0 when none is running.
func shake_now() -> float:
	return shake_amplitude(_shake_strength, _shake_elapsed, _shake_duration)


## True when the camera has fully blended into the cockpit view.
func is_cockpit() -> bool:
	return _cockpit_weight >= 1.0


## Advances the camera by `delta` seconds and places it. `_process` calls this every frame;
## tests call it directly.
func update(delta: float) -> void:
	if ship == null or not is_inside_tree():
		return
	var def: ShipDef = ship.def
	_update_free_look(delta)
	_update_boost(delta, def)
	_update_shake_clock(delta)
	var target_weight: float = 1.0 if view == View.COCKPIT else 0.0
	_cockpit_weight = move_toward(_cockpit_weight, target_weight, delta / BLEND_TIME)
	var eased: float = smoothstep(0.0, 1.0, _cockpit_weight)

	var chase: Transform3D = _update_chase(delta)
	var base: Transform3D = _cockpit_base()
	var cockpit: Transform3D = base * Transform3D(free_look_basis(_look), Vector3.ZERO)
	var pose: Transform3D = chase.interpolate_with(cockpit, eased)
	pose = pose * _shake_transform()
	camera.global_transform = pose
	camera.fov = boost_fov(def.base_fov, def.boost_fov_kick, _boost_amount)

	var inside: bool = eased > COCKPIT_SHOW_WEIGHT
	_show_exterior(not inside)
	if _canopy != null:
		_canopy.visible = inside
		_canopy.global_transform = base


## Seconds-based smoothing weight: the fraction of the remaining distance to cover in `dt`
## seconds for a time constant `tau`. A `tau` of 0 or less means "no lag" (1.0).
static func smooth_weight(dt: float, tau: float) -> float:
	if tau <= 0.0:
		return 1.0
	return 1.0 - exp(-dt / tau)


## The chase camera's ideal pose for a ship at `ship_transform`, before lag and clearance.
## `look` is the free-look rotation about the ship; `speed_fraction` (0..1) pulls the camera back.
static func chase_pose_for(
	ship_transform: Transform3D, def: ShipDef, look: Basis, speed_fraction: float
) -> Transform3D:
	var pivot: Basis = ship_transform.basis.orthonormalized() * look
	var offset: Vector3 = (
		def.chase_offset + Vector3(0.0, 0.0, def.chase_speed_pullback * speed_fraction)
	)
	var position: Vector3 = ship_transform.origin + pivot * offset
	var aim: Vector3 = ship_transform.origin + pivot * Vector3(0.0, 0.0, -def.chase_look_ahead)
	return Transform3D(Basis.looking_at(aim - position, pivot.y), position)


## Field of view for a boost amount of 0..1.
static func boost_fov(base_fov: float, kick: float, amount: float) -> float:
	return base_fov + kick * clampf(amount, 0.0, 1.0)


## Shake strength left `elapsed` seconds into a shake of `strength` lasting `duration`: it fades
## quadratically to zero.
static func shake_amplitude(strength: float, elapsed: float, duration: float) -> float:
	if duration <= 0.0 or elapsed >= duration:
		return 0.0
	var remaining: float = 1.0 - elapsed / duration
	return strength * remaining * remaining


## One step of the chase camera's clearance fraction (1 = full distance). When geometry is in
## the way (`hit_fraction` below `current`) the camera is pulled in at once; when it is clear the
## fraction eases back out with time constant `recover_tau`.
static func clearance_step(
	current: float, hit_fraction: float, dt: float, recover_tau: float
) -> float:
	if hit_fraction < current:
		return hit_fraction
	return lerpf(current, hit_fraction, smooth_weight(dt, recover_tau))


## The rotation for a free-look of `look` radians (yaw, pitch; right and up positive).
static func free_look_basis(look: Vector2) -> Basis:
	return Basis.from_euler(Vector3(look.y, -look.x, 0.0))


func _chase_target(look: Basis) -> Transform3D:
	return chase_pose_for(_ship_transform(), ship.def, look, _speed_fraction())


## Where the ship is drawn this frame. With physics interpolation on, that is between the last two
## physics ticks, so the camera moves smoothly at any frame rate (the tick-stepped
## `global_transform` would make it judder above 60 Hz).
func _ship_transform() -> Transform3D:
	return ship.get_global_transform_interpolated()


func _speed_fraction() -> float:
	return clampf(ship.linear_velocity.length() / ship.def.boost_max_speed, 0.0, 1.0)


## Advances the lagged chase state and returns the chase pose, pulled in clear of geometry.
func _update_chase(delta: float) -> Transform3D:
	var def: ShipDef = ship.def
	var ship_position: Vector3 = _ship_transform().origin
	var target: Transform3D = _chase_target(free_look_basis(_look))
	_chase_offset = _chase_offset.lerp(
		target.origin - ship_position, smooth_weight(delta, def.chase_position_lag)
	)
	_chase_rotation = _chase_rotation.slerp(
		target.basis.get_rotation_quaternion(), smooth_weight(delta, def.chase_rotation_lag)
	)
	var wanted: Vector3 = ship_position + _chase_offset
	_clearance = clearance_step(
		_clearance, _clear_fraction(ship_position, wanted), delta, CLEARANCE_RECOVER_TAU
	)
	var position: Vector3 = ship_position + _chase_offset * _clearance
	return Transform3D(Basis(_chase_rotation), position)


## How far along the way from `pivot` to `wanted` the camera can go before it meets geometry.
func _clear_fraction(pivot: Vector3, wanted: Vector3) -> float:
	var length: float = pivot.distance_to(wanted)
	if length < 0.01:
		return 1.0
	var direction: Vector3 = (wanted - pivot) / length
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pivot, wanted + direction * CLEARANCE_MARGIN, clearance_mask, [ship.get_rid()]
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	var distance: float = pivot.distance_to(hit["position"] as Vector3) - CLEARANCE_MARGIN
	return clampf(distance / length, CLEARANCE_MIN_FRACTION, 1.0)


## The eye pose in the cockpit view, without free look or shake.
func _cockpit_base() -> Transform3D:
	var eye: Transform3D = _ship_transform() * Transform3D(Basis.IDENTITY, FALLBACK_EYE)
	if _socket != null:
		eye = _socket.get_global_transform_interpolated()
	eye.basis = eye.basis.orthonormalized()
	return eye


func _update_free_look(delta: float) -> void:
	var stick: Vector2 = InputRouter.free_look_vector()
	var wanted: Vector2 = Vector2(stick.x * FREE_LOOK_MAX_YAW, stick.y * FREE_LOOK_MAX_PITCH)
	_look = _look.lerp(wanted, smooth_weight(delta, FREE_LOOK_TAU))


func _update_boost(delta: float, def: ShipDef) -> void:
	# Boost held *and* powered: the kick drops when the capacitor runs dry (M1-T3).
	var wanted: float = 1.0 if ship.is_boosting() else 0.0
	var tau: float = FOV_KICK_IN_TAU if wanted > _boost_amount else FOV_KICK_OUT_TAU
	_boost_amount = lerpf(_boost_amount, wanted, smooth_weight(delta, tau))
	if def.boost_fov_kick <= 0.0:
		_boost_amount = 0.0


func _update_shake_clock(delta: float) -> void:
	_shake_elapsed += delta


func _shake_transform() -> Transform3D:
	var scale: float = clampf(float(Settings.get_value(SETTING_SHAKE, DEFAULT_SHAKE)), 0.0, 1.0)
	var amount: float = shake_now() * scale
	if amount <= 0.0:
		return Transform3D.IDENTITY
	var t: float = _shake_elapsed * SHAKE_FREQUENCY
	var push: Vector3 = Vector3(_noise.get_noise_1d(t), _noise.get_noise_1d(t + 100.0), 0.0)
	var twist: Vector3 = Vector3(
		_noise.get_noise_1d(t + 200.0),
		_noise.get_noise_1d(t + 300.0),
		_noise.get_noise_1d(t + 400.0)
	)
	var basis: Basis = Basis.from_euler(twist * SHAKE_MAX_ANGLE * amount)
	return Transform3D(basis, push * SHAKE_MAX_OFFSET * amount)


func _show_exterior(shown: bool) -> void:
	if ship != null and is_instance_valid(ship) and ship.model != null:
		ship.model.visible = shown


func _build_canopy() -> void:
	if _canopy != null:
		_canopy.queue_free()
		_canopy = null
	var path: String = ship.def.canopy_path
	if path.is_empty():
		return
	var packed: PackedScene = load(path) as PackedScene
	_canopy = packed.instantiate() as Node3D
	_canopy.top_level = true
	_canopy.visible = false
	add_child(_canopy)
