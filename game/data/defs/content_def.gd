class_name ContentDef
extends Resource
## Base class of every `*Def` resource that `Content` indexes. A def is pure data: stats, prices
## and ids live in `.tres` files under `res://data/`, never as numbers in code.

## Unique within the def's kind, e.g. `&"kestrel"`.
@export var id: StringName = &""


## The kind this def is indexed under in `Content` (e.g. `&"ship"`). Subclasses override it.
func kind() -> StringName:
	return &""


## Returns a list of problems with this def's values (empty when it is fine). Used by
## `Content` when loading and by the data tests.
func problems() -> PackedStringArray:
	var result: PackedStringArray = []
	if id == &"":
		result.append("id is empty")
	return result
