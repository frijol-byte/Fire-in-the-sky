class_name AIProfileDef
extends ContentDef
## How an AI pilot flies and fights (GDD 8, architecture 5.3): how fast it reacts, how well it aims,
## how aggressive it is and where it likes to shoot from. One profile per kind of pilot
## (`data/ai/*.tres`); the encounter code and, later, the difficulty setting pick one. Nothing
## about a ship's speed or turn rate is here: `AIPilot` reads those from the ship's own `ShipDef`.
##
## Units: metres, seconds, degrees.

## Seconds between a threat appearing (a missile steering at the ship, a lock on it) and the pilot
## reacting to it. Higher is easier to beat.
@export var reaction_time: float = 0.4
## How far the pilot's aim is off the lead point, at most, in degrees. Re-rolled every
## `aim_error_period` seconds and eased to, so it drifts instead of jittering.
@export var aim_error_deg: float = 2.0
@export var aim_error_period: float = 0.8
## 0 (cautious) to 1 (reckless). Raises the pull of attack runs and lowers the pull of evading and
## breaking off.
@export_range(0.0, 1.0) var aggression: float = 0.75

@export_group("Ranges")
## An attack run opens fire inside this distance (also limited by the gun's own range).
@export var preferred_range_m: float = 300.0
## Closer than this the pilot breaks off instead of ramming. Never below the ship's turning circle.
@export var break_off_range_m: float = 140.0
## Targets further than this are ignored.
@export var sight_range_m: float = 3000.0
## Seconds between looking for a nearer enemy than the current one.
@export var retarget_interval: float = 1.5

@export_group("Shooting")
## The guns fire when the nose is within this angle of the aim point (the target's size widens it).
@export var fire_cone_deg: float = 4.0
## Chance per attack run, 0..1, that the pilot uses its secondary weapon when it can.
@export_range(0.0, 1.0) var secondary_use: float = 0.5

@export_group("Steering")
## How sharply the nose chases the aim point: the turn rate asked for is the angle error times
## this, in 1/s, up to the ship's top turn rate.
@export var turn_gain: float = 5.0
## Spend boost energy only while the capacitor holds more than this fraction (the rest is for guns).
@export_range(0.0, 1.0) var boost_reserve: float = 0.45
@export var use_boost: bool = true

@export_group("Maneuvers")
## The pilot stays in a behavior at least this long (an emergency can still cut in).
@export var min_behavior_seconds: float = 0.6
## A break-off lasts this long.
@export var break_off_seconds: float = 1.2
## An evade lasts this long.
@export var evade_seconds: float = 1.5
## After an evade the pilot will not dodge gunfire again for this long (a missile or a lock still
## makes it evade), so the other pilot always gets a window to shoot back at.
@export var evade_cooldown: float = 3.0
## Seconds between changes of jink direction.
@export var jink_period: float = 0.7
## Chance per evade, 0..1, of a flight-assist-off flip to face an attacker that is behind.
@export_range(0.0, 1.0) var flip_chance: float = 0.35
## A flip gives up after this long.
@export var flip_seconds: float = 1.0
## Use countermeasure flares when a missile is steering at the ship.
@export var use_flares: bool = true

@export_group("Rocks")
## The pilot looks this far ahead along its velocity for rocks, in seconds of flight.
@export var rock_look_ahead: float = 2.2
## Extra clearance the pilot wants from a rock, in metres.
@export var rock_margin_m: float = 12.0


func kind() -> StringName:
	return &"ai_profile"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	var positive: Dictionary[String, float] = {
		"preferred_range_m": preferred_range_m,
		"break_off_range_m": break_off_range_m,
		"sight_range_m": sight_range_m,
		"retarget_interval": retarget_interval,
		"fire_cone_deg": fire_cone_deg,
		"turn_gain": turn_gain,
		"aim_error_period": aim_error_period,
		"break_off_seconds": break_off_seconds,
		"evade_seconds": evade_seconds,
		"jink_period": jink_period,
		"flip_seconds": flip_seconds,
		"rock_look_ahead": rock_look_ahead,
	}
	for field: String in positive:
		if positive[field] <= 0.0:
			result.append("%s must be above 0" % field)
	var not_negative: Dictionary[String, float] = {
		"reaction_time": reaction_time,
		"aim_error_deg": aim_error_deg,
		"min_behavior_seconds": min_behavior_seconds,
		"evade_cooldown": evade_cooldown,
		"rock_margin_m": rock_margin_m,
	}
	for field: String in not_negative:
		if not_negative[field] < 0.0:
			result.append("%s must not be negative" % field)
	if break_off_range_m >= preferred_range_m:
		result.append("break_off_range_m must be below preferred_range_m")
	if preferred_range_m >= sight_range_m:
		result.append("preferred_range_m must be below sight_range_m")
	return result
