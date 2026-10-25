class_name WeaponDef
extends ContentDef
## One weapon type: what a shot does, how fast it flies, what it costs in energy and heat, and
## how it looks and sounds. Pure data (`data/weapons/*.tres`): `WeaponSystem` fires from it and
## `ProjectileManager` flies the shots, neither holds a weapon number of its own.
##
## Units: metres, seconds, degrees. Energy is `PowerSystem` energy, heat is in the weapon's own
## units (`heat_capacity` is the overheat line).

## GDD 7.2 caps the gimbal at this many degrees.
const MAX_GIMBAL_DEG: float = 3.0

## `strings.csv` key of the weapon's name.
@export var display_name_key: String = ""
## Which hardpoint group fires it: `&"primary"` (sockets `SOCKET_primary_*`) or `&"secondary"`.
@export var slot: StringName = &"primary"

@export_group("Damage")
@export var damage_type: DamageInfo.Type = DamageInfo.Type.ENERGY
## Raw damage of one shot, before the `DamageTable` multipliers.
@export var damage: float = 10.0

@export_group("Fire")
## Shots per second, per mount.
@export var fire_rate: float = 4.0
## Muzzle velocity in m/s (added to nothing: shots do not inherit the ship's speed).
@export var projectile_speed: float = 400.0
## A shot is gone after flying this far, in metres.
@export var range_m: float = 800.0
## Half-angle of the random cone each shot is fired into, in degrees.
@export var spread_deg: float = 0.0
## Radius of the shot for the shape cast, in metres.
@export var projectile_radius: float = 0.3
## The mounts of a group are aimed at a point this far ahead of the ship so their shots cross
## on the reticle. 0 fires them parallel.
@export var convergence_m: float = 350.0
## Largest angle in degrees the mounts may swing off the nose towards the lead point of a locked
## target (gamepad only). GDD 7.2: "slight gimbal", at most `MAX_GIMBAL_DEG`.
@export var gimbal_deg: float = 3.0
## When true the mounts of a group fire one after another instead of together.
@export var stagger: bool = false

@export_group("Energy and heat")
## Energy taken from the capacitor for each shot (`PowerSystem.request`, all or nothing).
@export var energy_cost: float = 0.0
## Heat each shot adds to its mount.
@export var heat_per_shot: float = 0.0
## A mount that reaches this much heat overheats and cannot fire.
@export var heat_capacity: float = 100.0
## Heat lost per second.
@export var cool_rate: float = 20.0
## An overheated mount fires again once its heat is down to this fraction of `heat_capacity`.
@export_range(0.0, 1.0) var overheat_resume_fraction: float = 0.4

@export_group("Look and sound")
## Colour of the shot, its tracer streak and the muzzle flash (values above 1 glow).
@export var tracer_color: Color = Color(1.0, 0.3, 0.2)
## The streak is this long and this wide, in metres.
@export var tracer_length: float = 6.0
@export var tracer_width: float = 0.35
## Diameter of the muzzle flash, in metres.
@export var muzzle_flash_size: float = 1.6
## Colour of the sparks where a shot hits armor or hull.
@export var impact_color: Color = Color(1.0, 0.7, 0.35)
## Sound of one shot (a path under `assets/audio/sfx/`).
@export_file("*.wav") var fire_sfx: String = ""
@export var fire_sfx_db: float = -8.0


func kind() -> StringName:
	return &"weapon"


## Seconds between two shots of one mount.
func interval() -> float:
	return 1.0 / fire_rate if fire_rate > 0.0 else INF


## Seconds a shot lives, from muzzle to the end of its range.
func lifetime() -> float:
	return range_m / projectile_speed if projectile_speed > 0.0 else 0.0


## Heat at which an overheated mount may fire again.
func resume_heat() -> float:
	return heat_capacity * overheat_resume_fraction


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	if slot != &"primary" and slot != &"secondary":
		result.append("slot must be primary or secondary")
	var positive: Dictionary[String, float] = {
		"damage": damage,
		"fire_rate": fire_rate,
		"projectile_speed": projectile_speed,
		"range_m": range_m,
		"projectile_radius": projectile_radius,
		"heat_capacity": heat_capacity,
		"tracer_length": tracer_length,
		"tracer_width": tracer_width,
		"muzzle_flash_size": muzzle_flash_size,
	}
	for field: String in positive:
		if positive[field] <= 0.0:
			result.append("%s must be above 0" % field)
	if fire_rate > 60.0:
		result.append("fire_rate must be at most 60 (one shot per physics tick)")
	var not_negative: Dictionary[String, float] = {
		"spread_deg": spread_deg,
		"convergence_m": convergence_m,
		"energy_cost": energy_cost,
		"heat_per_shot": heat_per_shot,
		"cool_rate": cool_rate,
	}
	for field: String in not_negative:
		if not_negative[field] < 0.0:
			result.append("%s must not be negative" % field)
	if gimbal_deg < 0.0 or gimbal_deg > MAX_GIMBAL_DEG:
		result.append("gimbal_deg must be between 0 and %s" % MAX_GIMBAL_DEG)
	if heat_per_shot > heat_capacity:
		result.append("heat_per_shot must not exceed heat_capacity")
	if not fire_sfx.is_empty() and not ResourceLoader.exists(fire_sfx):
		result.append("fire_sfx does not exist: %s" % fire_sfx)
	return result
