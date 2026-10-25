class_name DeviceSystem
extends Node
## A ship's devices (GDD 7.2): active abilities with a cooldown, in the slots named by
## `ShipDef.device_ids`. The pilot presses a device button, which sets `controls.device` to the slot
## (1 to 3) for one tick; the player and the AI use it the same way. Only the Countermeasure Flares
## exist so far (they ask the scene's `MissileManager` to throw flares).
##
## An ion hit (`Durability.devices_disabled`) blocks devices, and a destroyed ship has none.
##
## `Ship` creates it and ticks it from `_physics_process`.

## Slot `slot` (1 to 3) was used.
signal used(slot: int, def: DeviceDef)

var _ship: Ship = null
var _defs: Array[DeviceDef] = []
var _cooldowns: PackedFloat32Array = []
var _warned_no_manager: bool = false


func _physics_process(delta: float) -> void:
	tick(delta)


## Fits the devices named in the ship's def. `Ship` calls it once.
func configure(ship: Ship) -> void:
	_ship = ship
	_defs.clear()
	_cooldowns.clear()
	for device_id: StringName in ship.def.device_ids:
		var def: DeviceDef = Content.device(device_id)
		if def == null:
			Log.error(&"devices", "no DeviceDef '%s' for %s" % [device_id, ship.def.id])
			continue
		_defs.append(def)
		_cooldowns.append(0.0)


## Number of fitted devices.
func count() -> int:
	return _defs.size()


## The device in `slot` (1 to 3), or null when the slot is empty.
func device_in(slot: int) -> DeviceDef:
	return _defs[slot - 1] if slot >= 1 and slot <= _defs.size() else null


## Seconds before the device in `slot` can be used again (0 when ready or the slot is empty).
func cooldown_left(slot: int) -> float:
	return _cooldowns[slot - 1] if slot >= 1 and slot <= _defs.size() else 0.0


## True when `slot` holds a device that is ready.
func is_ready(slot: int) -> bool:
	return device_in(slot) != null and cooldown_left(slot) <= 0.0


## Advances the cooldowns by `delta` seconds and runs the device the pilot pressed. `_physics_process`
## calls it; sims and unit tests may too.
func tick(delta: float) -> void:
	if _ship == null:
		return
	for index: int in _cooldowns.size():
		_cooldowns[index] = maxf(_cooldowns[index] - delta, 0.0)
	var slot: int = _ship.controls.device
	if slot != 0:
		# Used up: a controls object that stays the same between ticks must not repeat it.
		_ship.controls.device = 0
		use(slot)


## Uses the device in `slot` (1 to 3). Returns false, and spends nothing, when the slot is empty,
## cooling down, the device is blocked, or the capacitor cannot pay for it.
func use(slot: int) -> bool:
	var def: DeviceDef = device_in(slot)
	if def == null or not is_ready(slot):
		return false
	var durability: Durability = _ship.durability()
	if durability.is_destroyed() or durability.devices_disabled():
		return false
	var manager: MissileManager = MissileManager.for_node(self)
	if manager == null:
		if not _warned_no_manager:
			_warned_no_manager = true
			Log.warn(
				&"devices", "no MissileManager in the scene; %s cannot use flares" % _ship.name
			)
		return false
	if def.energy_cost > 0.0 and not _ship.power().request(def.energy_cost):
		return false
	match def.effect:
		DeviceDef.Effect.FLARES:
			manager.deploy_flares(_ship, def)
	_cooldowns[slot - 1] = def.cooldown
	used.emit(slot, def)
	return true
