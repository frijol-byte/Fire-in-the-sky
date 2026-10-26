class_name WaveDef
extends Resource
## One wave of an `EncounterDef`: which pirates come, in order. `ship_ids[i]` flies with the AI
## profile `profile_ids[i]`.

## `ShipDef` ids of the pirates in this wave.
@export var ship_ids: Array[StringName] = []
## `AIProfileDef` ids, one per ship (rookie, standard, ace).
@export var profile_ids: Array[StringName] = []


func count() -> int:
	return ship_ids.size()


func problems() -> PackedStringArray:
	var result: PackedStringArray = []
	if ship_ids.is_empty():
		result.append("a wave needs at least one ship")
	if profile_ids.size() != ship_ids.size():
		result.append("ship_ids and profile_ids must have the same length")
	return result
