class_name EncounterDef
extends ContentDef
## A scripted fight (M2-T7): waves of pirates, one after another, spawned around the player.
## `EncounterDirector` runs it. The combat test arena has one (waves of 1, then 2, then 3).

## The waves, in order.
@export var waves: Array[WaveDef] = []
## Pirates appear this far (metres) from the player, spread over this many degrees of yaw in
## front of the nose (the spread is the full width).
@export var spawn_distance_m: float = 800.0
@export var spawn_spread_deg: float = 50.0
## The pirates of a wave arrive one after another, this many seconds apart (0: all at once), so the
## player is not facing every gun the moment a wave starts.
@export var stagger_seconds: float = 0.0
## Seconds before the first wave of a run, and between a cleared wave and the next.
@export var first_wave_delay: float = 3.0
@export var intermission_seconds: float = 6.0
## True: after the last wave the encounter starts again from wave 1.
@export var loop: bool = true
## Seed of the pilots' dice, so a wave plays out the same way twice (the wave index is added).
@export var seed_base: int = 700


func kind() -> StringName:
	return &"encounter"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if waves.is_empty():
		result.append("an encounter needs at least one wave")
	for index: int in waves.size():
		if waves[index] == null:
			result.append("wave %d is empty" % (index + 1))
			continue
		for problem: String in waves[index].problems():
			result.append("wave %d: %s" % [index + 1, problem])
	if spawn_distance_m <= 0.0:
		result.append("spawn_distance_m must be above 0")
	if spawn_spread_deg < 0.0 or spawn_spread_deg > 170.0:
		result.append("spawn_spread_deg must be between 0 and 170")
	if stagger_seconds < 0.0:
		result.append("stagger_seconds must not be negative")
	if first_wave_delay < 0.0 or intermission_seconds < 0.0:
		result.append("delays must not be negative")
	return result
