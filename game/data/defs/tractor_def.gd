class_name TractorDef
extends ContentDef
## The player's tractor beam (M2-T6): loot containers inside `range_m` are pulled towards the ship
## and collected within `collect_radius_m`. Always on for now; the tractor beam becomes an
## equipment item later (GDD 9), which will bring its own defs of this kind.

## Containers closer than this (metres, from the ship's centre) are pulled in.
@export var range_m: float = 220.0
## A container this close to the ship's centre is collected.
@export var collect_radius_m: float = 9.0
## How fast a pulled container closes in on the ship (m/s relative to the ship) at most, and how
## quickly it gets there (m/s per second).
@export var pull_speed: float = 90.0
@export var pull_accel: float = 160.0


func kind() -> StringName:
	return &"tractor"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if range_m <= 0.0:
		result.append("range_m must be above 0")
	if collect_radius_m <= 0.0 or collect_radius_m >= range_m:
		result.append("collect_radius_m must be above 0 and below range_m")
	if pull_speed <= 0.0 or pull_accel <= 0.0:
		result.append("pull_speed and pull_accel must be above 0")
	return result
