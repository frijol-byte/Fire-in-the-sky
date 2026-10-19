class_name DevTools
extends Node
## The playtest tools every flight scene carries: the tuning overlay (F1 / Select) and bug
## capture (F12 / Back + Start). Drop `dev_tools.tscn` into a scene and call `bind` once the
## player's ship and camera rig exist. It keeps working while the game is paused.

const TOAST_SECONDS: float = 7.0

var _hotkeys: DevHotkeys = DevHotkeys.new()
var _ship: Ship = null

@onready var _overlay: TuningOverlay = $TuningOverlay
@onready var _toast: Label = $ToastLayer/Toast
@onready var _toast_timer: Timer = $ToastTimer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toast.visible = false
	_toast_timer.wait_time = TOAST_SECONDS
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(func() -> void: _toast.visible = false)


func _input(event: InputEvent) -> void:
	match _hotkeys.feed(event):
		DevHotkeys.Command.TOGGLE_OVERLAY:
			_overlay.toggle()
		DevHotkeys.Command.CAPTURE_BUG:
			capture_bug()


## Tells the tools which ship to dump and tune, and which camera to keep updating.
func bind(ship: Ship, rig: CameraRig) -> void:
	_ship = ship
	_overlay.bind(ship, rig)


## True while the tuning overlay is open (and so the game is paused).
func overlay_open() -> bool:
	return _overlay.is_open()


## Saves a bug report and shows where it went. Returns the report folder's `user://` path.
func capture_bug() -> String:
	var folder: String = BugReport.capture(get_tree(), _ship)
	if folder.is_empty():
		_show_toast(tr("BUG_REPORT_FAILED"))
	else:
		_show_toast(tr("BUG_REPORT_SAVED") % ProjectSettings.globalize_path(folder))
	return folder


func _show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	_toast_timer.start()
