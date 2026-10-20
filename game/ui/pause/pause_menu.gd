class_name PauseMenu
extends CanvasLayer
## A minimal pause menu for flight scenes: Resume, Open bug report folder, Quit. Esc / Start
## toggles it and the game is paused while it is open. Fully usable with a gamepad (the first
## button has focus). The full menu with options and saves comes with the game flow task.

signal opened
signal closed

var _open: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _panel: Control = $Panel
@onready var _resume: Button = $Panel/Center/Column/Resume
@onready var _bug_folder: Button = $Panel/Center/Column/BugFolder
@onready var _quit: Button = $Panel/Center/Column/Quit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_resume.pressed.connect(close)
	_bug_folder.pressed.connect(open_bug_report_folder)
	_quit.pressed.connect(func() -> void: get_tree().quit())


func _exit_tree() -> void:
	if _open:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	# Back + Start is the bug capture chord, not a pause.
	if DevHotkeys.back_held():
		return
	if _open:
		close()
	elif not get_tree().paused:
		open()
	else:
		return
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true
	get_tree().paused = true
	_resume.grab_focus()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = _saved_mouse_mode
	closed.emit()


## Opens the folder the bug reports are saved in with the system file browser (creating it
## first so there is always something to open).
func open_bug_report_folder() -> void:
	DirAccess.make_dir_recursive_absolute(BugReport.ROOT)
	OS.shell_open(ProjectSettings.globalize_path(BugReport.ROOT))
