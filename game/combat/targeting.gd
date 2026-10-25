class_name Targeting
extends Node
## A ship's target selection and lock (GDD 7.3). It reads the pilot's `controls.target_cmd` (the
## player's tap and double-tap on "target nearest", or whatever an AI writes), keeps one selected
## target, and each physics tick decides whether the ship still has a lock on it: a target out of
## range or hidden behind a rock loses the lock, and is dropped after `lock_loss_seconds`.
##
## For the player's ship (`is_player`, set by `PlayerPilot`) it also drives the gamepad aim assist:
## it gives `WeaponSystem` the lead point (the guns swing up to their gimbal limit towards it, scaled
## by the assist strength) and sets `InputRouter.aim_friction` so the right stick slows down near
## the target. The mouse gets none unless the player turned mouse assist on (`AimAssist`).
##
## Anything can be targeted that joins the `GROUP` group and has these methods (ships and target
## dummies do): `target_name() -> String` (already translated), `target_stance() -> Stance`,
## `target_velocity() -> Vector3`, `target_radius() -> float`, and `durability() -> Durability`.
##
## `Ship` owns one; it ticks itself from `_physics_process`.

## The selected target changed (`target` is null when it was cleared).
signal target_changed(target: Node3D)
## The lock on `target` was lost for `reason` (a `Lock` other than LOCKED) and the target dropped.
signal lock_lost(target: Node3D, reason: int)

## Whose side something is on. Drives the HUD bracket shape and what "nearest hostile" considers.
enum Stance { HOSTILE, NEUTRAL, FRIENDLY }
## Which targets a selection command considers.
enum Pick { HOSTILE, ANY }
## The state of the lock on the selected target.
enum Lock { LOCKED, OUT_OF_RANGE, OCCLUDED }

## Everything that can be targeted joins this group.
const GROUP: StringName = &"targetable"

## The selected target, or null.
var target: Node3D = null
## The lock state of `target` (meaningful while there is one).
var lock: Lock = Lock.LOCKED
## Seconds `target` has been without a lock.
var lost_for: float = 0.0
## Set for the player's ship: only it drives the aim assist and the input friction.
var is_player: bool = false
## Where to shoot to hit the locked target (world space), valid while `has_lead`.
var lead_point: Vector3 = Vector3.ZERO
## True while the locked target has a lead point a shot can reach.
var has_lead: bool = false

var _ship: Ship = null
var _def: TargetingDef = null


func _ready() -> void:
	_ship = get_parent() as Ship
	_def = Content.targeting()


func _physics_process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	_release_assist()


## Advances targeting by `delta` seconds: runs the pilot's command, checks the lock and updates the
## aim assist. `_physics_process` calls it; sims and unit tests may too.
func tick(delta: float) -> void:
	if _ship == null or _def == null or not _ship.is_inside_tree():
		return
	var controls: ShipControls = _ship.controls
	if controls.target_cmd != ShipControls.Target.NONE:
		command(controls.target_cmd)
		# Used up: a controls object that stays the same between ticks must not repeat it.
		controls.target_cmd = ShipControls.Target.NONE
	_update_lock(delta)
	_update_assist()


## Runs a `ShipControls.Target` command. Only the two selection commands do anything yet:
## `CYCLE_SUBSYSTEM` waits for capital ships (M7).
func command(cmd: int) -> void:
	match cmd:
		ShipControls.Target.NEAREST_HOSTILE:
			select_best(Pick.HOSTILE)
		ShipControls.Target.NEAREST_ANY:
			select_best(Pick.ANY)


## Selects what `choose` picks among the targets in range (`kind` as for `choose`). Does nothing
## when there is none.
func select_best(kind: Pick) -> void:
	var cone: float = deg_to_rad(_def.select_cone_deg)
	var found: Array[Candidate] = []
	for candidate: Candidate in candidates():
		if not is_occluded(candidate.position):
			found.append(candidate)
	var picked: Candidate = choose(found, target, kind, cone)
	if picked != null:
		select(picked.node as Node3D)


## Makes `new_target` the selected target (null clears it).
func select(new_target: Node3D) -> void:
	if new_target == target:
		return
	target = new_target
	lost_for = 0.0
	lock = Lock.LOCKED
	has_lead = false
	target_changed.emit(target)


## Clears the selected target.
func clear() -> void:
	select(null)


## True when there is a selected target the ship has a lock on.
func has_lock() -> bool:
	return target != null and lock == Lock.LOCKED


## Every valid target within lock range except this ship, as `Candidate`s measured from the ship's
## nose. Hidden ones (behind a rock) are included; `select_best` filters those.
func candidates() -> Array[Candidate]:
	var result: Array[Candidate] = []
	if _ship == null or not _ship.is_inside_tree():
		return result
	var origin: Vector3 = _ship.global_position
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node == _ship:
			continue
		var candidate: Candidate = Candidate.from_node(node, origin, forward)
		if candidate != null and candidate.distance <= _def.lock_range_m:
			result.append(candidate)
	return result


## True when world geometry (a rock) is between the ship and `point`.
func is_occluded(point: Vector3) -> bool:
	if _ship == null or not _ship.is_inside_tree():
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		_ship.global_position, point, PhysicsLayers.WORLD, [_ship.get_rid()]
	)
	return not _ship.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The best candidate for a selection command, or null when there is none.
##
## - `Pick.HOSTILE` (a tap): with nothing selected, the nearest hostile inside the reticle cone
##   (`cone` radians around the nose), else the nearest hostile at all. With a hostile already
##   selected, the next one further away (wrapping to the nearest): that is the cycle.
## - `Pick.ANY` (a double-tap): the nearest target of any side, whatever is selected.
##
## Ties go to the earlier candidate in `candidates`. `current` is the selected target.
static func choose(
	candidates_in: Array[Candidate], current: Node3D, kind: Pick, cone: float
) -> Candidate:
	var pool: Array[Candidate] = []
	for candidate: Candidate in candidates_in:
		if kind == Pick.ANY or candidate.stance == Stance.HOSTILE:
			pool.append(candidate)
	if pool.is_empty():
		return null
	pool.sort_custom(func(a: Candidate, b: Candidate) -> bool: return a.distance < b.distance)
	if kind == Pick.ANY:
		return pool[0]
	var selected: int = -1
	for index: int in pool.size():
		if current != null and pool[index].node == current:
			selected = index
	if selected >= 0:
		return pool[(selected + 1) % pool.size()]
	for candidate: Candidate in pool:
		if candidate.angle <= cone:
			return candidate
	return pool[0]


## The lock state for a target `distance` metres away: out of range, hidden behind geometry, or
## locked. Range wins over occlusion (a far target is simply far).
static func lock_status(distance: float, lock_range: float, occluded: bool) -> Lock:
	if distance > lock_range:
		return Lock.OUT_OF_RANGE
	if occluded:
		return Lock.OCCLUDED
	return Lock.LOCKED


## Seconds without a lock after another tick of `delta`: it counts up while the lock is missing
## and resets as soon as it is back.
static func lost_time_step(current: float, locked: bool, delta: float) -> float:
	return 0.0 if locked else current + delta


## True once a lock has been missing long enough for the target to be dropped.
static func lock_expired(lost_time: float, loss_seconds: float) -> bool:
	return lost_time >= loss_seconds


func _update_lock(delta: float) -> void:
	if target == null:
		return
	if not Candidate.is_valid_node(target):
		clear()
		return
	var distance: float = _ship.global_position.distance_to(target.global_position)
	var occluded: bool = distance <= _def.lock_range_m and is_occluded(target.global_position)
	lock = lock_status(distance, _def.lock_range_m, occluded)
	lost_for = lost_time_step(lost_for, lock == Lock.LOCKED, delta)
	if lock != Lock.LOCKED and lock_expired(lost_for, _def.lock_loss_seconds):
		var dropped: Node3D = target
		var reason: Lock = lock
		clear()
		lock_lost.emit(dropped, reason)


## Updates the lead point, and for the player the gimbal and the stick friction.
func _update_assist() -> void:
	has_lead = false
	var weapon: WeaponDef = _ship.weapons().weapon_for(WeaponSystem.GROUP_PRIMARY)
	if has_lock() and weapon != null:
		var velocity: Vector3 = _velocity_of(target)
		var time: float = Lead.time_to_hit(
			_ship.global_position,
			_ship.linear_velocity,
			target.global_position,
			velocity,
			weapon.projectile_speed
		)
		has_lead = time >= 0.0
		lead_point = target.global_position + velocity * maxf(time, 0.0)
	if not is_player:
		return
	var strength: float = AimAssist.current_strength(
		InputRouter.last_device == InputRouter.Device.GAMEPAD
	)
	var weapons: WeaponSystem = _ship.weapons()
	weapons.gimbal_enabled = strength > 0.0
	weapons.gimbal_scale = strength
	if has_lead and strength > 0.0:
		weapons.set_aim_point(lead_point)
	else:
		weapons.clear_aim_point()
	InputRouter.aim_friction = _friction_for(strength)


func _friction_for(strength: float) -> float:
	if not has_lock() or strength <= 0.0:
		return 1.0
	var origin: Vector3 = _ship.global_position
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	var aim_at: Vector3 = lead_point if has_lead else target.global_position
	var angle: float = forward.angle_to(aim_at - origin)
	var zone: float = AimAssist.friction_zone(
		deg_to_rad(_def.friction_zone_deg),
		_radius_of(target),
		origin.distance_to(target.global_position)
	)
	return AimAssist.friction_factor(angle, zone, _def.friction_min_factor, strength)


func _release_assist() -> void:
	if is_player:
		InputRouter.aim_friction = 1.0


static func _velocity_of(node: Node) -> Vector3:
	return (
		node.call(&"target_velocity") as Vector3
		if node.has_method(&"target_velocity")
		else Vector3.ZERO
	)


static func _radius_of(node: Node) -> float:
	return node.call(&"target_radius") as float if node.has_method(&"target_radius") else 0.0


## A target as the selection and the HUD see it, measured from a viewpoint: a snapshot, not a
## live reference to the numbers.
class Candidate:
	extends RefCounted
	var node: Node3D = null
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	var stance: Stance = Stance.HOSTILE
	var display_name: String = ""
	## Metres from the viewpoint.
	var distance: float = 0.0
	## Radians between the viewpoint's forward direction and the target.
	var angle: float = 0.0

	## The snapshot of `node` seen from `origin` looking along `forward`, or null if `node` is not
	## a valid target (freed, outside the tree, destroyed, or missing the target methods).
	static func from_node(node: Node, origin: Vector3, forward: Vector3) -> Candidate:
		if not is_valid_node(node):
			return null
		var spatial: Node3D = node as Node3D
		var result: Candidate = Candidate.new()
		result.node = spatial
		result.position = spatial.global_position
		result.velocity = node.call(&"target_velocity") as Vector3
		result.radius = node.call(&"target_radius") as float
		result.stance = node.call(&"target_stance") as Stance
		result.display_name = node.call(&"target_name") as String
		var offset: Vector3 = result.position - origin
		result.distance = offset.length()
		result.angle = forward.angle_to(offset) if result.distance > 0.0 else 0.0
		return result

	## Plain-data constructor, for tests and for AI code that tracks things without nodes.
	static func make(
		new_position: Vector3, new_stance: Stance, origin: Vector3, forward: Vector3
	) -> Candidate:
		var result: Candidate = Candidate.new()
		result.position = new_position
		result.stance = new_stance
		var offset: Vector3 = new_position - origin
		result.distance = offset.length()
		result.angle = forward.angle_to(offset) if result.distance > 0.0 else 0.0
		return result

	## True when `node` is alive, in the tree, has the target methods and is not destroyed.
	static func is_valid_node(node: Node) -> bool:
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			return false
		if not (node is Node3D):
			return false
		for method: StringName in [
			&"target_name", &"target_stance", &"target_velocity", &"target_radius"
		]:
			if not node.has_method(method):
				return false
		var durability: Durability = ProjectileManager.durability_of(node)
		return durability == null or not durability.is_destroyed()
