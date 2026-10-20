class_name DevHotkeys
extends RefCounted
## The playtest tools' hotkeys. F1 toggles the tuning overlay and F12 captures a bug report.
## On a gamepad, Select alone toggles the overlay and Back + Start (Select + Start) captures a
## bug report, in either press order. Feed every input event to `feed`; it says what to do.
##
## Select toggles on *release*, so pressing it as the first half of the capture chord does not
## also open the overlay.

enum Command { NONE, TOGGLE_OVERLAY, CAPTURE_BUG }

var _back_down: bool = false
var _start_down: bool = false
var _chorded: bool = false


## Returns what `event` asks for, or `Command.NONE`.
func feed(event: InputEvent) -> Command:
	if event is InputEventKey:
		return _feed_key(event as InputEventKey)
	if event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event
		if button.button_index == JOY_BUTTON_BACK:
			return _feed_back(button.pressed)
		if button.button_index == JOY_BUTTON_START:
			return _feed_start(button.pressed)
	return Command.NONE


## True while Select is held on any connected gamepad: the pause menu uses it to ignore the Start
## half of the capture chord.
static func back_held() -> bool:
	for pad: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_BACK):
			return true
	return false


func _feed_key(key: InputEventKey) -> Command:
	if not key.pressed or key.echo:
		return Command.NONE
	match key.physical_keycode:
		KEY_F1:
			return Command.TOGGLE_OVERLAY
		KEY_F12:
			return Command.CAPTURE_BUG
	return Command.NONE


func _feed_back(pressed: bool) -> Command:
	_back_down = pressed
	if pressed:
		if _start_down:
			_chorded = true
			return Command.CAPTURE_BUG
		return Command.NONE
	var toggle: bool = not _chorded
	_chorded = false
	return Command.TOGGLE_OVERLAY if toggle else Command.NONE


func _feed_start(pressed: bool) -> Command:
	_start_down = pressed
	if pressed and _back_down:
		_chorded = true
		return Command.CAPTURE_BUG
	return Command.NONE
