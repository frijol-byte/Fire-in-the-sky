class_name ShotDirector
extends Node
## Drives repeatable screenshots. Put one in a scene under `game/tests/shots/`, list the
## shots, and `tools/screenshot.sh` renders the scene and keeps exactly those frames.
##
## For every `ShotDef` the director moves the camera on the shot's frame. It tells the
## screenshot script which frames to keep by writing a manifest to the path given with
## `--shot-manifest=<path>` (user arg after `--`), then quits once the last frame is done.
## Without that argument (for example when you press F6 in the editor) it just plays.

const MANIFEST_ARG: String = "--shot-manifest="
## Frames to wait between freeing the scene and quitting.
const QUIT_FRAMES: int = 3

## Shots to take, in any order.
@export var shots: Array[ShotDef] = []
## Camera to move. When empty the viewport's current 3D camera is used.
@export var camera: Camera3D = null
## Extra frames to run after the last shot so the movie writer flushes it.
@export var tail_frames: int = 2

var _manifest_path: String = ""
var _last_frame: int = 0


func _ready() -> void:
	_manifest_path = manifest_path_from_args(OS.get_cmdline_user_args())
	_last_frame = last_frame(shots)
	write_manifest(_manifest_path, shots)


func _process(_delta: float) -> void:
	var frame: int = Engine.get_frames_drawn()
	for shot: ShotDef in shots_on_frame(shots, frame):
		_apply(shot)
	if not _manifest_path.is_empty() and frame >= _last_frame + tail_frames:
		set_process(false)
		_quit_cleanly()


## Frees the rest of the scene and lets a few frames pass before quitting. A sound still playing
## when the engine exits is reported as a leaked resource, which `tools/screenshot.sh` would count
## as an error; the audio server only lets go of it a frame or two after the player is freed.
func _quit_cleanly() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		for child: Node in scene.get_children():
			if child != self:
				child.queue_free()
	for _frame: int in QUIT_FRAMES:
		await get_tree().process_frame
	get_tree().quit()


## Returns the manifest path from `args`, or "" when the argument is absent.
static func manifest_path_from_args(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with(MANIFEST_ARG):
			return arg.substr(MANIFEST_ARG.length())
	return ""


## Returns the shots whose frame is `frame`.
static func shots_on_frame(shots: Array[ShotDef], frame: int) -> Array[ShotDef]:
	var result: Array[ShotDef] = []
	for shot: ShotDef in shots:
		if shot.frame == frame:
			result.append(shot)
	return result


## Returns the highest frame number among `shots` (0 when there are none).
static func last_frame(shots: Array[ShotDef]) -> int:
	var result: int = 0
	for shot: ShotDef in shots:
		result = maxi(result, shot.frame)
	return result


## Returns the manifest text for `shots`: `{"shots": [{"label": ..., "frame": ...}, ...]}`.
static func manifest_json(shots: Array[ShotDef]) -> String:
	var entries: Array[Dictionary] = []
	for shot: ShotDef in shots:
		entries.append({"label": shot.label, "frame": shot.frame})
	return JSON.stringify({"shots": entries}, "  ")


## Writes the manifest to `path`. Does nothing when `path` is empty.
static func write_manifest(path: String, shots: Array[ShotDef]) -> void:
	if path.is_empty():
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ShotDirector: cannot write manifest to %s" % path)
		return
	file.store_string(manifest_json(shots))
	file.close()


func _apply(shot: ShotDef) -> void:
	if not shot.move_camera:
		return
	var cam: Camera3D = camera if camera != null else get_viewport().get_camera_3d()
	if cam == null:
		push_error("ShotDirector: shot '%s' needs a Camera3D" % shot.label)
		return
	cam.global_position = shot.camera_position
	cam.fov = shot.fov
	cam.look_at(shot.look_at_point)
