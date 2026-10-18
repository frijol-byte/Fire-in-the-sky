extends Node
## Loads and indexes every `*Def` resource by id, e.g. `Content.ship("kestrel")`.
##
## At start-up it scans `res://data/` for `.tres` files and registers each one that is a
## `ContentDef` under `def.kind()` and `def.id`. Add content by adding a `.tres` file; there
## is no list to edit.

const DATA_ROOT: String = "res://data"
## Exported builds list resources as `<name>.tres.remap`.
const REMAP_SUFFIX: String = ".remap"

var _defs: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	load_directory(DATA_ROOT)


## Registers `def` under `kind` (e.g. `&"ship"`) and `id`. A second def with the same kind and
## id replaces the first one and logs an error.
func register(kind: StringName, id: StringName, def: Resource) -> void:
	if not _defs.has(kind):
		_defs[kind] = {}
	var by_id: Dictionary = _defs[kind]
	if by_id.has(id):
		Log.error(&"content", "duplicate %s id: %s" % [kind, id])
	by_id[id] = def


## Removes the def of `kind` with `id` (used by tests that register temporary defs).
func unregister(kind: StringName, id: StringName) -> void:
	var by_id: Dictionary = _defs.get(kind, {})
	by_id.erase(id)


## Returns the def of `kind` with `id`, or `null` if it does not exist.
func get_def(kind: StringName, id: StringName) -> Resource:
	var by_id: Dictionary = _defs.get(kind, {})
	return by_id.get(id) as Resource


## Returns the ship def with `id`, or `null`.
func ship(id: StringName) -> ShipDef:
	return get_def(&"ship", id) as ShipDef


## Returns the ids of every def of `kind`, sorted.
func ids(kind: StringName) -> Array[StringName]:
	var by_id: Dictionary = _defs.get(kind, {})
	var result: Array[StringName] = []
	for id: StringName in by_id:
		result.append(id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


## Loads every `.tres` under `path` (recursively) and registers the `ContentDef`s among them.
## Defs with problems are logged and skipped. Returns how many defs were registered.
func load_directory(path: String) -> int:
	var count: int = 0
	for file: String in _find_resources(path):
		var def: ContentDef = load(file) as ContentDef
		if def == null:
			continue
		var found: PackedStringArray = def.problems()
		if not found.is_empty():
			Log.error(&"content", "%s skipped: %s" % [file, ", ".join(found)])
			continue
		register(def.kind(), def.id, def)
		count += 1
	return count


func _find_resources(path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return result
	for sub: String in dir.get_directories():
		result.append_array(_find_resources(path.path_join(sub)))
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(REMAP_SUFFIX)
		if name.ends_with(".tres"):
			result.append(path.path_join(name))
	return result
