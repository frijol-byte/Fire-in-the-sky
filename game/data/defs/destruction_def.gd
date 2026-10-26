class_name DestructionDef
extends ContentDef
## How a ship (or dummy) blows up (M2-T6): the fireball and its light, the debris, what the wreck
## does and how long it takes to fade, plus the respawn screen timings. Sizes are relative to the
## destroyed thing's own size, so a freighter gets a bigger blast than a fighter.

@export_group("Fireball")
## The fireball is this many times the destroyed ship's radius across.
@export var fireball_radius_factor: float = 3.2
## ... but never smaller than this (metres), so a dummy still makes a show.
@export var fireball_min_radius: float = 9.0
@export var fireball_seconds: float = 1.1
@export var fireball_color: Color = Color(1.0, 0.62, 0.2, 1.0)
## The light the blast casts: peak energy, range in multiples of the fireball radius, and how long
## it takes to die away.
@export var light_energy: float = 6.0
@export var light_range_factor: float = 6.0
@export var light_seconds: float = 0.9
## The ring of the shockwave: how much bigger than the fireball it grows, and how long it takes.
@export var shockwave_factor: float = 1.8

@export_group("Debris")
@export var debris_count: int = 14
## Chunk speed, in m/s on top of the wreck's own velocity.
@export var debris_speed_min: float = 12.0
@export var debris_speed_max: float = 48.0
## A chunk is between these fractions of the ship's radius long.
@export var debris_size_min: float = 0.08
@export var debris_size_max: float = 0.3
## How fast chunks tumble, at most, in degrees per second.
@export var debris_spin_max_deg: float = 220.0
@export var debris_lifetime: float = 4.5
## Chunks glow hot at first and are cold after this many seconds.
@export var debris_cool_seconds: float = 1.6

@export_group("Wreck")
## The wreck tumbles at up to this many degrees per second on each axis while it fades.
@export var wreck_tumble_deg: float = 55.0
## It shrinks away over this many seconds, starting with the blast.
@export var wreck_fade_seconds: float = 2.5

@export_group("Respawn")
## The "Ship destroyed" screen comes up this long after the player's ship blows up, so the blast
## is seen first.
@export var death_screen_delay: float = 2.0
## The respawn button ignores presses for this long after the screen appears (the fire button is
## the confirm button too, and a player in a fight is still pressing it).
@export var respawn_input_delay: float = 1.2


func kind() -> StringName:
	return &"destruction"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if fireball_radius_factor <= 0.0 or fireball_min_radius <= 0.0:
		result.append("fireball_radius_factor and fireball_min_radius must be above 0")
	if fireball_seconds <= 0.0 or light_seconds <= 0.0:
		result.append("fireball_seconds and light_seconds must be above 0")
	if light_energy < 0.0 or light_range_factor <= 0.0 or shockwave_factor < 1.0:
		result.append("light_energy must not be negative, light_range_factor above 0")
	if debris_count < 0:
		result.append("debris_count must not be negative")
	if debris_speed_min < 0.0 or debris_speed_max < debris_speed_min:
		result.append("debris_speed_min must be 0 or more and not above debris_speed_max")
	if debris_size_min <= 0.0 or debris_size_max < debris_size_min:
		result.append("debris_size_min must be above 0 and not above debris_size_max")
	if debris_lifetime <= 0.0 or debris_cool_seconds <= 0.0:
		result.append("debris_lifetime and debris_cool_seconds must be above 0")
	if wreck_fade_seconds <= 0.0 or wreck_tumble_deg < 0.0 or debris_spin_max_deg < 0.0:
		result.append("wreck_fade_seconds must be above 0, tumble and spin not negative")
	if death_screen_delay < 0.0 or respawn_input_delay < 0.0:
		result.append("death_screen_delay and respawn_input_delay must not be negative")
	return result
