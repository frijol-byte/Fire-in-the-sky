class_name BugReport
extends RefCounted
## Bug capture: a screenshot, the last 200 log lines and a JSON state dump, written into a new
## folder under `user://bug_reports/`. The owner attaches that folder to a playtest report.
##
## `capture` gathers everything from the running game; `write` is the plain file writer (unit
## tested), and `state_dict` builds the dump.

const BootScript: GDScript = preload("res://core/boot/boot.gd")
const ROOT: String = "user://bug_reports"
const LOG_LINES: int = 200
const SCREENSHOT_FILE: String = "screenshot.png"
const LOG_FILE: String = "log.txt"
const STATE_FILE: String = "state.json"


## Captures the current frame, log and state into a new folder and returns the folder's
## `user://` path ("" when it could not be created). `ship` may be null (no flight scene).
static func capture(tree: SceneTree, ship: Ship = null, root: String = ROOT) -> String:
	var state: Dictionary = state_dict(
		tree.current_scene.scene_file_path if tree.current_scene != null else "",
		ship,
		Settings.values,
		InputRouter.last_device
	)
	var image: Image = null
	# The headless renderer has no frame to grab.
	if DisplayServer.get_name() != "headless":
		image = tree.root.get_viewport().get_texture().get_image()
	var folder: String = write(root, state, Log.recent_lines(LOG_LINES), image)
	if folder.is_empty():
		Log.error(&"bug_report", "could not create a bug report folder under %s" % root)
	else:
		Log.info(&"bug_report", "bug report saved to %s" % folder)
	return folder


## Creates `<root>/<timestamp>/` and writes the screenshot (if `image` is a real image), the
## log lines and the state dump into it. Returns the folder path, or "" on failure.
static func write(
	root: String, state: Dictionary, log_lines: PackedStringArray, image: Image
) -> String:
	var folder: String = _new_folder(root)
	if folder.is_empty():
		return ""
	if image != null and not image.is_empty():
		image.save_png(folder.path_join(SCREENSHOT_FILE))
	var log_file: FileAccess = FileAccess.open(folder.path_join(LOG_FILE), FileAccess.WRITE)
	if log_file != null:
		for line: String in log_lines:
			log_file.store_line(line)
		log_file.close()
	var state_file: FileAccess = FileAccess.open(folder.path_join(STATE_FILE), FileAccess.WRITE)
	if state_file != null:
		state_file.store_string(JSON.stringify(state, "\t"))
		state_file.close()
	return folder


## The JSON-safe state dump: where the game is, what the player's ship is doing, the settings.
static func state_dict(
	scene_path: String, ship: Ship, settings: Dictionary, device: int
) -> Dictionary:
	var state: Dictionary = {
		"time": Time.get_datetime_string_from_system(),
		"version": BootScript.read_version(),
		"engine": Engine.get_version_info().get("string", ""),
		"renderer": RenderingServer.get_video_adapter_name(),
		"scene": scene_path,
		"input_device": InputRouter.Device.keys()[device] if device >= 0 else "",
		"ship": ship_state(ship),
		"settings": json_safe(settings),
	}
	return state


## What a bug needs to know about `ship`, or an empty dictionary without one.
static func ship_state(ship: Ship) -> Dictionary:
	if ship == null or not ship.is_inside_tree():
		return {}
	var power: PowerSystem = ship.power()
	return {
		"id": str(ship.def.id) if ship.def != null else "",
		"position": json_safe(ship.global_position),
		"velocity": json_safe(ship.linear_velocity),
		"local_velocity": json_safe(ship.local_velocity()),
		"speed": ship.linear_velocity.length(),
		"rotation_degrees": json_safe(ship.global_basis.get_euler() * (180.0 / PI)),
		"angular_velocity": json_safe(ship.angular_velocity),
		"fa_off": ship.controls.fa_off,
		"boosting": ship.is_boosting(),
		"energy": power.energy,
		"energy_capacity": power.capacity,
	}


## Turns `value` into something `JSON.stringify` keeps faithfully: vectors become arrays,
## dictionaries and arrays are converted recursively, and any other non-JSON type becomes the
## text `var_to_str` gives.
static func json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_VECTOR2:
			var v2: Vector2 = value
			return [v2.x, v2.y]
		TYPE_VECTOR3:
			var v3: Vector3 = value
			return [v3.x, v3.y, v3.z]
		TYPE_DICTIONARY:
			var converted: Dictionary = {}
			for key: Variant in value:
				converted[str(key)] = json_safe(value[key])
			return converted
		TYPE_ARRAY:
			var items: Array = []
			for item: Variant in value:
				items.append(json_safe(item))
			return items
	return var_to_str(value)


## `2026-10-19_14-03-22`, safe in a folder name.
static func timestamp_name(datetime: String) -> String:
	return datetime.replace("T", "_").replace(":", "-")


static func _new_folder(root: String) -> String:
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return ""
	var base: String = root.path_join(timestamp_name(Time.get_datetime_string_from_system()))
	var folder: String = base
	var suffix: int = 2
	while DirAccess.dir_exists_absolute(folder):
		folder = "%s_%d" % [base, suffix]
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	return folder
