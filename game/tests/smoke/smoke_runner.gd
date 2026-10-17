extends SceneTree
## Smoke test: boots every scene in `scenes.txt` for `FRAMES` frames and fails on any engine
## error or warning.
##
## Run with: godot --headless --path game -s res://tests/smoke/smoke_runner.gd
## Exit code 0 = all scenes booted cleanly, 1 = at least one problem.

const SCENE_LIST: String = "res://tests/smoke/scenes.txt"
const FRAMES: int = 300

var _catcher: SmokeLogCatcher = SmokeLogCatcher.new()
var _failures: int = 0


func _initialize() -> void:
	OS.add_logger(_catcher)
	_run.call_deferred()


func _run() -> void:
	var scenes: PackedStringArray = _read_scene_list()
	if scenes.is_empty():
		_fail("no scenes listed in %s" % SCENE_LIST)
	for path: String in scenes:
		await _boot_scene(path)
	OS.remove_logger(_catcher)
	print(
		(
			"SMOKE %s: %d scene(s), %d failure(s)"
			% ["FAIL" if _failures > 0 else "OK", scenes.size(), _failures]
		)
	)
	quit(1 if _failures > 0 else 0)


func _boot_scene(path: String) -> void:
	var before: int = _catcher.problems.size()
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("%s: could not load" % path)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	for i: int in FRAMES:
		await process_frame
	instance.queue_free()
	await process_frame
	var new_problems: PackedStringArray = _catcher.problems.slice(before)
	for problem: String in new_problems:
		_fail("%s: %s" % [path, problem])
	if new_problems.is_empty():
		print("SMOKE ok: %s (%d frames)" % [path, FRAMES])


func _read_scene_list() -> PackedStringArray:
	var scenes: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(SCENE_LIST).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			scenes.append(trimmed)
	return scenes


func _fail(message: String) -> void:
	_failures += 1
	printerr("SMOKE FAIL: %s" % message)
