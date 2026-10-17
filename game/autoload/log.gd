extends Node
## Structured logging. Writes every line to `user://logs/session.log` so bug reports can
## attach it, and mirrors to the Godot output.

enum Level { DEBUG, INFO, WARN, ERROR }

const LOG_DIR: String = "user://logs"
const LOG_FILE: String = "user://logs/session.log"
const LEVEL_NAMES: PackedStringArray = ["DEBUG", "INFO", "WARN", "ERROR"]

## Lines below this level are dropped.
var min_level: Level = Level.INFO

var _file: FileAccess = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	_file = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	info("log", "session started")


func _exit_tree() -> void:
	if _file != null:
		_file.close()
		_file = null


## Logs a debug line for `channel`.
func debug(channel: StringName, message: String) -> void:
	_write(Level.DEBUG, channel, message)


## Logs an informational line for `channel`.
func info(channel: StringName, message: String) -> void:
	_write(Level.INFO, channel, message)


## Logs a warning for `channel`. Warnings are written to the log file only, so expected
## conditions never trip the "zero warnings" test gates.
func warn(channel: StringName, message: String) -> void:
	_write(Level.WARN, channel, message)


## Logs an error for `channel`. Pushes to the engine error log too, which tests treat as a
## failure.
func error(channel: StringName, message: String) -> void:
	_write(Level.ERROR, channel, message)
	push_error("[%s] %s" % [channel, message])


func _write(level: Level, channel: StringName, message: String) -> void:
	if level < min_level:
		return
	var stamp: String = Time.get_datetime_string_from_system()
	var line: String = "[%s] [%s] [%s] %s" % [stamp, LEVEL_NAMES[level], channel, message]
	if _file != null:
		_file.store_line(line)
		_file.flush()
	print(line)
