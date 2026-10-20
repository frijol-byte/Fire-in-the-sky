class_name TuningSnippet
extends RefCounted
## Turns the tuned `ShipDef` values into a `.tres` snippet the owner can paste into a playtest
## report (and a session can paste into `data/ships/<id>.tres`), and saves it to
## `user://tuning/<ship id>.tres`.

const DIR: String = "user://tuning"


## The snippet text: a `[resource]` line, then one `name = value` line for every field the
## overlay edits, in the same syntax as the ship's `.tres` file. A `Vector3` field appears once
## with all three values.
static func build(def: ShipDef, params: Array[TuningParam]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		"; Tuned values for %s. Replace the same names in data/ships/%s.tres." % [def.id, def.id]
	)
	lines.append("[resource]")
	var seen: Dictionary[String, bool] = {}
	for param: TuningParam in params:
		var name: String = param.property_name()
		if seen.has(name):
			continue
		seen[name] = true
		lines.append("%s = %s" % [name, var_to_str(def.get(param.field))])
	return "\n".join(lines) + "\n"


## Writes `build(def, params)` to `<dir>/<ship id>.tres` and returns that path ("" if the file
## could not be written).
static func save(def: ShipDef, params: Array[TuningParam], dir: String = DIR) -> String:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return ""
	var path: String = dir.path_join("%s.tres" % def.id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(build(def, params))
	file.close()
	return path
