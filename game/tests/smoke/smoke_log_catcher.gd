class_name SmokeLogCatcher
extends Logger
## Collects every engine error and warning while the smoke test runs.

var problems: PackedStringArray = []

var _mutex: Mutex = Mutex.new()


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	_editor_notify: bool,
	error_type: int,
	_script_backtraces: Array[ScriptBacktrace]
) -> void:
	var kind: String = "warning" if error_type == ERROR_TYPE_WARNING else "error"
	var text: String = rationale if not rationale.is_empty() else code
	_mutex.lock()
	problems.append("%s: %s (%s:%d in %s)" % [kind, text, file, line, function])
	_mutex.unlock()
