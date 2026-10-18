class_name ShipControls
extends RefCounted
## One tick of pilot intent. The player (`InputRouter`) and the AI both fill one of these in
## each physics tick, and the flight and weapon code reads nothing else. That keeps AI and
## player on the same physics path and makes a touch layer cheap to add later.
##
## Axis convention (matches the sticks): +1 pitch = nose up, +1 yaw = nose right, +1 roll =
## right wing down. For `thrust`, +x is strafe right, +y is up and +z is forward.

## Values for `target_cmd`.
enum Target { NONE, NEAREST_HOSTILE, NEAREST_ANY, CYCLE_SUBSYSTEM }

## Linear command: x strafe, y vertical, z forward. Each axis is -1..1.
var thrust: Vector3 = Vector3.ZERO
## Angular command: x pitch, y yaw, z roll. Each axis is -1..1.
var rotate: Vector3 = Vector3.ZERO
## True while boost is held.
var boost: bool = false
## True while flight assist is held off (drifting).
var fa_off: bool = false
var fire_primary: bool = false
var fire_secondary: bool = false
## Device slot pressed this tick: 0 for none, 1 to 3 for devices 1-3.
var device: int = 0
## A `Target` value, set for the single tick on which the command was given.
var target_cmd: int = Target.NONE
## True for the single tick on which interact was pressed.
var interact: bool = false


## Returns true when nothing is commanded (every axis zero, no buttons, no one-shot commands).
func is_idle() -> bool:
	return (
		thrust == Vector3.ZERO
		and rotate == Vector3.ZERO
		and not boost
		and not fa_off
		and not fire_primary
		and not fire_secondary
		and device == 0
		and target_cmd == Target.NONE
		and not interact
	)
