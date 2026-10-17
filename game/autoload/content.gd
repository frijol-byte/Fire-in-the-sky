extends Node
## Loads and indexes every `*Def` resource by id, e.g. `Content.ship("kestrel")`.
## Stub: the `*Def` classes and the loader arrive with the first content task.

var _defs: Dictionary[StringName, Dictionary] = {}


## Registers `def` under `kind` (e.g. `&"ship"`) and `id`.
func register(kind: StringName, id: StringName, def: Resource) -> void:
	if not _defs.has(kind):
		_defs[kind] = {}
	var by_id: Dictionary = _defs[kind]
	by_id[id] = def


## Returns the def of `kind` with `id`, or `null` if it does not exist.
func get_def(kind: StringName, id: StringName) -> Resource:
	var by_id: Dictionary = _defs.get(kind, {})
	return by_id.get(id) as Resource
