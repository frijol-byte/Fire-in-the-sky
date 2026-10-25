class_name WeaponSystem
extends Node
## A ship's guns. It mounts the ship's `primary_weapon` on every `SOCKET_primary_*` hardpoint,
## and while the pilot holds `controls.fire_primary` it fires the whole group: each mount pays
## its energy through `PowerSystem.request` (all or nothing, so a dry capacitor just stops the
## shot), adds heat, and sends a shot into the scene's `ProjectileManager`. Player and AI fire
## through exactly this path; the AI only writes `ShipControls`.
##
## Aim: a mount shoots at a point `WeaponDef.convergence_m` ahead of the ship, so the guns cross
## on the reticle. With a locked target the caller gives `set_aim_point` the lead point, and the
## guns swing towards it by at most `WeaponDef.gimbal_deg` (3 degrees, GDD 7.2). The gimbal is for
## the gamepad: whoever owns targeting turns `gimbal_enabled` off for the mouse.
##
## `Ship` creates it and ticks it from `_physics_process`, which is also where shots may safely
## query the physics space.

## A mount overheated, or cooled down again.
signal overheated(group: StringName, mount: WeaponMount)
signal cooled(group: StringName, mount: WeaponMount)

const GROUP_PRIMARY: StringName = &"primary"
const GROUP_SECONDARY: StringName = &"secondary"
## Fixed seed of the spread; sims call `seed_spread` to get another sequence.
const SPREAD_SEED: int = 7919

## Whether a locked target's lead point may bend the aim (see above).
var gimbal_enabled: bool = true
## Set when a mount could not fire because the capacitor was short; cleared by a shot.
var energy_starved: bool = false

var _ship: Ship = null
var _mounts: Dictionary[StringName, Array] = {}
var _holding: Dictionary[StringName, bool] = {}
var _aim_point: Vector3 = Vector3.ZERO
var _has_aim_point: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _warned_no_manager: bool = false


func _ready() -> void:
	_rng.seed = SPREAD_SEED


func _physics_process(delta: float) -> void:
	tick(delta)


## Mounts the ship's weapon on its hardpoints. `Ship` calls it once the model exists.
func configure(ship: Ship) -> void:
	_ship = ship
	rebuild()


## Mounts again from the model's current sockets (a tier change adds `SOCKET_primary_2`). Heat
## and reload of the old mounts are lost.
func rebuild() -> void:
	_mounts.clear()
	_holding.clear()
	if _ship == null or _ship.model == null:
		return
	var weapon: WeaponDef = Content.weapon(_ship.def.primary_weapon)
	if weapon == null:
		Log.error(&"weapons", "no WeaponDef '%s' for %s" % [_ship.def.primary_weapon, _ship.def.id])
		return
	var primary: Array[WeaponMount] = []
	for socket: Marker3D in _ship.model.get_sockets(GROUP_PRIMARY):
		primary.append(WeaponMount.create(weapon, socket, primary.size()))
	_mounts[GROUP_PRIMARY] = primary
	_mounts[GROUP_SECONDARY] = []


## Seeds the random spread, for repeatable sims.
func seed_spread(seed_value: int) -> void:
	_rng.seed = seed_value


## The mounts of `group`.
func mounts(group: StringName) -> Array:
	return _mounts.get(group, [])


## The weapon fitted to `group`, or null when it has no mounts.
func weapon_for(group: StringName) -> WeaponDef:
	var list: Array = mounts(group)
	return (list[0] as WeaponMount).weapon if not list.is_empty() else null


## Hottest mount of `group` as a 0..1 fraction of its overheat line.
func heat_fraction(group: StringName) -> float:
	var hottest: float = 0.0
	for mount: WeaponMount in mounts(group):
		hottest = maxf(hottest, mount.heat_fraction())
	return hottest


## True while any mount of `group` is overheated.
func is_overheated(group: StringName) -> bool:
	for mount: WeaponMount in mounts(group):
		if mount.overheated:
			return true
	return false


## Points the guns at `point` (the lead point of the locked target), within the gimbal limit.
func set_aim_point(point: Vector3) -> void:
	_aim_point = point
	_has_aim_point = true


## Goes back to the convergence point.
func clear_aim_point() -> void:
	_has_aim_point = false


## Advances heat, reload and the trigger by `delta` seconds. `_physics_process` calls it; sims and
## unit tests may too.
func tick(delta: float) -> void:
	if _ship == null:
		return
	var controls: ShipControls = _ship.controls
	for group: StringName in _mounts:
		var holding: bool = (
			controls.fire_primary if group == GROUP_PRIMARY else controls.fire_secondary
		)
		_tick_group(group, holding, delta)


## The direction a shot leaves `mount` before spread: towards the aim point within the gimbal
## limit, else towards the convergence point, else straight ahead.
func aim_direction(mount: WeaponMount) -> Vector3:
	var origin: Vector3 = mount.socket.global_position
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	var weapon: WeaponDef = mount.weapon
	if _has_aim_point and gimbal_enabled and weapon.gimbal_deg > 0.0:
		var wanted: Vector3 = (_aim_point - origin).normalized()
		return limit_angle(forward, wanted, deg_to_rad(weapon.gimbal_deg))
	if weapon.convergence_m > 0.0:
		return (_ship.global_position + forward * weapon.convergence_m - origin).normalized()
	return forward


## `wanted`, unless it is more than `max_angle` radians off `forward`; then `forward` turned that
## far towards it. Both are unit vectors.
static func limit_angle(forward: Vector3, wanted: Vector3, max_angle: float) -> Vector3:
	if wanted.length_squared() < 0.000001:
		return forward
	var angle: float = forward.angle_to(wanted)
	if angle <= max_angle:
		return wanted.normalized()
	return forward.slerp(wanted.normalized(), max_angle / angle).normalized()


## `direction` turned by a random angle of up to `spread_deg` degrees. `u` and `v` are random
## numbers in 0..1: `u` picks the angle (square-rooted, so shots fill the cone evenly), `v` the side.
static func spread_direction(direction: Vector3, spread_deg: float, u: float, v: float) -> Vector3:
	if spread_deg <= 0.0:
		return direction
	var angle: float = deg_to_rad(spread_deg) * sqrt(u)
	var around: float = TAU * v
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = direction.cross(side).normalized()
	var offset: Vector3 = side * cos(around) + up * sin(around)
	return (direction * cos(angle) + offset * sin(angle)).normalized()


func _tick_group(group: StringName, holding: bool, delta: float) -> void:
	var list: Array = _mounts[group]
	var disabled: bool = _group_disabled(group)
	var firing: bool = holding and not disabled and not _ship.durability().is_destroyed()
	if firing and not _holding.get(group, false):
		for mount: WeaponMount in list:
			mount.stagger_start(list.size())
	_holding[group] = firing
	for mount: WeaponMount in list:
		if mount.advance(delta, firing):
			cooled.emit(group, mount)
		if firing and mount.can_fire():
			_fire(group, mount)


## Ion hits switch off missiles and devices (GDD 7.1); the primary guns keep working.
func _group_disabled(group: StringName) -> bool:
	return group == GROUP_SECONDARY and _ship.durability().devices_disabled()


func _fire(group: StringName, mount: WeaponMount) -> void:
	var weapon: WeaponDef = mount.weapon
	var manager: ProjectileManager = ProjectileManager.for_node(self)
	if manager == null:
		if not _warned_no_manager:
			_warned_no_manager = true
			Log.warn(&"weapons", "no ProjectileManager in the scene; %s cannot fire" % _ship.name)
		return
	if weapon.energy_cost > 0.0 and not _ship.power().request(weapon.energy_cost):
		energy_starved = true
		return
	energy_starved = false
	var direction: Vector3 = spread_direction(
		aim_direction(mount), weapon.spread_deg, _rng.randf(), _rng.randf()
	)
	var muzzle: Vector3 = mount.socket.global_position
	manager.spawn(weapon, _ship, muzzle, direction)
	if manager.fx != null:
		manager.fx.muzzle(muzzle, weapon)
	if mount.register_shot():
		overheated.emit(group, mount)
		if manager.fx != null:
			manager.fx.overheat(muzzle)
