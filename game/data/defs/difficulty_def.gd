class_name DifficultyDef
extends ContentDef
## A difficulty setting (GDD 10). A stub for now: it only carries the aim assist's scale, and grows
## the enemy and economy multipliers when those systems need them (M3 and later).

## `strings.csv` key of the difficulty's name.
@export var display_name_key: String = ""
## Multiplies the aim assist's strength (0 turns it off, 1 is the full effect).
@export_range(0.0, 1.0) var aim_assist_scale: float = 1.0


func kind() -> StringName:
	return &"difficulty"


func problems() -> PackedStringArray:
	var result: PackedStringArray = super.problems()
	if display_name_key.is_empty():
		result.append("display_name_key is empty")
	if aim_assist_scale < 0.0 or aim_assist_scale > 1.0:
		result.append("aim_assist_scale must be between 0 and 1")
	return result
