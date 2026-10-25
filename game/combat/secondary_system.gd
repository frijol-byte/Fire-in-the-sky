class_name SecondarySystem
extends Node
## A ship's secondary weapon (GDD 7.2): the Homing Missile or the Rocket Pod, whichever
## `ShipDef.secondary_weapon` names. Player and AI use it through `controls.fire_secondary` only.
##
## Homing Missile: hold the button with a locked target selected (`Targeting`) inside the lock cone
## and range, and the lock builds for `lock_time` seconds (`MissileLock`, with beeps for the
## player). Release once it is locked to launch; release early and nothing is launched and no
## ammo is spent. If the target leaves the cone the lock drains away.
## Rocket Pod: press (or hold) to fire a salvo of unguided rockets, one after another.
##
## Ammo counts down per missile or rocket; stations will sell more (`add_ammo`). An ion hit
## (`Durability.devices_disabled`) blocks the weapon, like it does devices. The rounds are flown by
## the scene's `MissileManager`.
##
## `Ship` creates it and ticks it from `_physics_process`.

## A round was launched from this ship.
signal launched(round_record: Missile)

## Fixed seed of the rocket spread; sims call `seed_spread` to get another sequence.
const SPREAD_SEED: int = 4177
const LOCK_BEEP_DB: float = -6.0
const LOCK_READY_DB: float = -4.0
const SOUND_LOCK_BEEP: AudioStreamWAV = preload("res://assets/audio/sfx/lock_beep.wav")
const SOUND_LOCK_READY: AudioStreamWAV = preload("res://assets/audio/sfx/lock_ready.wav")

var def: SecondaryDef = null
## Rounds left.
var ammo: int = 0
var lock: MissileLock = MissileLock.new()
## The target the lock is built on (or null).
var lock_target: Node3D = null

var _ship: Ship = null
var _cooldown: float = 0.0
var _salvo_left: int = 0
var _salvo_timer: float = 0.0
var _was_holding: bool = false
var _launch_count: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _warned_no_manager: bool = false
var _beeper: AudioStreamPlayer = null


func _ready() -> void:
	_rng.seed = SPREAD_SEED


func _physics_process(delta: float) -> void:
	tick(delta)


## Takes the weapon from the ship's def and fills the magazine. `Ship` calls it once.
func configure(ship: Ship) -> void:
	_ship = ship
	def = Content.secondary(ship.def.secondary_weapon)
	ammo = def.ammo if def != null else 0
	if def == null and ship.def.secondary_weapon != &"":
		Log.error(
			&"weapons", "no SecondaryDef '%s' for %s" % [ship.def.secondary_weapon, ship.def.id]
		)


## Seeds the random spread of rockets, for repeatable sims.
func seed_spread(seed_value: int) -> void:
	_rng.seed = seed_value


## Adds rounds, up to a full magazine. Returns how many were added.
func add_ammo(count: int) -> int:
	if def == null:
		return 0
	var added: int = clampi(count, 0, def.ammo - ammo)
	ammo += added
	return added


## Seconds until the weapon may start again (0 when ready).
func cooldown_left() -> float:
	return _cooldown


## True while a salvo of rockets is still being fired.
func is_firing_salvo() -> bool:
	return _salvo_left > 0


## True when the weapon has a round and is not cooling down.
func is_ready() -> bool:
	return def != null and ammo > 0 and _cooldown <= 0.0


## Whether `target` could be locked from here right now: the weapon homes and is ready, the ship
## has a lock on `target` as its selected target, and it is inside the cone and the range.
func can_lock_on(target: Node3D) -> bool:
	if def == null or not def.is_homing() or not is_ready() or not is_instance_valid(target):
		return false
	var targeting: Targeting = _ship.targeting()
	if targeting.target != target or not targeting.has_lock():
		return false
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	return in_lock_envelope(
		forward,
		target.global_position - _ship.global_position,
		def.lock_cone_rad(),
		def.lock_range_m
	)


## True when a target `to_target` metres away (a vector from the ship) is within `max_range` and
## within `cone` radians of `forward`.
static func in_lock_envelope(
	forward: Vector3, to_target: Vector3, cone: float, max_range: float
) -> bool:
	var distance: float = to_target.length()
	if distance > max_range:
		return false
	return distance < 0.001 or forward.angle_to(to_target) <= cone


## Advances the weapon by `delta` seconds. `_physics_process` calls it; sims and unit tests may too.
func tick(delta: float) -> void:
	if _ship == null or def == null:
		return
	var durability: Durability = _ship.durability()
	var enabled: bool = not durability.is_destroyed() and not durability.devices_disabled()
	var holding: bool = _ship.controls.fire_secondary and enabled
	_cooldown = maxf(_cooldown - delta, 0.0)
	if def.is_homing():
		_tick_homing(delta, holding, enabled)
	else:
		_tick_rockets(delta, holding, enabled)
	_was_holding = holding


func _tick_homing(delta: float, holding: bool, enabled: bool) -> void:
	var target: Node3D = _ship.targeting().target
	if target != lock_target:
		lock.reset()
		lock_target = target
	var released: bool = _was_holding and not holding
	if released and enabled and lock.is_locked() and can_lock_on(lock_target):
		_launch_missile(lock_target)
	var beep: MissileLock.Beep = lock.advance(delta, holding, can_lock_on(target), def.lock_time)
	_play_beep(beep)


func _tick_rockets(delta: float, holding: bool, enabled: bool) -> void:
	if _salvo_left > 0:
		if not enabled:
			_end_salvo()
			return
		_salvo_timer -= delta
		while _salvo_timer <= 0.0 and _salvo_left > 0:
			_launch_rocket()
			_salvo_left -= 1
			_salvo_timer += def.salvo_interval
		if _salvo_left <= 0:
			_end_salvo()
	elif holding and _cooldown <= 0.0 and ammo > 0:
		_salvo_left = mini(def.salvo_count, ammo)
		_salvo_timer = 0.0
		_tick_rockets(delta, holding, enabled)


func _end_salvo() -> void:
	_salvo_left = 0
	_cooldown = def.cooldown


func _launch_missile(target: Node3D) -> void:
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	if _launch(forward, target) != null:
		_cooldown = def.cooldown
		lock.reset()


func _launch_rocket() -> void:
	var forward: Vector3 = -_ship.global_basis.orthonormalized().z
	var direction: Vector3 = WeaponSystem.spread_direction(
		forward, def.spread_deg, _rng.randf(), _rng.randf()
	)
	_launch(direction, null)
	if ammo <= 0:
		_salvo_left = 0


## Fires one round along `direction`. Returns it, or null when there is no manager or no ammo.
func _launch(direction: Vector3, target: Node3D) -> Missile:
	if ammo <= 0:
		return null
	var manager: MissileManager = MissileManager.for_node(self)
	if manager == null:
		if not _warned_no_manager:
			_warned_no_manager = true
			Log.warn(&"weapons", "no MissileManager in the scene; %s cannot launch" % _ship.name)
		return null
	var origin: Vector3 = _launch_origin()
	var start_velocity: Vector3 = _ship.linear_velocity + direction * def.launch_speed
	ammo -= 1
	_launch_count += 1
	var round_record: Missile = manager.launch(def, _ship, origin, start_velocity, target)
	if manager.fx != null:
		manager.fx.flash(origin, def.color, def.launch_flash_size)
		if not def.launch_sfx.is_empty():
			manager.fx.play(manager.fx.load_sound(def.launch_sfx), origin, def.launch_sfx_db)
	launched.emit(round_record)
	return round_record


## Where rounds leave: the next `SOCKET_secondary_*` if the model has them, else the ship's
## `secondary_launch_offset`.
func _launch_origin() -> Vector3:
	var sockets: Array[Marker3D] = _ship.model.get_sockets(&"secondary")
	if not sockets.is_empty():
		return sockets[_launch_count % sockets.size()].global_position
	return _ship.global_transform * _ship.def.secondary_launch_offset


func _play_beep(beep: MissileLock.Beep) -> void:
	if beep == MissileLock.Beep.NONE or not _ship.targeting().is_player:
		return
	if _beeper == null:
		_beeper = AudioStreamPlayer.new()
		_beeper.name = "LockBeeper"
		_beeper.tree_exiting.connect(_beeper.stop)
		add_child(_beeper)
	if beep == MissileLock.Beep.READY:
		_beeper.stream = SOUND_LOCK_READY
		_beeper.volume_db = LOCK_READY_DB
		_beeper.pitch_scale = 1.0
	else:
		_beeper.stream = SOUND_LOCK_BEEP
		_beeper.volume_db = LOCK_BEEP_DB
		_beeper.pitch_scale = MissileLock.beep_pitch(lock.progress)
	_beeper.play()
