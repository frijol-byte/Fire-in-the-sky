class_name DeviceDef
extends ContentDef
## One device: an active ability with a cooldown that the pilot triggers with a device slot button
## (GDD 7.2). Only the Countermeasure Flares exist so far; Shield Booster, EMP Pulse and Repair
## Nanites come later and add their own `Effect` values. Pure data (`data/devices/*.tres`):
## `DeviceSystem` runs it.

enum Effect {
	## Throws decoy flares that missiles tracking the ship may chase instead.
	FLARES,
}

## `strings.csv` key of the device's name.
@export var display_name_key: String = ""
@export var effect: Effect = Effect.FLARES
## Seconds before the device can be used again.
@export var cooldown: float = 8.0
## Energy taken from the capacitor on use (`PowerSystem.request`); 0 is free.
@export var energy_cost: float = 0.0

@export_group("Flares")
## Flares thrown by one use.
@export var flare_count: int = 4
## Seconds a flare burns.
@export var flare_lifetime: float = 4.0
## Chance (0..1) that a missile tracking the ship chases a flare instead, rolled once per missile
## per use.
@export_range(0.0, 1.0) var decoy_chance: float = 0.65
## Only missiles this close to the ship can be fooled: further out they cannot tell the flares from
## the ship's exhaust.
@export var decoy_range_m: float = 700.0
## Speed the flares leave the ship at, sideways and backwards, in m/s.
@export var eject_speed: float = 35.0
## Colour of a flare (values above 1 glow).
@export var color: Color = Color(1.0, 0.85, 0.5)
## Length and width of a flare's streak, in metres.
@export var streak_length: float = 1.6
@export var streak_width: float = 0.45
## Diameter of the flash where the flares leave, in metres.
@export var flash_size: float = 5.0
## Sound of a use (a path under `assets/audio/sfx/`).
@export_file("*.wav") var use_sfx: String = ""
@export var use_sfx_db: float = -4.0


func kind() -> StringName:
	return &"device"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	if cooldown <= 0.0:
		result.append("cooldown must be above 0")
	if energy_cost < 0.0:
		result.append("energy_cost must not be negative")
	if effect == Effect.FLARES:
		var positive: Dictionary[String, float] = {
			"flare_lifetime": flare_lifetime,
			"decoy_range_m": decoy_range_m,
			"eject_speed": eject_speed,
			"streak_length": streak_length,
			"streak_width": streak_width,
			"flash_size": flash_size,
		}
		for field: String in positive:
			if positive[field] <= 0.0:
				result.append("%s must be above 0" % field)
		if flare_count < 1:
			result.append("flare_count must be at least 1")
	if not use_sfx.is_empty() and not ResourceLoader.exists(use_sfx):
		result.append("use_sfx does not exist: %s" % use_sfx)
	return result
