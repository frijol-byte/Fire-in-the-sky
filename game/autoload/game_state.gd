extends Node
## The current save's live data (player profile, wallet, cargo, reputation, missions, world
## state). Stub: fields are added by the tasks that own them.

## Bumped whenever the serialized shape changes; `SaveSystem` migrates between versions.
const SCHEMA_VERSION: int = 1


## Resets all live data to a new game.
func reset() -> void:
	pass


## Returns the live data as a plain, JSON-safe dictionary for `SaveSystem`.
func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION}
