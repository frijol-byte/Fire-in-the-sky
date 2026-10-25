class_name TargetingDef
extends ContentDef
## How targeting behaves: which targets a tap picks, how far a lock reaches and how long a lost lock
## is kept, and the aim assist's reach. One def (`default`) for now; the numbers are tuned in the M2
## playtest.
##
## Units: metres, seconds, degrees.

## A tap on "target nearest" prefers hostiles inside this half-angle around the nose (the reticle).
@export var select_cone_deg: float = 15.0
## A target further than this cannot be selected or kept locked.
@export var lock_range_m: float = 1500.0
## A target that is out of range or hidden behind a rock is dropped after this long.
@export var lock_loss_seconds: float = 2.0

@export_group("Aim assist")
## Reticle friction starts when the nose is within this angle of the locked target (plus the angle
## the target itself covers).
@export var friction_zone_deg: float = 6.0
## Right-stick multiplier on the target at full assist strength (1 = no friction).
@export_range(0.0, 1.0) var friction_min_factor: float = 0.45


func kind() -> StringName:
	return &"targeting"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if select_cone_deg <= 0.0 or select_cone_deg > 90.0:
		result.append("select_cone_deg must be above 0 and at most 90")
	if lock_range_m <= 0.0:
		result.append("lock_range_m must be above 0")
	if lock_loss_seconds < 0.0:
		result.append("lock_loss_seconds must not be negative")
	if friction_zone_deg < 0.0:
		result.append("friction_zone_deg must not be negative")
	return result
