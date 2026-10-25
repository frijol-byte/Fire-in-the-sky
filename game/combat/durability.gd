class_name Durability
extends Node
## A ship's health: shield, then armor, then hull (GDD 7.1). `apply` is the one function that
## turns a `DamageInfo` into lost health; every weapon, splash and collision goes through it.
##
## A hit is multiplied by the `DamageTable` for the layer it lands on. When a layer runs out,
## the unspent part of the hit carries on to the next layer, converted back to raw damage first
## so a layer's multiplier only applies to what that layer absorbed. Shields regenerate after
## `shield_regen_delay` seconds without damage; armor does not (stations repair it). Hull at 0
## destroys the ship. An ion hit also starts the ion status (`devices_disabled`).
##
## `Ship` ticks it from `_integrate_forces`.

var shield: float = 0.0
var armor: float = 0.0
var hull: float = 0.0
var shield_capacity: float = 0.0
var armor_capacity: float = 0.0
var hull_capacity: float = 0.0
## Shield regained per second once the delay has passed.
var shield_regen_per_second: float = 0.0
## Seconds without damage before the shield starts to regenerate.
var shield_regen_delay: float = 4.0

var _ship: Node = null
var _table: DamageTable = null
var _destroyed: bool = false
var _seconds_since_damage: float = 0.0
## Status name -> seconds remaining.
var _statuses: Dictionary[StringName, float] = {}


## Takes the layer sizes and shield regeneration from `def`, fills every layer and uses `table`
## (the default `DamageTable` from `Content` when `null`). `ship` is reported in the events.
func configure(def: ShipDef, ship: Node = null, table: DamageTable = null) -> void:
	_ship = ship
	_table = table if table != null else Content.get_def(&"damage_table", &"default") as DamageTable
	shield_capacity = def.shield_capacity
	armor_capacity = def.armor_capacity
	hull_capacity = def.hull_capacity
	shield_regen_per_second = def.shield_regen
	shield_regen_delay = def.shield_regen_delay
	restore()


## Fills every layer, clears statuses and revives the ship (used on respawn).
func restore() -> void:
	shield = shield_capacity
	armor = armor_capacity
	hull = hull_capacity
	_destroyed = false
	_seconds_since_damage = shield_regen_delay
	_statuses.clear()


## Applies one hit and reports what it did. Emits `Events.ship_damaged` for a hit that took
## health, and `Events.ship_destroyed` once, on the hit that empties the hull. A destroyed ship
## takes nothing more.
func apply(info: DamageInfo) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	if _destroyed or info.amount <= 0.0:
		return result
	_seconds_since_damage = 0.0
	var remaining: float = info.amount
	var shield_mult: float = _table.multiplier(info.type, DamageTable.Layer.SHIELD)
	var armor_mult: float = _table.multiplier(info.type, DamageTable.Layer.ARMOR)
	var hull_mult: float = _table.multiplier(info.type, DamageTable.Layer.HULL)

	var shield_hit: Vector2 = _absorb(remaining, shield_mult, shield)
	shield -= shield_hit.x
	result.shield_damage = shield_hit.x
	remaining = shield_hit.y

	var armor_hit: Vector2 = _absorb(remaining, armor_mult, armor)
	armor -= armor_hit.x
	result.armor_damage = armor_hit.x
	remaining = armor_hit.y

	var hull_hit: Vector2 = _absorb(remaining, hull_mult, hull)
	hull -= hull_hit.x
	result.hull_damage = hull_hit.x

	if info.type == DamageInfo.Type.ION:
		_statuses[DamageTable.STATUS_ION] = maxf(
			_statuses.get(DamageTable.STATUS_ION, 0.0), _table.ion_disable_seconds
		)
		result.ion_disabled = _table.ion_disable_seconds > 0.0

	if hull_hit.x > 0.0 and hull <= 0.0:
		hull = 0.0
		_destroyed = true
		result.destroyed = true
	if result.total() > 0.0:
		Events.ship_damaged.emit(_ship, info, result)
	if result.destroyed:
		Events.ship_destroyed.emit(_ship, info)
	return result


## Advances shield regeneration and status timers by `dt` seconds.
func tick(dt: float) -> void:
	if _destroyed:
		return
	_seconds_since_damage += dt
	if _seconds_since_damage >= shield_regen_delay:
		shield = minf(shield_capacity, shield + shield_regen_per_second * dt)
	for status: StringName in _statuses.keys():
		var left: float = _statuses[status] - dt
		if left <= 0.0:
			_statuses.erase(status)
		else:
			_statuses[status] = left


func is_destroyed() -> bool:
	return _destroyed


## True while the named status (e.g. `DamageTable.STATUS_ION`) is active.
func has_status(status: StringName) -> bool:
	return _statuses.has(status)


## Seconds left on a status, 0 when it is not active.
func status_remaining(status: StringName) -> float:
	return _statuses.get(status, 0.0)


## True while an ion hit has devices and missiles disabled.
func devices_disabled() -> bool:
	return has_status(DamageTable.STATUS_ION)


func shield_fraction() -> float:
	return shield / shield_capacity if shield_capacity > 0.0 else 0.0


func armor_fraction() -> float:
	return armor / armor_capacity if armor_capacity > 0.0 else 0.0


func hull_fraction() -> float:
	return hull / hull_capacity if hull_capacity > 0.0 else 0.0


## One layer's share of a hit. `raw` is the damage still to place, `multiplier` the layer's
## factor for this damage type and `health` what the layer has left. Returns (health lost,
## raw damage left over for the next layer). A layer that is empty or immune (multiplier 0)
## takes nothing and passes the whole hit on.
func _absorb(raw: float, multiplier: float, health: float) -> Vector2:
	if raw <= 0.0 or multiplier <= 0.0 or health <= 0.0:
		return Vector2(0.0, raw)
	var effective: float = raw * multiplier
	if effective <= health:
		return Vector2(effective, 0.0)
	return Vector2(health, (effective - health) / multiplier)
