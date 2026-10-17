extends Node
## Serializes `GameState` to and from versioned JSON, with slots and migrations.
## Stub: implemented by the save-system task.

const SAVE_DIR: String = "user://saves"


## Writes `GameState` to `slot`. Returns an `Error` code.
func save_slot(_slot: int) -> Error:
	return ERR_UNAVAILABLE


## Loads `slot` into `GameState`. Returns an `Error` code.
func load_slot(_slot: int) -> Error:
	return ERR_UNAVAILABLE
