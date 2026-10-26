class_name DeathScreen
extends CanvasLayer
## The "Ship destroyed" screen (M2-T6). The flight scene arms it when the player's ship blows up;
## it comes up after `delay` seconds (so the explosion is seen first) and offers one button,
## Respawn. The button ignores presses for `input_delay` seconds after the screen appears, because
## the fire button is also the confirm button and a pilot in a fight is still pressing it.
## Pressing it emits `respawn_requested`; the scene respawns the player (insurance and the
## station respawn come with M4). The game keeps running behind the screen.

signal respawn_requested

var _delay_left: float = -1.0
var _input_left: float = 0.0
var _open: bool = false
var _saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

@onready var _panel: Control = $Panel
@onready var _cause: Label = $Panel/Center/Column/Cause
@onready var _respawn: Button = $Panel/Center/Column/Respawn


func _ready() -> void:
	_panel.visible = false
	_respawn.pressed.connect(request_respawn)


func _exit_tree() -> void:
	if _open:
		close()


func _process(delta: float) -> void:
	advance(delta)


## Gets ready to come up `delay` seconds from now. `cause` is the line under the title (e.g.
## who destroyed the ship); `input_delay` is how long the button ignores presses once shown.
func arm(delay: float, input_delay: float, cause: String) -> void:
	close()
	_cause.text = cause
	_input_left = input_delay
	_delay_left = maxf(delay, 0.0)
	if _delay_left <= 0.0:
		_show()


## Moves the countdowns on by `delta` seconds. `_process` calls it; tests call it directly.
func advance(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left <= 0.0:
			_show()
	elif _open and _input_left > 0.0:
		_input_left = maxf(_input_left - delta, 0.0)
		_respawn.disabled = _input_left > 0.0
		if _input_left <= 0.0:
			_respawn.grab_focus()


## True while the screen is up.
func is_open() -> bool:
	return _open


## True while the screen is armed but has not come up yet.
func is_pending() -> bool:
	return _delay_left > 0.0


## True when the screen is up and the button accepts presses.
func accepts_input() -> bool:
	return _open and _input_left <= 0.0


## Asks for a respawn. Ignored while the screen is not up or the button is still locked out.
func request_respawn() -> void:
	if not accepts_input():
		return
	close()
	respawn_requested.emit()


## Hides the screen and cancels a pending one.
func close() -> void:
	_delay_left = -1.0
	if not _open:
		return
	_open = false
	_panel.visible = false
	Input.mouse_mode = _saved_mouse_mode


## The line under the title for a ship destroyed by `killer` (null for no known cause).
func cause_text(killer: Node) -> String:
	if killer != null and is_instance_valid(killer) and killer.has_method(&"target_name"):
		return tr("DEATH_DESTROYED_BY") % killer.call(&"target_name")
	return tr("DEATH_NO_KILLER")


func _show() -> void:
	_delay_left = -1.0
	_open = true
	_saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true
	_respawn.disabled = _input_left > 0.0
