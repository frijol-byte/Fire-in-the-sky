class_name WeaponMount
extends RefCounted
## One gun on one hardpoint: its `WeaponDef`, the socket it sits on, and its heat and reload.
## The rules for rate of fire, heat and overheating live here, apart from the scene, so they can
## be unit tested; `WeaponSystem` decides when to pull the trigger.
##
## Rate of fire: `cooldown` counts down to the next shot. Firing adds one interval to it instead of
## resetting it, so the fraction of a tick left over is kept and the rate is exact (7 shots a
## second really is 7). It never banks more than one tick, so waiting for energy cannot save up a burst.
## Heat: each shot adds `heat_per_shot`; reaching `heat_capacity` overheats the mount, which cannot
## fire until it has cooled to `WeaponDef.resume_heat`.

var weapon: WeaponDef = null
## The `SOCKET_primary_*` marker the shots leave from.
var socket: Marker3D = null
## Position among the mounts of its group, from 0.
var index: int = 0
var heat: float = 0.0
var overheated: bool = false
## Seconds until the next shot is allowed (negative: ready, down to one tick banked).
var cooldown: float = 0.0


static func create(new_weapon: WeaponDef, new_socket: Marker3D, new_index: int) -> WeaponMount:
	var mount: WeaponMount = WeaponMount.new()
	mount.weapon = new_weapon
	mount.socket = new_socket
	mount.index = new_index
	return mount


## Advances reload and cooling by `delta` seconds. `holding` is whether the trigger is down: an
## idle mount keeps no head start. Returns true on the tick the mount stops being overheated.
func advance(delta: float, holding: bool) -> bool:
	cooldown -= delta
	cooldown = maxf(cooldown, -delta) if holding else maxf(cooldown, 0.0)
	heat = maxf(heat - weapon.cool_rate * delta, 0.0)
	if overheated and heat <= weapon.resume_heat():
		overheated = false
		return true
	return false


## True when the mount may fire this tick (energy aside).
func can_fire() -> bool:
	return not overheated and cooldown <= 0.0


## Records a shot: the next one is an interval away and the heat goes up. Returns true if this
## shot overheated the mount.
func register_shot() -> bool:
	cooldown += weapon.interval()
	heat += weapon.heat_per_shot
	if heat >= weapon.heat_capacity:
		heat = weapon.heat_capacity
		overheated = true
		return true
	return false


## Heat as a 0..1 fraction of the overheat line.
func heat_fraction() -> float:
	return heat / weapon.heat_capacity


## Delays the first shot of a freshly started burst by `index / count` of an interval, which makes
## staggered guns alternate. Does nothing for a mount that is already reloading for longer.
func stagger_start(count: int) -> void:
	if weapon.stagger and count > 1:
		cooldown = maxf(cooldown, weapon.interval() * float(index) / float(count))
