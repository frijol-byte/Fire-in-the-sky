class_name PowerSystem
extends Node
## The ship's energy capacitor. Boost, energy weapons and devices all spend from this one pool
## (GDD 4.3). Energy regenerates once nothing has been spent for `regen_delay` seconds.
##
## Consumers call `request(amount)`: it is all or nothing, so a weapon that cannot afford a shot
## simply does not fire. `Ship` calls `tick` once per physics step.

## Energy in the capacitor right now, 0..`capacity`.
var energy: float = 0.0
var capacity: float = 100.0
## Energy regained per second once the delay has passed.
var regen_per_second: float = 12.0
## Seconds after the last spend before regeneration starts.
var regen_delay: float = 1.2

var _seconds_since_spend: float = 0.0


## Takes the capacitor size and regeneration from `def`, and fills it.
func configure(def: ShipDef) -> void:
	capacity = def.energy_capacity
	regen_per_second = def.energy_regen
	regen_delay = def.energy_regen_delay
	energy = capacity
	_seconds_since_spend = regen_delay


## Takes new capacitor size and regeneration values from `def` without refilling, keeping the
## energy held (capped to the new capacity). The tuning overlay calls this while you fly.
func retune(def: ShipDef) -> void:
	capacity = def.energy_capacity
	regen_per_second = def.energy_regen
	regen_delay = def.energy_regen_delay
	energy = minf(energy, capacity)


## Spends `amount` and returns true, or returns false and spends nothing when there is not
## enough. A successful spend restarts the regeneration delay.
func request(amount: float) -> bool:
	if amount < 0.0 or amount > energy:
		return false
	energy -= amount
	if amount > 0.0:
		_seconds_since_spend = 0.0
	return true


## True when `request(amount)` would succeed.
func can_afford(amount: float) -> bool:
	return amount >= 0.0 and amount <= energy


## Energy as a 0..1 fraction of the capacity.
func fraction() -> float:
	return energy / capacity if capacity > 0.0 else 0.0


## Advances regeneration by `dt` seconds.
func tick(dt: float) -> void:
	_seconds_since_spend += dt
	if _seconds_since_spend >= regen_delay:
		energy = minf(capacity, energy + regen_per_second * dt)
