extends Node
## User settings (graphics, audio, controls, accessibility), stored separately from game
## saves. Stub: filled in by the options-menu task.

const SETTINGS_PATH: String = "user://settings.cfg"

## Persisted user settings, keyed by "section/key".
var values: Dictionary[String, Variant] = {}


## Returns the stored value for `key`, or `default_value` if it was never set.
func get_value(key: String, default_value: Variant) -> Variant:
	return values.get(key, default_value)


## Stores `value` for `key`. Call `save()` to persist.
func set_value(key: String, value: Variant) -> void:
	values[key] = value


## Writes the settings file. Returns an `Error` code.
func save() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: String in values:
		var parts: PackedStringArray = key.split("/", true, 1)
		if parts.size() == 2:
			config.set_value(parts[0], parts[1], values[key])
	return config.save(SETTINGS_PATH)
