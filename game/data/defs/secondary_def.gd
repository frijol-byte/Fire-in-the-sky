class_name SecondaryDef
extends ContentDef
## One secondary weapon (GDD 7.2): the Homing Missile and the Rocket Pod so far. Pure data
## (`data/secondaries/*.tres`): `SecondarySystem` launches from it and `MissileManager` flies the
## rounds, neither holds a missile number of its own. Splash damage goes through the same
## `DamageInfo` / `Durability.apply` path as every other hit.
##
## Units: metres, seconds, degrees.

## How the round finds its target.
enum Mode {
	## Hold the trigger to lock the selected target, release to launch. The missile steers itself.
	HOMING,
	## Press to fire a salvo of unguided rockets.
	ROCKET,
}

## `strings.csv` key of the weapon's name.
@export var display_name_key: String = ""
@export var mode: Mode = Mode.HOMING

@export_group("Damage")
@export var damage_type: DamageInfo.Type = DamageInfo.Type.EXPLOSIVE
## Raw damage at the centre of the blast, before the `DamageTable` multipliers.
@export var damage: float = 60.0
## Everything this close (measured to the target's surface) to the blast takes damage.
@export var splash_radius_m: float = 14.0
## Fraction of `damage` that reaches a target at the very edge of the blast (linear in between).
@export_range(0.0, 1.0) var splash_edge_fraction: float = 0.3

@export_group("Ammo and fire")
## Rounds carried when full (one missile, or one rocket, is one round).
@export var ammo: int = 6
## Seconds after a launch (after the last rocket of a salvo) before the next may start.
@export var cooldown: float = 1.0
## Rockets in one salvo (1 for a missile).
@export var salvo_count: int = 1
## Seconds between the rockets of a salvo.
@export var salvo_interval: float = 0.08
## Half-angle of the random cone each rocket is fired into.
@export var spread_deg: float = 0.0

@export_group("Flight")
## Added to the ship's own velocity along the launch direction.
@export var launch_speed: float = 120.0
@export var max_speed: float = 300.0
## Speed gained per second until `max_speed`.
@export var acceleration: float = 160.0
## The round self-destructs (harmlessly) after this long.
@export var lifetime: float = 8.0
## Radius of the round for the shape cast, in metres.
@export var radius: float = 0.5
## The proximity fuse only works after the round has flown this far, so it cannot hit its launcher.
@export var arm_distance_m: float = 40.0
## Detonates when its path passes within this many metres of its target's centre (0: contact only).
## A fighter is about 8 m from its centre to its hull, so this is a few metres beyond the skin.
@export var fuse_radius_m: float = 12.0

@export_group("Guidance (homing)")
## Seconds the trigger must be held on a target before the missile is locked.
@export var lock_time: float = 1.2
## A target further away than this cannot be locked.
@export var lock_range_m: float = 1200.0
## A target more than this many degrees off the nose cannot be locked.
@export var lock_cone_deg: float = 20.0
## The fastest the missile can turn, in degrees per second. A small number is what lets a pilot
## outmanoeuvre it.
@export var turn_rate_deg: float = 55.0
## Proportional navigation gain: how hard the missile turns for each radian per second the line
## of sight to its target swings. 3 to 5 is usual.
@export var nav_gain: float = 4.0
## Seconds of straight flight after launch before the seeker starts steering.
@export var ignite_delay: float = 0.35
## The seeker only sees this many degrees either side of the nose. A target that gets further
## round than that (a missile that has flown past it, or one that dodged hard) is lost for good.
@export_range(1.0, 180.0) var seeker_cone_deg: float = 110.0

@export_group("Look and sound")
## Colour of the flame and streak (values above 1 glow).
@export var color: Color = Color(1.0, 0.7, 0.35)
## Length and width of the streak, in metres.
@export var streak_length: float = 9.0
@export var streak_width: float = 0.9
## Diameter of the flash at the muzzle, in metres.
@export var launch_flash_size: float = 3.0
## Colour of the blast.
@export var blast_color: Color = Color(1.0, 0.6, 0.25)
## Sound of a launch (a path under `assets/audio/sfx/`).
@export_file("*.wav") var launch_sfx: String = ""
@export var launch_sfx_db: float = -4.0


func kind() -> StringName:
	return &"secondary"


## True for a missile that steers itself (needs a lock to launch).
func is_homing() -> bool:
	return mode == Mode.HOMING


## `lock_cone_deg` in radians.
func lock_cone_rad() -> float:
	return deg_to_rad(lock_cone_deg)


## `seeker_cone_deg` in radians.
func seeker_cone_rad() -> float:
	return deg_to_rad(seeker_cone_deg)


## `turn_rate_deg` in radians per second.
func turn_rate_rad() -> float:
	return deg_to_rad(turn_rate_deg)


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	var positive: Dictionary[String, float] = {
		"damage": damage,
		"splash_radius_m": splash_radius_m,
		"cooldown": cooldown,
		"salvo_interval": salvo_interval,
		"launch_speed": launch_speed,
		"max_speed": max_speed,
		"acceleration": acceleration,
		"lifetime": lifetime,
		"radius": radius,
		"streak_length": streak_length,
		"streak_width": streak_width,
		"launch_flash_size": launch_flash_size,
	}
	for field: String in positive:
		if positive[field] <= 0.0:
			result.append("%s must be above 0" % field)
	if ammo < 1:
		result.append("ammo must be at least 1")
	if salvo_count < 1 or salvo_count > ammo:
		result.append("salvo_count must be between 1 and ammo")
	if spread_deg < 0.0 or arm_distance_m < 0.0 or fuse_radius_m < 0.0:
		result.append("spread_deg, arm_distance_m and fuse_radius_m must not be negative")
	if launch_speed > max_speed:
		result.append("launch_speed must not exceed max_speed")
	if is_homing():
		var guidance: Dictionary[String, float] = {
			"lock_time": lock_time,
			"lock_range_m": lock_range_m,
			"lock_cone_deg": lock_cone_deg,
			"turn_rate_deg": turn_rate_deg,
			"nav_gain": nav_gain,
			"seeker_cone_deg": seeker_cone_deg,
		}
		for field: String in guidance:
			if guidance[field] <= 0.0:
				result.append("%s must be above 0" % field)
		if ignite_delay < 0.0:
			result.append("ignite_delay must not be negative")
		if seeker_cone_deg > 180.0:
			result.append("seeker_cone_deg must be at most 180")
		if salvo_count != 1:
			result.append("a homing missile fires one at a time (salvo_count 1)")
	if not launch_sfx.is_empty() and not ResourceLoader.exists(launch_sfx):
		result.append("launch_sfx does not exist: %s" % launch_sfx)
	return result
